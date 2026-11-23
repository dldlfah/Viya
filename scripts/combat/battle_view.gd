extends Control
## Debug shapes are deliberately not final Viya character art.
const AttackVisuals = preload("res://scripts/combat/attack_visuals.gd")
const ApproachCues = preload("res://scripts/combat/approach_cues.gd")
const BattleProjection = preload("res://scripts/combat/battle_projection.gd")
var camera = preload("res://scripts/combat/combat_camera.gd").new()
var high_angle: bool = true # F8: development-only comparison, never a gameplay rule.
var high_renderer = preload("res://scripts/combat/high_angle_battle.gd").new()
var art = preload("res://scripts/ui/asset_slots.gd").new()
var simulation
var show_damage: bool = true
var show_xp: bool = true
var simple_attacks: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func camera_center() -> Vector2:
	return camera.center(simulation,size)

func spawn_guard_size() -> Vector2:
	return camera.guard_size(size)

func advance_camera(delta: float, displacement: Vector2, active: bool) -> void:
	camera.advance(simulation.run_id,displacement,delta,active)

func world_to_screen(at: Vector2) -> Vector2:
	return BattleProjection.world_to_screen(at,camera_center(),size) if high_angle else at-camera_center()+size*.5

func screen_to_world(at: Vector2) -> Vector2:
	return BattleProjection.screen_to_world(at,camera_center(),size) if high_angle else at+camera_center()-size*.5

func world_view_size() -> Vector2:
	# The comparison toggle does not change saved viewport geometry or spawn RNG.
	# Unshifted extent; spawn_guard_size also covers the entire possible lead.
	return BattleProjection.world_view_size(size)

func _screen(at: Vector2) -> Vector2:
	return world_to_screen(at)

