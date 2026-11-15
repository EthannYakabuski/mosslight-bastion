# Production preparation — 2026-11-15

The owner subsequently authorized committing and pushing this configuration and
integration, and monitoring the exact-commit CI. The leaderboard UTC timing is
explicitly deferred; its implementation and documented limitation are unchanged.
The preparation record below predates that source publication. Check the
containing public commit's Actions result and deployed `build-info.json` for
hosted identity; the delivery report records those results separately. Local
artifact hashes keep their original snapshot scope. Git text normalization may
change line endings in public blobs without changing configuration values.

The owner configuration is wired into the production source. This is local
preparation of an uncommitted working tree based on
`962740e313af078bee07eb8548c72ba1554527ce`; no commit, push, Pages deployment,
Play Console change or app-store upload was performed. Native and owner-console
acceptance remain separate from source and package verification.

## Configuration and behavior

`platform/config.json` is byte-identical to the owner's initial file:
SHA256 `4AE7E80742D3378FDC4DBA355EF8883407CFD58532CEF3212D94315D58BCDD0D`.
Play Games remains enabled and AdMob `test_mode` remains false. All twenty
achievement and four leaderboard mappings are complete and distinct. The
numeric PGS game ID now matches the Android preset, and the production AdMob
manifest setting matches the JSON App ID. No owner IDs were substituted.

Debug/editor runtime requests always select Google sample units. Android debug
exports also select Google's sample manifest App ID; production release exports
retain the owner App ID and, with `test_mode=false`, the owner units. The complete
production JSON remains packaged in both variants; debug safety comes from the
tested routing code and variant-specific manifest. Production SDKs were never
executed during this work.

Play Games clients bind before authentication checks. Banked local achievements
and records synchronize at startup, and desired values survive offline/failure,
restart and interrupted journal writes. Submission callbacks acknowledge the
captured score, retries coalesce and use bounded noninteractive checks, and a
missing/late callback cannot acknowledge a newer score. The game save is separate
from the retry journal. Existing save keys and earned-assistance eligibility are
retained. No real save or Google player progress was used in tests.

Daily queue entries carry their UTC puzzle date; stale and legacy undated values
are not uploaded as today's puzzle. All four boards use raw integer Number
values, zero decimal places and larger-is-better ordering: Endless points,
Daily points, campaign star total and keeper level. No duration conversion is
performed. Actual Console types/order/limits remain unverified.

