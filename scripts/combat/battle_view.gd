extends Control
## Debug shapes are deliberately not final Viya character art.
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
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -20), at + Vector2(19, 13), at + Vector2(-19, 13)]), Color("aa5364"))
			draw_rect(Rect2(at + Vector2(-18, -29), Vector2(36, 4)), Color("302b2e"))
			draw_rect(Rect2(at + Vector2(-18, -29), Vector2(36.0 * enemy["hp"] / 20.0, 4)), Color("d98a8d"))
	for bullet in simulation.bullets:
		var at := _screen(bullet["p"])
		draw_line(at - bullet["direction"] * 12.0, at, Color("f6d798"), 4.0, true)
	for effect in simulation.effects:
		var color := Color("c95678") if effect["kind"] == "sigil" else Color("e3b66f")
		color.a = clampf(float(effect["life"]) / 0.25, 0.0, 1.0)
		draw_arc(_screen(effect["p"]), effect["radius"], 0.0, TAU, 40, color, 3.0, true)
	var center := size * 0.5
	var direction: Vector2 = simulation.facing
	draw_circle(center + Vector2(0, 8), 23, Color(0, 0, 0, 0.5))
	draw_colored_polygon(PackedVector2Array([center - direction * 26.0, center + direction.orthogonal() * 12.0, center - direction.orthogonal() * 12.0]), Color("8e2b47"))
	var player_color := Color("fff1db") if simulation.hurt_clock > 0.5 else Color("cbbba1")
	draw_circle(center, 16.0, player_color)
	draw_line(center + direction * 6.0, center + direction * 34.0, Color("3a3e48"), 8.0, true)
	draw_arc(center, 24.0, 0.0, TAU, 36, Color("b69a65"), 1.4, true)
