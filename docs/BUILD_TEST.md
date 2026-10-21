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
baseline `90d304a426486aedb5ae1dcb061f64ce182be1f4` passed
[run 39527297049](https://github.com/EthannYakabuski/mosslight-bastion/actions/runs/39527297049).
That is a dated result, not a claim about later edits. Hosted artifacts have not
received the original local APK's native QA. The deploy job remains `if: false`;
no live Pages site is established.

`HANDOFF.txt` preserves actual native scope and unresolved Chromium cache
diagnostics. Keep strict checks intact; do not suppress errors to produce a pass.
Production configuration, physical-device/audio/interactive-Web checks and human
acceptance remain separate. A documentation-only change does not require a new APK.
