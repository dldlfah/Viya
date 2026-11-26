extends SceneTree
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
var ui
var errors=[]
var rows=[]
const FOLDER="res://"+".local_validation/GAME063/visual"
func _initialize():call_deferred("run")
func compare(tag):
	var images=[];var before=Snapshot.capture(ui.simulation);var cue_before=ui.simulation.cues.snapshot()
	for enabled in [false,true]:
		ui.view.high_renderer.cache_bodies=enabled;ui._update_hud();ui.view.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image();images.append(image)
		image.save_png(FOLDER.path_join(tag+("_after" if enabled else "_before")+".png"))
	var a=images[0].get_data();var b=images[1].get_data();var maximum=0;var changed=0
	for i in range(a.size()):
		var d=absi(int(a[i])-int(b[i]));maximum=maxi(maximum,d)
		if d>0:changed+=1
	var same=Snapshot.capture(ui.simulation)==before and ui.simulation.cues.snapshot()==cue_before
	rows.append({"tag":tag,"max_channel_difference":maximum,"changed_channels":changed,"authority_and_cues_equal":same,"actors":ui.simulation.enemies.size(),"visible":ui.view.high_renderer.stats.get("actors",0),"occluders":ui.view.high_renderer.stats.get("occluders",0),"hero_animation":ui.view.actor_visual().sample.animation,"hero_frame":ui.view.actor_visual().sample.index,"boss_guidance":ui.view.boss_guidance})
	if maximum>1 or not same:errors.append(tag)
func run():
	DirAccess.make_dir_recursive_absolute(FOLDER)
	ui=load("res://scenes/main.tscn").instantiate();ui.run_store.path=FOLDER.path_join("battle.save");ui.gold_progress.path=FOLDER.path_join("gold.cfg");ui.settings_path=FOLDER.path_join("settings.cfg")
	for p in [ui.run_store.path,ui.gold_progress.path,ui.settings_path]:DirAccess.remove_absolute(p)
	root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.add_child(ui);ui.set_physics_process(false);await process_frame;Campaign.depart(ui)
	ui.safe_area_override=Rect2(0,6,1280,702);ui._apply_layout()
	var data=FileAccess.open("res://tests/fixtures/game063/natural_full_300.bin",FileAccess.READ).get_var(false)
	if not Snapshot.restore(data,ui.simulation):errors.append("restore")
	var s=ui.simulation;s.set_paused(false);ui.view.camera.reset();ui.view.actors.reset();ui.last_phase=-1;ui._sync_phase_ui()
	await compare("natural300")
	# Controlled real cues, all original gameplay APIs; these are QA fixtures, not natural balance.
	s.add_enemy(s.player+Vector2(110,30),"boss")
	var boss=s.enemies[-1]
	s.add_enemy(s.player+Vector2(-65,30),"normal","normal")
	var victim=s.enemies[-1];victim.weapon_status={"mark":1.0,"slow_left":1.0}
	ui.view.actors.prepare(s);s.hurt_clock=0 # Controlled accepted-hit fixture, not natural invulnerability/balance.
	s._damage_enemy(victim.id,5);s.damage_player(10,"physical",0.0,{"kind":"contact","id":victim.id,"p":victim.p})
	s.add_enemy(s.player+Vector2(190,-60),"normal","ranged");s.enemies[-1].fire_clock=0;s._tick_ranged(s.enemies[-1],.01)
	ui.view.actors.sync(s,Vector2.ZERO,true)
	await compare("hurt_tells_boss")
	var solid=s.map_space.definition.obstacles[0];var rect=s.MapCatalog.rectangle(solid.rect)
	s.player=Vector2(rect.get_center().x,rect.end.y-5);ui.view.camera.reset();ui.view.actors.reset()
	await compare("wall_occlusion")
	s.player=Vector2(2500,1700);boss.p=s.player+Vector2(180,0);ui.view.camera.reset()
	s._apply_supply("purge")
	await compare("purge_protected_boss")
	ui.view.high_angle=false
	await compare("legacy_f8")
	ui.view.high_angle=true
	while s.phase==s.Phase.CHOOSING:ui._choose_skill(s.growth.offer[0],s.growth.ticket)
	ui.pause_game();await compare("paused")
	var result={"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"rows":rows,"scope":"Frozen actual production UI before/after only cache switch; all captures preserve authority/cues. Injected hurt/status/boss/ranged/occlusion/purge are visual QA, not natural balance or hardware FPS."}
	FileAccess.open(FOLDER.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result));ui.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
