extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Cues=preload("res://scripts/combat/combat_cues.gd")
const Motion=preload("res://scripts/combat/actor_motion.gd")
const Incoming=preload("res://scripts/combat/incoming_feedback.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")

static func quiet(seed_value:int=3001):
	var state=State.new()
	state.start(seed_value,"viya",null,"prologue_wall","weapons_v1")
	state.player=Vector2(2500,1700)
	state.spawn_clock=999
	state.shot_clock=999
	state._scatter_clock=999
	state._swarm_clock=999
	return state

static func run(host,verify:Callable)->void:
	verify.call(Incoming.arrow(Vector2(1,.45),true)=="→" and Incoming.arrow(Vector2(1,.45),false)=="↘","HUD direction sectors follow the actual projected or legacy screen axes")
	var cues=Cues.new()
	cues.record_received(Vector2.ZERO,0,{"kind":"contact","id":1,"p":Vector2.RIGHT})
	verify.call(cues.received.is_empty() and cues.received_serial==0,"Zero HP loss creates no received event or serial")
	for index in range(12):cues.record_received(Vector2.ZERO,1,{})
	verify.call(cues.received.size()==Cues.MAX_RECEIVED and cues.received[0].serial==7,"Received marks have their own six-event cap without evicting outgoing hit/XP cues")
	var copy:Dictionary=cues.snapshot()
	copy.received[0].amount=999
	verify.call(cues.received[0].amount==1,"Received snapshot is a detached copy")
	copy=cues.latest_received()
	copy.direction=Vector2.RIGHT
	verify.call(cues.latest_received().direction==Vector2.ZERO,"A HUD notice cannot rewrite received direction")
	cues.advance(NAN)
	verify.call(cues.received.size()==6,"Invalid timing leaves received lifetimes intact")
	cues.advance(1)
	verify.call(cues.received.is_empty(),"Received marks expire on the existing simulation clock")
	cues.record_received(Vector2.ZERO,2,{})
	cues.set_enabled(false)
	verify.call(cues.received.is_empty() and cues.received_serial==0,"Disabling cues clears received marks and serial without changing combat")
	var state=quiet()
	state.add_enemy(state.player+Vector2(16,0))
	state.add_enemy(state.player+Vector2(0,2))
	for enemy in state.enemies:
		enemy.speed=0
		enemy.contact_damage=12
	var actual_id:int=state.enemies[0].id
	var observer=Motion.new()
	observer.prepare(state)
	# Real regen at the end of this same production step conceals the net HP delta.
	state.stats.regen=240
	state.step(.05,Vector2.ZERO)
	observer.sync(state,Vector2.ZERO,true)
	var hit:Dictionary=state.cues.latest_received()
	verify.call(hit.kind=="contact" and hit.id==actual_id and hit.direction==Vector2.RIGHT and hit.amount==12,"Actual collision iteration identifies the accepted attacker, not the nearest enemy")
	verify.call(state.cues.received.size()==1,"The second overlapping enemy produces no fake hit during invulnerability")
	verify.call(state.hp==state.max_hp and observer.pose(state).pose=="hurt" and observer.pose(state).direction=="e","Committed loss drives hurt direction even when real same-step regen restores HP")
	verify.call(observer.pose(state,actual_id).pose=="attack" and observer.pose(state,int(state.enemies[1].id)).pose!="attack","Only the actual accepted contact attacker receives the attack pose")
	state.stats.regen=0
	state.enemies.clear()
	state.hurt_clock=0
	state.facing=Vector2.LEFT
	observer.prepare(state)
	state.damage_player(2)
	state.step(.05,Vector2.ZERO)
	observer.sync(state,Vector2.ZERO,true)
	verify.call(state.cues.latest_received().kind=="unknown" and state.cues.latest_received().direction==Vector2.ZERO and observer.pose(state).direction=="w","Unknown-source damage stays neutral and cannot reuse a previous hit direction")
	state=quiet(3002)
	state.add_enemy(state.player-Vector2(10,0))
	state.enemies[0].speed=0
	state.enemies[0].contact_damage=0
	state.enemy_bullets.append({"p":state.player+Vector2(80,0),"velocity":Vector2(-1800,0),"damage":8,"life":1.0})
	state.step(.05,Vector2.ZERO)
	hit=state.cues.latest_received()
	verify.call(state.hp==92 and state.enemy_bullets.is_empty() and hit.kind=="projectile" and hit.direction==Vector2.RIGHT and hit.id==0,"A removed crossing projectile preserves its true incoming direction without inventing a shooter")
	state=quiet(3003)
	state.map_space.solids.clear()
	state.map_space.solids.append(Rect2(state.player+Vector2(-55,-30),Vector2(12,60)))
	state.enemy_bullets.append({"p":state.player-Vector2(80,0),"velocity":Vector2(1800,0),"damage":8,"life":1.0})
	state.step(.05,Vector2.ZERO)
	verify.call(state.hp==100 and state.cues.received.is_empty() and state.enemy_bullets.is_empty(),"A projectile actually stopped by terrain creates no received damage marker")
	state=quiet(3004)
	state.add_enemy(state.player+Vector2(300,0),"normal","ranged")
	state.enemies[0].fire_clock=0
	state.step(.05,Vector2.ZERO)
	verify.call(state.enemies[0].windup>0 and state.cues.received.is_empty(),"Ranged preparation alone is not reported as a hit")
	state=quiet(3005)
	state.stats.damage_reduction=.03
	state._damage_reduction_remainder=.99
	var accepted:bool=state.damage_player(1)
	verify.call(accepted and state.hp==100 and state.hurt_clock>0 and state.cues.received.is_empty() and state.feedback.current(100,100)=="normal","Fully prevented fractional damage keeps existing acceptance/lock semantics but produces no false hurt reaction")
	state.hurt_clock=0
	state.stats.physical_defense=200
	state.damage_player(20)
	verify.call(state.cues.latest_received().amount==100-state.hp and state.cues.latest_received().amount<20,"Received numbers show HP actually lost after defense and account prevention")
	state=quiet(3006)
	state.hp=3
	state.damage_player(999)
	verify.call(state.phase==State.Phase.DEFEAT and state.cues.latest_received().amount==3,"Lethal received damage is capped to the actual remaining HP")
	state=quiet(3007)
	state.damage_player(4,"physical",0,{"kind":"contact","id":77,"p":state.player+Vector2.UP})
	var saved:Dictionary=Snapshot.capture(state)
	var restored=State.new()
	verify.call(Snapshot.restore(saved,restored) and restored.hp==state.hp and restored.cues.received.is_empty() and restored.cues.received_serial==0,"Version15 restore preserves HP and reconstructs neutral transient received state")
	observer=Motion.new()
	observer.prepare(restored)
	observer.sync(restored,Vector2.ZERO,true)
	verify.call(observer.pose(restored).pose=="idle","Restoring a hit lock cannot replay the old attacker or hurt animation")
	for phase in [State.Phase.PAUSED,State.Phase.CHOOSING,State.Phase.DEFEAT]:
		state.phase=phase
		var frozen:Dictionary=state.cues.snapshot()
		state.step(.05,Vector2.ONE)
		verify.call(frozen==state.cues.snapshot(),"Inactive phase freezes received events: "+str(phase))
	state.start(3008,"viya",null,"prologue_wall","weapons_v1")
	verify.call(state.cues.received.is_empty() and state.cues.received_serial==0,"New sorties discard old received directions")
	# Actual mobile adapter uses the same state, actor motion and both drawing paths.
	var ui=load("res://scenes/main.tscn").instantiate()
	var folder:="user://incoming-"+Crypto.new().generate_random_bytes(8).hex_encode()
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
	state.spawn_clock=999
	state.shot_clock=999
	state._scatter_clock=999
	state._swarm_clock=999
	state.add_enemy(state.player+Vector2(16,0))
	state.enemies[0].speed=0
	state.enemies[0].contact_damage=12
	ui._physics_process(.05)
	verify.call(state.hp==88 and ui.feedback_panel.reaction_text.text=="→ −12" and ui.view.actors.pose(state,int(state.enemies[0].id)).pose=="attack","Actual mobile physics connects accepted HP loss,compact reaction label and contact attacker")
	state.enemies.clear()
	state.hurt_clock=0
	state.damage_player(2,"physical",0,{"kind":"contact","id":4,"p":state.player+Vector2(10,10)})
	for high in [true,false]:
		ui.view.high_angle=high
		ui.view.queue_redraw()
		await host.get_tree().process_frame
		var expected:Vector2=(ui.view.world_to_screen(state.player+Vector2(100,100))-ui.view.world_to_screen(state.player)).normalized()
		verify.call(ui.view.incoming_plan.marks[0].direction.is_equal_approx(expected),"Received direction shares the actual ground projection: "+str(high))
		verify.call(ui.view.display_plan.labels.any(func(label):return label.event.kind=="received"),"Actual received HP text enters the bounded collision-aware label plan")
	ui.view.show_damage=false
	ui.view.queue_redraw()
	await host.get_tree().process_frame
	verify.call(not ui.view.incoming_plan.is_empty() and not ui.view.display_plan.labels.any(func(label):return label.event.kind=="received"),"Damage-number preference hides received numbers while retaining the direction mark")
	ui.view.show_damage=true
	ui.view.high_angle=true
	var snapshot:Dictionary=Snapshot.capture(state)
	var visual:Dictionary=state.cues.snapshot()
	for index in range(50):Incoming.build(ui.view)
	verify.call(snapshot==Snapshot.capture(state) and visual==state.cues.snapshot(),"Received display planning writes no combat/save/reward/RNG or cue lifetimes")
	ui._open_mission(state.navigation_ticket,ui._menu_revision)
	ui.view.queue_redraw()
	await host.get_tree().process_frame
	visual=state.cues.snapshot()
	ui._physics_process(.05)
	verify.call(ui._mission_open and ui.view.incoming_plan.is_empty() and visual==state.cues.snapshot(),"Mission pause hides received marks while preserving their remaining simulation time")
	ui._handle_mobile_back()
	ui._physics_process(.05)
	verify.call(state.phase==State.Phase.RUNNING and not Incoming.build(ui.view).is_empty(),"Returning from mission restores the live received direction without replaying damage")
	state.cues.set_enabled(false)
	ui._update_hud()
	verify.call(ui.feedback_panel.reaction_text.text=="피격 · 고통","Disabling visual cues cannot leave a stale directional reaction label")
	ui.queue_free()
	await host.get_tree().process_frame
