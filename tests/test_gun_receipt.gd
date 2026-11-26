extends RefCounted
## Consumed projectiles must still drive the connected hero pose, never rules.
const State=preload("res://scripts/combat/run_state.gd")
const Motion=preload("res://scripts/combat/actor_motion.gd")
const Modules=preload("res://scripts/combat/weapon_modules.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")

static func quiet():
	var state=State.new()
	state.start(2865)
	state.spawn_clock=999;state._scatter_clock=999;state._swarm_clock=999;state.shot_clock=999
	return state

static func run(host,verify:Callable) -> void:
	var state=quiet()
	var observer=Motion.new()
	observer.prepare(state)
	state._projectile(Vector2.RIGHT,1,1)
	var serial:int=state.cues.gun_serial
	var authoritative:Dictionary=Snapshot.capture(state)
	state.cues.record_gun_fire(Vector2.UP,"bow_swift")
	state.cues.record_gun_fire(Vector2.UP,"gun_rifle",true)
	state.cues.record_gun_fire(Vector2.ZERO,"gun_rifle")
	state.cues.record_gun_fire(Vector2(INF,0),"gun_rifle")
	verify.call(state.cues.gun_serial==serial and state.cues.gun_direction==Vector2.RIGHT,"Bow, fragments and invalid directions cannot replace the latest real gun receipt")
	verify.call(Snapshot.capture(state)==authoritative,"Gun presentation receipts never enter or mutate the authoritative save payload")
	var blocked=quiet()
	blocked.bullets.resize(blocked.MAX_BULLETS)
	verify.call(not blocked._projectile(Vector2.RIGHT,1,1) and blocked.cues.gun_serial==0,"A refused legacy shot at capacity never advertises gunfire")
	var module=quiet()
	var profile:Dictionary=module.attack_profile("gun_rifle",1,float(module.stats.rate))
	Modules.projectile(module,module.player,Vector2.UP,profile)
	verify.call(module.cues.gun_serial==1 and module.cues.gun_direction==Vector2.UP,"Modular gun commit records its real direction")
	profile.fragment=true
	Modules.projectile(module,module.player,Vector2.LEFT,profile)
	verify.call(module.cues.gun_serial==1,"Modular secondary fragments do not turn the hero or renew its firing pose")
	profile.fragment=false
	module.bullets.resize(module.MAX_BULLETS)
	Modules.projectile(module,module.player,Vector2.RIGHT,profile)
	verify.call(module.cues.gun_serial==1,"A refused modular shot at capacity leaves the receipt unchanged")
	module=quiet()
	observer.reset();observer.prepare(module)
	Modules.fire_start(module)
	verify.call(module.shots==0 and module.cues.gun_serial==0,"No target does not advertise a scheduled or attempted attack")
	# A gun consumed this tick followed by a surviving bow is not a bow-facing gun.
	module._projectile(Vector2.RIGHT,1,1)
	module.bullets.clear()
	var bow:Dictionary=module.attack_profile("bow_swift",1,float(module.stats.rate))
	Modules.projectile(module,module.player,Vector2.UP,bow)
	module.step(.05,Vector2.ZERO);observer.sync(module,Vector2.ZERO,true)
	verify.call(observer.pose(module).gun_aim==Vector2.RIGHT and observer.pose(module).direction=="e" and observer.pose(module).shot_age==0,"Committed gun direction wins over a later surviving non-gun projectile")
	var age:float=observer.pose(module).shot_age
	module.set_paused(true);observer.prepare(module);module.step(.05,Vector2.RIGHT);observer.sync(module,Vector2.ZERO,false)
	verify.call(observer.pose(module).shot_age==age,"Pause freezes the receipt's animation age")
	module.set_paused(false);observer.prepare(module);module.step(.05,Vector2.ZERO);observer.sync(module,Vector2.ZERO,true)
	verify.call(observer.pose(module).shot_age>=.049,"An already consumed receipt cannot renew the firing hold on the next update")
	var saved=quiet()
	saved._projectile(Vector2.RIGHT,1,1)
	var restored=State.new()
	verify.call(Snapshot.restore(Snapshot.capture(saved),restored) and restored.cues.gun_serial==0 and restored.cues.gun_direction==Vector2.ZERO,"Continue discards transient gun receipts rather than replaying historical shots")
	observer.reset();observer.prepare(restored);restored.step(.05,Vector2.ZERO);observer.sync(restored,Vector2.ZERO,true)
	verify.call(observer.pose(restored).gun_aim==Vector2.ZERO,"A fresh observer on Continue does not invent a new gun pose")
	module.start(2866)
	verify.call(module.cues.gun_serial==0 and module.cues.gun_direction==Vector2.ZERO,"New run clears the bounded receipt")
	module.cues.set_enabled(false)
	var before:Dictionary=Snapshot.capture(module)
	module.cues.record_gun_fire(Vector2.LEFT,"gun_rifle")
	verify.call(module.cues.gun_serial==0 and Snapshot.capture(module)==before,"Disabled cue diagnostics neither record gunfire nor change gameplay")
	# Production scene, active E47 clip, real swept collision and wall removal.
	var folder:="user://gun-receipt-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	var ui=Campaign.make_ui(host,folder)
	Campaign.depart(ui)
	state=ui.simulation
	state.player=Vector2(1500,460);state.enemies.clear();state.bullets.clear()
	state.spawn_clock=999;state._scatter_clock=999;state._swarm_clock=999;state.shot_clock=999
	var forward:Vector2=ui.view.input_direction(Vector2.RIGHT)
	state.facing=forward
	state.add_enemy(state.player+forward*120)
	ui.view.actors.reset();ui.view.actors.prepare(state)
	state._projectile(forward,1,1,3000)
	var old:Vector2=state.player
	state.step(.05,forward);ui.view.actors.sync(state,state.player-old,true)
	verify.call(state.shots==1 and state.bullets.is_empty() and state.enemies[0].hp<state.enemies[0].max_hp,"Production swept impact consumes the close-range shot in its creation update")
	verify.call(ui.view.actor_visual().sample.animation=="run_fire_e","Actual E moving-fire clip activates even after an immediate hit removed its bullet")
	var held:float=ui.view.actor_visual().gait_phase
	var cue_before:Dictionary=state.cues.snapshot()
	var save_before:Dictionary=Snapshot.capture(state)
	ui.view.actor_visual();ui.view.actor_visual()
	verify.call(ui.view.actor_visual().gait_phase==held and state.cues.snapshot()==cue_before and Snapshot.capture(state)==save_before,"Repeated display sampling consumes no receipts, distance or gameplay state")
	state.enemies.clear();state.bullets.clear()
	ui.view.actors.reset();ui.view.viya._gait_run=""
	# A controlled wall fixture exercises the real production wall sweep only.
	state.map_space.solids.assign([Rect2(state.player+Vector2(80,-200),Vector2(10,400))])
	ui.view.actors.prepare(state)
	state._projectile(forward,1,1,3000)
	old=state.player;state.step(.05,forward);ui.view.actors.sync(state,state.player-old,true)
	verify.call(state.bullets.is_empty() and ui.view.actor_visual().sample.animation=="run_fire_e","Wall-consumed gunfire uses the same committed E pose without a surviving bullet")
	ui.queue_free();await host.get_tree().process_frame
	for file in ["ui.save","gold.cfg","settings.cfg"]:DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
