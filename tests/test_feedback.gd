extends SceneTree
## Requires the actual Godot engine. Static source checks are NOT these tests.
const RunState = preload("res://scripts/combat/run_state.gd")
const Feedback = preload("res://scripts/combat/feedback_state.gd")
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
	verify(state.start(42), "Production character data starts a run")
	state.spawn_clock = 999.0
	return state

func advance_run(state, seconds: float) -> void:
	for frame in range(int(ceil(seconds / 0.05))):
		state.step(0.05, Vector2.ZERO)

func _run() -> void:
	var feedback = Feedback.new()
	verify(feedback.current(100, 100) == "normal", "Normal at full HP")
	verify(feedback.current(30, 100) == "low_hp", "30 percent boundary is low")
	verify(feedback.current(31, 100) == "normal", "Above boundary is normal")
	verify(feedback.current(36, 120) == "low_hp", "Threshold uses current maximum HP")
	verify(not feedback.is_low(0, 100), "Defeat is not a live low-HP state")
	verify(not feedback.trigger("unknown"), "Unknown feedback rejected")
	verify(feedback.level_up(5), "First level-up ticket accepted")
	verify(not feedback.level_up(5) and not feedback.level_up(4), "Same or stale level-up event rejected")
	feedback.trigger("magic")
	feedback.trigger("hurt")
	verify(feedback.current(25, 100) == "hurt", "Hurt has priority over magic and growth")
	verify(feedback.snapshot(25, 100)["low_hp"], "Low-HP warning remains independent")
	var original: Dictionary = feedback.clocks.duplicate(true)
	feedback.advance(10.0, false)
	feedback.advance(-1.0, true)
	feedback.advance(INF, true)
	feedback.advance(NAN, true)
	verify(feedback.clocks == original, "Stopped and invalid steps never spend reaction time")
	feedback.advance(float(Feedback.DURATIONS["hurt"]), true)
	verify(feedback.current(25, 100) == "magic", "Hurt returns to pending magic")
	verify(is_equal_approx(feedback.clocks["magic"], Feedback.DURATIONS["magic"]), "Covered reaction keeps full visible duration")
	feedback.advance(float(Feedback.DURATIONS["magic"]), true)
	verify(feedback.current(25, 100) == "levelup", "Magic returns to pending level-up")
	feedback.advance(float(Feedback.DURATIONS["levelup"]), true)
	verify(feedback.current(25, 100) == "low_hp", "Transient returns to current persistent health state")
	verify(feedback.current(50, 100) == "normal", "Healing clears low-HP reaction")
	var exported: Dictionary = feedback.snapshot(100, 100)
	exported["label"] = "mutated"
	verify(feedback.snapshot(100, 100)["label"] != "mutated", "Presentation copies cannot change static rules")
	feedback.trigger("magic")
	feedback.finish()
	verify(feedback.current(100, 100) == "defeat" and not feedback.trigger("hurt"), "Defeat overrides and rejects later events")
	feedback.reset()
	verify(feedback.current(100, 100) == "normal" and feedback.level_up(1), "Restart clears reaction state and previous ticket")
	feedback.reset()
	for event in range(100):
		feedback.trigger("hurt")
	verify(feedback.clocks.size() == 3, "Repeated events keep a bounded three-kind store")

	# Real state owner, not a duplicate Python simulation.
	var state = quiet_state()
	verify(state.damage_player(76), "Accepted damage reduces HP")
	verify(state.feedback.current(state.hp, state.max_hp) == "hurt", "Accepted damage triggers reaction")
	original = state.feedback.clocks.duplicate(true)
	verify(not state.damage_player(1) and state.feedback.clocks == original, "Invulnerability rejection cannot restart reaction")
	advance_run(state, 0.60)
	verify(state.feedback.current(state.hp, state.max_hp) == "low_hp", "Damage reaction expires into low-HP state")
	var old_magic_ticket: int = state.magic.ticket
	verify(state.cast_ultimate(old_magic_ticket), "Valid active magic triggers real cast")
	original = state.feedback.clocks.duplicate(true)
	verify(state.feedback.current(state.hp, state.max_hp) == "magic", "Successful magic triggers its own reaction")
	verify(not state.cast_ultimate(old_magic_ticket) and state.feedback.clocks == original, "Rejected duplicate magic cannot retrigger feedback")
	state.grant_xp(state.growth.threshold())
	verify(state.phase == RunState.Phase.CHOOSING, "Actual XP opens choice")
	var old_offer: Array[String] = state.growth.offer.duplicate()
	var old_ticket: int = state.growth.ticket
	var frozen: String = JSON.stringify([state.elapsed, state.magic.mana,
		state.magic.cooldown_left, state.feedback.clocks, state.effects])
	state.step(0.05, Vector2.RIGHT)
	verify(frozen == JSON.stringify([state.elapsed, state.magic.mana,
		state.magic.cooldown_left, state.feedback.clocks, state.effects]), "Choice freezes combat, MP, effects and reaction clocks")
	state.set_paused(true)
	state.step(0.05, Vector2.RIGHT)
	verify(frozen == JSON.stringify([state.elapsed, state.magic.mana,
		state.magic.cooldown_left, state.feedback.clocks, state.effects]), "Settings freezes reaction and resource state")
	verify(not state.cast_ultimate(state.magic.ticket), "Paused magic rejected")
	state.set_paused(false)
	verify(state.growth.ticket == old_ticket and state.growth.offer == old_offer, "Resume preserves choice ticket and candidates")
	verify(state.select_skill(old_offer[0], old_ticket), "Production selection resumes pending reactions")
	original = state.feedback.clocks.duplicate(true)
	verify(not state.select_skill(old_offer[0], old_ticket) and state.feedback.clocks == original, "Stale selection does not restart feedback")
	advance_run(state, 3.0)
	verify(state.feedback.current(state.hp, state.max_hp) in ["normal", "low_hp"], "Reactions drain and return to current health")
	state.hurt_clock = 0.0
	verify(state.damage_player(10000), "Lethal damage accepted")
	verify(state.feedback.current(state.hp, state.max_hp) == "defeat", "Lethal damage does not leave a happy/cast reaction")
	var summary: Dictionary = state.result_summary()
	state.step(0.05, Vector2.RIGHT)
	verify(summary == state.result_summary() and summary["ended"], "Result state stays frozen")
	summary["kills"] = 99999
	verify(state.result_summary()["kills"] != 99999, "Result value cannot mutate the run")
	verify(state.start(9), "Restart after defeat")
	verify(state.feedback.current(state.hp, state.max_hp) == "normal", "Restart clears defeat and all transient reactions")
	verify(state.magic.casts == 0 and state.growth.level == 1 and state.growth.threshold() == 30.0, "Restart retains original XP rule and resets cast count")

	# Actual F5 scene: cast kills -> pickups -> three choices -> feedback -> death -> restart.
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.new_run_ruleset = "legacy" # Preserve this historical regression; GAME018 separately tests the production default.
	scene.run_store.path = "user://native-test_feedback-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".save"
	root.add_child(scene)
	scene.set_physics_process(false) # Deterministic test stepping; production still uses physics.
	await process_frame
	await process_frame
	verify(is_instance_valid(scene.feedback_panel), "Real HUD instantiates placeholder reaction panel")
	verify(scene.feedback_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Reaction panel cannot steal touch")
	preload("res://tests/test_campaign.gd").depart(scene)
	scene.simulation.spawn_clock = 999.0
	for i in range(6):
		scene.simulation.add_enemy(scene.simulation.player + Vector2(30.0 + i * 10.0, 0.0))
	scene.magic_button.pressed.emit()
	verify(scene.feedback_panel.state_key == "magic" and scene.simulation.kills == 6, "Button cast damages actual enemies and immediately updates reaction")
	for frame in range(12):
		scene._physics_process(0.05)
	verify(scene.simulation.phase == RunState.Phase.CHOOSING and scene.choice_buttons.size() == 3, "Actual cast drops 30 XP and reaches the unchanged threshold")
	verify(is_instance_valid(scene.feedback_overlay_label), "Reaction text remains readable on choice overlay")
	original = scene.simulation.feedback.clocks.duplicate(true)
	scene._magic_touch_id = 9
	scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	scene._physics_process(0.05)
	verify(scene.simulation.phase == RunState.Phase.PAUSED and not scene.movement.enabled and scene._magic_touch_id == -1, "App interruption clears movement/magic input")
	verify(scene.simulation.feedback.clocks == original, "App interruption preserves feedback time")
	scene.resume_button.pressed.emit()
	scene.choice_buttons[0].pressed.emit()
	advance_run(scene.simulation, 3.0)
	scene._physics_process(0.0)
	verify(scene.feedback_panel.state_key == "normal", "Scene reaction returns after growth")
	scene.simulation.hurt_clock = 0.0
	scene.simulation.damage_player(scene.simulation.hp - int(scene.simulation.max_hp * 0.24))
	scene._physics_process(0.0)
	verify(scene.feedback_panel.state_key == "hurt" and not scene.feedback_panel.danger_text.text.is_empty(), "HUD displays hurt and low-HP warning together")
	advance_run(scene.simulation, 0.60)
	scene._physics_process(0.0)
	verify(scene.feedback_panel.state_key == "low_hp", "HUD returns to low HP after hurt")
	scene.simulation.hurt_clock = 0.0
	scene.simulation.damage_player(10000)
	scene._physics_process(0.0)
	verify(scene.overlay.visible and scene.feedback_panel.state_key == "defeat", "Scene defeat opens result and clears transient reaction")
	verify(scene.result_summary_label.text.contains("고유 마법 1회"), "Result uses actual active-magic count")
	preload("res://tests/test_campaign.gd").depart(scene)
	verify(scene.feedback_panel.state_key == "normal" and not scene.overlay.visible, "Result restart clears UI and feedback")
	verify(scene.simulation.magic.casts == 0 and scene.simulation.growth.owned == {"common_rifle": 1}, "New run clears previous results and skill selections")
	scene.queue_free()
	await process_frame
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "status": "PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
