extends RefCounted
## One hero's derived gait, gun height and transparent texture validation.
## No projectile, damage, clock, save, RNG or source-image mutation.
var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/viya_motion.json"))
var _alpha:Dictionary={}
static var _verified_alpha:Dictionary={} # Immutable texture instances; bounded across views.
var _decoded:Dictionary={}
var _run_seconds:Dictionary={}
var _fire_clips:Dictionary={}
var _shot_offsets:Dictionary={}
var _run_id:String=""
var _clock:float=-1
var _view_key:String=""
var _gait_run:String=""
var _gait_time:float=-1.0
var _distance:float=0.0
var _phase:float=0.0
var _direction:String=""
var _burst_since:float=-1.0
var _gun_until:float=-1.0
var _interrupted_shot:float=-INF

func direction_for(view, facing:Vector2, fallback:String) -> String:
	var projected:Vector2=view.project_direction(facing)
	if projected.is_zero_approx():return fallback
	var angle:float=projected.angle()
	var wanted:String=view.actors.DIRECTIONS[posmod(roundi(angle/(PI/4)),8)]
	if _direction.is_empty():return wanted
	var old_angle:float=view.actors.DIRECTIONS.find(_direction)*PI/4
	# Angular Schmitt trigger: no delay for large turns, no boundary chatter.
	if absf(wrapf(angle-old_angle,-PI,PI))<=PI/8+deg_to_rad(float(config.direction_hysteresis_degrees)):return _direction
	return wanted

func accepts(view) -> bool:
	var asset:Resource=view.art.resource("viya_battle")
	return asset!=null and asset.resource_path==config.resource

func transparent(texture:Texture2D) -> bool:
	if texture==null:return false
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

func phase_clock(asset:SpriteFrames, animation:String, phase:float) -> float:
	if asset==null or not asset.has_animation(animation):return 0.0
	var key:String=str(asset.get_instance_id())+":"+animation
	if not _run_seconds.has(key):
		var speed:float=asset.get_animation_speed(animation)
		if not is_finite(speed) or speed<=0:return 0.0
		var duration:float=0.0
		for index in range(asset.get_frame_count(animation)):
			duration+=asset.get_frame_duration(animation,index)
		if not is_finite(duration) or duration<=0:return 0.0
		_run_seconds[key]=duration/speed
	# Distance owns the gait. The shared sampler resolves the actual weighted
	# frame durations; no second animation clock or equal-frame phase mapping.
	var seconds:float=float(_run_seconds[key])
	# Round-trip floating point must not move an exact authored boundary to
	# the previous frame (e.g. 3/11). Keep the seam on the final distinct frame.
	return minf(fposmod(phase,1.0)*seconds+.000000001,seconds-.000000001)

func run_clock(asset:SpriteFrames, direction:String, phase:float) -> float:
	return phase_clock(asset,"run_"+direction,phase)

