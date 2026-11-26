extends SceneTree
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
class TimedUI:
	extends "res://scripts/ui/mobile_main.gd"
	var measured:bool=false
	var cpu:Array=[]
	var hashes:Array=[]
	var request_time:int=0
	var input_latency:float=-1
	func _physics_process(delta):
		var start=Time.get_ticks_usec();var before=simulation.player
		super._physics_process(delta)
		if not measured:return
		cpu.append((Time.get_ticks_usec()-start)/1000.0)
		if input_latency<0 and before!=simulation.player:input_latency=(Time.get_ticks_usec()-request_time)/1000.0
		if cpu.size()>=40:set_physics_process(false);measured=false
var sampled_ui
var sampling:bool=false
var post_times:Array=[]
var first_present:float=-1
func summary(values:Array):
	var a=values.duplicate();a.sort()
	return {"p50_ms":a[int(a.size()*.5)],"p95_ms":a[mini(a.size()-1,int(a.size()*.95))],"max_ms":a[-1]}
func digest(state):
	var c=HashingContext.new();c.start(HashingContext.HASH_SHA256);c.update(var_to_bytes(Campaign.comparable(state)));return c.finish().hex_encode()
func on_post_draw():
	if not sampling:return
	post_times.append(Time.get_ticks_usec())
	if first_present<0 and sampled_ui.input_latency>=0:first_present=(Time.get_ticks_usec()-sampled_ui.request_time)/1000.0
func _initialize():call_deferred("run")
func key(pressed:bool):
	var e=InputEventKey.new();e.physical_keycode=KEY_D;e.keycode=KEY_D;e.pressed=pressed;Input.parse_input_event(e)
func run():
	var folder="res://"+".local_validation/GAME063/automatic"
	DirAccess.make_dir_recursive_absolute(folder)
	var ui=load("res://scenes/main.tscn").instantiate();ui.combat_audio.free();ui.set_script(TimedUI)
	ui.run_store.path=folder.path_join("battle.save");ui.gold_progress.path=folder.path_join("gold.cfg");ui.settings_path=folder.path_join("settings.cfg")
	for p in [ui.run_store.path,ui.gold_progress.path,ui.settings_path]:DirAccess.remove_absolute(p)
	root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	sampled_ui=ui
	RenderingServer.frame_post_draw.connect(on_post_draw)
	root.add_child(ui);ui.set_physics_process(false);await process_frame;Campaign.depart(ui)
	ui.safe_area_override=Rect2(0,6,1280,702);ui._apply_layout()
	var rows=[];var errors=[]
	for tag in ["300","fly1540"]:
		var path="res://tests/fixtures/game063/natural_full_300.bin" if tag=="300" else "res://tests/fixtures/game050_v21/fly1540.bin"
		var data=FileAccess.open(path,FileAccess.READ).get_var(false)
		var hashes=[]
		for enabled in [false,true]:
			if not Snapshot.restore(data,ui.simulation):errors.append("restore");continue
			ui.simulation.set_paused(false);ui.view.camera.reset();ui.view.actors.reset();ui.view.viya._gait_run=""
			ui.view.high_renderer.cache_bodies=enabled;ui.last_phase=-1;ui._sync_phase_ui();ui._update_hud()
			for i in range(12):ui.view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
			ui.cpu=[];ui.hashes=[];ui.input_latency=-1;key(true);ui.request_time=Time.get_ticks_usec();ui.measured=true;ui.set_physics_process(true)
			post_times=[];first_present=-1;sampling=true
			var first_process_frame:int=Engine.get_process_frames()
			while ui.measured:await process_frame
			await RenderingServer.frame_post_draw
			sampling=false
			var frames=[]
			for index in range(1,post_times.size()):frames.append((post_times[index]-post_times[index-1])/1000.0)
			var first_present_ms:float=first_present
			key(false)
			await process_frame;await RenderingServer.frame_post_draw
			var final_hash:String=digest(ui.simulation)
			if hashes.is_empty():hashes.append(final_hash)
			elif final_hash!=hashes[0]:errors.append("automatic authority "+tag)
			var row={"tag":tag,"cache":enabled,"physics_ticks":ui.cpu.size(),"presented_intervals":frames.size(),"engine_process_frames":Engine.get_process_frames()-first_process_frame,"physics_callback":summary(ui.cpu.slice(8)),"presented_interval":summary(frames),"input_to_first_movement_ms":ui.input_latency,"input_to_presented_movement_ms":first_present_ms,"final_authority_hash":final_hash,"actors":ui.simulation.enemies.size(),"input_released":not Input.is_physical_key_pressed(KEY_D),"hero_animation":ui.view.actor_visual().sample.animation,"hero_frame":ui.view.actor_visual().sample.index,"shots":ui.simulation.shots}
			if ui.input_latency<0 or not row.input_released:errors.append("input "+tag)
			rows.append(row);print(JSON.stringify(row))
	var result={"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"rows":rows,"scope":"Actual engine scheduled60Hz callbacks with real Input.parse_input_event D key, exactly40 updates and retained engine catch-up policy. Different presented frame counts; compare final authority after exactly40 physics callbacks, not wall-time battle duration. Linux input probe, not hardware latency/mobile FPS."}
	FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	RenderingServer.frame_post_draw.disconnect(on_post_draw);sampled_ui=null
	ui.combat_audio.stop_all();ui.queue_free();await process_frame;await process_frame;await create_timer(.06).timeout;quit(0 if errors.is_empty() else 1)
