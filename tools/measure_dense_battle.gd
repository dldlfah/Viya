extends SceneTree
## Actual game canvas/native update A/B. Only the static mesh display switch differs.
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const State=preload("res://scripts/combat/run_state.gd")
class TimedView:
	extends "res://scripts/combat/battle_view.gd"
	var draw_ms:float=0
	func _draw():
		var start:int=Time.get_ticks_usec()
		super._draw()
		draw_ms=(Time.get_ticks_usec()-start)/1000.0
class TimedRenderer:
	extends "res://scripts/combat/high_angle_battle.gd"
	var body_us:int=0
	func draw(view):
		body_us=0
		super.draw(view)
	func _draw_enemy(enemy):
		var start:int=Time.get_ticks_usec()
		super._draw_enemy(enemy)
		body_us+=Time.get_ticks_usec()-start
var rows:Array=[]
var errors:Array=[]
func _initialize():call_deferred("run")
static func summary(values:Array) -> Dictionary:
	var a:Array=values.duplicate();a.sort()
	return {"p50_ms":a[int(a.size()*.5)],"p95_ms":a[mini(a.size()-1,int(a.size()*.95))],"max_ms":a[-1]}
static func digest(state) -> String:
	var c:=HashingContext.new();c.start(HashingContext.HASH_SHA256);c.update(var_to_bytes(Campaign.comparable(state)));return c.finish().hex_encode()
func run():
	var folder:String="res://"+".local_validation/GAME063/paired"
	DirAccess.make_dir_recursive_absolute(folder)
	var ui=load("res://scenes/main.tscn").instantiate()
	ui.run_store.path=folder.path_join("battle.save");ui.gold_progress.path=folder.path_join("gold.cfg");ui.settings_path=folder.path_join("settings.cfg")
	for path in [ui.run_store.path,ui.gold_progress.path,ui.settings_path]:DirAccess.remove_absolute(path)
	root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.add_child(ui);ui.set_physics_process(false);await process_frame
	Campaign.depart(ui)
	ui.view.set_script(TimedView);ui.view.simulation=ui.simulation;ui.view.high_renderer=TimedRenderer.new()
	ui.safe_area_override=Rect2(0,6,1280,702);ui._apply_layout()
	var tags:Array=["239","240","270","300","stage640","fly1540"]
	var rounds:int=3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tags="):tags=Array(arg.trim_prefix("--tags=").split(","))
		if arg.begins_with("--rounds="):rounds=int(arg.trim_prefix("--rounds="))
	for tag in tags:
		var path:String="res://tests/fixtures/game063/"+"natural_full_"+tag+".bin" if str(tag).is_valid_int() else "res://tests/fixtures/game050_v21/"+tag+".bin"
		if not FileAccess.file_exists(path):errors.append("Missing original fixture:"+tag);continue
		var data:Dictionary=FileAccess.open(path,FileAccess.READ).get_var(false)
		for repeat in range(rounds):
			for active in [false,true]:
				var reference:Array=[]
				for enabled in ([false,true] if repeat%2==0 else [true,false]):
					if not Snapshot.restore(data,ui.simulation):errors.append("restore "+tag);continue
					ui.simulation.set_paused(false);ui.movement.axis=Vector2(.6,.8)
					ui.view.camera.reset();ui.view.actors.reset();ui.view.viya._gait_run=""
					ui.view.high_renderer.cache_bodies=enabled
					ui.last_phase=-1;ui._sync_phase_ui();ui._update_hud()
					if ui.overlay.visible:errors.append("Obscured battle:"+tag)
					var cpu:Array=[];var frames:Array=[];var draws:Array=[];var bodies:Array=[];var hashes:Array=[];var counts:Array=[]
					var first:Dictionary={}
					for frame in range(72 if tag=="239" and active else 40):
						if ui.simulation.phase==State.Phase.CHOOSING:ui._choose_skill(ui.simulation.growth.offer[0],ui.simulation.growth.ticket)
						var start:int=Time.get_ticks_usec()
						if active:ui._physics_process(1.0/60)
						var physics:float=(Time.get_ticks_usec()-start)/1000.0
						ui.view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
						var elapsed:float=(Time.get_ticks_usec()-start)/1000.0
						if frame==0:first={"native_update_ms":physics,"iteration_ms":elapsed,"draw_ms":ui.view.draw_ms,"mesh_builds_total":ui.view.high_renderer.body_cache.builds}
						if frame>=8:
							cpu.append(physics);frames.append(elapsed);draws.append(ui.view.draw_ms);bodies.append(ui.view.high_renderer.body_us/1000.0)
						hashes.append(digest(ui.simulation));counts.append(ui.simulation.enemies.size())
					if reference.is_empty():reference=hashes
					elif hashes!=reference:errors.append("Authority/RNG mismatch:"+tag)
					var row:Dictionary={"tag":tag,"round":repeat,"cache":enabled,"active":active,"initial_actors":data.run.enemies.size(),"visible":ui.view.high_renderer.stats.actors,"counts":counts,"hashes":hashes,"first":first,"native_update":summary(cpu),"draw_cpu":summary(draws),"body_cpu":summary(bodies),"rendered_iteration":summary(frames),"raw":{"native_update":cpu,"draw_cpu":draws,"body_cpu":bodies,"rendered_iteration":frames},"view":str(ui.view.size),"spawn_guard":str(ui.simulation.spawn_view_size)}
					rows.append(row)
					print(JSON.stringify({"tag":tag,"round":repeat,"active":active,"cache":enabled,"draw":row.draw_cpu,"iteration":row.rendered_iteration}))
					if not active and repeat==0:root.get_texture().get_image().save_png(folder.path_join(tag+("_after" if enabled else "_before")+".png"))
	var file:=FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"rows":rows,"renderer":RenderingServer.get_video_adapter_name(),"scope":"Linux actual GUI, fixed native updates and separate frozen draw, alternating order, no screenshot encoding in samples. Iteration includes frame scheduling/render submission/wait; it is not isolated GPU time or device FPS."},"  "))
	ui.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
