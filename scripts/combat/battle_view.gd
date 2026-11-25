extends Control
## Debug shapes are deliberately not final Viya character art.
const AttackVisuals = preload("res://scripts/combat/attack_visuals.gd")
const ApproachCues = preload("res://scripts/combat/approach_cues.gd")
const BattleProjection = preload("res://scripts/combat/battle_projection.gd")
const ObliqueProjection = preload("res://scripts/combat/oblique_projection.gd")
var oblique_enabled:bool=true # Diagnostic only; no saved rule or rotating camera.
var _tilt_player:=Vector2.INF
var _tilt_offset:=Vector2.INF
var _tilt_size:=Vector2.ZERO
var _tilt_run:String=""
var _tilt_matrix:=Transform2D.IDENTITY # One derived transform, never one per actor.
const Display=preload("res://scripts/combat/combat_display.gd")
const BossGuidance=preload("res://scripts/combat/boss_guidance.gd")
const SupplyFeedback=preload("res://scripts/combat/supply_feedback.gd")
const PurgeFeedback=preload("res://scripts/combat/purge_feedback.gd")
const IncomingFeedback=preload("res://scripts/combat/incoming_feedback.gd")
var incoming_plan:Dictionary={}
var boss_guidance:Dictionary={}
var auto_display:bool=true # Diagnostic comparison; no gameplay/save setting.
var display_plan:Dictionary={}
var camera = preload("res://scripts/combat/combat_camera.gd").new()
var high_angle: bool = true # F8: development-only comparison, never a gameplay rule.
var high_renderer = preload("res://scripts/combat/high_angle_battle.gd").new()
var art = preload("res://scripts/ui/asset_slots.gd").new()
var actor_art=preload("res://scripts/ui/actor_assets.gd").new()
var actors=preload("res://scripts/combat/actor_motion.gd").new()
var viya=preload("res://scripts/combat/viya_presentation.gd").new()
var simulation
var show_damage: bool = true
var show_xp: bool = true
var simple_attacks: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func camera_center() -> Vector2:
	if uses_oblique():
		var extent:Vector2=BattleProjection.world_view_size(size)
		var lag:Vector2=camera.offset*extent if camera.run_id==simulation.run_id and camera._initialized and camera._viewport==size else Vector2.ZERO
		var projected:Vector2=ObliqueProjection.screen_direction(lag,size)
		var fraction:float=minf(1,minf(size.x*.08/maxf(.001,absf(projected.x)),size.y*.08/maxf(.001,absf(projected.y))))
		var target:Vector2=simulation.player+lag*fraction
		var center:Vector2=target if simulation.map_id=="legacy_arena" else simulation.map_space.camera_center(target,ObliqueProjection.world_view_size(size))
		return ObliqueProjection.keep_player_visible(simulation.player,center,size)
	return camera.center(simulation,size)

func spawn_guard_size() -> Vector2:
	return world_view_size()*(1.0+2.0*camera.MAX_OFFSET_FRACTION)

func advance_camera(delta: float, displacement: Vector2, active: bool) -> void:
	camera.advance(simulation,size,displacement,delta,active)

func uses_oblique() -> bool:
	return high_angle and oblique_enabled and simulation!=null

func ground_transform() -> Transform2D:
	if not uses_oblique():return BattleProjection.transform(camera_center(),size)
	if _tilt_player!=simulation.player or _tilt_offset!=camera.offset or _tilt_size!=size or _tilt_run!=simulation.run_id:
		_tilt_player=simulation.player;_tilt_offset=camera.offset;_tilt_size=size;_tilt_run=simulation.run_id
		_tilt_matrix=ObliqueProjection.transform(camera_center(),size)
	return _tilt_matrix

func ground_visible() -> Rect2:
	return ground_transform().affine_inverse()*Rect2(Vector2.ZERO,size) if uses_oblique() else BattleProjection.visible_world(camera_center(),size)

