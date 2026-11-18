extends RefCounted
## Exact gameplay data. Cosmetic effects/cues are rebuilt after a restore.
const VERSION := 1
const RUN_FIELDS := ["phase", "player", "facing", "hp", "elapsed", "kills", "shots",
	"shot_clock", "spawn_clock", "hurt_clock", "skill_clocks", "_resume_phase",
	"_enemy_serial", "_regen_remainder", "navigation_ticket", "stage", "run_id",
	"gold_collected", "gold_drop_chance", "_elites_spawned", "_boss_spawned", "_boss_defeated", "checkpoint_index", "end_reason",
	"enemies", "bullets", "pickups", "gold_pickups"]
const GROWTH_FIELDS := ["character_id", "owned", "level", "xp", "pending", "offer", "ticket", "revision"]
const MAGIC_FIELDS := ["mana", "cooldown_left", "casts", "ticket"]

static func fingerprint() -> String:
	return (FileAccess.get_file_as_string("res://data/stages.json") + FileAccess.get_file_as_string("res://data/prototype_skills.json")).sha256_text()

static func capture(state) -> Dictionary:
	var result := {"version": VERSION, "rules": fingerprint(), "run": {}, "growth": {}, "magic": {}, "rng": []}
	for key in RUN_FIELDS:
		result.run[key] = state.get(key)
	for key in GROWTH_FIELDS:
		result.growth[key] = state.growth.get(key)
	for key in MAGIC_FIELDS:
		result.magic[key] = state.magic.get(key)
	for generator in [state.rng, state.growth.rng, state.gold_rng]:
		result.rng.append({"seed": generator.seed, "state": generator.state})
	return result.duplicate(true)

static func finite_number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= minimum and value <= maximum

static func vector(value: Variant) -> bool:
	return value is Vector2 and value.is_finite() and value.length() < 100000.0

