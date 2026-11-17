extends RefCounted
## One authoritative simulation. UI and future character art only read this state.
## All values below are prototype tuning, not approved final balance.
enum Phase { READY, RUNNING, PAUSED, DEFEAT }
const WORLD_SIZE := Vector2(1800.0, 1200.0)
const PLAYER_SPEED := 235.0
const PLAYER_RADIUS := 17.0
const ENEMY_RADIUS := 18.0
const MAX_ENEMIES := 80
const MAX_BULLETS := 64
const SHOT_INTERVAL := 0.30
const SHOT_RANGE := 520.0
const BULLET_SPEED := 920.0
const HIT_LOCK := 0.85

var phase: int = Phase.READY
var player := WORLD_SIZE * 0.5
var facing := Vector2.RIGHT
var hp: int = 100
var elapsed: float = 0.0
var kills: int = 0
var shots: int = 0
var shot_clock: float = 0.0
var spawn_clock: float = 0.0
var hurt_clock: float = 0.0
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func start(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	player = WORLD_SIZE * 0.5
	facing = Vector2.RIGHT
	hp = 100
	elapsed = 0.0
	kills = 0
	shots = 0
	shot_clock = 0.0
	spawn_clock = 0.2
	hurt_clock = 0.0
	enemies.clear()
	bullets.clear()
	phase = Phase.RUNNING

func set_paused(value: bool) -> void:
	if value and phase == Phase.RUNNING:
		phase = Phase.PAUSED
	elif not value and phase == Phase.PAUSED:
		phase = Phase.RUNNING

func damage_player(amount: int) -> bool:
	if phase != Phase.RUNNING or hurt_clock > 0.0 or amount <= 0:
		return false
	hp = maxi(0, hp - amount)
	hurt_clock = HIT_LOCK
	if hp == 0:
		phase = Phase.DEFEAT
	return true

func add_enemy(at: Vector2) -> bool:
	if enemies.size() >= MAX_ENEMIES:
		return false
	enemies.append({"p": at, "hp": 20})
	return true

func step(delta: float, direction: Vector2) -> void:
	if phase != Phase.RUNNING or delta <= 0.0:
		return
	var dt := minf(delta, 0.05)
	elapsed += dt
	hurt_clock = maxf(0.0, hurt_clock - dt)
	var movement := direction.limit_length(1.0)
	player += movement * PLAYER_SPEED * dt
	player = player.clamp(Vector2.ONE * 30.0, WORLD_SIZE - Vector2.ONE * 30.0)
	if movement.length_squared() > 0.001:
		facing = movement.normalized()
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
	_move_bullets(dt)

func _spawn_enemy() -> void:
	if enemies.size() >= MAX_ENEMIES:
		return
	for attempt in range(8):
		var angle := rng.randf_range(0.0, TAU)
		var candidate := player + Vector2.from_angle(angle) * 590.0
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

func _auto_fire() -> void:
	if bullets.size() >= MAX_BULLETS:
		return
	var best := SHOT_RANGE * SHOT_RANGE
	var target := Vector2.ZERO
	var found := false
	for enemy in enemies:
		var pos: Vector2 = enemy["p"]
		var distance := player.distance_squared_to(pos)
		if distance < best:
			best = distance
			target = pos
			found = true
	if not found:
		return
	var direction := (target - player).normalized()
	if direction.length_squared() < 0.01:
		direction = facing
	facing = direction
	bullets.append({"p": player, "direction": direction, "life": 0.75})
	shots += 1
	shot_clock = SHOT_INTERVAL

func _move_bullets(dt: float) -> void:
	for bullet_index in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[bullet_index]
		var old_pos: Vector2 = bullet["p"]
		var new_pos: Vector2 = old_pos + bullet["direction"] * BULLET_SPEED * dt
		bullet["p"] = new_pos
		bullet["life"] -= dt
		var hit_index := -1
		var first_distance := INF
		# Swept segment collision avoids tunnelling through enemies at low FPS.
		for enemy_index in range(enemies.size()):
			var pos: Vector2 = enemies[enemy_index]["p"]
			var nearest := Geometry2D.get_closest_point_to_segment(pos, old_pos, new_pos)
			if pos.distance_squared_to(nearest) <= pow(ENEMY_RADIUS + 4.0, 2.0):
				var distance := old_pos.distance_squared_to(nearest)
				if distance < first_distance:
					first_distance = distance
					hit_index = enemy_index
		if hit_index >= 0:
			enemies[hit_index]["hp"] -= 10
			if enemies[hit_index]["hp"] <= 0:
				enemies.remove_at(hit_index)
				kills += 1
			bullets.remove_at(bullet_index)
		elif bullet["life"] <= 0.0:
			bullets.remove_at(bullet_index)
