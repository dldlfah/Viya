extends RefCounted
## One authoritative simulation. All numbers/effects are provisional test tuning.
const Growth = preload("res://scripts/progression/growth_state.gd")
const MagicState = preload("res://scripts/combat/magic_state.gd")
const FeedbackState = preload("res://scripts/combat/feedback_state.gd")
const CombatCues = preload("res://scripts/combat/combat_cues.gd")
const StageCatalog = preload("res://scripts/combat/stage_catalog.gd")
const MapCatalog = preload("res://scripts/world/map_catalog.gd")
const MapSpace = preload("res://scripts/world/map_space.gd")
const SupplyCatalog = preload("res://scripts/world/supply_catalog.gd")
const AccountTalents = preload("res://scripts/progression/account_talents.gd")
enum Phase { READY, RUNNING, PAUSED, DEFEAT, CHOOSING, ABANDONED, CLEARED }
const WORLD_SIZE := Vector2(1800.0, 1200.0) # Legacy API; mapped runs use world_size.
const PLAYER_SPEED := 235.0
const PLAYER_RADIUS := 17.0
const ENEMY_RADIUS := 18.0
const MAX_ENEMIES := 160
const MAX_ENEMY_BULLETS := 64
const SWARM_SIZE := 30
const SCATTER_VARIANTS := ["normal", "fast", "heavy", "flier"]
const MAX_BULLETS := 64
const MAX_PICKUPS := 240
const MAX_EFFECTS := 32
const SHOT_INTERVAL := 0.30
const SHOT_RANGE := 520.0
const BULLET_SPEED := 920.0
const HIT_LOCK := 0.85
const RANGED_SLOW_DURATION := 1.0 # Provisional existing-ranged-hit status.
const SLOW_SPEED_SCALE := 0.85
const FLIER_PLAYER_PUSH := 18.0

var phase: int = Phase.READY
var player := WORLD_SIZE * 0.5
var facing := Vector2.RIGHT
var hp: int = 100
var max_hp: int = 100
var elapsed: float = 0.0
var kills: int = 0
var shots: int = 0
var shot_clock: float = 0.0
var spawn_clock: float = 0.0
var hurt_clock: float = 0.0
var enemies: Array[Dictionary] = []
var enemy_bullets: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var growth = Growth.new()
var magic = MagicState.new()
var feedback = FeedbackState.new()
var cues = CombatCues.new()
var skill_clocks: Dictionary = {}
var stats := {"power": 1.0, "rate": 1.0, "speed": PLAYER_SPEED,
	"pickup": 80.0, "xp": 1.0, "crit": 0.0, "regen": 0.0, "ultimate": 0}
var _resume_phase: int = Phase.RUNNING
var _enemy_serial: int = 0
var _regen_remainder: float = 0.0
# Navigation is owned here, not by a second UI simulation. Never reuse tickets.
var navigation_ticket: int = 0
var transition_action: String = ""
var _finished_result: Dictionary = {}
# Provisional stage length, probability and base bonus. Gold ranges are fixed.
var stage_duration: float = 360.0
var gold_drop_chance: float = 0.3
var stage_clear_gold: int = 100
var stage: int = 1
var gold_collected: int = 0
var gold_pickups: Array[Dictionary] = []
var gold_rng := RandomNumberGenerator.new()
var encounter_rng := RandomNumberGenerator.new()
var scatter_rng := RandomNumberGenerator.new()
var _scatter_clock: float = 12.0
var _scatter_index: int = 0
var _swarm_clock: float = 20.0
var _swarm_pending: bool = false # Legacy saved event; new formations never queue.
var _swarm_serial: int = 0
var run_id: String = ""
var _elites_spawned: int = 0
var _boss_spawned: bool = false
var _boss_defeated: bool = false
var checkpoint_index: int = 0
var end_reason: String = ""
var stage_catalog = StageCatalog.new()
var stage_rules: Dictionary = {}
var map_catalog = MapCatalog.new()
var map_id: String = "legacy_arena"
var map_space = MapSpace.new(map_catalog.definition(map_id))
var world_size: Vector2 = WORLD_SIZE
var spawn_view_size := Vector2(1256,468)
var supply_catalog = SupplyCatalog.new()
var structures: Array[Dictionary] = []
var item_pickups: Array[Dictionary] = []
var loot_rng := RandomNumberGenerator.new()
var _loot_serial: int = 0
var account_talent_levels: Dictionary = AccountTalents.empty_levels()
var account_attack_level: int: # Compatibility view; all six levels freeze at departure.
	get: return int(account_talent_levels.attack_power)
	set(value): account_talent_levels.attack_power = value
var _damage_reduction_remainder: float = 0.0
var _slow_left: float = 0.0
var _kill_heal_clock: float = 0.0
var _kill_heal_used: float = 0.0

