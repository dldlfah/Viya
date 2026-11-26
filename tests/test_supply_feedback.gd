extends RefCounted
const Supplies=preload("res://tests/test_supplies.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const State=preload("res://scripts/combat/run_state.gd")
const NoticeTests=preload("res://tests/test_battle_save_notice.gd")

static func latest(state) -> Dictionary:
	for index in range(state.cues.events.size()-1,-1,-1):
		if state.cues.events[index].kind=="item":return state.cues.events[index]
	return {}

static func collect(state,kind:String) -> Dictionary:
	var drop:Dictionary=Supplies.drop(state,kind)
	drop.p=state.player
	state._collect_items(0)
	return latest(state)

static func run(host,verify:Callable) -> void:
	var state=Supplies.quiet()
	state.hp=10
	var event:Dictionary=collect(state,"hp")
	verify.call(state.hp==40 and event.label=="HP +30" and event.supply.hp==30,"Actual destroyed HP supply reports committed recovery rather than its generic name")
	state.hp=state.max_hp-1
	event=collect(state,"hp")
	verify.call(state.hp==state.max_hp and event.label=="HP +1" and event.supply.hp==1,"Near-full HP reports only the one HP actually restored")
	event=collect(state,"hp")
	verify.call(event.label=="HP 가득 참" and event.supply.hp==0 and not event.label.contains("+"),"Full HP consumption cannot claim fictional recovery")
	state.magic.mana=state.magic.maximum_mana()-.05
	event=collect(state,"mp")
	verify.call(is_equal_approx(event.supply.mp,.05) and event.label=="MP +0.05" and state.magic.mana==state.magic.maximum_mana(),"Fractional near-full MP displays its actual delta rather than thirty MP")
	event=collect(state,"mp")
	verify.call(event.supply.mp==0 and event.label=="MP 가득 참","Full MP has a truthful non-recovery receipt")
	state.magic.mana=state.magic.maximum_mana()-.0001
	event=collect(state,"mp")
	verify.call(event.supply.mp>0 and not event.label.contains("가득 참") and not event.label.contains("+0 "),"Even tiny real MP recovery is distinguished from a full-resource pickup")
	var levels:Dictionary=State.AccountTalents.empty_levels()
	for id in levels:levels[id]=3
	state.start(3301,"viya",levels,"prologue_wall")
	state.hp=10
	event=collect(state,"hp")
	verify.call(state.hp==49 and is_equal_approx(state._regen_remainder,.675) and event.supply.hp==39 and event.label=="HP +39","Healing-efficiency and fractional HP carry retain their original mechanics while reporting integer HP gained")
	state=Supplies.quiet()
	state.add_pickup(Vector2(4900,3100),90)
	state.add_pickup(Vector2(100,500),60)
	state.gold_pickups.append({"p":Vector2(4900,500),"value":123})
	state.gold_pickups.append({"p":Vector2(100,3100),"value":456})
	event=collect(state,"magnet")
	verify.call(state.phase==State.Phase.CHOOSING and state.growth.pending==3 and state.gold_collected==579 and state.pickups.is_empty() and state.gold_pickups.is_empty(),"Map-wide collection still opens the existing queued choices and collects distant gold exactly once")
	verify.call(event.supply.xp==150 and event.supply.gold==579 and event.label=="전체 자석 · +150 XP / +579 금화","Magnet receipt reports weighted XP collected and earned gold,not drops merely spawned")
	var offer:Array=state.growth.offer.duplicate(true)
	var frozen:Dictionary=Snapshot.capture(state)
	state.step(.05,Vector2.ZERO)
	verify.call(frozen==Snapshot.capture(state) and latest(state)==event and state.growth.offer==offer,"Choice freezes the receipt and its existing offer instead of consuming or rerolling again")
	state.set_paused(true)
	var restored=State.new()
	verify.call(Snapshot.restore(Snapshot.capture(state),restored) and restored.growth.offer==offer and restored.gold_collected==579 and restored.cues.events.is_empty(),"Restoring a collected magnet preserves choices/gold without replaying its receipt")
	state=Supplies.quiet()
	event=collect(state,"magnet")
	verify.call(event.supply.xp==0 and event.supply.gold==0 and event.label=="전체 자석 · 회수할 XP·금화 없음","An empty map magnet cannot claim invented collection")
	state.elapsed=300
	state.checkpoint_index=2
	state.gold_drop_chance=1
	for variant in ["normal","ranged","fast","heavy","flier"]:state.add_enemy(state.player+Vector2(800,0),"normal",variant)
	state.add_enemy(state.player+Vector2(900,0),"elite")
	state.add_enemy(state.player+Vector2(1000,0),"boss")
	state._boss_spawned=true
	state.enemy_bullets.append({"p":state.player+Vector2(500,0),"velocity":Vector2.LEFT*200,"life":1.0,"damage":8})
	var boss:Dictionary=state.enemies[-1].duplicate(true)
	event=collect(state,"purge")
	verify.call(state.enemies.size()==1 and state.enemies[0]==boss and not state._boss_defeated and state.enemy_bullets.is_empty(),"Removal feedback never changes the surviving boss or hostile-bullet cleanup")
	verify.call(event.supply.kills==6 and event.supply.bullets==1 and event.label=="제거 6 · 탄환 1 · 보스 제외","Removal count includes the real elite and all ordinary variants but explicitly excludes the boss")
	verify.call(state.pickups.size()==6 and state.gold_pickups.size()==6 and state.gold_collected==0 and event.supply.gold==0,"Removal keeps rewards on the ground rather than advertising uncollected gold as earned")
	event=collect(state,"purge")
	verify.call(event.supply.kills==0 and event.label=="제거 0 · 보스 제외" and state.enemies[0]==boss,"A second removal beside only a boss cannot fabricate kills or duplicate rewards")
	var input:Dictionary=event.supply.duplicate(true)
	state.cues.record_item(state.player,"fallback",input)
	input.kills=999
	verify.call(latest(state).supply.kills==0,"Receipt payload is detached from its caller")
	var copy:Dictionary=state.cues.snapshot()
	copy.events[-1].supply.kills=999
	verify.call(latest(state).supply.kills==0,"Existing cue snapshots also detach pickup metadata")
	state.cues.record_item(state.player,"기존 아이템")
	verify.call(latest(state).label=="기존 아이템" and not latest(state).has("supply"),"Original two-argument item notifications remain compatible")
	for kind in ["hp","mp","magnet","purge"]:
		var a=Supplies.quiet()
		var b=State.new()
		Snapshot.restore(Snapshot.capture(a),b)
		b.set_paused(false)
		a.cues.set_enabled(false)
		for current in [a,b]:
			current.hp=20
			current.magic.mana=20.5
			current.add_enemy(current.player+Vector2(600,0))
			current.add_pickup(Vector2(4900,3100),15)
			collect(current,kind)
		verify.call(Campaign.comparable(a)==Campaign.comparable(b) and a.cues.events.is_empty(),"Disabling pickup presentation preserves effects,rewards and all seven RNG: "+kind)
	var folder:="user://supply-feedback-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var ui=NoticeTests.make_ui(host,folder)
	await host.get_tree().process_frame
	Campaign.depart(ui)
	state=ui.simulation
	state.spawn_clock=999
	state.shot_clock=999
	state._scatter_clock=999
	state._swarm_clock=999
	state.hp=73
	var item:Dictionary=Supplies.drop(state,"hp")
	item.p=state.player
	ui._physics_process(.05)
	verify.call(state.hp==100 and latest(state).label=="HP +27" and ui.combat_audio.played.get("pickup",0)==1,"Production physics reaches actual healing,one pickup receipt and existing pickup sound")
	var plan:Dictionary=preload("res://scripts/combat/combat_display.gd").build(ui.view)
	verify.call(plan.labels.any(func(label):return label.event.kind=="item" and label.text=="HP +27" and label.color.r>label.color.b),"The original read-only display plan uses the committed receipt and matching HP color")
	ui.pause_game()
	frozen=Snapshot.capture(state)
	var frozen_cues:Dictionary=state.cues.snapshot()
	ui._physics_process(.5)
	verify.call(frozen==Snapshot.capture(state) and frozen_cues==state.cues.snapshot(),"Paused production UI freezes pickup effects and receipt time")
	ui.resume_button.pressed.emit()
	for frame in range(27):ui._physics_process(.05)
	verify.call(not state.cues.events.any(func(e):return e.kind=="item") and ui.combat_audio.played.get("pickup",0)==1,"Active time expires pickup feedback without another sound or reward")
	state.cues.reset()
	state.elapsed=300
	state.checkpoint_index=2
	state._boss_spawned=true
	state._elites_spawned=2
	state.add_enemy(state.player+Vector2(1000,200),"boss")
	ui.view.size=Vector2(791,266)
	ui.view.boss_guidance=preload("res://scripts/combat/boss_guidance.gd").build(ui.view)
	state.cues.record_item(state.player,"",{"kind":"magnet","xp":35,"gold":579})
	state.cues.record_item(state.player,"",{"kind":"purge","kills":6,"bullets":1})
	item=Supplies.drop(state,"mp")
	item.p=state.player+Vector2(200,100)
	frozen=Snapshot.capture(state)
	frozen_cues=state.cues.snapshot()
	plan=preload("res://scripts/combat/combat_display.gd").build(ui.view)
	verify.call(plan.labels.any(func(label):return label.text.begins_with("전체 자석")) and plan.labels.any(func(label):return label.text.contains("제거 6") and label.text.contains("보스 제외")),"Compact boss guidance leaves readable fallback positions for both long pickup receipts")
	var item_box:Rect2=preload("res://scripts/combat/supply_feedback.gd").bounds(ui.view.world_to_screen(item.p),true)
	verify.call(plan.labels.all(func(label):return not label.rect.grow(2).intersects(item_box)) and plan.labels.size()<=plan.label_limit,"Pickup text preserves visible glyphs and the original label budget")
	verify.call(frozen==Snapshot.capture(state) and frozen_cues==state.cues.snapshot(),"Compact pickup planning remains read-only for resources,cues and seven RNG")
	ui.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().create_timer(.25).timeout
