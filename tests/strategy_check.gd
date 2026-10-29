extends SceneTree
## Real production simulator, legal actions only, zero persistent preparation.
const Sim = preload("res://game/simulation.gd")
const Missions = preload("res://game/missions.gd")
var witnesses: Array = []
var failures: Array = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	for number in range(1,Missions.count()+1):
		var best: Dictionary = {}
		for strategy in range(12):
			var attempt: Dictionary = solve(Missions.campaign(number),strategy)
			if attempt.result.won:
				assert(int(attempt.observed_bosses)==1,"Winning production run must actually spawn its final-wave boss")
				assert(int(attempt.result.waves)==Missions.campaign(number).waves.size(),"Each authored wave resolves exactly once")
				best=attempt
				break
		if best.is_empty():
			failures.append(number)
			print("MISSION FAIL ",number)
		else:
			witnesses.append(best)
			print("MISSION PASS ",number," hearts=",best.result.hearts," stars=",best.result.stars," strategy=",best.strategy," actions=",best.actions.size())
	var file := FileAccess.open("res://tests/evidence/strategy-witnesses.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Production deterministic model with automatic wave timers; legal build/upgrade/Rally/advance only, no manual wave inputs; zero preparation or earned assistance. Not native QA.","missions":witnesses,"failed":failures},"  "))
	file.close()
	quit(0 if failures.is_empty() else 1)

func coverage(sim: BastionSimulation, pad: int, kind: String) -> float:
	var score: float=0.0
	for route in sim.routes:
		for point in route:
			if sim.pads[pad].distance_to(point)<=float(Sim.TOWERS[kind].range): score+=1.0
	return score

func purchase(sim: BastionSimulation, strategy: int, actions: Array) -> void:
	var orders: Array = [["archer","ember","frost","prism"],["ember","archer","prism","frost"],["prism","ember","archer","frost"],["archer","archer","ember","prism"],["ember","frost","archer","prism"],["prism","prism","ember","archer"]]
	for _attempt in range(12):
		var kind: String = orders[strategy%orders.size()][sim.towers.size()%4]
		var best_pad: int=-1
		var best_score: float=-INF
		for pad in range(sim.pads.size()):
			if not sim.tower_at(pad).is_empty(): continue
			var score: float=coverage(sim,pad,kind)
			for tower in sim.towers:
				if sim.pads[pad].distance_to(sim.pads[int(tower.pad)])<2.0: score*=0.75
			if score>best_score:
				best_score=score
				best_pad=pad
		var prefer_upgrade: bool = strategy>=6 and sim.towers.size()>=2
		var up_pad: int=-1
		for tower in sim.towers:
			if sim.upgrade_cost(int(tower.pad))>0 and sim.supplies>=sim.upgrade_cost(int(tower.pad)):
				up_pad=int(tower.pad)
				break
		if prefer_upgrade and up_pad>=0:
			var before: int=sim.supplies
			assert(sim.upgrade(up_pad))
			actions.append({"at":sim.elapsed,"wave":sim.wave_index,"action":"upgrade","pad":up_pad,"before":before,"after":sim.supplies})
		elif best_pad>=0 and sim.supplies>=int(Sim.TOWERS[kind].cost):
			var before: int=sim.supplies
			assert(sim.build(best_pad,kind))
			actions.append({"at":sim.elapsed,"wave":sim.wave_index,"action":"build","pad":best_pad,"kind":kind,"before":before,"after":sim.supplies})
		elif best_pad<0 and up_pad>=0:
			var before: int=sim.supplies
			assert(sim.upgrade(up_pad))
			actions.append({"at":sim.elapsed,"wave":sim.wave_index,"action":"upgrade","pad":up_pad,"before":before,"after":sim.supplies})
		else: break

func solve(mission: Dictionary, strategy: int) -> Dictionary:
	var sim: BastionSimulation=Sim.new(mission,{"power":0,"fortify":0})
	var actions: Array=[]
	var steps: int=0
	var boss_ids: Dictionary={}
	while sim.status in ["ready","running"] and steps<18000:
		if steps%10==0: purchase(sim,strategy,actions)
		if sim.rally_cooldown<=0 and not sim.enemies.is_empty():
			assert(sim.rally())
			actions.append({"at":sim.elapsed,"action":"rally"})
		sim.advance(Sim.DT)
		for enemy in sim.enemies:
			if bool(Sim.ENEMIES[str(enemy.type)].get("boss",false)):boss_ids[int(enemy.id)]=true
		steps+=1
	return {"mission":int(mission.id),"name":str(mission.name),"budget":int(mission.budget),"preparation":{"power":0,"fortify":0},"strategy":strategy,"observed_bosses":boss_ids.size(),"actions":actions,"result":sim.result()}
