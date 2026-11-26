extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Store=preload("res://scripts/progression/run_store.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Notice=preload("res://scripts/ui/battle_save_notice.gd")
const Campaign=preload("res://tests/test_campaign.gd")

static func make_ui(host,folder:String,save_path:String=""):
	DirAccess.make_dir_recursive_absolute(folder)
	var ui=load("res://scenes/main.tscn").instantiate()
	ui.run_store.path=folder.path_join("battle.save") if save_path.is_empty() else save_path
	ui.gold_progress.path=folder.path_join("gold.cfg")
	ui.settings_path=folder.path_join("settings.cfg")
	host.get_tree().root.add_child(ui)
	ui.set_physics_process(false)
	return ui

static func run(host,verify:Callable)->void:
	var folder:="user://save-notice-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var ui=make_ui(host,folder)
	await host.get_tree().process_frame
	Campaign.depart(ui)
	var state=ui.simulation
	state.spawn_clock=999
	state.shot_clock=999
	state._scatter_clock=999
	state._swarm_clock=999
	state.player=Vector2(2500,1700)
	verify.call(ui.battle_save_error==OK and ui.save_notice.count_for(state.run_id)==0 and not ui.save_notice.visible(state,OK),"Initial successful admission seeds status without a false checkpoint toast")
	state.hp=77
	state.magic.mana=61.5
	state.elapsed=119.96 # Boundary fixture,not a natural two-minute measurement.
	ui._physics_process(.05)
	verify.call(state.checkpoint_index==1 and ui._saved_checkpoint==1 and ui.save_notice.checkpoint==1 and ui.save_notice.sequence==1,"Actual checkpoint step and successful file write produce exactly one confirmed notice")
	verify.call(ui.mission_button.text.contains("저장됨") and ui.save_notice.visible(state,OK),"The existing interactive mission button exposes confirmed saving without a new hit area")
	var disk=Store.new()
	disk.path=ui.run_store.path
	verify.call(disk.load_saved(state)==OK and disk.pending.run.checkpoint_index==1 and disk.pending.run.hp==77,"A displayed confirmation corresponds to the actual readable snapshot on disk")
	var until:float=ui.save_notice.until
	var sequence:int=ui.save_notice.sequence
	var before:Dictionary=Snapshot.capture(state)
	var cues:Dictionary=state.cues.snapshot()
	for index in range(30):ui._update_hud()
	verify.call(before==Snapshot.capture(state) and cues==state.cues.snapshot() and ui.save_notice.sequence==sequence,"Repeated status layout changes no state,offers,rewards,RNG or notification count")
	ui._ensure_battle_saved()
	ui._set_volume(.45)
	verify.call(ui.save_notice.sequence==sequence and ui.save_notice.until==until,"Duplicate saves at the same checkpoint and settings saves cannot extend or repeat the toast")
	var text:String=ui._saved_battle_text()
	verify.call(text.contains("캠페인 S1") and text.contains(state.map_space.definition.name) and text.contains("진행 02:00") and text.contains("HP 77 · MP %.1f" % float(ui.run_store.pending.magic.mana)),"Saved summary uses actual mode/map/progress/HP/MP rather than live defaults or invented maximums")
	ui.pause_game()
	verify.call(ui.dialog_body.get_child(1)==ui.resume_button and ui._saved_context_label.visible and ui._saved_context_label.text.contains("마지막 전투 저장"),"Paused Continue stays at the top with confirmed saved context below it")
	var frozen:Dictionary=Snapshot.capture(state)
	ui._physics_process(.5)
	verify.call(frozen==Snapshot.capture(state) and ui.save_notice.until==until and not ui.mission_button.visible,"Pause freezes the simulation-time notice without replaying it")
	ui.resume_button.pressed.emit()
	verify.call(ui.save_notice.visible(state,OK) and ui.save_notice.sequence==sequence,"Explicit resume keeps only the remaining notice time")
	var path:String=ui.run_store.path
	var file_before:PackedByteArray=FileAccess.get_file_as_bytes(path)
	ui.run_store.path=folder.path_join("missing-parent/battle.save")
	state.elapsed=239.96
	ui._physics_process(.05)
	verify.call(state.checkpoint_index==2 and state.phase==State.Phase.PAUSED and ui.battle_save_error!=OK,"An actual failed checkpoint write keeps the existing pause/retry recovery")
	verify.call(ui.save_notice.checkpoint==1 and ui._saved_checkpoint==1 and not ui.save_notice.visible(state,ui.battle_save_error) and not ui._saved_context_label.visible,"Uncommitted progress cannot advertise a saved checkpoint or success card")
	verify.call(ui.stage_text.text.contains("저장 1/2") and FileAccess.get_file_as_bytes(path)==file_before,"Confirmed checkpoint text and original durable file survive failed writing")
	ui.run_store.path=path
	ui._retry_battle_save()
	verify.call(ui.battle_save_error==OK and ui.save_notice.checkpoint==2 and ui.save_notice.sequence==sequence+1 and ui._saved_context_label.visible,"A successful explicit retry confirms checkpoint2 once and restores its real summary")
	ui._retry_battle_save()
	verify.call(ui.save_notice.sequence==sequence+1,"Repeating a successful retry does not invent another checkpoint confirmation")
	var saved_hp:int=ui.run_store.pending.run.hp
	state.hp=99 # Distinguish current values from the already confirmed snapshot.
	ui._refresh_save_context()
	verify.call(ui._saved_context_label.text.contains("HP %d ·" % saved_hp) and not ui._saved_context_label.text.contains("HP 99 ·"),"Saved context remains the persisted HP rather than a later live mutation")
	state.hp=saved_hp
	var ui2=make_ui(host,folder.path_join("reload"),path)
	await host.get_tree().process_frame
	var ready_info:Label=ui2.dialog_body.get_node("SavedBattleSummary")
	verify.call(ui2.simulation.phase==State.Phase.READY and ui2.start_button.text=="이어하기" and ready_info.text.contains("체크포인트 2/2") and ready_info.text.contains("HP %d ·" % saved_hp),"Fresh UI advertises the real stored checkpoint/resources and waits for explicit Continue")
	var saved_data:Dictionary=ui2.run_store.pending.duplicate(true)
	ui2.start_button.pressed.emit()
	verify.call(ui2.simulation.phase==State.Phase.PAUSED and ui2.save_notice.sequence==0 and not ui2.save_notice.visible(ui2.simulation,OK),"Restore normalization may save but cannot emit a fake new checkpoint toast or auto-resume")
	verify.call(ui2.simulation.hp==saved_hp and ui2._saved_context_label.text.contains("진행 04:00"),"Paused restored context retains real progress and resources")
	var reference=State.new()
	Snapshot.restore(saved_data,reference)
	reference.set_paused(false)
	ui2.resume_button.pressed.emit()
	reference.spawn_view_size=ui2.simulation.spawn_view_size
	var same:=true
	for frame in range(100):
		reference.step(.05,Vector2.ZERO)
		ui2._physics_process(.05)
		same=same and Campaign.comparable(reference)==Campaign.comparable(ui2.simulation)
	verify.call(same and ui2.save_notice.sequence==0,"Confirmed status preserves100restored production steps and sevenRNG with no fake re-save")
	verify.call(not ui2.save_notice.visible(ui2.simulation,OK),"Old saved checkpoints do not become a new toast in a running restored battle")
	ui2.pause_game()
	ui2._request_transition("restart",ui2.simulation.navigation_ticket,ui2._menu_revision)
	ui2.confirm_button.pressed.emit()
	verify.call(ui2.simulation.run_id!=str(saved_data.run.run_id) and ui2.save_notice.checkpoint==0 and not ui2.save_notice.visible(ui2.simulation,OK),"Existing confirmed restart resets only presentation status for the new run")
	var summary_before:Dictionary=ui.run_store.pending.duplicate(true)
	var summary:String=Notice.summary(summary_before,ui.simulation.map_catalog)
	verify.call(summary_before==ui.run_store.pending and not summary.is_empty(),"Formatting a saved card cannot rewrite its snapshot")
	var gold=State.new()
	gold.start(3202,"viya",null,"gold_slime","weapons_v1",{},"gold_slime",20000)
	var data:Dictionary=Snapshot.capture(gold)
	data.run.elapsed=60.0
	data.run.checkpoint_index=1
	data.growth.pending=1
	data.magic.mana=42.25
	summary=Notice.summary(data,gold.map_catalog)
	verify.call(summary.contains("골드 던전") and summary.contains("진행 01:00") and summary.contains("추가 입장 횟수") and summary.contains("남은 성장 선택 1회"),"Dungeon and pending-choice cards use saved mode/resources without promising campaign unlocks or rerolling offers")
	var helper=Notice.new()
	helper.seed(data,OK)
	verify.call(helper.checkpoint==1 and helper.sequence==0 and helper.until<0,"Seeding a historical confirmed checkpoint is neutral")
	helper.confirmed(data,ERR_FILE_CANT_WRITE,gold,true)
	verify.call(helper.sequence==0 and helper.until<0,"A reported persistence error cannot manufacture success")
	data.run.phase=State.Phase.CLEARED
	verify.call(Notice.summary(data,gold.map_catalog).is_empty(),"Terminal results are not presented as resumable saved battles")
	ui.queue_free()
	ui2.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().create_timer(.06).timeout
