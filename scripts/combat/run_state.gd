extends RefCounted
## One authoritative simulation. All numbers/effects are provisional test tuning.
const Growth = preload("res://scripts/progression/growth_state.gd")
const MagicState = preload("res://scripts/combat/magic_state.gd")
const FeedbackState = preload("res://scripts/combat/feedback_state.gd")
enum Phase { READY, RUNNING, PAUSED, DEFEAT, CHOOSING, ABANDONED }
const WORLD_SIZE := Vector2(1800.0, 1200.0)
const PLAYER_SPEED := 235.0
const PLAYER_RADIUS := 17.0
const ENEMY_RADIUS := 18.0
const MAX_ENEMIES := 80
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
var bullets: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var growth = Growth.new()
var magic = MagicState.new()
var feedback = FeedbackState.new()
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

func start(seed_value: int = 0, character_id: String = "viya") -> bool:
	# Validate the complete selected character before changing the previous run.
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
	magic.reset(candidate, character_id)
	feedback.reset()
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

func add_enemy(at: Vector2) -> bool:
	if enemies.size() >= MAX_ENEMIES:
		return false
	_enemy_serial += 1
	enemies.append({"id": _enemy_serial, "p": at, "hp": 20})
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
	hp = mini(max_hp, hp + maxi(0, max_hp - previous_max))
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
	max_hp = 100 + 20 * _effect_rank("vitality")
	stats = {"power": 1.0 + 0.15 * _effect_rank("power"),
		"rate": 1.0 + 0.08 * _effect_rank("haste"),
		"speed": PLAYER_SPEED * (1.0 + 0.07 * _effect_rank("stride")),
		"pickup": 80.0 + 20.0 * _effect_rank("magnet"),
		"xp": 1.0 + 0.12 * _effect_rank("learning"),
		"crit": 0.04 * _effect_rank("precision"),
		"regen": 0.6 * _effect_rank("recovery"),
		"ultimate": _effect_rank("ultimate")}

func step(delta: float, direction: Vector2) -> void:
	if phase != Phase.RUNNING or delta <= 0.0 or not is_finite(delta):
		return
	var dt := minf(delta, 0.05)
	feedback.advance(dt, true)
	elapsed += dt
	hurt_clock = maxf(0.0, hurt_clock - dt)
	var movement := direction.limit_length(1.0)
	player += movement * float(stats["speed"]) * dt
	player = player.clamp(Vector2.ONE * 30.0, WORLD_SIZE - Vector2.ONE * 30.0)
	if movement.length_squared() > 0.001:
		facing = movement.normalized()
	_collect_pickups(dt)
	if phase != Phase.RUNNING:
		return
	spawn_clock -= dt
	if spawn_clock <= 0.0:
		_spawn_enemy()
		spawn_clock = maxf(0.32, 0.85 - elapsed * 0.003)
	_move_enemies(dt)
	if phase != Phase.RUNNING:
		return
	shot_clock = maxf(0.0, shot_clock - dt)
	if shot_clock == 0.0:
		_auto_fire()
	magic.advance(dt, true)
	_tick_skills(dt)
	_move_bullets(dt)
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

func _collect_pickups(dt: float) -> void:
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

func _spawn_enemy() -> void:
	if enemies.size() >= MAX_ENEMIES:
		return
	for attempt in range(8):
		var candidate := player + Vector2.from_angle(rng.randf_range(0.0, TAU)) * 590.0
		candidate = candidate.clamp(Vector2.ONE * 24.0, WORLD_SIZE - Vector2.ONE * 24.0)
		if candidate.distance_squared_to(player) >= 160.0 * 160.0:
			add_enemy(candidate)
			return

