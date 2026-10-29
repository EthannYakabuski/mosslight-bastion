# Mosslight Bastion continuation

## Round 5 continuation

Continue the requested Round 5 update in this existing game. Read
`docs/ROUND_FIVE_UPDATE.md` for current acceptance criteria and test scope. The
campaign has 100 missions, five to ten timed waves per mission and a final-wave
boss. New scenes use the supplied Kenney UI stars and Creature Mixer sheets;
retain their distinct licence notices. Existing first-sixty mission identities,
routes, save keys, service IDs and production callback protections must remain
compatible. Earned-ad-assisted scores and stars now qualify for ordinary records;
the legacy `unassisted_*` identifiers remain only for save/backend compatibility.

The Android default is Gradle **AAB**, min API **24** / target API **35**, with
ARM64, x86 and x86_64. Follow `docs/ROUND_FOUR_ANDROID.md` for exports. Prior dated
APKs, screenshots and qualified Round Four exports do not validate changed Round
Five source. Preserve original evidence, real saves, owner edits and untracked
artwork. Source tests, exported binaries, browser checks and native/physical
acceptance must be recorded separately; a debug AAB is not a production release.

Work in this game's canonical `Apps/mosslight-bastion` Git working copy. Earlier
publication copies and preserved original folders are archives, not parallel
development locations. A new task must read this file, `README.md`, `HANDOFF.txt`,
`docs/DEVELOPER.md`, `docs/BUILD_TEST.md` and `docs/PLATFORM_SETUP.md`; do not assume
it inherits another chat. Inspect Git status, origin and the requested change
before editing. Preserve user edits.

- Use Godot 4.5.1 Compatibility. Android is primary; Web is single-threaded.
  Current preset min API 24/target API 35 does not establish Play eligibility.
- Service IDs: definitions use `id` in `game/catalog.json`; put console IDs in
  the matching `platform/config.json` maps. The numeric PGS game ID also belongs
  in Android `export_presets.cfg` at `godot_play_game_services/game_id`.
- AdMob's manifest App ID comes from the Godot setting
  `admob/general/android/app_id`, serialized in `project.godot`. JSON `app_id` is
  reference data. `test_mode` changes wording only; real ad unit IDs remain real
  requests. Use official sample IDs or explicitly configured test devices.
- Run tests with isolated application data, including the shared Services store.
  Strategy/core/UI tests generate `tests/evidence` files; review any resulting
  diff. Synthetic fixtures do not establish native gameplay or ad acceptance.
- Keep simulation paused through fullscreen dismissal and require explicit Resume;
  earned callbacks grant entitlement only. Preserve Results/Retry result banking,
  once-only claims. Earned assistance qualifies for the same competitive records;
  never fabricate an earned callback or replay a claim.
- Preserve original local QA APKs, saves and private evidence. Keep build outputs,
  signing material, credentials, raw logs and private notes out of commits. Review
  tracked QA documents too: ignore rules do not protect already tracked paths.
- Retain `LICENSE`, `NOTICE` and all `LICENSES/` notices. Original code's Apache-2.0
  does not relicense third-party assets or plugins.
- Complete only the requested game update; do not start new games.
  Do not activate Pages/Library, publish to Google Play or change security settings.
  Production IDs/backend/signing, physical/audio/Web interaction and human balance
  acceptance remain owner setup or unverified tests as recorded in `HANDOFF.txt`.
