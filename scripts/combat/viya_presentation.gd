extends RefCounted
## One hero's derived gait, gun height and transparent texture validation.
## No projectile, damage, clock, save, RNG or source-image mutation.
var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/viya_motion.json"))
var _alpha:Dictionary={}
static var _verified_alpha:Dictionary={} # Immutable texture instances; bounded across views.
var _decoded:Dictionary={}
var _shot_offsets:Dictionary={}
var _run_id:String=""
var _clock:float=-1
var _view_key:String=""

func accepts(view) -> bool:
	var asset:Resource=view.art.resource("viya_battle")
	return asset!=null and asset.resource_path==config.resource

func transparent(texture:Texture2D) -> bool:
	var key:int=texture.get_instance_id()
	if _alpha.has(key):return _alpha[key]
	if _verified_alpha.has(key):
		_alpha[key]=_verified_alpha[key]
		return _alpha[key]
	var pixels:Image=texture.get_image()
	var valid:bool=pixels!=null and not pixels.is_empty() and pixels.detect_alpha()!=Image.ALPHA_NONE
	if valid:
		for point in [Vector2i.ZERO,Vector2i(pixels.get_width()-1,0),Vector2i(0,pixels.get_height()-1),pixels.get_size()-Vector2i.ONE]:
			valid=valid and pixels.get_pixelv(point).a<.01
		for uv in [Vector2(.04,.04),Vector2(.96,.04),Vector2(.04,.96),Vector2(.96,.96),Vector2(.08,.065),Vector2(.92,.065)]:
			valid=valid and pixels.get_pixelv(Vector2i(uv*Vector2(pixels.get_size()-Vector2i.ONE))).a<.01
	_alpha[key]=valid
	if _verified_alpha.size()>=512:_verified_alpha.clear()
	_verified_alpha[key]=valid
	return valid

func decoded(path:String) -> Texture2D:
	var root:String=str(config.resource).get_base_dir().get_base_dir()+"/"
	if not path.begins_with(root) or not path.ends_with(".png") or ".." in path:return null
	if _decoded.has(path):return _decoded[path]
	if not FileAccess.file_exists(path):return null
	var pixels:=Image.new()
	if pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK or pixels.is_empty():return null
	var texture:=ImageTexture.create_from_image(pixels)
	if not transparent(texture):return null
	_decoded[path]=texture
	return texture

func apply(view, visual:Dictionary) -> void:
	if not accepts(view):return
	var gun_aim:Vector2=visual.get("gun_aim",Vector2.ZERO)
	if visual.pose!="hurt" and float(visual.get("shot_age",1000))<.4 and not gun_aim.is_zero_approx():
		visual.facing=gun_aim
		visual.direction=view.actors.DIRECTIONS[posmod(roundi(view.project_direction(gun_aim).angle()/(PI/4)),8)]
	var row:Dictionary=config.directions[visual.direction]
	var selected:String="hurt" if visual.pose=="hurt" else ("run" if visual.moving else "idle")
	var region:Rect2
	var muzzle_pixels:=Vector2(row.muzzle[0],row.muzzle[1])
	var clock:float=visual.clock
	if selected=="run":
		var travel:float=float(visual.distance)
		if visual.get("motion",Vector2.ZERO).dot(visual.facing)< -.2:travel= -travel
		var index:int=floori(fposmod(travel,float(config.stride_world))/float(config.stride_world)*row.run.size())
		var frame:Dictionary=row.run[index]
		clock=float(frame.index)/16.6666666667+.000001
		region=Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
		muzzle_pixels=Vector2(frame.muzzle[0],frame.muzzle[1])
	elif selected=="idle":region=Rect2(row.idle_region[0],row.idle_region[1],row.idle_region[2],row.idle_region[3])
	visual.sample=view.actor_art.frame(view.art,["viya_battle"],selected,visual.direction,clock,view.size)
	if visual.sample.is_empty():return
	if not transparent(visual.sample.texture):
		var root:String=str(config.resource).get_base_dir().get_base_dir()
		var expected:String=root.path_join("textures/viya_idle_"+str(visual.direction)+".png") if selected=="idle" else root.path_join("frames/viya_%s_%s_%02d.png" % [selected,visual.direction,int(visual.sample.index)])
		var repaired:Texture2D=decoded(expected)
		if repaired==null:
			visual.sample={}
			return # An opaque/stale import can never become a white rectangle.
		visual.sample.texture=repaired # Same PNG pixels, bypassing a damaged import.
	visual.region=region
	visual.recoil=maxf(0,1-float(visual.get("shot_age",visual.clock))/.12) if visual.pose=="attack" else 0.0
	visual.muzzle=muzzle_pixels

