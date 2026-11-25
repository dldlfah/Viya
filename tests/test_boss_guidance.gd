extends RefCounted
const Guidance=preload("res://scripts/combat/boss_guidance.gd")
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Weapons=preload("res://scripts/combat/weapon_modules.gd")
const Campaign=preload("res://tests/test_campaign.gd")

static func run(host,verify:Callable)->void:
	var state=State.new()
	state.start(2901,"viya",null,"prologue_wall","weapons_v1")
	state.player=Vector2(900,1500)
	state.enemies.clear()
	verify.call(Guidance.inspect(state).is_empty(),"Boss guidance is absent before a real boss exists")
	state.add_enemy(state.player+Vector2(300,0),"boss")
	state.add_enemy(state.player+Vector2(0,80))
	var boss:Dictionary=state.enemies[0]
	var profile:Dictionary=state.attack_profile("gun_rifle",1,float(state.stats.rate))
	var plan:Dictionary=Guidance.inspect(state)
	Weapons.fire(state,profile,true)
	verify.call(plan.aimed and state.facing.is_equal_approx(state.player.direction_to(boss.p)) and plan.hp==boss.hp,"Guidance agrees with actual starter boss-priority aim and live HP")
	verify.call(plan.in_range and not plan.blocked and plan.status.ends_with("보스 조준"),"An open in-range boss reports aim, without promising projectile hits through intervening enemies")
	boss.p=state.player+Vector2(float(profile.reach)+.01,0)
	verify.call(not Guidance.inspect(state).in_range and Guidance.inspect(state).status.ends_with("접근 필요"),"Actual attack-profile reach controls the approach instruction")
	boss.p=state.player+Vector2(float(profile.reach),0)
	verify.call(Guidance.inspect(state).in_range and Guidance.inspect(state).aimed,"Boss-priority inclusive reach boundary matches the actual attack selector")
	boss.p=state.player+Vector2(300,0)
	state.map_space.solids.clear()
	state.map_space.solids.append(Rect2(state.player+Vector2(150,-50),Vector2(20,100)))
	plan=Guidance.inspect(state)
	verify.call(plan.in_range and plan.blocked and plan.status.ends_with("우회"),"The real projectile-width wall test reports terrain obstruction inside reach")
	state.map_space.solids.clear()
	state.growth.pacing_version=0
	plan=Guidance.inspect(state)
	Weapons.fire(state,profile,false)
	verify.call(not plan.aimed and state.facing==Vector2.DOWN and plan.status.ends_with("다른 대상 조준"),"Old pacing keeps nearest-target behavior instead of claiming boss priority")
	state.phase=State.Phase.PAUSED
	verify.call(Guidance.inspect(state).is_empty(),"Paused guidance has no running updates")
	state.phase=State.Phase.CHOOSING
	verify.call(Guidance.inspect(state).is_empty(),"Level selection hides running guidance without consuming its offer")
	state.phase=State.Phase.CLEARED
	verify.call(Guidance.inspect(state).is_empty(),"Results cannot show a stale live boss instruction")
	state.phase=State.Phase.RUNNING
	state.run_mode="gold_slime"
	verify.call(Guidance.inspect(state).is_empty(),"The boss-free gold dungeon does not acquire campaign tracking")
	var ui=load("res://scenes/main.tscn").instantiate()
	var folder:="user://boss-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	ui.run_store.path=folder.path_join("battle.save")
	ui.gold_progress.path=folder.path_join("gold.cfg")
	ui.settings_path=folder.path_join("settings.cfg")
	host.get_tree().root.add_child(ui)
	ui.set_physics_process(false)
	await host.get_tree().process_frame
	Campaign.depart(ui)
	state=ui.simulation
	state.player=Vector2(2500,1700)
	state.enemies.clear()
	state.add_enemy(state.player+Vector2(900,0),"boss")
	var saved:Dictionary=Snapshot.capture(state)
	var cues:Dictionary=state.cues.snapshot()
	for high in [true,false]:
		ui.view.high_angle=high
		for size in [Vector2(1280,538),Vector2(797,266)]:
			ui.view.size=size
			plan=Guidance.build(ui.view)
			verify.call(plan.offscreen and plan.marker_rect.has_area() and Rect2(Vector2.ZERO,size).encloses(plan.marker_rect),"Real projected boss location gets a bounded offscreen marker: "+str(high)+str(size))
			verify.call(plan.direction.dot((ui.view.world_to_screen(state.enemies[0].p)-plan.marker_rect.get_center()).normalized())>.999,"Boss arrow points at the live boss using the displayed camera")
			for index in range(50):Guidance.build(ui.view)
	verify.call(saved==Snapshot.capture(state) and cues==state.cues.snapshot(),"Repeated tracking planning changes no saved state, damage cues, offers, rewards or7RNG")
	ui.view.high_angle=true
	ui.view.size=Vector2(1280,538)
	state.spawn_view_size=ui.view.spawn_guard_size()
	for frame in range(30):ui.view.advance_camera(.05,Vector2.RIGHT,true)
	state.enemies[0].p=ui.view.screen_to_world(Vector2(-5,ui.view.size.y*.5))
	plan=Guidance.build(ui.view)
	verify.call(plan.offscreen and state.visible_world().has_point(plan.p),"Boss tracking uses the actual led viewport even when the boss remains inside the spawn exclusion envelope")
	state._scatter_index=1
	state.add_enemy(plan.p,"normal","fast",1)
	plan=Guidance.build(ui.view)
	var cue_at:Vector2=ui.view.world_to_screen(state.enemies[-1].p).clamp(Vector2.ONE*20,ui.view.size-Vector2.ONE*20)
	verify.call(plan.marker_rect.has_area() and not plan.marker_rect.intersects(Rect2(cue_at-Vector2.ONE*42,Vector2.ONE*84)),"An offscreen pack warning retains its space beside the boss marker")
	state.enemies[0].p=state.player+Vector2(100,0)
	ui.view.queue_redraw()
	await host.get_tree().process_frame
	verify.call(not ui.view.boss_guidance.offscreen and not ui.view.boss_guidance.marker_rect.has_area(),"A visible boss uses its actual foreground foot ring instead of an edge arrow")
	verify.call(ui.view.display_plan.reserved.has(ui.view.boss_guidance.status_rect.grow(3)),"Damage labels reserve the new boss status plate")
	ui._open_mission(state.navigation_ticket,ui._menu_revision)
	ui.view.queue_redraw()
	await host.get_tree().process_frame
	verify.call(ui._mission_open and ui.view.boss_guidance.is_empty() and not ui.boss_label.visible,"Existing mission pause hides both tracking and HP without intercepting inputs")
	ui.queue_free()
	await host.get_tree().process_frame
