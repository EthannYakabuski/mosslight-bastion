extends SceneTree
## Pure routing/export-metadata checks. No ad SDK request or live ad is made.

var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var services: Node = root.get_node("Services")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://platform/config.json"))
	var production := {
		"banner": "ca-app-pub-7719473349082950/2645613001",
		"interstitial": "ca-app-pub-7719473349082950/3735333396",
		"rewarded": "ca-app-pub-7719473349082950/7530933165",
	}
	var samples := {
		"banner": "ca-app-pub-3940256099942544/6300978111",
		"interstitial": "ca-app-pub-3940256099942544/1033173712",
		"rewarded": "ca-app-pub-3940256099942544/5224354917",
	}
	check(config.admob.app_id == "ca-app-pub-7719473349082950~7481017619", "owner App ID retained")
	check(ProjectSettings.get_setting("admob/general/android/app_id", "") == config.admob.app_id, "manifest setting matches JSON App ID")
	check(config.admob.test_mode == false, "release configuration requests production units")
	for kind in production:
		check(config.admob[kind + "_unit_id"] == production[kind], "owner unit retained: " + kind)
		for debug_build in [false, true]:
			for force_test in [false, true]:
				var variant := config.duplicate(true)
				variant.admob.test_mode = force_test
				var actual: String = services._ad_id_for_build(variant, kind, debug_build)
				var expected: String = samples[kind] if debug_build or force_test else production[kind]
				check(actual == expected, "%s debug=%s force_test=%s routes correctly" % [kind, debug_build, force_test])
		check(services._ad_id_for_build({}, kind, false) == samples[kind], "missing config defaults to sample: " + kind)
		var missing_flag := config.duplicate(true)
		missing_flag.admob.erase("test_mode")
		check(services._ad_id_for_build(missing_flag, kind, false) == samples[kind], "missing flag defaults to sample: " + kind)
		var missing_unit := config.duplicate(true)
		missing_unit.admob.erase(kind + "_unit_id")
		check(services._ad_id_for_build(missing_unit, kind, false).is_empty(), "missing production unit does not request an ad: " + kind)
		check(services._ad_id(kind) == samples[kind], "actual debug runtime selects sample: " + kind)
	check(services._ad_id_for_build(config, "unknown", true).is_empty(), "unsupported kind cannot request an ad")
	check(services._ad_id_for_build(config, "unknown", false).is_empty(), "unsupported kind remains empty in release")
	check(services._use_test_ads(), "debug status accurately reports test ads")
	check(not services.can_reward(), "headless checks never create ad entitlement")
	_test_consent_cache(services)
	print("MOSSLIGHT_ADMOB_CONFIG_TESTS checks=%d failures=%d; no SDK requests or live ads" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_consent_cache(services: Node) -> void:
	check(services._consent_status_allows_ads(ConsentInformation.ConsentStatus.OBTAINED), "obtained consent allows ad initialization")
	check(services._consent_status_allows_ads(ConsentInformation.ConsentStatus.NOT_REQUIRED), "not-required consent allows ad initialization")
	check(not services._consent_status_allows_ads(ConsentInformation.ConsentStatus.UNKNOWN), "unknown consent pauses ad initialization")
	check(not services._consent_status_allows_ads(ConsentInformation.ConsentStatus.REQUIRED), "required consent pauses ad initialization")
	var fixture: GDScript = load("res://platform/tests/play_games_clients_fixture.gd")
	var banner: Variant = fixture.FakeBanner.new()
	var interstitial: Variant = fixture.FakeInterstitial.new()
	var rewarded: Variant = fixture.FakeRewarded.new()
	services._banner = banner
	services._interstitial = interstitial
	services._rewarded = rewarded
	services._ads_ready = true
	services._consent_ready = true
	services._on_ads_initialized(null, services._ad_request_generation)
	check(services._banner == banner and services._interstitial == interstitial and services._rewarded == rewarded, "duplicate initialization preserves existing caches without issuing new loads")
	var generation: int = services._ad_request_generation
	services._invalidate_cached_ads()
	check(not services._ads_ready and not services._consent_ready and services._ad_request_generation == generation + 1, "privacy refresh clears ad eligibility and invalidates older requests")
	check(banner.destroys == 1 and interstitial.destroys == 1 and rewarded.destroys == 1, "privacy refresh destroys cached banner and idle fullscreen ads once")
	check(services._banner == null and services._interstitial == null and services._rewarded == null and not services.can_reward(), "unready consent leaves no reusable ad or reward entitlement")
	services._on_ads_initialized(null, generation)
	check(not services._ads_ready, "late initialization cannot enable ads after consent was invalidated")
	services._consent_ready = true
	services._on_ads_initialized(null, generation)
	check(not services._ads_ready, "previous-generation initializer cannot start new loads after a later consent refresh permits ads")
	services._ads_ready = true
	var stale_interstitial: Variant = fixture.FakeInterstitial.new()
	var stale_rewarded: Variant = fixture.FakeRewarded.new()
	services._interstitial_loaded(stale_interstitial, generation)
	services._rewarded_loaded(stale_rewarded, generation)
	check(stale_interstitial.destroys == 1 and stale_rewarded.destroys == 1 and services._interstitial == null and services._rewarded == null, "late loads from the previous privacy generation are discarded")
	interstitial = fixture.FakeInterstitial.new()
	rewarded = fixture.FakeRewarded.new()
	services._interstitial = interstitial
	services._rewarded = rewarded
	services._interstitial_showing = true
	services._reward_showing = true
	var extra_interstitial: Variant = fixture.FakeInterstitial.new()
	services._interstitial_loaded(extra_interstitial, services._ad_request_generation)
	check(extra_interstitial.destroys == 1 and services._interstitial == interstitial, "overlapping same-generation loads cannot replace an active fullscreen handle")
	services._interstitial_loading = true
	services._invalidate_cached_ads()
	check(not services._interstitial_loading, "privacy invalidation releases the old interstitial load guard")
	check(interstitial.destroys == 0 and rewarded.destroys == 0 and services.fullscreen_ad_active(), "in-progress fullscreen lifecycle survives privacy invalidation without forced dismissal")
	services._interstitial_showing = false
	services._reward_showing = false
	services._interstitial_closed()
	check(interstitial.destroys == 0 and services._interstitial == interstitial, "duplicate close cannot dispose a newer cached interstitial")
	services._round_count = 1
	services.round_finished()
	check(interstitial.shows == 0, "a retained fullscreen object cannot show while ad eligibility is paused")
	services._invalidate_cached_ads()
	check(interstitial.destroys == 1 and rewarded.destroys == 1, "formerly active fullscreen caches are disposed after their lifecycle is no longer active")
