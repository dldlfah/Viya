extends RefCounted
## Read-only boss tracking. "Aimed" describes target selection, never a hit promise.
const Weapons=preload("res://scripts/combat/weapon_modules.gd")
const Ground=preload("res://scripts/combat/battle_projection.gd")
const Approaches=preload("res://scripts/combat/approach_cues.gd")

static func inspect(state) -> Dictionary:
	if state.phase!=state.Phase.RUNNING or state.run_mode!="campaign":return {}
	var boss:Dictionary={}
	for enemy in state.enemies:
		if enemy.kind=="boss" and enemy.hp>0:
			boss=enemy
			break
	if boss.is_empty():return {}
	var profile:Dictionary
	var victim:Dictionary
	if state.growth.ruleset=="weapons_v1":
		var starter:String=Weapons.starter(state)
		profile=state.attack_profile(starter,state.growth.skill_level(starter),float(state.stats.rate))
		if profile.is_empty():return {}
		victim=Weapons.target(state,state.player,float(profile.reach),str(profile.target))
		if state.growth.pacing_version==1 and bool(state.growth.pacing.data.boss_priority):
			for enemy in state.enemies:
				if enemy.kind=="boss" and state.player.distance_to(enemy.p)<=float(profile.reach):
					victim=enemy
					break
	else:
		profile={"reach":state.SHOT_RANGE*float(state.stats.get("attack_range",1.0)),"width":4.0}
		victim=state._nearest(state.player,float(profile.reach))
	var distance:float=state.player.distance_to(boss.p)
	var fraction:float=state.map_space.wall_fraction(state.player,boss.p,float(profile.width))
	var in_range:bool=distance<=float(profile.reach)
	var aimed:bool=not victim.is_empty() and int(victim.id)==int(boss.id)
	var status:String="기본 공격 · 보스 조준"
	if not in_range:status="기본 공격 · 사거리 밖 · 접근 필요"
	elif fraction<1.0:status="기본 공격 · 지형에 가림 · 우회"
	elif not aimed:status="기본 공격 · 다른 대상 조준"
	return {"id":int(boss.id),"p":boss.p,"hp":boss.hp,"max_hp":boss.max_hp,
		"distance":distance,"reach":float(profile.reach),"blocked":fraction<1.0,
		"in_range":in_range,"aimed":aimed,"status":status}

static func build(view) -> Dictionary:
	var result:Dictionary=inspect(view.simulation)
	if result.is_empty():return {}
	var compact:bool=view.size.x<900 or view.size.y<350
	result.font_size=11 if compact else 13
	result.status_rect=Rect2(Vector2(view.size.x*.33,26),Vector2(minf(360,view.size.x*.40),22))
	result.screen=view.world_to_screen(result.p)
	result.offscreen=not Rect2(Vector2.ZERO,view.size).has_point(result.screen)
	result.marker_rect=Rect2()
	if not result.offscreen:return result
	# Use the real displayed camera, not RunState's larger spawn envelope.
	var visible:Rect2=view.ground_visible() if view.high_angle else Rect2(view.camera_center()-view.size*.5,view.size)
	var occupied:Array=[result.status_rect.grow(8),Rect2(view.world_to_screen(view.simulation.player)-Vector2(30,70),Vector2(60,100))]
	for cue in view.approach_cues():
		var at:Vector2=view.world_to_screen(cue.at).clamp(Vector2.ONE*20,view.size-Vector2.ONE*20)
		occupied.append(Rect2(at-Vector2.ONE*42,Vector2.ONE*84))
	# Keep away from the mission, boss HP, radar, and the outer pack/shot cues.
	var safe:=Rect2(Vector2(88,72 if compact else 144),view.size-Vector2(176,112 if compact else 184))
	var ideal:Vector2=result.screen.clamp(safe.position,safe.end)
	var candidates:Array[Vector2]=[ideal]
	for x in range(ceili(safe.position.x),floori(safe.end.x)+1,32):
		candidates.append(Vector2(x,safe.position.y))
		candidates.append(Vector2(x,safe.end.y))
	for y in range(ceili(safe.position.y),floori(safe.end.y)+1,32):
		candidates.append(Vector2(safe.position.x,y))
		candidates.append(Vector2(safe.end.x,y))
	candidates.sort_custom(func(a,b):return a.distance_squared_to(ideal)<b.distance_squared_to(ideal))
	for at in candidates:
		var box:=Rect2(at-Vector2(40,20),Vector2(80,40))
		if occupied.any(func(other):return box.intersects(other)):continue
		result.marker_rect=box
		result.direction=(result.screen-at).normalized()
		break
	return result

static func draw(view,plan:Dictionary) -> void:
	if plan.is_empty():return
	var color:=Color("edb375") if not plan.in_range or plan.blocked else Color("f1c2bc")
	var font:Font=view.get_theme_default_font()
	var area:Rect2=plan.status_rect
	view.draw_rect(area,Color("19161c",.90))
	view.draw_string(font,area.position+Vector2(6,15),plan.status,HORIZONTAL_ALIGNMENT_LEFT,area.size.x-12,plan.font_size,color)
	if plan.offscreen:
		var box:Rect2=plan.marker_rect
		if not box.has_area():return
		var at:Vector2=box.get_center()
		var d:Vector2=plan.direction
		view.draw_circle(at,20,Color("21191d",.94))
		view.draw_arc(at,20,0,TAU,24,Color("df918b"),1.5,true)
		view.draw_colored_polygon(PackedVector2Array([at+d*38,at+d*26+d.orthogonal()*6,at+d*26-d.orthogonal()*6]),Color("f0a99e"))
		view.draw_string(font,at-Vector2(font.get_string_size("보스",HORIZONTAL_ALIGNMENT_LEFT,-1,12).x*.5,-4),"보스",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f5d9cc"))
	else:
		# A foreground foot ring identifies the actual boss without covering its art.
		view.draw_arc(plan.screen,43,0,TAU,40,Color("f0a99e"),2,true)
		view.draw_line(plan.screen+Vector2(-8,43),plan.screen+Vector2(8,43),Color("f5d9cc"),2,true)
