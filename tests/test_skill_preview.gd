extends RefCounted
## Invoked by the existing native HUD/overview test chain. Requires actual Godot.
const RunState = preload("res://scripts/combat/run_state.gd")
const Preview = preload("res://scripts/ui/skill_preview.gd")
const Overview = preload("res://scripts/ui/growth_overview.gd")

static func _snapshot(state) -> String:
	return JSON.stringify([state.phase, state.player, state.facing, state.hp, state.max_hp,
		state.elapsed, state.kills, state.shots, state.shot_clock, state.spawn_clock,
		state.hurt_clock, state._regen_remainder, state.enemies, state.bullets,
		state.pickups, state.effects, state.skill_clocks, state.stats,
		state.growth.owned, state.growth.pool, state.growth.level, state.growth.xp,
		state.growth.pending, state.growth.offer, state.growth.ticket, state.growth.revision,
		state.rng.state, state.growth.rng.state, state.magic.config, state.magic.mana,
		state.magic.cooldown_left, state.magic.casts, state.magic.ticket,
		state.navigation_ticket, state.transition_action, state.result_summary(),
		state.cues.snapshot(), state.feedback.snapshot(state.hp, state.max_hp)])

static func _legacy_attack(effect: String, rank: int, rate: float) -> Dictionary:
	# Independent numeric oracle from pre-refactor GAME-005, not production profiles.
	var table: Dictionary = {
		"rifle": {"damage": 10.0 + 3.0 * (rank - 1), "projectiles": 1, "hits": 1, "speed": 920.0},
		"scatter": {"damage": 7.0 + rank * 2.0, "projectiles": 3, "hits": 1, "speed": 920.0},
		"lance": {"damage": 12.0 + rank * 4.0, "projectiles": 1, "hits": 1 + rank, "speed": 1150.0},
		"grenade": {"damage": 12.0 + rank * 4.0, "radius": 60.0 + rank * 8.0},
		"pulse": {"damage": 8.0 + rank * 3.0, "radius": 105.0 + rank * 8.0},
		"crossfire": {"damage": 9.0 + rank * 3.0, "projectiles": 4, "hits": 1, "speed": 920.0},
		"chain": {"damage": 9.0 + rank * 2.0, "targets": 1 + rank, "link_range": 160.0},
		"heavy": {"damage": 24.0 + rank * 8.0, "projectiles": 1, "hits": 1, "speed": 1300.0},
		"sigil": {"damage": 18.0 + rank * 6.0, "radius": 75.0 + rank * 12.0}}
	var value: Dictionary = table[effect]
	value["interval"] = (0.30 if effect == "rifle" else (3.0 if effect == "sigil" else 2.0)) / rate
	return value

static func _check_attack(state, effect: String, expected: Dictionary, verify: Callable) -> void:
	state.enemies.clear()
	state.bullets.clear()
	state.effects.clear()
	state.skill_clocks.clear()
	state.add_enemy(state.player + Vector2(80, 0))
	state.enemies[0]["hp"] = 100000
	if effect == "rifle":
		state._auto_fire()
		verify.call(is_equal_approx(state.shot_clock, float(expected["interval"])), "Rifle actually uses the preview interval")
	else:
		state._tick_skills(0.0)
		var id: String = ""
		for entry in state.growth.pool:
			if entry["effect"] == effect:
				id = str(entry["id"])
		verify.call(is_equal_approx(float(state.skill_clocks[id]), float(expected["interval"])), "Automatic skill actually uses shared interval: " + effect)
	if expected.has("projectiles"):
		verify.call(state.bullets.size() == int(expected["projectiles"]), "Actual projectile count: " + effect)
		for bullet in state.bullets:
			verify.call(float(bullet["damage"]) == float(expected["damage"])
				and int(bullet["remaining"]) == int(expected["hits"])
				and float(bullet["speed"]) == float(expected["speed"]), "Actual projectile values: " + effect)
	else:
		verify.call(100000 - int(state.enemies[0]["hp"]) == int(ceil(float(expected["damage"]))), "Actual committed base damage: " + effect)
		if expected.has("radius"):
			verify.call(float(state.effects[0]["radius"]) == float(expected["radius"]), "Actual burst radius: " + effect)