func moving_fire_ready(asset:SpriteFrames, row:Dictionary, direction:String="e") -> bool:
	# Optional whole-body art: absence must keep the accepted run, never fall
	# through the shared sampler's generic idle fallback.
	if direction not in ["e","se","s"]:return false
	var animation:String="run_fire_"+direction
	if asset==null or not asset.has_animation(animation):return false
	var rows:Variant=row.get("run_fire")
	if not rows is Array or rows.is_empty() or rows.size()!=asset.get_frame_count(animation):return false
	var speed:float=asset.get_animation_speed(animation)
	if not asset.get_animation_loop(animation) or not is_finite(speed) or speed<=0:return false
	var origin:Variant=row.get("run_fire_phase_origin")
	if not (origin is int or origin is float) or not is_finite(float(origin)) or float(origin)<0 or float(origin)>=1:return false
	var key:String=str(asset.get_instance_id())+":"+animation+":"+str(rows.hash())+":"+str(speed)
	if _fire_clips.has(key):return _fire_clips[key]
	var valid:=true
	var root:String=str(config.resource).get_base_dir().get_base_dir()+"/"
	for index in range(rows.size()):
		var item:Variant=rows[index]
		if not item is Dictionary:
			valid=false
			break
		var frame_index:Variant=item.get("index")
		var region:Variant=item.get("region")
		var muzzle:Variant=item.get("muzzle")
		var path:Variant=item.get("texture")
		var texture:Texture2D=asset.get_frame_texture(animation,index)
		var duration:float=asset.get_frame_duration(animation,index)
		if direction in ["se","s"]:
			var milliseconds:Variant=item.get("duration_ms")
			if not (milliseconds is int or milliseconds is float) or not is_finite(float(milliseconds)) or float(milliseconds)<=0 or absf(duration/speed*1000.0-float(milliseconds))>.000001:
				valid=false
				break
		if not (frame_index is int or frame_index is float) or float(frame_index)!=index or not region is Array or region.size()!=4 or not muzzle is Array or muzzle.size()!=2 or not path is String:
			valid=false
			break
		# JSON numbers are floats; Array equality also compares element types.
		if not region.all(func(value):return (value is int or value is float) and is_finite(float(value))) or float(region[0])!=0.0 or float(region[1])!=0.0 or float(region[2])!=200.0 or float(region[3])!=248.0:
			valid=false
			break
		if not muzzle.all(func(value):return (value is int or value is float) and is_finite(float(value))) or float(muzzle[0])<0 or float(muzzle[0])>200 or float(muzzle[1])<0 or float(muzzle[1])>248:
			valid=false
			break
		if not path.begins_with(root) or not path.ends_with(".png") or ".." in path or not FileAccess.file_exists(path) or texture==null or texture.get_size()!=Vector2(200,248) or not is_finite(duration) or duration<=0:
			valid=false
			break
		if not texture.resource_path.is_empty() and texture.resource_path!=path:
			valid=false
			break
	if _fire_clips.size()>=8:_fire_clips.clear()
	_fire_clips[key]=valid
	return valid

func repair_sample(visual:Dictionary, selected:String, run_frame:Dictionary) -> bool:
	if visual.sample.is_empty() or visual.sample.texture.get_size()!=Vector2(200,248):return false
	if not transparent(visual.sample.texture):
		var root:String=str(config.get("fallback_texture_root",str(config.resource).get_base_dir()))
		var expected:String=root.path_join("viya_idle_"+str(visual.direction)+".png") if selected=="idle" else root.path_join("viya_%s_%s_%02d.png" % [selected,visual.direction,int(visual.sample.index)])
		if run_frame.has("texture"):expected=str(run_frame.texture)
		var repaired:Texture2D=decoded(expected)
		if repaired==null or repaired.get_size()!=Vector2(200,248):return false
		visual.sample.texture=repaired # Same PNG pixels, bypassing a damaged import.
	return true

func observe_gait(view) -> void:
	if view.art.definitions.get("viya_battle", "") == config.resource:
		_advance_gait(view, view.actors.pose(view.simulation))

func _advance_gait(view, visual:Dictionary) -> bool:
	var now:float=view.simulation.elapsed
	var distance:float=float(visual.get("distance",0))
	if _gait_run!=view.simulation.run_id or now<_gait_time or distance<_distance:
		_gait_run=view.simulation.run_id
		_distance=distance
		_phase=0
		_direction=""
		_burst_since=-1
		_gun_until=-1
		_interrupted_shot=-INF
	_gait_time=now
	var gun_aim:Vector2=visual.get("gun_aim",Vector2.ZERO)
	var shot_age:float=float(visual.get("shot_age",1000))
	var gun_active:bool=shot_age<.4 and not gun_aim.is_zero_approx()
	if visual.pose=="hurt":
		_interrupted_shot=maxf(_interrupted_shot,now-shot_age)
		_burst_since=-1
	gun_active=gun_active and now-shot_age>_interrupted_shot+.000001
	if visual.pose!="hurt" and gun_active:
		visual.facing=gun_aim
	_direction=direction_for(view,visual.facing,visual.direction)
	visual.direction=_direction
	# Reverse only the next increment. Negating the accumulated travel reflected
	# the current phase and teleported the legs whenever a target crossed behind.
	var sign:float=-1.0 if visual.get("motion",Vector2.ZERO).dot(visual.facing)<-.2 else 1.0
	if visual.moving:_phase=fposmod(_phase+sign*maxf(0,distance-_distance)/float(config.stride_world),1.0)
	_distance=distance
	visual.gait_phase=_phase
	return gun_active

