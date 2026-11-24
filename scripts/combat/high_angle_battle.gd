extends RefCounted
## One shared canvas, bounded visible tile loops and sorted draw commands.
## No actor nodes, RNG, simulation writes or dynamic lights.
const BattleProjection = preload("res://scripts/combat/battle_projection.gd")
const Visuals = preload("res://scripts/combat/attack_visuals.gd")
const Approaches = preload("res://scripts/combat/approach_cues.gd")
const CombatSkin=preload("res://scripts/ui/combat_skin.gd")
const Forms=preload("res://scripts/combat/battle_forms.gd")
const Battlefield=preload("res://scripts/combat/battlefield_presentation.gd")
const ObliqueScenery=preload("res://scripts/combat/oblique_scenery.gd")
const ObliqueProjection=preload("res://scripts/combat/oblique_projection.gd")
var materials=CombatSkin.new()
var detail_actors:bool=true
var canvas
var state
var ground: Transform2D
var visible: Rect2
var viewport: Rect2
var camera: Vector2
var stats: Dictionary = {}

func screen(at: Vector2) -> Vector2:
	return ground * at

func depth_commands(simulation, area: Rect2, oblique:bool=false) -> Array:
	var commands: Array = []
	for enemy in simulation.enemies:
		if area.grow(120).has_point(enemy.p):commands.append({"layer":"enemy", "depth":ObliqueProjection.depth(enemy.p) if oblique else float(enemy.p.y), "id":int(enemy.id), "value":enemy})
	for prop in simulation.structures:
		if area.grow(80).has_point(prop.p):commands.append({"layer":"prop", "depth":ObliqueProjection.depth(prop.p) if oblique else float(prop.p.y), "id":int(prop.id), "value":prop})
	var serial := 0
	for obstacle in simulation.map_space.definition.obstacles:
		var box: Rect2 = simulation.MapCatalog.rectangle(obstacle.rect)
		if area.grow(260 if oblique else 180).intersects(box):commands.append({"layer":"obstacle", "depth":ObliqueProjection.depth(Vector2(box.position.x,box.end.y)) if oblique else box.end.y, "id":serial, "value":obstacle})
		serial += 1
	commands.append({"layer":"hero", "depth":ObliqueProjection.depth(simulation.player) if oblique else float(simulation.player.y), "id":-1, "value":{}})
	commands.sort_custom(func(a,b):return a.depth < b.depth if a.depth != b.depth else a.id < b.id)
	return commands

func draw(view) -> void:
	canvas = view
	state = view.simulation
	camera = canvas.camera_center()
	ground = view.ground_transform()
	visible = view.ground_visible()
	viewport = Rect2(Vector2.ZERO, view.size)
	stats = {"tiles":0, "actors":0, "occluders":0, "commands":0}
	canvas.draw_rect(viewport, Color("171c20"))
	canvas.draw_set_transform_matrix(ground)
	_draw_ground()
	_draw_floor_effects()
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	var commands := depth_commands(state, visible, view.uses_oblique())
	stats.commands = commands.size()
	detail_actors=not view.display_plan.simple and commands.size()<=125
	stats.detailed_actors=detail_actors
	stats.display_dense=view.display_plan.dense
	stats.labels=view.display_plan.labels.size()
	stats.effects=view.display_plan.effects.size()
	stats.skipped_links=view.display_plan.skipped_links
	for command in commands:
		match command.layer:
			"enemy":_draw_enemy(command.value)
			"hero":_draw_hero()
			"prop":_draw_prop(command.value)
			"obstacle":_draw_obstacle(command.value)
	# Ground-space effects use the SAME transform as their actual damage geometry.
	canvas.draw_set_transform_matrix(ground)
	for bullet in state.bullets:
		if visible.grow(50).has_point(bullet.p):Visuals.draw_projectile(canvas, bullet.p, bullet.direction, str(bullet.get("source","rifle")), canvas.display_plan.simple, bool(bullet.get("weapon",{}).get("evolved",false)), bool(bullet.get("weapon",{}).get("fragment",false)))

	for effect in canvas.display_plan.effects:
		var reach: float = float(effect.get("radius",0))
		if visible.grow(reach+40).has_point(effect.p) or effect.has("from"):
			Visuals.draw_effect(canvas, effect.p, effect, effect.get("from",effect.p),canvas.display_plan.simple)
			if effect.get("kind","")=="ultimate" and reach>0 and not canvas.display_plan.simple:
				var alpha:float=clampf(float(effect.life)/maxf(.001,float(effect.get("duration",.25))),0,1)
				CombatSkin.rune(canvas,effect.p,reach*.78,Color("d95b75",alpha*.8),true)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	canvas.PurgeFeedback.draw(canvas)
	canvas._draw_combat_cues()
	canvas.IncomingFeedback.draw(canvas,canvas.incoming_plan)
	canvas._draw_foreground_threats()
	# Foreground identification remains visible even in a dense crowd.
	var feet := screen(state.player)
	canvas.draw_arc(feet, 20, 0, TAU, 28, Color("f5dc9c"), 2, true)
	canvas.draw_line(feet+Vector2(-5,0),feet+Vector2(5,0),Color("fff3c5"),2,true)
	if stats.occluders > 0:
		canvas.draw_polyline(PackedVector2Array([feet+Vector2(-14,-6),feet+Vector2(-10,-38),feet+Vector2(0,-54),feet+Vector2(11,-38),feet+Vector2(15,-6)]),Color("fff0bc"),2,true)
	_draw_approaches()
	canvas = null
	state = null