func start(seed_value: int = 0, character_id: String = "viya", account_level: Variant = null, selected_map: String = "legacy_arena") -> bool:
	# Validate the complete selected character before changing the previous run.
	var selected_levels: Dictionary = account_talent_levels.duplicate(true)
	if account_level is int:
		if account_level != -1:
			selected_levels = AccountTalents.from_attack(account_level)
	elif account_level != null:
		if not AccountTalents.valid_levels(account_level):
			return false
		selected_levels = account_level.duplicate(true)
	if not AccountTalents.valid_levels(selected_levels):
		return false
	var rules: Dictionary = stage_catalog.for_stage(stage)
	if rules.is_empty():
		return false
	var map_data: Dictionary = map_catalog.definition(selected_map)
	if map_data.is_empty():
		return false
	var selected_space = MapSpace.new(map_data)
	if not SupplyCatalog.valid_layout(supply_catalog.layouts.get(selected_map), selected_space):
		return false
	var candidate_pool: Array[Dictionary] = growth.catalog.pool_for(character_id)
	if not growth.catalog.validate_pool(candidate_pool, character_id):
		return false
	var hero: Dictionary = growth.catalog.characters.get(character_id, {})
	var candidate = hero.get("active_magic", {})
	if not candidate is Dictionary or not magic.accepts(candidate, character_id):
		return false
	var upgrade_valid: bool = false
	for entry in candidate_pool:
		if entry["id"] == candidate["upgrade_skill_id"]:
			upgrade_valid = entry["kind"] == "ultimate" and entry["effect"] == "ultimate"
	if not upgrade_valid:
		return false
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	if not growth.reset(character_id, int(rng.seed) ^ 0x51A7):
		return false
	account_talent_levels = selected_levels
	gold_rng.seed = int(rng.seed) ^ 0x601D
	encounter_rng.seed = int(rng.seed) ^ 0xE11C
	scatter_rng.seed = int(rng.seed) ^ 0x5CA77
	loot_rng.seed = int(rng.seed) ^ 0x1007
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	gold_collected = 0
	gold_pickups.clear()
	_elites_spawned = 0
	_boss_spawned = false
	_boss_defeated = false
	checkpoint_index = 0
	end_reason = ""
	stage_rules = rules
	map_id = selected_map
	map_space = MapSpace.new(map_data)
	world_size = map_space.world_size
	structures = supply_catalog.create(map_id, map_space)
	item_pickups.clear()
	_loot_serial = 0
	_scatter_clock = float(rules.scatter.interval)
	_scatter_index = 0
	_swarm_clock = float(rules.swarm.interval)
	_swarm_pending = false
	_swarm_serial = 0
	stage_duration = float(rules.duration)
	stage_clear_gold = int(rules.clear_gold)
	magic.reset(candidate, character_id)
	feedback.reset()
	cues.reset()
	navigation_ticket += 1
	transition_action = ""
	_finished_result.clear()
	player = map_space.start
	facing = Vector2.RIGHT
	hp = 100
	max_hp = 100
	elapsed = 0.0
	kills = 0
	shots = 0
	shot_clock = 0.0
	spawn_clock = 0.2
	hurt_clock = 0.0
	_enemy_serial = 0
	_regen_remainder = 0.0
	_damage_reduction_remainder = 0.0
	_slow_left = 0.0
	_kill_heal_clock = 0.0
	_kill_heal_used = 0.0
	_resume_phase = Phase.RUNNING
	enemies.clear()
	enemy_bullets.clear()
	bullets.clear()
	pickups.clear()
	effects.clear()
	skill_clocks.clear()
	_refresh_stats()
	hp = max_hp
	magic.mana = magic.maximum_mana()
	phase = Phase.RUNNING
	return true

func set_paused(value: bool) -> void:
	if not transition_action.is_empty():
		return # Confirmation must be resolved or interrupted explicitly.
	if value and phase in [Phase.RUNNING, Phase.CHOOSING]:
		magic.invalidate_requests()
		_resume_phase = phase
		phase = Phase.PAUSED
		navigation_ticket += 1
	elif not value and phase == Phase.PAUSED:
		magic.invalidate_requests()
		phase = _resume_phase
		navigation_ticket += 1

func damage_player(amount: int) -> bool:
	if phase != Phase.RUNNING or hurt_clock > 0.0 or amount <= 0:
		return false
	# Accumulate fractional prevention so 1-3% works with small integer-HP hits.
	_damage_reduction_remainder += amount * float(stats.get("damage_reduction", 0.0))
	var prevented := mini(amount, int(floor(_damage_reduction_remainder + 0.000000001)))
	_damage_reduction_remainder = maxf(0.0, _damage_reduction_remainder - prevented)
	hp = maxi(0, hp - (amount - prevented))
	hurt_clock = float(stats.get("hit_lock", HIT_LOCK))
	if hp == 0:
		_finish_run("defeat")
	else:
		feedback.trigger("hurt")
	return true

func apply_slow(duration: float) -> bool:
	if phase != Phase.RUNNING or duration <= 0.0 or not is_finite(duration):
		return false
	_slow_left = maxf(_slow_left, minf(duration, RANGED_SLOW_DURATION) * (1.0 - float(stats.get("status_resist", 0.0))))
	return true

func push_player(displacement: Vector2) -> bool:
	if phase != Phase.RUNNING or not displacement.is_finite():
		return false
	player = map_space.move(player, displacement * (1.0 - float(stats.get("knockback_resist", 0.0))), 30.0)
	return true

func add_enemy(at: Vector2, kind: String = "normal", variant: String = "normal", scatter_group: int = 0) -> bool:
	if kind not in ["normal", "elite", "boss"]:
		return false
	if variant not in ["normal", "ranged", "fast", "heavy", "flier"] or (kind != "normal" and variant != "normal"):
		return false
	if scatter_group < 0 or scatter_group > _scatter_index or (scatter_group > 0 and (kind != "normal" or variant not in SCATTER_VARIANTS)):
		return false
	if scatter_group == 0 and variant != "flier" and _ground_count() >= MAX_ENEMIES:
		return false
	_enemy_serial += 1
	var wave := wave_profile()
	var life: int = int(wave.hp)
	if kind == "elite":
		life = int(stage_rules.elite_hp[mini(_elites_spawned, 1)])
	elif kind == "boss":
		life = int(stage_rules.boss_hp)
	var speed: float = float(wave.speed)
	match variant:
		"fast": speed *= float(stage_rules.fast_speed_scale)
		"heavy":
			life *= 2
			speed *= float(stage_rules.heavy_speed_scale)
		"ranged": speed *= float(stage_rules.ranged.speed_scale)
		"flier": speed = float(stage_rules.swarm.speed)
	var enemy := {"id": _enemy_serial, "p": at, "hp": life, "max_hp": life, "kind": kind, "variant": variant, "speed": speed, "scatter_group": scatter_group}
	if variant == "ranged":
		enemy.merge({"fire_clock": float(stage_rules.ranged.interval), "windup": 0.0, "aim": at})
	elif variant == "flier":
		enemy.merge({"velocity": Vector2.RIGHT * float(stage_rules.swarm.speed), "life": float(stage_rules.swarm.life), "group": _swarm_serial})
	enemies.append(enemy)
	return true

func add_pickup(at: Vector2, value: float = 5.0) -> void:
	if value <= 0.0 or not is_finite(value):
		return
	if pickups.size() >= MAX_PICKUPS:
		# Preserve XP instead of dropping rewards when the display cap is reached.
		pickups[-1]["value"] += value
	else:
		pickups.append({"p": at, "value": value})

func grant_xp(amount: float) -> void:
	if phase != Phase.RUNNING:
		return
	growth.gain(amount)
	_begin_choice_if_needed()

func select_skill(id: String, ticket: int) -> bool:
	if phase != Phase.CHOOSING or not growth.select(id, ticket):
		return false
	var previous_max := max_hp
	_refresh_stats()
	hp = selection_health(hp, previous_max, max_hp)
	phase = Phase.RUNNING
	_begin_choice_if_needed()
	return true

func acknowledge_exhausted(ticket: int) -> bool:
	if phase != Phase.CHOOSING or not growth.acknowledge_exhausted(ticket):
		return false
	phase = Phase.RUNNING
	return true

