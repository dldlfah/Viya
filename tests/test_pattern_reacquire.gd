extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Revised=preload("res://scripts/combat/enemy_patterns_v2.gd")
const OriginalTests=preload("res://tests/test_enemy_patterns.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const SavedTests=preload("res://tests/test_battle_save_notice.gd")
const Visuals=preload("res://scripts/combat/enemy_pattern_visuals.gd")

static func interrupted():
	var state=OriginalTests.fresh(2)
	OriginalTests.arm(state)
	var origin:Vector2=state.enemies[0].p
	state.add_enemy(origin-Vector2(35,0),"normal","flier")
	state._move_fliers(.05) # Actual existing ground-push path, not a simulated flag.
	state.enemies.remove_at(1) # Isolate the resulting interruption from later flier contact.
	state.step(.05,Vector2.ZERO)
	return state

static func run(host,verify:Callable)->void:
	var state=State.new()
	verify.call(state.start(3901,"viya",null,"prologue_wall","weapons_v1") and state.enemy_pattern_version==2,"The original production start defaults only new campaigns to revision2")
	verify.call(Snapshot.VERSION==17 and Snapshot.fingerprint_for_v16()==Snapshot.GAME038_RULES,"Schema17 retains the exact published16 fingerprint")
	var frozen:String=FileAccess.get_file_as_string("res://scripts/combat/enemy_patterns_v1.gd")
	verify.call(frozen.sha256_text()=="4059f30002b56fa0ccb73ed38b4fe4af9c0fe8092a8f5836ad53f6e3cef5a4af","Published v1 logic is preserved byte for byte")
	var old:Dictionary=state.enemy_patterns.specification(1)
	var current:Dictionary=state.enemy_patterns.specification(2)
	var same:bool=true
	for key in old:same=same and old[key]==current[key]
	verify.call(same and current.reacquire==.3 and current.rearm_delay==.4,"Revision2 retains every completed-swing value and adds only interruption timings")
	current.damage=999
	verify.call(state.enemy_patterns.specification(2).damage==24,"Inspection returns detached configuration and cannot alter real damage")
	for mutation in ["missing","short","long","nan","rearm","boolean"]:
		var bad:Dictionary=state.enemy_patterns.revised.data.duplicate(true)
		match mutation:
			"missing":bad.orc_siege.erase("reacquire")
			"short":bad.orc_siege.reacquire=.01
			"long":bad.orc_siege.reacquire=10
			"nan":bad.orc_siege.reacquire=NAN
			"rearm":bad.orc_siege.rearm_delay=10
			"boolean":bad.orc_siege.rearm_delay=false
		verify.call(not Revised.valid_revision(bad),"Invalid interruption data rejected: "+mutation)
	var before:Dictionary=Snapshot.capture(state)
	state.enemy_patterns.revised.error="fixture"
	verify.call(not state.start(3902,"viya",null,"prologue_wall","weapons_v1") and before==Snapshot.capture(state),"Unavailable revised data rejects a new campaign atomically")
	verify.call(state.enemy_patterns.available(1),"Unavailable revised data does not disable published v1 continuation")
	state.enemy_patterns.revised.error=""
	state=interrupted()
	var enemy:Dictionary=state.enemies[0]
	verify.call(enemy.p!=enemy.pattern.origin and enemy.pattern.phase=="reacquire" and enemy.pattern.left==.3 and state.hp==100,"Actual flier displacement interrupts into a brief damage-free reacquire state")
	var position:Vector2=enemy.p
	OriginalTests.advance(state,.25)
	verify.call(enemy.p==position and enemy.pattern.phase=="reacquire" and state.hp==100,"Reacquisition holds the actor and cannot produce a ghost strike")
	OriginalTests.advance(state,.05)
	verify.call(enemy.pattern.phase=="chase" and enemy.pattern.left==.4,"An interrupted swing gets the separate0.4second rearm delay")
	state.player=enemy.p+Vector2(0,100)
	OriginalTests.advance(state,.4)
	verify.call(enemy.pattern.phase=="windup" and enemy.pattern.left==.9 and enemy.pattern.direction.dot(Vector2.DOWN)>.999,"Reacquired target receives a full new windup using its current direction")
	OriginalTests.advance(state,.85)
	verify.call(state.hp==100,"A rearmed attack still cannot hit before the full advertised windup")
	OriginalTests.advance(state,.05)
	verify.call(state.hp==76 and enemy.pattern.phase=="strike","A genuine rearmed swing applies the original24physical impact once")
	OriginalTests.advance(state,.2)
	verify.call(enemy.pattern.phase=="recovery" and enemy.pattern.left>.6,"Completed impacts still use the original full recovery")
	OriginalTests.advance(state,.8)
	verify.call(enemy.pattern.phase=="chase" and enemy.pattern.left>2.9,"Completed impacts keep the original3second cooldown")
	state=interrupted()
	state.player=state.enemies[0].p+Vector2(20,0)
	OriginalTests.advance(state,.25)
	verify.call(state.hp==100,"Own contact is suppressed during interrupted recovery")
	OriginalTests.advance(state,.05)
	verify.call(state.hp==82,"Original18contact and shared invulnerability resume after reacquisition")
	for revision in [0,1]:
		state=OriginalTests.fresh(revision)
		if revision==1:
			OriginalTests.arm(state)
			state.enemies[0].p+=Vector2(10,0)
			state.step(.05,Vector2.ZERO)
			verify.call(state.enemies[0].pattern.phase=="recovery" and state.enemies[0].pattern.left==.75,"Published v1 retains its old interruption behavior")
		var historical:Dictionary=Snapshot.capture(state)
		historical.version=16
		historical.rules=Snapshot.GAME038_RULES
		var restored=State.new()
		verify.call(Snapshot.restore(historical,restored) and restored.enemy_pattern_version==revision and Campaign.comparable(restored).run.enemies==historical.run.enemies,"Published16 preserves its original rule and all actor fields: "+str(revision))
	state=interrupted()
	var saved:Dictionary=Snapshot.capture(state)
	for mutation in ["scalar","array","null","long","extra","old_rule","old_schema"]:
		var invalid:Dictionary=saved.duplicate(true)
		match mutation:
			"scalar":invalid.run.enemies[0].pattern=5
			"array":invalid.run.enemies[0].pattern=[]
			"null":invalid.run.enemies[0].pattern=null
			"long":invalid.run.enemies[0].pattern.left=.31
			"extra":invalid.run.enemies[0].pattern.extra=true
			"old_rule":invalid.run.enemy_pattern_version=1
			"old_schema":
				invalid.version=16
				invalid.rules=Snapshot.GAME038_RULES
		before=Snapshot.capture(state)
		verify.call(not Snapshot.restore(invalid,state) and before==Snapshot.capture(state),"Malformed revised phase rejects without partial state or parser errors: "+mutation)
	for phase in ["windup","strike","recovery","reacquire"]:
		state=interrupted() if phase=="reacquire" else OriginalTests.fresh(2)
		if phase!="reacquire":OriginalTests.arm(state)
		if phase in ["strike","recovery"]:OriginalTests.advance(state,.9)
		if phase=="recovery":OriginalTests.advance(state,.2)
		saved=Snapshot.capture(state)
		var restored=State.new()
		verify.call(Snapshot.restore(saved,restored),"Revised phase restores: "+phase)
		restored.set_paused(false)
		var equal:=true
		for frame in range(100):
			state.step(.05,Vector2.ZERO)
			restored.step(.05,Vector2.ZERO)
			equal=equal and Campaign.comparable(state)==Campaign.comparable(restored)
		verify.call(equal,"Revised phase preserves100future production steps/sevenRNG: "+phase)
	var folder:="user://reacquire-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var ui=SavedTests.make_ui(host,folder)
	await host.get_tree().process_frame
	Campaign.depart(ui)
	state=ui.simulation
	OriginalTests.quiet(state)
	state.player=Vector2(2500,1700)
	state.add_enemy(state.player-Vector2(100,0),"elite","normal",0,"orc_siege")
	state.enemies[0].pattern.left=0
	ui._physics_process(.05)
	state.enemies[0].p+=Vector2(10,0)
	ui._physics_process(.05)
	verify.call(state.enemy_pattern_version==2 and state.enemies[0].pattern.phase=="reacquire" and ui.view.actors.pose(state,state.enemies[0].id).pose!="attack","Actual scene cancels the stale attack pose for the interrupted swing")
	var plan:Array=Visuals.plan(ui.view)
	verify.call(plan.size()==1 and plan[0].phase=="reacquire" and not plan[0].has("points"),"Cancelled swing has a neutral marker and no damaging sector")
	var left:float=state.enemies[0].pattern.left
	ui._open_mission(state.navigation_ticket,ui._menu_revision)
	for frame in range(20):ui._physics_process(.05)
	verify.call(state.enemies[0].pattern.left==left and Visuals.plan(ui.view).is_empty(),"Existing mission pause freezes/hides revised reacquisition")
	ui.mission_return_button.pressed.emit()
	state.grant_xp(state.growth.threshold())
	ui._sync_phase_ui()
	for frame in range(20):ui._physics_process(.05)
	verify.call(state.enemies[0].pattern.left==left and state.phase==State.Phase.CHOOSING,"Existing choice keeps exact interrupted state and offer frozen")
	ui.choice_buttons[0].pressed.emit()
	var saved_hp:int=ui.simulation.hp # Vitality is a legitimate random choice.
	ui.pause_game()
	var ui2=SavedTests.make_ui(host,folder)
	await host.get_tree().process_frame
	ui2.start_button.pressed.emit()
	verify.call(ui2.simulation.phase==State.Phase.PAUSED and ui2.simulation.enemy_pattern_version==2 and ui2.simulation.enemies[0].pattern.phase=="reacquire" and ui2.simulation.enemies[0].pattern.left==left,"Real binary scene recovery retains the interrupted phase until explicit Continue")
	ui2.resume_button.pressed.emit()
	for frame in range(6):ui2._physics_process(.05)
	verify.call(ui2.simulation.enemies[0].pattern.phase=="chase" and ui2.simulation.hp==saved_hp,"Continue completes only remaining interrupted recovery without an old hit")
	ui.queue_free()
	ui2.queue_free()
	await host.get_tree().process_frame
