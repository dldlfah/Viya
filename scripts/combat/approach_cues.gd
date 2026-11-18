extends RefCounted
## Presentation only: derive bounded approach cues from actual live actors.
static func build(state, visible: Rect2) -> Array:
	var groups := {}
	for enemy in state.enemies:
		if visible.has_point(enemy.p):
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
		if not visible.has_point(group.at):
			result.append(group)
	result.sort_custom(func(a,b): return a.at.distance_squared_to(state.player) < b.at.distance_squared_to(state.player))
	result.resize(mini(result.size(),6))
	var shots := 0
	for bullet in state.enemy_bullets:
		if shots >= 2:
			break
		if not visible.has_point(bullet.p) and bullet.velocity.dot(state.player-bullet.p) > 0:
			result.append({"at":bullet.p,"count":1,"kind":"shot"})
			shots += 1
	return result
