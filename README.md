# Mosslight Bastion

## Round Five source update

The campaign now spans **100 missions across 20 regions** with **five to ten
automatic waves per mission** and a boss in every final wave. Plan during the
opening countdown or use Send now to start sooner; later waves advance without
manual input. Twelve enemy roles use supplied animated monster sheets, including
slow goliath, sprinting hare and splitting broodroot bosses. Campaign and Results
show Kenney filled/empty star icons; Results reserves a bottom-banner safe area.
See [Round Five acceptance and verification](docs/ROUND_FIVE_UPDATE.md) and the
current status at the top of `HANDOFF.txt`. Earlier exports and screenshots keep
their original source provenance.

## Round 4 build continuation (2026-10-24)

The Android preset now defaults to **AAB** with Gradle, minimum API **24** and target API **35**. ARM64, x86 and x86_64 are selected; the [Round 4 Android guide](docs/ROUND_FOUR_ANDROID.md) explains the native ABI-pair validator and release-owner steps. These are current preset choices, not permanent engine restrictions.

Round Four public source `38f0e87b750a2c29a82e941e018c5de7e647c591` has [passing exact-commit hosted CI](https://github.com/EthannYakabuski/mosslight-bastion/actions/runs/40125532538); accepted debug AAB/Web exports are listed in `HANDOFF.txt`. Affected native acceptance remains pending. An ABI-validated debug AAB is test-signed and does not establish Google Play acceptance. Dated APK hashes and screenshots below retain their original build provenance. This round does not start new games.

Hold the lane. Keep the mosslight burning.

A portrait woodland defense game for Godot 4.5.1 Compatibility: one hundred authored
campaign missions across twenty regions, four complementary towers, twelve enemy roles,
Endless siege, date-seeded Daily defense, keeper progression, twenty achievements
and four record categories. Preparation and cosmetic lantern upgrades use coins
earned in ordinary play.

## Play

Open `project.godot` and run `main.tscn`. Tap a build pad and choose a pictured guardian at its shown supply cost.
The selected tower shows its range on the board. Upgrade or sell a selected tower, let timed waves arrive or tap Send now, and use
free Rally when enemies cluster. Android Back pauses combat; Resume continues and
Abandon returns Home without result credit. Ordinary retries are free. Campaign cards show wave count and enemy portraits and start the selected defense
directly. Retry and Next level also enter the defense directly. Cycle the speed
button through 1x, 2x, 3x and 4x; Pause freezes every speed. The keep has a visible
health meter and a distinct damage cue when enemies reach it.

The optional native earned repair is limited once per run. It leaves combat paused
through the fullscreen endcard until explicit Resume. Earned-ad-assisted runs qualify for the same
rewards, stars and competitive bests as ordinary runs. No reward is granted without
a genuine earned callback. Banked progress persists;
unfinished battles intentionally do not survive process death.

## Continue development

Use this game's canonical `Apps/mosslight-bastion` Git working copy as the single
development location. Preserved original folders retain local builds and private
QA history. A source-only clone does not contain those generated exports.

Start a focused Codex task for the desired update and have it read `AGENTS.md`,
`HANDOFF.txt`, [developer guidance](docs/DEVELOPER.md),
[build/test commands](docs/BUILD_TEST.md) and [service setup](docs/PLATFORM_SETUP.md).
Provide the requested behavior or owner console IDs explicitly; a new task should
not assume access to this project's prior conversation.

Android is primary. Web uses a single-threaded Compatibility export with graceful
native-service fallbacks. Matching Godot templates, Java 17 and Android SDK are
required for Android. The observed min API 24/target API 35 configuration does not
establish current Google Play release eligibility.

`game/catalog.json` defines achievement and leaderboard `id` values; matching
console IDs belong in `platform/config.json`. PGS is currently disabled with blank
IDs. AdMob uses Google's official sample IDs. Its manifest App ID must also be set
through Godot's `admob/general/android/app_id` Project Setting; changing only JSON
`app_id` is insufficient. `test_mode` changes status wording and does not convert
production ad unit IDs into test requests. See the platform guide before changing
IDs, consent settings or signing configuration.

## Preserved Round Two source status

The dated Round Two source contained 60 missions across twelve regions, Next Level, revised tower balance and centered Home. Illustrated app/feature art and all 20 achievement/4 leaderboard badges are integrated. See [the engineering update](docs/ROUND_TWO_UPDATE.md) for verification and continuity. Current Android/Web exports are accepted at runtime `9f84e66e63c354692a6b514a670a801fe7ab6b51` under `build/round-two-9f84e66e-a1/`. Current affected copy/controls/save and nine raw native emulator views are complete; critical combat/ad/offline evidence belongs to the qualified D890 predecessor. The broad native diagnostic gate remains false for one unresolved Chromium image-reader buffer-queue diagnostic. See HANDOFF for exact selectors and limitations.

## Verification and release

The current qualified local package is recorded in `HANDOFF.txt`, `docs/NATIVE_QA.json` and `docs/LOCAL_TEST_RESULTS.json`. Its broad native log gate remains false for one Chromium image-reader queue diagnostic with no observed visible failure and unresolved cause/impact. Original E9CF cache diagnostics and AVD install/data loss remain separate historical evidence. The old progressed backup was not merged with the later genuine fresh profile.

Public source: https://github.com/EthannYakabuski/mosslight-bastion

The public source baseline `6632ffd453ce2df2b882bba8a8772229210b300f` was verified on remote main on October 22, 2026 and passed
[exact-commit hosted build/test CI](https://github.com/EthannYakabuski/mosslight-bastion/actions/runs/39701092106). This dated result does not cover the subsequent screenshot/document changes until their own commit and CI run are verified.
That dated run built Android/Web artifacts; its binaries have not received the
original local APK's native QA. Documentation-only changes do not rebuild or
reverify that APK. Pages deployment remains disabled; no Library or Google Play
publication is implied.

Owner work includes production IDs/backend/signing, policy/contact/consent and
Data safety details, release requirements and Google Play submission. Physical
devices, audible Android output, interactive Web/audio/WebGL, production services
and human balance remain unverified. Emulator audio was disabled.

See `docs/DESIGN.md` and `docs/ARCHITECTURE.md` for gameplay and source structure.
Store copy/art is in `store/` and `marketing/`. `tests/evidence` contains synthetic
desktop fixtures; `marketing/screenshots-round-two` contains the nine current raw native emulator views; `marketing/screenshots` retains the original images/manifest. Preserve `LICENSE`, `NOTICE`, `LICENSES/` and `assets/SOURCE_MAP.json`.
Apache-2.0 covers original code/content/art/music; third-party terms remain intact.

## Round Three screenshot expansion

[The expanded native screenshot set](docs/SCREENSHOTS_ROUND_THREE.md) supplies six genuine views per phone/logical7/logical10 profile in `marketing/screenshots-round-three/`. It combines the nine unchanged accepted Round Two views with nine ordinary menu captures from the same exact APK. Runtime exports and the retained native diagnostic qualification are unchanged.

## Round Four gameplay update

The requested concise campaign/build UI, direct mission entry, four playback speeds,
new keep illustration, damage sound and health gauge are implemented. See
[Round Four source verification](docs/ROUND_FOUR_UPDATE.md). Existing qualified
native artifacts and screenshots remain historical evidence; they do not cover
these visual/runtime changes until the coordinator records a new native pass.
