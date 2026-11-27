extends RefCounted
const Slots=preload("res://scripts/ui/asset_slots.gd")
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Scenery=preload("res://scripts/combat/oblique_scenery.gd")
const MANIFEST:="res://assets/characters/pilot_32/source_manifest.json"
const SOURCE_RESOURCE:="res://assets/characters/pilot_32/resources/viya_directional_motion.tres"
const RESOURCE:="res://assets/characters/pilot_32/game067_se_run_fire/viya_game067_frames.tres"
const CACHE=preload("res://assets/characters/pilot_32/render_cache/viya_render_frames.tres")
const EAST_TIMING:="res://assets/characters/pilot_32/game064_e_run/provenance/frame_timing.csv"
const SE_FIRST="res://assets/characters/pilot_32/game066_se_run/frames/viya_run_se_000.png"
const EAST_FIRST:="res://assets/characters/pilot_32/game064_e_run/frames/viya_run_e_000.png"
const EAST_MANIFEST:="res://assets/characters/pilot_32/game064_e_run/provenance/asset_manifest.json"
const DIRECTIONS:=["e","se","s","sw","w","nw","n","ne"]

static func east_timing() -> Array:
	var rows:Array=[]
	var input:FileAccess=FileAccess.open(EAST_TIMING,FileAccess.READ)
	if input==null:return rows
	if input.get_csv_line()!=PackedStringArray(["frame","filename","source_frame","source_time_ms","start_ms","duration_ms","classification"]):return rows
	while not input.eof_reached():
		var cells:PackedStringArray=input.get_csv_line()
		if cells.size()==1 and cells[0].is_empty():continue
		if cells.size()!=7:return []
		rows.append({"index":int(cells[0]),"filename":cells[1],"source_index":int(cells[2]),"start_ms":float(cells[4]),"duration_ms":float(cells[5])})
	input.close()
	return rows

