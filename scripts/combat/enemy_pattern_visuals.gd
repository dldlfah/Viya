extends RefCounted
## Shared read-only ground geometry for both renderers. No gameplay clocks.
static func plan(view) -> Array:
	var result:Array=[]
	var state=view.simulation
	if state.phase!=state.Phase.RUNNING or state.enemy_pattern_version not in [1,2,3]:return result
	for enemy in state.enemies:
		if not state.enemy_patterns.applies(state,enemy) or enemy.pattern.phase=="chase":continue
		var spec:Dictionary=state.enemy_patterns.specification(state.enemy_pattern_version,str(enemy.species))
		if enemy.species=="demon_shaman":
			var entry:Dictionary=preload("res://scripts/combat/curse_visuals.gd").plan(view,enemy,spec)
			if not entry.is_empty():result.append(entry)
			continue
		var p:Dictionary=enemy.pattern
		if p.phase=="reacquire":
			result.append({"id":int(enemy.id),"phase":"reacquire","origin":view.world_to_screen(enemy.p),"progress":1-float(p.left)/float(spec.reacquire)})
			continue
		if p.phase not in ["windup","strike"]:continue
		var points:=PackedVector2Array([view.world_to_screen(p.origin)])
		var half:float=deg_to_rad(float(spec.half_angle_degrees))
		for index in range(49):
			var ray:Vector2=p.direction.rotated(lerpf(-half,half,index/48.0))
			var end:Vector2=p.origin+ray*float(spec.reach)
			points.append(view.world_to_screen(p.origin+(end-p.origin)*state.map_space.wall_fraction(p.origin,end,0)))
		result.append({"id":int(enemy.id),"phase":str(p.phase),"points":points,"progress":1-float(p.left)/float(spec[p.phase]),"origin":view.world_to_screen(p.origin)})
	return result

static func draw(view) -> void:
	for entry in plan(view):
		if entry.phase=="curse_windup":
			preload("res://scripts/combat/curse_visuals.gd").draw_windup(view,entry)
			continue
		if entry.phase=="reacquire":
			var at:Vector2=entry.origin
			var color:=Color("b7c4d0",.8)
			view.draw_arc(at,23,.25,TAU-.25,24,color,2,true)
			view.draw_line(at+Vector2(-5,-5),at+Vector2(5,5),color,2,true)
			view.draw_line(at+Vector2(-5,5),at+Vector2(5,-5),color,2,true)
			continue
		var points:PackedVector2Array=entry.points
		var color:Color=Color("ffce80") if entry.phase=="windup" else Color("ff7b6e")
		# Individual triangles remain valid when terrain clips adjacent rays to zero.
		for index in range(1,points.size()-1):
			if absf((points[index]-points[0]).cross(points[index+1]-points[0]))>.001:
				view.draw_colored_polygon(PackedVector2Array([points[0],points[index],points[index+1]]),Color(color,.13 if entry.phase=="windup" else .28))
		points.append(points[0])
		view.draw_polyline(points,color,2,true)
		view.draw_arc(entry.origin,22,0,TAU*clampf(float(entry.progress),0,1),32,color,2,true)
		if entry.phase=="strike":
			var head:Vector2=entry.origin.lerp(points[25],.65)
			var tangent:Vector2=(head-entry.origin).normalized().orthogonal()*12
			view.draw_line(entry.origin.lerp(head,.25),head,Color("e3bc82"),5,true)
			view.draw_line(head-tangent,head+tangent,Color("ffd5a0"),9,true)
