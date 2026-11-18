extends RefCounted
const State = preload("res://scripts/combat/run_state.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const Campaign = preload("res://tests/test_campaign.gd")
const Store = preload("res://scripts/progression/run_store.gd")

static func quiet(map_id: String = "legacy_arena"):
	var state=State.new()
	state.start(2001,"viya",null,map_id,"weapons_v1")
	state.spawn_clock=999.0
	state.shot_clock=999.0
	state._scatter_clock=999.0
	state.stage_rules.swarm.chance=0.0
	return state

static func run(host, verify: Callable) -> void:
	var state=quiet()
	verify.call(state.profiles.error.is_empty() and state.profiles.data.species.size()==12 and state.combat_profile_version==1,"Production profile data contains7ordinary/3elite/2boss species")
	verify.call(state.hp==100 and state.max_hp==100 and state.magic.mana==100 and state.stats.speed==235 and state.stats.pickup==80 and state.stats.crit==0 and state.stats.crit_damage==2 and state.stats.hit_lock==0.85 and state.stats.regen==0,"Locked Viya HP/movement/crit/invulnerability/recovery/pickup stats come from her profile")
	var magic: Dictionary=state.magic.profile(0)
	verify.call(magic.damage==100 and magic.radius==460 and magic.mana_cost==40 and magic.mana_regen==1 and magic.cooldown==0 and state.stats.physical_penetration==0.15 and state.stats.magical_penetration==0,"Locked MP attack/resources and physical-only15percent penetration remain applied")
	verify.call(state.growth.owned=={"gun_rifle":1},"Applying stat profiles never grants an initial automatic unique")
	var malformed: Dictionary=state.profiles.data.duplicate(true)
	malformed.species.orc_shield.contact_damage=-1
	verify.call(not state.CombatProfiles.valid(malformed),"Invalid species contact damage is rejected at data load")
	malformed=state.profiles.data.duplicate(true)
	malformed.maps.prologue_wall.normal.normal[0].id="slime"
	verify.call(not state.CombatProfiles.valid(malformed),"Unknown/slime species cannot silently enter Chapter1 pools")
	var frozen: Dictionary=Campaign.comparable(state)
	verify.call(not state.add_enemy(state.player+Vector2(200,0),"normal","normal",0,"unknown") and frozen==Campaign.comparable(state),"Invalid explicit species does not consume actor IDs/RNG or mutate battle")
	var normal := {
		"goblin_raider":["normal",[20,28,36],[68,80,96]],
		"goblin_javelin":["ranged",[20,28,36],[58,68,82]],
		"hell_hound":["fast",[20,28,36],[116,136,164]],
		"orc_shield":["heavy",[40,56,72],[37,44,52]],
		"wing_imp":["flier",[20,28,36],[360,360,360]],
		"skeleton_soldier":["normal",[24,34,43],[68,80,96]],
		"skeleton_archer":["ranged",[20,28,36],[58,68,82]]}
	for id in normal:
		for wave in range(3):
			state=quiet()
			state.elapsed=wave*120.0
			state.add_enemy(state.player+Vector2(300,0),"normal",normal[id][0],0,id)
			var enemy: Dictionary=state.enemies[0]
			verify.call(enemy.hp==normal[id][1][wave] and enemy.max_hp==enemy.hp and enemy.speed==normal[id][2][wave] and enemy.spawn_wave==wave and enemy.contact_damage==12,"Actual species HP/speed/rounding and contact stat: "+id+" wave"+str(wave))
			state.set_paused(true)
			var copy=State.new()
			verify.call(Snapshot.restore(Snapshot.capture(state),copy) and copy.enemies==state.enemies,"Spawn-wave stats survive exact restore: "+id+"/"+str(wave))
	var specials := {"orc_siege":["elite",1600,45,18],"demon_shaman":["elite",1600,65,12],"undead_knight":["elite",1600,85,16],"demon_vanguard":["boss",3200,60,20],"undead_commander":["boss",3200,65,16]}
	for id in specials:
		state=quiet()
		state.elapsed=300
		state.add_enemy(state.player+Vector2(20,0),specials[id][0],"normal",0,id)
		var enemy: Dictionary=state.enemies[0]
		verify.call(enemy.hp==specials[id][1] and enemy.speed==specials[id][2] and enemy.contact_damage==specials[id][3],"Actual special species fixed stats: "+id)
		state._move_enemies(0.0)
		verify.call(state.hp==100-specials[id][3],"Actual contact applies species-specific damage: "+id)
	spawn_checks(verify)
	ranged_checks(verify)
	recovery_checks(verify)
	# This is the actual existing lobby/stage path, not an alternate game.
	host.new_run_ruleset="weapons_v1"
	host.begin_run()
	verify.call(host.simulation.combat_profile_version==1 and host.simulation.profiles.hero("viya").hp==100,"Existing production scene launches with stat profiles enabled")
	host.simulation.elapsed=300
	host.simulation._boss_spawned=host.simulation._spawn_enemy("boss")
	host._update_hud()
	var boss_name := "마왕군 선봉장" if host.simulation.map_id=="prologue_wall" else "망자의 지휘관"
	verify.call(host.boss_label.text.contains(boss_name) and host.boss_bar.max_value==3200,"Actual boss HUD names its species and uses the locked HP")
	frozen=Campaign.comparable(host.simulation)
	host.view.queue_redraw()
	await host.get_tree().process_frame
	verify.call(frozen==Campaign.comparable(host.simulation),"Species labels/typed hostile projectile drawing cannot mutate stats or seven RNG streams")

static func spawn_checks(verify: Callable) -> void:
	for map_id in ["prologue_wall","outskirts_trial"]:
		var state=quiet(map_id)
		var seen := {}
		for variant in ["normal","ranged"]:
			for index in range(50):
				state.add_enemy(state.player+Vector2(600,0),"normal",variant)
				seen[state.enemies[-1].species]=true
		verify.call(seen.has("goblin_raider") and seen.has("goblin_javelin") and (seen.has("skeleton_soldier") and seen.has("skeleton_archer") if map_id=="outskirts_trial" else not seen.has("skeleton_soldier")),"Actual map pools select appropriate species: "+map_id)
		state=quiet(map_id)
		for index in range(4):
			verify.call(state._spawn_scatter(),"Existing30member formation still spawns in "+map_id)
			var pack: Array=state.enemies.filter(func(e):return e.scatter_group==index+1)
			verify.call(pack.size()==30 and pack.all(func(e):return e.species==pack[0].species) and pack[0].variant in state.SCATTER_VARIANTS,"Each added formation retains30 members of one selected species")
		state=quiet(map_id)
		state.elapsed=109.99
		state.step(.02,Vector2.ZERO)
		var first: Dictionary=state.enemies.filter(func(e):return e.kind=="elite")[0]
		verify.call(first.species==("orc_siege" if map_id=="prologue_wall" else "demon_shaman"),"110second elite follows its map species plan")
		state.elapsed=229.99
		state.step(.02,Vector2.ZERO)
		verify.call(state.enemies.filter(func(e):return e.kind=="elite")[-1].species==("demon_shaman" if map_id=="prologue_wall" else "undead_knight"),"230second elite follows its map species plan")
		state.elapsed=299.99
		state.step(.02,Vector2.ZERO)
		verify.call(state.enemies.filter(func(e):return e.kind=="boss")[0].species==("demon_vanguard" if map_id=="prologue_wall" else "undead_commander"),"300second boss follows its map species plan")
	var state=quiet("outskirts_trial")
	var streams := [state.rng.state,state.growth.rng.state,state.gold_rng.state,state.encounter_rng.state,state.scatter_rng.state,state.loot_rng.state]
	for index in range(40):state.add_enemy(state.player+Vector2(600,0))
	verify.call(streams==[state.rng.state,state.growth.rng.state,state.gold_rng.state,state.encounter_rng.state,state.scatter_rng.state,state.loot_rng.state],"Species choice uses its seventh RNG without consuming six existing streams")

static func ranged_checks(verify: Callable) -> void:
	for pair in [["goblin_javelin","javelin"],["skeleton_archer","arrow"]]:
		var state=quiet()
		state.add_enemy(state.player+Vector2(120,0),"normal","ranged",0,pair[0])
		var enemy: Dictionary=state.enemies[0]
		enemy.fire_clock=0.0
		state._tick_ranged(enemy,0.05)
		verify.call(enemy.windup==0.65 and state.enemy_bullets.is_empty(),"Species ranged attack retains0.65second telegraph")
		for frame in range(13):state._tick_ranged(enemy,0.05)
		verify.call(state.enemy_bullets.size()==1 and state.enemy_bullets[0].damage==8 and state.enemy_bullets[0].shot==pair[1],"Actual ranged projectile carries8damage and species shot type: "+pair[0])
		for frame in range(15):state._move_enemy_bullets(0.05)
		verify.call(state.hp==92 and state.enemy_bullets.is_empty(),"Actual species projectile removes8HP and preserves invulnerability")

static func recovery_checks(verify: Callable) -> void:
	var state=quiet("outskirts_trial")
	state.elapsed=239.99
	state._spawn_scatter()
	state.hp=61
	state.magic.mana=33.25
	state.set_paused(true)
	var store=Store.new()
	store.path="user://species-"+Crypto.new().generate_random_bytes(8).hex_encode()+".save"
	var copy=State.new()
	verify.call(store.save_current(state)==OK and store.load_saved(copy)==OK and Snapshot.restore(store.pending,copy) and Campaign.comparable(state)==Campaign.comparable(copy),"Binary save preserves species stats/HP/MP and seventh RNG exactly")
	state.set_paused(false)
	copy.set_paused(false)
	# Restore the same nonproduction scheduling fixture, not different swarm probabilities.
	copy.stage_rules.swarm.chance=0
	var same:=true
	for frame in range(40):
		state.step(.05,Vector2.LEFT)
		copy.step(.05,Vector2.LEFT)
		same=same and Campaign.comparable(state)==Campaign.comparable(copy)
	verify.call(same,"Wave-boundary movement/next species/RNG/rewards continue identically after Continue")
	for mutation in ["species","kind","speed","contact","wave","profile","rng"]:
		var bad: Dictionary=Snapshot.capture(state)
		match mutation:
			"species":bad.run.enemies[0].species="slime"
			"kind":bad.run.enemies[0].species="wing_imp"
			"speed":bad.run.enemies[0].speed+=1
			"contact":bad.run.enemies[0].contact_damage+=1
			"wave":bad.run.enemies[0].spawn_wave=9
			"profile":bad.run.combat_profile_version=99
			"rng":bad.rng.pop_back()
		var frozen: Dictionary=Campaign.comparable(copy)
		verify.call(not Snapshot.restore(bad,copy) and frozen==Campaign.comparable(copy),"Malformed species state rejected atomically: "+mutation)
	state=quiet()
	state.combat_profile_version=0 # Reconstruct actual GAME019 generic actors.
	state.add_enemy(state.player+Vector2(200,0),"normal","heavy")
	state.enemies[0].hp=27
	state.hp=73
	state.magic.mana=42.5
	var old: Dictionary=Snapshot.capture(state)
	old.version=11
	old.rules=Snapshot.GAME019_RULES
	old.run.erase("combat_profile_version")
	old.rng.resize(6)
	verify.call(Snapshot.restore(old,copy) and copy.combat_profile_version==0 and copy.armor_enabled and copy.hp==73 and copy.magic.mana==42.5 and copy.enemies==state.enemies,"Published11 retains armor and spent resources/generic actor stats without species refill")
	copy.add_enemy(copy.player+Vector2(300,0),"normal","heavy")
	verify.call(is_equal_approx(copy.enemies[-1].speed,37.4) and not copy.enemies[-1].has("species"),"Future spawns in an old continued battle keep old generic stats too")
	DirAccess.remove_absolute(store.path)
