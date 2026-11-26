extends RefCounted
## Locked base stats and provisional map species selection. No battle state here.
const PATH := "res://data/combat_profiles.json"
const VARIANTS := ["normal","ranged","fast","heavy","flier"]
var data: Dictionary = {}
var error: String = ""

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not valid(parsed):
		error = "Invalid character/species profile data"
		return
	data = parsed
	# The stage field reuses locked species/stats; published maps stay byte-identical.
	if data.maps.has("prologue_wall"):
		data.maps["siege_battlefield"]=data.maps.prologue_wall.duplicate(true)

static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(value) and value >= minimum and value <= maximum

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema_version") != 1 or not value.get("characters") is Dictionary or not value.get("species") is Dictionary or not value.get("maps") is Dictionary:
		return false
	for hero in value.characters.values():
		if not hero is Dictionary or not hero.get("name") is String or not hero.get("magic") is Dictionary:
			return false
		for key in ["hp","speed","pickup","crit","crit_damage","hit_lock","hp_regen","power","rate"]:
			if not number(hero.get(key),0,10000):return false
		if hero.hp < 1 or hero.hp != floor(hero.hp) or hero.speed < 1 or hero.crit > 1 or hero.hit_lock < 0.01 or hero.power <= 0 or hero.rate <= 0:
			return false
		for key in ["max_mana","mana_cost","mana_regen","damage","radius","cooldown"]:
			if not number(hero.magic.get(key),0,10000):return false
		if hero.magic.max_mana < 1 or hero.magic.mana_cost <= 0 or hero.magic.mana_cost > hero.magic.max_mana or hero.magic.damage <= 0 or hero.magic.radius <= 0:
			return false
	for enemy in value.species.values():
		if not enemy is Dictionary or not enemy.get("name") is String or enemy.get("kind") not in ["normal","elite","boss"] or enemy.get("variant") not in VARIANTS or enemy.get("shot") not in ["","javelin","arrow"]:
			return false
		for key in ["hp","speed","contact_damage"]:
			if not number(enemy.get(key),1,1000000):return false
		if enemy.hp != floor(enemy.hp) or enemy.contact_damage != floor(enemy.contact_damage) or enemy.speed > 1000 or (enemy.kind!="normal" and enemy.variant!="normal") or (enemy.variant=="ranged") != (enemy.shot!=""):
			return false
	for pool in value.maps.values():
		if not pool is Dictionary or not pool.get("normal") is Dictionary or not pool.get("elites") is Array or pool.elites.size()!=2 or not value.species.has(pool.get("boss")) or value.species[pool.boss].kind!="boss":
			return false
		for id in pool.elites:
			if not value.species.has(id) or value.species[id].kind!="elite":return false
		for variant in VARIANTS:
			var list: Variant = pool.normal.get(variant)
			if not list is Array or list.is_empty():return false
			var used := {}
			for item in list:
				if not item is Dictionary or not value.species.has(item.get("id")) or used.has(item.id) or not number(item.get("weight"),0.001,1000):return false
				var definition: Dictionary = value.species[item.id]
				if definition.kind!="normal" or definition.variant!=variant:return false
				used[item.id] = true
	return not value.characters.is_empty() and not value.maps.is_empty()

func hero(id: String) -> Dictionary:
	return data.get("characters",{}).get(id,{}).duplicate(true)

func species(id: String) -> Dictionary:
	return data.get("species",{}).get(id,{}).duplicate(true)

func select(map_id: String, kind: String, variant: String, elite_index: int, generator: RandomNumberGenerator) -> String:
	var pool: Dictionary = data.get("maps",{}).get(map_id,{})
	if pool.is_empty():return ""
	if kind=="boss":return str(pool.boss)
	if kind=="elite":return str(pool.elites[clampi(elite_index,0,1)])
	var list: Array = pool.normal.get(variant,[])
	if list.is_empty():return ""
	if list.size()==1:return str(list[0].id)
	var total: float = list.reduce(func(sum,item):return sum+float(item.weight),0.0)
	var roll := generator.randf()*total
	for item in list:
		roll -= float(item.weight)
		if roll < 0:return str(item.id)
	return str(list[-1].id)

func scaled(id: String, wave: Dictionary, rules: Dictionary) -> Dictionary:
	var found := species(id)
	if found.is_empty():return {}
	if found.kind=="normal":
		found.hp = maxi(1,roundi(float(found.hp)*float(wave.hp)/20.0))
		found.speed = float(found.speed) if found.variant=="flier" else float(maxi(1,roundi(float(found.speed)*float(wave.speed)/68.0)))
	elif found.kind=="boss":
		found.hp = int(rules.boss_hp)
	else:
		found.hp = int(found.hp)
	found.contact_damage = int(found.contact_damage)
	return found