Google's native daily leaderboard resets at UTC−7 year-round, while the local
puzzle changes at UTC. The new queue guard does not make those periods match:
the same UTC puzzle score can enter two native daily windows, and a native
window can contain scores from two puzzles. A strict per-puzzle ranking needs
additional period/backend design. This is an owner acceptance limitation, not a
configurable reset option. See [Google's documentation](https://developer.android.com/games/pgs/leaderboards).

Privacy refresh invalidates cached ads and old consent/load/initialization
callbacks before new requests. Unknown/required consent blocks advertising;
duplicate initialization and overlapping interstitial loads are guarded.
Existing active fullscreen lifecycle and genuine earned-only callbacks remain
intact, with explicit Resume and once-only result banking preserved.

The Android target is raised from 35 to **36**, retaining min API **24**, Gradle
AAB, ARM64, x86 and x86_64. [Google's phone-app requirement](https://developer.android.com/google/play/requirements/target-sdk)
requires API 36 for new apps/updates from August 31, 2026. Target level alone
does not establish full Play eligibility. Dated API 35 exports and native QA
remain preserved with their original scope.

Package inspection also found the old category value `0` exported as
Accessibility with `isGame=false`. The preset now uses Godot's Game value `2`;
the package checker requires `appCategory=game`, `isGame=true` and
`allowBackup=false`. The enum and game flag behavior were checked against the
[Godot 4.5.1 exporter source](https://github.com/godotengine/godot/blob/4.5.1-stable/platform/android/export/export_plugin.cpp).

## Source verification

Final tests use Godot `4.5.1.stable.official.f62fdbde1`, Java 17, a frozen export
snapshot of canonical source, per-process application data and a task-specific
Gradle home. No global Gradle daemon stop, emulator operation or editor-process
termination was used.
Scoped write/read/delete access was verified with a temporary file inside this
project's ignored build directory before implementation.

| Check | Final source result |
| --- | --- |
| Import and strict diagnostics | Pass |
| Legal automatic-wave campaign witnesses | 100/100 missions |
| Independent core | 265/265 |
| Retry/result banking | 124/124 |
| Round Five | 1,497/1,497 |
| Round Four UI | 975/975 |
| Round Two | 268/268 |
| Artwork/provenance | 60/60 |
| UI scene | 25/25 |
| Viewport input dispatch | 91/91 |
| Service fallback/geometry/earned callback contract | Pass |
| Ad routing/consent/interstitial fixtures | 51/51 |
| Play Games synthetic clients/retry/journal/date/units | 117/117 |
| Offline package-parser regressions | 10/10 |
| Source IDs/preset consistency | Pass |

The assertion suites total 3,473 checks, plus the 100 campaign witnesses and
service smoke. They prove isolated model/adapter behavior, not native SDK,
human balance, production sign-in or advertising acceptance. Generated fixture
evidence stays in the private build snapshot; canonical tracked fixtures were
not replaced with new synthetic captures.

The full game/service suite ran in local run `a2`. The final category correction
changes only the Android preset and the offline checker/test; a byte comparison
proves every other source input, including all game/service scripts, assets and
owner configuration, is identical. Final run `a3` repeats import, configuration,
the expanded ten package-parser tests and all exports/package checks. Its receipt
explicitly identifies the carried suite rather than claiming another full run.

Initial restricted service runs passed their behavioral checks but failed the
strict log gate with `Failed to read the root certificate store`. Those logs
remain under the ignored service-test run. Final source checks passed with
normal Windows certificate-store access; no trust settings or diagnostic filters
were changed. An earlier partial export snapshot was interrupted before tests
or exports for the final service guards and API 36 change; it is not accepted
build evidence.

## Remaining acceptance

Owner OAuth/app linkage, package and signing-certificate fingerprints, PGS tester
access and service publication have not been inspected in Console. Validate
ordinary unlock types and Number/descending leaderboard settings with an owner
test account before production-service acceptance. This task did not request
an unlock or submit any score to Google.

Owner release signing is untouched. An unsigned release AAB is not upload-ready;
a generated QA signature is not a production identity. The preset remains
version 1.0.0/code 1; the owner must verify an unused version code, Play App
Signing configuration and the complete current release requirements.

Fresh native/physical gameplay, test-ad consent/banner/interstitial/reward flows,
offline/restart behavior, Android 16 and 16KB-device behavior, audible output,
interactive Web/iframe storage and human balance remain not run for these
exports. Earlier APKs/screenshots do not validate them. Hosted CI is not run for
this uncommitted change; the workflow retains its existing gates and adds source
configuration, isolated service fixtures, actual package-ID and independent
debug-signature checks.

See [production data practices](PRODUCTION_DATA_PRACTICES.md) for SDK versions,
local saves, Google identifiers, advertising/consent, permissions and external
URLs. There is no active game cloud-save, billing, custom analytics or crash SDK
integration. The advertising SDK has its own measurement/diagnostic practices.
The in-game privacy entry opens UMP, not a policy website. The separate website
task supplies final policy pages; this task changes no website. Policy/contact,
retention/deletion representations, audience settings and Play Data safety/ad
declarations still need owner review.

## Final package verification and deliverables

Accepted local export run: `build/production-integration-20261115-a3/`.
`BUILD-RECEIPT.json` status is **PASS**, with unchanged canonical runtime/test
inputs before/after. All final export/check commands exited zero with empty
strict diagnostic lists. This is an uncommitted source snapshot, not hosted CI.

| Artifact relative to that run | Bytes | SHA256 |
| --- | ---: | --- |
| `android-release-unsigned/mosslight-bastion-release-unsigned.aab` | 100,332,306 | `87234efdd28e1e104be7bc2f2716dabe22f1eb614b7ee54e791263de179b1268` |
| `android-debug/mosslight-bastion-debug.aab` | 107,962,200 | `ba9a7ac2f9da24f25b8b1f2490061e46376e39013e68c153505b84782e2a3b1f` |
| `web/index.html` | 5,492 | `6c4086b1ae40088e8fe78a7df3f2eaf272132a74a6e06ce116d4b2bcbc5c517c` |
| `web/index.pck` | 16,348,600 | `3826f7f937157d47394c10aa3667a3fdfbd9265baa5dd2c3594c8b7e98fe0d0e` |

The release AAB is **unsigned, not debuggable and not upload-ready**. Independent
jarsigner inspection reports `jar is unsigned`. The final debug AAB is signed
only with a new task-generated QA key; independent jarsigner reports
`jar verified`. Godot's raw debug export was unsigned despite the signed preset,
so it is preserved separately and is not the accepted debug deliverable.
The package parser deliberately reports its own cryptographic check as false;
the separate jarsigner stage supplies that evidence.

Both AABs verify package `com.ethannyakabuski.mosslightbastion`, version
1.0.0/code 1, minimum API 24, target API 36, Game category, `isGame=true`,
`allowBackup=false`, all expected native plugin metadata, the resolved owner PGS
game ID and exact source config/catalog JSON. The release manifest contains the
production AdMob App ID; the debug manifest contains Google's sample App ID.
Web PCK config/catalog JSON also matches the frozen source.

Each AAB includes ARM64, x86 and x86_64, with six verified ELF headers and paired
32/64-bit libraries. Both native libraries in each 64-bit ABI have 16KB PT_LOAD
alignment in the release AAB. This does not prove generated APK ZIP alignment
or runtime behavior on a 16KB device; those remain not run.

The resolved `standardReleaseRuntimeClasspath`, supplied the same exported
plugin dependency properties, confirms GMA Next-Gen 1.4.0, UMP 4.0.0, Play Games
v2 21.0.0 and Gson 2.13.2 (the direct 2.11.0 request is upgraded by Tink's
transitive constraint). The template uses Gradle 8.11.1, AGP 8.6.1, compile SDK
35, build-tools 35.0.0 and Kotlin 2.1.20; the actual manifest target 36 is checked
separately. The resolved graph contains no Firebase/Crashlytics/Billing client.

All three output folders contain exact matching LICENSE, NOTICE and complete
LICENSES notices. Distribute only the named output folders/files, keeping Web
JS/WASM/PCK and sidecars together. The parent run also contains private source,
caches, raw logs and a QA key, which are not distribution payloads or commits.

Retained export diagnostics include one unparsed X509 certificate, experimental
Android path-check and manifest-replacement warnings, libraries packaged without
stripping, editor-exit Orphan StringName Node output and a debug Scan thread
aborted warning. QA signatures also report expected self-signed/untrusted-chain
and timestamp warnings. No diagnostics were suppressed; passing strict gates is
not a blanket clean-log or native-runtime claim.

Earlier `a2` exports are preserved as candidates with the wrong application
category and are not the final delivery. Its first dependency-report command
used the nonexistent `releaseRuntimeClasspath`; the corrected report and
original failure remain recorded. Final `a3` uses the correct configuration and
passes that report directly. This reporting failure did not invalidate the
byte-identical game/service assertions carried explicitly into `a3`.
