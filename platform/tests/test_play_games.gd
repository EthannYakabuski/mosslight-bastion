extends SceneTree
## Synthetic adapter tests only. These do not authenticate with Google or prove
## native/backend acceptance. The runner must isolate user data and opt in below.

const PENDING = "user://platform_pending_v1.json"

var checks := 0
var failures: Array[String] = []
var catalog: Dictionary = {}
var service_serial := 0
var service_script: GDScript
var clients_fixture: GDScript

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# This guard is additional protection, not a substitute for process-scoped
	# APPDATA/LOCALAPPDATA (Windows) or XDG_DATA_HOME (Linux) set by the runner.
	if OS.get_environment("MOSSLIGHT_PGS_TEST_ISOLATED") != "1" or OS.get_name() == "Android" or not OS.get_cmdline_user_args().has("--qa-isolated"):
		printerr("FAIL: PGS fixture requires isolated user data and --qa-isolated and MOSSLIGHT_PGS_TEST_ISOLATED=1; Android execution is forbidden")
		quit(1)
		return
	var isolated_root := OS.get_environment("MOSSLIGHT_PGS_TEST_ROOT").replace("\\", "/").trim_suffix("/")
	var user_path := OS.get_user_data_dir().replace("\\", "/")
	if isolated_root.is_empty() or not user_path.begins_with(isolated_root + "/"):
		printerr("FAIL: PGS fixture user data is outside its explicit isolation root")
		quit(1)
		return
	# A --script entrypoint compiles before autoload globals are registered.
	# Resolve production services and SDK-derived fakes only after deferred _run,
	# when the normal autoload startup has completed. No SDK files are modified.
	service_script = root.get_node("Services").get_script() as GDScript
	clients_fixture = load("res://platform/tests/play_games_clients_fixture.gd") as GDScript
	if service_script == null or clients_fixture == null or not clients_fixture.can_instantiate():
		printerr("FAIL: post-autoload Play Games test scripts failed to load")
		quit(1)
		return
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	check(catalog.get("achievements", []).size() == 20 and catalog.get("leaderboards", []).size() == 4, "fixture exercises the complete Mosslight service catalog")
	await _test_complete_achievement_mapping()
	await _test_authentication_and_deduplication()
	await _test_manual_sign_in_and_pending_views()
	await _test_score_acknowledges_captured_value()
	await _test_failed_submissions_retry()
	await _test_missing_callbacks_and_late_scores()
	await _test_missing_ids_and_invalid_keys()
	await _test_pending_journal_restart_and_validation()
	await _test_daily_period_and_score_units()
	_erase_synthetic_files()
	print("MOSSLIGHT_PLAY_GAMES_TESTS checks=%d failures=%d; synthetic adapters only, no Google/backend validation" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _settle() -> void:
	await process_frame
	await process_frame

func _erase_pending() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = PENDING + suffix
		if FileAccess.file_exists(path):
			check(DirAccess.remove_absolute(path) == OK, "remove only synthetic isolated pending file " + suffix)

func _erase_synthetic_files() -> void:
	_erase_pending()

func _settings() -> Dictionary:
	var achievements := {}
	var boards := {}
	for item in catalog.get("achievements", []): achievements[str(item.id)] = "fixture-ach-" + str(item.id)
	for item in catalog.get("leaderboards", []): boards[str(item.id)] = "fixture-board-" + str(item.id)
	return {"play_games": {"enabled": true, "game_id": "1", "achievements": achievements, "leaderboards": boards}}

func _service(clear_journal: bool = true) -> Node:
	if clear_journal: _erase_pending()
	var service: Node = service_script.new()
	service_serial += 1
	service.name = "PgsFixture%d" % service_serial
	# Desktop _ready loads the real journal code and then takes its non-native
	# fallback. Override settings only with synthetic IDs before fake binding.
	root.add_child(service)
	service.set_process(false)
	service.settings = _settings()
	return service

func _clients(service: Node) -> Dictionary:
	var sign: Variant = clients_fixture.FakeSignIn.new()
	var achievements: Variant = clients_fixture.FakeAchievements.new()
	var boards: Variant = clients_fixture.FakeBoards.new()
	service._bind_play_games_clients(sign, achievements, boards)
	check(sign.checks == 0, "initial authentication waits until all native client nodes are ready")
	await _settle()
	check(sign.ready_seen and achievements.ready_seen and boards.ready_seen and sign.premature_requests == 0, "deferred authentication follows all client _ready hooks")
	return {"sign": sign, "achievements": achievements, "boards": boards}

func _dispose(service: Node) -> void:
	if is_instance_valid(service):
		service.set_process(false)
		service.queue_free()
	await _settle()

func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "isolated fixture can write synthetic JSON")
	if file != null:
		file.store_string(JSON.stringify(value))
		file.close()

