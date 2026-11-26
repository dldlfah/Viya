extends RefCounted
const Space=preload("res://scripts/world/map_space.gd")
const Reference=preload("res://tests/fixtures/game050_v21/map_space_before.gd")

static func run(_host,verify:Callable):
	var catalog=preload("res://scripts/world/map_catalog.gd").new()
	var rng=RandomNumberGenerator.new();rng.seed=5201
	for id in ["siege_battlefield","prologue_wall","outskirts_trial","legacy_arena"]:
		var data:Dictionary=catalog.definition(id)
		var fast=Space.new(data);var old=Reference.new(data)
		var visible:=true;var motion:=true;var routes:=true
		for index in range(500):
			var a:=Vector2(rng.randf_range(-60,fast.world_size.x+60),rng.randf_range(-60,fast.world_size.y+60))
			var b:=Vector2(rng.randf_range(-60,fast.world_size.x+60),rng.randf_range(-60,fast.world_size.y+60))
			var radius:float=[0.0,4.0,24.0,30.0,297.095][index%5]
			visible=visible and fast.line_clear(a,b,radius)==(old.wall_fraction(a,b,radius)>=1.0)
			motion=motion and fast.move(a,b-a,radius)==old.move(a,b-a,radius)
			if index<40:routes=routes and fast.route_target(a,b,24)==old.route_target(a,b,24)
		verify.call(visible,"Early exit preserves500 original line-of-sight predicates with exact intersection arithmetic: "+id)
		verify.call(motion,"Axis bins preserve500 original long/diagonal/negative/boundary-clamped sweeps: "+id)
		verify.call(routes,"Moving goals retain40 original route choices and ties: "+id)
	# Bin boundaries are inclusive; keep original wall order and re-bucket after X.
	var fast=Space.new(catalog.definition("siege_battlefield"))
	var old=Reference.new(fast.definition)
	fast.solids.assign([Rect2(255,255,2,2),Rect2(-256,-256,80,80),Rect2(500,0,30,800)])
	old.solids.assign(fast.solids)
	fast.play_bounds=Rect2(-1000,-1000,5000,5000);old.play_bounds=fast.play_bounds
	var edges:=true
	for radius in [0.0,4.0,24.0]:
		for y in [-256.01,-256.0,-255.99,0.0,255.0,255.99,256.0,256.01,257.0,512.0]:
			for from in [Vector2(80,y),Vector2(255,y),Vector2(256,y),Vector2(512,y)]:
				for delta in [Vector2.ZERO,Vector2(800,800),Vector2(-800,-800),Vector2(0,.0001)]:
					edges=edges and fast.move(from,delta,radius)==old.move(from,delta,radius)
					edges=edges and fast.line_clear(from,from+delta,radius)==(old.wall_fraction(from,from+delta,radius)>=1.0)
	verify.call(edges,"Signed bin edges/starts inside/on corners/zero/grazing/axis-update sweeps preserve original results")
	fast.solids.clear();fast.solids.append(Rect2(0,0,2000000,2000000));old.solids.assign(fast.solids)
	verify.call(fast._walls(24).axes.is_empty() and fast.move(Vector2(400,400),Vector2(100,100),24)==old.move(Vector2(400,400),Vector2(100,100),24),"Oversized diagnostic geometry falls back to bounded original full sweeps")
	fast.solids.clear();fast.solids.append(Rect2(300,400,80,80));old.solids.assign(fast.solids)
	verify.call(not fast._walls(24).axes.is_empty() and fast.move(Vector2(200,450),Vector2(400,0),24)==old.move(Vector2(200,450),Vector2(400,0),24),"Geometry mutation invalidates wall/bucket/route caches together")
