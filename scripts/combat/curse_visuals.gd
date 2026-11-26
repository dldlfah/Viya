extends RefCounted
## Read-only ground geometry shared by both renderers, above friendly decoration.
static func plan(view,enemy:Dictionary,spec:Dictionary) -> Dictionary:
	var p:Dictionary=enemy.pattern
	if p.phase=="reacquire":return {"id":int(enemy.id),"phase":"reacquire","origin":view.world_to_screen(enemy.p),"progress":1-float(p.left)/float(spec.reacquire)}
	if p.phase!="windup":return {}
	var state=view.simulation
	var distance:float=float(spec.bullet_speed)*float(spec.bullet_life)
	var end:Vector2=p.origin+p.direction*distance
	end=p.origin+(end-p.origin)*state.map_space.wall_fraction(p.origin,end,float(spec.bullet_radius))
	var side:Vector2=p.direction.orthogonal()*float(spec.bullet_radius)
	var points:=PackedVector2Array()
	for at in [p.origin-side,end-side,end+side,p.origin+side]:points.append(view.world_to_screen(at))
	return {"id":int(enemy.id),"phase":"curse_windup","points":points,"origin":view.world_to_screen(p.origin),"end":view.world_to_screen(end),"progress":1-float(p.left)/float(spec.windup)}

static func draw_windup(view,entry:Dictionary) -> void:
	var points:PackedVector2Array=entry.points
	view.draw_colored_polygon(points,Color("bc8df0",.17))
	points.append(points[0])
	view.draw_polyline(points,Color("e4b4ff"),1.5,true)
	view.draw_line(entry.origin,entry.end,Color("ffcf82",.8),1,true)
	view.draw_arc(entry.origin,24,0,TAU*clampf(float(entry.progress),0,1),32,Color("ffcf82"),2.5,true)
	view.draw_arc(entry.end,8,0,TAU,16,Color("e4b4ff"),2,true)

static func draw_bullet(view,bullet:Dictionary) -> void:
	var spec:Dictionary=view.simulation.enemy_patterns.specification(3,"demon_shaman")
	var points:=PackedVector2Array()
	for index in range(25):points.append(view.world_to_screen(bullet.p+Vector2.from_angle(index*TAU/24)*float(spec.bullet_radius)))
	var at:Vector2=view.world_to_screen(bullet.p)
	var tail:Vector2=view.world_to_screen(bullet.p-bullet.velocity.normalized()*22)
	view.draw_line(tail,at,Color("c599ef"),4,true)
	view.draw_colored_polygon(points,Color("8d54bc"))
	view.draw_polyline(points,Color("ffdaa0"),2,true)
	view.draw_line(at+Vector2(-3,0),at+Vector2(3,0),Color("fff0d0"),2,true)