func _test_authentication_and_deduplication() -> void:
	var service = _service()
	service.unlock("five_walls")
	service.submit("unassisted_endless_score", 180)
	var clients := await _clients(service)
	await _settle()
	check(clients.achievements.unlocks.is_empty() and clients.boards.submissions.is_empty(), "offline state never fabricates remote success")
	clients.sign.complete(false)
	await _settle()
	check(not service._signed_in and clients.boards.submissions.is_empty(), "failed automatic authentication keeps progress local")
	service.sign_in()
	check(clients.sign.interactive_requests == 1, "only explicit sign-in requests interactive authentication")
	clients.sign.complete(true)
	await _settle()
	check(clients.achievements.unlocks == ["fixture-ach-five_walls"] and clients.boards.count_for("fixture-board-unassisted_endless_score") == 1, "successful authentication sends retained progress with matching IDs")
	for repeat in range(8):
		service.unlock("five_walls")
		service.submit("unassisted_endless_score", 180)
		service._queue_progress_flush()
	await _settle()
	check(clients.achievements.unlocks.size() == 1 and clients.boards.submissions.size() == 1, "duplicate game updates do not flood in-flight requests")
	clients.achievements.complete("fixture-ach-five_walls", true)
	clients.boards.complete("fixture-board-unassisted_endless_score", true)
	await _settle()
	service.unlock("five_walls")
	service.submit("unassisted_endless_score", 179)
	service._flush_pending()
	await _settle()
	check(clients.achievements.unlocks.size() == 1 and clients.boards.submissions.size() == 1, "acknowledged unchanged achievement and lower score are not resent in one session")
	check(service._pending_scores.get("unassisted_endless_score") == 180 and service._pending_unlocks.has("five_walls"), "acknowledgement retains durable desired progress")
	clients.sign.complete(false)
	clients.sign.complete(true)
	await _settle()
	check(clients.achievements.unlocks.size() == 2 and clients.boards.submissions.size() == 2, "new authenticated session replays genuine desired progress")
	await _dispose(service)

func _test_complete_achievement_mapping() -> void:
	var service = _service()
	var clients := await _clients(service)
	var expected: Array[String] = []
	for item in catalog.get("achievements", []):
		var key := str(item.id)
		expected.append("fixture-ach-" + key)
		service.unlock(key)
	clients.sign.complete(true)
	await _settle()
	var actual: Array[String] = clients.achievements.unlocks.duplicate()
	actual.sort()
	expected.sort()
	check(actual == expected, "all 20 symbolic achievements dispatch their distinct matching configured remote IDs")
	check(clients.achievements.incremental_requests == 0, "complete catalog uses standard unlock requests exclusively")
	for remote_id in expected: clients.achievements.complete(remote_id, true)
	for item in catalog.get("achievements", []): service.unlock(str(item.id))
	await _settle()
	check(clients.achievements.unlocks.size() == 20, "acknowledged complete catalog is not redundantly dispatched again")
	await _dispose(service)

func _test_score_acknowledges_captured_value() -> void:
	var service = _service()
	var clients := await _clients(service)
	clients.sign.complete(true)
	service.submit("unassisted_endless_score", 180)
	await _settle()
	service.submit("unassisted_endless_score", 240)
	await _settle()
	check(clients.boards.submissions.size() == 1, "higher value waits behind the existing request for the same remote ID")
	clients.boards.complete("fixture-board-unassisted_endless_score", true)
	var acknowledged: Dictionary = service._submitted_scores.get("unassisted_endless_score", {})
	check(int(acknowledged.get("value", -1)) == 180, "older success acknowledges the captured sent value, not the newer desired value")
	await _settle()
	check(clients.boards.count_for("fixture-board-unassisted_endless_score") == 2 and clients.boards.latest_value("fixture-board-unassisted_endless_score") == 240, "newer high score is dispatched after the old request settles")
	clients.boards.complete("fixture-board-unassisted_endless_score", true)
	await _settle()
	acknowledged = service._submitted_scores.get("unassisted_endless_score", {})
	check(int(acknowledged.get("value", -1)) == 240, "newer score is acknowledged only by its own completion")
	check(service._pending_scores.get("unassisted_endless_score") == 240, "highest desired score remains durable after acknowledgement")
	await _dispose(service)

