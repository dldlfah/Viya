extends RefCounted
## Shared, deterministic PvE damage mitigation and character-intrinsic penetrations.
## These provisional armor rates do NOT replace existing enemy HP or spawn rules.
const MAX_DEFENSE := 0.75
const MAX_PENETRATION := 0.60
const NONE := {"physical_penetration":0.0,"magical_penetration":0.0,
	"physical_defense":0.0,"magical_defense":0.0}
const HERO_TRAITS := {
	"viya":{"physical_penetration":0.15,"magical_penetration":0.0,
		"physical_defense":0.0,"magical_defense":0.0}
}
const ENEMY_RESISTANCE := {
	"normal":{"physical":0.0,"magical":0.0},
	"ranged":{"physical":0.05,"magical":0.05},
	"fast":{"physical":0.0,"magical":0.0},
	"heavy":{"physical":0.30,"magical":0.10},
	"flier":{"physical":0.05,"magical":0.10},
	"elite":{"physical":0.25,"magical":0.15},
	"boss":{"physical":0.35,"magical":0.20}
}

static func character_stats(id: String) -> Dictionary:
	return HERO_TRAITS.get(id,NONE).duplicate(true)

static func valid_supports(main_id: String, attack: Array, passive: Array) -> bool:
	# Main actor and the four supports cannot share the same character or slot.
	if main_id.is_empty() or attack.size()>2 or passive.size()>2:
		return false
	var seen := {main_id:true}
	for slots in [attack,passive]:
		for id in slots:
			if not id is String or not HERO_TRAITS.has(id) or seen.has(id):
				return false
			seen[id] = true
	return true

static func character_penetration(id: String, damage_type: String) -> float:
	if damage_type not in ["physical","magical"]:
		return 0.0
	return float(character_stats(id).get(damage_type+"_penetration",0.0))

static func main_penetration(main_id: String, passive_support_ids: Array, damage_type: String) -> float:
	# Passive support inherits its intrinsic stat only for PHYSICAL/MAGICAL hits
	# of the main hero; attack supports use their OWN trait via source_id.
	if not valid_supports(main_id,[],passive_support_ids):
		return 0.0
	var total := character_penetration(main_id,damage_type)
	for id in passive_support_ids:
		total += character_penetration(str(id),damage_type)
	return clampf(total,0.0,MAX_PENETRATION)

static func armor_rate(kind: String, variant: String, damage_type: String) -> float:
	if damage_type not in ["physical","magical"]:
		return 0.0
	var key := kind if kind in ["elite","boss"] else variant
	var rates: Dictionary = ENEMY_RESISTANCE.get(key,ENEMY_RESISTANCE.normal)
	return clampf(float(rates.get(damage_type,0.0)),0.0,MAX_DEFENSE)

static func mitigated_damage(raw: float, armor: float, penetration: float) -> float:
	if not is_finite(raw) or raw <= 0.0:
		return 0.0
	var effective_armor := clampf(armor,0.0,MAX_DEFENSE) * (1.0-clampf(penetration,0.0,MAX_PENETRATION))
	return raw * (1.0-effective_armor)