static func run(scene, verify: Callable) -> void:
	var reference = RunState.new()
	verify.call(reference.start(6006), "Preview fixture starts with the real catalog")
	for effect in ["rifle", "scatter", "lance", "grenade", "pulse", "crossfire", "chain", "heavy", "sigil"]:
		for rank in range(1, 6):
			for rate in [1.0, 1.16, 1.4]:
				verify.call(reference.attack_profile(effect, rank, rate) == _legacy_attack(effect, rank, rate), "Shared profile preserves previous values: %s/%d/%.2f" % [effect, rank, rate])
	verify.call(reference.attack_profile("rifle", 0, 1.0).is_empty(), "Unowned attack has no fictitious Lv.0 damage")
	verify.call(Preview.build(reference, "unknown").is_empty(), "Unknown candidate has no invented preview")
	var comparisons: int = 0
	for definition in reference.growth.pool:
		var id: String = str(definition["id"])
		for rank in range(0, int(definition["max_level"])):
			if id == "common_rifle" and rank == 0:
				continue # The actual run already starts with rifle Lv.1.
			var state = RunState.new()
			state.start(6010 + rank)
			if rank > 0:
				state.growth.owned[id] = rank
			state._refresh_stats()
			state.hp = state.max_hp - 37
			state.magic.mana = 31.0
			state.magic.cooldown_left = 0.0
			state.grant_xp(state.growth.threshold())
			state.growth.offer.clear()
			state.growth.offer.append(id) # Explicit candidate fixture, not an extra selection.
			var original: String = _snapshot(state)
			var data: Dictionary = Preview.build(state, id)
			verify.call(not data.is_empty(), "Every eligible candidate/rank has a preview: %s/%d" % [id, rank])
			if data.is_empty():
				continue
			for repeat in range(3):
				Preview.describe(Preview.build(state, id))
			verify.call(_snapshot(state) == original, "Repeated preview leaves HP/MP/XP/RNG/tickets/cues unchanged: " + id)
			var copied: Dictionary = data.duplicate(true)
			copied["after"]["stats"]["power"] = 999.0
			verify.call(_snapshot(state) == original, "Preview copies cannot mutate actual stats")
			var ticket: int = state.growth.ticket
			verify.call(state.select_skill(id, ticket), "Original selection path accepts the candidate once")
			verify.call(state.stats == data["after"]["stats"] and state.max_hp == int(data["after"]["max_hp"])
				and state.hp == int(data["after"]["hp"]), "Actual post-selection values match prediction: " + id)
			verify.call(state.magic.mana == 31.0 and state.magic.cooldown_left == 0.0, "Selection preview does not refill mana/cooldown")
			var selected: String = _snapshot(state)
			verify.call(not state.select_skill(id, ticket) and selected == _snapshot(state), "Stale selection is still rejected")
			var overview: Dictionary = Overview.capture(state)
			verify.call(overview["stats"] == data["after"]["stats"] and int(overview["hp"]) == int(data["after"]["hp"]), "Overview agrees with choice preview: " + id)
			if data["after"].has("magic"):
				verify.call(state.magic.profile(rank + 1) == data["after"]["magic"], "Active magic uses the same character profile")
			if data["after"].has("attack"):
				_check_attack(state, str(definition["effect"]), data["after"]["attack"], verify)
			comparisons += 1
	verify.call(comparisons == 89, "All 18 candidates and every reachable pre-cap rank covered")
	# Full slots and max rank remain actual eligibility constraints.
	reference.growth.owned = {"common_rifle": 5, "common_scatter": 1, "common_lance": 1, "common_grenade": 1}
	verify.call(Preview.build(reference, "common_rifle").is_empty(), "Maxed skill is not offered a false extra level")
	verify.call(Preview.build(reference, "viya_sigil").is_empty(), "Full attack slots do not invent a new-slot preview")
	reference.start(6020)
	var magic_data: Dictionary = Preview.build(reference, str(reference.magic.config["upgrade_skill_id"]))
	verify.call(float(magic_data["before"]["magic"]["damage"]) == 100.0
		and float(magic_data["after"]["magic"]["damage"]) == 130.0, "First magic upgrade starts from the already usable rank-zero spell")
	verify.call(Preview.describe(magic_data).contains("초당 MP 회복 1") and not Preview.describe(magic_data).contains("재사용"), "Mana-only upgrade preview shows regeneration without cooldown")
	reference.magic.config["damage"] = 77.0
	magic_data = Preview.build(reference, str(reference.magic.config["upgrade_skill_id"]))
	verify.call(float(magic_data["before"]["magic"]["damage"]) == 77.0, "Preview reads config values instead of hardcoding Viya damage")
	# Production F5 scene: exactly the old candidates, callbacks and overview flow.
	scene.begin_run()
	scene.simulation.spawn_clock = 999.0
	scene.simulation.grant_xp(30.0)
	scene._physics_process(0.0)
	var offer: Array[String] = scene.simulation.growth.offer.duplicate()
	var choice_ticket: int = scene.simulation.growth.ticket
	verify.call(scene.choice_buttons.size() == 3, "Preview does not add a fourth selection card")
	for i in range(scene.choice_buttons.size()):
		var button: Button = scene.choice_buttons[i]
		var expected: Dictionary = Preview.build(scene.simulation, offer[i])
		verify.call(button.text.contains("선택 시 변화") and button.text.contains("[임시]")
			and button.get_meta("skill_preview") == expected, "Actual card contains the read-only profile for its own candidate")
	var original_state: String = _snapshot(scene.simulation)
	scene._show_levelup()
	verify.call(_snapshot(scene.simulation) == original_state, "Rebuilding cards does not reroll or spend resources")
	scene.overview_button.pressed.emit()
	scene.overview_return_button.pressed.emit()
	verify.call(scene.simulation.growth.offer == offer and scene.simulation.growth.ticket == choice_ticket, "Overview returns to the same preview candidates/ticket")
	scene.root_ui.size = Vector2(853, 384)
	scene.safe_area_override = Rect2()
	scene._apply_layout()
	verify.call(scene._choice_grid.columns == 1 and scene.choice_buttons.size() == 3, "Compact cards retain the existing one-column scroll layout")
	var predicted: Dictionary = Preview.build(scene.simulation, offer[0])
	var links: Array[Dictionary] = scene.choice_buttons[0].get_signal_connection_list("pressed")
	verify.call(links.size() == 1, "Card retains a single confirmation callback")
	if links.size() == 1:
		var choose: Callable = links[0]["callable"]
		choose.call()
		verify.call(scene.simulation.stats == predicted["after"]["stats"] and scene.simulation.hp == int(predicted["after"]["hp"]), "Actual card selection applies the shown values")
		var once: Dictionary = scene.simulation.growth.owned.duplicate(true)
		choose.call()
		verify.call(scene.simulation.growth.owned == once, "Duplicate card press still cannot upgrade twice")
	scene.root_ui.size = Vector2(1280, 720)
	scene._apply_layout()
	scene.begin_run()