func _draw() -> void:
	if high_angle and simulation != null:
		high_renderer.draw(self)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("191c22") if simulation == null or simulation.map_id == "legacy_arena" else (Color("302d2a") if simulation.map_id == "prologue_wall" else Color("28352f")))
	if simulation == null:
		return
	var origin: Vector2 = size * 0.5 - camera_center()
	for x in range(int(-origin.x / 64.0) - 1, int((size.x - origin.x) / 64.0) + 2):
		draw_line(Vector2(origin.x + x * 64, 0), Vector2(origin.x + x * 64, size.y), Color("242832"))
	for y in range(int(-origin.y / 64.0) - 1, int((size.y - origin.y) / 64.0) + 2):
		draw_line(Vector2(0, origin.y + y * 64), Vector2(size.x, origin.y + y * 64), Color("242832"))
	_draw_map(origin)
	_draw_supplies()
	_draw_weapon_fields()
	draw_rect(Rect2(origin, simulation.world_size), Color("6c5c43"), false, 4.0)
	for pickup in simulation.pickups:
		var pos := _screen(pickup["p"])
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -7),
			pos + Vector2(5, 0), pos + Vector2(0, 7), pos + Vector2(-5, 0)]), Color("7cd3c1"))
	var names_left := 8
	for enemy in simulation.enemies:
		var at := _screen(enemy["p"])
		var variant: String = str(enemy.get("variant", "normal"))
		if Rect2(Vector2.ZERO, size).grow(30).has_point(at):
			draw_circle(at + Vector2(0, 5), 21, Color(0, 0, 0, 0.4))
			var flash: float = simulation.cues.flash_alpha(int(enemy["id"]))
			var kind: String = str(enemy.get("kind", "normal"))
			var base: Color = {"normal": Color("aa5364"), "ranged": Color("85ce95"), "fast": Color("6fcce6"), "heavy": Color("c39360"), "flier": Color("a6a8ed")}[variant]
			if enemy.get("species","")=="gold_slime":base=Color("e5bd42")
			if str(enemy.get("species","")).begins_with("skeleton_"):
				base = Color("d6d0c3")
			if kind != "normal":
				base = Color("b66ad6") if kind == "elite" else Color("eb5868")
			var enemy_color: Color = base.lerp(Color("fff1db"), flash)
			var texture: Texture2D = art.texture(kind if kind != "normal" else variant,"run",simulation.elapsed)
			if texture:
				draw_texture_rect(texture,Rect2(at-Vector2(22,30),Vector2(44,52)),false,enemy_color.lightened(0.5))
			elif enemy.get("species","")=="gold_slime":
				draw_circle(at+Vector2(0,2),18,enemy_color)
				draw_circle(at+Vector2(-6,-3),2,Color("3c3224"))
				draw_circle(at+Vector2(6,-3),2,Color("3c3224"))
				draw_arc(at+Vector2(-4,-5),6,PI,PI*1.5,8,Color("fff0a6"),2,true)
			else:
				_draw_enemy_body(at, variant, enemy_color)
			if kind != "normal":
				draw_arc(at, 29.0 if kind == "elite" else 34.0, 0.0, TAU, 24, base, 3.0, true)
				if kind == "boss":
					draw_arc(at, 39.0, 0.0, TAU, 24, base, 1.5, true)
			var weapon_status: Dictionary = enemy.get("weapon_status",{})
			if float(weapon_status.get("mark",0)) > 0:
				draw_polyline(PackedVector2Array([at+Vector2(-8,-40),at+Vector2(0,-48),at+Vector2(8,-40),at+Vector2(0,-32),at+Vector2(-8,-40)]),Color("ed759d"),2,true)
			if float(weapon_status.get("slow_left",0)) > 0:
				draw_arc(at,23,0,TAU,20,Color("8bcbe3"),1.3,true)
			draw_rect(Rect2(at + Vector2(-18, -29), Vector2(36, 4)), Color("302b2e"))
			draw_rect(Rect2(at + Vector2(-18, -29), Vector2(36.0 * enemy["hp"] / float(enemy.get("max_hp", 20)), 4)), Color("d98a8d"))
			if enemy.has("species") and (names_left>0 or kind!="normal"):
				var name: String = str(simulation.enemy_definition(enemy.species).name)
				var font: Font = get_theme_default_font()
				var label_at := at+Vector2(-font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x*0.5,-37)
				draw_string_outline(font,label_at,name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,2,Color("17191e"))
				draw_string(font,label_at,name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ece0c5"))
				names_left -= 1
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
		AttackVisuals.draw_projectile(self, at, bullet["direction"], str(bullet.get("source", "rifle")), simple_attacks, bool(bullet.get("weapon",{}).get("evolved",false)), bool(bullet.get("weapon",{}).get("fragment",false)))
	for bullet in simulation.enemy_bullets:
		var at := _screen(bullet.p)
		draw_line(at - bullet.velocity.normalized() * 10.0, at, Color("ed9268"), 2.0, true)
		if bullet.get("shot","") in ["arrow","javelin"]:
			var direction: Vector2 = bullet.velocity.normalized()
			var reach := 18.0 if bullet.shot=="javelin" else 11.0
			draw_line(at-direction*reach,at,Color("f7ac6d"),2.5,true)
			draw_polyline(PackedVector2Array([at-direction*7+direction.orthogonal()*4,at,at-direction*7-direction.orthogonal()*4]),Color("f7ac6d"),1.5,true)
		else:
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

func _draw_supplies() -> void:
	var visible := Rect2(Vector2.ZERO, size).grow(50.0)
	for structure in simulation.structures:
		var at := _screen(structure.p)
		if not visible.has_point(at):
			continue
		if structure.hp <= 0:
			draw_line(at+Vector2(-17,8),at+Vector2(5,3),Color("766553"),4)
			draw_line(at+Vector2(7,6),at+Vector2(20,11),Color("766553"),3)
			continue
		draw_circle(at+Vector2(0,11),26,Color(0,0,0,0.3))
		var base := Color("ac8657") if structure.style == "crate" else (Color("9c6e54") if structure.style == "urn" else Color("899085"))
		base = base.lerp(Color("fff1db"),simulation.cues.flash_alpha(int(structure.id)))
		match structure.style:
			"crate":
				draw_rect(Rect2(at-Vector2(22,20),Vector2(44,40)),base)
				draw_rect(Rect2(at-Vector2(18,16),Vector2(36,32)),Color("594532"),false,3)
				draw_line(at-Vector2(17,15),at+Vector2(17,15),Color("594532"),3)
				draw_line(at+Vector2(-17,15),at+Vector2(17,-15),Color("594532"),3)
			"urn":
				draw_circle(at,21,base)
				draw_rect(Rect2(at-Vector2(13,24),Vector2(26,8)),base.lightened(0.15))
				draw_arc(at,14,0.3,PI-0.3,12,Color("554138"),3)
			"debris":
				draw_colored_polygon(PackedVector2Array([at+Vector2(-24,16),at+Vector2(-17,-10),at+Vector2(4,-21),at+Vector2(24,12)]),base)
				draw_line(at+Vector2(4,-18),at+Vector2(-3,0),Color("424c47"),3)
		if structure.hp < structure.max_hp:
			draw_rect(Rect2(at+Vector2(-20,-33),Vector2(40,4)),Color("302b2e"))
			draw_rect(Rect2(at+Vector2(-20,-33),Vector2(40.0*structure.hp/structure.max_hp,4)),Color("c7b187"))
	for item in simulation.item_pickups:
		var at := _screen(item.p)
		if not visible.has_point(at):
			continue
		var color: Color = {"hp":Color("f58c9c"),"mp":Color("7abcf3"),"magnet":Color("f3ce79"),"purge":Color("cea2fa")}[item.kind]
		draw_circle(at,17,Color("20252c"))
		draw_arc(at,18,0,TAU,24,color,2,true)
		match item.kind:
			"hp":
				draw_line(at+Vector2(-9,0),at+Vector2(9,0),color,5)
				draw_line(at+Vector2(0,-9),at+Vector2(0,9),color,5)
			"mp":
				draw_colored_polygon(PackedVector2Array([at+Vector2(0,-11),at+Vector2(8,3),at+Vector2(0,10),at+Vector2(-8,3)]),color)
			"magnet":
				draw_arc(at,8,0,PI,14,color,5,true)
				draw_line(at+Vector2(-8,0),at+Vector2(-8,-9),color,5)
				draw_line(at+Vector2(8,0),at+Vector2(8,-9),color,5)
			"purge":
				draw_line(at-Vector2(8,8),at+Vector2(8,8),color,4)
				draw_line(at+Vector2(-8,8),at+Vector2(8,-8),color,4)

func _draw_weapon_fields() -> void:
	for event in simulation.weapon_events:
		var p: Dictionary = event.profile
		if p.mode not in ["zone","orbit","blast"]:
			continue
		var color: Color = {"gun":Color("e5b079"),"bow":Color("a6d89a"),"sword":Color("9cd9ee"),"magic":Color("b8a5ed")}[p.family]
		color.a = 0.55
		var at := _screen(simulation.player if p.follow else event.p)
		if p.mode == "orbit":
			for index in range(int(p.projectiles)):
				var angle: float = maxi(0,int(event.index)-1)*float(p.tick_gap)*float(p.orbit_speed)+TAU*index/int(p.projectiles)
				draw_circle(_screen(simulation.player)+Vector2.from_angle(angle)*float(p.orbit_radius),6,color)
		else:
			draw_arc(at,float(p.radius),0,TAU,40,color,2.0 if p.evolved else 1.0,true)
			if p.mode == "blast":
				draw_line(at-Vector2(8,0),at+Vector2(8,0),color,1.5,true)

func _draw_map(origin: Vector2) -> void:
	var visible := Rect2(camera_center()-size*0.5,size)
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
	var visible := Rect2(camera_center()-size*0.5,size)
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
		if kind == "item":
			var label: String = event.get("label", "")
			var text_at := at + Vector2(-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x*0.5,-48-progress*25)
			draw_string_outline(font,text_at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,17,3,Color("17191e",fraction))
			draw_string(font,text_at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("f5dfa6",fraction))
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
