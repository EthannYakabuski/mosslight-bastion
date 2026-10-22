# Round Three screenshot expansion

The set in `marketing/screenshots-round-three/` contains **18 genuine Android views: six per phone, logical 7-inch and logical 10-inch profile**.

Each profile shows Home, live defense, the field journal, the campaign roster, mission two's briefing and the keeper's workshop. The first three are byte-identical accepted Round Two images. The last three were captured through ordinary visible menus on October 22, without starting rounds, buying, claiming rewards or requesting rewarded ads. Raw PNGs are unchanged; there are no fixtures, overlays, crops or resizes.

All 18 belong to the same accepted debug APK, SHA256 `28962971847F38998301D6A6EF76DEFA6AA873CF56A6C6C80682CA9E4D45106E`, runtime source `9f84e66e63c354692a6b514a670a801fe7ab6b51`. This is a screenshot/document update; no runtime rebuild occurred. The manifest records each image's exact hash, dimensions and provenance.

The new capture session restored the genuine recorded profile because the temporary emulator session lacked the package. This is restoration, not proof of retention across the lost session. A normal UTC day rollover reset daily counters; wallet, XP and campaign/preparation progress stayed unchanged. A stopped genuine backup was verified privately and display/network settings were restored.

Profiles are actual guest framebuffers: phone1080x1920/420dpi, logical7 1200x1920/320dpi and logical10 1600x2560/300dpi. They all use one API30 x86 emulator and do not establish physical-device acceptance. Audio output remains disabled. This work does not retest production services, rewarded/interstitial behavior, offline gameplay or interactive Web, and does not resolve the retained Round Two Chromium diagnostic.

The original Round Two screenshot folder, APK, Web export and archives remain preserved. Existing Round Two archives contain the earlier nine-view set; they are not relabelled as eighteen-view archives. See `HANDOFF.txt` for exact artifacts and the existing functional QA qualifications.
