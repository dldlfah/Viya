extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const Space=preload("res://scripts/world/map_space.gd")
const Reference=preload("res://tests/fixtures/game050_v21/map_space_before.gd")
const Index=preload("res://scripts/combat/spatial_candidates.gd")
const FIXED_FLIER_FINAL="7450ea3a8ce3b39b7d5108a220e7c8f4f65051c368f99e0cb51b14b9160e02ad"
const MANIFEST:="res://tests/fixtures/game050_v21/baseline.json"
static func digest(state)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	var data:Dictionary=Campaign.comparable(state)
	data.version=21;data.rules=Snapshot.fingerprint_for_v21();data.run.erase("loot_rules_version")
	hash.update(var_to_bytes(data))
	return hash.finish().hex_encode()
static func run(host,verify:Callable):
	var catalog=preload("res://scripts/world/map_catalog.gd").new()
	var random:=RandomNumberGenerator.new();random.seed=5001
	for id in ["siege_battlefield","prologue_wall","outskirts_trial","legacy_arena"]:
		var data:Dictionary=catalog.definition(id)
		var fast=Space.new(data);var before=Reference.new(data)
		var equal:=true
		for sample in range(250):
			var a:=Vector2(random.randf_range(-100,fast.world_size.x+100),random.randf_range(-100,fast.world_size.y+100))
			var b:=Vector2(random.randf_range(-100,fast.world_size.x+100),random.randf_range(-100,fast.world_size.y+100))
			var radius:float=[0.0,4.0,24.0,297.095][sample%4]
			equal=equal and fast.wall_fraction(a,b,radius)==before.wall_fraction(a,b,radius)
		verify.call(equal,"All250 swept-wall fractions retain the exact original float results:"+id)
		equal=true
		for box in before.solids:
			for at in [box.position,box.end,Vector2(box.end.x,box.position.y),box.get_center()]:
				for offset in [Vector2.ZERO,Vector2(.0001,0),Vector2(0,-.0001),Vector2(100,100)]:
					equal=equal and fast.wall_fraction(at,at+offset,0)==before.wall_fraction(at,at+offset,0)
		verify.call(equal,"Starts inside/on corners,zero-length and grazing segments preserve published wall behavior:"+id)
		equal=true
		var goal:Vector2=fast.start
		for sample in range(40):
			var at:=Vector2(random.randf_range(40,fast.world_size.x-40),random.randf_range(460,fast.world_size.y-40))
			if not fast.valid_position(at,24):continue
			equal=equal and fast.route_target(at,goal,24)==before.route_target(at,goal,24)
			equal=equal and fast.move(at,Vector2(700,-400),24)==before.move(at,Vector2(700,-400),24)
		verify.call(equal,"Ranked visibility candidates and cached wall sweeps preserve route ties and movement:"+id)
		for radius in range(40):fast.wall_fraction(Vector2.ZERO,goal,float(radius))
		verify.call(fast._wall_cache.size()<=Space.MAX_WALL_RADII,"Derived wall-radius cache stays bounded:"+id)
		fast.solids.clear();fast.solids.append(Rect2(goal+Vector2(60,-40),Vector2(20,80)))
		var fresh=Reference.new(data);fresh.solids.assign(fast.solids)
		verify.call(fast.wall_fraction(goal,goal+Vector2(200,0),4)==fresh.wall_fraction(goal,goal+Vector2(200,0),4) and fast.route_target(goal,goal+Vector2(200,0),24)==fresh.route_target(goal,goal+Vector2(200,0),24),"Diagnostic geometry changes invalidate walls and route graph together:"+id)
	var index=Index.new()
	var actors:Array[Dictionary]=[]
	for value in range(200):actors.append({"id":value+1,"hp":10,"p":Vector2((value%20-10)*32,(int(value/20)-5)*32),"variant":"normal"})
	verify.call(index.build([actors]),"Temporary spatial index accepts unique live actors")
	var candidates:Array=index.segment(Vector2(-128,0),Vector2(128,0),24)
	var hits:Array=actors.filter(func(a):return Geometry2D.get_closest_point_to_segment(a.p,Vector2(-128,0),Vector2(128,0)).distance_to(a.p)<=24)
	verify.call(hits.all(func(a):return candidates.has(a)),"Broadphase includes every exact swept hit at cell boundaries")
	var ordered:Array=candidates.map(func(a):return a.id);var sorted:Array=ordered.duplicate();sorted.sort()
	verify.call(ordered==sorted,"Candidate order preserves original actor order for equal hits and RNG")
	actors[0].p=Vector2.ZERO;index.moved(actors[0]);actors[1].hp=0
	verify.call(index.segment(Vector2.ZERO,Vector2.ZERO,0).has(actors[0]) and not index.segment(Vector2(-1000,0),Vector2(1000,0),1000).has(actors[1]),"Immediate knockback rebucketing and committed deaths affect the next query")
	verify.call(not index.build([actors,[actors[0]]]),"Duplicate diagnostic IDs fall back to the original scan")
	var motion_state=State.new();motion_state.start(5001)
	motion_state.add_enemy(motion_state.player+Vector2(70,0))
	motion_state.add_enemy(motion_state.player+Vector2(700,200))
	motion_state.add_enemy(motion_state.player+Vector2(700,300),"elite")
	var motion=preload("res://scripts/combat/actor_motion.gd").new()
	var full=preload("res://scripts/combat/actor_motion.gd").new()
	var region:=Rect2(motion_state.player-Vector2.ONE*128,Vector2.ONE*256)
	motion.prepare(motion_state,true,region);full.prepare(motion_state)
	motion_state.elapsed=.05;motion_state.enemies[0].p+=Vector2(2,0)
	motion.sync(motion_state,Vector2.ZERO,true,true,region);full.sync(motion_state,Vector2.ZERO,true)
	verify.call(motion.entries.size()==3 and full.entries.size()==4,"Animation observer tracks hero/nearby ordinary/remote elite without updating hidden ordinary actors")
	verify.call(motion.pose(motion_state,1)==full.pose(motion_state,1) and motion.pose(motion_state,3)==full.pose(motion_state,3),"Visible and important enemy animation samples retain their poses and clocks")
	motion_state.enemies[1].p=motion_state.player+Vector2(80,0);motion.prepare(motion_state,true,region)
	motion_state.elapsed=.10;motion_state.enemies[1].p+=Vector2(2,0);motion.sync(motion_state,Vector2.ZERO,true,true,region)
	verify.call(motion.entries.has(2) and motion.pose(motion_state,2).moving,"Entering the visibility margin initializes actual movement before rendering")
	var frozen_pose:Dictionary=motion.pose(motion_state,1)
	motion.sync(motion_state,Vector2.ZERO,false,true,region)
	verify.call(motion.pose(motion_state,1)==frozen_pose,"Paused observers retain the same animation clock")
	motion_state.enemies[0].p+=Vector2(900,0);motion_state.elapsed=.15;motion.sync(motion_state,Vector2.ZERO,true,true,region)
	verify.call(not motion.entries.has(1) and motion.entries.has(3),"Offscreen ordinary observations are released while remote elite tells remain tracked")
	# Real captures and all subsequent authority/RNG hashes from GAME049 code.
	var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	verify.call(Snapshot.VERSION==22 and Snapshot.fingerprint_for_v21()==baseline.fingerprint21,"Save22 retains the exact published21 gameplay fingerprint")
	for row in baseline.records:
		var state=State.new()
		var data:Dictionary=FileAccess.open(MANIFEST.get_base_dir().path_join(row.tag+".bin"),FileAccess.READ).get_var(false)
		var loaded:bool=Snapshot.restore(data,state)
		verify.call(loaded and state.enemies.size()==row.actors,"Restore original dense fixture without population/resource changes:"+row.tag)
		if not loaded:continue
		state.set_paused(false) # Explicit Continue is required by the original reader.
		var actions:Array=FileAccess.open(MANIFEST.get_base_dir().path_join(row.tag+"_actions.bin"),FileAccess.READ).get_var(false)
		# Preserve the published manifest. Only its known broken final fly sample
		# changes:187expired fliers retire without167ground ghost pushes and
		# heavy1076 takes the resulting13damage. All
		# other fields/RNG are proven in
		# test_flier_expiry against the frozen original lifetime implementation.
		var expected:Array=row.hashes101.duplicate()
		var expected_valid:bool=row.final_valid
		if row.tag=="fly1540":
			expected[100]=FIXED_FLIER_FINAL
			expected_valid=true
		var same:bool=digest(state)==expected[0]
		var cleared:=true
		for step in range(actions.size()):
			var action:Dictionary=actions[step]
			if not action.skill.is_empty():state.select_skill(action.skill,state.growth.ticket)
			if action.cast:state.cast_ultimate(state.magic.ticket)
			state.step(.05,action.move)
			same=same and digest(state)==expected[step+1]
			cleared=cleared and state._bullet_candidates==null and state._push_candidates==null
		verify.call(same,"All101 dense hashes retain the exact published behavior except the reviewed final flier-expiry correction:"+row.tag)
		verify.call(cleared and Snapshot.valid(Snapshot.capture(state),state)==expected_valid,"Transient indices clear and strict saves pass including the corrected flier-expiry endpoint:"+row.tag)
