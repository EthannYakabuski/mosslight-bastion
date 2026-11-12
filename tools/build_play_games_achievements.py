#!/usr/bin/env python3
"""Build and independently validate this game's Play Games achievement import."""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import struct
import zipfile
import zlib

CONFIG = {'slug': 'mosslight-bastion', 'title': 'Mosslight Bastion', 'points': {'first_wall': 10, 'five_walls': 20, 'ten_walls': 30, 'twenty_walls': 50, 'all_walls': 75, 'stars_15': 20, 'stars_45': 40, 'stars_90': 75, 'kills_25': 10, 'kills_250': 35, 'kills_1000': 75, 'built_20': 25, 'upgrades_20': 25, 'rally_10': 20, 'level_3': 20, 'level_6': 40, 'level_10': 75, 'endless_5': 30, 'daily_3': 30, 'streak_7': 50}, 'copy_note': "Eleven descriptions insert a missing space between a word and a number, such as 'Defeat25' to 'Defeat 25'. Original catalog copy remains in the worksheet. The original 30-mission achievement is preserved even though the current campaign has 100 missions. Runtime catalog and symbolic IDs are unchanged."}
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "marketing" / "play-games-achievements"
OFFICIAL = "https://developer.android.com/games/pgs/integrate-achievements#zip-file-guidelines"

def require(condition, message):
    if not condition:
        raise ValueError(message)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def csv_bytes(rows):
    out = io.StringIO(newline="")
    csv.writer(out, lineterminator="\r\n").writerows(rows)
    return out.getvalue().encode("utf-8")

def check_png(data):
    require(data[:8] == b"\x89PNG\r\n\x1a\n", "Invalid PNG signature")
    require(struct.unpack(">II", data[16:24]) == (512, 512), "Icon must be 512 by 512")
    offset = 8
    ended = False
    while offset < len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        chunk = data[offset + 8:offset + 8 + length]
        expected = struct.unpack(">I", data[offset + 8 + length:offset + 12 + length])[0]
        require(zlib.crc32(kind + chunk) & 0xffffffff == expected, "PNG chunk CRC mismatch")
        offset += length + 12
        if kind == b"IEND":
            ended = True
            break
    require(ended and offset == len(data), "Invalid PNG end")

def validate_archive(payload, expected_rows, icons):
    require(len(payload) < 800_000_000, "ZIP exceeds size limit")
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        require(archive.testzip() is None, "Archive CRC failure")
        names = archive.namelist()
        require(len(names) == len(set(names)) <= 403, "Duplicate names or too many files")
        require(set(names) == {"AchievementsMetadata.csv", "AchievementsIconsMappings.csv"} | set(icons), "Unexpected ZIP files")
        for info in archive.infolist():
            require(not info.is_dir() and "/" not in info.filename and "\\" not in info.filename, "Non-flat ZIP")
            require(info.file_size < 1_000_000, "Member exceeds conservative 1 MB limit")
            require(Path(info.filename).suffix.lower() in {".csv", ".png", ".jpg", ".jpeg"}, "Unsupported member")
        rows = list(csv.reader(io.StringIO(archive.read("AchievementsMetadata.csv").decode("utf-8"))))
        require(rows == [[str(value) for value in row] for row in expected_rows], "Metadata mismatch")
        require(len({row[0] for row in rows}) == len(rows), "Duplicate achievement names")
        for row in rows:
            require(len(row) == 7 and 0 < len(row[0]) <= 100 and len(row[1]) <= 500, "Invalid metadata columns")
            require(all("," not in value and "\n" not in value and "\r" not in value for value in row[:2]), "Invalid name/description")
            require(row[2:5] == ["False", "", "Revealed"], "Standard/revealed contract mismatch")
            require(5 <= int(row[5]) <= 200 and int(row[5]) % 5 == 0 and int(row[6]) > 0, "Invalid points/order")
        require(sum(int(row[5]) for row in rows) <= 2000, "Total points exceed allowance")
        mappings = list(csv.reader(io.StringIO(archive.read("AchievementsIconsMappings.csv").decode("utf-8"))))
        require(mappings == [[row[0], filename] for row, filename in zip(rows, icons)], "Icon mapping mismatch")
        for filename, original in icons.items():
            data = archive.read(filename)
            require(data == original, "Icon differs from original catalog asset")
            check_png(data)
    return {"status": "PASS", "achievement_count": len(rows), "file_count": len(names),
            "points_total": sum(int(row[5]) for row in rows), "zip_bytes": len(payload),
            "zip_sha256": sha(payload), "checks": [
            "Exact CSV names; no headers; seven metadata columns; two icon-map columns",
            "Unique flat member names; allowed extensions; conservative size limits",
            "Unique names; valid lengths; no commas in names or descriptions",
            "Standard unlock type; blank steps; Revealed state; valid points and order",
            "All catalog achievements mapped exactly once; all PNGs 512x512",
            "ZIP CRC; PNG chunk CRC; archived icon bytes equal original source icons"]}