func apply(view, visual:Dictionary) -> void:
	if not accepts(view):return
	var gun_active := _advance_gait(view, visual)
	var now:float=view.simulation.elapsed
	var shot_age:float=float(visual.get("shot_age",1000))
	var row:Dictionary=config.directions[visual.direction]
	var selected:String="hurt" if visual.pose=="hurt" else ("run" if visual.moving else "idle")
	var region:=Rect2(0,0,200,248)
	var muzzle_pixels:=Vector2(row.muzzle[0],row.muzzle[1])
	var clock:float=visual.clock
	if selected=="run":
		clock=run_clock(view.art.resource("viya_battle"),visual.direction,_phase+float(row.phase_origin))
		if visual.direction in ["e","se","s"] and gun_active and moving_fire_ready(view.art.resource("viya_battle"),row,visual.direction):
			selected="run_fire"
			clock=phase_clock(view.art.resource("viya_battle"),"run_fire_"+visual.direction,_phase+float(row.get("run_fire_phase_origin",row.phase_origin)))
	# Play the original whole-body attack once per stationary burst, not per
	# projectile. Continuous .3s fire holds the aimed end pose between shots.
	if selected=="idle" and gun_active:
		if _burst_since<0 or now>_gun_until:_burst_since=now-maxf(0,shot_age)
		selected="attack"
		clock=minf(maxf(0,now-_burst_since),float(row.attack_hold_frame)/50.0+.000001)
		muzzle_pixels=Vector2(row.attack_muzzle[0],row.attack_muzzle[1])
	elif selected!="hurt":_burst_since=-1
	if gun_active:_gun_until=maxf(_gun_until,now-shot_age+.4)
	visual.sample=view.actor_art.frame(view.art,["viya_battle"],selected,visual.direction,clock,view.size)
	var run_frame:Dictionary={}
	if selected=="run_fire" and visual.sample.get("animation","")!="run_fire_"+visual.direction:visual.sample={}
	if not visual.sample.is_empty() and selected in ["run","run_fire"]:run_frame=row[selected][int(visual.sample.index)]
	if not repair_sample(visual,selected,run_frame):
		if selected!="run_fire":
			visual.sample={}
			return # An opaque/stale import can never become a white rectangle.
		# An unavailable firing texture must not freeze the feet or reset gait.
		selected="run"
		clock=run_clock(view.art.resource("viya_battle"),visual.direction,_phase+float(row.phase_origin))
		visual.sample=view.actor_art.frame(view.art,["viya_battle"],selected,visual.direction,clock,view.size)
		if visual.sample.is_empty():return
		run_frame=row.run[int(visual.sample.index)]
		if not repair_sample(visual,selected,run_frame):
			visual.sample={}
			return
	if not run_frame.is_empty():muzzle_pixels=Vector2(run_frame.muzzle[0],run_frame.muzzle[1])
	visual.region=region
	visual.recoil=0.0 # Native whole-body frames; no upper-body mesh deformation.
	visual.muzzle=muzzle_pixels

static func body_rect(art, visual:Dictionary, feet:Vector2) -> Rect2:
	var box:Rect2=art.rectangle(visual.sample,feet)
	var source:Rect2=visual.get("region",Rect2())
	if source.has_area():
		# Preserve the original canvas/root across poses. Pinning each changing
		# alpha bounding box to the floor moved the entire head/torso every frame.
		var full:Rect2=box
		box.position=full.position+source.position/Vector2(200,248)*full.size
		box.size=source.size/Vector2(200,248)*full.size
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
	# One primitive for every pose: no independent strips, seams or mesh churn.
	if source==Rect2(Vector2.ZERO,texture.get_size()):canvas.draw_texture_rect(texture,box,false,Color.WHITE)
	else:canvas.draw_texture_rect_region(texture,box,source)
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
