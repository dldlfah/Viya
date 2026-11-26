extends SceneTree
const State=preload("res://scripts/combat/run_state.gd")
func _initialize()->void:
	var rows:Array=[]
	for id in ["orc_shield","orc_siege","demon_vanguard"]:
		for rank in [1,5]:
			for pierce in [0.0,0.15]:rows.append(measure(id,rank,pierce))
	print(JSON.stringify({"status":"PASS" if rows.all(func(r):return r.killed) else "FAIL","rows":rows,"scope":"Actual weapon firing/projectile/damage pipeline at60Hz against a stationary isolated target; no other skills/MP/leveling, fixed original species HP,range200. Time excludes approach/dodge/other enemies,not human boss clear time."}))
	quit(0 if rows.all(func(r):return r.killed) else 1)
func measure(id:String,rank:int,pierce:float)->Dictionary:
	var state=State.new()
	state.start(22,"viya",null,"legacy_arena","weapons_v1")
	state.growth.owned={"gun_rifle":rank}
	state.growth.level=rank
	state._refresh_stats()
	state.stats.physical_penetration=pierce
	var definition:Dictionary=state.profiles.species(id)
	state.add_enemy(state.player+Vector2(200,0),definition.kind,definition.variant,0,id)
	var hp:int=state.enemies[0].hp
	var armor:float=state.DefenseRules.armor_rate(definition.kind,definition.variant,"physical")
	var frame:=0
	while not state.enemies.is_empty() and frame<20000:
		frame+=1
		state.WeaponModules.advance(state,1.0/60)
		state.shot_clock=maxf(0,state.shot_clock-1.0/60)
		if state.shot_clock==0:state._auto_fire()
		state._move_bullets(1.0/60)
	return {"species":id,"hp":hp,"rank":rank,"penetration":pierce,"armor":armor,"raw100_theoretical":state.DefenseRules.mitigated_damage(100,armor,pierce),"raw10_actual":int(ceil(snappedf(state.DefenseRules.mitigated_damage(10,armor,pierce),.000001))),"ttk_seconds":frame/60.0,"projectiles":state.shots,"killed":state.enemies.is_empty()}
