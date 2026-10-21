class_name BastionSimulation
extends RefCounted
## Production deterministic20Hz combat. Rendering and native callbacks never own time.

const DT: float = 0.05
const TOWERS: Dictionary = {
	"archer": {"name":"Archer", "cost":45, "damage":4.2, "period":0.5, "range":2.65, "splash":0.0, "slow":0.0, "role":"Quick shots; efficient against ordinary runners.", "sprite":85},
	"ember": {"name":"Ember", "cost":70, "damage":10.0, "period":1.25, "range":2.5, "splash":1.0, "slow":0.0, "role":"Splash catches clusters; partially bypasses armor.", "sprite":84},
	"frost": {"name":"Frost", "cost":55, "damage":3.0, "period":0.9, "range":2.8, "splash":0.0, "slow":0.5, "role":"Slows most enemies; wisps ignore the chill.", "sprite":89},
	"prism": {"name":"Prism", "cost":100, "damage":20.0, "period":1.5, "range":4.0, "splash":0.0, "slow":0.0, "role":"Long reach and true damage; slower against crowds.", "sprite":88}
}
const ENEMIES: Dictionary = {
	"sprig": {"name":"Sprig", "hp":32.0, "speed":0.65, "armor":0.0, "bounty":6, "leak":1, "immune":false, "sprite":96, "role":"Ordinary woodland visitor."},
	"runner": {"name":"Runner", "hp":25.0, "speed":1.1, "armor":0.0, "bounty":7, "leak":1, "immune":false, "sprite":97, "role":"Fast and fragile; slow it before a corner."},
	"shell": {"name":"Shellguard", "hp":80.0, "speed":0.46, "armor":0.6, "bounty":10, "leak":2, "immune":false, "sprite":98, "role":"Armor blocks 60% of arrows; prism ignores it."},
	"swarm": {"name":"Sporeling", "hp":17.0, "speed":0.8, "armor":0.0, "bounty":4, "leak":1, "immune":false, "sprite":108, "role":"Weak alone, crowded together; ember excels."},
	"wisp": {"name":"Wisp", "hp":46.0, "speed":0.9, "armor":0.0, "bounty":9, "leak":1, "immune":true, "sprite":110, "role":"Ignores slow; focus direct damage."},
	"bramble": {"name":"Bramble", "hp":175.0, "speed":0.36, "armor":0.3, "bounty":18, "leak":3, "immune":false, "sprite":121, "role":"Durable siege leader; costs three hearts if leaked."}
}

var definition: Dictionary = {}
var mode: String = "campaign"
var routes: Array = []
var pads: Array = []
var towers: Array = []
var enemies: Array = []
var projectiles: Array = []
var supplies: int = 0
var max_hearts: int = 15
var hearts: int = 15
var wave_index: int = -1
var waves_cleared: int = 0
var status: String = "ready"
var elapsed: float = 0.0
var wave_elapsed: float = 0.0
var accumulator: float = 0.0
var paused: bool = false
var assisted: bool = false
var killed: int = 0
var leaked: int = 0
var built: int = 0
var upgrades_bought: int = 0
var rally_uses: int = 0
var rally_left: float = 0.0
var rally_cooldown: float = 0.0
var _spawn_queue: Array = []
var _next_enemy: int = 1
var _power: int = 0

func _init(mission: Dictionary = {}, preparation: Dictionary = {}) -> void:
	if mission.is_empty():
		return
	definition = mission.duplicate(true)
	mode = str(definition.get("mode", "campaign"))
	supplies = int(definition.get("budget", 150))
	_power = 0 if mode == "daily" else clampi(int(preparation.get("power", 0)),0,5)
	max_hearts = int(definition.get("hearts", 15)) + (0 if mode == "daily" else clampi(int(preparation.get("fortify", 0)),0,5))
	hearts = max_hearts
	for raw_route in definition.get("routes", []):
		var points: Array = []
		for raw in raw_route:
			var point := Vector2(int(raw[0]),int(raw[1]))
			if points.is_empty():
				points.append(point)
			else:
				var previous: Vector2 = points.back()
				assert(previous.x == point.x or previous.y == point.y,"Authored routes must be cardinal")
				while previous != point:
					previous += (point-previous).sign()
					points.append(previous)
		routes.append(points)
	for raw in definition.get("pads", []):
		pads.append(Vector2(int(raw[0]),int(raw[1])))
	assert(not routes.is_empty() and not pads.is_empty())
	for point in pads:
		for route in routes:
			assert(not route.has(point),"A tower pad must never block a route")

func tower_at(pad_index: int) -> Dictionary:
	for tower in towers:
		if int(tower.pad) == pad_index:
			return tower
	return {}

