extends RefCounted
const Slots=preload("res://scripts/ui/asset_slots.gd")
const ActorArt=preload("res://scripts/ui/actor_assets.gd")
const Motion=preload("res://scripts/combat/actor_motion.gd")
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")

static func texture(color:Color, width:int=128)->GradientTexture2D:
	var result:=GradientTexture2D.new()
	result.width=width
	result.height=160
	result.gradient=Gradient.new()
	result.gradient.colors=PackedColorArray([color,color])
	return result

static func frames()->SpriteFrames:
	var result:=SpriteFrames.new()
	for name in ["idle","run_e","attack_e","hurt_e"]:
		result.add_animation(name)
		result.set_animation_speed(name,2)
		result.set_animation_loop(name,name in ["idle","run_e"])
		result.add_frame(name,texture(Color.RED),1)
		result.add_frame(name,texture(Color.BLUE),3)
	return result

static func run(host,verify:Callable)->void:
	var folder:="user://actors-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	var path:String=folder.path_join("actor.tres")
	var generic:String=folder.path_join("generic.tres")
	ResourceSaver.save(frames(),path)
	ResourceSaver.save(texture(Color.GREEN),generic)
	var slots=Slots.new()
	var art=ActorArt.new()
	verify.call(slots.definitions.keys().all(func(k):return k=="viya_battle" or slots.definitions[k]=="") and slots.definitions.viya_battle=="res://assets/characters/pilot_32/game069_s_run_fire/viya_game069_frames.tres" and slots.definitions.has("gold_slime") and slots.definitions.has("skeleton_soldier"),"Only the explicitly supplied Viya pilot with its E derivative is bound; all species and other presentation paths remain blank")
	slots.definitions.normal=generic
	slots.definitions.goblin_raider=path
	var sample:Dictionary=art.frame(slots,["goblin_raider","normal"],"run","e",.49)
	verify.call(sample.slot=="goblin_raider" and sample.animation=="run_e" and sample.index==0,"Species-specific directional frames take priority over generic role art")
	verify.call(art.frame(slots,["goblin_raider"],"run","e",.51).index==1 and art.frame(slots,["goblin_raider"],"run","e",1.99).index==1,"Unequal relative frame durations are honored at the animation FPS")
	verify.call(art.frame(slots,["goblin_raider"],"run","e",2.0).index==0,"Looping animations wrap their total weighted duration")
	verify.call(art.frame(slots,["goblin_raider"],"attack","e",100).index==1,"Nonlooping attacks hold the final frame instead of repeating")
	verify.call(art.frame(slots,["goblin_raider","normal"],"run","w",1).animation=="idle","A missing direction uses its own neutral idle without mirroring asymmetric art")
	var right_only:=SpriteFrames.new()
	right_only.add_animation("idle_e")
	right_only.add_frame("idle_e",texture(Color.WHITE))
	var right_path:String=folder.path_join("right.tres")
	ResourceSaver.save(right_only,right_path)
	slots.definitions.goblin_raider=right_path
	verify.call(art.frame(slots,["goblin_raider","normal"],"run","w",1).slot=="normal","A right-only asset never substitutes a reversed east sprite for west")
	slots.definitions.goblin_raider=folder.path_join("missing.tres")
	verify.call(art.frame(slots,["goblin_raider","normal"],"run","e",0).slot=="normal","Missing species files preserve the existing generic actor fallback")
	slots.definitions.normal=""
	verify.call(art.frame(slots,["goblin_raider","normal"],"idle","e",0).is_empty(),"No usable texture returns the existing procedural actor fallback")
	slots.definitions.normal=generic
	slots.definitions.goblin_raider=path
	art.specs.actors.goblin_raider.pivot=[.4,.9]
	sample=art.frame(slots,["goblin_raider"],"idle","e",0)
	var feet:=Vector2(345,220)
	var rect:=ActorArt.rectangle(sample,feet)
	verify.call((rect.position+rect.size*sample.pivot).is_equal_approx(feet),"Normalized foot pivot remains exact for any frame at fixed draw size")
	art.specs.actors.goblin_raider.pivot=[-1,1]
	verify.call(art.frame(slots,["goblin_raider","normal"],"idle","e",0).slot=="normal","Invalid pivot metadata cannot partly displace an actor")
	art.specs.actors.goblin_raider.pivot=[.5,1]
	var bad:=frames()
	bad.add_frame("run_e",texture(Color.WHITE,64))
	var bad_path:String=folder.path_join("bad.tres")
	ResourceSaver.save(bad,bad_path)
	slots.definitions.goblin_raider=bad_path
	verify.call(art.frame(slots,["goblin_raider","normal"],"idle","e",0).slot=="normal","Mixed source canvases are rejected instead of shifting feet between frames")
	verify.call(art.frame(slots,["normal"],"idle","e",NAN).is_empty(),"Invalid animation time never produces a corrupt frame selection")
	var valid_specs:Dictionary=art.specs
	art.specs={"actors":[]}
	verify.call(art.frame(slots,["normal"],"idle","e",0).is_empty(),"Malformed actor metadata falls back cleanly instead of moving or crashing actors")
	art.specs=valid_specs
	var directions:=[]
	for index in range(8):directions.append(Motion.direction(Vector2.from_angle(index*PI/4)))
	verify.call(directions==["e","se","s","sw","w","nw","n","ne"],"Eight projected directions have explicit names and no automatic horizontal flip")
	var magic_state=State.new()
	magic_state.start(2812)
	magic_state.shot_clock=999
	magic_state.spawn_clock=999
	magic_state.facing=Vector2.DOWN
	magic_state._projectile(Vector2.RIGHT,1,1)
	var magic_observer=Motion.new()
	magic_observer.prepare(magic_state)
	magic_state.cast_ultimate(magic_state.magic.ticket)
	magic_state.step(.05,Vector2.ZERO)
	magic_observer.sync(magic_state,Vector2.ZERO,true)
	verify.call(magic_observer.pose(magic_state).pose=="attack" and magic_observer.pose(magic_state).direction=="s","Manual MP magic never borrows an older projectile's facing")
	var shot_state=State.new()
	shot_state.start(2813)
	shot_state.shot_clock=999
	shot_state.spawn_clock=999
	shot_state.facing=Vector2.DOWN
	shot_state._projectile(Vector2.RIGHT,1,1)
	shot_state.bullets[0].p+=Vector2(200,0)
	shot_state.add_enemy(shot_state.player-Vector2(120,0))
	var shot_observer=Motion.new()
	shot_observer.prepare(shot_state)
	shot_state._projectile(Vector2.LEFT,1,1,3000)
	shot_state.step(.05,Vector2.ZERO)
	shot_observer.sync(shot_state,Vector2.ZERO,true)
	verify.call(shot_state.bullets.size()==1 and shot_observer.pose(shot_state).direction=="w" and shot_observer.pose(shot_state).gun_aim==Vector2.LEFT and shot_observer.pose(shot_state).shot_age==0,"An immediately consumed shot retains its committed direction instead of borrowing an older surviving bullet")
	var rapid=State.new()
	rapid.start(2814)
	rapid.shot_clock=999
	rapid.spawn_clock=999
	var rapid_observer=Motion.new()
	for frame in range(4):
		rapid_observer.prepare(rapid)
		rapid._projectile(Vector2.RIGHT,1,1)
		rapid.step(.05,Vector2.ZERO)
		rapid_observer.sync(rapid,Vector2.ZERO,true)
	verify.call(rapid_observer.pose(rapid).pose=="attack" and rapid_observer.pose(rapid).clock>.09,"Rapid multiweapon fire advances animation frames instead of restarting frame0 every tick")
	var ui=load("res://scenes/main.tscn").instantiate()
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
	state.add_enemy(state.player+Vector2(350,0))
	ui.view.art.definitions.viya_battle=path
	ui.movement.axis=Vector2.RIGHT
	ui._physics_process(.05)
	verify.call(state.shots>0 and ui.view.actors.pose(state).pose=="attack" and ui.view.actor_visual().sample.animation=="attack_e","Actual committed projectile creation starts the connected attack animation")
	var original_size:Array=ui.view.actor_art.specs.actors.viya_battle.size.duplicate()
	ui.view.actor_art.specs.actors.viya_battle.size=[160,190]
	var actual_body:Rect2=ui.view.actor_art.rectangle(ui.view.actor_visual().sample,ui.view.world_to_screen(state.player))
	verify.call(preload("res://scripts/combat/combat_display.gd").build(ui.view).reserved[0].encloses(actual_body),"Damage labels protect the actual configured sprite rectangle as well as its foot marker")
	ui.view.actor_art.specs.actors.viya_battle.size=original_size
	state.shot_clock=999
	for frame in range(4):ui._physics_process(.05)
	verify.call(ui.view.actors.pose(state).pose=="run" and ui.view.actors.pose(state).moving,"Actual post-collision movement selects run after attack finishes")
	ui.movement.axis=Vector2.ZERO
	ui._physics_process(.05)
	verify.call(ui.view.actors.pose(state).pose=="idle","Released movement selects idle without altering combat speed")
	state.damage_player(1)
	state._damage_enemy(state.enemies[0].id,1)
	ui._physics_process(.05)
	verify.call(ui.view.actors.pose(state).pose=="hurt" and ui.view.actors.pose(state,state.enemies[0].id).pose=="hurt","Actual HP loss/committed hit feedback drive hero and enemy hurt poses")
	state.add_enemy(state.player+Vector2(200,150),"normal","ranged")
	state.enemies[-1].fire_clock=0
	ui._physics_process(.05)
	verify.call(ui.view.actors.pose(state,state.enemies[-1].id).pose=="attack","Real ranged windup selects its attack-preparation animation")
	ui._open_mission(state.navigation_ticket,ui._menu_revision)
	var frozen:Dictionary=ui.view.actors.pose(state)
	var before:Dictionary=Snapshot.capture(state)
	for frame in range(6):ui._physics_process(.05)
	verify.call(ui._mission_open and frozen==ui.view.actors.pose(state) and before==Snapshot.capture(state),"Mission freezes frame clocks and exact gameplay together")
	ui._handle_mobile_back()
	state.enemies.clear()
	ui._physics_process(.05)
	verify.call(ui.view.actors.entries.size()==1,"Removed actors are pruned and animation observations remain bounded by live actors")
	var cues:Dictionary=state.cues.snapshot()
	before=Snapshot.capture(state)
	ui.view.high_angle=true
	ui.view.queue_redraw()
	await host.get_tree().process_frame
	ui.view.high_angle=false
	ui.view.queue_redraw()
	await host.get_tree().process_frame
	verify.call(before==Snapshot.capture(state) and cues==state.cues.snapshot(),"Both real renderers sample external frames without changing saved state or7RNG")
	state.grant_xp(state.growth.threshold())
	ui._sync_phase_ui()
	frozen=ui.view.actors.pose(state)
	ui._physics_process(.5)
	verify.call(state.phase==State.Phase.CHOOSING and frozen==ui.view.actors.pose(state),"Skill selection freezes animation time without consuming or rerolling the offer")
	ui._choose_skill(state.growth.offer[0],state.growth.ticket)
	state.hurt_clock=0
	state.damage_player(100000)
	ui._sync_phase_ui()
	frozen=ui.view.actors.pose(state)
	ui._physics_process(.5)
	verify.call(state.phase==State.Phase.DEFEAT and frozen==ui.view.actors.pose(state),"Result screens hold animation frames without wall-time playback")
	ui.new_run_encounter_version=1 # Isolate idle cache reset from real policy2 reinforcements.
	ui.begin_run()
	state.spawn_clock=999
	state._scatter_clock=999
	var reference=State.new()
	Snapshot.restore(Snapshot.capture(state),reference)
	reference.set_paused(false)
	var same:=true
	for frame in range(180):
		ui.movement.axis=Vector2.RIGHT if frame<60 else Vector2.ZERO
		reference.step(.05,ui.view.input_direction(ui.movement.axis))
		ui._physics_process(.05)
		ui.view.actor_visual()
		same=same and Campaign.comparable(state)==Campaign.comparable(reference) and state.cues.snapshot()==reference.cues.snapshot()
	verify.call(same,"180actual production steps match an independent run despite sprite sampling and animation histories")
	verify.call(ui.view.actors.pose(state).pose=="idle" and ui.view.actors.run_id==state.run_id,"New deployment discards old attack/hurt animation observations")
	var resumed=State.new()
	Snapshot.restore(Snapshot.capture(state),resumed)
	resumed.set_paused(false)
	var observer=Motion.new()
	observer.prepare(resumed)
	observer.sync(resumed,Vector2.ZERO,true)
	verify.call(observer.pose(resumed).pose=="idle","Restored cumulative shot counts never invent a fresh attack animation")
	state.player=Vector2(30,1700)
	ui.movement.axis=Vector2.LEFT
	ui._physics_process(.05)
	verify.call(ui.view.actors.pose(state).pose!="run" and not ui.view.actors.pose(state).moving,"Wall-blocked input cannot animate walking; actual attacks may still play")
	state.start(2831,"viya",null,"gold_slime","weapons_v1",{},"gold_slime",2831)
	state.spawn_clock=999
	state._scatter_clock=999
	state.add_enemy(state.player+Vector2(250,0),"normal","normal",0,"gold_slime")
	ui.movement.axis=Vector2.ZERO
	ui._physics_process(.05)
	verify.call(not ui.view.tracks_enemy_motion() and ui.view.actors.entries.size()==1,"Blank-art gold slimes skip unused animation observers while the hero still animates")
	ui.view.art.definitions.normal=path
	ui._physics_process(.05)
	verify.call(ui.view.tracks_enemy_motion() and ui.view.actors.entries.has(int(state.enemies[0].id)) and ui.view.actor_visual(state.enemies[0]).sample.slot=="normal","Connecting slime or generic frame art automatically enables its actual movement observations")
	ui.queue_free()
	await host.get_tree().process_frame
	for file in ["actor.tres","generic.tres","right.tres","bad.tres","battle.save","gold.cfg","settings.cfg"]:DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	await preload("res://tests/test_gun_receipt.gd").run(host,verify)
