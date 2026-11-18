extends RefCounted
const Talents = preload("res://scripts/progression/account_talents.gd")
const Wallet = preload("res://scripts/progression/gold_progress.gd")
const RunState = preload("res://scripts/combat/run_state.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const Campaign = preload("res://tests/test_campaign.gd")
const Previous = preload("res://tests/test_account_talents.gd")

static func levels_for(id: String, rank: int) -> Dictionary:
	var levels := Talents.empty_levels()
	while not id.is_empty():
		levels[id] = rank
		id = str(Talents.DEFINITIONS[id].get("parent", ""))
	return levels

static func quiet(levels: Dictionary):
	var state = RunState.new()
	state.start(1400, "viya", levels)
	state.spawn_clock = 999.0
	state._scatter_clock = 999.0
	state.shot_clock = 999.0
	state.stage_rules.swarm.chance = 0.0
	state.gold_drop_chance = 0.0
	return state

static func run(host, verify: Callable) -> void:
	var directory := "user://tree-test-" + Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(directory)
	wallet_checks(directory, verify)
	for rank in range(1, 4):
		combat_checks(rank, verify)
	recovery_checks(verify)
	await ui_checks(host, directory, verify)
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	verify.call(true, "Full eighteen-node tree reached its last integration check")

static func wallet_checks(directory: String, verify: Callable) -> void:
	verify.call(Talents.IDS.size() == 18 and Talents.CHAINS.size() == 3, "Exactly eighteen nodes form three two-chain categories")
	var wallet = Previous.funded(directory.path_join("locks.cfg"), 18918000)
	var balance: int = wallet.total
	verify.call(wallet.purchase_talent("crit_chance", 0) != OK and wallet.total == balance, "Locked descendant cannot spend gold through the actual purchase API")
	verify.call(wallet.purchase_talent("attack_power", 0) == OK and wallet.purchase_talent("crit_chance", 0) == OK and wallet.purchase_talent("crit_damage", 0) == OK, "Same-level root-child-grandchild purchases unlock independently of the other chain")
	balance = wallet.total
	verify.call(wallet.purchase_talent("crit_chance", 1) != OK and wallet.purchase_talent("crit_damage", 1) != OK and wallet.total == balance, "Lv.1 ancestors cannot unlock a descendant's Lv.2")
	verify.call(wallet.purchase_talent("attack_power", 1) == OK and wallet.purchase_talent("crit_chance", 1) == OK and wallet.purchase_talent("crit_damage", 1) == OK, "Advancing each immediate parent to Lv.2 unlocks only the matching purchase")
	verify.call(wallet.talent_levels.attack_speed == 0 and wallet.talent_levels.max_hp == 0, "Purchasing one branch does not require another branch")
	wallet = Previous.funded(directory.path_join("full.cfg"), 18918000)
	for id in Talents.IDS:
		for rank in range(3):
			var before: int = wallet.total
			verify.call(wallet.purchase_talent(id, rank) == OK and wallet.total == before - [1000, 50000, 1000000][rank], "Actual exact-price tree purchase: %s/%d" % [id, rank + 1])
	verify.call(wallet.total == 0 and wallet.talent_levels.values().all(func(rank): return rank == 3), "All54 purchases debit18918000 and reach only the defined cap")
	var file := ConfigFile.new()
	file.set_value("gold", "total", 10000)
	file.set_value("gold", "next_stage", 2)
	file.set_value("gold", "last_run", "legacy-six")
	file.set_value("account", "schema", 2)
	file.set_value("account", "attack_level", 3)
	var old := {}
	for id in Talents.ROOT_IDS:
		old[id] = 3
	file.set_value("account", "talent_levels", old)
	file.save(directory.path_join("legacy.cfg"))
	wallet.path = directory.path_join("legacy.cfg")
	verify.call(wallet.load_progress() == OK and wallet.attack_level == 3 and wallet.talent_levels.crit_chance == 0 and wallet.total == 10000, "Schema2 preserves all six paid roots and grants no free descendants")
	verify.call(wallet.purchase_talent("crit_chance", 0) == OK and wallet.total == 9000, "First new-node purchase upgrades a legacy account atomically")
	file.load(wallet.path)
	var invalid: Dictionary = wallet.talent_levels.duplicate(true)
	invalid.crit_damage = 2
	file.set_value("account", "talent_levels", invalid)
	file.save(wallet.path)
	verify.call(wallet.load_progress() != OK and not wallet.loaded, "Saved descendant rank above its immediate parent is rejected")

static func combat_checks(rank: int, verify: Callable) -> void:
	var state = quiet(levels_for("crit_damage", rank))
	verify.call(is_equal_approx(state.stats.crit, 0.01 * rank) and is_equal_approx(state.stats.crit_damage, 2.0 + 0.05 * rank), "Crit chance and multiplier compose through actual account stats")
	state.stats.crit = 1.0 # Force a crit for an exact damage oracle.
	state.add_enemy(state.player + Vector2(100, 0))
	state.enemies[0].hp = 2000
	state.enemies[0].max_hp = 2000
	state._damage_enemy(state.enemies[0].id, 100.0)
	var expected := int(ceil(snappedf(100.0 * (1.0 + 0.05 * rank) * (2.0 + 0.05 * rank), 0.000001)))
	verify.call(state.enemies[0].hp == 2000 - expected, "Real shared damage path consumes the upgraded critical multiplier")
	state = quiet(levels_for("projectile_speed", rank))
	state.add_enemy(state.player + Vector2(100, 0))
	state._auto_fire()
	verify.call(is_equal_approx(state.bullets[0].speed, 920.0 * (1.0 + 0.05 * rank)), "Actual friendly projectile uses account flight speed")
	state.add_enemy(state.player + Vector2(300, 0), "normal", "ranged")
	state.enemies[-1].windup = 0.01
	state._tick_ranged(state.enemies[-1], 0.05)
	verify.call(is_equal_approx(state.enemy_bullets[0].velocity.length(), state.stage_rules.ranged.bullet_speed), "Account projectile speed never accelerates hostile fire")
	state = quiet(levels_for("attack_range", rank))
	state.add_enemy(state.player + Vector2(520.0 * (1.0 + 0.03 * rank) - 1, 0))
	state._auto_fire()
	verify.call(state.bullets.size() == 1, "Actual target search reaches beyond the unupgraded range")
	verify.call(is_equal_approx(state.attack_profile("grenade", 1, 1.0).radius, 68.0 * (1.0 + 0.03 * rank)) and is_equal_approx(state.attack_profile("chain", 1, 1.0).link_range, 160.0 * (1.0 + 0.03 * rank)) and is_equal_approx(state.magic.profile(0).radius, 460.0 * (1.0 + 0.03 * rank)), "Range scales actual burst/link/ultimate profiles without scaling hit count or cosmetic chain width")
	state = quiet(levels_for("invulnerability", rank))
	var start: Vector2 = state.player
	state.step(0.05, Vector2.RIGHT)
	verify.call(is_equal_approx(state.player.x - start.x, 235.0 * (1.0 + 0.02 * rank) * 0.05), "Movement talent changes real movement distance")
	state.damage_player(1)
	verify.call(is_equal_approx(state.hurt_clock, 0.85 + 0.03 * rank) and Snapshot.valid(Snapshot.capture(state), state), "New hit-lock duration is applied and allowed by save validation")
	state = quiet(levels_for("knockback_resist", rank))
	start = state.player
	state.add_enemy(start - Vector2(20, 0), "normal", "flier")
	state._move_enemies(0.05)
	verify.call(is_equal_approx(state.player.x - start.x, 18.0 * (1.0 - 0.05 * rank)), "A real flier hit pushes the player by the resisted distance")
	var after: Vector2 = state.player
	state._move_enemies(0.05)
	verify.call(state.player == after, "Invulnerability blocks repeated formation knockback as well as repeated damage")
	state = quiet(levels_for("status_resist", rank))
	state.enemy_bullets.append({"p": state.player - Vector2(50, 0), "velocity": Vector2(2000, 0), "life": 1.0, "damage": 8})
	state._move_enemy_bullets(0.05)
	verify.call(is_equal_approx(state._slow_left, 1.0 - 0.05 * rank), "Confirmed ranged projectile hit applies the resisted status duration")
	start = state.player
	state.step(0.05, Vector2.RIGHT)
	verify.call(is_equal_approx(state.player.x - start.x, 235.0 * 0.85 * 0.05), "Slow status has an actual movement effect")
	state = quiet(levels_for("healing_efficiency", rank))
	state.hp = 50
	state._heal_hp(10.0)
	verify.call(is_equal_approx(state.hp - 50 + state._regen_remainder, 10.0 * (1.0 + 0.05 * rank)), "HP efficiency affects real fractional healing without granting extra maximum HP")
	verify.call(state.selection_health(80, 100, 120) == 80 + int(floor(20.0 * (1.0 + 0.05 * rank) + 0.000000001)), "Vitality selection healing follows the explicitly defined healing efficiency")
	state = quiet(levels_for("mana_cost_reduction", rank))
	var cost := 40.0 * (1.0 - 0.02 * rank)
	verify.call(state.magic.mana == 100.0 + 5.0 * rank and is_equal_approx(state.magic.effective_cost(), cost), "Maximum mana and cost reduction derive from departure talents")
	var ticket: int = state.magic.ticket
	verify.call(state.cast_ultimate(ticket) and is_equal_approx(state.magic.mana, 100.0 + 5.0 * rank - cost), "Actual ultimate deducts the reduced cost")
	verify.call(not state.cast_ultimate(ticket), "Reduced cost does not bypass duplicate-input protection")
	state.magic.advance(1000.0, true)
	verify.call(state.magic.mana == 100.0 + 5.0 * rank, "Regeneration respects the upgraded maximum mana")

static func recovery_checks(verify: Callable) -> void:
	var range_state = quiet(levels_for("attack_range", 3))
	range_state.add_enemy(range_state.player + Vector2(73, 0))
	range_state.enemies[0].hp = 1000
	range_state.enemies[0].max_hp = 1000
	var grenade: Dictionary = range_state.attack_profile("grenade", 1, 1.0)
	range_state._burst(range_state.player, grenade.radius, grenade.damage, "blast")
	verify.call(range_state.enemies[0].hp == 984 and is_equal_approx(range_state.effects[-1].radius, 74.12), "Expanded real burst hits a target outside its original68 radius and draws the actual boundary")
	range_state.enemies.clear()
	range_state.growth.owned.common_chain = 1
	for offset in [200, 373]:
		range_state.add_enemy(range_state.player + Vector2(offset, 0))
		range_state.enemies[-1].hp = 1000
		range_state.enemies[-1].max_hp = 1000
	range_state._tick_skills(0.0)
	verify.call(range_state.enemies.all(func(enemy): return enemy.hp == 989), "Actual chain hits its next target173 units away through the upgraded link range")
	var state = quiet(levels_for("kill_heal", 3))
	state.hp = 50
	for index in range(50):
		state.add_enemy(state.player + Vector2(200, 0))
	var ids: Array = state.enemies.map(func(enemy): return enemy.id)
	for id in ids:
		state._damage_enemy(id, 10000)
	var actual: float = state.hp - 50 + state._regen_remainder
	verify.call(is_equal_approx(actual, 0.90 * 1.15) and is_equal_approx(state._kill_heal_used, 0.90), "Mass kills cap base healing at0.9 per active second, before efficiency")
	state._damage_enemy(ids[0], 10000)
	verify.call(is_equal_approx(state.hp - 50 + state._regen_remainder, actual), "Duplicate death requests cannot pay HP again")
	var restored = RunState.new()
	verify.call(Snapshot.restore(Snapshot.capture(state), restored), "Kill-heal budget and fractional HP save successfully")
	restored.stage_rules.swarm.chance = 0.0
	restored.set_paused(false)
	var same := true
	for frame in range(90):
		state.step(0.05, Vector2.UP)
		restored.step(0.05, Vector2.UP)
		same = same and Campaign.comparable(state) == Campaign.comparable(restored)
	verify.call(same, "Kill-heal rate limits and recovery continue exactly after restore")
	var before_heal: float = state.hp + state._regen_remainder
	state.add_enemy(state.player + Vector2(200, 0))
	state._damage_enemy(state.enemies[-1].id, 10000)
	verify.call(is_equal_approx(state.hp + state._regen_remainder - before_heal, 0.15 * 1.15), "A later active-second window permits a new capped kill heal")
	var full := Talents.empty_levels()
	for id in Talents.IDS:
		full[id] = 3
	state = quiet(full)
	state.hp = 80
	state.apply_slow(1.0)
	state.damage_player(8)
	state.magic.mana = 111.25
	verify.call(Snapshot.valid(Snapshot.capture(state), state) and Snapshot.restore(Snapshot.capture(state), restored) and restored.magic.mana == 111.25 and restored._slow_left == state._slow_left and restored.hurt_clock == state.hurt_clock, "All eighteen bonuses, boosted mana, slow and longer invulnerability survive recovery")
	restored.set_paused(false)
	same = true
	for frame in range(25):
		state.step(0.05, Vector2.RIGHT)
		restored.step(0.05, Vector2.RIGHT)
		same = same and Campaign.comparable(state) == Campaign.comparable(restored)
	verify.call(same and state._slow_left == 0.0, "Restored slow expires at the same time while moving/healing and regenerating boosted mana")
	var old: Dictionary = Campaign.pre_scatter(Snapshot.capture(quiet(Talents.from_attack(2))))
	old.version = 5
	var roots := {}
	for id in Talents.ROOT_IDS:
		roots[id] = old.run.account_talent_levels[id]
	old.run.account_talent_levels = roots
	for field in ["_slow_left", "_kill_heal_clock", "_kill_heal_used"]:
		old.run.erase(field)
	verify.call(Snapshot.restore(old, restored) and restored.account_attack_level == 2 and restored.account_talent_levels.crit_chance == 0, "Version5 preserves its six roots and does not grant new nodes or statuses")
	for field in ["_slow_left", "_kill_heal_clock", "_kill_heal_used"]:
		var bad: Dictionary = Snapshot.capture(state)
		bad.run[field] = 100.0
		verify.call(not Snapshot.restore(bad, restored), "Out-of-range battle timer/budget is rejected: " + field)

static func ui_checks(host, directory: String, verify: Callable) -> void:
	Previous.funded(directory.path_join("gold.cfg"), 18918000)
	var ui = Campaign.make_ui(host, directory)
	ui.talents_button.pressed.emit()
	verify.call(ui.talent_buttons_by_id.size() == 6 and ui.talent_buy_buttons.size() == 18 and ui._talent_grid.columns == 2, "Actual lobby renders two three-deep chains with18 tier buttons")
	verify.call(ui.talent_buttons_by_id.crit_chance[0].disabled and ui.talent_buttons_by_id.crit_chance[0].text.contains("Lv.1 필요"), "Locked child shows its required parent level")
	ui.talent_buttons_by_id.crit_chance[0].pressed.emit()
	verify.call(ui.gold_progress.total == 18918000 and ui.gold_progress.talent_levels.crit_chance == 0, "Forged press of a disabled child still cannot buy")
	ui.talent_buttons_by_id.attack_power[0].pressed.emit()
	verify.call(not ui.talent_buttons_by_id.crit_chance[0].disabled and ui.talent_buttons_by_id.crit_chance[1].disabled, "Buying rootLv.1 refreshes the exact child tier lock")
	ui.talent_buttons_by_id.crit_chance[0].pressed.emit()
	verify.call(not ui.talent_buttons_by_id.crit_damage[0].disabled and ui.talent_buttons_by_id.crit_chance[1].disabled, "Buying childLv.1 unlocks grandchildLv.1 while preserving Lv.2 locks")
	ui.root_ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ui.root_ui.size = Vector2(853, 384)
	ui._apply_layout()
	await host.get_tree().process_frame
	verify.call(ui._talent_grid.columns == 1 and ui._scroll.get_v_scroll_bar().max_value > ui._scroll.get_v_scroll_bar().page, "Compact tree stacks chains and scrolls to every node")
	for tab in range(3):
		ui.talent_tabs[tab].pressed.emit()
		var chains: Array = Talents.CHAINS[["attack", "defense", "recovery"][tab]]
		for chain in chains:
			for id in chain:
				while ui.gold_progress.talent_levels[id] < 3:
					var rank: int = ui.gold_progress.talent_levels[id]
					var before: int = ui.gold_progress.talent_levels[id]
					ui.talent_buttons_by_id[id][rank].pressed.emit()
					if ui.gold_progress.talent_levels[id] == before:
						verify.call(false, "Full actual UI tree purchase failed: " + id)
						ui.queue_free()
						return
	verify.call(ui.gold_progress.total == 0 and ui.gold_progress.talent_levels.values().all(func(rank): return rank == 3), "Actual UI completes all54 purchases with exact remaining gold")
	ui.talents_return_button.pressed.emit()
	preload("res://tests/test_campaign.gd").depart(ui)
	verify.call(ui.simulation.magic.maximum_mana() == 115.0 and is_equal_approx(ui.simulation.magic.effective_cost(),37.6) and is_equal_approx(ui.simulation.stats.crit_damage,2.15) and ui.mana_bar.max_value == 115.0, "Real departure/HUD consume full-tree magic and crit profiles")
	ui.queue_free()
	await host.get_tree().process_frame
