# Mosslight Bastion

Hold the lane. Keep the mosslight burning.

A portrait woodland defense game for Godot 4.5.1 Compatibility: thirty authored
campaign missions across six regions, four complementary towers, six enemy roles,
Endless siege, date-seeded Daily defense, keeper progression, twenty achievements
and four record categories. Preparation and cosmetic lantern upgrades use coins
earned in ordinary play.

## Play

Open `project.godot` and run `main.tscn`. Tap a build pad and inspect price/range
before choosing a tower. Upgrade or sell a selected tower, call Next wave and use
free Rally when enemies cluster. Android Back pauses combat; Resume continues and
Abandon returns Home without result credit. Ordinary retries are free.

The optional native earned repair is limited once per run. It leaves combat paused
through the fullscreen endcard until explicit Resume. Assisted runs keep ordinary
rewards and cannot replace unassisted competitive bests. Banked progress persists;
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

## Verification and release

The original local QA APK and actual native qualifications are recorded in
`HANDOFF.txt`, `docs/NATIVE_QA.json` and `docs/LOCAL_TEST_RESULTS.json`. The original
read-only emulator session lost its install/data at host exit; separate fresh-profile
offline testing does not establish retention across that loss. The final broad
native diagnostic gate remains false for unresolved Chromium cache diagnostics.

Public source: https://github.com/EthannYakabuski/mosslight-bastion

The published baseline `90d304a426486aedb5ae1dcb061f64ce182be1f4` passed
[hosted build/test CI](https://github.com/EthannYakabuski/mosslight-bastion/actions/runs/39527297049).
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
desktop fixtures; `marketing/screenshots` contains separately reviewed native
captures. Preserve `LICENSE`, `NOTICE`, `LICENSES/` and `assets/SOURCE_MAP.json`.
Apache-2.0 covers original code/content/art/music; third-party terms remain intact.
