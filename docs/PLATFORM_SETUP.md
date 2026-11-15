# Platform setup

## Current production Android export

The preset uses minimum API **24** / target API **36**, Gradle **AAB**, and ARM64,
x86 and x86_64. API 36 supersedes the dated Round Four API 35 default for current
production preparation. [Google's current phone-app requirement](https://developer.android.com/google/play/requirements/target-sdk)
requires API 36 for new apps/updates from August 31, 2026. This is not complete
Play eligibility. Follow the [Android export guide](ROUND_FOUR_ANDROID.md);
inspect the actual bundle with both verification tools and independent jarsigner.
The Android category is Game (`package/app_category=2` in Godot 4.5.1), not
index 0/Accessibility. The package checker also validates `isGame=true` and
`allowBackup=false` in the actual manifest.

The debug AAB is test-signed; release signing stays with the owner outside Git. ABI validation alone does not establish native gameplay, production services or Google Play acceptance. Public Round Four source `38f0e87b750a2c29a82e941e018c5de7e647c591` has [passing exact-commit hosted CI](https://github.com/EthannYakabuski/mosslight-bastion/actions/runs/40125532538). Affected native acceptance remains pending; see the current qualified export/browser scope in `../HANDOFF.txt`. The AAB/Web/package retain their recorded as-built source identities and bytes. Preserve historical APK/native QA identities; no new-game work is authorized by this continuation.

Use Godot 4.5.1 Compatibility and matching export templates. Android is primary;
single-threaded Web keeps native-service fallbacks. Android requires Java 17 and
the SDK/Gradle environment described by the workflow. The actual presets use
min API 24/target API 36 and ARM64, x86 and x86_64 support. These values describe the
tested engine configuration, not current Google Play release eligibility.

## Play Games IDs

`game/catalog.json` contains twenty achievement definitions and four leaderboard
definitions using `id` values. `platform/config.json` has matching symbolic keys:

- `play_games.achievements`: assign each key its owner-created Console achievement ID.
- `play_games.leaderboards`: assign each key its owner-created Console leaderboard ID.
- `play_games.game_id`: assign the numeric Play Games game ID.
- Android `export_presets.cfg`, `godot_play_game_services/game_id`: set the same
  numeric game ID instead of the placeholder `"0"`.

The owner has set `play_games.enabled=true` and supplied the numeric game ID,
twenty achievement IDs and four leaderboard IDs. The Android preset matches.
OAuth/app linkage, signing fingerprints and test access still require owner
verification. The Android package is
`com.ethannyakabuski.mosslightbastion`. Game ID and achievement/leaderboard IDs are
client identifiers; never commit private signing keys, OAuth secrets, service
accounts or backend credentials. Verify sign-in, one real unlock and a score with
the owner's test account before claiming production integration.

## AdMob IDs and test requests

`platform/config.json` supplies `admob.banner_unit_id`, `interstitial_unit_id` and
`rewarded_unit_id`. The owner supplied production values with `test_mode=false`.
The Services adapter always substitutes Google's official sample units in debug
and editor builds. Release builds use owner units only when `test_mode=false`;
`true` or a missing flag selects samples. This does not register test devices.
Use sample requests for testing; do not execute a production-ad release in QA.

The Android manifest App ID is a separate exporter input: set Godot Project
Settings `admob/general/android/app_id`, which is serialized in `project.godot`
under `[admob]` as `general/android/app_id`. It now matches the production JSON
App ID. The vendored Android exporter substitutes the sample App ID for debug
exports and retains the configured owner App ID for release. JSON `admob.app_id`
is reference data; changing it alone does not change the exported manifest.
Verify both actual manifest variants with `tools/verify_production_integration.py`.

Consent, audience/under-age settings, privacy policy and Data safety must match
the owner's real configuration. Unavailable consent/native services leave local
play available. Privacy refresh invalidates cached ads and stale load callbacks;
an active fullscreen lifecycle and earned-only entitlement remain independent.
Web/offline paths never simulate native reward entitlement. Audience settings
remain the owner's responsibility; the configured under-age-of-consent flag is
false and no child-directed targeting override is set. See
[data practices](PRODUCTION_DATA_PRACTICES.md) for SDK and policy details.

## Reward lifecycle and verification

Fullscreen activity and earned entitlement are separate. Freeze simulation while
the request, native fullscreen content or application suspension blocks play.
An earned callback can grant one repair but cannot dismiss the ad or resume combat.
Explicit Resume is required after return; keep stale callbacks from affecting a
new battle. Natural completed rounds alone advance interstitial cadence.

Headless fixtures test code paths, not SDK acceptance. Dated per-binary native QA and unresolved diagnostics are in `HANDOFF.txt` and `docs/NATIVE_QA.json`; original E9CF cache errors and current Chromium queue diagnostics are separate. Preserve
original local packages and real saves. Tests must isolate application data,
including `user://platform_pending_v1.json`, from the player's real data.

The owner handles production OAuth/service-console setup, signing, release requirements and Google
Play publication. Physical-device, audible-output, interactive Web and real-service
verification are still needed. This repository's Pages deployment is separately authorized; see `WEB_PAGES.md`. Library activation remains outside scope.

## Daily leaderboard reset policy

`unassisted_daily_score` is the current UTC-date puzzle's best integer score.
The queue records that date and never retries an older or undated Daily score
as today's puzzle. Legacy undated values are retained locally, without upload;
the banked local profile supplies the authoritative current-date value.

Google's native daily leaderboard resets at UTC-7 year-round; weekly/all-time
views also exist automatically. That window does not match this game's UTC
puzzle day, and an arbitrary daily reset is not a Console setting. The adapter
cannot submit a past date or make the native UI a strict same-puzzle ranking.
Owner acceptance must review this mismatch; strict UTC per-puzzle competition
needs an additional backend/period design outside these existing four IDs.
See [Google's leaderboard documentation](https://developer.android.com/games/pgs/leaderboards).

## Score units and queued progress

All four boards require **Number, zero decimal places, larger is better**:

| Existing mapping key | Submitted value |
| --- | --- |
| `unassisted_endless_score` | Best Endless points |
| `unassisted_daily_score` | Current UTC-date Daily puzzle points |
| `unassisted_stars` | Total banked campaign stars |
| `player_level` | Integer keeper level |

No board receives elapsed time or milliseconds. Owner Console format/order,
limits and achievement type still require verification; client mappings cannot
inspect those settings. All twenty achievements use ordinary unlock calls.

Startup synchronizes the banked profile, including saves from before service
configuration. Services preserve desired unlocks/best scores in
`user://platform_pending_v1.json`, recovering valid `.bak`/`.tmp` records.
Uploads coalesce, acknowledge captured values and retry noninteractively on
resume or a bounded 30-second cadence. Missing callbacks cannot acknowledge a
newer score; failed/offline uploads leave the game save untouched. Auth and
callback fixtures use synthetic clients, never owner accounts or actual SDK
requests. Device-earned records are local to the installation and may be sent
to the Google player who signs in; this does not provide cloud saves.

## Round Five record compatibility

Keep existing leaderboard mapping keys `unassisted_endless_score`,
`unassisted_daily_score`, `unassisted_stars` and `player_level`. The first three
retain their legacy identifiers for compatibility; their current values include
genuine earned-ad-assisted results, just as other banked results. Display names
and descriptions are in `game/catalog.json`. Repair still requires an actual
earned callback and grants at most once per run; this record rule does not
enable simulated Web rewards or configure production sign-in/backend policy.

## Web deployment

See [GitHub Pages and iframe guidance](WEB_PAGES.md) for this repository's
main-branch Web publishing. Native services and real Android/device/backend
acceptance remain separate; Web never simulates a successful native ad.
