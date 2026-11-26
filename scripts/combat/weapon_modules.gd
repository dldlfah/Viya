extends RefCounted
## Shared attack execution. All mutable actors/events remain in the ONE RunState.
const MAX_EVENTS := 96
const MAX_EVENT_TICKS := 48

static func starter(state) -> String:
	return str(state.growth.catalog.hero(state.growth.character_id,state.growth.ruleset).get("starting_attack",""))

static func fire_start(state) -> void:
	var id := starter(state)
	var p: Dictionary = state.attack_profile(id,state.growth.skill_level(id),float(state.stats.rate))
	if not p.is_empty() and fire(state,p,state.growth.pacing_version==1 and bool(state.growth.pacing.data.boss_priority)):
		state.shot_clock = float(p.interval)

static func tick_skills(state, dt: float) -> void:
	var first := starter(state)
	for entry in state.growth.row_entries("attack"):
		if state.phase != state.Phase.RUNNING:
			return
		var id: String = entry.id
		if id == first:
			continue
		state.skill_clocks[id] = maxf(0.0,float(state.skill_clocks.get(id,0.0))-dt)
		if state.skill_clocks[id] > 0.0:
			continue
		var p: Dictionary = state.attack_profile(id,state.growth.skill_level(id),float(state.stats.rate))
		if not p.is_empty() and fire(state,p):
			state.skill_clocks[id] = float(p.interval)

static func target(state, at: Vector2, reach: float, mode: String = "nearest", ignored: Array[int] = []) -> Dictionary:
	if mode != "strongest":
		return state._nearest(at,reach,ignored)
	var found := {}
	for enemy in state.enemies:
		if not ignored.has(int(enemy.id)) and at.distance_to(enemy.p) < reach and (found.is_empty() or enemy.hp > found.hp):
			found = enemy
	return state._nearest(at,reach,ignored) if found.is_empty() else found

static func fire(state, p: Dictionary, boss_priority:bool=false) -> bool:
	if state.phase != state.Phase.RUNNING or state.weapon_events.size() >= MAX_EVENTS:
		return false
	var victim := target(state,state.player,float(p.reach),str(p.target))
	if boss_priority:
		for enemy in state.enemies:
			if enemy.kind=="boss" and state.player.distance_to(enemy.p)<=float(p.reach):
				victim=enemy
				break
	if victim.is_empty():
		return false
	var direction: Vector2 = state.player.direction_to(victim.p)
	if direction.is_zero_approx():
		direction = state.facing
	state.facing = direction
	var repeats := int(p.ticks) if p.mode in ["zone","orbit"] else int(p.bursts)
	var event := {"profile":p.duplicate(true),"p":victim.p,"direction":direction,
		"left":float(p.delay),"remaining":repeats,"index":0}
	if event.left <= 0.0:
		execute(state,event)
		event.remaining -= 1
		event.index += 1
		event.left = float(p.tick_gap) if p.mode in ["zone","orbit"] else float(p.burst_gap)
	if event.remaining > 0:
		state.weapon_events.append(event)
	return true

static func advance(state, dt: float) -> void:
	# RunState calls this only after its RUNNING guard.
	if state.phase != state.Phase.RUNNING or dt <= 0.0 or not is_finite(dt):
		return
	for enemy in state.enemies:
		var status: Dictionary = enemy.get("weapon_status",{})
		if status.is_empty():
			continue
		status.mark = maxf(0.0,float(status.mark)-dt)
		status.slow_left = maxf(0.0,float(status.slow_left)-dt)
		if status.slow_left == 0.0:
			status.slow = 0.0
	var budget := MAX_EVENT_TICKS
	for index in range(state.weapon_events.size()-1,-1,-1):
		if state.phase != state.Phase.RUNNING:
			return
		var event: Dictionary = state.weapon_events[index]
		event.left = maxf(0.0,float(event.left)-dt)
		if event.left > 0.000000001 or budget <= 0:
			continue
		budget -= 1
		execute(state,event)
		event.remaining -= 1
		event.index += 1
		if event.remaining <= 0:
			state.weapon_events.remove_at(index)
		else:
			event.left = maxf(0.01,float(event.profile.tick_gap) if event.profile.mode in ["zone","orbit"] else float(event.profile.burst_gap))