func _test_manual_sign_in_and_pending_views() -> void:
	var service = _service()
	var clients := await _clients(service)
	service.open_achievements()
	service.sign_in()
	service.sign_in()
	check(clients.sign.interactive_requests == 0, "manual requests wait behind the current automatic authentication check")
	clients.sign.complete(false)
	check(clients.sign.interactive_requests == 1, "queued manual sign-in starts exactly once after automatic authentication returns false")
	clients.sign.complete(true)
	await _settle()
	check(clients.achievements.opened == 1, "requested achievements view opens after successful sign-in")
	service.open_leaderboards("unassisted_endless_score")
	check(clients.boards.opened == ["fixture-board-unassisted_endless_score"], "specific leaderboard view uses the configured remote ID")
	clients.sign.complete(false)
	service.open_leaderboards("player_level")
	clients.sign.complete(false)
	await _settle()
	var interactive_after_cancel: int = clients.sign.interactive_requests
	service._process_play_games(31.0)
	await _settle()
	check(clients.sign.interactive_requests == interactive_after_cancel, "cancellation never causes repeated background interactive prompts")
	check(clients.sign.checks >= 2, "background reconnect uses a non-interactive authentication check")
	check(clients.boards.opened.size() == 1, "cancelled sign-in does not open the pending online leaderboard")
	await _dispose(service)

func _test_failed_submissions_retry() -> void:
	var service = _service()
	var clients := await _clients(service)
	service.unlock("first_wall")
	service.submit("unassisted_stars", 7)
	clients.sign.complete(true)
	await _settle()
	clients.achievements.complete("fixture-ach-first_wall", false)
	clients.boards.complete("fixture-board-unassisted_stars", false)
	await _settle()
	check(service._pending_unlocks.has("first_wall") and service._pending_scores.get("unassisted_stars") == 7, "failed callbacks retain durable desired values")
	check(not service._submitted_unlocks.has("first_wall") and not service._submitted_scores.has("unassisted_stars"), "failed callbacks never become successful acknowledgements")
	var failed_unlock_count: int = clients.achievements.unlocks.size()
	var failed_score_count: int = clients.boards.submissions.size()
	service.unlock("first_wall")
	service.submit("unassisted_stars", 8)
	await _settle()
	check(clients.achievements.unlocks.size() == failed_unlock_count and clients.boards.submissions.size() == failed_score_count, "new progress retains its higher value without bypassing failed-upload backoff")
	service._process_play_games(31.0)
	await _settle()
	check(clients.sign.checks >= 2 and not service._signed_in, "failed submission schedules a non-interactive authentication recheck")
	clients.sign.complete(true)
	await _settle()
	check(clients.achievements.unlocks.size() >= 2 and clients.boards.count_for("fixture-board-unassisted_stars") >= 2, "bounded retry tick retries failed unlock and score without new gameplay")
	check(clients.sign.interactive_requests == 0, "background retry never opens an interactive sign-in request")
	await _dispose(service)

func _test_missing_callbacks_and_late_scores() -> void:
	var service = _service()
	var clients := await _clients(service)
	service.submit("player_level", 100)
	# An unanswered authentication check must not block an explicit retry forever.
	service._process_play_games(21.0)
	await _settle()
	service.sign_in()
	check(clients.sign.interactive_requests == 1, "authentication timeout permits a later explicit sign-in")
	clients.sign.complete(true)
	await _settle()
	service.submit("player_level", 300)
	service._process_play_games(31.0)
	await _settle()
	check(service._pending_scores.get("player_level") == 300, "missing callback does not lose the newer desired score")
	check(service._uncertain_score_ids.has("fixture-board-player_level") and clients.boards.count_for("fixture-board-player_level") >= 2, "missing score callback expires and retries without assuming an acknowledgement")
	clients.boards.complete("fixture-board-player_level", true)
	await _settle()
	var acknowledged: Dictionary = service._submitted_scores.get("player_level", {})
	check(int(acknowledged.get("value", -1)) != 300, "ambiguous late success never falsely acknowledges a newer value")
	check(service._pending_scores.get("player_level") == 300, "late callback cannot remove durable desired progress")
	var ambiguous_count: int = clients.boards.submissions.size()
	service.submit("player_level", 300)
	await _settle()
	check(clients.boards.submissions.size() == ambiguous_count, "an unchanged ambiguous score cannot bypass the retry cooldown")
	await _dispose(service)

