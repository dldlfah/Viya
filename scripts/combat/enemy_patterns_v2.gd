extends "res://scripts/combat/enemy_patterns_v1.gd"
## Interrupted windups reacquire briefly instead of paying a completed-swing cooldown.
const REVISED_PATH := "res://data/enemy_patterns_v2.json"

func _init() -> void:
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(REVISED_PATH))
	if not valid_revision(parsed):
		data={}
		error="Invalid revised enemy pattern data"
		return
	data=parsed

static func valid_revision(value:Variant) -> bool:
	if not preload("res://scripts/combat/enemy_patterns_v1.gd").valid_data(value):return false
	return number(value[SPECIES].get("reacquire"),.15,float(value[SPECIES].recovery)) and number(value[SPECIES].get("rearm_delay"),.1,1)

func applies(state,enemy:Dictionary) -> bool:
	return state.enemy_pattern_version==2 and state.run_mode=="campaign" and state.combat_profile_version==1 and enemy.kind=="elite" and enemy.get("species","")==SPECIES

func tick(state,enemy:Dictionary,dt:float) -> bool:
	if applies(state,enemy) and state.phase==state.Phase.RUNNING and dt>0:
		var p:Dictionary=enemy.pattern
		if p.phase=="windup" and enemy.p.distance_squared_to(p.origin)>.01:
			p.phase="reacquire"
			p.left=float(data[SPECIES].reacquire)
			return true
		if p.phase=="reacquire":
			p.left=maxf(0,float(p.left)-dt)
			if p.left<=.000000001:
				p.phase="chase"
				p.left=float(data[SPECIES].rearm_delay)
			return true
	return super.tick(state,enemy,dt)

func valid_actor(run:Dictionary,enemy:Dictionary) -> bool:
	if run.enemy_pattern_version!=2:return false
	var compatible:Dictionary=run.duplicate()
	compatible.enemy_pattern_version=1
	var p:Variant=enemy.get("pattern")
	if not p is Dictionary or p.get("phase","")!="reacquire":return super.valid_actor(compatible,enemy)
	if not number(enemy.pattern.get("left"),0,float(data[SPECIES].reacquire)):return false
	var copy:Dictionary=enemy.duplicate()
	copy.pattern=enemy.pattern.duplicate(true)
	copy.pattern.phase="recovery"
	return super.valid_actor(compatible,copy)