func _begin_choice_if_needed() -> void:
	if growth.pending > 0:
		growth.open_offer()
		feedback.level_up(growth.ticket)
		magic.invalidate_requests()
		phase = Phase.CHOOSING

func cast_ultimate(expected_ticket: int) -> bool:
	if magic.owner_id != growth.character_id:
		return false
	var cast: Dictionary = magic.consume(expected_ticket, phase == Phase.RUNNING, int(stats["ultimate"]))
	if cast.is_empty():
		return false
	# Separate from automatic "sigil". Use the normal damage/death/XP path.
	_burst(player, float(cast["radius"]), float(cast["damage"]), "ultimate")
	effects[-1]["life"] = float(cast["effect_duration"])
	effects[-1]["duration"] = float(cast["effect_duration"])
	feedback.trigger("magic")
	return true

func _effect_rank(effect: String) -> int:
	for entry in growth.pool:
		if entry["effect"] == effect:
			return growth.skill_level(entry["id"])
	return 0

func _refresh_stats() -> void:
	var profile: Dictionary = stats_profile(growth.owned)
	max_hp = int(profile["max_hp"])
	stats = profile["stats"]
	var account := AccountTalents.bonuses(account_talent_levels)
	magic.bonus_mana_regen = float(account.mp_regen)
	magic.bonus_max_mana = float(account.max_mana)
	magic.mana_cost_scale = 1.0 - float(account.mana_cost_reduction)
	magic.radius_scale = 1.0 + float(account.attack_range)

func stats_profile(levels: Dictionary) -> Dictionary:
	# Pure lookup shared by actual upgrades and choice previews. Never edit levels.
	var ranks: Dictionary = {}
	for entry in growth.pool:
		var effect: String = str(entry["effect"])
		if not ranks.has(effect):
			ranks[effect] = int(levels.get(entry["id"], 0))
	var account := AccountTalents.bonuses(account_talent_levels)
	return {"max_hp": AccountTalents.maximum_hp(100 + 20 * int(ranks.get("vitality", 0)), account_talent_levels),
		"stats": {"power": (1.0 + 0.15 * int(ranks.get("power", 0))) * AccountTalents.power_multiplier(account_attack_level),
			"rate": (1.0 + 0.08 * int(ranks.get("haste", 0))) * (1.0 + float(account.attack_speed)),
			"speed": PLAYER_SPEED * (1.0 + 0.07 * int(ranks.get("stride", 0))) * (1.0 + float(account.move_speed)),
			"pickup": 80.0 + 20.0 * int(ranks.get("magnet", 0)),
			"xp": 1.0 + 0.12 * int(ranks.get("learning", 0)),
			"crit": minf(1.0, 0.04 * int(ranks.get("precision", 0)) + float(account.crit_chance)),
			"crit_damage": 2.0 + float(account.crit_damage),
			"hit_lock": HIT_LOCK + float(account.invulnerability),
			"knockback_resist": float(account.knockback_resist), "status_resist": float(account.status_resist),
			"healing_efficiency": 1.0 + float(account.healing_efficiency),
			"kill_heal": float(account.kill_heal), "kill_heal_cap": float(account.kill_heal) * 6.0,
			"projectile_speed": 1.0 + float(account.projectile_speed), "attack_range": 1.0 + float(account.attack_range),
			"regen": 0.6 * int(ranks.get("recovery", 0)) + float(account.hp_regen),
			"damage_reduction": float(account.damage_reduction),
			"ultimate": int(ranks.get("ultimate", 0))}}

func selection_health(current_hp: int, previous_max: int, next_max: int) -> int:
	var scale: float = 1.0 + float(AccountTalents.bonuses(account_talent_levels).healing_efficiency)
	return mini(next_max, current_hp + int(floor(maxi(0, next_max - previous_max) * scale + 0.000000001)))

func attack_profile(effect: String, rank: int, rate: float) -> Dictionary:
	# The production attack consumes these exact values; UI does not copy formulas.
	if rank <= 0 or rate <= 0.0 or not is_finite(rate):
		return {}
	var result: Dictionary = {}
	match effect:
		"rifle":
			result = {"damage": 10.0 + 3.0 * (rank - 1), "projectiles": 1, "hits": 1, "speed": BULLET_SPEED}
		"scatter":
			result = {"damage": 7.0 + rank * 2.0, "projectiles": 3, "hits": 1, "speed": BULLET_SPEED}
		"lance":
			result = {"damage": 12.0 + rank * 4.0, "projectiles": 1, "hits": 1 + rank, "speed": 1150.0}
		"grenade":
			result = {"damage": 12.0 + rank * 4.0, "radius": 60.0 + rank * 8.0}
		"pulse":
			result = {"damage": 8.0 + rank * 3.0, "radius": 105.0 + rank * 8.0}
		"crossfire":
			result = {"damage": 9.0 + rank * 3.0, "projectiles": 4, "hits": 1, "speed": BULLET_SPEED}
		"chain":
			result = {"damage": 9.0 + rank * 2.0, "targets": 1 + rank, "link_range": 160.0}
		"heavy":
			result = {"damage": 24.0 + rank * 8.0, "projectiles": 1, "hits": 1, "speed": 1300.0}
		"sigil":
			result = {"damage": 18.0 + rank * 6.0, "radius": 75.0 + rank * 12.0}
	if result.is_empty():
		return {}
	if result.has("speed"):
		result.speed *= float(stats.get("projectile_speed", 1.0))
	for key in ["radius", "link_range"]:
		if result.has(key):
			result[key] *= float(stats.get("attack_range", 1.0))
	result["interval"] = (SHOT_INTERVAL if effect == "rifle" else (2.0 if effect != "sigil" else 3.0)) / rate
	return result

