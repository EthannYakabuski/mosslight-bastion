# Round Four gameplay update

## Changes

- Campaign cards start a defense immediately. Each card shows its authored wave
  count, supply budget and the actual enemy-type portraits. Locked missions remain
  locked. Daily, Endless, Retry and Next level also enter their defense directly;
  the separate level-details page is removed.
- Build choices show the same guardian sprites as the board, with name and cost.
  Range remains visible around a selected placed tower; it is removed from the
  build-button text. Home and battle copy are shorter.
- Speed cycles 1x, 2x, 3x, 4x. Each multiplier advances the existing deterministic
  simulator in ordinary bounded steps. It changes playback, not enemy/tower stats,
  result rewards or authored strategy. Pause and native fullscreen lifecycle rules
  continue to block every speed.
- A new original transparent woodland-keep illustration replaces the rectangular
  keep and appears on Home. Its unchanged generated PNG and prompt/provenance are
  in `assets/keep/`. Tower/enemy sprites remain the supplied Kenney atlas art.
- The keep has a proportional health gauge, exact numeric value and low-health
  tint. Real enemy leaks emit a damage event which updates the meter, briefly
  flashes the keep and plays a dedicated Kenney wood-impact cue when SFX is on.
  The copied sound and CC0 notice are recorded in `assets/SOURCE_MAP.json`.

## Verification scope

`tests/test_round_four_ui.gd` uses the real desktop Viewport and paired pointer
events with isolated progress and an explicitly named fake service adapter. It
checks all 60 campaign cards, truthful wave/enemy details and locks, one direct
run per click, guardian portraits, three portrait layout profiles, all four speed
ratios and pause behavior. An ordinary unbuilt wave produces a real simulated
enemy leak; the test checks exact health loss, the damage event, meter and flash.
It never edits terminal results or grants a synthetic earned reward.

Existing actual-input UI and Retry/Next regressions are updated for the requested
direct-entry flow. The campaign model, all 60 strategy witnesses, banked save
format, tower/enemy balance and service entitlement logic are preserved.

These are source fixtures, not genuine native screenshots, Android audible-output
proof, physical-device playtesting, production SDK acceptance or human balance
acceptance. Native/runtime export and hosted-CI results belong to the coordinator's
dated delivery receipt. Original qualified APKs, genuine saves and prior evidence
remain separate and unchanged. Significant Home/campaign/build/health visuals need
fresh native captures; old mission-briefing screenshots are historical only.

The focused source fixture passed 615 checks. The actual desktop Compatibility
visual fixture passed 625 checks with ten private development views; phone Home,
campaign, build choices and the natural-leak meter plus tablet build layouts were
visually inspected. The broader regression pass included all 60 strategy witnesses,
125 core, 25 UI, 91 paired dispatch, 96 natural Retry/Next, 268 Round Two, 60 badge
checks and services. These counts describe isolated source fixtures only. No strict
Godot diagnostics were reported by these runs.
