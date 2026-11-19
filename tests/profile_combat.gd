extends Node
## QA scene, never linked from player menus. Run this scene on the actual target
## device before claiming mobile performance. Synthetic load is not a campaign.
var frames:=300
var warmup:=60
var simple:=false
var ui
var actor_serial:=0
var cpu_samples:Array=[]
var frame_samples:Array=[]
var peaks:={"enemies":0,"bullets":0,"events":0,"effects":0}
func _ready()->void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--frames="):frames=int(argument.trim_prefix("--frames="))
		elif argument=="--simple":simple=true
	if frames<60 or frames>3600:
		get_tree().quit(2)
		return
	call_deferred("run")
func add_load()->void:
	var state=ui.simulation
	while state.enemies.size()<360:
		var column:=actor_serial%30
		var row:=int(actor_serial/30)%12
		var offset:=Vector2((column-14.5)*21.0,(row-5.5)*13.0)
		# Keep the player out of the initial central cluster; foes still move/hit.
		if offset.length()<70:offset.x+=140.0 if offset.x>=0 else -140.0
		if not state.add_enemy(state.player+offset,"normal","normal",1+int(actor_serial/30)%12,"gold_slime"):break
		actor_serial+=1
func run()->void:
	var folder:="user://qa-profile-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	ui=load("res://scenes/main.tscn").instantiate()
	ui.run_store.path=folder.path_join("run.save")
	ui.gold_progress.path=folder.path_join("gold.cfg")
	ui.settings_path=folder.path_join("settings.cfg")
	get_tree().root.add_child(ui)
	ui.set_physics_process(false)
	await get_tree().process_frame
	ui.dungeon_button.pressed.emit()
	ui.dungeon_launch_button.pressed.emit()
	var state=ui.simulation
	state.growth.owned={"gun_rifle":5,"gun_suppress":5,"gun_grenade":5,"gun_ricochet":5}
	state.growth.level=1000 # Test-only unused rank budget, avoids choice pauses.
	state._refresh_stats()
	state.elapsed=50.0
	state._scatter_index=12
	state.spawn_clock=999.0
	state._scatter_clock=999.0
	state.enemies.clear()
	ui.simple_attacks=simple
	ui.view.simple_attacks=simple
	var timer:=Time.get_ticks_usec()
	var survived:=true
	for frame in range(warmup+frames):
		add_load() # Replenishment cost is explicitly excluded from the step timer.
		var before:=Time.get_ticks_usec()
		ui._physics_process(1.0/60.0)
		var cpu_ms:=(Time.get_ticks_usec()-before)/1000.0
		ui.view.queue_redraw()
		await get_tree().process_frame
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		if frame>=warmup:
			cpu_samples.append(cpu_ms)
			frame_samples.append((now-timer)/1000.0)
			peaks.enemies=maxi(peaks.enemies,state.enemies.size())
			peaks.bullets=maxi(peaks.bullets,state.bullets.size())
			peaks.events=maxi(peaks.events,state.weapon_events.size())
			peaks.effects=maxi(peaks.effects,state.effects.size())
		timer=now
		if not state.has_active_run():
			survived=false
			break
	var result:={"status":"MEASURED" if survived and cpu_samples.size()==frames else "INCOMPLETE","os":OS.get_name(),"display":DisplayServer.get_name(),"rendering_device":("headless: no GPU" if DisplayServer.get_name()=="headless" else RenderingServer.get_video_adapter_name()),"viewport":str(get_viewport().get_visible_rect().size),"simple_attacks":simple,"frames":cpu_samples.size(),"warmup":warmup,"cpu_step_ms":summary(cpu_samples),"whole_frame_ms":summary(frame_samples),"peaks":peaks,"active_4x_Lv5":state.growth.owned,"kills":state.kills,"hp_end":state.hp,"limits":"Synthetic360slime replenishment +4Lv5; only actual measured OS/device is covered. Whole-frame includes render/event scheduling and load refill. Headless timing excludes GPU; desktop/software rendering does not establish mobile FPS/thermal/battery."}
	print(JSON.stringify(result))
	ui.queue_free()
	await get_tree().process_frame
	for name in ["run.save","run.save.tmp","gold.cfg","gold.cfg.tmp","settings.cfg"]:
		if FileAccess.file_exists(folder.path_join(name)):DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
	get_tree().quit(0 if result.status=="MEASURED" else 1)
static func summary(samples:Array)->Dictionary:
	if samples.is_empty():return {}
	var sorted:=samples.duplicate()
	sorted.sort()
	return {"p50":sorted[int((sorted.size()-1)*.5)],"p95":sorted[int((sorted.size()-1)*.95)],"p99":sorted[int((sorted.size()-1)*.99)],"max":sorted[-1]}
