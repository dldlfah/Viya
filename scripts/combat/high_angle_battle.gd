extends RefCounted
## One shared canvas, bounded visible tile loops and sorted draw commands.
## No actor nodes, RNG, simulation writes, dynamic lights or generated artwork.
const BattleProjection = preload("res://scripts/combat/battle_projection.gd")
const Visuals = preload("res://scripts/combat/attack_visuals.gd")
const Approaches = preload("res://scripts/combat/approach_cues.gd")
var canvas
var state
var ground: Transform2D
var visible: Rect2
var viewport: Rect2
var camera: Vector2
var stats: Dictionary = {}

func screen(at: Vector2) -> Vector2:
	return ground * at

func depth_commands(simulation, area: Rect2) -> Array:
	var commands: Array = []
	for enemy in simulation.enemies:
		if area.grow(120).has_point(enemy.p):commands.append({"layer":"enemy", "depth":float(enemy.p.y), "id":int(enemy.id), "value":enemy})
	for prop in simulation.structures:
		if area.grow(80).has_point(prop.p):commands.append({"layer":"prop", "depth":float(prop.p.y), "id":int(prop.id), "value":prop})
	var serial := 0
	for obstacle in simulation.map_space.definition.obstacles:
		var box: Rect2 = simulation.MapCatalog.rectangle(obstacle.rect)
		if area.grow(180).intersects(box):commands.append({"layer":"obstacle", "depth":box.end.y, "id":serial, "value":obstacle})
		serial += 1
	commands.append({"layer":"hero", "depth":float(simulation.player.y), "id":-1, "value":{}})
	commands.sort_custom(func(a,b):return a.depth < b.depth if a.depth != b.depth else a.id < b.id)
	return commands

func draw(view) -> void:
	canvas = view
	state = view.simulation
	camera = state.camera_center()
	ground = BattleProjection.transform(camera, view.size)
	visible = BattleProjection.visible_world(camera, view.size)
	viewport = Rect2(Vector2.ZERO, view.size)
	stats = {"tiles":0, "actors":0, "occluders":0, "commands":0}
	canvas.draw_rect(viewport, Color("171c20"))
	canvas.draw_set_transform_matrix(ground)
	_draw_ground()
	_draw_floor_effects()
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	var commands := depth_commands(state, visible)
	stats.commands = commands.size()
	for command in commands:
		match command.layer:
			"enemy":_draw_enemy(command.value)
			"hero":_draw_hero()
			"prop":_draw_prop(command.value)
			"obstacle":_draw_obstacle(command.value)
	# Ground-space effects use the SAME transform as their actual damage geometry.
	canvas.draw_set_transform_matrix(ground)
	for bullet in state.bullets:
		if visible.grow(50).has_point(bullet.p):Visuals.draw_projectile(canvas, bullet.p, bullet.direction, str(bullet.get("source","rifle")), canvas.simple_attacks, bool(bullet.get("weapon",{}).get("evolved",false)), bool(bullet.get("weapon",{}).get("fragment",false)))
	for bullet in state.enemy_bullets:
		if not visible.grow(30).has_point(bullet.p):continue
		var direction: Vector2 = bullet.velocity.normalized()
		canvas.draw_line(bullet.p-direction*18, bullet.p, Color("ff916b"), 3, true)
		canvas.draw_polyline(PackedVector2Array([bullet.p-direction*8+direction.orthogonal()*5,bullet.p,bullet.p-direction*8-direction.orthogonal()*5]),Color("ffd2a3"),2,true)
	for effect in state.effects:
		var reach: float = float(effect.get("radius",0))
		if visible.grow(reach+40).has_point(effect.p) or effect.has("from"):
			Visuals.draw_effect(canvas, effect.p, effect, effect.get("from",effect.p),canvas.simple_attacks)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	# Foreground identification remains visible even in a dense crowd.
	var feet := screen(state.player)
	canvas.draw_arc(feet, 20, 0, TAU, 28, Color("f5dc9c"), 2, true)
	canvas.draw_line(feet+Vector2(-5,0),feet+Vector2(5,0),Color("fff3c5"),2,true)
	if stats.occluders > 0:
		canvas.draw_polyline(PackedVector2Array([feet+Vector2(-14,-6),feet+Vector2(-10,-38),feet+Vector2(0,-54),feet+Vector2(11,-38),feet+Vector2(15,-6)]),Color("fff0bc"),2,true)
	_draw_approaches()
	canvas._draw_combat_cues()
	canvas = null
	state = null