func _test_missing_ids_and_invalid_keys() -> void:
	var service = _service()
	service.settings.play_games.achievements["first_wall"] = ""
	service.settings.play_games.leaderboards["unassisted_endless_score"] = ""
	service.unlock("first_wall")
	service.submit("unassisted_endless_score", 180)
	service.unlock("unknown_achievement")
	service.submit("unknown_board", 999)
	var clients := await _clients(service)
	clients.sign.complete(true)
	await _settle()
	check(clients.achievements.unlocks.is_empty() and clients.boards.submissions.is_empty(), "missing mappings never send blank remote IDs")
	check(service._pending_unlocks.has("first_wall") and service._pending_scores.get("unassisted_endless_score") == 180, "missing mappings retain real progress for later configuration")
	check(not service._pending_unlocks.has("unknown_achievement") and not service._pending_scores.has("unknown_board"), "unrecognized symbolic keys are rejected")
	service.settings.play_games.achievements["first_wall"] = "fixture-ach-first_wall"
	service.settings.play_games.leaderboards["unassisted_endless_score"] = "fixture-board-unassisted_endless_score"
	service._flush_pending()
	await _settle()
	check(clients.achievements.unlocks == ["fixture-ach-first_wall"] and clients.boards.latest_value("fixture-board-unassisted_endless_score") == 180, "adding mappings submits the retained genuine values without replaying gameplay")
	await _dispose(service)

func _test_pending_journal_restart_and_validation() -> void:
	var service = _service()
	service.unlock("five_walls")
	service.submit("unassisted_endless_score", 180)
	service.submit("unassisted_endless_score", 240)
	await _settle()
	check(FileAccess.file_exists(PENDING) and not FileAccess.file_exists(PENDING + ".tmp"), "successful ledger write leaves a complete primary and no temporary file")
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string(PENDING + ".bak"))
	check(backup is Dictionary, "replacing a valid ledger retains a parseable last-good backup")
	await _dispose(service)
	service = _service(false)
	check(service._pending_unlocks.has("five_walls") and service._pending_scores.get("unassisted_endless_score") == 240, "restart restores the retained unlock and highest endless point value")
	check(service._submitted_unlocks.is_empty() and service._submitted_scores.is_empty(), "session acknowledgements are not trusted across a process restart")
	await _dispose(service)
	_erase_pending()
	_write_json(PENDING, {"unlocks": {"first_wall": true, "five_walls": "true", "unknown_achievement": true}, "scores": {"unassisted_endless_score": 180, "unassisted_daily_score": 4, "unassisted_stars": -1, "player_level": 3.5, "unknown_board": 99}})
	service = _service(false)
	check(service._pending_unlocks == {"first_wall": true}, "journal validation accepts only true flags for known achievement keys")
	check(service._pending_scores.get("unassisted_endless_score") == 180 and service._legacy_daily_score == 4 and not service._pending_scores.has("unassisted_daily_score"), "JSON integers round-trip; undated daily value is preserved without relabelling its day")
	check(not service._pending_scores.has("unknown_board") and not service._pending_scores.has("unassisted_stars") and not service._pending_scores.has("player_level"), "negative, fractional and unknown journal scores are safely ignored")
	await _dispose(service)
	_erase_pending()
	_write_json(PENDING, {"unlocks": {}, "scores": {"unassisted_endless_score": "180", "unassisted_daily_score": false, "player_level": [3], "unassisted_stars": {}}})
	service = _service(false)
	check(service._pending_scores.is_empty(), "string, boolean, array and object journal scores are rejected")
	await _dispose(service)
	_erase_pending()
	_write_json(PENDING, {"unlocks": [], "scores": "not-a-dictionary"})
	_write_json(PENDING + ".bak", {"unlocks": {"five_walls": true}, "scores": {"unassisted_endless_score": 180}})
	service = _service(false)
	check(service._pending_unlocks.has("five_walls") and service._pending_scores.get("unassisted_endless_score") == 180, "malformed primary field types fall back to the last-good journal")
	await _dispose(service)
	_erase_pending()
	_write_json(PENDING, {"unlocks": {"first_wall": true}, "scores": {"unassisted_endless_score": 120}})
	_write_json(PENDING + ".bak", {"unlocks": {"five_walls": true}, "scores": {"unassisted_endless_score": 180}})
	_write_json(PENDING + ".tmp", {"unlocks": {"ten_walls": true}, "scores": {"unassisted_endless_score": 240}})
	service = _service(false)
	check(service._pending_unlocks.has("first_wall") and service._pending_unlocks.has("five_walls") and service._pending_unlocks.has("ten_walls"), "interrupted write recovery preserves the union of valid unlocks")
	check(service._pending_scores.get("unassisted_endless_score") == 240, "primary, backup and temporary journals recover the highest valid raw integer score")
	await _dispose(service)

