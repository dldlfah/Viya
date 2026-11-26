extends SceneTree
## Reproducible controller over the real RunState. This measures growth, not player approval.
const RunState = preload("res://scripts/combat/run_state.gd")
const Talents = preload("res://scripts/progression/account_talents.gd")
var profile_name := "none"
var map_name := "prologue_wall"
var skill_ruleset := "weapons_v1"
var account_levels: Dictionary = Talents.empty_levels()
const PRIORITY := {"pulse": 16.0, "chain": 15.0, "grenade": 14.0,
	"scatter": 13.0, "rifle": 12.0, "power": 11.0, "haste": 10.0,
	"learning": 9.0, "magnet": 8.0, "recovery": 7.0}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ruleset="):
			skill_ruleset = argument.trim_prefix("--ruleset=")
			continue
		if argument.begins_with("--map="):
			map_name = argument.trim_prefix("--map=")
			continue
		if not argument.begins_with("--talents="):
			printerr("Unknown measurement argument: ", argument)
			quit(2)
			return
		profile_name = argument.trim_prefix("--talents=")
	if map_name not in ["legacy_arena", "prologue_wall", "outskirts_trial"]:
		printerr("Unknown map")
		quit(2)
		return
	if skill_ruleset not in ["legacy","weapons_v1"]:
		printerr("Unknown skill ruleset")
		quit(2)
		return
	if profile_name not in ["none", "roots", "full"]:
		printerr("Expected --talents=none, roots or full")
		quit(2)
		return
	for id in (Talents.IDS if profile_name == "full" else Talents.ROOT_IDS if profile_name == "roots" else []):
		account_levels[id] = 3
	var reports: Array = []
	for seed_value in [7, 42, 143, 407, 2026]:
		reports.append(measure(seed_value))
	var target_met: bool = reports.all(func(result): return result.choices >= 10 and result.choices <= 12)
	print(JSON.stringify({"profile": profile_name, "map_id": map_name, "skill_ruleset":skill_ruleset, "account_levels": account_levels, "runs": reports, "growth_target_met": target_met,
		"status": "PASS" if target_met else "FAIL"}))
	quit(0 if target_met else 1)

func measure(seed_value: int) -> Dictionary:
	var state = RunState.new()
	state.stage = 2 if map_name == "outskirts_trial" else 1
	if not state.start(seed_value, "viya", account_levels, map_name, skill_ruleset):
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
		"peak_enemies": peak_enemies, "gold_reward": state.result_summary().gold_reward, "milestones": milestones,
		"magic_casts": state.magic.casts, "mana_left": state.magic.mana, "max_mana": state.magic.maximum_mana(), "max_hp": state.max_hp,
		"owned":state.growth.owned.duplicate(true), "evolved":state.growth.owned.keys().filter(func(id):return state.growth.owned[id]==5 and state.growth.definition(id).kind!="passive")}

func pick_skill(state) -> String:
	var selected: String = state.growth.offer[0]
	var best := -100.0
	for id in state.growth.offer:
		var entry: Dictionary = state.growth.definition(id)
		var semantic: String = {"gun_rifle":"rifle","gun_scatter":"scatter","gun_lance":"lance","gun_grenade":"grenade","gun_suppress":"pulse","gun_ricochet":"chain","gun_sniper":"heavy","gun_rupture":"crossfire"}.get(str(entry.effect),str(entry.effect))
		var score: float = PRIORITY.get(semantic, 5.0)
		if float(state.hp) / state.max_hp < 0.6:
			if entry.effect == "vitality":
				score = 20.0
			elif entry.effect == "recovery":
				score = 19.0
		if entry.row == "attack" and state.growth.skill_level(id) == 0:
			score += 2.0
		if score > best:
			best = score
			selected = id
	return selected

func move_direction(state, near: Dictionary) -> Vector2:
	var goal := movement_goal(state, near)
	var selected := Vector2.ZERO
	var best := -INF
	for index in range(9):
		var direction := Vector2.ZERO if index == 8 else Vector2.from_angle(index * TAU / 8.0)
		var future: Vector2 = (state.player + direction * float(state.stats.speed) * 0.35).clamp(Vector2.ONE * 30, state.world_size - Vector2.ONE * 30)
		var score: float = direction.dot(goal) * 30.0
		for enemy in state.enemies:
			var predicted: Vector2 = enemy.p
			if enemy.get("variant", "normal") == "flier":
				predicted += enemy.velocity * 0.35
			var distance := future.distance_to(predicted)
			if distance < 100.0:
				score -= (100.0 - distance) * 4.0
			if enemy.get("variant", "normal") == "ranged" and float(enemy.windup) > 0.0:
				var aim_line := Geometry2D.get_closest_point_to_segment(future, enemy.p, enemy.aim)
				score -= maxf(0.0, 40.0 - future.distance_to(aim_line)) * 3.0
		for bullet in state.enemy_bullets:
			var line := Geometry2D.get_closest_point_to_segment(future, bullet.p, bullet.p + bullet.velocity * 0.65)
			score -= maxf(0.0, 42.0 - future.distance_to(line)) * 8.0
		if future.x < 70 or future.y < 70 or future.x > state.world_size.x - 70 or future.y > state.world_size.y - 70:
			score -= 20.0
		if score > best:
			best = score
			selected = direction
	return selected

func movement_goal(state, near: Dictionary) -> Vector2:
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
