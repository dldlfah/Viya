extends "res://scripts/combat/enemy_patterns_v2.gd"
## One new species; published v1/v2 hammer code and data stay immutable.
const CURSE_PATH := "res://data/enemy_curse_v3.json"
const CASTER := "demon_shaman"
var curse:Dictionary={}

func _init() -> void:
	super()
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(CURSE_PATH))
	if not valid_curse_data(parsed):
		error="Invalid curse prototype data"
		return
	curse=parsed[CASTER]

static func valid_curse_data(value:Variant) -> bool:
	if not value is Dictionary or value.get("schema_version")!=1 or not value.get(CASTER) is Dictionary:return false
	var spec:Dictionary=value[CASTER]
	if spec.size()!=12 or spec.get("damage_type")!="magical":return false
	for key in ["damage","trigger_range","windup","recovery","cooldown","initial_delay","bullet_speed","bullet_life","bullet_radius","reacquire","rearm_delay"]:
		if not number(spec.get(key),.01,1000):return false
	return spec.damage==floor(spec.damage) and spec.damage<=100 and spec.windup>=.65 and spec.windup<=3 and spec.recovery<=3 and spec.cooldown<=15 and spec.initial_delay<=15 and spec.trigger_range<=600 and spec.bullet_speed>=100 and spec.bullet_speed<=600 and spec.bullet_life<=5 and spec.bullet_speed*spec.bullet_life>=spec.trigger_range and spec.bullet_radius>=5 and spec.bullet_radius<=16 and spec.reacquire<=spec.recovery and spec.rearm_delay<=1

func applies(state,enemy:Dictionary) -> bool:
	return state.enemy_pattern_version==3 and state.run_mode=="campaign" and state.combat_profile_version==1 and enemy.kind=="elite" and enemy.get("species","") in [SPECIES,CASTER]

func attach(state,enemy:Dictionary) -> void:
	if applies(state,enemy) and enemy.species==CASTER:
		enemy.pattern={"phase":"chase","left":float(curse.initial_delay),"origin":enemy.p,"direction":Vector2.DOWN}
	else:super.attach(state,enemy)

func tick(state,enemy:Dictionary,dt:float) -> bool:
	if not applies(state,enemy) or enemy.species!=CASTER:return super.tick(state,enemy,dt)
	var p:Dictionary=enemy.pattern
	if state.phase!=state.Phase.RUNNING or dt<=0:return p.phase!="chase"
	if p.phase=="windup" and enemy.p.distance_squared_to(p.origin)>.01:
		p.phase="reacquire"
		p.left=float(curse.reacquire)
		return true
	p.left=maxf(0,float(p.left)-dt)
	match p.phase:
		"chase":
			if p.left<=.000000001 and enemy.p.distance_to(state.player)<=float(curse.trigger_range) and state.map_space.wall_fraction(enemy.p,state.player,float(curse.bullet_radius))>=1:
				p.origin=enemy.p
				p.direction=enemy.p.direction_to(state.player) if enemy.p!=state.player else Vector2.DOWN
				p.phase="windup"
				p.left=float(curse.windup)
				return true
			return false
		"windup":
			if p.left<=.000000001:
				# Consume the attempt BEFORE appending, also when the shared cap is full.
				p.phase="recovery"
				p.left=float(curse.recovery)
				if state.enemy_bullets.size()<state.MAX_ENEMY_BULLETS:
					state.enemy_bullets.append({"p":p.origin,"velocity":p.direction*float(curse.bullet_speed),"life":float(curse.bullet_life),"damage":int(curse.damage),"damage_type":str(curse.damage_type),"species":CASTER,"shot":"curse"})
		"recovery":
			if p.left<=.000000001:
				p.phase="chase"
				p.left=float(curse.cooldown)
		"reacquire":
			if p.left<=.000000001:
				p.phase="chase"
				p.left=float(curse.rearm_delay)
	return true

func is_curse(state,bullet:Dictionary) -> bool:
	return state.enemy_pattern_version==3 and bullet.get("shot","")=="curse"

func move_curse(state,bullet:Dictionary,dt:float) -> bool:
	var previous:Vector2=bullet.p
	var next:Vector2=previous+bullet.velocity*minf(dt,float(bullet.life))
	var wall:float=state.map_space.wall_fraction(previous,next,float(curse.bullet_radius))
	bullet.p=previous.lerp(next,wall)
	bullet.life-=dt
	var nearest:Vector2=Geometry2D.get_closest_point_to_segment(state.player,previous,bullet.p)
	var hit:bool=nearest.distance_squared_to(state.player)<=pow(state.PLAYER_RADIUS+float(curse.bullet_radius),2)
	if hit:state.damage_player(int(bullet.damage),str(bullet.damage_type),0,{"kind":"projectile","direction":-bullet.velocity.normalized()})
	# Existing shared hurt lock/defense accepts or rejects once. No new slow/debuff.
	return hit or bullet.life<=0 or wall<1

func valid_bullet(run:Dictionary,bullet:Dictionary) -> bool:
	return run.enemy_pattern_version==3 and bullet.size()==7 and bullet.get("species")==CASTER and bullet.get("shot")=="curse" and bullet.get("damage_type")==curse.damage_type and bullet.get("damage") is int and bullet.damage==int(curse.damage) and bullet.get("velocity") is Vector2 and bullet.velocity.is_finite() and is_equal_approx(bullet.velocity.length(),float(curse.bullet_speed)) and number(bullet.get("life"),.000001,float(curse.bullet_life))

func valid_actor(run:Dictionary,enemy:Dictionary) -> bool:
	if run.enemy_pattern_version!=3:return false
	if enemy.get("species","")!=CASTER or enemy.get("kind")!="elite":
		var compatible:Dictionary=run.duplicate()
		compatible.enemy_pattern_version=2
		return super.valid_actor(compatible,enemy)
	var p:Variant=enemy.get("pattern")
	if not p is Dictionary or p.size()!=4 or p.get("phase") not in ["chase","windup","recovery","reacquire"] or not p.get("origin") is Vector2 or not p.origin.is_finite() or p.origin.length()>100000 or not p.get("direction") is Vector2 or not p.direction.is_finite() or not is_equal_approx(p.direction.length(),1):return false
	var cap:float=maxf(float(curse.initial_delay),float(curse.cooldown)) if p.phase=="chase" else float(curse[p.phase])
	return number(p.get("left"),0,cap)