func _test_daily_period_and_score_units() -> void:
	var today := Time.get_date_string_from_system(true)
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	_erase_pending()
	_write_json(PENDING, {"unlocks": {}, "scores": {"unassisted_daily_score": 9000}, "daily_day": yesterday})
	var service = _service(false)
	var clients := await _clients(service)
	clients.sign.complete(true)
	await _settle()
	check(clients.boards.submissions.is_empty(), "yesterday's queued daily best is never uploaded into today's period")
	service.submit("unassisted_daily_score", 9999)
	service.submit_daily(8888, yesterday)
	await _settle()
	check(clients.boards.submissions.is_empty(), "generic undated and expired-day daily submissions cannot reach the SDK")
	service.submit_daily(120, today)
	await _settle()
	check(service._pending_daily_day == today and service._pending_scores.get("unassisted_daily_score") == 120, "new daily period resets its queue rather than taking yesterday's larger score")
	check(clients.boards.latest_value("fixture-board-unassisted_daily_score") == 120, "daily raw point value is submitted without duration or scale conversion")
	service.submit_daily(119, today)
	service.submit_daily(120, today)
	service.submit_daily(140, today)
	await _settle()
	check(clients.boards.count_for("fixture-board-unassisted_daily_score") == 1, "same-day worse/equal/better updates wait behind one in-flight request")
	clients.boards.complete("fixture-board-unassisted_daily_score", true)
	check(service._submitted_scores.get("unassisted_daily_score", {}).get("value", -1) == 120, "daily callback acknowledges the captured old score only")
	await _settle()
	check(clients.boards.latest_value("fixture-board-unassisted_daily_score") == 140 and clients.boards.count_for("fixture-board-unassisted_daily_score") == 2, "newer same-day high is sent after old acknowledgement")
	clients.boards.complete("fixture-board-unassisted_daily_score", true)
	await _settle()
	for pair in [["unassisted_endless_score", 5230], ["unassisted_stars", 234], ["player_level", 12]]:
		service.submit(str(pair[0]), int(pair[1]))
	await _settle()
	for pair in [["unassisted_endless_score", 5230], ["unassisted_stars", 234], ["player_level", 12]]:
		check(clients.boards.latest_value("fixture-board-" + str(pair[0])) == int(pair[1]), "raw higher-is-better integer units for " + str(pair[0]))
	await _dispose(service)
	service = _service(false)
	check(service._pending_daily_day == today and service._pending_scores.get("unassisted_daily_score") == 140, "restart and yesterday backup recovery preserve today's own maximum only")
	await _dispose(service)
	_erase_pending()
	_write_json(PENDING, {"unlocks": {}, "scores": {"unassisted_daily_score": 9999}})
	service = _service(false)
	clients = await _clients(service)
	clients.sign.complete(true)
	await _settle()
	check(clients.boards.submissions.is_empty() and service._legacy_daily_score == 9999, "legacy undated daily queue is retained without automatic upload")
	service.submit_daily(70, today)
	await _settle()
	check(clients.boards.latest_value("fixture-board-unassisted_daily_score") == 70 and service._legacy_daily_score == 9999, "authoritative current-day profile replaces daily queue while preserving undated migration record")
	await _dispose(service)
	service = _service(false)
	check(service._legacy_daily_score == 9999 and service._pending_scores.get("unassisted_daily_score") == 70, "migration preserves both current-day and legacy raw daily records across restart")
	await _dispose(service)
