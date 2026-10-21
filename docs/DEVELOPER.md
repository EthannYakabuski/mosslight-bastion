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

Keep all required notices with source and builds. The ten-game cap, held Pages/
Library actions and owner responsibility for production services/Play publication
remain unchanged. Do not claim physical/audio/Web/production/human acceptance from
source tests or hosted CI.
