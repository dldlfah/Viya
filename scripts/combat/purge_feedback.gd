extends RefCounted
## One existing item receipt drives bounded presentation; no nodes, timers or RNG.
const MAX_MARKS := 12
const MAX_BOSSES := 2
const DURATION := 1.3

static func capture(enemies: Array, visible: Rect2) -> Array[Vector2]:
	var cells: Dictionary = {}
	var marks: Array[Vector2] = []
	if visible.size.x <= 0 or visible.size.y <= 0:
		return marks
	for enemy in enemies:
		if enemy.kind == "boss" or not visible.has_point(enemy.p):
			continue
		var uv: Vector2 = (enemy.p - visible.position) / visible.size
		var cell := clampi(floori(uv.x * 4), 0, 3) + 4 * clampi(floori(uv.y * 3), 0, 2)
		if not cells.has(cell):
			cells[cell] = enemy.p
	marks.assign(cells.values())
	return marks

static func attach(cues, marks: Array[Vector2]) -> void:
	if not cues.enabled or cues.events.is_empty():
		return
	var event: Dictionary = cues.events[-1]
	if event.kind == "item" and event.get("supply", {}).get("kind", "") == "purge":
		event["purge_marks"] = marks.duplicate()

static func plan(view) -> Dictionary:
	var state = view.simulation
	if state == null or not state.cues.enabled or state.phase not in [state.Phase.RUNNING, state.Phase.CHOOSING, state.Phase.PAUSED]:
		return {}
	var receipt: Dictionary = {}
	for index in range(state.cues.events.size() - 1, -1, -1):
		var event: Dictionary = state.cues.events[index]
		if event.kind == "item" and event.has("purge_marks"):
			receipt = event
			break
	if receipt.is_empty() or receipt.life <= 0:
		return {}
	var origin: Vector2 = view.world_to_screen(receipt.p)
	var age := clampf(float(receipt.duration) - float(receipt.life), 0, DURATION)
	var simple: bool = view.simple_attacks or bool(view.display_plan.get("simple", false))
	var marks: Array[Vector2] = []
	for at in receipt.purge_marks:
		var screen: Vector2 = view.world_to_screen(at)
		if Rect2(Vector2.ZERO, view.size).grow(60).has_point(screen):
			marks.append(screen)
		if marks.size() >= (6 if simple else MAX_MARKS):
			break
	var bosses: Array[Vector2] = []
	for enemy in state.enemies:
		if enemy.kind == "boss":
			var at: Vector2 = view.world_to_screen(enemy.p)
			if Rect2(Vector2.ZERO, view.size).grow(60).has_point(at):
				bosses.append(at)
		if bosses.size() >= MAX_BOSSES:
			break
	var reach := 1.0
	for corner in [Vector2.ZERO, Vector2(view.size.x, 0), view.size, Vector2(0, view.size.y)]:
		reach = maxf(reach, origin.distance_to(corner))
	return {"origin":origin, "age":age, "reach":reach + 60, "marks":marks, "bosses":bosses, "simple":simple}

static func draw(view) -> void:
	var fx := plan(view)
	if fx.is_empty():
		return
	var age: float = fx.age
	var origin: Vector2 = fx.origin
	var fade := clampf(1.0 - age / DURATION, 0, 1)
	var red := Color("f36b7e")
	var gold := Color("f6d79b")
	# A soft crimson wash stays inside the battlefield; no camera kick or white flash.
	view.draw_rect(Rect2(Vector2.ZERO, view.size), Color(.35, .025, .07, .035 * fade))
	var pulse := smoothstep(0.0, .9, age)
	var radius := lerpf(22, float(fx.reach), pulse)
	view.draw_arc(origin, radius, 0, TAU, 64, Color(red, .12 * fade), 10, true)
	view.draw_arc(origin, radius, 0, TAU, 64, Color(red, .85 * fade), 2.8, true)
	if not fx.simple:
		view.draw_arc(origin, maxf(2, radius - 20), 0, TAU, 64, Color(gold, .6 * fade), 1.3, true)
	# The activation sigil sits on the ground beneath the expanding wave.
	view.draw_set_transform(origin, 0, Vector2(1, .58 if view.high_angle else 1.0))
	var seal := 64.0 + minf(age, .3) * 80
	view.draw_circle(Vector2.ZERO, seal, Color(.38, .035, .1, .18 * fade))
	view.draw_arc(Vector2.ZERO, seal, 0, TAU, 40, Color(gold, .85 * fade), 2, true)
	view.draw_arc(Vector2.ZERO, seal * .76, 0, TAU, 40, Color(red, fade), 2, true)
	var glyphs := 6 if fx.simple else 12
	for index in range(glyphs):
		var axis := Vector2.from_angle(TAU * index / glyphs - PI * .5)
		var at := axis * seal * .87
		view.draw_line(at - axis * 7, at + axis * 7, Color(gold, fade), 2, true)
		view.draw_line(at, at + axis.rotated(PI * .6) * 7, Color(red, fade), 2, true)
	var star := PackedVector2Array()
	for index in range(6):
		star.append(Vector2.from_angle(-PI * .5 + index * TAU * 2 / 5) * seal * .62)
	view.draw_polyline(star, Color(red, .9 * fade), 2.2, true)
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
	# Twelve screen-grid samples at most; every actual death still uses normal rewards.
	for index in range(fx.marks.size()):
		var at: Vector2 = fx.marks[index]
		var t := clampf((age - .04 * (index % 3)) / .85, 0, 1)
		var alpha := (1 - t) * fade
		view.draw_line(at + Vector2(0, 4 - t * 20), at + Vector2(0, -42 - t * 35), Color(red, alpha * .65), 2.5, true)
		for shard in range(3):
			var center := at + Vector2((shard - 1) * (8 + t * 16), -15 - shard * 11 - t * 36)
			var size := 4.0 * (1 - t) + 1
			view.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -size * 2), center + Vector2(size, size), center - Vector2(size, 0)]), Color(gold if shard == 1 else red, alpha))
	# Boss protection is indicated without changing HP, position, AI or damage rules.
	for feet in fx.bosses:
		var at: Vector2 = feet + Vector2(0, -58)
		view.draw_polyline(PackedVector2Array([at + Vector2(-10, -10), at + Vector2(10, -10), at + Vector2(9, 3), at + Vector2(0, 12), at + Vector2(-9, 3), at + Vector2(-10, -10)]), Color(gold, fade), 2, true)
