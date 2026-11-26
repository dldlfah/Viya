extends RefCounted
## Local encounter pressure; all live state and RNG remain in the existing run.
const PATH := "res://data/campaign_pressure.json"
var data:Dictionary={}
func _init():
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if valid_data(parsed):data=parsed
static func valid_data(value:Variant)->bool:
	if not value is Dictionary or value.get("pulse_seconds")!=1.0:return false
	if not value.get("near_targets") is Array or value.near_targets.size()!=6:return false
	var previous:=0.0
	for number in value.near_targets:
		if not number is float or not is_finite(number) or number!=floor(number) or number<previous or number<1 or number>640:return false
		previous=number
	for key in ["warmup_seconds","near_padding","edge_gap","edge_jitter","far_padding","max_refill","max_recycle"]:
		if not value.get(key) is float or not is_finite(value[key]) or value[key]<0:return false
	return value.warmup_seconds<=15 and value.near_padding>=0 and value.near_padding<=240 and value.edge_gap>=64 and value.edge_gap<=120 and value.edge_jitter<=48 and value.far_padding>=320 and value.far_padding<=800 and value.max_refill==floor(value.max_refill) and value.max_refill>=1 and value.max_refill<=30 and value.max_recycle==floor(value.max_recycle) and value.max_recycle>=1 and value.max_recycle<=30
func target(state)->int:return int(data.near_targets[state.encounters.tier(state.elapsed)])
func near_count(state)->int:
	var region:Rect2=state.visible_world().grow(float(data.near_padding))
	return state.enemies.filter(func(e):return e.kind=="normal" and e.variant!="flier" and e.scatter_group==0 and region.has_point(e.p)).size()
func anchor(state,role:String)->Variant:
	var visible:Rect2=state.visible_world()
	var candidates:Array=state.map_space.definition.zones.filter(func(z):return role in z.roles and state.elapsed>=float(z.from))
	if candidates.is_empty():return null
	var weights:Array[float]=[]
	var total:=0.0
	for zone in candidates:
		var weight:=1.0
		for row in zone.weights:
			if state.elapsed>=float(row.from):weight=float(row.weight)
		weights.append(weight);total+=weight
	for attempt in range(64):
		var roll:float=state.rng.randf()*total
		var selected:Dictionary=candidates[-1]
		for index in range(candidates.size()):
			roll-=weights[index]
			if roll<0:selected=candidates[index];break
		var angle:float=state.rng.randf_range(0,TAU)
		# Zone activation/side/weight still controls the approach. Positions follow
		# the player's guarded rectangle rather than a fixed distant world zone.
		if state.map_space.definition.mode=="frontline" and attempt<32:
			match selected.side:
				"front":angle=state.rng.randf_range(PI*.30,PI*.70)
				"left":angle=state.rng.randf_range(PI*.80,PI*1.20)
				"right":angle=state.rng.randf_range(-PI*.20,PI*.20)
		var direction:=Vector2.from_angle(angle)
		var distance:float=minf(visible.size.x*.5/maxf(absf(direction.x),.00001),visible.size.y*.5/maxf(absf(direction.y),.00001))
		var at:Vector2=visible.get_center()+direction*(distance+float(data.edge_gap)+24+state.rng.randf()*float(data.edge_jitter))
		if state.map_space.valid_position(at,24) and not visible.grow(56).has_point(at) and at.distance_to(state.player)>=160:return at
	return null
func tick(state,dt:float)->void:
	if state.encounter_version!=2 or state.phase!=state.Phase.RUNNING or state.elapsed<float(data.warmup_seconds):return
	# Elapsed time is already authoritative/saved. No extra clock to reset on
	# Continue, and pause/choices cannot consume or repeat this boundary.
	if floori((state.elapsed+.000001)/float(data.pulse_seconds))==floori((maxf(0,state.elapsed-dt)+.000001)/float(data.pulse_seconds)):return
	var outer:Rect2=state.visible_world().grow(float(data.far_padding))
	var recycled:=0
	for enemy in state.enemies:
		if recycled>=int(data.max_recycle):break
		if enemy.kind!="normal" or enemy.variant=="flier" or enemy.scatter_group!=0 or float(enemy.get("windup",0))>0 or outer.has_point(enemy.p):continue
		var at:Variant=anchor(state,"normal")
		if at is Vector2:
			enemy.p=at # Keep identity, HP, status, cooldowns and consumed hit records.
			recycled+=1
	var missing:int=mini(int(data.max_refill),maxi(0,target(state)-near_count(state)))
	for index in range(missing):
		if not state._spawn_enemy():break
