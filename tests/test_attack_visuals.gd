extends RefCounted
## Called by the existing combat-cues suite. Requires the real Godot engine.
const RunState = preload("res://scripts/combat/run_state.gd")
const Visuals = preload("res://scripts/combat/attack_visuals.gd")

static func _quiet():
	var state = RunState.new()
	state.start(407)
	state.spawn_clock = 999.0
	state.shot_clock = 999.0
	return state

static func _snapshot(state) -> String:
	var bullets: Array = state.bullets.duplicate(true)
	var effects: Array = state.effects.duplicate(true)
	for bullet in bullets:
		bullet.erase("source")
	for effect in effects:
		effect.erase("from")
	return var_to_str([state.phase, state.player, state.facing, state.hp, state.max_hp,
		state.elapsed, state.kills, state.shots, state.shot_clock, state.spawn_clock,
		state.hurt_clock, state.enemies, bullets, state.pickups, effects, state.skill_clocks,
		state.stats, state.rng.state, state.growth.rng.state, state.growth.owned,
		state.growth.xp, state.growth.level, state.growth.pending, state.growth.offer,
		state.growth.ticket, state.growth.revision, state.magic.config, state.magic.mana,
		state.magic.cooldown_left, state.magic.ticket, state.magic.casts,
		state.navigation_ticket, state.transition_action, state.result_summary(),
		state.cues.snapshot(), state.feedback.snapshot(state.hp, state.max_hp)])

