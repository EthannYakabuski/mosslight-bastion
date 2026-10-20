class_name BastionProgress
extends RefCounted
## Typed, bounded local progress. Test callers supply their own isolated save path/day.

const CAP: int = 2000000000
const QUESTS: Dictionary = {"kills":{"target":40,"coins":75,"xp":20},"waves":{"target":5,"coins":60,"xp":15},"towers":{"target":6,"coins":55,"xp":15}}
var data: Dictionary = {}
var path: String = "user://mosslight_progress_v1.json"
var last_save_ok: bool = true
var recovered_backup: bool = false
var _day_override: String = ""

func _init(save_path: String = "user://mosslight_progress_v1.json", day_override: String = "") -> void:
	path = save_path
	_day_override = day_override
	load_progress()

static func defaults() -> Dictionary:
	return {"version":1,"coins":150,"xp":0,"completed":{},"unassisted_stars":{},"kills":0,"rounds":0,"waves":0,"towers_built":0,"upgrades_bought":0,"rallies":0,"best_endless":{"score":0,"wave":0},"best_daily":{},"preparation":{"power":0,"fortify":0},"cosmetics":{"moss":true},"settings":{"sound":true,"music":true,"skin":"moss"},"day":"","login_day":"","streak":0,"daily":{"kills":0,"waves":0,"towers":0},"daily_claimed":{},"daily_clears":{},"unlocked":{},"run_sequence":0,"credited_runs":[]}

static func level_for(xp: int) -> int:
	return 1+int(floor(sqrt(float(maxi(0,xp))/100.0)))

func level() -> int:
	return level_for(int(data.xp))

func _bounded(value: Variant, fallback: int = 0, top: int = CAP) -> int:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):
		return fallback
	return clampi(int(value),0,top)

static func valid_day(day: String) -> bool:
	var pieces: PackedStringArray = day.split("-")
	if pieces.size()!=3 or pieces[0].length()!=4 or pieces[1].length()!=2 or pieces[2].length()!=2:
		return false
	for piece in pieces:
		if not piece.is_valid_int(): return false
	var year: int = int(pieces[0])
	var month: int = int(pieces[1])
	var date: int = int(pieces[2])
	if year<1970 or year>9999 or month<1 or month>12: return false
	var days: Array = [31,29 if year%400==0 or (year%4==0 and year%100!=0) else 28,31,30,31,30,31,31,30,31,30,31]
	return date>=1 and date<=int(days[month-1])

func current_day() -> String:
	var observed: String = _day_override if valid_day(_day_override) else Time.get_date_string_from_system(true)
	return str(data.day) if valid_day(str(data.get("day",""))) and str(data.day)>observed else observed

func _normalize(raw: Dictionary) -> Dictionary:
	var clean: Dictionary = defaults()
	for key in ["coins","xp","kills","rounds","waves","towers_built","upgrades_bought","rallies","run_sequence"]:
		clean[key] = _bounded(raw.get(key,clean[key]),int(clean[key]))
	clean.streak = _bounded(raw.get("streak",0),0,7)
	for key in ["completed","unassisted_stars"]:
		var stored: Variant = raw.get(key,{})
		if stored is Dictionary:
			for mission in stored:
				if str(mission).is_valid_int() and int(mission)>=1 and int(mission)<=30:
					var stars: int = _bounded(stored[mission],0,3)
					if stars>0: clean[key][str(int(mission))] = stars
	for key in ["day","login_day"]:
		clean[key] = str(raw.get(key,"")) if valid_day(str(raw.get(key,""))) else ""
	var prep: Variant = raw.get("preparation",{})
	if prep is Dictionary:
		for key in ["power","fortify"]: clean.preparation[key]=_bounded(prep.get(key,0),0,5)
	var settings: Variant = raw.get("settings",{})
	if settings is Dictionary:
		for key in ["music","sound"]:
			if typeof(settings.get(key))==TYPE_BOOL: clean.settings[key]=settings[key]
	var cosmetics: Variant = raw.get("cosmetics",{})
	if cosmetics is Dictionary:
		for key in ["moss","amber","moon"]:
			if cosmetics.get(key,false)==true: clean.cosmetics[key]=true
	if settings is Dictionary and clean.cosmetics.has(str(settings.get("skin","moss"))): clean.settings.skin=str(settings.get("skin","moss"))
	var endless: Variant = raw.get("best_endless",{})
	if endless is Dictionary:
		clean.best_endless={"score":_bounded(endless.get("score",0)),"wave":_bounded(endless.get("wave",0))}
	for key in ["best_daily","daily_clears"]:
		var stored: Variant = raw.get(key,{})
		if stored is Dictionary:
			for day in stored:
				if valid_day(str(day)) and (key=="best_daily" or stored[day]==true):
					clean[key][str(day)] = _bounded(stored[day]) if key=="best_daily" else true
	var daily: Variant = raw.get("daily",{})
	if daily is Dictionary:
		for key in QUESTS: clean.daily[key]=_bounded(daily.get(key,0),0,1000000)
	var claimed: Variant = raw.get("daily_claimed",{})
	if claimed is Dictionary:
		for key in QUESTS:
			if claimed.get(key,false)==true: clean.daily_claimed[key]=true
	var unlocked: Variant = raw.get("unlocked",{})
	if unlocked is Dictionary:
		var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
		if catalog is Dictionary:
			for row in catalog.get("achievements",[]):
				if unlocked.get(str(row.id),false)==true: clean.unlocked[str(row.id)]=true
	var credited: Variant = raw.get("credited_runs",[])
	if credited is Array:
		for id in credited:
			if id is String and id.length()>0 and id.length()<=96 and not clean.credited_runs.has(id): clean.credited_runs.append(id)
		while clean.credited_runs.size()>128: clean.credited_runs.pop_front()
	return clean

