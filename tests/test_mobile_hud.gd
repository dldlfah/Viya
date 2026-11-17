extends SceneTree
## Run with the actual Godot engine. These tests are NOT a Python layout surrogate.
const Layout = preload("res://scripts/ui/hud_layout.gd")
const RunState = preload("res://scripts/combat/run_state.gd")
const MoveInput = preload("res://scripts/ui/move_input.gd")
const OverviewChecks = preload("res://tests/test_growth_overview.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func contains(outer: Rect2, inner: Rect2) -> bool:
	return inner.has_area() and outer.grow(1.0).encloses(inner)

func _touch(id: int, at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = at
	event.pressed = pressed
	return event


func _detail_close_request(scene) -> Callable:
	var links: Array[Dictionary] = scene.detail_return_button.get_signal_connection_list("pressed")
	verify(links.size() == 1, "Detail close has exactly one guarded callback")
	return links[0]["callable"] if links.size() == 1 else Callable()

func _test_stale_detail_close(scene) -> void:
	# Capture the actual button callback, not a substitute copy of the guard.
	scene.begin_run()
	scene.simulation.spawn_clock = 999.0
	scene._open_skill_detail("common_rifle")
	var old_close: Callable = _detail_close_request(scene)
	if not old_close.is_valid():
		return
	old_close.call()
	verify(scene.simulation.phase == RunState.Phase.RUNNING, "Current detail callback resumes combat")
	scene._open_skill_detail("common_rifle")
	var before: String = JSON.stringify([scene.simulation.elapsed, scene.simulation.hp,
		scene.simulation.magic.mana, scene.simulation.magic.cooldown_left,
		scene.simulation.growth.owned, scene.simulation.growth.offer,
		scene.simulation.growth.ticket, scene.simulation.navigation_ticket, scene._menu_revision])
	old_close.call()
	verify(scene._detail_open and scene.overlay.visible and scene.simulation.phase == RunState.Phase.PAUSED,
		"An earlier detail callback cannot close a newer detail")
	verify(before == JSON.stringify([scene.simulation.elapsed, scene.simulation.hp,
		scene.simulation.magic.mana, scene.simulation.magic.cooldown_left,
		scene.simulation.growth.owned, scene.simulation.growth.offer,
		scene.simulation.growth.ticket, scene.simulation.navigation_ticket, scene._menu_revision]),
		"Rejected detail close has no gameplay or navigation side effects")
	# Test ticket and UI revision independently, not just their combined mismatch.
	scene._close_skill_detail(scene.simulation.navigation_ticket, scene._menu_revision - 1)
	verify(scene._detail_open, "Wrong UI revision is rejected even with current run ticket")
	scene._close_skill_detail(scene.simulation.navigation_ticket - 1, scene._menu_revision)
	verify(scene._detail_open, "Wrong run ticket is rejected even with current UI revision")
	scene.detail_return_button.pressed.emit()
	verify(scene.simulation.phase == RunState.Phase.RUNNING and not scene.overlay.visible,
		"Current detail close still returns to combat")
	# A stale close must not reveal a newer level-up modal or reroll its candidates.
	scene.simulation.grant_xp(30.0)
	scene._physics_process(0.0)
	var choice_ticket: int = scene.simulation.growth.ticket
	var candidates: Array[String] = scene.simulation.growth.offer.duplicate()
	scene._open_skill_detail("common_rifle")
	old_close.call()
	verify(scene._detail_open and scene.simulation.phase == RunState.Phase.PAUSED,
		"Old combat detail cannot close a detail opened over level-up")
	var interrupted_close: Callable = _detail_close_request(scene)
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	if interrupted_close.is_valid():
		interrupted_close.call()
	verify(scene.simulation.phase == RunState.Phase.PAUSED and scene.overlay.visible and not scene._detail_open,
		"Interrupted detail callback cannot bypass explicit Continue")
	scene.resume_button.pressed.emit()
	verify(scene.simulation.phase == RunState.Phase.CHOOSING
		and scene.simulation.growth.ticket == choice_ticket
		and scene.simulation.growth.offer == candidates,
		"Continue after interrupted detail restores the identical level-up offer")
	# Previous-run callbacks cannot close the next run's detail.
	scene.begin_run()
	scene.simulation.spawn_clock = 999.0
	scene._open_skill_detail("common_rifle")
	old_close.call()
	verify(scene._detail_open and scene.simulation.phase == RunState.Phase.PAUSED,
		"Previous-run detail callback cannot resume a new run")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	scene._unhandled_key_input(escape)
	verify(not scene._detail_open and scene.simulation.phase == RunState.Phase.RUNNING,
		"Esc passes current identifiers and closes the current detail")

func _run() -> void:
	for size in [Vector2(853, 384), Vector2(960, 540), Vector2(1280, 720), Vector2(1600, 720), Vector2(1920, 1080)]:
		for inset in [0.0, 36.0]:
			var safe := Rect2(Vector2(inset, 0), Vector2(size.x - inset * 2, size.y - 12))
			var data: Dictionary = Layout.build(size, safe)
			for key in ["top", "battle", "bottom", "feedback", "resources", "skills", "support", "magic", "modal"]:
				verify(contains(safe, data[key]), "Safe-area containment: %s %s" % [size, key])
			verify(contains(data["battle"], data["move"]), "Movement is a subset of the battle area")
			verify(not data["move"].intersects(data["magic"]), "Movement and magic never overlap")
			verify(not data["battle"].intersects(data["bottom"]), "Battle and bottom HUD do not overlap")
			var panels := ["feedback", "resources", "skills", "support", "magic"]
			for a in range(panels.size()):
				for b in range(a + 1, panels.size()):
					verify(not data[panels[a]].intersects(data[panels[b]]), "HUD groups are disjoint: %s/%s" % [panels[a], panels[b]])
	# Transformed input coordinates: a Control may not start at viewport origin.
	var stick = MoveInput.new()
	root.add_child(stick)
	stick.position = Vector2(40, 25)
	stick.size = Vector2(1280, 720)
	stick.set_interaction_rect(Rect2(20, 80, 300, 400))
	stick.set_enabled(true)
	verify(stick.accepts(Vector2(90, 160)), "Input converts viewport coordinates to local coordinates")
	verify(not stick.accepts(Vector2(90, 60)), "Header cannot capture a movement finger")
	stick._input(_touch(2, Vector2(90, 160), true))
	verify(stick.touch_id == 2, "Movement finger is captured inside its layout rectangle")
	stick._input(_touch(5, Vector2(1100, 640), true))
	verify(stick.touch_id == 2, "Second finger on HUD cannot steal movement")
	stick.set_interaction_rect(Rect2(20, 80, 310, 400))
	verify(stick.touch_id == -1 and stick.axis == Vector2.ZERO, "Resize releases captured movement")
	stick.queue_free()
	# Load the production F5 scene, which inherits the existing combat main.
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false) # Deterministic checks drive the real simulation explicitly.
	scene.start_button.pressed.emit()
	scene.simulation.spawn_clock = 999.0
	verify(scene.slot_buttons.size() == 8, "Two rows retain four read-only detail buttons each")
	verify(scene.simulation.growth.pool.size() == 18 and scene.simulation.growth.threshold() == 30.0, "18 candidates and triple XP unchanged")
	for size in [Vector2(960, 540), Vector2(1280, 720), Vector2(1600, 720)]:
		scene.root_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		scene.root_ui.size = size
		scene.safe_area_override = Rect2(Vector2(28, 0), size - Vector2(56, 12))
		scene._apply_layout()
		await process_frame
		await process_frame
		var allowed: Rect2 = scene.layout_data["safe"]
		for control in [scene._header, scene.feedback_panel, scene._resources, scene._skills, scene._support, scene.magic_button, scene.view]:
			verify(contains(allowed, control.get_rect()), "Actual Control fits after container layout: " + str(control.name))
		verify(scene.view.get_rect() == scene.layout_data["battle"], "Battle view follows shared rectangle")
		verify(scene.movement.interaction_rect == scene.layout_data["move"], "Joystick uses shared rectangle, not old constants")
	# Long names: tapping a HUD slot must never acquire/upgrade/cast anything.
	var owned_before: Dictionary = scene.simulation.growth.owned.duplicate(true)
	var casts_before: int = scene.simulation.magic.casts
	var level_before: int = scene.simulation.growth.level
	scene.slot_buttons[0].pressed.emit()
	verify(scene._detail_open and scene.simulation.phase == RunState.Phase.PAUSED, "Owned skill tap opens paused read-only detail")
	verify(scene.overlay.visible and not scene.movement.enabled, "Detail blocks world input")
	var frozen := JSON.stringify([scene.simulation.elapsed, scene.simulation.magic.mana, scene.simulation.magic.cooldown_left])
	scene._physics_process(0.05)
	verify(frozen == JSON.stringify([scene.simulation.elapsed, scene.simulation.magic.mana, scene.simulation.magic.cooldown_left]), "Detail pauses gameplay resources and time")
	scene.magic_button.pressed.emit()
	verify(scene.simulation.magic.casts == casts_before, "Detail cannot accidentally cast magic")
	scene.detail_return_button.pressed.emit()
	verify(not scene.overlay.visible and scene.simulation.phase == RunState.Phase.RUNNING, "Detail close restores running state")
	verify(scene.simulation.growth.owned == owned_before and scene.simulation.growth.level == level_before, "Read-only detail cannot alter skill levels")
	# Preserve a real choice while resizing or temporarily inspecting a held skill.
	scene.simulation.grant_xp(30.0)
	scene._physics_process(0.0)
	var ticket: int = scene.simulation.growth.ticket
	var offer: Array[String] = scene.simulation.growth.offer.duplicate()
	var choice_id: String = offer[0]
	scene.root_ui.size = Vector2(853, 384)
	scene.safe_area_override = Rect2()
	scene._apply_layout()
	await process_frame
	await process_frame
	verify(scene._choice_grid.columns == 1 and scene.choice_buttons.size() == 3, "Compact modal scrolls three cards without dropping a choice")
	verify(ticket == scene.simulation.growth.ticket and offer == scene.simulation.growth.offer, "Resize does not reroll or invalidate the skill offer")
	scene._open_skill_detail("common_rifle")
	verify(scene._detail_open and not scene.simulation.select_skill(choice_id, ticket), "Stale card callbacks are blocked while reading a detail")
	scene.detail_return_button.pressed.emit()
	verify(scene.simulation.phase == RunState.Phase.CHOOSING and scene.simulation.growth.ticket == ticket and scene.simulation.growth.offer == offer, "Detail restores the identical choice ticket and candidates")
	scene.choice_buttons[0].pressed.emit()
	var after_choice: Dictionary = scene.simulation.growth.owned.duplicate(true)
	scene._choose_skill(choice_id, ticket)
	verify(scene.simulation.growth.owned == after_choice, "Responsive cards preserve duplicate-selection rejection")
	# Two distinct fingers: movement + magic, followed by resize cancellation.
	scene.begin_run()
	scene.simulation.spawn_clock = 999.0
	scene.root_ui.size = Vector2(1280, 720)
	scene._apply_layout()
	await process_frame
	await process_frame
	var move_center: Vector2 = scene.layout_data["move"].get_center()
	scene.movement._input(_touch(3, move_center, true))
	var magic_center: Vector2 = scene.magic_button.get_global_rect().get_center()
	scene._input(_touch(7, magic_center, true))
	verify(scene.movement.touch_id == 3 and scene.simulation.magic.casts == 1, "Movement and magic use separate native touch owners")
	scene._input(_touch(7, magic_center, true))
	verify(scene.simulation.magic.casts == 1, "Repeated second-finger event cannot cast twice")
	scene.root_ui.size = Vector2(1600, 720)
	scene._apply_layout()
	verify(scene._magic_touch_id == -1 and scene.movement.touch_id == -1, "Resize cancels both native input owners")
	# App interruption from details must not auto-resume combat.
	scene._open_skill_detail("common_rifle")
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	verify(not scene._detail_open and scene.simulation.phase == RunState.Phase.PAUSED and scene.overlay.visible, "Focus loss replaces detail with an explicit pause screen")
	scene.resume_button.pressed.emit()
	verify(scene.simulation.phase == RunState.Phase.RUNNING, "Explicit Continue resumes after detail interruption")
	_test_stale_detail_close(scene)
	OverviewChecks.run(scene, verify)
	scene.begin_run()
	verify(not scene._detail_open and scene.simulation.growth.owned == {"common_rifle": 1}, "Restart clears detail state and per-run upgrades")
	scene.queue_free()
	await process_frame
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "status": "PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)