func build(pad_index: int, kind: String) -> bool:
	if paused or status not in ["ready","running"] or not TOWERS.has(kind) or pad_index < 0 or pad_index >= pads.size() or not tower_at(pad_index).is_empty():
		return false
	var cost: int = int(TOWERS[kind].cost)
	if supplies < cost:
		return false
	supplies -= cost
	towers.append({"pad":pad_index,"kind":kind,"level":1,"spent":cost,"cooldown":0.0,"shots":0})
	built += 1
	return true

func upgrade_cost(pad_index: int) -> int:
	var tower: Dictionary = tower_at(pad_index)
	return int(round(float(TOWERS[tower.kind].cost)*0.75*int(tower.level))) if not tower.is_empty() and int(tower.level)<3 else -1

func upgrade(pad_index: int) -> bool:
	var cost: int = upgrade_cost(pad_index)
	if paused or status not in ["ready","running"] or cost < 0 or supplies < cost:
		return false
	var tower: Dictionary = tower_at(pad_index)
	tower.level = int(tower.level)+1
	tower.spent = int(tower.spent)+cost
	supplies -= cost
	upgrades_bought += 1
	return true

func sell_value(pad_index: int) -> int:
	var tower: Dictionary = tower_at(pad_index)
	return int(floor(int(tower.spent)*0.7)) if not tower.is_empty() else 0

func sell(pad_index: int) -> bool:
	if paused or status not in ["ready","running"]:
		return false
	var tower: Dictionary = tower_at(pad_index)
	if tower.is_empty():
		return false
	supplies += sell_value(pad_index)
	towers.erase(tower)
	return true

func wave_groups(index: int = -1) -> Array:
	var number: int = wave_index+1 if index < 0 else index
	if mode != "endless":
		var authored: Array = definition.get("waves", [])
		return authored[number].duplicate(true) if number >= 0 and number < authored.size() else []
	var cycle: Array = ["sprig","runner","swarm","shell","wisp","bramble"]
	var groups: Array = [{"type":cycle[number%cycle.size()],"count":5+number*2,"interval":maxf(0.25,0.9-number*0.025),"route":number%routes.size(),"delay":0.0}]
	if number>=3:
		groups.append({"type":"sprig" if number%2==0 else "runner","count":4+number,"interval":0.65,"route":(number+1)%routes.size(),"delay":2.5})
	return groups

func next_wave() -> bool:
	if paused or status != "ready":
		return false
	var groups: Array = wave_groups()
	if groups.is_empty():
		return false
	wave_index += 1
	wave_elapsed = 0.0
	_spawn_queue.clear()
	for group in groups:
		assert(ENEMIES.has(str(group.type)) and int(group.route)>=0 and int(group.route)<routes.size())
		for index in range(int(group.count)):
			_spawn_queue.append({"at":float(group.get("delay",0.0))+index*float(group.interval),"type":str(group.type),"route":int(group.route),"order":_spawn_queue.size()})
	_spawn_queue.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.order)<int(b.order) if float(a.at)==float(b.at) else float(a.at)<float(b.at))
	status = "running"
	return true

func rally() -> bool:
	if paused or status != "running" or rally_cooldown>0.0:
		return false
	rally_left = 4.0
	rally_cooldown = 18.0
	rally_uses += 1
	return true

func accept_earned_repair() -> bool:
	if assisted or status not in ["running","lost","ready"]:
		return false
	assisted = true
	hearts = mini(max_hearts,hearts+8)
	supplies += 40
	if status == "lost":
		status = "running"
	paused = true
	accumulator = 0.0
	return true

func advance(delta: float, platform_blocked: bool = false) -> void:
	if paused or platform_blocked or status != "running":
		accumulator = 0.0
		return
	accumulator += clampf(delta,0.0,0.25)
	while accumulator+0.0000001>=DT and status=="running":
		accumulator -= DT
		_fixed_step()

func enemy_position(enemy: Dictionary) -> Vector2:
	var route: Array = routes[int(enemy.route)]
	var distance: float = clampf(float(enemy.distance),0.0,float(route.size()-1))
	var index: int = mini(int(floor(distance)),route.size()-2)
	return (route[index] as Vector2).lerp(route[index+1],distance-index)

func _enemy(id: int) -> Dictionary:
	for enemy in enemies:
		if int(enemy.id)==id:
			return enemy
	return {}

static func damage_after_armor(kind: String, damage: float, armor: float) -> float:
	var armor_fraction: float = 0.0 if kind=="prism" else (armor*0.35 if kind=="ember" else (armor*0.5 if kind=="frost" else armor))
	return maxf(1.0,damage*(1.0-armor_fraction))

func _hit(projectile: Dictionary, target: Dictionary) -> void:
	var point: Vector2 = enemy_position(target)
	for enemy in enemies:
		if enemy==target or (float(projectile.splash)>0.0 and enemy_position(enemy).distance_to(point)<=float(projectile.splash)):
			var enemy_traits: Dictionary = ENEMIES[str(enemy.type)]
			enemy.hp = float(enemy.hp)-damage_after_armor(str(projectile.kind),float(projectile.damage),float(enemy_traits.armor))
			if float(projectile.slow)>0.0 and not bool(enemy_traits.immune):
				enemy.slow = 1.7

