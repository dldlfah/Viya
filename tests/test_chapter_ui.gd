extends RefCounted
const Campaign = preload("res://tests/test_campaign.gd")
static func run(host, verify: Callable) -> void:
	var directory := "user://chapter-ui-" + Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(directory)
	var ui = Campaign.make_ui(host, directory)
	verify.call(ui.start_button.text == "출격" and is_instance_valid(ui.lobby_settings_button), "Lobby retains real departure/talents and adds settings")
	ui.start_button.pressed.emit()
	verify.call(ui._modal_kind == "stages" and ui.simulation.phase == ui.RunState.Phase.READY and ui.stage_buttons.size() == 2, "Departure opens chapter/stage selection without starting a battle")
	verify.call(not ui.stage_buttons[0].disabled and not ui.stage_buttons[1].disabled, "Both implemented stages are freely selectable")
	ui.stage_buttons[1].pressed.emit()
	verify.call(ui._selected_stage == 2 and ui.stage_launch_button.text.begins_with("S2"), "Selecting another stage refreshes the actual departure target")
	var stale: Callable = ui.stage_launch_button.get_signal_connection_list("pressed")[0].callable
	ui.stage_back_button.pressed.emit()
	stale.call()
	verify.call(ui._modal_kind == "ready" and ui.simulation.phase == ui.RunState.Phase.READY and ui.gold_progress.total == 0, "Back and stale launch cannot reset or start a run")
	ui.lobby_settings_button.pressed.emit()
	verify.call(ui._modal_kind == "lobby_settings", "Lobby settings are a working screen")
	ui.stage_back_button.pressed.emit()
	Campaign.depart(ui)
	verify.call(ui.simulation.phase == ui.RunState.Phase.RUNNING and not ui.overlay.visible, "Selected stage launches through the actual existing scene")
	ui.simulation.elapsed = 300.0
	ui.simulation._boss_spawned = ui.simulation.add_enemy(ui.simulation.player + Vector2(300,0), "boss")
	ui._update_hud()
	verify.call(ui.boss_bar.visible and ui.boss_bar.value == 3200.0, "Actual boss health appears in the HUD")
	ui.simulation._damage_enemy(ui.simulation.enemies[-1].id, 100.0)
	ui._update_hud()
	verify.call(ui.boss_bar.value == 3129.0, "Boss health display follows real damage")
	ui.simulation.apply_slow(1.0)
	ui._update_hud()
	verify.call(ui.ailment_text.text.contains("둔화"), "Slow has a dedicated readable status field")
	ui.simulation.elapsed = 360.0
	ui.simulation.checkpoint_index = 2
	ui.simulation._damage_enemy(ui.simulation.enemies[-1].id,100000)
	ui._physics_process(0.0)
	var paid_balance: int = ui.gold_progress.total
	ui.start_button.pressed.emit()
	verify.call(ui._modal_kind == "stages" and ui.simulation.phase == ui.RunState.Phase.READY and ui.gold_progress.next_stage == 2,"Next-stage selection leaves the paid result in a proper frozen lobby state")
	ui.stage_back_button.pressed.emit()
	ui.talents_button.pressed.emit()
	verify.call(ui._talents_open and ui.gold_progress.total == paid_balance,"Cancel after a result preserves the complete paid reward and allows lobby talents")
	ui.queue_free()
	await host.get_tree().process_frame
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
