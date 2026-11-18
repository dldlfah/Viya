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
	if rules.waves[0].from != 0.0:
		return false
	if not rules.get("enemy_mix") is Dictionary or rules.enemy_mix.size() != 4:
		return false
	var weight := 0.0
	for key in ["normal", "ranged", "fast", "heavy"]:
		if not number(rules.enemy_mix.get(key), 0, 100):
			return false
		weight += float(rules.enemy_mix[key])
	if not is_equal_approx(weight, 100.0) or not number(rules.get("fast_speed_scale"), 1.01, 5):
		return false
	if not number(rules.get("heavy_speed_scale"), 0.1, 0.99):
		return false
	if not rules.get("ranged") is Dictionary or not rules.get("swarm") is Dictionary:
		return false
	for key in ["speed_scale", "range", "keep_distance", "interval", "windup", "bullet_speed", "bullet_life", "damage"]:
		if not number(rules.ranged.get(key), 0.01, 1000):
			return false
	if rules.ranged.keep_distance >= rules.ranged.range or rules.ranged.damage != floor(rules.ranged.damage):
		return false
	for wave in rules.waves:
		if float(wave.speed) * maxf(float(rules.fast_speed_scale), float(rules.ranged.speed_scale)) > 1000.0:
			return false
	for key in ["interval", "speed", "life", "spacing"]:
		if not number(rules.swarm.get(key), 0.01, 1000):
			return false
	if float(rules.swarm.speed) * float(rules.swarm.life) > 50000.0 or float(rules.ranged.bullet_speed) * float(rules.ranged.bullet_life) > 50000.0:
		return false
	return number(rules.swarm.get("chance"), 0, 1)

static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return value is float and is_finite(value) and value >= minimum and value <= maximum
