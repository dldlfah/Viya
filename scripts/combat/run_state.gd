extends RefCounted
## One authoritative simulation. All numbers/effects are provisional test tuning.
const Growth = preload("res://scripts/progression/growth_state.gd")
const MagicState = preload("res://scripts/combat/magic_state.gd")
const FeedbackState = preload("res://scripts/combat/feedback_state.gd")
const CombatCues = preload("res://scripts/combat/combat_cues.gd")
const StageCatalog = preload("res://scripts/combat/stage_catalog.gd")
const AccountTalents = preload("res://scripts/progression/account_talents.gd")
enum Phase { READY, RUNNING, PAUSED, DEFEAT, CHOOSING, ABANDONED, CLEARED }
const WORLD_SIZE := Vector2(1800.0, 1200.0)
const PLAYER_SPEED := 235.0
const PLAYER_RADIUS := 17.0
const ENEMY_RADIUS := 18.0
const MAX_ENEMIES := 160
const MAX_ENEMY_BULLETS := 64
const SWARM_SIZE := 30
const MAX_BULLETS := 64
const MAX_PICKUPS := 240
const MAX_EFFECTS := 32
const SHOT_INTERVAL := 0.30
const SHOT_RANGE := 520.0
const BULLET_SPEED := 920.0
const HIT_LOCK := 0.85

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
var account_attack_level: int = 0 # Frozen at departure, including saved battles.

func start(seed_value: int = 0, character_id: String = "viya", account_level: int = -1) -> bool:
	# Validate the complete selected character before changing the previous run.
	var selected_account_level := account_attack_level if account_level == -1 else account_level
	if not AccountTalents.valid_level(selected_account_level):
		return false
	var rules: Dictionary = stage_catalog.for_stage(stage)
	if rules.is_empty():
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
	account_attack_level = selected_account_level
	gold_rng.seed = int(rng.seed) ^ 0x601D
	encounter_rng.seed = int(rng.seed) ^ 0xE11C
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	gold_collected = 0
	gold_pickups.clear()
	_elites_spawned = 0
	_boss_spawned = false
	_boss_defeated = false
	checkpoint_index = 0
	end_reason = ""
	stage_rules = rules
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
	player = WORLD_SIZE * 0.5
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
	_resume_phase = Phase.RUNNING
	enemies.clear()
	enemy_bullets.clear()
	bullets.clear()
	pickups.clear()
	effects.clear()
	skill_clocks.clear()
	_refresh_stats()
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
	hp = maxi(0, hp - amount)
	hurt_clock = HIT_LOCK
	if hp == 0:
		_finish_run("defeat")
	else:
		feedback.trigger("hurt")
	return true

func add_enemy(at: Vector2, kind: String = "normal", variant: String = "normal") -> bool:
	if kind not in ["normal", "elite", "boss"]:
		return false
	if variant not in ["normal", "ranged", "fast", "heavy", "flier"] or (kind != "normal" and variant != "normal"):
		return false
	if variant != "flier" and _ground_count() >= MAX_ENEMIES:
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
	var enemy := {"id": _enemy_serial, "p": at, "hp": life, "max_hp": life, "kind": kind, "variant": variant, "speed": speed}
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

func stats_profile(levels: Dictionary) -> Dictionary:
	# Pure lookup shared by actual upgrades and choice previews. Never edit levels.
	var ranks: Dictionary = {}
	for entry in growth.pool:
		var effect: String = str(entry["effect"])
		if not ranks.has(effect):
			ranks[effect] = int(levels.get(entry["id"], 0))
	return {"max_hp": 100 + 20 * int(ranks.get("vitality", 0)),
		"stats": {"power": (1.0 + 0.15 * int(ranks.get("power", 0))) * AccountTalents.power_multiplier(account_attack_level),
			"rate": 1.0 + 0.08 * int(ranks.get("haste", 0)),
			"speed": PLAYER_SPEED * (1.0 + 0.07 * int(ranks.get("stride", 0))),
			"pickup": 80.0 + 20.0 * int(ranks.get("magnet", 0)),
			"xp": 1.0 + 0.12 * int(ranks.get("learning", 0)),
			"crit": 0.04 * int(ranks.get("precision", 0)),
			"regen": 0.6 * int(ranks.get("recovery", 0)),
			"ultimate": int(ranks.get("ultimate", 0))}}

func selection_health(current_hp: int, previous_max: int, next_max: int) -> int:
	return mini(next_max, current_hp + maxi(0, next_max - previous_max))

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
	var movement := direction.limit_length(1.0)
	player += movement * float(stats["speed"]) * dt
	player = player.clamp(Vector2.ONE * 30.0, WORLD_SIZE - Vector2.ONE * 30.0)
	if movement.length_squared() > 0.001:
		facing = movement.normalized()
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
	if hp < max_hp:
		_regen_remainder += float(stats["regen"]) * dt
		var healing := int(_regen_remainder)
		hp = mini(max_hp, hp + healing)
		_regen_remainder -= healing
	else:
		_regen_remainder = 0.0
	_resolve_deadline()

func _collect_pickups(dt: float) -> void:
	_collect_gold(dt)
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
		if enemy.variant != "flier":
			count += 1
	return count

