#!/usr/bin/env python3
"""Check configured IDs and their actual Android AAB/Web PCK copies offline.

This is configuration/package evidence, not native service or store acceptance.
No SDK, account, network, signing key or ad request is used. Protobuf field numbers
follow AOSP tools/aapt2/Resources.proto; PCK layout follows Godot 4.5.1
core/io/file_access_pack.cpp. Both formats are read without extracting files.
Signature-file detection does not verify a certificate or signature; use an
independent jarsigner verification for a signed debug delivery.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import sys
import zipfile

SAMPLE_APP_ID = 'ca-app-pub-3940256099942544~3347511713'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'Duplicate JSON key: ' + key)
        result[key] = value
    return result


def read_json(data):
    return json.loads(data, object_pairs_hook=unique_object)


def sections(path):
    text = Path(path).read_text(encoding='utf-8-sig')
    return dict(re.findall(r'^\[([^\]]+)\]\s*\n(.*?)(?=^\[|\Z)', text, re.M | re.S))


def setting(body, key):
    matches = re.findall(r'^' + re.escape(key) + r'=(.*)$', body, re.M)
    require(len(matches) == 1, 'Missing or duplicate setting: ' + key)
    return matches[0].strip().strip('"')


def source_configuration(root):
    config = read_json((root / 'platform/config.json').read_bytes())
    catalog = read_json((root / 'game/catalog.json').read_bytes())
    ads, games = config['admob'], config['play_games']
    require(games['enabled'] is True, 'Play Games must be enabled in production config')
    require(ads['test_mode'] is False, 'Production config must set test_mode=false')
    require(re.fullmatch(r'[1-9][0-9]+', games['game_id']) is not None, 'Invalid numeric PGS game ID')
    require(re.fullmatch(r'ca-app-pub-[0-9]{16}~[0-9]{10}', ads['app_id']) is not None, 'Invalid AdMob App ID')
    require('3940256099942544' not in ads['app_id'], 'Production App ID is still Google sample')
    for kind in ('banner', 'interstitial', 'rewarded'):
        unit = ads[kind + '_unit_id']
        require(re.fullmatch(r'ca-app-pub-[0-9]{16}/[0-9]{10}', unit) is not None, 'Invalid ad unit: ' + kind)
        require(unit.split('/')[0] == ads['app_id'].split('~')[0], 'Ad unit publisher differs from App ID: ' + kind)
    require(len({ads[k + '_unit_id'] for k in ('banner', 'interstitial', 'rewarded')}) == 3, 'Duplicate ad units')
    all_ids = []
    for category, expected in (('achievements', 20), ('leaderboards', 4)):
        keys = [item['id'] for item in catalog[category]]
        require(len(keys) == len(set(keys)) == expected, 'Unexpected catalog ' + category)
        require(set(games[category]) == set(keys), 'Mappings differ from catalog: ' + category)
        for key, remote_id in games[category].items():
            require(isinstance(remote_id, str) and re.fullmatch(r'Cgk[A-Za-z0-9_-]+', remote_id) is not None,
                    'Invalid remote ID: ' + category + '.' + key)
            all_ids.append(remote_id)
    require(len(set(all_ids)) == len(all_ids), 'Duplicate Play Games remote IDs')
    project = sections(root / 'project.godot')
    require(setting(project.get('admob', ''), 'general/android/app_id') == ads['app_id'], 'Project manifest App ID differs from JSON')
    presets = sections(root / 'export_presets.cfg')
    android_names = [name for name, body in presets.items()
                     if re.fullmatch(r'preset\.[0-9]+', name) and setting(body, 'name') == 'Android']
    require(len(android_names) == 1, 'Expected one Android preset')
    options = presets[android_names[0] + '.options']
    require(setting(options, 'godot_play_game_services/game_id') == games['game_id'], 'Android PGS game ID differs from JSON')
    require(setting(options, 'package/unique_name') == 'com.ethannyakabuski.mosslightbastion', 'Unexpected Android package')
    require(setting(options, 'gradle_build/min_sdk') == '24', 'Unexpected minimum SDK')
    require(setting(options, 'gradle_build/target_sdk') == '36', 'Production Android export must target API 36')
    require(setting(options, 'package/app_category') == '2', 'Android category must be Game (Godot enum index 2)')
    return config, catalog, options


def varint(data, position):
    result = 0
    for shift in range(0, 70, 7):
        require(position < len(data), 'Truncated protobuf varint')
        value = data[position]
        position += 1
        result |= (value & 127) << shift
        if value < 128:
            return result, position
    raise ValueError('Oversize protobuf varint')


def protobuf(data):
    position, result = 0, {}
    while position < len(data):
        key, position = varint(data, position)
        number, wire = key >> 3, key & 7
        require(number > 0, 'Invalid protobuf field')
        if wire == 0:
            value, position = varint(data, position)
        elif wire in (1, 2, 5):
            if wire == 2:
                size, position = varint(data, position)
            else:
                size = 8 if wire == 1 else 4
            require(position + size <= len(data), 'Truncated protobuf value')
            value = data[position:position + size]
            position += size
        else:
            raise ValueError('Unsupported protobuf wire type')
        result.setdefault(number, []).append(value)
    return result


def one(fields, number, default=None):
    values = fields.get(number, [])
    require(len(values) <= 1, 'Duplicate singular protobuf field')
    return values[0] if values else default


def text(fields, number):
    return one(fields, number, b'').decode('utf-8')


def xml_elements(data):
    node = protobuf(data)
    element = one(node, 1)
    if element is None:
        return
    fields = protobuf(element)
    attributes = {}
    for attribute in fields.get(4, []):
        attr = protobuf(attribute)
        key = text(attr, 2)
        require(key not in attributes, 'Duplicate manifest attribute: ' + key)
        attributes[key] = text(attr, 3)
    yield text(fields, 3), attributes
    for child in fields.get(5, []):
        yield from xml_elements(child)


def resource_strings(data, name):
    values = []
    for package in protobuf(data).get(2, []):
        for resource_type in protobuf(package).get(3, []):
            resource_type = protobuf(resource_type)
            if text(resource_type, 2) != 'string':
                continue
            for entry in resource_type.get(3, []):
                entry = protobuf(entry)
                if text(entry, 2) != name:
                    continue
                for config_value in entry.get(6, []):
                    value = protobuf(one(protobuf(config_value), 2, b''))
                    item = protobuf(one(value, 4, b''))
                    string = protobuf(one(item, 2, b''))
                    values.append(text(string, 1))
    require(values, 'Packaged Android string resource is missing: ' + name)
    return values


def check_bundle(path, config, catalog, options, variant):
    require(variant in ('release', 'debug'), 'Unknown bundle variant')
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        require(len(names) == len(set(names)), 'Duplicate AAB ZIP entries')
        require('BundleConfig.pb' in names, 'Not an Android App Bundle')
        manifest = list(xml_elements(archive.read('base/manifest/AndroidManifest.xml')))
        root = [attrs for name, attrs in manifest if name == 'manifest']
        require(len(root) == 1, 'Expected one manifest root')
        for attr, key in (('package', 'package/unique_name'), ('versionCode', 'version/code'), ('versionName', 'version/name')):
            require(root[0].get(attr) == setting(options, key), 'Packaged manifest differs: ' + attr)
        sdks = [attrs for name, attrs in manifest if name == 'uses-sdk']
        require(len(sdks) == 1, 'Expected one uses-sdk element')
        for attr, key in (('minSdkVersion', 'gradle_build/min_sdk'), ('targetSdkVersion', 'gradle_build/target_sdk')):
            require(sdks[0].get(attr) == setting(options, key), 'Packaged manifest differs: ' + attr)
        metadata = {}
        for name, attrs in manifest:
            if name == 'meta-data':
                require(attrs['name'] not in metadata, 'Duplicate manifest metadata: ' + attrs['name'])
                metadata[attrs['name']] = attrs.get('value', attrs.get('resource'))
        expected_app_id = SAMPLE_APP_ID if variant == 'debug' else config['admob']['app_id']
        require(metadata.get('com.google.android.gms.ads.APPLICATION_ID') == expected_app_id, 'Packaged manifest App ID differs')
        require(metadata.get('com.google.android.gms.games.APP_ID') == '@string/game_services_project_id', 'Unexpected PGS metadata reference')
        require(set(resource_strings(archive.read('base/resources.pb'), 'game_services_project_id')) == {config['play_games']['game_id']}, 'Resolved packaged PGS game ID differs')
        for plugin in ('GodotPlayGameServices', 'PoingGodotAdMob'):
            require('org.godotengine.plugin.v2.' + plugin in metadata, 'Native plugin metadata is missing: ' + plugin)
        for relative, expected in (('platform/config.json', config), ('game/catalog.json', catalog)):
            candidates = [n for n in names if n.endswith('/assets/' + relative)]
            require(len(candidates) == 1, 'Expected one packaged asset: ' + relative)
            require(read_json(archive.read(candidates[0])) == expected, 'Packaged JSON differs from source: ' + relative)
        signature_files = sorted(n for n in names if re.fullmatch(r'META-INF/[^/]+\.(RSA|DSA|EC|SF)', n, re.I))
        signature_stems = {n.rsplit('.', 1)[0].upper() for n in signature_files if n.upper().endswith('.SF')}
        certificate_stems = {n.rsplit('.', 1)[0].upper() for n in signature_files if not n.upper().endswith('.SF')}
        signed = bool(signature_stems & certificate_stems)
        apps = [attrs for name, attrs in manifest if name == 'application']
        require(len(apps) == 1, 'Expected one application element')
        require(apps[0].get('appCategory') == 'game' and apps[0].get('isGame') == 'true', 'Packaged Android application is not categorized as a game')
        require(apps[0].get('allowBackup') == 'false', 'Packaged game must retain local-only backup behavior')
        debuggable = apps[0].get('debuggable', 'false') == 'true'
        if variant == 'release':
            require(not signature_files, 'Expected unsigned release AAB for owner signing')
            require(not debuggable, 'Release AAB is debuggable')
        if variant == 'debug':
            require(signed, 'Expected test-signed debug AAB')
            require(debuggable, 'Debug AAB is not debuggable')
        with Path(path).open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        return {'path': str(path), 'sha256': digest,
                'variant': variant, 'signed': signed, 'signature_files': signature_files,
                'signature_cryptographically_verified': False, 'debuggable': debuggable,
                'app_category': apps[0]['appCategory'], 'is_game': True, 'allow_backup': False,
                'manifest_admob_app_id': expected_app_id, 'permissions': sorted(attrs['name'] for name, attrs in manifest if name == 'uses-permission'),
                'package': root[0]['package'],
                'version': root[0]['versionName'], 'version_code': root[0]['versionCode'],
                'sdk': sdks[0], 'manifest_and_packaged_IDs': 'PASS'}


def pck_json(path, relative):
    with Path(path).open('rb') as stream:
        def unpack(fmt):
            size = struct.calcsize(fmt)
            data = stream.read(size)
            require(len(data) == size, 'Truncated PCK')
            return struct.unpack(fmt, data)
        magic, version, major, minor, patch, flags, file_base = unpack('<6IQ')
        require(magic == 0x43504447 and version in (2, 3), 'Unsupported Godot PCK format')
        require(not flags & 1, 'Encrypted PCK directory cannot be inspected')
        if version == 3:
            directory, = unpack('<Q')
            stream.seek(directory)
        else:
            stream.seek(16 * 4, 1)
        count, = unpack('<I')
        require(count < 1000000, 'Unreasonable PCK entry count')
        found = []
        for _ in range(count):
            length, = unpack('<I')
            require(length < 1024 * 1024, 'Unreasonable PCK path length')
            name = stream.read(length).rstrip(b'\0').decode('utf-8').removeprefix('res://')
            offset, size, digest, entry_flags = unpack('<QQ16sI')
            if name == relative:
                require(not entry_flags & 3, 'PCK entry is removed or encrypted')
                found.append((file_base + offset, size, digest))
        require(len(found) == 1, 'Expected one PCK file: ' + relative)
        offset, size, digest = found[0]
        stream.seek(offset)
        data = stream.read(size)
        require(len(data) == size and hashlib.md5(data).digest() == digest, 'PCK content checksum differs')
        return read_json(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--bundle', type=Path)
    parser.add_argument('--variant', choices=('debug', 'release'), default='release')
    parser.add_argument('--web-pck', type=Path)
    args = parser.parse_args()
    try:
        config, catalog, options = source_configuration(args.root)
        result = {'source_configuration': 'PASS', 'achievement_mappings': 20, 'leaderboard_mappings': 4,
                  'native_service_acceptance': False, 'google_play_submission_verified': False}
        if args.bundle:
            result['android'] = check_bundle(args.bundle, config, catalog, options, args.variant)
        if args.web_pck:
            require(pck_json(args.web_pck, 'platform/config.json') == config, 'Web packaged config differs')
            require(pck_json(args.web_pck, 'game/catalog.json') == catalog, 'Web packaged catalog differs')
            result['web_packaged_IDs'] = 'PASS'
        print(json.dumps(result, indent=2))
    except (ValueError, OSError, KeyError, TypeError, zipfile.BadZipFile, struct.error) as error:
        print('PRODUCTION INTEGRATION VALIDATION FAILED: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
