extends RefCounted
const Camera=preload("res://scripts/combat/combat_camera.gd")
const Ground=preload("res://scripts/combat/battle_projection.gd")
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Approaches=preload("res://scripts/combat/approach_cues.gd")

static func run(host,verify:Callable)->void:
	var camera=Camera.new()
	var probe=State.new()
	probe.start(2600)
	var viewport:=Vector2(1280,538)
	camera.advance(probe,viewport,Vector2.ZERO,.05,true)
	var initial:Vector2=camera.center(probe,viewport)
	for frame in range(4):
		probe.player+=Vector2(10,0)
		camera.advance(probe,viewport,Vector2(10,0),.05,true)
	verify.call(camera.center(probe,viewport).is_equal_approx(initial),"Small movement inside the central dead zone leaves the background fixed")
	for frame in range(30):
		probe.player+=Vector2(12,0)
		camera.advance(probe,viewport,Vector2(12,0),.05,true)
	verify.call(camera.offset.x<0 and camera.offset.x>=-.08 and camera.offset.y==0,"Long movement follows from behind without anticipatory camera lead")
	var frozen:Vector2=camera.offset
	camera.advance(probe,viewport,Vector2.ZERO,1,false)
	verify.call(camera.offset==frozen,"Inactive combat freezes the stable camera")
	var stopped_at:Vector2=camera.center(probe,viewport)
	probe.player-=Vector2(12,0)
	camera.advance(probe,viewport,Vector2(-12,0),.05,true)
	verify.call(camera.center(probe,viewport).is_equal_approx(stopped_at),"Direction reversal does not keep panning in the old direction")
	frozen=camera.offset
	for frame in range(40):camera.advance(probe,viewport,Vector2.ZERO,.05,true)
	verify.call(camera.offset==frozen and camera.center(probe,viewport).is_equal_approx(stopped_at),"Releasing movement leaves no return-to-center drift")
	probe.start(2602)
	camera.advance(probe,viewport,Vector2.ZERO,.05,false)
	verify.call(camera.offset==Vector2.ZERO and camera.run_id==probe.run_id,"New run discards old presentation history even while paused")
	camera.advance(probe,viewport,Vector2.RIGHT,NAN,true)
	verify.call(camera.offset==Vector2.ZERO,"Invalid timing cannot corrupt camera state")
	for dt in [1.0/60.0,.05]:
		probe.start(2603)
		camera.reset(probe.run_id)
		camera.advance(probe,viewport,Vector2.ZERO,dt,true)
		var bounded:=true
		for frame in range(140):
			var direction:Vector2=Vector2.RIGHT if frame<40 else (Vector2.LEFT if frame<80 else (Vector2.ZERO if frame<100 else Vector2.DOWN))
			var displacement:Vector2=direction*235*dt
			var previous:Vector2=camera.center(probe,viewport)
			probe.player+=displacement
			camera.advance(probe,viewport,displacement,dt,true)
			var motion:Vector2=camera.center(probe,viewport)-previous
			bounded=bounded and absf(motion.x)<=absf(displacement.x)+.001 and absf(motion.y)<=absf(displacement.y)+.001 and motion.dot(displacement)>=-.001 and absf(camera.offset.x)<=.080001 and absf(camera.offset.y)<=.080001
		verify.call(bounded,"Camera never moves faster than the actual player or outside the published envelope at dt="+str(dt))
		var stable:Vector2=camera.center(probe,viewport)
		for frame in range(30):camera.advance(probe,viewport,Vector2.ZERO,dt,true)
		verify.call(camera.center(probe,viewport).is_equal_approx(stable),"Stopping after vertical movement freezes the exact displayed center at dt="+str(dt))
	verify.call(Camera.guard_size(viewport)==Ground.world_view_size(viewport)*1.16,"Published1.16spawn extent is unchanged by comfort tracking")
	probe.start(2604)
	camera.reset(probe.run_id)
	camera.advance(probe,viewport,Vector2.ZERO,.05,true)
	var held:Vector2=camera.center(probe,viewport)
	probe.player+=Vector2(10,0)
	camera.advance(probe,viewport,Vector2(10,0),.05,false)
	camera.advance(probe,viewport,Vector2.ZERO,.05,true)
	verify.call(camera.center(probe,viewport).is_equal_approx(held),"A final movement step opening a choice/pause does not cause a recenter jump on Continue")
	for map_id in ["legacy_arena","prologue_wall","outskirts_trial","gold_slime"]:
		var state=State.new()
		var started:bool=state.start(2601,"viya",null,map_id,"weapons_v1",{},"gold_slime" if map_id=="gold_slime" else "campaign",2601 if map_id=="gold_slime" else -1)
		for tested_viewport in [Vector2(1280,538),Vector2(960,403),Vector2(797,266),Vector2(1544,520)]:
			state.spawn_view_size=Camera.guard_size(tested_viewport)
			var covered:bool=started and state.map_id==map_id
			for point in [Vector2(31,31),state.world_size-Vector2.ONE*31,state.world_size*.5,Vector2(31,state.world_size.y*.5),Vector2(state.world_size.x*.5,31)]:
				state.player=point
				camera.reset(state.run_id)
				camera.advance(state,tested_viewport,Vector2.ZERO,.05,true)
				for index in range(8):
					camera.run_id=state.run_id
					var direction:Vector2=Vector2.from_angle(index*TAU/8)
					camera.offset=Vector2(signf(direction.x) if absf(direction.x)>.01 else 0,signf(direction.y) if absf(direction.y)>.01 else 0)*Camera.MAX_OFFSET_FRACTION
					var center:Vector2=camera.center(state,tested_viewport)
					var visible:=Ground.visible_world(center,tested_viewport)
					covered=covered and state.visible_world().grow(.01).encloses(visible)
					if map_id!="legacy_arena":covered=covered and state.map_space.camera_bounds.grow(.01).encloses(visible)
			verify.call(covered,"Fixed spawn envelope covers all axis/corner offsets and clamped map edge: "+map_id+str(tested_viewport))
	var ui=load("res://scenes/main.tscn").instantiate()
	var folder:="user://camera-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	ui.run_store.path=folder.path_join("battle.save")
	ui.gold_progress.path=folder.path_join("gold.cfg")
	ui.settings_path=folder.path_join("settings.cfg")
	host.get_tree().root.add_child(ui)
	ui.set_physics_process(false)
	await host.get_tree().process_frame
	Campaign.depart(ui)
	var state=ui.simulation
	state.player=Vector2(2500,1700)
	state.spawn_clock=999
	state._scatter_clock=999
	ui.movement.axis=Vector2.RIGHT
	for frame in range(20):ui._physics_process(.05)
	verify.call(ui.view.camera.offset.x<0 and ui.view.world_to_screen(state.player).x>ui.view.size.x*.5 and ui.view.world_to_screen(state.player).x<=ui.view.size.x*.581,"Actual mobile physics uses the stable dead zone instead of forward camera lead")
	var point:Vector2=state.player+Vector2(0,460)
	var edge:Vector2=ui.view.world_to_screen(point)-ui.view.world_to_screen(state.player)
	verify.call(ui.view.screen_to_world(ui.view.world_to_screen(point)).is_equal_approx(point) and edge.is_equal_approx(ui.view.project_direction(Vector2(0,460))),"Stable tracking preserves inverse mapping and the actual460ultimate ellipse")
	var saved:Dictionary=Snapshot.capture(state)
	ui.view.advance_camera(.05,Vector2.ZERO,true)
	ui.view.queue_redraw()
	await host.get_tree().process_frame
	verify.call(saved==Snapshot.capture(state),"Camera motion/rendering writes no authoritative field or7RNG")
	var visible:=Ground.visible_world(ui.view.camera_center(),ui.view.size)
	state._scatter_index=2
	state.add_enemy(Vector2(visible.end.x+10,state.player.y),"normal","fast",1)
	state.add_enemy(state.player,"normal","heavy",2)
	var warnings:Array=Approaches.build(state,visible)
	verify.call(warnings.size()==1 and warnings[0].count==1 and warnings[0].at.x>visible.end.x,"Approach cues follow actual stable viewport rather than the larger spawn envelope")
	state.enemies.clear()
	state._scatter_index=0
	ui._open_mission(state.navigation_ticket,ui._menu_revision)
	frozen=ui.view.camera.offset
	saved=Snapshot.capture(state)
	for frame in range(10):ui._physics_process(.05)
	verify.call(ui._mission_open and ui.view.camera.offset==frozen and saved==Snapshot.capture(state),"Mission freezes camera/combat together without losing the offset")
	ui._handle_mobile_back()
	ui._physics_process(.05)
	verify.call(ui.view.camera.offset==frozen,"Mission return with released movement keeps the exact stable view")
	state.grant_xp(state.growth.threshold())
	ui._sync_phase_ui()
	frozen=ui.view.camera.offset
	ui._physics_process(.05)
	verify.call(state.phase==State.Phase.CHOOSING and ui.view.camera.offset==frozen,"Skill selection freezes camera and never rerolls offers")
	ui._choose_skill(state.growth.offer[0],state.growth.ticket)
	# A player pushing a solid wall has no actual displacement.
	state.player=Vector2(31,1700)
	ui.movement.axis=ui.view.project_direction(Vector2.LEFT).normalized()
	ui._physics_process(.05)
	var blocked_center:Vector2=ui.view.camera_center()
	for frame in range(40):ui._physics_process(.05)
	verify.call(ui.view.camera_center()==blocked_center,"Blocked movement cannot make the background drift")
	ui.view.camera.offset=Vector2(.05,0)
	ui.root_ui.size=Vector2(853,384)
	ui._apply_layout()
	verify.call(ui.view.camera.offset==Vector2.ZERO and state.spawn_view_size==ui.view.spawn_guard_size(),"Layout rebuild resets only camera/input and reconstructs its fixed guard")
	var current:Dictionary=Snapshot.capture(state)
	var restored=State.new()
	var loaded:bool=Snapshot.restore(current,restored)
	if loaded:restored.set_paused(false)
	verify.call(Snapshot.VERSION==22 and loaded and Campaign.comparable(restored)==Campaign.comparable(state),"Stable camera remains cosmetic while current v18 restores gameplay exactly")
	ui.queue_free()
	await host.get_tree().process_frame
	for file in ["battle.save","gold.cfg","settings.cfg"]:DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