func step(delta: float, direction: Vector2) -> void:
	if phase != Phase.RUNNING or delta <= 0.0 or not is_finite(delta):
		return
	var dt := minf(delta, 0.05)
	feedback.advance(dt, true)
	cues.advance(dt)
	elapsed = minf(stage_duration, elapsed + dt)
	while checkpoint_index < 2 and elapsed + 0.000001 >= float(stage_rules.checkpoints[checkpoint_index]):
		checkpoint_index += 1
	hurt_clock = maxf(0.0, hurt_clock - dt)
	_kill_heal_clock = maxf(0.0, _kill_heal_clock - dt)
	if _kill_heal_clock == 0.0:
		_kill_heal_used = 0.0
	var movement := direction.limit_length(1.0)
	var motion_dt := dt - (1.0 - SLOW_SPEED_SCALE) * minf(dt, _slow_left)
	_slow_left = maxf(0.0, _slow_left - dt)
	player = map_space.move(player, movement * float(stats["speed"]) * motion_dt, 30.0)
	if movement.length_squared() > 0.001:
		facing = movement.normalized()
	_tick_structures(dt)
	_collect_pickups(dt)
	if phase != Phase.RUNNING:
		_resolve_deadline()
		return
	spawn_clock -= dt
	if elapsed >= float(stage_rules.boss_at) and not _boss_spawned:
		_boss_spawned = _spawn_enemy("boss")
	elif _elites_spawned < 2 and elapsed >= float(stage_rules.elites[_elites_spawned]):
		if _spawn_enemy("elite"):
			_elites_spawned += 1
	if spawn_clock <= 0.0:
		var wave := wave_profile()
		for index in range(int(wave.batch)):
			_spawn_enemy()
		spawn_clock = float(wave.interval)
	_tick_swarm(dt)
	_tick_scatter(dt)
	_move_enemies(dt)
	if phase != Phase.RUNNING:
		return
	_move_enemy_bullets(dt)
	if phase != Phase.RUNNING:
		return
	shot_clock = maxf(0.0, shot_clock - dt)
	if shot_clock == 0.0:
		_auto_fire()
	magic.advance(dt, true)
	_tick_skills(dt)
	if phase != Phase.RUNNING:
		return
	_move_bullets(dt)
	if phase != Phase.RUNNING:
		return
	for i in range(effects.size() - 1, -1, -1):
		effects[i]["life"] -= dt
		if effects[i]["life"] <= 0.0:
			effects.remove_at(i)
	_heal_hp(float(stats["regen"]) * dt)
	_resolve_deadline()

func _heal_hp(amount: float) -> void:
	if phase != Phase.RUNNING or amount < 0.0 or not is_finite(amount):
		return
	if hp >= max_hp:
		_regen_remainder = 0.0
		return
	_regen_remainder += amount * float(stats.get("healing_efficiency", 1.0))
	var healing := int(floor(_regen_remainder + 0.000000001))
	hp = mini(max_hp, hp + healing)
	_regen_remainder = 0.0 if hp == max_hp else maxf(0.0, _regen_remainder - healing)

func _heal_on_kill() -> void:
	var amount: float = float(stats.get("kill_heal", 0.0))
	if amount <= 0.0:
		return
	if _kill_heal_clock == 0.0:
		_kill_heal_clock = 1.0
		_kill_heal_used = 0.0
	amount = minf(amount, maxf(0.0, float(stats.kill_heal_cap) - _kill_heal_used))
	_kill_heal_used += amount
	_heal_hp(amount)

func _collect_pickups(dt: float) -> void:
	_collect_gold(dt)
	_collect_items(dt)
	if phase != Phase.RUNNING:
		return # A global magnet may open an exact, saved level-up offer.
	var reward: float = 0.0
	for i in range(pickups.size() - 1, -1, -1):
		var pos: Vector2 = pickups[i]["p"]
		if pos.distance_squared_to(player) <= pow(float(stats["pickup"]), 2.0):
			pos = pos.move_toward(player, 420.0 * dt)
			pickups[i]["p"] = pos
		if pos.distance_squared_to(player) <= pow(PLAYER_RADIUS + 10.0, 2.0):
			reward += float(pickups[i]["value"]) * float(stats["xp"])
			pickups.remove_at(i)
	if reward > 0.0:
		grant_xp(reward)
		cues.record_collected_xp(player, reward)

func _ground_count() -> int:
	var count := 0
	for enemy in enemies:
		if enemy.variant != "flier" and enemy.scatter_group == 0:
			count += 1
	return count

func _spawn_enemy(kind: String = "normal") -> bool:
	# Flying formations have their own lifetime; only reserve the ground boss slot.
	var limit: int = MAX_ENEMIES - (0 if _boss_spawned else 1)
	if kind == "boss":
		limit = MAX_ENEMIES
	if _ground_count() >= limit:
		return false
	if map_id != "legacy_arena":
		var at: Variant = map_space.spawn_anchor(rng, player, elapsed, kind, visible_world(), 24.0)
		return add_enemy(at, kind, _roll_variant() if kind == "normal" else "normal") if at is Vector2 else false
	for attempt in range(8):
		var candidate := player + Vector2.from_angle(rng.randf_range(0.0, TAU)) * 590.0
		candidate = candidate.clamp(Vector2.ONE * 24.0, world_size - Vector2.ONE * 24.0)
		if candidate.distance_squared_to(player) >= 160.0 * 160.0:
			return add_enemy(candidate, kind, _roll_variant() if kind == "normal" else "normal")
	return false

func _move_enemies(dt: float) -> void:
	# Ground movement happens first so fly-bys cannot be undone by pursuit this frame.
	for enemy in enemies:
		if enemy.variant == "flier":
			continue
		var speed: float = float(enemy.get("speed", wave_profile().speed))
		var pos: Vector2 = enemy["p"]
		var offset := player - pos
		var variant: String = str(enemy.get("variant", "normal"))
		if variant == "ranged":
			var distance := offset.length()
			if distance > float(stage_rules.ranged.range) * 0.85:
				pos += offset.normalized() * speed * dt
			elif distance < float(stage_rules.ranged.keep_distance) * 0.75:
				pos -= offset.normalized() * speed * dt
			pos = pos.clamp(Vector2.ONE * 24.0, world_size - Vector2.ONE * 24.0)
		elif offset.length_squared() > 0.01:
			pos += offset.normalized() * minf(speed * dt, offset.length())
		if map_id != "legacy_arena":
			if variant != "ranged" or offset.length() > float(stage_rules.ranged.range) * 0.85:
				var waypoint: Vector2 = map_space.route_target(enemy.p, player, 24.0)
				pos = enemy.p.move_toward(waypoint, speed * dt)
			pos = map_space.move(enemy.p, pos - enemy.p, 24.0)
		enemy["p"] = pos
		if variant == "ranged":
			_tick_ranged(enemy, dt)
	_move_fliers(dt)
	for enemy in enemies:
		if enemy.p.distance_squared_to(player) <= pow(PLAYER_RADIUS + ENEMY_RADIUS, 2.0):
			var accepted := damage_player(12)
			if accepted and enemy.variant == "flier":
				push_player(enemy.velocity.normalized() * FLIER_PLAYER_PUSH)
			if phase == Phase.DEFEAT:
				return

