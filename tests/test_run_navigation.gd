extends SceneTree
## Executes the production RunState and F5 scene. Written tests are not PASS evidence.
const RunState = preload("res://scripts/combat/run_state.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func quiet_state():
	var state = RunState.new()
	verify(state.start(42), "Valid test run starts")
	state.spawn_clock = 999.0
	return state

func gameplay_snapshot(state) -> String:
	# Navigation/magic request counters intentionally change; gameplay does not.
	return JSON.stringify([state.player, state.facing, state.hp, state.max_hp,
		state.elapsed, state.kills, state.shots, state.shot_clock, state.spawn_clock,
		state.hurt_clock, state.enemies, state.bullets, state.pickups, state.effects,
		state.skill_clocks, state.stats, state.rng.state,
		state.growth.level, state.growth.xp, state.growth.pending,
		state.growth.owned, state.growth.offer, state.growth.ticket,
		state.growth.rng.state, state.magic.mana, state.magic.cooldown_left,
		state.magic.casts, state.feedback.clocks])

func named_button(scene, title: String) -> Button:
	for child in scene.dialog_body.get_children():
		if child is Button and child.text == title:
			return child as Button
	return null

func press_named(scene, title: String) -> void:
	var button := named_button(scene, title)
	verify(is_instance_valid(button), "Actual menu has button: " + title)
	if is_instance_valid(button):
		button.pressed.emit()

func _run() -> void:
	var state = quiet_state()
	state.hp = 77
	state.magic.mana = 46.0
	state.magic.cooldown_left = 3.5
	state.add_enemy(state.player + Vector2(400, 0))
	state.add_pickup(state.player + Vector2(100, 0))
	state.feedback.trigger("hurt")
	var snapshot: String = gameplay_snapshot(state)
	var original_ticket: int = state.navigation_ticket
	verify(not state.request_transition("unknown", original_ticket), "Unknown intent rejected")
	verify(not state.request_transition("restart", original_ticket - 1), "Stale intent rejected")
	verify(state.request_transition("restart", original_ticket), "Restart requests confirmation")
	verify(state.phase == RunState.Phase.PAUSED, "Confirmation pauses the same state")
	verify(snapshot == gameplay_snapshot(state), "Opening confirmation does not reset any gameplay data")
	var confirm_ticket: int = state.navigation_ticket
	verify(not state.request_transition("leave", confirm_ticket), "Repeated request cannot overwrite intent")
	state.set_paused(false)
	verify(state.phase == RunState.Phase.PAUSED, "Ordinary Continue cannot bypass confirmation")
	state.step(0.05, Vector2.RIGHT)
	verify(snapshot == gameplay_snapshot(state), "Confirmation freezes timers, resources, feedback and actors")
	verify(not state.damage_player(10), "Confirmation rejects damage")
	verify(not state.cast_ultimate(state.magic.ticket), "Confirmation rejects magic")
	verify(state.cancel_transition(confirm_ticket), "Cancel accepted once")
	verify(state.phase == RunState.Phase.RUNNING and snapshot == gameplay_snapshot(state), "Cancel resumes unchanged running state")
	verify(not state.cancel_transition(confirm_ticket) and not state.confirm_transition(confirm_ticket), "Both old confirmation callbacks rejected")

	state = quiet_state()
	state.grant_xp(144.0)
	verify(state.growth.pending == 3, "Real three-level queue prepared")
	var choice_ticket: int = state.growth.ticket
	var offer: Array[String] = state.growth.offer.duplicate()
	snapshot = gameplay_snapshot(state)
	state.set_paused(true)
	verify(state.request_transition("leave", state.navigation_ticket), "Leave request from settings over a level choice")
	confirm_ticket = state.navigation_ticket
	verify(not state.select_skill(offer[0], choice_ticket), "Hidden card cannot apply during confirmation")
	verify(state.cancel_transition(confirm_ticket), "Cancel leave restores underlying state")
	verify(state.phase == RunState.Phase.CHOOSING, "Underlying state is CHOOSING, not RUNNING")
	verify(snapshot == gameplay_snapshot(state), "All queued XP/skills/candidates/RNG preserved on cancel")
	verify(state.request_transition("leave", state.navigation_ticket), "Can reopen confirmation after cancel")
	confirm_ticket = state.navigation_ticket
	verify(state.interrupt_transition(), "App interruption cancels pending intent")
	verify(state.phase == RunState.Phase.PAUSED and state.transition_action.is_empty(), "Interruption stays paused; no automatic resume")
	verify(not state.confirm_transition(confirm_ticket), "Pre-interruption confirm is stale")
	state.set_paused(false)
	verify(state.phase == RunState.Phase.CHOOSING and snapshot == gameplay_snapshot(state), "Explicit Continue restores the same offer and pending levels")

	verify(state.request_transition("leave", state.navigation_ticket), "New leave intent accepted")
	confirm_ticket = state.navigation_ticket
	var hp_before: int = state.hp
	verify(state.confirm_transition(confirm_ticket), "Confirmed leave completes")
	verify(state.phase == RunState.Phase.ABANDONED and state.hp == hp_before, "Abandonment does not fake lethal damage")
	var result: Dictionary = state.result_summary()
	verify(result["ended"] and result["outcome"] == "abandoned", "Result explicitly records abandonment")
	verify(state.growth.pending == 0 and state.growth.offer.is_empty() and state.growth.ticket > choice_ticket, "Terminal run invalidates pending selection callbacks")
	verify(not state.confirm_transition(confirm_ticket), "Repeated leave confirmation is rejected")
	snapshot = gameplay_snapshot(state)
	state.step(0.05, Vector2.RIGHT)
	verify(snapshot == gameplay_snapshot(state), "Abandoned result freezes gameplay")
	result["kills"] = -999
	verify(state.result_summary()["kills"] != -999, "Result caller receives a copy")
	var result_ticket: int = state.navigation_ticket
	verify(state.return_to_ready(result_ticket), "Result can return to READY")
	verify(state.phase == RunState.Phase.READY and state.result_summary()["outcome"] == "abandoned", "Lobby retains frozen outcome without resuming")
	verify(not state.return_to_ready(result_ticket), "Old lobby callback rejected")
	state.step(0.05, Vector2.RIGHT)
	verify(snapshot == gameplay_snapshot(state), "Lobby does not advance prior-run timers")
	verify(state.start(7), "Explicit new start accepted")
	verify(not state.result_summary()["ended"] and state.growth.owned == {"common_rifle": 1}, "New run clears result and old upgrades")
	verify(state.hp == 100 and state.magic.mana == 100.0 and state.magic.casts == 0, "Restart restores only initial per-run resources")

	state.hp = 42
	state.grant_xp(30.0)
	verify(state.request_transition("restart", state.navigation_ticket), "Restart request at a choice")
	confirm_ticket = state.navigation_ticket
	verify(state.confirm_transition(confirm_ticket), "Confirmed restart starts exactly one new run")
	var new_navigation: int = state.navigation_ticket
	verify(state.phase == RunState.Phase.RUNNING and state.growth.level == 1 and state.hp == 100, "Confirmed restart clears per-run state")
	verify(not state.confirm_transition(confirm_ticket) and state.navigation_ticket == new_navigation, "Double confirm cannot restart twice")
	state.hurt_clock = 0.0
	verify(state.damage_player(1000), "Real lethal damage accepted")
	verify(state.phase == RunState.Phase.DEFEAT and state.result_summary()["outcome"] == "defeat", "Real defeat remains distinct from abandonment")
	verify(state.return_to_ready(state.navigation_ticket), "Defeat result also returns to READY")

	# Production F5 scene, not a replacement mock interface.
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.new_run_ruleset = "legacy" # Preserve this historical regression; GAME018 separately tests the production default.
	scene.run_store.path = "user://native-test_run_navigation-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".save"
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	var lobby_ticket: int = scene.simulation.navigation_ticket
	var lobby_revision: int = scene._menu_revision
	preload("res://tests/test_campaign.gd").depart(scene)
	scene.simulation.spawn_clock = 999.0
	verify(scene.simulation.phase == RunState.Phase.RUNNING and not scene.overlay.visible, "Actual lobby start works")
	scene._start_from_menu(lobby_ticket, lobby_revision)
	verify(scene.simulation.phase == RunState.Phase.RUNNING and not scene.overlay.visible, "Stale lobby click cannot interrupt a running game")
	scene.simulation.hp = 67
	scene.pause_game()
	press_named(scene, "새 전투 시작")
	verify(is_instance_valid(scene.confirm_button) and scene.simulation.hp == 67, "Actual restart button opens confirmation, not reset")
	scene.cancel_button.pressed.emit()
	verify(scene.simulation.hp == 67 and scene.simulation.phase == RunState.Phase.RUNNING, "Actual cancel resumes unchanged game")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	scene._unhandled_key_input(esc)
	verify(scene.simulation.phase == RunState.Phase.PAUSED, "Escape after cancel still opens settings")
	scene.resume_button.pressed.emit()

	scene.simulation.grant_xp(30.0)
	scene._physics_process(0.0)
	choice_ticket = scene.simulation.growth.ticket
	offer = scene.simulation.growth.offer.duplicate()
	scene.pause_game()
	scene.leave_button.pressed.emit()
	verify(scene._modal_kind == "confirm", "Leave from settings opens confirmation")
	scene._unhandled_key_input(esc)
	verify(scene.simulation.phase == RunState.Phase.CHOOSING and scene.simulation.growth.ticket == choice_ticket and scene.simulation.growth.offer == offer, "Escape cancellation restores identical level choices")
	scene.pause_game()
	scene.leave_button.pressed.emit()
	confirm_ticket = scene.simulation.navigation_ticket
	var old_revision: int = scene._menu_revision
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	verify(scene.simulation.phase == RunState.Phase.PAUSED and scene.simulation.transition_action.is_empty() and scene._modal_kind == "paused", "Focus loss requires explicit Continue")
	scene._confirm_transition(confirm_ticket, old_revision)
	verify(scene.simulation.phase == RunState.Phase.PAUSED, "Stale pre-focus confirmation cannot abandon")
	scene.resume_button.pressed.emit()
	verify(scene.simulation.growth.offer == offer and scene.simulation.growth.ticket == choice_ticket, "Focus return does not reroll choice")

	scene.pause_game()
	scene.leave_button.pressed.emit()
	scene.confirm_button.pressed.emit()
	verify(scene.simulation.phase == RunState.Phase.ABANDONED and scene.overlay.visible, "Actual confirmed leave shows a terminal result")
	verify(scene.dialog_body.get_child(0).text == "전투 포기", "Abandonment heading is not defeat")
	verify(not scene.movement.enabled and scene.magic_button.disabled, "Result blocks movement and magic")
	result_ticket = scene.simulation.navigation_ticket
	old_revision = scene._menu_revision
	scene.lobby_button.pressed.emit()
	verify(scene.simulation.phase == RunState.Phase.READY and scene.overlay.visible, "Actual result-to-lobby button works")
	preload("res://tests/test_campaign.gd").depart(scene)
	scene._return_to_lobby(result_ticket, old_revision)
	verify(scene.simulation.phase == RunState.Phase.RUNNING and not scene.overlay.visible, "Old result callback cannot send new run to lobby")
	scene.pause_game()
	press_named(scene, "새 전투 시작")
	confirm_ticket = scene.simulation.navigation_ticket
	old_revision = scene._menu_revision
	scene.confirm_button.pressed.emit()
	new_navigation = scene.simulation.navigation_ticket
	scene._confirm_transition(confirm_ticket, old_revision)
	verify(scene.simulation.phase == RunState.Phase.RUNNING and scene.simulation.navigation_ticket == new_navigation, "Actual restart confirmation applied only once")
	verify(scene.simulation.growth.pool.size() == 18 and scene.simulation.growth.threshold() == 30.0, "18 candidates and XP multiplier unchanged")
	scene.simulation.damage_player(1000)
	scene._physics_process(0.0)
	verify(scene.dialog_body.get_child(0).text == "전투 종료 · 패배" and is_instance_valid(scene.lobby_button), "Real defeat menu has separate heading and lobby route")
	# Keep the full dense regression in a separate existing engine suite budget.
	await preload("res://tests/test_combat_performance.gd").run(scene, verify)
	preload("res://tests/test_enemy_shape_cache.gd").run(scene, verify)
	await preload("res://tests/test_flier_expiry.gd").run(scene, verify)
	preload("res://tests/test_loot_attraction.gd").run(scene, verify)
	preload("res://tests/test_route_queries.gd").run(scene, verify)
	await preload("res://tests/test_purge_feedback.gd").run(scene, verify)
	await preload("res://tests/test_portrait_reactions.gd").run(scene, verify)
	await preload("res://tests/test_oblique_stage.gd").run(scene, verify)
	await preload("res://tests/test_stage_access_reset.gd").run(scene, verify)
	await preload("res://tests/test_character_pilot.gd").run(scene, verify)
	await preload("res://tests/test_viya_presentation.gd").run(scene, verify)
	scene.queue_free()
	await process_frame
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "status": "PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