func _draw_ground() -> void:
	var bounds := visible.grow(100).intersection(Rect2(Vector2.ZERO,state.world_size))
	var tile: Texture2D = canvas.art.texture("stone_floor_tile")
	var base := Color("343337") if state.map_id=="prologue_wall" else (Color("303a35") if state.map_id=="outskirts_trial" else Color("363529"))
	for y in range(floori(bounds.position.y/80), ceili(bounds.end.y/80)):
		for x in range(floori(bounds.position.x/112), ceili(bounds.end.x/112)):
			var box := Rect2(Vector2(x*112,y*80),Vector2(112,80))
			var shade := float(posmod(x*73+y*37,9))*0.008
			canvas.draw_rect(box,base.lightened(shade))
			if tile:canvas.draw_texture_rect(tile,box,false)
			else:
				canvas.draw_rect(box.grow(-1),Color("1c2124"),false,1)
				if posmod(x+y*3,7)==0:
					var start := box.position+Vector2(22,22)
					canvas.draw_polyline(PackedVector2Array([start,start+Vector2(12,10),start+Vector2(8,24),start+Vector2(24,32)]),Color("20272a"),1)
			stats.tiles += 1
	for decor in state.map_space.definition.get("decor",[]):
		if decor.kind=="gate":continue
		var box: Rect2 = state.MapCatalog.rectangle(decor.rect)
		if not visible.intersects(box):continue
		var color := Color("6e614a",.18) if decor.kind=="lane" else Color("668e80",.13)
		canvas.draw_rect(box,color)
	canvas.draw_rect(Rect2(Vector2.ZERO,state.world_size),Color("927753"),false,3)

