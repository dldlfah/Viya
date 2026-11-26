extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Wallet=preload("res://scripts/progression/gold_progress.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Dungeon=preload("res://tests/test_gold_dungeon.gd")
const NoticeTests=preload("res://tests/test_battle_save_notice.gd")
const Payment=preload("res://scripts/ui/reward_payment.gd")

static func quiet(state) -> void:
	state.spawn_clock=999
	state.shot_clock=999
	state._scatter_clock=999
	state._swarm_clock=999

static func finish_campaign(ui) -> void:
	var state=ui.simulation
	quiet(state)
	state.enemies.clear()
	state.elapsed=359.99
	state.checkpoint_index=2
	state._elites_spawned=2
	state._boss_spawned=true
	state.gold_collected=57
	state.gold_pickups.append({"p":Vector2(4900,3100),"value":11})
	state.gold_drop_chance=0
	state.add_enemy(state.player+Vector2(300,0),"boss")
	state._damage_enemy(int(state.enemies[-1].id),100000)
	ui._physics_process(.02)

static func data(ui) -> Dictionary:
	return Payment.describe(ui.simulation.result_summary(),ui.run_store.pending,ui.gold_progress,ui.battle_save_error,ui.gold_error)

static func run(host,verify:Callable) -> void:
	var folder:="user://reward-payment-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var scenes:Array=[]
	var ui=NoticeTests.make_ui(host,folder.path_join("paid"))
	scenes.append(ui)
	await host.get_tree().process_frame
	Campaign.depart(ui)
	finish_campaign(ui)
	verify.call(ui.simulation.phase==State.Phase.CLEARED and data(ui).state=="paid" and ui.gold_progress.total==168 and ui.gold_progress.next_stage==2,"Actual campaign clear sweeps field gold and confirms the durable current-run168gold payout")
	verify.call(ui.result_summary_label.text.contains("지급 완료 · 168 금화") and ui.result_summary_label.text.contains("기본 보상 100 + 획득 금화 68 = 총 168 금화"),"Existing result label shows confirmed status and the original exact reward breakdown")
	var disk=Wallet.new()
	disk.path=ui.gold_progress.path
	verify.call(disk.load_progress()==OK and disk.total==168 and disk.last_run==ui.simulation.run_id,"Displayed payment corresponds to the actual readable account file/current run ID")
	var frozen:Dictionary=Snapshot.capture(ui.simulation)
	var saved:Dictionary=ui.run_store.pending.duplicate(true)
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(ui.gold_progress.path)
	for index in range(20):data(ui)
	verify.call(frozen==Snapshot.capture(ui.simulation) and saved==ui.run_store.pending and FileAccess.get_file_as_bytes(ui.gold_progress.path)==bytes,"Formatting never writes files,mutates frozen results/resources or consumes RNG")
	ui.overview_button.pressed.emit()
	var summary_label:Label=ui.dialog_body.get_node("RewardPaymentSummary")
	verify.call(ui._overview_open and summary_label.text.contains("지급 완료 · 168 금화") and frozen==Snapshot.capture(ui.simulation),"Existing final-growth overview exposes the same paid receipt without another settlement")
	ui.overview_return_button.pressed.emit()
	ui._retry_gold_save()
	verify.call(ui.gold_progress.total==168 and FileAccess.get_file_as_bytes(ui.gold_progress.path)==bytes and data(ui).state=="paid","Closing details,retrying and reopening a paid result cannot credit it twice")
	var good_battle:String=ui.run_store.path
	ui.run_store.path=folder.path_join("missing-paid/battle.save")
	ui._retry_gold_save()
	verify.call(ui.battle_save_error!=OK and data(ui).state=="recorded" and ui.result_summary_label.text.contains("지급 기록 있음") and not ui.result_summary_label.text.contains("지급 대기"),"Already credited reward is not falsely advertised as unpaid when a later result write fails")
	verify.call(ui.start_button.disabled and ui.lobby_button.disabled and ui.gold_progress.total==168,"Recorded-but-unconfirmed saving preserves original blocked navigation and wallet")
	ui.run_store.path=good_battle
	ui._retry_battle_save()
	verify.call(data(ui).state=="paid" and ui.gold_progress.total==168 and not ui.lobby_button.disabled,"Existing battle retry confirms saving without another payment")
	ui.lobby_button.pressed.emit()
	ui.overview_button.pressed.emit()
	verify.call(ui.simulation.phase==State.Phase.READY and ui.dialog_body.get_node("RewardPaymentSummary").text.contains("지급 완료"),"Lobby final-growth access keeps the frozen paid receipt until another explicit start")
	ui.overview_return_button.pressed.emit()
	var frozen_summary:Dictionary=ui.simulation.result_summary()
	verify.call(Payment.describe(frozen_summary,{},ui.gold_progress,OK,OK).state!="paid","A generic success code without the matching terminal snapshot cannot confirm payment")
	var unrelated=Wallet.new()
	unrelated.path=folder.path_join("unrelated.cfg")
	unrelated.load_progress()
	verify.call(Payment.describe(frozen_summary,saved,unrelated,OK,OK).state=="pending","Unrelated loaded account success cannot confirm the current run")
	var changed:Dictionary=saved.duplicate(true)
	changed.run.gold_collected+=1
	verify.call(not Payment.durable(frozen_summary,changed),"Stored gold must match the frozen current result rather than another payload")
	unrelated.loaded=false
	verify.call(Payment.describe(frozen_summary,saved,unrelated,OK,ERR_FILE_CORRUPT).text.contains("잔액 확인 불가"),"Unreadable account does not invent a confirmed zero balance")
	verify.call(Payment.describe({"ended":false},{},unrelated,OK,OK).is_empty(),"Active/nonterminal state cannot create a payout receipt")
	# Real account-write failure followed by original retry.
	ui=NoticeTests.make_ui(host,folder.path_join("account-failure"))
	scenes.append(ui)
	await host.get_tree().process_frame
	Campaign.depart(ui)
	var good_gold:String=ui.gold_progress.path
	ui.gold_progress.path=folder.path_join("missing-account/gold.cfg")
	finish_campaign(ui)
	verify.call(ui.gold_error!=OK and data(ui).state=="pending" and ui.gold_progress.total==0 and ui.gold_progress.next_stage==1,"Actual failed account write leaves the168gold reward pending without credit or unlock")
	verify.call(ui.result_summary_label.text.contains("지급 대기 · 예정 168 금화") and ui.result_summary_label.text.contains("정산 대상 168 금화") and ui.start_button.disabled and ui.lobby_button.disabled,"Failed result labels the quoted reward as pending and keeps existing recovery controls")
	verify.call(ui.dialog_body.get_child(1) is Button and ui.dialog_body.get_child(1).pressed.is_connected(ui._retry_gold_save),"Existing account retry is promoted above long result text")
	ui._set_volume(.4)
	verify.call(ui.settings_error==OK and data(ui).state=="pending","Successful settings persistence is not successful reward payment")
	ui.gold_progress.path=good_gold
	ui._retry_gold_save()
	verify.call(data(ui).state=="paid" and ui.gold_progress.total==168 and ui.gold_progress.next_stage==2,"Original account retry commits the frozen reward once and updates its status")
	ui._retry_gold_save()
	verify.call(ui.gold_progress.total==168,"Repeating the successful retry cannot pay again")
	# Battle failure must keep the account untouched even when loaded successfully.
	ui=NoticeTests.make_ui(host,folder.path_join("battle-failure"))
	scenes.append(ui)
	await host.get_tree().process_frame
	Campaign.depart(ui)
	good_battle=ui.run_store.path
	ui.run_store.path=folder.path_join("missing-battle/battle.save")
	finish_campaign(ui)
	verify.call(ui.battle_save_error!=OK and data(ui).state=="pending" and not data(ui).saved and ui.gold_progress.total==0,"Failed terminal battle persistence cannot confirm or credit a quoted reward")
	verify.call(ui.dialog_body.get_child(1) is Button and ui.dialog_body.get_child(1).pressed.is_connected(ui._retry_battle_save),"Battle-save failure prioritizes its actual recovery action at the top")
	ui.run_store.path=good_battle
	ui._retry_battle_save()
	verify.call(data(ui).state=="paid" and ui.gold_progress.total==168,"Original battle retry then settlement reaches the actual paid state")
	for outcome in ["defeat","timeout","abandoned"]:
		ui=NoticeTests.make_ui(host,folder.path_join(outcome))
		scenes.append(ui)
		await host.get_tree().process_frame
		Campaign.depart(ui)
		quiet(ui.simulation)
		ui.simulation.gold_collected=321
		if outcome=="defeat":ui.simulation.damage_player(10000)
		elif outcome=="timeout":
			ui.simulation.elapsed=359.99
			ui.simulation.checkpoint_index=2
			ui._physics_process(.02)
		else:
			ui.pause_game()
			ui._request_transition("leave",ui.simulation.navigation_ticket,ui._menu_revision)
			ui.confirm_button.pressed.emit()
		ui._sync_phase_ui()
		verify.call(data(ui).state=="unpaid" and ui.result_summary_label.text.contains("보상 미지급 · 0 금화") and not ui.result_summary_label.text.contains("지급 대기"),"Nonclear outcome truthfully stays unpaid rather than a promised later payout: "+outcome)
		verify.call(ui.gold_progress.total==0 and ui.gold_progress.next_stage==1 and ui.simulation.result_summary().gold_reward==0,"No partial payment or campaign unlock introduced for "+outcome)
	# Authentic daily admission and separate dungeon ledger.
	for outcome in ["cleared","defeat","abandoned"]:
		ui=NoticeTests.make_ui(host,folder.path_join("dungeon-"+outcome))
		scenes.append(ui)
		await host.get_tree().process_frame
		ui._open_gold_dungeon()
		ui.dungeon_launch_button.pressed.emit()
		quiet(ui.simulation)
		ui.simulation.gold_collected=100000 # Receipt fixture,not an income measurement.
		good_gold=ui.gold_progress.path
		ui.gold_progress.path=folder.path_join("missing-dungeon-"+outcome+"/gold.cfg")
		if outcome=="cleared":Dungeon.finish(ui.simulation)
		elif outcome=="defeat":ui.simulation.damage_player(10000)
		else:
			ui.pause_game()
			ui._request_transition("leave",ui.simulation.navigation_ticket,ui._menu_revision)
			ui.confirm_button.pressed.emit()
		ui._sync_phase_ui()
		var expected:String="pending" if outcome=="cleared" else "unpaid"
		verify.call(ui.gold_error!=OK and data(ui).state==expected and ui.gold_progress.total==0 and ui.gold_progress.dungeon.used==1,"Failed dungeon close/payment keeps original admission and honest status: "+outcome)
		if outcome!="cleared":verify.call(ui.result_summary_label.text.contains("던전 종료 기록 저장 대기"),"Zero-reward dungeon closes its entry separately from reward payment")
		ui.gold_progress.path=good_gold
		ui._retry_gold_save()
		var reward:int=100000 if outcome=="cleared" else 0
		verify.call(data(ui).state==("paid" if outcome=="cleared" else "unpaid") and ui.gold_progress.total==reward and ui.gold_progress.next_stage==1 and ui.gold_progress.dungeon.closed_id==ui.simulation.run_id,"Dungeon retry confirms its own ledger without campaign unlock: "+outcome)
		verify.call(ui.gold_progress.dungeon.used==1 and ui.gold_progress.dungeon.initial.is_empty() and not ui.lobby_button.disabled,"Dungeon close consumes one admission and releases existing navigation after success")
		ui._retry_gold_save()
		verify.call(ui.gold_progress.total==reward and ui.gold_progress.dungeon.used==1,"Dungeon repeat cannot repay or recharge an admission")
	for scene in scenes:scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().create_timer(1.0).timeout
