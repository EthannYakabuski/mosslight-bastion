extends Control
const Progress = preload("res://game/progress.gd")
const Missions = preload("res://game/missions.gd")
const Session = preload("res://game/session.gd")
const Board = preload("res://game/board.gd")
const INK := Color("eef0cf")
const MUTED := Color("b6cbb2")
const GOLD := Color("efd58e")
var progress: BastionProgress
var session: BastionSession
var service_override: Node
var stage: Control
var page: String = "home"
var selected_mission: Dictionary = {}
var selected_pad: int = -1
var buttons: Dictionary = {}
var board: BastionBoard
var status_label: Label
var battle_hud: Label
var battle_note: Label
var action_box: VBoxContainer
var pause_layer: PanelContainer
var _music: AudioStreamPlayer
var _effects: AudioStreamPlayer
var _toast_text: String = ""
var _elapsed_ui: float = 0.0
var _last_battle_status: String = ""
var _ending: bool = false
var _speed: float = 1.0
var _pause_signature: String = ""
var _home_gutter: MarginContainer

func platform() -> Node:
	return service_override if is_instance_valid(service_override) else get_node_or_null("/root/Services")

func _ready() -> void:
	if progress==null: progress=Progress.new()
	progress.save()
	session=Session.new(progress,platform())
	var theme_resource := Theme.new()
	theme_resource.default_font_size=18
	theme=theme_resource
	_music=AudioStreamPlayer.new()
	_music.stream=load("res://assets/audio/woodland.ogg.wav")
	_music.volume_db=-14
	add_child(_music)
	_music.finished.connect(func() -> void:
		if bool(progress.data.settings.music): _music.play()
	)
	_effects=AudioStreamPlayer.new()
	add_child(_effects)
	_apply_audio()
	get_viewport().size_changed.connect(_fit)
	var native: Node = platform()
	if native!=null and native.has_signal("menu_bottom_reserve_changed"): native.menu_bottom_reserve_changed.connect(_menu_metrics_changed)
	if native!=null and native.has_signal("service_notice"): native.service_notice.connect(func(message: String) -> void: _toast_text=message)
	show_home()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_GO_BACK_REQUEST: go_back()
	if what==NOTIFICATION_APPLICATION_PAUSED and session!=null:
		session.pause()
		if page=="play": _show_pause()

func _apply_audio() -> void:
	if bool(progress.data.settings.music):
		if not _music.playing: _music.play()
	else: _music.stop()

func _click(confirm: bool = false) -> void:
	if not bool(progress.data.settings.sound): return
	_effects.stream=load("res://assets/audio/confirmation_002.ogg" if confirm else "res://assets/audio/click_002.ogg")
	_effects.play()

func _fit() -> void:
	if stage==null: return
	var view: Vector2 = get_viewport_rect().size
	var scale_value: float = minf(view.x/540.0,view.y/960.0)
	stage.scale=Vector2.ONE*scale_value
	stage.position=(view-Vector2(540,960)*scale_value)*0.5

func _reserve() -> float:
	var native: Node = platform()
	if page!="home" or native==null or not native.has_method("menu_bottom_reserve"): return 0.0
	var scale_value: float = stage.scale.y if stage!=null else 1.0
	return maxf(0.0,float(native.menu_bottom_reserve(self))/maxf(0.01,scale_value))

func _menu_metrics_changed() -> void:
	if page=="home": show_home.call_deferred()

func _style(color: Color, border: Color = Color("577e61")) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color=color
	result.border_color=border
	result.set_border_width_all(1)
	result.set_corner_radius_all(10)
	result.content_margin_left=12
	result.content_margin_right=12
	result.content_margin_top=10
	result.content_margin_bottom=10
	return result

func _label(text: String, font_size: int = 18, color: Color = INK) -> Label:
	var result := Label.new()
	result.text=text
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

