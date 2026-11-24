extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const PressureChecks=preload("res://tests/test_campaign_pressure.gd")
const ChestChecks=preload("res://tests/test_campaign_encounters.gd")
const MANIFEST:="res://tests/fixtures/game049_v20/baseline.json"
static func fresh():
	var state=State.new()
	state.start(4901,"viya",null,"siege_battlefield","weapons_v1",{},"campaign",-1,-1,-1,2)
	return state
static func run(host,verify:Callable):
	var state=fresh()
	verify.call(state.phase==State.Phase.RUNNING and state.world_size==Vector2(5000,3200) and state.encounter_version==2,"Stage field starts in the existing sole RunState with pressure2")
	verify.call(state.stage_catalog.for_departure(1).map_id=="siege_battlefield" and state.stage_catalog.for_stage(1).map_id=="prologue_wall" and state.stage_catalog.for_departure(2).map_id=="outskirts_trial","Fresh stage1 is separated from unchanged prologue/old rules and stage2")
	var original=State.new()
	verify.call(original.start(4901,"viya",null,"prologue_wall","weapons_v1",{},"campaign",-1,-1,-1,2) and original.map_space.solids.size()==4,"Explicit prologue retains its original four collision objects")
	verify.call(state.map_space.solids.size()==20 and state.structures.size()==32 and original.structures.size()==32,"Facilities and disconnected barricades use real collision, with the original32 destructibles")
	var preserved:=true
	for index in range(32):
		for key in ["id","style","hp","max_hp"]:preserved=preserved and state.structures[index][key]==original.structures[index][key]
		preserved=preserved and state.map_space.valid_position(state.structures[index].p,24)
	verify.call(preserved,"Supply relocation preserves IDs/styles/HP/order and keeps every pickup site outside walls")
	verify.call(state.profiles.data.maps.siege_battlefield==original.profiles.data.maps.prologue_wall,"Locked species pools and stats are reused without balance changes")
	var space=state.map_space
	for route in space.definition.routes:
		var at:=Vector2(route.points[0][0],route.points[0][1])
		var clear:bool=space.valid_position(at,130)
		for next in route.points.slice(1):
			var goal:=Vector2(next[0],next[1])
			while at.distance_to(goal)>.01:
				var movement:=at.direction_to(goal)*minf(12,at.distance_to(goal))
				var moved:Vector2=space.move(at,movement,130)
				if moved.distance_to(at)<.001:clear=false;break
				at=moved
				clear=clear and space.valid_position(at,129.99)
			if not clear:break
		verify.call(clear,"Actual swept collision traverses the full260wide route:"+str(route.id))
	for pocket in space.definition.formation_pockets:
		verify.call(space.valid_position(Vector2(pocket.p[0],pocket.p[1]),297.095),"Full30formation footprint fits deployment pocket:"+str(pocket.id))
	var successes:=0
	for time in [0.0,121.0,241.0]:
		for position in [Vector2(2500,600),Vector2(650,1540),Vector2(4450,1560),Vector2(2500,2820)]:
			state=fresh();state.elapsed=time;state.player=position
			var at:Variant=state.pressure.anchor(state,"normal")
			verify.call(at is Vector2 and state.map_space.valid_position(at,24) and not state.visible_world().grow(56).has_point(at),"Actual pressure entry stays offscreen and outside new walls:"+str(time)+str(position))
			var formed:bool=state._spawn_map_formation("normal",6,80,12,state.scatter_rng,true)
			verify.call(state.enemies.size()==(30 if formed else 0) and state.enemies.all(func(e):return state.map_space.valid_position(e.p,24)),"Map formations commit all30 valid actors or none")
			if formed:successes+=1
	verify.call(successes>=3,"Thirty-actor formations still enter through multiple places/times around the new structures")
	# Exact old published20 payloads and subsequent behavior, not recaptured fixtures.
	var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	verify.call(Snapshot.VERSION==22 and Snapshot.fingerprint_for_v20()==baseline.fingerprint20,"Schema21 keeps the exact published20 fingerprint")
	for row in baseline.records:
		var data:Dictionary=FileAccess.open(MANIFEST.get_base_dir().path_join("old_"+row.tag+".bin"),FileAccess.READ).get_var(false)
		var old=State.new()
		var restored:bool=Snapshot.restore(data,old)
		verify.call(restored and old.map_id==data.run.map_id and old.structures==data.run.structures and old.encounter_version==data.run.encounter_version,"Old20 keeps map/structures/chest and population policy:"+row.tag)
		if not restored:continue
		old.set_paused(false)
		var same:bool=PressureChecks.digest(old)==row.hashes101[0]
		for index in range(100):old.step(.05,Vector2.ZERO);same=same and PressureChecks.digest(old)==row.hashes101[index+1]
		verify.call(same,"All101authority/sevenRNG hashes from published20 remain exact:"+row.tag)
	state=fresh();ChestChecks.equip(state);ChestChecks.drop(state,3)
	state._damage_structure(int(state.structures[0].id),1000)
	state.set_paused(true)
	var saved:Dictionary=Snapshot.capture(state)
	var restored=fresh()
	verify.call(Snapshot.valid(saved,state) and Snapshot.restore(saved,restored) and Campaign.comparable(state)==Campaign.comparable(restored),"New battlefield restores spent MP/HP/skills,unclaimed chest,items and broken supplies without moving/resetting them")
	state.set_paused(false);restored.set_paused(false)
	var equal:=true
	var active:=0
	for index in range(100):
		if state.phase==State.Phase.CHOOSING:
			var id:String=state.growth.offer[0]
			state.select_skill(id,state.growth.ticket);restored.select_skill(id,restored.growth.ticket)
		if state.phase==State.Phase.RUNNING:active+=1
		state.step(.05,Vector2.ZERO);restored.step(.05,Vector2.ZERO)
		equal=equal and Campaign.comparable(state)==Campaign.comparable(restored)
	verify.call(equal and active==100,"Resumed stage matches100actual combat steps/sevenRNG without duplicate drops or upgrades")
	var malformed:Dictionary=saved.duplicate(true)
	malformed.version=20;malformed.rules=Snapshot.GAME048_RULES
	verify.call(not Snapshot.restore(malformed,restored),"An old schema cannot forge a new battlefield map")
	malformed.version=20.0
	verify.call(not Snapshot.restore(malformed,restored),"A floating old version cannot bypass new-map isolation")
	malformed=saved.duplicate(true);malformed.run.structures[0].p=Vector2(800,1000)
	verify.call(not Snapshot.restore(malformed,restored),"Moved/buried saved supplies are rejected without resetting the existing state")
