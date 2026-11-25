extends RefCounted
const Ground=preload("res://scripts/combat/battle_projection.gd")
const Oblique=preload("res://scripts/combat/oblique_projection.gd")
const Scenery=preload("res://scripts/combat/oblique_scenery.gd")
const State=preload("res://scripts/combat/run_state.gd")
const View=preload("res://scripts/combat/battle_view.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")

static func run(host,verify:Callable) -> void:
	var basis:=Oblique.basis(Vector2(1280,526))
	verify.call(is_equal_approx(basis.x.x,cos(Oblique.YAW)) and is_equal_approx(basis.y.x,-sin(Oblique.YAW)),"Wide survivor view never zooms scenery/pickups to fit an old axis-aligned envelope")
	var state=State.new()
	state.start(5501,"viya",null,"siege_battlefield","weapons_v1")
	var view=View.new();view.simulation=state
	host.get_tree().root.add_child(view)
	for size in [Vector2(1280,526),Vector2(960,396),Vector2(797,266),Vector2(1544,520)]:
		view.size=size
		var exact:=true;var covered:=true;var mapped:=true;var player_safe:=true
		for player in [Vector2(31,31),Vector2(4969,3169),Vector2(2500,600),Vector2(2500,1700)]:
			state.player=player;state.spawn_view_size=view.spawn_guard_size();view.camera.reset(state.run_id)
			view.advance_camera(.05,Vector2.ZERO,true)
			for offset in [Vector2.ZERO,Vector2(.08,.08),Vector2(-.08,.08),Vector2(.08,-.08),Vector2(-.08,-.08)]:
				view.camera.offset=offset
				for point in [Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y),size*.5]:
					var at:Vector2=view.screen_to_world(point)
					exact=exact and view.world_to_screen(at).distance_to(point)<.01
					covered=covered and (not state.map_space.camera_bounds.has_point(at) or state.visible_world().grow(.02).has_point(at))
				player_safe=player_safe and Rect2(Vector2.ZERO,size).grow(-20).has_point(view.world_to_screen(player)) and view.world_to_screen(player).y>=size.y*.30
		for index in range(8):
			var input:=Vector2.from_angle(index*PI/4)*.5
			var movement:Vector2=view.input_direction(input)
			mapped=mapped and is_equal_approx(movement.length(),.5) and view.project_direction(movement).normalized().distance_to(input.normalized())<.001
		verify.call(exact,"Oblique viewport corners/inverse roundtrip on four camera edges:"+str(size))
		verify.call(covered,"All on-map tilted corners remain inside the actual spawn guard, including maximal camera lag:"+str(size))
		verify.call(player_safe,"At all four map edges the full hero stays above the HUD, including maximal camera lag:"+str(size))
		verify.call(mapped and view.input_direction(Vector2.ZERO)==Vector2.ZERO,"Eight screen input directions/analog strength retain world speed:"+str(size))
	view.size=Vector2(1280,526)
	verify.call(view.uses_oblique() and absf(view.project_direction(Vector2.RIGHT).y)>0.1,"Stage1 world axes are actually slanted with a fixed azimuth")
	var box:=Rect2(1300,1250,360,120)
	var matrix:Transform2D=Oblique.transform(Vector2(1440,1300),view.size)
	var shape:Dictionary=Scenery.geometry(box,88,matrix)
	verify.call(shape.top.size()==4 and shape.front.size()==4 and shape.side.size()==4 and shape.top[0].is_equal_approx(shape.base[0]-Vector2(0,88)),"Ground footprint is extruded vertically with independent top and two side faces")
	verify.call(Scenery.occludes(shape,matrix*Vector2(1440,1232)),"A body behind the raised ruin triggers transparency")
	verify.call(not Scenery.occludes(shape,matrix*Vector2(1440,1430)),"The same ruin does not fade when the player stands in front")
	verify.call(Scenery.height_for({"kind":"wall"})>122 and Scenery.height_for({"kind":"ruin"})>65,"Stage-only walls and ruins have a stronger silhouette without changing collision data")
	state.player=Vector2(2500,1700);view.camera.reset(state.run_id)
	var outside:Vector2=view.screen_to_world(Vector2(-15,view.size.y*.5))
	state.enemies.clear();state._scatter_index=9;state.add_enemy(outside,"normal","fast",9)
	verify.call(view.ground_visible().has_point(outside) and view.approach_cues().any(func(c):return c.count==1 and c.kind=="pack"),"A pack in a rotated AABB corner still gets its offscreen warning")
	state.damage_player(1,"physical",0,{"kind":"contact","id":1,"p":state.player+Vector2(100,80)})
	var incoming:Dictionary=view.IncomingFeedback.build(view)
	verify.call(not incoming.is_empty() and incoming.marks[0].direction.is_equal_approx(view.project_direction(state.cues.latest_received().direction).normalized()),"Accepted-hit direction marks follow the same tilted axes as the real attacker")
	var old:Dictionary=Snapshot.capture(state)
	view.queue_redraw();await host.get_tree().process_frame
	verify.call(Snapshot.capture(state)==old,"Slanted drawing/depth/occlusion/radar never mutate gameplay or seven RNG")
	var commands:Array=view.high_renderer.depth_commands(state,Rect2(Vector2.ZERO,state.world_size),true)
	var sorted:=true
	for index in range(1,commands.size()):sorted=sorted and commands[index-1].depth<=commands[index].depth
	verify.call(sorted and commands.any(func(c):return c.layer=="hero"),"Actors/props/scenery use stable projected foot-depth rather than worldY")
	view.high_angle=false
	verify.call(not view.uses_oblique() and view.input_direction(Vector2.RIGHT)==Vector2.RIGHT and view.screen_to_world(view.world_to_screen(state.player))==state.player,"F8 keeps the original planar renderer/inverse/input path")
	view.high_angle=true
	for map in ["prologue_wall","outskirts_trial","gold_slime","legacy_arena"]:
		state.start(5502,"viya",null,map,"weapons_v1",{},"gold_slime" if map=="gold_slime" else "campaign",5502 if map=="gold_slime" else -1)
		view.camera.reset(state.run_id)
		var before:Dictionary=Snapshot.capture(state)
		view.queue_redraw();await host.get_tree().process_frame
		verify.call(view.uses_oblique() and view.ground_transform()==Oblique.transform(view.camera_center(),view.size) and view.project_direction(view.input_direction(Vector2.DOWN)).normalized().distance_to(Vector2.DOWN)<.001,"All existing maps share tilted projection and matching screen input:"+map)
		verify.call(before==Snapshot.capture(state),"Global projection never mutates a resumed/other-map simulation:"+map)
		for viewport in [Vector2(1280,526),Vector2(797,266)]:
			view.size=viewport
			var corners_ok:=true
			for edge in [Vector2(31,31),state.world_size-Vector2(31,31)]:
				state.player=edge;state.spawn_view_size=view.spawn_guard_size();view.camera.reset(state.run_id);view.advance_camera(.05,Vector2.ZERO,true)
				for pixel in [Vector2.ZERO,Vector2(viewport.x,0),viewport,Vector2(0,viewport.y)]:
					var world:Vector2=view.screen_to_world(pixel)
					corners_ok=corners_ok and view.world_to_screen(world).distance_to(pixel)<.01 and (not state.map_space.camera_bounds.has_point(world) or state.visible_world().grow(.02).has_point(world))
					if map!="legacy_arena":corners_ok=corners_ok and Rect2(Vector2.ZERO,viewport).grow(-20).has_point(view.world_to_screen(edge))
			verify.call(corners_ok,"Every map's two camera edges fit inverse/spawn guard using the actual wide viewport:"+map+str(viewport))
	view.queue_free();await host.get_tree().process_frame
	var ui=load("res://scenes/main.tscn").instantiate()
	var folder:="user://oblique-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	ui.run_store.path=folder.path_join("battle.save");ui.gold_progress.path=folder.path_join("gold.cfg");ui.settings_path=folder.path_join("settings.cfg")
	host.get_tree().root.add_child(ui);ui.set_physics_process(false);await host.get_tree().process_frame
	Campaign.depart(ui);state=ui.simulation
	state.player=Vector2(2500,1700);state.spawn_clock=999;state.shot_clock=999;state._scatter_clock=999;state._swarm_clock=999
	ui.view.camera.reset(state.run_id)
	var start:Vector2=state.player
	ui.movement.axis=Vector2.RIGHT;ui._physics_process(.05)
	var displacement:Vector2=ui.view.project_direction(state.player-start)
	verify.call(displacement.x>0 and absf(displacement.y)<.01 and is_equal_approx(state.player.distance_to(start),235*.05),"Actual main physics maps screen-right input to screen-right movement at the existing235world speed")
	ui.movement.axis=Vector2.ZERO
	var at:Vector2=ui.view.camera_center()
	for i in range(10):ui._physics_process(.05)
	verify.call(ui.view.camera_center()==at,"Release leaves the tilted camera fixed without drift or rotation")
	ui.pause_game();var frozen:Dictionary=Snapshot.capture(state);var ground:Transform2D=ui.view.ground_transform()
	for i in range(5):ui._physics_process(.05)
	verify.call(Snapshot.capture(state)==frozen and ui.view.ground_transform()==ground,"Pause preserves the same camera/projection and authoritative state")
	var restored=State.new()
	verify.call(Snapshot.VERSION==22 and Snapshot.restore(frozen,restored) and Campaign.comparable(restored)==Campaign.comparable(state),"Original schema22 reader restores the same state without a camera/save field or reset")
	ui.resume_button.pressed.emit();restored.set_paused(false)
	var same:=true
	for i in range(100):
		if state.phase==State.Phase.CHOOSING:
			var id:String=state.growth.offer[0];ui._choose_skill(id,state.growth.ticket);restored.select_skill(id,restored.growth.ticket)
		ui._physics_process(.05);restored.step(.05,Vector2.ZERO)
		same=same and Campaign.comparable(state)==Campaign.comparable(restored)
	verify.call(same,"Actual continued tilted UI matches100world steps/sevenRNG against independent restore")
	ui.queue_free();await host.get_tree().process_frame
	for file in ["battle.save","gold.cfg","settings.cfg"]:DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