static func execute(state, event: Dictionary) -> void:
	var p: Dictionary = event.profile
	var center: Vector2 = state.player if p.follow else event.p
	match str(p.mode):
		"projectile":
			volley(state,state.player,event.direction,p)
		"blast":
			if event.index > 0:
				center += Vector2.from_angle(event.index*2.399963) * minf(event.index*18.0,float(p.radius)*0.8)
			area(state,center,float(p.radius),p)
			secondary(state,center,p)
		"zone":
			area(state,center,float(p.radius),p)
			fragments(state,center,p)
		"orbit":
			for index in range(int(p.projectiles)):
				var angle: float = event.index*float(p.tick_gap)*float(p.orbit_speed)+TAU*index/int(p.projectiles)
				area(state,state.player+Vector2.from_angle(angle)*float(p.orbit_radius),float(p.radius),p)
		"cone":
			var direction: Vector2 = event.direction.rotated((1 if event.index%2==0 else -1)*minf(0.4,float(p.angle)*0.2))
			for actor in actors(state):
				var offset: Vector2 = actor.p-state.player
				if offset.length() <= float(p.radius) and (offset.is_zero_approx() or direction.dot(offset.normalized()) >= cos(float(p.angle)*0.5)):
					impact(state,actor,p)
			visual(state,state.player,float(p.radius),p,"slash")
			state.effects[-1].direction = direction
			state.effects[-1].angle = float(p.angle)
		"chain":
			var used: Array[int] = []
			var anchors: Array[Vector2] = []
			for branch in range(int(p.branches)):
				anchors.append(state.player)
			for index in range(int(p.targets)):
				var slot := index%anchors.size()
				var from: Vector2 = anchors[slot]
				var victim := target(state,from,float(p.reach) if index < anchors.size() else float(p.link_range),"nearest",used)
				if victim.is_empty():
					continue
				used.append(int(victim.id))
				anchors[slot] = victim.p
				impact(state,victim,p)
				visual(state,anchors[slot],28.0,p,"chain")
				state.effects[-1]["from"] = from
		"dash":
			var from: Vector2 = state.player
			state.player = state.map_space.move(from,event.direction*float(p.travel),30.0)
			for actor in actors(state):
				var nearest := Geometry2D.get_closest_point_to_segment(actor.p,from,state.player)
				if actor.p.distance_to(nearest) <= float(p.radius):
					impact(state,actor,p)
			visual(state,state.player,float(p.radius),p,"dash")
			state.effects[-1]["from"] = from
			if p.impact > 0.0:
				area(state,state.player,float(p.impact),p)
			fragments(state,state.player,p)

static func actors(state) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for list in [state.enemies,state.structures]:
		for actor in list:
			if actor.hp > 0:
				result.append(actor)
	return result

static func speed_scale(enemy: Dictionary) -> float:
	return 1.0-float(enemy.get("weapon_status",{}).get("slow",0.0))