func _move_enemies(dt: float) -> void:
	var speed := 68.0 + minf(38.0, elapsed * 0.35)
	for enemy in enemies:
		var pos: Vector2 = enemy["p"]
		var offset := player - pos
		if offset.length_squared() > 0.01:
			pos += offset.normalized() * minf(speed * dt, offset.length())
		enemy["p"] = pos
		if pos.distance_squared_to(player) <= pow(PLAYER_RADIUS + ENEMY_RADIUS, 2.0):
			damage_player(12)
			if phase == Phase.DEFEAT:
				return

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
	if _projectile(direction, 10.0 + 3.0 * (_effect_rank("rifle") - 1), 1):
		shot_clock = SHOT_INTERVAL / float(stats["rate"])

func _projectile(direction: Vector2, damage: float, hits: int, speed: float = BULLET_SPEED) -> bool:
	if bullets.size() >= MAX_BULLETS:
		return false
	bullets.append({"p": player, "direction": direction, "life": 0.75,
		"speed": speed, "damage": damage, "remaining": hits, "seen": {}})
	shots += 1
	return true

func _damage_enemy(id: int, base_damage: float) -> void:
	for i in range(enemies.size()):
		if int(enemies[i]["id"]) != id:
			continue
		var damage := base_damage * float(stats["power"])
		if float(stats["crit"]) > 0.0 and rng.randf() < float(stats["crit"]):
			damage *= 2.0
		enemies[i]["hp"] -= maxi(1, int(ceil(damage)))
		if enemies[i]["hp"] <= 0:
			add_pickup(enemies[i]["p"])
			enemies.remove_at(i)
			kills += 1
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
		var at: Vector2 = target["p"]
		var direction := (at - player).normalized()
		if direction.is_zero_approx():
			direction = facing
		match effect:
			"scatter":
				for n in range(3):
					_projectile(direction.rotated((n - 1) * 0.22), 7.0 + rank * 2.0, 1)
			"lance":
				_projectile(direction, 12.0 + rank * 4.0, 1 + rank, 1150.0)
			"grenade":
				_burst(at, 60.0 + rank * 8.0, 12.0 + rank * 4.0, "blast")
			"pulse":
				_burst(player, 105.0 + rank * 8.0, 8.0 + rank * 3.0, "pulse")
			"crossfire":
				for n in range(4):
					_projectile(Vector2.from_angle(n * PI * 0.5), 9.0 + rank * 3.0, 1)
			"chain":
				var used: Array[int] = []
				var anchor := player
				for n in range(1 + rank):
					var linked := _nearest(anchor, SHOT_RANGE if n == 0 else 160.0, used)
					if linked.is_empty():
						break
					var victim: int = linked["id"]
					anchor = linked["p"]
					used.append(victim)
					_damage_enemy(victim, 9.0 + rank * 2.0)
					_effect(anchor, 28.0, "chain")
			"heavy":
				_projectile(direction, 24.0 + rank * 8.0, 1, 1300.0)
			"sigil":
				_burst(at, 75.0 + rank * 12.0, 18.0 + rank * 6.0, "sigil")
		skill_clocks[id] = (2.0 if effect != "sigil" else 3.0) / float(stats["rate"])

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
		"shots": shots, "magic_casts": magic.casts}

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

func confirm_transition(expected_ticket: int) -> bool:
	if not _valid_confirmation(expected_ticket):
		return false
	if transition_action == "restart":
		# start() validates first. On failure keep the old run and confirmation.
		return start(0, growth.character_id)
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
	phase = Phase.DEFEAT if outcome == "defeat" else Phase.ABANDONED
	transition_action = ""
	navigation_ticket += 1
	magic.invalidate_requests()
	growth.ticket += 1
	growth.offer.clear()
	growth.pending = 0
	feedback.finish()
	_finished_result = _summary(outcome)

func return_to_ready(expected_ticket: int) -> bool:
	if expected_ticket != navigation_ticket or phase not in [Phase.DEFEAT, Phase.ABANDONED]:
		return false
	phase = Phase.READY
	navigation_ticket += 1
	magic.invalidate_requests()
	# Keep the frozen result until the next explicit start; do not start timers.
	return true
