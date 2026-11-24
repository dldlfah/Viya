extends RefCounted
## Stage-only scenery. Draws from static map data; never owns combat or RNG.
static func draw_ground(renderer) -> void:
	var canvas=renderer.canvas
	for route in renderer.state.map_space.definition.get("routes",[]):
		var points:=PackedVector2Array()
		for p in route.points:points.append(Vector2(p[0],p[1]))
		var width:float=680 if route.id=="R1" else 260
		canvas.draw_polyline(points,Color("b0a18a",.12),width,true)
		canvas.draw_polyline(points,Color("514536",.13),maxf(20,width-80),true)
		# Wagon ruts describe movement rather than fixed spawn/quest markers.
		for offset in [-22,22]:
			var rut:=PackedVector2Array()
			for point in points:rut.append(point+Vector2(offset,0))
			canvas.draw_polyline(rut,Color("211f1c",.18),9,true)
	for obstacle in renderer.state.map_space.definition.obstacles:
		if not obstacle.has("appearance"):continue
		var box:Rect2=renderer.state.MapCatalog.rectangle(obstacle.rect)
		if not renderer.visible.grow(90).intersects(box):continue
		canvas.draw_rect(box.grow(36),Color("161514",.18))
		for index in range(4):
			var at:=Vector2(box.position.x+box.size.x*(index+1)/5,box.end.y+18+index%2*14)
			canvas.draw_line(at-Vector2(13,3),at+Vector2(12,5),Color("574a3b",.55),5,true)

static func draw_barricade(renderer,box:Rect2,base:Rect2,height:float,alpha:float) -> void:
	var canvas=renderer.canvas
	canvas.draw_rect(base,Color("342c25",alpha))
	var count:=maxi(3,int(box.size.x/32))
	for index in range(count):
		var x:float=base.position.x+(index+.5)*base.size.x/count
		var y:float=base.end.y
		var h:float=height*(.7 if index%3==0 else 1.0)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x-8,y),Vector2(x-6,y-h),Vector2(x+1,y-h-6),Vector2(x+7,y)]),Color("73543a",alpha))
		canvas.draw_line(Vector2(x-3,y-3),Vector2(x+1,y-h+4),Color("b08b5a",alpha*.7),2,true)
	canvas.draw_line(Vector2(base.position.x+4,base.end.y-height*.35),Vector2(base.end.x-4,base.end.y-height*.68),Color("433328",alpha),7,true)
	canvas.draw_line(Vector2(base.position.x+6,base.end.y-height*.76),Vector2(base.end.x-4,base.end.y-height*.15),Color("967049",alpha),4,true)

static func draw_facility(renderer,obstacle:Dictionary,top:Rect2,front:Rect2,alpha:float) -> void:
	var canvas=renderer.canvas
	var appearance:String=obstacle.get("appearance","")
	var interior:Rect2=top.grow(-14)
	if not interior.has_area():return
	# Dark, filled collapse silhouettes signal that these footprints are solid.
	canvas.draw_rect(interior,Color("272727",alpha*.88))
	for index in range(5):
		var x:float=interior.position.x+(index+.5)*interior.size.x/5
		var start:=Vector2(x,interior.position.y+3)
		var end:=Vector2(minf(interior.end.x-3,x+25),interior.end.y-3)
		canvas.draw_line(start,end,Color("66513b",alpha),8,true)
		canvas.draw_line(start+Vector2(2,0),end+Vector2(2,0),Color("a28254",alpha*.55),2,true)
	if appearance=="tower":
		for side in [0.18,0.82]:
			var x:float=front.position.x+front.size.x*side
			canvas.draw_line(Vector2(x,top.position.y+10),Vector2(x,front.end.y),Color("4a362b",alpha),11,true)
		canvas.draw_line(top.position+Vector2(18,8),Vector2(top.end.x-18,front.end.y-12),Color("9a7752",alpha),5,true)
	elif appearance=="aid":
		var p:=top.position+Vector2(12,4)
		canvas.draw_colored_polygon(PackedVector2Array([p,p+Vector2(top.size.x*.6,8),p+Vector2(top.size.x*.52,top.size.y*.65),p+Vector2(5,top.size.y*.8)]),Color("9a8d73",alpha*.9))
	elif appearance in ["wagon","workshop"]:
		for offset in [.25,.75]:
			var at:=Vector2(front.position.x+front.size.x*offset,front.end.y-10)
			canvas.draw_arc(at,15,0,TAU,16,Color("392d26",alpha),5,true)
			canvas.draw_line(at-Vector2(10,10),at+Vector2(10,10),Color("b29365",alpha),2,true)
	elif appearance in ["warehouse","barracks"]:
		var p:=Vector2(front.position.x+front.size.x*.65,front.position.y+4)
		canvas.draw_colored_polygon(PackedVector2Array([p,p+Vector2(27,0),p+Vector2(23,37),p+Vector2(12,29),p+Vector2(3,40)]),Color("713e42",alpha))
		canvas.draw_line(p+Vector2(3,3),p+Vector2(24,3),Color("b59a6b",alpha),2,true)
