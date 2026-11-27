extends RefCounted
## Derived, bounded animation observations only. Never saved or used for attacks.
const Ground=preload("res://scripts/combat/battle_projection.gd")
const DIRECTIONS := ["e","se","s","sw","w","nw","n","ne"]
var run_id:String=""
var clock:float=-1
var entries:Dictionary={}

static func direction(vector:Vector2) -> String:
	var projected:=Vector2(vector.x,vector.y*Ground.GROUND_Y)
	return DIRECTIONS[posmod(roundi(projected.angle()/(PI/4)),8)] if not projected.is_zero_approx() else "s"

func reset(id:String="") -> void:
	run_id=id
	clock=-1
	entries.clear()

func prepare(state, track_enemies:bool=true, motion_region:Rect2=Rect2()) -> void:
	if state.run_id!=run_id or state.elapsed<clock:reset(state.run_id)
	if not entries.has(0):entries[0]={"p":state.player,"hp":state.hp,"shots":state.shots,"casts":state.magic.casts,"pose":"idle","moving":false,"since":state.elapsed,"direction":direction(state.facing),"facing":state.facing}
	entries[0].before_bullets=state.bullets.duplicate()
	entries[0].before_received=state.cues.received_serial
	entries[0].before_gun=state.cues.gun_serial
	if not track_enemies:return
	var bounded:bool=motion_region.has_area()
	for enemy in state.enemies:
		if bounded and enemy.kind=="normal" and not motion_region.has_point(enemy.p):continue
		if not entries.has(int(enemy.id)):entries[int(enemy.id)]={"p":enemy.p,"hp":enemy.hp,"fire_clock":enemy.get("fire_clock",0),"pose":"idle","moving":false,"since":state.elapsed,"direction":direction(state.player-enemy.p),"facing":enemy.p.direction_to(state.player)}

func sync(state, hero_displacement:Vector2, active:bool, track_enemies:bool=true, motion_region:Rect2=Rect2(), hero_intent:bool=true) -> void:
	if state.run_id!=run_id or state.elapsed<clock:reset(state.run_id)
	if not active or state.elapsed<=clock:return
	clock=state.elapsed
	var live:Dictionary={0:true}
	var hero:Dictionary=entries.get(0,{"p":state.player-hero_displacement,"hp":state.hp,"shots":state.shots,"casts":state.magic.casts})
	var fired:bool=state.shots>int(hero.get("shots",state.shots)) or state.magic.casts>int(hero.get("casts",state.magic.casts))
	var aim:Vector2=state.facing
	var contacts:Dictionary={}
	var received_now:bool=false
	for hit in state.cues.received:
		if int(hit.serial)<=int(hero.get("before_received",state.cues.received_serial)):continue
		received_now=true
		hero.hurt_until=state.elapsed+.12
		hero.erase("hurt_aim")
		if not hit.direction.is_zero_approx():hero.hurt_aim=hit.direction
		if hit.kind in ["contact","melee"]:contacts[int(hit.id)]=hit.p
	if state.hp<float(hero.hp) and not received_now:hero.erase("hurt_aim")
	if state.shots>int(hero.get("shots",state.shots)):
		for index in range(state.bullets.size()-1,-1,-1):
			var bullet:Dictionary=state.bullets[index]
			if not hero.get("before_bullets",[]).any(func(old):return is_same(old,bullet)):
				aim=bullet.direction
				var source:String=str(bullet.get("source","rifle"))
				if (source in ["rifle","scatter","lance","crossfire","heavy","viya_runebullet_v1"] or source.begins_with("gun_")) and not bullet.get("weapon",{}).get("fragment",false):
					hero.gun_since=state.elapsed
					hero.gun_aim=bullet.direction
				break
	# A committed shot may already have hit or reached a wall this tick. Its
	# receipt also wins over a later non-gun projectile from another skill.
	if state.cues.gun_serial>int(hero.get("before_gun",state.cues.gun_serial)):
		aim=state.cues.gun_direction
		hero.gun_since=state.elapsed
		hero.gun_aim=aim
	update(0,hero,state.player,state.hp,hero_displacement if hero_intent else Vector2.ZERO,aim,fired,0,state)
	entries[0].distance=float(hero.get("distance",0))+hero_displacement.length() if hero_intent else float(hero.get("distance",0))
	entries[0].shots=state.shots
	entries[0].casts=state.magic.casts
	entries[0].before_bullets=[]
	entries[0].before_received=state.cues.received_serial
	entries[0].before_gun=state.cues.gun_serial
	var bounded:bool=motion_region.has_area()
	for enemy in (state.enemies if track_enemies else []):
		if bounded and enemy.kind=="normal" and not motion_region.has_point(enemy.p):continue
		var id:int=enemy.id
		live[id]=true
		var previous:Dictionary=entries.get(id,{"p":enemy.p,"hp":enemy.hp})
		var flash:float=state.cues.flash_alpha(id)
		if flash>float(previous.get("flash",0)):previous.hurt_until=state.elapsed+.12
		if enemy.get("pattern",{}).get("phase","")=="reacquire":
			previous.erase("attack_until")
			previous.erase("attack_since")
			previous.erase("aim")
		var windup:float=enemy.get("windup",0)
		var attacking:bool=windup>0 or float(enemy.get("fire_clock",0))>float(previous.get("fire_clock",enemy.get("fire_clock",0)))
		var aim_at:Vector2=enemy.get("aim",state.player) if attacking else state.player
		if enemy.get("pattern",{}).get("phase","") in ["windup","strike"]:
			attacking=true
			windup=float(enemy.pattern.left) if enemy.pattern.phase=="windup" else 0
			aim_at=enemy.p+enemy.pattern.direction
		if contacts.has(id):
			attacking=true
			windup=0
			aim_at=contacts[id]
		update(id,previous,enemy.p,enemy.hp,enemy.p-previous.p,aim_at-enemy.p,attacking,windup,state)
		entries[id].fire_clock=enemy.get("fire_clock",0)
		entries[id].flash=flash
	for id in entries.keys():
		if not live.has(id):entries.erase(id)