func _move_fliers(dt: float) -> void:
	for index in range(enemies.size() - 1, -1, -1):
		var flier: Dictionary = enemies[index]
		if flier.variant != "flier":
			continue
		flier.life -= dt
		if flier.life <= 0.0:
			enemies.remove_at(index) # Expiry never awards a kill or loot.
			continue
		var previous: Vector2 = flier.p
		flier.p += flier.velocity * dt
		_push_ground(previous, flier.p)

func _push_ground(previous: Vector2, destination: Vector2) -> void:
	var direction := previous.direction_to(destination)
	if direction.is_zero_approx():
		return
	var radius := ENEMY_RADIUS * 2.0
	for enemy in enemies:
		if enemy.variant == "flier" or (enemy.p - previous).dot(direction) < 0.0:
			continue
		var nearest := Geometry2D.get_closest_point_to_segment(enemy.p, previous, destination)
		if nearest.distance_squared_to(enemy.p) >= radius * radius:
			continue
		var relative: Vector2 = enemy.p - destination
		var lateral: float = relative.dot(direction.orthogonal())
		var front := sqrt(maxf(0.0, radius * radius - lateral * lateral)) + 0.1
		var distance: float = relative.dot(direction)
		if distance < front:
			# Preserve the flying path and push every ground type, including bosses.
			enemy.p = map_space.move(enemy.p, direction * (front - distance), 24.0)

func _roll_variant() -> String:
	var roll := encounter_rng.randf() * 100.0
	var weight := 0.0
	for variant in ["normal", "ranged", "fast", "heavy"]:
		weight += float(stage_rules.enemy_mix[variant])
		if roll < weight:
			return variant
	return "heavy"

func _tick_ranged(enemy: Dictionary, dt: float) -> void:
	var rules: Dictionary = stage_rules.ranged
	enemy.fire_clock = maxf(0.0, float(enemy.fire_clock) - dt)
	if enemy.windup > 0.0:
		enemy.windup = maxf(0.0, float(enemy.windup) - dt)
		if enemy.windup == 0.0:
			if enemy_bullets.size() < MAX_ENEMY_BULLETS:
				var direction: Vector2 = enemy.p.direction_to(enemy.aim)
				if direction.is_zero_approx():
					direction = Vector2.RIGHT
				enemy_bullets.append({"p": enemy.p, "velocity": direction * float(rules.bullet_speed), "life": float(rules.bullet_life), "damage": int(rules.damage)})
			enemy.fire_clock = float(rules.interval)
		return
	if enemy.fire_clock == 0.0 and enemy.p.distance_to(player) <= float(rules.range):
		enemy.aim = player
		enemy.windup = float(rules.windup)

func _move_enemy_bullets(dt: float) -> void:
	for index in range(enemy_bullets.size() - 1, -1, -1):
		var bullet: Dictionary = enemy_bullets[index]
		var previous: Vector2 = bullet.p
		var next: Vector2 = bullet.p + bullet.velocity * minf(dt, float(bullet.life))
		var wall_hit: float = map_space.wall_fraction(previous,next,5.0)
		bullet.p = previous.lerp(next,wall_hit)
		bullet.life -= dt
		var nearest := Geometry2D.get_closest_point_to_segment(player, previous, bullet.p)
		var hit: bool = nearest.distance_squared_to(player) <= pow(PLAYER_RADIUS + 5.0, 2.0)
		if hit:
			if damage_player(int(bullet.damage)):
				apply_slow(RANGED_SLOW_DURATION)
		if hit or bullet.life <= 0.0 or wall_hit < 1.0:
			enemy_bullets.remove_at(index)
		if phase != Phase.RUNNING:
			return

func _tick_swarm(dt: float) -> void:
	if _swarm_pending:
		_swarm_pending = not _spawn_swarm()
		return
	_swarm_clock = maxf(0.0, _swarm_clock - dt)
	if _swarm_clock > 0.0:
		return
	_swarm_clock = float(stage_rules.swarm.interval)
	var chance: float = float(stage_rules.swarm.chance)
	if chance >= 1.0 or encounter_rng.randf() < chance:
		_swarm_pending = not _spawn_swarm()

func _spawn_swarm() -> bool:
	if map_id != "legacy_arena":
		return _spawn_map_formation("flier", 5, float(stage_rules.swarm.spacing), 0.0, encounter_rng, false)
	# An accepted encounter always creates all 30, even in an occupied/full field.
	_swarm_serial += 1
	var direction := Vector2.from_angle(encounter_rng.randi_range(0, 3) * PI * 0.5)
	var origin := player - direction * 650.0
	var rules: Dictionary = stage_rules.swarm
	for index in range(SWARM_SIZE):
		var offset := direction.orthogonal() * ((index % 5) - 2) * float(rules.spacing)
		offset -= direction * int(index / 5) * float(rules.spacing)
		add_enemy(origin + offset, "normal", "flier")
		enemies[-1].velocity = direction * float(rules.speed)
	return true

func _tick_scatter(dt: float) -> void:
	if phase != Phase.RUNNING or elapsed >= stage_duration:
		return
	_scatter_clock = maxf(0.0, _scatter_clock - dt)
	if _scatter_clock <= 0.000001:
		if _spawn_scatter():
			_scatter_clock = float(stage_rules.scatter.interval)

func _spawn_scatter() -> bool:
	# Independent schedule/RNG and population: never replace or block old spawns.
	var rules: Dictionary = stage_rules.scatter
	if _scatter_index >= ceili(stage_duration / float(rules.interval)):
		return false
	if map_id != "legacy_arena":
		return _spawn_map_formation(SCATTER_VARIANTS[_scatter_index % 4], 6, float(rules.spacing), float(rules.jitter), scatter_rng, true)
	var spacing: float = float(rules.spacing)
	var jitter: float = float(rules.jitter)
	var margin := Vector2.ONE * (spacing * 3.0 + jitter)
	var centers: Array[Vector2] = []
	for side in range(4):
		var at := (player + Vector2.from_angle(side * PI * 0.5) * float(rules.approach)).clamp(margin, world_size - margin)
		if at.distance_to(player) >= spacing * 2.0 + jitter + 180.0:
			centers.append(at)
	if centers.is_empty():
		return false
	var center: Vector2 = centers[scatter_rng.randi_range(0, centers.size() - 1)]
	var direction := center.direction_to(player)
	var variant: String = SCATTER_VARIANTS[_scatter_index % SCATTER_VARIANTS.size()]
	_scatter_index += 1
	if variant == "flier":
		_swarm_serial += 1
	for index in range(SWARM_SIZE):
		var offset := direction.orthogonal() * ((index % 6) - 2.5) * spacing
		offset += direction * (int(index / 6) - 2) * spacing
		offset += Vector2(scatter_rng.randf_range(-jitter, jitter), scatter_rng.randf_range(-jitter, jitter))
		add_enemy(center + offset, "normal", variant, _scatter_index)
		if variant == "flier":
			enemies[-1].velocity = direction * float(stage_rules.swarm.speed)
	return true

