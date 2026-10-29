# Round Five: timed woodland defenses

## Requested behavior and source changes

- Campaign grows from 60 to 100 missions across 20 regions. The original sixty
  IDs, names, routes and pads are preserved. The forty additional missions use
  eight authored base route plans with rotated/mirrored coordinate variants,
  legal build pads and individual wave definitions. These are forty distinct
  coordinate layouts, not forty symmetry-distinct route plans. Existing saves retain
  banked currency, progression, settings and service identifiers.
- Every mission has five to ten waves. Waves advance automatically, with an
  eight-second opening countdown. The next deadline includes the last spawn plus
  150% of ordinary route travel and four seconds; when all foes clear sooner,
  the empty intermission becomes at most six seconds. Send now remains optional.
  Pause and fullscreen blockers freeze these clocks.
- Every final wave has a boss: slow/high-health Honey goliath, sprinting
  Gravebone hare, or Witching broodroot that splits into four sporelings.
  Children remain part of their parent's wave and prevent premature victory.
- The existing fast runner moves 15% faster. Existing non-fast roles have 20%
  more health, within the requested 10–25% range. Three additional ordinary
  roles add frost-immune moths, splitting oozes and heavy armored bulwarks.
- Twelve enemy roles use eleven provided animated Creature Mixer sheets. Heavy,
  winged, skeletal and plant appearances map to their combat traits. Those
  assets use the supplied custom Creature Mixer terms, not CC0. Kenney UI stars
  retain the supplied UI pack's CC0 notice. See `assets/SOURCE_MAP.json` and
  `LICENSES/INDEX.txt` for provenance.
- Campaign cards and winning Results use actual filled/empty star textures.
  Results requests a bottom native banner and reserves safe space. Resizing or
  banner metrics may rebuild the view, but cannot bank the result again.
- Earned-ad-assisted results can set the same bests and stars as other runs;
  the warning is removed. Legacy `unassisted_*` save/backend identifiers remain
  compatible. Actual entitlement, once-per-run repair, stale-callback rejection,
  once-only result credit and explicit Resume after ads remain required.

## Verification status

Godot 4.5.1 local import and the complete isolated source suite passed on
2026-10-29 with zero script/parse/assertion, ObjectDB-leak or resource-in-use
diagnostics. The first feasibility pass cleared 94/100 missions; six dense new
dual-route mission schedules prompted a consistent opening ramp for the new
forty missions. Requested enemy buffs, all waves and bosses remained intact.

| Check | Final local result |
| --- | --- |
| Automatic-wave legal strategy solver | 100/100 wins, 100 actually observed bosses, 701 fully resolved waves; 58.11 s |
| Independent core replay/combat/save/earned-callback checks | 265/265 |
| Round Five content/timing/overlap/splitter/save/star/banner checks | 1,497/1,497 |
| Natural five-wave UI win, Retry, Next and once-only exact payouts | 124/124 |
| Prior Round Four scene/UI regressions | 975/975 |
| Prior Round Two model/save/balance regressions | 268/268 |
| Existing art/provenance checks | 60/60 |
| Existing UI scene/input checks | 25/25 |
| Paired/mouse UI dispatch regressions | 91/91 |
| Shared service fallback/menu geometry/once-only callbacks | Pass |

The UI replay identified a 150 ms action-eligibility lag after automatic-wave,
Rally and supply changes; control eligibility now refreshes each production
frame while labels remain throttled. Exact replay compares every scalar and the
complete key set because JSON numbers parse as floats; diagnostics confirmed
identical values rather than weakening result/payout assertions. Deferred banner
rebuilds are bound to the expected page and run so they cannot reopen Results
after navigation. Actual naturally simulated losses show three empty star
textures, respect changing banner reserves and cannot bank twice on rebuild.

Independent source review found no further blocking wave/traversal/splitter or
assisted-record defect. Five zero-preparation witnesses finish with one to four
hearts (missions 16, 21, 26, 53 and 87); this is a practical human-balance review
target. A legal automated win is not evidence of comfortable human difficulty.

These are local source/scene results. Hosted CI must be checked for the exact
published commit. No Round Five Android/Web binary, native banner/reward flow,
audible output, physical-device acceptance or changed-screen capture is selected
by this document. Preserve all earlier qualified exports with their dated
source/build provenance; they do not validate these changed scenes or mechanics.

The source solver uses legal build/upgrade/Rally actions at zero preparation. It
tests feasibility and deterministic accounting, not human difficulty, touch
comfort, audible output, real advertising, Play Games or physical devices.
Results-banner geometry is a scene fixture until verified on a native device.
Prior Android renderer failures and historical screenshot provenance remain
separate. Current changed combat, sprites, stars and Results require fresh
browser/native visual review; older captures cannot be relabelled as Round Five.

## Owner acceptance still required

Play the early tutorial arc, mixed dual-route missions and the final ten missions
with touch controls. Check automatic-wave pacing at all four speeds, each boss's
counterplay and splitting cleanup; review stars and Results with a real banner.
Verify real earned-only assistance and once-only records after dismissal and
relaunch. Test signed-in production services, audible music/effects and physical
devices with configured owner IDs. Preserve real saves during all checks.
