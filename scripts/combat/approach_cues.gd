extends RefCounted
## Presentation only: derive bounded approach cues from actual live actors.
static func contains(at:Vector2, visible:Rect2, screen_test:Callable) -> bool:
	return screen_test.call(at) if screen_test.is_valid() else visible.has_point(at)

static func build(state, visible: Rect2, screen_test:Callable=Callable()) -> Array:
	var groups := {}
	for enemy in state.enemies:
		if contains(enemy.p,visible,screen_test):
			continue
		if enemy.variant == "flier" and enemy.velocity.dot(state.player - enemy.p) <= 0:
			continue
		var key := "scatter:%d" % enemy.get("scatter_group",0)
		if enemy.get("scatter_group",0) == 0:
			if enemy.variant != "flier":
				continue
			key = "flight:%d" % enemy.group
		if not groups.has(key):
			groups[key] = {"at":Vector2.ZERO,"count":0,"kind":"pack"}
		groups[key].at += enemy.p
		groups[key].count += 1
	var result: Array = []
	for group in groups.values():
		group.at /= group.count
		if not contains(group.at,visible,screen_test):
			result.append(group)
	result.sort_custom(func(a,b): return a.at.distance_squared_to(state.player) < b.at.distance_squared_to(state.player))
	result.resize(mini(result.size(),6))
	var shots := 0
	for bullet in state.enemy_bullets:
		if shots >= 2:
			break
		if not contains(bullet.p,visible,screen_test) and bullet.velocity.dot(state.player-bullet.p) > 0:
			result.append({"at":bullet.p,"count":1,"kind":"shot"})
			shots += 1
	# Share the existing two hostile-shot markers; no new text/input budget.
	if state.phase==state.Phase.RUNNING and state.enemy_pattern_version==3:
		for enemy in state.enemies:
			if shots>=2:break
			if enemy.get("species","")!="demon_shaman" or enemy.get("pattern",{}).get("phase","")!="windup":continue
			if not contains(enemy.p,visible,screen_test) and enemy.pattern.direction.dot(state.player-enemy.pattern.origin)>0:
				result.append({"at":enemy.p,"count":1,"kind":"shot"})
				shots+=1
	return result
