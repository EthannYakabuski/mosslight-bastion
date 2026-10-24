extends SceneTree
## Headless real Viewport paired-input regression. Unique fixture save; no native claim.
const Main=preload("res://game/main.gd")
const Progress=preload("res://game/progress.gd")
const Harness=preload("res://tests/test_ui.gd")
var game: Control
var checks=0
var failures=0
var paired=true
var candidate=false
func _init() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures+=1;push_error("Moss dispatch failed: "+label)
func frames(count: int=3) -> void:
	for index in range(count):await process_frame
func send_mouse(point: Vector2,pressed: bool) -> void:
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
	event.position=point;event.global_position=point;event.pressed=pressed
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;event.device=-1 if paired else 0
	root.push_input(event,true)
func send_touch(point: Vector2,pressed: bool) -> void:
	var event=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=pressed
	root.push_input(event,true)
func click(control: Control,key: String,expected: String="") -> void:
	check(is_instance_valid(control) and control.is_visible_in_tree(),"actual visible control "+key)
	if not is_instance_valid(control):return
	var ancestor=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(control);break
		ancestor=ancestor.get_parent()
	await frames()
	var old_stage=game.stage
	var old_actions: Array=[]
	if is_instance_valid(game.action_box):old_actions=game.action_box.get_children()
	var activations={"count":0}
	if control is BaseButton:control.pressed.connect(func():activations.count+=1)
	var point=control.get_global_transform_with_canvas()*(control.size*.5)
	print("MOSS_DISPATCH_BEGIN ",key," mode=",("paired" if paired else "mouse"))
	send_mouse(point,true)
	if paired:send_touch(point,true)
	await frames(1)
	send_mouse(point,false)
	if paired:send_touch(point,false)
	print("MOSS_DISPATCH_RETURN ",key," page=",game.page," target_in_tree=",control.is_inside_tree())
	if not expected.is_empty():check(game.page==expected,"ordinary GUI route "+key)
	check(activations.count==1,"button activates exactly once "+key)
	if candidate:
		check(control.is_inside_tree(),"input target ancestry retained through paired release "+key)
		if game.stage!=old_stage:retirement(old_stage,"stage "+key)
		for previous in old_actions:
			if is_instance_valid(previous) and previous.is_queued_for_deletion():retirement(previous,"action panel "+key)
	await frames()
	var controls=0
	for child in game.get_children():
		if child is Control:controls+=1
	check(controls==1 and game.stage.is_inside_tree() and game.stage.visible,"one usable current stage "+key)
	if candidate and game.page=="play":
		var expected_children=1 if game.selected_pad<0 else (2 if game.session.simulation.tower_at(game.selected_pad).is_empty() else 3)
		check(game.action_box.get_child_count()==expected_children,"no retired action rows or layout gaps "+key)
func retirement(control: Control,label: String) -> void:
	check(control.is_inside_tree() and control.is_queued_for_deletion() and not control.visible and control.mouse_filter==Control.MOUSE_FILTER_IGNORE,"attached hidden noninteractive retirement "+label)
func press(key: String,expected: String="") -> void:
	check(game.buttons.has(key) and is_instance_valid(game.buttons[key]),"registered actual action "+key)
	if game.buttons.has(key) and is_instance_valid(game.buttons[key]):await click(game.buttons[key],key,expected)
func run() -> void:
	paired=not "--mouse-only" in OS.get_cmdline_user_args()
	candidate="--candidate-retirement" in OS.get_cmdline_user_args()
	var service=Harness.UIService.new();root.add_child(service)
	game=Main.new();game.progress=Progress.new("user://dispatch-%d-%d.json"%[OS.get_process_id(),Time.get_ticks_usec()],"2026-10-20")
	game.progress.data.settings.sound=false;game.progress.data.settings.music=false
	game.service_override=service;root.add_child(game);game.set_process(false);await frames()
	await press("journal","journal");await press("back","home")
	await press("settings","settings");await press("back","home")
	await press("campaign","campaign");await press("mission_1","play")
	var point=game.board.get_global_transform_with_canvas()*game.board.center(game.session.simulation.pads[2])
	# Actual board hit-test using the same valid mouse-before-touch event pair.
	send_mouse(point,true)
	if paired:send_touch(point,true)
	send_mouse(point,false)
	if paired:send_touch(point,false)
	await frames();check(game.selected_pad==2,"ordinary board input selects pad2")
	await press("build_archer","play");check(game.session.simulation.tower_at(2).kind=="archer" and game.session.simulation.supplies==55,"ordinary UI builds archer for45 supplies")
	await press("upgrade","play");check(game.session.simulation.tower_at(2).level==2 and game.session.simulation.supplies==21,"ordinary UI upgrades archer for34 supplies")
	await press("sell","play");check(game.session.simulation.tower_at(2).is_empty() and game.session.simulation.supplies==76,"ordinary UI sells tower for55 supplies")
	await press("pause","play");check(game.session.user_paused,"ordinary Pause stops combat")
	await press("resume","play");check(not game.session.user_paused,"ordinary Resume usable")
	await press("pause","play")
	# Named fake adapter's unearned response exercises production signature refresh.
	# No SDK event, earned grant, assisted state or native evidence is simulated.
	service.available=true;game._process(0.0)
	await press("repair","play")
	check(game.session.reward_pending and service.modal and service.receiver.is_valid(),"ordinary Repair control reaches explicit fake adapter")
	var previous_pause=game.pause_layer
	service.modal=false;service.receiver.call(false);game._process(0.0)
	print("MOSS_PAUSE_SIGNATURE_REFRESH old_in_tree=",previous_pause.is_inside_tree())
	if candidate:retirement(previous_pause,"pause signature refresh")
	await frames();check(not is_instance_valid(previous_pause),"old pause layer freed after refresh frame")
	check(not game.session.reward_pending and not game.session.simulation.assisted and game.session.simulation.supplies==76,"unearned fake callback gives no assistance or supplies")
	await press("resume","play");check(not game.session.user_paused,"Resume usable after unearned fixture response")
	await press("pause","play");await press("abandon","home")
	check(not game.session.simulation.assisted and int(game.progress.data.rounds)==0 and int(game.progress.data.xp)==0,"no injected assistance, credited result or XP")
	print("MOSSLIGHT UI DISPATCH CHECKS %d failures %d; real Viewport events; isolated fixture; no native acceptance"%[checks,failures])
	game._music.stop();game._effects.stop();game.queue_free();service.queue_free();await frames(6)
	quit(1 if failures else 0)
