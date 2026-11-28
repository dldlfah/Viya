extends SceneTree
## Run with -- --plan-b-preview. A windowed run also verifies the SubViewport.
const Campaign = preload("res://tests/test_campaign.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const RunState = preload("res://scripts/combat/run_state.gd")
const Scenery = preload("res://scripts/combat/oblique_scenery.gd")

var failures: Array[String] = []
var count := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	count += 1
	if not condition:
		failures.append(message)

func touch(at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func drag(at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	if not OS.get_cmdline_user_args().has("--plan-b-preview"):
		push_error("Run this test with -- --plan-b-preview and isolated user data")
		quit(1)
		return
	var folder := "user://plan_b_preview"
	if DirAccess.dir_exists_absolute(folder):
		push_error("Use a fresh user data directory for the Plan B QA sortie")
		quit(1)
		return
	var windowed := DisplayServer.get_name() != "headless"
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	await process_frame
	ui.safe_area_override = Rect2(0, 6, 1280, 702)
	ui._apply_layout()
	Campaign.depart(ui)
	var state = ui.simulation
	var preview = ui.view.high_renderer.plan_b_actor
	verify(state.uses_plan_b_aiming() and state.phase == RunState.Phase.RUNNING, "Real main scene launches the preview campaign")
	verify(ui.run_store.path.begins_with(folder) and ui.gold_progress.path.begins_with(folder) and ui.settings_path.begins_with(folder), "Preview persistence uses its own profile")
	if preview == null or preview.camera == null:
		verify(false, "Imported preview scene has its rig, camera, animations and muzzle")
		finish()
		return
	var camera_pose: Transform3D = preview.camera.transform
	var skeleton: Skeleton3D = preview.rig.find_children("*", "Skeleton3D", true, false).front()
	var leg := skeleton.find_bone("leg_l")
	var spine := skeleton.find_bone("spine")

	const DT := 1.0 / 60.0
	var initial: Dictionary = Snapshot.capture(state)
	verify(not initial.run.has("plan_b_preview") and not initial.run.has("plan_b_rifle_shots"), "Preview flags and presentation counters are transient")
	var restored = RunState.new()
	verify(Snapshot.restore(initial, restored) and not restored.uses_plan_b_aiming(), "Regular save restore remains compatible and opt-in")
	ui.pause_game()
	var paused_shots: int = state.shots
	ui._physics_process(DT)
	verify(ui.overlay.visible and state.shots == paused_shots, "A paused run does not fire")
	ui.resume_game()
	verify(not ui.overlay.visible and state.phase == RunState.Phase.RUNNING, "Preview pauses and resumes through actual overlays")
	state.enemies.clear()
	state.spawn_clock = 999.0
	state._swarm_clock = 999.0
	state._scatter_clock = 999.0

	var origin: Vector2 = ui.movement.interaction_rect.get_center()
	touch(origin, true)
	drag(origin + Vector2.RIGHT * ui.movement.stick_radius)
	ui._physics_process(DT)
	var east: Vector2 = ui.view.input_direction(Vector2.RIGHT)
	verify(state.facing.dot(east) > 0.9999 and state.plan_b_rifle_shots == 1 and not state.bullets.is_empty(), "Touch movement aims and automatically fires into empty space")
	verify(not state.bullets.is_empty() and state.bullets[-1].direction.dot(east) > 0.9999, "Projectile takes the same direction as the stick")
	touch(origin, false)
	state.add_enemy(state.player - east * 110.0)
	state.shot_clock = 0
	ui._physics_process(DT)
	verify(state.facing.dot(east) > 0.9999 and state.plan_b_rifle_shots == 2 and state.bullets[-1].direction.dot(east) > 0.9999, "Stationary fire retains direction with an enemy behind")

	var targeted: Dictionary = state.attack_profile("gun_lance", 1, 1.0)
	state.WeaponModules.fire(state, targeted)
	verify(state.facing.dot(east) > 0.9999 and state.bullets[-1].direction.dot(-east) > 0.94, "Independent targeted attack does not turn the player's aim")

	state.growth.owned["gun_rifle"] = 2
	state.shot_clock = 0.0
	ui._physics_process(DT)
	var before_turn: int = state.plan_b_rifle_shots
	touch(origin, true)
	drag(origin + Vector2.UP * ui.movement.stick_radius)
	var moved_leg := false
	var aimed_torso := false
	for index in range(10):
		ui._physics_process(DT)
		if preview.shot_age > 0.02 and preview.shot_age < 0.13:
			moved_leg = moved_leg or absf(skeleton.get_bone_pose_rotation(leg).dot(skeleton.get_bone_rest(leg).basis.get_rotation_quaternion())) < 0.9999
			aimed_torso = aimed_torso or absf(skeleton.get_bone_pose_rotation(spine).dot(skeleton.get_bone_rest(spine).basis.get_rotation_quaternion())) < 0.9999
	touch(origin, false)
	var north: Vector2 = ui.view.input_direction(Vector2.UP)
	var turned_bullet: bool = state.bullets.any(func(bullet):
		return bullet.source == "gun_rifle" and bullet.direction.dot(north) > 0.9999)
	verify(state.facing.dot(north) > 0.9999 and state.plan_b_rifle_shots > before_turn and turned_bullet, "A delayed burst uses the direction at its launch tick after a turn")
	verify(moved_leg and aimed_torso, "Firing layers the upper motion over moving legs")
	verify(preview.camera.transform.is_equal_approx(camera_pose), "The rig uses a fixed camera")

	var feet: Vector2 = ui.view.world_to_screen(state.player)
	var bullet_at_muzzle := {"p": state.player, "direction": state.facing, "age": 0.0, "speed": 920.0}
	var shown: Dictionary = preview.projectile(ui.view, bullet_at_muzzle)
	verify(Vector2(shown.p).distance_to(feet + preview.muzzle_offset(state.facing)) < 0.001 and shown.direction.dot(Vector2.UP) > 0.9999, "First-frame tracer goes from the projected muzzle in the real screen direction")

	if windowed:
		for frame in range(3):
			ui.view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
		var tip: Vector2 = (preview.camera.unproject_position(preview.muzzle.global_position) - preview.camera.unproject_position(Vector3.ZERO)) * preview.DISPLAY_SCALE
		verify(tip.distance_to(preview.muzzle_offset(state.facing)) < 0.05, "Tracer origin agrees with the imported 3D attachment")
		var barrel_2d: Vector2 = preview.camera.unproject_position(preview.muzzle.global_position + preview.rig.global_basis.z) - preview.camera.unproject_position(preview.muzzle.global_position)
		verify(barrel_2d.normalized().dot(shown.direction) > 0.9999, "Visible barrel and tracer agree under the fixed camera")
		var pixels: Image = preview.get_texture().get_image()
		var visible := 0
		for y in range(pixels.get_height()):
			for x in range(pixels.get_width()):
				if pixels.get_pixel(x, y).a > 0.5:
					visible += 1
		verify(visible > 200 and visible < pixels.get_width() * pixels.get_height() / 2.0, "Actual 3D render has visible geometry and transparent terrain cutout")
		var image := root.get_texture().get_image()
		image.save_png(folder.path_join("plan_b_battle.png"))

	var wall_found := false
	for solid: Rect2 in state.map_space.solids:
		var wall_center := solid.get_center()
		var near := Vector2(solid.position.x - 55.0, wall_center.y)
		var far := Vector2(solid.end.x + 50.0, wall_center.y)
		if not state.map_space.valid_position(near, 30) or not state.map_space.valid_position(far, 24):
			continue
		state.bullets.clear()
		state.weapon_events.clear()
		state.enemies.clear()
		state.player = near
		state.facing = Vector2.RIGHT
		state.add_enemy(far)
		var health: int = state.enemies[-1].hp
		state._auto_fire()
		for tick in range(5):
			state._move_bullets(0.05)
		wall_found = state.bullets.is_empty() and state.enemies[-1].hp == health
		break
	verify(wall_found, "Wall blocks preview rifle damage through the actual map collision")
	if windowed:
		var rendered_wall := false
		for obstacle in state.map_space.definition.obstacles:
			if obstacle.kind != "wall" and obstacle.kind != "ruin":
				continue
			var box: Rect2 = state.MapCatalog.rectangle(obstacle.rect)
			var at := Vector2(box.get_center().x, box.position.y - 36.0)
			if not state.map_space.valid_position(at, 30.0):
				continue
			state.player = at
			ui.view.camera.reset()
			var screen_at: Vector2 = ui.view.world_to_screen(at)
			var shape := Scenery.geometry(box, Scenery.height_for(obstacle), ui.view.ground_transform())
			if not Scenery.occludes(shape, screen_at, Rect2(screen_at - Vector2(34.5, 85.56), Vector2(69, 85.56))):
				continue
			ui.view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			rendered_wall = ui.view.high_renderer.stats.occluders > 0
			root.get_texture().get_image().save_png(folder.path_join("plan_b_wall.png"))
			break
		verify(rendered_wall, "Existing wall fades over the depth-sorted preview actor")
	ui.combat_audio.stop_all()
	ui.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	finish()

func finish() -> void:
	print(JSON.stringify({"checks": count, "failures": failures, "status": "PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
