extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Patterns=preload("res://scripts/combat/enemy_patterns.gd")
const Visuals=preload("res://scripts/combat/enemy_pattern_visuals.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const SavedTests=preload("res://tests/test_battle_save_notice.gd")

static func quiet(state) -> void:
	state.spawn_clock=999
	state.shot_clock=999
	state._scatter_clock=999
	state._swarm_clock=999

static func fresh(version:int=1):
	var state=State.new()
	state.start(3801,"viya",null,"prologue_wall","weapons_v1",{},"campaign",-1,-1,version)
	state.player=Vector2(2500,1700)
	quiet(state)
	state.add_enemy(state.player-Vector2(100,0),"elite","normal",0,"orc_siege")
	return state

static func arm(state) -> void:
	state.enemies[0].pattern.left=0.0
	state.step(.05,Vector2.ZERO)

static func advance(state,seconds:float,direction:Vector2=Vector2.ZERO) -> void:
	for frame in range(ceili(seconds/.05)):state.step(minf(.05,seconds-frame*.05),direction)

static func run(host,verify:Callable)->void:
	var state=fresh()
	verify.call(Snapshot.VERSION==17 and Snapshot.fingerprint_for_v15()==Snapshot.GAME023_RULES,"Explicit v17 pattern schema retains the exact published v15 fingerprint")
	verify.call(state.enemy_pattern_version==1 and state.enemies[0].has("pattern") and state.enemies[0].hp==1600 and state.enemies[0].speed==45 and state.enemies[0].contact_damage==18,"Explicit v1 campaign attaches only the pattern while preserving locked elite stats")
	for mutation in ["missing","fractional","negative","nan","short","angle","range","schema"]:
		var data:Dictionary=state.enemy_patterns.data.duplicate(true)
		match mutation:
			"missing":data.orc_siege.erase("windup")
			"fractional":data.orc_siege.damage=24.5
			"negative":data.orc_siege.cooldown=-1
			"nan":data.orc_siege.reach=NAN
			"short":data.orc_siege.windup=.01
			"angle":data.orc_siege.half_angle_degrees=181
			"range":data.orc_siege.trigger_range=999
			"schema":data.schema_version=999
		verify.call(not Patterns.valid_data(data),"Invalid pattern catalog rejected: "+mutation)
	var before:Dictionary=Snapshot.capture(state)
	state.enemy_patterns.error="fixture"
	verify.call(not state.start(3802,"viya",null,"prologue_wall","weapons_v1") and before==Snapshot.capture(state),"Invalid pattern data rejects new campaign before IDs/resources/RNG are changed")
	state.enemy_patterns.error=""
	state.add_enemy(state.player+Vector2(300,0),"elite","normal",0,"demon_shaman")
	state.add_enemy(state.player+Vector2(300,0))
	verify.call(not state.enemies[1].has("pattern") and not state.enemies[2].has("pattern"),"Other elite species and ordinary actors do not inherit the hammer AI")
	state=fresh(0)
	verify.call(not state.enemies[0].has("pattern"),"Explicit old-rule campaigns keep original living and future AI")
	state=fresh()
	arm(state)
	var enemy:Dictionary=state.enemies[0]
	var origin:Vector2=enemy.p
	verify.call(enemy.pattern.phase=="windup" and enemy.pattern.left==.9 and state.hp==100,"Actual production step starts a full0.9second windup without early damage")
	var locked:Vector2=enemy.pattern.direction
	state.player=origin+Vector2(0,100)
	advance(state,.45)
	verify.call(enemy.p==origin and enemy.pattern.direction==locked and state.hp==100,"Windup fixes origin/facing and stops pursuit instead of tracking a dodging player")
	advance(state,.45)
	verify.call(enemy.pattern.phase=="strike" and state.hp==100,"Moving outside the advertised sector actually avoids the strike")
	state.player=origin+Vector2(90,0)
	advance(state,.1)
	verify.call(state.hp==100,"Entering an already consumed strike window cannot take delayed damage")
	advance(state,.1)
	verify.call(enemy.pattern.phase=="recovery" and enemy.p==origin,"Strike leads into stationary recovery")
	advance(state,.8)
	verify.call(enemy.pattern.phase=="chase" and enemy.pattern.left>2.8,"Recovery returns to chase with a separate cooldown")
	var old:Vector2=enemy.p
	state.step(.05,Vector2.ZERO)
	verify.call(enemy.p!=old,"The original terrain-aware pursuit resumes after recovery")
	# A stationary victim takes one defended physical hit with exact melee source.
	state=fresh()
	arm(state)
	advance(state,.9)
	verify.call(state.hp==76 and state.cues.latest_received().kind=="melee" and state.cues.latest_received().id==state.enemies[0].id,"A real hammer impact deals one24physical hit and records its actual attacking ID")
	advance(state,.7)
	verify.call(state.hp==76,"Strike and recovery cannot repeat hammer or own contact damage")
	state=fresh()
	state.player=state.enemies[0].p+Vector2(20,0)
	arm(state)
	advance(state,.6)
	verify.call(state.hp==100,"Close overlapping contact is suppressed throughout the readable windup")
	advance(state,.3)
	verify.call(state.hp==76,"Close victim receives only the one hammer hit at the strike boundary")
	state=fresh()
	arm(state)
	state.stats.physical_defense=100.0
	advance(state,.9)
	var damage:int=maxi(1,ceili(state.DefenseRules.mitigated_damage(24,100,0)))
	verify.call(state.hp==100-damage,"Hammer uses the original physical defense calculation")
	state=fresh()
	arm(state)
	state.hurt_clock=2.0
	advance(state,.9)
	verify.call(state.hp==100,"Existing invulnerability rejects the single impact attempt")
	state.hurt_clock=0
	advance(state,.1)
	verify.call(state.hp==100,"Rejected impact is consumed rather than retried when invulnerability ends")
	state=fresh()
	arm(state)
	state.map_space.solids.append(Rect2(state.enemies[0].p+Vector2(40,-80),Vector2(15,160)))
	advance(state,.9)
	verify.call(state.hp==100,"Real map wall tracing blocks hammer damage through terrain")
	state=fresh()
	state.map_space.solids.append(Rect2(state.enemies[0].p+Vector2(40,-80),Vector2(15,160)))
	arm(state)
	verify.call(state.enemies[0].pattern.phase=="chase","An obstructed target cannot arm a swing through a wall")
	state=fresh()
	arm(state)
	state.enemies[0].p+=Vector2(10,0)
	state.step(.05,Vector2.ZERO)
	verify.call(state.enemies[0].pattern.phase=="recovery" and state.hp==100,"External formation displacement cancels a windup instead of moving its advertised hit area")
	state=fresh()
	arm(state)
	state._damage_enemy(state.enemies[0].id,100000)
	var kills:int=state.kills
	advance(state,1.5)
	verify.call(state.enemies.is_empty() and state.hp==100 and state.kills==kills and state.pickups.size()==1,"Killing the windup actor cancels its swing and retains one original death/XP reward")
	for terminal in ["defeat","abandoned","cleared"]:
		state=fresh()
		arm(state)
		state._finish_run(terminal)
		before=Snapshot.capture(state)
		advance(state,2)
		verify.call(before==Snapshot.capture(state),"Terminal state freezes all pending attacks: "+terminal)
	# Exact disk state must retain every phase and reject malformed attacks atomically.
	for phase in ["windup","strike","recovery"]:
		state=fresh()
		arm(state)
		if phase!="windup":advance(state,.9)
		if phase=="recovery":advance(state,.2)
		state.set_paused(true)
		var saved:Dictionary=Snapshot.capture(state)
		var copy=State.new()
		verify.call(Snapshot.valid(saved,state) and Snapshot.restore(saved,copy) and Campaign.comparable(state)==Campaign.comparable(copy),"Exact saved pattern phase and resources restore: "+phase)
		copy.set_paused(false)
		state.set_paused(false)
		var same:=true
		for frame in range(100):
			state.step(.05,Vector2.ZERO)
			copy.step(.05,Vector2.ZERO)
			same=same and Campaign.comparable(state)==Campaign.comparable(copy)
		verify.call(same,"Restored phase preserves100future steps/sevenRNG and single-impact semantics: "+phase)
	state=fresh()
	arm(state)
	var valid:Dictionary=Snapshot.capture(state)
	for mutation in ["version","missing","phase","timer","direction","origin","extra","species","mode"]:
		var bad:Dictionary=valid.duplicate(true)
		match mutation:
			"version":bad.run.enemy_pattern_version=3
			"missing":bad.run.enemies[0].erase("pattern")
			"phase":bad.run.enemies[0].pattern.phase="again"
			"timer":bad.run.enemies[0].pattern.left=INF
			"direction":bad.run.enemies[0].pattern.direction=Vector2.ZERO
			"origin":bad.run.enemies[0].pattern.origin=Vector2(NAN,0)
			"extra":bad.run.enemies[0].pattern.repeat=true
			"species":bad.run.enemy_pattern_version=0
			"mode":bad.run.run_mode="gold_slime"
		before=Snapshot.capture(state)
		verify.call(not Snapshot.restore(bad,state) and before==Snapshot.capture(state),"Corrupt pattern rejects before partial restore: "+mutation)
	state=fresh(0)
	var legacy:Dictionary=Snapshot.capture(state)
	legacy.version=15
	legacy.rules=Snapshot.GAME023_RULES
	legacy.run.erase("enemy_pattern_version")
	var restored=State.new()
	verify.call(Snapshot.restore(legacy,restored) and restored.enemy_pattern_version==0 and not restored.enemies[0].has("pattern"),"Published15 battle migrates without retroactive attack AI")
	restored.add_enemy(restored.player+Vector2(300,0),"elite","normal",0,"orc_siege")
	verify.call(not restored.enemies[-1].has("pattern"),"Future orcs in a migrated old battle also retain their original AI")
	# Actual scene + shared renderer/mission/choice paths and saved windup.
	var folder:="user://hammer-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var ui=SavedTests.make_ui(host,folder)
	await host.get_tree().process_frame
	Campaign.depart(ui)
	state=ui.simulation
	quiet(state)
	state.player=Vector2(2500,1700)
	state.add_enemy(state.player-Vector2(100,0),"elite","normal",0,"orc_siege")
	state.enemies[0].pattern.left=0.0
	ui._physics_process(.05)
	var plan:Array=Visuals.plan(ui.view)
	before=Snapshot.capture(state)
	for high in [true,false]:
		ui.view.high_angle=high
		var a:Array=Visuals.plan(ui.view)
		var point:Vector2=ui.view.screen_to_world(a[0].points[1])
		verify.call(a.size()==1 and point.is_equal_approx(state.enemies[0].pattern.origin+state.enemies[0].pattern.direction.rotated(-deg_to_rad(55))*150),"Both renderers project the same fixed actual sector geometry: "+str(high))
		for index in range(20):Visuals.plan(ui.view)
	verify.call(before==Snapshot.capture(state),"Repeated shared telegraph planning changes no saved state or RNG")
	ui._open_mission(state.navigation_ticket,ui._menu_revision)
	var left:float=state.enemies[0].pattern.left
	for frame in range(30):ui._physics_process(.05)
	verify.call(state.enemies[0].pattern.left==left and Visuals.plan(ui.view).is_empty(),"Original mission pause freezes and hides the authoritative windup")
	ui.mission_return_button.pressed.emit()
	state.grant_xp(state.growth.threshold())
	ui._sync_phase_ui()
	for frame in range(30):ui._physics_process(.05)
	verify.call(state.enemies[0].pattern.left==left and state.phase==State.Phase.CHOOSING,"Original level choice freezes windup and its selected offer")
	ui.choice_buttons[0].pressed.emit()
	# The selected upgrade may increase HP or knock back the enemy. Compare the
	# same selected battle rather than assuming every random offer leaves HP100.
	var uninterrupted=State.new()
	Snapshot.restore(Snapshot.capture(state),uninterrupted)
	uninterrupted.set_paused(false)
	ui.pause_game()
	var ui2=SavedTests.make_ui(host,folder)
	await host.get_tree().process_frame
	ui2.start_button.pressed.emit()
	verify.call(ui2.simulation.phase==State.Phase.PAUSED and ui2.simulation.enemies[0].pattern.left==left,"Actual binary scene restore waits for Continue with exact pending windup")
	ui2.resume_button.pressed.emit()
	uninterrupted.spawn_view_size=ui2.simulation.spawn_view_size
	for frame in range(18):
		uninterrupted.step(.05,Vector2.ZERO)
		ui2._physics_process(.05)
	verify.call(Campaign.comparable(ui2.simulation)==Campaign.comparable(uninterrupted),"Explicit UI Continue matches the selected upgrade and uninterrupted attack without duplicate impact")
	state=State.new()
	state.start(3802,"viya",null,"gold_slime","weapons_v1",{},"gold_slime",20000)
	state._spawn_enemy()
	verify.call(state.enemy_pattern_version==0 and not state.enemies[0].has("pattern"),"Dungeon initial admission and slime AI remain free of campaign patterns")
	ui.queue_free()
	ui2.queue_free()
	await host.get_tree().process_frame