func _draw_ground() -> void:
	var bounds := visible.grow(100).intersection(Rect2(Vector2.ZERO,state.world_size))
	var tile: Texture2D = canvas.art.map_texture("stone_floor_tile",state.map_id)
	if not tile:tile=materials.floor_tile(state.map_id)
	for y in range(floori(bounds.position.y/80), ceili(bounds.end.y/80)):
		for x in range(floori(bounds.position.x/112), ceili(bounds.end.x/112)):
			var box := Rect2(Vector2(x*112,y*80),Vector2(112,80))
			canvas.draw_texture_rect(tile,box,false)
			stats.tiles += 1
	for decor in state.map_space.definition.get("decor",[]):
		if decor.kind in ["gate","arrival"]:continue
		var box: Rect2 = state.MapCatalog.rectangle(decor.rect)
		if not visible.intersects(box):continue
		var color := Color("6e614a",.07) if decor.kind=="lane" else Color("668e80",.13)
		canvas.draw_rect(box,color)
	if state.map_id=="siege_battlefield":Battlefield.draw_ground(self)
	canvas.draw_rect(Rect2(Vector2.ZERO,state.world_size),Color("927753"),false,3)

func _draw_floor_effects() -> void:
	for enemy in state.enemies:
		if visible.grow(50).has_point(enemy.p):
			canvas.draw_circle(enemy.p,16 if enemy.kind=="normal" else 25,Color(0,0,0,.28))

	canvas.draw_circle(state.player,19,Color(0,0,0,.35))
	for pickup in state.pickups:
		if visible.grow(32).has_point(pickup.p):
			var at: Vector2 = pickup.p
			state.LootAttraction.draw_trail(canvas,pickup,state.player,false)
			canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-6),at+Vector2(5,0),at+Vector2(0,6),at-Vector2(5,0)]),Color("8ad4c5"))
	for gold in state.gold_pickups:
		if visible.grow(32).has_point(gold.p):
			state.LootAttraction.draw_trail(canvas,gold,state.player,true)
			canvas.draw_circle(gold.p,6,Color("efc364"))
	# Supply badges stay upright and the same screen size in both renderers.
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	canvas._draw_supply_items()
	canvas.draw_set_transform_matrix(ground)
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
	var visual:Dictionary=canvas.actor_visual(enemy)
	if not visual.sample.is_empty():canvas.draw_texture_rect(visual.sample.texture,canvas.actor_art.rectangle(visual.sample,feet),false,Color.WHITE.lerp(Color(1.8,1.8,1.8),state.cues.flash_alpha(int(enemy.id))))
	elif enemy.get("species","")=="gold_slime":
		canvas.draw_circle(feet+Vector2(0,-13),16,color)
		canvas.draw_circle(feet+Vector2(-5,-16),2,Color("403822"))
		canvas.draw_circle(feet+Vector2(5,-16),2,Color("403822"))
		if not canvas.simple_attacks:canvas.draw_arc(feet+Vector2(-3,-19),6,PI,PI*1.6,8,Color("fff0ac"),2,true)
	else:
		Forms.enemy(canvas,feet,variant,color,height,detail_actors or kind!="normal",visual)
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
	var visual:Dictionary=canvas.actor_visual()
	if not visual.sample.is_empty():canvas.draw_texture_rect(visual.sample.texture,canvas.actor_art.rectangle(visual.sample,feet),false)
	else:
		var direction: Vector2 = canvas.project_direction(visual.facing).normalized()
		Forms.hero(canvas,feet,direction,state.hurt_clock>.5,visual)

