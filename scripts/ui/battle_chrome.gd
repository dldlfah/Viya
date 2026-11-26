extends Control
## One non-interactive overlay. Reference-inspired frames and an optional small
## radar use actual state only. No guide illustration or invented resource data.
const CombatSkin=preload("res://scripts/ui/combat_skin.gd")
var hud

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if not is_instance_valid(hud) or hud.layout_data.is_empty() or hud.overlay.visible:return
	var data:Dictionary=hud.layout_data
	for key in ["top","resources","skills","magic"]:
		var box:Rect2=data[key]
		var color:=CombatSkin.GOLD
		for p in [box.position,box.end,Vector2(box.end.x,box.position.y),Vector2(box.position.x,box.end.y)]:
			var inward:Vector2=(box.get_center()-p).sign()
			draw_polyline(PackedVector2Array([p+Vector2(inward.x*14,0),p+Vector2(inward.x*5,inward.y*3),p+Vector2(0,inward.y*12)]),color,1,true)
	var bottom:Rect2=data.bottom
	draw_line(bottom.position-Vector2(0,3),Vector2(bottom.end.x,bottom.position.y-3),Color("ba9566",.7),1,true)
	if not data.compact:_radar()

func _radar() -> void:
	var area:Rect2=hud.layout_data.battle
	var center:=Vector2(area.end.x-57,area.position.y+72)
	var radius:=45.0
	draw_circle(center,radius,Color("17151b",.88))
	draw_arc(center,radius,0,TAU,48,CombatSkin.GOLD,1.5,true)
	draw_arc(center,radius*.6,0,TAU,40,Color("6c604e",.4),1,true)
	draw_line(center-Vector2(radius-4,0),center+Vector2(radius-4,0),Color("78644e",.35),1,true)
	draw_line(center-Vector2(0,radius-4),center+Vector2(0,radius-4),Color("78644e",.35),1,true)
	var enemies:Array=hud.simulation.enemies.duplicate()
	var player:Vector2=hud.simulation.player
	enemies.sort_custom(func(a,b):return a.p.distance_squared_to(player)<b.p.distance_squared_to(player))
	var dots:=0
	for enemy in enemies:
		var delta:Vector2=(enemy.p-player)/900*radius
		if hud.view.uses_oblique():delta=hud.view.project_direction(delta)/hud.view.ObliqueProjection.basis(hud.view.size).x.length()
		else:delta.y*=.8660254037844386
		if delta.length()>radius-5:continue
		if dots>=48:break
		draw_circle(center+delta,2.5 if enemy.kind=="boss" else 1.5,Color("ed796f") if enemy.kind!="elite" else Color("c49be0"))
		dots+=1
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-5),center+Vector2(4,4),center+Vector2(0,2),center+Vector2(-4,4)]),CombatSkin.LIGHT)
	var north:Vector2=hud.view.project_direction(Vector2.UP).normalized() if hud.view.uses_oblique() else Vector2.UP
	draw_string(get_theme_default_font(),center+north*(radius+4)+Vector2(-4,0),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,11,CombatSkin.LIGHT)
	draw_string(get_theme_default_font(),center+Vector2(-23,radius+13),"주변 전장",HORIZONTAL_ALIGNMENT_LEFT,-1,10,CombatSkin.GOLD)
