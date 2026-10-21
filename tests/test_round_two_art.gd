extends SceneTree
## Synthetic desktop collection presentation, isolated data. No native SDK or store proof.
const Main=preload("res://game/main.gd")
const Progress=preload("res://game/progress.gd")
var checks: int=0
var failures: int=0
class ArtService extends Node:
	func status() -> String:return "Desktop collection fixture: no native SDK."
	func set_menu_visible(_value: bool) -> void:pass
	func menu_bottom_reserve(_reference: CanvasItem=null) -> float:return 0.0
	func unlock(_key: String) -> void:pass
	func submit(_key: String,_score: int) -> void:pass
func _initialize() -> void:call_deferred("run")
func check(value: bool,text: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(text)
func frames() -> void:
	for i in range(5):await process_frame
func reveal(control: Control) -> void:
	var ancestor: Node=control.get_parent()
	while ancestor!=null and not ancestor is ScrollContainer:ancestor=ancestor.get_parent()
	if ancestor!=null:ancestor.ensure_control_visible(control)
	await frames()
func tap(control: Control) -> void:
	await reveal(control);var at: Vector2=control.get_global_rect().get_center()
	for down in [true,false]:
		var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=at;mouse.global_position=at;mouse.pressed=down;mouse.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;mouse.device=-1;root.push_input(mouse,true)
		var touch:=InputEventScreenTouch.new();touch.index=0;touch.position=at;touch.pressed=down;root.push_input(touch,true);await process_frame
	await frames()
func capture(name_value: String) -> void:
	var folder: String=OS.get_environment("MOSS_R2_ART_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless":return
	DirAccess.make_dir_recursive_absolute(folder);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(name_value+".png"))==OK,"actual Compatibility journal frame")
func run() -> void:
	create_timer(50).timeout.connect(func():push_error("Moss badge UI timeout");quit(2))
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(540,960)
	var service:=ArtService.new();root.add_child(service)
	var app: Control=Main.new();app.progress=Progress.new("user://badge-ui-fixture.json","2026-10-21");app.progress.data.settings.music=false;app.progress.data.settings.sound=false;app.service_override=service;root.add_child(app);app.set_process(false);await frames()
	var before: String=JSON.stringify(app.progress.data)
	await tap(app.buttons.journal);check(app.page=="journal","ordinary paired Journal input opens illustrated collection once")
	check(JSON.stringify(app.progress.data)==before,"collection presentation leaves typed synthetic progress unchanged")
	var icons: Array[Node]=app.find_children("Badge*","TextureRect",true,false);check(icons.size()==24,"all20achievements and4boards have runtime badge textures")
	for item in icons:
		check(item.texture!=null and item.texture.get_width()==512 and item.texture.get_height()==512,"catalogue texture loads full512: "+item.name)
		check(item.mouse_filter==Control.MOUSE_FILTER_IGNORE,"art does not intercept scrolling/input: "+item.name)
	for profile in [["phone",540,960],["tablet7",600,960],["tablet10",640,1024]]:
		root.size=Vector2i(profile[1],profile[2]);await frames()
		var first: Control=app.find_child("Badgefirst_wall",true,false);await reveal(first)
		check(first.size.x>=64 and first.size.y>=64,"phone/tablet badge readable64logicalpx minimum")
		check(first.get_global_rect().end.x<=float(root.size.x),"badge fits viewport width")
		await capture(str(profile[0])+"-journal-achievements")
		var last: Control=app.find_child("Badgeplayer_level",true,false);await reveal(last)
		check(last.get_global_rect().end.x<=float(root.size.x),"leaderboard badge fits viewport width")
		await capture(str(profile[0])+"-journal-leaderboards")
	app.queue_free();service.queue_free();await frames();print("MOSS_R2_ART ",checks," checks / ",failures," failures");quit(1 if failures else 0)
