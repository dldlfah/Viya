extends RefCounted
## Runs inside the existing native combat-cues suite against the actual scene.
const RunState = preload("res://scripts/combat/run_state.gd")
const GoldProgress = preload("res://scripts/progression/gold_progress.gd")

static func run(scene, verify: Callable) -> void:
	var directory: String = "user://gold-settings-test-" + Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(directory)
	var state = RunState.new()
	state.start(143)
	var combat_rng: int = state.rng.state
	var choice_rng: int = state.growth.rng.state
	state.gold_drop_chance = 1.0
	for kind in ["normal", "elite", "boss"]:
		var minimum: int = 10 if kind == "normal" else 100
		var maximum: int = 50 if kind == "normal" else 1000
		var in_range := true
		var seen_min := false
		var seen_max := false
		for sample in range(20000):
			state.gold_pickups.clear()
			state._drop_gold(state.player, kind)
			var value: int = state.gold_pickups[0]["value"]
			in_range = in_range and value >= minimum and value <= maximum
			seen_min = seen_min or value == minimum
			seen_max = seen_max or value == maximum
		verify.call(in_range and seen_min and seen_max, kind + " gold uses both inclusive amount limits")
	state.gold_pickups.clear()
	state.gold_drop_chance = 0.0
	state._drop_gold(state.player, "normal")
	verify.call(state.gold_pickups.is_empty(), "Zero chance never creates a drop")
	state.gold_drop_chance = 0.3
	var dropped := 0
	for sample in range(5000):
		state.gold_pickups.clear()
		state._drop_gold(state.player, "normal")
		if not state.gold_pickups.is_empty():
			dropped += 1
	verify.call(dropped > 1250 and dropped < 1750, "Configured chance produces both drops and misses")
	verify.call(state.rng.state == combat_rng and state.growth.rng.state == choice_rng, "Gold rolls preserve combat and choice RNG streams")
	state.gold_pickups.clear()
	state.gold_drop_chance = 1.0
	for sample in range(RunState.MAX_PICKUPS + 10):
		state._drop_gold(state.player, "normal")
	verify.call(state.gold_pickups.size() == RunState.MAX_PICKUPS, "Gold pickup storage remains bounded")
	state._collect_pickups(0.05)
	var collected: int = state.gold_collected
	state._collect_pickups(0.05)
	verify.call(collected >= (RunState.MAX_PICKUPS + 10) * 10 and state.gold_collected == collected, "Pickup cap preserves value and collection happens once")
	state.start(145)
	state.gold_drop_chance = 1.0
	state.add_enemy(state.player + Vector2(300, 0), "elite")
	var enemy_id: int = state.enemies[0]["id"]
	state._damage_enemy(enemy_id, 1000)
	state._damage_enemy(enemy_id, 1000)
	verify.call(state.kills == 1 and state.gold_pickups.size() == 1 and state.pickups.size() == 1, "All attacks share one death path with independent XP and gold drops")
	state.start(146)
	state.gold_drop_chance = 1.0 # Guarantee a drop for the boss payout assertion.
	state.elapsed = state.stage_duration / 3.0
	state.spawn_clock = 999.0
	state.step(0.01, Vector2.ZERO)
	verify.call(state.enemies.any(func(enemy): return enemy["kind"] == "elite"), "Stage schedule spawns an elite through the existing spawn path")
	state.elapsed = float(state.stage_rules.boss_at)
	state.step(0.01, Vector2.ZERO)
	var bosses: Array = state.enemies.filter(func(enemy): return enemy["kind"] == "boss")
	verify.call(bosses.size() == 1 and state._boss_spawned, "Stage schedule spawns one final boss")
	state._damage_enemy(bosses[0]["id"], 10000)
	state.elapsed = state.stage_duration - 0.01
	state.step(0.02, Vector2.ZERO)
	var result: Dictionary = state.result_summary()
	verify.call(state.phase == RunState.Phase.CLEARED and result["gold_collected"] >= 100, "Boss death clears the stage and includes its final gold drop")
	verify.call(result["gold_reward"] == result["gold_collected"] + result["gold_bonus"], "Clear reward is base bonus plus acquired gold")
	var frozen: String = var_to_str(result)
	state.step(0.05, Vector2.RIGHT)
	state._damage_enemy(enemy_id, 10000)
	verify.call(frozen == var_to_str(state.result_summary()), "Clear results remain frozen against delayed damage and stepping")
	var wallet = GoldProgress.new()
	wallet.path = directory.path_join("gold.cfg")
	verify.call(wallet.load_progress() == OK and wallet.total == 0, "Existing players without currency saves start with zero gold")
	verify.call(wallet.settle(result) == OK, "A cleared stage saves its reward")
	var total: int = wallet.total
	wallet.settle(result)
	verify.call(wallet.total == total and wallet.next_stage == 2, "A repeated clear cannot award twice")
	var reloaded = GoldProgress.new()
	reloaded.path = wallet.path
	verify.call(reloaded.load_progress() == OK and reloaded.total == total, "Gold survives process-style reload")
	reloaded.settle(result)
	verify.call(reloaded.total == total, "Persisted settlement identity prevents repeat credit after reload")
	var blocked = GoldProgress.new()
	blocked.path = directory.path_join("missing/gold.cfg")
	blocked.load_progress()
	verify.call(blocked.settle(result) != OK and blocked.total == 0 and blocked.next_stage == 1, "A failed write keeps wallet and stage unchanged")
	DirAccess.make_dir_recursive_absolute(directory.path_join("missing"))
	verify.call(blocked.settle(result) == OK and blocked.total == total, "The same failed settlement can be retried once")
	DirAccess.remove_absolute(blocked.path)
	DirAccess.remove_absolute(directory.path_join("missing"))
	state.start(147)
	state.damage_player(10000)
	verify.call(wallet.settle(state.result_summary()) != OK and wallet.total == total, "Defeat never pays a stage clear reward")
	var corrupt := ConfigFile.new()
	corrupt.set_value("gold", "total", -1)
	corrupt.save(reloaded.path)
	verify.call(reloaded.load_progress() != OK and not reloaded.loaded, "Corrupt currency saves block overwriting the wallet")
	# UI settings use the existing PAUSED menu and preserve legacy audio keys.
	scene.settings_path = directory.path_join("settings.cfg")
	var legacy := ConfigFile.new()
	legacy.set_value("audio", "master", 0.45)
	legacy.set_value("other", "retained", 19)
	legacy.set_value("display", "show_damage", "invalid")
	legacy.save(scene.settings_path)
	scene._load_settings()
	verify.call(is_equal_approx(scene.volume, 0.45) and scene.show_damage and scene.show_xp and not scene.simple_attacks, "Legacy and invalid setting values use explicit defaults")
	scene.begin_run()
	scene.simulation.grant_xp(30.0)
	scene._physics_process(0.0)
	scene.pause_game()
	var offer: Array = scene.simulation.growth.offer.duplicate()
	var ticket: int = scene.simulation.growth.ticket
	var snapshot: String = var_to_str([scene.simulation.elapsed, scene.simulation.hp, scene.simulation.magic.mana, scene.simulation.rng.state, scene.simulation.growth.rng.state, scene.simulation.gold_rng.state])
	for key in ["show_damage", "show_xp", "simple_attacks"]:
		var toggle: CheckBox = scene.dialog_body.get_node(NodePath(key))
		toggle.button_pressed = key == "simple_attacks"
	verify.call(not scene.view.show_damage and not scene.view.show_xp and scene.view.simple_attacks, "Real settings controls update the existing View")
	verify.call(scene.simulation.phase == RunState.Phase.PAUSED and offer == scene.simulation.growth.offer and ticket == scene.simulation.growth.ticket, "Changing display options preserves the paused level choice")
	verify.call(snapshot == var_to_str([scene.simulation.elapsed, scene.simulation.hp, scene.simulation.magic.mana, scene.simulation.rng.state, scene.simulation.growth.rng.state, scene.simulation.gold_rng.state]), "Display options preserve resources, time and all RNG streams")
	var saved := ConfigFile.new()
	saved.load(scene.settings_path)
	verify.call(saved.get_value("other", "retained") == 19 and is_equal_approx(saved.get_value("audio", "master"), 0.45), "Display saves preserve audio and unrelated existing settings")
	scene._set_volume(0.2)
	scene._load_settings()
	verify.call(not scene.show_damage and not scene.show_xp and scene.simple_attacks and is_equal_approx(scene.volume, 0.2), "Settings survive reload and changing audio preserves display choices")
	scene.settings_path = directory.path_join("absent/settings.cfg")
	scene._save_settings()
	verify.call(scene.settings_error != OK and scene.settings_message.text.contains("실패"), "Settings write failures are visible")
	scene.resume_button.pressed.emit()
	verify.call(scene.simulation.phase == RunState.Phase.CHOOSING and scene.simulation.growth.ticket == ticket and scene.simulation.growth.offer == offer, "Settings Continue restores the identical choice")
	# Real UI settlement, retries and next-stage routing, with isolated save data.
	scene.gold_progress = GoldProgress.new()
	scene.gold_progress.path = directory.path_join("ui-gold.cfg")
	scene.gold_error = scene.gold_progress.load_progress()
	scene.begin_run()
	scene.simulation.gold_collected = 57
	_complete_stage(scene.simulation)
	scene._physics_process(0.0)
	verify.call(scene._modal_kind == "cleared" and scene.gold_progress.total == 157 and scene.result_summary_label.text.contains("157"), "Real result UI displays and saves base plus acquired gold")
	scene._show_menu("cleared")
	verify.call(scene.gold_progress.total == 157, "Reopening results cannot pay twice")
	preload("res://tests/test_campaign.gd").depart(scene)
	verify.call(scene.simulation.stage == 2 and scene.simulation.gold_collected == 0 and scene.gold_progress.total == 157, "Next-stage UI retains wallet and resets per-stage gold")
	scene.gold_progress.path = directory.path_join("retry/gold.cfg")
	_complete_stage(scene.simulation)
	scene._physics_process(0.0)
	verify.call(scene.start_button.disabled and scene.lobby_button.disabled and scene.gold_progress.total == 157, "Failed settlement blocks losing the pending reward by leaving results")
	DirAccess.make_dir_recursive_absolute(directory.path_join("retry"))
	scene._retry_gold_save()
	verify.call(not scene.start_button.disabled and scene.gold_progress.total == 257, "Result retry credits only the pending stage bonus")
	DirAccess.remove_absolute(scene.gold_progress.path)
	DirAccess.remove_absolute(directory.path_join("retry"))
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	verify.call(true, "Gold/settings suite reached its final integration check")

static func _complete_stage(state) -> void:
	state.elapsed = state.stage_duration
	state.gold_drop_chance = 0.0
	state._boss_spawned = true
	state.add_enemy(state.player, "boss")
	state._damage_enemy(state.enemies[-1]["id"], 10000)
