extends RefCounted
const Campaign=preload("res://tests/test_campaign.gd")
const Wallet=preload("res://scripts/progression/gold_progress.gd")
const Reset=preload("res://scripts/progression/account_reset.gd")
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")

static func button_action(button:Button) -> Callable:
	return button.get_signal_connection_list("pressed")[0].callable

static func clear(ui) -> void:
	var state=ui.simulation
	state.gold_collected=23
	state.elapsed=state.stage_duration
	state.checkpoint_index=2
	state._boss_spawned=true
	state._boss_defeated=true
	state._finish_run("cleared")
	ui._physics_process(0)

static func run(host,verify:Callable) -> void:
	var folder:="user://stage-reset-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	var ui=Campaign.make_ui(host,folder)
	var owner=ui.simulation
	ui.start_button.pressed.emit()
	var old_launch:Callable=button_action(ui.stage_launch_button)
	ui.stage_buttons[1].pressed.emit()
	old_launch.call()
	verify.call(ui._selected_stage==2 and ui.simulation.phase==State.Phase.READY,"Stage changes invalidate old launch callbacks without starting an old target")
	ui._select_stage(999,ui.simulation.navigation_ticket,ui._menu_revision)
	verify.call(ui._selected_stage==2,"Unimplemented regions cannot be forged into campaign selections")
	ui.stage_launch_button.pressed.emit()
	verify.call(ui.simulation==owner and owner.stage==2 and owner.map_id=="outskirts_trial" and ui.view.uses_oblique(),"Actual S2 selection launches the existing owner/map with global oblique scenery")
	owner.hp=71;owner.magic.mana=32
	ui.pause_game();ui._park_battle()
	ui.queue_free();await host.get_tree().process_frame
	ui=Campaign.make_ui(host,folder)
	Campaign.depart(ui)
	verify.call(ui.simulation.phase==State.Phase.PAUSED and ui.simulation.stage==2 and ui.simulation.hp==71 and ui.simulation.magic.mana==32,"Uncleared selected S2 survives a cold scene read and Continue prompt")
	ui.resume_button.pressed.emit()
	clear(ui)
	var first_id:String=ui.simulation.run_id
	verify.call(ui.gold_progress.total==123 and ui.gold_progress.next_stage==1 and ui.gold_progress.has_cleared_stage(2) and not ui.gold_progress.has_cleared_stage(1),"Out-of-order S2 pays once and does not silently mark S1 cleared")
	var paid:Dictionary=ui.run_store.pending.duplicate(true)
	ui.queue_free();await host.get_tree().process_frame
	ui=Campaign.make_ui(host,folder)
	verify.call(ui.battle_save_error==OK and ui.simulation.phase==State.Phase.READY and ui.gold_progress.total==123,"Paid out-of-order result recovers without duplicate payment")
	Campaign.depart(ui);clear(ui)
	var wallet=ui.gold_progress
	verify.call(wallet.total==246 and wallet.next_stage==2 and wallet.has_cleared_stage(1),"S1 remains playable after S2 and advances sequential progress on its own clear")
	verify.call(wallet.settle({"outcome":"cleared","run_id":first_id,"stage":2,"gold_reward":123})==OK and wallet.total==246,"Older already-paid result stays idempotent after a later different clear")
	verify.call(wallet.settle({"outcome":"cleared","run_id":first_id,"stage":2,"gold_reward":999})==ERR_INVALID_PARAMETER,"A paid receipt cannot be reclassified with a larger reward")
	verify.call(not wallet.campaign_allows(paid.run.merged({"phase":1},true)),"An old active checkpoint cannot revive a paid replay")
	ui.start_button.pressed.emit();ui.stage_buttons[0].pressed.emit();ui.stage_launch_button.pressed.emit();clear(ui)
	verify.call(wallet.total==369 and wallet.next_stage==2,"A fresh replay of S1 earns its own clear reward without advancing progress twice")
	ui._return_to_lobby(ui.simulation.navigation_ticket,ui._menu_revision)
	var full_levels:Dictionary=wallet.talent_levels.duplicate(true)
	for id in full_levels:full_levels[id]=3
	verify.call(wallet._commit(7777,wallet.next_stage,wallet.last_run,full_levels)==OK,"Reset fixture contains a funded wallet and all eighteen purchased three-rank talents")
	ui.lobby_settings_button.pressed.emit()
	ui._set_volume(.35);ui._set_display_option(false,"show_damage")
	var settings_hash:String=FileAccess.get_sha256(ui.settings_path)
	var gold_hash:String=FileAccess.get_sha256(wallet.path)
	var reset_owner=ui.simulation
	ui.account_reset_button.pressed.emit()
	var stale_reset:Callable=button_action(ui.confirm_button)
	verify.call(ui._modal_kind=="account_reset" and ui.confirm_button.focus_mode==Control.FOCUS_NONE and ui.cancel_button.has_focus(),"Settings reset opens an explicit warning with Cancel as keyboard default")
	ui._handle_mobile_back();stale_reset.call()
	verify.call(ui._modal_kind=="lobby_settings" and FileAccess.get_sha256(wallet.path)==gold_hash,"Back/Cancel and stale confirmation preserve the entire account")
	ui.account_reset_button.pressed.emit();ui.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	verify.call(ui._modal_kind=="lobby_settings" and FileAccess.get_sha256(wallet.path)==gold_hash,"Interruption cancels reset confirmation before it can become accidental consent")
	ui.account_reset_button.pressed.emit();ui.confirm_button.pressed.emit()
	verify.call(ui.simulation==reset_owner and ui.simulation.phase==State.Phase.READY and ui.gold_progress.loaded and ui.gold_progress.total==0 and ui.gold_progress.next_stage==1 and ui.gold_progress.paid_campaign.is_empty() and ui.gold_progress.talent_levels.values().all(func(v):return v==0),"Confirmed reset clears wallet, progress, receipts and every account talent in the existing run owner")
	verify.call(ui.run_store.pending.is_empty() and not FileAccess.file_exists(ui.run_store.path) and not Reset.pending(wallet.path) and FileAccess.get_sha256(ui.settings_path)==settings_hash,"Reset leaves no battle/intent and preserves the separate settings file")
	ui.queue_free();await host.get_tree().process_frame
	ui=Campaign.make_ui(host,folder)
	verify.call(ui.gold_progress.total==0 and ui.start_button.text=="출격" and is_equal_approx(ui.volume,.35) and not ui.show_damage,"A fresh scene after reset cannot resurrect a terminal reward and retains settings")
	Campaign.depart(ui)
	ui.simulation.grant_xp(100)
	ui.pause_game()
	var before:Dictionary=Snapshot.capture(ui.simulation)
	ui.account_reset_button.pressed.emit();ui.cancel_button.pressed.emit()
	verify.call(ui._modal_kind=="paused" and Snapshot.capture(ui.simulation)==before,"In-battle reset Cancel preserves HP/MP, offered choices, tickets and seven RNG")
	ui.account_reset_button.pressed.emit();ui.confirm_button.pressed.emit()
	verify.call(ui.simulation.phase==State.Phase.READY and ui.run_store.pending.is_empty() and ui.gold_progress.total==0,"Confirmed in-battle reset returns to the lobby without settling an abandoned or pending battle")
	# Seed a durably admitted dungeon and force a deletion failure after intent.
	var admitted=State.new()
	admitted.start(5701,"viya",null,"gold_slime","weapons_v1",{},"gold_slime",preload("res://scripts/combat/gold_dungeon.gd").day_index(int(Time.get_unix_time_from_system())))
	verify.call(ui.gold_progress.admit_dungeon(Snapshot.capture(admitted))==OK and ui.run_store.save_current(admitted)==OK,"A charged dungeon admission exists in both original save owners before reset failure")
	DirAccess.make_dir_absolute(ui.gold_progress.path+".tmp")
	ui.lobby_settings_button.pressed.emit();ui.account_reset_button.pressed.emit();ui.confirm_button.pressed.emit()
	verify.call(ui._modal_kind=="reset_recovery" and ui._account_reset_pending and Reset.pending(ui.gold_progress.path),"Failed deletion retains durable intent and blocks the account instead of partially resuming it")
	ui.begin_run();ui._retry_gold_load();ui._retry_battle_load();ui._physics_process(.05)
	verify.call(ui._modal_kind=="reset_recovery" and not ui._persist_battle() and not FileAccess.file_exists(ui.run_store.path),"Partial reset has removed the battle; blocked autosave/reload cannot reconstruct it from the old dungeon account")
	ui.queue_free();await host.get_tree().process_frame
	ui=Campaign.make_ui(host,folder)
	verify.call(ui._modal_kind=="reset_recovery" and not ui.gold_progress.loaded and ui.run_store.pending.is_empty(),"Startup attempts reset recovery before reading either old account or dungeon snapshot")
	DirAccess.remove_absolute(ui.gold_progress.path+".tmp")
	ui.queue_free();await host.get_tree().process_frame
	ui=Campaign.make_ui(host,folder)
	verify.call(ui._modal_kind=="ready" and ui.gold_progress.dungeon==Wallet.empty_dungeon() and ui.gold_progress.dungeon_remaining()==2 and ui.run_store.pending.is_empty() and not Reset.pending(ui.gold_progress.path),"Restart completes interrupted reset and cannot reconstruct the old charged dungeon")
	# Retry from the recovery screen also completes the same idempotent intent.
	DirAccess.make_dir_absolute(ui.run_store.path+".tmp")
	ui.lobby_settings_button.pressed.emit();ui.account_reset_button.pressed.emit();ui.confirm_button.pressed.emit()
	DirAccess.remove_absolute(ui.run_store.path+".tmp")
	ui.confirm_button.pressed.emit()
	verify.call(ui._modal_kind=="ready" and not ui._account_reset_pending and ui.gold_progress.total==0,"Actual reset recovery button retries once and returns to a usable clean lobby")
	Campaign.depart(ui)
	verify.call(ui.simulation.stage==1 and ui.simulation.account_talent_levels.values().all(func(v):return v==0) and ui.simulation.phase==State.Phase.RUNNING,"A clean account can depart with zero bonuses after recovery")
	ui.queue_free();await host.get_tree().process_frame
	for name in DirAccess.get_files_at(folder):DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
