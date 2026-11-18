extends RefCounted
const State = preload("res://scripts/combat/run_state.gd")
const Modules = preload("res://scripts/combat/weapon_modules.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const Store = preload("res://scripts/progression/run_store.gd")
const Campaign = preload("res://tests/test_campaign.gd")
const Preview = preload("res://scripts/ui/skill_preview.gd")
const Visuals = preload("res://scripts/combat/attack_visuals.gd")
const Defense = preload("res://scripts/combat/defense_rules.gd")

static func quiet(family: String = "gun"):
	var state = State.new()
	if family != "gun":
		# Test-only loadout injection, never another production Viya/class/character.
		var library = state.growth.catalog.weapons
		var hero: Dictionary = library.characters.viya
		hero.families = [family]
		hero.attack_pool = library.entries.values().filter(func(e): return e.kind=="attack" and e.family==family).map(func(e): return e.id)
		hero.starting_attack = hero.attack_pool[0]
		hero.starting_levels = {hero.starting_attack:1}
	state.start(1801,"viya",null,"legacy_arena","weapons_v1")
	state.spawn_clock = 999.0
	state.shot_clock = 999.0
	state._scatter_clock = 999.0
	state.stage_rules.swarm.chance = 0.0
	return state

static func targets(state) -> void:
	for offset in [Vector2(100,0),Vector2(135,20),Vector2(200,0),Vector2(60,80),Vector2(260,70)]:
		state.add_enemy(state.player+offset)
		state.enemies[-1].hp = 100000
		state.enemies[-1].max_hp = 100000

static func damage(state) -> int:
	return state.enemies.reduce(func(sum, enemy): return sum+100000-int(enemy.hp),0)

static func run(host, verify: Callable) -> void:
	catalog_checks(verify)
	defense_checks(verify)
	all_attacks(verify)
	module_checks(verify)
	unique_checks(verify)
	recovery_checks(verify)
	await ui_checks(host,verify)


static func defense_checks(verify: Callable) -> void:
	var state = quiet()
	verify.call(state.armor_enabled and is_equal_approx(float(state.stats.physical_penetration),0.15), "New Viya sortie applies intrinsic physical armor penetration 15%")
	verify.call(float(state.stats.magical_penetration)==0.0 and state.stats.physical_defense==0.0, "Viya has no invented magical penetration or defense")
	verify.call(is_equal_approx(Defense.mitigated_damage(100.0,0.4,0.15),66.0), "15% penetration negates 15% of armor: 40% reduction becomes 34%")
	verify.call(is_equal_approx(Defense.mitigated_damage(100.0,0.0,0.15),100.0), "Armor piercing does not become free raw damage against zero armor")
	verify.call(Defense.valid_supports("other",[],["viya"]) and is_equal_approx(Defense.main_penetration("other",["viya"],"physical"),0.15), "Viya passive supporter contributes 15% to a different main character")
	verify.call(is_equal_approx(Defense.character_penetration("viya","physical"),0.15) and Defense.character_penetration("viya","magical")==0.0, "Viya attack supporter keeps own physical-only intrinsic penetration")
	verify.call(not Defense.valid_supports("viya",[],["viya"]) and not Defense.valid_supports("other",["viya"],["viya"]), "Cannot equip Viya as own/duplicate support")
	state.add_enemy(state.player+Vector2(130,0),"normal","heavy")
	var enemy: Dictionary = state.enemies[-1]
	enemy.hp=300
	enemy.max_hp=300
	state._damage_enemy(int(enemy.id),100.0,"physical")
	verify.call(enemy.hp==225, "Real physical hit takes 75 of 100 raw damage against 30% heavy armor after Viya piercing")
	state._damage_enemy(int(enemy.id),100.0,"magical")
	verify.call(enemy.hp==135, "Real magical hit takes 90 of 100 raw damage with 10% magical resistance; physical piercing is not reused")
	var snap: Dictionary = Snapshot.capture(state)
	verify.call(snap.version==11 and Snapshot.valid(snap,state) and snap.run.armor_enabled, "New armor-enabled run snapshots retain the branch rule")
	var old: Dictionary = snap.duplicate(true)
	old.version=10
	old.rules=Snapshot.fingerprint_previous()
	old.run.erase("armor_enabled")
	old.run.erase("support_attack_ids")
	old.run.erase("support_passive_ids")
	var migrated: Dictionary = Snapshot.upgrade_legacy(old,state)
	verify.call(migrated.version==11 and not migrated.run.armor_enabled and Snapshot.valid(migrated,state), "Existing v10 saves continue unchanged without retroactive armor")
	var legacy = State.new()
	legacy.start(125,"viya",null,"legacy_arena","legacy")
	verify.call(not legacy.armor_enabled and float(legacy.stats.physical_penetration)==0.0, "Legacy damage semantics remain intact")

static func catalog_checks(verify: Callable) -> void:
	var state = quiet()
	var library = state.growth.catalog.weapons
	verify.call(library.error.is_empty() and library.entries.size()==33, "Four8-skill family libraries plus one Viya automatic unique are valid")
	verify.call(state.growth.ruleset=="weapons_v1" and state.growth.pool.size()==18, "New rules select exactly eighteen candidates")
	verify.call(state.growth.pool.filter(func(e):return e.kind=="attack").all(func(e):return e.family=="gun"), "Viya only receives the eight gun-family attacks")
	verify.call(state.growth.owned=={"gun_rifle":1} and state.growth.row_entries("attack").size()==1, "Locked initial state grants only rifle1; automatic unique remains a level-up candidate")
	verify.call(state.magic.config.id=="viya_wave_v1" and state.growth.definition("viya_wave_upgrade_v1").kind=="ultimate", "Independent MP unique and its enhancement point to the right character")
	verify.call(not state.growth.pool.any(func(e):return e.id in ["common_rifle","viya_sigil","viya_ultimate"]), "Old IDs are never silently relabelled as new weapons")
	var original: Dictionary = Campaign.comparable(state)
	verify.call(not state.start(10,"viya",null,"legacy_arena","unknown") and original==Campaign.comparable(state), "Unknown ruleset cannot partly reset a battle")
	var mixed: Dictionary = library.characters.viya.duplicate(true)
	mixed.families = ["gun","sword"]
	mixed.attack_pool = ["gun_rifle","gun_scatter","gun_lance","gun_grenade","sword_slash","sword_spin","sword_dash","sword_wave"]
	verify.call(library.valid_hero(mixed,"viya"), "Generic character data can select an explicit mixed8-skill pool without a fifth family")
	mixed.attack_pool[7] = "gun_rifle"
	verify.call(not library.valid_hero(mixed,"viya"), "Duplicate mixed-pool entries are invalid")
	var different: Dictionary = library.characters.viya.duplicate(true)
	different.skills[0].owner = "other"
	verify.call(not library.valid_hero(different,"viya"), "Foreign automatic unique is not accepted by a character loadout")
	for family in library.FAMILIES:
		var list: Array = library.entries.values().filter(func(e):return e.kind=="attack" and e.family==family)
		verify.call(list.size()==8, "Exactly eight provisional common attacks: "+family)
		for entry in list:
			var shape: Dictionary = entry.levels[0].duplicate(true)
			shape.erase("damage")
			shape.erase("change")
			var final: Dictionary = entry.levels[4].duplicate(true)
			final.erase("damage")
			final.erase("change")
			verify.call(shape!=final and str(entry.levels[4].change).begins_with("진화:"), "Lv5 changes actual attack behavior beyond damage/name: "+entry.id)
	state.growth.owned["gun_scatter"] = 1
	state.growth.owned["gun_lance"] = 1
	state.growth.owned["viya_runebullet_v1"] = 1
	verify.call(not state.growth.eligible().has("gun_grenade") and state.growth.eligible().has("gun_rifle"), "Four-slot attack cap still permits upgrades and blocks a fifth attack")
	state.growth.owned.gun_rifle = 5
	verify.call(not state.growth.eligible().has("gun_rifle"), "Evolved skill cannot be offered an invented sixth level")

static func all_attacks(verify: Callable) -> void:
	var library = quiet().growth.catalog.weapons
	for entry in library.entries.values():
		if entry.kind != "attack":continue
		for rank in range(1,6):
			var state = quiet(str(entry.family))
			targets(state)
			var p: Dictionary = state.attack_profile(str(entry.id),rank,1.0)
			var started: bool = Modules.fire(state,p)
			for frame in range(50):
				Modules.advance(state,0.05)
				state._move_bullets(0.05)
			verify.call(started and damage(state)>0, "Actual shared runtime commits damage for "+entry.id+" Lv."+str(rank))
			verify.call(state.bullets.size()<=state.MAX_BULLETS and state.weapon_events.size()<=Modules.MAX_EVENTS and state.kills==0, "Attack bounds hold without fabricating fixture deaths: "+entry.id+"/"+str(rank))
			if rank in [1,5]:
				verify.call(not p.evolved if rank==1 else p.evolved, "Evolution flag matches live rank: "+entry.id+"/"+str(rank))

static func module_checks(verify: Callable) -> void:
	var state = quiet()
	targets(state)
	state.growth.owned.gun_rifle = 5
	state._auto_fire()
	verify.call(state.bullets.size()==3 and state.weapon_events.size()==1 and state.weapon_events[0].remaining==2, "Evolved rifle emits3 now and queues two timed volleys")
	for frame in range(4):Modules.advance(state,0.05)
	verify.call(state.shots==9 and state.weapon_events.is_empty(), "Three real timed volleys produce nine bullets, not a visual-only evolution")
	state = quiet()
	state.add_enemy(state.player+Vector2(100,0))
	state.add_enemy(state.player+Vector2(200,60))
	for enemy in state.enemies:enemy.hp=10
	Modules.fire(state,state.attack_profile("gun_ricochet",2,1))
	for frame in range(16):state._move_bullets(0.05)
	verify.call(state.kills==2 and state.pickups.size()==2, "A live ricochet redirects into another enemy and rewards each death once")
	state = quiet()
	state.add_enemy(state.player+Vector2(100,0))
	Modules.fire(state,state.attack_profile("gun_rupture",3,1))
	for frame in range(3):state._move_bullets(0.05)
	verify.call(state.shots==4 and state.kills==1, "Impact creates the actual three child projectiles with one committed kill")
	state = quiet("magic")
	state.add_enemy(state.player+Vector2(80,0))
	state.enemies[0].hp=100000
	state.enemies[0].max_hp=100000
	Modules.fire(state,state.attack_profile("magic_frost",1,1))
	verify.call(is_equal_approx(Modules.speed_scale(state.enemies[0]),0.7), "Frost applies actual movement slow")
	state.enemies[0].p=state.player+Vector2(150,0)
	var at: Vector2 = state.enemies[0].p
	state._move_enemies(0.05)
	verify.call(is_equal_approx(at.distance_to(state.enemies[0].p),68*0.7*0.05), "Ground pursuit consumes the shared slow magnitude")
	state = quiet("sword")
	targets(state)
	var from: Vector2 = state.player
	Modules.fire(state,state.attack_profile("sword_dash",1,1))
	verify.call(state.player!=from and damage(state)>0 and state.map_space.valid_position(state.player,30), "Sword dash moves the real actor and hits its terrain-safe swept path")
	state = quiet("bow")
	targets(state)
	Modules.fire(state,state.attack_profile("bow_return",1,1))
	var outward := damage(state)
	for frame in range(25):state._move_bullets(0.05)
	verify.call(damage(state)>outward and state.bullets.is_empty(), "Returning arrows travel back to the player through the real projectile path")
	state = quiet()
	state.start(1801,"viya",null,"outskirts_trial","weapons_v1")
	state.player=Vector2(1100,1175)
	state.add_enemy(Vector2(1600,1175))
	state.enemies[0].hp=100000
	state.enemies[0].max_hp=100000
	Modules.fire(state,state.attack_profile("gun_lance",5,1))
	for frame in range(15):state._move_bullets(0.05)
	verify.call(state.enemies[0].hp==100000 and state.bullets.is_empty(), "New evolved piercing projectiles still stop at solid terrain")

static func unique_checks(verify: Callable) -> void:
	var state = quiet()
	targets(state)
	var p: Dictionary = state.attack_profile("viya_runebullet_v1",1,1)
	Modules.fire(state,p)
	for frame in range(3):state._move_bullets(0.05)
	verify.call(state.enemies[0].get("weapon_status",{}).get("mark",0)>0 and state.magic.casts==0, "Viya automatic rune bullets mark an enemy without a manual cast")
	state.growth.owned.viya_wave_upgrade_v1=3
	state._refresh_stats()
	var before: int = state.enemies[0].hp
	var ticket: int = state.magic.ticket
	verify.call(state.cast_ultimate(ticket) and state.magic.mana==60 and state.magic.casts==1, "Manual rune wave keeps40MP cost/no cooldown and its independent cast counter")
	verify.call(before-state.enemies[0].hp==220 and state.enemies[0].weapon_status.mark==0, "Rank3 wave consumes a mark for190base+30extra damage")
	verify.call(not state.cast_ultimate(ticket) and state.magic.mana==60, "Duplicate ultimate input cannot queue another wave or spend twice")
	state = quiet()
	targets(state)
	state.growth.owned.viya_wave_upgrade_v1=5
	state.growth.level=50
	state._refresh_stats()
	state.cast_ultimate(state.magic.ticket)
	verify.call(state.weapon_events.size()==1 and state.magic.mana==60, "Rank5 manual evolution schedules a second wave for one MP charge")
	verify.call(Snapshot.valid(Snapshot.capture(state),state), "Pending evolved manual wave is valid resumable state")
	var hit: int = damage(state)
	for frame in range(4):Modules.advance(state,0.05)
	verify.call(damage(state)>hit and state.magic.casts==1 and state.magic.mana==60, "Second wave commits additional hits without a second manual cast")

static func recovery_checks(verify: Callable) -> void:
	var state = quiet()
	targets(state)
	state.growth.level=50 # Explicit rank fixture, no false claim of natural progression.
	state.growth.owned.gun_rifle=5
	state._auto_fire()
	Modules.fire(state,state.attack_profile("gun_grenade",5,1))
	state._move_bullets(0.05)
	state.set_paused(true)
	var store=Store.new()
	store.path="user://weapons-"+Crypto.new().generate_random_bytes(8).hex_encode()+".save"
	var restored=State.new()
	verify.call(store.save_current(state)==OK and store.load_saved(restored)==OK and Snapshot.restore(store.pending,restored), "Binary save restores new rules, live bullets, status and pending burst/explosion events")
	verify.call(Campaign.comparable(state)==Campaign.comparable(restored), "Saved new skill state is exact before explicit Continue")
	state.set_paused(false)
	restored.set_paused(false)
	var same:=true
	for frame in range(60):
		Modules.advance(state,0.05)
		Modules.advance(restored,0.05)
		state._move_bullets(0.05)
		restored._move_bullets(0.05)
		same=same and Campaign.comparable(state)==Campaign.comparable(restored)
	verify.call(same,"Restored bursts/echoes/children/HP/rewards and six RNG streams match60 uninterrupted frames")
	for mutation in ["rules","mode","foreign","left","count","rank","slow","rng"]:
		state = quiet()
		targets(state)
		state.growth.level=50
		state.growth.owned.gun_rifle=5
		state._auto_fire()
		state._move_bullets(0.05)
		var bad: Dictionary = Snapshot.capture(state)
		match mutation:
			"rules":bad.growth.ruleset="unknown"
			"mode":bad.run.weapon_events[0].profile.mode="unknown"
			"foreign":bad.run.bullets[0].weapon.id="magic_fire"
			"left":bad.run.weapon_events[0].left=NAN
			"count":bad.run.weapon_events[0].remaining=999
			"rank":bad.run.bullets[0].weapon.rank=6
			"slow":bad.run.enemies[0].weapon_status={"mark":0.0,"slow":2.0,"slow_left":1.0}
			"rng":bad.rng.pop_back()
		var frozen: Dictionary = Campaign.comparable(restored)
		verify.call(not Snapshot.restore(bad,restored) and frozen==Campaign.comparable(restored), "Malformed/foreign new skill state is rejected atomically: "+mutation)
	state=quiet()
	targets(state)
	state.growth.owned.gun_rifle=5
	state._auto_fire()
	state.set_paused(true)
	var frozen: Dictionary = Campaign.comparable(state)
	state.step(0.05,Vector2.RIGHT)
	verify.call(frozen==Campaign.comparable(state),"Pause freezes new attacks, delayed volleys, status and projectiles")
	state.set_paused(false)
	state.grant_xp(30)
	frozen=Campaign.comparable(state)
	state.step(0.05,Vector2.RIGHT)
	verify.call(frozen==Campaign.comparable(state),"Level-up choice freezes the new attack event queue too")
	DirAccess.remove_absolute(store.path)

static func ui_checks(host, verify: Callable) -> void:
	var ui=load("res://scenes/main.tscn").instantiate()
	var folder: String = "user://weapons-ui-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	ui.run_store.path=folder.path_join("battle.save")
	ui.gold_progress.path=folder.path_join("gold.cfg")
	ui.settings_path=folder.path_join("settings.cfg")
	host.get_tree().root.add_child(ui)
	ui.set_physics_process(false)
	verify.call(ui.new_run_ruleset=="weapons_v1", "Unmodified production main scene defaults to the new weapon rules")
	Campaign.depart(ui)
	verify.call(ui.simulation.growth.ruleset=="weapons_v1" and ui.simulation.map_id=="prologue_wall" and ui.simulation.structures.size()==32, "Actual lobby/stage launch connects new skills and existing supply/map systems")
	verify.call(ui.attack_slots[0].text.contains("연발 소총") and ui.attack_slots[1].text=="--" and state_initial_power(ui.simulation), "Actual HUD/initial stats retain rifle-only locked baseline")
	ui.simulation.grant_xp(30)
	ui._physics_process(0)
	verify.call(ui.choice_buttons.size()==3 and ui.simulation.growth.offer.all(func(id): return ui.simulation.growth.definition(id).get("family","gun")=="gun"), "Actual level-up still presents three choices without foreign-family attacks")
	for button in ui.choice_buttons:
		verify.call(button.text.contains("선택 시 변화") and button.get_meta("skill_preview")==Preview.build(ui.simulation,ui.simulation.growth.offer[ui.choice_buttons.find(button)]), "Production card uses the exact new combat profile")
	ui.choice_buttons[0].pressed.emit()
	ui.begin_run()
	ui.simulation.grant_xp(30)
	ui.simulation.growth.offer.assign(["viya_runebullet_v1"])
	ui._physics_process(0)
	ui.choice_buttons[0].pressed.emit()
	ui._update_hud()
	verify.call(ui.simulation.growth.skill_level("viya_runebullet_v1")==1 and ui.attack_slots[1].text.contains("진홍 각인탄"), "Real level-up acquisition adds the automatic unique instead of granting it at departure")
	ui.begin_run()
	var state=ui.simulation
	state.growth.owned.gun_rifle=4
	state.growth.level=4
	state.grant_xp(state.growth.threshold())
	state.growth.offer.assign(["gun_rifle"]) # Deterministic evolution card fixture.
	ui._physics_process(0)
	verify.call(ui.choice_buttons[0].text.contains("Lv.5 최종 진화") and ui.choice_buttons[0].text.contains("3방향"), "Real Lv4->5 choice explains the behavioral evolution")
	var ticket: int = state.growth.ticket
	ui.choice_buttons[0].pressed.emit()
	ui._update_hud()
	verify.call(state.growth.skill_level("gun_rifle")==5 and ui.attack_slots[0].text.contains("진화") and not state.select_skill("gun_rifle",ticket), "Actual card upgrades once and HUD marks final evolution")
	var before: Dictionary = Campaign.comparable(state)
	ui.view.queue_redraw()
	await host.get_tree().process_frame
	verify.call(before==Campaign.comparable(state), "New weapon/field/mark/evolution drawing is read-only")
	ui.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	verify.call(ui.run_store.pending.growth.ruleset=="weapons_v1" and ui.run_store.pending.growth.owned.gun_rifle==5, "Focus-loss save records actual new skills without a reroll")
	ui.queue_free()
	await host.get_tree().process_frame
	for file in DirAccess.get_files_at(folder):DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)

static func state_initial_power(state) -> bool:
	var p: Dictionary = state.attack_profile("gun_rifle",1,1)
	return state.hp==100 and state.magic.mana==100 and state.stats.speed==235 and p.damage==10 and p.interval==0.30 and p.reach==520 and p.speed==920 and state.stats.crit==0 and state.stats.regen==0
