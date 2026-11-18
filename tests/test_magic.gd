extends SceneTree
## Production GDScript + real start scene handlers. Device touch is separate QA.
const RunState = preload("res://scripts/combat/run_state.gd")
const Growth = preload("res://scripts/progression/growth_state.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func quiet_state():
	var state = RunState.new()
	verify(state.start(504), "Start configured Viya")
	state.spawn_clock = 999.0
	state.shot_clock = 999.0
	return state

func choose_upgrade(state) -> void:
	# Deterministic test fixture; actual selection still checks its ID and ticket.
	state.growth.pending = 1
	state.growth.offer.assign(["viya_ultimate"])
	state.growth.ticket += 1
	state.phase = RunState.Phase.CHOOSING
	verify(state.select_skill("viya_ultimate", state.growth.ticket), "Select real ultimate enhancement")

func snapshot(state) -> String:
	return JSON.stringify([state.magic.mana, state.magic.cooldown_left, state.magic.casts,
		state.magic.ticket, state.enemies, state.pickups, state.effects, state.kills])

func _run() -> void:
	var growth = Growth.new()
	growth.reset("viya", 44)
	for level in range(1, 51):
		growth.level = level
		verify(growth.threshold() == (10.0 + (level - 1) * 6.0) * 3.0, "Required XP tripled at level %d" % level)
	growth.reset("viya", 44)
	growth.gain(29.0)
	verify(growth.level == 1 and growth.pending == 0, "29 XP does not level up")
	growth.gain(1.0)
	verify(growth.level == 2 and growth.pending == 1 and growth.xp == 0.0, "30 XP opens first level")
	growth.reset("viya", 44)
	growth.gain(144.5)
	verify(growth.level == 4 and growth.pending == 3 and growth.xp == 0.5, "Triple curve preserves multiple levels and fractional remainder")
	for entry in growth.pool:
		verify(str(entry["name"]).begins_with("[임시] "), "Temporary name: " + str(entry["id"]))

	var dormant = RunState.new()
	verify(not dormant.cast_ultimate(dormant.magic.ticket), "No magic before run starts")
	var state = quiet_state()
	var bad_cost: Dictionary = state.magic.config.duplicate(true)
	bad_cost["mana_cost"] = -1.0
	verify(not state.magic.accepts(bad_cost, "viya"), "Runtime config rejects negative cost")
	verify(state.magic.mana == 100.0 and state.magic.cooldown_left == 0.0, "Run starts with full MP and ready magic")
	verify(state.growth.pool.size() == 18, "Active magic is not a nineteenth choice")
	state.add_enemy(state.player + Vector2(459, 0))
	state.add_enemy(state.player + Vector2(461, 0))
	var ticket: int = state.magic.ticket
	verify(state.cast_ultimate(ticket), "Configured button action casts")
	verify(state.magic.mana == 60.0 and state.magic.cooldown_left == 0.0 and state.magic.casts == 1, "One cast consumes 40 MP with no cooldown")
	verify(state.kills == 1 and state.enemies.size() == 1 and state.pickups.size() == 1, "Radius damage uses ordinary death and XP-drop path")
	verify(state.pickups[0]["value"] == 5.0 and state.growth.xp == 0.0, "XP reward unchanged and not awarded until collected")
	verify(state.effects[-1]["kind"] == "ultimate" and state.effects[-1]["radius"] == 460.0, "Magic effect identifies actual damage radius")
	var before: String = snapshot(state)
	verify(not state.cast_ultimate(ticket) and snapshot(state) == before, "Duplicate/stale input cannot spend or damage twice")
	verify(state.cast_ultimate(state.magic.ticket) and state.magic.mana == 20.0 and state.magic.cooldown_left == 0.0, "A fresh input casts again immediately using only MP")
	before = snapshot(state)
	verify(not state.cast_ultimate(state.magic.ticket) and snapshot(state) == before, "Third immediate cast is blocked by insufficient MP")
	state.set_paused(true)
	before = snapshot(state)
	state.step(0.05, Vector2.RIGHT)
	verify(snapshot(state) == before, "Settings pause freezes MP, cooldown and effects")
	verify(not state.cast_ultimate(state.magic.ticket) and snapshot(state) == before, "No cast while paused")
	state.set_paused(false)
	state.enemies.clear()
	state.step(0.05, Vector2.ZERO)
	verify(is_equal_approx(state.magic.mana, 20.05) and state.magic.cooldown_left == 0.0, "Only active simulation restores MP at one per second")
	state.grant_xp(state.growth.threshold())
	before = snapshot(state)
	state.step(0.05, Vector2.RIGHT)
	verify(snapshot(state) == before and not state.cast_ultimate(state.magic.ticket), "Level-up choice freezes and blocks magic")
	var old_magic_ticket: int = state.magic.ticket
	state.start(505)
	verify(state.magic.mana == 100.0 and state.magic.casts == 0 and state.magic.cooldown_left == 0.0, "Restart resets per-run MP/cooldown/count")
	before = snapshot(state)
	verify(not state.cast_ultimate(old_magic_ticket) and snapshot(state) == before, "Previous-run magic request cannot cast after restart")
	state.magic.mana = 39.0
	before = snapshot(state)
	verify(state.magic.unavailable_reason(true) == "mana" and not state.cast_ultimate(state.magic.ticket), "Insufficient MP rejected")
	verify(snapshot(state) == before, "Rejected low-MP cast has zero effects")
	state.magic.mana = 40.0
	verify(state.cast_ultimate(state.magic.ticket) and state.magic.mana == 0.0, "Exact MP cost accepted, never negative")
	verify(state.enemies.is_empty(), "Empty-area cast allowed without inventing enemies")
	state.hurt_clock = 0.0
	state.damage_player(1000)
	before = snapshot(state)
	state.step(0.05, Vector2.ZERO)
	verify(not state.cast_ultimate(state.magic.ticket) and snapshot(state) == before, "Defeat stops resources and rejects casts")

	state = quiet_state()
	choose_upgrade(state)
	state.add_enemy(state.player + Vector2(240, 0))
	state.enemies[0]["hp"] = 200
	verify(state.cast_ultimate(state.magic.ticket), "Cast after actual enhancement selection")
	verify(state.enemies[0]["hp"] == 70 and state.effects[-1]["radius"] == 496.0, "Rank 1 increases real damage and range")
	verify(state.growth.skill_level("viya_sigil") == 0, "Active enhancement does not acquire automatic sigil")
	var saved_mp: float = state.magic.mana
	var saved_cd: float = state.magic.cooldown_left
	choose_upgrade(state)
	verify(state.magic.mana == saved_mp and state.magic.cooldown_left == saved_cd, "Upgrading does not refill MP or clear current cooldown")
	state = quiet_state()
	var invalid: Dictionary = state.growth.catalog.characters["viya"].duplicate(true)
	invalid["active_magic"]["mana_cost"] = -1.0
	state.growth.catalog.characters["bad"] = invalid
	before = snapshot(state)
	verify(not state.start(4, "bad") and snapshot(state) == before, "Invalid character/magic fails before run mutation")
	var hero: Dictionary = state.growth.catalog.characters["viya"].duplicate(true)
	for entry in hero["skills"]:
		entry["owner"] = "test_hero"
		entry["id"] = "test_" + str(entry["effect"])
	hero["active_magic"]["owner"] = "test_hero"
	hero["active_magic"]["id"] = "test_wave"
	hero["active_magic"]["upgrade_skill_id"] = "test_ultimate"
	hero["active_magic"]["name"] = "[임시] 시험 마법"
	hero["active_magic"]["radius"] = 90.0
	hero["active_magic"]["cooldown"] = 3.0
	state.growth.catalog.characters["test_hero"] = hero
	verify(state.start(6, "test_hero"), "Test-only character binds its own magic config")
	verify(state.magic.owner_id == "test_hero" and state.magic.profile(0)["radius"] == 90.0, "No hard-coded Viya magic fallback")
	verify(state.cast_ultimate(state.magic.ticket) and state.magic.cooldown_left == 3.0, "Generic magic still supports a configured positive cooldown")
	before = snapshot(state)
	verify(not state.cast_ultimate(state.magic.ticket) and snapshot(state) == before, "A different character configured with cooldown still waits")
	verify(state.growth.definition("viya_ultimate").is_empty(), "Other character does not inherit Viya enhancement")

	# Actual F5 scene and input handlers with synthetic events; NOT a device test.
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.run_store.path = "user://native-test_magic-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".save"
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	await process_frame
	scene.begin_run()
	scene._physics_process(0.0)
	verify(not scene.magic_button.disabled and scene.magic_button.text.contains("[임시]"), "Real HUD shows temporary, enabled magic")
	verify(scene.level_text.text.contains("30"), "HUD uses new first XP threshold")
	var move := InputEventScreenTouch.new()
	move.index = 5
	move.pressed = true
	move.position = Vector2(100, 380)
	scene.movement._input(move)
	var drag := InputEventScreenDrag.new()
	drag.index = 5
	drag.position = Vector2(160, 380)
	scene.movement._input(drag)
	var magic_touch := InputEventScreenTouch.new()
	magic_touch.index = 9
	magic_touch.pressed = true
	magic_touch.position = scene.magic_button.get_global_rect().get_center()
	scene.movement._input(magic_touch)
	scene._input(magic_touch)
	verify(scene.simulation.magic.casts == 1, "Second-finger magic handler casts once")
	verify(scene.movement.touch_id == 5 and scene.movement.axis.x > 0.0, "Magic finger does not steal movement finger")
	scene._input(magic_touch)
	verify(scene.simulation.magic.casts == 1, "Repeated held finger does not recast")
	magic_touch.pressed = false
	magic_touch.canceled = true
	scene._input(magic_touch)
	verify(scene._magic_touch_id == -1 and scene.movement.touch_id == 5, "Magic cancel releases only its own finger")
	scene._physics_process(0.0)
	verify(not scene.magic_button.disabled and not scene.magic_button.text.contains("재사용"), "Real HUD remains ready after a cast when MP is sufficient")
	verify(scene.magic_button.tooltip_text.contains("초당 MP 회복 1") and not scene.magic_button.tooltip_text.contains("쿨다운"), "Real HUD describes mana regeneration instead of cooldown")
	scene.magic_button.pressed.emit()
	scene._physics_process(0.0)
	verify(scene.simulation.magic.casts == 2 and scene.magic_button.disabled and scene.magic_button.text.contains("마력 부족"), "Second fresh button press casts immediately, then MP blocks the button")
	scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	before = snapshot(scene.simulation)
	scene._physics_process(0.05)
	scene.magic_button.pressed.emit()
	verify(snapshot(scene.simulation) == before and scene.simulation.phase == RunState.Phase.PAUSED, "Focus loss freezes magic and blocks button signal")
	verify(scene.movement.touch_id == -1, "Focus loss clears movement finger")
	scene.begin_run()
	scene.magic_button.pressed.emit()
	verify(scene.simulation.magic.casts == 1, "Mouse/button signal wired after restart")
	for label in scene.attack_slots:
		if label.text != "--":
			verify(label.text.contains("[임시]"), "Owned skill HUD explicitly temporary")
	scene.queue_free()
	await process_frame
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "status": "PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