func _button(text: String, action: Callable, key: String = "", small: bool = false) -> Button:
	var result := Button.new()
	result.text=text
	result.custom_minimum_size=Vector2(0,44 if small else 56)
	result.add_theme_font_size_override("font_size",16 if small else 18)
	result.add_theme_color_override("font_color",INK)
	result.add_theme_color_override("font_disabled_color",Color("839682"))
	result.add_theme_stylebox_override("normal",_style(Color("284b3e")))
	result.add_theme_stylebox_override("hover",_style(Color("365d48"),GOLD))
	result.add_theme_stylebox_override("pressed",_style(Color("1c392e"),GOLD))
	result.add_theme_stylebox_override("disabled",_style(Color("243d34"),Color("3c5747")))
	result.pressed.connect(func() -> void: _click(); action.call())
	if not key.is_empty(): buttons[key]=result
	return result

func _retire_ui(control: Control) -> void:
	# Paired touch release may still inspect this control after its mouse callback.
	# Keep it attached, hidden and noninteractive until queued deletion completes.
	control.hide()
	control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	control.name="RetiredUI-%d"%control.get_instance_id()
	control.queue_free()

func _page(name_value: String, title: String, subtitle: String) -> VBoxContainer:
	_home_gutter=null
	page=name_value
	buttons.clear()
	board=null
	pause_layer=null
	_pause_signature=""
	if stage!=null:
		_retire_ui(stage)
	stage=Control.new()
	stage.size=Vector2(540,960)
	add_child(stage)
	_fit()
	var background := ColorRect.new()
	background.color=Color("112c29")
	background.size=Vector2(540,960)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(background)
	var heading := _label(title,28,GOLD)
	heading.position=Vector2(20,20)
	heading.size=Vector2(500,42)
	if name_value=="home": heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(heading)
	var sub := _label(subtitle,16,MUTED)
	sub.position=Vector2(20,66)
	sub.size=Vector2(500,64)
	if name_value=="home": sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(sub)
	var native: Node = platform()
	if native!=null and native.has_method("set_menu_visible"): native.set_menu_visible(page=="home")
	var scroll := ScrollContainer.new()
	scroll.position=Vector2(18,142)
	scroll.size=Vector2(504,maxf(260,960-154-_reserve()))
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	stage.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	if name_value=="home":
		_home_gutter=MarginContainer.new()
		_home_gutter.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		scroll.add_child(_home_gutter)
		_home_gutter.add_child(content)
		scroll.get_v_scroll_bar().visibility_changed.connect(_center_home_menu)
		_center_home_menu.call_deferred()
	else: scroll.add_child(content)
	return content

func _center_home_menu() -> void:
	# A visible right scrollbar reduces the content viewport. Reserve the same
	# gutter on the left so real Home controls stay centered under the heading.
	if page!="home" or not is_instance_valid(_home_gutter): return
	var scroll: ScrollContainer=_home_gutter.get_parent() as ScrollContainer
	var bar: VScrollBar=scroll.get_v_scroll_bar()
	_home_gutter.add_theme_constant_override("margin_left",ceili(bar.get_combined_minimum_size().x) if bar.visible else 0)

func _footer(content: VBoxContainer) -> void:
	var label := _label("Progress saves on this device. Optional online services never gate play.",14,MUTED)
	content.add_child(label)
	var spacer := Control.new()
	spacer.custom_minimum_size=Vector2(1,24)
	content.add_child(spacer)

