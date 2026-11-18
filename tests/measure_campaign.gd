extends SceneTree
## Reproducible controller over the real RunState. This measures growth, not player approval.
const RunState = preload("res://scripts/combat/run_state.gd")
const PRIORITY := {"pulse": 16.0, "chain": 15.0, "grenade": 14.0,
	"scatter": 13.0, "rifle": 12.0, "power": 11.0, "haste": 10.0,
	"learning": 9.0, "magnet": 8.0, "recovery": 7.0}

func _initialize() -> void:
	var reports: Array = []
	for seed_value in [7, 42, 143, 407, 2026]:
		reports.append(measure(seed_value))
	var target_met: bool = reports.all(func(result): return result.choices >= 10 and result.choices <= 12)
	print(JSON.stringify({"runs": reports, "growth_target_met": target_met,
		"status": "PASS" if target_met else "FAIL"}))
	quit(0 if target_met else 1)

func measure(seed_value: int) -> Dictionary:
	var state = RunState.new()
	if not state.start(seed_value):
		return {"seed": seed_value, "choices": -1, "outcome": "invalid_stage"}
	var choices := 0
	var first_choice := -1.0
	var boss_defeated_at := -1.0
	var milestones: Array = []
	var peak_enemies := 0
	for frame in range(12000):
		if state.phase == RunState.Phase.CHOOSING:
			if first_choice < 0.0:
				first_choice = state.elapsed
			if state.growth.offer.is_empty():
				state.acknowledge_exhausted(state.growth.ticket)
			elif state.select_skill(pick_skill(state), state.growth.ticket):
				choices += 1
		if not state.has_active_run():
			break
		var near: Dictionary = state._nearest(state.player, 10000)
		if not near.is_empty() and state.player.distance_to(near.p) <= 220:
			state.cast_ultimate(state.magic.ticket)
		state.step(0.05, move_direction(state, near))
		peak_enemies = maxi(peak_enemies, state.enemies.size())
		if state._boss_defeated and boss_defeated_at < 0.0:
			boss_defeated_at = state.elapsed
		if milestones.size() < 3 and state.elapsed + 0.000001 >= (milestones.size() + 1) * 120.0:
			milestones.append({"time": state.elapsed, "choices": choices, "kills": state.kills, "hp": state.hp, "gold_collected": state.gold_collected})
	return {"seed": seed_value, "outcome": state.result_summary().outcome,
		"elapsed": state.elapsed, "hp": state.hp, "kills": state.kills,
		"choices": choices, "first_choice": first_choice, "boss_defeated_at": boss_defeated_at,
		"peak_enemies": peak_enemies, "gold_reward": state.result_summary().gold_reward, "milestones": milestones}

func pick_skill(state) -> String:
	var selected: String = state.growth.offer[0]
	var best := -100.0
	for id in state.growth.offer:
		var entry: Dictionary = state.growth.definition(id)
		var score: float = PRIORITY.get(str(entry.effect), 5.0)
		if entry.row == "attack" and state.growth.skill_level(id) == 0:
			score += 2.0
		if score > best:
			best = score
			selected = id
	return selected

func move_direction(state, near: Dictionary) -> Vector2:
	if not near.is_empty() and state.player.distance_to(near.p) < 100:
		return (state.player - near.p).normalized()
	if not state.pickups.is_empty():
		var closest: Vector2 = state.pickups[0].p
		for pickup in state.pickups:
			if state.player.distance_squared_to(pickup.p) < state.player.distance_squared_to(closest):
				closest = pickup.p
		return state.player.direction_to(closest)
	if not near.is_empty() and state.player.distance_to(near.p) > 300:
		return state.player.direction_to(near.p)
	return Vector2.ZERO
