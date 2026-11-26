extends RefCounted
## Retain static vector triangles, not actor images or animation state.
## One shared bounded cache per view; no per-enemy nodes/RIDs/timers.
const Forms=preload("res://scripts/combat/battle_forms.gd")
const LIMIT:=64
var meshes:Dictionary={}
var builds:int=0

class Geometry:
	extends RefCounted
	var vertices:=PackedVector2Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	func polygon(points:PackedVector2Array, tint:PackedColorArray, order:PackedInt32Array) -> void:
		var offset:int=vertices.size()
		vertices.append_array(points);colors.append_array(tint)
		for index in order:indices.append(offset+index)
	func draw_colored_polygon(points:PackedVector2Array, color:Color) -> void:
		var tint:=PackedColorArray();tint.resize(points.size());tint.fill(color)
		polygon(points,tint,Geometry2D.triangulate_polygon(points))
	func quad(points:PackedVector2Array, color:Color, feather:bool=false) -> void:
		var clear:=Color(color,0)
		polygon(points,PackedColorArray([color,clear,clear,color]) if feather else PackedColorArray([color,color,color,color]),PackedInt32Array([0,1,2,0,2,3]))
	func draw_circle(at:Vector2, radius:float, color:Color) -> void:
		# Godot's filled ellipse uses the same 64-segment centre fan.
		var points:=PackedVector2Array([at]);var order:=PackedInt32Array()
		for i in range(65):points.append(at+Vector2.from_angle(i*TAU/64)*radius)
		for i in range(64):order.append_array(PackedInt32Array([0,i+1,i+2]))
		var tint:=PackedColorArray();tint.resize(points.size());tint.fill(color)
		polygon(points,tint,order)
	func draw_line(a:Vector2, b:Vector2, color:Color, width:float, antialias:bool) -> void:
		# Match Godot4.7.2 canvas line geometry, including its1.25 feather and
		# compensated width (renderer_canvas_cull.cpp, MIT/Godot contributors).
		if antialias:
			width=width*.5 if width<=2.50001 else (lerpf(width*.5,width-.625,(width-2.5)/2.5) if width<=5.00001 else width-.625)
		var direction:Vector2=(a-b).normalized()
		var side:Vector2=direction.orthogonal()
		var normal:Vector2=side*width*.5
		var left_a:Vector2=a+normal;var right_a:Vector2=a-normal
		var left_b:Vector2=b+normal;var right_b:Vector2=b-normal
		quad(PackedVector2Array([left_a,right_a,right_b,left_b]),color)
		if not antialias:return
		var feather:float=1.25*minf(1,width)
		var across:Vector2=side*feather;var along:Vector2=direction*feather
		quad(PackedVector2Array([left_a,left_a+across,left_b+across,left_b]),color,true)
		quad(PackedVector2Array([right_a,right_a-across,right_b-across,right_b]),color,true)
		quad(PackedVector2Array([left_a,left_a+along,right_a+along,right_a]),color,true)
		quad(PackedVector2Array([left_b,left_b-along,right_b-along,right_b]),color,true)
		var clear:=Color(color,0)
		for corner in [[left_a,along,across],[right_a,along,-across],[left_b,-along,across],[right_b,-along,-across]]:
			var at:Vector2=corner[0];var x:Vector2=corner[1];var y:Vector2=corner[2]
			polygon(PackedVector2Array([at,at+x,at+x+y,at+y]),PackedColorArray([color,clear,clear,clear]),PackedInt32Array([0,1,2,0,2,3]))
	func mesh() -> ArrayMesh:
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
		var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return result

func shape(variant:String, color:Color, detailed:bool, front:bool=false) -> ArrayMesh:
	var key:Array=[variant,color,detailed,front]
	if meshes.has(key):return meshes[key]
	var geometry:=Geometry.new()
	Forms.static_part(geometry,variant,color,detailed,front)
	var result:ArrayMesh=geometry.mesh()
	# Fixed shape/style cache, never keyed by actor IDs or continuous gait/HP.
	if meshes.size()>=LIMIT:meshes.erase(meshes.keys()[0])
	meshes[key]=result;builds+=1
	return result

func draw_part(canvas:CanvasItem, variant:String, color:Color, detailed:bool, front:bool) -> void:
	canvas.draw_mesh(shape(variant,color,detailed,front),null)