func approach_cues() -> Array:
	var area:Rect2=ground_visible() if high_angle else Rect2(camera_center()-size*.5,size)
	var test:Callable=func(at:Vector2):return Rect2(Vector2.ZERO,size).has_point(world_to_screen(at))
	return ApproachCues.build(simulation,area,test) if uses_oblique() else ApproachCues.build(simulation,area)

func input_direction(value:Vector2) -> Vector2:
	return ObliqueProjection.input_direction(value,size) if uses_oblique() else value

func project_direction(value:Vector2) -> Vector2:
	if not high_angle:return value
	var basis:Transform2D=ground_transform()
	return basis.x*value.x+basis.y*value.y

func world_to_screen(at: Vector2) -> Vector2:
	return ground_transform()*at if high_angle else at-camera_center()+size*.5

func screen_to_world(at: Vector2) -> Vector2:
	return ground_transform().affine_inverse()*at if high_angle else at+camera_center()-size*.5

func world_view_size() -> Vector2:
	# Layout feeds this actual display footprint into the existing viewport input.
	return ObliqueProjection.world_view_size(size) if uses_oblique() else BattleProjection.world_view_size(size)

func _screen(at: Vector2) -> Vector2:
	return world_to_screen(at)

func actor_visual(enemy:Dictionary={}) -> Dictionary:
	var data:Dictionary=actors.pose(simulation,int(enemy.get("id",0)))
	if uses_oblique():data.direction=actors.DIRECTIONS[posmod(roundi(project_direction(data.facing).angle()/(PI/4)),8)]
	var keys:Array=["viya_battle"]
	if not enemy.is_empty():keys=[str(enemy.get("species","")),str(enemy.kind if enemy.kind!="normal" else enemy.get("variant","normal"))]
	data.sample=actor_art.frame(art,keys,data.pose,data.direction,data.clock,size)
	if enemy.is_empty() and not data.sample.is_empty():viya.apply(self,data)
	return data

func tracks_enemy_motion() -> bool:
	# The blank-art slime fallback has no gait; avoid unused per-slime observers.
	return simulation.run_mode!="gold_slime" or art.definitions.get("gold_slime","")!="" or art.definitions.get("normal","")!=""

func _draw() -> void:
	if simulation!=null:boss_guidance=BossGuidance.build(self)
	if simulation!=null:incoming_plan=IncomingFeedback.build(self)
	if simulation!=null:display_plan=Display.build(self)
	if high_angle and simulation != null:
		high_renderer.draw(self)
		BossGuidance.draw(self,boss_guidance)
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
		if Rect2(Vector2.ZERO,size).grow(32).has_point(pos):
			_draw_loot_trail(pickup,false)
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
			var visual:Dictionary=actor_visual(enemy)
			if not visual.sample.is_empty():
				draw_texture_rect(visual.sample.texture,actor_art.rectangle(visual.sample,at),false,Color.WHITE.lerp(Color(1.8,1.8,1.8),flash))
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

	for gold in simulation.gold_pickups:
		var at := _screen(gold["p"])
		if Rect2(Vector2.ZERO,size).grow(32).has_point(at):
			_draw_loot_trail(gold,true)
		draw_circle(at, 7.0, Color("edbc54"))
		draw_arc(at, 4.0, 0.0, TAU, 12, Color("fff0b3"), 1.2, true)
	for bullet in simulation.bullets:
		var at := _screen(bullet["p"])
		var shown:Dictionary=viya.projectile(self,bullet)
		AttackVisuals.draw_projectile(self, shown.p, shown.direction, str(bullet.get("source", "rifle")), display_plan.simple, bool(bullet.get("weapon",{}).get("evolved",false)), bool(bullet.get("weapon",{}).get("fragment",false)))

	for effect in display_plan.effects:
		var effect_at: Vector2 = _screen(effect["p"])
		var link_from: Vector2 = _screen(effect.get("from", effect["p"]))
		AttackVisuals.draw_effect(self, effect_at, effect, link_from, display_plan.simple)
	var center := _screen(simulation.player)
	var hero:Dictionary=actor_visual()
	var direction: Vector2 = hero.facing
	if not hero.sample.is_empty():
		viya.draw(self,actor_art,hero,center)
	else:
		draw_circle(center + Vector2(0, 8), 23, Color(0, 0, 0, 0.5))
		draw_colored_polygon(PackedVector2Array([center - direction * 26.0, center + direction.orthogonal() * 12.0, center - direction.orthogonal() * 12.0]), Color("8e2b47"))
		var player_color := Color("fff1db") if simulation.hurt_clock > 0.5 else Color("cbbba1")
		draw_circle(center, 16.0, player_color)
		draw_line(center + direction * 6.0, center + direction * 34.0, Color("3a3e48"), 8.0, true)
	PurgeFeedback.draw(self)
	_draw_combat_cues()
	IncomingFeedback.draw(self,incoming_plan)
	_draw_foreground_threats()
	_draw_approaches()
	BossGuidance.draw(self,boss_guidance)

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
	_draw_supply_items()

