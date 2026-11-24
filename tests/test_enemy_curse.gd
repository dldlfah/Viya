extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Curse=preload("res://scripts/combat/enemy_patterns_v3.gd")
const Hammer=preload("res://tests/test_enemy_patterns.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Saved=preload("res://tests/test_battle_save_notice.gd")
const Visuals=preload("res://scripts/combat/enemy_pattern_visuals.gd")
const Approaches=preload("res://scripts/combat/approach_cues.gd")

static func fresh(version:int=3):
	var state=State.new()
	state.start(4001,"viya",null,"prologue_wall","weapons_v1",{},"campaign",-1,-1,version)
	Hammer.quiet(state)
	state.player=Vector2(2500,1700)
	state.add_enemy(state.player-Vector2(300,0),"elite","normal",0,"demon_shaman")
	return state

static func launch(state) -> void:
	Hammer.arm(state)
	Hammer.advance(state,1.1)

static func run(host,verify:Callable) -> void:
	var state=State.new()
	verify.call(state.start(4002,"viya",null,"prologue_wall","weapons_v1") and state.enemy_pattern_version==3,"Production campaign start connects curse revision3")
	verify.call(Snapshot.VERSION==19 and Snapshot.fingerprint_for_v17()==Snapshot.GAME039_RULES and Snapshot.fingerprint_for_v16()==Snapshot.GAME038_RULES,"Save18 retains exact published16/17 fingerprints")
	state=Hammer.fresh(3)
	verify.call(state.enemies[0].has("pattern") and state.enemy_patterns.specification(3).damage==24,"New rule initializes the inherited immutable hammer catalog")
	Hammer.arm(state)
	Hammer.advance(state,.9)
	verify.call(state.hp==76 and state.enemies[0].pattern.phase=="strike","New rule still completes the original24damage hammer strike")
	Hammer.advance(state,.2)
	verify.call(state.enemies[0].pattern.phase=="recovery" and state.enemies[0].pattern.left>.6,"New rule preserves completed hammer recovery")
	state=fresh()
	verify.call(state.enemies[0].hp==1600 and state.enemies[0].speed==65 and state.enemies[0].contact_damage==12 and state.enemies[0].pattern.left==1.75,"Curse attachment preserves locked shaman stats and full initial delay")
	for version in [0,1,2]:
		var old=fresh(version)
		Hammer.advance(old,2)
		verify.call(not old.enemies[0].has("pattern") and old.enemy_bullets.is_empty() and old.enemies[0].p.x>2200,"Published rules keep shaman original pursuit and no curse: "+str(version))
	for mutation in ["missing","bool","damage_type","fraction","windup","speed","radius","life","nan","extra"]:
		var bad:Dictionary={"schema_version":1,"demon_shaman":state.enemy_patterns.specification(3,"demon_shaman")}
		match mutation:
			"missing":bad.demon_shaman.erase("bullet_life")
			"bool":bad.demon_shaman.cooldown=true
			"damage_type":bad.demon_shaman.damage_type="physical"
			"fraction":bad.demon_shaman.damage=18.5
			"windup":bad.demon_shaman.windup=.1
			"speed":bad.demon_shaman.bullet_speed=1000
			"radius":bad.demon_shaman.bullet_radius=99
			"life":bad.demon_shaman.bullet_life=.1
			"nan":bad.demon_shaman.trigger_range=NAN
			"extra":bad.demon_shaman.homing=true
		verify.call(not Curse.valid_curse_data(bad),"Malformed curse data rejected: "+mutation)
	var before:Dictionary=Snapshot.capture(state)
	state.enemy_patterns.current.error="fixture"
	verify.call(not state.start(4003,"viya",null,"prologue_wall","weapons_v1") and before==Snapshot.capture(state) and state.enemy_patterns.available(1) and state.enemy_patterns.available(2),"Invalid curse data rejects new start atomically without disabling published rules")
	state=fresh()
	Hammer.arm(state)
	var enemy:Dictionary=state.enemies[0]
	var origin:Vector2=enemy.p
	verify.call(enemy.pattern.phase=="windup" and enemy.pattern.left==1.1 and state.enemy_bullets.is_empty(),"Actual production step begins full1.1second telegraph without early fire")
	state.player+=Vector2(0,200)
	Hammer.advance(state,1.05)
	verify.call(enemy.p==origin and enemy.pattern.direction==Vector2.RIGHT and state.enemy_bullets.is_empty(),"Caster and advertised direction stay fixed when victim moves")
	Hammer.advance(state,.05)
	verify.call(enemy.pattern.phase=="recovery" and state.enemy_bullets.size()==1 and state.enemy_bullets[0].velocity==Vector2(300,0) and state.hp==100,"One real fixed-direction curse launches into recovery")
	Hammer.advance(state,1.2)
	verify.call(state.hp==100 and enemy.pattern.phase=="chase" and enemy.pattern.left>3,"Lateral evasion avoids projectile and recovery returns original terrain chase")
	state=fresh()
	launch(state)
	Hammer.advance(state,1)
	verify.call(state.hp==82 and state.enemy_bullets.is_empty() and state._slow_left==0 and state.cues.latest_received().kind=="projectile" and state.cues.latest_received().id==0 and state.cues.latest_received().direction==Vector2.LEFT,"Real curse hits once for18magical HP through existing source/defense path with no new slow or invented shooter")
	Hammer.advance(state,.8)
	verify.call(state.hp==82,"Consumed projectile cannot hit again during recovery or chase")
	state=fresh()
	state.stats.magical_defense=.5
	state.stats.physical_defense=0
	launch(state)
	Hammer.advance(state,1)
	verify.call(state.hp==91,"Curse uses magical rather than physical defense")
	state=fresh()
	launch(state)
	state.hurt_clock=3
	Hammer.advance(state,1)
	verify.call(state.hp==100 and state.enemy_bullets.is_empty() and state.cues.received.is_empty(),"Existing invulnerability rejects the hit and still consumes the projectile once")
	state=fresh()
	launch(state)
	var saved_bullet:Dictionary=state.enemy_bullets[0].duplicate(true)
	state.enemy_bullets.clear()
	for index in range(state.MAX_ENEMY_BULLETS):state.enemy_bullets.append(saved_bullet.duplicate(true))
	state.enemies[0].pattern.phase="windup"
	state.enemies[0].pattern.left=.05
	state.enemy_patterns.tick(state,state.enemies[0],.05)
	verify.call(state.enemy_bullets.size()==64 and state.enemies[0].pattern.phase=="recovery","Curse respects the shared64bullet cap and consumes a full-cap attempt")
	state.enemy_bullets.clear()
	state.enemy_patterns.tick(state,state.enemies[0],.05)
	verify.call(state.enemy_bullets.is_empty(),"Clearing capacity cannot replay a skipped launch")
	state=fresh()
	Hammer.arm(state)
	var start:Vector2=state.enemies[0].p
	state.add_enemy(start-Vector2(35,0),"normal","flier")
	state._move_fliers(.05)
	state.enemies.remove_at(1)
	state.step(.05,Vector2.ZERO)
	verify.call(state.enemies[0].p!=start and state.enemies[0].pattern.phase=="reacquire" and state.enemy_bullets.is_empty(),"Actual flier displacement cancels a curse instead of moving its advertised origin")
	Hammer.advance(state,.7)
	verify.call(state.enemies[0].pattern.phase=="windup" and state.enemies[0].pattern.left==1.1 and state.enemy_bullets.is_empty(),"Interrupted curse requires a fresh full windup")
	state=fresh()
	launch(state)
	state._damage_enemy(state.enemies[0].id,10000)
	verify.call(state.kills==1 and state.enemies.is_empty() and state.enemy_bullets.size()==1 and not state.pickups.is_empty(),"Killing a caster retains its already-launched ordinary projectile and original XP/loot path")
	Hammer.advance(state,1)
	verify.call(state.hp==82 and state.enemy_bullets.is_empty(),"Existing launched curse resolves once even after caster death")
	state=fresh()
	Hammer.arm(state)
	state._damage_enemy(state.enemies[0].id,10000)
	Hammer.advance(state,1.2)
	verify.call(state.enemy_bullets.is_empty() and state.hp==100,"Death before launch never creates a ghost projectile")
	state=fresh()
	launch(state)
	state.map_space.definition.obstacles.append({"id":"curse-test","kind":"ruin","solid":true,"rect":[2300,1650,30,100]})
	# MapSpace caches geometry; use the same constructor as normal maps.
	state.map_space=state.MapSpace.new(state.map_space.definition)
	Hammer.advance(state,1)
	verify.call(state.hp==100 and state.enemy_bullets.is_empty(),"Actual swept curse stops at blocking terrain before the victim")
	state=fresh()
	launch(state)
	state.player+=Vector2(0,300)
	Hammer.advance(state,2.2)
	verify.call(state.enemy_bullets.is_empty() and state.hp==100,"Missed curse expires at its data lifetime without tracking the player")
	for phase in ["windup","before_fire","flight","recovery","reacquire"]:
		state=fresh()
		Hammer.arm(state)
		if phase=="before_fire":Hammer.advance(state,1.05)
		if phase in ["flight","recovery"]:Hammer.advance(state,1.1)
		if phase=="recovery":Hammer.advance(state,.3)
		if phase=="reacquire":
			state.enemies[0].p+=Vector2(10,0)
			state.step(.05,Vector2.ZERO)
		var saved:Dictionary=Snapshot.capture(state)
		var restored=State.new()
		verify.call(Snapshot.restore(saved,restored),"Curse state validates and restores: "+phase)
		restored.set_paused(false)
		var same:=true
		for frame in range(100):
			state.step(.05,Vector2.ZERO)
			restored.step(.05,Vector2.ZERO)
			same=same and Campaign.comparable(state)==Campaign.comparable(restored)
		verify.call(same,"Curse preserves100future RUNNINGsteps/sevenRNG and single launch: "+phase)
	state=fresh()
	launch(state)
	var valid:Dictionary=Snapshot.capture(state)
	for mutation in ["old_schema","old_rule","missing_type","type","damage","velocity","life","extra","species","bad_phase","bad_timer","bad_origin"]:
		var bad:Dictionary=valid.duplicate(true)
		match mutation:
			"old_schema":
				bad.version=17
				bad.rules=Snapshot.GAME039_RULES
			"old_rule":bad.run.enemy_pattern_version=2
			"missing_type":bad.run.enemy_bullets[0].erase("damage_type")
			"type":bad.run.enemy_bullets[0].damage_type="physical"
			"damage":bad.run.enemy_bullets[0].damage=999
			"velocity":bad.run.enemy_bullets[0].velocity=Vector2(400,0)
			"life":bad.run.enemy_bullets[0].life=3
			"extra":bad.run.enemy_bullets[0].homing=true
			"species":bad.run.enemy_bullets[0].species="orc_siege"
			"bad_phase":bad.run.enemies[0].pattern.phase="strike"
			"bad_timer":bad.run.enemies[0].pattern.left=9
			"bad_origin":bad.run.enemies[0].pattern.origin=Vector2(NAN,0)
		before=Snapshot.capture(state)
		verify.call(not Snapshot.restore(bad,state) and before==Snapshot.capture(state),"Malformed curse rejects atomically: "+mutation)
	var directory:="user://curse-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var ui=Saved.make_ui(host,directory)
	await host.get_tree().process_frame
	Campaign.depart(ui)
	state=ui.simulation
	Hammer.quiet(state)
	state.player=Vector2(2500,1700)
	state.add_enemy(state.player-Vector2(300,0),"elite","normal",0,"demon_shaman")
	state.enemies[0].pattern.left=0
	ui._physics_process(.05)
	before=Snapshot.capture(state)
	for high in [true,false]:
		ui.view.high_angle=high
		var planned:Array=Visuals.plan(ui.view)
		verify.call(planned.size()==1 and planned[0].phase=="curse_windup" and ui.view.screen_to_world(planned[0].origin).is_equal_approx(state.enemies[0].pattern.origin),"Both renderers show actual fixed curse origin/corridor: "+str(high))
	verify.call(before==Snapshot.capture(state),"Repeated curse geometry changes no authoritative state or RNG")
	var outside:Rect2=Rect2(state.player-Vector2(50,50),Vector2(100,100))
	verify.call(Approaches.build(state,outside).any(func(c):return c.kind=="shot" and c.at==state.enemies[0].p),"Offscreen curse windup uses the existing bounded hostile marker")
	ui._open_mission(state.navigation_ticket,ui._menu_revision)
	for frame in range(40):ui._physics_process(.05)
	verify.call(state.enemies[0].pattern.left==1.1 and state.enemy_bullets.is_empty() and Visuals.plan(ui.view).is_empty(),"Existing mission freezes and hides curse without ghost fire")
	ui.mission_return_button.pressed.emit()
	state.grant_xp(state.growth.threshold())
	ui._sync_phase_ui()
	var offers:Array=state.growth.offer.duplicate()
	for frame in range(40):ui._physics_process(.05)
	verify.call(state.phase==State.Phase.CHOOSING and state.enemies[0].pattern.left==1.1 and offers==state.growth.offer,"Existing growth choice freezes curse and exact offers")
	ui.pause_game()
	var ui2=Saved.make_ui(host,directory)
	await host.get_tree().process_frame
	ui2.start_button.pressed.emit()
	verify.call(ui2.simulation.phase==State.Phase.PAUSED and ui2.simulation.growth.offer==offers and ui2.simulation.enemies[0].pattern.left==1.1 and ui2.combat_audio.played.is_empty(),"Actual scene restore preserves pending choices/windup and does not replay old audio")
	ui2.resume_button.pressed.emit()
	verify.call(ui2.simulation.phase==State.Phase.CHOOSING and ui2.simulation.growth.offer==offers,"Explicit Continue returns to the same choice before resuming curse")
	ui.queue_free()
	ui2.queue_free()
	await host.get_tree().process_frame
