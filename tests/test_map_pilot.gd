extends RefCounted
const Slots=preload("res://scripts/ui/asset_slots.gd")
const Renderer=preload("res://scripts/combat/high_angle_battle.gd")
const View=preload("res://scripts/combat/battle_view.gd")
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")

static func source_at(regions:Array,point:Vector2) -> Vector2:
	for region in regions:
		if region.destination.has_point(point):return region.source.position+(point-region.destination.position)*region.source.size/region.destination.size
	return Vector2(INF,INF)

static func run(host,verify:Callable) -> void:
	var slots=Slots.new()
	verify.call(slots.definitions.size()==53 and slots.definitions.values().all(func(p):return p==""),"Map pilot leaves every shared/character presentation path blank")
	verify.call(slots.map_definitions.keys()==["prologue_wall"] and slots.map_definitions.prologue_wall.size()==3,"Only the prologue receives the three pilot overrides")
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/pilot_01/source_manifest.json"))
	for asset in manifest.assets:
		var texture:Texture2D=slots.map_texture(asset.slot,"prologue_wall")
		verify.call(texture!=null and texture.get_size()==Vector2(asset.source_size[0],asset.source_size[1]) and FileAccess.get_sha256(texture.resource_path)==asset.sha256,"Production pilot loads the exact supplied PNG: "+str(asset.slot))
		verify.call(texture==slots.map_texture(asset.slot,"prologue_wall"),"Pilot resource is shared/cached: "+str(asset.slot))
		verify.call(slots.texture(asset.slot)==null and ["outskirts_trial","legacy_arena","gold_slime"].all(func(id):return slots.map_texture(asset.slot,id)==null),"Pilot cannot leak into global slots or another map: "+str(asset.slot))
	var crate:Image=slots.map_texture("prop_crate","prologue_wall").get_image()
	verify.call(crate.get_pixel(46,0).a==0 and crate.get_pixel(46,85).a>0,"Original crate padding and bottom contact row survive import")
	var path:="user://map-fallback-"+Crypto.new().generate_random_bytes(8).hex_encode()+".tres"
	var fallback:=GradientTexture2D.new()
	fallback.gradient=Gradient.new()
	ResourceSaver.save(fallback,path)
	slots.definitions.prop_crate=path
	verify.call(slots.map_texture("prop_crate","outskirts_trial")==slots.texture("prop_crate") and slots.map_texture("prop_crate","prologue_wall")!=slots.texture("prop_crate"),"Existing shared fallback remains available without overriding the pilot")
	for invalid in [null,5,[],{"prop_crate":5},{"prop_crate":"user://missing-pilot.png"}]:
		slots.map_definitions.prologue_wall=invalid
		verify.call(slots.map_texture("prop_crate","prologue_wall")==slots.texture("prop_crate"),"Invalid map-only entries preserve the existing fallback: "+str(invalid))
	DirAccess.remove_absolute(path)
	var world:=Rect2(53,0,211,1)
	var front:=Rect2(35,35,211,122)
	var window:=Rect2(0,0,320,200)
	var regions:Array=Renderer.material_regions(world,front,window,Vector2(192,244))
	var area:=0.0
	var bounded:=true
	for region in regions:
		area+=region.destination.get_area()
		bounded=bounded and front.encloses(region.destination) and window.encloses(region.destination) and Rect2(0,0,192,244).grow(.0001).encloses(region.source)
	verify.call(bounded and is_equal_approx(area,211*122),"Wall regions cover the exact face while both source and destination edges stay bounded")
	var shifted:Array=Renderer.material_regions(world,Rect2(front.position-Vector2(24,0),front.size),window,Vector2(192,244))
	verify.call(source_at(regions,Vector2(115,85)).is_equal_approx(source_at(shifted,Vector2(91,85))),"World-point wall UV stays fixed through a24pixel camera pan")
	var clipped:Array=Renderer.material_regions(world,Rect2(35,-25,211,122),window,Vector2(192,244))
	verify.call(is_equal_approx(clipped[0].source.position.y,50) and is_equal_approx(clipped[0].source.size.y,194),"Top viewport clipping crops matching source pixels instead of stretching the front")
	verify.call(Renderer.material_regions(world,Rect2(400,0,211,122),window,Vector2(192,244)).is_empty(),"Fully offscreen wall creates no unbounded material draw loop")
	for map_id in ["prologue_wall","outskirts_trial","gold_slime"]:
		var a=State.new()
		a.stage=2 if map_id=="outskirts_trial" else 1
		a.start(4101,"viya",null,map_id,"weapons_v1",{},"gold_slime" if map_id=="gold_slime" else "campaign",20000 if map_id=="gold_slime" else -1)
		var b=State.new()
		Snapshot.restore(Snapshot.capture(a),b)
		b.set_paused(false)
		var pilot=View.new()
		var plain=View.new()
		pilot.simulation=a
		plain.simulation=b
		pilot.size=Vector2(1000,480)
		plain.size=pilot.size
		plain.art.map_definitions={}
		host.add_child(pilot)
		host.add_child(plain)
		var same:=true
		for frame in range(100):
			a.step(.05,Vector2.RIGHT if frame<30 else Vector2.ZERO)
			b.step(.05,Vector2.RIGHT if frame<30 else Vector2.ZERO)
			pilot.queue_redraw()
			plain.queue_redraw()
			if frame%20==0:await host.get_tree().process_frame
			same=same and Campaign.comparable(a)==Campaign.comparable(b)
		verify.call(same and Snapshot.VERSION==18 and Snapshot.valid(Snapshot.capture(a),a),"Pilot/placeholder views preserve all authoritative fields and seven RNG over100production steps: "+map_id)
		pilot.queue_free()
		plain.queue_free()
		await host.get_tree().process_frame