static func run(scene, verify: Callable) -> void:
	var silhouettes: Dictionary = {}
	for source in ["rifle", "scatter", "lance", "crossfire", "heavy"]:
		silhouettes[Visuals.projectile_style(source)["shape"]] = true
	for kind in ["blast", "pulse", "chain", "sigil"]:
		silhouettes[Visuals.effect_style(kind)["shape"]] = true
	verify.call(silhouettes.size() == 9, "Nine existing attacks have different silhouettes, not only different colors")
	verify.call(Visuals.effect_style("sigil")["shape"] != Visuals.effect_style("ultimate")["shape"], "Automatic sigil stays distinct from manual magic")
	for effect in ["rifle", "scatter", "lance", "crossfire", "heavy"]:
		for rank in range(1, 6):
			var state = _quiet()
			state.growth.owned["common_" + effect] = rank
			state.add_enemy(state.player + Vector2(100, 0))
			var profile: Dictionary = state.attack_profile(effect, rank, 1.0)
			if effect == "rifle":
				state._auto_fire()
			else:
				state._tick_skills(0.0)
			verify.call(state.bullets.size() == int(profile["projectiles"]), "Actual projectile count unchanged: " + effect)
			var valid: bool = true
			for bullet in state.bullets:
				valid = valid and bullet["source"] == effect and bullet["damage"] == profile["damage"] and bullet["speed"] == profile["speed"] and bullet["remaining"] == profile["hits"]
			verify.call(valid and state.cues.events.is_empty(), "Metadata follows actual spawns and firing alone does not report a hit: " + effect)
	for effect in ["grenade", "pulse", "sigil"]:
		var state = _quiet()
		var id: String = "viya_sigil" if effect == "sigil" else "common_" + effect
		state.growth.owned[id] = 1
		var target: Vector2 = state.player + Vector2(300, 0)
		state.add_enemy(target)
		state._tick_skills(0.0)
		var profile: Dictionary = state.attack_profile(effect, 1, 1.0)
		var data: Dictionary = state.effects[0]
		verify.call(data["p"] == (state.player if effect == "pulse" else target) and data["radius"] == profile["radius"], "Effect uses the real burst center and damage radius: " + effect)
		if effect == "pulse":
			verify.call(state.enemies[0]["hp"] == 20 and state.cues.events.is_empty(), "An empty defense pulse draws its area without inventing a hit")
	var chain = _quiet()
	chain.growth.owned["common_chain"] = 2
	var points: Array[Vector2] = [chain.player + Vector2(100, 0), chain.player + Vector2(220, 0), chain.player + Vector2(350, 0)]
	for at in points:
		chain.add_enemy(at)
		chain.enemies[-1]["hp"] = 1
	chain.add_enemy(chain.player + Vector2(600, 300))
	chain._tick_skills(0.0)
	verify.call(chain.kills == 3 and chain.effects.size() == 3 and chain.pickups.size() == 3, "Real chain endpoints survive target removal without changing rewards")
	for i in range(3):
		verify.call(chain.effects[i]["from"] == (chain.player if i == 0 else points[i - 1]) and chain.effects[i]["p"] == points[i], "Each chain segment joins only actual consecutive targets")
	var before: String = var_to_str(chain.effects)
	chain.set_paused(true)
	chain.step(0.05, Vector2.RIGHT)
	verify.call(before == var_to_str(chain.effects), "Existing pause freezes links and effects")
	chain.set_paused(false)
	chain.grant_xp(30.0)
	before = var_to_str(chain.effects)
	chain.step(0.05, Vector2.RIGHT)
	verify.call(before == var_to_str(chain.effects), "Pending growth freezes links and effects")
	chain.request_transition("leave", chain.navigation_ticket)
	chain.confirm_transition(chain.navigation_ticket)
	chain.step(0.05, Vector2.RIGHT)
	verify.call(before == var_to_str(chain.effects), "Abandoned result preserves frozen effects")
	chain.return_to_ready(chain.navigation_ticket)
	chain.step(0.05, Vector2.RIGHT)
	verify.call(before == var_to_str(chain.effects), "Lobby never advances previous effects")
	chain.start(407)
	verify.call(chain.effects.is_empty() and chain.bullets.is_empty(), "New deployment clears source-tagged bullets and links")
	var capped = _quiet()
	for i in range(RunState.MAX_BULLETS):
		capped._projectile(Vector2.RIGHT, 1.0, 1, 920.0, "held")
	capped.growth.owned["common_scatter"] = 1
	capped.add_enemy(capped.player + Vector2(100, 0))
	capped._tick_skills(0.0)
	verify.call(capped.bullets.size() == RunState.MAX_BULLETS and capped.bullets[-1]["source"] == "held" and capped.shots == RunState.MAX_BULLETS, "Rejected spawn cannot retag an old bullet or exceed the old cap")
	for i in range(RunState.MAX_EFFECTS):
		capped._effect(capped.player, 10.0, "blast")
	capped.growth.owned["common_chain"] = 1
	capped._tick_skills(0.0)
	verify.call(capped.effects.size() == RunState.MAX_EFFECTS and capped.effects[-1].has("from"), "Chain metadata reuses capped effect storage")
	# Compare production stepping with metadata retained vs discarded; do not
	# substitute a Python simulation or change the authoritative RNG streams.
	var a = _quiet()
	var b = _quiet()
	for state in [a, b]:
		state.growth.owned["common_chain"] = 2
		state.growth.owned["common_lance"] = 2
		state.stats["crit"] = 0.35
		state.shot_clock = 0.0
		for n in range(6):
			state.add_enemy(state.player + Vector2(120 + n * 60, 0))
	var equal: bool = true
	for frame in range(180):
		a.step(1.0 / 60.0, Vector2.LEFT)
		b.step(1.0 / 60.0, Vector2.LEFT)
		for bullet in b.bullets:
			bullet.erase("source")
		for effect in b.effects:
			effect.erase("from")
		equal = equal and _snapshot(a) == _snapshot(b)
	verify.call(equal, "Discarding visual metadata leaves damage, RNG, XP, timers and navigation identical")
	# Exercise drawing through the actual F5 View, not a substitute renderer.
	scene.begin_run()
	scene.simulation.spawn_clock = 999.0
	for entry in scene.simulation.growth.pool:
		if entry["row"] == "attack":
			scene.simulation.growth.owned[entry["id"]] = 1 # Test-only coverage, not a slot rule change.
	scene.simulation.add_enemy(scene.simulation.player + Vector2(100, 0))
	scene.simulation.enemies[0]["hp"] = 10000
	scene.simulation._auto_fire()
	scene.simulation._tick_skills(0.0)
	scene.simulation.cast_ultimate(scene.simulation.magic.ticket)
	before = _snapshot(scene.simulation)
	var metadata: String = var_to_str([scene.simulation.bullets, scene.simulation.effects])
	scene.view.queue_redraw()
	await scene.get_tree().process_frame
	await scene.get_tree().process_frame
	verify.call(before == _snapshot(scene.simulation) and metadata == var_to_str([scene.simulation.bullets, scene.simulation.effects]), "Actual View redraw reads attack data without mutation")
