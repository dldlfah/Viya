extends Control
## Replaceable lobby backdrop slot. All geometry is provisional.
@export var backdrop: Texture2D
@export var hero: Texture2D
func _ready() -> void:
	var bank = preload("res://scripts/ui/asset_slots.gd").new()
	backdrop = bank.texture("lobby_city") if backdrop == null else backdrop
	hero = bank.texture("viya_lobby") if hero == null else hero
	custom_minimum_size.y = 150
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	if backdrop:
		draw_texture_rect(backdrop, Rect2(Vector2.ZERO, size), true)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("202a34"))
		for i in range(9):
			var x := size.x * i / 9.0
			draw_rect(Rect2(x, size.y * 0.40, size.x / 10.0, size.y * 0.48), Color("4d555d"))
			draw_rect(Rect2(x, size.y * 0.31, 18, size.y * 0.12), Color("6c7378"))
		draw_rect(Rect2(size.x * 0.40, size.y * 0.50, size.x * 0.13, size.y * 0.38), Color("24232b"))
		draw_rect(Rect2(0, size.y * 0.88, size.x, size.y * 0.12), Color("3c3432"))
	var at := Vector2(size.x * 0.75, size.y * 0.6)
	if hero:
		draw_texture_rect(hero, Rect2(at - Vector2(40, 60), Vector2(80, 110)), false)
	else:
		draw_circle(at - Vector2(0, 28), 12, Color("ddcdb3"))
		draw_colored_polygon(PackedVector2Array([at - Vector2(10, 13), at + Vector2(20, 35), at + Vector2(-24, 35)]), Color("963d55"))
		draw_line(at + Vector2(2, -3), at + Vector2(46, -10), Color("b39c70"), 6)
