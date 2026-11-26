extends SceneTree
## Real-game baseline/scale inspection. Does not supply new animation frames.
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const FOLDER="res://"+".local_validation/GAME064/game"
var ui
var errors:Array=[]
var records:Array=[]
func _initialize():call_deferred("run")
func expect(value:bool, label:String):
	if not value:errors.append(label)
func key(pressed:bool):
	var event:=InputEventKey.new();event.physical_keycode=KEY_D;event.keycode=KEY_D;event.pressed=pressed
	Input.parse_input_event(event)
func draw_frame(path:String=""):
	ui._update_hud();ui.view.queue_redraw()
	var before:Dictionary=Snapshot.capture(ui.simulation)
	var cues:Dictionary=ui.simulation.cues.snapshot()
	await process_frame;await RenderingServer.frame_post_draw
	expect(before==Snapshot.capture(ui.simulation) and cues==ui.simulation.cues.snapshot(),"Read-only actual draw:"+path)
	if not path.is_empty():expect(root.get_texture().get_image().save_png(FOLDER.path_join(path))==OK,"Capture:"+path)
func run():
	DirAccess.make_dir_recursive_absolute(FOLDER.path_join("frames"))
	root.size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	ui=load("res://scenes/main.tscn").instantiate()
	ui.run_store.path=FOLDER.path_join("battle.save");ui.gold_progress.path=FOLDER.path_join("gold.cfg");ui.settings_path=FOLDER.path_join("settings.cfg")
	for path in [ui.run_store.path,ui.gold_progress.path,ui.settings_path]:DirAccess.remove_absolute(path)
	root.add_child(ui);ui.set_physics_process(false);await process_frame;Campaign.depart(ui)
	ui.safe_area_override=Rect2(0,6,1600,882);ui._apply_layout()
	var state=ui.simulation
	# Explicit scale/gait QA fixture, not natural spawn/difficulty evidence.
	state.player=Vector2(2500,610);state.enemies.clear();state.bullets.clear()
	state.spawn_clock=999;state._scatter_clock=999;state._swarm_clock=999;state.shot_clock=999
	state.facing=ui.view.input_direction(Vector2.RIGHT)
	state.add_enemy(state.player+ui.view.input_direction(Vector2.LEFT)*120)
	state.enemies[-1].speed=0
	var crate:Dictionary=state.structures.filter(func(p):return p.style=="crate")[0]
	crate.p=state.player+ui.view.input_direction(Vector2(1,.4))*110
	ui.view.camera.reset();ui.view.actors.reset();ui.view.viya._gait_run=""
	await draw_frame("scale_reference.png")
	var shown:Dictionary=ui.view.actor_visual()
	expect(shown.sample["size"]==Vector2(69,85.56),"Existing fixed69x85.56 size")
	expect(not ui.overlay.visible,"Production battle is visible")
	var gate:Texture2D=ui.view.art.map_texture("gate_front",state.map_id)
	records.append({"kind":"scale","map":state.map_id,"hero_size":str(shown.sample["size"]),"hero_body":str(ui.view.viya.body_rect(ui.view.actor_art,shown,ui.view.world_to_screen(state.player))),"normal_height":40,"crate_display_size":"(46,43)","gate_source_size":str(gate.get_size()),"camera":str(ui.view.camera_center()),"ground_transform":str(ui.view.ground_transform()),"projection":"existing shared oblique,world_scale1","fixture":"Existing stage gate, normal enemy and existing crate moved for comparison only"})
	key(true);await process_frame
	var seen:Dictionary={};var wraps:int=0;var last:int=-1
	for index in range(90):
		ui._physics_process(1.0/60)
		shown=ui.view.actor_visual()
		expect(shown.sample.animation=="run_e","Actual rightward input samples E run")
		seen[shown.sample.index]=true
		if last==10 and int(shown.sample.index)==0:wraps+=1
		last=int(shown.sample.index)
		await draw_frame("frames/frame_%03d.png" % index if index%3==0 else "")
		records.append({"kind":"run","step":index,"elapsed":state.elapsed,"animation":shown.sample.animation,"frame":shown.sample.index,"gait_phase":shown.gait_phase,"distance":ui.view.actors.pose(state).distance,"muzzle":str(ui.view.viya.muzzle(ui.view.actor_art,shown,ui.view.world_to_screen(state.player))),"body":str(ui.view.viya.body_rect(ui.view.actor_art,shown,ui.view.world_to_screen(state.player)))})
	key(false);await process_frame
	ui._physics_process(1.0/60);shown=ui.view.actor_visual()
	expect(shown.sample.animation=="idle_e" and not Input.is_physical_key_pressed(KEY_D),"Real input release returns to stable E idle")
	expect(seen.size()==11 and wraps>=2,"All11 original frames and at least2 loop seams observed")
	await draw_frame("released_idle.png")
	var result:Dictionary={"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"frames_seen":seen.keys(),"loop_wraps":wraps,"records":records,"scope":"Unmodified production animation: real native D input,90fixed1/60updates,controlled stage scale fixture,actual X11/llvmpipe. Capture sequence sampled every3steps for20FPS playback; not real-time performance or a corrected loop/new moving-fire art."}
	FileAccess.open(FOLDER.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify({"status":result.status,"errors":errors,"seen":seen.size(),"wraps":wraps}))
	ui.combat_audio.stop_all();ui.queue_free();await process_frame;await process_frame;await create_timer(.06).timeout
	quit(0 if errors.is_empty() else 1)
