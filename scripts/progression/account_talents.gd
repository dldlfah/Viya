extends RefCounted
## One shared account table. Stage values are cumulative, never summed together.
const SCHEMA := 3
const ATTACK_COSTS := [1000, 50000, 1000000]
const ATTACK_BONUSES := [0.0, 0.05, 0.10, 0.15]
const ROOT_IDS := ["attack_power", "attack_speed", "max_hp", "damage_reduction", "hp_regen", "mp_regen"]
const IDS := ROOT_IDS + ["crit_chance", "crit_damage", "projectile_speed", "attack_range", "move_speed", "invulnerability", "knockback_resist", "status_resist", "healing_efficiency", "kill_heal", "max_mana", "mana_cost_reduction"]
const CHAINS := {"attack": [["attack_power", "crit_chance", "crit_damage"], ["attack_speed", "projectile_speed", "attack_range"]],
	"defense": [["max_hp", "move_speed", "invulnerability"], ["damage_reduction", "knockback_resist", "status_resist"]],
	"recovery": [["hp_regen", "healing_efficiency", "kill_heal"], ["mp_regen", "max_mana", "mana_cost_reduction"]]}
const DESCRIPTIONS := {
	"crit_chance": "모든 공격·필살기에 적용하며 전투 패시브와 합산합니다.",
	"crit_damage": "기본 치명타 2배에 추가: 최종 2.05 / 2.10 / 2.15배.",
	"projectile_speed": "아군 탄환의 비행 속도를 높입니다.",
	"attack_range": "표적 탐색·범위 공격 반경·연쇄 거리·필살기 반경에 적용합니다.",
	"move_speed": "기존 이동 속도에 배율로 적용합니다.",
	"invulnerability": "피격 후 무적시간은 최대 0.94초입니다.",
	"knockback_resist": "비행 무리 피격 시 밀려나는 거리를 줄입니다.",
	"status_resist": "현재 원거리 피격으로 생기는 둔화의 시간을 줄입니다.",
	"healing_efficiency": "초당 회복·처치 회복·체력 강화 회복에 적용합니다.",
	"kill_heal": "초당 기본 회복 상한 0.30 / 0.60 / 0.90. 회복 효율은 추가 적용됩니다.",
	"max_mana": "캐릭터의 기본 최대 MP에 추가합니다.",
	"mana_cost_reduction": "필살기의 마나 소모 비율을 줄입니다."}
const DEFINITIONS := {
	"attack_power": {"name": "공격력 증가", "category": "attack", "values": ATTACK_BONUSES, "unit": "percent"},
	"attack_speed": {"name": "공격 속도 증가", "category": "attack", "values": [0.0, 0.02, 0.04, 0.06], "unit": "percent"},
	"max_hp": {"name": "최대 HP 증가", "category": "defense", "values": ATTACK_BONUSES, "unit": "percent"},
	"damage_reduction": {"name": "받는 피해 감소", "category": "defense", "values": [0.0, 0.01, 0.02, 0.03], "unit": "reduction"},
	"hp_regen": {"name": "초당 HP 회복", "category": "recovery", "values": [0.0, 0.05, 0.10, 0.15], "unit": "flat"},
	"mp_regen": {"name": "초당 MP 회복", "category": "recovery", "values": [0.0, 0.05, 0.10, 0.15], "unit": "flat"},
	"crit_chance": {"name": "[임시] 치명타 확률", "category": "attack", "parent": "attack_power", "values": [0.0, 0.01, 0.02, 0.03], "unit": "points"},
	"crit_damage": {"name": "[임시] 치명타 피해량", "category": "attack", "parent": "crit_chance", "values": [0.0, 0.05, 0.10, 0.15], "unit": "points"},
	"projectile_speed": {"name": "[임시] 투사체 속도", "category": "attack", "parent": "attack_speed", "values": [0.0, 0.05, 0.10, 0.15], "unit": "percent"},
	"attack_range": {"name": "[임시] 공격 범위", "category": "attack", "parent": "projectile_speed", "values": [0.0, 0.03, 0.06, 0.09], "unit": "percent"},
	"move_speed": {"name": "[임시] 이동 속도", "category": "defense", "parent": "max_hp", "values": [0.0, 0.02, 0.04, 0.06], "unit": "percent"},
	"invulnerability": {"name": "[임시] 피격 무적시간", "category": "defense", "parent": "move_speed", "values": [0.0, 0.03, 0.06, 0.09], "unit": "seconds"},
	"knockback_resist": {"name": "[임시] 밀어내기 저항", "category": "defense", "parent": "damage_reduction", "values": [0.0, 0.05, 0.10, 0.15], "unit": "reduction"},
	"status_resist": {"name": "[임시] 상태이상 지속시간 감소", "category": "defense", "parent": "knockback_resist", "values": [0.0, 0.05, 0.10, 0.15], "unit": "reduction"},
	"healing_efficiency": {"name": "[임시] HP 회복 효율", "category": "recovery", "parent": "hp_regen", "values": [0.0, 0.05, 0.10, 0.15], "unit": "percent"},
	"kill_heal": {"name": "[임시] 적 처치 시 HP 회복", "category": "recovery", "parent": "healing_efficiency", "values": [0.0, 0.05, 0.10, 0.15], "unit": "flat"},
	"max_mana": {"name": "[임시] 최대 MP", "category": "recovery", "parent": "mp_regen", "values": [0.0, 5.0, 10.0, 15.0], "unit": "flat"},
	"mana_cost_reduction": {"name": "[임시] MP 소모량 감소", "category": "recovery", "parent": "max_mana", "values": [0.0, 0.02, 0.04, 0.06], "unit": "reduction"}}

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
	for id in IDS:
		var parent: String = DEFINITIONS[id].get("parent", "")
		if not parent.is_empty() and value[id] > value[parent]:
			return false
	return true

static func expand_six(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != ROOT_IDS.size():
		return {}
	var result := empty_levels()
	for id in ROOT_IDS:
		if not valid_level(value.get(id)):
			return {}
		result[id] = value[id]
	return result

static func can_purchase(levels: Dictionary, id: String, expected: int) -> bool:
	if not valid_levels(levels) or id not in IDS or not valid_level(expected) or expected >= 3 or levels[id] != expected:
		return false
	var parent: String = DEFINITIONS[id].get("parent", "")
	return parent.is_empty() or levels[parent] >= expected + 1

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
	if definition.unit == "seconds":
		return "+%.2f초" % value
	if definition.unit == "points":
		return "+%.0f%%p" % (value * 100.0)
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
