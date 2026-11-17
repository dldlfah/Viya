extends SceneTree
## Runs the production GDScript state and actual F5 UI. No Python gameplay substitute.
const RunState = preload("res://scripts/combat/run_state.gd")
const Growth = preload("res://scripts/progression/growth_state.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func quiet_state():
	var state = RunState.new()
	state.start(42)
	state.spawn_clock = 999.0
	return state

func force_choice(state, id: String) -> bool:
	# Synthetic offer is test setup only; application still uses production validation.
	state.growth.pending = 1
	state.growth.offer.assign([id])
	state.growth.ticket += 1
	state.phase = RunState.Phase.CHOOSING
	return state.select_skill(id, state.growth.ticket)

func _run() -> void:
	var state = quiet_state()
	verify(state.growth.pool.size() == 18, "Exactly 18 candidate types")
	verify(state.growth.catalog.validate_pool(state.growth.pool, "viya"), "8+1+8+1 schema and non-resistance passives")
	verify(state.growth.owned == {"common_rifle": 1}, "Existing starting rifle occupies one slot")
	verify(not state.start(99, "missing"), "Unknown character rejected, not silently changed to Viya")
	verify(state.growth.character_id == "viya", "Rejected character leaves previous identity intact")
	var unique_ok := true
	var repeatable_ok := true
	for seed_value in range(1, 65):
		var a = Growth.new()
		var b = Growth.new()
		a.reset("viya", seed_value)
		b.reset("viya", seed_value)
		a.gain(a.threshold())
		b.gain(b.threshold())
		a.open_offer()
		b.open_offer()
		var distinct: Dictionary = {}
		for id in a.offer:
			distinct[id] = true
		unique_ok = unique_ok and a.offer.size() == 3 and distinct.size() == 3
		repeatable_ok = repeatable_ok and a.offer == b.offer
	verify(unique_ok, "64 seeds: three distinct IDs, no duplicated card")
	verify(repeatable_ok, "64 seeds: same seed makes same initial offer")
	# A synthetic fixture tests character-driven substitution, not a new character product.
	var hero: Dictionary = state.growth.catalog.characters["viya"].duplicate(true)
	for entry in hero["skills"]:
		entry["owner"] = "fixture_hero"
		entry["id"] = "fixture_" + str(entry["effect"])
	hero["active_magic"]["owner"] = "fixture_hero"
	hero["active_magic"]["upgrade_skill_id"] = "fixture_ultimate"
	state.growth.catalog.characters["fixture_hero"] = hero
	verify(state.start(3, "fixture_hero"), "Synthetic character can supply its two own candidates")
	verify(state.growth.definition("viya_sigil").is_empty() and state.growth.definition("viya_ultimate").is_empty(), "Viya-specific candidates absent from other character")
	verify(not state.growth.definition("fixture_sigil").is_empty(), "Replacement special skill comes from selected character data")
	state = quiet_state()
	state.add_enemy(state.player + Vector2(150, 0))
	for frame in range(100):
		state.step(1.0 / 60.0, Vector2.ZERO)
	verify(state.kills == 1 and state.pickups.size() <= 1, "Real shooting kill produces XP pickup")
	# Collect a second drop; collecting, not spawning, grants XP.
	state.pickups.clear()
	state.add_pickup(state.player + Vector2(300, 0), state.growth.threshold())
	state.step(0.01, Vector2.ZERO)
	verify(state.growth.level == 1, "Remote drop does not award XP immediately")
	state.player = state.pickups[0]["p"]
	state.step(0.01, Vector2.ZERO)
	verify(state.phase == RunState.Phase.CHOOSING and state.growth.level == 2, "Pickup opens real level-up choice state")
	var old_ticket: int = state.growth.ticket
	var old_offer: Array[String] = state.growth.offer.duplicate()
	var before: String = JSON.stringify([state.player, state.elapsed, state.shot_clock,
		state.spawn_clock, state.hurt_clock, state.enemies, state.bullets, state.pickups, state.skill_clocks])
	state.step(0.05, Vector2.RIGHT)
	var after: String = JSON.stringify([state.player, state.elapsed, state.shot_clock,
		state.spawn_clock, state.hurt_clock, state.enemies, state.bullets, state.pickups, state.skill_clocks])
	verify(before == after, "Choice freezes all simulation/timer collections")
	verify(not state.damage_player(1000), "No damage during choice")
	state.set_paused(true)
	verify(not state.select_skill(old_offer[0], old_ticket), "Cannot apply a card while settings are open")
	state.step(0.05, Vector2.RIGHT)
	state.set_paused(false)
	verify(state.phase == RunState.Phase.CHOOSING and state.growth.offer == old_offer and state.growth.ticket == old_ticket, "Pause/resume preserves original offer without reroll")
	verify(not state.select_skill("not_a_skill", old_ticket), "Injected unknown choice rejected")
	verify(state.select_skill(old_offer[0], old_ticket), "One offered skill is applied")
	var snapshot: Dictionary = state.growth.owned.duplicate(true)
	verify(not state.select_skill(old_offer[0], old_ticket) and state.growth.owned == snapshot, "Repeated pressed event cannot apply twice")
	state = quiet_state()
	state.grant_xp(144.0)
	verify(state.growth.level == 4 and state.growth.pending == 3 and is_zero_approx(state.growth.xp), "Three exact thresholds queue three level choices")
	for i in range(3):
		var ticket: int = state.growth.ticket
		var id: String = state.growth.offer[0]
		verify(state.select_skill(id, ticket), "Queued choice applies once")
		verify(not state.select_skill(id, ticket), "Old ticket blocked even when another choice is pending")
	verify(state.phase == RunState.Phase.RUNNING and state.growth.pending == 0, "All queued levels return to combat")
	# Restart invalidates tickets and clears all per-run upgrades/XP/pickups.
	state.grant_xp(100.0)
	old_ticket = state.growth.ticket
	state.start(7)
	state.grant_xp(state.growth.threshold())
	verify(not state.select_skill(state.growth.offer[0], old_ticket), "Prior-run callback cannot select new-run card")
	state.start(7)
	verify(state.growth.level == 1 and state.growth.pending == 0 and state.growth.xp == 0.0 and state.growth.owned == {"common_rifle": 1}, "Restart clears growth state")
	verify(state.pickups.is_empty() and state.skill_clocks.is_empty() and int(state.stats["ultimate"]) == 0, "Restart clears pickup/attack cooldown/ultimate enhancement state")
	# Keep 18 kinds distinct from prototype four-slot capacity.
	force_choice(state, "common_scatter")
	force_choice(state, "common_lance")
	force_choice(state, "common_grenade")
	verify(state.growth.row_entries("attack").size() == 4, "Four attack slots including base rifle")
	verify(not state.growth.eligible().has("common_pulse") and state.growth.eligible().has("common_rifle"), "Full slots allow upgrades but not fifth attack")
	state.growth.owned.clear()
	for entry in state.growth.pool:
		state.growth.owned[entry["id"]] = int(entry["max_level"])
	state.growth.owned["common_rifle"] = 4
	state.growth.owned["passive_power"] = 4
	state.growth.pending = 1
	state.growth.offer.clear()
	state.growth.open_offer()
	verify(state.growth.offer.size() == 2, "Two remaining candidates show two, never duplicate to fill three")
	state.growth.owned["common_rifle"] = 5
	state.growth.owned["passive_power"] = 5
	state.growth.offer.clear()
	state.growth.open_offer()
	state.phase = RunState.Phase.CHOOSING
	verify(state.growth.offer.is_empty(), "Exhausted pool contains no invented extra skill")
	verify(state.acknowledge_exhausted(state.growth.ticket) and state.phase == RunState.Phase.RUNNING, "Exhaustion can resume without deadlock")
	# Every offensive prototype produces actual damage, not only an icon.
	var pool: Array[Dictionary] = state.growth.pool.duplicate(true)
	for entry in pool:
		if entry["row"] != "attack":
			continue
		var attack_state = quiet_state()
		verify(force_choice(attack_state, entry["id"]), "Acquire/upgrade offensive prototype " + str(entry["id"]))
		if entry["effect"] != "rifle":
			attack_state.shot_clock = 999.0
		attack_state.add_enemy(attack_state.player + Vector2(75, 0))
		for frame in range(25):
			attack_state.step(1.0 / 60.0, Vector2.ZERO)
		verify(attack_state.kills > 0 or int(attack_state.enemies[0]["hp"]) < 20, "Offensive prototype deals damage: " + str(entry["id"]))
	# Each passive reaches its actual state owner.
	state = quiet_state()
	force_choice(state, "passive_power")
	state.add_enemy(state.player + Vector2(200, 0))
	state._damage_enemy(state.enemies[0]["id"], 10.0)
	verify(state.enemies[0]["hp"] == 8, "Power passive modifies real damage")
	force_choice(state, "passive_haste")
	state.shot_clock = 0.0
	state._auto_fire()
	verify(state.shot_clock < RunState.SHOT_INTERVAL, "Haste modifies real shot cooldown")
	state = quiet_state()
	state.hp = 80
	force_choice(state, "passive_vitality")
	verify(state.max_hp == 120 and state.hp == 100, "Vitality increases cap and heals only the added cap")
	force_choice(state, "passive_stride")
	var origin: Vector2 = state.player
	state.step(0.05, Vector2.RIGHT)
	verify(state.player.distance_to(origin) > RunState.PLAYER_SPEED * 0.05, "Stride modifies actual movement")
	force_choice(state, "passive_magnet")
	state.add_pickup(state.player + Vector2(95, 0))
	state.step(0.01, Vector2.ZERO)
	verify(state.pickups[0]["p"].distance_to(state.player) < 95.0, "Magnet pulls previously out-of-range pickup")
	force_choice(state, "passive_learning")
	state.pickups.clear()
	state.add_pickup(state.player, state.growth.threshold())
	state.step(0.01, Vector2.ZERO)
	verify(state.growth.level == 2 and absf(state.growth.xp - 3.6) < 0.001, "Learning applies XP multiplier without discarding fractional XP")
	state = quiet_state()
	force_choice(state, "passive_precision")
	verify(is_equal_approx(state.stats["crit"], 0.04), "Precision reaches crit probability")
	force_choice(state, "passive_recovery")
	state.hp = 90
	for frame in range(120):
		state.step(1.0 / 60.0, Vector2.ZERO)
	verify(state.hp > 90 and state.hp <= state.max_hp, "Recovery heals actual HP over time")
	force_choice(state, "viya_ultimate")
	verify(state.stats["ultimate"] == 1 and state.growth.row_entries("passive").size() == 2, "Ultimate enhancement is separate from passive slots")
	state = quiet_state()
	for i in range(RunState.MAX_PICKUPS + 5):
		state.add_pickup(Vector2.ZERO)
	var reward_sum := 0.0
	for pickup in state.pickups:
		reward_sum += float(pickup["value"])
	verify(state.pickups.size() == RunState.MAX_PICKUPS and reward_sum == float(RunState.MAX_PICKUPS + 5) * 5.0, "Pickup cap merges value without losing XP")
	# Exercise actual scene buttons and status rows, not a substitute test interface.
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.start_button.pressed.emit()
	scene.simulation.spawn_clock = 999.0
	scene.simulation.grant_xp(scene.simulation.growth.threshold())
	scene._physics_process(0.0)
	verify(scene.choice_buttons.size() == 3 and scene.overlay.visible and not scene.movement.enabled, "F5 displays three cards and disables movement")
	var chosen_id: String = scene.simulation.growth.offer[0]
	var chosen_ticket: int = scene.simulation.growth.ticket
	scene.pause_game()
	scene.resume_button.pressed.emit()
	verify(scene.simulation.growth.ticket == chosen_ticket and scene.choice_buttons.size() == 3, "Actual settings resume restores level-up cards")
	scene.choice_buttons[0].pressed.emit()
	verify(scene.simulation.growth.skill_level(chosen_id) >= 1 and not scene.overlay.visible, "Actual card button applies upgrade and closes overlay")
	verify(scene._slot_revision == scene.simulation.growth.revision, "Actual two-row HUD updates to selected growth revision")
	verify(not scene.magic_button.disabled, "Configured ultimate is usable after growth choice")
	scene.simulation.grant_xp(100.0)
	scene._physics_process(0.0)
	scene.begin_run()
	verify(scene.simulation.growth.owned == {"common_rifle": 1} and scene.simulation.growth.pending == 0, "UI restart clears queued choices and owned upgrades")
	scene.queue_free()
	await process_frame
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "status": "PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