func _nearest(at: Vector2, reach: float, ignored: Array[int] = []) -> Dictionary:
	var best := reach * reach
	var found: Dictionary = {}
	for enemy in enemies:
		if ignored.has(int(enemy["id"])):
			continue
		var distance := at.distance_squared_to(enemy["p"])
		if distance < best:
			best = distance
			found = enemy
	# Enemies keep priority; supplies are targets when no enemy is in range.
	if found.is_empty():
		for structure in structures:
			if structure.hp <= 0 or ignored.has(int(structure.id)):
				continue
			var distance := at.distance_squared_to(structure.p)
			if distance < best and map_space.wall_fraction(at, structure.p, 4.0) >= 1.0:
				best = distance
				found = structure
	return found

func _auto_fire() -> void:
	var target := _nearest(player, SHOT_RANGE * float(stats.get("attack_range", 1.0)))
	if target.is_empty():
		return
	var direction: Vector2 = (target["p"] - player).normalized()
	if direction.length_squared() < 0.01:
		direction = facing
	facing = direction
	var profile: Dictionary = attack_profile("rifle", _effect_rank("rifle"), float(stats["rate"]))
	if profile.is_empty():
		return
	if _projectile(direction, float(profile["damage"]), int(profile["hits"]), float(profile["speed"])):
		shot_clock = float(profile["interval"])

func _projectile(direction: Vector2, damage: float, hits: int, speed: float = BULLET_SPEED, source: String = "rifle") -> bool:
	if bullets.size() >= MAX_BULLETS:
		return false
	bullets.append({"p": player, "direction": direction, "life": 0.75,
		"speed": speed, "damage": damage, "remaining": hits, "seen": {}, "source": source})
	shots += 1
	return true

func _damage_enemy(id: int, base_damage: float) -> void:
	if phase != Phase.RUNNING:
		return
	for i in range(enemies.size()):
		if int(enemies[i]["id"]) != id:
			continue
		var damage := base_damage * float(stats["power"])
		var critical: bool = false
		var previous_hp: int = int(enemies[i]["hp"])
		var hit_at: Vector2 = enemies[i]["p"]
		if float(stats["crit"]) > 0.0 and rng.randf() < float(stats["crit"]):
			damage *= float(stats.get("crit_damage", 2.0))
			critical = true
		if account_attack_level > 0:
			# 100 * 1.10 must be 110, not 111 from binary rounding before ceil.
			damage = snappedf(damage, 0.000001)
		enemies[i]["hp"] -= maxi(1, int(ceil(damage)))
		# Display HP actually removed, not theoretical overkill damage. Reuse the crit roll.
		var hp_lost: int = maxi(0, previous_hp - maxi(0, int(enemies[i]["hp"])))
		cues.record_hit(id, hit_at, hp_lost, critical)
		if enemies[i]["hp"] <= 0:
			_defeat_enemy(i)
		return

func _defeat_enemy(index: int) -> void:
	# Both normal damage and purge use this single committed death/reward path.
	var enemy: Dictionary = enemies[index]
	add_pickup(enemy.p)
	_drop_gold(enemy.p, str(enemy.kind))
	enemies.remove_at(index)
	kills += 1
	cues.record_kill(int(enemy.id), enemy.p)
	_heal_on_kill()
	if enemy.kind == "boss" and _boss_spawned:
		_boss_defeated = true
		if elapsed + 0.000001 >= stage_duration:
			_clear_stage()

func _damage_target(id: int, damage: float) -> void:
	if id < -1:
		_damage_structure(id, damage)
	else:
		_damage_enemy(id, damage)

func _burst(at: Vector2, radius: float, damage: float, kind: String) -> void:
	var targets: Array[int] = []
	for enemy in enemies:
		if at.distance_squared_to(enemy["p"]) <= radius * radius:
			targets.append(int(enemy["id"]))
	for id in targets:
		_damage_enemy(id, damage)
	for structure in structures:
		if structure.hp > 0 and at.distance_squared_to(structure.p) <= radius * radius:
			_damage_structure(int(structure.id), damage)
	_effect(at, radius, kind)

func _effect(at: Vector2, radius: float, kind: String) -> void:
	if effects.size() >= MAX_EFFECTS:
		effects.pop_front()
	effects.append({"p": at, "radius": radius, "kind": kind, "life": 0.25})

func _tick_skills(dt: float) -> void:
	for entry in growth.row_entries("attack"):
		if phase != Phase.RUNNING:
			return
		var effect: String = entry["effect"]
		if effect == "rifle":
			continue
		var id: String = entry["id"]
		var clock := maxf(0.0, float(skill_clocks.get(id, 0.0)) - dt)
		skill_clocks[id] = clock
		if clock > 0.0:
			continue
		var target := _nearest(player, SHOT_RANGE * float(stats.get("attack_range", 1.0)))
		if target.is_empty():
			continue
		var rank: int = growth.skill_level(id)
		var profile: Dictionary = attack_profile(effect, rank, float(stats["rate"]))
		if profile.is_empty():
			continue
		var at: Vector2 = target["p"]
		var direction := (at - player).normalized()
		if direction.is_zero_approx():
			direction = facing
		match effect:
			"scatter":
				for n in range(int(profile["projectiles"])):
					_projectile(direction.rotated((n - 1) * 0.22), float(profile["damage"]), int(profile["hits"]), float(profile["speed"]), effect)
			"lance":
				_projectile(direction, float(profile["damage"]), int(profile["hits"]), float(profile["speed"]), effect)
			"grenade":
				_burst(at, float(profile["radius"]), float(profile["damage"]), "blast")
			"pulse":
				_burst(player, float(profile["radius"]), float(profile["damage"]), "pulse")
			"crossfire":
				for n in range(int(profile["projectiles"])):
					_projectile(Vector2.from_angle(n * PI * 0.5), float(profile["damage"]), int(profile["hits"]), float(profile["speed"]), effect)
			"chain":
				var used: Array[int] = []
				var anchor := player
				for n in range(int(profile["targets"])):
					var linked := _nearest(anchor, SHOT_RANGE * float(stats.get("attack_range", 1.0)) if n == 0 else float(profile["link_range"]), used)
					if linked.is_empty():
						break
					var victim: int = linked["id"]
					var link_from: Vector2 = anchor
					anchor = linked["p"]
					used.append(victim)
					_damage_target(victim, float(profile["damage"]))
					_effect(anchor, 28.0, "chain")
					effects[-1]["from"] = link_from # Committed link, not a new target search.
					if phase != Phase.RUNNING:
						return
			"heavy":
				_projectile(direction, float(profile["damage"]), int(profile["hits"]), float(profile["speed"]), effect)
			"sigil":
				_burst(at, float(profile["radius"]), float(profile["damage"]), "sigil")
		skill_clocks[id] = float(profile["interval"])

