extends RefCounted
const State = preload("res://scripts/combat/run_state.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const Store = preload("res://scripts/progression/run_store.gd")
const Campaign = preload("res://tests/test_campaign.gd")

static func quiet(seed_value: int = 1501):
	var state = State.new()
	state.start(seed_value)
	state.spawn_clock = 999.0
	state.shot_clock = 999.0
	state.stage_rules.swarm.chance = 0.0
	return state

static func run(scene, verify: Callable) -> void:
	var state = quiet()
	verify.call(state.stage_rules.scatter.interval == 12.0 and state._scatter_clock == 12.0, "Additional30 packs start after twelve active seconds")
	for index in range(4):
		var original_streams := [state.rng.state, state.growth.rng.state, state.gold_rng.state, state.encounter_rng.state]
		verify.call(state._spawn_scatter(), "Each rotating variant creates a complete additional pack")
		var pack: Array = state.enemies.filter(func(enemy): return enemy.scatter_group == index + 1)
		var variant: String = State.SCATTER_VARIANTS[index]
		verify.call(pack.size() == 30 and pack.all(func(enemy): return enemy.kind == "normal" and enemy.variant == variant), "Exactly thirty same-type actors, never ranged/elites/bosses: " + variant)
		var minimum := INF
		var bounds := Rect2(pack[0].p, Vector2.ZERO)
		for a in range(pack.size()):
			bounds = bounds.expand(pack[a].p)
			for b in range(a):
				minimum = minf(minimum, pack[a].p.distance_to(pack[b].p))
		verify.call(minimum > 36.0 and bounds.size.x > 250.0 and bounds.size.y > 250.0, "Pack spreads across both axes with visible separation: " + variant)
		verify.call(pack.all(func(enemy): return enemy.p.distance_to(state.player) >= 180.0), "Scatter placement keeps every actor outside player contact range")
		verify.call(original_streams == [state.rng.state, state.growth.rng.state, state.gold_rng.state, state.encounter_rng.state], "New packing never consumes an existing RNG stream")
	verify.call(state.enemies.filter(func(enemy): return enemy.variant == "heavy")[0].hp == 40 and state.enemies.filter(func(enemy): return enemy.variant == "fast")[0].speed == 68.0 * 1.7, "Additional heavy and fast keep the real wave archetype stats")
	var flying: Array = state.enemies.filter(func(enemy): return enemy.scatter_group == 4)
	var before: Array = flying.map(func(enemy): return enemy.p)
	state._move_enemies(0.05)
	verify.call(flying.all(func(enemy): return enemy.velocity == flying[0].velocity) and (flying[29].p - flying[0].p).is_equal_approx(before[29] - before[0]), "Scattered flight retains the existing straight moving formation")
	for seed_value in range(8):
		var edge = quiet(seed_value + 1510)
		edge.player = Vector2(30 if seed_value % 2 == 0 else 1770, 30 if seed_value % 4 < 2 else 1170)
		edge._spawn_scatter()
		verify.call(edge.enemies.size() == 30 and edge.enemies.all(func(enemy): return enemy.p.x > 0 and enemy.p.x < 1800 and enemy.p.y > 0 and enemy.p.y < 1200 and enemy.p.distance_to(edge.player) >= 180), "Corners preserve all30 distinct in-world approach positions")
	capacity_checks(verify)
	schedule_checks(verify)
	await restore_checks(scene, verify)
	verify.call(true, "Additional scatter pack suite reached its last integration check")

static func capacity_checks(verify: Callable) -> void:
	var state = quiet()
	for index in range(state.MAX_ENEMIES - 2):
		state.add_enemy(Vector2(100, 100))
	for index in range(3):
		state._spawn_scatter()
	verify.call(state.enemies.size() == 248 and state._ground_count() == 158, "Ninety added ground actors leave the old ground capacity untouched")
	verify.call(state._spawn_enemy() and state._ground_count() == 159, "Existing ordinary spawning still has its original reserved-boss limit")
	state.elapsed = 300.0
	state._boss_spawned = state._spawn_enemy("boss")
	verify.call(state._boss_spawned and state._ground_count() == 160 and Snapshot.valid(Snapshot.capture(state), state), "Boss still spawns at full old capacity alongside scatter packs")
	state._spawn_scatter()
	state._spawn_swarm()
	verify.call(state.enemies.filter(func(enemy): return enemy.variant == "flier").size() == 60 and Snapshot.valid(Snapshot.capture(state), state), "New scattered flight and original thirty-member flight coexist")
	verify.call(state.enemies.filter(func(enemy): return enemy.scatter_group > 0).all(func(enemy): return enemy.variant != "ranged"), "Only the additional packs exclude ranged actors")
	for key in ["tag", "size", "variant", "clock", "rng"]:
		var bad: Dictionary = Snapshot.capture(state)
		match key:
			"tag": bad.run.enemies[-1].scatter_group = -1
			"size":
				var extra: Dictionary = bad.run.enemies.filter(func(enemy): return enemy.scatter_group == 1)[0].duplicate(true)
				bad.run._enemy_serial += 1
				extra.id = bad.run._enemy_serial
				bad.run.enemies.append(extra)
			"variant": bad.run.enemies.filter(func(enemy): return enemy.scatter_group == 1)[0].variant = "ranged"
			"clock": bad.run._scatter_clock = -1.0
			"rng": bad.rng.pop_back()
		verify.call(not Snapshot.valid(bad, state), "Malformed scatter state is rejected: " + key)
	state = quiet()
	state.gold_drop_chance = 1.0
	state._spawn_scatter()
	var ids: Array = state.enemies.map(func(enemy): return enemy.id)
	for id in ids:
		state._damage_enemy(id, 10000)
	verify.call(state.kills == 30 and state.pickups.size() == 30 and state.gold_pickups.size() == 30, "All additional deaths use existing kills/XP/normal gold exactly once")
	state._damage_enemy(ids[0], 10000)
	verify.call(state.kills == 30 and state.gold_pickups.size() == 30, "Repeated death cannot duplicate added pack rewards")

static func schedule_checks(verify: Callable) -> void:
	var enabled = quiet(1550)
	var baseline = quiet(1550)
	enabled.spawn_clock = 0.2
	baseline.spawn_clock = 0.2
	baseline._scatter_clock = 999.0
	# Clear actors after each frame to measure scheduling without HP/capacity interference.
	var moments: Array = []
	var variants: Array = []
	var old_equal := true
	var ranged := 0
	for frame in range(7200):
		enabled.step(0.05, Vector2.ZERO)
		baseline.step(0.05, Vector2.ZERO)
		var old: Array = enabled.enemies.filter(func(enemy): return enemy.scatter_group == 0)
		old_equal = old_equal and old.size() == baseline.enemies.size()
		for index in range(mini(old.size(), baseline.enemies.size())):
			for key in ["kind", "variant", "hp", "speed", "p"]:
				old_equal = old_equal and old[index][key] == baseline.enemies[index][key]
			if old[index].variant == "ranged":
				ranged += 1
		var added: Array = enabled.enemies.filter(func(enemy): return enemy.scatter_group > 0)
		if not added.is_empty():
			moments.append(snappedf(enabled.elapsed, 0.01))
			variants.append(added[0].variant)
			old_equal = old_equal and added.size() == 30
		enabled.enemies.clear()
		baseline.enemies.clear()
	verify.call(old_equal and ranged > 0 and enabled.encounter_rng.state == baseline.encounter_rng.state and enabled.rng.state == baseline.rng.state, "Whole6-minute production schedule preserves original spawns, ranged distribution and RNG while adding30 each time")
	verify.call(moments.size() == 29 and moments[0] == 12.0 and moments[-1] == 348.0 and variants.slice(0, 4) == ["normal", "fast", "heavy", "flier"], "Production step adds29 packs/870 actors over6minutes at12-second intervals in four-type rotation")

static func restore_checks(scene, verify: Callable) -> void:
	var full = quiet()
	for index in range(full.MAX_ENEMIES - 1):
		full.add_enemy(Vector2(100, 100))
	for index in range(30):
		full._spawn_scatter()
	var store = Store.new()
	store.path = "user://scatter-limit-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".save"
	verify.call(full.enemies.size() == 1059 and not full._spawn_scatter(), "Finite stage budget bounds even an unthinned field without truncating any30 pack")
	verify.call(store.save_current(full) == OK and store.load_saved(full) == OK and store.pending.run.enemies.size() == 1059, "Maximum six-minute scatter population fits the existing checked atomic save file")
	store.discard()
	DirAccess.remove_absolute(store.path)
	var state = quiet()
	state._scatter_clock = 0.07
	for index in range(3):
		state._spawn_scatter()
	var restored = State.new()
	verify.call(Snapshot.restore(Snapshot.capture(state), restored), "Live scatter members, next type, remaining clock and fifth RNG restore")
	restored.set_paused(false)
	var same := true
	for frame in range(100):
		state.step(0.05, Vector2.UP)
		restored.step(0.05, Vector2.UP)
		same = same and Campaign.comparable(state) == Campaign.comparable(restored)
	verify.call(same and state._scatter_index == 4, "Recovery crosses the next scattered-flight event with identical positions/resources/RNG")
	var frozen: Dictionary = Campaign.comparable(state)
	state.set_paused(true)
	for frame in range(300):
		state.step(0.05, Vector2.ZERO)
	state.set_paused(false)
	verify.call(frozen == Campaign.comparable(state), "Paused packs and next event time do not advance")
	var legacy: Dictionary = Campaign.pre_scatter(Snapshot.capture(state))
	legacy.version = 6
	legacy.run.enemies = legacy.run.enemies.filter(func(enemy): return enemy.scatter_group == 0)
	for enemy in legacy.run.enemies:
		enemy.erase("scatter_group")
	var original: Dictionary = legacy.duplicate(true)
	verify.call(Snapshot.restore(legacy, restored) and restored._scatter_index == 0 and restored._scatter_clock == 12.0 and restored.magic.mana == state.magic.mana and legacy == original, "Published version6 keeps all prior resources and waits12seconds for its first new pack without replay or source mutation")
	# Existing UI/start route must consume the new production stage data.
	scene.begin_run()
	scene.simulation.spawn_clock = 999.0
	scene.simulation._scatter_clock = 0.0
	scene._physics_process(0.05)
	verify.call(scene.simulation.enemies.filter(func(enemy): return enemy.scatter_group == 1).size() == 30, "Actual start scene and physics path create the additional thirty actors")
