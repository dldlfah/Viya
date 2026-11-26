extends PanelContainer
## Deliberately text/border placeholders, not new character artwork.
## No Timer/Tween/process clock: drawing cannot change the simulation.
var state_key: String = "normal"
var expression_key: String = "normal"
var expression_has_art: bool = false
var compact_mode: bool = false
var reaction_text: Label
var context_text: Label
var danger_text: Label
var frame_style: StyleBoxFlat
var _signature: String = ""
var art = preload("res://scripts/ui/asset_slots.gd").new()
var portrait_assets = preload("res://scripts/ui/portrait_assets.gd").new(art)
var portrait: TextureRect

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
	column.name = "ReactionColumn"
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
	for caption in [reaction_text,danger_text]:
		caption.add_theme_color_override("font_outline_color",Color("17131c"))
		caption.add_theme_constant_override("outline_size",2)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.modulate.a = 1.0
	add_child(portrait)
	move_child(portrait,0)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
	expression_key = str(data.get("expression", "normal"))
	var resolved: Dictionary = portrait_assets.resolve(expression_key)
	expression_has_art = bool(resolved.exact)
	if portrait.texture != resolved.texture:portrait.texture = resolved.texture
	portrait.visible = portrait.texture != null
	var column: VBoxContainer = get_node("ReactionColumn")
	column.alignment = BoxContainer.ALIGNMENT_END if portrait.visible else BoxContainer.ALIGNMENT_BEGIN
	column.get_child(0).visible = not compact_mode and not portrait.visible
	context_text.visible = not compact_mode and not portrait.visible
	var signature: String = "%s|%s|%s|%s|%s|%s" % [state_key, data["low_hp"], context, expression_key, portrait.visible, data["detail"]]
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
