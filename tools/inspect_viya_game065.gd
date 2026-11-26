extends SceneTree
## Actual production scene/render for GAME065 east full-body moving fire.
## Fixed simulation updates are reproducible evidence, not real-time FPS results.
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const FOLDER="res://"+".local_validation/GAME065_INTEGRATION/game"
const MANIFEST="res://assets/characters/pilot_32/game065_e_run_fire/manifest.json"
var ui
var errors:Array=[]
var records:Array=[]
var checks:int=0
var draw_checks:int=0
var manifest:Dictionary
var logic_only:bool=false
func _initialize():call_deferred("run")
func expect(value:bool, label:String):
	checks+=1
	if not value:errors.append(label)
func key(code:Key, pressed:bool):
	var event:=InputEventKey.new()
	event.physical_keycode=code;event.keycode=code;event.pressed=pressed
	Input.parse_input_event(event)
func draw_frame(path:String=""):
	if logic_only:
		await process_frame
		return
	ui._update_hud();ui.view.queue_redraw()
	var before:Dictionary=Snapshot.capture(ui.simulation)
	var cues:Dictionary=ui.simulation.cues.snapshot()
	await process_frame;await RenderingServer.frame_post_draw
	expect(before==Snapshot.capture(ui.simulation) and cues==ui.simulation.cues.snapshot(),"Read-only actual render:"+path)
	draw_checks+=1
	if not path.is_empty():expect(root.get_texture().get_image().save_png(FOLDER.path_join(path))==OK,"Capture:"+path)
func record(kind:String, shown:Dictionary, step:int):
	var feet:Vector2=ui.view.world_to_screen(ui.simulation.player)
	records.append({"kind":kind,"step":step,"elapsed":ui.simulation.elapsed,"animation":shown.sample.animation,"frame":shown.sample.index,"phase":shown.get("gait_phase",0),"distance":ui.view.actors.pose(ui.simulation).distance,"world_position":str(ui.simulation.player),"muzzle":str(ui.view.viya.muzzle(ui.view.actor_art,shown,feet)),"body":str(ui.view.viya.body_rect(ui.view.actor_art,shown,feet)),"shots":ui.simulation.shots,"texture":shown.sample.texture.resource_path})