func load_progress() -> void:
	data = defaults()
	for candidate in [path,path+".backup"]:
		if not FileAccess.file_exists(candidate): continue
		var parsed: Variant = _read_save(candidate)
		if parsed is Dictionary and parsed.get("version")==1:
			data = _normalize(parsed)
			recovered_backup = candidate!=path
			break
	roll_day()

func _read_save(candidate: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(candidate))==OK else null

func roll_day() -> void:
	var today: String = current_day()
	if str(data.day).is_empty() or today>str(data.day):
		data.day = today
		data.daily = {"kills":0,"waves":0,"towers":0}
		data.daily_claimed = {}

func save() -> bool:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:
		last_save_ok=false
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	var checked: Variant = _read_save(path+".tmp")
	if not checked is Dictionary or checked.get("version")!=1 or _normalize(checked)!=_normalize(data):
		last_save_ok=false
		return false
	var main_path: String = ProjectSettings.globalize_path(path)
	var backup_path: String = ProjectSettings.globalize_path(path+".backup")
	var temp_path: String = ProjectSettings.globalize_path(path+".tmp")
	if FileAccess.file_exists(path):
		var prior: Variant = _read_save(path)
		var prior_valid: bool = prior is Dictionary and prior.get("version")==1
		if prior_valid:
			if FileAccess.file_exists(path+".backup") and DirAccess.remove_absolute(backup_path)!=OK:
				last_save_ok=false
				return false
		elif _rename_file(main_path,main_path+".invalid-"+str(Time.get_ticks_usec()))!=OK:
			last_save_ok=false
			return false
		if prior_valid and _rename_file(main_path,backup_path)!=OK:
			last_save_ok=false
			return false
	last_save_ok = _rename_file(temp_path,main_path)==OK
	if not last_save_ok and FileAccess.file_exists(path+".backup") and not FileAccess.file_exists(path):
		# Copy instead of consuming the only known-good backup on a failed commit.
		DirAccess.copy_absolute(backup_path,main_path)
	return last_save_ok

func _rename_file(from_path: String, to_path: String) -> Error:
	return DirAccess.rename_absolute(from_path,to_path)

func begin_run() -> String:
	roll_day()
	data.run_sequence = mini(CAP,int(data.run_sequence)+1)
	save()
	return str(data.day)+":"+str(data.run_sequence)

func _add_xp(amount: int) -> int:
	var prior: int = level()
	data.xp = mini(CAP,int(data.xp)+maxi(0,amount))
	var bonus: int = (level()-prior)*40
	data.coins = mini(CAP,int(data.coins)+bonus)
	return bonus

func available(number: int) -> bool:
	return number==1 or data.completed.has(str(number-1))

func star_total(unassisted: bool = false) -> int:
	var total: int = 0
	for stars in (data.unassisted_stars if unassisted else data.completed).values(): total+=int(stars)
	return total

