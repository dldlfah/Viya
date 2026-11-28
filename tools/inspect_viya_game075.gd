extends SceneTree
## Main-scene SW15 aimed-run integration review. Fixed updates and actual draws, never realtime FPS.
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const FOLDER="res://"+".local_validation/GAME075_INTEGRATION/game"
var output_folder:String=FOLDER
var ui
var checks:int=0
var draws:int=0
var failures:Array=[]
var records:Array=[]
var logic_only:bool=false
var timeline:Array=[]
var rendered_frames:Dictionary={}
var last_render_candidate:Dictionary={}
var rendered_seams:Dictionary={}
func _initialize():call_deferred("run")
func expect(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label)
func key(code:Key,pressed:bool):
	var event:=InputEventKey.new()
	event.physical_keycode=code;event.keycode=code;event.pressed=pressed
	Input.parse_input_event(event)
func draw_frame(path:String=""):
	if logic_only:await process_frame;return
	# Capture every distinct regular/firing frame plus one last-to-first seam.
	# Simulation/input checks still run at every fixed tick, including skipped draws.
	if path.begins_with("frames/"):
		var sample:Dictionary=ui.view.actor_visual().sample
		var animation:String=sample.animation;var index:int=sample.index
		var key:String=animation+":"+str(index)
		var seam:bool=last_render_candidate.has(animation) and index<int(last_render_candidate[animation]) and not rendered_seams.has(animation)
		last_render_candidate[animation]=index
		if rendered_frames.has(key) and not seam:return
		rendered_frames[key]=true
		if seam:rendered_seams[animation]=true
	elif path.is_empty():return
	ui._update_hud();ui.view.queue_redraw()
	var saved:Dictionary=Snapshot.capture(ui.simulation)
	var cues:Dictionary=ui.simulation.cues.snapshot()
	await process_frame;await RenderingServer.frame_post_draw
	expect(saved==Snapshot.capture(ui.simulation) and cues==ui.simulation.cues.snapshot(),"Read-only main-scene render:"+path)
	draws+=1
	var capture:Image=root.get_texture().get_image()
	expect(capture.save_png(output_folder.path_join("timeline/%03d.png"%(draws-1)))==OK,"Timeline capture")
	timeline.append({"draw":draws-1,"label":path,"time":ui.simulation.elapsed,"animation":ui.view.actor_visual().sample.animation})
	if not path.is_empty():expect(capture.save_png(output_folder.path_join(path))==OK,"Capture:"+path)
func record(kind:String,index:int,shown:Dictionary):
	records.append({"kind":kind,"step":index,"time":ui.simulation.elapsed,"position":str(ui.simulation.player),"phase":shown.gait_phase,"frame":shown.sample.index,"animation":shown.sample.animation,"texture":shown.sample.texture.resource_path,"muzzle":str(ui.view.viya.muzzle(ui.view.actor_art,shown,ui.view.world_to_screen(ui.simulation.player))),"shots":ui.simulation.shots})
func moving_step(animation:String,sign:float=1.0) -> Dictionary:
	var previous:Dictionary=ui.view.actor_visual()
	var position:Vector2=ui.simulation.player
	ui._physics_process(1.0/60)
	var shown:Dictionary=ui.view.actor_visual()
	if not animation.is_empty():expect(shown.sample.animation==animation,"Expected actual moving clip:"+animation)
	if shown.sample.animation=="run_fire_sw":
		var expected:Array=ui.view.viya.config.directions.sw.run_fire[int(shown.sample.index)].muzzle
		expect(shown.muzzle==Vector2(expected[0],expected[1]),"Dedicated SW frame uses its own measured muzzle")
	var traveled:float=ui.simulation.player.distance_to(position)
	expect(absf(traveled-235.0/60)<.002,"Unobstructed fixture retains configured movement235")
	expect(is_equal_approx(fposmod(shown.gait_phase-float(previous.gait_phase),1.0),fposmod(sign*traveled/155,1.0)),"Actual distance and signed gait increment remain continuous")
	return shown
