# Platform setup

## Current Round 4 Android export

The preset currently uses minimum API **24** / target API **35**, Gradle **AAB**, and ARM64, x86 and x86_64. These settings are configurable choices, not a fixed Godot target-SDK limit. Follow the [Round 4 Android guide](ROUND_FOUR_ANDROID.md); create a new unused output directory, export a debug `.aab`, then run `tools/verify_android_bundle.py` on the actual bundle.

The debug AAB is test-signed; release signing stays with the owner outside Git. ABI validation alone does not establish native gameplay, production services or Google Play acceptance. Public Round Four source `38f0e87b750a2c29a82e941e018c5de7e647c591` has [passing exact-commit hosted CI](https://github.com/EthannYakabuski/mosslight-bastion/actions/runs/40125532538). Affected native acceptance remains pending; see the current qualified export/browser scope in `../HANDOFF.txt`. The AAB/Web/package retain their recorded as-built source identities and bytes. Preserve historical APK/native QA identities; no new-game work is authorized by this continuation.

Use Godot 4.5.1 Compatibility and matching export templates. Android is primary;
single-threaded Web keeps native-service fallbacks. Android requires Java 17 and
the SDK/Gradle environment described by the workflow. The actual presets use
min API 24/target API 35 and ARM64, x86 and x86_64 support. These values describe the
tested engine configuration, not current Google Play release eligibility.

## Play Games IDs

`game/catalog.json` contains twenty achievement definitions and four leaderboard
definitions using `id` values. `platform/config.json` has matching symbolic keys:

- `play_games.achievements`: assign each key its owner-created Console achievement ID.
- `play_games.leaderboards`: assign each key its owner-created Console leaderboard ID.
- `play_games.game_id`: assign the numeric Play Games game ID.
- Android `export_presets.cfg`, `godot_play_game_services/game_id`: set the same
  numeric game ID instead of the placeholder `"0"`.

Keep `play_games.enabled` false until the owner has configured the Android package,
OAuth/app linkage, signing fingerprints and test access, and the mappings are
complete. Its current game ID and all mappings are blank. The Android package is
`com.ethannyakabuski.mosslightbastion`. Game ID and achievement/leaderboard IDs are
client identifiers; never commit private signing keys, OAuth secrets, service
accounts or backend credentials. Verify sign-in, one real unlock and a score with
the owner's test account before claiming production integration.

## AdMob IDs and test requests

`platform/config.json` supplies `admob.banner_unit_id`, `interstitial_unit_id` and
`rewarded_unit_id`. Current values are Google's official Android sample units.
The Services adapter passes these configured strings directly to native ad APIs.
`admob.test_mode` only changes the status message; setting it true does not replace
production IDs or configure test devices. Keep official sample IDs for development,
or deliberately configure an approved SDK test device before using owner unit IDs.

The Android manifest App ID is a separate exporter input: set Godot Project
Settings `admob/general/android/app_id`, which is serialized in `project.godot`
under `[admob]` as `general/android/app_id`. The current project has no override,
so the vendored plugin uses its official sample App ID. JSON `admob.app_id` is
reference data and is not read by the game/platform scripts; editing it alone
does not change the exported manifest. When configuring the owner App ID, update
the reference consistently and verify the actual exported manifest.

Consent, audience/under-age settings, privacy policy and Data safety must match
the owner's real configuration. Unavailable consent/native services leave local
play available. Web/offline paths never simulate native reward entitlement.

## Reward lifecycle and verification

Fullscreen activity and earned entitlement are separate. Freeze simulation while
the request, native fullscreen content or application suspension blocks play.
An earned callback can grant one repair but cannot dismiss the ad or resume combat.
Explicit Resume is required after return; keep stale callbacks from affecting a
new battle. Natural completed rounds alone advance interstitial cadence.

Headless fixtures test code paths, not SDK acceptance. Dated per-binary native QA and unresolved diagnostics are in `HANDOFF.txt` and `docs/NATIVE_QA.json`; original E9CF cache errors and current Chromium queue diagnostics are separate. Preserve
original local packages and real saves. Tests must isolate application data,
including `user://platform_pending_v1.json`, from the player's real data.

The owner handles production IDs/backend/signing, release requirements and Google
Play publication. Physical-device, audible-output, interactive Web and real-service
verification are still needed. Live Pages/Library activation is outside this
continuation task; leave the existing held configuration unchanged.

## Daily leaderboard reset policy

For `unassisted_daily_score`, configure a suitable daily reset/period policy in the owner backend or leaderboard service and verify it with owner test accounts. Client labels and submissions do not configure the service policy. Keep this setup guidance outside player-facing collection descriptions.

## Round Five record compatibility

Keep existing leaderboard mapping keys `unassisted_endless_score`,
`unassisted_daily_score`, `unassisted_stars` and `player_level`. The first three
retain their legacy identifiers for compatibility; their current values include
genuine earned-ad-assisted results, just as other banked results. Display names
and descriptions are in `game/catalog.json`. Repair still requires an actual
earned callback and grants at most once per run; this record rule does not
enable simulated Web rewards or configure production sign-in/backend policy.
