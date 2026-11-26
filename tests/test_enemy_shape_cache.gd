extends RefCounted
const Cache=preload("res://scripts/combat/enemy_shape_cache.gd")
static func run(_host, verify:Callable) -> void:
	var cache=Cache.new()
	var first:ArrayMesh=cache.shape("normal",Color("b07670"),false)
	verify.call(first==cache.shape("normal",Color("b07670"),false) and cache.builds==1,"Static enemy geometry is retained and shared, not rebuilt per actor")
	for variant in ["normal","fast","heavy","flier"]:
		for detailed in [false,true]:
			for front in ([false,true] if variant=="flier" else [false]):
				var mesh:ArrayMesh=cache.shape(variant,Color("bd85db"),detailed,front)
				var data:Array=mesh.surface_get_arrays(0)
				verify.call(mesh.get_surface_count()==1 and data[Mesh.ARRAY_VERTEX].size()==data[Mesh.ARRAY_COLOR].size() and data[Mesh.ARRAY_INDEX].size()%3==0,"One ordered triangle surface preserves all static parts:"+variant+str(detailed)+str(front))
	var detailed:ArrayMesh=cache.shape("normal",Color("b07670"),true)
	verify.call(first!=detailed and first.get_aabb().size.y<detailed.get_aabb().size.y,"Detailed weapon/helmet silhouette has a separate mesh")
	var left:Variant=first.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	verify.call(first.get_aabb().position.y<=-52 and first.get_aabb().end.y<0 and left.size()>64,"Static body retains head fan/arms above the dynamic ground-contact limbs")
	for index in range(100):cache.shape("heavy",Color(float(index)/100,.25,.5),true)
	verify.call(cache.meshes.size()<=Cache.LIMIT,"Unusual diagnostic styles cannot grow the shared mesh cache beyond64 entries")
	var geometry=Cache.Geometry.new()
	geometry.draw_line(Vector2.ZERO,Vector2(10,0),Color.WHITE,5,true)
	verify.call(geometry.vertices.size()==36 and geometry.indices.size()==54,"Native AA stroke retains centre, four feather strips and four corner quads")
	verify.call(geometry.colors.count(Color(1,1,1,0))==20,"Feather triangles keep transparent edge colours instead of removing AA")
