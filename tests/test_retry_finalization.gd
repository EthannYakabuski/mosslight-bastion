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
	var before_coins: int=int(game.progress.data.coins)
	var before_xp: int=int(game.progress.data.xp)
	var witnesses: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/evidence/strategy-witnesses.json"))
	var witness: Dictionary=witnesses.missions[0]
	check(int(witness.mission)==1 and bool(witness.result.won),"first mission has a production legal-action witness")
	for action in witness.actions:
		while game.session.simulation.elapsed+0.00001<float(action.at) and game.session.simulation.status in ["ready","running"]:
			game._process(0.05)
		match str(action.action):
			"build":
				await pad(int(action.pad));await press("build_"+str(action.kind))
			"upgrade":
				await pad(int(action.pad));await press("upgrade")
			"rally": await press("rally")
			"next_wave": await press("wave")
	for step in range(18000):
		if game.page=="results":break
		game._process(0.05)
		if step%80==0:await frames(1)
	await frames()
	var sim=game.session.simulation
	var actual: Dictionary=sim.result()
	var differences: Dictionary={}
	for key in actual:
		if actual[key]!=witness.result.get(key):differences[key]={"actual":actual[key],"expected":witness.result.get(key)}
	if actual!=witness.result:print("RETRY EXACT RESULT DIAGNOSTIC direct_dictionary_equal=false scalar_differences=",differences," actual=",actual," expected=",witness.result)
	# JSON numbers parse as floats. Compare the complete key set and every exact
	# scalar as the independent core replay does, without type-strict Dictionary==.
	check(sim.status=="won" and actual.size()==witness.result.size() and differences.is_empty() and not sim.assisted,"ordinary UI reproduces the legal five-wave boss victory%d"%number)
	check(game.page=="results" and game.session.banked,"natural result shown and banked%d"%number)
	check(int(game.progress.data.rounds)==number and game.progress.data.credited_runs.size()==number,"single bank for each legal run%d"%number)
	var first: bool=number==1
	var gained_xp: int=sim.killed*2+sim.waves_cleared*4+(50 if first else 20)
	var bonus: int=(Progress.level_for(before_xp+gained_xp)-Progress.level_for(before_xp))*40
	var earned_coins: int=sim.killed*2+(95 if first else 30)+bonus
	check(game.progress.data.coins==before_coins+earned_coins and game.progress.data.xp==before_xp+gained_xp,"natural first/replay exact bank and level bonus%d"%number)
	check(game.platform().menu and game._reserve()>0.0,"results request native bottom banner and reserve its space")
	var star_row: Node=game.find_child("MissionStars",true,false)
	check(star_row!=null and star_row.get_child_count()==3,"result uses three filled/unfilled Kenney stars")
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
	await press("campaign");await press("mission_1")
	await natural_win(1)
	var first_bank=game.progress.data.duplicate(true)
	await press("retry")
	check(game.page=="play" and int(game.progress.data.run_sequence)==2,"Retry directly starts exactly one new ordinary run")
	var retry_bank=game.progress.data.duplicate(true);retry_bank.run_sequence=first_bank.run_sequence
	check(retry_bank==first_bank,"direct Retry preserves all prior banked fields except the new run sequence")
	check(game.page=="play" and int(game.progress.data.rounds)==1,"Direct Retry keeps first bank until natural second result")
	await natural_win(2)
	check(service.rounds==2,"service cadence sees exactly two natural accepted results")
	check(game.progress.data.credited_runs==["2026-10-20:1","2026-10-20:2"],"two unique credited source run ids")
	check(game.buttons.has("next_level") and not game.buttons.next_level.disabled,"banked campaign win offers Next level")
	var second_bank=game.progress.data.duplicate(true)
	await press("next_level")
	check(game.page=="play" and int(game.selected_mission.id)==2 and int(game.progress.data.rounds)==2,"Next level starts unlocked mission directly without duplicate credit")
	var next_bank=game.progress.data.duplicate(true);next_bank.run_sequence=second_bank.run_sequence
	check(next_bank==second_bank,"direct Next preserves all prior banked fields except the new run sequence")
	check(game.page=="play" and game.session.simulation.status=="ready" and not game._ending and int(game.progress.data.run_sequence)==3,"Next level starts a fresh ordinary battle and resets finalization")
	await press("pause");await press("abandon")
	check(game.page=="home" and int(game.progress.data.rounds)==2,"abandon new level does not fabricate a third bank")
	var restored=Progress.new(game.progress.path,"2026-10-20")
	check(restored.data==game.progress.data and game.progress.last_save_ok,"all typed progress roundtrips after natural retry results")
	print("MOSSLIGHT RETRY CHECKS %d failures %d; mode=%s; ordinary UI and production time; isolated no-ads fixture; no native acceptance"%[checks,failures,"paired" if paired else "mouse"])
	game._music.stop();game._effects.stop();game.queue_free();service.queue_free();await frames(6)
	quit(1 if failures else 0)