func _draw_prop(prop: Dictionary) -> void:
	var feet := screen(prop.p)
	if prop.hp<=0:
		var broken: Texture2D = canvas.art.map_texture("prop_"+prop.style+"_broken",state.map_id)
		if broken:
			canvas.draw_texture_rect(broken,Rect2(feet-Vector2(23,43),Vector2(46,43)),false)
			return
		canvas.draw_line(feet-Vector2(14,2),feet+Vector2(16,3),Color("756c5c"),4,true)
		return
	var color := Color("a48254") if prop.style=="crate" else (Color("9c7159") if prop.style=="urn" else Color("8d8d7e"))
	var flash:float=state.cues.flash_alpha(int(prop.id))
	color=color.lerp(Color("fff1db"),flash)
	var texture: Texture2D = canvas.art.map_texture("prop_"+prop.style,state.map_id)
	if texture:canvas.draw_texture_rect(texture,Rect2(feet-Vector2(23,43),Vector2(46,43)),false,Color.WHITE.lerp(Color(1.8,1.8,1.8),flash))
	elif prop.style=="urn":
		canvas.draw_circle(feet-Vector2(0,20),17,color.darkened(.15))
		canvas.draw_rect(Rect2(feet-Vector2(10,39),Vector2(20,10)),color)
		canvas.draw_arc(feet-Vector2(0,37),10,0,TAU,18,color.lightened(.2),3,true)
		canvas.draw_arc(feet-Vector2(0,23),13,PI,TAU,14,color.lightened(.2),2,true)
	elif prop.style=="debris":
		for index in range(3):
			var at:=feet+Vector2(index*12-18,-index%2*7)
			canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-10,0),at+Vector2(-6,-16),at+Vector2(5,-19),at+Vector2(12,-2)]),color.darkened(index*.12))
	else:
		canvas.draw_rect(Rect2(feet-Vector2(22,35),Vector2(44,35)),color.darkened(.18))
		canvas.draw_colored_polygon(PackedVector2Array([feet+Vector2(-22,-35),feet+Vector2(-13,-43),feet+Vector2(30,-43),feet+Vector2(22,-35)]),color.lightened(.12))
		for index in range(3):canvas.draw_line(feet+Vector2(-21,-10-index*10),feet+Vector2(22,-10-index*10),Color("57402e"),1,true)
		canvas.draw_line(feet+Vector2(-17,-30),feet+Vector2(16,-5),Color("d1aa6e"),3,true)
	if prop.hp<prop.max_hp:
		canvas.draw_rect(Rect2(feet-Vector2(20,49),Vector2(40,3)),Color("342b2b"))
		canvas.draw_rect(Rect2(feet-Vector2(20,49),Vector2(40.0*prop.hp/prop.max_hp,3)),Color("c7a674"))

