extends RefCounted
## Called by the existing native HUD suite. This is NOT a Python mock of the game.
const RunState = preload("res://scripts/combat/run_state.gd")
const Overview = preload("res://scripts/ui/growth_overview.gd")

static func _gameplay(state) -> String:
	return JSON.stringify([state.player, state.hp, state.max_hp, state.elapsed,
		state.kills, state.shots, state.enemies, state.bullets, state.pickups,
		state.growth.owned, state.growth.level, state.growth.xp, state.growth.pending,
		state.growth.offer, state.growth.ticket, state.rng.state, state.growth.rng.state,
		state.magic.mana, state.magic.cooldown_left, state.magic.casts,
		state.cues.snapshot(), state.feedback.snapshot(state.hp, state.max_hp)])

static func _callback(button: Button, verify: Callable) -> Callable:
	var links: Array[Dictionary] = button.get_signal_connection_list("pressed")
	verify.call(links.size() == 1, "Overview button has one real guarded callback")
	return links[0]["callable"] if links.size() == 1 else Callable()

static func run(scene, verify: Callable) -> void:
	scene.begin_run()
	scene.simulation.spawn_clock = 999.0
	var before: String = _gameplay(scene.simulation)
	var data: Dictionary = Overview.capture(scene.simulation)
	verify.call(data["attack"].size() == 1 and data["passive"].is_empty(), "Overview reflects actual starting loadout")
	verify.call(data["magic_rank"] == 0 and not data["magic"].is_empty(), "Unupgraded active magic is shown outside skill slots")
	verify.call(data["attack_cap"] == scene.simulation.growth.ATTACK_CAP and data["xp_required"] == 30.0, "Overview reads the real caps and triple XP threshold")
	verify.call(Overview.sections(data).size() == 5 and before == _gameplay(scene.simulation), "Formatting is read-only and consumes no gameplay RNG")
	data["attack"][0]["level"] = 99
	data["stats"]["power"] = 99.0
	data["magic"]["damage"] = 999.0
	verify.call(before == _gameplay(scene.simulation) and scene.simulation.magic.profile(0)["damage"] != 999.0, "Snapshot edits cannot write back to gameplay")
	scene.pause_game()
	var stale_open: Callable = _callback(scene.overview_button, verify)
	if not stale_open.is_valid():
		return
	stale_open.call()
	verify.call(scene._overview_open and scene.simulation.phase == RunState.Phase.PAUSED, "Settings opens the existing paused read-only overview")
	var stale_close: Callable = _callback(scene.overview_return_button, verify)
	if not stale_close.is_valid():
		return
	before = _gameplay(scene.simulation)
	scene._physics_process(0.05)
	scene.magic_button.pressed.emit()
	verify.call(before == _gameplay(scene.simulation) and not scene.movement.enabled, "Overview freezes combat, cues, XP, mana and input")
	stale_close.call()
	verify.call(not scene._overview_open and scene.overlay.visible and scene.simulation.phase == RunState.Phase.PAUSED, "Closing settings overview does not silently resume combat")
	scene.overview_button.pressed.emit()
	var revision: int = scene._menu_revision
	stale_close.call()
	stale_open.call()
	verify.call(scene._overview_open and scene._menu_revision == revision, "Old overview callbacks cannot affect a newly opened overview")
	scene._close_growth_overview(scene.simulation.navigation_ticket - 1, scene._menu_revision)
	verify.call(scene._overview_open, "Wrong navigation ticket cannot close the overview")
	scene._close_growth_overview(scene.simulation.navigation_ticket, scene._menu_revision - 1)
	verify.call(scene._overview_open, "Wrong menu revision cannot close the overview")
	scene.overview_return_button.pressed.emit()
	scene.resume_button.pressed.emit()
	verify.call(scene.simulation.phase == RunState.Phase.RUNNING, "Existing Continue still resumes combat")
	scene.simulation.grant_xp(30.0)
	scene._physics_process(0.0)
	var choice_ticket: int = scene.simulation.growth.ticket
	var offer: Array[String] = scene.simulation.growth.offer.duplicate()
	var pending: int = scene.simulation.growth.pending
	var choice_rng: int = scene.simulation.growth.rng.state
	scene.overview_button.pressed.emit()
	verify.call(scene._overview_open and scene.simulation.phase == RunState.Phase.PAUSED, "Choice menu overview pauses without selecting a candidate")
	var old_choice_close: Callable = _callback(scene.overview_return_button, verify)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	scene._unhandled_key_input(escape)
	verify.call(scene.simulation.phase == RunState.Phase.CHOOSING and scene.choice_buttons.size() == 3, "Esc returns to exactly three choice cards")
	verify.call(choice_ticket == scene.simulation.growth.ticket and offer == scene.simulation.growth.offer and pending == scene.simulation.growth.pending and choice_rng == scene.simulation.growth.rng.state, "Overview preserves candidate identity, ticket, pending choices and RNG")
	scene.overview_button.pressed.emit()
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	if old_choice_close.is_valid():
		old_choice_close.call()
	verify.call(not scene._overview_open and scene.simulation.phase == RunState.Phase.PAUSED and scene.overlay.visible, "Interrupted overview requires explicit Continue")
	scene.resume_button.pressed.emit()
	verify.call(scene.simulation.phase == RunState.Phase.CHOOSING and scene.simulation.growth.offer == offer, "Continue restores the unchanged choice after interruption")
	scene.choice_buttons[0].pressed.emit()
	verify.call(scene.simulation.phase == RunState.Phase.RUNNING, "Existing upgrade selection still applies once")
	scene.pause_game()
	scene.leave_button.pressed.emit()
	scene.confirm_button.pressed.emit()
	var final_data: Dictionary = scene._final_growth.duplicate(true)
	verify.call(final_data["summary"]["outcome"] == "abandoned" and final_data["level"] == 2, "Confirmed abandonment captures the final build with the right outcome")
	scene.overview_button.pressed.emit()
	scene.overview_return_button.pressed.emit()
	verify.call(scene.simulation.phase == RunState.Phase.ABANDONED and scene._final_growth == final_data, "Result overview keeps the ended state and frozen build")
	scene.lobby_button.pressed.emit()
	verify.call(scene.simulation.phase == RunState.Phase.READY and is_instance_valid(scene.overview_button), "Lobby exposes the previous build without starting a run")
	scene.overview_button.pressed.emit()
	scene._unhandled_key_input(escape)
	verify.call(scene.simulation.phase == RunState.Phase.READY and scene._final_growth == final_data, "Lobby overview returns to READY and keeps final data")
	scene.start_button.pressed.emit()
	stale_open.call()
	stale_close.call()
	verify.call(scene.simulation.phase == RunState.Phase.RUNNING and scene._final_growth.is_empty() and not scene._overview_open, "New deployment clears the result build and rejects old callbacks")
	scene.simulation.hurt_clock = 0.0
	scene.simulation.damage_player(9999)
	scene._physics_process(0.0)
	verify.call(scene._final_growth["summary"]["outcome"] == "defeat", "Lethal defeat captures a separate final outcome")
	scene.overview_button.pressed.emit()
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	verify.call(scene.simulation.phase == RunState.Phase.DEFEAT and not scene._overview_open, "Focus loss in result overview does not resume or relabel defeat")
