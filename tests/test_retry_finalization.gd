extends SceneTree
## Ordinary Viewport controls, controlled production time, isolated save/no-ads fixture.
## No terminal/status/hearts/supplies/currency/result injection. Not native acceptance.
const Main=preload("res://game/main.gd")
const Progress=preload("res://game/progress.gd")
const Harness=preload("res://tests/test_ui.gd")
var game: Control
var checks=0
var failures=0
var paired=true
var runs: Array=[]
func _init() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures+=1;push_error("Retry regression: "+label)
func frames(count: int=3) -> void:
	for index in range(count):await process_frame
func pointer(point: Vector2,pressed: bool) -> void:
	var mouse=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.position=point;mouse.global_position=point;mouse.pressed=pressed
	mouse.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;mouse.device=-1 if paired else 0
	root.push_input(mouse,true)
	if paired:
		var touch=InputEventScreenTouch.new();touch.index=0;touch.position=point;touch.pressed=pressed
		root.push_input(touch,true)
func click(control: Control,label: String) -> void:
	check(is_instance_valid(control) and control.is_visible_in_tree(),"visible actual control "+label)
	if not is_instance_valid(control):return
	var ancestor=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(control);break
		ancestor=ancestor.get_parent()
	await frames()
	var activated={"count":0}
	if control is BaseButton:control.pressed.connect(func():activated.count+=1)
	var point=control.get_global_transform_with_canvas()*(control.size*.5)
	pointer(point,true);await frames(1);pointer(point,false)
	check(activated.count==1,"exactly one UI activation "+label)
	await frames()
func press(key: String) -> void:
	check(game.buttons.has(key) and is_instance_valid(game.buttons[key]) and not game.buttons[key].disabled,"enabled registered action "+key)
	if game.buttons.has(key) and is_instance_valid(game.buttons[key]):await click(game.buttons[key],key)
func pad(index: int) -> void:
	var point=game.board.get_global_transform_with_canvas()*game.board.center(game.session.simulation.pads[index])
	pointer(point,true);await frames(1);pointer(point,false);await frames()
	check(game.selected_pad==index,"ordinary board input selects pad%d"%index)
func natural_win(number: int) -> void:
	check(game.page=="play" and game.session.simulation.status=="ready","legal fresh ready run%d"%number)
	check(int(game.progress.data.run_sequence)==number,"one new run id at Start%d"%number)
	check(game.session.run_id=="2026-10-20:%d"%number,"distinct source-created run id%d"%number)
	await pad(6);await press("build_archer")
	check(game.session.simulation.supplies==55,"Archer spends45 from authored100 budget")
	var ember=false
	var steps=0
	while game.session.simulation.status in ["ready","running"] and steps<2400:
		var sim=game.session.simulation
		if not ember and sim.supplies>=70:
			await pad(2);await press("build_ember");ember=true
			check(sim.tower_at(2).get("kind","")=="ember","legal earned-supply Ember purchase")
		if sim.status=="ready" and not game.buttons.wave.disabled:await press("wave")
		if sim.status=="running" and sim.rally_cooldown<=0 and not sim.enemies.is_empty() and not game.buttons.rally.disabled:await press("rally")
		game._process(0.05)
		steps+=1
		if steps%80==0:await frames(1)
	# Allow real production result dispatch; no direct finish/record or terminal writes.
	for index in range(12):game._process(0.05)
	await frames()
	var sim=game.session.simulation
	var snapshot={"run":number,"run_id":game.session.run_id,"page":game.page,"status":sim.status,"hearts":sim.hearts,"supplies":sim.supplies,"kills":sim.killed,"waves":sim.waves_cleared,"elapsed":sim.elapsed,"banked":game.session.banked,"ending":game._ending,"coins":game.progress.data.coins,"xp":game.progress.data.xp,"rounds":game.progress.data.rounds,"run_sequence":game.progress.data.run_sequence,"credited_runs":game.progress.data.credited_runs.duplicate(),"receipt":game.session.last_receipt.duplicate(true)}
	runs.append(snapshot);print("MOSS_RETRY_NATURAL ",JSON.stringify(snapshot))
	check(sim.status=="won" and sim.killed==10 and sim.waves_cleared==2 and sim.hearts==14 and not sim.assisted,"natural authored two-wave unassisted victory%d"%number)
	check(game.page=="results" and game.session.banked,"natural result shown and banked%d"%number)
	check(int(game.progress.data.rounds)==number and game.progress.data.credited_runs.size()==number,"single bank for each legal run%d"%number)
	if number==1:
		check(int(game.progress.data.coins)==265 and int(game.progress.data.xp)==78,"nerfed first-clear exact source payout115coins78XP")
	else:
		check(int(game.progress.data.coins)==355 and int(game.progress.data.xp)==126,"nerfed replay exact source payout50coins48XP plus40level bonus")
	var bank=game.progress.data.duplicate(true)
	for index in range(40):game._process(0.05)
	await frames()
	check(game.progress.data==bank,"repeated result frames do not duplicate credit%d"%number)
func run() -> void:
	paired=not "--mouse-only" in OS.get_cmdline_user_args()
	create_timer(55.0).timeout.connect(func():push_error("Retry regression exceeded55seconds");quit(2))
	var service=Harness.UIService.new();root.add_child(service)
	game=Main.new();game.progress=Progress.new("user://retry-%d-%d.json"%[OS.get_process_id(),Time.get_ticks_usec()],"2026-10-20")
	game.progress.data.settings.music=false;game.progress.data.settings.sound=false
	game.service_override=service;root.add_child(game);game.set_process(false);await frames()
	check(game.progress.data.coins==150 and game.progress.data.rounds==0 and game.progress.data.run_sequence==0,"fresh isolated default save")
	await press("campaign");await press("mission_1");await press("start")
	await natural_win(1)
	var first_bank=game.progress.data.duplicate(true)
	await press("retry")
	check(game.page=="brief" and game.progress.data==first_bank,"Retry opens brief without Home or new credit")
	await press("start")
	check(game.page=="play" and int(game.progress.data.rounds)==1,"Retry Start keeps first bank until natural second result")
	await natural_win(2)
	check(service.rounds==2,"service cadence sees exactly two natural accepted results")
	check(game.progress.data.credited_runs==["2026-10-20:1","2026-10-20:2"],"two unique credited source run ids")
	check(game.buttons.has("next_level") and not game.buttons.next_level.disabled,"banked campaign win offers Next level")
	var second_bank=game.progress.data.duplicate(true)
	await press("next_level")
	check(game.page=="brief" and int(game.selected_mission.id)==2 and game.progress.data==second_bank,"Next level opens the newly unlocked mission without Home, charge or duplicate credit")
	await press("start")
	check(game.page=="play" and game.session.simulation.status=="ready" and not game._ending and int(game.progress.data.run_sequence)==3,"Next level starts a fresh ordinary battle and resets finalization")
	await press("pause");await press("abandon")
	check(game.page=="home" and int(game.progress.data.rounds)==2,"abandon new level does not fabricate a third bank")
	var restored=Progress.new(game.progress.path,"2026-10-20")
	check(restored.data==game.progress.data and game.progress.last_save_ok,"all typed progress roundtrips after natural retry results")
	print("MOSSLIGHT RETRY CHECKS %d failures %d; mode=%s; ordinary UI and production time; isolated no-ads fixture; no native acceptance"%[checks,failures,"paired" if paired else "mouse"])
	game._music.stop();game._effects.stop();game.queue_free();service.queue_free();await frames(6)
	quit(1 if failures else 0)
