extends RefCounted
## Extruded terrain faces, static textures and contact shadows. No game state.

static func corners(box: Rect2) -> PackedVector2Array:
	return PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)])

static func height_for(obstacle: Dictionary) -> float:
	var height:float=float(obstacle.get("visual_height",122 if obstacle.kind=="wall" else 65))
	return height*(1.45 if obstacle.kind=="wall" else (1.35 if obstacle.kind=="ruin" else 1.0))

static func geometry(box: Rect2, height: float, ground: Transform2D) -> Dictionary:
	var base:PackedVector2Array=ground*corners(box)
	var top:=PackedVector2Array()
	for at in base:top.append(at-Vector2(0,height))
	return {"base":base,"top":top,"front":PackedVector2Array([top[3],top[2],base[2],base[3]]),"side":PackedVector2Array([top[0],top[3],base[3],base[0]]),"bounds":Rect2(ground*box.position,Vector2.ZERO).expand(top[0]).expand(top[1]).expand(top[2]).expand(top[3]).expand(base[0]).expand(base[1]).expand(base[2]).expand(base[3])}

static func occludes(shape: Dictionary, player: Vector2, actor_body:Rect2=Rect2()) -> bool:
	# Test front-edge depth at this X, rather than fading a wall in front of feet.
	var body:Rect2=actor_body if actor_body.has_area() else Rect2(player-Vector2(19,57),Vector2(38,58))
	if not shape.bounds.intersects(body):return false
	for face in [shape.front,shape.side]:
		var a:Vector2=face[3];var b:Vector2=face[2]
		if body.end.x<minf(a.x,b.x) or body.position.x>maxf(a.x,b.x):continue
		var t:float=clampf((player.x-a.x)/(b.x-a.x),0,1) if absf(b.x-a.x)>.001 else .5
		var edge:Vector2=a.lerp(b,t)
		if player.y>edge.y+1:continue
		var rectangle:PackedVector2Array=corners(body)
		if not Geometry2D.intersect_polygons(rectangle,face).is_empty() or not Geometry2D.intersect_polygons(rectangle,shape.top).is_empty():return true
	return false

static func polygon(canvas, points: PackedVector2Array, color: Color, texture: Texture2D=null, uv: PackedVector2Array=PackedVector2Array()) -> void:
	if texture:canvas.draw_polygon(points,PackedColorArray([color]),uv,texture)
	else:canvas.draw_colored_polygon(points,color)

static func top_tiles(renderer, box: Rect2, height: float, texture: Texture2D, alpha: float) -> void:
	var inverse:Transform2D=renderer.ground.affine_inverse()
	var visible:Rect2=inverse*Rect2(Vector2(0,height),renderer.canvas.size)
	var area:Rect2=box.intersection(visible.grow(112))
	if not area.has_area():return
	for y in range(floori(area.position.y/80)*80,ceili(area.end.y),80):
		for x in range(floori(area.position.x/96)*96,ceili(area.end.x),96):
			var tile:=Rect2(x,y,96,80)
			var part:Rect2=tile.intersection(box)
			var points:=PackedVector2Array();var uv:=PackedVector2Array()
			for at in corners(part):
				points.append(renderer.screen(at)-Vector2(0,height));uv.append((at-tile.position)/tile.size)
			polygon(renderer.canvas,points,Color(1,1,1,alpha),texture,uv)

static func face_tiles(renderer, from: Vector2, to: Vector2, height: float, texture: Texture2D, shade: Color) -> void:
	var length:float=from.distance_to(to)
	var count:=ceili(length/96)
	for index in range(count):
		var a:Vector2=renderer.screen(from.lerp(to,index*96/length))
		var b:Vector2=renderer.screen(from.lerp(to,minf(length,(index+1)*96)/length))
		var up:=Vector2(0,height)
		var points:=PackedVector2Array([a-up,b-up,b,a])
		var bounds:=Rect2(a-up,Vector2.ZERO).expand(b-up).expand(a).expand(b)
		if not renderer.viewport.intersects(bounds):continue
		var u:float=minf(96,length-index*96)/96
		polygon(renderer.canvas,points,shade,texture,PackedVector2Array([Vector2.ZERO,Vector2(u,0),Vector2(u,1),Vector2(0,1)]))

