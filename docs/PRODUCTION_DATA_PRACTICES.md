# Production data practices checkpoint

Source audit: 2026-11-15. This is an engineering handoff for policy drafting,
not a published policy or completed Google Play Data safety declaration. It
describes this canonical working copy; production account settings, SDK network
traffic and actual player consent were not exercised. Owner identifiers were
read for configuration review and are not reproduced here.

## SDKs and build identity

| Component | Source / resolved version | Evidence |
| --- | --- | --- |
| Godot | 4.5.1 Compatibility | Project instructions and Android build template |
| Poing Godot AdMob | 5.1.0 | `addons/admob/plugin.cfg` |
| Google Mobile Ads Next-Gen Android SDK | `ads-mobile-sdk:1.4.0` | `addons/admob/android/bin/ads/poing_godot_admob_ads.gd` |
| Google User Messaging Platform Android SDK | 4.0.0 resolved dependency of the ads SDK | Final exported release dependency graph and cached Maven POM |
| GodotPlayGameServices | 3.4.0 | `addons/GodotPlayGameServices/plugin.cfg` |
| Google Play Games Services v2 Android SDK | `play-services-games-v2:21.0.0` | `addons/GodotPlayGameServices/export_plugin.gd` |
| Gson | 2.11.0 requested directly; 2.13.2 resolved | Final graph upgrades the direct request through Tink's transitive constraint |

The Android package is `com.ethannyakabuski.mosslightbastion`. Presets request
minimum API 24, target API 36, ARM64, x86 and x86_64. Those settings alone are
not a Google Play eligibility determination. No iOS export is in this delivery;
the vendored iOS dependency declarations are not the Android SDK versions.

## Local game data

`game/progress.gd` writes `user://mosslight_progress_v1.json`. It contains banked
coins and XP, mission completion and stars, cumulative gameplay counts, Endless
and date-keyed Daily records, preparation upgrades, cosmetic ownership and skin,
music/sound preferences, local day/login dates and streak, quest progress/claims,
Daily clears, locally unlocked achievement keys, run sequence and up to 128
credited run IDs used to prevent duplicate payouts. Existing `unassisted_*`
names are compatibility keys; genuinely earned-ad-assisted runs qualify too.

Writes use a checked temporary file and previous-valid `.backup`. Invalid save
files may be retained with an `.invalid-...` suffix. These are application-local
files, not an owner-operated remote store. Unfinished combat intentionally does
not survive process death. Clearing app data or uninstalling may erase local
progress; the Android manifest sets `allowBackup=false`, and this game does not
offer cloud restore or an in-game account deletion/export function.

`platform/services.gd` separately persists queued achievement keys and best
integer leaderboard values in `user://platform_pending_v1.json` for later
submission, with `.tmp`/`.bak` recovery files. Daily entries carry their UTC
puzzle date; older/undated values are retained locally without uploading as a
later puzzle. Google's UTC-7 native daily window differs from the UTC puzzle;
see the readiness report for that limitation. Desired unlocks and best values
remain durable after successful submission so reconnect/retry can safely resend
them. Upload acknowledgements are session-only. The current game profile is
device-local rather than partitioned by Google player ID: signing into another
Google player can submit that same device's earned records to that player.

The game does not collect a player name, email address, phone number, precise
location, contacts, photos, microphone or camera content in its game code. It
does not persist a Google player/account identifier in either game save. That
does not mean the Google SDKs collect no identifiers or diagnostic information.

The Web build uses browser-local game storage with no native ad or Play Games
integration. Browser clearing/private mode or cross-site iframe storage
blocking/partitioning can affect retention. The repository's `WEB_PAGES.md`
requires actual destination/browser checks and makes no cross-device save claim.

## Play Games account and online records

The owner has supplied enabled Play Games configuration with a numeric game ID,
20 achievement mappings and four leaderboard mappings. Sign-in initialization
checks authentication and the UI includes optional Play Games sign-in. When
authenticated, the adapter sends earned achievement unlocks and the four
integer record categories: Endless score, Daily score, campaign star total and
keeper level. Score units and backend ordering/reset settings must match the
separate production integration/readiness report.

The native Google SDK manages authentication and associates submitted records
with the signed-in Play Games player. The game does not implement its own
account server, password, OAuth-token exchange or server-side identity store.
It instantiates sign-in, achievements and leaderboard clients. Although the
vendored plugin includes player, friends and snapshots/cloud-save wrappers,
the game does not instantiate or call them. There is no game cloud-save
upload/download, cross-device progress merge or remote save backup in this
implementation. Online records/achievements must not be described as cloud saves.

Local gameplay remains available without successful sign-in or connectivity.
Production OAuth linkage, signing fingerprints, tester access and actual online
record acceptance still require owner verification; configuration is not proof
that sign-in succeeds.

## Advertising and consent behavior

The game uses Android banner, interstitial and rewarded ads. A bottom banner is
shown on menu/Results screens and hidden during gameplay. An interstitial may
show after every second naturally completed round when an ad is available.
Optional rewarded repair is limited to once per run and requires the genuine
native earned callback. Fullscreen advertising leaves combat paused until
explicit Resume. Failure/unavailability does not prevent ordinary local play;
Web and non-Android paths do not simulate a native earned reward.

