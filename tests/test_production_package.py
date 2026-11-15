"""Offline package-inspection regressions; no Godot, account or SDK is invoked."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('integration', ROOT / 'tools/verify_production_integration.py')
integration = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(integration)


def varint(value):
    result = bytearray()
    while value > 127:
        result.append((value & 127) | 128)
        value >>= 7
    result.append(value)
    return bytes(result)


def field(number, value):
    if isinstance(value, str):
        value = value.encode()
    return varint(number << 3 | 2) + varint(len(value)) + value


def element(name, attrs=None, children=()):
    data = field(3, name)
    for key, value in (attrs or {}).items():
        data += field(4, field(2, key) + field(3, value))
    for child in children:
        data += field(5, child)
    return field(1, data)


def resources(game_id):
    # ResourceTable.package -> Package.type -> Type.entry -> Entry.config_value
    # -> ConfigValue.value -> Value.item -> Item.str -> String.value.
    entry = field(2, 'game_services_project_id')
    entry += field(6, field(2, field(4, field(2, field(1, game_id)))))
    return field(2, field(3, field(2, 'string') + field(3, entry)))


def manifest(config, options, debuggable=False, app_id=None, package=None, app_flags=None):
    attrs = {'package': integration.setting(options, 'package/unique_name'),
             'versionCode': integration.setting(options, 'version/code'),
             'versionName': integration.setting(options, 'version/name')}
    if package is not None:
        attrs['package'] = package
    if app_id is None:
        app_id = integration.SAMPLE_APP_ID if debuggable else config['admob']['app_id']
    metadata = {'com.google.android.gms.ads.APPLICATION_ID': app_id,
                'com.google.android.gms.games.APP_ID': '@string/game_services_project_id',
                'org.godotengine.plugin.v2.GodotPlayGameServices': 'plugin',
                'org.godotengine.plugin.v2.PoingGodotAdMob': 'plugin'}
    flags = {'debuggable': str(debuggable).lower(), 'appCategory': 'game', 'isGame': 'true', 'allowBackup': 'false'}
    flags.update(app_flags or {})
    app = element('application', flags, [
        element('meta-data', {'name': key, 'value': value}) for key, value in metadata.items()])
    sdk = element('uses-sdk', {
        'minSdkVersion': integration.setting(options, 'gradle_build/min_sdk'),
        'targetSdkVersion': integration.setting(options, 'gradle_build/target_sdk')})
    return element('manifest', attrs, [sdk, app])


class ProductionPackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='mosslight-package-test-')
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.catalog = {'achievements': [{'id': 'achievement_' + str(i)} for i in range(20)],
                        'leaderboards': [{'id': 'board_' + str(i)} for i in range(4)]}
        self.config = {'schema_version': 1,
                       'admob': {'test_mode': False,
                                 'app_id': 'ca-app-pub-1234567890123456~1234567890',
                                 'banner_unit_id': 'ca-app-pub-1234567890123456/1234567891',
                                 'interstitial_unit_id': 'ca-app-pub-1234567890123456/1234567892',
                                 'rewarded_unit_id': 'ca-app-pub-1234567890123456/1234567893'},
                       'play_games': {'enabled': True, 'game_id': '123456789',
                                      'achievements': {item['id']: 'CgkAchievement' + str(i) for i, item in enumerate(self.catalog['achievements'])},
                                      'leaderboards': {item['id']: 'CgkBoard' + str(i) for i, item in enumerate(self.catalog['leaderboards'])}}}
        self.options = '\n'.join([
            'package/unique_name="com.ethannyakabuski.mosslightbastion"',
            'version/code=1', 'version/name="1.0.0"', 'package/app_category=2',
            'gradle_build/min_sdk="24"', 'gradle_build/target_sdk="36"',
            'godot_play_game_services/game_id="123456789"'])

    def source(self, config=None, project_id=None):
        (self.directory / 'platform').mkdir(exist_ok=True)
        (self.directory / 'game').mkdir(exist_ok=True)
        (self.directory / 'platform/config.json').write_text(json.dumps(config or self.config))
        (self.directory / 'game/catalog.json').write_text(json.dumps(self.catalog))
        (self.directory / 'project.godot').write_text('[admob]\ngeneral/android/app_id="' +
                                                   (project_id or self.config['admob']['app_id']) + '"\n')
        (self.directory / 'export_presets.cfg').write_text('[preset.0]\nname="Android"\n[preset.0.options]\n' + self.options)
        return self.directory

    def bundle(self, config=None, game_id=None, signed=False, debuggable=False, app_id=None, package=None,
               incomplete_signature=False, app_flags=None):
        config = config or self.config
        path = self.directory / 'fixture.aab'
        with zipfile.ZipFile(path, 'w') as archive:
            archive.writestr('BundleConfig.pb', b'')
            archive.writestr('base/manifest/AndroidManifest.xml', manifest(self.config, self.options, debuggable, app_id, package, app_flags))
            archive.writestr('base/resources.pb', resources(game_id or self.config['play_games']['game_id']))
            archive.writestr('assetPackInstallTime/assets/platform/config.json', json.dumps(config))
            archive.writestr('assetPackInstallTime/assets/game/catalog.json', json.dumps(self.catalog))
            if signed:
                archive.writestr('META-INF/TEST.RSA', b'fixture only')
                archive.writestr('META-INF/TEST.SF', b'fixture only')
            elif incomplete_signature:
                archive.writestr('META-INF/TEST.SF', b'fixture only')
        return path

    def test_source_configuration_requires_complete_exact_mappings_and_flags(self):
        config, catalog, _ = integration.source_configuration(self.source())
        self.assertEqual(config, self.config)
        self.assertEqual(catalog, self.catalog)
        variants = []
        for key, value in (('enabled', False), ('game_id', '0')):
            variant = copy.deepcopy(self.config)
            variant['play_games'][key] = value
            variants.append(variant)
        for key, value in (('test_mode', True), ('rewarded_unit_id', 'ca-app-pub-3940256099942544/5224354917')):
            variant = copy.deepcopy(self.config)
            variant['admob'][key] = value
            variants.append(variant)
        variant = copy.deepcopy(self.config)
        variant['play_games']['achievements'].pop('achievement_0')
        variants.append(variant)
        variant = copy.deepcopy(self.config)
        variant['play_games']['leaderboards']['board_0'] = variant['play_games']['achievements']['achievement_0']
        variants.append(variant)
        for variant in variants:
            with self.subTest(variant=variant), self.assertRaises(ValueError):
                integration.source_configuration(self.source(config=variant))
        with self.assertRaisesRegex(ValueError, 'Project manifest App ID'):
            integration.source_configuration(self.source(project_id=integration.SAMPLE_APP_ID))

    def test_unsigned_release_and_test_signed_debug(self):
        result = integration.check_bundle(self.bundle(), self.config, self.catalog, self.options, 'release')
        self.assertFalse(result['signed'])
        self.assertFalse(result['signature_cryptographically_verified'])
        result = integration.check_bundle(self.bundle(signed=True, debuggable=True), self.config, self.catalog, self.options, 'debug')
        self.assertTrue(result['signed'])
        self.assertFalse(result['signature_cryptographically_verified'])
        self.assertEqual(result['manifest_admob_app_id'], integration.SAMPLE_APP_ID)

    def test_variant_app_id_and_package_are_verified(self):
        for variant, kwargs in (('debug', {'signed': True, 'debuggable': True, 'app_id': self.config['admob']['app_id']}),
                                ('release', {'app_id': integration.SAMPLE_APP_ID}),
                                ('release', {'package': 'com.example.wrong'})):
            with self.subTest(variant=variant, kwargs=kwargs), self.assertRaises(ValueError):
                integration.check_bundle(self.bundle(**kwargs), self.config, self.catalog, self.options, variant)

    def test_debug_requires_matching_signature_files_and_debuggable_application(self):
        for kwargs in ({'debuggable': True}, {'debuggable': True, 'incomplete_signature': True}, {'signed': True}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                integration.check_bundle(self.bundle(**kwargs), self.config, self.catalog, self.options, 'debug')

    def test_mismatched_packaged_json_rejected(self):
        changed = copy.deepcopy(self.config)
        changed['admob']['rewarded_unit_id'] = 'ca-app-pub-3940256099942544/5224354917'
        with self.assertRaisesRegex(ValueError, 'Packaged JSON differs'):
            integration.check_bundle(self.bundle(config=changed), self.config, self.catalog, self.options, 'release')

    def test_pgs_resource_must_resolve_exactly(self):
        with self.assertRaisesRegex(ValueError, 'Resolved packaged PGS'):
            integration.check_bundle(self.bundle(game_id='12345'), self.config, self.catalog, self.options, 'release')

    def test_release_cannot_be_debuggable_or_signed(self):
        for kwargs in ({'debuggable': True}, {'signed': True}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                integration.check_bundle(self.bundle(**kwargs), self.config, self.catalog, self.options, 'release')

    def test_game_category_and_local_backup_flags_are_required(self):
        for flags in ({'appCategory': 'accessibility', 'isGame': 'false'}, {'isGame': 'false'}, {'allowBackup': 'true'}):
            with self.subTest(flags=flags), self.assertRaises(ValueError):
                integration.check_bundle(self.bundle(app_flags=flags), self.config, self.catalog, self.options, 'release')

    def test_malformed_protobuf_and_duplicate_json_rejected(self):
        for data in (b'\x0a\x05a', b'\x80', b'\x00'):
            with self.subTest(data=data), self.assertRaises(ValueError):
                integration.protobuf(data)
        with self.assertRaisesRegex(ValueError, 'Duplicate JSON key'):
            integration.read_json('{"test_mode":true,"test_mode":false}')

    def test_web_pck_reads_actual_directory_and_checksum(self):
        path = self.directory / 'web.pck'
        data = json.dumps(self.config).encode()
        name = b'res://platform/config.json\0'
        header_size = 112
        directory = struct.pack('<I', 1) + struct.pack('<I', len(name)) + name
        directory += struct.pack('<QQ16sI', 0, len(data), hashlib.md5(data).digest(), 0)
        header = struct.pack('<6IQQ', 0x43504447, 3, 4, 5, 1, 2, header_size, header_size + len(data))
        path.write_bytes(header.ljust(header_size, b'\0') + data + directory)
        self.assertEqual(integration.pck_json(path, 'platform/config.json'), self.config)
        damaged = bytearray(path.read_bytes())
        damaged[header_size] ^= 1
        path.write_bytes(damaged)
        with self.assertRaisesRegex(ValueError, 'checksum'):
            integration.pck_json(path, 'platform/config.json')


if __name__ == '__main__':
    unittest.main()
