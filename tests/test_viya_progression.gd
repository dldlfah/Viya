extends RefCounted
const Characters = preload("res://scripts/progression/character_progress.gd")
const Wallet = preload("res://scripts/progression/gold_progress.gd")
const Reset = preload("res://scripts/progression/account_reset.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const SceneFactory = preload("res://tests/test_battle_save_notice.gd")

class ConfiguredWallet:
	extends "res://scripts/progression/gold_progress.gd"

	func viya_imprint_cost() -> int:
		return 3 # Test-only cost. Production starts with no acquisition or cost.

static func run(host, verify: Callable) -> void:
	var folder := "user://viya-progression-" + Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	var legacy := ConfigFile.new()
	legacy.set_value("gold", "total", 3000)
	legacy.set_value("gold", "next_stage", 2)
	legacy.set_value("gold", "last_run", "older-clear")
	var wallet := ConfiguredWallet.new()
	wallet.path = folder.path_join("progress.cfg")
	legacy.save(wallet.path)
	var hash := FileAccess.get_sha256(wallet.path)
	verify.call(wallet.load_progress() == OK and wallet.character_progress == Characters.empty() and wallet.total == 3000 and wallet.next_stage == 2 and FileAccess.get_sha256(wallet.path) == hash, "Previous accounts gain default 3-star Viya without rewriting or changing balances")
	verify.call(wallet.complete_viya_imprint(3, 0) == ERR_UNAVAILABLE and FileAccess.get_sha256(wallet.path) == hash, "Insufficient shards do not start an imprint or mutate the account")

	var seeded := Characters.empty()
	seeded.items[Characters.VIYA_SHARD] = 63
	verify.call(wallet._commit(wallet.total, wallet.next_stage, wallet.last_run, wallet.talent_levels, null, null, seeded) == OK, "The account transaction supports a stored inventory stack")
	var stale := ConfiguredWallet.new()
	stale.path = wallet.path
	stale.load_progress()
	var result := wallet.complete_viya_imprint(3, 0)
	verify.call(result == OK and wallet.character_progress.viya.imprints == 1 and wallet.character_progress.items[Characters.VIYA_SHARD] == 60, "An imprint success consumes exactly the configured shard cost")
	verify.call(stale.complete_viya_imprint(3, 0) == ERR_BUSY and wallet.complete_viya_imprint(3, 0) == ERR_INVALID_PARAMETER, "Stale disk owners and repeated activation cannot spend the same shard step twice")
	hash = FileAccess.get_sha256(wallet.path)
	DirAccess.make_dir_absolute(wallet.path + ".tmp")
	result = wallet.complete_viya_imprint(3, 1)
	verify.call(result != OK and wallet.character_progress.viya.imprints == 1 and wallet.character_progress.items[Characters.VIYA_SHARD] == 60 and FileAccess.get_sha256(wallet.path) == hash, "Atomic write failure keeps both imprint progress and shard count intact")
	DirAccess.remove_absolute(wallet.path + ".tmp")

	var exact := true
	for step in range(2, 21):
		var viya: Dictionary = wallet.character_progress.viya
		result = wallet.complete_viya_imprint(viya.stars, viya.imprints)
		var expected_stars := mini(6, 3 + step / 5)
		var expected_imprints := 5 if step == 20 else step % 5
		exact = exact and result == OK and wallet.character_progress.viya == {"stars": expected_stars, "imprints": expected_imprints}
	verify.call(exact and wallet.character_progress.items[Characters.VIYA_SHARD] == 3, "Five successes per star promote automatically to 4, 5 and 6, then stop at 6 stars and 5 imprints")
	verify.call(wallet.complete_viya_imprint(6, 5) == ERR_UNAVAILABLE and wallet.character_progress.items[Characters.VIYA_SHARD] == 3, "The cap preserves unused shards")
	verify.call(wallet.purchase_attack(0) == OK and wallet.settle({"outcome":"cleared","run_id":"new-clear","stage":2,"gold_reward":24}) == OK, "Regular talent transactions and settlements can save after imprint progress")
	var disk := Wallet.new()
	disk.path = wallet.path
	verify.call(disk.load_progress() == OK and disk.character_progress == wallet.character_progress and disk.total == 2024 and disk.next_stage == 3 and disk.attack_level == 1, "Imprints and inventory survive a fresh load with gold, talents, receipts and stage progress")
	verify.call(not Characters.valid({"viya":{"stars":3,"imprints":5},"items":{}}) and not Characters.valid({"viya":{"stars":7,"imprints":0},"items":{}}) and not Characters.valid({"viya":{"stars":6,"imprints":5},"items":{"viya_shard":-1}}), "Invalid promotion states and negative shard counts are rejected")

	var ui = SceneFactory.make_ui(host, folder.path_join("lobby"))
	await host.get_tree().process_frame
	var initial: Dictionary = Snapshot.capture(ui.simulation)
	ui.dialog_body.find_child("InventoryButton", true, false).pressed.emit()
	verify.call(ui._modal_kind == "inventory" and ui.dialog_body.find_child("ItemCount_viya_shard", true, false).text == "0개", "The active lobby lists the registered shard with zero owned")
	ui.dialog_body.find_child("InventoryBack", true, false).pressed.emit()
	ui.dialog_body.find_child("CharacterInfoButton", true, false).pressed.emit()
	var imprint: Button = ui.dialog_body.get_node("ViyaImprintButton")
	verify.call(imprint.text.contains("3성 · 각인 0/5"), "Character information starts at 3 stars with five available imprint steps")
	imprint.pressed.emit()
	var action: Button = ui.dialog_body.get_node("ImprintAction")
	verify.call(ui._modal_kind == "viya_imprint" and action.disabled and action.text.contains("준비 중"), "Production has no imprint economy enabled")
	verify.call(ui._handle_mobile_back() and ui._modal_kind == "character_info" and ui._handle_mobile_back() and ui._modal_kind == "ready", "Back returns from imprint to character info and then to the lobby")
	verify.call(Snapshot.capture(ui.simulation) == initial and not FileAccess.file_exists(ui.gold_progress.path), "Examining inventory and imprint progress changes neither account files nor the battle")
	ui.queue_free()
	await host.get_tree().process_frame

	verify.call(Reset.begin(wallet.path, folder.path_join("battle.save")) == OK and disk.load_progress() == OK and disk.character_progress == Characters.empty() and disk.total == 0, "The existing reset returns both inventory and Viya to their defaults")
	verify.call(stale.complete_viya_imprint(3, 0) == ERR_BUSY and not FileAccess.file_exists(wallet.path), "A stale imprint request cannot recreate a reset account")
