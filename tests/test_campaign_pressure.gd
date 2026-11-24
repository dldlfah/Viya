extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Rewards=preload("res://tests/test_campaign_encounters.gd")
const Pressure=preload("res://scripts/combat/campaign_pressure.gd")
const MANIFEST:="res://tests/fixtures/game048_v19/baseline.json"
static func fresh(policy:int=2):
	var state=State.new()
	state.start(4801,"viya",null,"prologue_wall","weapons_v1",{},"campaign",-1,-1,-1,policy)
	state.spawn_clock=999;state.shot_clock=999;state._scatter_clock=999;state._swarm_clock=999
	return state
static func digest(state)->String:
	var data:Dictionary=Campaign.comparable(state)
	data.erase("version");data.erase("rules")
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(data));return hash.finish().hex_encode()
static func run(host,verify:Callable):
	var state=fresh()
	verify.call(state.encounter_version==2 and Pressure.valid_data(state.pressure.data),"Local pressure starts through the original sole RunState")
	for key in ["pulse_seconds","warmup_seconds","near_targets","edge_gap","near_padding","far_padding","max_refill","max_recycle"]:
		var bad:Dictionary=state.pressure.data.duplicate(true)
		bad[key]=[] if key=="near_targets" else -1.0
		verify.call(not Pressure.valid_data(bad),"Reject unsafe pressure data:"+key)
	# Every geometry sample uses actual map collision and guarded spawn rectangle.
	for map_id in ["prologue_wall","outskirts_trial"]:
		for size in [Vector2(960,520),Vector2(1470,704),Vector2(2200,1050)]:
			for corner in [Vector2(50,450),Vector2(50,2700),Vector2(4100,450),Vector2(4100,2700),Vector2(2500,1700)]:
				for elapsed in [0.0,121.0,241.0]:
					state=State.new();state.start(4801,"viya",null,map_id,"weapons_v1",{},"campaign",-1,-1,-1,2)
					state.player=corner;state.elapsed=elapsed;state.spawn_view_size=size
					var at:Variant=state.pressure.anchor(state,"normal")
					verify.call(at is Vector2 and state.map_space.valid_position(at,24) and not state.visible_world().grow(56).has_point(at) and state.visible_world().grow(220).has_point(at),"Near-edge spawn stays offscreen/in bounds/outside walls across maps,sizes,corners,times:"+map_id+str(size)+str(corner)+str(elapsed))
	state=fresh();state.elapsed=1
	var warmup:Dictionary=Snapshot.capture(state);state.pressure.tick(state,.05)
	verify.call(warmup==Snapshot.capture(state),"Opening6second approach grace does not add pressure or consume RNG")
	state=fresh();state.elapsed=5.95;state.step(.05,Vector2.ZERO)
	verify.call(state.enemies.size()==6 and state.enemies.all(func(e):return not state.visible_world().grow(32).has_point(e.p)),"Actual first post-warmup pressure pulse adds6 safe approaching ordinary enemies")
	state.elapsed=6.95;state.step(.05,Vector2.ZERO)
	verify.call(state.enemies.size()==12 and Snapshot.valid(Snapshot.capture(state),state),"Next pulse keeps incoming enemies outside the local target and remains bounded to6 additions")
	for index in range(state.enemies.size()):state.enemies[index].p=state.player+Vector2(index*8-100,120)
	state.elapsed=8;state.pressure.tick(state,.05)
	verify.call(state.enemies.size()==12,"A satisfied local target does not create another arbitrary wave")
	for entry in [[0.0,12],[60.0,24],[120.0,48],[180.0,96],[240.0,144],[300.0,192]]:
		state.elapsed=entry[0]
		verify.call(state.pressure.target(state)==entry[1] and state.encounters.multiplier(2,state.elapsed)==pow(2,state.encounters.tier(state.elapsed)),"Local target grows alongside original minute doubling:"+str(entry[0]))
	# Recycling is relocation,never another defeat/spawn or heal/status reset.
	state=fresh()
	state.add_enemy(Vector2(2500,2800))
	var id:int=state.enemies[0].id
	state._damage_enemy(id,1)
	var old:Dictionary=state.enemies[0].duplicate(true)
	state._scatter_index=1
	state.add_enemy(Vector2(2600,2800),"normal","normal",1)
	state.add_enemy(Vector2(2700,2800),"elite","normal",0,"orc_siege")
	verify.call(state.add_enemy(Vector2(2800,2800),"normal","ranged",0,"goblin_javelin"),"Construct actual ranged windup protection fixture")
	state.enemies[-1].windup=.4
	verify.call(state.add_enemy(Vector2(2900,2800),"boss","normal",0,"demon_vanguard"),"Construct actual boss protection fixture")
	verify.call(state.add_enemy(Vector2(3000,2800),"normal","flier"),"Construct actual flying formation protection fixture")
	state.add_enemy(state.player+Vector2(0,200))
	var protected:Array=state.enemies.slice(1).map(func(e):return {"id":e.id,"p":e.p})
	var kills:int=state.kills;var gold:int=state.gold_collected;var xp:float=state.growth.xp
	state.elapsed=7;state.pressure.tick(state,.05)
	var moved:Dictionary=state.enemies.filter(func(e):return e.id==id)[0].duplicate(true)
	var old_position:Vector2=old.p;old.erase("p");var new_position:Vector2=moved.p;moved.erase("p")
	verify.call(old==moved and old_position!=new_position and state.visible_world().grow(220).has_point(new_position),"Far ordinary enemy returns near edge with identical ID,HP,species,status and cooldown fields")
	verify.call(protected.all(func(row):return state.enemies.any(func(e):return e.id==row.id and e.p==row.p)),"Elites,30-member formation identity and active ranged windups are not recycled")
	verify.call(kills==state.kills and gold==state.gold_collected and xp==state.growth.xp,"Recycling grants no kills,gold,XP or destruction rewards")
	for phase in [State.Phase.PAUSED,State.Phase.CHOOSING]:
		state=fresh();state.elapsed=7;state.phase=phase
		var before:Dictionary=Snapshot.capture(state);state.pressure.tick(state,.05);state.step(.05,Vector2.ZERO)
		verify.call(before==Snapshot.capture(state),"Pause/choice freezes pressure without consuming a saved boundary")
	state=fresh(1);state.elapsed=7
	var old_policy:Dictionary=Snapshot.capture(state);state.pressure.tick(state,.05)
	verify.call(old_policy==Snapshot.capture(state),"Published encounter policy1 never receives new refill or recycling")
	state=fresh();state.elapsed=5.95
	var saved:Dictionary=Snapshot.capture(state)
	var resumed=State.new()
	verify.call(Snapshot.restore(saved,resumed) and resumed.phase==State.Phase.PAUSED,"Current20 pressure state restores and requires explicit Continue")
	resumed.set_paused(false)
	var equal:=true
	for i in range(100):
		state.step(.05,Vector2.ZERO);resumed.step(.05,Vector2.ZERO);equal=equal and Campaign.comparable(state)==Campaign.comparable(resumed)
	verify.call(equal,"Resume at a refill boundary preserves100authoritative steps/sevenRNG without duplicate pulses")
	state=fresh();Rewards.equip(state);Rewards.drop(state,5)
	var owned:Dictionary=state.growth.owned.duplicate(true)
	state.player=state.chest_pickups[0].p;state.encounters.collect(state,.05)
	verify.call(state._chests_opened==1 and state._chest_bonus_ranks==5 and owned.keys().all(func(key):return state.growth.owned[key]==owned[key]+1),"Current2 policy keeps real30percent seeded chest and unique held-skill upgrades")
	for policy in [1,2]:
		state=fresh(policy)
		state.enemy_bullets.append({"p":Vector2(2500,2700),"velocity":Vector2(240,0),"life":.05000000000000001,"damage":8,"species":"goblin_javelin","shot":"javelin"})
		state.step(.05,Vector2.ZERO)
		verify.call(state.enemy_bullets.size()==(0 if policy==2 else 1),"Submicrosecond ranged lifetime is retired only in newpolicy2;published1 physics remains frozen")
		if policy==2:verify.call(Snapshot.valid(Snapshot.capture(state),state),"Live pressure snapshot remains valid at an enemy-projectile expiry boundary without relaxing the validator")
	var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	verify.call(Snapshot.VERSION==21 and Snapshot.fingerprint_for_v19()==baseline.fingerprint19,"Schema20 retains the exact published19 fingerprint")
	for row in baseline.records:
		var original:Dictionary=FileAccess.open(MANIFEST.get_base_dir().path_join("old_"+row.tag+".bin"),FileAccess.READ).get_var(false)
		var previous=State.new()
		var restored:bool=Snapshot.restore(original,previous)
		verify.call(restored and previous.encounter_version==row.encounter_version,"Published19 continues its saved policy/chest/regen rather than silently migrating to2:"+row.tag)
		if not restored:continue
		previous.set_paused(false)
		var same:bool=digest(previous)==row.hashes101[0]
		for i in range(100):previous.step(.05,Vector2.ZERO);same=same and digest(previous)==row.hashes101[i+1]
		verify.call(same,"Published19 all101authoritative hashes/sevenRNG match:"+row.tag)
	var dungeon=State.new()
	verify.call(not dungeon.start(4801,"viya",null,"gold_slime","weapons_v1",{},"gold_slime",20000,-1,-1,2) and dungeon.start(4801,"viya",null,"gold_slime","weapons_v1",{},"gold_slime",20000),"Gold dungeon retains its original mode/policy and rejects campaign pressure opt-in")
