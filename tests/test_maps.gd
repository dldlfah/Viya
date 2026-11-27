extends RefCounted
const State = preload("res://scripts/combat/run_state.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const Store = preload("res://scripts/progression/run_store.gd")
const Campaign = preload("res://tests/test_campaign.gd")
const Cues = preload("res://scripts/combat/approach_cues.gd")
static func quiet(id: String, seed_value: int = 1601):
	var state = State.new()
	state.start(seed_value,"viya",null,id)
	state.spawn_clock = 999.0
	state.shot_clock = 999.0
	state._scatter_clock = 999.0
	state.stage_rules.swarm.chance = 0.0
	return state
static func run(scene, verify: Callable) -> void:
	var state = quiet("prologue_wall")
	verify.call(state.world_size == Vector2(5000,3200) and state.player == Vector2(2500,600), "Data-driven prologue starts in the5000x3200 trial field")
	var before: Dictionary = Campaign.comparable(state)
	verify.call(not state.start(3,"viya",null,"missing") and before == Campaign.comparable(state), "Unknown map cannot partly reset an existing run")
	var bad: Dictionary = state.map_catalog.definition("prologue_wall")
	bad.obstacles[0].rect = [0,0,5000,1000]
	verify.call(not state.MapCatalog.valid(bad), "A solid over the player start is invalid map data")
	for at in [Vector2(30,500),Vector2(4970,3170),Vector2(2500,600)]:
		state.player = at
		var visible: Rect2 = state.visible_world()
		verify.call(Rect2(Vector2.ZERO,state.world_size).encloses(visible), "Edge camera stays in its configured world bounds")
	state.player = state.map_space.start
	for i in range(100):
		state.step(0.05,Vector2.UP)
	verify.call(state.player.y >= 450 and state.player.y < 460 and state.map_space.valid_position(state.player,30), "City wall actually blocks sustained player movement")
	state = quiet("outskirts_trial")
	verify.call(state.world_size == Vector2(4200,2800) and state.map_space.definition.mode == "perimeter", "General region uses its own size/start/independent perimeter rules")
	movement_checks(verify)
	spawn_checks(verify)
	recovery_checks(verify)
	# Production stage UI applies stage->map data, never a second simulation.
	scene.begin_run()
	verify.call(scene.simulation.map_id == str(scene.simulation.stage_catalog.for_departure(scene.simulation.stage).map_id), "Actual existing start scene applies its configured stage map")
	var frozen: Dictionary = Campaign.comparable(scene.simulation)
	scene.view.queue_redraw()
	await scene.get_tree().process_frame
	verify.call(frozen == Campaign.comparable(scene.simulation), "Map/environment/camera/approach rendering leaves gameplay and RNG unchanged")
	verify.call(scene.layout_data.battle.size.y > 100.0, "Default live HUD retains a usable battle viewport")
	verify.call(scene._handle_mobile_back() and scene.simulation.phase == State.Phase.PAUSED, "Mobile Back pauses combat instead of quitting it")
	var art = preload("res://scripts/ui/asset_slots.gd").new()
	verify.call(art.definitions.keys().all(func(key):return key=="viya_battle" or art.definitions[key]=="") and art.definitions.viya_battle=="res://assets/characters/pilot_32/game069_s_run_fire/viya_game069_frames.tres","Only the explicitly requested Viya pilot with its E derivative is bound; other slots remain blank and final art approval remains separate")
	var fixture := "user://icon-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".tres"
	var texture := GradientTexture2D.new()
	texture.gradient = Gradient.new()
	texture.width = 16
	texture.height = 16
	ResourceSaver.save(texture,fixture)
	scene.ui_art.definitions.common_rifle = fixture
	scene._update_slots(scene.attack_slots,"attack")
	verify.call(scene.slot_buttons[0].icon != null,"Actual skill button resolves its optional external art slot")
	scene.ui_art.definitions.common_rifle = ""
	scene._update_slots(scene.attack_slots,"attack")
	DirAccess.remove_absolute(fixture)
	verify.call(scene.slot_buttons[0].icon == null,"Removing the art resource cleanly restores the existing text placeholder")
	verify.call(true,"Map integration reached its last check")
static func movement_checks(verify: Callable) -> void:
	var state = quiet("outskirts_trial")
	state.player = Vector2(1100,1175)
	var stopped: Vector2 = state.map_space.move(state.player,Vector2(1000,0),30)
	verify.call(stopped.x <= 1170.0 and state.map_space.valid_position(stopped,30), "Swept movement cannot tunnel through a solid ruin")
	state.player = Vector2(1600,1175)
	state.add_enemy(Vector2(1100,1175))
	var arrived := false
	var safe := true
	for i in range(400):
		state.step(0.05,Vector2.ZERO)
		safe = safe and state.map_space.valid_position(state.enemies[0].p,24)
		if state.enemies[0].p.distance_to(state.player) < 60:
			arrived = true
			break
	verify.call(arrived and safe,"Real ground pursuit routes around the ruin and reaches the other side without clipping")
	state = quiet("outskirts_trial")
	state.player = Vector2(1100,1175)
	state.add_enemy(Vector2(1600,1175))
	state._projectile(Vector2.RIGHT,100,4,1000)
	for i in range(12):
		state._move_bullets(0.05)
	verify.call(state.bullets.is_empty() and state.enemies[0].hp == 20,"Even piercing friendly bullets stop at terrain before damaging a covered target")
	state.enemy_bullets.append({"p":Vector2(1600,1175),"velocity":Vector2(-2000,0),"life":3.0,"damage":8})
	for i in range(12):
		state._move_enemy_bullets(0.05)
	verify.call(state.enemy_bullets.is_empty() and state.hp == 100,"Hostile swept bullets stop at the same solid terrain")
	state.add_enemy(Vector2(1100,1175),"normal","flier")
	var flier: Dictionary = state.enemies[-1]
	state._move_fliers(0.5)
	verify.call(flier.p.x == 1280.0 and flier.p.y == 1175.0,"Flying units retain straight flight over low ground obstacles")
static func spawn_checks(verify: Callable) -> void:
	for id in ["prologue_wall","outskirts_trial"]:
		var state = quiet(id)
		var offscreen := true
		var front := true
		var quadrants := {}
		for i in range(32):
			var created: bool = state._spawn_enemy()
			offscreen = offscreen and created
			if not created:continue
			var enemy: Dictionary = state.enemies[-1]
			offscreen = offscreen and not state.visible_world().grow(32).has_point(enemy.p) and state.map_space.valid_position(enemy.p,24)
			front = front and enemy.p.y > state.player.y
			quadrants[Vector2(signf(enemy.p.x-state.player.x),signf(enemy.p.y-state.player.y))] = true
		verify.call(offscreen,"Real spawns are off camera and outside terrain in " + id)
		verify.call(front if id == "prologue_wall" else quadrants.size()==4,"Early frontline is one-sided while general map supports all directions")
		var count_before: int = state.enemies.size()
		for index in range(4):
			verify.call(state._spawn_scatter(),"Thirty-member additional map formation accepts a valid anchor")
			var pack: Array = state.enemies.filter(func(enemy): return enemy.scatter_group == index+1)
			verify.call(pack.size()==30 and pack.all(func(enemy): return not state.visible_world().grow(32).has_point(enemy.p) and state.map_space.valid_position(enemy.p,24)),"Map commits all30 scattered actors outside camera/terrain")
		verify.call(state.enemies.size()==count_before+120 and state._spawn_swarm(),"Original flying event coexists with all four added map packs")
		var cues: Array = Cues.build(state,state.visible_world())
		verify.call(not cues.is_empty() and cues.size()<=8,"Approach warnings use actual offscreen packs and have a fixed display bound")
	var state = quiet("prologue_wall")
	var early: Array = state.map_space.definition.zones.filter(func(zone): return zone.from<=0)
	var middle: Array = state.map_space.definition.zones.filter(func(zone): return zone.from<=120)
	var late: Array = state.map_space.definition.zones.filter(func(zone): return zone.from<=240)
	verify.call(early.size()==1 and middle.size()==2 and late.size()==3,"Prologue opens one flank at2minutes and both flanks at4minutes while retaining a weighted main front")
static func recovery_checks(verify: Callable) -> void:
	for id in ["prologue_wall","outskirts_trial"]:
		var state = quiet(id)
		state.player = Vector2(3900,2500)
		state._scatter_clock = 0.03
		state.magic.mana = 33.5
		state._spawn_scatter()
		var restored = State.new()
		verify.call(Snapshot.restore(Snapshot.capture(state),restored) and restored.map_id==id and restored.player==state.player and restored.world_size==state.world_size and restored.magic.mana==33.5,"Map ID/expanded coordinates/spent MP restore exactly in " + id)
		restored.set_paused(false)
		var same := true
		for frame in range(30):
			state.step(0.05,Vector2.LEFT)
			restored.step(0.05,Vector2.LEFT)
			same = same and Campaign.comparable(state)==Campaign.comparable(restored)
		verify.call(same,"Map movement/next pack/RNG continue identically after restore")
		var bad: Dictionary = Snapshot.capture(state)
		bad.run.map_id = "unknown"
		verify.call(not Snapshot.restore(bad,restored),"Unknown map save is rejected, never guessed")
		bad = Snapshot.capture(state)
		bad.run.player = state.map_space.solids[0].get_center()
		verify.call(not Snapshot.restore(bad,restored),"Saved player inside a solid cannot be resumed")
