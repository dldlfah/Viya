extends RefCounted
## Data-driven prototype, operating only on the original authoritative RunState.
const PATH := "res://data/enemy_patterns.json"
const SPECIES := "orc_siege"
const PHASES := ["chase","windup","strike","recovery"]
var data:Dictionary={}
var error:String=""

func _init() -> void:
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not valid_data(parsed):
		error="Invalid enemy pattern data"
		return
	data=parsed

static func number(value:Variant,low:float,high:float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high

static func valid_data(value:Variant) -> bool:
	if not value is Dictionary or value.get("schema_version")!=1 or not value.get(SPECIES) is Dictionary:return false
	var p:Dictionary=value[SPECIES]
	for key in ["damage","trigger_range","reach","half_angle_degrees","windup","strike","recovery","cooldown","initial_delay"]:
		if not number(p.get(key),.01,1000):return false
	return p.damage==floor(p.damage) and p.trigger_range<=p.reach and p.half_angle_degrees<=85 and p.windup>=.3 and p.strike<=1 and p.recovery<=10 and p.cooldown<=30 and p.initial_delay<=30

func applies(state,enemy:Dictionary) -> bool:
	return state.enemy_pattern_version==1 and state.run_mode=="campaign" and state.combat_profile_version==1 and enemy.kind=="elite" and enemy.get("species","")==SPECIES

func attach(state,enemy:Dictionary) -> void:
	if applies(state,enemy):enemy.pattern={"phase":"chase","left":float(data[SPECIES].initial_delay),"origin":enemy.p,"direction":Vector2.DOWN}

func locked(state,enemy:Dictionary) -> bool:
	return applies(state,enemy) and enemy.has("pattern") and enemy.pattern.phase!="chase"

func tick(state,enemy:Dictionary,dt:float) -> bool:
	if not applies(state,enemy):return false
	var p:Dictionary=enemy.pattern
	if state.phase!=state.Phase.RUNNING or dt<=0:return p.phase!="chase"
	var spec:Dictionary=data[SPECIES]
	# Flying formations still push every ground actor. Displacement cancels the
	# pending swing rather than silently moving its already advertised area.
	if p.phase=="windup" and enemy.p.distance_squared_to(p.origin)>.01:
		p.phase="recovery"
		p.left=float(spec.recovery)
		return true
	p.left=maxf(0,float(p.left)-dt)
	match p.phase:
		"chase":
			if p.left<=.000000001 and enemy.p.distance_to(state.player)<=float(spec.trigger_range) and state.map_space.wall_fraction(enemy.p,state.player,0)>=1:
				p.origin=enemy.p
				p.direction=enemy.p.direction_to(state.player) if enemy.p!=state.player else Vector2.DOWN
				p.phase="windup"
				p.left=float(spec.windup)
				return true
			return false
		"windup":
			if p.left<=.000000001:
				# Entering strike consumes the one attempt, even if dodged, blocked
				# or rejected by existing invulnerability. Restoring strike cannot hit again.
				p.phase="strike"
				p.left=float(spec.strike)
				if hits(p.origin,p.direction,float(spec.reach),deg_to_rad(float(spec.half_angle_degrees)),state.player,state.PLAYER_RADIUS) and state.map_space.wall_fraction(p.origin,state.player,0)>=1:
					state.damage_player(int(spec.damage),"physical",0,{"kind":"melee","id":int(enemy.id),"p":p.origin})
		"strike":
			if p.left<=.000000001:
				p.phase="recovery"
				p.left=float(spec.recovery)
		"recovery":
			if p.left<=.000000001:
				p.phase="chase"
				p.left=float(spec.cooldown)
	return true

static func hits(origin:Vector2,direction:Vector2,reach:float,half_angle:float,at:Vector2,radius:float) -> bool:
	var offset:Vector2=at-origin
	if offset.length()>reach+radius:return false
	if offset.length()<=radius:return true
	if absf(direction.angle_to(offset))<=half_angle:return true
	for side in [-1,1]:
		var edge:Vector2=origin+direction.rotated(half_angle*side)*reach
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at,origin,edge))<=radius:return true
	return false

func valid_actor(run:Dictionary,enemy:Dictionary) -> bool:
	var enabled:bool=run.enemy_pattern_version==1 and enemy.get("species","")==SPECIES and enemy.get("kind")=="elite"
	if not enabled:return not enemy.has("pattern")
	var p:Variant=enemy.get("pattern")
	if not p is Dictionary or p.size()!=4 or p.get("phase") not in PHASES or not p.get("origin") is Vector2 or not p.origin.is_finite() or p.origin.length()>100000 or not p.get("direction") is Vector2 or not p.direction.is_finite() or not is_equal_approx(p.direction.length(),1):return false
	var cap:float=maxf(float(data[SPECIES].initial_delay),float(data[SPECIES].cooldown)) if p.phase=="chase" else float(data[SPECIES][p.phase])
	return number(p.get("left"),0,cap)
