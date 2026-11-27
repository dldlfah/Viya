extends RefCounted
const Campaign=preload("res://tests/test_campaign.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Pilot=preload("res://tests/test_character_pilot.gd")
const IDLE="res://assets/characters/pilot_32/textures/viya_idle_e.png"

static func run(host,verify:Callable) -> void:
	preload("res://tests/test_viya_edges.gd").run(verify)
	var folder:="user://viya-presentation-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	var ui=Campaign.make_ui(host,folder)
	Campaign.depart(ui)
	var view=ui.view
	var state=ui.simulation
	state.player=Vector2(2500,1700);state.spawn_clock=999;state.shot_clock=999;state._scatter_clock=999;state._swarm_clock=999
	var asset:SpriteFrames=view.art.resource("viya_battle")
	var all_alpha:=true
	var active_count:=0
	for animation in asset.get_animation_names():
		for index in range(asset.get_frame_count(animation)):
			active_count+=1
			all_alpha=all_alpha and view.viya.transparent(asset.get_frame_texture(animation,index))
	verify.call(all_alpha and view.viya._alpha.size()>=active_count and view.viya._alpha.size()<=512,"Every active directional frame actually decodes with transparent corners in Godot within the512entry bound: "+str(active_count))
	var opaque:=Image.create(200,248,false,Image.FORMAT_RGBA8)
	opaque.fill(Color.WHITE)
	verify.call(not view.viya.transparent(ImageTexture.create_from_image(opaque)),"Lost-alpha white texture is rejected before it can be drawn as a rectangle")
	for direction in ["e","w"]:
		var path:String=IDLE.get_base_dir().path_join("viya_idle_"+direction+".png")
		var recovered:Texture2D=view.viya.decoded(path)
		var pixels:=Image.new()
		pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		verify.call(recovered!=null and view.viya.transparent(recovered) and recovered.get_image().get_data()==pixels.get_data(),"Raw PNG recovery of left/right bypasses a stale opaque import with the exact original alpha/pixels:"+direction)
	var original:Texture2D=asset.get_frame_texture("idle_w",0)
	view.viya._alpha[original.get_instance_id()]=false # Inject the rejected-import path.
	var recovered_pose:Dictionary={"pose":"idle","moving":false,"direction":"w","facing":Vector2.LEFT,"clock":0.0,"sample":{}}
	view.viya.apply(view,recovered_pose)
	verify.call(not recovered_pose.sample.is_empty() and is_same(recovered_pose.sample.texture,view.viya.decoded(original.resource_path)),"Actual hero sampling replaces a rejected left import with its verified transparent display frame instead of a white box or another character")
	view.viya._alpha[original.get_instance_id()]=true
	var east:Texture2D=asset.get_frame_texture("idle_e",0)
	asset.set_frame("idle_e",0,ImageTexture.create_from_image(opaque))
	var failed_import:Dictionary={"pose":"idle","moving":false,"direction":"e","facing":Vector2.RIGHT,"clock":0.0,"sample":{}}
	view.viya.apply(view,failed_import)
	verify.call(not failed_import.sample.is_empty() and view.viya.transparent(failed_import.sample.texture) and is_same(failed_import.sample.texture,view.viya.decoded("res://assets/characters/pilot_32/render_cache/viya_idle_e.png")),"A wholly opaque cached frame with a missing resource path recovers the correct east display frame rather than drawing a white square")
	asset.set_frame("idle_e",0,east)
	verify_e_cycle(view,asset,verify)
	preload("res://tests/test_viya_game065.gd").run(view,asset,verify)
	preload("res://tests/test_viya_game066.gd").run(view,asset,verify)
	for index in range(8):
		var direction:String=view.actors.DIRECTIONS[index]
		var facing:Vector2=view.input_direction(Vector2.from_angle(index*PI/4))
		view.viya._gait_run="" # Independent directional trial, not a target turn.
		var visual:Dictionary={"pose":"run","direction":direction,"facing":facing,"clock":.06,"moving":true,"motion":facing,"distance":0.0,"sample":{}}
		var seen:Dictionary={}
		var expected_count:int=asset.get_frame_count("run_"+direction)
		var steps:int=maxi(44,expected_count*4)
		for step in range(steps):
			visual.distance=step*155.0/float(steps)
			view.viya.apply(view,visual)
			seen[visual.sample.index]=true
		var texture:Texture2D=visual.sample.texture
		var region:Rect2=visual.region
		var registered:Rect2=view.viya.body_rect(view.actor_art,visual,Vector2(200,180))
		var held_phase:float=visual.gait_phase
		visual.pose="attack";visual.shot_age=0.0;visual.gun_aim=facing;view.viya.apply(view,visual)
		var firing_pose_ok:bool=(visual.sample.animation=="run_fire_e" and not is_same(visual.sample.texture,texture)) if direction=="e" else is_same(visual.sample.texture,texture)
		verify.call(seen.size()==expected_count and expected_count==(47 if direction=="e" else (18 if direction=="se" else 11)) and registered.end.y==180 and is_equal_approx(registered.size.x/region.size.x,registered.size.y/region.size.y) and firing_pose_ok and is_equal_approx(visual.gait_phase,held_phase) and visual.region==Rect2(0,0,200,248) and visual.recoil==0,"Every whole-body frame retains one canvas/root and gait phase through moving fire:"+direction)
		visual.moving=false
		var attack_frames:Dictionary={}
		for step in range(8):
			state.elapsed+=.020001;visual.shot_age=.01
			view.viya.apply(view,visual);attack_frames[visual.sample.index]=true
		state.elapsed+=.3;visual.shot_age=0.0;view.viya.apply(view,visual)
		verify.call(visual.sample.animation=="attack_"+direction and visual.sample.index==7 and attack_frames.size()==8,"Stationary burst plays all8native whole-body poses then holds the aimed end frame across repeated shots:"+direction)
		var world_direction:Vector2=facing
		state.facing=world_direction;view.actors.reset(state.run_id)
		var bullet:Dictionary={"p":state.player,"direction":world_direction,"life":.75,"speed":920.0,"source":"rifle"}
		view.viya._shot_offsets.clear()
		var before:Dictionary=Snapshot.capture(state)
		var shown:Dictionary=view.viya.projectile(view,bullet)
		var current:Dictionary=view.actor_visual()
		var muzzle:Vector2=view.viya.muzzle(view.actor_art,current,view.world_to_screen(state.player))
		verify.call(shown.p.distance_to(muzzle)<.001 and shown.p.distance_to(view.world_to_screen(state.player))>20 and Snapshot.capture(state)==before,"Fresh visual bullet starts at the registered gun muzzle without changing authoritative projectile/player/RNG:"+direction)

	var before:Dictionary=Snapshot.capture(state)
	var rune:Dictionary={"p":state.player,"direction":state.facing,"life":.75,"speed":920.0,"source":"viya_runebullet_v1"}
	verify.call(view.viya.projectile(view,rune).p.distance_to(view.world_to_screen(state.player))>20,"Viya's exclusive rune bullet also emits at gun height rather than under her feet")
	var held:Dictionary={"pose":"run","moving":true,"direction":"e","facing":view.input_direction(Vector2.RIGHT),"gun_aim":view.input_direction(Vector2.LEFT),"motion":view.input_direction(Vector2.RIGHT),"shot_age":.25,"clock":.25,"distance":40.0,"sample":{}}
	view.viya._gait_run=""
	view.viya.apply(view,held)
	var held_index:int=held.sample.index
	held.pose="attack";held.shot_age=0.0;view.viya.apply(view,held)
	verify.call(held.direction=="w" and held.sample.index==held_index,"Automatic fire holds aim through attack/run transitions while backward movement keeps its distance-driven leg phase")
	var phase:float=held.gait_phase
	held.motion=-held.facing;view.viya.apply(view,held)
	verify.call(is_equal_approx(held.gait_phase,phase),"Reversal at unchanged travel preserves the current phase rather than reflecting p to1-p")
	held.distance+=5;view.viya.apply(view,held)
	verify.call(is_equal_approx(held.gait_phase,fposmod(phase-5.0/155,1.0)),"Backward motion reverses only subsequent distance increments")
	view.viya._direction="e"
	var quiet:=true
	for angle in [21.0,24.0,22.0,25.0,20.0]:
		quiet=quiet and view.viya.direction_for(view,view.input_direction(Vector2.from_angle(deg_to_rad(angle))),"e")=="e"
	verify.call(quiet and view.viya.direction_for(view,view.input_direction(Vector2.from_angle(deg_to_rad(29))),"e")=="se","Five-degree angular hysteresis rejects boundary chatter while a deliberate turn responds immediately")
	view.actors.reset(state.run_id)
	ui.movement.axis=Vector2.RIGHT
	for i in range(6):ui._physics_process(.05)
	var distance:float=view.actors.pose(state).distance
	verify.call(is_equal_approx(distance,235.0*.3),"Hero gait follows actual traveled world distance, not the fire animation clock")
	ui.movement.axis=Vector2.ZERO
	for i in range(6):ui._physics_process(.05)
	verify.call(view.actor_visual().sample.animation.begins_with("idle_") and view.actors.pose(state).distance==distance,"Released input immediately stops the legs and freezes gait distance")
	ui.pause_game();before=Snapshot.capture(state);var pose:Dictionary=view.actor_visual()
	for i in range(4):ui._physics_process(.05)
	verify.call(Snapshot.capture(state)==before and view.actor_visual().sample.index==pose.sample.index and view.actors.pose(state).distance==distance,"Pause freezes derived gait and authoritative state together")
	ui.queue_free();await host.get_tree().process_frame
	for file in DirAccess.get_files_at(folder):DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)