func update(id:int, previous:Dictionary, position:Vector2, hp:float, displacement:Vector2, facing:Vector2, attack:bool, windup:float, state) -> void:
	var now:float=state.elapsed
	var moving:bool=displacement.length_squared()>.0001
	var value:Dictionary=previous.duplicate()
	if hp<float(previous.hp):value.hurt_until=now+.12
	if attack and (windup==0 or float(previous.get("attack_until",0))<=now):
		value.attack_until=now+maxf(.16,windup+.12)
		# Rapid multiweapon fire extends the pose without pinning frame0 forever.
		if previous.get("pose","") not in ["attack","hurt"] or now-float(previous.get("attack_since",-1))>=.16:value.attack_since=now
		value.aim=facing
	var pose:String="hurt" if now<float(value.get("hurt_until",0)) else ("attack" if now<float(value.get("attack_until",0)) else ("run" if moving else "idle"))
	if pose!=previous.get("pose",""):value.since=now
	if pose=="attack":value.since=value.get("attack_since",now)
	if moving and not previous.get("moving",false):value.move_since=now
	var face:Vector2=value.get("aim",facing) if pose=="attack" else (displacement if moving else facing)
	if pose=="hurt":face=value.get("hurt_aim",face)
	value.merge({"p":position,"hp":hp,"pose":pose,"moving":moving,"motion":displacement.normalized(),"direction":direction(face),"facing":face.normalized()},true)
	entries[id]=value

func silhouette_motion(state, id:int) -> Dictionary:
	if run_id!=state.run_id or not entries.has(id):return {}
	var value:Dictionary=entries[id]
	return {"moving":value.moving,"move_clock":maxf(0,state.elapsed-float(value.get("move_since",state.elapsed)))}

func pose(state, id:int=0) -> Dictionary:
	if run_id!=state.run_id or not entries.has(id):return {"pose":"idle","direction":direction(state.facing if id==0 else Vector2.DOWN),"facing":state.facing if id==0 else Vector2.DOWN,"clock":0.0,"moving":false,"move_clock":0.0,"distance":0.0}
	var value:Dictionary=entries[id]
	return {"pose":value.pose,"direction":value.direction,"facing":value.facing,"clock":maxf(0,state.elapsed-float(value.get("since",state.elapsed))),"moving":value.moving,"motion":value.get("motion",Vector2.ZERO),"move_clock":maxf(0,state.elapsed-float(value.get("move_since",state.elapsed))),"distance":float(value.get("distance",0)),"shot_age":state.elapsed-float(value.get("gun_since",-1000)),"gun_aim":value.get("gun_aim",Vector2.ZERO)}
