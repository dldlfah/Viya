extends Control
## Own exactly one movement finger. The HUD supplies the real allowed rectangle.
var enabled := false
var touch_id := -1
var mouse_drag := false
var axis := Vector2.ZERO
var base := Vector2.ZERO
var knob := Vector2.ZERO
const RADIUS := 62.0
var interaction_rect := Rect2()
var stick_radius: float = RADIUS
var _region_configured := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_interaction_rect(rect: Rect2) -> void:
	# Resizing releases captured fingers; a held finger must not jump to a new HUD.
	if _region_configured and interaction_rect == rect:
		return
	clear_input()
	_region_configured = true
	interaction_rect = rect
	stick_radius = minf(RADIUS, maxf(16.0, minf(rect.size.x, rect.size.y) * 0.30))
	queue_redraw()

func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		clear_input()
	queue_redraw()

func clear_input() -> void:
	touch_id = -1
	mouse_drag = false
	axis = Vector2.ZERO
	knob = Vector2.ZERO
	queue_redraw()

func direction() -> Vector2:
	if not enabled:
		return Vector2.ZERO
	var keys := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
		- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	return keys.limit_length(1.0) if keys.length_squared() > 0.0 else axis

func _local_position(at: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * at

func accepts(at: Vector2) -> bool:
	var region := interaction_rect if _region_configured else Rect2(Vector2.ZERO, size)
	return region.has_area() and region.has_point(_local_position(at))

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.index == touch_id and (not event.pressed or event.canceled):
			clear_input()
			get_viewport().set_input_as_handled()
		elif event.pressed and not event.canceled and touch_id == -1 and accepts(event.position):
			touch_id = event.index
			base = _local_position(event.position)
			_update_axis(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_update_axis(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION or touch_id != -1:
			return
		if not event.pressed and mouse_drag:
			clear_input()
			get_viewport().set_input_as_handled()
		elif event.pressed and accepts(event.position):
			mouse_drag = true
			base = _local_position(event.position)
			_update_axis(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and mouse_drag:
		_update_axis(event.position)
		get_viewport().set_input_as_handled()

func _update_axis(at: Vector2) -> void:
	knob = (_local_position(at) - base).limit_length(stick_radius)
	axis = knob / stick_radius
	if axis.length() < 0.12:
		axis = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	if not enabled:
		return
	var region := interaction_rect if _region_configured else Rect2(Vector2.ZERO, size)
	if not region.has_area():
		return
	var idle := Vector2(region.position.x + stick_radius + 8.0, region.end.y - stick_radius - 8.0)
	idle = idle.clamp(region.position, region.end)
	var center := base if touch_id >= 0 or mouse_drag else idle
	draw_circle(center, stick_radius, Color(0.12, 0.13, 0.16, 0.65))
	draw_arc(center, stick_radius, 0.0, TAU, 48, Color(0.72, 0.61, 0.42, 0.7), 2.0, true)
	draw_circle(center + knob, minf(22.0, stick_radius * 0.38), Color(0.85, 0.75, 0.57, 0.65))
