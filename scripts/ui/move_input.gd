extends Control
## Own exactly one movement finger. Other fingers remain available for GUI buttons.
var enabled := false
var touch_id := -1
var mouse_drag := false
var axis := Vector2.ZERO
var base := Vector2.ZERO
var knob := Vector2.ZERO
const RADIUS := 62.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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

func accepts(at: Vector2) -> bool:
	return at.x < size.x * 0.32 and at.y > 130.0 and at.y < size.y - 174.0

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.index == touch_id and (not event.pressed or event.canceled):
			clear_input()
			get_viewport().set_input_as_handled()
		elif event.pressed and not event.canceled and touch_id == -1 and accepts(event.position):
			touch_id = event.index
			base = event.position
			_update_axis(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_update_axis(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Native touch is already tracked. Never treat its emulated mouse as a second stick.
		if event.device == InputEvent.DEVICE_ID_EMULATION or touch_id != -1:
			return
		if not event.pressed and mouse_drag:
			clear_input()
		elif event.pressed and accepts(event.position):
			mouse_drag = true
			base = event.position
			_update_axis(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and mouse_drag:
		_update_axis(event.position)
		get_viewport().set_input_as_handled()

func _update_axis(at: Vector2) -> void:
	knob = (at - base).limit_length(RADIUS)
	axis = knob / RADIUS
	if axis.length() < 0.12:
		axis = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	if not enabled:
		return
	var center := base if touch_id >= 0 or mouse_drag else Vector2(115, size.y - 258)
	draw_circle(center, RADIUS, Color(0.12, 0.13, 0.16, 0.65))
	draw_arc(center, RADIUS, 0.0, TAU, 48, Color(0.72, 0.61, 0.42, 0.7), 2.0, true)
	draw_circle(center + knob, 22.0, Color(0.85, 0.75, 0.57, 0.65))