static func valid(data: Dictionary, state) -> bool:
	if data.get("version") != VERSION or data.get("rules") != fingerprint():
		return false
	for key in ["run", "growth", "magic"]:
		if not data.get(key) is Dictionary:
			return false
	var run: Dictionary = data.run
	var growth: Dictionary = data.growth
	var magic: Dictionary = data.magic
	for key in RUN_FIELDS:
		if not run.has(key):
			return false
	if run.phase not in [1, 2, 3, 4, 5, 6] or run._resume_phase not in [1, 4]:
		return false
	for key in ["hp", "kills", "shots", "_enemy_serial", "navigation_ticket", "stage", "gold_collected", "_elites_spawned", "checkpoint_index"]:
		if not run.get(key) is int or not finite_number(run[key], 0, 1000000000):
			return false
	for key in ["elapsed", "shot_clock", "spawn_clock", "hurt_clock", "_regen_remainder"]:
		if not finite_number(run.get(key), 0, 36000):
			return false
	if not vector(run.player) or not vector(run.facing) or run.stage < 1 or run.checkpoint_index > 2 or run._elites_spawned > 2:
		return false
	if not finite_number(run.get("gold_drop_chance"), 0, 1):
		return false
	if run.player != run.player.clamp(Vector2.ONE * 30.0, state.WORLD_SIZE - Vector2.ONE * 30.0):
		return false
	if run._regen_remainder >= 1.0 or run.hurt_clock > state.HIT_LOCK:
		return false
	if not run.run_id is String or run.run_id.length() != 32 or not run.run_id.is_valid_hex_number(false):
		return false
	if not run._boss_spawned is bool or not run._boss_defeated is bool or (run._boss_defeated and not run._boss_spawned):
		return false
	var rules: Dictionary = state.stage_catalog.for_stage(run.stage)
	if rules.is_empty() or (run.phase == 6 and (not run._boss_defeated or run.elapsed + 0.000001 < rules.duration)):
		return false
	if run._boss_spawned and run.elapsed + 0.000001 < float(rules.boss_at):
		return false
	var due := 0
	for moment in rules.checkpoints:
		if run.elapsed + 0.000001 >= float(moment):
			due += 1
	if run.checkpoint_index > due:
		return false
	if not growth.get("character_id") is String or not growth.get("owned") is Dictionary or not growth.get("offer") is Array:
		return false
	var pool: Array[Dictionary] = state.growth.catalog.pool_for(growth.character_id)
	if not state.growth.catalog.validate_pool(pool, growth.character_id):
		return false
	for key in ["level", "pending", "ticket", "revision"]:
		if not growth.get(key) is int or not finite_number(growth[key], 0, 1000000):
			return false
	if growth.level < 1 or growth.pending >= growth.level or not finite_number(growth.get("xp"), 0, (10 + (growth.level - 1) * 6) * 3):
		return false
	if growth.xp >= (10 + (growth.level - 1) * 6) * 3:
		return false
	var definitions: Dictionary = {}
	for entry in pool:
		definitions[entry.id] = entry
	var rows := {"attack": 0, "passive": 0, "ultimate": 0}
	var upgrades := 0
	for id in growth.owned:
		var rank: Variant = growth.owned[id]
		if not definitions.has(id) or not rank is int or rank < 1 or rank > int(definitions[id].max_level):
			return false
		rows[definitions[id].row] += 1
		upgrades += rank
	if rows.attack > 4 or rows.passive > 4 or rows.ultimate > 1 or upgrades + growth.pending > growth.level:
		return false
	var eligible: Array = []
	for entry in pool:
		var rank: int = growth.owned.get(entry.id, 0)
		if rank == int(entry.max_level):
			continue
		if rank == 0 and entry.row in ["attack", "passive"] and rows[entry.row] >= 4:
			continue
		eligible.append(entry.id)
	var seen: Dictionary = {}
	for id in growth.offer:
		if not id is String or not eligible.has(id) or seen.has(id):
			return false
		seen[id] = true
	var choosing: bool = run.phase == 4 or (run.phase == 2 and run._resume_phase == 4)
	if choosing != (growth.pending > 0) or growth.offer.size() != (mini(3, eligible.size()) if choosing else 0):
		return false
	var maximum_hp: int = 100 + 20 * int(growth.owned.get("passive_vitality", 0))
	if run.hp > maximum_hp or run.get("end_reason") not in ["", "defeat", "timeout", "abandoned", "cleared"]:
		return false
	if (run.phase in [1, 2, 4] and run.end_reason != "") or (run.phase == 3 and run.end_reason not in ["defeat", "timeout"]) or (run.phase == 5 and run.end_reason != "abandoned") or (run.phase == 6 and run.end_reason != "cleared"):
		return false
	if (run.end_reason == "defeat") != (run.hp == 0) or (run.end_reason == "timeout" and run.elapsed + 0.000001 < rules.duration):
		return false
	var config: Dictionary = state.growth.catalog.characters[growth.character_id].active_magic
	if not finite_number(magic.get("mana"), 0, config.max_mana) or not finite_number(magic.get("cooldown_left"), 0, config.cooldown):
		return false
	for key in ["casts", "ticket"]:
		if not magic.get(key) is int or not finite_number(magic[key], 0, 1000000000):
			return false
	if not data.get("rng") is Array or data.rng.size() != 3:
		return false
	for generator in data.rng:
		if not generator is Dictionary or not generator.get("seed") is int or not generator.get("state") is int:
			return false
	if not run.skill_clocks is Dictionary or run.skill_clocks.size() > 18:
		return false
	for id in run.skill_clocks:
		if not definitions.has(id) or not finite_number(run.skill_clocks[id], 0, 60):
			return false
	return valid_actors(run, state)

