extends SceneTree
const Sim = preload("res://game/simulation.gd")
const Missions = preload("res://game/missions.gd")
const Progress = preload("res://game/progress.gd")
const Session = preload("res://game/session.gd")
var checks: Array = []
var failures: Array = []
var serial: int=0

class FakeServices extends Node:
	var modal: bool=false
	var available: bool=true
	var callback: Callable
	var completed_rounds: int=0
	func fullscreen_ad_active() -> bool: return modal
	func can_reward() -> bool: return available and not modal
	func reward_requested(_context: String, receiver: Callable) -> void:
		modal=true
		callback=receiver
	func round_finished() -> void: completed_rounds+=1

class FailingProgress extends BastionProgress:
	var fail_promotion: bool=false
	func _rename_file(from_path: String,to_path: String) -> Error:
		if fail_promotion and from_path.ends_with(".tmp"): return ERR_CANT_CREATE
		return super._rename_file(from_path,to_path)

func _init() -> void: call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks.append(label)
	if not condition:
		failures.append(label)
		push_error("CHECK FAILED: "+label)

func fresh(day: String="2026-10-20") -> BastionProgress:
	serial+=1
	return Progress.new("user://core-"+str(Time.get_ticks_usec())+"-"+str(serial)+".json",day)

func put(path: String, text: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()

func run() -> void:
	var mission: Dictionary=Missions.campaign(1)
	var sim: BastionSimulation=Sim.new(mission)
	check(not sim.build(-1,"archer") and not sim.build(100,"archer") and not sim.build(0,"invalid"),"Invalid build requests reject without spending")
	var initial: int=sim.supplies
	check(sim.build(0,"archer") and sim.supplies==initial-45,"Build charges exact shown price")
	check(not sim.build(0,"archer"),"Occupied pad rejects second tower")
	var price: int=sim.upgrade_cost(0)
	check(price==34 and sim.upgrade(0) and sim.supplies==initial-45-34,"Upgrade charges exact 75-percent rounded level1 cost")
	var refund: int=sim.sell_value(0)
	check(refund==55 and sim.sell(0) and sim.supplies==initial-45-34+55,"Sell returns floor70-percent total spend and cannot mint supplies")
	check(not sim.sell(0) and not sim.upgrade(0),"Empty pad cannot sell or upgrade")
	check(is_equal_approx(Sim.damage_after_armor("prism",34,0.6),34),"Prism ignores shell armor")
	check(Sim.damage_after_armor("ember",17,0.6)>Sim.damage_after_armor("archer",17,0.6),"Ember partially bypasses armor; archer remains cheap fast damage")
	check(Sim.TOWERS.archer.cost<Sim.TOWERS.ember.cost and Sim.TOWERS.archer.period<Sim.TOWERS.prism.period and Sim.TOWERS.prism.range>Sim.TOWERS.archer.range,"Counter roles retain cost/cadence/range tradeoffs")
	check(sim.next_wave() and not sim.next_wave(),"Wave starts only once from ready")
	sim.advance(0.2)
	var frozen: Dictionary=sim.snapshot()
	for _index in range(1000): sim.advance(0.2,true)
	check(sim.snapshot()==frozen,"Platform-blocked long dwell freezes ALL simulation state")
	sim.paused=true
	for _index in range(1000): sim.advance(0.2)
	check(sim.snapshot()==frozen,"User pause freezes spawn movement projectiles damage rally and timers")
	check(not sim.build(0,"archer") and not sim.rally() and not sim.next_wave(),"Paused actions reject")
	sim.paused=false
	check(sim.rally() and not sim.rally(),"Free Rally once per combat cooldown")
	var a: BastionSimulation=Sim.new(mission)
	var b: BastionSimulation=Sim.new(mission)
	a.build(0,"archer"); b.build(0,"archer")
	a.next_wave(); b.next_wave()
	for _index in range(120): a.advance(0.05)
	for _index in range(60): b.advance(0.1)
	check(a.snapshot()==b.snapshot(),"Fixed-step combat identical across two frame partitions")
	var slow_probe: BastionSimulation=Sim.new(mission)
	slow_probe.next_wave()
	slow_probe.advance(0.05)
	var target: Dictionary=slow_probe.enemies[0]
	var hp: float=float(target.hp)
	slow_probe._hit({"kind":"frost","damage":5.0,"splash":0.0,"slow":0.5},target)
	check(float(target.slow)>0.0 and float(target.hp)<hp,"Frost damages and slows a normal actual enemy")
	var wisp_def: Dictionary=mission.duplicate(true)
	wisp_def.waves=[[{"type":"wisp","count":1,"interval":1.0,"route":0,"delay":0.0}]]
	var wisp: BastionSimulation=Sim.new(wisp_def)
	wisp.next_wave(); wisp.advance(0.05)
	wisp._hit({"kind":"frost","damage":5.0,"splash":0.0,"slow":0.5},wisp.enemies[0])
	check(float(wisp.enemies[0].slow)==0.0,"Wisp actual enemy ignores frost slow")
	var swarm_def: Dictionary=mission.duplicate(true)
	swarm_def.waves=[[{"type":"swarm","count":3,"interval":0.0,"route":0,"delay":0.0}]]
	var swarm: BastionSimulation=Sim.new(swarm_def)
	swarm.next_wave(); swarm.advance(0.05)
	swarm._hit({"kind":"ember","damage":10.0,"splash":1.0,"slow":0.0},swarm.enemies[0])
	check(float(swarm.enemies[1].hp)<17 and float(swarm.enemies[2].hp)<17,"Ember splash damages a real clustered group")
	var daily: BastionSimulation=Sim.new(Missions.daily("2026-10-20"),{"power":5,"fortify":5})
	check(daily._power==0 and daily.max_hearts==int(daily.definition.hearts),"Daily disables persistent power and fortification")
	check(Missions.daily("2026-10-20")==Missions.daily("2026-10-20") and Missions.daily("2026-10-21").id!=daily.definition.id,"Daily is deterministic by UTC date and varies next day")
	check(Sim.new(Missions.endless()).wave_groups(12).size()==2,"Endless generates expanding two-route compositions beyond authored campaign")
	_test_progress()
	_test_lifecycle()
	_replay_witnesses()
	var report: Dictionary={"scope":"Actual Godot production model/save/lifecycle checks with isolated test paths and explicitly fake native adapter; not device or real SDK QA.","checks":checks.size(),"passed":checks.size()-failures.size(),"failures":failures,"names":checks}
	put("res://tests/evidence/core-results.json",JSON.stringify(report,"  "))
	print("MOSSLIGHT CORE ",checks.size()-failures.size(),"/",checks.size()," failed=",failures)
	quit(0 if failures.is_empty() else 1)

func _test_progress() -> void:
	var p: BastionProgress=fresh()
	check(p.data.coins==150 and p.available(1) and not p.available(2),"Fresh progression starts150 coins and first mission only")
	for raw in [{"version":1},{"version":1,"settings":{"sound":false}},{"version":1,"settings":null}]:
		var clean: Dictionary=p._normalize(raw)
		check(clean.settings.skin=="moss" and clean.settings.music==true,"Missing or partial settings normalize with safe skin default")
	check(not p._normalize({"daily_clears":{"2026-10-20":false}}).daily_clears.has("2026-10-20"),"False daily-clear field never becomes a claimed clear")
	check(p._normalize({"coins":-10,"xp":"huge","preparation":{"power":99}}).coins==0 and p._normalize({"preparation":{"power":99}}).preparation.power==5,"Save numbers are typed and bounded")
	check(Progress.valid_day("2024-02-29") and not Progress.valid_day("2026-02-29") and not Progress.valid_day("2026-13-20"),"Canonical real calendar validation includes leap years")
	var gift: Dictionary=p.claim_login()
	var coins: int=p.data.coins
	check(gift.claimed and gift.coins==50 and gift.xp==10 and not p.claim_login().claimed and p.data.coins==coins,"Login pays exact first gift once")
	p._day_override="2026-10-19"
	check(p.current_day()=="2026-10-20" and not p.claim_login().claimed,"Clock rollback cannot claim gift or rewind saved day")
	for date in range(21,28):
		p._day_override="2026-10-"+str(date)
		var next: Dictionary=p.claim_login()
		check(next.claimed and int(next.streak)==((date-20)%7)+1,"Consecutive seven-day gift cycle day"+str(date))
	var result: Dictionary={"finished":true,"won":true,"mode":"campaign","mission":1,"day":"","kills":10,"waves":2,"stars":3,"built":2,"upgrades":1,"rallies":1,"assisted":false,"score":1000}
	var id: String=p.begin_run()
	var receipt: Dictionary=p.record_result(id,result)
	check(receipt.recorded and p.available(2) and p.star_total()==3 and p.star_total(true)==3,"Actual finished result unlocks next mission and both unassisted star records")
	coins=p.data.coins
	check(not p.record_result(id,result).recorded and p.data.coins==coins and p.data.rounds==1,"Duplicate result cannot pay currency XP or rounds twice")
	var unfinished: Dictionary=result.duplicate(true); unfinished.finished=false
	check(not p.record_result(p.begin_run(),unfinished).recorded,"Unfinished combat cannot bank a result")
	var assisted: Dictionary=result.duplicate(true); assisted.mission=2; assisted.assisted=true
	check(p.record_result(p.begin_run(),assisted).recorded and p.data.completed.has("2") and not p.data.unassisted_stars.has("2"),"Assisted clear earns ordinary unlock while excluded from competitive stars")
	var endless: Dictionary=result.duplicate(true); endless.mode="endless"; endless.won=false; endless.score=900
	p.record_result(p.begin_run(),endless)
	endless.assisted=true; endless.score=99999
	p.record_result(p.begin_run(),endless)
	check(p.data.best_endless.score==900,"Assisted endless cannot overwrite unassisted best")
	p.data.daily.kills=40
	var quest: Dictionary=p.claim_quest("kills")
	coins=p.data.coins
	check(quest.claimed and quest.xp==20 and not p.claim_quest("kills").claimed and coins==p.data.coins,"Daily action quest pays once and repeat is disabled")
	var before_power: int=p.data.preparation.power
	var cost: int=p.preparation_cost("power")
	coins=p.data.coins
	check(p.buy_preparation("power") and p.data.preparation.power==before_power+1 and p.data.coins==coins-cost,"Preparation costs shown amount and persists one level")
	p.save()
	var restored: BastionProgress=Progress.new(p.path,p.current_day())
	check(restored.data==p.data,"All typed save groups round-trip after a cold model load")
	var path: String="user://backup-recovery-"+str(Time.get_ticks_usec())+".json"
	var fail: FailingProgress=FailingProgress.new(path,"2026-10-20")
	fail.data.coins=321; check(fail.save(),"First atomic save succeeds")
	fail.data.coins=654; check(fail.save(),"Second save preserves previous valid generation")
	put(path,"{corrupt")
	var recover: FailingProgress=FailingProgress.new(path,"2026-10-20")
	check(recover.recovered_backup and recover.data.coins==321,"Corrupt primary loads the real previous-valid backup")
	recover.fail_promotion=true
	recover.data.coins=777
	check(not recover.save(),"Injected ordinary rename failure reports save failure")
	var backup: Variant=JSON.parse_string(FileAccess.get_file_as_string(path+".backup"))
	var primary: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(backup is Dictionary and int(backup.coins)==321 and primary is Dictionary and int(primary.coins)==321,"Failed recovery promotion preserves both known-good backup and recoverable primary")
	recover.fail_promotion=false
	check(recover.save() and Progress.new(path,"2026-10-20").data.coins==777,"Retry after genuine failed commit safely writes current progress")

func _test_lifecycle() -> void:
	var fake: FakeServices=FakeServices.new()
	root.add_child(fake)
	var session: BastionSession=Session.new(fresh(),fake)
	session.begin(Missions.campaign(1))
	session.simulation.build(0,"archer"); session.simulation.next_wave(); session.advance(0.2)
	check(session.request_repair() and not session.request_repair(),"Only one pending native repair request is possible")
	var frozen: Dictionary=session.simulation.snapshot()
	for _index in range(1000): session.advance(0.2)
	check(session.simulation.snapshot()==frozen,"Pending real-native-ad boundary freezes full simulation during long wait")
	fake.callback.call(true)
	var earned: Dictionary=session.simulation.snapshot()
	check(session.simulation.assisted and session.user_paused and session.simulation.supplies==int(frozen.supplies)+40,"Earned callback grants once but leaves player paused")
	fake.callback.call(true)
	for _index in range(2000): session.advance(0.2)
	check(session.simulation.snapshot()==earned and not session.resume(),"Earned long endcard freezes all state; duplicate callback cannot pay; Resume rejects while visible")
	fake.modal=false
	check(session.resume(),"Immediate explicit Resume after dismissal succeeds without intervening frame")
	session.advance(0.1)
	check(session.simulation.elapsed>float(earned.elapsed) and not session.user_paused,"First explicit Resume stays effective after dismissal edge")
	check(not session.request_repair(),"Earned assistance limited once per run")
	session.begin(Missions.campaign(1))
	var before: int=session.simulation.supplies
	check(session.request_repair(),"New run may request its own optional repair")
	fake.callback.call(false); fake.modal=false
	check(not session.simulation.assisted and session.simulation.supplies==before and session.user_paused,"Unearned callback pays nothing and stays paused")
	var stale: Callable=fake.callback
	session.abandon(); session.begin(Missions.campaign(1)); stale.call(true)
	check(not session.simulation.assisted and session.simulation.supplies==int(session.simulation.definition.budget),"Stale previous-run callback cannot grant to new run")
	fake.available=false
	check(not session.request_repair() and not session.reward_pending,"Offline/Web unavailable service never simulates entitlement")
	# Run a genuine no-build natural defeat, then bank only its actual terminal result.
	session.simulation.next_wave()
	for _index in range(20000):
		if session.simulation.status=="ready": session.simulation.next_wave()
		if session.simulation.status in ["won","lost"]: break
		session.advance(0.05)
	check(session.simulation.status in ["won","lost"],"Ordinary unassisted simulation reaches a genuine terminal result")
	check(session.accept_result().recorded and not session.accept_result().recorded and fake.completed_rounds==1,"Actual terminal result banks once and increments natural interstitial cadence once")
	fake.queue_free()

func _replay_witnesses() -> void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/evidence/strategy-witnesses.json"))
	if not parsed is Dictionary:
		check(false,"Strategy witness file must exist before core replay")
		return
	check(parsed.missions.size()==30 and parsed.failed.is_empty(),"Every authored mission has a successful recorded legal strategy")
	for witness in parsed.missions:
		var sim: BastionSimulation=Sim.new(Missions.campaign(int(witness.mission)),{"power":0,"fortify":0})
		var valid: bool=true
		for action in witness.actions:
			while sim.elapsed+0.00001<float(action.at) and sim.status=="running": sim.advance(0.05)
			if absf(sim.elapsed-float(action.at))>0.001: valid=false; break
			match str(action.action):
				"build": valid=sim.supplies==int(action.before) and sim.build(int(action.pad),str(action.kind)) and sim.supplies==int(action.after)
				"upgrade": valid=sim.supplies==int(action.before) and sim.upgrade(int(action.pad)) and sim.supplies==int(action.after)
				"next_wave": valid=sim.next_wave()
				"rally": valid=sim.rally()
				_: valid=false
			if not valid: break
		for _index in range(18000):
			if sim.status!="running": break
			sim.advance(0.05)
		var actual: Dictionary=sim.result()
		var same: bool=true
		for key in actual:
			if actual[key]!=witness.result.get(key): same=false
		if not valid or not same: print("REPLAY DIAGNOSTIC ",witness.mission," legal=",valid," actual=",actual," expected=",witness.result)
		check(valid and sim.status=="won" and not sim.assisted and same,"Mission%02d legal action replay reproduces exact win and accounting"%int(witness.mission))
