extends RefCounted
## Versioned campaign encounters. The existing RunState owns every live field.
const PATH := "res://data/campaign_encounters.json"
const LEGACY_LIMIT := 160
const MAX_CHESTS := 16
var data:Dictionary={}
func _init():
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if valid_data(parsed):data=parsed
static func valid_data(value:Variant)->bool:
	if not value is Dictionary or value.get("minute_seconds")!=60.0:return false
	for key in ["spawn_multipliers","ground_limits"]:
		if not value.get(key) is Array or value[key].size()!=6:return false
		var previous:=0
		for n in value[key]:
			if not n is float or not is_finite(n) or n!=floor(n) or n<previous or n<1 or n>(64 if key=="spawn_multipliers" else 640):return false
			previous=int(n)
	return value.spawn_multipliers[0]==1 and value.ground_limits[0]==LEGACY_LIMIT and value.get("chest_min_upgrades")==1 and value.get("chest_max_upgrades")==5 and value.get("chest_drop_chance") is float and is_finite(value.chest_drop_chance) and value.chest_drop_chance>=0 and value.chest_drop_chance<=1
func tier(elapsed:float)->int:return clampi(floori((elapsed+.000001)/float(data.minute_seconds)),0,5)
func multiplier(version:int,elapsed:float)->int:return int(data.spawn_multipliers[tier(elapsed)]) if version==1 else 1
func population_limit(version:int,elapsed:float)->int:return int(data.ground_limits[tier(elapsed)]) if version==1 else LEGACY_LIMIT
func elite_times(rules:Dictionary,version:int)->Array:
	if version==0:return rules.elites.duplicate()
	var result:Array=[]
	var previous:=0.0
	for at in rules.elites:
		result.append((previous+float(at))*.5)
		result.append(float(at))
		previous=float(at)
	return result
func elite_index(version:int,index:int)->int:return mini(int(index/2),1) if version==1 else index
func batch(state,wave:Dictionary)->int:
	var count:int=int(wave.batch)*multiplier(state.encounter_version,state.elapsed)
	if state.encounter_version==0:return count
	return mini(count,maxi(0,population_limit(1,state.elapsed)-state._ground_count()))
func drop(state,enemy:Dictionary)->void:
	if state.encounter_version!=1 or state.phase!=state.Phase.RUNNING or enemy.kind!="elite" or state.chest_pickups.size()>=MAX_CHESTS:return
	if state.loot_rng.randf()>=float(data.chest_drop_chance):return
	state._chest_serial+=1
	state.chest_pickups.append({"id":state._chest_serial,"source":int(enemy.id),"p":enemy.p,"count":state.loot_rng.randi_range(int(data.chest_min_upgrades),int(data.chest_max_upgrades)),"seed":state.loot_rng.randi()})
func collect(state,dt:float)->void:
	if state.encounter_version!=1 or state.phase!=state.Phase.RUNNING:return
	for i in range(state.chest_pickups.size()-1,-1,-1):
		var chest:Dictionary=state.chest_pickups[i]
		if chest.p.distance_squared_to(state.player)<=pow(float(state.stats.pickup),2):chest.p=chest.p.move_toward(state.player,420*dt)
		if chest.p.distance_squared_to(state.player)>pow(state.PLAYER_RADIUS+10,2):continue
		# Remove before granting: snapshot removal, levels and receipt counter together.
		state.chest_pickups.remove_at(i)
		state._chests_opened+=1
		var eligible:Array=[]
		for id in state.growth.owned:
			var entry:Dictionary=state.growth.definition(str(id))
			if not entry.is_empty() and state.growth.skill_level(id)>0 and state.growth.skill_level(id)<int(entry.max_level):eligible.append(str(id))
		eligible.sort()
		# A drop owns its seed/count. Reloading cannot reroll XP offers or this chest.
		var generator:=RandomNumberGenerator.new()
		generator.seed=int(chest.seed)
		for n in range(eligible.size()-1,0,-1):
			var j:int=generator.randi_range(0,n)
			var id:String=eligible[n]
			eligible[n]=eligible[j]
			eligible[j]=id
		var upgrades:Array=[]
		var previous_hp:int=state.max_hp
		for n in range(mini(int(chest.count),eligible.size())):
			var id:String=eligible[n]
			var before:int=state.growth.skill_level(id)
			state.growth.owned[id]=before+1
			upgrades.append({"id":id,"name":str(state.growth.definition(id).name),"from":before,"to":before+1})
		state._chest_bonus_ranks+=upgrades.size()
		if not upgrades.is_empty():
			state.growth.ticket+=1
			state.growth.revision+=1
			state._refresh_stats()
			state.hp=state.selection_health(state.hp,previous_hp,state.max_hp)
			state.magic.invalidate_requests()
		state.cues.record_item(state.player,"강화 상자",{"kind":"chest","upgrades":upgrades})
func valid_run(run:Dictionary,world_size:Vector2)->bool:
	if not run.get("encounter_version") is int or run.encounter_version not in [0,1]:return false
	if not run.get("chest_pickups") is Array or run.chest_pickups.size()>MAX_CHESTS:return false
	if not run.get("_chest_bonus_ranks") is int or run._chest_bonus_ranks<0:return false
	if not run.get("_chest_serial") is int or not run.get("_chests_opened") is int or not run.get("kills") is int:return false
	if run._chests_opened<0 or run._chest_serial<run._chests_opened or run._chest_serial>run.kills or run.chest_pickups.size()+run._chests_opened!=run._chest_serial:return false
	if run._chest_bonus_ranks>run._chests_opened*5:return false
	if run.encounter_version==0:return run._chest_bonus_ranks==0 and run._chest_serial==0 and run._chests_opened==0 and run.chest_pickups.is_empty()
	if not run.get("_enemy_serial") is int:return false
	if data.is_empty() or run.get("run_mode")!="campaign" or run.get("combat_profile_version")!=1:return false
	var ids:Dictionary={}
	var sources:Dictionary={}
	for chest in run.chest_pickups:
		if not chest is Dictionary or chest.size()!=5:return false
		if not chest.get("id") is int or chest.id<1 or chest.id>run._chest_serial or ids.has(chest.id):return false
		if not chest.get("source") is int or chest.source<1 or chest.source>run.get("_enemy_serial",0) or sources.has(chest.source):return false
		if not chest.get("p") is Vector2 or not chest.p.is_finite() or not Rect2(Vector2.ZERO,world_size).has_point(chest.p):return false
		if not chest.get("count") is int or chest.count<1 or chest.count>5 or not chest.get("seed") is int or chest.seed<0 or chest.seed>4294967295:return false
		if not run.get("enemies") is Array or run.enemies.any(func(e):return e is Dictionary and e.get("id")==chest.source):return false
		ids[chest.id]=true
		sources[chest.source]=true
	return true
