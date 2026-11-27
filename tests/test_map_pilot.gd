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
	verify.call(slots.definitions.size()==53 and slots.definitions.viya_battle=="res://assets/characters/pilot_32/game067_se_run_fire/viya_game067_frames.tres" and slots.definitions.keys().all(func(k):return k=="viya_battle" or slots.definitions[k]==""),"Map pilot is unchanged; only the explicitly supplied Viya pilot with its E derivative occupies its shared slot")
	verify.call(slots.map_definitions.keys()==["prologue_wall","siege_battlefield","outskirts_trial"] and slots.map_definitions.prologue_wall.size()==12 and slots.map_definitions.siege_battlefield==slots.map_definitions.prologue_wall and slots.map_definitions.outskirts_trial.size()==2,"Prologue and stage1 share twelve originals; outskirts explicitly reuses only the two ruin face/top materials")
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/pilot_01/source_manifest.json"))
	var second:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/pilot_02/source_manifest.json"))
	manifest.assets.append_array(second.assets)
	var third:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/pilot_03/source_manifest.json"))
	manifest.assets.append_array(third.assets)
	var fourth:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/pilot_04/source_manifest.json"))
	manifest.assets.append_array(fourth.assets)
	for asset in manifest.assets:
		var source_size:Array=asset.get("source_size",asset.get("size_px",[]))
		var texture:Texture2D=slots.map_texture(asset.slot,"prologue_wall")
		verify.call(texture!=null and texture.get_size()==Vector2(source_size[0],source_size[1]) and FileAccess.get_sha256(texture.resource_path)==asset.sha256,"Production pilot loads the exact supplied PNG: "+str(asset.slot))
		verify.call(texture==slots.map_texture(asset.slot,"prologue_wall"),"Pilot resource is shared/cached: "+str(asset.slot))
		var ruin_slot:bool=asset.slot in ["ruin_block","ruin_top_tile"]
		verify.call(slots.texture(asset.slot)==null and ["legacy_arena","gold_slime"].all(func(id):return slots.map_texture(asset.slot,id)==null) and (slots.map_texture(asset.slot,"outskirts_trial")==texture if ruin_slot else slots.map_texture(asset.slot,"outskirts_trial")==null),"Only explicitly shared ruin materials reach outskirts; all other map/global bindings stay isolated: "+str(asset.slot))
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
	top_regions(verify)
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
		verify.call(same and Snapshot.VERSION==22 and Snapshot.valid(Snapshot.capture(a),a),"Pilot/placeholder views preserve all authoritative fields and seven RNG over100production steps: "+map_id)
		pilot.queue_free()
		plain.queue_free()
		await host.get_tree().process_frame

static func top_regions(verify:Callable) -> void:
	var gy:float=preload("res://scripts/combat/battle_projection.gd").GROUND_Y
	var world:=Rect2(53,47,211,121)
	var top:=Rect2(Vector2(35,35),Vector2(211,121*gy))
	var window:=Rect2(0,0,320,200)
	var regions:Array=Renderer.top_material_regions(world,top,window,Vector2(192,160))
	var area:=0.0
	var bounded:=true
	var no_overlap:=true
	for i in range(regions.size()):
		var region:Dictionary=regions[i]
		area+=region.destination.get_area()
		bounded=bounded and top.grow(.001).encloses(region.destination) and window.encloses(region.destination) and Rect2(0,0,192,160).grow(.001).encloses(region.source)
		for j in range(i):no_overlap=no_overlap and not region.destination.intersects(regions[j].destination)
	verify.call(bounded and is_equal_approx(area,top.get_area()),"Top tiles cover the exact projected face without source or destination overflow")
	verify.call(no_overlap and regions.size()==9,"Two-axis top tiles have no overlap or double alpha at internal edges")
	var point:Vector2=top.position+(Vector2(115,85)-world.position)*Vector2(1,gy)
	verify.call(source_at(regions,point).is_equal_approx(Vector2(38,10)),"Both top UV axes use the global96x80world grid, not the obstacle or screen origin")
	var shifted:Array=Renderer.top_material_regions(world,Rect2(top.position-Vector2(24,13),top.size),window,Vector2(192,160))
	verify.call(source_at(regions,point).is_equal_approx(source_at(shifted,point-Vector2(24,13))),"Top world-point UV survives camera motion in both axes")
	var reversed:Array=Renderer.top_material_regions(world,Rect2(top.position+Vector2(24,13),top.size),Rect2(0,0,640,400),Vector2(192,160))
	verify.call(source_at(regions,point).is_equal_approx(source_at(reversed,point+Vector2(24,13))),"Camera reversal and viewport resize cannot reset top tile phase")
	var edge_top:=Rect2(Vector2(-20,-13),top.size)
	var edge_window:=Rect2(0,0,150,75)
	var edge:Array=Renderer.top_material_regions(world,edge_top,edge_window,Vector2(192,160))
	var full:Array=Renderer.top_material_regions(world,edge_top,Rect2(-1000,-1000,2000,2000),Vector2(192,160))
	verify.call(source_at(edge,Vector2(20,10)).is_equal_approx(source_at(full,Vector2(20,10))),"Viewport clipping crops matching top source pixels rather than stretching partial tiles")
	area=0
	bounded=true
	for region in edge:
		area+=region.destination.get_area()
		bounded=bounded and edge_window.encloses(region.destination) and Rect2(0,0,192,160).grow(.001).encloses(region.source)
	verify.call(bounded and is_equal_approx(area,edge_top.intersection(edge_window).get_area()),"Top clips exactly against both obstacle and viewport bounds")
	verify.call(regions.all(func(r):return (r.source.size/r.destination.size).is_equal_approx(Vector2(2,2/gy))),"Top Y projection occurs exactly once while source aspect and texel density stay intact")
	var sliver:Array=Renderer.top_material_regions(Rect2(0,0,5000,420),Rect2(Vector2(-2048,-100),Vector2(5000,420*gy)),Rect2(0,0,7,5),Vector2(192,160))
	verify.call(not sliver.is_empty() and sliver.size()<=4,"Huge wall through a tiny viewport plans only visible top tiles")
	verify.call(Renderer.top_material_regions(world,Rect2(400,300,211,121*gy),window,Vector2(192,160)).is_empty(),"Fully offscreen top produces no draw work")
	verify.call(Renderer.top_material_regions(Rect2(),top,window,Vector2(192,160)).is_empty() and Renderer.top_material_regions(world,top,window,Vector2.ZERO).is_empty(),"Empty top dimensions or texture cannot produce invalid tile loops")
