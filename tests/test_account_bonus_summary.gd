extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Talents=preload("res://scripts/progression/account_talents.gd")
const Summary=preload("res://scripts/ui/account_bonus_summary.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const NoticeTests=preload("res://tests/test_battle_save_notice.gd")

static func panel(ui) -> Control:
	return ui.dialog_body.get_node("AccountBonusSummary")

static func info(ui) -> Dictionary:
	return panel(ui).get_meta("summary")

static func fund(ui,amount:int) -> void:
	ui.gold_progress.settle({"outcome":"cleared","run_id":"summary-fixture-funds","stage":1,"gold_reward":amount})
	ui._show_menu("ready")

static func buy(ui,id:String,rank:int) -> void:
	var category:String=Talents.DEFINITIONS[id].category
	ui._select_talent_category(category,ui.simulation.navigation_ticket,ui._menu_revision)
	ui.talent_buttons_by_id[id][rank].pressed.emit()

static func run(host,verify:Callable) -> void:
	var none:Dictionary=Talents.empty_levels()
	var data:Dictionary=Summary.for_levels(none)
	verify.call(data.available and data.total==0 and data.sections.size()==3 and data.sections.all(func(section):return section.entries.is_empty()),"Fresh account summary identifies zero additional bonuses without inventing base stats")
	var full:Dictionary=Talents.empty_levels()
	for id in full:full[id]=3
	data=Summary.for_levels(full)
	verify.call(data.available and data.total==54 and data.bonuses==Talents.bonuses(full) and data.sections.reduce(func(count,section):return count+section.entries.size(),0)==18,"All54owned ranks are summarized through the same eighteen-trait effect table")
	var exact:=true
	for section in data.sections:
		for entry in section.entries:exact=exact and entry.text=="%s %s" % [Talents.DEFINITIONS[entry.id].name,Talents.effect_text(entry.id,3)]
	verify.call(exact and data.bonuses.attack_power==.15 and data.detail.contains("+15%") and not data.detail.contains("+30%"),"Cumulative ranks are not added together and every displayed unit comes from original effect_text")
	data.levels.attack_power=0
	verify.call(full.attack_power==3,"Returned presentation data is detached from the owned levels")
	var invalid:Dictionary=none.duplicate()
	invalid.crit_chance=1
	verify.call(not Summary.for_levels(invalid).available and not Summary.for_levels({}).available,"Malformed/parent-locked levels are unavailable rather than fabricated zero enhancements")
	var folder:="user://account-summary-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var ui=NoticeTests.make_ui(host,folder.path_join("campaign"))
	await host.get_tree().process_frame
	fund(ui,2000000)
	ui.talents_button.pressed.emit()
	buy(ui,"attack_power",0)
	buy(ui,"max_hp",0)
	buy(ui,"mp_regen",0)
	verify.call(ui.gold_progress.total==1997000 and ui.gold_progress.talent_levels.attack_power==1,"Existing actual purchase buttons charge three1000gold roots before summary")
	ui.talents_return_button.pressed.emit()
	ui.start_button.pressed.emit()
	data=info(ui)
	verify.call(ui._modal_kind=="stages" and data.levels==ui.gold_progress.talent_levels and data.total==3 and data.brief.contains("공격력 증가 +5%") and data.brief.contains("최대 HP 증가 +5%") and data.brief.contains("초당 MP 회복 +0.05"),"Production stage preparation shows the actual purchased attack/defense/recovery bonuses")
	verify.call(ui.dialog_body.get_child(2)==ui.stage_launch_button and ui.dialog_body.get_child(3)==ui.stage_back_button,"Existing launch/back actions remain above expandable information")
	var frozen:Dictionary=Snapshot.capture(ui.simulation)
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(ui.gold_progress.path)
	var stale:Callable=ui._toggle_account_summary.bind(ui.simulation.navigation_ticket,ui._menu_revision)
	panel(ui).get_node("Toggle").pressed.emit()
	verify.call(panel(ui).get_node("Details").visible and info(ui).detail.contains("초당 MP 회복 +0.05"),"Existing preparation expands owned effects without another game state")
	panel(ui).get_node("Toggle").pressed.emit()
	verify.call(not panel(ui).get_node("Details").visible and frozen==Snapshot.capture(ui.simulation) and FileAccess.get_file_as_bytes(ui.gold_progress.path)==bytes,"Summary expand/collapse changes no account file,resources,offers or RNG")
	ui.stage_back_button.pressed.emit()
	stale.call()
	verify.call(ui._modal_kind=="ready" and not ui.dialog_body.has_node("AccountBonusSummary") and frozen==Snapshot.capture(ui.simulation),"Delayed summary callbacks after Back are rejected by existing ticket/revision guards")
	ui.start_button.pressed.emit()
	ui.stage_launch_button.pressed.emit()
	verify.call(ui.simulation.account_talent_levels==data.levels and ui.simulation.max_hp==105 and is_equal_approx(ui.simulation.stats.power,1.05) and is_equal_approx(ui.simulation.magic.bonus_mana_regen,.05),"Original single-run campaign launch applies the same bonuses actually displayed")
	ui.simulation.hp=31
	ui.simulation.magic.mana=12.25
	ui.pause_game()
	verify.call(info(ui).levels==data.levels and ui.dialog_body.get_child(1)==ui.resume_button,"Paused summary reads the current run's departure-time levels while Continue stays first")
	ui._park_battle()
	ui.talents_button.pressed.emit()
	buy(ui,"attack_power",1)
	verify.call(ui.gold_progress.total==1947000 and ui.gold_progress.talent_levels.attack_power==2,"Account can buy the original50000gold second rank while its old battle is parked")
	ui.talents_return_button.pressed.emit()
	verify.call(info(ui).levels.attack_power==1 and info(ui).bonuses.attack_power==.05 and ui.gold_progress.talent_levels.attack_power==2,"Saved-battle summary uses original departure levels,not later account upgrades")
	verify.call(str(panel(ui).get_meta("caption")).contains("출격 당시") and ui._saved_battle_text().contains("출격 당시 계정 강화"),"Current account versus saved departure-time enhancements is explicit")
	var pending:Dictionary=ui.run_store.pending.duplicate(true)
	bytes=FileAccess.get_file_as_bytes(ui.gold_progress.path)
	panel(ui).get_node("Toggle").pressed.emit()
	verify.call(pending==ui.run_store.pending and FileAccess.get_file_as_bytes(ui.gold_progress.path)==bytes,"Inspecting saved bonuses never rewrites the battle or account")
	ui.start_button.pressed.emit()
	verify.call(ui.simulation.phase==State.Phase.PAUSED and info(ui).levels.attack_power==1 and ui.simulation.hp==31 and ui.simulation.magic.mana==12.25,"Explicit Continue retains original enhancement levels and spent HP/MP without retroactive healing")
	ui.resume_button.pressed.emit()
	verify.call(ui.simulation.account_talent_levels.attack_power==1 and is_equal_approx(ui.simulation.stats.power,1.05),"Resumed combat does not apply the newer account's10percent power")
	ui.pause_game()
	ui._request_transition("leave",ui.simulation.navigation_ticket,ui._menu_revision)
	ui.confirm_button.pressed.emit()
	ui.lobby_button.pressed.emit()
	ui.start_button.pressed.emit()
	verify.call(info(ui).levels.attack_power==2 and info(ui).bonuses.attack_power==.10,"After ending the old battle,the next departure preview uses current account upgrades")
	ui.stage_launch_button.pressed.emit()
	verify.call(ui.simulation.account_talent_levels.attack_power==2 and is_equal_approx(ui.simulation.stats.power,1.10) and ui.simulation.hp==105,"Only a real new start applies the updated bonus and normal starting HP")
	var ui2=NoticeTests.make_ui(host,folder.path_join("dungeon"))
	await host.get_tree().process_frame
	fund(ui2,100000)
	for id in ["mp_regen","max_mana","mana_cost_reduction"]:ui2.gold_progress.purchase_talent(id,0)
	ui2._show_menu("ready")
	ui2._open_gold_dungeon()
	verify.call(info(ui2).total==3 and info(ui2).bonuses.max_mana==5 and info(ui2).bonuses.mana_cost_reduction==.02 and info(ui2).detail.contains(Talents.effect_text("mana_cost_reduction",1)),"Dungeon summary includes active child traits through the same table and correct reduction units")
	frozen=Snapshot.capture(ui2.simulation)
	bytes=FileAccess.get_file_as_bytes(ui2.gold_progress.path)
	panel(ui2).get_node("Toggle").pressed.emit()
	verify.call(ui2.gold_progress.dungeon.used==0 and frozen==Snapshot.capture(ui2.simulation) and FileAccess.get_file_as_bytes(ui2.gold_progress.path)==bytes,"Previewing dungeon enhancements consumes no admission or file write")
	verify.call(ui2.dialog_body.get_child(2)==ui2.dungeon_launch_button and ui2.dungeon_launch_button.disabled==false,"Existing dungeon admission action stays above expanded details")
	ui2.dungeon_launch_button.pressed.emit()
	verify.call(ui2.simulation.run_mode=="gold_slime" and ui2.gold_progress.dungeon.used==1 and ui2.simulation.magic.maximum_mana()==105 and is_equal_approx(ui2.simulation.magic.mana_cost_scale,.98),"Actual dungeon start applies displayed MP bonuses and consumes exactly one normal admission")
	verify.call(not Summary.for_account(ui2.gold_progress,ERR_FILE_CORRUPT).available,"Failed account state cannot advertise cached bonuses as confirmed")
	verify.call(not Summary.for_saved(pending,ERR_FILE_CORRUPT).available and not Summary.for_saved({},OK).available,"Unreadable or absent battle does not invent zero departure-time enhancements")
	ui2.pause_game()
	var own:Dictionary=info(ui2)
	ui2.gold_progress.loaded=false
	verify.call(not Summary.for_account(ui2.gold_progress,OK).available and own.available,"Valid live battle bonuses remain separate from an unreadable current account")
	var ui3=NoticeTests.make_ui(host,folder.path_join("errors"))
	await host.get_tree().process_frame
	fund(ui3,999)
	ui3.talents_button.pressed.emit()
	buy(ui3,"attack_power",0)
	ui3.talents_return_button.pressed.emit()
	ui3.start_button.pressed.emit()
	verify.call(info(ui3).total==0 and ui3.gold_progress.total==999,"Insufficient-funds purchase cannot appear as an acquired departure bonus")
	ui3.stage_back_button.pressed.emit()
	ui3.talents_button.pressed.emit()
	buy(ui3,"crit_chance",0)
	ui3.talents_return_button.pressed.emit()
	ui3.start_button.pressed.emit()
	verify.call(info(ui3).sections.all(func(section):return section.entries.is_empty()),"Parent-locked purchase cannot leak a child bonus into preparation")
	ui3.stage_back_button.pressed.emit()
	# Existing account file starts at999; one additional valid settlement funds a retry.
	ui3.gold_progress.settle({"outcome":"cleared","run_id":"summary-fixture-extra","stage":2,"gold_reward":1})
	ui3._show_menu("ready")
	ui3.talents_button.pressed.emit()
	# Keep account identity unchanged; block the actual atomic temporary write.
	var temporary:String=ui3.gold_progress.path+".tmp"
	DirAccess.make_dir_absolute(temporary)
	buy(ui3,"attack_power",0)
	DirAccess.remove_absolute(temporary)
	ui3.talents_return_button.pressed.emit()
	ui3.start_button.pressed.emit()
	verify.call(info(ui3).total==0 and ui3.gold_progress.total==1000,"Failed atomic purchase write preserves zero bonus and gold (ranks=%d,gold=%d)" % [int(info(ui3).get("total",-1)),ui3.gold_progress.total])
	ui3.stage_back_button.pressed.emit()
	ui3.gold_error=ERR_FILE_CORRUPT
	ui3._open_stages()
	verify.call(not info(ui3).available and panel(ui3).get_node("Toggle").disabled and ui3.stage_launch_button.disabled,"Unreadable account shows unavailable enhancement information and preserves original launch blocking")
	ui.queue_free()
	ui2.queue_free()
	ui3.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().create_timer(1.0).timeout