def outputs():
    raw = (ROOT / "game/catalog.json").read_bytes()
    achievements = json.loads(raw)["achievements"]
    keys = [item.get("key", item.get("id")) for item in achievements]
    require(set(keys) == set(CONFIG["points"]) and len(keys) == len(set(keys)), "Point map/catalog keys differ")
    services = (ROOT / "platform/services.gd").read_text(encoding="utf-8-sig")
    require("_achievements_client.unlock_achievement(remote_id)" in services, "Review achievement adapter type")
    require(not re.search(r"_achievements_client\.(increment_achievement|set_achievement_steps)\(", services), "Incremental adapter requires review")
    rows, worksheet, icons, sources, edits = [], [], {}, [], []
    for order, item in enumerate(achievements, 1):
        key = item.get("key", item.get("id"))
        original_name, original_description = item["name"], item["description"]
        name, description = original_name, original_description
        if CONFIG["slug"] == "dewdrop-plot" and key == "dew_twins":
            require(name == "Two wells, one garden", "Review title override")
            name = "Two wells - one garden"
        if CONFIG["slug"] == "mosslight-bastion":
            description = re.sub(r"(?<=[A-Za-z])(?=\d)", " ", description)
        if (name, description) != (original_name, original_description):
            edits.append({"key": key, "original_name": original_name, "import_name": name,
                          "original_description": original_description, "import_description": description})
        icon_path = item["icon"].removeprefix("res://")
        path = ROOT / icon_path
        data = path.read_bytes()
        check_png(data)
        require(path.name not in icons, "Duplicate icon filename")
        icons[path.name] = data
        points = CONFIG["points"][key]
        row = [name, description, "False", "", "Revealed", points, order]
        rows.append(row)
        worksheet.append([key, original_name, name, original_description, description, "False", "", "Revealed", points, order, path.name, ""])
        sources.append({"key": key, "path": icon_path, "bytes": len(data), "sha256": sha(data)})
    members = {
        "AchievementsMetadata.csv": csv_bytes(rows),
        "AchievementsIconsMappings.csv": csv_bytes([[row[0], icon] for row, icon in zip(rows, icons)]),
        **icons,
    }
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for filename, data in members.items():
            info = zipfile.ZipInfo(filename, (2026, 11, 12, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, data, compresslevel=9)
    payload = buffer.getvalue()
    report = validate_archive(payload, rows, icons)
    report.update({"catalog_path": "game/catalog.json", "catalog_sha256": sha(raw),
                   "source_icons": sources, "import_only_copy_edits": edits, "official_schema": OFFICIAL,
                   "assumptions": ["English default locale", "All achievements initially Revealed",
                                   "Point values selected for this package; not specified by catalog"],
                   "limits": ["Not uploaded to Play Console", "No runtime or service configuration changed",
                              "No new Android/device acceptance claimed"]})
    zipname = CONFIG["slug"] + "-achievements-google-play.zip"
    header = ["CatalogKey", "OriginalName", "ImportName", "OriginalDescription", "ImportDescription",
              "IncrementalValue", "StepsNeeded", "InitialState", "Points", "ListOrder", "IconFilename", "PlayGamesAchievementId"]
    readme = f"""{CONFIG['title']}: Google Play Games achievement import
Prepared 2026-11-12 from the current game/catalog.json and original catalog icons.

Upload ONLY {zipname}.
It contains AchievementsMetadata.csv, AchievementsIconsMappings.csv and
{len(rows)} PNG icons directly at the root. CSVs have no header rows.
The worksheet, this README and validation report are NOT inside the import ZIP.

PACKAGE CHOICES
All {len(rows)} achievements are Standard (Incremental Value False; blank steps).
The current adapter calls unlock_achievement after local thresholds are met.
Count-based local progress does not make these Play Games incremental achievements.
All initial states are Revealed. Point values range from
{min(CONFIG['points'].values())} to {max(CONFIG['points'].values())}, totaling {report['points_total']}.
Points and initial states are package choices, not catalog settings.
Review these choices before publication; published types/states cannot be changed.
Catalog order and original PNG bytes are preserved.

COPY ADJUSTMENTS
{CONFIG['copy_note']}

DEFAULT LANGUAGE
English metadata provides the default locale. Confirm the game's default locale
is the intended English locale. No extra translations are invented.
AchievementsLocalizations.csv is optional and must not repeat the default locale.

IMPORT AND ID MAPPING
1. Select this game in Play Console > Play Games Services > Achievements.
2. Choose Import achievements and upload only the named ZIP.
3. Review all names, descriptions, icons, points and states; save as draft.
4. Use achievement-id-mapping-and-points.csv to match generated achievement IDs
   by ImportName and unchanged CatalogKey, then fill the corresponding values in
   platform/config.json. Backend mappings are not created by this ZIP.
5. Follow docs/PLATFORM_SETUP.md for game ID, Android linkage and testing.
Check existing Console achievements for duplicates before importing.
This package has not been reconciled against Console contents or uploaded.
It does not publish achievements, change service settings or rebuild the game.

VALIDATION AND REBUILD
python tools/build_play_games_achievements.py
python tools/build_play_games_achievements.py --check
The first command rebuilds this package from current source icons and catalog.
The second independently validates the archive and verifies generated files.
validation-report.json records schema, CRC, dimension, mapping and hash checks.
Keep .gdignore so import assets do not enter Godot resource scanning.

OFFICIAL SOURCES
{OFFICIAL}
https://developer.android.com/games/pgs/achievements#points_and_experience_points
"""
    return {zipname: payload, ".gdignore": b"",
            "achievement-id-mapping-and-points.csv": csv_bytes([header] + worksheet),
            "validation-report.json": (json.dumps(report, indent=2) + "\n").encode("utf-8"),
            "README.txt": readme.encode("utf-8")}, report

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check without writing files")
    args = parser.parse_args()
    files, report = outputs()
    if args.check:
        for filename, expected in files.items():
            path = DEST / filename
            require(path.is_file() and path.read_bytes() == expected, "Generated file mismatch: " + filename)
    else:
        DEST.mkdir(parents=True, exist_ok=True)
        for filename, data in files.items():
            (DEST / filename).write_bytes(data)
    print(json.dumps({key: report[key] for key in ("status", "achievement_count", "file_count", "points_total", "zip_bytes", "zip_sha256")}))
if __name__ == "__main__":
    main()
