extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Supplies=preload("res://tests/test_supplies.gd")
const Fx=preload("res://scripts/combat/purge_feedback.gd")
const Audio=preload("res://scripts/combat/combat_audio.gd")

static func view_for(state):
	var view=preload("res://scripts/combat/battle_view.gd").new()
	view.size=Vector2(1280,530);view.simulation=state
	return view

static func run(host,verify:Callable):
	var state=State.new()
	verify.call(state.start(5301,"viya",null,"prologue_wall","weapons_v1",{},"campaign",-1,-1,-1,2,1),"Purge presentation uses the original current RunState")
	state.elapsed=300;state.checkpoint_index=2;state._elites_spawned=4
	state.spawn_clock=999;state.shot_clock=999;state._scatter_clock=999;state._swarm_clock=999
	state.player=Vector2(2500,1700);state.gold_drop_chance=1
	for variant in ["normal","ranged","fast","heavy","flier"]:
		state.add_enemy(state.player+Vector2(120,120),"normal",variant)
	state.add_enemy(state.player+Vector2(-120,120),"elite")
	state.add_enemy(state.player+Vector2(250,-60),"boss");state._boss_spawned=true
	state.enemy_bullets.append({"p":state.player+Vector2(400,0),"velocity":Vector2.LEFT*200,"life":1.0,"damage":8,"species":"skeleton_archer","shot":"arrow"})
	var item:Dictionary=Supplies.drop(state,"purge");item.p=state.player
	var before:Dictionary=Snapshot.capture(state)
	var reference=State.new()
	verify.call(Snapshot.restore(before,reference),"Pre-purge current save restores for the presentation-disabled comparison")
	reference.set_paused(false);reference.cues.set_enabled(false)
	var boss:Dictionary=state.enemies[-1].duplicate(true)
	state._collect_items(0);reference._collect_items(0)
	verify.call(Campaign.comparable(state)==Campaign.comparable(reference),"New visual sampling leaves all gameplay,death rewards and seven RNG identical")
	verify.call(state.enemies.size()==1 and state.enemies[0]==boss and state.kills==6 and state.enemy_bullets.is_empty(),"All five variants and elite die exactly once;boss HP/position/AI and normal rewards stay intact")
	var event:Dictionary=state.cues.events[-1]
	verify.call(event.kind=="item" and event.supply.kind=="purge" and event.supply.kills==6 and event.has("purge_marks"),"Purge effect is attached to the committed existing pickup receipt")
	verify.call(event.purge_marks.size()<=Fx.MAX_MARKS and event.purge_marks.all(func(p):return p!=boss.p),"Death marks are bounded and never sampled from the immune boss")
	var view=view_for(state)
	var plan:Dictionary=Fx.plan(view)
	verify.call(not plan.is_empty() and plan.age==0 and plan.bosses.size()==1 and not plan.marks.is_empty(),"Actual view has activation seal,death marks and live boss protection")
	var gameplay:Dictionary=Snapshot.capture(state);var cues:Dictionary=state.cues.snapshot()
	for index in range(10):Fx.plan(view)
	verify.call(Snapshot.capture(state)==gameplay and state.cues.snapshot()==cues,"Repeated render plans consume no gameplay,cues,RNG or effect lifetime")
	state._collect_items(0)
	verify.call(Snapshot.capture(state)==gameplay and state.cues.snapshot()==cues,"A consumed purge item cannot restart the effect or pay its kills twice")
	state.set_paused(true);var frozen:Dictionary=state.cues.snapshot();state.step(.05,Vector2.RIGHT)
	verify.call(state.cues.snapshot()==frozen and Fx.plan(view).age==0,"Pause freezes effect age with the original run clock")
	state.set_paused(false);state.grant_xp(state.growth.threshold())
	frozen=state.cues.snapshot();state.step(.05,Vector2.RIGHT)
	verify.call(state.phase==state.Phase.CHOOSING and state.cues.snapshot()==frozen,"XP choice freezes purge animation without altering the saved offer")
	var restored=State.new()
	verify.call(Snapshot.restore(Snapshot.capture(state),restored) and restored.cues.events.is_empty(),"Restore retains committed deaths/rewards/choice but never replays a cosmetic purge")
	var offer:Array=state.growth.offer.duplicate()
	verify.call(restored.growth.offer==offer and restored.kills==6 and restored.enemies[0]==boss,"Restore keeps original offer and immune boss with no reroll/re-kill")
	while state.phase==state.Phase.CHOOSING:state.select_skill(state.growth.offer[0],state.growth.ticket)
	state.cues.advance(.4)
	verify.call(is_equal_approx(float(Fx.plan(view).age),.4),"Running animation age comes only from committed simulation time")
	view.simple_attacks=true
	verify.call(Fx.plan(view).simple and Fx.plan(view).marks.size()<=6,"Simple effects retain the purge wave with at most six death samples")
	state.cues.advance(1.0)
	verify.call(Fx.plan(view).is_empty(),"Purge receipt expires with no residual effect objects or timers")
	state._apply_supply("purge")
	verify.call(state.kills==6 and Fx.plan(view).marks.is_empty() and Fx.plan(view).bosses.size()==1,"Boss-only purge gives truthful empty death marks and protection without fake kills")
	state._apply_supply("purge")
	verify.call(Fx.plan(view).age==0 and state.kills==6,"Repeated activation replaces the displayed wave instead of stacking global effects")
	state.cues.reset();verify.call(Fx.plan(view).is_empty(),"Run cue reset releases every purge sample")
	# Dense stored battle: no per-kill emitter,node or unbounded afterimage allocation.
	var dense=State.new()
	var data:Dictionary=FileAccess.open("res://tests/fixtures/game050_v21/fly1540.bin",FileAccess.READ).get_var(false)
	verify.call(Snapshot.restore(data,dense),"Load original1540-actor combat for bounded effect sampling")
	dense.set_paused(false)
	var marks:Array=Fx.capture(dense.enemies,dense.visible_world())
	verify.call(marks.size()<=12 and marks.all(func(p):return dense.visible_world().has_point(p)),"1540actors still allocate at most12visible screen-grid samples")
	# Sound observes the same receipt through the existing six-voice pool.
	var muted:bool=AudioServer.is_bus_mute(0);AudioServer.set_bus_mute(0,false)
	var audio=Audio.new();host.get_tree().root.add_child(audio)
	await host.get_tree().process_frame
	state=Supplies.quiet();audio.prepare(state);state._apply_supply("purge");audio.finish(state,true)
	await host.get_tree().create_timer(.03).timeout
	verify.call(int(audio.played.get("purge",0))==1 and audio.active_count()<=Audio.MAX_VOICES,"Committed purge plays one dedicated low boom within the existing bounded voices")
	audio.prepare(state);audio.finish(state,true)
	verify.call(int(audio.played.get("purge",0))==1,"Rendering/observing an unchanged receipt cannot replay the boom")
	audio.stop_all();AudioServer.set_bus_mute(0,true)
	audio.prepare(state);state._apply_supply("purge");audio.finish(state,true)
	verify.call(audio.active_count()==0 and int(audio.played.get("purge",0))==1,"Master mute suppresses purge audio without delaying gameplay or a replay")
	AudioServer.set_bus_mute(0,false)
	audio.queue_free();view.free();await host.get_tree().process_frame
	await host.get_tree().create_timer(.06).timeout # Allow the audio mixer to release stopped playbacks.
	AudioServer.set_bus_mute(0,muted)
