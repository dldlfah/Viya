extends RefCounted
## Actual received HP loss only. Screen-space marks never own combat/input state.
const Ground=preload("res://scripts/combat/battle_projection.gd")
const ARROWS := ["→","↘","↓","↙","←","↖","↑","↗"]

static func arrow(direction:Vector2, high_angle:bool=true) -> String:
	if direction.is_zero_approx():return "•"
	var projected:Vector2=Ground.transform(Vector2.ZERO,Vector2.ZERO)*direction if high_angle else direction
	return ARROWS[posmod(roundi(projected.angle()/(PI/4)),8)]

static func notice(state, high_angle:bool=true, project:Callable=Callable()) -> String:
	var hit:Dictionary=state.cues.latest_received()
	return "" if hit.is_empty() else "%s −%d" % [(arrow(project.call(hit.direction),false) if project.is_valid() else arrow(hit.direction,high_angle)),int(hit.amount)]

static func build(view) -> Dictionary:
	var state=view.simulation
	if state.phase!=state.Phase.RUNNING or not state.cues.enabled or state.cues.received.is_empty():return {}
	var result:Dictionary={"center":view.world_to_screen(state.player),"marks":[]}
	# Up to3 recent marks. The original48outgoing numbers and hostile cues remain.
	for index in range(state.cues.received.size()-1,maxi(-1,state.cues.received.size()-4),-1):
		var hit:Dictionary=state.cues.received[index]
		# Transform the vector itself; subtracting large world positions loses precision.
		var direction:Vector2=view.project_direction(hit.direction)
		result.marks.append({"direction":direction.normalized(),"alpha":clampf(float(hit.life)/float(hit.duration),0,1),
			"origin":view.world_to_screen(hit.origin),"contact":hit.kind=="contact" and float(hit.duration)-float(hit.life)<.16})
	var latest:Dictionary=state.cues.latest_received()
	result.text="−%d HP" % int(latest.amount)
	result.alpha=clampf(float(latest.life)/float(latest.duration),0,1)
	return result

static func draw(view,plan:Dictionary) -> void:
	if plan.is_empty():return
	var center:Vector2=plan.center
	for mark in plan.marks:
		var color:=Color("ff8493",float(mark.alpha))
		var direction:Vector2=mark.direction
		if direction.is_zero_approx():
			view.draw_arc(center,33,0,TAU,32,color,2,true)
		else:
			var angle:float=direction.angle()
			view.draw_arc(center,36,angle-.48,angle+.48,12,color,4,true)
			view.draw_colored_polygon(PackedVector2Array([center+direction*26,center+direction*34+direction.orthogonal()*5,center+direction*34-direction.orthogonal()*5]),color)
		if mark.contact:
			view.draw_arc(mark.origin,23,0,TAU,20,Color("efb995",float(mark.alpha)),2,true)
