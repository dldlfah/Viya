extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Dungeon=preload("res://scripts/combat/gold_dungeon.gd")
const Checks=preload("res://tests/test_gold_dungeon.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Wallet=preload("res://scripts/progression/gold_progress.gd")
static func fresh():
	var state=Checks.fresh()
	state.gold_reward_version=1
	return state
static func gold_on_floor(state)->int:
	var total:=0
	for pickup in state.gold_pickups:total+=int(pickup.value)
	return total
static func run(_host,verify:Callable)->void:
	var state=State.new()
	verify.call(state.start(2021,"viya",null,"gold_slime","weapons_v1",{},"gold_slime",20000) and state.gold_reward_version==1 and state.gold_drop_range()==Vector2i(22,110),"New dungeon uses22-110gold per kill,not a fixed100k bonus")
	verify.call(state.stage_duration==180 and state.stage_clear_gold==0 and state.growth.pacing_version==1 and state.hp==100 and state.magic.mana==100 and state.dungeon.data.daily_entries==2,"Reward revision retains3minutes,daily2,HP/MP and growth")
	var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Dungeon.REWARD_PATH))
	for key in ["reversed","fractional","missing","infinite"]:
		var bad:Dictionary=config.duplicate(true)
		match key:
			"reversed":bad.gold_slime.minimum=111.0
			"fractional":bad.gold_slime.maximum=110.5
			"missing":bad.gold_slime.erase("minimum")
			"infinite":bad.gold_slime.minimum=INF
		verify.call(not Dungeon.valid_rewards(bad),"Invalid reward data blocked: "+key)
	var expected_rng:=RandomNumberGenerator.new()
	expected_rng.seed=state.gold_rng.seed
	expected_rng.state=state.gold_rng.state
	var expected:=0
	var within:=true
	for index in range(500):
		var before:=gold_on_floor(state)
		state.add_enemy(state.player+Vector2(50,0))
		state._damage_enemy(int(state.enemies[-1].id),10000)
		var delta:=gold_on_floor(state)-before
		within=within and delta>=22 and delta<=110
		expected+=expected_rng.randi_range(22,110)
	verify.call(within and state.kills==500 and gold_on_floor(state)==expected and state.gold_rng.state==expected_rng.state and state.gold_pickups.size()<=State.MAX_PICKUPS,"500actual kills preserve exact22-110rolls and total across pickup pooling")
	var before_rng:Array=Snapshot.capture(state).rng
	state._drop_gold(state.player,"normal")
	var after_rng:Array=Snapshot.capture(state).rng
	var isolated:=true
	for index in [0,1,3,4,5,6]:isolated=isolated and before_rng[index]==after_rng[index]
	verify.call(isolated and before_rng[2]!=after_rng[2],"Gold roll consumes only the existing gold RNG,never growth or combat streams")
	state.set_paused(true)
	var current:Dictionary=Snapshot.capture(state)
	var copy=State.new()
	verify.call(Snapshot.restore(current,copy) and copy.gold_reward_version==1 and Campaign.comparable(copy)==Campaign.comparable(state),"Current reward version and exact uncollected gold survive save/restore")
	state._drop_gold(state.player,"normal")
	copy._drop_gold(copy.player,"normal")
	verify.call(Campaign.comparable(copy)==Campaign.comparable(state),"Next resumed gold roll matches uninterrupted play")
	var old=fresh()
	old.hp=61
	old.magic.mana=33.25
	old.gold_collected=777
	old._drop_gold(old.player,"normal")
	old.gold_pickups[0].value=31
	var published:Dictionary=Snapshot.capture(old)
	published.version=14
	published.rules=Snapshot.GAME022_RULES
	published.run.erase("gold_reward_version")
	verify.call(Snapshot.restore(published,copy) and copy.gold_reward_version==0 and copy.growth.pacing_version==1 and copy.hp==61 and copy.magic.mana==33.25 and copy.gold_collected==777 and gold_on_floor(copy)==31 and copy.gold_drop_range()==Vector2i(10,50),"Published14keeps its pacing/resources/coins and original10-50future drops")
	for key in ["unknown","missing","campaign"]:
		var invalid:Dictionary=current.duplicate(true)
		match key:
			"unknown":invalid.run.gold_reward_version=2
			"missing":invalid.run.erase("gold_reward_version")
			"campaign":invalid.run.run_mode="campaign"
		var frozen:Dictionary=Campaign.comparable(copy)
		verify.call(not Snapshot.restore(invalid,copy) and Campaign.comparable(copy)==frozen,"Malformed reward save rejected without mutation: "+key)
	var campaign=State.new()
	campaign.start(2021)
	verify.call(campaign.gold_reward_version==0 and campaign.gold_drop_range()==Vector2i(10,50) and campaign.gold_drop_range("elite")==Vector2i(100,1000) and campaign.gold_drop_range("boss")==Vector2i(100,1000),"Campaign normal/elite/boss ranges are unchanged")
	var wallet=Wallet.new()
	wallet.path="user://reward-test-"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg"
	wallet.load_progress()
	state=fresh()
	verify.call(wallet.admit_dungeon(Snapshot.capture(state),20000*86400-32400+100)==OK,"New reward profile enters through durable daily ledger")
	for index in range(1600):state._drop_gold(state.player,"normal")
	expected=gold_on_floor(state)
	var result:Dictionary=Checks.finish(state)
	verify.call(expected>100000 and result.gold_reward==expected and wallet.finish_dungeon(result)==OK and wallet.total==expected and wallet.next_stage==1,"Large earned payout credits exactly once with no clear bonus or campaign unlock")
	verify.call(wallet.finish_dungeon(result)==OK and wallet.total==expected,"Repeated100k settlement cannot duplicate reward")
	for outcome in ["abandoned","defeat"]:
		state=fresh()
		state.dungeon_day=20001
		wallet.admit_dungeon(Snapshot.capture(state),20001*86400-32400+100)
		state.gold_collected=100000
		state._finish_run(outcome)
		verify.call(wallet.finish_dungeon(state.result_summary())==OK and wallet.total==expected,"No100k payout on "+outcome)
	DirAccess.remove_absolute(wallet.path)
