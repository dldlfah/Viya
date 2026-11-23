extends RefCounted
const State = preload("res://scripts/combat/run_state.gd")
const Rules = preload("res://scripts/world/supply_catalog.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const Store = preload("res://scripts/progression/run_store.gd")
const Wallet = preload("res://scripts/progression/gold_progress.gd")
const Campaign = preload("res://tests/test_campaign.gd")

static func quiet(map_id: String = "prologue_wall"):
	var state = State.new()
	state.start(1701, "viya", null, map_id)
	state.spawn_clock = 999.0
	state.shot_clock = 999.0
	state._scatter_clock = 999.0
	state.stage_rules.swarm.chance = 0.0
	return state

static func drop(state, kind: String) -> Dictionary:
	# Deterministic fixture seed; still uses the real destruction/drop/pickup path.
	var generator := RandomNumberGenerator.new()
	for seed_value in range(1,10000):
		generator.seed = seed_value
		if Rules.roll_item(generator) == kind:
			state.loot_rng.seed = seed_value
			break
	for structure in state.structures:
		if structure.hp > 0:
			state._damage_structure(int(structure.id), 1000.0)
			return state.item_pickups[-1]
	return {}

static func run(scene, verify: Callable) -> void:
	probability_checks(verify)
	attack_checks(verify)
	recovery_checks(verify)
	magnet_checks(verify)
	purge_checks(verify)
	respawn_checks(verify)
	save_checks(verify)
	# Actual existing main scene/view is the production route, not a separate demo.
	scene.begin_run()
	var state = scene.simulation
	verify.call(state.structures.size() == 32 and scene.view.simulation == state, "Production sortie creates map supplies on the original simulation/view")
	var item: Dictionary = drop(state,"hp")
	state.hp = 10
	item.p = state.player
	scene._physics_process(0.05)
	verify.call(state.hp == 40 and state.item_pickups.is_empty(), "Actual main physics picks up HP loot and applies recovery")
	var frozen: Dictionary = Campaign.comparable(state)
	scene.view.queue_redraw()
	await scene.get_tree().process_frame
	verify.call(frozen == Campaign.comparable(state), "Supply/item/feedback drawing does not mutate gameplay or any RNG")
	verify.call(state.cues.events.any(func(event): return event.kind == "item" and event.label == "HP +30"), "Committed pickup drives its visible Korean feedback")

static func probability_checks(verify: Callable) -> void:
	verify.call(Rules.item_for_roll(0.2,0.0)=="" and Rules.item_for_roll(0.999,0.4)=="", "Exactly20percent of the drop roll interval yields an item")
	for pair in [[0.0,"hp"],[0.399999,"hp"],[0.4,"mp"],[0.799999,"mp"],[0.8,"magnet"],[0.899999,"magnet"],[0.9,"purge"],[0.999999,"purge"]]:
		verify.call(Rules.item_for_roll(0.199999,pair[0])==pair[1], "Conditional40/40/10/10 boundary: " + str(pair[0]))
	var generator := RandomNumberGenerator.new()
	generator.seed = 170017
	var counts := {"":0,"hp":0,"mp":0,"magnet":0,"purge":0}
	for index in range(100000):
		counts[Rules.roll_item(generator)] += 1
	var drops: int = 100000-counts[""]
	verify.call(absi(drops-20000)<600, "100000 real RNG trials stay near20percent item drops")
	verify.call(absf(float(counts.hp)/drops-0.4)<0.02 and absf(float(counts.mp)/drops-0.4)<0.02, "HP and MP each have40percent configured weight in real draws")
	verify.call(absf(float(counts.magnet)/drops-0.1)<0.015 and absf(float(counts.purge)/drops-0.1)<0.015, "Remaining draws split10percent magnet/10percent purge")
	for map_id in ["prologue_wall","outskirts_trial"]:
		var state = quiet(map_id)
		verify.call(state.structures.size()==32 and Rules.valid_layout(state.supply_catalog.layouts[map_id],state.map_space), "All32 themed supplies are placed outside solid terrain: " + map_id)
		var invalid: Array = state.supply_catalog.layouts[map_id].duplicate(true)
		invalid[0].p = [0,0]
		verify.call(not Rules.valid_layout(invalid,state.map_space), "A supply in a wall/outside walkable space is rejected")
		var streams := [state.rng.state,state.growth.rng.state,state.gold_rng.state,state.encounter_rng.state,state.scatter_rng.state]
		for structure in state.structures:
			state._damage_structure(int(structure.id),1000)
		verify.call(state.kills==0 and state.pickups.is_empty() and state.gold_pickups.is_empty(), "Supply destruction does not fake monster kills or XP/gold")
		verify.call(streams==[state.rng.state,state.growth.rng.state,state.gold_rng.state,state.encounter_rng.state,state.scatter_rng.state], "Supply drops never consume any of the five pre-existing RNG streams")

static func attack_checks(verify: Callable) -> void:
	var state = quiet()
	var target: Dictionary = state._nearest(state.player,State.SHOT_RANGE)
	verify.call(target.id < -1, "Automatic attack can acquire a visible supply when no enemy is in range")
	for shot in range(3):
		state._auto_fire()
		for frame in range(14):state._move_bullets(0.05)
	verify.call(target.hp==0 and state.shots==3, "Three real swept rifle hits break a30HP supply")
	var before: Dictionary = Campaign.comparable(state)
	state._damage_structure(int(target.id),1000)
	verify.call(before==Campaign.comparable(state), "Repeated attacks on a broken supply cannot reroll loot")
	state = quiet()
	state.add_enemy(state.player+Vector2(400,0))
	verify.call(state._nearest(state.player,520).id > 0, "Nearby supplies do not steal targeting priority from enemies")
	state = quiet()
	target = state.structures[0]
	state._burst(target.p,50,100,"blast")
	verify.call(target.hp==0, "Actual area attack damages supplies")
	state = quiet()
	target = state.structures[0]
	state._damage_target(int(target.id),10)
	verify.call(target.hp==20, "Shared chain target dispatch applies supply damage")
	state.cast_ultimate(state.magic.ticket)
	verify.call(target.hp==0 and state.magic.mana==60, "Real MP ultimate also destroys supplies in its range")
	state = quiet()
	state.player = Vector2(800,1300)
	state._projectile(Vector2.RIGHT,1,5,1000)
	state.player = state.structures[0].p-Vector2(100,0)
	state.bullets.clear()
	state._projectile(Vector2.RIGHT,1,5,1000)
	state._move_bullets(0.12)
	verify.call(state.bullets[0].seen.has(state.structures[0].id) and Snapshot.valid(Snapshot.capture(state),state), "Piercing bullets remember negative supply IDs in a valid saved hit history")

static func recovery_checks(verify: Callable) -> void:
	var state = quiet()
	state.hp = 10
	state.magic.mana = 10.5
	var hp_item: Dictionary = drop(state,"hp")
	hp_item.p = state.player
	state._collect_pickups(0.0)
	verify.call(state.hp==40 and state.magic.mana==10.5, "HP item restores30percent max HP without spending MP")
	var mp_item: Dictionary = drop(state,"mp")
	mp_item.p = state.player
	state._collect_pickups(0.0)
	verify.call(state.hp==40 and state.magic.mana==40.5, "MP item restores30percent max MP independently")
	state.hp = state.max_hp-1
	state.magic.mana = state.magic.maximum_mana()-0.1
	state._apply_supply("hp")
	state._apply_supply("mp")
	verify.call(state.hp==state.max_hp and state.magic.mana==state.magic.maximum_mana(), "Both recovery effects clamp to their actual maxima")
	var levels: Dictionary = State.AccountTalents.empty_levels()
	for id in levels:levels[id]=3
	state.start(1701,"viya",levels,"prologue_wall")
	state.hp = 10
	state.magic.mana = 10.5
	state._apply_supply("hp")
	state._apply_supply("mp")
	verify.call(state.hp==49 and is_equal_approx(state._regen_remainder,0.675) and state.magic.mana==45, "MaxHP/MP and healing-efficiency talents compose with items including fractional HP carry")
	for phase in [State.Phase.PAUSED,State.Phase.CHOOSING,State.Phase.READY,State.Phase.CLEARED,State.Phase.DEFEAT]:
		state.phase = phase
		var before: Dictionary = Campaign.comparable(state)
		state._collect_items(0.05)
		for kind in Rules.ITEM_KINDS:state._apply_supply(kind)
		verify.call(before==Campaign.comparable(state), "Inactive phases cannot consume/apply item effects: " + str(phase))

static func magnet_checks(verify: Callable) -> void:
	var state = quiet()
	state.add_pickup(Vector2(4900,3100),90)
	state.add_pickup(Vector2(100,500),60)
	state.gold_pickups.append({"p":Vector2(4900,500),"value":123})
	state.gold_pickups.append({"p":Vector2(100,3100),"value":456})
	var magnet: Dictionary = drop(state,"magnet")
	var other: Dictionary = drop(state,"mp")
	magnet.p = state.player
	state._collect_pickups(0)
	verify.call(state.gold_collected==579 and state.gold_pickups.is_empty() and state.pickups.is_empty(), "Map magnet instantly collects distant XP and gold over the entire map")
	verify.call(state.phase==State.Phase.CHOOSING and state.growth.pending==3 and state.growth.level==4 and state.growth.xp==6, "Magnet uses the real XP curve and opens queued choices once")
	verify.call(state.item_pickups.size()==1 and state.item_pickups[0].id==other.id, "Magnet does not recursively activate other supply items")
	state.set_paused(true) # Same focus-loss path used before a mobile save.
	var restored = State.new()
	verify.call(Snapshot.restore(Snapshot.capture(state),restored) and restored.growth.offer==state.growth.offer and restored.gold_collected==579, "Choice opened by magnet restores the identical offer and already-collected gold")
	restored.set_paused(false)
	state.set_paused(false)
	verify.call(Campaign.comparable(restored)==Campaign.comparable(state), "Explicit Continue preserves magnet consumption and queued growth without reroll")

static func purge_checks(verify: Callable) -> void:
	var state = quiet()
	state.gold_drop_chance = 1.0
	state.elapsed = 300.0
	state.checkpoint_index = 2
	for variant in ["normal","ranged","fast","heavy","flier"]:
		state.add_enemy(state.player+Vector2(800,0),"normal",variant)
	state.add_enemy(state.player+Vector2(900,0),"elite")
	state.add_enemy(state.player+Vector2(1000,0),"boss")
	state._boss_spawned = true
	state.enemy_bullets.append({"p":state.player+Vector2(400,0),"velocity":Vector2.LEFT*200,"life":1.0,"damage":8})
	var boss: Dictionary = state.enemies[-1].duplicate(true)
	var purge: Dictionary = drop(state,"purge")
	purge.p = state.player
	state._collect_items(0)
	verify.call(state.enemies.size()==1 and state.enemies[0]==boss and not state._boss_defeated, "Purge kills all five variants and elites while preserving exact boss HP/state")
	verify.call(state.kills==6 and state.pickups.size()==6 and state.gold_pickups.size()==6 and state.enemy_bullets.is_empty(), "Purge uses one reward per real death and clears live hostile bullets")
	state._collect_items(0)
	verify.call(state.kills==6 and state.gold_pickups.size()==6, "Consumed purge cannot repeat kills or gold rewards")
	state.elapsed = 360.0
	state._resolve_deadline()
	verify.call(state.end_reason=="timeout" and state.result_summary().gold_reward==0, "Purge cannot substitute for killing the boss or grant timeout rewards")
	# Normal clear still sweeps purge drops and pays only once through GoldProgress.
	state.phase = State.Phase.RUNNING
	state.end_reason = ""
	state._finished_result.clear()
	state._damage_enemy(int(boss.id),100000)
	var summary: Dictionary = state.result_summary()
	verify.call(summary.outcome=="cleared" and summary.gold_reward==state.gold_collected+100 and state.gold_pickups.is_empty(), "Boss kill plus6minutes settles all purge/boss gold through normal clear")
	var wallet = Wallet.new()
	wallet.path = "user://supply-wallet-"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg"
	wallet.load_progress()
	verify.call(wallet.settle(summary)==OK and wallet.total==summary.gold_reward and wallet.settle(summary)==OK and wallet.total==summary.gold_reward, "Existing atomic wallet credits item-assisted clear exactly once")
	DirAccess.remove_absolute(wallet.path)

static func save_checks(verify: Callable) -> void:
	var state = quiet()
	var item: Dictionary = drop(state,"mp")
	state._damage_structure(int(state.structures[1].id),7)
	state.hp = 54
	state.magic.mana = 12.25
	state.set_paused(true)
	var store = Store.new()
	store.path = "user://supply-save-"+Crypto.new().generate_random_bytes(8).hex_encode()+".save"
	var restored = State.new()
	verify.call(store.save_current(state)==OK and store.load_saved(restored)==OK and Snapshot.restore(store.pending,restored), "Actual checksummed file restores broken/damaged structures and a live drop")
	verify.call(Campaign.comparable(state)==Campaign.comparable(restored) and restored.magic.mana==12.25 and restored.hp==54, "Saved drop kind/position/six RNG states and spent resources are exact")
	state.set_paused(false)
	restored.set_paused(false)
	for index in range(2,32):
		state._damage_structure(int(state.structures[index].id),1000)
		restored._damage_structure(int(restored.structures[index].id),1000)
	verify.call(Campaign.comparable(state)==Campaign.comparable(restored), "Future drop rolls after Continue exactly match uninterrupted play")
	item = restored.item_pickups[0]
	item.p = restored.player
	restored._collect_items(0)
	var copy = State.new()
	verify.call(Snapshot.restore(Snapshot.capture(restored),copy) and not copy.item_pickups.any(func(p): return p.id == item.id) and copy.item_pickups.size()==restored.item_pickups.size(), "Claimed recovery cannot reappear on a second restore")
	for mutation in ["hp","id","position","loot","duplicate","source","generation","timer","serial","partial","rng"]:
		var bad: Dictionary = Snapshot.capture(state)
		match mutation:
			"hp":bad.run.structures[0].hp=-1
			"id":bad.run.structures[0].id=-999
			"position":bad.run.structures[0].p=Vector2.ZERO
			"loot":bad.run.item_pickups[0].kind="unknown"
			"duplicate":bad.run.item_pickups.append(bad.run.item_pickups[0].duplicate(true))
			"source":bad.run.item_pickups[0].source=-999
			"generation":bad.run.item_pickups[0].generation=999
			"timer":bad.run.structures[0].respawn_left=-1.0
			"serial":bad.run._loot_serial=0
			"partial":bad.run.structures.pop_back()
			"rng":bad.rng.pop_back()
		var frozen: Dictionary = Campaign.comparable(copy)
		verify.call(not Snapshot.restore(bad,copy) and frozen==Campaign.comparable(copy), "Malformed supply save rejected atomically: "+mutation)
	var legacy: Dictionary = Snapshot.capture(state)
	legacy.version = 8
	legacy.rules = Snapshot.GAME016_RULES
	legacy.run.erase("structures")
	legacy.run.erase("item_pickups")
	legacy.run.erase("_loot_serial")
	legacy.rng.resize(5)
	verify.call(Snapshot.restore(legacy,copy) and copy.structures.is_empty() and copy.item_pickups.is_empty() and copy.hp==54 and copy.magic.mana==12.25 and copy.map_id=="prologue_wall", "Published version8 keeps its map/resources and gains no retroactive supplies")
	DirAccess.remove_absolute(store.path)

static func respawn_checks(verify: Callable) -> void:
	var state = quiet()
	var item: Dictionary = drop(state,"mp")
	var structure: Dictionary = state.structures[0]
	verify.call(structure.hp==0 and structure.respawn_left==45.0 and structure.generation==1, "Destruction starts a45-second active-time respawn countdown")
	state._damage_structure(int(state.structures[1].id),10)
	state._tick_structures(44.95)
	state.elapsed = 44.95
	verify.call(structure.hp==0 and is_equal_approx(structure.respawn_left,0.05), "Broken supply remains broken just before45seconds")
	state.set_paused(true)
	var frozen: Dictionary = Campaign.comparable(state)
	state.step(0.05,Vector2.ZERO)
	state._tick_structures(45)
	verify.call(frozen==Campaign.comparable(state), "Pause freezes even a nearly-complete structure respawn")
	var copy = State.new()
	verify.call(Snapshot.restore(Snapshot.capture(state),copy) and is_equal_approx(copy.structures[0].respawn_left,0.05), "Process recovery preserves remaining respawn time, not a fresh45seconds")
	copy.set_paused(false)
	var rng_before: int = copy.loot_rng.state
	copy.step(0.05,Vector2.ZERO)
	verify.call(copy.structures[0].hp==30 and copy.structures[0].respawn_left==0 and copy.loot_rng.state==rng_before, "First active frame at45seconds restores full HP without rolling loot early")
	verify.call(copy.structures[1].hp==20 and copy.item_pickups.size()==1 and copy.item_pickups[0].id==item.id, "Respawn leaves damaged living supplies and old unclaimed items intact")
	var next: Dictionary = drop(copy,"mp")
	verify.call(copy.item_pickups.size()==2 and item.id != next.id and next.source==item.source and next.generation==2, "Breaking the regenerated supply produces an independent second drop with a unique generation/ID")
	copy.item_pickups[0].p=copy.player
	copy._collect_items(0)
	verify.call(copy.item_pickups.size()==1 and copy.item_pickups[0].id==next.id, "Picking up an older drop cannot consume a newer drop from the same supply")
	verify.call(Snapshot.valid(Snapshot.capture(copy),copy), "Repeated-generation drops remain valid exact saved state")
	copy.elapsed = 44.9 + 0.05 + 0.05 # Real frame addition may be just below45.
	verify.call(Snapshot.valid(Snapshot.capture(copy),copy), "Floating-point45-second boundary cannot reject a valid second-generation save")
	copy.grant_xp(30)
	frozen=Campaign.comparable(copy)
	copy.step(0.05,Vector2.ZERO)
	copy._tick_structures(45)
	verify.call(frozen==Campaign.comparable(copy), "Level-up choice also freezes respawn countdown and item state")
