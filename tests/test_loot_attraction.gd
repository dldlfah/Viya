extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Supplies=preload("res://tests/test_supplies.gd")
const Store=preload("res://scripts/progression/run_store.gd")
const Wallet=preload("res://scripts/progression/gold_progress.gd")

static func fresh(mode:String="campaign",version:int=1):
	var state=State.new()
	state.start(5101,"viya",null,"siege_battlefield" if mode=="campaign" else "gold_slime","weapons_v1",{},mode,-1 if mode=="campaign" else 20000,-1,-1,2 if mode=="campaign" else 0,version)
	state.spawn_clock=999;state.shot_clock=999;state._scatter_clock=999;state._swarm_clock=999
	return state

static func choose(state):
	while state.phase==State.Phase.CHOOSING:
		state.select_skill(state.growth.offer[0],state.growth.ticket)

static func floor_gold(state)->int:
	var value:=0
	for pickup in state.gold_pickups:value+=int(pickup.value)
	return value

static func run(_host,verify:Callable):
	var state=fresh()
	state.gold_collected=77
	state.add_pickup(Vector2(4900,3100),90)
	state.add_pickup(Vector2(100,500),60)
	state.gold_pickups.assign([{"p":Vector2(4900,500),"value":123},{"p":Vector2(100,3100),"value":456}])
	var item:Dictionary=Supplies.drop(state,"magnet")
	var other:Dictionary=Supplies.drop(state,"mp")
	item.p=state.player
	var before_rng:Array=Snapshot.capture(state).rng
	state._collect_pickups(0)
	verify.call(state.loot_rules_version==1 and state.gold_collected==77 and state.growth.level==1 and state.phase==State.Phase.RUNNING,"New magnet leaves money and XP uncredited until actual arrival")
	verify.call(state.pickups.all(func(p):return p.get("magnet")==true) and state.gold_pickups.all(func(p):return p.get("magnet")==true),"Every distant gem and coin on the entire map is marked for attraction")
	verify.call(state.item_pickups.size()==1 and state.item_pickups[0].id==other.id,"Magnet consumes its own item once and leaves other supplies untouched")
	verify.call(Snapshot.capture(state).rng==before_rng and state.cues.events[-1].label.contains("4개 끌어오는 중"),"Activation uses no random draws and reports attraction rather than invented rewards")
	var old_pos:Vector2=state.pickups[0].p
	state.player+=Vector2(80,40)
	state._collect_pickups(.05)
	verify.call(state.pickups[0].p.distance_to(state.player)<old_pos.distance_to(state.player) and state.pickups[0].p!=state.player,"Far pickup visibly travels toward the hero's current position across terrain")
	var total:int=floor_gold(state)+state.gold_collected
	state._apply_supply("magnet")
	verify.call(floor_gold(state)+state.gold_collected==total and state.gold_pickups.size()==2,"Repeated magnet activation cannot duplicate, remove or pre-credit a flying coin")
	state.set_paused(true)
	var frozen:Dictionary=Snapshot.capture(state)
	state.step(.05,Vector2.RIGHT)
	verify.call(Snapshot.capture(state)==frozen,"Pause freezes attraction and all rewards")
	var store=Store.new();store.path="user://magnet-"+Crypto.new().generate_random_bytes(8).hex_encode()+".save"
	verify.call(Snapshot.valid(frozen,state) and store.save_current(state)==OK,"Midflight pickups and amounts pass the strict validator and atomic disk save")
	var restored=State.new()
	verify.call(store.load_saved(restored)==OK and Snapshot.restore(store.pending,restored) and restored.phase==State.Phase.PAUSED and Campaign.comparable(restored)==Campaign.comparable(state),"Disk restore retains every flight position/flag/value and seven RNG streams; explicit Continue required")
	state.set_paused(false);restored.set_paused(false)
	var equal:=true
	var saw_choice:=false
	for index in range(180):
		if state.phase==State.Phase.CHOOSING:
			saw_choice=true
			var choice:Dictionary=Snapshot.capture(state)
			state.step(.05,Vector2.ZERO)
			equal=equal and Snapshot.capture(state)==choice
		choose(state);choose(restored)
		state._collect_pickups(.05);restored._collect_pickups(.05)
		equal=equal and Campaign.comparable(state)==Campaign.comparable(restored)
	verify.call(equal and saw_choice,"Midflight restore has identical arrival/XP choices without rerolls; choosing freezes remaining flights")
	verify.call(state.gold_collected==656 and state.gold_pickups.is_empty() and state.pickups.is_empty() and state.growth.level>1,"All marked resources reach the hero once with their original amounts and real growth")
	var collected:int=state.gold_collected
	state._collect_pickups(.05);state._apply_supply("magnet")
	verify.call(state.gold_collected==collected,"Empty and already-consumed magnet paths cannot award the same gold twice")
	state.add_pickup(Vector2(100,3100))
	state.gold_pickups.append({"p":Vector2(4900,500),"value":7})
	state._collect_pickups(.05)
	verify.call(not state.pickups[0].has("magnet") and state.gold_pickups[0].p==Vector2(4900,500),"Drops created after the magnet retain ordinary pickup range")
	# Reject damaged flags/rule versions without touching the active run.
	var valid:Dictionary=Snapshot.capture(restored)
	for bad_value in [false,1,"true",INF]:
		var bad:Dictionary=valid.duplicate(true)
		bad.run.gold_pickups=[{"p":state.player,"value":10,"magnet":bad_value}]
		var unchanged:Dictionary=Campaign.comparable(restored)
		verify.call(not Snapshot.restore(bad,restored) and Campaign.comparable(restored)==unchanged,"Reject corrupt magnetic flag without mutation: "+str(bad_value))
	for bad_value in [-1,2,1.0,"1"]:
		var bad:Dictionary=valid.duplicate(true);bad.run.loot_rules_version=bad_value
		verify.call(not Snapshot.restore(bad,restored),"Reject unsupported/incorrectly typed loot rules: "+str(bad_value))
	# Existing public21 saves keep old instant magnet and future roll amounts.
	var legacy=fresh("campaign",0)
	legacy.gold_pickups.append({"p":Vector2(4900,500),"value":31})
	var published:Dictionary=Snapshot.capture(legacy)
	published.version=21;published.rules=Snapshot.GAME050_RULES;published.run.erase("loot_rules_version")
	verify.call(Snapshot.fingerprint_for_v21()==Snapshot.GAME050_RULES and Snapshot.restore(published,restored) and restored.loot_rules_version==0 and restored.gold_drop_range()==Vector2i(10,50),"Published21 fingerprint, amounts and legacy rules migrate exactly to22")
	restored.set_paused(false);restored._apply_supply("magnet")
	verify.call(restored.gold_collected==31 and restored.gold_pickups.is_empty(),"A continued public21 run keeps its original instant magnet without reward replay")
	published.run.loot_rules_version=1
	verify.call(not Snapshot.restore(published,restored),"Old-schema forgery cannot opt into new reward/magnet rules")
	# Same kills/chance/raw rolls; each positive raw amount floors to half.
	for mode in ["campaign","gold_slime"]:
		var newer=fresh(mode,1);var older=fresh(mode,0)
		var amounts:=true
		var chances:=true
		var expected:=0
		for index in range(600):
			newer.gold_pickups.clear();older.gold_pickups.clear()
			var kind:String=["normal","elite","boss"][index%3] if mode=="campaign" else "normal"
			newer._drop_gold(newer.player,kind);older._drop_gold(older.player,kind)
			var raw:int=floor_gold(older)
			amounts=amounts and floor_gold(newer)==raw / 2
			chances=chances and newer.gold_pickups.size()==older.gold_pickups.size()
			expected+=floor_gold(newer)
		verify.call(amounts and chances and expected>0 and Snapshot.capture(newer).rng==Snapshot.capture(older).rng,"600 same raw rolls keep chance and all seven RNG streams, flooring each amount to50percent: "+mode)
		verify.call(newer.gold_drop_range()==(Vector2i(5,25) if mode=="campaign" else Vector2i(11,55)) and newer.gold_drop_range("elite")==Vector2i(50,500),"Displayed normal and elite/boss ranges reflect the new amounts: "+mode)
	# Expiring runs settle airborne coins once; defeat/leave never pay them.
	state=fresh();state.gold_collected=11;state.gold_pickups.append({"p":Vector2(4900,500),"value":89,"magnet":true})
	state.elapsed=360;state.checkpoint_index=2;state._boss_spawned=true;state._boss_defeated=true;state._elites_spawned=4
	state._clear_stage()
	var summary:Dictionary=state.result_summary()
	verify.call(summary.gold_collected==100 and summary.gold_bonus==100 and summary.gold_reward==200 and state.gold_pickups.is_empty(),"Clear sweeps still-flying gold once and retains the fixed100clear reward")
	var wallet=Wallet.new();wallet.path=store.path+".cfg";wallet.load_progress()
	verify.call(wallet.settle(summary)==OK and wallet.total==200 and wallet.settle(summary)==OK and wallet.total==200,"Clear payment remains atomic and idempotent after magnetic collection")
	for outcome in ["defeat","abandoned"]:
		state=fresh();state.gold_pickups.append({"p":state.player,"value":100,"magnet":true});state._finish_run(outcome)
		verify.call(state.result_summary().gold_reward==0,"Unfinished attraction never bypasses zero reward on "+outcome)
	# Bounded population: the actual pickup pool handles at most480 marks/strokes.
	state=fresh()
	for index in range(State.MAX_PICKUPS):
		state.add_pickup(Vector2(50+index*19,500),5)
		state.gold_pickups.append({"p":Vector2(50+index*19,3100),"value":1})
	state._apply_supply("magnet")
	verify.call(state.pickups.size()==240 and state.gold_pickups.size()==240 and Snapshot.valid(Snapshot.capture(state),state),"Maximum480 pooled pickups can be marked and saved without extra actors/effect queues")
	DirAccess.remove_absolute(store.path);DirAccess.remove_absolute(wallet.path)