func run():
	logic_only=OS.get_cmdline_user_args().has("--logic-only")
	if DisplayServer.get_name()=="headless" and not logic_only:
		print('{"status":"BLOCKED","reason":"Actual display required"}');quit(2);return
	DirAccess.make_dir_recursive_absolute(FOLDER.path_join("frames"))
	manifest=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	ui=load("res://scenes/main.tscn").instantiate()
	ui.run_store.path=FOLDER.path_join("battle.save");ui.gold_progress.path=FOLDER.path_join("gold.cfg");ui.settings_path=FOLDER.path_join("settings.cfg")
	for path in [ui.run_store.path,ui.gold_progress.path,ui.settings_path]:DirAccess.remove_absolute(path)
	root.add_child(ui);ui.set_physics_process(false);await process_frame;Campaign.depart(ui)
	ui.safe_area_override=Rect2(0,6,1280,702);ui._apply_layout()
	var state=ui.simulation
	# Isolated stage fixture: existing gate, enemy and crate at controlled positions.
	# This unobstructed route avoids the east barracks during the longer firing test.
	state.player=Vector2(1500,460);state.enemies.clear();state.bullets.clear()
	state.spawn_clock=999;state._scatter_clock=999;state._swarm_clock=999;state.shot_clock=999
	state.facing=ui.view.input_direction(Vector2.RIGHT)
	state.add_enemy(state.player+ui.view.input_direction(Vector2.LEFT)*120)
	state.enemies[-1].speed=0
	var crate:Dictionary=state.structures.filter(func(p):return p.style=="crate")[0]
	crate.p=state.player+ui.view.input_direction(Vector2(1,.4))*110
	ui.view.camera.reset();ui.view.actors.reset();ui.view.viya._gait_run=""
	await draw_frame("scale_reference.png")
	var shown:Dictionary=ui.view.actor_visual()
	expect(shown.sample["size"]==Vector2(69,85.56),"Fixed69x85.56 display")
	expect(shown.sample.pivot==Vector2(.5,1),"Fixed full-canvas bottom pivot")
	expect(not ui.overlay.visible,"Production battle is visible")
	expect(ui.view.art.resource("viya_battle").resource_path==manifest.resource,"Production slot uses the new derivative")
	var seen:Dictionary={};var wraps:int=0;var last_phase:float=0.0
	key(KEY_D,true);await process_frame
	for index in range(160):
		ui._physics_process(1.0/60)
		shown=ui.view.actor_visual()
		expect(shown.sample.animation=="run_e","Rightward input selects run_e")
		seen[shown.sample.index]=true
		if shown.gait_phase<last_phase:wraps+=1
		last_phase=shown.gait_phase
		record("run_e",shown,index)
		await draw_frame("frames/frame_%03d.png" % index)
	key(KEY_D,false);await process_frame
	ui._physics_process(1.0/60);shown=ui.view.actor_visual()
	expect(shown.sample.animation=="idle_e" and not Input.is_physical_key_pressed(KEY_D),"Native key release returns to idle_e")
	expect(wraps>=4,"At least4 running-cycle seams rendered")
	expect(seen.size()>=35,"Distinct frames sampled at60Hz; sub16.7ms frames may be skipped")
	await draw_frame("released_idle.png")
	var distance:float=ui.view.actors.pose(state).distance
	for index in range(12):ui._physics_process(1.0/60)
	expect(is_equal_approx(distance,ui.view.actors.pose(state).distance),"Released input freezes gait distance")
	# Existing adjacent-direction art remains connected across different counts.
	key(KEY_D,true);key(KEY_S,true);await process_frame
	for index in range(20):
		ui._physics_process(1.0/60);shown=ui.view.actor_visual()
		expect(shown.sample.animation=="run_se","Diagonal input uses preserved SE art")
		record("direction_se",shown,index)
		await draw_frame("direction_se.png" if index==19 else "")
	key(KEY_S,false);await process_frame
	for index in range(20):
		ui._physics_process(1.0/60);shown=ui.view.actor_visual()
		expect(shown.sample.animation=="run_e","Returning east uses derivative")
		record("direction_e",shown,index)
		await draw_frame("returned_e.png" if index==19 else "")
	# Existing real auto-fire owns cadence and bullets; only the full-body visual changes.
	state.enemies.clear();state.bullets.clear();state.shot_clock=0
	var east:Vector2=ui.view.input_direction(Vector2.RIGHT)
	state.add_enemy(state.player+east*250)
	state.enemies[-1].speed=0;state.enemies[-1].hp=100000;state.enemies[-1].max_hp=100000
	var shots_before:int=state.shots
	var fire_seen:Dictionary={};var fire_wraps:int=0
	var previous_phase:float=shown.gait_phase
	var shot_times:Array=[];var previous_shots:int=state.shots
	for index in range(160):
		state.enemies[-1].p=state.player+east*250
		ui._physics_process(1.0/60);shown=ui.view.actor_visual()
		expect(shown.sample.animation=="run_fire_e","Real committed fire selects the new full-body east cycle")
		expect(is_equal_approx(fposmod(shown.gait_phase-previous_phase,1.0),235.0/60/155),"Starting/repeating shots preserves the distance-driven gait increment")
		if shown.gait_phase<previous_phase:fire_wraps+=1
		previous_phase=shown.gait_phase;fire_seen[shown.sample.index]=true
		if state.shots>previous_shots:shot_times.append(state.elapsed)
		previous_shots=state.shots
		record("moving_fire",shown,index)
		await draw_frame("frames/fire_%03d.png" % index)
	expect(state.shots>shots_before,"Existing auto-fire commits real shots while moving")
	expect(fire_wraps>=4 and fire_seen.size()>=mini(35,manifest.frames.size()),"New distinct firing poses and at least four seams rendered")
	state.enemies.clear();state.shot_clock=999
	for index in range(48):
		ui._physics_process(1.0/60);shown=ui.view.actor_visual()
		expect(is_equal_approx(fposmod(shown.gait_phase-previous_phase,1.0),235.0/60/155),"Ending committed fire preserves gait increment")
		if index>=26:expect(shown.sample.animation=="run_e","Expired firing window returns to accepted run at the same gait phase")
		previous_phase=shown.gait_phase
		record("fire_off",shown,index)
		await draw_frame("frames/off_%03d.png" % index)
	state.shot_clock=0
	state.add_enemy(state.player+east*250)
	state.enemies[-1].speed=0;state.enemies[-1].hp=100000;state.enemies[-1].max_hp=100000
	key(KEY_D,false);key(KEY_A,true);await process_frame
	var backward_steps:int=0
	for index in range(48):
		state.enemies[-1].p=state.player+east*250
		var previous:float=shown.gait_phase
		ui._physics_process(1.0/60);shown=ui.view.actor_visual()
		expect(shown.sample.animation=="run_fire_e","Backward travel while aiming east keeps the new full-body firing art")
		if is_equal_approx(fposmod(shown.gait_phase-previous,1.0),1.0-235.0/60/155):backward_steps+=1
		record("backward_fire",shown,index)
		await draw_frame("backward_fire.png" if index==30 else "")
	expect(backward_steps>=46,"Backward travel reverses only subsequent phase increments")
	key(KEY_A,false);await process_frame
	for index in range(30):
		ui._physics_process(1.0/60);shown=ui.view.actor_visual()
		expect(shown.sample.animation=="attack_e","Stationary fire uses preserved whole-body attack")
		record("stationary_fire",shown,index)
		await draw_frame("stationary_fire.png" if index==29 else "")
	ui.pause_game()
	var paused:Dictionary=Snapshot.capture(state)
	var paused_frame:int=shown.sample.index
	for index in range(12):ui._physics_process(1.0/60)
	expect(Snapshot.capture(state)==paused and ui.view.actor_visual().sample.index==paused_frame,"Pause freezes game and displayed frame")
	await draw_frame("paused.png")
	var result:Dictionary={"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"checks":checks,"draw_checks":draw_checks,"frames_seen":seen.keys(),"loop_wraps":wraps,"fire_frames_seen":fire_seen.keys(),"fire_loop_wraps":fire_wraps,"actual_shot_times":shot_times,"backward_steps":backward_steps,"records":records,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_rendering_device().get_device_name() if RenderingServer.get_rendering_device()!=null else "OpenGL compatibility","engine":Engine.get_version_info(),"scope":"Production main.tscn, isolated existing-stage fixture, native key events, fixed1/60updates and actual rendered frames. E travel/release/SE direction/actual moving-fire on and off at continuous gait phase/backward aiming/stationary fire/pause. Not real-time FPS, mobile or final art approval."}
	result["logic_only"]=logic_only
	FileAccess.open(FOLDER.path_join("preflight_report.json" if logic_only else "report.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify({"status":result.status,"errors":errors,"checks":checks,"draw_checks":draw_checks,"run_seen":seen.size(),"run_wraps":wraps,"fire_seen":fire_seen.size(),"fire_wraps":fire_wraps}))
	ui.combat_audio.stop_all();ui.queue_free();await process_frame;await process_frame;await create_timer(.06).timeout
	quit(0 if errors.is_empty() else 1)
