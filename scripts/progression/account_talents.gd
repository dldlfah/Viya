extends RefCounted
## One shared account table. Stage values are cumulative, never summed together.
const SCHEMA := 2
const ATTACK_COSTS := [1000, 50000, 1000000]
const ATTACK_BONUSES := [0.0, 0.05, 0.10, 0.15]
const IDS := ["attack_power", "attack_speed", "max_hp", "damage_reduction", "hp_regen", "mp_regen"]
const DEFINITIONS := {
	"attack_power": {"name": "공격력 증가", "category": "attack", "values": ATTACK_BONUSES, "unit": "percent"},
	"attack_speed": {"name": "공격 속도 증가", "category": "attack", "values": [0.0, 0.02, 0.04, 0.06], "unit": "percent"},
	"max_hp": {"name": "최대 HP 증가", "category": "defense", "values": ATTACK_BONUSES, "unit": "percent"},
	"damage_reduction": {"name": "받는 피해 감소", "category": "defense", "values": [0.0, 0.01, 0.02, 0.03], "unit": "reduction"},
	"hp_regen": {"name": "초당 HP 회복", "category": "recovery", "values": [0.0, 0.05, 0.10, 0.15], "unit": "flat"},
	"mp_regen": {"name": "초당 MP 회복", "category": "recovery", "values": [0.0, 0.05, 0.10, 0.15], "unit": "flat"}}

static func valid_level(value: Variant) -> bool:
	return value is int and value >= 0 and value <= 3

static func empty_levels() -> Dictionary:
	var result := {}
	for id in IDS:
		result[id] = 0
	return result

static func valid_levels(value: Variant) -> bool:
	if not value is Dictionary or value.size() != IDS.size():
		return false
	for id in IDS:
		if not valid_level(value.get(id)):
			return false
	return true

static func from_attack(level: int) -> Dictionary:
	if not valid_level(level):
		return {}
	var result := empty_levels()
	result.attack_power = level
	return result

static func bonuses(levels: Dictionary) -> Dictionary:
	var result := {}
	for id in IDS:
		result[id] = float(DEFINITIONS[id].values[levels[id]])
	return result

static func power_multiplier(level: int) -> float:
	return 1.0 + float(ATTACK_BONUSES[level])

static func maximum_hp(base: int, levels: Dictionary) -> int:
	return int(round(base * (1.0 + float(DEFINITIONS.max_hp.values[levels.max_hp]))))

static func effect_text(id: String, level: int) -> String:
	var definition: Dictionary = DEFINITIONS[id]
	var value: float = float(definition.values[level])
	if definition.unit == "flat":
		return "+%.2f" % value
	return ("-%.0f%%" if definition.unit == "reduction" else "+%.0f%%") % (value * 100.0)

static func gold_text(value: int) -> String:
	var digits := str(value)
	var result := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result
