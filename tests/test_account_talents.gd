extends RefCounted
const Wallet = preload("res://scripts/progression/gold_progress.gd")
const Talents = preload("res://scripts/progression/account_talents.gd")
const RunState = preload("res://scripts/combat/run_state.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const Campaign = preload("res://tests/test_campaign.gd")

static func funded(path: String, amount: int):
	var wallet = Wallet.new()
	wallet.path = path
	wallet.load_progress()
	wallet.settle({"outcome": "cleared", "run_id": "test-funds", "stage": 1, "gold_reward": amount})
	return wallet

static func run(host, verify: Callable) -> void:
	var directory := "user://talent-test-" + Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(directory)
	wallet_checks(directory, verify)
	combat_checks(verify)
	await ui_checks(host, directory, verify)
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	verify.call(true, "Account talent suite reached its final integration check")

static func wallet_checks(directory: String, verify: Callable) -> void:
	var wallet = Wallet.new()
	wallet.path = directory.path_join("new.cfg")
	verify.call(wallet.load_progress() == OK and wallet.attack_level == 0 and wallet.total == 0, "Fresh accounts get no free gold or talent levels")
	verify.call(wallet.purchase_attack(0) != OK and not FileAccess.file_exists(wallet.path), "Insufficient funds never create an upgrade save")
	var legacy := ConfigFile.new()
	legacy.set_value("gold", "total", 1051000)
	legacy.set_value("gold", "next_stage", 2)
	legacy.set_value("gold", "last_run", "legacy-clear")
	legacy.set_value("other", "keep", 17)
	wallet.path = directory.path_join("legacy.cfg")
	legacy.save(wallet.path)
	verify.call(wallet.load_progress() == OK and wallet.attack_level == 0 and wallet.total == 1051000, "Legacy wallet loads with its exact gold and zero talents")
	var other = Wallet.new()
	other.path = wallet.path
	other.load_progress()
	for level in range(3):
		var before: int = wallet.total
		verify.call(wallet.purchase_attack(level) == OK and wallet.attack_level == level + 1 and wallet.total == before - [1000, 50000, 1000000][level], "Sequential purchase charges the requested exact price at step " + str(level + 1))
		verify.call(wallet.purchase_attack(level) != OK and wallet.total == before - [1000, 50000, 1000000][level], "Duplicate expected-level request cannot charge twice")
		var reloaded = Wallet.new()
		reloaded.path = wallet.path
		verify.call(reloaded.load_progress() == OK and reloaded.attack_level == level + 1 and reloaded.total == wallet.total and reloaded.next_stage == 2 and reloaded.last_run == "legacy-clear", "Gold and account level persist together without changing stage/settlement identity")
	verify.call(wallet.total == 0 and wallet.purchase_attack(3) != OK, "Three upgrades cost 1051000 in total and cannot exceed stage three")
	verify.call(other.purchase_attack(0) == ERR_BUSY and other.settle({"outcome": "cleared", "run_id": "stale-clear", "stage": 2, "gold_reward": 100}) == ERR_BUSY, "Stale account instances cannot spend old funds or overwrite the purchased level on settlement")
	var saved := ConfigFile.new()
	saved.load(wallet.path)
	verify.call(saved.get_value("other", "keep") == 17 and saved.get_value("account", "attack_level") == 3, "Atomic account updates retain unrelated existing keys")
	wallet = funded(directory.path_join("failed.cfg"), 1000)
	DirAccess.make_dir_absolute(wallet.path + ".tmp")
	verify.call(wallet.purchase_attack(0) != OK and wallet.total == 1000 and wallet.attack_level == 0, "Write failure leaves both gold and talent level unchanged in memory")
	other.path = wallet.path
	other.load_progress()
	verify.call(other.total == 1000 and other.attack_level == 0, "Write failure also preserves both values on disk")
	DirAccess.remove_absolute(wallet.path + ".tmp")
	verify.call(wallet.purchase_attack(0) == OK and wallet.total == 0 and wallet.attack_level == 1, "The failed exact-balance purchase can be retried once")
	wallet = funded(directory.path_join("poor.cfg"), 999)
	verify.call(wallet.purchase_attack(0) != OK and wallet.total == 999 and wallet.attack_level == 0, "A balance one gold below the price cannot buy a talent")
	for value in [-1, 4, 1.0, "1", null]:
		saved.set_value("account", "attack_level", value)
		saved.save(directory.path_join("corrupt.cfg"))
		other.path = directory.path_join("corrupt.cfg")
		verify.call(other.load_progress() == ERR_FILE_CORRUPT and not other.loaded and other.purchase_attack(0) != OK, "Malformed account level blocks purchases: " + str(value))

static func combat_checks(verify: Callable) -> void:
	var state = RunState.new()
	for level in range(4):
		verify.call(state.start(1200, "viya", level) and is_equal_approx(state.stats.power, 1.0 + 0.05 * level), "Shared account multiplier applies on departure at step " + str(level))
		state.add_enemy(state.player + Vector2(100, 0))
		state.enemies[0].hp = 1000
		state.enemies[0].max_hp = 1000
		state.cast_ultimate(state.magic.ticket)
		verify.call(state.enemies[0].hp == 900 - 5 * level and state.magic.mana == 60.0, "Actual ultimate damage includes the account bonus without changing mana cost")
	var before: Dictionary = Campaign.comparable(state)
	verify.call(not state.start(1200, "viya", 4) and before == Campaign.comparable(state), "Invalid talent input cannot partially restart an existing battle")
	var hero: Dictionary = state.growth.catalog.characters.viya.duplicate(true)
	for skill in hero.skills:
		skill.owner = "test_account_hero"
		skill.id = "test_account_" + str(skill.effect)
	hero.active_magic.owner = "test_account_hero"
	hero.active_magic.upgrade_skill_id = "test_account_ultimate"
	state.growth.catalog.characters.test_account_hero = hero
	verify.call(state.start(1201, "test_account_hero", 2) and is_equal_approx(state.stats.power, 1.10), "A second character fixture uses the same account talent with no Viya-specific damage branch")
	state.start(1202, "viya", 2)
	state.spawn_clock = 999.0
	state.magic.mana = 23.5
	var restored = RunState.new()
	verify.call(Snapshot.restore(Snapshot.capture(state), restored) and restored.account_attack_level == 2 and restored.magic.mana == 23.5, "Battle snapshot retains the departure talent and spent MP")
	restored.set_paused(false)
	verify.call(Campaign.comparable(state) == Campaign.comparable(restored), "Restored bonus does not alter actors, resources, offers or RNG")
	var legacy: Dictionary = Snapshot.capture(state)
	legacy.version = 3
	legacy.rules = Snapshot.GAME011_RULES
	legacy.run.erase("account_attack_level")
	verify.call(Snapshot.restore(legacy, restored) and restored.account_attack_level == 0 and restored.magic.mana == 23.5 and is_equal_approx(restored.stats.power, 1.0), "Pre-talent version-three battles migrate with their original zero account bonus")
	var bad: Dictionary = Snapshot.capture(state)
	bad.run.account_attack_level = 4
	verify.call(not Snapshot.restore(bad, restored), "Invalid serialized account bonus is rejected")
	state.start(1203, "viya", 2)
	state.growth.owned.passive_power = 2
	state._refresh_stats()
	verify.call(is_equal_approx(state.stats.power, 1.30 * 1.10), "Run power passive composes with the account multiplier without changing its rank scaling")
	state.start(1204, "viya", 1)
	state.add_enemy(state.player + Vector2(100, 0))
	state._auto_fire()
	state._move_bullets(0.2)
	verify.call(state.enemies[0].hp == 9, "Actual ordinary rifle projectile includes the account bonus and rounds fractional damage upward")

static func callback(button: Button) -> Callable:
	return button.get_signal_connection_list("pressed")[0].callable

static func ui_checks(host, directory: String, verify: Callable) -> void:
	var wallet = funded(directory.path_join("gold.cfg"), 1051000)
	var ui = Campaign.make_ui(host, directory)
	verify.call(ui.simulation.phase == RunState.Phase.READY and ui.dialog_body.get_child(0).text.contains("메인 로비") and ui.overlay.color.a == 1.0, "Actual start scene opens an opaque temporary main lobby")
	ui.talents_button.pressed.emit()
	verify.call(ui._talents_open and ui.talent_tabs.size() == 3 and ui.talent_buy_buttons.size() == 6, "Lobby opens attack/defense/recovery tabs with two attack talents, each with three stages")
	var stale: Callable = callback(ui.talent_buy_buttons[0])
	for index in [1, 2]:
		ui.talent_tabs[index].pressed.emit()
		verify.call(ui.talent_buttons_by_id.size() == 2 and ui.talent_buy_buttons.size() == 6, "Defense and recovery each expose two three-stage talents")
	stale.call()
	verify.call(ui.gold_progress.attack_level == 0 and ui.gold_progress.total == 1051000, "Old purchase callbacks cannot buy from a different category")
	ui.talent_tabs[0].pressed.emit()
	verify.call(ui.talent_buy_buttons[0].text.contains("1,000") and ui.talent_buy_buttons[1].text.contains("50,000") and ui.talent_buy_buttons[2].text.contains("1,000,000") and ui.talent_buy_buttons[1].disabled, "Actual UI shows all requested prices and locks later stages")
	stale = callback(ui.talent_buy_buttons[0])
	ui.talent_buy_buttons[0].pressed.emit()
	stale.call()
	verify.call(ui.gold_progress.total == 1050000 and ui.gold_progress.attack_level == 1 and ui.talent_buy_buttons[0].disabled and not ui.talent_buy_buttons[1].disabled, "Real button upgrades once and immediately refreshes gold and sequential locks")
	ui.root_ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ui.root_ui.size = Vector2(853, 384)
	ui.safe_area_override = Rect2(20, 0, 813, 384)
	ui._apply_layout()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	verify.call(ui.layout_data.safe.encloses(ui._modal_host.get_rect()) and ui._scroll.get_v_scroll_bar().max_value > ui._scroll.get_v_scroll_bar().page, "Compact safe-area talent content remains inside a scrollable modal")
	ui.talents_return_button.pressed.emit()
	ui.start_button.pressed.emit()
	verify.call(ui.simulation.account_attack_level == 1 and is_equal_approx(ui.simulation.stats.power, 1.05), "Real lobby departure applies the purchased account bonus")
	stale.call()
	verify.call(ui.gold_progress.total == 1050000, "Combat rejects a delayed lobby purchase")
	ui.pause_game()
	ui._park_battle()
	ui.talents_button.pressed.emit()
	ui.talent_buy_buttons[1].pressed.emit()
	verify.call(ui.gold_progress.attack_level == 2 and ui.gold_progress.total == 1000000 and ui.simulation.account_attack_level == 1, "Lobby purchase while a battle is parked upgrades the account without rewriting the existing battle")
	ui.talents_return_button.pressed.emit()
	ui.start_button.pressed.emit()
	verify.call(ui.simulation.phase == RunState.Phase.PAUSED and ui.simulation.account_attack_level == 1 and is_equal_approx(ui.simulation.stats.power, 1.05), "Continue restores the departure bonus even after another account purchase")
	ui.resume_button.pressed.emit()
	ui.pause_game()
	for button in ui.dialog_body.get_children():
		if button is Button and button.text == "새 전투 시작":
			button.pressed.emit()
			break
	ui.confirm_button.pressed.emit()
	verify.call(ui.simulation.phase == RunState.Phase.RUNNING and ui.simulation.account_attack_level == 2 and is_equal_approx(ui.simulation.stats.power, 1.10), "Confirmed restart takes the newest account bonus exactly once")
	preload("res://tests/test_gold_settings.gd")._complete_stage(ui.simulation)
	ui._physics_process(0.0)
	verify.call(ui.gold_progress.total == 1000100 and ui.gold_progress.attack_level == 2, "Stage reward settlement retains the account upgrade and adds only its normal reward")
	ui.lobby_button.pressed.emit()
	ui.talents_button.pressed.emit()
	ui.talent_buy_buttons[2].pressed.emit()
	verify.call(ui.gold_progress.attack_level == 3 and ui.gold_progress.total == 100, "Third real UI purchase uses exactly one million gold")
	ui.talents_return_button.pressed.emit()
	ui.talents_button.pressed.emit()
	verify.call(ui.talent_buy_buttons.all(func(button): return button.disabled), "Completed three-stage attack talent has no further purchasable level")
	var close: Callable = callback(ui.talents_return_button)
	ui.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	close.call()
	verify.call(not ui._talents_open and ui.simulation.phase == RunState.Phase.READY and ui.gold_progress.total == 100, "App interruption closes the talent menu and rejects stale callbacks without spending")
	var reloaded = Wallet.new()
	reloaded.path = wallet.path
	verify.call(reloaded.load_progress() == OK and reloaded.attack_level == 3 and reloaded.total == 100, "Purchases and the subsequent clear survive an independent account reload")
	ui.queue_free()
	await host.get_tree().process_frame
	# A parseable but corrupted account cannot be overwritten by a purchase.
	var second_dir := directory.path_join("ui-errors")
	DirAccess.make_dir_absolute(second_dir)
	funded(second_dir.path_join("gold.cfg"), 1000)
	ui = Campaign.make_ui(host, second_dir)
	ui.talents_button.pressed.emit()
	DirAccess.make_dir_absolute(ui.gold_progress.path + ".tmp")
	ui.talent_buy_buttons[0].pressed.emit()
	verify.call(ui.gold_progress.total == 1000 and ui.gold_progress.attack_level == 0 and ui._talent_notice.contains("실패"), "Actual UI reports a failed write without consuming gold or granting a bonus")
	DirAccess.remove_absolute(ui.gold_progress.path + ".tmp")
	var corrupt := ConfigFile.new()
	corrupt.load(ui.gold_progress.path)
	corrupt.set_value("account", "attack_level", 99)
	corrupt.save(ui.gold_progress.path)
	ui.talent_buy_buttons[0].pressed.emit()
	verify.call(ui.gold_error != OK and not ui.gold_progress.loaded and ui.talent_buy_buttons.all(func(button): return button.disabled), "Corrupt account input disables further purchases rather than overwriting the file")
	ui.talents_return_button.pressed.emit()
	verify.call(ui.start_button.disabled, "A corrupt account also blocks departure until the wallet can be reloaded")
	ui.queue_free()
	await host.get_tree().process_frame
	for name in DirAccess.get_files_at(second_dir):
		DirAccess.remove_absolute(second_dir.path_join(name))
	DirAccess.remove_absolute(second_dir)
