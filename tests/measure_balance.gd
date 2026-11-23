extends "res://tests/measure_campaign.gd"
## Reuses the original movement and semantic priorities. "evolve" explicitly
## chooses owned attack upgrades first; "original" keeps the historical bot.
var pattern_override:=-1
var pacing_override:=-1
var strategy:="evolve"
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):map_name=arg.trim_prefix("--map=")
		elif arg.begins_with("--talents="):profile_name=arg.trim_prefix("--talents=")
		elif arg.begins_with("--patterns="):pattern_override=int(arg.trim_prefix("--patterns="))
		elif arg.begins_with("--pacing="):pacing_override=int(arg.trim_prefix("--pacing="))
		elif arg.begins_with("--strategy="):strategy=arg.trim_prefix("--strategy=")
		else:
			printerr("Unknown measurement argument: ",arg)
			quit(2)
			return
	if map_name not in ["prologue_wall","outskirts_trial","gold_slime"] or profile_name not in ["none","full"] or pattern_override not in [-1,0,1,2,3] or pacing_override not in [-1,0,1] or strategy not in ["evolve","original"]:
		quit(2)
		return
	for id in (Talents.IDS if profile_name=="full" else []):account_levels[id]=3
	var reports:Array=[]
	for seed_value in [7,42,143,407,2026]:reports.append(measure_balanced(seed_value))
	var target:Array=[6,9] if map_name=="gold_slime" else [10,12]
	var growth_ok:bool=reports.all(func(r):return r.choices>=target[0] and r.choices<=target[1])
	var evolution_ok:bool=map_name=="gold_slime" or reports.all(func(r):return not r.evolved.is_empty())
	var clear_ok:bool=reports.all(func(r):return r.outcome=="cleared")
	print(JSON.stringify({"map_id":map_name,"talents":profile_name,"strategy":strategy,"pacing_override":pacing_override,"pattern_override":pattern_override,"choice_target":target,"growth_target_met":growth_ok,"campaign_evolution_met":evolution_ok,"all_cleared":clear_ok,"runs":reports,"status":"PASS" if growth_ok and evolution_ok and clear_ok else "FAIL","scope":"Deterministic controller,not human approval;explicit evolution priority,no HP/XP/defense gifts."}))
	quit(0 if growth_ok and evolution_ok and clear_ok else 1)
func measure_balanced(seed_value:int)->Dictionary:
	var state=RunState.new()
	state.stage=2 if map_name=="outskirts_trial" else 1
	if not state.start(seed_value,"viya",account_levels,map_name,"weapons_v1",{},"gold_slime" if map_name=="gold_slime" else "campaign",20000 if map_name=="gold_slime" else -1,pacing_override,pattern_override):return {"outcome":"invalid_start","choices":-1,"evolved":[]}
	var strikes:=0
	var melee_hits:=0
	var melee_hp:=0
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
		var phases:Dictionary={}
		for enemy in state.enemies:
			if enemy.has("pattern"):phases[int(enemy.id)]=str(enemy.pattern.phase)
		var received:int=state.cues.received_serial
		state.step(.05,move_direction(state,near))
		for enemy in state.enemies:
			if enemy.has("pattern") and enemy.pattern.phase=="strike" and phases.get(int(enemy.id),"")=="windup":strikes+=1
		for hit in state.cues.received:
			if hit.serial>received and hit.kind=="melee":
				melee_hits+=1
				melee_hp+=int(hit.amount)
		peak=maxi(peak,state.enemies.size())
		if state._boss_defeated and boss_defeated_at<0:boss_defeated_at=state.elapsed
		if milestones.size()<(3 if map_name=="gold_slime" else 6) and state.elapsed+.000001>=(milestones.size()+1)*60:
			milestones.append({"time":state.elapsed,"choices":trace.size(),"xp":collected_xp(state),"kills":state.kills,"hp":state.hp,"mp":state.magic.mana,"collected_gold":state.gold_collected})
	var bosses:Array=state.enemies.filter(func(e):return e.kind=="boss")
	return {"seed":seed_value,"enemy_pattern_version":state.enemy_pattern_version,"hammer_strikes":strikes,"hammer_hits":melee_hits,"hammer_hp_lost":melee_hp,"outcome":state.result_summary().outcome,"pacing_version":state.growth.pacing_version,"elapsed":state.elapsed,"choices":trace.size(),"trace":trace,"evolved":evolved_at.keys(),"evolved_at":evolved_at,"boss_defeated_at":boss_defeated_at,"boss_hp_left":bosses[0].hp if not bosses.is_empty() else 0,"boss_distance_left":state.player.distance_to(bosses[0].p) if not bosses.is_empty() else 0.0,"gold_reward":state.result_summary().gold_reward,"hp":state.hp,"mp":state.magic.mana,"kills":state.kills,"total_collected_xp":collected_xp(state),"peak_enemies":peak,"owned":state.growth.owned.duplicate(true),"milestones":milestones}
func pick_skill(state)->String:
	if strategy=="original":return super.pick_skill(state)
	var chosen:String=state.growth.offer[0]
	var best:=-INF
	for id in state.growth.offer:
		var entry:Dictionary=state.growth.definition(id)
		var semantic:String={"gun_rifle":"rifle","gun_scatter":"scatter","gun_lance":"lance","gun_grenade":"grenade","gun_suppress":"pulse","gun_ricochet":"chain","gun_sniper":"heavy","gun_rupture":"crossfire"}.get(str(entry.effect),str(entry.effect))
		var score:float=PRIORITY.get(semantic,5.0)
		if entry.row=="attack" and state.growth.skill_level(id)>0:score+=40+state.growth.skill_level(id)*5
		if float(state.hp)/state.max_hp<.6:
			if entry.effect=="vitality":score=20.0
			elif entry.effect=="recovery":score=19.0
		if entry.row=="attack" and state.growth.skill_level(id)==0:score+=2.0
		if score>best:
			best=score
			chosen=id
	return chosen
static func collected_xp(state)->float:
	var result:float=state.growth.xp
	for level in range(1,state.growth.level):result+=state.growth.threshold_for(level,state.run_mode,state.growth.pacing_version)
	return result
