Mosslight Bastion: Google Play Games achievement import
Prepared 2026-11-12 from the current game/catalog.json and original catalog icons.

Upload ONLY mosslight-bastion-achievements-google-play.zip.
It contains AchievementsMetadata.csv, AchievementsIconsMappings.csv and
20 PNG icons directly at the root. CSVs have no header rows.
The worksheet, this README and validation report are NOT inside the import ZIP.

PACKAGE CHOICES
All 20 achievements are Standard (Incremental Value False; blank steps).
The current adapter calls unlock_achievement after local thresholds are met.
Count-based local progress does not make these Play Games incremental achievements.
All initial states are Revealed. Point values range from
10 to 75, totaling 755.
Points and initial states are package choices, not catalog settings.
Review these choices before publication; published types/states cannot be changed.
Catalog order and original PNG bytes are preserved.

COPY ADJUSTMENTS
Eleven descriptions insert a missing space between a word and a number, such as 'Defeat25' to 'Defeat 25'. Original catalog copy remains in the worksheet. The original 30-mission achievement is preserved even though the current campaign has 100 missions. Runtime catalog and symbolic IDs are unchanged.

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
https://developer.android.com/games/pgs/integrate-achievements#zip-file-guidelines
https://developer.android.com/games/pgs/achievements#points_and_experience_points
