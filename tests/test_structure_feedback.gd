extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Supplies=preload("res://tests/test_supplies.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const NoticeTests=preload("res://tests/test_battle_save_notice.gd")
const Feedback=preload("res://scripts/combat/structure_feedback.gd")
const Display=preload("res://scripts/combat/combat_display.gd")

static func plan(ui) -> Dictionary:
	return Display.build(ui.view)

static func marker(data:Dictionary,id:int) -> Dictionary:
	for entry in data.structures:
		if entry.id==id:return entry
	return {}

static func labels(data:Dictionary) -> Array:
	return data.labels.filter(func(label):return label.event.kind=="structure")

static func run(host,verify:Callable) -> void:
	var folder:="user://structure-feedback-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var ui=NoticeTests.make_ui(host,folder)
	ui.new_run_encounter_version=1 # Enemy-free legacy fixture isolates the45second timer;pressure2 is covered separately.
	await host.get_tree().process_frame
	Campaign.depart(ui)
	var state=ui.simulation
	state.spawn_clock=999
	state._scatter_clock=999
	state._swarm_clock=999
	var prop:Dictionary=state.structures[0]
	state.player=prop.p+Vector2(120,0)
	var current:Dictionary=plan(ui)
	verify.call(not marker(current,int(prop.id)).is_empty() and not marker(current,int(prop.id)).waiting,"Existing production structure receives a breakable marker before damage")
	verify.call(current.structures.size()<=8 and labels(current).is_empty(),"Intact structures do not invent respawn countdowns")
	state.shot_clock=0
	for frame in range(12):
		ui._physics_process(.05)
		if prop.hp<prop.max_hp:break
	state.shot_clock=999
	verify.call(prop.hp>0 and prop.hp<prop.max_hp and state.shots>0,"Real automatic fire reaches the original enemy-free structure fallback and damages it")
	current=plan(ui)
	verify.call(marker(current,int(prop.id)).damaged and state.cues.flash_alpha(int(prop.id))>0,"Damage state and high-angle flash come from the actual committed hit")
	var hp_bar:=Rect2(ui.view.world_to_screen(prop.p)-Vector2(20,49),Vector2(40,4))
	verify.call(current.labels.all(func(label):return not label.rect.grow(2).intersects(hp_bar)),"Existing damage numbers avoid the actual high-angle structure HP bar")
	# Fixture seed chooses a drop through the existing destruction path.
	var generator:=RandomNumberGenerator.new()
	for seed_value in range(1,10000):
		generator.seed=seed_value
		if state.SupplyCatalog.roll_item(generator)=="hp":
			state.loot_rng.seed=seed_value
			break
	ui.magic_button.pressed.emit()
	verify.call(prop.hp==0 and prop.respawn_left==45 and prop.generation==1,"Existing UI magic destroys the damaged prop and starts its actual45second timer")
	var old_drops:Array=state.item_pickups.duplicate(true)
	verify.call(not old_drops.is_empty() and old_drops.any(func(item):return item.source==prop.id and item.generation==1),"Actual destruction produced the first generation's unclaimed drop")
	current=plan(ui)
	verify.call(labels(current).is_empty() and marker(current,int(prop.id)).is_empty(),"Broken structure has no respawn text, hourglass or progress marker")
	var frozen:Dictionary=Snapshot.capture(state)
	var frozen_cues:Dictionary=state.cues.snapshot()
	for frame in range(15):current=plan(ui)
	verify.call(frozen==Snapshot.capture(state) and frozen_cues==state.cues.snapshot(),"Repeated structure planning changes no HP,time,loot,cues,offers or seven RNG")
	for frame in range(899):state.step(.05,Vector2.ZERO)
	current=plan(ui)
	verify.call(prop.hp==0 and is_equal_approx(prop.respawn_left,.05) and labels(current).is_empty() and marker(current,int(prop.id)).is_empty(),"899real active steps retain the hidden45second timer without showing respawn UI")
	verify.call(state.item_pickups==old_drops,"Respawn countdown cannot erase or reroll the unclaimed first-generation loot")
	ui.pause_game()
	frozen=Snapshot.capture(state)
	var paused_plan:Dictionary=plan(ui)
	for frame in range(10):ui._physics_process(.05)
	verify.call(frozen==Snapshot.capture(state) and paused_plan==plan(ui),"Real pause freezes the hidden respawn timer and authoritative state")
	var ui2=NoticeTests.make_ui(host,folder.path_join("reload"),ui.run_store.path)
	await host.get_tree().process_frame
	ui2.start_button.pressed.emit()
	var restored=ui2.simulation
	verify.call(restored.phase==State.Phase.PAUSED and restored.structures[0].hp==0 and is_equal_approx(restored.structures[0].respawn_left,.05),"Existing Continue restores the actual remaining timer and waits for explicit resume")
	verify.call(restored.cues.events.is_empty() and restored.cues.flash_alpha(int(prop.id))==0 and labels(plan(ui2)).is_empty() and marker(plan(ui2),int(prop.id)).is_empty(),"Restore keeps respawn UI hidden without replaying old break or hit effects")
	ui2.resume_button.pressed.emit()
	ui2._physics_process(.05)
	current=plan(ui2)
	verify.call(restored.structures[0].hp==restored.structures[0].max_hp and restored.structures[0].respawn_left==0 and not marker(current,int(prop.id)).waiting,"The first active frame at45seconds switches to the actual restored living body")
	verify.call(not labels(current).any(func(label):return label.event.id==prop.id) and restored.item_pickups==old_drops,"Rebuilt prop has no stale timer and keeps old loot intact")
	var second:Dictionary=Supplies.drop(restored,"mp")
	verify.call(restored.structures[0].generation==2 and second.source==prop.id and second.generation==2 and restored.item_pickups.size()==old_drops.size()+1,"Rebreaking the actual regenerated prop adds a distinct second-generation drop")
	verify.call(Snapshot.valid(Snapshot.capture(restored),restored),"Feedback preserves a valid production save after two destruction generations")
	restored.grant_xp(restored.growth.threshold())
	frozen=Snapshot.capture(restored)
	var choice_plan:Dictionary=plan(ui2)
	restored.step(.05,Vector2.ZERO)
	verify.call(restored.phase==State.Phase.CHOOSING and frozen==Snapshot.capture(restored) and choice_plan==plan(ui2),"Growth choice freezes waiting structure feedback and the same pending offer")
	# Several visible nearby props test limits without creating another game state owner.
	restored.set_paused(false)
	while restored.phase==State.Phase.CHOOSING:
		if restored.growth.offer.is_empty():restored.acknowledge_exhausted(restored.growth.ticket)
		else:restored.select_skill(restored.growth.offer[0],restored.growth.ticket)
	for index in range(8):
		restored.structures[index].p=restored.player+Vector2(120+(index%4)*52,-60+(index/4)*100)
		restored.structures[index].hp=0
		restored.structures[index].respawn_left=10.01
	ui2.view.size=Vector2(791,266)
	current=plan(ui2)
	verify.call(current.structures.is_empty() and labels(current).is_empty() and current.labels.size()<=16,"Compact view has no respawn markers or countdown labels even with eight nearby broken objects")
	for index in range(60):restored.add_enemy(restored.player+Vector2(200+(index%5)*20,120),"normal")
	current=plan(ui2)
	verify.call(current.dense and current.structures.is_empty() and labels(current).is_empty() and current.labels.size()<=8,"Dense compact combat keeps all broken structure UI hidden without changing enemies")
	restored.cues.record_item(restored.player,"실제 획득")
	current=plan(ui2)
	verify.call(current.labels.any(func(label):return label.event.kind=="item") and labels(current).is_empty(),"Real pickup messages remain visible while respawn text is absent")
	var safe:=Rect2(Vector2(8,8),ui2.view.size-Vector2(16,16))
	var clear:=true
	for label in current.labels:
		clear=clear and safe.encloses(label.rect) and current.reserved.all(func(box):return not label.rect.grow(2).intersects(box))
	verify.call(clear,"Structure labels stay inside the battle canvas and avoid hero,boss,items and markers")
	frozen=Snapshot.capture(restored)
	current.structures.clear()
	verify.call(frozen==Snapshot.capture(restored),"The returned presentation plan does not own or mutate original prop dictionaries")
	var old_phase:int=restored.phase
	for phase in [State.Phase.READY,State.Phase.CLEARED,State.Phase.DEFEAT]:
		restored.phase=phase
		verify.call(plan(ui2).structures.is_empty() and labels(plan(ui2)).is_empty(),"Inactive results/lobby cannot advertise a live structure timer: "+str(phase))
	restored.phase=old_phase
	restored.structures.clear()
	verify.call(plan(ui2).structures.is_empty() and labels(plan(ui2)).is_empty(),"Old saves and gold dungeon with no supplies cannot invent structure markers")
	ui.queue_free()
	ui2.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().create_timer(1.0).timeout