static func impact(state, actor: Dictionary, p: Dictionary) -> void:
	if state.phase != state.Phase.RUNNING or actor.hp <= 0:
		return
	var attack_type: String = str(p.get("damage_type","magical" if str(p.family)=="magic" else "physical"))
	var source: String = str(p.get("source_character_id",state.growth.character_id))
	if attack_type not in ["physical","magical"] or (state.armor_enabled and source != state.growth.character_id and not state.support_attack_ids.has(source)):
		return # Invalid source must not mark, slow or knock back the target.
	var marked := false
	if actor.id > 0:
		if not actor.has("weapon_status"):
			actor.weapon_status = {"mark":0.0,"slow":0.0,"slow_left":0.0}
		var status: Dictionary = actor.weapon_status
		marked = status.mark > 0.0
		status.mark = maxf(float(status.mark),float(p.mark))
		if p.slow > 0.0:
			status.slow = maxf(float(status.slow),float(p.slow))
			status.slow_left = maxf(float(status.slow_left),float(p.slow_duration))
		if p.knockback > 0.0:
			var displacement: Vector2 = state.player.direction_to(actor.p)*float(p.knockback)*(0.25 if actor.kind=="boss" else 1.0)
			actor.p = actor.p+displacement if actor.variant=="flier" else state.map_space.move(actor.p,displacement,24.0)
			state.projectile_target_moved(actor)
	state._damage_target(int(actor.id),float(p.damage),attack_type,source)
	if marked and p.mark_burst > 0.0:
		var burst: Dictionary = p.duplicate(true)
		burst.damage *= 0.5
		burst.mark_burst = 0.0
		burst.mark = 0.0
		area(state,actor.p,float(p.mark_burst),burst,[int(actor.id)])

static func area(state, at: Vector2, radius: float, p: Dictionary, ignored: Array[int] = []) -> void:
	for actor in actors(state):
		if not ignored.has(int(actor.id)) and at.distance_squared_to(actor.p) <= radius*radius:
			impact(state,actor,p)
	visual(state,at,radius,p,"blast")

static func visual(state, at: Vector2, radius: float, p: Dictionary, kind: String) -> void:
	state._effect(at,radius,kind)
	state.effects[-1].family = p.family
	state.effects[-1].evolved = bool(p.evolved)
	state.effects[-1].weapon_id = p.id

static func volley(state, at: Vector2, direction: Vector2, p: Dictionary) -> void:
	for index in range(int(p.projectiles)):
		var angle := 0.0 if p.projectiles==1 else float(p.spread)*(float(index)/(int(p.projectiles)-1)-0.5)
		projectile(state,at,direction.rotated(angle),p)

static func projectile(state, at: Vector2, direction: Vector2, p: Dictionary) -> void:
	if state.bullets.size() >= state.MAX_BULLETS:
		return
	state.bullets.append({"p":at,"direction":direction,"life":float(p.life),"speed":float(p.speed),
		"damage":float(p.damage),"remaining":int(p.hits),"seen":{},"source":p.id,
		"weapon":p.duplicate(true),"age":0.0,"returning":false})
	state.shots += 1

static func fragments(state, at: Vector2, p: Dictionary) -> void:
	if p.fragments <= 0:
		return
	var child: Dictionary = p.duplicate(true)
	child.damage *= 0.35
	child.hits = 1
	child.fragments = 0
	child.bounces = 0
	child.impact = 0.0
	child.echoes = 0
	child.mark_burst = 0.0
	child.return_after = 0.0
	child.life = 0.5
	child.speed = maxf(500.0,float(p.speed)*0.75)
	child.width = 3.0
	child.fragment = true
	for index in range(int(p.fragments)):
		projectile(state,at,Vector2.from_angle(TAU*index/int(p.fragments)),child)

static func secondary(state, at: Vector2, p: Dictionary) -> void:
	fragments(state,at,p)
	if p.echoes > 0 and state.weapon_events.size() < MAX_EVENTS and state.phase == state.Phase.RUNNING:
		var echo: Dictionary = p.duplicate(true)
		echo.echoes = 0
		echo.fragments = 0
		echo.mode = "blast"
		echo.radius = maxf(float(p.radius),float(p.impact))*0.75
		echo.damage *= 0.5
		state.weapon_events.append({"profile":echo,"p":at,"direction":Vector2.RIGHT,"left":0.2,"remaining":1,"index":0})

