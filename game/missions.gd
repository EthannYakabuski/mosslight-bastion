class_name BastionMissions
extends RefCounted

static func data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://game/missions.json"))
	return parsed if parsed is Dictionary else {}

static func count() -> int:
	return data().get("missions",[]).size()

static func campaign(number: int) -> Dictionary:
	var all: Array = data().get("missions",[])
	return all[clampi(number-1,0,all.size()-1)].duplicate(true) if not all.is_empty() else {}

static func daily(day: String) -> Dictionary:
	var number: int = posmod(int(day.replace("-","")),count())+1
	var mission: Dictionary = campaign(number)
	mission.mode = "daily"
	mission.day = day
	mission.name = "Daily lantern · "+day
	mission.hint = "The day deterministically selects an authored mission. Preparation upgrades are disabled here. Waves arrive automatically; an earned repair can help defend the same record."
	return mission

static func endless() -> Dictionary:
	var mission: Dictionary = campaign(8)
	mission.mode = "endless"
	mission.id = 0
	mission.name = "Endless siege"
	mission.budget = 190
	mission.hearts = 18
	mission.hp_scale = 1.0
	mission.hint = "Waves arrive automatically. Build during the countdown, use free Rally and hold the wall. Earned repairs can help set a new best."
	return mission