func _draw_floor_effects() -> void:
	for enemy in state.enemies:
		if visible.grow(50).has_point(enemy.p):
			canvas.draw_circle(enemy.p,16 if enemy.kind=="normal" else 25,Color(0,0,0,.28))
		if enemy.get("variant","")=="ranged" and float(enemy.get("windup",0))>0:
			canvas.draw_line(enemy.p,enemy.aim,Color("ff936d",.7),2,true)
			canvas.draw_arc(enemy.aim,8,0,TAU,16,Color("ffb37f"),2,true)
			canvas.draw_line(enemy.aim-Vector2(10,0),enemy.aim+Vector2(10,0),Color("ffb37f"),1.5,true)
	canvas.draw_circle(state.player,19,Color(0,0,0,.35))
	for pickup in state.pickups:
		if visible.grow(10).has_point(pickup.p):
			var at: Vector2 = pickup.p
			canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-6),at+Vector2(5,0),at+Vector2(0,6),at-Vector2(5,0)]),Color("8ad4c5"))
	for gold in state.gold_pickups:
		if visible.grow(10).has_point(gold.p):canvas.draw_circle(gold.p,6,Color("efc364"))
	for item in state.item_pickups:
		if not visible.grow(20).has_point(item.p):continue
		var color: Color = {"hp":Color("f58c9c"),"mp":Color("7abcf3"),"magnet":Color("f3ce79"),"purge":Color("cea2fa")}[item.kind]
		canvas.draw_arc(item.p,15,0,TAU,20,color,2,true)
		canvas.draw_string(canvas.get_theme_default_font(),item.p+Vector2(-8,5),{"hp":"+","mp":"M","magnet":"U","purge":"X"}[item.kind],HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
	for event in state.weapon_events:
		var p: Dictionary = event.profile
		if p.mode not in ["zone","orbit","blast"]:continue
		var at: Vector2 = state.player if p.follow else event.p
		var color: Color = {"gun":Color("e5b079",.5),"bow":Color("a6d89a",.5),"sword":Color("9cd9ee",.5),"magic":Color("b8a5ed",.5)}[p.family]
		if p.mode=="orbit":
			for index in range(int(p.projectiles)):
				var angle: float = maxi(0,int(event.index)-1)*float(p.tick_gap)*float(p.orbit_speed)+TAU*index/int(p.projectiles)
				canvas.draw_circle(state.player+Vector2.from_angle(angle)*float(p.orbit_radius),6,color)
		else:canvas.draw_arc(at,float(p.radius),0,TAU,40,color,2 if p.evolved else 1,true)

func _draw_enemy(enemy: Dictionary) -> void:
	var feet := screen(enemy.p)
	if not viewport.grow(110).has_point(feet):return
	stats.actors += 1
	var variant: String = enemy.get("variant","normal")
	var kind: String = enemy.get("kind","normal")
	var color: Color = {"normal":Color("b07670"),"ranged":Color("91bd84"),"fast":Color("77c4d4"),"heavy":Color("bb966a"),"flier":Color("b4a4dd")}[variant]
	if enemy.get("species","")=="gold_slime":color=Color("e3bc48")
	if str(enemy.get("species","")).begins_with("skeleton_"):color=Color("d4ccaf")
	if kind!="normal":color=Color("bd85db") if kind=="elite" else Color("ee7777")
	color=color.lerp(Color("fff1db"),state.cues.flash_alpha(int(enemy.id)))
	var height: float = 92 if kind=="boss" else (66 if kind=="elite" else (50 if variant=="heavy" else 40))
	var texture: Texture2D = canvas.art.texture(kind if kind!="normal" else variant,"run",state.elapsed)
	if texture:canvas.draw_texture_rect(texture,Rect2(feet-Vector2(height*.4,height),Vector2(height*.8,height)),false)
	elif enemy.get("species","")=="gold_slime":
		canvas.draw_circle(feet+Vector2(0,-13),16,color)
		canvas.draw_circle(feet+Vector2(-5,-16),2,Color("403822"))
		canvas.draw_circle(feet+Vector2(5,-16),2,Color("403822"))
		if not canvas.simple_attacks:canvas.draw_arc(feet+Vector2(-3,-19),6,PI,PI*1.6,8,Color("fff0ac"),2,true)
	else:
		canvas.draw_set_transform(feet,0,Vector2.ONE*(height/40))
		canvas._draw_enemy_body(Vector2(0,-20),variant,color)
		canvas.draw_line(Vector2(-6,-10),Vector2(-7,0),color.darkened(.25),3,true)
		canvas.draw_line(Vector2(6,-10),Vector2(7,0),color.darkened(.25),3,true)
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	if kind!="normal" or enemy.hp < enemy.max_hp:
		canvas.draw_rect(Rect2(feet+Vector2(-18,-height-7),Vector2(36,3)),Color("302b2e"))
		canvas.draw_rect(Rect2(feet+Vector2(-18,-height-7),Vector2(36.0*enemy.hp/float(enemy.max_hp),3)),color)
	if kind!="normal":
		canvas.draw_polyline(PackedVector2Array([feet+Vector2(-12,-height-15),feet+Vector2(-7,-height-22),feet+Vector2(0,-height-16),feet+Vector2(7,-height-22),feet+Vector2(12,-height-15)]),color,2,true)
	var status: Dictionary = enemy.get("weapon_status",{})
	if float(status.get("mark",0))>0:canvas.draw_arc(feet+Vector2(0,-height-12),5,0,TAU,12,Color("ed759d"),2,true)
	if float(status.get("slow_left",0))>0:canvas.draw_arc(feet,19,0,TAU,16,Color("8bcbe3"),1.5,true)

func _draw_hero() -> void:
	var feet := screen(state.player)
	var texture: Texture2D = canvas.art.texture("viya_battle","hurt" if state.hurt_clock>0 else "idle",state.elapsed)
	if texture:canvas.draw_texture_rect(texture,Rect2(feet-Vector2(25,62),Vector2(50,62)),false)
	else:
		canvas.draw_colored_polygon(PackedVector2Array([feet+Vector2(-5,-45),feet+Vector2(-19,-5),feet+Vector2(1,-11),feet+Vector2(15,-3),feet+Vector2(9,-45)]),Color("9e3e51"))
		canvas.draw_line(feet+Vector2(-5,-16),feet+Vector2(-6,-1),Color("d1b792"),4,true)
		canvas.draw_line(feet+Vector2(6,-16),feet+Vector2(8,-1),Color("d1b792"),4,true)
		canvas.draw_circle(feet+Vector2(0,-46),8,Color("fff1db") if state.hurt_clock>.5 else Color("d1b792"))
		var direction: Vector2 = Vector2(state.facing.x,state.facing.y*BattleProjection.GROUND_Y).normalized()
		canvas.draw_line(feet+Vector2(1,-30),feet+Vector2(1,-30)+direction*29,Color("e1c486"),5,true)

func _draw_prop(prop: Dictionary) -> void:
	var feet := screen(prop.p)
	if prop.hp<=0:
		canvas.draw_line(feet-Vector2(14,2),feet+Vector2(16,3),Color("756c5c"),4,true)
		return
	var color := Color("a48254") if prop.style=="crate" else (Color("9c7159") if prop.style=="urn" else Color("8d8d7e"))
	var texture: Texture2D = canvas.art.texture("prop_"+prop.style)
	if texture:canvas.draw_texture_rect(texture,Rect2(feet-Vector2(23,43),Vector2(46,43)),false)
	else:
		canvas.draw_rect(Rect2(feet-Vector2(22,35),Vector2(44,35)),color.darkened(.18))
		canvas.draw_colored_polygon(PackedVector2Array([feet+Vector2(-22,-35),feet+Vector2(-13,-43),feet+Vector2(30,-43),feet+Vector2(22,-35)]),color.lightened(.12))
		canvas.draw_line(feet+Vector2(-16,-28),feet+Vector2(16,-5),Color("584936"),2,true)

func _draw_obstacle(obstacle: Dictionary) -> void:
	var box: Rect2 = state.MapCatalog.rectangle(obstacle.rect)
	var height: float = 122 if obstacle.kind=="wall" else 65
	var alpha := .28 if BattleProjection.occludes_player(box,height,state.player,camera,canvas.size) else 1.0
	if alpha<1:stats.occluders += 1
	var base := Rect2(screen(box.position),Vector2(box.size.x,box.size.y*BattleProjection.GROUND_Y))
	if not viewport.intersects(Rect2(base.position-Vector2(0,height),base.size+Vector2(0,height))):return
	var top := Rect2(base.position-Vector2(0,height),base.size)
	var stone := Color("56575b",alpha)
	canvas.draw_rect(top,stone.lightened(.13))
	canvas.draw_rect(Rect2(Vector2(base.position.x,top.end.y),Vector2(base.size.x,height)),stone.darkened(.16))
	canvas.draw_rect(top,Color("b39b73",alpha),false,2)
	var texture: Texture2D = canvas.art.texture("wall_segment" if obstacle.kind=="wall" else "ruin_block")
	if texture:
		for x in range(floori(maxf(base.position.x,0)/96)*96,ceili(minf(base.end.x,canvas.size.x)),96):
			canvas.draw_texture_rect(texture,Rect2(Vector2(x,top.end.y),Vector2(96,height)),false,Color(1,1,1,alpha))
	else:
		for x in range(floori(maxf(base.position.x,0)/64)*64,ceili(minf(base.end.x,canvas.size.x)),64):
			canvas.draw_line(Vector2(x,top.end.y),Vector2(x,base.end.y),Color("2c3035",alpha),2,true)
			if obstacle.kind=="wall":canvas.draw_rect(Rect2(Vector2(x,top.end.y-12),Vector2(34,12)),Color("929080",alpha))
	for decor in state.map_space.definition.get("decor",[]):
		if decor.kind!="gate":continue
		var door: Rect2 = state.MapCatalog.rectangle(decor.rect)
		if not box.encloses(door):continue
		var at := screen(Vector2(door.position.x,door.end.y))
		canvas.draw_rect(Rect2(at-Vector2(0,height-8),Vector2(door.size.x,height-8)),Color("473b32",alpha))
		canvas.draw_rect(Rect2(at-Vector2(0,height-8),Vector2(door.size.x,height-8)),Color("b39b73",alpha),false,3)

func _draw_approaches() -> void:
	for cue in Approaches.build(state,visible):
		var raw := screen(cue.at)
		var at := raw.clamp(Vector2.ONE*20,canvas.size-Vector2.ONE*20)
		var direction := (raw-at).normalized()
		var side := direction.orthogonal()
		var color := Color("ffa16f") if cue.kind=="shot" else Color("bfb0ee")
		canvas.draw_colored_polygon(PackedVector2Array([at+direction*10,at-direction*8+side*7,at-direction*8-side*7]),color)
		canvas.draw_string(canvas.get_theme_default_font(),at-direction*20+Vector2(-4,5),"!" if cue.kind=="shot" else str(cue.count),HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