func _spawn_enemy(kind: String = "normal") -> bool:
	# Flying formations have their own lifetime; only reserve the ground boss slot.
	var limit: int = MAX_ENEMIES - (0 if _boss_spawned else 1)
	if kind == "boss":
		limit = MAX_ENEMIES
	if _ground_count() >= limit:
		return false
	for attempt in range(8):
		var candidate := player + Vector2.from_angle(rng.randf_range(0.0, TAU)) * 590.0
		candidate = candidate.clamp(Vector2.ONE * 24.0, WORLD_SIZE - Vector2.ONE * 24.0)
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
			pos = pos.clamp(Vector2.ONE * 24.0, WORLD_SIZE - Vector2.ONE * 24.0)
		elif offset.length_squared() > 0.01:
			pos += offset.normalized() * minf(speed * dt, offset.length())
		enemy["p"] = pos
		if variant == "ranged":
			_tick_ranged(enemy, dt)
	_move_fliers(dt)
	for enemy in enemies:
		if enemy.p.distance_squared_to(player) <= pow(PLAYER_RADIUS + ENEMY_RADIUS, 2.0):
			damage_player(12)
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
			enemy.p = (enemy.p + direction * (front - distance)).clamp(Vector2.ONE * 24.0, WORLD_SIZE - Vector2.ONE * 24.0)

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
		bullet.p += bullet.velocity * minf(dt, float(bullet.life))
		bullet.life -= dt
		var nearest := Geometry2D.get_closest_point_to_segment(player, previous, bullet.p)
		var hit: bool = nearest.distance_squared_to(player) <= pow(PLAYER_RADIUS + 5.0, 2.0)
		if hit:
			damage_player(int(bullet.damage))
		if hit or bullet.life <= 0.0:
			enemy_bullets.remove_at(index)
		if phase != Phase.RUNNING:
			return

func _tick_swarm(dt: float) -> void:
	if _swarm_pending:
		_spawn_swarm()
		_swarm_pending = false
		return
	_swarm_clock = maxf(0.0, _swarm_clock - dt)
	if _swarm_clock > 0.0:
		return
	_swarm_clock = float(stage_rules.swarm.interval)
	var chance: float = float(stage_rules.swarm.chance)
	if chance >= 1.0 or encounter_rng.randf() < chance:
		_spawn_swarm()

func _spawn_swarm() -> bool:
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
	return found

func _auto_fire() -> void:
	var target := _nearest(player, SHOT_RANGE)
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
			damage *= 2.0
			critical = true
		if account_attack_level > 0:
			# 100 * 1.10 must be 110, not 111 from binary rounding before ceil.
			damage = snappedf(damage, 0.000001)
		enemies[i]["hp"] -= maxi(1, int(ceil(damage)))
		# Display HP actually removed, not theoretical overkill damage. Reuse the crit roll.
		var hp_lost: int = maxi(0, previous_hp - maxi(0, int(enemies[i]["hp"])))
		cues.record_hit(id, hit_at, hp_lost, critical)
		if enemies[i]["hp"] <= 0:
			add_pickup(enemies[i]["p"])
			var kind: String = str(enemies[i].get("kind", "normal"))
			_drop_gold(hit_at, kind)
			enemies.remove_at(i)
			kills += 1
			cues.record_kill(id, hit_at)
			if kind == "boss" and _boss_spawned:
				_boss_defeated = true
				if elapsed + 0.000001 >= stage_duration:
					_clear_stage()
		return

func _burst(at: Vector2, radius: float, damage: float, kind: String) -> void:
	var targets: Array[int] = []
	for enemy in enemies:
		if at.distance_squared_to(enemy["p"]) <= radius * radius:
			targets.append(int(enemy["id"]))
	for id in targets:
		_damage_enemy(id, damage)
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
		var target := _nearest(player, SHOT_RANGE)
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
					var linked := _nearest(anchor, SHOT_RANGE if n == 0 else float(profile["link_range"]), used)
					if linked.is_empty():
						break
					var victim: int = linked["id"]
					var link_from: Vector2 = anchor
					anchor = linked["p"]
					used.append(victim)
					_damage_enemy(victim, float(profile["damage"]))
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
		bullet["p"] = new_pos
		bullet["life"] -= dt
		# Swept collision, ordered impacts, stable enemy IDs: one hit per target.
		while int(bullet["remaining"]) > 0:
			var victim := -1
			var first_distance := INF
			for enemy in enemies:
				if bullet["seen"].has(enemy["id"]):
					continue
				var pos: Vector2 = enemy["p"]
				var nearest := Geometry2D.get_closest_point_to_segment(pos, old_pos, new_pos)
				if pos.distance_squared_to(nearest) <= pow(ENEMY_RADIUS + 4.0, 2.0):
					var distance := old_pos.distance_squared_to(nearest)
					if distance < first_distance:
						first_distance = distance
						victim = int(enemy["id"])
			if victim == -1:
				break
			bullet["seen"][victim] = true
			bullet["remaining"] -= 1
			_damage_enemy(victim, float(bullet["damage"]))
			if phase != Phase.RUNNING:
				return
		if bullet["remaining"] <= 0 or bullet["life"] <= 0.0:
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

func confirm_transition(expected_ticket: int, account_level: int = -1) -> bool:
	if not _valid_confirmation(expected_ticket):
		return false
	if transition_action == "restart":
		# start() validates first. On failure keep the old run and confirmation.
		return start(0, growth.character_id, account_level)
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
