extends "res://tests/measure_balance.gd"
## GAME029 reproducible diagnostic: unchanged evolve choices/movement from GAME022.
## Uses the actual HudLayout battle extent and fixed camera spawn guard.
## Timeout is measured evidence, not an assertion failure or permission to nerf HP.
var measured_view:=Vector2.ZERO
func _initialize()->void:
	profile_name="full"
	map_name="prologue_wall"
	for id in Talents.IDS:account_levels[id]=3
	var rows:Array=[]
	for config in [{"tag":"historical-default","viewport":Vector2.ZERO,"seed":407},{"tag":"current-standard","viewport":Vector2(1280,720),"seed":407},{"tag":"current-compact","viewport":Vector2(853,384),"seed":407},{"tag":"current-wide","viewport":Vector2(1600,720),"seed":407},{"tag":"current-standard-control","viewport":Vector2(1280,720),"seed":7}]:
		measured_view=config.viewport
		if measured_view!=Vector2.ZERO:
			var inset:float=28 if config.tag in ["current-compact","current-wide"] else 0
			measured_view=preload("res://scripts/ui/hud_layout.gd").build(measured_view,Rect2(Vector2(inset,6),measured_view-Vector2(inset*2,18))).battle.size
		var row:Dictionary=measure_balanced(config.seed)
		row.case=config.tag
		row.battle_viewport=str(measured_view)
		row.window=str(config.viewport)
		rows.append(row)
	print(JSON.stringify({"scope":"Original unchanged evolve controller; full talents; actual7200steps per6min maximum. No tracking-driven bot or numeric balance changes. Historical RunState default versus current projected1.16spawn guard.","runs":rows}))
	quit(0)
func measure_balanced(seed_value:int)->Dictionary:
	var state=RunState.new()
	state.stage=2 if map_name=="outskirts_trial" else 1
	if not state.start(seed_value,"viya",account_levels,map_name,"weapons_v1",{},"gold_slime" if map_name=="gold_slime" else "campaign",20000 if map_name=="gold_slime" else -1,pacing_override):return {"outcome":"invalid_start","choices":-1,"evolved":[]}
	if measured_view!=Vector2.ZERO:state.spawn_view_size=preload("res://scripts/combat/combat_camera.gd").guard_size(measured_view)
	var boss_samples:Array=[]
	var trace:Array=[]
	var milestones:Array=[]
	var evolved_at:={}
	var boss_defeated_at:=-1.0
	var peak:=0
	for frame in range(12000):
		if state.phase==RunState.Phase.CHOOSING:
			if state.growth.offer.is_empty():state.acknowledge_exhausted(state.growth.ticket)
			else:
				var selected:=pick_skill(state)
				if state.select_skill(selected,state.growth.ticket):
					trace.append({"time":state.elapsed,"skill":selected,"rank":state.growth.skill_level(selected),"collected_xp":collected_xp(state),"kills":state.kills})
					if state.growth.skill_level(selected)==5 and state.growth.definition(selected).row=="attack":evolved_at[selected]=state.elapsed
		if not state.has_active_run():break
		var near:Dictionary=state._nearest(state.player,10000)
		if not near.is_empty() and state.player.distance_to(near.p)<=220:state.cast_ultimate(state.magic.ticket)
		if frame%20==0 and state.elapsed>=300:
			var guidance:Dictionary=preload("res://scripts/combat/boss_guidance.gd").inspect(state)
			if not guidance.is_empty():
				guidance.p=str(guidance.p)
				guidance.time=state.elapsed
				guidance.player=str(state.player)
				guidance.controller_goal=str(movement_goal(state,near))
				guidance.pickups=state.pickups.size()
				boss_samples.append(guidance)
		state.step(.05,move_direction(state,near))
		peak=maxi(peak,state.enemies.size())
		if state._boss_defeated and boss_defeated_at<0:boss_defeated_at=state.elapsed
		if milestones.size()<(3 if map_name=="gold_slime" else 6) and state.elapsed+.000001>=(milestones.size()+1)*60:
			milestones.append({"time":state.elapsed,"choices":trace.size(),"xp":collected_xp(state),"kills":state.kills,"hp":state.hp,"mp":state.magic.mana,"collected_gold":state.gold_collected})
	var bosses:Array=state.enemies.filter(func(e):return e.kind=="boss")
	return {"boss_samples":boss_samples,"spawn_view_size":str(state.spawn_view_size),"seed":seed_value,"outcome":state.result_summary().outcome,"pacing_version":state.growth.pacing_version,"elapsed":state.elapsed,"choices":trace.size(),"trace":trace,"evolved":evolved_at.keys(),"evolved_at":evolved_at,"boss_defeated_at":boss_defeated_at,"boss_hp_left":bosses[0].hp if not bosses.is_empty() else 0,"boss_distance_left":state.player.distance_to(bosses[0].p) if not bosses.is_empty() else 0.0,"gold_reward":state.result_summary().gold_reward,"hp":state.hp,"mp":state.magic.mana,"kills":state.kills,"total_collected_xp":collected_xp(state),"peak_enemies":peak,"owned":state.growth.owned.duplicate(true),"milestones":milestones}
