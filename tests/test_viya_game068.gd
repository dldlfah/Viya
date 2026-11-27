extends RefCounted
const Presenter=preload("res://scripts/combat/viya_presentation.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Prior=preload("res://assets/characters/pilot_32/game067_se_run_fire/viya_game067_frames.tres")
const Reader=preload("res://tests/test_viya_game067.gd")
const CSV="res://assets/characters/pilot_32/game068_s_run/provenance/frame_timing.csv"
const META="res://assets/characters/pilot_32/game068_s_run/provenance/clip_metadata.json"
const PHASE="res://assets/characters/pilot_32/game068_s_run/provenance/phase_alignment.json"
const MANIFEST="res://assets/characters/pilot_32/game068_s_run/manifest.json"

static func begin(view,phase:float) -> Dictionary:
	var forward:Vector2=view.input_direction(Vector2.DOWN)
	var visual:Dictionary={"pose":"run","direction":"s","facing":forward,"motion":forward,"clock":0.0,"moving":true,"distance":0.0,"shot_age":1000.0,"gun_aim":Vector2.ZERO,"sample":{}}
	view.viya._gait_run=""
	view.viya.apply(view,visual)
	visual.distance=fposmod(phase,1.0)*155.0
	view.viya.apply(view,visual)
	return visual

static func frame(visual:Dictionary,name:String,index:int=-1) -> bool:
	return not visual.sample.is_empty() and visual.sample.animation==name and (index<0 or visual.sample.index==index)

static func run(view,asset:SpriteFrames,verify:Callable) -> void:
	var preserved:=true
	var total:=0
	for name in Prior.get_animation_names():
		if name=="run_s":continue
		var count:int=Prior.get_frame_count(name)
		total+=count
		if not asset.has_animation(name) or asset.get_frame_count(name)!=count:
			preserved=false
			continue
		preserved=preserved and asset.get_animation_loop(name)==Prior.get_animation_loop(name) and asset.get_animation_speed(name)==Prior.get_animation_speed(name)
		for index in range(count):
			preserved=preserved and asset.get_frame_texture(name,index).resource_path==Prior.get_frame_texture(name,index).resource_path and asset.get_frame_duration(name,index)==Prior.get_frame_duration(name,index)
	verify.call(preserved and total==307 and asset.get_animation_names().size()==34,"GAME068 live resource preserves all33other clips/307resolved frames and exact weights/speeds/loops")
	var timing:Array=Reader.read_timing(CSV)
	var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(META))
	var alignment:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PHASE))
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var rows:Array=view.viya.config.directions.s.run
	verify.call(asset.get_frame_count("run_s")==17 and asset.get_animation_loop("run_s") and not asset.has_animation("run_fire_s") and timing.size()==17 and rows.size()==17,"Only S ordinary running is replaced by17 native frames; no fabricated S firing clip")
	if timing.size()!=17 or rows.size()!=17:return
	var speed:float=asset.get_animation_speed("run_s")
	var elapsed:=0.0
	var valid:=true
	var pixels_match:=true
	var hashes:Dictionary={}
	for index in range(17):
		var row:Dictionary=timing[index]
		valid=valid and row.index==index and row.duration_ms>0 and absf(row.start_ms-elapsed)<.000001
		valid=valid and speed>0 and absf(asset.get_frame_duration("run_s",index)/speed*1000.0-row.duration_ms)<.000001
		elapsed+=row.duration_ms
		var path:String=rows[index].texture
		var image:=Image.new()
		var loaded:bool=image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))==OK
		pixels_match=pixels_match and loaded and image.get_size()==Vector2i(200,248) and asset.get_frame_texture("run_s",index).resource_path==path
		if loaded:pixels_match=pixels_match and image.get_data()==asset.get_frame_texture("run_s",index).get_image().get_data() and image.get_pixel(0,0).a==0 and image.get_pixel(199,247).a==0
		hashes[FileAccess.get_sha256(path)]=true
		pixels_match=pixels_match and FileAccess.get_sha256(path)==manifest.frame_checks[index].sha256
	verify.call(valid and absf(elapsed-660)<.000001,"Every S PTS-derived frame weight preserves the delivered timing within1microsecond and sums to660ms")
	verify.call(pixels_match and hashes.size()==17,"All17distinct S PNGs import pixel-identically with fixed canvas and clear alpha; no second matte")
	var origin:float=view.viya.config.directions.s.phase_origin
	verify.call(is_equal_approx(origin,metadata.phase_origin) and is_equal_approx(origin,alignment.recommended_phase_origin) and not is_equal_approx(origin,3.0/11.0) and alignment.anchors.size()==2,"S uses its independently measured opposite-support phase metadata, not the previous3/11")
	var original=view.viya
	view.viya=Presenter.new()
	var saved:Dictionary=Snapshot.capture(view.simulation)
	var cues:Dictionary=view.simulation.cues.snapshot()
	var midpoints:=true
	var boundaries:=true
	var muzzles:=true
	for index in range(17):
		var row:Dictionary=timing[index]
		var phase:float=(row.start_ms+row.duration_ms*.5)/660.0-origin
		var visual:Dictionary=begin(view,phase)
		midpoints=midpoints and frame(visual,"run_s",index)
		muzzles=muzzles and visual.muzzle==Vector2(metadata.frames[index].muzzle[0],metadata.frames[index].muzzle[1])
		var end:float=row.start_ms+row.duration_ms
		boundaries=boundaries and frame(begin(view,(end-.001)/660.0-origin),"run_s",index) and frame(begin(view,(end+.001)/660.0-origin),"run_s",(index+1)%17)
	verify.call(midpoints and muzzles,"Actual S adapter resolves all17 authored midpoints and their independently measured muzzle coordinates")
	verify.call(boundaries,"Every S boundary including last-to-first switches correctly1microsecond either side")
	var visual:Dictionary=begin(view,.373)
	var index:int=visual.sample.index
	var held:float=visual.gait_phase
	visual.pose="attack";visual.shot_age=.01;visual.gun_aim=visual.facing
	view.viya.apply(view,visual)
	verify.call(frame(visual,"run_s",index) and is_equal_approx(visual.gait_phase,held) and visual.recoil==0,"Committed S gunfire preserves the same whole-body run phase without a dedicated firing asset or mesh deformation")
	var feet:=Vector2(200,180)
	var muzzle:Vector2=view.viya.muzzle(view.actor_art,visual,feet)
	var box:Rect2=view.viya.body_rect(view.actor_art,visual,feet)
	verify.call(box.size==Vector2(69,85.56) and box.end.y==feet.y and muzzle.distance_to(feet)>20,"S drawing keeps the original display/root and its gun-height muzzle")
	var se:Vector2=view.input_direction(Vector2(1,1).normalized())
	visual.facing=se;visual.gun_aim=se;visual.motion=se
	view.viya.apply(view,visual)
	var turn_ok:bool=frame(visual,"run_fire_se") and is_equal_approx(visual.gait_phase,held)
	visual.facing=view.input_direction(Vector2.DOWN);visual.gun_aim=visual.facing;visual.motion=visual.facing
	view.viya.apply(view,visual)
	verify.call(turn_ok and frame(visual,"run_s",index) and is_equal_approx(visual.gait_phase,held),"S to preserved SE firing and back keeps the common distance phase across unequal clips")
	visual.motion=-visual.facing
	view.viya.apply(view,visual)
	var reverse_ok:bool=frame(visual,"run_s",index) and is_equal_approx(visual.gait_phase,held)
	visual.distance+=5
	view.viya.apply(view,visual)
	verify.call(reverse_ok and is_equal_approx(visual.gait_phase,fposmod(held-5.0/155.0,1.0)),"S backward aiming reverses only newly traveled distance without reflecting the current pose")
	visual.pose="hurt"
	view.viya.apply(view,visual)
	verify.call(frame(visual,"hurt_s"),"Existing S hurt animation takes priority over moving gunfire")
	var texture:Texture2D=asset.get_frame_texture("run_s",8)
	var weight:float=asset.get_frame_duration("run_s",8)
	var opaque:=Image.create(200,248,false,Image.FORMAT_RGBA8)
	opaque.fill(Color.WHITE)
	asset.set_frame("run_s",8,ImageTexture.create_from_image(opaque),weight)
	visual=begin(view,(timing[8].start_ms+timing[8].duration_ms*.5)/660.0-origin)
	verify.call(frame(visual,"run_s",8) and is_same(visual.sample.texture,view.viya.decoded(rows[8].texture)),"A pathless white S import recovers the correct native PNG without changing the run phase")
	asset.set_frame("run_s",8,texture,weight)
	view.viya=original
	verify.call(Snapshot.capture(view.simulation)==saved and view.simulation.cues.snapshot()==cues and is_same(asset.get_frame_texture("run_s",8),texture),"All S presentation trials restore the asset and leave saves,RNG,rewards and cues unchanged")