func _move_bullets(dt: float) -> void:
	for bullet_index in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[bullet_index]
		var old_pos: Vector2 = bullet["p"]
		var new_pos: Vector2 = old_pos + bullet["direction"] * float(bullet["speed"]) * dt
		var wall_hit: float = map_space.wall_fraction(old_pos,new_pos,4.0)
		new_pos = old_pos.lerp(new_pos,wall_hit)
		bullet["p"] = new_pos
		bullet["life"] -= dt
		# Swept collision, ordered impacts, stable enemy IDs: one hit per target.
		while int(bullet["remaining"]) > 0:
			var victim := -1
			var first_distance := INF
			for actors in [enemies, structures]:
				for actor in actors:
					if actor.hp <= 0 or bullet["seen"].has(actor.id):
						continue
					var pos: Vector2 = actor.p
					var nearest := Geometry2D.get_closest_point_to_segment(pos, old_pos, new_pos)
					var radius: float = SupplyCatalog.RADIUS if actor.id < 0 else ENEMY_RADIUS
					if pos.distance_squared_to(nearest) <= pow(radius + 4.0, 2.0):
						var distance := old_pos.distance_squared_to(nearest)
						if distance < first_distance:
							first_distance = distance
							victim = int(actor.id)
			if victim == -1:
				break
			bullet["seen"][victim] = true
			bullet["remaining"] -= 1
			_damage_target(victim, float(bullet["damage"]))
			if phase != Phase.RUNNING:
				return
		if bullet["remaining"] <= 0 or bullet["life"] <= 0.0 or wall_hit < 1.0:
			bullets.remove_at(bullet_index)


func result_summary() -> Dictionary:
	# Freeze the result once. Lobby UI and callers receive independent copies.
	if not _finished_result.is_empty():
		return _finished_result.duplicate(true)
	return _summary("")

func _summary(outcome: String) -> Dictionary:
	return {"ended": not outcome.is_empty(), "outcome": outcome,
		"level": growth.level, "elapsed": elapsed, "kills": kills,
		"shots": shots, "magic_casts": magic.casts, "run_id": run_id if not outcome.is_empty() else "", "stage": stage,
		"gold_collected": gold_collected, "gold_bonus": stage_clear_gold if outcome == "cleared" else 0,
		"gold_reward": gold_collected + stage_clear_gold if outcome == "cleared" else 0}

func has_active_run() -> bool:
	return phase in [Phase.RUNNING, Phase.CHOOSING, Phase.PAUSED]

func request_transition(action: String, expected_ticket: int) -> bool:
	if expected_ticket != navigation_ticket or not has_active_run():
		return false
	if action not in ["leave", "restart"] or not transition_action.is_empty():
		return false
	# _resume_phase still owns the underlying choice/running state when paused.
	set_paused(true)
	transition_action = action
	navigation_ticket += 1
	return true

func cancel_transition(expected_ticket: int) -> bool:
	if not _valid_confirmation(expected_ticket):
		return false
	transition_action = ""
	navigation_ticket += 1
	set_paused(false) # Same XP, offer/ticket, HP, MP, timers and RNG state.
	return true

func confirm_transition(expected_ticket: int, account_level: Variant = null) -> bool:
	if not _valid_confirmation(expected_ticket):
		return false
	if transition_action == "restart":
		# start() validates first. On failure keep the old run and confirmation.
		return start(0, growth.character_id, account_level, map_id)
	_finish_run("abandoned")
	return true

func interrupt_transition() -> bool:
	# Focus loss cancels pending intent, NOT the run. Explicit Continue required.
	if phase != Phase.PAUSED or transition_action.is_empty():
		return false
	transition_action = ""
	navigation_ticket += 1
	magic.invalidate_requests()
	return true

func _valid_confirmation(expected_ticket: int) -> bool:
	return expected_ticket == navigation_ticket and phase == Phase.PAUSED and transition_action in ["leave", "restart"]

func _finish_run(outcome: String) -> void:
	# Abandonment is a separate terminal state; it does not inflict damage.
	end_reason = outcome
	phase = {"defeat": Phase.DEFEAT, "timeout": Phase.DEFEAT, "abandoned": Phase.ABANDONED, "cleared": Phase.CLEARED}[outcome]
	transition_action = ""
	navigation_ticket += 1
	magic.invalidate_requests()
	growth.ticket += 1
	growth.offer.clear()
	growth.pending = 0
	feedback.finish()
	_finished_result = _summary(outcome)

func return_to_ready(expected_ticket: int) -> bool:
	if expected_ticket != navigation_ticket or phase not in [Phase.DEFEAT, Phase.ABANDONED, Phase.CLEARED]:
		return false
	phase = Phase.READY
	navigation_ticket += 1
	magic.invalidate_requests()
	# Keep the frozen result until the next explicit start; do not start timers.
	return true

func _drop_gold(at: Vector2, kind: String) -> void:
	if gold_drop_chance < 1.0 and gold_rng.randf() >= gold_drop_chance:
		return
	var amount: int = gold_rng.randi_range(10, 50) if kind == "normal" else gold_rng.randi_range(100, 1000)
	if gold_pickups.size() >= MAX_PICKUPS:
		gold_pickups[-1]["value"] += amount
	else:
		gold_pickups.append({"p": at, "value": amount})

