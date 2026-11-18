extends Control
## Debug shapes are deliberately not final Viya character art.
const AttackVisuals = preload("res://scripts/combat/attack_visuals.gd")
const ApproachCues = preload("res://scripts/combat/approach_cues.gd")
var art = preload("res://scripts/ui/asset_slots.gd").new()
var simulation
var show_damage: bool = true
var show_xp: bool = true
var simple_attacks: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _screen(at: Vector2) -> Vector2:
	return at - simulation.camera_center() + size * 0.5

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("191c22") if simulation == null or simulation.map_id == "legacy_arena" else (Color("302d2a") if simulation.map_id == "prologue_wall" else Color("28352f")))
	if simulation == null:
		return
	var origin: Vector2 = size * 0.5 - simulation.camera_center()
	for x in range(int(-origin.x / 64.0) - 1, int((size.x - origin.x) / 64.0) + 2):
		draw_line(Vector2(origin.x + x * 64, 0), Vector2(origin.x + x * 64, size.y), Color("242832"))
	for y in range(int(-origin.y / 64.0) - 1, int((size.y - origin.y) / 64.0) + 2):
		draw_line(Vector2(0, origin.y + y * 64), Vector2(size.x, origin.y + y * 64), Color("242832"))
	_draw_map(origin)
	draw_rect(Rect2(origin, simulation.world_size), Color("6c5c43"), false, 4.0)
	for pickup in simulation.pickups:
		var pos := _screen(pickup["p"])
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -7),
			pos + Vector2(5, 0), pos + Vector2(0, 7), pos + Vector2(-5, 0)]), Color("7cd3c1"))
	for enemy in simulation.enemies:
		var at := _screen(enemy["p"])
		var variant: String = str(enemy.get("variant", "normal"))
		if Rect2(Vector2.ZERO, size).grow(30).has_point(at):
			draw_circle(at + Vector2(0, 5), 21, Color(0, 0, 0, 0.4))
			var flash: float = simulation.cues.flash_alpha(int(enemy["id"]))
			var kind: String = str(enemy.get("kind", "normal"))
			var base: Color = {"normal": Color("aa5364"), "ranged": Color("85ce95"), "fast": Color("6fcce6"), "heavy": Color("c39360"), "flier": Color("a6a8ed")}[variant]
			if kind != "normal":
				base = Color("b66ad6") if kind == "elite" else Color("eb5868")
			var enemy_color: Color = base.lerp(Color("fff1db"), flash)
			var texture: Texture2D = art.texture(kind if kind != "normal" else variant,"run",simulation.elapsed)
			if texture:
				draw_texture_rect(texture,Rect2(at-Vector2(22,30),Vector2(44,52)),false,enemy_color.lightened(0.5))
			else:
				_draw_enemy_body(at, variant, enemy_color)
			if kind != "normal":
				draw_arc(at, 29.0 if kind == "elite" else 34.0, 0.0, TAU, 24, base, 3.0, true)
				if kind == "boss":
					draw_arc(at, 39.0, 0.0, TAU, 24, base, 1.5, true)
			draw_rect(Rect2(at + Vector2(-18, -29), Vector2(36, 4)), Color("302b2e"))
			draw_rect(Rect2(at + Vector2(-18, -29), Vector2(36.0 * enemy["hp"] / float(enemy.get("max_hp", 20)), 4)), Color("d98a8d"))
		if variant == "ranged" and float(enemy.windup) > 0.0:
			var target := _screen(enemy.aim)
			draw_line(at, target, Color(0.8, 0.4, 0.3, 0.5), 1.5, true)
			draw_arc(target, 8.0, 0, TAU, 16, Color("edb06e"), 1.5, true)
	for gold in simulation.gold_pickups:
		var at := _screen(gold["p"])
		draw_circle(at, 7.0, Color("edbc54"))
		draw_arc(at, 4.0, 0.0, TAU, 12, Color("fff0b3"), 1.2, true)
	for bullet in simulation.bullets:
		var at := _screen(bullet["p"])
		AttackVisuals.draw_projectile(self, at, bullet["direction"], str(bullet.get("source", "rifle")), simple_attacks)
	for bullet in simulation.enemy_bullets:
		var at := _screen(bullet.p)
		draw_line(at - bullet.velocity.normalized() * 10.0, at, Color("ed9268"), 2.0, true)
		draw_circle(at, 5.0, Color("f7ac6d"))
	for effect in simulation.effects:
		var effect_at: Vector2 = _screen(effect["p"])
		var link_from: Vector2 = _screen(effect.get("from", effect["p"]))
		AttackVisuals.draw_effect(self, effect_at, effect, link_from, simple_attacks)
	var center := _screen(simulation.player)
	var direction: Vector2 = simulation.facing
	var hero: Texture2D = art.texture("viya_battle", "hurt" if simulation.hurt_clock > 0.0 else "idle", simulation.elapsed)
	if hero:
		draw_texture_rect(hero,Rect2(center-Vector2(26,40),Vector2(52,68)),false)
	else:
		draw_circle(center + Vector2(0, 8), 23, Color(0, 0, 0, 0.5))
		draw_colored_polygon(PackedVector2Array([center - direction * 26.0, center + direction.orthogonal() * 12.0, center - direction.orthogonal() * 12.0]), Color("8e2b47"))
		var player_color := Color("fff1db") if simulation.hurt_clock > 0.5 else Color("cbbba1")
		draw_circle(center, 16.0, player_color)
		draw_line(center + direction * 6.0, center + direction * 34.0, Color("3a3e48"), 8.0, true)
		draw_arc(center, 24.0, 0.0, TAU, 36, Color("b69a65"), 1.4, true)
	_draw_approaches()
	_draw_combat_cues()

