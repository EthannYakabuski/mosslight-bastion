extends SceneTree
## Bounded desktop fixture: real Viewport input, isolated progress, no native/SDK claim.
const Main=preload("res://game/main.gd")
const Progress=preload("res://game/progress.gd")
const Missions=preload("res://game/missions.gd")
const Harness=preload("res://tests/test_ui.gd")
var app: Control
var checks: int=0
var failures: Array[String]=[]
var images: Array=[]

func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);push_error("Round Four: "+label)
func frames() -> void:
	for index in range(4): await process_frame
func tap(control: Control) -> void:
	var parent: Node=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer: parent.ensure_control_visible(control);break
		parent=parent.get_parent()
	await frames()
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*0.5)
	var activated={"count":0}
	var is_button: bool=control is BaseButton
	if is_button: control.pressed.connect(func():activated.count+=1)
	for down in [true,false]:
		var mouse:=InputEventMouseButton.new()
		mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=point;mouse.global_position=point
		mouse.pressed=down;mouse.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;mouse.device=-1
		root.push_input(mouse,true)
		var touch:=InputEventScreenTouch.new();touch.index=0;touch.position=point;touch.pressed=down
		root.push_input(touch,true)
		await process_frame
	await frames()
	if is_button: check(activated.count==1,"paired GUI action exactly once")
func press(key: String) -> void:
	check(app.buttons.has(key),"registered "+key)
	if app.buttons.has(key): await tap(app.buttons[key])
func capture(label: String) -> void:
	var folder: String=OS.get_environment("MOSS_R4_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(folder)
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	check(image.save_png(folder.path_join(label+".png"))==OK,"rendered fixture "+label)
	images.append(label+".png")

func run() -> void:
	create_timer(70).timeout.connect(func():push_error("Bounded Moss Round Four UI timeout");quit(2))
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(540,960)
	var service=Harness.UIService.new();root.add_child(service)
	app=Main.new()
	app.progress=Progress.new("user://round-four-%d-%d.json"%[OS.get_process_id(),Time.get_ticks_usec()],"2026-10-24")
	app.progress.data.settings.music=false;app.progress.data.settings.sound=false
	app.service_override=service;root.add_child(app);app.set_process(false);await frames()
	check(app.find_child("HomeKeep",true,false)!=null,"Home uses the new illustrated keep")
	for profile in [["phone",540,960],["tablet7",600,960],["tablet10",800,1280]]:
		root.size=Vector2i(profile[1],profile[2]);app.show_home();await frames()
		check(absf(app.buttons.campaign.get_global_rect().get_center().x-root.size.x*0.5)<1.0,"Home centered "+str(profile[0]))
		await capture(str(profile[0])+"-home")
		await press("campaign")
		check(app.page=="campaign" and app.buttons.mission_1.get_combined_minimum_size().y>=110,"concise touch campaign cards")
		for number in range(1,61):
			var card: Button=app.buttons["mission_"+str(number)]
			var mission: Dictionary=Missions.campaign(number)
			var icons: Node=card.find_child("MissionEnemies",true,false)
			check(icons!=null and icons.get_child_count()==app._mission_enemy_types(mission).size(),"all actual foe types shown on card%d"%number)
			check(card.tooltip_text.begins_with("%d waves"%mission.waves.size()),"actual wave count card%d"%number)
			check(card.disabled==not app.progress.available(number),"lock unchanged card%d"%number)
		await capture(str(profile[0])+"-campaign")
		var run_sequence: int=int(app.progress.data.run_sequence)
		await press("mission_1")
		check(app.page=="play" and not app.buttons.has("start") and int(app.progress.data.run_sequence)==run_sequence+1,"one card press directly enters one run")
		check(app.keep_health.value==app.session.simulation.hearts and app.keep_health.max_value==app.session.simulation.max_hearts,"health gauge exact initial value")
		app._select_pad(2);await frames()
		for kind in BastionSimulation.TOWERS:
			var button: Button=app.buttons["build_"+str(kind)]
			check(button.icon is AtlasTexture and not "range" in button.text.to_lower(),"illustrated concise guardian "+str(kind))
			check(button.get_global_rect().end.x<=root.size.x+1.0 and button.get_global_rect().end.y<=root.size.y+1.0,"guardian fits "+str(profile[0])+str(kind))
		await capture(str(profile[0])+"-build")
		app._pause();app._abandon();await frames()
	app.launch_mission(Missions.campaign(1));await frames()
	var starting_rounds: int=int(app.progress.data.rounds)
	for speed in [1,2,3,4]:
		if speed>1: await press("speed")
		check(app._speed==float(speed) and app.buttons.speed.text=="%dx"%speed,"visible speed %dx"%speed)
		# Real wave time, including at 100ms/frame; no skip from the simulation clamp.
		if speed==1: await press("wave")
		var before: float=app.session.simulation.elapsed
		app._process(0.1)
		check(is_equal_approx(app.session.simulation.elapsed-before,0.1*speed),"actual simulated time %dx"%speed)
	await press("speed");check(app._speed==1.0,"speed cycles back to1x")
	app._pause();await frames()
	var frozen: Dictionary=app.session.simulation.snapshot()
	for index in range(5): app._process(0.1)
	app._toggle_speed()
	check(app.session.simulation.snapshot()==frozen and app._speed==1.0,"pause freezes all speed options")
	app._resume();await frames()
	var observed={"count":0,"damage":0}
	app.session.simulation.base_damaged.connect(func(amount: int):observed.count+=1;observed.damage+=amount)
	var original_hearts: int=app.session.simulation.hearts
	for index in range(1400):
		if observed.count>0: break
		app._process(0.05)
	check(observed.count>0 and app.session.simulation.hearts==original_hearts-int(observed.damage),"ordinary unbuilt wave naturally damages keep and emits exact damage")
	check(app.keep_health.value==app.session.simulation.hearts and app.board.damage_flash>0.0,"health gauge and keep hit flash follow actual leak")
	check(app.battle_note.text.ends_with("%d reached the keep"%app.session.simulation.leaked),"damage event updates the leak footer consistently")
	check(app._damage_effects.stream!=null and app._damage_effects.stream.resource_path.ends_with("base-impact.ogg"),"dedicated licensed damage cue wired")
	check(int(app.progress.data.rounds)==starting_rounds,"unfinished defense has no invented payout")
	await capture("actual-source-leak-health")
	app._pause();app._abandon();await frames()
	check(app.page=="home","Back/Pause/Abandon usable after direct launch")
	var report={"scope":"Real desktop Viewport paired-input and deterministic source fixture with isolated progress and named fake services; not native/device/SDK/audio proof.","checks":checks,"failures":failures,"images":images}
	var report_path: String=OS.get_environment("MOSS_R4_REPORT")
	if not report_path.is_empty():
		var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("MOSS_ROUND_FOUR ",checks," checks; failures=",failures)
	app._music.stop();app._effects.stop();app._damage_effects.stop()
	app.queue_free();service.queue_free();await frames()
	quit(0 if failures.is_empty() else 1)