static func draw(renderer, obstacle: Dictionary) -> bool:
	var canvas=renderer.canvas
	var box:Rect2=renderer.state.MapCatalog.rectangle(obstacle.rect)
	var height:float=height_for(obstacle)
	var shape:Dictionary=geometry(box,height,renderer.ground)
	if not renderer.viewport.grow(30).intersects(shape.bounds):return false
	var faded:bool=occludes(shape,renderer.screen(renderer.state.player),renderer.hero_body)
	var alpha:float=.28 if faded else 1.0
	var shadow:=PackedVector2Array()
	for at in [shape.base[0],shape.base[1],shape.base[2],shape.base[2]+Vector2(24,22),shape.base[3]+Vector2(24,22),shape.base[3]]:shadow.append(at)
	polygon(canvas,shadow,Color(0,0,0,.22*alpha))
	if obstacle.kind=="barricade":
		var from:=Vector2(box.position.x,box.get_center().y)
		var to:=Vector2(box.end.x,box.get_center().y)
		var a:Vector2=renderer.screen(from);var b:Vector2=renderer.screen(to)
		for index in range(maxi(3,ceili(box.size.x/32))):
			var t:float=(index+.5)/maxi(3,ceili(box.size.x/32))
			var at:Vector2=a.lerp(b,t);var h:float=height*(.72 if index%3==0 else 1.0)
			polygon(canvas,PackedVector2Array([at+Vector2(-5,0),at+Vector2(-4,-h),at+Vector2(0,-h-7),at+Vector2(5,-2)]),Color("806044",alpha))
		canvas.draw_line(a-Vector2(0,height*.35),b-Vector2(0,height*.65),Color("4d3527",alpha),6,true)
		return faded
	var key:String="wall" if obstacle.kind=="wall" else "ruin"
	var top_texture:Texture2D=canvas.art.map_texture(key+"_top_tile",renderer.state.map_id)
	var front_texture:Texture2D=canvas.art.map_texture("wall_segment" if key=="wall" else "ruin_block",renderer.state.map_id)
	# Top and two vertical faces have independent UVs and consistent side lighting.
	polygon(canvas,shape.side,Color("343439",alpha))
	polygon(canvas,shape.front,Color("555159",alpha))
	if front_texture:
		face_tiles(renderer,box.position,Vector2(box.position.x,box.end.y),height,front_texture,Color(.62,.64,.70,alpha))
		face_tiles(renderer,Vector2(box.position.x,box.end.y),box.end,height,front_texture,Color(.88,.85,.82,alpha))
	if top_texture:top_tiles(renderer,box,height,top_texture,alpha)
	else:polygon(canvas,shape.top,Color("77756d",alpha))
	var outline:PackedVector2Array=shape.top.duplicate();outline.append(outline[0])
	canvas.draw_polyline(outline,Color("b9a786",alpha*.8),1.5,true)
	canvas.draw_line(shape.top[3],shape.base[3],Color("b4a181",alpha*.7),2,true)
	var rim:=PackedVector2Array([shape.top[3],shape.top[2],shape.top[2]+Vector2(0,7),shape.top[3]+Vector2(0,7)])
	polygon(canvas,rim,Color("a0947d",alpha*.75))
	if key=="wall":
		# Battlement blocks are clipped to the visible interval of the long wall.
		var area:Rect2=box.intersection(renderer.visible.grow(240))
		for x in range(floori(area.position.x/160)*160,ceili(area.end.x),160):
			var at:Vector2=renderer.screen(Vector2(x+35,box.end.y))-Vector2(0,height)
			var along:Vector2=renderer.ground.x.normalized()*45
			polygon(canvas,PackedVector2Array([at,at+along,at+along-Vector2(0,16),at-Vector2(0,16)]),Color("989385",alpha))
		for decor in renderer.state.map_space.definition.get("decor",[]):
			if decor.kind!="gate":continue
			var door:Rect2=renderer.state.MapCatalog.rectangle(decor.rect)
			if not box.encloses(door):continue
			var a:Vector2=renderer.screen(Vector2(door.position.x,door.end.y))
			var b:Vector2=renderer.screen(door.end)
			var points:=PackedVector2Array([a-Vector2(0,height-10),b-Vector2(0,height-10),b,a])
			var texture:Texture2D=canvas.art.map_texture("gate_front",renderer.state.map_id)
			polygon(canvas,points,Color(1,1,1,alpha),texture,PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]))
			if not texture:polygon(canvas,points,Color("493a2f",alpha))
			points.append(points[0]);canvas.draw_polyline(points,Color("b69c72",alpha),3,true)
			var axis:Vector2=(b-a).normalized()
			for at in [a-axis*16,b+axis*16]:
				var light:Vector2=at-Vector2(0,height*.55)
				canvas.draw_line(light+Vector2(0,12),light+Vector2(0,28),Color("8e6b48",alpha),4,true)
				canvas.draw_circle(light,13,Color("f1a74e",alpha*.08))
				polygon(canvas,PackedVector2Array([light+Vector2(-5,6),light+Vector2(0,-10),light+Vector2(4,6)]),Color("efad68",alpha))
	else:
		facility(renderer,obstacle,box,height,alpha)
	return faded

static func facility(renderer, obstacle: Dictionary, box: Rect2, height: float, alpha: float) -> void:
	var canvas=renderer.canvas
	if not obstacle.has("appearance"):return
	var inner:=box.grow(-18)
	var points:=PackedVector2Array()
	for at in corners(inner):points.append(renderer.screen(at)-Vector2(0,height))
	polygon(canvas,points,Color("232024",alpha*.9))
	for index in range(4):
		var x:float=inner.position.x+(index+.5)*inner.size.x/4
		canvas.draw_line(renderer.screen(Vector2(x,inner.position.y))-Vector2(0,height),renderer.screen(Vector2(x+12,inner.end.y))-Vector2(0,height),Color("9a7c53",alpha*.8),5,true)
	if obstacle.appearance=="aid":polygon(canvas,PackedVector2Array([points[0],points[1],points[2].lerp(points[1],.4),points[3].lerp(points[0],.2)]),Color("b3a187",alpha*.95))
	if obstacle.appearance=="tower":
		for at in [points[0],points[2]]:canvas.draw_line(at,at+Vector2(0,height),Color("5d4230",alpha),8,true)
	if obstacle.appearance in ["wagon","workshop"]:
		for fraction in [.25,.75]:
			var at:Vector2=renderer.screen(Vector2(lerpf(box.position.x,box.end.x,fraction),box.end.y))-Vector2(0,10)
			canvas.draw_arc(at,15,0,TAU,16,Color("392d26",alpha),5,true)
			canvas.draw_line(at-Vector2(10,10),at+Vector2(10,10),Color("b29365",alpha),2,true)
	if obstacle.appearance in ["warehouse","barracks","tower"]:
		var at:Vector2=renderer.screen(Vector2(box.get_center().x,box.end.y))-Vector2(0,height-8)
		polygon(canvas,PackedVector2Array([at,at+Vector2(24,-5),at+Vector2(24,37),at+Vector2(12,30),at+Vector2(0,43)]),Color("873e45",alpha))
