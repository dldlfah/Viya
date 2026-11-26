extends RefCounted
## A read-only frame plan for living breakable objects. Respawn stays invisible.

static func build(view,reserved:Array,compact:bool,dense:bool) -> Dictionary:
	var result:Dictionary={"markers":[],"events":[],"reserved":[]}
	var state=view.simulation
	if not state.has_active_run() or not state.cues.enabled:return result
	var safe:=Rect2(Vector2(8,8),view.size-Vector2(16,16))
	var candidates:Array=[]
	for prop in state.structures:
		if prop.hp<=0:continue
		var at:Vector2=view.world_to_screen(prop.p)
		if not safe.has_point(at):continue
		candidates.append({"prop":prop,"at":at,"distance":prop.p.distance_squared_to(state.player)})
	candidates.sort_custom(func(a,b):return a.distance<b.distance if a.distance!=b.distance else int(a.prop.id)<int(b.prop.id))
	var marker_limit:int=(2 if compact else 4) if dense else (4 if compact else 8)
	var occupied:Array=reserved.duplicate()
	for candidate in candidates:
		var prop:Dictionary=candidate.prop
		var at:Vector2=candidate.at
		if prop.hp>0 and prop.hp<prop.max_hp:
			var hp_bar:=Rect2(at-Vector2(20,49 if view.high_angle else 33),Vector2(40,4))
			occupied.append(hp_bar)
			result.reserved.append(hp_bar)
		if result.markers.size()>=marker_limit:continue
		var center:Vector2=at+Vector2(-30,-22)
		var badge:=Rect2(center-Vector2(7,7),Vector2(14,14))
		var boxes:Array=[badge]
		if boxes.any(func(box):return not safe.encloses(box) or occupied.any(func(other):return box.grow(2).intersects(other))):continue
		var marker:Dictionary={"id":int(prop.id),"at":center,"waiting":false,"damaged":prop.hp<prop.max_hp,"boxes":boxes}
		result.markers.append(marker)
		occupied.append_array(boxes)
		result.reserved.append_array(boxes)
	return result

static func draw(canvas,markers:Array) -> void:
	for marker in markers:
		var at:Vector2=marker.at
		var tint:=Color("e3b869" if marker.damaged else "c6ae7e")
		canvas.draw_rect(Rect2(at-Vector2(7,7),Vector2(14,14)),Color("202027"))
		canvas.draw_rect(Rect2(at-Vector2(7,7),Vector2(14,14)),tint,false,1)
		# Hammer glyph: identifies a breakable object without promising a drop.
		canvas.draw_line(at+Vector2(-3,4),at+Vector2(3,-3),tint,2,true)
		canvas.draw_line(at+Vector2(-1,-4),at+Vector2(4,1),tint,3,true)