static func valid_actors(run: Dictionary, state) -> bool:
	var caps := {"enemies": state.MAX_ENEMIES, "bullets": state.MAX_BULLETS, "pickups": state.MAX_PICKUPS, "gold_pickups": state.MAX_PICKUPS}
	for key in caps:
		if not run[key] is Array or run[key].size() > caps[key]:
			return false
		for item in run[key]:
			if not item is Dictionary or not vector(item.get("p")):
				return false
	var ids: Dictionary = {}
	var boss_count := 0
	for enemy in run.enemies:
		if not enemy.get("id") is int or enemy.id <= 0 or enemy.id > run._enemy_serial or ids.has(enemy.id):
			return false
		ids[enemy.id] = true
		if enemy.get("kind") not in ["normal", "elite", "boss"]:
			return false
		if not enemy.get("hp") is int or not enemy.get("max_hp") is int or enemy.hp < 1 or enemy.hp > enemy.max_hp or enemy.max_hp > 1000000:
			return false
		if not finite_number(enemy.get("speed"), 1, 1000):
			return false
		if enemy.kind == "boss":
			boss_count += 1
	if boss_count > 1 or (run._boss_spawned and not run._boss_defeated and boss_count != 1) or (run._boss_defeated and boss_count != 0):
		return false
	for bullet in run.bullets:
		if not vector(bullet.get("direction")) or not bullet.get("seen") is Dictionary or bullet.seen.size() > run._enemy_serial:
			return false
		for key in ["life", "speed", "damage", "remaining"]:
			if not finite_number(bullet.get(key), 0, 1000000):
				return false
		for id in bullet.seen:
			if not id is int or id <= 0 or id > run._enemy_serial or bullet.seen[id] != true:
				return false
	for pickup in run.pickups:
		if not finite_number(pickup.get("value"), 0.000001, 1000000000):
			return false
	for pickup in run.gold_pickups:
		if not pickup.get("value") is int or pickup.value < 1 or pickup.value > 1000000000:
			return false
	return true

static func restore(data: Dictionary, state) -> bool:
	if not valid(data, state):
		return false
	data = data.duplicate(true)
	var previous_navigation: int = state.navigation_ticket
	var previous_growth: int = state.growth.ticket
	var previous_magic: int = state.magic.ticket
	for key in RUN_FIELDS:
		if state.get(key) is Array:
			state.get(key).assign(data.run[key].duplicate(true))
		else:
			state.set(key, data.run[key])
	for key in GROWTH_FIELDS:
		if state.growth.get(key) is Array:
			state.growth.get(key).assign(data.growth[key].duplicate(true))
		else:
			state.growth.set(key, data.growth[key])
	state.growth.pool = state.growth.catalog.pool_for(state.growth.character_id)
	state.magic.reset(state.growth.catalog.characters[state.growth.character_id].active_magic, state.growth.character_id)
	for key in MAGIC_FIELDS:
		state.magic.set(key, data.magic[key])
	var generators := [state.rng, state.growth.rng, state.gold_rng]
	for index in range(3):
		generators[index].seed = data.rng[index].seed
		generators[index].state = data.rng[index].state
	state.stage_rules = state.stage_catalog.for_stage(state.stage)
	state.stage_duration = float(state.stage_rules.duration)
	state.stage_clear_gold = int(state.stage_rules.clear_gold)
	state._refresh_stats()
	state.transition_action = ""
	state.navigation_ticket = maxi(previous_navigation, state.navigation_ticket) + 1
	state.growth.ticket = maxi(previous_growth, state.growth.ticket) + 1
	state.growth.revision += 1
	state.magic.ticket = maxi(previous_magic, state.magic.ticket) + 1
	state.effects.clear()
	state.cues.reset()
	state.feedback.reset()
	state._finished_result.clear()
	if state.phase in [1, 2, 4]:
		state._resume_phase = 4 if state.growth.pending > 0 else 1
		state.phase = 2 # Always require an explicit Continue after process recovery.
	else:
		state.feedback.finish()
		state._finished_result = state._summary(state.end_reason)
	return true