func _collect_gold(dt: float) -> void:
	for i in range(gold_pickups.size() - 1, -1, -1):
		var pos: Vector2 = gold_pickups[i]["p"]
		if pos.distance_squared_to(player) <= pow(float(stats["pickup"]), 2.0):
			pos = pos.move_toward(player, 420.0 * dt)
			gold_pickups[i]["p"] = pos
		if pos.distance_squared_to(player) <= pow(PLAYER_RADIUS + 10.0, 2.0):
			gold_collected += int(gold_pickups[i]["value"])
			gold_pickups.remove_at(i)

func _damage_structure(id: int, base_damage: float) -> void:
	if phase != Phase.RUNNING or not is_finite(base_damage) or base_damage <= 0.0:
		return
	for structure in structures:
		if structure.id != id or structure.hp <= 0:
			continue
		# Supplies use attack power without drawing a combat critical-hit roll.
		var damage := maxi(1, ceili(snappedf(base_damage * float(stats.power), 0.000001)))
		var lost := mini(int(structure.hp), damage)
		structure.hp = maxi(0, int(structure.hp) - damage)
		cues.record_hit(id, structure.p, lost, false)
		if structure.hp == 0:
			structure.generation += 1
			structure.respawn_left = SupplyCatalog.RESPAWN_SECONDS
			var kind := SupplyCatalog.roll_item(loot_rng)
			_effect(structure.p, 30.0, "blast")
			if not kind.is_empty():
				_loot_serial += 1
				item_pickups.append({"id": _loot_serial, "source": id, "generation": structure.generation, "p": structure.p, "kind": kind})
		return # Broken props never reroll or award monster kills/XP/gold.

func _tick_structures(dt: float) -> void:
	# Called only within a RUNNING step; choices/pause/results freeze this timer.
	if phase != Phase.RUNNING or dt <= 0.0 or not is_finite(dt):
		return
	for structure in structures:
		if structure.hp > 0:
			continue
		structure.respawn_left = maxf(0.0, float(structure.respawn_left) - dt)
		if structure.respawn_left <= 0.000000001:
			structure.respawn_left = 0.0
			structure.hp = structure.max_hp

func _collect_items(dt: float) -> void:
	for index in range(item_pickups.size() - 1, -1, -1):
		if phase != Phase.RUNNING:
			return
		var item: Dictionary = item_pickups[index]
		if item.p.distance_squared_to(player) <= pow(float(stats.pickup), 2.0):
			item.p = item.p.move_toward(player, 420.0 * dt)
		if item.p.distance_squared_to(player) > pow(PLAYER_RADIUS + 10.0, 2.0):
			continue
		# Commit removal before the effect, including effects that open a choice.
		item_pickups.remove_at(index)
		_apply_supply(str(item.kind))

func _apply_supply(kind: String) -> void:
	if phase != Phase.RUNNING or kind not in SupplyCatalog.ITEM_KINDS:
		return
	match kind:
		"hp":
			_heal_hp(max_hp * SupplyCatalog.RECOVERY_FRACTION)
		"mp":
			magic.mana = minf(magic.maximum_mana(), magic.mana + magic.maximum_mana() * SupplyCatalog.RECOVERY_FRACTION)
		"magnet":
			var xp := 0.0
			for pickup in pickups:
				xp += float(pickup.value) * float(stats.xp)
			for gold in gold_pickups:
				gold_collected += int(gold.value)
			pickups.clear()
			gold_pickups.clear()
			if xp > 0.0:
				grant_xp(xp)
				cues.record_collected_xp(player, xp)
		"purge":
			for index in range(enemies.size() - 1, -1, -1):
				if enemies[index].kind != "boss":
					_defeat_enemy(index)
			enemy_bullets.clear()
	cues.record_item(player, str(SupplyCatalog.ITEM_NAMES[kind]))

func _clear_stage() -> void:
	if phase not in [Phase.RUNNING, Phase.CHOOSING] or not _boss_defeated or elapsed + 0.000001 < stage_duration:
		return
	# Sweep the final boss drop and remaining field gold into the same settlement.
	for pickup in gold_pickups:
		gold_collected += int(pickup["value"])
	gold_pickups.clear()
	_finish_run("cleared")

func _resolve_deadline() -> void:
	if phase not in [Phase.RUNNING, Phase.CHOOSING] or elapsed + 0.000001 < stage_duration:
		return
	if _boss_defeated:
		_clear_stage()
	else:
		_finish_run("timeout")

func wave_profile() -> Dictionary:
	var selected: Dictionary = stage_rules.get("waves", [{"hp": 20, "speed": 68.0}])[0]
	for wave in stage_rules.get("waves", []):
		if elapsed >= float(wave.from):
			selected = wave
	return selected

func park_saved_run() -> bool:
	if phase != Phase.PAUSED or not transition_action.is_empty():
		return false
	phase = Phase.READY
	navigation_ticket += 1
	magic.invalidate_requests()
	return true

func camera_center() -> Vector2:
	return player if map_id == "legacy_arena" else map_space.camera_center(player, spawn_view_size)

func visible_world() -> Rect2:
	return Rect2(camera_center() - spawn_view_size * 0.5, spawn_view_size)

func _spawn_map_formation(variant: String, columns: int, spacing: float, jitter: float, generator: RandomNumberGenerator, scatter: bool) -> bool:
	var rows := SWARM_SIZE / columns
	var footprint := Vector2((columns - 1) * spacing, (rows - 1) * spacing).length() * 0.5 + jitter * sqrt(2.0) + 24.0
	var at: Variant = map_space.spawn_anchor(generator, player, elapsed, "normal", visible_world(), footprint)
	if not at is Vector2:
		return false
	var center: Vector2 = at
	var direction := center.direction_to(player)
	var positions: Array[Vector2] = []
	for index in range(SWARM_SIZE):
		var offset := direction.orthogonal() * ((index % columns) - (columns - 1) * 0.5) * spacing
		offset += direction * (int(index / columns) - (rows - 1) * 0.5) * spacing
		offset += Vector2(generator.randf_range(-jitter,jitter),generator.randf_range(-jitter,jitter)) if jitter > 0.0 else Vector2.ZERO
		var position := center + offset
		if not map_space.valid_position(position, 24.0) or visible_world().grow(32).has_point(position):
			return false # Never commit a partial group or spawn in a wall/on screen.
		positions.append(position)
	if scatter:
		_scatter_index += 1
	if variant == "flier":
		_swarm_serial += 1
	for position in positions:
		add_enemy(position, "normal", variant, _scatter_index if scatter else 0)
		if variant == "flier":
			enemies[-1].velocity = direction * float(stage_rules.swarm.speed)
	return true