func _record_heading(content: VBoxContainer, text: String, icon_path: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	var icon := TextureRect.new()
	icon.texture=load(icon_path)
	icon.custom_minimum_size=Vector2(48,48)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var heading: Label=_label(text,20,color)
	heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	content.add_child(row)

func show_home() -> void:
	_ending=false
	var content: VBoxContainer = _page("home","Mosslight Bastion","Hold the lane. Keep the mosslight burning.")
	var balance: Label=_label("Keeper Lv %d   ·   %d coins   ·   %d XP"%[progress.level(),int(progress.data.coins),int(progress.data.xp)],20,GOLD)
	balance.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(balance)
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation",16)
	content.add_child(hero_row)
	var hero: BastionBoard = Board.new()
	hero.custom_minimum_size=Vector2(190,190)
	hero.decorative=true
	hero.simulation=BastionSimulation.new(Missions.campaign(3))
	hero.simulation.build(0,"archer")
	hero.simulation.build(1,"ember")
	hero.simulation.supplies=0
	hero.region=Missions.data().regions[0]
	hero.lantern_skin=str(progress.data.settings.skin)
	hero.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hero.clip_contents=true
	hero_row.add_child(hero)
	var welcome := VBoxContainer.new()
	welcome.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hero_row.add_child(welcome)
	welcome.add_child(_label("A little light.\nA wall worth holding.",23,GOLD))
	welcome.add_child(_label("Place guardians, read the lanes, and rally when the woodland presses close.",17,MUTED))
	welcome.add_child(_label("Lantern: "+str(progress.data.settings.skin).capitalize(),15))
	content.add_child(_button("Campaign ·60 authored missions",show_campaign,"campaign"))
	content.add_child(_button("Daily defense · "+progress.current_day(),func() -> void: show_brief(Missions.daily(progress.current_day())),"daily"))
	content.add_child(_button("Endless siege",func() -> void: show_brief(Missions.endless()),"endless"))
	content.add_child(_button("Workshop · preparation and lanterns",show_workshop,"workshop"))
	content.add_child(_button("Field journal · towers, foes and records",show_journal,"journal"))
	content.add_child(_button("Gifts and daily quests",show_gifts,"gifts"))
	content.add_child(_button("Settings and privacy",show_settings,"settings",true))
	status_label=_label(_toast_text if not _toast_text.is_empty() else _service_status(),15,MUTED)
	content.add_child(status_label)
	_footer(content)
	_sync_services()

func _service_status() -> String:
	var native: Node = platform()
	return str(native.status()) if native!=null and native.has_method("status") else "Offline progress is available."

func show_campaign() -> void:
	var content: VBoxContainer = _page("campaign","The twelve woodland walls","%d/60 missions · %d/180 stars. Every mission has a shown route and budget."%[progress.data.completed.size(),progress.star_total()])
	content.add_child(_button("Back to Home",show_home,"back",true))
	var data: Dictionary = Missions.data()
	for region_index in range(data.regions.size()):
		content.add_child(_label(str(data.regions[region_index].name),23,Color(str(data.regions[region_index].accent))))
		content.add_child(_label(str(data.regions[region_index].subtitle),16,MUTED))
		for number in range(region_index*5+1,region_index*5+6):
			var mission: Dictionary = Missions.campaign(number)
			var stars: int = int(progress.data.completed.get(str(number),0))
			var button: Button = _button("%02d · %s    %s"%[number,str(mission.name),"★".repeat(stars) if stars>0 else "—"],show_brief.bind(mission),"mission_"+str(number))
			button.disabled=not progress.available(number)
			content.add_child(button)
	_footer(content)

func show_brief(mission: Dictionary) -> void:
	selected_mission=mission.duplicate(true)
	var content: VBoxContainer = _page("brief",str(mission.name),"%d supplies · %d hearts · %d fixed lanes"%[int(mission.budget),int(mission.hearts),mission.routes.size()])
	content.add_child(_button("Back",show_campaign if str(mission.mode)=="campaign" else show_home,"back",true))
	content.add_child(_label(str(mission.hint),19,GOLD))
	content.add_child(_label("Tap a glowing build pad, inspect costs and range, then call the next wave. Enemies always keep their fixed route. Free Rally and retries need no ads.",18))
	if str(mission.mode)=="daily": content.add_child(_label("Daily preparation upgrades are disabled. Earned repair still allows ordinary rewards, but cannot replace an unassisted competitive best.",16,MUTED))
	for wave_index in range(mission.waves.size()):
		content.add_child(_label("Wave %d · %s"%[wave_index+1,_groups_text(mission.waves[wave_index])],17))
	content.add_child(_button("Prepare the wall",_start_battle,"start"))
	for kind in BastionSimulation.TOWERS:
		var tower: Dictionary = BastionSimulation.TOWERS[kind]
		content.add_child(_label("%s · %d supplies · range %.1f\n%s"%[tower.name,int(tower.cost),float(tower.range),tower.role],16,MUTED))
	_footer(content)

func _groups_text(groups: Array) -> String:
	var pieces: PackedStringArray = []
	for group in groups:
		pieces.append("%d %s (%s)"%[int(group.count),str(BastionSimulation.ENEMIES[str(group.type)].name),String.chr(65+int(group.route))])
	return ", ".join(pieces)

func _start_battle() -> void:
	_ending=false
	session.begin(selected_mission)
	selected_pad=-1
	_speed=1.0
	_last_battle_status=""
	show_battle()

func show_battle() -> void:
	_page("play",str(session.simulation.definition.name),"Tap a build pad. Routes stay open. All costs below are run supplies.")
	# Battle uses fixed panels; menu ScrollContainer is removed.
	for child in stage.get_children():
		if child is ScrollContainer: child.queue_free()
	battle_hud=_label("",19,GOLD)
	battle_hud.position=Vector2(18,120)
	battle_hud.size=Vector2(504,48)
	stage.add_child(battle_hud)
	board=Board.new()
	board.position=Vector2(27,177)
	board.size=Vector2(486,486)
	board.simulation=session.simulation
	board.region=Missions.data().regions[int(session.simulation.definition.get("region",0))]
	board.lantern_skin=str(progress.data.settings.skin)
	board.selected=selected_pad
	board.pad_selected.connect(_select_pad)
	stage.add_child(board)
	var controls := HBoxContainer.new()
	controls.position=Vector2(18,675)
	controls.size=Vector2(504,48)
	controls.add_theme_constant_override("separation",8)
	stage.add_child(controls)
	for item in [
		_button("Next wave",_next_wave,"wave",true),
		_button("Rally · free",_rally,"rally",true),
		_button("Pause",_pause,"pause",true),
		_button("1x",_toggle_speed,"speed",true)]:
		item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		controls.add_child(item)
	action_box=VBoxContainer.new()
	action_box.position=Vector2(18,735)
	action_box.size=Vector2(504,168)
	action_box.add_theme_constant_override("separation",8)
	stage.add_child(action_box)
	battle_note=_label("",15,MUTED)
	battle_note.position=Vector2(18,909)
	battle_note.size=Vector2(504,45)
	stage.add_child(battle_note)
	_tower_panel()
	_update_battle_labels()
	if session.user_paused: _show_pause()

func _select_pad(index: int) -> void:
	if session.user_paused or session.fullscreen_active() or session.reward_pending: return
	selected_pad=index
	_click()
	_tower_panel()

func _tower_panel() -> void:
	if action_box==null: return
	for child in action_box.get_children():
		_retire_ui(child as Control)
	if selected_pad<0:
		action_box.add_child(_label("Tap a ringed build pad. Range is shown after placement.\nNext: "+_groups_text(session.simulation.wave_groups()),17))
		return
	var tower: Dictionary = session.simulation.tower_at(selected_pad)
	if tower.is_empty():
		action_box.add_child(_label("Pad %d · choose a tower. Nothing is spent until you choose."%(selected_pad+1),16))
		var grid := GridContainer.new()
		grid.columns=2
		grid.add_theme_constant_override("h_separation",8)
		grid.add_theme_constant_override("v_separation",6)
		action_box.add_child(grid)
		for kind in BastionSimulation.TOWERS:
			var data: Dictionary = BastionSimulation.TOWERS[kind]
			var button: Button = _button("%s %d · range %.1f"%[data.name,int(data.cost),float(data.range)],_build.bind(str(kind)),"build_"+str(kind),true)
			button.custom_minimum_size.x=246
			button.disabled=session.simulation.supplies<int(data.cost)
			button.tooltip_text=str(data.role)
			grid.add_child(button)
	else:
		var data: Dictionary = BastionSimulation.TOWERS[str(tower.kind)]
		action_box.add_child(_label("%s Lv %d · %s"%[data.name,int(tower.level),data.role],16))
		var upgrade_cost: int = session.simulation.upgrade_cost(selected_pad)
		var upgrade_button: Button = _button("Upgrade · %d supplies"%upgrade_cost if upgrade_cost>=0 else "Maximum tower level",_upgrade_tower,"upgrade",true)
		upgrade_button.disabled=upgrade_cost<0 or session.simulation.supplies<upgrade_cost
		action_box.add_child(upgrade_button)
		action_box.add_child(_button("Sell · return %d supplies"%session.simulation.sell_value(selected_pad),_sell_tower,"sell",true))

func _build(kind: String) -> void:
	if session.simulation.build(selected_pad,kind):
		_click(true)
		_tower_panel()

func _upgrade_tower() -> void:
	if session.simulation.upgrade(selected_pad): _click(true)
	_tower_panel()

func _sell_tower() -> void:
	session.simulation.sell(selected_pad)
	_tower_panel()

func _next_wave() -> void:
	if session.simulation.next_wave():
		_last_battle_status="running"
		_tower_panel()

func _rally() -> void:
	if session.simulation.rally(): _click(true)

func _toggle_speed() -> void:
	_speed=2.0 if _speed==1.0 else 1.0
	buttons.speed.text="%dx"%int(_speed)

func _pause() -> void:
	session.pause()
	_show_pause()

func _show_pause() -> void:
	if page!="play": return
	var signature: String=str(session.simulation.status)+str(session.reward_pending)+str(session.fullscreen_active())+session.notice
	if pause_layer!=null and is_instance_valid(pause_layer):
		if signature==_pause_signature: return
		_retire_ui(pause_layer)
	for key in ["resume","accept_result","repair","abandon"]: buttons.erase(key)
	_pause_signature=signature
	pause_layer=PanelContainer.new()
	pause_layer.position=Vector2(45,265)
	pause_layer.size=Vector2(450,410)
	pause_layer.add_theme_stylebox_override("panel",_style(Color("183c32"),GOLD))
	stage.add_child(pause_layer)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	pause_layer.add_child(box)
	var defeated: bool=session.simulation.status=="lost"
	box.add_child(_label("The keep needs a new plan" if defeated else "The wall is paused",26,GOLD))
	box.add_child(_label(session.notice if not session.notice.is_empty() else ("Accept this result, or use one available earned repair. Normal retries cost nothing." if defeated else "Enemy movement, spawning, shots and all combat timers are stopped."),18))
	box.add_child(_button("Accept result" if defeated else "Resume",_finish_result if defeated else _resume,"accept_result" if defeated else "resume"))
	var repair: Button = _button("Optional native repair · once this run",_request_repair,"repair",true)
	repair.disabled=not session.can_request_repair()
	box.add_child(repair)
	box.add_child(_label("Earned repair restores up to 8 hearts and 40 supplies; marks this run assisted. No ad is required to retry or use Rally.",15,MUTED))
	box.add_child(_button("Abandon to Home · no result credit",_abandon,"abandon",true))

func _resume() -> void:
	if session.resume():
		if is_instance_valid(pause_layer): pause_layer.queue_free()
		pause_layer=null

func _request_repair() -> void:
	session.request_repair()
	if pause_layer!=null:
		pause_layer.queue_free()
		pause_layer=null
	_show_pause()

func _abandon() -> void:
	if session.fullscreen_active() or session.reward_pending: return
	session.abandon()
	show_home()

func _process(delta: float) -> void:
	if session==null: return
	if page=="play":
		session.advance(delta*_speed)
		if board!=null: board.queue_redraw()
		if session.user_paused: _show_pause()
		if buttons.has("resume") and is_instance_valid(buttons.resume): buttons.resume.disabled=session.reward_pending or session.fullscreen_active() or session.simulation.status=="lost"
		if buttons.has("repair") and is_instance_valid(buttons.repair): buttons.repair.disabled=not session.can_request_repair()
		if buttons.has("abandon") and is_instance_valid(buttons.abandon): buttons.abandon.disabled=session.reward_pending or session.fullscreen_active()
		if buttons.has("accept_result") and is_instance_valid(buttons.accept_result): buttons.accept_result.disabled=session.reward_pending or session.fullscreen_active()
		if session.simulation.status=="won" or (session.simulation.status=="lost" and session.simulation.assisted):
			_finish_result()
		elif session.simulation.status=="lost" and not session.user_paused:
			session.pause()
			_show_defeat()
		_elapsed_ui+=delta
		if _elapsed_ui>=0.15:
			_elapsed_ui=0
			_update_battle_labels()
			for kind in BastionSimulation.TOWERS:
				if buttons.has("build_"+str(kind)) and is_instance_valid(buttons["build_"+str(kind)]): buttons["build_"+str(kind)].disabled=session.user_paused or session.simulation.supplies<int(BastionSimulation.TOWERS[kind].cost)
			if buttons.has("upgrade") and is_instance_valid(buttons.upgrade): buttons.upgrade.disabled=session.user_paused or session.simulation.upgrade_cost(selected_pad)<0 or session.simulation.supplies<session.simulation.upgrade_cost(selected_pad)
			if session.simulation.status!=_last_battle_status:
				_last_battle_status=session.simulation.status
				_tower_panel()
	elif page=="home" and status_label!=null:
		status_label.text=_toast_text if not _toast_text.is_empty() else _service_status()

func _update_battle_labels() -> void:
	if page!="play" or battle_hud==null: return
	var sim: BastionSimulation = session.simulation
	battle_hud.text="Hearts %d/%d   Supplies %d   Wave %d   %d:%02d"%[sim.hearts,sim.max_hearts,sim.supplies,maxi(1,sim.wave_index+1),int(sim.elapsed)/60,int(sim.elapsed)%60]
	buttons.wave.disabled=sim.status!="ready" or session.user_paused
	buttons.rally.disabled=sim.status!="running" or sim.rally_cooldown>0 or session.user_paused
	buttons.rally.text="Rally %ds"%int(ceil(sim.rally_cooldown)) if sim.rally_cooldown>0 else "Rally · free"
	battle_note.text="Assisted: ordinary rewards; no competitive best." if sim.assisted else ("Wave clear. Build or upgrade, then call the next wave." if sim.status=="ready" else "%d defeated · %d leaked · Pause and Rally are free."%[sim.killed,sim.leaked])

func _show_defeat() -> void:
	_show_pause()

func _finish_result() -> void:
	if _ending or session.fullscreen_active() or session.reward_pending: return
	var receipt: Dictionary = session.accept_result()
	if not bool(receipt.get("recorded",false)): return
	_ending=true
	_click(true)
	_sync_services()
	var sim: BastionSimulation = session.simulation
	var content: VBoxContainer = _page("results","The mosslight holds" if sim.status=="won" else "A lesson for the next wall","%d defeated · %d waves · %d seconds · %s"%[sim.killed,sim.waves_cleared,int(sim.elapsed),"assisted" if sim.assisted else "unassisted"])
	content.add_child(_label("%d coins   +%d XP"%[int(receipt.coins),int(receipt.xp)],27,GOLD))
	if int(receipt.get("level_bonus",0))>0: content.add_child(_label("Includes %d coins from your new keeper level."%int(receipt.level_bonus),17))
	content.add_child(_label("★".repeat(sim.stars()) if sim.status=="won" else "Free retries. Your banked progress is safe.",25))
	content.add_child(_label("Assisted successes keep ordinary progress. Only unassisted records can replace competitive bests.",16,MUTED))
	if sim.status=="won" and str(sim.definition.get("mode","campaign"))=="campaign" and int(sim.definition.id)<Missions.count():
		content.add_child(_button("Next level · "+str(Missions.campaign(int(sim.definition.id)+1).name),_next_level,"next_level"))
	content.add_child(_button("Try this wall again · free",func() -> void: show_brief(selected_mission),"retry"))
	content.add_child(_button("Return Home",show_home,"home"))
	_footer(content)

func _next_level() -> void:
	# A settled, banked campaign victory owns this transition. Never skip a loss,
	# Daily/Endless attempt or an undismissed fullscreen activity.
	if session==null or session.simulation==null or not session.banked or session.fullscreen_active() or session.reward_pending: return
	var sim: BastionSimulation=session.simulation
	var number: int=int(sim.definition.get("id",0))+1
	if sim.status!="won" or str(sim.definition.get("mode",""))!="campaign" or number>Missions.count() or not progress.available(number): return
	show_brief(Missions.campaign(number))

func show_gifts() -> void:
	progress.roll_day()
	var content: VBoxContainer = _page("gifts","Gifts and daily quests","UTC saved day "+progress.current_day()+". Clock rollback never rewinds the claimed day.")
	content.add_child(_button("Back to Home",show_home,"back",true))
	content.add_child(_label("Seven lanterns · a seven-day login gift",24,GOLD))
	content.add_child(_label("50 coins on day 1, then 15 more per consecutive day through day 7; 10 XP each gift. The cycle restarts after day 7. Current streak %d."%int(progress.data.streak),18))
	var gift: Button = _button("Login gift claimed" if str(progress.data.login_day)==str(progress.data.day) else "Claim today's login gift",_claim_login,"login")
	gift.disabled=str(progress.data.login_day)==str(progress.data.day)
	content.add_child(gift)
	for key in BastionProgress.QUESTS:
		var quest: Dictionary = BastionProgress.QUESTS[key]
		var done: bool = progress.data.daily_claimed.has(key)
		content.add_child(_label("%s · %d/%d · %d coins/%d XP"%[str(key).capitalize(),int(progress.data.daily[key]),int(quest.target),int(quest.coins),int(quest.xp)],18))
		var claim: Button = _button("Claimed" if done else "Claim "+str(key)+" quest",_claim_quest.bind(str(key)),"quest_"+str(key),true)
		claim.disabled=done or int(progress.data.daily[key])<int(quest.target)
		content.add_child(claim)
	if not _toast_text.is_empty(): content.add_child(_label(_toast_text,17,GOLD))
	_footer(content)

func _claim_login() -> void:
	var receipt: Dictionary = progress.claim_login()
	if bool(receipt.get("claimed",false)): _toast_text="Gift: %d coins and %d XP."%[int(receipt.coins),int(receipt.xp)]
	show_gifts()
	_sync_services()

func _claim_quest(key: String) -> void:
	var receipt: Dictionary = progress.claim_quest(key)
	if bool(receipt.get("claimed",false)): _toast_text="Quest: %d coins and %d XP."%[int(receipt.coins),int(receipt.xp)]
	show_gifts()
	_sync_services()

func show_workshop() -> void:
	var content: VBoxContainer = _page("workshop","The keeper's workshop","%d coins · ordinary progression is free. Every campaign witness uses no preparation upgrades."%int(progress.data.coins))
	content.add_child(_button("Back to Home",show_home,"back",true))
	for key in ["power","fortify"]:
		var cost: int = progress.preparation_cost(key)
		content.add_child(_label("Tower preparation" if key=="power" else "Keep masonry",24,GOLD))
		content.add_child(_label("+4% tower damage per level" if key=="power" else "+1 keep heart per level",18))
		var button: Button = _button("Level %d/5 · %d coins"%[int(progress.data.preparation[key]),cost] if cost>=0 else "Level 5/5 · maximum",_buy_preparation.bind(key),"prep_"+key)
		button.disabled=cost<0 or int(progress.data.coins)<cost
		content.add_child(button)
	content.add_child(_label("Daily defenses disable preparation upgrades so the daily field remains equal.",16,MUTED))
	content.add_child(_label("Lantern colors · cosmetic only",24,GOLD))
	for key in ["moss","amber","moon"]:
		var owned: bool = progress.data.cosmetics.has(key)
		var cost: int = 0 if owned else (150 if key=="amber" else 250)
		var button: Button = _button(str(key).capitalize()+ (" · selected" if str(progress.data.settings.skin)==key else (" · choose" if owned else " · %d coins"%cost)),_choose_skin.bind(key),"skin_"+key,true)
		button.disabled=not owned and int(progress.data.coins)<cost
		content.add_child(button)
	_footer(content)

func _buy_preparation(key: String) -> void:
	if progress.buy_preparation(key): _click(true)
	show_workshop()

func _choose_skin(key: String) -> void:
	progress.choose_skin(key)
	show_workshop()

func show_journal() -> void:
	var content: VBoxContainer = _page("journal","The field journal","Tower counters, readable enemy traits, local achievements and unassisted records.")
	content.add_child(_button("Back to Home",show_home,"back",true))
	for kind in BastionSimulation.TOWERS:
		var tower: Dictionary = BastionSimulation.TOWERS[kind]
		content.add_child(_label("%s · %d supplies · %.0f damage / %.2fs · range %.1f"%[tower.name,int(tower.cost),float(tower.damage),float(tower.period),float(tower.range)],19,GOLD))
		content.add_child(_label(str(tower.role),17))
	for kind in BastionSimulation.ENEMIES:
		var enemy: Dictionary = BastionSimulation.ENEMIES[kind]
		content.add_child(_label("%s · %.0f base HP · %d-heart leak"%[enemy.name,float(enemy.hp),int(enemy.leak)],19,GOLD))
		content.add_child(_label(str(enemy.role),17))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	content.add_child(_label("20 local achievements",25,GOLD))
	for row in catalog.achievements:
		var unlocked: bool = progress.data.unlocked.has(str(row.id))
		_record_heading(content,("Unlocked: " if unlocked else "Locked: ")+str(row.name),str(row.icon),GOLD if unlocked else INK)
		content.add_child(_label(str(row.description)+"  %d/%d"%[progress.metric(str(row.metric)),int(row.target)],16,MUTED))
	content.add_child(_label("Four leaderboards",25,GOLD))
	var scores: Dictionary = progress.leaderboard_values()
	for row in catalog.leaderboards:
		_record_heading(content,str(row.name)+": "+str(scores[str(row.id)]),str(row.icon),INK)
		content.add_child(_label(str(row.description),16,MUTED))
	content.add_child(_button("Online achievements",_online_achievements,"online_achievements",true))
	content.add_child(_button("Online leaderboards",_online_boards,"online_boards",true))
	_footer(content)

func show_settings() -> void:
	var content: VBoxContainer = _page("settings","Settings and privacy","Offline play remains complete when optional Android services are unavailable.")
	content.add_child(_button("Back to Home",show_home,"back",true))
	for key in ["music","sound"]:
		content.add_child(_button(str(key).capitalize()+ (" · on" if bool(progress.data.settings[key]) else " · off"),_toggle_setting.bind(key),key))
	content.add_child(_button("Advertising privacy options",_privacy,"privacy"))
	content.add_child(_button("Optional Play Games sign-in",_sign_in,"sign_in"))
	content.add_child(_label("Native Android ads use official Google test IDs. Production Play Games IDs are placeholders and disabled pending owner configuration. No Web/offline reward is simulated.",18))
	content.add_child(_label("Banked campaign, currency, achievements and daily progress save locally with a previous-valid backup. Unfinished combat is not resumable after process death. Local clocks/saves are not anti-cheat secure.",18,MUTED))
	content.add_child(_label(_service_status(),17,GOLD))
	_footer(content)

func _toggle_setting(key: String) -> void:
	progress.data.settings[key]=not bool(progress.data.settings[key])
	progress.save()
	_apply_audio()
	show_settings()

func _privacy() -> void:
	if platform()!=null: platform().privacy_options()
	_toast_text=_service_status()
	show_settings()

func _sign_in() -> void:
	if platform()!=null: platform().sign_in()
	_toast_text=_service_status()
	show_settings()

func _online_achievements() -> void:
	if platform()!=null: platform().open_achievements()

func _online_boards() -> void:
	if platform()!=null: platform().open_leaderboards()

func _sync_services() -> void:
	var native: Node = platform()
	if native==null: return
	for key in progress.data.unlocked:
		if native.has_method("unlock"): native.unlock(str(key))
	for key in progress.leaderboard_values():
		if native.has_method("submit"): native.submit(str(key),int(progress.leaderboard_values()[key]))

func go_back() -> void:
	if session!=null and (session.fullscreen_active() or session.reward_pending):
		session.pause()
		return
	if page=="play":
		if session.user_paused:
			_resume()
		else: _pause()
	elif page=="home":
		_toast_text="Your wall is safe here. Choose a mission when you are ready."
	else: show_home()

func _exit_tree() -> void:
	if progress!=null: progress.save()

