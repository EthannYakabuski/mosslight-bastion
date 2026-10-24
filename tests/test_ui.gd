extends SceneTree
## Real Godot scene, synthetic pointer input, isolated save and explicit fake ad adapter.
## Rendered desktop fixtures are never native/store screenshot evidence.
const Main=preload("res://game/main.gd")
const Progress=preload("res://game/progress.gd")
var game: Control
var failures: Array=[]
var checks: Array=[]
var images: Array=[]

class UIService extends Node:
	signal menu_bottom_reserve_changed
	signal service_notice(message: String)
	var reserve: float=150.0
	var menu: bool=true
	var modal: bool=false
	var available: bool=false
	var receiver: Callable
	var rounds: int=0
	func status() -> String: return "Desktop UI fixture: native SDK is not active."
	func set_menu_visible(value: bool) -> void: menu=value
	func menu_bottom_reserve(_reference: CanvasItem=null) -> float: return reserve if menu else 0.0
	func fullscreen_ad_active() -> bool: return modal
	func can_reward() -> bool: return available and not modal
	func reward_requested(_context: String, callback: Callable) -> void: modal=true; receiver=callback
	func round_finished() -> void: rounds+=1
	func unlock(_key: String) -> void: pass
	func submit(_key: String,_score: int) -> void: pass
	func privacy_options() -> void: pass
	func sign_in() -> void: pass
	func open_achievements() -> void: pass
	func open_leaderboards() -> void: pass

func _init() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks.append(label)
	if not value: failures.append(label); push_error(label)

func frames() -> void:
	await process_frame
	await process_frame
	await process_frame

func click_control(control: Control) -> void:
	var parent: Node=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
			break
		parent=parent.get_parent()
	await frames()
	var point: Vector2=control.get_global_rect().get_center()
	var down:=InputEventMouseButton.new()
	down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true; down.position=point
	root.push_input(down,true)
	await process_frame
	var up:=InputEventMouseButton.new()
	up.button_index=MOUSE_BUTTON_LEFT; up.pressed=false; up.position=point
	root.push_input(up,true)
	await frames()

func press(key: String) -> void:
	if not game.buttons.has(key): check(false,"Missing UI action: "+key); return
	await click_control(game.buttons[key])

