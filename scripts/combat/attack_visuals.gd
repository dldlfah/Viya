extends RefCounted
## Provisional silhouettes on the existing BattleView canvas, not final art.
## Only committed bullet/effect data is read. No targets, timers, RNG or damage.

static func projectile_style(source: String) -> Dictionary:
	match source:
		"scatter":
			return {"shape": "pellet", "color": Color("ffb46a")}
		"lance":
			return {"shape": "spear", "color": Color("80d9ee")}
		"crossfire":
			return {"shape": "diamond", "color": Color("9adea2")}
		"heavy":
			return {"shape": "heavy", "color": Color("f3eddf")}
	return {"shape": "tracer", "color": Color("f6d798")}

static func effect_style(kind: String) -> Dictionary:
	match kind:
		"blast":
			return {"shape": "blast", "color": Color("edaa65")}
		"pulse":
			return {"shape": "segmented", "color": Color("79cddd")}
		"chain":
			return {"shape": "link", "color": Color("ba9be8")}
		"sigil":
			return {"shape": "rune", "color": Color("c95678")}
		"ultimate":
			return {"shape": "ultimate", "color": Color("f46caa")}
	return {"shape": "ring", "color": Color("e3b66f")}

static func draw_projectile(canvas: CanvasItem, at: Vector2, direction: Vector2, source: String) -> void:
	var style: Dictionary = projectile_style(source)
	var color: Color = style["color"]
	var d: Vector2 = direction.normalized()
	if d.is_zero_approx():
		d = Vector2.RIGHT
	var normal: Vector2 = d.orthogonal()
	# Silhouette sizes are cosmetic, never collision radii or damage ranges.
	match str(style["shape"]):
		"pellet":
			canvas.draw_line(at - d * 6.0, at, color, 2.0, true)
			canvas.draw_circle(at, 2.8, color)
		"spear":
			canvas.draw_line(at - d * 22.0 + normal * 2.0, at - d * 5.0 + normal * 2.0, color, 1.5, true)
			canvas.draw_line(at - d * 22.0 - normal * 2.0, at - d * 5.0 - normal * 2.0, color, 1.5, true)
			canvas.draw_polyline(PackedVector2Array([at - d * 7.0 + normal * 4.0,
				at, at - d * 7.0 - normal * 4.0]), color, 2.0, true)
		"diamond":
			canvas.draw_line(at - d * 14.0, at - d * 7.0, color, 1.5, true)
			canvas.draw_polyline(PackedVector2Array([at, at - d * 5.0 + normal * 3.5,
				at - d * 10.0, at - d * 5.0 - normal * 3.5, at]), color, 2.0, true)
		"heavy":
			canvas.draw_line(at - d * 30.0, at, color, 5.0, true)
			canvas.draw_line(at - d * 10.0 - normal * 5.0, at - d * 10.0 + normal * 5.0, color, 2.0, true)
		_:
			canvas.draw_line(at - d * 12.0, at, color, 4.0, true)

static func draw_effect(canvas: CanvasItem, at: Vector2, effect: Dictionary, link_from: Vector2) -> void:
	var style: Dictionary = effect_style(str(effect.get("kind", "")))
	var duration: float = float(effect.get("duration", 0.25))
	if duration <= 0.0 or not is_finite(duration):
		return
	var fraction: float = clampf(float(effect.get("life", 0.0)) / duration, 0.0, 1.0)
	if fraction <= 0.0:
		return
	var color: Color = style["color"]
	color.a = fraction
	var shape: String = style["shape"]
	if shape == "link":
		# The saved endpoints were selected by the actual chain attack. Do not
		# connect to today's player position or search a fresh nearest enemy here.
		if effect.has("from"):
			canvas.draw_line(link_from, at, color, 2.0, true)
		canvas.draw_polyline(PackedVector2Array([at + Vector2(0, -5), at + Vector2(5, 0),
			at + Vector2(0, 5), at + Vector2(-5, 0), at + Vector2(0, -5)]), color, 1.5, true)
		return # A chain hit is not a circular area attack.
	var radius: float = float(effect.get("radius", 0.0))
	if radius <= 0.0 or not is_finite(radius):
		return
	if shape == "segmented":
		# All segments lie on the committed damage boundary. No filled screen wash.
		for n in range(12):
			var start: float = float(n) * TAU / 12.0
			canvas.draw_arc(at, radius, start, start + TAU / 18.0, 6, color, 2.5, true)
		canvas.draw_arc(at, radius * (1.0 - fraction), 0.0, TAU, 32, color, 1.5, true)
		return
	# The full outer ring always uses the real burst center and radius.
	canvas.draw_arc(at, radius, 0.0, TAU, 64, color, 5.0 if shape == "ultimate" else 3.0, true)
	match shape:
		"blast":
			for n in range(8):
				var d: Vector2 = Vector2.from_angle(float(n) * TAU / 8.0)
				canvas.draw_line(at + d * radius * 0.72, at + d * radius * 0.92, color, 2.0, true)
		"rune":
			canvas.draw_polyline(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0),
				at + Vector2(0, radius), at + Vector2(-radius, 0), at + Vector2(0, -radius)]), color, 1.5, true)
			canvas.draw_line(at + Vector2(-7, 0), at + Vector2(7, 0), color, 2.0, true)
			canvas.draw_line(at + Vector2(0, -7), at + Vector2(0, 7), color, 2.0, true)
		"ultimate":
			# Preserve the original manual-magic inner/outer ring and lifetime.
			canvas.draw_arc(at, radius * (1.0 - fraction), 0.0, TAU, 48, color, 2.0, true)
