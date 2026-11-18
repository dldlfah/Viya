extends SceneTree
## REAL GDScript tests. Python source checks are not execution of these cases.
const RunState = preload("res://scripts/combat/run_state.gd")
const Cues = preload("res://scripts/combat/combat_cues.gd")
const AttackChecks = preload("res://tests/test_attack_visuals.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func quiet_state():
	var state = RunState.new()
	verify(state.start(42), "Production state starts")
	state.spawn_clock = 999.0
	state.shot_clock = 999.0
	return state

func of_kind(cues, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in cues.events:
		if event["kind"] == kind:
			result.append(event.duplicate(true))
	return result

func gameplay_snapshot(state) -> String:
	# Everything authoritative, deliberately excluding the presentation-only cues.
	return var_to_str([state.phase, state.player, state.facing, state.hp, state.max_hp,
		state.elapsed, state.kills, state.shots, state.shot_clock, state.spawn_clock,
		state.hurt_clock, state.enemies, state.bullets, state.pickups, state.effects,
		state.rng.state, state.growth.rng.state, state.growth.level, state.growth.xp,
		state.growth.pending, state.growth.offer, state.growth.owned, state.growth.ticket,
		state.growth.revision, state.skill_clocks, state.stats, state.magic.mana,
		state.magic.cooldown_left, state.magic.ticket, state.magic.casts,
		state.navigation_ticket, state.transition_action, state.result_summary(),
		state.gold_pickups, state.gold_collected, state.gold_rng.state,
		state.feedback.snapshot(state.hp, state.max_hp)])

func frozen_cues(state, description: String) -> void:
	var snapshot: String = var_to_str(state.cues.snapshot())
	state.step(0.05, Vector2.RIGHT)
	verify(snapshot == var_to_str(state.cues.snapshot()), description)

func _run() -> void:
	var cues = Cues.new()
	cues.record_hit(1, Vector2.ZERO, 0, false)
	cues.record_collected_xp(Vector2.ZERO, NAN)
	verify(cues.events.is_empty(), "Invalid visual events ignored")
	cues.record_hit(1, Vector2.ZERO, 4, false)
	cues.record_hit(1, Vector2.ONE, 3, true)
	verify(cues.events.size() == 1 and cues.events[0]["amount"] == 7.0 and cues.events[0]["critical"], "Nearby pellet impacts coalesce without a second crit roll")
	var copy: Dictionary = cues.snapshot()
	copy["events"][0]["amount"] = -99.0
	verify(cues.events[0]["amount"] == 7.0, "Snapshot cannot mutate visual state")
	cues.record_collected_xp(Vector2.ZERO, 5.6)
	cues.record_collected_xp(Vector2.ZERO, 5.6)
	verify(of_kind(cues, "xp").size() == 1 and is_equal_approx(of_kind(cues, "xp")[0]["amount"], 11.2), "Collected fractional XP coalesces without rounding its value")
	var visual_before: String = var_to_str(cues.snapshot())
	cues.advance(NAN)
	cues.advance(-1.0)
	verify(visual_before == var_to_str(cues.snapshot()), "Invalid time does not corrupt visual state")
	cues.advance(1.0)
	verify(cues.events.is_empty() and cues.flashes.is_empty(), "All expired events and flashes removed")
	for id in range(Cues.MAX_FLASHES + 30):
		cues.record_hit(id + 1, Vector2.ZERO, 1, false)
	verify(cues.events.size() == Cues.MAX_EVENTS and cues.flashes.size() == Cues.MAX_FLASHES, "Both arrays are bounded even under synthetic overload")
	cues.set_enabled(false)
	cues.record_kill(1, Vector2.ZERO)
	verify(cues.events.is_empty() and cues.flashes.is_empty(), "Disabling presentation clears visuals only")
	var state = quiet_state()
	state._damage_enemy(999, 30.0)
	state.add_pickup(state.player + Vector2(300, 0), 5.0)
	verify(state.cues.events.is_empty(), "Missing target and drop creation are not hit/collection events")
	state.add_enemy(state.player + Vector2(150, 0))
	var id: int = state.enemies[0]["id"]
	state._auto_fire()
	verify(state.cues.events.is_empty(), "Firing without impact produces no hit cue")
	state._damage_enemy(id, 7.0)
	verify(state.enemies[0]["hp"] == 13 and of_kind(state.cues, "hit")[0]["amount"] == 7.0, "Confirmed HP loss drives exact damage cue")
	verify(state.cues.flash_alpha(id) == 1.0, "Confirmed hit highlights the correct live enemy")
	state._damage_enemy(id, 100.0)
	verify(state.kills == 1 and of_kind(state.cues, "hit")[0]["amount"] == 20.0, "Overkill label counts remaining HP only, gameplay kill unchanged")
	verify(of_kind(state.cues, "kill").size() == 1 and of_kind(state.cues, "xp").is_empty(), "Real kill creates one death cue, not an XP award cue")
	verify(state.cues.flash_alpha(id) == 0.0, "Dead enemy flash removed")
	visual_before = var_to_str(state.cues.snapshot())
	state._damage_enemy(id, 100.0)
	verify(visual_before == var_to_str(state.cues.snapshot()) and state.kills == 1, "Removed target cannot emit a duplicate kill")
	state = quiet_state()
	state.stats["crit"] = 1.0
	state.add_enemy(state.player + Vector2(80, 0))
	state._damage_enemy(state.enemies[0]["id"], 3.0)
	verify(state.enemies[0]["hp"] == 14 and of_kind(state.cues, "hit")[0]["critical"], "Critical cue reuses the real doubled damage")
	# Actual projectile traversal, not just the internal damage helper.
	state = quiet_state()
	state.add_enemy(state.player + Vector2(120, 0))
	state._projectile(Vector2.RIGHT, 4.0, 1)
	for frame in range(12):
		state.step(1.0 / 60.0, Vector2.ZERO)
	verify(not of_kind(state.cues, "hit").is_empty() and state.enemies[0]["hp"] == 16, "Swept projectile collision feeds hit cues")
	state = quiet_state()
	state.stats["xp"] = 1.12
	state.add_pickup(state.player, 5.0)
	state.step(0.01, Vector2.ZERO)
	verify(is_equal_approx(state.growth.xp, 5.6) and is_equal_approx(of_kind(state.cues, "xp")[0]["amount"], 5.6), "Actual pickup and XP multiplier feed the same amount")
	state = quiet_state()
	state.add_pickup(state.player, 30.0)
	state.step(0.01, Vector2.ZERO)
	verify(state.phase == RunState.Phase.CHOOSING and of_kind(state.cues, "xp").size() == 1, "Level-up-triggering pickup still gets its collection cue")
	frozen_cues(state, "Choosing freezes cue lifetime")
	var ticket: int = state.growth.ticket
	var offer: Array[String] = state.growth.offer.duplicate()
	state.set_paused(true)
	frozen_cues(state, "Settings freeze cue lifetime")
	state.set_paused(false)
	verify(state.request_transition("leave", state.navigation_ticket), "Confirmation enters from pending choice")
	frozen_cues(state, "Confirmation freezes cue lifetime")
	verify(state.cancel_transition(state.navigation_ticket), "Confirmation cancel succeeds")
	verify(state.growth.offer == offer and state.growth.ticket == ticket, "Cancel preserves exact growth offer")
	verify(state.select_skill(offer[0], ticket), "Choice returns to running")
	state.step(0.05, Vector2.ZERO)
	verify(float(of_kind(state.cues, "xp")[0]["life"]) < Cues.XP_SECONDS, "Cue lifetime resumes with simulation time")
	verify(state.request_transition("leave", state.navigation_ticket), "Request abandonment")
	verify(state.confirm_transition(state.navigation_ticket), "Confirmed abandonment succeeds")
	frozen_cues(state, "Abandonment freezes cue lifetime")
	verify(state.return_to_ready(state.navigation_ticket), "Result returns to ready")
	frozen_cues(state, "Ready does not advance previous combat cues")
	state.start(42)
	verify(state.cues.events.is_empty() and state.cues.flashes.is_empty(), "Restart clears every combat cue")
	state.cues.record_collected_xp(state.player, 1.0)
	state.damage_player(1000)
	frozen_cues(state, "Defeat freezes cue lifetime")
	# Large real burst: cosmetic caps must never suppress kills or XP drops.
	state = quiet_state()
	for n in range(RunState.MAX_ENEMIES):
		state.add_enemy(state.player + Vector2.from_angle(float(n) * 0.2) * 100.0)
	var magic_ticket: int = state.magic.ticket
	verify(state.cast_ultimate(magic_ticket), "Real area magic accepted")
	verify(state.kills == RunState.MAX_ENEMIES and state.pickups.size() == RunState.MAX_ENEMIES, "Cosmetic overflow loses neither kills nor XP drops")
	verify(state.cues.events.size() <= Cues.MAX_EVENTS and state.cues.flashes.is_empty(), "Area-kill visual storage remains bounded")
	visual_before = var_to_str(state.cues.snapshot())
	verify(not state.cast_ultimate(magic_ticket) and visual_before == var_to_str(state.cues.snapshot()), "Rejected duplicate magic emits no combat cues")
	# Differential test: identical authoritative state with visuals enabled/disabled.
	var a = quiet_state()
	var b = quiet_state()
	b.cues.set_enabled(false)
	for current in [a, b]:
		current.stats["crit"] = 0.35
		current.add_enemy(current.player + Vector2(100, 0))
		current._damage_enemy(current.enemies[0]["id"], 5.0)
		current.cast_ultimate(current.magic.ticket)
		current.add_pickup(current.player, 30.0)
	var identical: bool = true
	for frame in range(180):
		a.step(1.0 / 60.0, Vector2.RIGHT)
		b.step(1.0 / 60.0, Vector2.RIGHT)
		identical = identical and gameplay_snapshot(a) == gameplay_snapshot(b)
		if a.phase == RunState.Phase.CHOOSING:
			var chosen: String = a.growth.offer[0]
			a.select_skill(chosen, a.growth.ticket)
			b.select_skill(chosen, b.growth.ticket)
	verify(identical, "Visual switch preserves damage, XP, RNG streams, offers, tickets and timers over 180 production steps")
	# Active F5 scene: same RunState/View and the existing read-only detail modal.
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.start_button.pressed.emit()
	scene.simulation.spawn_clock = 999.0
	scene.simulation.add_enemy(scene.simulation.player + Vector2(100, 0))
	scene.simulation._damage_enemy(scene.simulation.enemies[0]["id"], 5.0)
	verify(scene.view.simulation == scene.simulation and not scene.view.simulation.cues.events.is_empty(), "Active F5 View reads the same accepted combat events")
	visual_before = var_to_str(scene.simulation.cues.snapshot())
	scene.slot_buttons[0].pressed.emit()
	scene._physics_process(0.05)
	verify(scene._detail_open and visual_before == var_to_str(scene.simulation.cues.snapshot()), "Actual skill detail pauses combat cues")
	scene.detail_return_button.pressed.emit()
	scene.view.queue_redraw()
	await process_frame
	scene.begin_run()
	verify(scene.simulation.cues.events.is_empty(), "Active UI restart clears the presentation state")
	await AttackChecks.run(scene, verify)
	await preload("res://tests/test_gold_settings.gd").run(scene, verify)
	scene.queue_free()
	await process_frame
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "status": "PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
