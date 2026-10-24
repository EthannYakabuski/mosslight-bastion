class_name BastionBoard
extends Control
signal pad_selected(index: int)
var simulation: BastionSimulation
var region: Dictionary = {}
var selected: int = -1
var decorative: bool = false
var lantern_skin: String = "moss"
var damage_flash: float = 0.0
const KEEP = preload("res://assets/keep/woodland-keep.png")
const TOWN = preload("res://assets/town/tilemap_packed.png")
const DUNGEON = preload("res://assets/dungeon/tilemap_packed.png")
const COLORS: Dictionary = {"archer":Color("e3ce84"),"ember":Color("f49b68"),"frost":Color("9ddcde"),"prism":Color("d7aff0")}

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP

func cell_size() -> float:
	return minf(size.x,size.y)/9.0

func center(point: Vector2) -> Vector2:
	return (point+Vector2(0.5,0.5))*cell_size()

func _tile(texture: Texture2D, id: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect_region(texture,rect,Rect2(Vector2((id%12)*16,int(id/12)*16),Vector2(16,16)),tint)

func _gui_input(event: InputEvent) -> void:
	if decorative or simulation==null: return
	var pressed: bool = (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed: return
	var position_value: Vector2 = event.position
	for index in range(simulation.pads.size()):
		if center(simulation.pads[index]).distance_to(position_value)<=cell_size()*0.45:
			selected=index
			pad_selected.emit(index)
			accept_event()
			queue_redraw()
			return

func _draw() -> void:
	if simulation==null: return
	var cell: float = cell_size()
	var lantern_color: Color=Color("ffb467") if lantern_skin=="amber" else (Color("b8d4fa") if lantern_skin=="moon" else Color("f8dd92"))
	var ground := Color(str(region.get("ground","#49754d")))
	draw_style_box(_panel_style(ground.darkened(0.15)),Rect2(Vector2.ZERO,Vector2(cell*9,cell*9)))
	for y in range(9):
		for x in range(9):
			var ground_rect:=Rect2(Vector2(x,y)*cell,Vector2.ONE*cell)
			draw_rect(ground_rect,ground)
			_tile(TOWN,0,ground_rect,Color(1,1,1,0.18))
			var point:=Vector2(x,y)
			var occupied: bool=simulation.pads.has(point)
			for route in simulation.routes:
				if route.has(point): occupied=true
			if not occupied and (x*7+y*3+int(region.get("tile",0)))%19==0:
				_tile(TOWN,4+int(region.get("tile",0)),ground_rect.grow(-cell*0.13),Color(1,1,1,0.8))
	for route_index in range(simulation.routes.size()):
		var route: Array = simulation.routes[route_index]
		for point in route:
			_tile(TOWN,13,Rect2(point*cell,Vector2.ONE*cell),Color("dcc39a"))
		for index in range(route.size()-1):
			draw_line(center(route[index]),center(route[index+1]),Color(0.46,0.31,0.19,0.28),2.0)
		draw_circle(center(route[0]),cell*0.19,Color("f4d782"))
		draw_string(get_theme_default_font(),center(route[0])+Vector2(-5,5),String.chr(65+route_index),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("263c38"))
		var keep: Vector2 = center(route.back())
		draw_circle(keep,cell*0.44,Color(0.05,0.12,0.10,0.35))
		var keep_top: Vector2=keep-Vector2(cell*0.60,cell*0.76)
		keep_top=keep_top.clamp(Vector2.ZERO,Vector2.ONE*cell*7.8)
		draw_texture_rect(KEEP,Rect2(keep_top,Vector2(cell*1.20,cell*1.20)),false,Color("ffb29a") if damage_flash>0.0 else Color.WHITE)
		draw_circle(keep-Vector2(0,cell*0.18),cell*0.07,lantern_color)

	if selected>=0 and selected<simulation.pads.size():
		var tower: Dictionary = simulation.tower_at(selected)
		if not tower.is_empty():
			var range_value: float = float(BastionSimulation.TOWERS[str(tower.kind)].range)+(int(tower.level)-1)*0.25
			draw_circle(center(simulation.pads[selected]),range_value*cell,Color(0.9,0.95,0.8,0.10))
			draw_arc(center(simulation.pads[selected]),range_value*cell,0,TAU,80,Color(0.9,0.95,0.8,0.6),1.5)
	for index in range(simulation.pads.size()):
		var pos: Vector2 = center(simulation.pads[index])
		var tower: Dictionary = simulation.tower_at(index)
		draw_circle(pos,cell*0.31,Color("233e34"))
		draw_arc(pos,cell*0.32,0,TAU,24,Color("fff0ad") if selected==index else Color("8caa79"),3.0 if selected==index else 1.5)
		if tower.is_empty():
			draw_line(pos-Vector2(cell*0.12,0),pos+Vector2(cell*0.12,0),Color("adc591"),2.0)
			draw_line(pos-Vector2(0,cell*0.12),pos+Vector2(0,cell*0.12),Color("adc591"),2.0)
		else:
			var data: Dictionary = BastionSimulation.TOWERS[str(tower.kind)]
			_tile(DUNGEON,int(data.sprite),Rect2(pos-Vector2.ONE*cell*0.31,Vector2.ONE*cell*0.62),COLORS[str(tower.kind)].lightened(0.2))
			for dot in range(int(tower.level)):
				draw_circle(pos+Vector2((dot-(int(tower.level)-1)*0.5)*6,cell*0.25),2.0,COLORS[str(tower.kind)])
	for enemy in simulation.enemies:
		var pos: Vector2 = center(simulation.enemy_position(enemy))
		var data: Dictionary = BastionSimulation.ENEMIES[str(enemy.type)]
		if float(enemy.slow)>0: draw_circle(pos,cell*0.23,Color(0.6,0.9,1.0,0.5))
		_tile(DUNGEON,int(data.sprite),Rect2(pos-Vector2.ONE*cell*0.25,Vector2.ONE*cell*0.5))
		if float(data.armor)>0: draw_arc(pos,cell*0.26,0,TAU,16,Color("c6d0c7"),1.4)
		draw_rect(Rect2(pos+Vector2(-11,-cell*0.32),Vector2(22,3)),Color("23332e"))
		draw_rect(Rect2(pos+Vector2(-11,-cell*0.32),Vector2(22*clampf(float(enemy.hp)/float(enemy.max_hp),0,1),3)),Color("b7e18d"))
	for projectile in simulation.projectiles:
		var target: Dictionary = simulation._enemy(int(projectile.target))
		if target.is_empty(): continue
		var from: Vector2 = center(projectile.from)
		var to: Vector2 = center(simulation.enemy_position(target))
		var t: float = 1.0-float(projectile.left)/float(projectile.duration)
		draw_circle(from.lerp(to,t),3.0,COLORS[str(projectile.kind)])

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.corner_radius_top_left=8
	style.corner_radius_top_right=8
	style.corner_radius_bottom_left=8
	style.corner_radius_bottom_right=8
	return style
