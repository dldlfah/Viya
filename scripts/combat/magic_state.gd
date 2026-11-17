extends RefCounted
## Per-run active magic resources, not an extra level-up candidate or passive slot.
## Values come from the selected character's prototype config. No wall-clock timers.
var config: Dictionary = {}
var owner_id: String = ""
var mana: float = 0.0
var cooldown_left: float = 0.0
var casts: int = 0
var ticket: int = 0 # Monotonic across restarts, phase changes, and successful casts.

func accepts(candidate: Dictionary, character_id: String) -> bool:
	if character_id.is_empty() or candidate.get("owner", "") != character_id:
		return false
	if candidate.get("effect", "") != "radial_burst" or not candidate.get("prototype", false):
		return false
	for key in ["id", "name", "upgrade_skill_id"]:
		if not (candidate.get(key, "") is String) or str(candidate.get(key, "")).is_empty():
			return false
	if not str(candidate["name"]).begins_with("[임시] "):
		return false
	for key in ["max_mana", "mana_cost", "mana_regen", "cooldown", "damage",
		"damage_per_rank", "radius", "radius_per_rank", "effect_duration"]:
		var value = candidate.get(key)
		if not (value is int or value is float):
			return false
		if not is_finite(float(value)) or float(value) < 0.0:
			return false
	for key in ["max_mana", "mana_cost", "cooldown", "damage", "radius", "effect_duration"]:
		if float(candidate[key]) <= 0.0:
			return false
	return float(candidate["mana_cost"]) <= float(candidate["max_mana"])

func reset(candidate: Dictionary, character_id: String) -> bool:
	if not accepts(candidate, character_id):
		return false # Invalid new profile leaves the current run untouched.
	config = candidate.duplicate(true)
	owner_id = character_id
	mana = float(config["max_mana"])
	cooldown_left = 0.0
	casts = 0
	invalidate_requests()
	return true

func invalidate_requests() -> void:
	ticket += 1

func advance(delta: float, running: bool) -> void:
	if not running or config.is_empty() or delta <= 0.0 or not is_finite(delta):
		return
	cooldown_left = maxf(0.0, cooldown_left - delta)
	mana = minf(float(config["max_mana"]), mana + float(config["mana_regen"]) * delta)

func unavailable_reason(running: bool) -> String:
	if not running:
		return "inactive"
	if config.is_empty():
		return "unconfigured"
	if cooldown_left > 0.0:
		return "cooldown"
	if mana < float(config["mana_cost"]):
		return "mana"
	return ""

func profile(rank: int) -> Dictionary:
	if config.is_empty() or rank < 0:
		return {}
	return {"id": config["id"], "owner": owner_id, "name": config["name"],
		"rank": rank, "mana_cost": float(config["mana_cost"]),
		"cooldown": float(config["cooldown"]),
		"damage": float(config["damage"]) + float(config["damage_per_rank"]) * rank,
		"radius": float(config["radius"]) + float(config["radius_per_rank"]) * rank,
		"effect_duration": float(config["effect_duration"])}

func consume(expected_ticket: int, running: bool, rank: int) -> Dictionary:
	if expected_ticket != ticket or not unavailable_reason(running).is_empty():
		return {}
	var result: Dictionary = profile(rank)
	if result.is_empty():
		return {}
	# Deduct before damage/visual callbacks; duplicate inputs cannot spend twice.
	mana = maxf(0.0, mana - float(result["mana_cost"]))
	cooldown_left = float(result["cooldown"])
	casts += 1
	invalidate_requests()
	return result
