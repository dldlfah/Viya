extends SubViewport
## An opt-in rig over the existing 2D ground. This viewport owns visuals only.
const GroundProjection = preload("res://scripts/combat/oblique_projection.gd")
const Probe = "res://assets/characters/plan_b_probe/probe.glb"
const DISPLAY_SCALE := 0.65
const SHOT_WINDOW := 0.27

var rig: Node3D
var camera: Camera3D
var muzzle: Node3D
var animation_tree: AnimationTree
var rest_muzzle := Vector3.ZERO
var run_id := ""
var stride_time := 0.0
var shot_age := 1.0
var flash_facing := Vector2.ZERO
var stride_length: float
var fire_length: float

func _ready() -> void:
	size = Vector2i(192, 192)
	transparent_bg = true
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var scene := load(Probe) as PackedScene
	if scene == null:
		return
	rig = scene.instantiate()
	add_child(rig)
	muzzle = rig.find_child("Muzzle", true, false)
	var animator := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if muzzle == null or animator == null:
		return
	rest_muzzle = rig.to_local(muzzle.global_position)
	_build_animation_tree(animator)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.85
	add_child(camera)
	var height := deg_to_rad(55.0)
	var focus := Vector3(0, 0.83, 0)
	camera.position = focus + Vector3(sin(GroundProjection.YAW) * cos(height), sin(height), cos(GroundProjection.YAW) * cos(height)) * 5.0
	camera.look_at(focus)
	camera.make_current()
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-55, 25, 0)
	light.light_energy = 1.35

func _build_animation_tree(animator: AnimationPlayer) -> void:
	stride_length = animator.get_animation("locomotion").length
	var fire := animator.get_animation("aim_fire")
	fire_length = fire.length
	var blend := AnimationNodeBlendTree.new()
	var upper := AnimationNodeBlend2.new()
	upper.filter_enabled = true
	for track in range(fire.get_track_count()):
		var path := fire.track_get_path(track)
		if path.get_subname_count() > 0 and path.get_subname(0) == "spine":
			upper.set_filter_path(path, true)
	blend.add_node("upper_body", upper)
	for clip_name in ["locomotion", "aim_fire"]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = clip_name
		blend.add_node(clip_name, clip)
		blend.add_node(clip_name + "_time", AnimationNodeTimeSeek.new())
		blend.connect_node(clip_name + "_time", 0, clip_name)
	blend.connect_node("upper_body", 0, "locomotion_time")
	blend.connect_node("upper_body", 1, "aim_fire_time")
	blend.connect_node("output", 0, "upper_body")
	animation_tree = AnimationTree.new()
	animation_tree.tree_root = blend
	animation_tree.root_node = animator.root_node
	animator.get_parent().add_child(animation_tree)
	animation_tree.anim_player = animation_tree.get_path_to(animator)
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_tree.active = true

func sync(state, delta: float, distance: float, active: bool, previous_shots: int) -> void:
	if camera == null or not state.uses_plan_b_aiming():
		return
	if state.run_id != run_id:
		run_id = state.run_id
		stride_time = 0.0
		shot_age = 1.0
	if not active:
		return
	rig.rotation.y = yaw(state.facing)
	stride_time += distance / 155.0 * stride_length
	shot_age += delta
	if state.plan_b_rifle_shots > previous_shots:
		shot_age = 0.0
		flash_facing = state.facing
	animation_tree.set("parameters/locomotion_time/seek_request", fposmod(stride_time, stride_length))
	animation_tree.set("parameters/aim_fire_time/seek_request", minf(shot_age, fire_length))
	animation_tree.set("parameters/upper_body/blend_amount", 1.0 if shot_age < SHOT_WINDOW else 0.0)
	animation_tree.advance(0.0)
	render_target_update_mode = SubViewport.UPDATE_ONCE

func yaw(direction: Vector2) -> float:
	return atan2(direction.x, direction.y)

func drawing_rect(feet: Vector2) -> Rect2:
	var anchor := camera.unproject_position(Vector3.ZERO)
	return Rect2(feet - anchor * DISPLAY_SCALE, Vector2(size) * DISPLAY_SCALE)

func muzzle_offset(direction: Vector2) -> Vector2:
	var tip := rest_muzzle.rotated(Vector3.UP, yaw(direction))
	return (camera.unproject_position(tip) - camera.unproject_position(Vector3.ZERO)) * DISPLAY_SCALE

func projectile(view, bullet: Dictionary) -> Dictionary:
	var direction: Vector2 = view.project_direction(bullet.direction).normalized()
	var at: Vector2 = view.world_to_screen(bullet.p)
	var proportion := smoothstep(0.0, 180.0, float(bullet.age) * float(bullet.speed))
	var offset := muzzle_offset(bullet.direction).lerp(Vector2(0, -20), proportion)
	return {"p": at + offset, "direction": direction}

func draw_actor(view, feet: Vector2, direction: Vector2) -> void:
	view.draw_texture_rect(get_texture(), drawing_rect(feet), false)
	if shot_age < 0.075 and direction.is_equal_approx(flash_facing):
		var aim: Vector2 = view.project_direction(direction).normalized()
		var tip := feet + muzzle_offset(direction)
		view.draw_line(tip, tip + aim * 10.0, Color("ffe3a2"), 2.0, true)
