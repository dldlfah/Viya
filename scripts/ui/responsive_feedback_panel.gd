extends "res://scripts/ui/feedback_panel.gd"
## Reuses the existing feedback state; this class only fits its placeholder labels.

func fit_compact(compact: bool) -> void:
	if not is_instance_valid(reaction_text):
		return
	custom_minimum_size = Vector2.ZERO
	var column: VBoxContainer = get_node("ReactionColumn")
	column.add_theme_constant_override("separation", 2 if compact else 4)
	column.get_child(0).visible = not compact
	context_text.visible = not compact
	for child in column.get_children():
		if child is Label:
			child.clip_text = true
			child.custom_minimum_size.x = 0.0
	frame_style.content_margin_top = 5 if compact else 8
	frame_style.content_margin_bottom = 5 if compact else 8
	reaction_text.add_theme_font_size_override("font_size", 16 if compact else 17)
	danger_text.custom_minimum_size.y = 16
