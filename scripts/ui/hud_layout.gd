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
	var margin := minf(6.0, safe.size.y * 0.008)
	var gap := minf(4.0, safe.size.y * 0.005)
	var inner := safe.grow(-margin)
	var compact := inner.size.x < COMPACT_WIDTH
	# The small-screen header folds secondary information instead of stealing FOV.
	var top_height := clampf(safe.size.y * 0.067, 32.0, 48.0)
	var bottom_height := clampf(safe.size.y * 0.16, 58.0, 112.0)
	var top := Rect2(inner.position, Vector2(inner.size.x, top_height))
	var bottom := Rect2(Vector2(inner.position.x, inner.end.y-bottom_height), Vector2(inner.size.x,bottom_height))
	var battle := Rect2(Vector2(inner.position.x,top.end.y+gap),Vector2(inner.size.x,bottom.position.y-top.end.y-gap*2))
	var move := Rect2(battle.position+Vector2(0,36),Vector2(battle.size.x*.42,maxf(1,battle.size.y-36)))
	var feedback_width := clampf(bottom.size.x*.10,65.0,110.0)
	var resources_width := clampf(bottom.size.x*.18,110.0,210.0)
	var magic_width := clampf(bottom.size.x*.16,100.0,190.0)
	var support_height := 12.0
	var info_height := bottom_height-support_height-gap
	var feedback := Rect2(bottom.position,Vector2(feedback_width,info_height))
	var resources := Rect2(Vector2(feedback.end.x+gap,bottom.position.y),Vector2(resources_width,bottom_height))
	var support := Rect2(Vector2(bottom.position.x,bottom.end.y-support_height),Vector2(feedback_width,support_height))
	var magic := Rect2(Vector2(bottom.end.x-magic_width,bottom.position.y),Vector2(magic_width,bottom_height))
	var skills := Rect2(Vector2(resources.end.x+gap,bottom.position.y),Vector2(magic.position.x-resources.end.x-gap*2,bottom_height))
	var modal_width := minf(1040.0, inner.size.x)
	var modal := Rect2(Vector2(safe.get_center().x - modal_width * 0.5, inner.position.y), Vector2(modal_width, inner.size.y))
	return {"safe": safe, "top": top, "bottom": bottom, "battle": battle, "move": move,
		"feedback": feedback, "resources": resources, "skills": skills, "support": support,
		"magic": magic, "modal": modal, "compact": compact, "unit": unit,
		"gap": gap, "card_columns": 3 if modal_width >= 850.0 else 1}
