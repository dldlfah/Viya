extends RefCounted
const Presenter=preload("res://scripts/combat/viya_presentation.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Baseline=preload("res://assets/characters/pilot_32/game066_se_run/viya_game066_frames.tres")
const BASE_TIMING="res://assets/characters/pilot_32/game066_se_run/provenance/frame_timing.csv"
const FIRE="run_fire_se"
const GAME067_TIMING="res://assets/characters/pilot_32/game067_se_run_fire/provenance/frame_timing.csv"

static func read_timing(path:String) -> Array:
	var result:Array=[]
	var input:FileAccess=FileAccess.open(path,FileAccess.READ)
	if input==null:return result
	var header:PackedStringArray=input.get_csv_line()
	var frame:int=header.find("frame")
	var start:int=header.find("start_ms")
	var duration:int=header.find("duration_ms")
	var classification:int=header.find("classification")
	if frame<0 or start<0 or duration<0:return result
	while not input.eof_reached():
		var cells:PackedStringArray=input.get_csv_line()
		if cells.size()==1 and cells[0].is_empty():continue
		if cells.size()!=header.size():return []
		result.append({"index":int(cells[frame]),"start_ms":float(cells[start]),"duration_ms":float(cells[duration]),"classification":cells[classification] if classification>=0 else ""})
	input.close()
	return result

static func expected_index(timing:Array,total_ms:float,phase:float) -> int:
	var at_ms:float=fposmod(phase,1.0)*total_ms
	for row in timing:
		if at_ms<float(row.start_ms)+float(row.duration_ms):return int(row.index)
	return timing.size()-1

static func begin_motion(view,phase:float,firing:bool=true) -> Dictionary:
	var forward:Vector2=view.input_direction(Vector2(1,1).normalized())
	var visual:Dictionary={"pose":"attack" if firing else "run","direction":"se","facing":forward,"motion":forward,"clock":0.0,"moving":true,"distance":0.0,"shot_age":.01 if firing else 1000.0,"gun_aim":forward if firing else Vector2.ZERO,"sample":{}}
	view.viya._gait_run=""
	view.viya.apply(view,visual)
	visual.distance=fposmod(phase,1.0)*155.0
	view.viya.apply(view,visual)
	return visual

static func is_frame(visual:Dictionary,animation:String,index:int=-1) -> bool:
	return not visual.sample.is_empty() and visual.sample.animation==animation and (index<0 or visual.sample.index==index)

static func run(view,asset:SpriteFrames,verify:Callable) -> void:
	# Historical33-clip preservation remains exact; GAME068 tests its S replacement.
	var preserved_asset:SpriteFrames=load("res://assets/characters/pilot_32/game067_se_run_fire/viya_game067_frames.tres")
	var preserved:=true
	var old_count:=0
	for animation in Baseline.get_animation_names():
		preserved=preserved and preserved_asset.has_animation(animation) and preserved_asset.get_frame_count(animation)==Baseline.get_frame_count(animation) and preserved_asset.get_animation_speed(animation)==Baseline.get_animation_speed(animation) and preserved_asset.get_animation_loop(animation)==Baseline.get_animation_loop(animation)
		for index in range(Baseline.get_frame_count(animation)):
			old_count+=1
			preserved=preserved and preserved_asset.get_frame_texture(animation,index).resource_path==Baseline.get_frame_texture(animation,index).resource_path and preserved_asset.get_frame_duration(animation,index)==Baseline.get_frame_duration(animation,index)
	verify.call(preserved and old_count==298 and Baseline.get_animation_names().size()==33,"GAME067 preserves every33existing clip/298resolved frames, durations, loop and speed")
	var count:int=asset.get_frame_count(FIRE) if asset.has_animation(FIRE) else 0
	var timing:Array=read_timing(GAME067_TIMING)
	var rows:Variant=view.viya.config.directions.se.get("run_fire")
	verify.call(count>0 and asset.get_animation_names().size()==34 and timing.size()==count and rows is Array and rows.size()==count,"The active composite adds one SE moving-fire clip alongside preserved E backed by its actual delivered timing and frame metadata")
	if count<=0 or timing.size()!=count or not rows is Array or rows.size()!=count:return
	var total_ms:=0.0
	var timing_valid:=true
	var fps:float=asset.get_animation_speed(FIRE)
	for index in range(count):
		var row:Dictionary=timing[index]
		timing_valid=timing_valid and row.index==index and is_finite(row.duration_ms) and row.duration_ms>0 and absf(row.start_ms-total_ms)<.000001 and fps>0
		if fps>0:timing_valid=timing_valid and absf(asset.get_frame_duration(FIRE,index)/fps*1000.0-row.duration_ms)<.000001
		total_ms+=row.duration_ms
	verify.call(timing_valid and total_ms>0,"The delivered CSV retains every positive interval and its real SpriteFrames playback time")
	if not timing_valid or total_ms<=0:return
	var imported_pixels_match:=true
	for index in range(count):
		var raw:=Image.new()
		var path:String=str(rows[index].texture)
		imported_pixels_match=imported_pixels_match and raw.load_png_from_buffer(FileAccess.get_file_as_bytes(path))==OK
		imported_pixels_match=imported_pixels_match and asset.get_frame_texture(FIRE,index).get_image().get_data()==raw.get_data()
	verify.call(imported_pixels_match,"All20normal Godot imports preserve exact delivered RGBA pixels without another edge matte")
	# Isolate derived presentation state; every injected resource/config change is restored.
	var original_presenter=view.viya
	view.viya=Presenter.new()
	var state=view.simulation
	var saved_elapsed:float=state.elapsed
	var before:Dictionary=Snapshot.capture(state)
	var before_cues:Dictionary=state.cues.snapshot()
	var row:Dictionary=view.viya.config.directions.se
	var origin:float=float(row.get("run_fire_phase_origin",row.phase_origin))
	var forward:Vector2=view.input_direction(Vector2(1,1).normalized())
	var activated:bool=is_frame(begin_motion(view,0.0),FIRE)
	verify.call(activated,"Actual moving-fire sampling activates the complete delivered clip before transition trials")
	if not activated:
		view.viya=original_presenter
		return
	var middles:=true
	var boundaries:=true
	var muzzle_match:=true
	for index in range(count):
		var item:Dictionary=timing[index]
		var phase:float=(float(item.start_ms)+float(item.duration_ms)*.5)/total_ms-origin
		var visual:Dictionary=begin_motion(view,phase)
		middles=middles and is_frame(visual,FIRE,index)
		var expected_muzzle:Array=row.run_fire[index].muzzle
		muzzle_match=muzzle_match and visual.get("muzzle",Vector2.INF)==Vector2(expected_muzzle[0],expected_muzzle[1])
		if index==count-1:continue
		var end_ms:float=float(item.start_ms)+float(item.duration_ms)
		var just_before:Dictionary=begin_motion(view,(end_ms-.001)/total_ms-origin)
		var just_after:Dictionary=begin_motion(view,(end_ms+.001)/total_ms-origin)
		boundaries=boundaries and is_frame(just_before,FIRE,index) and is_frame(just_after,FIRE,index+1)
	verify.call(middles and muzzle_match,"Every delivered moving-fire midpoint selects its own full-body frame and matching measured muzzle")
	verify.call(boundaries,"Every internal moving-fire boundary switches one microsecond either side of its independently delivered CSV time")
	var visual:Dictionary=begin_motion(view,(total_ms-.001)/total_ms-origin)
	var last_visible:bool=is_frame(visual,FIRE,count-1)
	visual.distance+=.002/total_ms*155.0
	view.viya.apply(view,visual)
	verify.call(last_visible and is_frame(visual,FIRE,0),"The last distinct moving-fire frame wraps directly to the first through continuous traveled distance")
	var phases:Array=[(float(timing[0].start_ms)+float(timing[0].duration_ms)*.5)/660.0-origin,(float(timing[5].start_ms)+float(timing[5].duration_ms)*.5)/660.0-origin,1.0-.000001]
	var toggles:=true
	for phase in phases:
		visual=begin_motion(view,phase,false)
		var old_index:int=int(visual.sample.get("index",-1))
		var old_texture:Texture2D=visual.sample.get("texture")
		var held:float=visual.gait_phase
		visual.pose="attack";visual.gun_aim=forward;visual.shot_age=.01
		view.viya.apply(view,visual)
		toggles=toggles and is_frame(visual,FIRE,expected_index(timing,total_ms,held+origin)) and is_equal_approx(visual.gait_phase,held) and visual.pose=="attack" and visual.region==Rect2(0,0,200,248)
		visual.pose="run";visual.shot_age=.4
		view.viya.apply(view,visual)
		toggles=toggles and is_frame(visual,"run_se",old_index) and is_same(visual.sample.get("texture"),old_texture) and is_equal_approx(visual.gait_phase,held)
	verify.call(toggles,"Contact, recovery and seam toggles preserve gait phase, fixed canvas and the exact returning run pose without rewriting the attack observation")
	visual=begin_motion(view,.373)
	visual.distance+=13.0;visual.shot_age=.29
	view.viya.apply(view,visual)
	var held_phase:float=visual.gait_phase
	var held_index:int=int(visual.sample.get("index",-1))
	visual.shot_age=0.0
	view.viya.apply(view,visual)
	verify.call(is_frame(visual,FIRE,held_index) and is_equal_approx(visual.gait_phase,held_phase),"A repeated observed shot at unchanged travel does not restart moving-fire gait at frame0")
	visual=begin_motion(view,.373,false)
	visual.pose="attack"
	view.viya.apply(view,visual)
	var no_gun:bool=is_frame(visual,"run_se")
	visual.gun_aim=forward;visual.shot_age=.4
	view.viya.apply(view,visual)
	verify.call(no_gun and is_frame(visual,"run_se"),"An attack observation without a committed gun shot, or an expired gun window, keeps ordinary SE running")
	visual=begin_motion(view,.373)
	held_phase=visual.gait_phase;held_index=int(visual.sample.get("index",-1))
	var east:Vector2=view.input_direction(Vector2.RIGHT)
	visual.gun_aim=east;visual.facing=east;visual.motion=east
	view.viya.apply(view,visual)
	var turn_ok:bool=is_frame(visual,"run_fire_e") and is_equal_approx(visual.gait_phase,held_phase)
	visual.gun_aim=forward;visual.facing=forward;visual.motion=forward
	view.viya.apply(view,visual)
	verify.call(turn_ok and is_frame(visual,FIRE,held_index) and is_equal_approx(visual.gait_phase,held_phase),"SE moving-fire to preserved E moving-fire and back preserves the shared phase across different frame counts")
	visual.motion=-forward
	view.viya.apply(view,visual)
	var reverse_ok:bool=is_frame(visual,FIRE,held_index) and is_equal_approx(visual.gait_phase,held_phase)
	visual.distance+=5.0
	view.viya.apply(view,visual)
	var reverse_phase:float=fposmod(held_phase-5.0/155.0,1.0)
	verify.call(reverse_ok and is_frame(visual,FIRE,expected_index(timing,total_ms,reverse_phase+origin)) and is_equal_approx(visual.gait_phase,reverse_phase),"Backward moving-fire reverses only new travel and retains the authored weighted timing")
	visual=begin_motion(view,.373)
	visual.pose="hurt"
	view.viya.apply(view,visual)
	var hurt_wins:bool=is_frame(visual,"hurt_se")
	visual.pose="run"
	view.viya.apply(view,visual)
	var cancelled:bool=is_frame(visual,"run_se")
	state.elapsed=saved_elapsed+.02;visual.shot_age=0.0
	view.viya.apply(view,visual)
	var fresh_shot:bool=is_frame(visual,FIRE)
	state.elapsed=saved_elapsed
	verify.call(hurt_wins and cancelled and fresh_shot,"Hurt cancels the old firing observation until a genuinely newer shot time arrives")
	var textures:Array=[]
	var durations:Array=[]
	for index in range(count):
		textures.append(asset.get_frame_texture(FIRE,index));durations.append(asset.get_frame_duration(FIRE,index))
	var loop:bool=asset.get_animation_loop(FIRE)
	asset.remove_animation(FIRE)
	visual=begin_motion(view,.373)
	var missing_falls_back:bool=is_frame(visual,"run_se") and is_equal_approx(visual.gait_phase,.373)
	asset.add_animation(FIRE);asset.set_animation_speed(FIRE,fps);asset.set_animation_loop(FIRE,loop)
	for index in range(count):asset.add_frame(FIRE,textures[index],durations[index])
	verify.call(missing_falls_back,"A missing optional moving-fire clip explicitly falls back to running at the same phase, never idle")
	var recover_index:int=floori(float(count)*.5)
	var original_rows:Array=row.run_fire
	var invalid_rows:Array=original_rows.duplicate(true)
	invalid_rows[recover_index].muzzle=[]
	row.run_fire=invalid_rows
	visual=begin_motion(view,.373)
	var invalid_falls_back:bool=is_frame(visual,"run_se") and is_equal_approx(visual.gait_phase,.373)
	row.run_fire=original_rows
	verify.call(invalid_falls_back,"One incomplete delivered muzzle row disables the optional clip and preserves ordinary running")
	for invalid in ["missing_metadata","missing_origin","invalid_origin","out_of_range_origin","missing_duration","invalid_duration","mismatched_duration","invalid_region","invalid_path"]:
		var saved:Dictionary=row.duplicate(true)
		row.run_fire=original_rows.duplicate(true)
		if invalid=="missing_metadata":row.erase("run_fire")
		elif invalid=="missing_origin":row.erase("run_fire_phase_origin")
		elif invalid=="invalid_origin":row.run_fire_phase_origin=NAN
		elif invalid=="out_of_range_origin":row.run_fire_phase_origin=2.0
		elif invalid=="missing_duration":row.run_fire[0].erase("duration_ms")
		elif invalid=="invalid_duration":row.run_fire[0].duration_ms=0.0
		elif invalid=="mismatched_duration":row.run_fire[0].duration_ms=1.0
		else:
			row.run_fire=original_rows.duplicate(true)
			if invalid=="invalid_region":row.run_fire[0].region=[0,0,199,248]
			else:row.run_fire[0].texture="res://"+"../missing.png"
		visual=begin_motion(view,.373)
		verify.call(is_frame(visual,"run_se") and is_equal_approx(visual.gait_phase,.373),"Invalid SE optional metadata keeps same-phase SE running:"+invalid)
		row.clear();row.merge(saved,true)
	var opaque:=Image.create(200,248,false,Image.FORMAT_RGBA8)
	opaque.fill(Color.WHITE)
	asset.set_frame(FIRE,recover_index,ImageTexture.create_from_image(opaque),durations[recover_index])
	var recover_phase:float=(float(timing[recover_index].start_ms)+float(timing[recover_index].duration_ms)*.5)/total_ms-origin
	visual=begin_motion(view,recover_phase)
	var expected_path:String=str(original_rows[recover_index].texture)
	var raw:=Image.new()
	var loaded:bool=raw.load_png_from_buffer(FileAccess.get_file_as_bytes(expected_path))==OK
	var recovered:bool=is_frame(visual,FIRE,recover_index) and loaded and is_same(visual.sample.get("texture"),view.viya.decoded(expected_path)) and visual.sample.texture.get_image().get_data()==raw.get_data()
	asset.set_frame(FIRE,recover_index,textures[recover_index],durations[recover_index])
	verify.call(recovered,"A pathless opaque moving-fire import recovers its own delivered PNG exactly and retains its original frame duration")
	var restored:bool=asset.get_frame_count(FIRE)==count and asset.get_animation_speed(FIRE)==fps and asset.get_animation_loop(FIRE)==loop
	for index in range(count):restored=restored and is_same(asset.get_frame_texture(FIRE,index),textures[index]) and asset.get_frame_duration(FIRE,index)==durations[index]
	view.viya=original_presenter
	verify.call(restored and Snapshot.capture(state)==before and state.cues.snapshot()==before_cues,"All injection trials restore the real clip and leave gameplay, saves, RNG and cues unchanged")
