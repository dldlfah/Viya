extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Before=preload("res://tests/fixtures/savefix001/flier_before.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Store=preload("res://scripts/progression/run_store.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Perf=preload("res://tests/test_combat_performance.gd")

static func quiet():
	var state=State.new()
	state.start(2867,"viya",null,"siege_battlefield","weapons_v1")
	state.player=Vector2(2500,1700)
	state.spawn_clock=999;state.shot_clock=999;state._scatter_clock=999;state._swarm_clock=999
	return state

static func flier(state,life:float=5.0) -> Dictionary:
	state.add_enemy(state.player+Vector2(700,0),"normal","flier")
	var actor:Dictionary=state.enemies[-1]
	actor.life=life;actor.velocity=Vector2.RIGHT*360
	return actor

static func run(host,verify:Callable) -> void:
	for fps in [20,60,120]:
		var state=quiet();flier(state)
		var before_rng:Array=Snapshot.capture(state).rng
		for step in range(fps*5):state.step(1.0/fps,Vector2.ZERO)
		verify.call(state.enemies.is_empty() and state.kills==0 and state.gold_collected==0 and state.pickups.is_empty() and state.gold_pickups.is_empty(),"Nominal5second expiry at%dHz gives no kill,XP,gold or extra live frame"%fps)
		verify.call(Snapshot.valid(Snapshot.capture(state),state) and Snapshot.capture(state).rng==before_rng,"Expiry yields a strict valid save and consumes no seven-stream RNG at%dHz"%fps)
	for remainder in [.99e-6,1e-6,1.01e-6]:
		var state=quiet();flier(state,.05+remainder)
		state._move_fliers(.05)
		verify.call(state.enemies.size()==(0 if remainder<1e-6 else 1) and Snapshot.valid(Snapshot.capture(state),state),"Only below-minimum lifetime expires;the existing live1microsecond boundary survives:"+str(remainder))
	var state=quiet();var moving:Dictionary=flier(state,.05+1e-14)
	var ground:Vector2=moving.p+Vector2(15,0)
	state.add_enemy(ground)
	state._move_fliers(.05)
	verify.call(state.enemies.size()==1 and state.enemies[0].p==ground,"A just-expired flier cannot push ground actors in a ghost final update")
	state=quiet();flier(state,.05+1e-14)
	state.set_paused(true);var frozen:Dictionary=Snapshot.capture(state)
	state.step(.05,Vector2.RIGHT)
	verify.call(Snapshot.capture(state)==frozen,"Paused play freezes even a near-expiry flier without expiry side effects")
	state.set_paused(false);state.step(.05,Vector2.ZERO)
	verify.call(state.enemies.is_empty() and Snapshot.valid(Snapshot.capture(state),state),"Resuming performs the expiry before any saved running frame")
	state=quiet();flier(state,1e-14)
	var bad:Dictionary=Snapshot.capture(state);var receiver=quiet();var original:Dictionary=Snapshot.capture(receiver)
	verify.call(not Snapshot.valid(bad,state) and not Snapshot.restore(bad,receiver) and Snapshot.capture(receiver)==original,"A forged submicrosecond live actor still fails strict validation and cannot mutate the receiving run")
	# Frozen original and current runtime, identical actual1540capture/actions.
	var base:String="res://tests/fixtures/game050_v21/fly1540.bin"
	var data:Dictionary=FileAccess.open(base,FileAccess.READ).get_var(false)
	var actions:Array=FileAccess.open(base.get_basename()+"_actions.bin",FileAccess.READ).get_var(false)
	var legacy=Before.new();state=State.new()
	verify.call(Snapshot.restore(data,legacy) and Snapshot.restore(data,state),"Load the original dense flight into both actual lifetime implementations")
	legacy.set_paused(false);state.set_paused(false)
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/game050_v21/baseline.json"))
	var row:Dictionary=manifest.records.filter(func(item):return item.tag=="fly1540")[0]
	var original_all:bool=Perf.digest(legacy)==row.hashes101[0]
	var same_before_expiry:bool=true;var same_rng:bool=true
	for index in range(actions.size()):
		var action:Dictionary=actions[index]
		for current in [legacy,state]:
			if not action.skill.is_empty():current.select_skill(action.skill,current.growth.ticket)
			if action.cast:current.cast_ultimate(current.magic.ticket)
			current.step(.05,action.move)
		original_all=original_all and Perf.digest(legacy)==row.hashes101[index+1]
		same_rng=same_rng and Snapshot.capture(legacy).rng==Snapshot.capture(state).rng
		if index<99:same_before_expiry=same_before_expiry and Campaign.comparable(state)==Campaign.comparable(legacy)
	verify.call(original_all and same_before_expiry and same_rng,"Original101goldens remain intact,first100states and every7RNG value agree up to nominal expiry")
	var expected:Dictionary=Campaign.comparable(legacy)
	var removed:Array=expected.run.enemies.filter(func(actor):return actor.variant=="flier" and actor.life<.000001)
	expected.run.enemies=expected.run.enemies.filter(func(actor):return actor.variant!="flier" or actor.life>=.000001)
	var changed_positions:int=0
	var only_ground_positions:bool=true
	var same_actor_fields:bool=true
	var changed_hp:int=0
	var expected_hit:bool=true
	for actor in expected.run.enemies:
		var current:Dictionary=state.enemies.filter(func(item):return item.id==actor.id)[0]
		if actor.p!=current.p:
			changed_positions+=1
			only_ground_positions=only_ground_positions and actor.variant!="flier"
		var old_fields:Dictionary=actor.duplicate(true);old_fields.erase("p")
		var new_fields:Dictionary=current.duplicate(true);new_fields.erase("p")
		if old_fields.hp!=new_fields.hp:
			changed_hp+=1
			expected_hit=expected_hit and actor.id==1076 and actor.variant=="heavy" and old_fields.hp==59 and new_fields.hp==46
			old_fields.hp=new_fields.hp
		same_actor_fields=same_actor_fields and old_fields==new_fields
	var actual:Dictionary=Campaign.comparable(state)
	expected.run.erase("enemies");actual.run.erase("enemies")
	verify.call(removed.size()==187 and removed.all(func(actor):return actor.life>0) and changed_positions==167 and only_ground_positions and changed_hp==1 and expected_hit and same_actor_fields and actual==expected and Perf.digest(state)==Perf.FIXED_FLIER_FINAL,"The reviewed endpoint differs only by187expired fliers,167ground positions without ghost pushes and the resulting13damage on heavy1076;every other field and the full corrected golden hash are exact")
	verify.call(not Snapshot.valid(Snapshot.capture(legacy),legacy) and Snapshot.valid(Snapshot.capture(state),state),"Original expiry failure is reproduced while the corrected endpoint passes the unchanged validator")
	# Actual pause/disk/restart/Continue through the production scene.
	var folder:String="user://flier-expiry-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	var ui=Campaign.make_ui(host,folder);Campaign.depart(ui)
	state=ui.simulation;state.player=Vector2(2500,1700);state.enemies.clear();state.bullets.clear()
	state.spawn_clock=999;state.shot_clock=999;state._scatter_clock=999;state._swarm_clock=999
	flier(state,.05+1e-14);ui._physics_process(.05);ui.pause_game()
	verify.call(state.enemies.is_empty() and state.phase==state.Phase.PAUSED and ui.battle_save_error==OK,"Real F5 loop expires the flier and persists the paused battle without save-error lock")
	var disk=Store.new();disk.path=ui.run_store.path;var resumed=State.new()
	verify.call(disk.load_saved(resumed)==OK and Snapshot.restore(disk.pending,resumed) and Campaign.comparable(resumed)==Campaign.comparable(state),"A new disk reader restores the exact paused battle after expiry")
	ui.resume_game();verify.call(state.phase==state.Phase.RUNNING and ui.movement.enabled,"The real Continue button path unfreezes movement after the saved expiry")
	flier(state,.23);ui._physics_process(.05);ui.pause_game()
	verify.call(disk.load_saved(resumed)==OK and Snapshot.restore(disk.pending,resumed) and Campaign.comparable(resumed)==Campaign.comparable(state) and resumed.enemies.size()==1,"A live flier retains exact life,velocity,HP and position through disk Continue")
	ui.resume_game();resumed.set_paused(false)
	var equal:bool=true
	for index in range(10):
		state.step(.02,Vector2.ZERO);resumed.step(.02,Vector2.ZERO)
		equal=equal and Campaign.comparable(state)==Campaign.comparable(resumed)
	verify.call(equal and state.enemies.is_empty() and state.kills==0,"Original and resumed live flier expire on the same step without reward duplication")
	ui.queue_free();await host.get_tree().process_frame
	for file in ["ui.save","gold.cfg","settings.cfg"]:DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