static func body_rect(art, visual:Dictionary, feet:Vector2) -> Rect2:
	var box:Rect2=art.rectangle(visual.sample,feet)
	var source:Rect2=visual.get("region",Rect2())
	if source.has_area():
		# Translate the source contact to the ground; never stretch body proportions.
		box.size.y*=source.size.y/248.0
		box.position.y=feet.y-box.size.y
	return box

static func muzzle(art, visual:Dictionary, feet:Vector2) -> Vector2:
	if visual.sample.is_empty() or not visual.has("muzzle"):return feet+Vector2(0,-34)
	var box:Rect2=body_rect(art,visual,feet)
	var source:Rect2=visual.get("region",Rect2(0,0,200,248))
	if not source.has_area():source=Rect2(0,0,200,248)
	return box.position+(visual.muzzle-source.position)/source.size*box.size

static func draw(canvas, art, visual:Dictionary, feet:Vector2) -> void:
	var box:Rect2=body_rect(art,visual,feet)
	var texture:Texture2D=visual.sample.texture
	var source:Rect2=visual.get("region",Rect2())
	if not source.has_area():
		canvas.draw_texture_rect(texture,box,false,Color.WHITE)
		return
	# A single textured primitive avoids the independent strip boundaries that
	# can show seams on compatibility drivers. Idle/run needs no mesh at all.
	var recoil:Vector2=canvas.project_direction(visual.facing).normalized()*float(visual.get("recoil",0))*box.size.y*.009
	if recoil.is_zero_approx():canvas.draw_texture_rect_region(texture,box,source)
	else:
		var vertices:=PackedVector2Array()
		var uv:=PackedVector2Array()
		var indices:=PackedInt32Array()
		for row in range(13):
			var t:float=row/12.0
			var shift:Vector2=-recoil*(1-smoothstep(.25,.55,t))
			for side in range(2):
				vertices.append(box.position+Vector2(side*box.size.x,t*box.size.y)+shift)
				uv.append((source.position+Vector2(side*source.size.x,t*source.size.y))/texture.get_size())
			if row<12:
				var start:int=row*2
				indices.append_array(PackedInt32Array([start,start+1,start+3,start,start+3,start+2]))
		var arrays:=[]
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_TEX_UV]=uv
		arrays[Mesh.ARRAY_INDEX]=indices
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		# Canvas draw commands keep a RID; retain its owner until the next redraw.
		canvas.set_meta("viya_recoil_mesh",mesh)
		canvas.draw_mesh(mesh,texture)
	if visual.pose=="attack" and float(visual.get("shot_age",1000))<.075:
		var at:Vector2=muzzle(art,visual,feet)
		var aim:Vector2=canvas.project_direction(visual.facing).normalized()
		var normal:Vector2=aim.orthogonal()
		var scale:float=box.size.y/155
		canvas.draw_colored_polygon(PackedVector2Array([at-aim*2*scale,at+normal*4*scale,at+aim*13*scale,at-normal*4*scale]),Color("ffe3a2",.9))

func projectile(view, bullet:Dictionary) -> Dictionary:
	var at:Vector2=view.world_to_screen(bullet.p)
	var direction:Vector2=view.project_direction(bullet.direction).normalized()
	var source:String=str(bullet.get("source","rifle"))
	if not accepts(view) or (source not in ["rifle","scatter","lance","crossfire","heavy","viya_runebullet_v1"] and not source.begins_with("gun_")) or bullet.get("weapon",{}).get("fragment",false):return {"p":at,"direction":direction}
	var age:float=float(bullet.get("age",maxf(0,.75-float(bullet.life))))
	var travel:float=maxf(0,age*float(bullet.speed))
	if travel>=180:return {"p":at+Vector2(0,-20),"direction":direction}
	var view_key:String=str(view.size)+str(view.high_angle)+str(view.uses_oblique())
	if _run_id!=view.simulation.run_id or view.simulation.elapsed<_clock or view_key!=_view_key:
		_shot_offsets.clear()
		_run_id=view.simulation.run_id
		_view_key=view_key
	_clock=view.simulation.elapsed
	var born:int=roundi((view.simulation.elapsed-age)*100000)
	if not _shot_offsets.has(born):
		var visual:Dictionary=view.actor_visual()
		var feet:Vector2=view.world_to_screen(view.simulation.player)
		_shot_offsets[born]=muzzle(view.actor_art,visual,feet)-feet
		if _shot_offsets.size()>32:_shot_offsets.erase(_shot_offsets.keys().min())
	var offset:Vector2=_shot_offsets[born]
	var weight:float=1-smoothstep(0,180,travel)
	var previous_weight:float=1-smoothstep(0,180,maxf(0,travel-12))
	var target_height:=Vector2(0,-20)
	var previous:Vector2=at-direction*12+target_height+(offset-target_height)*previous_weight
	var shown:Vector2=at+target_height+(offset-target_height)*weight
	return {"p":shown,"direction":(shown-previous).normalized()}
