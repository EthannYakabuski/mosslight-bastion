# Build and test

Use Godot 4.5.1 Compatibility and matching templates. Android is primary; Java 17
and the Android SDK are required. Current exports use min API 24/target API 35,
ARM64 plus x86 test support. Verify current release requirements separately.

Run these commands from the project root with isolated per-process application
data. Isolate both game saves and the Services pending store from real player data.

```sh
godot --headless --editor --path . --import
godot --headless --path . --script tests/strategy_check.gd
godot --headless --path . --script tests/test_core.gd
godot --headless --path . --script tests/test_round_five.gd
godot --headless --path . --script tests/test_retry_finalization.gd
godot --headless --path . --script tests/test_ui.gd
godot --headless --path . --script platform/tests/services_smoke.gd
```

Strategy generates `tests/evidence/strategy-witnesses.json`; core independently
replays it. Core/UI also write reports under `tests/evidence`, so review generated
diffs before committing. UI headless checks do not render native screenshots.
An actual Compatibility driver can produce designed desktop fixtures, which must
not be presented as real Android gameplay or native SDK proof.

For a new export, create a separate destination and preserve original local QA
artifacts. Install the Android build template before exporting with the Android
preset. Web uses single-threaded Compatibility, no native extensions and no
simulated native rewards. Keep notices beside redistributed artifacts. Do not
commit generated exports, keys, credentials, raw logs or real saves.

The workflow `.github/workflows/build-and-deploy.yml` pins Godot/templates, checks
imports and services, runs strategy/game tests under strict error gates, builds
Android debug and Web artifacts, and includes license notices. The published
baseline `6632ffd453ce2df2b882bba8a8772229210b300f` was verified on remote main on October 22, 2026 and passed
[run 39701092106](https://github.com/EthannYakabuski/mosslight-bastion/actions/runs/39701092106).
That is a dated result, not a claim about later edits. Hosted artifacts have not
received the original local APK's native QA. The deploy job remains `if: false`;
no live Pages site is established.

The dated Round Two section of `HANDOFF.txt` records runtime `9f84e66e63c354692a6b514a670a801fe7ab6b51` and its versioned Android/Web/package outputs; the current top entry separates later source status from historical artifact acceptance. It preserves the current unresolved Chromium queue diagnostic and separately dated original E9CF cache errors. Keep strict checks intact; do not suppress errors to produce a pass.
Production configuration, physical-device/audio/interactive-Web checks and human
acceptance remain separate. A documentation-only change does not require a new APK.

## Round Five acceptance

Run the strategy generator before independent replay and the natural-UI Retry
fixture; the committed witness file is synthetic model evidence. The solver
uses automatic scheduling and legal build/upgrade/Rally only at zero persistent
preparation, requiring one actually observed final boss and all authored waves
resolved for each of 100 wins. Core independently checks actions/accounting and
absence of queued/orphan enemies. Do not remove error gates or replace actual
native/device/reward/audio checks with fixture counts. See the current results
and remaining gates in `docs/ROUND_FIVE_UPDATE.md`.