static func material_regions(world:Rect2,front:Rect2,window:Rect2,texture_size:Vector2) -> Array:
	# X is unrotated world distance. Clip both the wall face and the viewport,
	# retaining the matching source subrectangle instead of stretching edge tiles.
	var result:Array=[]
	var visible_front:Rect2=front.intersection(window)
	if not visible_front.has_area():return result
	var first:float=world.position.x+visible_front.position.x-front.position.x
	var last:float=world.position.x+visible_front.end.x-front.position.x
	var scale:Vector2=texture_size/Vector2(96,front.size.y)
	for x in range(floori(first/96)*96,ceili(last),96):
		var tile:=Rect2(Vector2(front.position.x+x-world.position.x,front.position.y),Vector2(96,front.size.y))
		var destination:Rect2=tile.intersection(front).intersection(window)
		if not destination.has_area():continue
		result.append({"destination":destination,"source":Rect2((destination.position-tile.position)*scale,destination.size*scale)})
	return result

static func top_material_regions(world:Rect2,top:Rect2,window:Rect2,texture_size:Vector2) -> Array:
	# The screen top is already projected. Anchor both UV axes to world space,
	# and crop source pixels together with each visible destination rectangle.
	var result:Array=[]
	if not world.has_area() or not top.has_area() or texture_size.x<=0 or texture_size.y<=0:return result
	var clipped:Rect2=top.intersection(window)
	if not clipped.has_area():return result
	var projection:Vector2=top.size/world.size
	var first:Vector2=world.position+(clipped.position-top.position)/projection
	var last:Vector2=world.position+(clipped.end-top.position)/projection
	var tile_size:=Vector2(96,80)*projection
	var scale:Vector2=texture_size/tile_size
	for y in range(floori(first.y/80)*80,ceili(last.y),80):
		for x in range(floori(first.x/96)*96,ceili(last.x),96):
			var tile:=Rect2(top.position+(Vector2(x,y)-world.position)*projection,tile_size)
			var destination:Rect2=tile.intersection(top).intersection(window)
			if destination.has_area():result.append({"destination":destination,"source":Rect2((destination.position-tile.position)*scale,destination.size*scale)})
	return result

