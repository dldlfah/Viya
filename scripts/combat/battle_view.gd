extends Control
## Debug shapes are deliberately not final Viya character art.
const AttackVisuals = preload("res://scripts/combat/attack_visuals.gd")
var simulation

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _screen(at: Vector2) -> Vector2:
	return at - simulation.player + size * 0.5

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("191c22"))
	if simulation == null:
		return
	var origin: Vector2 = size * 0.5 - simulation.player
	for x in range(int(-origin.x / 64.0) - 1, int((size.x - origin.x) / 64.0) + 2):
		draw_line(Vector2(origin.x + x * 64, 0), Vector2(origin.x + x * 64, size.y), Color("242832"))
	for y in range(int(-origin.y / 64.0) - 1, int((size.y - origin.y) / 64.0) + 2):
		draw_line(Vector2(0, origin.y + y * 64), Vector2(size.x, origin.y + y * 64), Color("242832"))
	draw_rect(Rect2(origin, simulation.WORLD_SIZE), Color("6c5c43"), false, 4.0)
	for pickup in simulation.pickups:
		var pos := _screen(pickup["p"])
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -7),
			pos + Vector2(5, 0), pos + Vector2(0, 7), pos + Vector2(-5, 0)]), Color("7cd3c1"))
	for enemy in simulation.enemies:
		var at := _screen(enemy["p"])
		if Rect2(Vector2.ZERO, size).grow(30).has_point(at):
			draw_circle(at + Vector2(0, 5), 21, Color(0, 0, 0, 0.4))
			var flash: float = simulation.cues.flash_alpha(int(enemy["id"]))
			var enemy_color: Color = Color("aa5364").lerp(Color("fff1db"), flash)
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -20), at + Vector2(19, 13), at + Vector2(-19, 13)]), enemy_color)
			draw_rect(Rect2(at + Vector2(-18, -29), Vector2(36, 4)), Color("302b2e"))
			draw_rect(Rect2(at + Vector2(-18, -29), Vector2(36.0 * enemy["hp"] / 20.0, 4)), Color("d98a8d"))
	for bullet in simulation.bullets:
		var at := _screen(bullet["p"])
		AttackVisuals.draw_projectile(self, at, bullet["direction"], str(bullet.get("source", "rifle")))
	for effect in simulation.effects:
		var effect_at: Vector2 = _screen(effect["p"])
		var link_from: Vector2 = _screen(effect.get("from", effect["p"]))
		AttackVisuals.draw_effect(self, effect_at, effect, link_from)
	var center := size * 0.5
	var direction: Vector2 = simulation.facing
	draw_circle(center + Vector2(0, 8), 23, Color(0, 0, 0, 0.5))
	draw_colored_polygon(PackedVector2Array([center - direction * 26.0, center + direction.orthogonal() * 12.0, center - direction.orthogonal() * 12.0]), Color("8e2b47"))
	var player_color := Color("fff1db") if simulation.hurt_clock > 0.5 else Color("cbbba1")
	draw_circle(center, 16.0, player_color)
	draw_line(center + direction * 6.0, center + direction * 34.0, Color("3a3e48"), 8.0, true)
	draw_arc(center, 24.0, 0.0, TAU, 36, Color("b69a65"), 1.4, true)
	_draw_combat_cues()

func _draw_combat_cues() -> void:
	# One existing canvas, no spawned labels/particles/timers and no state writes.
	if not simulation.cues.enabled:
		return
	var font: Font = get_theme_default_font()
	var visible_area := Rect2(Vector2.ZERO, size).grow(40.0)
	for event in simulation.cues.events:
		var at: Vector2 = _screen(event["p"])
		if not visible_area.has_point(at):
			continue
		var fraction: float = clampf(float(event["life"]) / float(event["duration"]), 0.0, 1.0)
		var progress: float = 1.0 - fraction
		var kind: String = event["kind"]
		if kind == "kill":
			var ring := Color("d98a8d", fraction)
			draw_arc(at, 12.0 + progress * 15.0, 0.0, TAU, 16, ring, 2.0, true)
			continue
		if font == null:
			continue
		var text: String
		var color: Color
		if kind == "xp":
			text = "+%.2f XP" % float(event["amount"])
			color = Color("7cd3c1", fraction)
			at += Vector2(24.0, -18.0 - progress * 22.0)
		else:
			text = ("!%d" if bool(event["critical"]) else "%d") % int(event["amount"])
			color = Color("f6d798" if bool(event["critical"]) else "fff1db", fraction)
			at += Vector2(0.0, -35.0 - progress * 18.0)
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		at.x -= width * 0.5
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 2, Color(0.03, 0.03, 0.04, fraction))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
