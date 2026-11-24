extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Store=preload("res://scripts/progression/run_store.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Encounters=preload("res://scripts/combat/campaign_encounters.gd")
const LEGACY_MANIFEST:="res://tests/fixtures/game046_v18/baseline.json"
static func fresh():
	var s=State.new()
	s.start(4601,"viya",null,"prologue_wall","weapons_v1",{},"campaign",-1,-1,-1,1)
	s.player=Vector2(2500,1700)
	s.spawn_clock=999
	s.shot_clock=999
	s._scatter_clock=999
	s._swarm_clock=999
	return s
static func equip(s):
	s.growth.owned={"viya_rifle":1} if s.growth.definition("viya_rifle").size()>0 else s.growth.owned.duplicate(true)
	for entry in s.growth.pool:
		if entry.row=="attack" and not s.growth.owned.has(entry.id) and s.growth.row_entries("attack").size()<4:s.growth.owned[entry.id]=1
	for entry in s.growth.pool:
		if entry.row=="passive" and not s.growth.owned.has(entry.id):
			s.growth.owned[entry.id]=1
			break
	s.growth.level=s.growth.owned.values().reduce(func(total,n):return total+int(n),0)
	s._refresh_stats()
static func seed_for(count:int,win:bool=true)->int:
	var r:=RandomNumberGenerator.new()
	for seed_value in range(1,100000):
		r.seed=seed_value
		var drop:bool=r.randf()<.3
		if drop!=win:continue
		if not win or r.randi_range(1,5)==count:return seed_value
	return -1
static func drop(s,count:int=3,win:bool=true):
	s.loot_rng.seed=seed_for(count,win)
	s.add_enemy(s.player+Vector2(150,0),"elite","normal",0,"orc_siege")
	s._damage_enemy(int(s.enemies[-1].id),1000000)
static func old_digest(state)->String:
	var d:Dictionary=Campaign.comparable(state)
	d.erase("version")
	d.erase("rules")
	for key in ["encounter_version","chest_pickups","_chest_serial","_chests_opened","_chest_bonus_ranks"]:d.run.erase(key)
	var h:=HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(var_to_bytes(d))
	return h.finish().hex_encode()
static func run(host,verify:Callable):
	var s=fresh()
	verify.call(s.encounter_version==1 and s.encounters.data.size()==6,"New campaign encounter rules start through the existing state")
	for entry in [[0,1,160],[59.9,1,160],[60,2,320],[120,4,640],[180,8,640],[240,16,640],[300,32,640],[359.95,32,640]]:
		s.elapsed=float(entry[0])
		verify.call(s.encounters.multiplier(1,s.elapsed)==entry[1] and s.population_limit()==entry[2] and s.encounters.batch(s,s.wave_profile())==int(s.wave_profile().batch)*entry[1],"Data-driven minute multiplier and independent population ceiling at"+str(entry[0]))
	for entry in [[59.95,1,4],[119.95,2,16],[299.95,4,192]]:
		s=fresh()
		s.elapsed=float(entry[0]);s._elites_spawned=int(entry[1]);s.spawn_clock=.01
		s.step(.05,Vector2.ZERO)
		verify.call(s.enemies.filter(func(e):return e.kind=="normal").size()==entry[2],"Actual spawning changes at minute boundary"+str(entry[0]))
	s=fresh()
	verify.call(s.elite_schedule()==[55.0,110.0,170.0,230.0],"Two original elite times retained with two midway reinforcements")
	for i in range(4):
		s.elapsed=float(s.elite_schedule()[i])-.05
		s.step(.05,Vector2.ZERO)
		var elite:Dictionary=s.enemies.filter(func(e):return e.kind=="elite")[0]
		verify.call(s._elites_spawned==i+1 and elite.species==("orc_siege" if i<2 else "demon_shaman") and elite.max_hp==1600,"Actual scheduled elite retains the original species/HP at"+str(i))
		s._damage_enemy(int(elite.id),1000000)
	verify.call(Snapshot.valid(Snapshot.capture(s),s),"Four-elite progression and actual dropped rewards form a valid save")
	# Reserve special slots even with a completely saturated ordinary wave.
	s=fresh()
	for i in range(200):s._spawn_enemy()
	verify.call(s._ground_count()==155,"Current normal spawning reserves four elite slots plus the original boss slot")
	var specials:=true
	for i in range(4):
		specials=specials and s._spawn_enemy("elite")
		s._elites_spawned+=1
	s._boss_spawned=s._spawn_enemy("boss")
	verify.call(specials and s._boss_spawned and s._ground_count()==160,"All four elites and boss can spawn into a saturated normal population")
	s.elapsed=60
	for i in range(400):s._spawn_enemy()
	verify.call(s._ground_count()==320,"Live population ceiling increases at the first minute")
	s.elapsed=120
	for i in range(700):s._spawn_enemy()
	s.elapsed=300 # The deliberately prefilled boss fixture must satisfy its original admission time.
	verify.call(s._ground_count()==640 and not s._spawn_enemy() and Snapshot.valid(Snapshot.capture(s),s),"640-ground actor ceiling is enforced and remains serializable")
	for policy in [0,1]:
		var restart=fresh()
		restart.encounter_version=policy
		restart.request_transition("restart",restart.navigation_ticket)
		verify.call(restart.confirm_transition(restart.navigation_ticket) and restart.encounter_version==policy,"Restart keeps the selected encounter policy:"+str(policy))
	# Only real elite deaths roll chests; every roll stores its reward count/seed.
	s=fresh();drop(s,1,false)
	verify.call(s.kills==1 and s.chest_pickups.is_empty() and s._chest_serial==0,"Actual 30percent failure does not create a chest or receipt")
	for count in range(1,6):
		s=fresh();equip(s);drop(s,count)
		verify.call(s.chest_pickups.size()==1 and s.chest_pickups[0].count==count and s._chest_serial==1,"Actual elite drop records a count between1and5:"+str(count))
		var owned:Dictionary=s.growth.owned.duplicate(true)
		var before_rng:Array=Snapshot.capture(s).rng
		var xp:float=s.growth.xp
		var level:int=s.growth.level
		s.player=s.chest_pickups[0].p
		s.encounters.collect(s,.05)
		var changed:=0
		var exactly_one:=true
		for id in owned:
			var delta:int=s.growth.skill_level(id)-int(owned[id]);changed+=1 if delta==1 else 0;exactly_one=exactly_one and delta in [0,1]
		verify.call(changed==count and exactly_one and owned.size()==s.growth.owned.size() and s.growth.row_entries("attack").size()<=4 and s.growth.row_entries("passive").size()<=4,"Chest chooses distinct owned skills,one rank each,without learning skills or expanding slots:"+str(count))
		verify.call(s.chest_pickups.is_empty() and s._chests_opened==1 and before_rng==Snapshot.capture(s).rng and s.growth.xp==xp and s.growth.level==level,"Opening commits removal/receipt with all seven streams and XP unchanged")
		var after:Dictionary=s.growth.owned.duplicate(true)
		s.encounters.collect(s,.05)
		verify.call(after==s.growth.owned and s._chests_opened==1,"Repeated collection cannot grant the same chest twice")
	# Evolve current attacks and gracefully handle fewer eligible or all-capped skills.
	s=fresh()
	var rifle:String=s.growth.owned.keys()[0]
	s.growth.owned[rifle]=4;s.growth.level=4;s._refresh_stats();drop(s,5)
	s.player=s.chest_pickups[0].p;s.encounters.collect(s,.05)
	verify.call(s.growth.skill_level(rifle)==5 and s.growth.owned.size()==1,"Only one eligible held attack receives exactly one rank and reaches actualLv5")
	drop(s,5);s.player=s.chest_pickups[0].p;s.encounters.collect(s,.05)
	verify.call(s.growth.skill_level(rifle)==5 and s._chests_opened==2 and s.cues.events[-1].supply.upgrades.is_empty(),"All-maxed owned skills consume the chest without exceeding caps or inventing upgrades")
	# Save before opening and after opening via the original atomic file store.
	s=fresh();equip(s);drop(s,5)
	var folder:String="user://encounters-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	var store=Store.new();store.path=folder.path_join("battle.save")
	verify.call(Snapshot.valid(Snapshot.capture(s),s) and store.save_current(s)==OK,"Unopened seeded chest is in the original valid atomic snapshot")
	var loaded=State.new()
	verify.call(store.load_saved(loaded)==OK and Snapshot.restore(store.pending,loaded) and loaded.phase==State.Phase.PAUSED and loaded.encounter_version==1 and loaded.chest_pickups==s.chest_pickups,"Reload preserves the unclaimed box and explicitly waits for Continue")
	var frozen:Dictionary=Snapshot.capture(loaded)
	loaded.step(.05,Vector2.ZERO);loaded.encounters.collect(loaded,.05)
	verify.call(frozen==Snapshot.capture(loaded),"Pause cannot open a chest or advance its state")
	loaded.set_paused(false)
	s.player=s.chest_pickups[0].p;loaded.player=loaded.chest_pickups[0].p
	s.step(.05,Vector2.ZERO);loaded.step(.05,Vector2.ZERO)
	verify.call(Campaign.comparable(s)==Campaign.comparable(loaded),"The same unopened seed yields identical rewards and seven RNG after restore")
	verify.call(store.save_current(loaded)==OK,"Opened receipt,levels and removal are saved together")
	var again=State.new();store.load_saved(again);Snapshot.restore(store.pending,again);again.set_paused(false)
	var ranks:Dictionary=again.growth.owned.duplicate(true)
	again.step(.05,Vector2.ZERO)
	verify.call(again.chest_pickups.is_empty() and again._chests_opened==1 and ranks==again.growth.owned,"Reloading the opened chest cannot replay upgrades")
	# Active choices and focus/pause preserve the pre-rolled reward instead of rerolling.
	s=fresh();drop(s,3);s.player=s.chest_pickups[0].p;s.grant_xp(s.growth.threshold())
	var offer:Array=s.growth.offer.duplicate();var chest:Dictionary=s.chest_pickups[0].duplicate(true)
	s.encounters.collect(s,.05);s.step(.05,Vector2.ZERO)
	verify.call(s.phase==State.Phase.CHOOSING and s.growth.offer==offer and s.chest_pickups[0]==chest,"A pending three-way skill choice freezes chests and original offer")
	s.select_skill(s.growth.offer[0],s.growth.ticket);s.encounters.collect(s,.05)
	verify.call(s.chest_pickups.is_empty() and s._chests_opened==1,"A chest opens against current owned skills only after the existing choice finishes")
	# Malformed boxes must be rejected atomically,without mutating a healthy state.
	s=fresh();drop(s,3)
	var valid:Dictionary=Snapshot.capture(s)
	var target=fresh();var untouched:Dictionary=Snapshot.capture(target)
	for mutation in ["version","count0","count6","seed","outside","ledger","duplicate","source"]:
		var bad:Dictionary=valid.duplicate(true)
		match mutation:
			"version":bad.run.encounter_version=2
			"count0":bad.run.chest_pickups[0].count=0
			"count6":bad.run.chest_pickups[0].count=6
			"seed":bad.run.chest_pickups[0].seed=-1
			"outside":bad.run.chest_pickups[0].p=Vector2(9999,9999)
			"ledger":bad.run._chests_opened=1
			"duplicate":bad.run.chest_pickups.append(bad.run.chest_pickups[0].duplicate(true));bad.run._chest_serial=2;bad.run.kills=2
			"source":bad.run.chest_pickups[0].source="wrong"
		verify.call(not Snapshot.restore(bad,target) and untouched==Snapshot.capture(target),"Corrupt chest rejected without partial mutation:"+mutation)
	# The complete original v18 states were captured with the previous production code.
	var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LEGACY_MANIFEST))
	verify.call(Snapshot.VERSION==19 and Snapshot.fingerprint_for_v18()==baseline.fingerprint18,"New schema keeps the exact published18 fingerprint")
	for row in baseline.records:
		var old:Dictionary=FileAccess.open(LEGACY_MANIFEST.get_base_dir().path_join("old_"+row.tag+".bin"),FileAccess.READ).get_var(false)
		var previous=State.new()
		var restored:bool=Snapshot.restore(old,previous)
		verify.call(restored and previous.encounter_version==0 and previous.chest_pickups.is_empty(),"Published18 restore keeps its old encounter policy:"+row.tag)
		if not restored:continue
		previous.set_paused(false)
		var same:bool=old_digest(previous)==row.hashes101[0]
		for frame in range(100):
			previous.step(.05,Vector2.ZERO);same=same and old_digest(previous)==row.hashes101[frame+1]
		verify.call(same,"All101original authoritative hashes/sevenRNG preserved:"+row.tag)
	var gold=State.new();gold.start(4601,"viya",null,"gold_slime","weapons_v1",{},"gold_slime",20000)
	verify.call(gold.encounter_version==0 and gold.encounters.multiplier(0,300)==1 and Snapshot.valid(Snapshot.capture(gold),gold),"Gold dungeon retains its original three-minute economy/population policy")
	# Real fresh UI departure opts in,whereas Continue keeps the stored policy.
	var ui=preload("res://tests/test_battle_save_notice.gd").make_ui(host,folder.path_join("ui"))
	await host.get_tree().process_frame
	Campaign.depart(ui)
	verify.call(ui.simulation.encounter_version==1 and ui.run_store.pending.run.encounter_version==1,"Real production departure and its initial saved admission enable new campaign rules")
	var actual=ui.simulation
	actual.spawn_clock=999;actual.shot_clock=999;actual._scatter_clock=999;actual._swarm_clock=999
	drop(actual,5)
	ui._physics_process(.05)
	verify.call(ui.run_store.pending.run._chest_serial==1 and ui.run_store.pending.run.chest_pickups.size()==1,"Actual UI physics immediately persists a dropped seeded chest")
	var actual_level:int=actual.growth.level
	actual.player=actual.chest_pickups[0].p
	ui._physics_process(.05)
	verify.call(ui.battle_save_error==OK and ui.run_store.pending.run._chests_opened==1 and ui.run_store.pending.run.chest_pickups.is_empty() and ui.run_store.pending.run._chest_bonus_ranks==1 and actual.growth.level==actual_level,"Actual pickup saves removal and bonus ranks atomically without inventing XP levels")
	var disk=Store.new();disk.path=ui.run_store.path
	verify.call(disk.load_saved(State.new())==OK and disk.pending.run._chests_opened==1,"A fresh reader validates the persisted opened reward")
	var path:String=ui.run_store.path
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(path)
	ui.run_store.path=folder.path_join("missing/battle.save")
	drop(actual,3)
	ui._physics_process(.05)
	verify.call(actual.phase==State.Phase.PAUSED and ui.battle_save_error!=OK and actual.chest_pickups.size()==1 and FileAccess.get_file_as_bytes(path)==bytes,"Failed chest persistence uses the original pause/retry and preserves the previous good file")
	var held_chest:Dictionary=actual.chest_pickups[0].duplicate(true)
	ui.run_store.path=path;ui._retry_battle_save()
	verify.call(ui.battle_save_error==OK and ui.run_store.pending.run.chest_pickups[0]==held_chest,"Retry stores the same pre-rolled chest without replacement or reroll")
	ui.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().create_timer(1.0).timeout
