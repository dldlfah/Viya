extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Notice=preload("res://scripts/ui/encounter_notice.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const SavedTests=preload("res://tests/test_battle_save_notice.gd")

static func quiet(state) -> void:
	state.spawn_clock=999
	state.shot_clock=999
	state._scatter_clock=999
	state._swarm_clock=999

static func run(host,verify:Callable)->void:
	var state=State.new()
	state.start(3701,"viya",null,"prologue_wall","weapons_v1")
	quiet(state)
	var notice=Notice.new()
	notice.seed(state)
	state.elapsed=float(state.stage_rules.elites[0])-.01
	notice.observe(state)
	verify.call(not notice.visible(state),"Scheduled time alone cannot announce an elite")
	state.step(.02,Vector2.ZERO)
	var saved:Dictionary=Snapshot.capture(state)
	notice.observe(state)
	verify.call(state._elites_spawned==1 and notice.visible(state) and notice.current.id==state.enemies[0].id,"Only an actually successful scheduled elite spawn announces its live ID")
	verify.call(notice.summary(state).contains(state.enemy_definition(state.enemies[0].species).name),"Actual elite species uses its original catalog name")
	for index in range(100):notice.observe(state)
	verify.call(notice.sequence==1 and Snapshot.capture(state)==saved,"Repeated inspection neither repeats the announcement nor changes authoritative state/sevenRNG")
	state.elapsed+=Notice.NOTICE_SECONDS
	notice.observe(state)
	verify.call(not notice.visible(state) and notice.current.is_empty(),"The announcement expires on simulation time without a wall timer")
	state._scatter_index+=1
	state.add_enemy(state.player+Vector2(400,0),"normal","fast",state._scatter_index)
	state.add_enemy(state.player+Vector2(400,0),"normal","ranged")
	notice.observe(state)
	verify.call(notice.sequence==1 and not notice.visible(state),"Normal ranged and scatter formations never create special-enemy announcements")
	verify.call(not state.add_enemy(state.player,"boss","fast") and notice.sequence==1,"Rejected enemy variants cannot manufacture an arrival")
	# Capacity failure at the real scheduled threshold, then a later successful retry.
	state.start(3702)
	quiet(state)
	for index in range(state.MAX_ENEMIES-1):state.add_enemy(state.player+Vector2(600,0))
	notice.seed(state)
	state.elapsed=float(state.stage_rules.elites[0])-.01
	state.step(.02,Vector2.ZERO)
	notice.observe(state)
	verify.call(state._elites_spawned==0 and not notice.visible(state),"A saturated scheduled elite attempt remains silent")
	state.enemies.pop_back()
	state.step(.02,Vector2.ZERO)
	notice.observe(state)
	verify.call(state._elites_spawned==1 and notice.visible(state),"A later successful retry, rather than its failed deadline, triggers the cue")
	# One bounded batch with deterministic boss priority, no later elite replay.
	state.start(3703)
	quiet(state)
	notice.seed(state)
	state.add_enemy(state.player+Vector2(500,0),"elite")
	state.add_enemy(state.player+Vector2(600,0),"boss")
	state.add_enemy(state.player+Vector2(700,0),"elite")
	notice.observe(state)
	var boss_id:int=notice.current.id
	var sequence:int=notice.sequence
	verify.call(notice.current.kind=="boss" and notice.living.size()==3,"Simultaneous actual arrivals consume one bounded batch with boss priority")
	state.add_enemy(state.player+Vector2(500,0),"elite")
	notice.observe(state)
	verify.call(notice.current.id==boss_id and notice.sequence==sequence,"A later elite cannot replace an unexpired boss arrival")
	state.elapsed=Notice.NOTICE_SECONDS
	notice.observe(state)
	verify.call(not notice.visible(state) and notice.sequence==sequence,"Suppressed simultaneous elites cannot form a delayed replay queue")
	notice.seed(state)
	verify.call(not notice.visible(state) and notice.living.size()==4,"Existing live actors seed neutrally at UI construction/recovery")
	state.enemies.clear()
	notice.observe(state)
	verify.call(notice.living.is_empty(),"Removed actors are pruned rather than accumulating a session history")
	state.add_enemy(state.player+Vector2(500,0),"boss")
	notice.observe(state)
	state.enemies.clear()
	notice.observe(state)
	verify.call(not notice.visible(state),"A dead or removed announced actor leaves no stale live arrival")
	state.add_enemy(state.player+Vector2(500,0),"elite")
	notice.observe(state)
	state.elapsed=-.01
	notice.observe(state)
	verify.call(not notice.visible(state),"A rewound clock seeds neutrally rather than replaying old arrivals")
	# Actual F5 UI: spawn -> unchanged mission hit area -> pause/choice/resume.
	var folder:="user://encounter-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var ui=SavedTests.make_ui(host,folder)
	await host.get_tree().process_frame
	Campaign.depart(ui)
	state=ui.simulation
	quiet(state)
	var hit_area:Rect2=ui.mission_button.get_global_rect()
	state.elapsed=float(state.stage_rules.elites[0])-.01
	ui._physics_process(.02)
	verify.call(ui.encounter_notice.visible(state) and ui.mission_button.text.contains("정예 등장") and hit_area==ui.mission_button.get_global_rect(),"Real battle step changes the existing mission caption without adding an input area")
	var message:String=ui.encounter_notice.summary(state)
	verify.call(ui.mission_button.tooltip_text.begins_with(message),"The compact cue retains the real species and full mission context")
	var until:float=ui.encounter_notice.until
	ui._open_mission(state.navigation_ticket,ui._menu_revision)
	for frame in range(10):ui._physics_process(.05)
	verify.call(ui._mission_open and not ui.mission_button.visible and ui.encounter_notice.until==until,"Opening the existing mission freezes and hides the arrival with the battle")
	verify.call(ui.dialog_body.get_children().any(func(child):return child is Label and child.text==message),"Touching the original mission exposes the actual species using existing paused context")
	ui.mission_return_button.pressed.emit()
	verify.call(state.phase==State.Phase.RUNNING and ui.encounter_notice.visible(state),"Guarded mission return retains the unexpired cue")
	state.grant_xp(state.growth.threshold())
	ui._sync_phase_ui()
	ui._update_hud()
	var offer:Array=state.growth.offer.duplicate()
	var elapsed:float=state.elapsed
	for frame in range(10):ui._physics_process(.05)
	verify.call(state.phase==State.Phase.CHOOSING and not ui.mission_button.visible and state.elapsed==elapsed and state.growth.offer==offer,"Actual growth selection freezes arrival lifetime and the original offer")
	ui.choice_buttons[0].pressed.emit()
	verify.call(state.phase==State.Phase.RUNNING and ui.encounter_notice.visible(state),"An actual selection returns to the same remaining arrival")
	# Checkpoint feedback wins; the bounded arrival waits for that confirmed notice.
	quiet(state)
	state.elapsed=119.99
	state.add_enemy(state.player+Vector2(600,0),"boss")
	ui._physics_process(.02)
	verify.call(ui.save_notice.visible(state,OK) and ui.mission_button.text.contains("저장됨") and not ui.encounter_notice.visible(state),"Real checkpoint save success retains mission priority over a simultaneous boss")
	verify.call(is_equal_approx(ui.encounter_notice.starts_at,ui.save_notice.until),"The one arrival is deferred until confirmed-save feedback finishes")
	state.elapsed=ui.save_notice.until
	ui._update_hud()
	verify.call(ui.mission_button.text.contains("보스 등장") and ui.encounter_notice.visible(state),"A still-live boss is announced after saving without another spawn or modal")
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(ui.run_store.path)
	saved=Snapshot.capture(state)
	for index in range(100):ui._update_hud()
	verify.call(bytes==FileAccess.get_file_as_bytes(ui.run_store.path) and saved==Snapshot.capture(state),"Showing arrivals does not write battles, replenish resources, spend currency or advance RNG")
	ui.pause_game()
	var pending:Dictionary=ui.run_store.pending.duplicate(true)
	var ui2=SavedTests.make_ui(host,folder)
	await host.get_tree().process_frame
	verify.call(ui2.simulation.phase==State.Phase.READY and ui2.encounter_notice.current.is_empty(),"A second real UI waits at the lobby with no old arrival")
	ui2.start_button.pressed.emit()
	verify.call(ui2.simulation.phase==State.Phase.PAUSED and ui2.encounter_notice.current.is_empty(),"Actual binary restore seeds old living elite/boss IDs silently")
	var reference=State.new()
	Snapshot.restore(pending,reference)
	reference.set_paused(false)
	ui2.resume_button.pressed.emit()
	reference.spawn_view_size=ui2.simulation.spawn_view_size
	var same:=true
	for frame in range(100):
		reference.step(.05,Vector2.ZERO)
		ui2._physics_process(.05)
		same=same and Campaign.comparable(reference)==Campaign.comparable(ui2.simulation)
	verify.call(same and ui2.encounter_notice.sequence==0,"Explicit Continue preserves100running steps/sevenRNG and never re-announces restored actors")
	# Only a genuinely new scheduled actor after recovery can announce.
	state=ui2.simulation
	quiet(state)
	state.elapsed=float(state.stage_rules.boss_at)-.01
	ui2._physics_process(.02)
	verify.call(state._boss_spawned and ui2.encounter_notice.current.kind=="boss" and ui2.encounter_notice.sequence==1,"A new scheduled boss after recovery still announces normally")
	for phase in [State.Phase.DEFEAT,State.Phase.CLEARED,State.Phase.ABANDONED,State.Phase.READY]:
		state.phase=phase
		ui2._update_hud()
		verify.call(ui2.encounter_notice.current.is_empty() and not ui2.mission_button.visible,"Terminal/lobby phase clears arrivals: "+str(phase))
	state.start(3704,"viya",null,"gold_slime","weapons_v1",{},"gold_slime",20000)
	ui2._after_run_started()
	state._spawn_enemy()
	ui2._update_hud()
	verify.call(not ui2.encounter_notice.visible(state) and ui2.encounter_notice.living.is_empty(),"Boss-free dungeon start and actual slime spawning clear campaign arrivals")
	# Legacy actors have no species; use the existing neutral role, never invent a name.
	state.start(3705)
	state.combat_profile_version=0
	ui2._after_run_started()
	state.add_enemy(state.player+Vector2(500,0),"elite")
	ui2._update_hud()
	verify.call(ui2.encounter_notice.summary(state)=="정예 등장","Species-free legacy actors use a neutral role")
	ui.queue_free()
	ui2.queue_free()
	await host.get_tree().process_frame