func _fixed_step() -> void:
	elapsed += DT
	wave_elapsed += DT
	rally_left = maxf(0.0,rally_left-DT)
	rally_cooldown = maxf(0.0,rally_cooldown-DT)
	while not _spawn_queue.is_empty() and float(_spawn_queue[0].at)<=wave_elapsed:
		var spawn: Dictionary = _spawn_queue.pop_front()
		var enemy_traits: Dictionary = ENEMIES[str(spawn.type)]
		var scale_hp: float = float(definition.get("hp_scale",1.0))*(1.0+maxi(0,wave_index-2)*0.08 if mode=="endless" else 1.0)
		enemies.append({"id":_next_enemy,"type":spawn.type,"route":int(spawn.route),"distance":0.0,"hp":float(enemy_traits.hp)*scale_hp,"max_hp":float(enemy_traits.hp)*scale_hp,"slow":0.0})
		_next_enemy += 1
	for enemy in enemies.duplicate():
		enemy.slow = maxf(0.0,float(enemy.slow)-DT)
		var enemy_traits: Dictionary = ENEMIES[str(enemy.type)]
		enemy.distance = float(enemy.distance)+float(enemy_traits.speed)*DT*(0.5 if float(enemy.slow)>0.0 else 1.0)
		if float(enemy.distance)>=float(routes[int(enemy.route)].size()-1):
			hearts = maxi(0,hearts-int(enemy_traits.leak))
			leaked += 1
			enemies.erase(enemy)
			if hearts<=0:
				status = "lost"
				return
	for projectile in projectiles.duplicate():
		projectile.left = float(projectile.left)-DT
		if float(projectile.left)<=0.0:
			var target: Dictionary = _enemy(int(projectile.target))
			if not target.is_empty():
				_hit(projectile,target)
			projectiles.erase(projectile)
	for enemy in enemies.duplicate():
		if float(enemy.hp)<=0.0:
			killed += 1
			supplies += int(ENEMIES[str(enemy.type)].bounty)
			enemies.erase(enemy)
	for tower in towers:
		tower.cooldown = maxf(0.0,float(tower.cooldown)-DT)
		if float(tower.cooldown)>0.0:
			continue
		var data: Dictionary = TOWERS[str(tower.kind)]
		var origin: Vector2 = pads[int(tower.pad)]
		var range_value: float = float(data.range)+(int(tower.level)-1)*0.25
		var chosen: Dictionary = {}
		var shortest: float = INF
		for enemy in enemies:
			var remaining: float = routes[int(enemy.route)].size()-1-float(enemy.distance)
			if enemy_position(enemy).distance_to(origin)<=range_value and remaining<shortest:
				chosen = enemy
				shortest = remaining
		if chosen.is_empty():
			continue
		var period: float = float(data.period)/(1.0+(int(tower.level)-1)*0.08)*(0.65 if rally_left>0.0 else 1.0)
		tower.cooldown = period
		tower.shots = int(tower.shots)+1
		projectiles.append({"from":origin,"target":int(chosen.id),"left":0.15,"duration":0.15,"kind":str(tower.kind),"damage":float(data.damage)*(1.0+(int(tower.level)-1)*0.55)*(1.0+_power*0.04),"splash":float(data.splash),"slow":float(data.slow)})
	if _spawn_queue.is_empty() and enemies.is_empty():
		projectiles.clear()
		waves_cleared += 1
		status = "won" if mode!="endless" and waves_cleared>=int(definition.waves.size()) else "ready"

func stars() -> int:
	if status!="won":
		return 0
	return 3 if hearts==max_hearts else (2 if hearts>=int(ceil(max_hearts*0.5)) else 1)

func result() -> Dictionary:
	return {"finished":status in ["won","lost"],"won":status=="won","mode":mode,"mission":int(definition.get("id",0)),"day":str(definition.get("day","")),"kills":killed,"waves":waves_cleared,"seconds":int(floor(elapsed)),"hearts":hearts,"stars":stars(),"built":built,"upgrades":upgrades_bought,"rallies":rally_uses,"assisted":assisted,"score":killed*15+waves_cleared*100+maxi(0,hearts)*10}

func snapshot() -> Dictionary:
	return {"status":status,"supplies":supplies,"hearts":hearts,"elapsed":elapsed,"wave_elapsed":wave_elapsed,"wave_index":wave_index,"waves_cleared":waves_cleared,"killed":killed,"leaked":leaked,"built":built,"upgrades":upgrades_bought,"assisted":assisted,"rally_left":rally_left,"rally_cooldown":rally_cooldown,"towers":towers.duplicate(true),"enemies":enemies.duplicate(true),"projectiles":projectiles.duplicate(true),"spawn_queue":_spawn_queue.duplicate(true)}

