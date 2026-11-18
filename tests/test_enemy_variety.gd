extends RefCounted
const RunState = preload("res://scripts/combat/run_state.gd")
const Store = preload("res://scripts/progression/run_store.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const Campaign = preload("res://tests/test_campaign.gd")

static func quiet(seed_value: int = 71):
	var state = RunState.new()
	state.start(seed_value)
	state.spawn_clock = 999.0
	state.shot_clock = 999.0
	return state

static func run(scene, verify: Callable) -> void:
	var state = quiet()
	state.add_enemy(state.player + Vector2(300, 0), "elite")
	state._elites_spawned = 1
	state.add_enemy(state.player + Vector2(300, 0), "elite")
	state.add_enemy(state.player + Vector2(300, 0), "boss")
	verify.call(state.enemies[0].hp == 1600 and state.enemies[1].hp == 1600 and state.enemies[2].hp == 3200, "Both elites inherit the old boss HP, and the boss has twice its old HP")
	for index in range(3):
		verify.call(int(state.stage_rules.waves[index].batch) == (index + 1) * 2, "Wave batch doubles with the existing interval preserved")
	var baseline: Array = spawn_counts(false)
	var doubled: Array = spawn_counts(true)
	verify.call(doubled == [baseline[0] * 2, baseline[1] * 2, baseline[2] * 2], "Actual step scheduling doubles ordinary spawns in every two-minute segment")
	for time in [0.0, 120.0, 240.0]:
		state = quiet()
		state.elapsed = time
		for variant in ["normal", "fast", "heavy", "ranged"]:
			state.add_enemy(state.player + Vector2(300, 0), "normal", variant)
		var normal: Dictionary = state.enemies[0]
		var fast: Dictionary = state.enemies[1]
		var heavy: Dictionary = state.enemies[2]
		verify.call(heavy.hp == normal.hp * 2 and heavy.speed < normal.speed and fast.speed > normal.speed, "Fast and double-HP slow variants scale with their actual wave")
		state._move_enemies(0.05)
		verify.call(fast.p.x < normal.p.x and heavy.p.x > normal.p.x, "Variant speeds affect actual pursuit movement")
	state = quiet()
	var streams: Array = [state.rng.state, state.growth.rng.state, state.gold_rng.state]
	var counts := {"normal": 0, "ranged": 0, "fast": 0, "heavy": 0}
	for sample in range(10000):
		counts[state._roll_variant()] += 1
	verify.call(counts.normal > 5200 and counts.normal < 5800 and counts.ranged > 1200 and counts.fast > 1200 and counts.heavy > 1200, "Data weights produce all four ordinary enemy variants")
	verify.call(streams == [state.rng.state, state.growth.rng.state, state.gold_rng.state], "Encounter rolls leave combat, choice and gold RNG streams intact")
	ranged_checks(verify)
	swarm_checks(verify)
	var directory := "user://enemy-test-" + Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(directory)
	state = quiet()
	state._spawn_swarm()
	state.add_enemy(state.player + Vector2(300, 0), "normal", "ranged")
	state.enemies[-1].fire_clock = 0.0
	state._move_enemies(0.05)
	state.enemy_bullets.append({"p": state.player + Vector2(-200, 60), "velocity": Vector2(240, 0), "life": 2.0, "damage": 8})
	state._swarm_pending = true
	var store = Store.new()
	store.path = directory.path_join("enemies.save")
	verify.call(store.save_current(state) == OK and store.load_saved(state) == OK, "Windups, hostile projectiles, complete formations and pending swarms save successfully")
	var restored = quiet(72)
	verify.call(Snapshot.restore(store.pending, restored), "New enemy state restores into the existing RunState")
	restored.set_paused(false)
	verify.call(Campaign.comparable(state) == Campaign.comparable(restored), "All enemy timers, projectile positions, formation state and encounter RNG round trip exactly")
	var equal := true
	for frame in range(30):
		state.step(0.05, Vector2.DOWN)
		restored.step(0.05, Vector2.DOWN)
		equal = equal and Campaign.comparable(state) == Campaign.comparable(restored)
	verify.call(equal, "Resumed enemy attacks and swarms produce the same subsequent simulation")
	var bad: Dictionary = store.pending.duplicate(true)
	bad.run.enemy_bullets[0].damage = -1
	verify.call(not Snapshot.valid(bad, restored), "Malformed hostile projectile data is rejected")
	legacy_checks(store, verify)
	# Draw actual archetypes and hostile attacks through the production View.
	scene.begin_run()
	scene.simulation.spawn_clock = 999.0
	for variant in ["normal", "ranged", "fast", "heavy"]:
		scene.simulation.add_enemy(scene.simulation.player + Vector2(200, 0), "normal", variant)
	scene.simulation.enemies[1].windup = 0.5
	scene.simulation.enemies[1].aim = scene.simulation.player
	scene.simulation._spawn_swarm()
	scene.simulation.enemy_bullets.append({"p": scene.simulation.player + Vector2(100, 0), "velocity": Vector2(-240, 0), "life": 1.0, "damage": 8})
	var before: Dictionary = Campaign.comparable(scene.simulation)
	scene.view.queue_redraw()
	await scene.get_tree().process_frame
	await scene.get_tree().process_frame
	verify.call(before == Campaign.comparable(scene.simulation), "Actual archetype/telegraph/projectile rendering is read-only")
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	verify.call(true, "Enemy variety suite reached its last integration check")

static func spawn_counts(doubled: bool) -> Array:
	var state = quiet()
	state.spawn_clock = 0.2
	state.stage_rules.swarm.chance = 0.0
	if not doubled:
		for wave in state.stage_rules.waves:
			wave.batch = float(wave.batch) / 2.0
	var counts: Array = [0, 0, 0]
	for frame in range(7200):
		state.step(0.05, Vector2.ZERO)
		var segment: int = mini(2, int(state.elapsed / 120.0))
		for enemy in state.enemies:
			if enemy.kind == "normal":
				counts[segment] += 1
		# Count scheduled production spawns independently of the live population cap.
		state.enemies.clear()
	return counts

static func ranged_checks(verify: Callable) -> void:
	var state = quiet()
	state.add_enemy(state.player + Vector2(300, 0), "normal", "ranged")
	var enemy: Dictionary = state.enemies[0]
	enemy.fire_clock = 0.0
	state._move_enemies(0.05)
	verify.call(enemy.windup > 0.0 and state.enemy_bullets.is_empty(), "Ranged attacks telegraph before producing a damaging projectile")
	var aim: Vector2 = enemy.aim
	state.player += Vector2(0, 120)
	for frame in range(15):
		state._move_enemies(0.05)
	verify.call(state.enemy_bullets.size() == 1 and enemy.aim == aim, "Windup locks its original target instead of tracking a dodging player")
	state._move_enemy_bullets(1.5)
	verify.call(state.hp == 100, "Moving away from the telegraphed line avoids ranged damage")
	state.enemy_bullets.clear()
	state.enemy_bullets.append({"p": state.player - Vector2(100, 0), "velocity": Vector2(4000, 0), "life": 1.0, "damage": 8})
	state._move_enemy_bullets(0.05)
	verify.call(state.hp == 92 and state.enemy_bullets.is_empty(), "Swept hostile projectile collision cannot tunnel through the player")
	state.hurt_clock = 0.0
	for index in range(2):
		state.enemy_bullets.append({"p": state.player - Vector2(60, 0), "velocity": Vector2(2000, 0), "life": 1.0, "damage": 8})
	state._move_enemy_bullets(0.05)
	verify.call(state.hp == 84, "Existing invulnerability prevents same-frame ranged damage stacking")
	state = quiet()
	for index in range(state.MAX_ENEMY_BULLETS + 5):
		state.add_enemy(state.player + Vector2(300, 0), "normal", "ranged")
		state.enemies[-1].windup = 0.01
	state._move_enemies(0.05)
	verify.call(state.enemy_bullets.size() == state.MAX_ENEMY_BULLETS, "Hostile projectile capacity is bounded under simultaneous fire")
	var before: Dictionary = Campaign.comparable(state)
	state.set_paused(true)
	state.step(0.05, Vector2.RIGHT)
	state.set_paused(false)
	verify.call(before == Campaign.comparable(state), "Pause freezes windups, hostile bullets and encounter schedules")

static func swarm_checks(verify: Callable) -> void:
	var state = quiet()
	verify.call(state._spawn_swarm() and state.enemies.size() == 20, "A flying formation contains exactly twenty real enemies")
	var offset: Vector2 = state.enemies[19].p - state.enemies[0].p
	state._move_enemies(0.05)
	verify.call((state.enemies[19].p - state.enemies[0].p).is_equal_approx(offset), "Flying enemies retain their formation during approach")
	state._move_enemies(5.0)
	verify.call(state.enemies.is_empty() and state.kills == 0 and state.pickups.is_empty() and state.gold_pickups.is_empty(), "Expired fly-bys despawn without inventing kills or rewards")
	state = quiet()
	state.stage_rules.swarm.chance = 0.0
	state._swarm_clock = 0.0
	state._tick_swarm(0.05)
	verify.call(state.enemies.is_empty() and not state._swarm_pending, "Zero probability never creates a swarm")
	state.stage_rules.swarm.chance = 1.0
	state._swarm_clock = 0.0
	for index in range(state.MAX_ENEMIES - 20):
		state.add_enemy(state.player + Vector2(500, 0))
	state._tick_swarm(0.05)
	verify.call(state._swarm_pending and state.enemies.size() == state.MAX_ENEMIES - 20, "A saturated scene queues a full formation instead of spawning a partial group")
	state.enemies.pop_back()
	state._tick_swarm(0.05)
	verify.call(not state._swarm_pending and state.enemies.filter(func(enemy): return enemy.variant == "flier").size() == 20, "Queued formation spawns all twenty when capacity becomes available")
	state.elapsed = 300.0
	state._boss_spawned = state._spawn_enemy("boss")
	verify.call(state._boss_spawned and state.enemies.size() == state.MAX_ENEMIES, "Swarm reservation still permits the scheduled boss")
	state = quiet()
	state._spawn_swarm()
	var targets: Array = state.enemies.duplicate()
	for enemy in targets:
		state._damage_enemy(enemy.id, 10000)
	verify.call(state.kills == 20 and state.pickups.size() == 20, "Flying enemies use the normal death, XP and gold path when killed")

static func legacy_checks(store, verify: Callable) -> void:
	var old = quiet()
	old.add_enemy(old.player + Vector2(150, 0))
	old.enemies[0].hp = 9
	var legacy: Dictionary = Snapshot.capture(old)
	legacy.version = 1
	legacy.rules = Snapshot.LEGACY_RULES
	legacy.rng.pop_back()
	for key in ["enemy_bullets", "_swarm_clock", "_swarm_pending", "_swarm_serial"]:
		legacy.run.erase(key)
	for enemy in legacy.run.enemies:
		enemy.erase("variant")
	store.write_snapshot(legacy)
	var restored = quiet(75)
	verify.call(store.load_saved(restored) == OK and store.pending.version == 2, "Published GAME-009 snapshots migrate through the real file loader")
	verify.call(Snapshot.restore(store.pending, restored) and restored.enemies[0].hp == 9 and restored.enemies[0].max_hp == 20, "Migration preserves living enemies and their actual damage")
	verify.call(restored.growth.owned == old.growth.owned and restored.rng.state == old.rng.state and restored.growth.rng.state == old.growth.rng.state and restored.gold_rng.state == old.gold_rng.state, "Migration preserves skills and all three existing RNG streams")
	restored.add_enemy(restored.player + Vector2(300, 0), "elite")
	verify.call(restored.enemies[-1].hp == 1600, "Future spawns in a migrated battle use the updated elite profile")
	for fingerprint in Snapshot.LEGACY_FINGERPRINTS:
		legacy.rules = fingerprint
		var migrated: Dictionary = Snapshot.upgrade_legacy(legacy, restored)
		verify.call(migrated.version == 2 and Snapshot.valid(migrated, restored), "GAME-009 migration accepts the published data's LF/CRLF line-ending fingerprints")
