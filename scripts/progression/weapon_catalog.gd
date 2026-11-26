extends RefCounted
## Versioned, provisional skill library. No runtime state, target search or RNG.
const PATH := "res://data/weapon_skills.json"
const RULESET := "weapons_v1"
const FAMILIES := ["gun", "bow", "sword", "magic"]
const MODES := ["projectile", "blast", "cone", "chain", "zone", "orbit", "dash"]
const INTS := ["projectiles", "hits", "bursts", "fragments", "bounces", "echoes", "ticks", "targets", "branches"]
const NUMBERS := ["damage", "interval", "reach", "speed", "spread", "burst_gap", "radius", "homing", "return_after", "impact", "slow", "slow_duration", "knockback", "mark", "mark_burst", "life", "width", "tick_gap", "duration", "orbit_radius", "orbit_speed", "travel", "angle", "delay", "link_range"]
var entries: Dictionary = {}
var characters: Dictionary = {}
var error := ""

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary or parsed.get("schema_version") != 1 or not parsed.get("families") is Dictionary or not parsed.get("characters") is Dictionary:
		error = "Invalid weapon library"
		return
	for family in FAMILIES:
		var list: Variant = parsed.families.get(family)
		if not list is Array or list.size() != 8:
			error = "Invalid family pool"
			return
		for entry in list:
			if not valid_attack(entry) or entry.family != family or entry.kind != "attack" or entry.owner != "" or entries.has(entry.id):
				error = "Invalid/duplicate family skill"
				return
			entries[entry.id] = entry.duplicate(true)
	characters = parsed.characters.duplicate(true)
	for id in characters:
		var hero: Variant = characters[id]
		if not hero is Dictionary or not hero.get("skills") is Array:
			error = "Invalid character loadout"
			return
		for entry in hero.skills:
			if entry.get("kind") == "character":
				if not valid_attack(entry) or entry.owner != id or entries.has(entry.id):
					error = "Invalid unique automatic skill"
					return
				entries[entry.id] = entry.duplicate(true)
		if not valid_hero(hero,id):
			error = "Invalid selected attack pool/start/uniques"
			return
		for skill_id in hero.starting_levels:
			hero.starting_levels[skill_id] = int(hero.starting_levels[skill_id])

static func valid_attack(entry: Variant) -> bool:
	if not entry is Dictionary or not entry.get("id") is String or entry.id.is_empty() or entry.get("effect") != entry.id or entry.get("family") not in FAMILIES or entry.get("mode") not in MODES or entry.get("kind") not in ["attack", "character"] or entry.get("row") != "attack" or entry.get("max_level") != 5 or entry.get("prototype") != true or not str(entry.get("name", "")).begins_with("[임시] "):
		return false
	if not entry.get("levels") is Array or entry.levels.size() != 5:
		return false
	for level in entry.levels:
		if not valid_parameters(level):
			return false
	return true

static func valid_parameters(value: Variant) -> bool:
	if not value is Dictionary or not value.get("change") is String or not value.get("follow") is bool or value.get("target") not in ["nearest", "strongest"]:
		return false
	for key in NUMBERS + INTS:
		var number: Variant = value.get(key)
		if not (number is float or number is int) or not is_finite(number) or number < 0 or number > 10000:
			return false
		if key in INTS and (number != floor(number) or number > 32):
			return false
	if value.damage <= 0 or value.interval <= 0 or value.life <= 0 or value.hits < 1 or value.projectiles < 1 or value.bursts < 1 or value.ticks < 1 or value.targets < 1 or value.branches < 1 or value.slow > 0.8:
		return false
	return true

func valid_hero(hero: Dictionary, id: String) -> bool:
	if not hero.get("families") is Array or hero.families.is_empty() or not hero.families.all(func(f): return f in FAMILIES) or not hero.get("attack_pool") is Array or hero.attack_pool.size() != 8 or not hero.get("starting_levels") is Dictionary or not hero.get("skills") is Array or hero.skills.size() != 2:
		return false
	var used := {}
	for skill_id in hero.attack_pool:
		if not entries.has(skill_id) or used.has(skill_id) or entries[skill_id].kind != "attack" or entries[skill_id].family not in hero.families:
			return false
		used[skill_id] = true
	var automatic := ""
	var manual := ""
	for entry in hero.skills:
		if entry.get("owner") != id:
			return false
		if entry.get("kind") == "character":
			automatic = str(entry.id)
		elif entry.get("kind") == "ultimate":
			manual = str(entry.id)
	if automatic != hero.get("unique_auto") or automatic.is_empty() or manual != hero.get("active_magic", {}).get("upgrade_skill_id") or manual.is_empty() or hero.get("starting_attack") not in hero.attack_pool:
		return false
	return hero.starting_levels.size()==1 and hero.starting_levels.get(hero.starting_attack)==1

func profile(id: String, rank: int, stats: Dictionary) -> Dictionary:
	if not error.is_empty() or not entries.has(id) or rank < 1 or rank > 5 or float(stats.get("rate", 0)) <= 0:
		return {}
	var entry: Dictionary = entries[id]
	var result: Dictionary = entry.levels[rank - 1].duplicate(true)
	for key in INTS:
		result[key] = int(result[key])
	result.merge({"id":id, "family":entry.family, "mode":entry.mode, "rank":rank, "evolved":rank == 5})
	result.interval /= float(stats.rate)
	result.speed *= float(stats.get("projectile_speed",1.0))
	for key in ["reach", "radius", "width", "impact", "orbit_radius", "mark_burst", "link_range"]:
		result[key] *= float(stats.get("attack_range",1.0))
	return result
