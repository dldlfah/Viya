extends SceneTree
## Main-scene SE review. Fixed updates and actual draws, never realtime FPS.
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const FOLDER="res://"+".local_validation/GAME066_REVIEW/game"
var ui
var checks:int=0
var draws:int=0
var failures:Array=[]
var records:Array=[]
var logic_only:bool=false
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
	ui._update_hud();ui.view.queue_redraw()
	var saved:Dictionary=Snapshot.capture(ui.simulation)
	var cues:Dictionary=ui.simulation.cues.snapshot()
	await process_frame;await RenderingServer.frame_post_draw
	expect(saved==Snapshot.capture(ui.simulation) and cues==ui.simulation.cues.snapshot(),"Read-only main-scene render:"+path)
	draws+=1
	if not path.is_empty():expect(root.get_texture().get_image().save_png(FOLDER.path_join(path))==OK,"Capture:"+path)
func record(kind:String,index:int,shown:Dictionary):
	records.append({"kind":kind,"step":index,"time":ui.simulation.elapsed,"position":str(ui.simulation.player),"phase":shown.gait_phase,"frame":shown.sample.index,"animation":shown.sample.animation,"texture":shown.sample.texture.resource_path,"muzzle":str(ui.view.viya.muzzle(ui.view.actor_art,shown,ui.view.world_to_screen(ui.simulation.player))),"shots":ui.simulation.shots})
func moving_step(animation:String,sign:float=1.0) -> Dictionary:
	var previous:Dictionary=ui.view.actor_visual()
	var position:Vector2=ui.simulation.player
	ui._physics_process(1.0/60)
	var shown:Dictionary=ui.view.actor_visual()
	expect(shown.sample.animation==animation,"Expected actual moving clip:"+animation)
	var traveled:float=ui.simulation.player.distance_to(position)
	expect(absf(traveled-235.0/60)<.002,"Unobstructed fixture retains configured movement235")
	expect(is_equal_approx(fposmod(shown.gait_phase-float(previous.gait_phase),1.0),fposmod(sign*traveled/155,1.0)),"Actual distance and signed gait increment remain continuous")
	return shown