func _draw_obstacle(obstacle: Dictionary) -> void:
	if canvas.uses_oblique():
		if ObliqueScenery.draw(self,obstacle):stats.occluders += 1
		return
	var box: Rect2 = state.MapCatalog.rectangle(obstacle.rect)
	var height: float = float(obstacle.get("visual_height",122 if obstacle.kind=="wall" else 65))
	var alpha := .28 if BattleProjection.occludes_player(box,height,state.player,camera,canvas.size) else 1.0
	if alpha<1:stats.occluders += 1
	var base := Rect2(screen(box.position),Vector2(box.size.x,box.size.y*BattleProjection.GROUND_Y))
	if not viewport.intersects(Rect2(base.position-Vector2(0,height),base.size+Vector2(0,height))):return
	if state.map_id=="siege_battlefield" and obstacle.kind=="barricade":
		Battlefield.draw_barricade(self,box,base,height,alpha)
		return
	var top := Rect2(base.position-Vector2(0,height),base.size)
	var stone := Color("56575b",alpha)
	var top_texture:Texture2D=canvas.art.map_texture("wall_top_tile" if obstacle.kind=="wall" else "ruin_top_tile",state.map_id)
	if top_texture:
		for region in top_material_regions(box,top,viewport,top_texture.get_size()):
			canvas.draw_texture_rect_region(top_texture,region.destination,region.source,Color(1,1,1,alpha))
	else:canvas.draw_rect(top,stone.lightened(.13))
	canvas.draw_rect(Rect2(Vector2(base.position.x,top.end.y),Vector2(base.size.x,height)),stone.darkened(.16))
	canvas.draw_rect(top,Color("b39b73",alpha),false,2)
	var texture: Texture2D = canvas.art.map_texture("wall_segment" if obstacle.kind=="wall" else "ruin_block",state.map_id)
	if texture:
		var front:=Rect2(Vector2(base.position.x,top.end.y),Vector2(base.size.x,height))
		for region in material_regions(box,front,viewport,texture.get_size()):
			canvas.draw_texture_rect_region(texture,region.destination,region.source,Color(1,1,1,alpha))
	else:
		for row in range(4):
			var y:float=top.end.y+row*height/4
			for x in range(floori(maxf(base.position.x,0)/80)*80-40,ceili(minf(base.end.x,canvas.size.x)),80):
				var left:float=maxf(base.position.x,x+(40 if row%2 else 0))
				var right:float=minf(base.end.x,x+(40 if row%2 else 0)+78)
				if right<=left:continue
				canvas.draw_rect(Rect2(Vector2(left,y+1),Vector2(right-left,height/4-2)),Color("414149",alpha).lightened(float(posmod(x+row,5))*.018))
				canvas.draw_line(Vector2(left+1,y+2),Vector2(right-1,y+2),Color("8e8171",alpha*.5),1,true)
		if obstacle.kind=="wall":
			for x in range(floori(maxf(base.position.x,0)/160)*160,ceili(minf(base.end.x,canvas.size.x)),160):
				canvas.draw_rect(Rect2(Vector2(x,top.end.y-13),Vector2(44,13)),Color("7d7a73",alpha))
			for x in range(floori(maxf(base.position.x,0)/350)*350,ceili(minf(base.end.x,canvas.size.x)),350):
				var p:=Vector2(x+50,top.end.y+4)
				canvas.draw_colored_polygon(PackedVector2Array([p,p+Vector2(42,0),p+Vector2(42,76),p+Vector2(20,67),p+Vector2(0,78)]),Color("773544",alpha))
				canvas.draw_line(p+Vector2(6,0),p+Vector2(6,69),Color("b18a58",alpha),1,true)
				canvas.draw_line(p+Vector2(35,0),p+Vector2(35,68),Color("b18a58",alpha),1,true)
				canvas.draw_line(p+Vector2(20,17),p+Vector2(20,43),Color("d1b783",alpha),2,true)
				canvas.draw_line(p+Vector2(10,29),p+Vector2(30,29),Color("d1b783",alpha),2,true)

	if state.map_id=="siege_battlefield" and obstacle.has("appearance"):
		Battlefield.draw_facility(self,obstacle,top,Rect2(Vector2(base.position.x,top.end.y),Vector2(base.size.x,height)),alpha)
	for decor in state.map_space.definition.get("decor",[]):
		if decor.kind!="gate":continue
		var door: Rect2 = state.MapCatalog.rectangle(decor.rect)
		if not box.encloses(door):continue
		var at := screen(Vector2(door.position.x,door.end.y))
		var gate_rect:=Rect2(at-Vector2(0,height-8),Vector2(door.size.x,height-8))
		var gate_texture:Texture2D=canvas.art.map_texture("gate_front",state.map_id)
		if gate_texture:
			var clipped:Rect2=gate_rect.intersection(viewport)
			if clipped.has_area():
				var scale:Vector2=gate_texture.get_size()/gate_rect.size
				canvas.draw_texture_rect_region(gate_texture,clipped,Rect2((clipped.position-gate_rect.position)*scale,clipped.size*scale),Color(1,1,1,alpha))
		else:canvas.draw_rect(gate_rect,Color("473b32",alpha))
		canvas.draw_rect(Rect2(at-Vector2(0,height-8),Vector2(door.size.x,height-8)),Color("b39b73",alpha),false,3)
		for offset in [-16.0,door.size.x+16]:
			var light:=at+Vector2(offset,-height*.55)
			canvas.draw_line(light+Vector2(0,12),light+Vector2(0,28),Color("8e6b48",alpha),4,true)
			canvas.draw_circle(light,13,Color("f1a74e",alpha*.08))
			canvas.draw_colored_polygon(PackedVector2Array([light+Vector2(-5,6),light+Vector2(0,-10),light+Vector2(4,6)]),Color("efad68",alpha))

func _draw_approaches() -> void:
	for cue in canvas.approach_cues():
		var raw := screen(cue.at)
		var at := raw.clamp(Vector2.ONE*20,canvas.size-Vector2.ONE*20)
		var direction := (raw-at).normalized()
		var side := direction.orthogonal()
		var color := Color("ffa16f") if cue.kind=="shot" else Color("bfb0ee")
		canvas.draw_colored_polygon(PackedVector2Array([at+direction*10,at-direction*8+side*7,at-direction*8-side*7]),color)
		canvas.draw_string(canvas.get_theme_default_font(),at-direction*20+Vector2(-4,5),"!" if cue.kind=="shot" else str(cue.count),HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