func run():
	logic_only=OS.get_cmdline_user_args().has("--logic-only")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output_folder=argument.trim_prefix("--output=")
	if not output_folder.begins_with("res://.local_validation/") or ".." in output_folder:
		printerr("Use an isolated res://.local_validation/ output");quit(2);return
	if DisplayServer.get_name()=="headless" and not logic_only:printerr("Actual display required");quit(2);return
	DirAccess.make_dir_recursive_absolute(output_folder.path_join("frames"))
	DirAccess.make_dir_recursive_absolute(output_folder.path_join("timeline"))
	root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	ui=load("res://scenes/main.tscn").instantiate()
	ui.run_store.path=output_folder.path_join("battle.save");ui.gold_progress.path=output_folder.path_join("gold.cfg");ui.settings_path=output_folder.path_join("settings.cfg")
	for path in [ui.run_store.path,ui.gold_progress.path,ui.settings_path]:DirAccess.remove_absolute(path)
	root.add_child(ui);ui.set_physics_process(false);await process_frame;Campaign.depart(ui)
	ui.safe_area_override=Rect2(0,6,1280,702);ui._apply_layout()
	var state=ui.simulation
	state.player=Vector2(2500,1200);state.enemies.clear();state.bullets.clear();state.map_space.solids.clear()
	state.spawn_clock=999;state.shot_clock=999;state._scatter_clock=999;state._swarm_clock=999
	var south:Vector2=ui.view.input_direction(Vector2(-1,1).normalized())
	state.facing=south;ui.view.camera.reset();ui.view.actors.reset();ui.view.viya._gait_run=""
	var asset:SpriteFrames=ui.view.art.resource("viya_battle")
	expect(asset.resource_path=="res://assets/characters/pilot_32/game075_sw_run_fire_candidate03/viya_game075_frames.tres" and asset.get_frame_count("run_sw")==17 and asset.get_frame_count("run_fire_sw")==15 and asset.get_frame_count("run_fire_s")==18,"Production slot resolves SW17, dedicated SW-fire15 and preserved S-fire18")
	var shown:Dictionary=ui.view.actor_visual()
	expect(shown.sample["size"]==Vector2(69,85.56) and shown.sample.pivot==Vector2(.5,1),"Shared display and root remain fixed")
	await draw_frame("idle_sw.png")
	key(KEY_S,true);key(KEY_A,true);await process_frame
	var seen:Dictionary={};var wraps:int=0;var previous_phase:float=0.0
	for index in range(160):
		shown=moving_step("run_sw")
		seen[shown.sample.index]=true
		if shown.gait_phase<previous_phase:wraps+=1
		previous_phase=shown.gait_phase;record("run_sw",index,shown)
		await draw_frame("frames/sw_%03d.png"%index)
	expect(seen.size()==17 and wraps>=4,"Main-scene travel samples all17frames through at least4seams")
	# S/SW direction changes retain traveled-distance phase across unequal counts.
	for turn in range(4):
		key(KEY_A,false);await process_frame
		for index in range(8):
			shown=moving_step("run_s");record("turn_se",turn*8+index,shown)
			await draw_frame("turn_s.png" if turn==0 and index==7 else "")
		key(KEY_A,true);await process_frame
		for index in range(8):
			shown=moving_step("run_sw");record("turn_s",turn*8+index,shown)
			await draw_frame("turn_sw.png" if turn==0 and index==7 else "")
	key(KEY_A,false);key(KEY_S,false);await process_frame
	ui._physics_process(1.0/60);shown=ui.view.actor_visual()
	expect(shown.sample.animation=="idle_sw","Released south input returns to SW idle")
	var held:float=shown.gait_phase
	for index in range(12):ui._physics_process(1.0/60)
	expect(is_equal_approx(ui.view.actor_visual().gait_phase,held),"Released movement does not animate feet")
	await draw_frame("released.png")
	# Observe committed SW shots through the dedicated full-body18frame clip.
	# Reset the independent route fixture only; no gameplay settings/assets change.
	state.player=Vector2(2500,1200);ui.view.camera.reset()
	state.enemies.clear();state.bullets.clear();state.add_enemy(state.player+south*250)
	state.enemies[-1].speed=0;state.enemies[-1].hp=100000;state.enemies[-1].max_hp=100000
	state.shot_clock=0
	key(KEY_S,true);key(KEY_A,true);await process_frame
	var shots:int=state.shots;var firing_seen:Dictionary={}
	var fire_wraps:int=0
	var previous_fire_index:int=-1
	for index in range(80):
		state.enemies[-1].p=state.player+south*250
		shown=moving_step("run_fire_sw");firing_seen[shown.sample.index]=true
		if previous_fire_index>=0 and shown.sample.index<previous_fire_index:fire_wraps+=1
		previous_fire_index=shown.sample.index
		expect(state.elapsed-float(ui.view.actors.entries[0].get("gun_since",-1000))<.4,"Actual committed shots keep the existing aim window active")
		record("current_sw_fire",index,shown)
		await draw_frame("frames/fire_%03d.png"%index)
	expect(state.shots>shots and firing_seen.size()==15,"Real SW gunfire selects all15dedicated SW firing frames")
	expect(fire_wraps>=2,"Real moving-fire traverses at least two last-to-first seams")
	# Optional-data failures must keep the same traveled-distance phase on screen.
	var metadata:Dictionary=ui.view.viya.config.directions.sw
	var original_rows:Array=metadata.run_fire
	var held_phase:float=shown.gait_phase
	var clip_textures:Array=[];var clip_durations:Array=[]
	var clip_speed:float=asset.get_animation_speed("run_fire_sw")
	for i in range(asset.get_frame_count("run_fire_sw")):
		clip_textures.append(asset.get_frame_texture("run_fire_sw",i));clip_durations.append(asset.get_frame_duration("run_fire_sw",i))
	asset.remove_animation("run_fire_sw");shown=ui.view.actor_visual()
	expect(shown.sample.animation=="run_sw" and is_equal_approx(shown.gait_phase,held_phase),"Missing optional clip renders same-phase SW17 fallback")
	await draw_frame("fallback_clip_missing.png")
	asset.add_animation("run_fire_sw");asset.set_animation_speed("run_fire_sw",clip_speed);asset.set_animation_loop("run_fire_sw",true)
	for i in range(clip_textures.size()):asset.add_frame("run_fire_sw",clip_textures[i],clip_durations[i])
	metadata.erase("run_fire")
	shown=ui.view.actor_visual()
	expect(shown.sample.animation=="run_sw" and is_equal_approx(shown.gait_phase,held_phase),"Missing SW metadata renders same-phase SW17 fallback")
	await draw_frame("fallback_missing.png")
	metadata.run_fire=original_rows.duplicate(true)
	metadata.run_fire[0].duration_ms=0.0
	shown=ui.view.actor_visual()
	expect(shown.sample.animation=="run_sw" and is_equal_approx(shown.gait_phase,held_phase),"Invalid SW duration renders same-phase SW17 fallback")
	await draw_frame("fallback_invalid.png")
	metadata.run_fire=original_rows
	shown=ui.view.actor_visual()
	expect(shown.sample.animation=="run_fire_sw" and is_equal_approx(shown.gait_phase,held_phase),"Restored SW metadata resumes dedicated fire at unchanged distance phase")
	await draw_frame("fallback_restored.png")
	state.shot_clock=999
	for index in range(30):
		shown=moving_step("")
		record("fire_off",index,shown)
		if index>=25:expect(shown.sample.animation=="run_sw","Fire off returns to same-phase SW run")
		await draw_frame("fire_off.png" if index==29 else "")
	state.shot_clock=0
	var southeast:Vector2=ui.view.input_direction(Vector2.DOWN)
	for turn in range(2):
		key(KEY_A,false);await process_frame
		for index in range(8):
			state.enemies[-1].p=state.player+southeast*250;state.shot_clock=0
			shown=moving_step("run_fire_s")
			record("fire_turn_s",turn*8+index,shown)
			await draw_frame("fire_s.png" if turn==0 and index==7 else "")
		key(KEY_A,true);await process_frame
		for index in range(8):
			state.enemies[-1].p=state.player+south*250;state.shot_clock=0
			shown=moving_step("run_fire_sw")
			record("fire_turn_s",turn*8+index,shown)
			await draw_frame("fire_sw.png" if turn==0 and index==7 else "")
	key(KEY_A,false);key(KEY_S,false);key(KEY_W,true);key(KEY_D,true);await process_frame
	for index in range(48):
		state.enemies[-1].p=state.player+south*250
		shown=moving_step("run_fire_sw",-1)
		record("backward_aim_s",index,shown)
		await draw_frame("backward.png" if index==24 else "")
	key(KEY_D,false);key(KEY_W,false);await process_frame
	for index in range(24):
		ui._physics_process(1.0/60);shown=ui.view.actor_visual()
		expect(shown.sample.animation=="attack_sw","Stationary SW fire uses the preserved whole-body attack")
		await draw_frame("stationary.png" if index==23 else "")
	ui.pause_game()
	var paused:Dictionary=Snapshot.capture(state);var frozen:Dictionary=ui.view.actor_visual()
	for index in range(12):ui._physics_process(1.0/60)
	expect(Snapshot.capture(state)==paused and ui.view.actor_visual().sample.index==frozen.sample.index,"Pause freezes both battle and pose")
	await draw_frame("paused.png")
	ui.resume_game()
	key(KEY_S,true);key(KEY_A,true);await process_frame
	state.player=Vector2(2500,1200);ui.view.camera.reset()
	state.enemies.clear();state.bullets.clear();state.hurt_clock=10
	state.add_enemy(state.player+south*20)
	state.enemies[-1].speed=0;state.enemies[-1].hp=100000;state.enemies[-1].max_hp=100000
	state.shot_clock=0
	var consumed_shots:int=state.shots
	ui._physics_process(.05);shown=ui.view.actor_visual()
	expect(state.shots>consumed_shots and state.bullets.is_empty() and shown.sample.animation=="run_fire_sw","Immediate target consumption retains actual SW shot posture")
	await draw_frame("immediate_hit.png")
	var saved_solids:Array[Rect2]=state.map_space.solids.duplicate()
	state.map_space.solids.append(Rect2(state.player+south*42-Vector2(2,2),Vector2(4,4)))
	state.enemies[-1].p=state.player+south*250;state.bullets.clear();state.shot_clock=0;consumed_shots=state.shots
	ui._physics_process(.05);shown=ui.view.actor_visual()
	expect(state.shots>consumed_shots and state.bullets.is_empty() and shown.sample.animation=="run_fire_sw","Immediate wall consumption retains actual SW shot posture")
	await draw_frame("wall_consumed.png")
	state.map_space.solids.assign(saved_solids)
	state.hurt_clock=0;state.enemies[-1].p=state.player+south*16;state.shot_clock=0
	var hp_before:int=state.hp
	ui._physics_process(1.0/60);shown=ui.view.actor_visual()
	expect(state.hp<hp_before and shown.sample.animation=="hurt_sw","Actual contact damage takes priority over SW moving-fire")
	await draw_frame("hurt.png")
	key(KEY_A,false);key(KEY_S,false);await process_frame
	var report:Dictionary={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"draws":draws,"failures":failures,"run_frames":seen.keys(),"run_wraps":wraps,"firing_frames":firing_seen.keys(),"real_shots":state.shots-shots,"logic_only":logic_only,"display":DisplayServer.get_name(),"records":records,"engine":Engine.get_version_info(),"scope":("Headless logic; no actual draws. " if logic_only else "Actual display draws. ")+"Production main.tscn,isolated open-stage route,native key events,fixed updates. SW17 cycles,S/SW turns,release,dedicated SW moving fire,on/off,S/SW firing turns,immediate target/wall consumption,actual hurt priority,backward aim,stationary attack,pause. Not realtime FPS,hardware QA,physical foot-contact proof or final producer approval."}
	report.firing_wraps=fire_wraps
	report.timeline=timeline
	report.capture_mode="Every distinct SW17/SW-fire15 frame, one seam per clip and all named transition cases; fixed physics/input checks retain every tick"
	report.rendered_frames=rendered_frames.keys()
	report.rendered_seams=rendered_seams.keys()
	if not logic_only:report.video_adapter=RenderingServer.get_video_adapter_name()
	FileAccess.open(output_folder.path_join("logic_report.json" if logic_only else "report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify({"status":report.status,"checks":checks,"draws":draws,"failures":failures,"run_frames":seen.size(),"run_wraps":wraps,"real_shots":report.real_shots}))
	ui.combat_audio.stop_all();ui.queue_free();await process_frame;await process_frame;await create_timer(.1).timeout;quit(0 if failures.is_empty() else 1)
