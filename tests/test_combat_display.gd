extends RefCounted
const Display=preload("res://scripts/combat/combat_display.gd")
const State=preload("res://scripts/combat/run_state.gd")
const View=preload("res://scripts/combat/battle_view.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")

static func run(host,verify:Callable)->void:
	var state=State.new()
	state.start(2701)
	state.add_enemy(state.player+Vector2(200,0))
	var id:int=state.enemies[0].id
	state._damage_enemy(id,7)
	state.cues.advance(.08)
	state._damage_enemy(id,7)
	state.cues.advance(.08)
	state._damage_enemy(id,1000)
	var original:Dictionary=state.cues.snapshot()
	var events:Array=Display.merged_events(state.cues.events)
	var hits:Array=events.filter(func(e):return e.kind=="hit")
	verify.call(hits.size()==2 and hits[0].amount==13 and hits[1].amount==7,"Display merges same-target nearby hits,not an older separate hit or overkill")
	verify.call(state.kills==1 and state.cues.snapshot()==original,"Display grouping preserves actual kill/reward and original cue amounts/lifetimes")
	state.add_enemy(state.player+Vector2(201,0))
	state._damage_enemy(state.enemies[0].id,3)
	events=Display.merged_events(state.cues.events)
	verify.call(events.filter(func(e):return e.kind=="hit").size()==3,"Adjacent enemies never have their damage totals combined")
	var critical_pair:Array=[{"kind":"hit","id":1,"p":Vector2.ZERO,"amount":4,"critical":true,"life":.42,"duration":.5},{"kind":"hit","id":1,"p":Vector2.ZERO,"amount":3,"critical":false,"life":.5,"duration":.5}]
	var combined:Array=Display.merged_events(critical_pair)
	verify.call(combined.size()==1 and combined[0].critical and combined[0].amount==7,"Grouped display retains a real critical flag and exact mixed-hit total")
	var a=State.new()
	var b=State.new()
	a.start(2707)
	for index in range(100):a.add_enemy(a.player+Vector2(170+index%10*8,-100+index/10*10))
	a.add_enemy(a.player+Vector2(-220,80),"boss")
	var boss_id:int=a.enemies[-1].id
	for enemy in a.enemies:a._damage_enemy(enemy.id,1)
	a.cues.record_item(a.player,"마나 회복")
	var view=View.new()
	view.simulation=a
	view.size=Vector2(1200,520)
	host.get_tree().root.add_child(view)
	var saved:Dictionary=Snapshot.capture(a)
	original=a.cues.snapshot()
	var plan:Dictionary=Display.build(view)
	verify.call(plan.dense and plan.simple and plan.actors==101 and a.enemies.size()==101,"Actual visible crowd enables cosmetic simplification without removing any actors")
	verify.call(plan.labels.size()<=12 and plan.labels.any(func(e):return e.event.kind=="hit" and e.event.id==boss_id),"Dense label budget reserves priority for actual boss hits")
	verify.call(plan.labels.any(func(e):return e.event.kind=="item"),"Item notifications retain first priority in a crowded scene")
	var clear:=true
	for index in range(plan.labels.size()):
		var box:Rect2=plan.labels[index].rect
		clear=clear and Rect2(Vector2.ZERO,view.size).encloses(box)
		for reserve in plan.reserved:clear=clear and not box.intersects(reserve)
		for other in range(index):clear=clear and not box.intersects(plan.labels[other].rect)
	verify.call(clear,"Actual font-metric boxes stay inside battle area and avoid each other/player/boss")
	verify.call(saved==Snapshot.capture(a) and original==a.cues.snapshot(),"Frame planning is read-only for all saved fields,7RNG and transient feedback")
	verify.call(Display.build(view).labels==plan.labels,"Repeated draw with frozen cues never moves or rerolls label positions")
	for kind in ["blast","pulse","sigil","ultimate","slash"]:a._effect(a.player,460,kind)
	for index in range(24):
		a._effect(a.player+Vector2(100,index),0,"chain")
		a.effects[-1]["from"]=a.player
	plan=Display.build(view)
	verify.call(plan.skipped_links==12 and plan.effects.filter(func(e):return e.kind=="chain").size()==12,"Dense friendly chain decoration has a bounded12link budget")
	verify.call(plan.effects.filter(func(e):return e.kind!="chain").size()==5 and plan.effects.any(func(e):return e.kind=="ultimate" and e.radius==460),"All real area boundaries and the manual460radius survive the display budget")
	verify.call(Display.visible_effect({"p":Vector2(3000,10),"from":Vector2(-3000,10)},Rect2(-100,-100,200,200)),"A real chain crossing the viewport is visible even with both endpoints offscreen")
	view.show_damage=false
	view.show_xp=false
	plan=Display.build(view)
	verify.call(not plan.labels.any(func(e):return e.event.kind in ["hit","xp"]) and plan.labels.any(func(e):return e.event.kind=="item"),"Existing damage/XP options stay independent from important item messages")
	view.size=Vector2(797,266)
	plan=Display.build(view)
	verify.call(plan.label_limit==8 and plan.labels.size()<=8,"Compact battle viewport uses an8label dense budget")
	view.show_damage=true
	view.show_xp=true
	view.size=Vector2(1200,520)
	a.enemies.clear()
	a.effects.clear()
	a.cues.reset()
	plan=Display.build(view)
	verify.call(not plan.dense and not plan.simple,"Sparse scenes recover detailed attacks without a gameplay or saved setting change")
	view.simple_attacks=true
	verify.call(Display.build(view).simple,"Manual simple-attacks option forces simplification even in sparse combat")
	view.simple_attacks=false
	for index in range(100):a.add_enemy(Vector2(30,30))
	verify.call(not Display.build(view).dense,"Offscreen populations do not force cosmetic simplification in a quiet viewport")
	# Compare actual production steps with different display histories/modes.
	a.start(2709)
	a.spawn_view_size=view.spawn_guard_size()
	Snapshot.restore(Snapshot.capture(a),b)
	b.set_paused(false)
	var other=View.new()
	other.simulation=b
	other.size=view.size
	other.auto_display=false
	host.get_tree().root.add_child(other)
	var same:=true
	for frame in range(180):
		a.step(.05,Vector2.RIGHT)
		b.step(.05,Vector2.RIGHT)
		if a.phase==State.Phase.CHOOSING:
			a.select_skill(a.growth.offer[0],a.growth.ticket)
			b.select_skill(b.growth.offer[0],b.growth.ticket)
		view.simple_attacks=frame%2==0
		other.high_angle=frame%3==0
		Display.build(view)
		Display.build(other)
		same=same and Campaign.comparable(a)==Campaign.comparable(b) and a.cues.snapshot()==b.cues.snapshot()
	verify.call(same,"180actual combat steps preserve saved state/7RNG/feedback across automatic/manual/legacy display modes")
	view.queue_free()
	other.queue_free()
	await host.get_tree().process_frame
