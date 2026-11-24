extends RefCounted
const Ground = preload("res://scripts/combat/battle_projection.gd")
const Renderer = preload("res://scripts/combat/high_angle_battle.gd")
const State = preload("res://scripts/combat/run_state.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const Layout = preload("res://scripts/ui/hud_layout.gd")
const View = preload("res://scripts/combat/battle_view.gd")
const Campaign = preload("res://tests/test_campaign.gd")

static func run(host, verify: Callable) -> void:
	var center := Vector2(2500,600)
	for size in [Vector2(1280,720),Vector2(960,540),Vector2(853,384),Vector2(1600,720)]:
		var safe := Rect2(Vector2(28,6),size-Vector2(56,18))
		var layout: Dictionary = Layout.build(size,safe)
		verify.call(layout.battle.size.y/safe.size.y>=.72,"At least72percent safe height remains battle space: "+str(size))
		verify.call(layout.magic.size.x>=48 and layout.magic.size.y>=48,"ManualMP button keeps48logical pixel target: "+str(size))
		var exact := true
		for point in [Vector2.ZERO,center,Vector2(5000,3200),Vector2(1317,1244)]:
			var screen := Ground.world_to_screen(point,center,layout.battle.size)
			exact=exact and Ground.screen_to_world(screen,center,layout.battle.size).is_equal_approx(point)
		verify.call(exact,"Ground projection and inverse roundtrip actual map points: "+str(size))
		var bounds := Ground.visible_world(center,layout.battle.size)
		verify.call(Ground.world_to_screen(bounds.position,center,layout.battle.size).is_equal_approx(Vector2.ZERO) and Ground.world_to_screen(bounds.end,center,layout.battle.size).is_equal_approx(layout.battle.size),"Projected viewport and offscreen spawn guard have identical edges: "+str(size))
	var viewport := Vector2(1200,520)
	verify.call(Ground.world_to_screen(center,center,viewport).is_equal_approx(viewport*.5),"Camera centers the player's ground contact point")
	var edge := Ground.world_to_screen(center+Vector2(0,460),center,viewport)-viewport*.5
	verify.call(is_equal_approx(edge.y,460*Ground.GROUND_Y) and edge.x==0,"Actual460world-unit MP radius projects to the ground ellipse,not an unscaled screen circle")
	var box := Rect2(1300,1250,360,120)
	verify.call(Ground.occludes_player(box,65,Vector2(1440,1232),Vector2(1440,1232),viewport),"An existing ruin behind-player overlap triggers visual fade")
	verify.call(not Ground.occludes_player(box,65,Vector2(1440,1430),Vector2(1440,1430),viewport),"Player in front of the same ruin does not fade it")
	var a=State.new()
	var b=State.new()
	a.start(2401,"viya",null,"prologue_wall","weapons_v1")
	b.start(2401,"viya",null,"prologue_wall","weapons_v1")
	b.run_id=a.run_id # Match the identifier independently randomized at admission.
	a.spawn_view_size=Ground.world_view_size(viewport)
	b.spawn_view_size=a.spawn_view_size
	var high=View.new()
	var legacy=View.new()
	high.simulation=a
	legacy.simulation=b
	high.size=viewport
	legacy.size=viewport
	legacy.high_angle=false
	host.get_tree().root.add_child(high)
	host.get_tree().root.add_child(legacy)
	var equal:=true
	for frame in range(180):
		a.step(.05,Vector2.RIGHT if frame<60 else Vector2.ZERO)
		b.step(.05,Vector2.RIGHT if frame<60 else Vector2.ZERO)
		if a.phase==State.Phase.CHOOSING:
			a.select_skill(a.growth.offer[0],a.growth.ticket)
			b.select_skill(b.growth.offer[0],b.growth.ticket)
		high.queue_redraw()
		legacy.queue_redraw()
		if frame%30==0:await host.get_tree().process_frame
		equal=equal and Campaign.comparable(a)==Campaign.comparable(b)
	verify.call(equal,"Two renderers preserve every authoritative field and7RNG over180production steps")
	var before:Dictionary=Snapshot.capture(a)
	high.high_angle=false
	high.queue_redraw()
	await host.get_tree().process_frame
	verify.call(Snapshot.capture(a)==before,"Development render toggle does not alter spawn viewport,save or RNG")
	high.high_angle=true
	var expected:Vector2=high.world_to_screen(a.player+Vector2(42,-73))
	verify.call(high.screen_to_world(expected).is_equal_approx(a.player+Vector2(42,-73)),"Actual BattleView exposes the same invertible projection")
	var commands:Array=Renderer.new().depth_commands(a,Rect2(Vector2.ZERO,a.world_size))
	var sorted:=true
	for index in range(1,commands.size()):sorted=sorted and commands[index-1].depth<=commands[index].depth
	verify.call(sorted and commands.any(func(c):return c.layer=="hero") and commands.any(func(c):return c.layer=="obstacle"),"Actor/structure commands share a deterministic foot-depth order")
	verify.call(Snapshot.VERSION==21 and Snapshot.valid(Snapshot.capture(a),a),"Presentation remains compatible with current version18snapshot rules")
	high.queue_free()
	legacy.queue_free()
	await host.get_tree().process_frame
	var scene=load("res://scenes/main.tscn").instantiate()
	var suffix:String=Crypto.new().generate_random_bytes(8).hex_encode()
	scene.run_store.path="user://high-angle-"+suffix+".save"
	scene.gold_progress.path="user://high-angle-"+suffix+".cfg"
	scene.settings_path="user://high-angle-"+suffix+"-settings.cfg"
	host.get_tree().root.add_child(scene)
	scene.set_physics_process(false)
	await host.get_tree().process_frame
	Campaign.depart(scene)
	for size in [Vector2(1280,720),Vector2(960,540),Vector2(853,384),Vector2(1600,720)]:
		scene.root_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		scene.root_ui.size=size
		scene.safe_area_override=Rect2(Vector2(28,6),size-Vector2(56,18))
		scene._apply_layout()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var fitted:=true
		for control in [scene._header,scene.feedback_panel,scene._resources,scene._skills,scene._support,scene.magic_button,scene.view]:
			fitted=fitted and scene.layout_data.safe.grow(1).encloses(control.get_rect())
		verify.call(fitted,"Real Controls remain inside the safe area after minimum sizes: "+str(size))
		verify.call(scene._resources.get_rect().intersection(scene._support.get_rect()).get_area()<1 and scene._skills.get_rect().intersection(scene.magic_button.get_rect()).get_area()<1,"Real resource/support/skill/button regions do not overlap: "+str(size))
		verify.call(scene.simulation.visible_world().size.is_equal_approx(scene.view.spawn_guard_size()) and not scene.stage_text.visible,"Existing simulation uses conservative projected viewport and folded mission: "+str(size))
	var frozen:Dictionary=Snapshot.capture(scene.simulation)
	var key:=InputEventKey.new()
	key.pressed=true
	key.keycode=KEY_F8
	scene._unhandled_key_input(key)
	verify.call(not scene.view.high_angle and Snapshot.capture(scene.simulation)==frozen,"ActualF8callback switches only the renderer")
	scene.pause_game()
	verify.call(scene.dialog_body.get_children().any(func(child):return child is Label and child.text==scene.stage_text.text),"Folded mission is available in the actual mobile pause screen")
	scene.queue_free()
	await host.get_tree().process_frame
	for path in ["user://high-angle-"+suffix+".save","user://high-angle-"+suffix+".cfg","user://high-angle-"+suffix+"-settings.cfg"]:DirAccess.remove_absolute(path)
