class_name BastionSession
extends RefCounted
## Production lifecycle: entitlement and fullscreen visibility are independent.
const Sim = preload("res://game/simulation.gd")
var progress: BastionProgress
var simulation: BastionSimulation
var services: Node
var run_id: String = ""
var reward_pending: bool = false
var user_paused: bool = false
var banked: bool = false
var last_receipt: Dictionary = {}
var notice: String = ""
var _token: int = 0
var _last_modal: bool = false

func _init(saved: BastionProgress = null, platform: Node = null) -> void:
	progress=saved
	services=platform

func begin(mission: Dictionary) -> void:
	_token+=1
	reward_pending=false
	banked=false
	user_paused=false
	_last_modal=false
	notice=""
	run_id=progress.begin_run()
	simulation=Sim.new(mission,progress.data.preparation)

func fullscreen_active() -> bool:
	return is_instance_valid(services) and services.has_method("fullscreen_ad_active") and bool(services.fullscreen_ad_active())

func advance(delta: float) -> void:
	if simulation==null or banked: return
	var modal: bool = fullscreen_active() or reward_pending
	if modal or (_last_modal and not modal):
		user_paused=true
		simulation.paused=true
	_last_modal=modal
	simulation.advance(delta,modal or user_paused)

func pause() -> void:
	user_paused=true
	if simulation!=null:
		simulation.paused=true
		simulation.accumulator=0.0

func resume() -> bool:
	if simulation==null or reward_pending or fullscreen_active() or simulation.status not in ["running","ready"] or banked: return false
	user_paused=false
	simulation.paused=false
	_last_modal=false
	notice=""
	return true

func can_request_repair() -> bool:
	return simulation!=null and not banked and not simulation.assisted and not reward_pending and not fullscreen_active() and simulation.status in ["ready","running","lost"] and is_instance_valid(services) and services.has_method("can_reward") and bool(services.can_reward())

func request_repair() -> bool:
	if not can_request_repair():
		notice="No native reward is available. Ordinary Rally, retries and progression stay free."
		return false
	pause()
	_token+=1
	reward_pending=true
	notice="Waiting for the native reward. Combat is paused until the ad closes."
	services.reward_requested("one keep repair",_reward_callback.bind(_token,run_id))
	return true

func _reward_callback(earned: bool, token: int, expected_run: String) -> void:
	if not reward_pending or token!=_token or expected_run!=run_id or simulation==null or banked: return
	reward_pending=false
	pause()
	if earned and simulation.accept_earned_repair():
		notice="Earned: up to 8 keep hearts and 40 supplies. Close the ad, then tap Resume."
	else:
		notice="No reward earned; no assistance granted. Close the ad, then choose your next action."

func accept_result() -> Dictionary:
	if simulation==null or banked or reward_pending or fullscreen_active() or simulation.status not in ["won","lost"]: return {"recorded":false}
	last_receipt=progress.record_result(run_id,simulation.result())
	if bool(last_receipt.get("recorded",false)):
		banked=true
		pause()
		if is_instance_valid(services) and services.has_method("round_finished"): services.round_finished()
	return last_receipt

func abandon() -> void:
	_token+=1
	reward_pending=false
	pause()
	run_id=""
	banked=true
