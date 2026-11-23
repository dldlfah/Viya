extends RefCounted
## A read-only frame plan, not a respawn timer or a history of destruction.
const Rules=preload("res://scripts/world/supply_catalog.gd")
const NEAR_DISTANCE := 320.0

static func build(view,reserved:Array,compact:bool,dense:bool) -> Dictionary:
	var result:Dictionary={"markers":[],"events":[],"reserved":[]}
	var state=view.simulation
	if not state.has_active_run() or not state.cues.enabled:return result
	var safe:=Rect2(Vector2(8,8),view.size-Vector2(16,16))
	var candidates:Array=[]
	for prop in state.structures:
		var at:Vector2=view.world_to_screen(prop.p)
		if not safe.has_point(at):continue
		candidates.append({"prop":prop,"at":at,"distance":prop.p.distance_squared_to(state.player)})
	candidates.sort_custom(func(a,b):return a.distance<b.distance if a.distance!=b.distance else int(a.prop.id)<int(b.prop.id))
	var marker_limit:int=(2 if compact else 4) if dense else (4 if compact else 8)
	var text_limit:int=1 if compact or dense else 2
	var occupied:Array=reserved.duplicate()
	for candidate in candidates:
		var prop:Dictionary=candidate.prop
		var at:Vector2=candidate.at
		var waiting:bool=prop.hp<=0
		if prop.hp>0 and prop.hp<prop.max_hp:
			var hp_bar:=Rect2(at-Vector2(20,49 if view.high_angle else 33),Vector2(40,4))
			occupied.append(hp_bar)
			result.reserved.append(hp_bar)
		if waiting and candidate.distance<=NEAR_DISTANCE*NEAR_DISTANCE and result.events.size()<text_limit:
			# Ceil and the actual HP gate prevent a premature "0 seconds / ready".
			var seconds:int=maxi(1,ceili(float(prop.respawn_left)))
			result.events.append({"kind":"structure","id":int(prop.id),"p":prop.p,"label":"재생성 %d초" % seconds,"life":1.0,"duration":1.0})
		if result.markers.size()>=marker_limit:continue
		var center:Vector2=at+Vector2(-35,-6) if waiting else at+Vector2(-30,-22)
		var badge:=Rect2(center-Vector2(7,7),Vector2(14,14))
		var bar:=Rect2(at+Vector2(-16,24),Vector2(32,3)) if waiting else Rect2()
		var boxes:Array=[badge]
		if waiting:boxes.append(bar.grow(1))
		if boxes.any(func(box):return not safe.encloses(box) or occupied.any(func(other):return box.grow(2).intersects(other))):continue
		var marker:Dictionary={"id":int(prop.id),"at":center,"waiting":waiting,"damaged":prop.hp>0 and prop.hp<prop.max_hp,
			"progress":clampf(1.0-float(prop.respawn_left)/Rules.RESPAWN_SECONDS,0,1) if waiting else 1.0,"bar":bar,"boxes":boxes}
		result.markers.append(marker)
		occupied.append_array(boxes)
		result.reserved.append_array(boxes)
	return result

static func draw(canvas,markers:Array) -> void:
	for marker in markers:
		var at:Vector2=marker.at
		var tint:=Color("b4ad9c") if marker.waiting else Color("e3b869" if marker.damaged else "c6ae7e")
		canvas.draw_rect(Rect2(at-Vector2(7,7),Vector2(14,14)),Color("202027"))
		canvas.draw_rect(Rect2(at-Vector2(7,7),Vector2(14,14)),tint,false,1)
		if marker.waiting:
			canvas.draw_polyline(PackedVector2Array([at+Vector2(-4,-4),at+Vector2(4,-4),at+Vector2(-4,4),at+Vector2(4,4),at+Vector2(-4,-4)]),tint,1.5,true)
			canvas.draw_rect(marker.bar.grow(1),Color("202027"))
			canvas.draw_rect(marker.bar,Color("514e48"))
			canvas.draw_rect(Rect2(marker.bar.position,Vector2(marker.bar.size.x*float(marker.progress),marker.bar.size.y)),tint)
		else:
			# Hammer glyph: identifies a breakable object without promising a drop.
			canvas.draw_line(at+Vector2(-3,4),at+Vector2(3,-3),tint,2,true)
			canvas.draw_line(at+Vector2(-1,-4),at+Vector2(4,1),tint,3,true)