func record_result(run_id: String, result: Dictionary) -> Dictionary:
	if run_id.is_empty() or data.credited_runs.has(run_id) or not bool(result.get("finished",false)):
		return {"recorded":false}
	var mode: String = str(result.get("mode",""))
	if mode not in ["campaign","daily","endless"]: return {"recorded":false}
	var mission: int = int(result.get("mission",0))
	if mode=="campaign" and (mission<1 or mission>30 or not available(mission)): return {"recorded":false}
	roll_day()
	var kills: int = _bounded(result.get("kills",0),0,1000000)
	var waves: int = _bounded(result.get("waves",0),0,100000)
	var won: bool = bool(result.get("won",false))
	var coins: int = kills*2
	var xp: int = kills*2+waves*4
	var first_clear: bool = false
	var daily_bonus: bool = false
	if mode=="campaign" and won:
		first_clear = not data.completed.has(str(mission))
		coins += 90+mission*5 if first_clear else 30
		xp += 45+mission*5 if first_clear else 20
		data.completed[str(mission)] = maxi(int(data.completed.get(str(mission),0)),clampi(int(result.get("stars",1)),1,3))
		if not bool(result.get("assisted",false)):
			data.unassisted_stars[str(mission)] = maxi(int(data.unassisted_stars.get(str(mission),0)),int(result.stars))
	elif mode=="daily" and won:
		var day: String = str(result.get("day",""))
		if day==str(data.day) and not data.daily_clears.has(day):
			daily_bonus = true
			data.daily_clears[day]=true
			coins += 75
			xp += 35
		coins += 30
		xp += 20
		if day==str(data.day) and not bool(result.get("assisted",false)):
			data.best_daily[day] = maxi(int(data.best_daily.get(day,0)),_bounded(result.get("score",0)))
	if mode=="endless" and not bool(result.get("assisted",false)):
		data.best_endless.score = maxi(int(data.best_endless.score),_bounded(result.get("score",0)))
		data.best_endless.wave = maxi(int(data.best_endless.wave),waves)
	data.rounds = mini(CAP,int(data.rounds)+1)
	data.kills = mini(CAP,int(data.kills)+kills)
	data.waves = mini(CAP,int(data.waves)+waves)
	data.towers_built = mini(CAP,int(data.towers_built)+_bounded(result.get("built",0)))
	data.upgrades_bought = mini(CAP,int(data.upgrades_bought)+_bounded(result.get("upgrades",0)))
	data.rallies = mini(CAP,int(data.rallies)+_bounded(result.get("rallies",0)))
	data.daily.kills = mini(1000000,int(data.daily.kills)+kills)
	data.daily.waves = mini(1000000,int(data.daily.waves)+waves)
	data.daily.towers = mini(1000000,int(data.daily.towers)+_bounded(result.get("built",0)))
	data.coins = mini(CAP,int(data.coins)+coins)
	var level_bonus: int = _add_xp(xp)
	data.credited_runs.append(run_id)
	while data.credited_runs.size()>128: data.credited_runs.pop_front()
	_check_achievements()
	save()
	return {"recorded":true,"coins":coins+level_bonus,"xp":xp,"level_bonus":level_bonus,"first_clear":first_clear,"daily_bonus":daily_bonus,"assisted":bool(result.get("assisted",false))}

func claim_login() -> Dictionary:
	roll_day()
	if str(data.login_day)==str(data.day): return {"claimed":false}
	var prior_day: String = str(data.login_day)
	var consecutive: bool = valid_day(prior_day) and int(Time.get_unix_time_from_datetime_string(str(data.day)+"T00:00:00"))-int(Time.get_unix_time_from_datetime_string(prior_day+"T00:00:00"))==86400
	data.streak = (int(data.streak)%7)+1 if consecutive else 1
	data.login_day = data.day
	var coins: int = 50+15*(int(data.streak)-1)
	data.coins = mini(CAP,int(data.coins)+coins)
	var bonus: int = _add_xp(10)
	_check_achievements()
	save()
	return {"claimed":true,"coins":coins+bonus,"xp":10,"streak":int(data.streak)}

func claim_quest(key: String) -> Dictionary:
	roll_day()
	if not QUESTS.has(key) or data.daily_claimed.has(key) or int(data.daily[key])<int(QUESTS[key].target): return {"claimed":false}
	data.daily_claimed[key] = true
	var coins: int = int(QUESTS[key].coins)
	var xp: int = int(QUESTS[key].xp)
	data.coins = mini(CAP,int(data.coins)+coins)
	var bonus: int = _add_xp(xp)
	_check_achievements()
	save()
	return {"claimed":true,"coins":coins+bonus,"xp":xp}

func preparation_cost(kind: String) -> int:
	return int(round(100.0*pow(1.65,int(data.preparation[kind])))) if data.preparation.has(kind) and int(data.preparation[kind])<5 else -1

func buy_preparation(kind: String) -> bool:
	var cost: int = preparation_cost(kind)
	if cost<0 or int(data.coins)<cost: return false
	data.coins = int(data.coins)-cost
	data.preparation[kind] = int(data.preparation[kind])+1
	save()
	return true

func choose_skin(kind: String) -> bool:
	if kind not in ["moss","amber","moon"]: return false
	if not data.cosmetics.has(kind):
		var cost: int = 150 if kind=="amber" else 250
		if int(data.coins)<cost: return false
		data.coins = int(data.coins)-cost
		data.cosmetics[kind]=true
	data.settings.skin=kind
	save()
	return true

func metric(key: String) -> int:
	match key:
		"clears": return data.completed.size()
		"stars": return star_total()
		"level": return level()
		"endless_wave": return int(data.best_endless.wave)
		"daily_clears": return data.daily_clears.size()
	return int(data.get(key,0))

func _check_achievements() -> void:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	if catalog is Dictionary:
		for row in catalog.get("achievements",[]):
			if metric(str(row.metric))>=int(row.target): data.unlocked[str(row.id)]=true

func leaderboard_values() -> Dictionary:
	return {"unassisted_endless_score":int(data.best_endless.score),"unassisted_daily_score":int(data.best_daily.get(str(data.day),0)),"unassisted_stars":star_total(true),"player_level":level()}
