extends SceneTree
## Engine tests, not a Python simulation. Run with Godot --headless --script.
const RunState = preload("res://scripts/combat/run_state.gd")
const MoveInput = preload("res://scripts/ui/move_input.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func _run() -> void:
	var state = RunState.new()
	verify(state.phase == RunState.Phase.READY, "Starts in ready state")
	state.start(7)
	state.spawn_clock = 999.0
	var initial: Vector2 = state.player
	state.step(0.05, Vector2(1, 1))
	verify(absf(state.player.distance_to(initial) - RunState.PLAYER_SPEED * 0.05) < 0.01, "Diagonal speed normalized")
	state.player = Vector2.ONE * 31
	state.step(0.05, Vector2(-1, -1))
	verify(state.player.x >= 30.0 and state.player.y >= 30.0, "Arena boundaries")
	state.start(8)
	state.spawn_clock = 999.0
	state.add_enemy(state.player + Vector2(190, 0))
	for frame in range(120):
		state.step(1.0 / 60.0, Vector2.ZERO)
	verify(state.kills == 1 and state.shots >= 2, "Automatic fire kills a target")
	verify(state.enemies.is_empty(), "Dead enemy removed")
	verify(state.bullets.size() <= RunState.MAX_BULLETS, "Bullet bound")
	state.start(9)
	state.spawn_clock = 999.0
	state.add_enemy(state.player)
	state.step(0.01, Vector2.ZERO)
	verify(state.hp == 88, "Contact damage applies")
	state.step(0.01, Vector2.ZERO)
	verify(state.hp == 88, "Contact invulnerability prevents frame-by-frame damage")
	state.set_paused(true)
	var frozen_time: float = state.elapsed
	var frozen_position: Vector2 = state.player
	var frozen_damage: float = state.hurt_clock
	state.step(0.05, Vector2.RIGHT)
	verify(state.elapsed == frozen_time and state.player == frozen_position and state.hurt_clock == frozen_damage, "Pause freezes simulation and timers")
	state.set_paused(false)
	state.hurt_clock = 0.0
	state.damage_player(500)
	verify(state.hp == 0 and state.phase == RunState.Phase.DEFEAT, "Lethal damage ends run")
	state.step(0.05, Vector2.RIGHT)
	verify(state.player == frozen_position, "No simulation after defeat")
	state.start(10)
	verify(state.hp == 100 and state.kills == 0 and state.shots == 0 and state.enemies.is_empty() and state.bullets.is_empty(), "Restart clears run state")
	for number in range(RunState.MAX_ENEMIES + 20):
		state.add_enemy(Vector2(500, 300))
	verify(state.enemies.size() == RunState.MAX_ENEMIES, "Enemy bound enforced")
	var stick = MoveInput.new()
	root.add_child(stick)
	stick.size = Vector2(1280, 720)
	stick.set_enabled(true)
	var first := InputEventScreenTouch.new()
	first.index = 5
	first.pressed = true
	first.position = Vector2(100, 380)
	stick._input(first)
	verify(stick.touch_id == 5, "First movement finger captured")
	var second := InputEventScreenTouch.new()
	second.index = 9
	second.pressed = true
	second.position = Vector2(1100, 600)
	stick._input(second)
	verify(stick.touch_id == 5, "Second finger cannot steal movement")
	var drag := InputEventScreenDrag.new()
	drag.index = 5
	drag.position = Vector2(200, 380)
	stick._input(drag)
	verify(stick.axis.x > 0.95 and stick.axis.length() <= 1.001, "Touch movement normalized")
	first.pressed = false
	first.canceled = true
	stick._input(first)
	verify(stick.touch_id == -1 and stick.axis == Vector2.ZERO, "Canceled touch releases movement")
	stick.queue_free()
	# Instantiate the actual F5 scene, not a replacement test UI.
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.run_store.path = "user://native-test_combat_foundation-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".save"
	root.add_child(scene)
	await process_frame
	verify(is_instance_valid(scene.start_button), "F5 scene creates a start button")
	scene.start_button.pressed.emit()
	verify(scene.simulation.phase == RunState.Phase.RUNNING and not scene.overlay.visible, "Start button is wired")
	scene.pause_game()
	verify(scene.simulation.phase == RunState.Phase.PAUSED and scene.overlay.visible, "Pause UI is wired")
	scene.resume_button.pressed.emit()
	verify(scene.simulation.phase == RunState.Phase.RUNNING and not scene.overlay.visible, "Resume button is wired")
	scene.simulation.hurt_clock = 0.0
	scene.simulation.damage_player(1000)
	scene._physics_process(0.016)
	verify(scene.overlay.visible, "Defeat opens result panel")
	scene.start_button.pressed.emit()
	verify(scene.simulation.hp == 100 and scene.simulation.enemies.is_empty(), "Result restart is wired")
	scene.queue_free()
	await process_frame
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "status": "PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