func _draw_enemy_body(at: Vector2, variant: String, color: Color) -> void:
	match variant:
		"ranged":
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -19), at + Vector2(18, 0), at + Vector2(0, 19), at + Vector2(-18, 0)]), color)
			draw_circle(at, 6.0, Color("283c32"))
		"heavy":
			draw_rect(Rect2(at - Vector2(17, 17), Vector2(34, 34)), color)
			draw_rect(Rect2(at - Vector2(12, 12), Vector2(24, 24)), Color("72533c"), false, 3.0)
		"fast":
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -22), at + Vector2(13, 16), at, at + Vector2(-13, 16)]), color)
		"flier":
			draw_polyline(PackedVector2Array([at + Vector2(-17, -8), at, at + Vector2(17, -8)]), color, 5.0, true)
			draw_circle(at, 6.0, color)
		_:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -20), at + Vector2(19, 13), at + Vector2(-19, 13)]), color)

func _draw_map(origin: Vector2) -> void:
	var visible := Rect2(simulation.camera_center()-size*0.5,size)
	var terrain: Texture2D = art.texture("terrain_" + simulation.map_id)
	if terrain:
		draw_texture_rect(terrain,Rect2(origin,simulation.world_size),false)
	for decor in simulation.map_space.definition.get("decor",[]):
		var box: Rect2 = simulation.MapCatalog.rectangle(decor.rect)
		if visible.intersects(box):
			var color: Color = {"gate":Color("6f573e"),"arrival":Color("40544b"),"lane":Color("4d4336")}.get(decor.kind,Color("454545"))
			draw_rect(Rect2(origin+box.position,box.size),color)
			if box.size.x < size.x:
				draw_string(get_theme_default_font(),origin+box.position+Vector2(12,24),str(decor.name),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("bdb09b"))
	for obstacle in simulation.map_space.definition.obstacles:
		var box: Rect2 = simulation.MapCatalog.rectangle(obstacle.rect)
		if not visible.intersects(box):
			continue
		var screen := Rect2(origin+box.position,box.size)
		draw_rect(screen,Color("65686a") if obstacle.kind == "wall" else Color("716453"))
		draw_rect(screen,Color("a59a81"),false,3)
		if obstacle.kind == "wall":
			for x in range(int(maxf(box.position.x,visible.position.x)/100.0)*100,int(minf(box.end.x,visible.end.x)),100):
				draw_line(origin+Vector2(x,box.position.y),origin+Vector2(x,box.end.y),Color("4d5155"),2)

	# Gate stays a visual slot above the solid city wall, never an open passage.
	for decor in simulation.map_space.definition.get("decor",[]):
		if decor.kind == "gate":
			var box: Rect2 = simulation.MapCatalog.rectangle(decor.rect)
			if visible.intersects(box):
				draw_rect(Rect2(origin+box.position,box.size),Color("6f573e"))
				draw_rect(Rect2(origin+box.position,box.size),Color("b29b71"),false,4)

func _draw_approaches() -> void:
	var visible := Rect2(simulation.camera_center()-size*0.5,size)
	for cue in ApproachCues.build(simulation,visible):
		var raw: Vector2 = _screen(cue.at)
		var at := raw.clamp(Vector2.ONE*20.0,size-Vector2.ONE*20.0)
		var direction := (raw-at).normalized()
		var side := direction.orthogonal()
		var color := Color("efa56c") if cue.kind == "shot" else Color("beb9ed")
		draw_colored_polygon(PackedVector2Array([at+direction*10,at-direction*8+side*7,at-direction*8-side*7]),color)
		var text := "!" if cue.kind == "shot" else str(cue.count)
		draw_string(get_theme_default_font(),at-direction*20+Vector2(-5,5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)

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
		if (kind == "xp" and not show_xp) or (kind == "hit" and not show_damage):
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
