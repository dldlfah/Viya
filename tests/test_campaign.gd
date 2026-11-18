extends RefCounted
const RunState = preload("res://scripts/combat/run_state.gd")
const Store = preload("res://scripts/progression/run_store.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")

static func depart(ui) -> void:
	ui.start_button.pressed.emit()
	if ui._modal_kind == "stages":
		ui.stage_launch_button.pressed.emit()

static func comparable(state) -> Dictionary:
	var data: Dictionary = Snapshot.capture(state)
	data.run.erase("navigation_ticket")
	data.growth.erase("ticket")
	data.growth.erase("revision")
	data.magic.erase("ticket")
	return data

static func pre_scatter(data: Dictionary) -> Dictionary:
	# Recreate the old four-stream payload before selecting its historical version.
	data = data.duplicate(true)
	data.rules = Snapshot.GAME011_RULES
	data.rng.resize(4)
	data.run.erase("_scatter_clock")
	data.run.erase("_scatter_index")
	return data

static func run(host, verify: Callable) -> void:
	var state = RunState.new()
	verify.call(state.start(123), "Data-driven campaign starts")
	verify.call(state.stage_duration == 360.0 and state.stage_rules.boss_at == 300.0 and state.stage_rules.checkpoints == [120.0, 240.0], "Six-minute duration, five-minute boss and two checkpoints come from data")
	state.spawn_clock = 999.0
	state.elapsed = 299.99
	state.step(0.02, Vector2.ZERO)
	verify.call(state._boss_spawned and state.enemies.any(func(enemy): return enemy.kind == "boss"), "Boss appears at five minutes while normal waves continue")
	var boss: Dictionary = state.enemies.filter(func(enemy): return enemy.kind == "boss")[0]
	state._damage_enemy(boss.id, 10000)
	verify.call(state._boss_defeated and state.phase == RunState.Phase.RUNNING, "Early boss kill alone cannot clear the stage")
	state.elapsed = 359.99
	state.step(0.02, Vector2.ZERO)
	verify.call(state.phase == RunState.Phase.CLEARED and state.checkpoint_index == 2, "Surviving six minutes after a boss kill clears once")
	state.start(124)
	state.spawn_clock = 999.0
	state.elapsed = 359.99
	state.step(0.02, Vector2.ZERO)
	verify.call(state.phase == RunState.Phase.DEFEAT and state.end_reason == "timeout" and state.hp > 0, "A live boss at six minutes produces a timeout without faking lethal damage")
	verify.call(state.result_summary().gold_reward == 0 and state.elapsed <= 360.0, "Timeout pays no clear reward and never extends the six-minute clock")
	state.start(127)
	for index in range(state.MAX_ENEMIES - 1):
		state.add_enemy(state.player + Vector2(600, 0))
	state.elapsed = 299.99
	state.step(0.02, Vector2.ZERO)
	verify.call(state.enemies.size() == state.MAX_ENEMIES and state._boss_spawned, "Reserved capacity lets the scheduled boss enter a saturated wave")
	state.stage_catalog.data.overrides["2"] = {"duration": 420.0, "boss_at": 350.0}
	state.stage = 2
	verify.call(state.start(128) and state.stage_duration == 420.0 and state.stage_rules.boss_at == 350.0, "Per-stage timing overrides are applied without changing combat code")
	state.stage = 1
	# Exact actor/timer/RNG continuation after a real binary save/restore.
	var directory := "user://campaign-test-" + Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(directory)
	state.start(125)
	state.spawn_clock = 999.0
	state.add_enemy(state.player + Vector2(150, 0))
	state._auto_fire()
	state.add_pickup(state.player + Vector2(100, 0))
	state._drop_gold(state.player + Vector2(120, 0), "elite")
	state.step(0.05, Vector2.RIGHT)
	var store = Store.new()
	store.path = directory.path_join("exact.save")
	verify.call(store.save_current(state) == OK, "Active simulation writes a complete atomic snapshot")
	var restored = RunState.new()
	verify.call(store.load_saved(restored) == OK and Snapshot.restore(store.pending, restored), "Binary snapshot is validated before restoring the existing state API")
	verify.call(restored.phase == RunState.Phase.PAUSED, "Recovery always waits for explicit Continue")
	restored.set_paused(false)
	verify.call(comparable(state) == comparable(restored), "Actors, bullets, pickups, HP/MP, skills, timers and all RNG states round trip exactly")
	var equal := true
	for frame in range(90):
		state.step(0.05, Vector2.LEFT)
		restored.step(0.05, Vector2.LEFT)
		equal = equal and comparable(state) == comparable(restored)
		if state.phase != RunState.Phase.RUNNING:
			break
	verify.call(equal, "Restored simulation produces the same subsequent combat and rewards")
	state.start(126)
	state.grant_xp(144.0)
	var offer: Array = state.growth.offer.duplicate()
	var old_ticket: int = state.growth.ticket
	var rng_state: int = state.growth.rng.state
	store.save_current(state)
	store.load_saved(restored)
	verify.call(Snapshot.restore(store.pending, restored), "Queued choices restore")
	restored.set_paused(false)
	verify.call(restored.growth.offer == offer and restored.growth.rng.state == rng_state and restored.growth.pending == 3, "Recovery preserves the exact offer and queued levels without rerolling")
	verify.call(not restored.select_skill(offer[0], old_ticket), "Old choice callbacks are invalid after recovery")
	verify.call(restored.select_skill(offer[0], restored.growth.ticket), "Restored choice can be applied exactly once with its new ticket")
	var valid: Dictionary = store.pending.duplicate(true)
	var rejected := 0
	for mutation in ["version", "rules", "hp", "offer", "mana", "rng", "owned", "actors"]:
		var bad: Dictionary = valid.duplicate(true)
		match mutation:
			"version": bad.version = 999
			"rules": bad.rules = "old rules"
			"hp": bad.run.hp = -1
			"offer": bad.growth.offer = ["foreign_skill"]
			"mana": bad.magic.mana = NAN
			"rng": bad.rng = []
			"owned": bad.growth.owned.common_rifle = 999
			"actors": bad.run.enemies = [{"p": Vector2.ZERO}]
		var before: Dictionary = comparable(restored)
		if not Snapshot.restore(bad, restored) and before == comparable(restored):
			rejected += 1
	verify.call(rejected == 8, "Unsupported/corrupt gameplay data is rejected without partial mutation")
	var bytes := FileAccess.get_file_as_bytes(store.path)
	bytes[-1] = bytes[-1] ^ 1
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	verify.call(store.load_saved(restored) == ERR_FILE_CORRUPT, "Checksum rejects damaged save bytes")
	verify.call(store.discard() == OK and store.load_saved(restored) == OK and store.pending.is_empty(), "Explicit discard writes a durable empty tombstone")
	await ui_checks(host, directory, verify)
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	verify.call(true, "Campaign recovery suite reached the final check")