static func expected_e_index(timing:Array,phase:float) -> int:
	var at_ms:float=fposmod(phase,1.0)*660.0
	for row in timing:
		if at_ms<float(row.start_ms)+float(row.duration_ms):return int(row.index)
	return timing.size()-1

static func verify_e_cycle(view,asset:SpriteFrames,verify:Callable) -> void:
	var timing:Array=Pilot.east_timing()
	verify.call(timing.size()==47,"E integration reads the47authored production timing rows")
	if timing.size()!=47:return
	var forward:Vector2=view.input_direction(Vector2.RIGHT)
	var visual:Dictionary={"pose":"run","direction":"e","facing":forward,"motion":forward,"clock":0.0,"moving":true,"distance":0.0,"sample":{}}
	view.viya._gait_run=""
	view.viya.apply(view,visual)
	var middles:=true
	var boundaries:=true
	var seam:=false
	var muzzle_rows:=true
	# Independent CSV times catch a uniform47-bin sampler even when it visits all frames.
	for index in range(timing.size()):
		var row:Dictionary=timing[index]
		visual.distance=(float(row.start_ms)+float(row.duration_ms)*.5)/660.0*155.0
		view.viya.apply(view,visual)
		middles=middles and visual.sample.animation=="run_e" and visual.sample.index==index
		var expected_muzzle:Array=view.viya.config.directions.e.run[index].muzzle
		muzzle_rows=muzzle_rows and visual.muzzle==Vector2(expected_muzzle[0],expected_muzzle[1])
		var boundary_ms:float=float(row.start_ms)+float(row.duration_ms)
		visual.distance=(boundary_ms-.001)/660.0*155.0
		view.viya.apply(view,visual)
		var before_index:int=visual.sample.index
		visual.distance=(boundary_ms+.001)/660.0*155.0
		view.viya.apply(view,visual)
		var after_index:int=visual.sample.index
		if index==46:seam=before_index==46 and after_index==0 and visual.gait_phase>0 and visual.gait_phase<.00001
		else:boundaries=boundaries and before_index==index and after_index==index+1
	verify.call(middles and muzzle_rows,"Distance-driven E sampling honors every authored unequal midpoint and its matching gun muzzle")
	verify.call(boundaries,"Every internal E boundary switches at the CSV time, checked one microsecond before and after")
	verify.call(seam,"The last distinct E frame46wraps directly to frame0at one155world-unit cycle without a repeated endpoint")
	view.viya._gait_run=""
	visual.distance=0.0
	view.viya.apply(view,visual)
	visual.distance=.373*155.0
	view.viya.apply(view,visual)
	var held_phase:float=visual.gait_phase
	var held_index:int=visual.sample.index
	var southeast:Vector2=view.input_direction(Vector2(1,1).normalized())
	visual.direction="se";visual.facing=southeast;visual.motion=southeast
	view.viya.apply(view,visual)
	var turn_keeps_phase:bool=visual.sample.animation=="run_se" and is_equal_approx(visual.gait_phase,held_phase)
	visual.direction="e";visual.facing=forward;visual.motion=forward
	view.viya.apply(view,visual)
	verify.call(turn_keeps_phase and visual.sample.animation=="run_e" and visual.sample.index==held_index and is_equal_approx(visual.gait_phase,held_phase),"Same-distance E47toSE11and back preserves normalized gait phase and the returning E pose")
	visual.motion=-forward
	view.viya.apply(view,visual)
	var reversal_keeps_phase:bool=visual.sample.index==held_index and is_equal_approx(visual.gait_phase,held_phase)
	visual.distance+=5.0
	view.viya.apply(view,visual)
	var expected_phase:float=fposmod(held_phase-5.0/155.0,1.0)
	verify.call(reversal_keeps_phase and is_equal_approx(visual.gait_phase,expected_phase) and visual.sample.index==expected_e_index(timing,expected_phase),"E reversal keeps the held phase then traverses the authored unequal durations backward only for new travel")
	# The imported texture intentionally loses both alpha and its path; fallback
	# must recover this exact derivative without borrowing an old E11 frame.
	var recover_index:=23
	var original:Texture2D=asset.get_frame_texture("run_e",recover_index)
	var duration:float=asset.get_frame_duration("run_e",recover_index)
	var opaque:=Image.create(200,248,false,Image.FORMAT_RGBA8)
	opaque.fill(Color.WHITE)
	asset.set_frame("run_e",recover_index,ImageTexture.create_from_image(opaque),duration)
	view.viya._gait_run=""
	visual.motion=forward;visual.distance=0.0
	view.viya.apply(view,visual)
	visual.distance=(float(timing[recover_index].start_ms)+float(timing[recover_index].duration_ms)*.5)/660.0*155.0
	view.viya.apply(view,visual)
	var expected_path:String=Pilot.EAST_FIRST.get_base_dir().path_join(timing[recover_index].filename)
	var pixels:=Image.new()
	var loaded:bool=pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(expected_path))==OK
	verify.call(not visual.sample.is_empty() and visual.sample.index==recover_index and is_same(visual.sample.texture,view.viya.decoded(expected_path)) and loaded and visual.sample.texture.get_image().get_data()==pixels.get_data(),"Lost-alpha E import recovers the exact registered three-digit derivative PNG and retains its authored duration")
	asset.set_frame("run_e",recover_index,original,duration)
	view.viya._gait_run=""
