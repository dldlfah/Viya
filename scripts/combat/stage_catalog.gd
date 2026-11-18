extends RefCounted
const PATH := "res://data/stages.json"
var data: Dictionary = {}

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		data = parsed

func for_stage(number: int) -> Dictionary:
	var defaults: Variant = data.get("default")
	var overrides: Variant = data.get("overrides", {})
	if not defaults is Dictionary or not overrides is Dictionary:
		return {}
	var custom: Variant = overrides.get(str(number), {})
	if not custom is Dictionary:
		return {}
	var result: Dictionary = defaults.duplicate(true)
	result.merge(custom, true)
	return result if valid(result) else {}

static func valid(rules: Dictionary) -> bool:
	for key in ["duration", "boss_at"]:
		if not rules.get(key) is float or not is_finite(rules[key]) or rules[key] <= 0.0 or rules[key] > 36000.0:
			return false
	if rules.boss_at >= rules.duration:
		return false
	for key in ["boss_hp", "clear_gold"]:
		if not rules.get(key) is float or not is_finite(rules[key]) or rules[key] < 1 or rules[key] > 1000000 or rules[key] != floor(rules[key]):
			return false # JSON numeric values are floats in Godot.
	for key in ["checkpoints", "elites"]:
		if not rules.get(key) is Array or rules[key].size() != 2:
			return false
		if not (rules[key][0] is float and rules[key][1] is float):
			return false
		if not (0 < rules[key][0] and rules[key][0] < rules[key][1] and rules[key][1] < rules.duration):
			return false
	if not rules.get("elite_hp") is Array or rules.elite_hp.size() != 2:
		return false
	for value in rules.elite_hp:
		if not value is float or not is_finite(value) or value < 1 or value > 1000000 or value != floor(value):
			return false
	if not rules.get("waves") is Array or rules.waves.size() != 3:
		return false
	var previous := -1.0
	for wave in rules.waves:
		if not wave is Dictionary:
			return false
		for key in ["from", "interval", "batch", "hp", "speed"]:
			if not wave.get(key) is float or not is_finite(wave[key]):
				return false
		if wave.from <= previous or wave.from >= rules.duration or wave.interval <= 0.0 or wave.interval > 36000.0 or wave.speed <= 0.0 or wave.speed > 1000.0:
			return false
		if wave.batch < 1 or wave.batch > 8 or wave.hp < 1 or wave.hp > 1000000 or wave.hp != floor(wave.hp) or wave.batch != floor(wave.batch):
			return false
		previous = wave.from
	return rules.waves[0].from == 0.0