static func move_projectile(state, index: int, dt: float) -> void:
	var bullet: Dictionary = state.bullets[index]
	var p: Dictionary = bullet.weapon
	bullet.age += dt
	bullet.life -= dt
	if p.return_after > 0.0 and bullet.age >= p.return_after and not bullet.returning:
		bullet.returning = true
		bullet.seen.clear()
		bullet.remaining = int(p.hits)
	if bullet.returning:
		bullet.direction = bullet.p.direction_to(state.player)
		if bullet.p.distance_to(state.player) < 20.0:
			state.bullets.remove_at(index)
			return
	elif p.homing > 0.0:
		var found := target(state,bullet.p,500.0,"nearest",seen_ids(bullet))
		if not found.is_empty():
			var turn := wrapf((found.p-bullet.p).angle()-bullet.direction.angle(),-PI,PI)
			bullet.direction = bullet.direction.rotated(clampf(turn,-float(p.homing)*dt,float(p.homing)*dt))
	var old: Vector2 = bullet.p
	var next: Vector2 = old+bullet.direction*float(bullet.speed)*dt
	var wall: float = state.map_space.wall_fraction(old,next,float(p.width))
	next = old.lerp(next,wall)
	bullet.p = next
	while bullet.remaining > 0:
		var found := {}
		var first := INF
		for actor in state.projectile_candidates(old,next,float(p.width)):
			if bullet.seen.has(actor.id):
				continue
			var nearest := Geometry2D.get_closest_point_to_segment(actor.p,old,next)
			var radius: float = state.ENEMY_RADIUS if actor.id > 0 else state.SupplyCatalog.RADIUS
			if actor.p.distance_to(nearest) <= radius+float(p.width) and old.distance_squared_to(nearest) < first:
				first = old.distance_squared_to(nearest)
				found = actor
		if found.is_empty():
			break
		var hit_at: Vector2 = found.p
		bullet.seen[found.id] = true
		bullet.remaining -= 1
		impact(state,found,p)
		if p.impact > 0.0:
			var blast: Dictionary = p.duplicate(true)
			blast.damage *= 0.6
			blast.mark_burst = 0.0
			area(state,hit_at,float(p.impact),blast,[int(found.id)])
		secondary(state,hit_at,p)
		if state.phase != state.Phase.RUNNING:
			if bullet.remaining <= 0 or bullet.life <= 0.0 or wall < 1.0:
				state.bullets.remove_at(index)
			return
		if p.bounces > 0 and bullet.remaining > 0:
			var linked := target(state,hit_at,float(p.link_range),"nearest",seen_ids(bullet))
			if not linked.is_empty():
				bullet.p = hit_at
				bullet.direction = hit_at.direction_to(linked.p)
				break # Redirect the next segment, never hit a new path retroactively.
	if bullet.remaining <= 0 or bullet.life <= 0.0 or wall < 1.0:
		state.bullets.remove_at(index)

static func seen_ids(bullet: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for id in bullet.seen:
		ids.append(int(id))
	return ids

static func ultimate(state, cast: Dictionary) -> void:
	var id: String = str(state.growth.catalog.hero(state.growth.character_id,state.growth.ruleset).unique_auto)
	var p: Dictionary = state.attack_profile(id,1,float(state.stats.rate))
	p.damage = float(cast.damage)
	p.damage_type = "magical" # Viya manual crimson wave, NOT her physical rune bullets.
	p.radius = float(cast.radius)
	p.mark = 0.0
	p.mark_burst = 0.0
	p.fragments = 0
	p.echoes = int(cast.get("echoes",0))
	p.knockback = float(cast.get("knockback",0))
	p.evolved = cast.rank==5
	p.rank = maxi(1,int(cast.rank))
	var marked: Array[int] = []
	for enemy in state.enemies:
		if enemy.p.distance_to(state.player) <= float(cast.radius) and float(enemy.get("weapon_status",{}).get("mark",0.0)) > 0:
			marked.append(int(enemy.id))
			enemy.weapon_status.mark = 0.0
	area(state,state.player,float(cast.radius),p)
	for victim in marked:
		if cast.get("mark_damage",0.0) > 0.0:
			state._damage_enemy(victim,float(cast.mark_damage),"magical")
	secondary(state,state.player,p)
	visual(state,state.player,float(cast.radius),p,"ultimate")
