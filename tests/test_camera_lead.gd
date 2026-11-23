extends RefCounted
const Camera=preload("res://scripts/combat/combat_camera.gd")
const Ground=preload("res://scripts/combat/battle_projection.gd")
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Approaches=preload("res://scripts/combat/approach_cues.gd")

static func run(host,verify:Callable)->void:
	var camera=Camera.new()
	for frame in range(30):camera.advance("a",Vector2.RIGHT,.05,true)
	verify.call(camera.offset.x>.075 and camera.offset.x<=.08 and camera.offset.y==0,"Camera settles near8percent forward without exceeding its envelope")
	var frozen:Vector2=camera.offset
	camera.advance("a",Vector2.LEFT,1,false)
	verify.call(camera.offset==frozen,"Inactive combat freezes camera smoothing")
	camera.advance("a",Vector2.LEFT,.05,true)
	verify.call(camera.offset.x>0 and camera.offset.x<frozen.x,"Reversal crosses through center smoothly instead of snapping")
	for frame in range(40):camera.advance("a",Vector2.ZERO,.05,true)
	verify.call(camera.offset==Vector2.ZERO,"Releasing movement returns the running camera to center")
	camera.advance("a",Vector2.RIGHT,.05,true)
	camera.advance("b",Vector2.ZERO,.05,false)
	verify.call(camera.offset==Vector2.ZERO and camera.run_id=="b","New run discards the previous presentation offset even while paused")
	camera.advance("b",Vector2.RIGHT,NAN,true)
	verify.call(camera.offset==Vector2.ZERO,"Invalid timing cannot corrupt camera state")
	for map_id in ["legacy_arena","prologue_wall","outskirts_trial","gold_slime"]:
		var state=State.new()
		var started:bool=state.start(2601,"viya",null,map_id,"weapons_v1",{},"gold_slime" if map_id=="gold_slime" else "campaign",2601 if map_id=="gold_slime" else -1)
		for viewport in [Vector2(1280,538),Vector2(960,403),Vector2(797,266),Vector2(1544,520)]:
			state.spawn_view_size=Camera.guard_size(viewport)
			var covered:bool=started and state.map_id==map_id
			for point in [Vector2(31,31),state.world_size-Vector2.ONE*31,state.world_size*.5,Vector2(31,state.world_size.y*.5),Vector2(state.world_size.x*.5,31)]:
				state.player=point
				for index in range(8):
					camera.run_id=state.run_id
					camera.offset=Vector2.from_angle(index*TAU/8)*Camera.LEAD_FRACTION
					var center:Vector2=camera.center(state,viewport)
					var visible:=Ground.visible_world(center,viewport)
					covered=covered and state.visible_world().grow(.01).encloses(visible)
					if map_id!="legacy_arena":covered=covered and state.map_space.camera_bounds.grow(.01).encloses(visible)
			verify.call(covered,"Fixed spawn envelope covers every8direction lead and clamped map edge: "+map_id+str(viewport))
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
	verify.call(ui.view.camera.offset.x>.075 and ui.view.world_to_screen(state.player).x<ui.view.size.x*.44,"Actual mobile physics connects real displacement to forward ground view")
	var point:Vector2=state.player+Vector2(0,460)
	var edge:Vector2=ui.view.world_to_screen(point)-ui.view.world_to_screen(state.player)
	verify.call(ui.view.screen_to_world(ui.view.world_to_screen(point)).is_equal_approx(point) and is_equal_approx(edge.y,460*Ground.GROUND_Y),"Lead preserves inverse mapping and the actual460ultimate ellipse")
	var saved:Dictionary=Snapshot.capture(state)
	ui.view.advance_camera(.05,Vector2.LEFT,true)
	ui.view.queue_redraw()
	await host.get_tree().process_frame
	verify.call(saved==Snapshot.capture(state),"Camera motion/rendering writes no authoritative field or7RNG")
	var visible:=Ground.visible_world(ui.view.camera_center(),ui.view.size)
	state._scatter_index=2
	state.add_enemy(Vector2(visible.end.x+10,state.player.y),"normal","fast",1)
	state.add_enemy(state.player,"normal","heavy",2)
	var warnings:Array=Approaches.build(state,visible)
	verify.call(warnings.size()==1 and warnings[0].count==1 and warnings[0].at.x>visible.end.x,"Approach cues follow actual shifted viewport rather than the larger spawn envelope")
	state.enemies.clear()
	state._scatter_index=0
	ui._open_mission(state.navigation_ticket,ui._menu_revision)
	frozen=ui.view.camera.offset
	saved=Snapshot.capture(state)
	for frame in range(10):ui._physics_process(.05)
	verify.call(ui._mission_open and ui.view.camera.offset==frozen and saved==Snapshot.capture(state),"Mission freezes camera/combat together without losing the offset")
	ui._handle_mobile_back()
	ui._physics_process(.05)
	verify.call(ui.view.camera.offset.length()<frozen.length(),"After mission return, released movement eases back instead of retaining input")
	state.grant_xp(state.growth.threshold())
	ui._sync_phase_ui()
	frozen=ui.view.camera.offset
	ui._physics_process(.05)
	verify.call(state.phase==State.Phase.CHOOSING and ui.view.camera.offset==frozen,"Skill selection freezes camera and never rerolls offers")
	ui._choose_skill(state.growth.offer[0],state.growth.ticket)
	# A player pushing a solid wall has no actual displacement.
	state.player=Vector2(31,1700)
	ui.movement.axis=Vector2.LEFT
	ui._physics_process(.05)
	for frame in range(40):ui._physics_process(.05)
	verify.call(ui.view.camera.offset==Vector2.ZERO,"Blocked movement cannot hold a false forward camera offset")
	ui.view.camera.offset=Vector2(.05,0)
	ui.root_ui.size=Vector2(853,384)
	ui._apply_layout()
	verify.call(ui.view.camera.offset==Vector2.ZERO and state.spawn_view_size==ui.view.spawn_guard_size(),"Layout rebuild resets only camera/input and reconstructs its fixed guard")
	var current:Dictionary=Snapshot.capture(state)
	var restored=State.new()
	var loaded:bool=Snapshot.restore(current,restored)
	if loaded:restored.set_paused(false)
	verify.call(Snapshot.VERSION==16 and loaded and Campaign.comparable(restored)==Campaign.comparable(state),"Lead remains cosmetic while current v16 restores gameplay exactly")
	ui.queue_free()
	await host.get_tree().process_frame
	for file in ["battle.save","gold.cfg","settings.cfg"]:DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
