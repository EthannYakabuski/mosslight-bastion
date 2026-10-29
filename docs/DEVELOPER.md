# Developer continuation

Use the canonical `Apps/mosslight-bastion` working copy and inspect Git status and
origin before editing. Other saved folders are historical archives. Keep one
focused task per requested outcome; a new agent should read `AGENTS.md`,
`README.md`, `HANDOFF.txt`, `docs/BUILD_TEST.md` and `docs/PLATFORM_SETUP.md` rather
than assume it inherits earlier chats. State the desired update and supplied IDs.

`docs/ARCHITECTURE.md` maps the source. Simulation is in `game/simulation.gd`,
banked save validation in `game/progress.gd`, and run identity/result banking and
fullscreen entitlement in `game/session.gd`. `game/main.gd` connects UI and services.
`game/missions.json` supplies the authored campaign. `game/catalog.json` uses `id`
keys; keep the matching PGS maps in `platform/config.json` consistent.

For an ID-only change, follow `docs/PLATFORM_SETUP.md`, preserve symbolic keys,
check that every catalog ID has one mapping, and inspect the resulting Android
manifest/preset. Client IDs do not replace owner OAuth/signing/test-account setup.
For gameplay changes, run the relevant strategy/core/UI/service checks with
isolated application data and test the affected native behavior when needed.

Do not overwrite the original QA APK with a newly exported binary. Preserve its
hash and identify new artifacts separately. CI builds are separate from original
native QA. Keep private local artifacts and raw evidence outside public commits;
inspect tracked documentation as well as untracked paths. No runtime rebuild is
needed for a documentation-only update.

Keep all required notices with source and builds. Pages/Library actions remain outside this task; production services and Play
publication remain owner work. Do not claim physical/audio/Web/production/human acceptance from
source tests or hosted CI.

## Round Five model and content

`game/missions.json` contains 100 stable sequential mission IDs. Missions 1–60
retain their original names/routes/pads; their waves now satisfy the five-wave
minimum and final-boss requirement. `game/simulation.gd` schedules each wave from
its last spawn plus route travel allowance. A fully cleared wave shortens its
empty intermission; a slow remaining enemy does not indefinitely stop the next
scheduled wave. Per-wave live/queued counts include splitter children, so one
boss cannot award an early victory. Opening and intermission timers freeze under
Pause and fullscreen blocking. The optional Send now action uses the old `wave`
button registry key for compatibility.

`tests/strategy_check.gd` exercises all missions with legal builds/upgrades/Rally,
zero preparation and automatic wave timing. `tests/test_core.gd` independently
replays those witnesses. These are synthetic production-model checks; they do
not prove a human will find the game balanced or certify native SDK behavior.
`tests/test_round_five.gd` covers timing, overlap, splitter accounting, 100-mission
save compatibility, inclusive assisted records and actual texture-backed stars.

`unassisted_*` save and leaderboard identifiers are retained to avoid breaking
existing mapping/configuration. Their current values include genuine earned-ad-
assisted results. Do not restore the old exclusion based on their legacy names.
The internal assisted flag still limits repair to once per run. Entitlement must
still come from the real earned callback, and combat stays paused until Resume.