func _draw_loot_trail(pickup:Dictionary,gold:bool) -> void:
	draw_set_transform(_screen(Vector2.ZERO))
	simulation.LootAttraction.draw_trail(self,pickup,simulation.player,gold)
	draw_set_transform(Vector2.ZERO)

func _draw_supply_items() -> void:
	var visible:=Rect2(Vector2.ZERO,size).grow(22)
	var compact:bool=size.x<900 or size.y<350
	for item in simulation.item_pickups:
		var at:=_screen(item.p)
		if visible.has_point(at):SupplyFeedback.draw_item(self,at,str(item.kind),compact)
	for chest in simulation.chest_pickups:
		var at:=_screen(chest.p)
		if visible.has_point(at):SupplyFeedback.draw_item(self,at,"chest",compact)

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

func _draw_foreground_threats() -> void:
	# Never reduced by friendly-attack/text budgets; always above their decoration.
	for enemy in simulation.enemies:
		if enemy.get("variant","")!="ranged" or float(enemy.get("windup",0))<=0:continue
		var at:Vector2=_screen(enemy.p)
		var aim:Vector2=_screen(enemy.aim)
		draw_line(at,aim,Color("ff936d",.8),2,true)
		draw_arc(aim,8,0,TAU,16,Color("ffb37f"),2,true)
		draw_line(aim-Vector2(10,0),aim+Vector2(10,0),Color("ffb37f"),1.5,true)
	for bullet in simulation.enemy_bullets:
		var at:Vector2=_screen(bullet.p)
		if not Rect2(Vector2.ZERO,size).grow(30).has_point(at):continue
		if simulation.enemy_patterns.is_curse(simulation,bullet):
			preload("res://scripts/combat/curse_visuals.gd").draw_bullet(self,bullet)
			continue
		var direction:Vector2=bullet.velocity.normalized()
		var start:Vector2=_screen(bullet.p-direction*18)
		var d:Vector2=(at-start).normalized()
		draw_line(start,at,Color("ff916b"),3,true)
		if bullet.get("shot","") in ["arrow","javelin"]:
			draw_polyline(PackedVector2Array([at-d*8+d.orthogonal()*5,at,at-d*8-d.orthogonal()*5]),Color("ffd2a3"),2,true)
		else:draw_circle(at,5,Color("ffd2a3"))

func _draw_combat_cues() -> void:
	preload("res://scripts/combat/enemy_pattern_visuals.gd").draw(self)
	if not simulation.cues.enabled:return
	preload("res://scripts/combat/structure_feedback.gd").draw(self,display_plan.get("structures",[]))
	var font:Font=get_theme_default_font()
	for event in display_plan.get("kills",[]):
		var fraction:float=clampf(float(event.life)/float(event.duration),0,1)
		draw_arc(_screen(event.p),12+(1-fraction)*15,0,TAU,16,Color("d98a8d",fraction),2,true)
	for label in display_plan.get("labels",[]):
		var color:Color=label.color
		draw_string_outline(font,label.at,label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size,2,Color(.03,.03,.04,color.a))
		draw_string(font,label.at,label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size,color)