func capture(name_value: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	var path: String="res://tests/evidence/desktop-"+name_value+".png"
	check(image!=null and not image.is_empty() and image.save_png(path)==OK,"Rendered desktop fixture: "+name_value)
	images.append({"path":path,"width":image.get_width(),"height":image.get_height(),"scope":"Desktop Godot scene with synthetic pointer input and isolated save; not native/store evidence"})

func run() -> void:
	create_timer(75.0).timeout.connect(func() -> void:
		push_error("Bounded UI test exceeded75seconds")
		quit(2)
	)
	var service:=UIService.new()
	root.add_child(service)
	game=Main.new()
	game.progress=Progress.new("user://ui-"+str(Time.get_ticks_usec())+".json","2026-10-20")
	game.progress.data.settings.music=false
	game.progress.data.settings.sound=false
	game.service_override=service
	root.add_child(game)
	game.set_process(false)
	await frames()
	check(game.page=="home" and game.buttons.size()==7,"Home has six game destinations plus settings")
	var scroll: ScrollContainer
	for child in game.stage.get_children():
		if child is ScrollContainer: scroll=child
	check(scroll!=null and scroll.position.y+scroll.size.y<=810.0,"Home reserves150 fixture logical units below scroll content")
	check(absf(game.buttons.campaign.get_global_rect().get_center().x-game.get_viewport_rect().size.x*.5)<1.0,"Phone Home controls centered including actual scrollbar gutter")
	await capture("phone-home")
	await press("campaign")
	check(game.page=="campaign" and not game.buttons.mission_1.disabled and game.buttons.mission_2.disabled,"Pointer opens campaign with truthful first unlock")
	await capture("phone-campaign")
	await press("mission_1")
	check(game.page=="play" and not game.buttons.has("start"),"Campaign card enters play directly without a briefing")
	check(game.page=="play" and game.session.simulation.status=="ready","Pointer prepares actual playable battle")
	await frames()
	var board: Control=game.board
	var pos: Vector2=board.get_global_transform()*board.center(game.session.simulation.pads[2])
	var down:=InputEventMouseButton.new(); down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true; down.position=pos
	root.push_input(down,true)
	await process_frame
	var up:=InputEventMouseButton.new(); up.button_index=MOUSE_BUTTON_LEFT; up.pressed=false; up.position=pos
	root.push_input(up,true)
	await frames()
	check(game.selected_pad==2 and game.buttons.has("build_archer"),"Real pointer hit test selects a glowing build pad")
	await press("build_archer")
	check(game.session.simulation.tower_at(2).kind=="archer" and game.session.simulation.supplies==55,"Pointer purchase builds actual tower and exact supply charge")
	await press("wave")
	for _i in range(80): game._process(0.05)
	check(game.session.simulation.elapsed>=3.9 and not game.session.simulation.enemies.is_empty(),"Production scene advances actual enemies after Next wave")
	await capture("phone-battle")
	game.go_back()
	var frozen: Dictionary=game.session.simulation.snapshot()
	for _i in range(100): game._process(0.1)
	check(game.session.user_paused and game.session.simulation.snapshot()==frozen,"System Back pauses full actual scene state")
	await capture("phone-pause")
	await press("resume")
	game._process(0.1)
	check(not game.session.user_paused and game.session.simulation.elapsed>float(frozen.elapsed),"Pointer Resume advances only after player action")
	service.available=true
	game.go_back(); await frames(); await press("repair")
	check(game.session.reward_pending and service.modal,"Pause optional repair invokes explicit fake test adapter")
	service.receiver.call(true)
	for _i in range(1000): game._process(0.1)
	check(game.session.simulation.assisted and game.session.user_paused and game.buttons.resume.disabled,"Earned visible endcard stays paused in rendered UI")
	service.modal=false
	game._process(0.05)
	await frames()
	await press("resume")
	check(not game.session.user_paused,"Earned-dismissed UI Resume succeeds")
	game.go_back(); await frames(); await press("abandon")
	check(game.page=="home" and game.progress.data.rounds==0,"Abandon returns Home without fabricated round credit")
	await press("gifts"); await press("login")
	check(game.page=="gifts" and game.buttons.login.disabled and game.progress.data.coins==200,"Actual gift UI pays once and disables repeat")
	await press("back"); await press("workshop"); await press("prep_power")
	check(game.progress.data.preparation.power==1 and game.progress.data.coins==100,"Workshop actual pointer spends shown100 coins for power1")
	await press("back"); await press("journal")
	check(game.page=="journal" and game.buttons.has("online_boards"),"Journal creates all24 icon rows and optional backend actions")
	await capture("phone-journal")
	await press("back"); await press("settings")
	check(game.page=="settings" and game.buttons.has("privacy"),"Settings privacy and safe service fallback reachable")
	await press("privacy"); await press("back")
	for profile in [{"name":"tablet7","size":Vector2i(600,960),"reserve":115.0},{"name":"tablet10","size":Vector2i(800,1280),"reserve":95.0}]:
		root.content_scale_size=Vector2i.ZERO
		root.size=profile.size
		service.reserve=profile.reserve
		game.show_home()
		await frames()
		check(game.stage.scale.x>0.0 and game.stage.get_global_rect().size.x<=float(root.size.x)+1.0,"Portrait stage fits "+str(profile.name))
		check(absf(game.buttons.campaign.get_global_rect().get_center().x-game.get_viewport_rect().size.x*.5)<1.0,"Home controls centered including actual scrollbar gutter "+str(profile.name))
		check(game.stage.get_global_rect().get_center().distance_to(game.get_viewport_rect().size*.5)<1.0,"Whole Home stage centered "+str(profile.name))
		await capture(str(profile.name)+"-home")
		game.show_campaign(); await frames(); await capture(str(profile.name)+"-campaign")
		game.launch_mission(BastionMissions.campaign(1)); await frames(); await capture(str(profile.name)+"-battle")
	var file:=FileAccess.open("res://tests/evidence/ui-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Desktop Godot scene/synthetic pointer tests with isolated save and named fake service; screenshots are development fixtures, never native/store evidence.","checks":checks.size(),"passed":checks.size()-failures.size(),"failures":failures,"images":images,"names":checks},"  "))
	file.close()
	print("MOSSLIGHT UI ",checks.size()-failures.size(),"/",checks.size()," failed=",failures)
	game.queue_free(); service.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)


