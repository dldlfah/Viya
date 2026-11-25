extends RefCounted
const Slots=preload("res://scripts/ui/asset_slots.gd")
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Scenery=preload("res://scripts/combat/oblique_scenery.gd")
const MANIFEST:="res://assets/characters/pilot_32/source_manifest.json"
const RESOURCE:="res://assets/characters/pilot_32/resources/viya_directional_motion.tres"
const DIRECTIONS:=["e","se","s","sw","w","nw","n","ne"]

static func run(host,verify:Callable) -> void:
	var slots=Slots.new()
	var asset:Resource=slots.resource("viya_battle")
	verify.call(slots.definitions.viya_battle==RESOURCE and asset is SpriteFrames and is_same(asset,slots.resource("viya_battle")),"Supplied character resource is bound through the original cached Viya slot")
	if not asset is SpriteFrames:return
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var exact:bool=FileAccess.get_sha256(RESOURCE)==manifest.source_package.resource_original_sha256
	for entry in manifest.runtime_files:exact=exact and FileAccess.get_sha256(MANIFEST.get_base_dir().path_join(entry.path))==entry.sha256
	verify.call(exact and manifest.runtime_files.size()==208,"Every shipped PNG and the relative-path resource match the supplied package bytes")
	verify.call(asset.get_animation_names().size()==32 and not asset.has_animation("default") and not asset.has_animation("idle"),"Exactly32directional states are shipped without a generic or mirrored replacement")
	var total:=0
	for pose in ["idle","run","attack","hurt"]:
		var valid:=true
		var expected:int={"idle":1,"run":11,"attack":8,"hurt":6}[pose]
		var fps:float={"idle":1.0,"run":16.6666666667,"attack":50.0,"hurt":50.0}[pose]
		for direction in DIRECTIONS:
			var name:String=pose+"_"+direction
			valid=valid and asset.has_animation(name) and asset.get_frame_count(name)==expected and is_equal_approx(asset.get_animation_speed(name),fps) and asset.get_animation_loop(name)==(pose in ["idle","run"])
			for index in range(asset.get_frame_count(name)):
				valid=valid and asset.get_frame_texture(name,index).get_size()==Vector2(200,248) and asset.get_frame_duration(name,index)==1.0
				total+=1
		verify.call(valid,"Eight supplied directions retain native count/timing/loop/canvas for:"+pose)
	verify.call(total==208,"All208supplied frames are reachable in the game resource")
	var ui=load("res://scenes/main.tscn").instantiate()
	var folder:="user://character-pilot-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	ui.run_store.path=folder.path_join("battle.save");ui.gold_progress.path=folder.path_join("gold.cfg");ui.settings_path=folder.path_join("settings.cfg")
	host.get_tree().root.add_child(ui);ui.set_physics_process(false);await host.get_tree().process_frame
	Campaign.depart(ui)
	var state=ui.simulation
	state.player=Vector2(2500,1700);state.spawn_clock=999;state._scatter_clock=999;state._swarm_clock=999;state.shot_clock=999
	var resolved:=true
	for direction in DIRECTIONS:
		for pose in ["idle","run","attack","hurt"]:
			var sample:Dictionary=ui.view.actor_art.frame(ui.view.art,["viya_battle"],pose,direction,0)
			resolved=resolved and not sample.is_empty() and sample.animation==pose+"_"+direction and sample["size"]==Vector2(125,155) and sample.pivot==Vector2(.5,1)
	verify.call(resolved,"Existing adapter resolves all32poses upright at125x155 with the original bottom pivot")
	for viewport in [Vector2(1280,526),Vector2(960,396),Vector2(797,266),Vector2(3840,1700)]:
		var fits:=true
		var foot:=Vector2(390,210)
		for direction in DIRECTIONS:
			for pose in ["idle","run","attack","hurt"]:
				var sample:Dictionary=ui.view.actor_art.frame(ui.view.art,["viya_battle"],pose,direction,.07,viewport)
				var rect:Rect2=ui.view.actor_art.rectangle(sample,foot)
				fits=fits and rect.end.y==foot.y and is_equal_approx(rect.get_center().x,foot.x) and is_equal_approx(rect.size.x/rect.size.y,200.0/248.0) and rect.size.x<=200 and rect.size.y<=248
				fits=fits and is_equal_approx(rect.size.y,minf(155.0*viewport.y/526.0,248.0))
		verify.call(fits,"All32frames keep source aspect/foot anchoring and a consistent battle-height share capped at native pixels:"+str(viewport))
	ui.view.art.definitions.normal=RESOURCE
	var enemy_sample:Dictionary=ui.view.actor_art.frame(ui.view.art,["normal"],"idle","e",0,Vector2(3840,1700))
	verify.call(enemy_sample["size"]==Vector2(32,40),"Hero presentation enlargement cannot resize another actor that reuses the same texture resource")
	ui.view.art.definitions.normal=""
	var reference_height:Variant=ui.view.actor_art.specs.actors.viya_battle.reference_view_height
	for invalid in [0,NAN,"bad"]:
		ui.view.actor_art.specs.actors.viya_battle.reference_view_height=invalid
		verify.call(ui.view.actor_art.frame(ui.view.art,["viya_battle"],"idle","e",0,Vector2(1280,526)).is_empty(),"Invalid responsive size metadata falls back without NaN geometry:"+str(invalid))
	ui.view.actor_art.specs.actors.viya_battle.reference_view_height=reference_height
	var side_feet:=Vector2(140,0)
	var shape:Dictionary=Scenery.geometry(Rect2(0,0,100,20),200,Transform2D.IDENTITY)
	var body:=Rect2(side_feet-Vector2(62.5,155),Vector2(125,155))
	verify.call(not Scenery.occludes(shape,side_feet) and Scenery.occludes(shape,side_feet,body),"A wall touching the enlarged body triggers fading even when the old tiny body misses it")
	verify.call(not Scenery.occludes(shape,side_feet+Vector2(0,40),Rect2(body.position+Vector2(0,40),body.size)),"A wall behind the enlarged hero remains opaque instead of fading just because bounding boxes overlap")
	var run_sample:Dictionary=ui.view.actor_art.frame(ui.view.art,["viya_battle"],"run","ne",.661)
	var attack_sample:Dictionary=ui.view.actor_art.frame(ui.view.art,["viya_battle"],"attack","ne",.2)
	var hurt_sample:Dictionary=ui.view.actor_art.frame(ui.view.art,["viya_battle"],"hurt","ne",.3)
	verify.call(run_sample.index==0 and attack_sample.index==7 and hurt_sample.index==5,"Run loops at660ms while attack/hurt hold their native final frames after160/120ms")
	ui._physics_process(.01)
	verify.call(ui.view.actor_visual().sample.animation=="idle_e","Actual fresh combat selects supplied E idle without a test slot override")
	ui.movement.axis=Vector2(1,-1).normalized();ui._physics_process(.05)
	verify.call(ui.view.actor_visual().sample.animation=="run_ne","Real screenNE movement selects supplied NE run in the tilted stage")
	ui.movement.axis=Vector2.ZERO
	var toward:Vector2=ui.view.input_direction(Vector2(1,-1).normalized())
	state.add_enemy(state.player+toward*250);state.enemies[-1].speed=0;state.shot_clock=0
	ui._physics_process(.01)
	verify.call(state.shots>0 and ui.view.actor_visual().sample.animation=="attack_ne","Actual shot creation selects the supplied attack; firing cadence stays owned by RunState")
	state.hurt_clock=0
	state.damage_player(1,"physical",0,{"kind":"contact","id":state.enemies[-1].id,"p":state.player+toward*100})
	ui._physics_process(.01)
	verify.call(state.hp==99 and ui.view.actor_visual().sample.animation=="hurt_ne" and ui.view.actor_visual().sample.index==0,"Accepted received damage interrupts attack with native hurt frame0")
	var frozen:Dictionary=ui.view.actor_visual()
	ui.pause_game();ui._physics_process(.05)
	verify.call(ui.view.actor_visual().sample.index==frozen.sample.index and ui.view.actors.pose(state).clock==frozen.clock,"Pause freezes the real sprite phase without wall-clock animation")
	ui.resume_button.pressed.emit()
	for i in range(2):ui._physics_process(.05)
	# Controlled accepted re-hit: clear only the QA invulnerability lock, not game rules.
	state.hurt_clock=0;state.damage_player(1,"physical",0,{"kind":"contact","id":state.enemies[-1].id,"p":state.player+toward*100});ui._physics_process(.02)
	verify.call(ui.view.actor_visual().sample.animation=="hurt_ne" and ui.view.actor_visual().sample.index==5,"Same-pose accepted re-hit extends pain while retaining the last supplied frame")
	state.enemies.clear();state.shot_clock=999
	for i in range(4):ui._physics_process(.05)
	verify.call(ui.view.actor_visual().sample.animation=="idle_ne","Expired hurt returns to the corresponding supplied idle without replaying a shot")
	state.grant_xp(state.growth.threshold());ui._sync_phase_ui()
	frozen=ui.view.actor_visual()
	var offer:Array=state.growth.offer.duplicate()
	for i in range(3):ui._physics_process(.05)
	verify.call(ui.view.actor_visual().sample.index==frozen.sample.index and ui.view.actors.pose(state).clock==frozen.clock and state.growth.offer==offer,"Skill choice freezes sprite clock and preserves the same offer")
	ui._choose_skill(state.growth.offer[0],state.growth.ticket)
	for high in [false,true]:
		ui.view.high_angle=high;ui.view.queue_redraw();await host.get_tree().process_frame
		verify.call(not ui.view.actor_visual().sample.is_empty() and ui.view.actor_visual().sample.slot=="viya_battle","Actual renderer uses the shipped resource, including F8:"+str(high))
	var snapshot:Dictionary=Snapshot.capture(state)
	var before:Dictionary=state.cues.snapshot()
	for i in range(20):ui.view.actor_visual()
	verify.call(Snapshot.capture(state)==snapshot and state.cues.snapshot()==before,"Sprite sampling leaves gameplay/save/reward/RNG and effect clocks untouched")
	var reference=State.new()
	verify.call(Snapshot.VERSION==22 and Snapshot.restore(snapshot,reference),"Original schema22 restores gameplay without saving art paths or animation phase")
	reference.set_paused(false)
	var same:=true
	for i in range(100):
		if state.phase==State.Phase.CHOOSING:
			var id:String=state.growth.offer[0];ui._choose_skill(id,state.growth.ticket);reference.select_skill(id,reference.growth.ticket)
		ui._physics_process(.05);reference.step(.05,Vector2.ZERO)
		same=same and Campaign.comparable(state)==Campaign.comparable(reference)
	verify.call(same,"Shipped sprites preserve100world production steps/sevenRNG against independent restored gameplay")
	ui.view.art.definitions.viya_battle="res://".path_join("missing-character-pilot.tres")
	verify.call(ui.view.actor_visual().sample.is_empty(),"Missing optional pilot cleanly restores the existing procedural character fallback")
	ui.view.art.definitions.viya_battle=RESOURCE
	verify.call(ui.view.art.definitions.viya_portrait=="" and JSON.parse_string(FileAccess.get_file_as_string("res://data/portrait_presentation.json")).viya.values().all(func(p):return p==""),"Battle-body sprite integration does not fill the separate portrait expressions")
	ui.queue_free();await host.get_tree().process_frame;await host.get_tree().create_timer(.06).timeout
	for file in ["battle.save","gold.cfg","settings.cfg"]:DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