At Android startup the adapter requests updated UMP consent information, passing
the configured `tag_for_under_age_of_consent` flag (currently false). It loads
and shows an available form when consent is required. Mobile Ads initialization
is gated on UMP status `OBTAINED` or `NOT_REQUIRED`; unknown/required status or a
missing UMP service leaves ads paused. A failed update only proceeds if the
cached status permits it. Settings includes an Advertising privacy options
entry that invokes the native privacy-options form and refreshes consent.

`OBTAINED` is the SDK consent status, not a claim that a player agreed to every
purpose or personalized advertising. The game does not itself override consent
choices or set a non-personalized-ad request flag. Actual forms, regional
messages, ad personalization, audience declarations, ad-network configuration,
retention and Google account controls depend on the owner's consoles and SDKs.
The under-age flag is not an age gate or a completed Families/audience setup.

Owner production AdMob App ID and three ad-unit IDs exist in configuration.
Final a3 package checks confirm the production release manifest App ID and
Google sample debug manifest App ID, with exact owner JSON in both. Source
fixtures verify release unit selection and safe debug/editor sample routing;
production ad execution was not performed. No production ad was requested or interacted with during
this audit. Test routing does not make SDK data collection impossible.

Google's current [GMA Next-Gen disclosure guidance](https://developers.google.com/admob/android/next-gen/privacy/play-data-disclosure)
describes automatic collection/sharing of IP address, interactions, diagnostics,
and device/account identifiers for ads, measurement and fraud prevention. This
is third-party guidance for its current SDK, not captured network evidence for
this specific 1.4.0 build. In particular, absence of a separately integrated
analytics/crash SDK must not be presented as absence of ad-SDK analytics or
diagnostics. Google publishes [UMP integration guidance](https://developers.google.com/admob/android/next-gen/privacy)
and the [Google Privacy Policy](https://policies.google.com/privacy).

## Purchases, analytics, crash reporting and backend services

No Google Play Billing, in-app purchase, paid currency, purchase verification,
Firebase Analytics, Crashlytics, Sentry, custom analytics endpoint, remote-config
service, push messaging integration, chat service or owner-operated backend was
found in game/platform code or the declared Android exporter dependencies.
Coins, preparation and cosmetics are earned/purchased only with local gameplay
currency. This finding covers explicit integrations; the ad SDK has its own
measurement/diagnostic behavior and transitive libraries.

## Android permissions and external destinations

The preset explicitly enables `INTERNET` and `ACCESS_NETWORK_STATE`. Both final
a3 **debug and release AAB manifests** also contain the following permissions:

- `android.permission.AD_ID`
- `com.google.android.gms.permission.AD_ID`
- `android.permission.READ_BASIC_PHONE_STATE`
- `android.permission.WAKE_LOCK`
- `android.permission.FOREGROUND_SERVICE`
- `com.ethannyakabuski.mosslightbastion.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`

Final package inspection confirms these eight total permissions,
`allowBackup=false`, Game category and minimum API 24 / target API 36.
This is packaged declaration evidence, not runtime permission or traffic QA. None of these are evidence that the game requests camera,
microphone, contacts, storage, precise location or notification access. The
app-private receiver permission is an AndroidX implementation detail, not a
permission to read other apps' player data.

No `OS.shell_open`, HTTP client or external policy/contact URL appears in the
game/platform runtime code. The Advertising privacy options button opens the
native UMP form, not a website privacy policy. Ad creatives and Google-owned
sign-in/record/consent UI can present their own third-party destinations, which
are not a fixed developer-owned URL list. SDK endpoints were not traffic audited.

Repository documentation references the project landing and playable Web URLs:

- `https://ethannyakabuski.github.io/mosslight-bastion/`
- `https://ethannyakabuski.github.io/mosslight-bastion/game/`

They are not runtime links in the Android game. `store/privacy-policy-draft.md`
is an earlier draft and still contains outdated test-only configuration wording.
A separate `site/privacy.html` source page is also explicitly a privacy draft
with no owner contact information; `site/index.html` links to it as "Privacy
draft". Its expected repository Pages path would be `/mosslight-bastion/privacy.html`,
but this source audit did not verify a live response or approve it as a final
policy. It is separate from the owner's website policy task.
The separate website task owns policy publication; no website was changed by
this audit and no policy URL is opened by this runtime. Final policy
contact/retention/deletion details and accurate Play Console declarations still
require owner review.

## Evidence boundaries

This checkpoint combines source/configuration reads with final a3 manifest,
resolved resource, packaged JSON and release dependency-graph inspection.
Exact artifact identities and test scope are in [the readiness report](PRODUCTION_READINESS.md). It does not establish
consent-message content, production SDK traffic, signed-in behavior, physical
device acceptance, remote retention/deletion, ad personalization or Play review
acceptance. Preserve historical build evidence separately.