static func make_ui(host, directory: String):
	var ui = load("res://scenes/main.tscn").instantiate()
	ui.run_store.path = directory.path_join("ui.save")
	ui.gold_progress.path = directory.path_join("gold.cfg")
	ui.settings_path = directory.path_join("settings.cfg")
	host.get_tree().root.add_child(ui)
	ui.set_physics_process(false)
	return ui

static func ui_checks(host, directory: String, verify: Callable) -> void:
	var ui = make_ui(host, directory)
	depart(ui)
	ui.simulation.elapsed = 119.99
	ui.simulation.spawn_clock = 999.0
	ui._physics_process(0.02)
	verify.call(ui.simulation.checkpoint_index == 1 and ui.run_store.pending.run.checkpoint_index == 1, "Actual main loop saves the first two-minute checkpoint")
	ui.simulation.elapsed = 239.99
	ui._physics_process(0.02)
	verify.call(ui.simulation.checkpoint_index == 2 and ui.run_store.pending.run.checkpoint_index == 2, "Actual main loop saves the second four-minute checkpoint")
	ui.simulation.grant_xp(30.0)
	ui._physics_process(0.0)
	var offer: Array = ui.simulation.growth.offer.duplicate()
	var ticket: int = ui.simulation.growth.ticket
	ui.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	verify.call(ui.run_store.pending.growth.offer == offer and ui.simulation.phase == RunState.Phase.PAUSED, "Background interruption saves the actual paused choice")
	ui.queue_free()
	await host.get_tree().process_frame
	ui = make_ui(host, directory)
	verify.call(ui.start_button.text == "이어하기", "New process-style scene offers the saved battle")
	depart(ui)
	verify.call(ui.simulation.phase == RunState.Phase.PAUSED and ui.simulation.growth.offer == offer and ui.simulation.growth.ticket != ticket, "Continue restores paused state and invalidates pre-close callbacks")
	ui.resume_button.pressed.emit()
	verify.call(ui.simulation.phase == RunState.Phase.CHOOSING and ui.simulation.growth.offer == offer, "Explicit Continue opens the original three choices")
	ui.choice_buttons[0].pressed.emit()
	verify.call(ui.run_store.pending.growth.owned == ui.simulation.growth.owned, "Applied skill is durably saved before gameplay resumes")
	ui.pause_game()
	ui._park_battle()
	verify.call(ui.simulation.phase == RunState.Phase.READY and ui.start_button.text == "이어하기", "Saved battle can be parked at the lobby")
	depart(ui)
	var original_path: String = ui.run_store.path
	ui.run_store.path = directory.path_join("missing/ui.save")
	ui.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	verify.call(ui.battle_save_error != OK and ui.resume_button.disabled, "A failed interruption save is visible and keeps play paused")
	DirAccess.make_dir_recursive_absolute(directory.path_join("missing"))
	ui._retry_battle_save()
	verify.call(ui.battle_save_error == OK and not ui.resume_button.disabled, "Battle save can be retried without resetting gameplay")
	DirAccess.remove_absolute(ui.run_store.path)
	DirAccess.remove_absolute(directory.path_join("missing"))
	ui.run_store.path = original_path
	ui.resume_button.pressed.emit()
	ui._ensure_battle_saved()
	var pre_clear: Dictionary = ui.run_store.pending.duplicate(true)
	ui.simulation.gold_collected = 77
	ui.simulation.gold_drop_chance = 0.0
	ui.simulation.elapsed = ui.simulation.stage_duration
	ui.simulation._boss_spawned = true
	ui.simulation.add_enemy(ui.simulation.player + Vector2(300, 0), "boss")
	ui.simulation._damage_enemy(ui.simulation.enemies[-1].id, 10000)
	ui._physics_process(0.0)
	verify.call(ui.run_store.pending.run.phase == RunState.Phase.CLEARED and ui.gold_progress.total == 177, "Terminal intent is saved before the full clear reward is credited")
	ui.queue_free()
	await host.get_tree().process_frame
	ui = make_ui(host, directory)
	verify.call(ui.simulation.phase == RunState.Phase.READY and ui.simulation.result_summary().outcome == "cleared" and ui.gold_progress.total == 177 and ui.gold_progress.next_stage == 2, "Recovery after payment opens the main lobby with its frozen result and no duplicate gold")
	var completed: Dictionary = ui.run_store.pending.duplicate(true)
	ui.run_store.write_snapshot(pre_clear)
	ui.queue_free()
	await host.get_tree().process_frame
	ui = make_ui(host, directory)
	depart(ui)
	verify.call(ui.battle_save_error == ERR_FILE_CORRUPT and ui.gold_progress.total == 177, "An older active checkpoint cannot replay a paid stage")
	ui.run_store.write_snapshot(completed)
	ui._retry_battle_load()
	verify.call(ui.simulation.phase == RunState.Phase.CLEARED and ui.gold_progress.total == 177, "A repaired terminal save reopens its result instead of starting over")
	depart(ui)
	ui.simulation.damage_player(10000)
	ui._physics_process(0.0)
	ui.queue_free()
	await host.get_tree().process_frame
	ui = make_ui(host, directory)
	verify.call(ui.simulation.phase == RunState.Phase.READY and ui.simulation.result_summary().outcome == "defeat" and ui.gold_progress.total == 177, "Defeat tombstone survives restart into the lobby and cannot resume a pre-death checkpoint")
	depart(ui)
	ui.pause_game()
	ui.leave_button.pressed.emit()
	ui.confirm_button.pressed.emit()
	ui.queue_free()
	await host.get_tree().process_frame
	ui = make_ui(host, directory)
	verify.call(ui.simulation.phase == RunState.Phase.READY and ui.simulation.result_summary().outcome == "abandoned" and ui.gold_progress.total == 177 and ui.gold_progress.next_stage == 2, "Abandonment persists into the lobby without gold or stage unlock")
	depart(ui)
	ui.run_store.path = directory.path_join("blocked/ui.save")
	ui.simulation.elapsed = ui.simulation.stage_duration
	ui.simulation._boss_spawned = true
	ui.simulation.gold_drop_chance = 0.0
	ui.simulation.add_enemy(ui.simulation.player, "boss")
	ui.simulation._damage_enemy(ui.simulation.enemies[-1].id, 10000)
	ui._physics_process(0.0)
	verify.call(ui.gold_progress.total == 177 and ui.start_button.disabled and ui.lobby_button.disabled, "Failed terminal save cannot pay gold or move to the next stage")
	DirAccess.make_dir_recursive_absolute(directory.path_join("blocked"))
	ui._retry_battle_save()
	verify.call(ui.gold_progress.total == 277 and ui.gold_progress.next_stage == 3, "Retry commits the pending clear and pays exactly once")
	DirAccess.remove_absolute(ui.run_store.path)
	DirAccess.remove_absolute(directory.path_join("blocked"))
	ui.queue_free()
	await host.get_tree().process_frame
	# Corruption has an explicit guarded deletion route and preserves the wallet.
	var file := FileAccess.open(original_path, FileAccess.WRITE)
	file.store_string("damaged")
	file.close()
	ui = make_ui(host, directory)
	verify.call(ui.start_button.disabled and ui.battle_save_error == ERR_FILE_CORRUPT, "Corrupt saved battle never silently resets progress")
	ui._ask_discard_save()
	ui.cancel_button.pressed.emit()
	verify.call(FileAccess.get_file_as_string(original_path) == "damaged", "Cancel preserves a corrupt save for recovery")
	ui._ask_discard_save()
	ui.confirm_button.pressed.emit()
	verify.call(not ui.start_button.disabled and ui.gold_progress.total == 277 and ui.gold_progress.next_stage == 3, "Confirmed save deletion preserves permanent gold and unlocked stage")
	depart(ui)
	ui.simulation.elapsed = 359.99
	ui._physics_process(0.02)
	ui.queue_free()
	await host.get_tree().process_frame
	ui = make_ui(host, directory)
	verify.call(ui.simulation.phase == RunState.Phase.READY and ui.simulation.end_reason == "timeout" and ui.dialog_body.get_child(0).text.contains("메인 로비") and ui.gold_progress.total == 277, "Timeout result survives a lobby restart with no payment or stage unlock")
	ui.queue_free()
	await host.get_tree().process_frame
