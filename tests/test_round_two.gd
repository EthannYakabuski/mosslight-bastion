extends SceneTree
## Synthetic isolated model checks. Not native, balance acceptance or ad proof.
const Sim=preload("res://game/simulation.gd")
const Missions=preload("res://game/missions.gd")
const Progress=preload("res://game/progress.gd")
var checks: int=0
var failures: int=0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(message)
func _init() -> void: call_deferred("run")
func run() -> void:
	var data: Dictionary=Missions.data()
	check(Missions.count()==100 and data.regions.size()==20,"100 missions across 20 regions")
	var baseline_dps: Dictionary={"archer":7.0/.45,"ember":17.0/1.15,"frost":5.0/.8,"prism":34.0/1.35}
	for kind in baseline_dps:
		check(float(Sim.TOWERS[kind].damage)/float(Sim.TOWERS[kind].period)<=float(baseline_dps[kind])*.6,"Substantial tower DPS reduction: "+str(kind))
	var enemies: Dictionary={"sprig":[38.4,.65,0.0,6,1],"runner":[25.0,1.265,0.0,7,1],"shell":[96.0,.46,.6,10,2],"swarm":[20.4,.8,0.0,4,1],"wisp":[55.2,.9,0.0,9,1],"bramble":[210.0,.36,.3,18,3]}
	for key in enemies:
		var e: Dictionary=Sim.ENEMIES[key]
		check([e.hp,e.speed,e.armor,e.bounty,e.leak]==enemies[key],"Round Five requested enemy buff: "+str(key))
	var layouts: Dictionary={}
	for index in range(60):
		var mission: Dictionary=Missions.campaign(index+1)
		check(int(mission.id)==index+1 and int(mission.region)==int(index/5),"Stable mission ID and region "+str(index+1))
		var sim: BastionSimulation=Sim.new(mission)
		check(not sim.routes.is_empty() and sim.pads.size()>=8 and sim.hearts>0,"Real simulator accepts mission "+str(index+1))
		for route in sim.routes:
			check(route.size()>3 and route.all(func(p: Vector2) -> bool:return p.x>=0 and p.y>=0 and p.x<=8 and p.y<=8),"Cardinal in-bounds expanded route "+str(index+1))
		if index>=30:
			var signature: String=JSON.stringify(mission.routes)
			check(not layouts.has(signature),"Distinct new authored route topology "+str(index+1))
			layouts[signature]=true
	check(layouts.size()==30,"Thirty additional distinct route layouts")
	var path: String="user://round-two-model-%d.json"%Time.get_ticks_usec()
	var p: BastionProgress=Progress.new(path,"2026-10-21")
	var legacy: Dictionary=Progress.defaults()
	legacy.day="2026-10-21";legacy.coins=748;legacy.xp=399;legacy.preparation={"power":1,"fortify":2}
	for number in range(1,31):legacy.completed[str(number)]=3;legacy.unassisted_stars[str(number)]=2
	p.data=p._normalize(legacy)
	check(p.data.completed==legacy.completed and p.data.unassisted_stars==legacy.unassisted_stars and p.data.coins==748 and p.data.xp==399 and p.data.preparation==legacy.preparation,"Legacy 30-mission progress and purchases preserved")
	check(p.available(31) and not p.available(32) and not p.available(61),"Legacy completion opens new mission 31 with bounded sequential unlocks")
	p.data.completed["60"]=2;p.data.unassisted_stars["60"]=1
	check(p.save(),"New mission progress saves")
	var restored: BastionProgress=Progress.new(path,"2026-10-21")
	check(restored.data==p.data,"All typed state including mission60 roundtrips")
	print("MOSSLIGHT ROUND TWO checks=%d failures=%d; synthetic isolated model, not native acceptance"%[checks,failures])
	quit(1 if failures else 0)