func run():
	logic_only=OS.get_cmdline_user_args().has("--logic-only")
	if DisplayServer.get_name()=="headless" and not logic_only:printerr("Actual display required");quit(2);return
	DirAccess.make_dir_recursive_absolute(FOLDER.path_join("frames"))
	root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	ui=load("res://scenes/main.tscn").instantiate()
	ui.run_store.path=FOLDER.path_join("battle.save");ui.gold_progress.path=FOLDER.path_join("gold.cfg");ui.settings_path=FOLDER.path_join("settings.cfg")
	for path in [ui.run_store.path,ui.gold_progress.path,ui.settings_path]:DirAccess.remove_absolute(path)
	root.add_child(ui);ui.set_physics_process(false);await process_frame;Campaign.depart(ui)
	ui.safe_area_override=Rect2(0,6,1280,702);ui._apply_layout()
	var state=ui.simulation
	state.player=Vector2(2500,1700);state.enemies.clear();state.bullets.clear()
	state.spawn_clock=999;state.shot_clock=999;state._scatter_clock=999;state._swarm_clock=999
	var se:Vector2=ui.view.input_direction(Vector2(1,1).normalized())
	state.facing=se;ui.view.camera.reset();ui.view.actors.reset();ui.view.viya._gait_run=""
	var asset:SpriteFrames=ui.view.art.resource("viya_battle")
	expect(asset.resource_path=="res://assets/characters/pilot_32/game066_se_run/viya_game066_frames.tres" and asset.get_frame_count("run_se")==18,"Production slot resolves the delivered SE18")
	var shown:Dictionary=ui.view.actor_visual()
	expect(shown.sample["size"]==Vector2(69,85.56) and shown.sample.pivot==Vector2(.5,1),"Shared display and root remain fixed")
	await draw_frame("idle_se.png")
	key(KEY_D,true);key(KEY_S,true);await process_frame
	var seen:Dictionary={};var wraps:int=0;var previous_phase:float=0.0
	for index in range(160):
		shown=moving_step("run_se")
		seen[shown.sample.index]=true
		if shown.gait_phase<previous_phase:wraps+=1
		previous_phase=shown.gait_phase;record("run_se",index,shown)
		await draw_frame("frames/se_%03d.png"%index)
	expect(seen.size()==18 and wraps>=4,"Main-scene travel samples all18frames through at least4seams")
	# E/SE direction changes retain traveled-distance phase across unequal counts.
	for turn in range(4):
		key(KEY_S,false);await process_frame
		for index in range(8):
			shown=moving_step("run_e");record("turn_e",turn*8+index,shown)
			await draw_frame("turn_e.png" if turn==0 and index==7 else "")
		key(KEY_S,true);await process_frame
		for index in range(8):
			shown=moving_step("run_se");record("turn_se",turn*8+index,shown)
			await draw_frame("turn_se.png" if turn==0 and index==7 else "")
	key(KEY_D,false);key(KEY_S,false);await process_frame
	ui._physics_process(1.0/60);shown=ui.view.actor_visual()
	expect(shown.sample.animation=="idle_se","Released diagonal input returns to SE idle")
	var held:float=shown.gait_phase
	for index in range(12):ui._physics_process(1.0/60)
	expect(is_equal_approx(ui.view.actor_visual().gait_phase,held),"Released movement does not animate feet")
	await draw_frame("released.png")
	# Current SE18 carries the gun; dedicated SE firing art is GAME067,not present.
	# Reset the independent route fixture only; no gameplay settings/assets change.
	state.player=Vector2(2500,1700);ui.view.camera.reset()
	state.enemies.clear();state.bullets.clear();state.add_enemy(state.player+se*250)
	state.enemies[-1].speed=0;state.enemies[-1].hp=100000;state.enemies[-1].max_hp=100000
	state.shot_clock=0
	key(KEY_D,true);key(KEY_S,true);await process_frame
	var shots:int=state.shots;var firing_seen:Dictionary={}
	for index in range(80):
		state.enemies[-1].p=state.player+se*250
		shown=moving_step("run_se");firing_seen[shown.sample.index]=true
		expect(state.elapsed-float(ui.view.actors.entries[0].get("gun_since",-1000))<.4,"Actual committed shots keep the existing aim window active")
		record("current_se_fire",index,shown)
		await draw_frame("frames/fire_%03d.png"%index)
	expect(state.shots>shots and firing_seen.size()==18,"Real SE gunfire remains connected to all18measured run frames")
	key(KEY_D,false);key(KEY_S,false);key(KEY_A,true);key(KEY_W,true);await process_frame
	for index in range(48):
		state.enemies[-1].p=state.player+se*250
		shown=moving_step("run_se",-1)
		record("backward_aim_se",index,shown)
		await draw_frame("backward.png" if index==24 else "")
	key(KEY_A,false);key(KEY_W,false);await process_frame
	for index in range(24):
		ui._physics_process(1.0/60);shown=ui.view.actor_visual()
		expect(shown.sample.animation=="attack_se","Stationary SE fire uses the preserved whole-body attack")
		await draw_frame("stationary.png" if index==23 else "")
	ui.pause_game()
	var paused:Dictionary=Snapshot.capture(state);var frozen:Dictionary=ui.view.actor_visual()
	for index in range(12):ui._physics_process(1.0/60)
	expect(Snapshot.capture(state)==paused and ui.view.actor_visual().sample.index==frozen.sample.index,"Pause freezes both battle and pose")
	await draw_frame("paused.png")
	var report:Dictionary={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"draws":draws,"failures":failures,"run_frames":seen.keys(),"run_wraps":wraps,"firing_frames":firing_seen.keys(),"real_shots":state.shots-shots,"logic_only":logic_only,"display":DisplayServer.get_name(),"records":records,"engine":Engine.get_version_info(),"scope":"Production main.tscn,isolated open-stage route,native key events,fixed updates,actual draws. SE18 cycles,E/SE turns,release,current generic moving fire,backward aim,stationary attack,pause. Not dedicated SE firing art,realtime FPS,hardware QA,physical foot-contact proof or final producer approval."}
	FileAccess.open(FOLDER.path_join("logic_report.json" if logic_only else "report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify({"status":report.status,"checks":checks,"draws":draws,"failures":failures,"run_frames":seen.size(),"run_wraps":wraps,"real_shots":report.real_shots}))
	ui.combat_audio.stop_all();ui.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
