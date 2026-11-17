extends RefCounted
## One source of rectangles for HUD, battle view and movement input.
## Coordinates are root_ui-local logical pixels, never physical screen pixels.
const COMPACT_WIDTH := 1100.0
const BASE_SIZE := Vector2(1280.0, 720.0)

static func build(viewport_size: Vector2, safe_area: Rect2 = Rect2()) -> Dictionary:
	var full := Rect2(Vector2.ZERO, viewport_size.max(Vector2.ONE))
	var safe := full
	if safe_area.has_area():
		var clipped := full.intersection(safe_area)
		if clipped.has_area():
			safe = clipped
	var unit := clampf(minf(safe.size.x / BASE_SIZE.x, safe.size.y / BASE_SIZE.y), 0.70, 1.25)
	var margin := 12.0 * unit
	var gap := 8.0 * unit
	var inner := safe.grow(-margin)
	var compact := inner.size.x < COMPACT_WIDTH
	var top_height := 64.0 * unit
	# Compact mode keeps the two skill rows below the status/magic row.
	var bottom_height := 204.0 if compact else 156.0 * unit
	bottom_height = minf(bottom_height, maxf(90.0, inner.size.y - top_height - gap * 2.0 - 48.0))
	var top := Rect2(inner.position, Vector2(inner.size.x, top_height))
	var bottom := Rect2(Vector2(inner.position.x, inner.end.y - bottom_height), Vector2(inner.size.x, bottom_height))
	var battle := Rect2(Vector2(inner.position.x, top.end.y + gap), Vector2(inner.size.x, maxf(1.0, bottom.position.y - top.end.y - gap * 2.0)))
	var move := Rect2(battle.position, Vector2(battle.size.x * 0.36, battle.size.y))
	var support_height := 18.0
	var feedback: Rect2
	var resources: Rect2
	var skills: Rect2
	var support: Rect2
	var magic: Rect2
	if compact:
		var info_height := minf(82.0, bottom.size.y * 0.40)
		var feedback_width := bottom.size.x * 0.25
		var magic_width := bottom.size.x * 0.29
		feedback = Rect2(bottom.position, Vector2(feedback_width, info_height))
		magic = Rect2(Vector2(bottom.end.x - magic_width, bottom.position.y), Vector2(magic_width, info_height))
		resources = Rect2(Vector2(feedback.end.x + gap, bottom.position.y), Vector2(magic.position.x - feedback.end.x - gap * 2.0, info_height))
		support = Rect2(Vector2(bottom.position.x, bottom.end.y - support_height), Vector2(bottom.size.x, support_height))
		skills = Rect2(Vector2(bottom.position.x, bottom.position.y + info_height + gap), Vector2(bottom.size.x, maxf(1.0, support.position.y - bottom.position.y - info_height - gap * 2.0)))
	else:
		var feedback_width := clampf(bottom.size.x * 0.14, 144.0, 180.0)
		var resources_width := clampf(bottom.size.x * 0.16, 174.0, 220.0)
		var magic_width := clampf(bottom.size.x * 0.16, 176.0, 220.0)
		feedback = Rect2(bottom.position, Vector2(feedback_width, bottom.size.y))
		resources = Rect2(Vector2(feedback.end.x + gap, bottom.position.y), Vector2(resources_width, bottom.size.y))
		magic = Rect2(Vector2(bottom.end.x - magic_width, bottom.position.y), Vector2(magic_width, bottom.size.y))
		var middle_x := resources.end.x + gap
		var middle_width := magic.position.x - middle_x - gap
		skills = Rect2(Vector2(middle_x, bottom.position.y), Vector2(middle_width, bottom.size.y - support_height - gap))
		support = Rect2(Vector2(middle_x, bottom.end.y - support_height), Vector2(middle_width, support_height))
	var modal_width := minf(1040.0, inner.size.x)
	var modal := Rect2(Vector2(safe.get_center().x - modal_width * 0.5, inner.position.y), Vector2(modal_width, inner.size.y))
	return {"safe": safe, "top": top, "bottom": bottom, "battle": battle, "move": move,
		"feedback": feedback, "resources": resources, "skills": skills, "support": support,
		"magic": magic, "modal": modal, "compact": compact, "unit": unit,
		"gap": gap, "card_columns": 3 if modal_width >= 850.0 else 1}
