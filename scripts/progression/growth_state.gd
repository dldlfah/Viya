extends RefCounted
## Owns XP, choice tickets and equipped levels. No node/timer/UI ownership here.
const Catalog = preload("res://scripts/progression/skill_catalog.gd")
const ATTACK_CAP := 4 # Existing prototype UI cap, not the eight-type pool size.
const PASSIVE_CAP := 4
const XP_REQUIREMENT_MULTIPLIER := 3.0 # Required XP only; rewards stay unchanged.
var catalog = Catalog.new()
var character_id: String = "viya"
var pool: Array[Dictionary] = []
var owned: Dictionary = {}
var level: int = 1
var xp: float = 0.0
var pending: int = 0
var offer: Array[String] = []
var ticket: int = 0 # Never reset: callbacks from a prior run must stay stale.
var revision: int = 0
var rng := RandomNumberGenerator.new()
var ruleset: String = "legacy"
var pacing_version:int=0 # Published1-13 retain their exact XP/offer policy.
var pacing_mode:String="campaign"
var pacing=preload("res://scripts/progression/combat_pacing.gd").new()

func reset(id: String, seed_value: int, selected_ruleset: String = "legacy", version:int=0, mode:String="campaign") -> bool:
	if version not in [0,1] or mode not in ["campaign","gold_slime"] or (version==1 and (selected_ruleset!="weapons_v1" or pacing.data.is_empty())):return false
	var candidate: Array[Dictionary] = catalog.pool_for(id,selected_ruleset)
	if not catalog.validate_pool(candidate, id):
		return false # No silent Viya fallback for an unknown character.
	character_id = id
	ruleset = selected_ruleset
	pacing_version=version
	pacing_mode=mode
	pool = candidate
	owned.clear()
	owned["common_rifle"] = 1 # Preserve existing starting rifle and its HUD slot.
	if ruleset == catalog.weapons.RULESET:
		owned = catalog.hero(id,ruleset).starting_levels.duplicate(true)
	level = 1
	xp = 0.0
	pending = 0
	offer.clear()
	ticket += 1
	revision += 1
	rng.seed = seed_value
	return true

func threshold() -> float:
	return threshold_for(level,pacing_mode,pacing_version)

func threshold_for(at_level:int,mode:String,version:int)->float:
	if version==0:return (10.0+float(at_level-1)*6.0)*XP_REQUIREMENT_MULTIPLIER
	return pacing.base_requirement(at_level,mode)*XP_REQUIREMENT_MULTIPLIER

func gain(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0:
		return
	xp += amount
	while xp >= threshold():
		var cost := threshold()
		xp -= cost
		level += 1
		pending += 1

func definition(id: String) -> Dictionary:
	for entry in pool:
		if entry["id"] == id:
			return entry
	return {}

func skill_level(id: String) -> int:
	return int(owned.get(id, 0))

func row_entries(row: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id in owned:
		var entry := definition(str(id))
		if entry.get("row", "") == row:
			entries.append(entry)
	return entries

func eligible() -> Array[String]:
	var result: Array[String] = []
	var attack_count := row_entries("attack").size()
	var passive_count := row_entries("passive").size()
	for entry in pool:
		var id: String = entry["id"]
		var rank := skill_level(id)
		if rank >= int(entry["max_level"]):
			continue
		if rank == 0:
			if entry["row"] == "attack" and attack_count >= ATTACK_CAP:
				continue
			if entry["row"] == "passive" and passive_count >= PASSIVE_CAP:
				continue
		result.append(id)
	return result

func open_offer() -> void:
	if pending <= 0 or not offer.is_empty():
		return
	var candidates := eligible()
	# Fisher-Yates with a dedicated RNG: spawning/crit rolls cannot reroll a menu.
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporary := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = temporary
	offer.clear()
	for i in range(mini(3, candidates.size())):
		offer.append(candidates[i])
	var focused:String=pacing.focus(self)
	if not focused.is_empty() and not offer.has(focused) and not offer.is_empty():offer[0]=focused
	ticket += 1

func select(id: String, expected_ticket: int) -> bool:
	if expected_ticket != ticket or pending <= 0 or not offer.has(id):
		return false
	if not eligible().has(id):
		return false
	owned[id] = skill_level(id) + 1
	pending -= 1
	offer.clear()
	ticket += 1
	revision += 1
	return true

func acknowledge_exhausted(expected_ticket: int) -> bool:
	if expected_ticket != ticket or pending <= 0 or not eligible().is_empty():
		return false
	# Temporary exhaustion policy: no invented skill/reward, simply resume play.
	pending = 0
	offer.clear()
	ticket += 1
	revision += 1
	return true
