extends PanelContainer
## Deliberately text/border placeholders, not new character artwork.
## No Timer/Tween/process clock: drawing cannot change the simulation.
var state_key: String = "normal"
var reaction_text: Label
var context_text: Label
var danger_text: Label
var frame_style: StyleBoxFlat
var _signature: String = ""

func _ready() -> void:
	name = "ViyaFeedbackPlaceholder"
	custom_minimum_size = Vector2(144, 108)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color("27242e")
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(7)
	frame_style.content_margin_left = 8
	frame_style.content_margin_right = 8
	frame_style.content_margin_top = 8
	frame_style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", frame_style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	column.add_child(_text("비야 반응 · 임시", 13))
	reaction_text = _text("전투 집중", 17)
	column.add_child(reaction_text)
	context_text = _text("출격 대기", 12)
	column.add_child(context_text)
	danger_text = _text("", 12)
	danger_text.custom_minimum_size.y = 16
	danger_text.add_theme_color_override("font_color", Color("efae77"))
	column.add_child(danger_text)

func _text(value: String, pixels: int) -> Label:
	var item := Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size", pixels)
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

func present(data: Dictionary, context: String = "") -> void:
	if not is_instance_valid(reaction_text):
		return
	state_key = str(data["key"])
	var signature: String = "%s|%s|%s" % [state_key, data["low_hp"], context]
	if signature == _signature:
		return
	_signature = signature
	var accent := Color(str(data["accent"]))
	frame_style.border_color = accent
	reaction_text.text = str(data["label"])
	reaction_text.add_theme_color_override("font_color", accent)
	context_text.text = str(data["detail"]) if context.is_empty() else context
	# Persistent safety information is not hidden by a happy/casting reaction.
	danger_text.text = "저체력 경고" if bool(data["low_hp"]) else ""
