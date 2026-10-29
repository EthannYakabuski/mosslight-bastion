extends SceneTree
## Isolated production-model/scene fixture. No native SDK or human balance claim.
const Sim=preload("res://game/simulation.gd")
const Missions=preload("res://game/missions.gd")
const Progress=preload("res://game/progress.gd")
const Main=preload("res://game/main.gd")
const Board=preload("res://game/board.gd")
const Harness=preload("res://tests/test_ui.gd")
var checks: int=0
var failures: Array[String]=[]

func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);push_error("Round Five: "+label)

func _initialize() -> void: call_deferred("run")

func frames() -> void:
	for index in range(4): await process_frame

func run() -> void:
	_test_content()
	_test_automatic_waves()
	_test_splitter_accounting()
	_test_records_and_saves()
	await _test_star_and_banner_scene()
	print("MOSSLIGHT_ROUND_FIVE checks=%d failures=%d; source/scene fixtures only, no native or human balance acceptance"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_content() -> void:
	check(Missions.count()==100 and Missions.data().regions.size()==20,"100 missions across twenty regions")
	var new_layouts: Dictionary={}
	var boss_types: Dictionary={}
	for number in range(1,101):
		var mission: Dictionary=Missions.campaign(number)
		check(int(mission.id)==number and mission.waves.size()>=5 and mission.waves.size()<=10,"stable mission ID and 5-10 waves %d"%number)
		var has_boss: bool=false
		for group in mission.waves[-1]:
			if bool(Sim.ENEMIES[str(group.type)].get("boss",false)):
				has_boss=true;boss_types[str(group.type)]=true
		check(has_boss,"final wave has an actual boss %d"%number)
		var sim: BastionSimulation=Sim.new(mission)
		for index in range(mission.waves.size()):
			var duration: float=sim.wave_duration(index)
			for group in mission.waves[index]:
				var traits: Dictionary=Sim.ENEMIES[str(group.type)]
				var tail: float=float(group.get("delay",0.0))+maxi(0,int(group.count)-1)*float(group.interval)
				var travel: float=float(sim.routes[int(group.route)].size()-1)/float(traits.speed)
				check(duration>=tail+travel,"timer includes spawn tail and ordinary path travel %d/%d"%[number,index])
		if number>60:
			var signature: String=JSON.stringify(mission.routes)
			check(not new_layouts.has(signature),"new route coordinate layout distinct %d"%number)
			new_layouts[signature]=true
	check(new_layouts.size()==40 and boss_types.size()==3,"forty added layouts and three distinct boss roles")
	check(is_equal_approx(float(Sim.ENEMIES.runner.speed),1.1*1.15),"existing fast runner speed increases exactly15percent")
	for row in [["sprig",32.0],["shell",80.0],["swarm",17.0],["wisp",46.0],["bramble",175.0]]:
		check(is_equal_approx(float(Sim.ENEMIES[str(row[0])].hp),float(row[1])*1.2),"existing non-fast enemy health increases20percent "+str(row[0]))
	check(Sim.ENEMIES.size()==12 and Board.ENEMY_SHEETS.size()==12,"twelve actual enemy roles have supplied monster-sheet art")
	for kind in Sim.ENEMIES:
		var icon: AtlasTexture=Board.enemy_icon(str(kind))
		check(icon.atlas!=null and icon.region.size==Vector2(192,192),"full aligned first animation frame "+str(kind))

func _test_automatic_waves() -> void:
	var sim: BastionSimulation=Sim.new(Missions.campaign(1))
	for index in range(161):sim.advance(Sim.DT)
	check(sim.wave_index==0 and sim.status=="running" and not sim.enemies.is_empty(),"first wave starts after its countdown without a Next-wave input")
	sim.paused=true
	var frozen: Dictionary=sim.snapshot()
	for index in range(200):sim.advance(0.25)
	check(sim.snapshot()==frozen,"pause freezes automatic countdown and all wave accounting")
	sim.paused=false
	for index in range(200):sim.advance(0.25,true)
	check(sim.snapshot()==frozen,"fullscreen platform block freezes timed waves")
	var definition: Dictionary={"id":1,"mode":"campaign","name":"Overlap fixture","routes":[[[0,4],[8,4]]],"pads":[[2,3],[6,3]],"budget":110,"hearts":100,"hp_scale":1.0,
		"waves":[[{"type":"elderroot","count":1,"interval":1.0,"route":0,"delay":0.0,"hp_multiplier":10.0}],[{"type":"sprig","count":1,"interval":1.0,"route":0,"delay":0.0}]]}
	var overlap: BastionSimulation=Sim.new(definition)
	check(overlap.build(0,"frost") and overlap.build(1,"frost"),"legal frost towers prepare the automatic-overlap fixture")
	for index in range(1300):
		overlap.advance(Sim.DT)
		if overlap.wave_index==1:break
	check(overlap.wave_index==1 and overlap.enemies.any(func(enemy: Dictionary)->bool:return int(enemy.wave)==0),"scheduled next wave starts even when a slow older foe remains")
	check(overlap._wave_remaining.has(0) and overlap._wave_remaining.has(1),"overlapping wave accounting preserves both groups")

func _test_splitter_accounting() -> void:
	var mission: Dictionary=Missions.campaign(1)
	mission.waves=[[{"type":"broodmother","count":1,"interval":1.0,"route":0,"delay":0.0}]]
	var sim: BastionSimulation=Sim.new(mission)
	check(sim.next_wave(),"splitter fixture begins through ordinary wave API")
	sim.advance(Sim.DT)
	var target: Dictionary=sim.enemies[0]
	sim._hit({"kind":"prism","damage":10000.0,"splash":0.0,"slow":0.0},target)
	sim.advance(Sim.DT)
	check(sim.enemies.size()==4 and sim.enemies.all(func(enemy: Dictionary)->bool:return str(enemy.type)=="swarm"),"broodroot defeat creates four actual child enemies")
	check(sim.status=="running" and sim.waves_cleared==0 and int(sim._wave_remaining.get(0,0))==4,"children keep the final wave alive and cannot award an early win")
	for child in sim.enemies.duplicate():sim._hit({"kind":"prism","damage":10000.0,"splash":0.0,"slow":0.0},child)
	sim.advance(Sim.DT)
	check(sim.status=="won" and sim.killed==5 and sim.waves_cleared==1,"final wave resolves once after all four children, with correct kills")

func _test_records_and_saves() -> void:
	var path: String="user://moss-r5-%d.json"%Time.get_ticks_usec()
	var saved: BastionProgress=Progress.new(path,"2026-10-29")
	var legacy: Dictionary=Progress.defaults()
	legacy.completed={"1":3,"60":2};legacy.unassisted_stars={"1":1};legacy.coins=748;legacy.xp=399
	saved.data=saved._normalize(legacy)
	check(saved.data.completed==legacy.completed and saved.data.coins==748 and saved.data.xp==399,"old banked clears/currency/XP survive expansion")
	check(saved.available(61) and not saved.available(62) and not saved.available(101),"sixtieth clear unlocks61 with bounded sequential progression")
	check(saved.leaderboard_values().unassisted_stars==5,"legacy leaderboard key now includes all genuinely saved campaign stars")
	var base: Dictionary={"finished":true,"won":true,"mode":"campaign","mission":61,"day":"2026-10-29","kills":12,"waves":8,"stars":3,"built":3,"upgrades":1,"rallies":1,"assisted":true,"score":3000}
	var id: String=saved.begin_run()
	check(saved.record_result(id,base).recorded and saved.leaderboard_values().unassisted_stars==8,"earned-assisted campaign stars set the same competitive total")
	var balance: int=saved.data.coins
	check(not saved.record_result(id,base).recorded and saved.data.coins==balance,"duplicate callbacks/results cannot pay twice")
	base.mode="endless";base.won=false;base.score=5000
	saved.record_result(saved.begin_run(),base)
	check(saved.data.best_endless.score==5000,"earned-assisted endless updates the ordinary competitive best")
	base.mode="daily";base.won=true;base.score=6000
	saved.record_result(saved.begin_run(),base)
	check(saved.data.best_daily.get("2026-10-29")==6000,"earned-assisted daily updates today's ordinary competitive best")
	saved.data.completed["99"]=2;saved.data.completed["100"]=3
	check(saved.save(),"100-mission progress persists")
	var loaded: BastionProgress=Progress.new(path,"2026-10-29")
	check(loaded.data==saved.data and loaded.data.completed.get("100")==3,"hundredth mission survives an actual cold model reload")

func _test_star_and_banner_scene() -> void:
	var native=Harness.UIService.new();root.add_child(native)
	var app: Control=Main.new()
	app.progress=Progress.new("user://moss-r5-ui-%d.json"%Time.get_ticks_usec(),"2026-10-29")
	app.progress.data.settings.music=false;app.progress.data.settings.sound=false
	app.progress.data.completed={"1":2};app.service_override=native
	root.add_child(app);app.set_process(false);await frames()
	for profile in [Vector2i(540,960),Vector2i(600,960),Vector2i(800,1280)]:
		root.size=profile;app.show_campaign();await frames()
		check(app.buttons.has("mission_100"),"all100 campaign cards available to browse")
		var stars: Node=app.buttons.mission_1.find_child("MissionStars",true,false)
		check(stars!=null and stars.get_child_count()==3,"campaign uses three actual Kenney star textures")
		for i in range(3):
			var image: TextureRect=stars.get_child(i)
			check(image.texture==app.STAR_FILLED if i<2 else image.texture==app.STAR_EMPTY,"filled/empty icon exactly matches saved stars")
		check(not "2/3 stars" in app.buttons.mission_1.tooltip_text,"campaign no longer substitutes a star text fraction")
		app.show_home();await frames()
	app.launch_mission(Missions.campaign(1));await frames()
	for index in range(6000):
		if app.session.simulation.status=="lost":break
		app._process(Sim.DT)
	check(app.session.simulation.status=="lost" and app.session.user_paused,"ordinary unbuilt defense reaches a real paused loss")
	app._finish_result();await frames()
	check(app.page=="results" and native.menu and app.session.banked,"actual accepted loss requests a result banner")
	var empty_stars: Node=app.stage.find_child("MissionStars",true,false)
	check(empty_stars!=null and empty_stars.get_child_count()==3,"loss results use three empty star textures")
	for image in empty_stars.get_children():check(image.texture==app.STAR_EMPTY,"no false earned star on a real loss")
	var bank: Dictionary=app.progress.data.duplicate(true)
	native.reserve=220.0;native.menu_bottom_reserve_changed.emit();await frames()
	for child in app.stage.get_children():
		if child is ScrollContainer:check(child.position.y+child.size.y<=960.0-app._reserve(),"result content stays above banner and bottom safe reserve")
	check(app.progress.data==bank,"result banner metric rebuild cannot bank a second reward")
	native.reserve=240.0;native.menu_bottom_reserve_changed.emit();app.show_home();await frames()
	check(app.page=="home" and app.progress.data==bank,"queued result banner metrics cannot reopen Results after Home navigation")
	var current_stage: int=app.stage.get_instance_id()
	app._refresh_menu_metrics("home",str(app.session.run_id)+"-older")
	check(app.stage.get_instance_id()==current_stage and app.progress.data==bank,"stale run banner metrics cannot rebuild the current page or re-bank")
	app._music.stop();app._effects.stop();app._damage_effects.stop()
	app.queue_free();native.queue_free();await frames()
