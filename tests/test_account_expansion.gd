extends RefCounted
const Talents = preload("res://scripts/progression/account_talents.gd")
const Wallet = preload("res://scripts/progression/gold_progress.gd")
const RunState = preload("res://scripts/combat/run_state.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const Campaign = preload("res://tests/test_campaign.gd")
const Previous = preload("res://tests/test_account_talents.gd")

static func quiet(levels: Dictionary):
	var state = RunState.new()
	state.start(1300, "viya", levels)
	state.spawn_clock = 999.0
	state._scatter_clock = 999.0
	state.shot_clock = 999.0
	state.stage_rules.swarm.chance = 0.0
	return state

static func run(host, verify: Callable) -> void:
	var directory := "user://talents-six-" + Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(directory)
	wallet_checks(directory, verify)
	combat_checks(verify)
	await ui_checks(host, directory, verify)
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	verify.call(true, "Six account talents reached their final integration check")

static func wallet_checks(directory: String, verify: Callable) -> void:
	var wallet = Previous.funded(directory.path_join("all.cfg"), 6306000)
	var expected := Talents.empty_levels()
	for id in Talents.ROOT_IDS:
		for level in range(3):
			var balance: int = wallet.total
			expected[id] += 1
			verify.call(wallet.purchase_talent(id, level) == OK and wallet.total == balance - [1000, 50000, 1000000][level] and wallet.talent_levels == expected, "Each independent talent buys one exact cumulative stage: %s/%d" % [id, level + 1])
			verify.call(wallet.purchase_talent(id, level) != OK and wallet.talent_levels == expected, "Duplicate purchase cannot advance a different talent: " + id)
	verify.call(wallet.total == 0 and wallet.attack_level == 3, "All eighteen purchases cost exactly 6306000 gold")
	var old := ConfigFile.new()
	old.set_value("gold", "total", 12345)
	old.set_value("gold", "next_stage", 2)
	old.set_value("gold", "last_run", "schema-one")
	old.set_value("account", "schema", 1)
	old.set_value("account", "attack_level", 2)
	old.save(directory.path_join("old.cfg"))
	wallet.path = directory.path_join("old.cfg")
	verify.call(wallet.load_progress() == OK and wallet.attack_level == 2 and wallet.talent_levels.attack_speed == 0 and wallet.total == 12345, "Schema-one account retains its purchased power rank and gold, with the other five talents zero")
	verify.call(wallet.purchase_talent("attack_speed", 0) == OK and wallet.attack_level == 2 and wallet.total == 11345, "Buying a new talent migrates the original purchase atomically")
	var reloaded = Wallet.new()
	reloaded.path = wallet.path
	verify.call(reloaded.load_progress() == OK and reloaded.talent_levels == wallet.talent_levels, "All six account ranks survive an independent reload")
	verify.call(wallet.purchase_talent("not_a_talent", 0) != OK, "Unknown talent cannot spend gold")
	var file := ConfigFile.new()
	file.load(wallet.path)
	for mutation in ["missing", "extra", "float", "rank", "mirror"]:
		var levels: Dictionary = wallet.talent_levels.duplicate(true)
		match mutation:
			"missing": levels.erase("max_hp")
			"extra": levels.extra = 0
			"float": levels.max_hp = 1.0
			"rank": levels.mp_regen = 4
			"mirror": levels.attack_power = 1
		file.set_value("account", "talent_levels", levels)
		file.save(directory.path_join("bad.cfg"))
		reloaded.path = directory.path_join("bad.cfg")
		verify.call(reloaded.load_progress() != OK and not reloaded.loaded, "Malformed six-talent account is rejected: " + mutation)

static func combat_checks(verify: Callable) -> void:
	for level in range(1, 4):
		var levels := Talents.empty_levels()
		levels.attack_speed = level
		levels.max_hp = level
		levels.damage_reduction = level
		levels.hp_regen = level
		levels.mp_regen = level
		var state = quiet(levels)
		verify.call(state.max_hp == 100 + 5 * level and state.hp == state.max_hp, "Maximum-HP account talent starts fully healed at its cumulative percentage")
		verify.call(is_equal_approx(state.stats.rate, 1.0 + 0.02 * level) and is_equal_approx(state.attack_profile("rifle", 1, state.stats.rate).interval, 0.30 / (1.0 + 0.02 * level)), "Attack-speed talent changes actual automatic attack intervals")
		state.add_enemy(state.player + Vector2(100, 0))
		state._auto_fire()
		verify.call(is_equal_approx(state.shot_clock, 0.30 / (1.0 + 0.02 * level)), "Actual rifle scheduling consumes the shared speed profile")
		state.enemies.clear()
		state.bullets.clear()
		state.shot_clock = 999.0
		var total := 0
		for hit in range(100):
			state.hp = state.max_hp
			state.hurt_clock = 0.0
			state.damage_player(10)
			total += state.max_hp - state.hp
		verify.call(total == 1000 - 10 * level, "Small integer hits preserve exactly the requested cumulative damage reduction")
		var remainder: float = state._damage_reduction_remainder
		state.damage_player(10)
		verify.call(state._damage_reduction_remainder == remainder, "Invulnerability rejection cannot earn fractional mitigation")
		state.hp = 50
		state.magic.mana = 0.0
		for frame in range(400):
			state.step(0.05, Vector2.ZERO)
		verify.call(state.hp == 50 + level, "Twenty active seconds restore precisely 1/2/3 account HP")
		verify.call(is_equal_approx(state.magic.mana, 20.0 + level) and is_equal_approx(state.magic.profile(0).mana_regen, 1.0 + 0.05 * level), "MP recovery adds 0.05/0.10/0.15 to the existing one per second")
		state.magic.advance(1000.0, true)
		verify.call(state.magic.mana == 100.0, "Expanded MP recovery still respects maximum mana")
	var levels := Talents.empty_levels()
	for id in Talents.ROOT_IDS:
		levels[id] = 3
	var state = quiet(levels)
	state.hp = 80
	state.hurt_clock = 0.0
	state.damage_player(12)
	state.magic.mana = 25.5
	for frame in range(25):
		state.step(0.05, Vector2.ZERO)
	var restored = RunState.new()
	verify.call(Snapshot.restore(Snapshot.capture(state), restored), "Six bonuses and both fractional accumulators restore through the existing state")
	restored.stage_rules.swarm.chance = 0.0
	restored.set_paused(false)
	var same := true
	for frame in range(150):
		if frame % 25 == 0:
			for current in [state, restored]:
				current.damage_player(8)
		state.step(0.05, Vector2.RIGHT)
		restored.step(0.05, Vector2.RIGHT)
		same = same and Campaign.comparable(state) == Campaign.comparable(restored)
	verify.call(same, "Resumed mitigation, HP/MP recovery, speed, HP and RNG continue identically")
	var before: Dictionary = Campaign.comparable(state)
	state.set_paused(true)
	for frame in range(40):
		state.step(0.05, Vector2.RIGHT)
	state.set_paused(false)
	verify.call(before == Campaign.comparable(state), "Pause freezes all six talents and fractional carry")
	var old = quiet(Talents.from_attack(2))
	old.magic.mana = 23.5
	var legacy: Dictionary = Campaign.pre_scatter(Snapshot.capture(old))
	legacy.version = 4
	legacy.run.erase("account_talent_levels")
	legacy.run.erase("_damage_reduction_remainder")
	verify.call(Snapshot.restore(legacy, restored) and restored.account_talent_levels == Talents.from_attack(2) and restored.magic.mana == 23.5 and restored.max_hp == 100, "Version-four battle preserves the purchased power bonus without granting any new talents")
	for mutation in ["levels", "mirror", "carry"]:
		var bad: Dictionary = Snapshot.capture(state)
		match mutation:
			"levels": bad.run.account_talent_levels.hp_regen = 4
			"mirror": bad.run.account_attack_level = 0
			"carry": bad.run._damage_reduction_remainder = 1.0
		verify.call(not Snapshot.restore(bad, restored), "Invalid expanded battle data is rejected: " + mutation)
	var hero: Dictionary = state.growth.catalog.characters.viya.duplicate(true)
	for skill in hero.skills:
		skill.owner = "six_fixture"
		skill.id = "six_fixture_" + str(skill.effect)
	hero.active_magic.owner = "six_fixture"
	hero.active_magic.upgrade_skill_id = "six_fixture_ultimate"
	state.growth.catalog.characters.six_fixture = hero
	verify.call(state.start(1301, "six_fixture", levels) and state.max_hp == 115 and is_equal_approx(state.stats.rate, 1.06) and is_equal_approx(state.magic.profile(0).mana_regen, 1.15), "Every character uses the shared full account profile")
	var profile: Dictionary = state.stats_profile({"passive_vitality": 2, "passive_haste": 2, "passive_recovery": 2})
	verify.call(profile.max_hp == 161 and is_equal_approx(profile.stats.rate, 1.16 * 1.06) and is_equal_approx(profile.stats.regen, 1.35), "Run vitality/haste/recovery compose with account bonuses")

static func ui_checks(host, directory: String, verify: Callable) -> void:
	Previous.funded(directory.path_join("gold.cfg"), 6306000)
	var ui = Campaign.make_ui(host, directory)
	preload("res://tests/test_campaign.gd").depart(ui)
	ui.pause_game()
	ui._park_battle()
	ui.talents_button.pressed.emit()
	for tab in range(3):
		ui.talent_tabs[tab].pressed.emit()
		verify.call(ui.talent_buy_buttons.size() == 18 and ui.talent_buttons_by_id.size() == 6, "Every actual category contains two three-node chains")
		var ids: Array = ui.talent_buttons_by_id.keys().filter(func(id): return id in Talents.ROOT_IDS)
		for id in ids:
			for level in range(3):
				ui.talent_buttons_by_id[id][level].pressed.emit()
			verify.call(ui.gold_progress.talent_levels[id] == 3, "Real UI purchases all three stages of " + id)
	verify.call(ui.gold_progress.total == 0 and ui.simulation.account_talent_levels == Talents.empty_levels(), "All purchases debit exact gold while preserving the parked battle's original six ranks")
	ui.talents_return_button.pressed.emit()
	preload("res://tests/test_campaign.gd").depart(ui)
	verify.call(ui.simulation.max_hp == 100 and ui.simulation.magic.profile(0).mana_regen == 1.0, "Continue retains pre-purchase HP and MP-recovery values")
	ui.resume_button.pressed.emit()
	ui.pause_game()
	for button in ui.dialog_body.get_children():
		if button is Button and button.text == "새 전투 시작":
			button.pressed.emit()
			break
	ui.confirm_button.pressed.emit()
	verify.call(ui.simulation.max_hp == 115 and is_equal_approx(ui.simulation.stats.rate, 1.06) and is_equal_approx(ui.simulation.stats.damage_reduction, 0.03) and is_equal_approx(ui.simulation.magic.profile(0).mana_regen, 1.15), "Confirmed new battle applies all six newly purchased ranks")
	ui.queue_free()
	await host.get_tree().process_frame