static func run(host,verify:Callable) -> void:
	var slots=Slots.new()
	var asset:Resource=slots.resource("viya_battle")
	verify.call(slots.definitions.viya_battle==RESOURCE and asset is SpriteFrames and is_same(asset,slots.resource("viya_battle")),"GAME065 E moving-fire derivative uses the existing Viya slot and a cached composite SpriteFrames resource")
	if not asset is SpriteFrames:return
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var exact:bool=FileAccess.get_sha256(SOURCE_RESOURCE)==manifest.source_package.resource_original_sha256
	for entry in manifest.runtime_files:exact=exact and FileAccess.get_sha256(MANIFEST.get_base_dir().path_join(entry.path))==entry.sha256
	verify.call(exact and manifest.runtime_files.size()==208,"Every shipped PNG and the relative-path resource match the supplied package bytes")
	verify.call(asset.get_animation_names().size()==34 and asset.has_animation("run_fire_e") and not asset.has_animation("default") and not asset.has_animation("idle"),"The32preserved directional states and one E moving-fire clip are shipped without a generic or mirrored replacement")
	var timing:Array=east_timing()
	var derivative:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(EAST_MANIFEST))
	var checks:Array=derivative.get("bitmap_checks",[])
	verify.call(timing.size()==47 and checks.size()==47,"The independent production CSV and bitmap provenance each contain47distinct E phases")
	if timing.size()!=47 or checks.size()!=47:return
	var end_ms:=0.0
	var east_valid:=true
	var unequal:=false
	var hashes:Dictionary={}
	for index in range(timing.size()):
		var row:Dictionary=timing[index]
		var expected_path:String=EAST_FIRST.get_base_dir().path_join("viya_run_e_%03d.png" % index)
		var digest:String=FileAccess.get_sha256(expected_path)
		east_valid=east_valid and row.index==index and row.source_index==index*2 and row.filename==expected_path.get_file() and is_finite(row.duration_ms) and row.duration_ms>0 and absf(row.start_ms-end_ms)<.000001
		east_valid=east_valid and int(checks[index].index)==index and digest==str(checks[index].sha256)
		unequal=unequal or not is_equal_approx(row.duration_ms,timing[0].duration_ms)
		hashes[digest]=true
		end_ms+=row.duration_ms
	verify.call(east_valid and unequal and absf(end_ms-660.0)<.000001 and hashes.size()==47,"E preserves47unique derivative PNGs and the authored unequal660ms timing without an endpoint duplicate")
	var total:=0
	var preserved:=true
	var preserved_count:=0
	for pose in ["idle","run","attack","hurt"]:
		var valid:=true
		var expected:int={"idle":1,"run":11,"attack":8,"hurt":6}[pose]
		var fps:float={"idle":1.0,"run":16.6666666667,"attack":50.0,"hurt":50.0}[pose]
		for direction in DIRECTIONS:
			var name:String=pose+"_"+direction
			var east:bool=name=="run_e"
			var southeast:bool=name=="run_se"
			valid=valid and asset.has_animation(name) and asset.get_frame_count(name)==(47 if east else (18 if southeast else expected)) and is_equal_approx(asset.get_animation_speed(name),47.0/.66 if east else (18.0/.66 if southeast else fps)) and asset.get_animation_loop(name)==(pose in ["idle","run"])
			for index in range(asset.get_frame_count(name)):
				total+=1
				var texture:Texture2D=asset.get_frame_texture(name,index)
				valid=valid and texture.get_size()==Vector2(200,248)
				if east:
					if index>=timing.size():
						valid=false
						continue
					valid=valid and texture.resource_path==EAST_FIRST.get_base_dir().path_join(timing[index].filename) and is_equal_approx(asset.get_frame_duration(name,index),timing[index].duration_ms*47.0/660.0)
				elif southeast:
					valid=valid and texture.resource_path==SE_FIRST.get_base_dir().path_join("viya_run_se_%03d.png" % index) and asset.get_frame_duration(name,index)==1.0
				else:
					valid=valid and asset.get_frame_duration(name,index)==1.0
					preserved=preserved and is_same(texture,CACHE.get_frame_texture(name,index)) and asset.get_frame_duration(name,index)==CACHE.get_frame_duration(name,index) and asset.get_animation_speed(name)==CACHE.get_animation_speed(name) and asset.get_animation_loop(name)==CACHE.get_animation_loop(name)
					preserved_count+=1
		verify.call(valid,"Directional count/timing/loop/canvas match the native poses plus the authored E47 exception for:"+pose)
	verify.call(total==251 and preserved and preserved_count==186,"Only E run and SE run change:186previous native display frames preserve resources and timings within251 directional frames")
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
			resolved=resolved and not sample.is_empty() and sample.animation==pose+"_"+direction and sample["size"]==Vector2(69,85.56) and sample.pivot==Vector2(.5,1)
	verify.call(resolved,"Existing adapter resolves all32poses upright at69x85.56 with the original bottom pivot")
	for viewport in [Vector2(1280,526),Vector2(960,396),Vector2(797,266),Vector2(3840,1700)]:
		var fits:=true
		var foot:=Vector2(390,210)
		for direction in DIRECTIONS:
			for pose in ["idle","run","attack","hurt"]:
				var sample:Dictionary=ui.view.actor_art.frame(ui.view.art,["viya_battle"],pose,direction,.07,viewport)
				var rect:Rect2=ui.view.actor_art.rectangle(sample,foot)
				fits=fits and rect.end.y==foot.y and is_equal_approx(rect.get_center().x,foot.x) and is_equal_approx(rect.size.x/rect.size.y,200.0/248.0) and rect.size.x<=200 and rect.size.y<=248
				fits=fits and is_equal_approx(rect.size.y,85.56)
		verify.call(fits,"All32frames keep source aspect/foot anchoring and a fixed world size independent of viewport height:"+str(viewport))
	ui.view.art.definitions.normal=RESOURCE
	var enemy_sample:Dictionary=ui.view.actor_art.frame(ui.view.art,["normal"],"idle","e",0,Vector2(3840,1700))
	verify.call(enemy_sample["size"]==Vector2(32,40),"Hero presentation enlargement cannot resize another actor that reuses the same texture resource")
	ui.view.art.definitions.normal=""
	for invalid in [0,NAN,"bad"]:
		ui.view.actor_art.specs.actors.viya_battle.reference_view_height=invalid
		verify.call(ui.view.actor_art.frame(ui.view.art,["viya_battle"],"idle","e",0,Vector2(1280,526)).is_empty(),"Invalid responsive size metadata falls back without NaN geometry:"+str(invalid))
	ui.view.actor_art.specs.actors.viya_battle.erase("reference_view_height")
	var side_feet:=Vector2(120,0)
	var shape:Dictionary=Scenery.geometry(Rect2(0,0,100,20),200,Transform2D.IDENTITY)
	var body:=Rect2(side_feet-Vector2(34.5,85.56),Vector2(69,85.56))
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
	verify.call(state.shots>0 and ui.view.actors.pose(state).pose=="attack" and ui.view.actor_visual().sample.animation=="attack_ne" and ui.view.actor_visual().recoil==0,"A committed stationary shot uses the original whole-body attack without mesh deformation; firing cadence stays owned by RunState")
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
