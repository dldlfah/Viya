extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
static func fresh(mode:String="campaign"):
	var state=State.new()
	state.start(2201,"viya",null,"gold_slime" if mode=="gold_slime" else "legacy_arena","weapons_v1",{},mode,20000 if mode=="gold_slime" else -1)
	return state
static func run(host,verify:Callable)->void:
	var state=fresh()
	verify.call(state.growth.pacing_version==1 and state.growth.pacing_mode=="campaign" and not state.growth.pacing.data.is_empty(),"Production weapons sortie uses versioned campaign pacing data")
	var costs:=[30,48,66,84,156,240,360,510,690,900,1140,2400,3600]
	for level in range(1,costs.size()+1):
		verify.call(state.growth.threshold_for(level,"campaign",1)==costs[level-1],"Actual campaign XP requirement level"+str(level))
	verify.call(state.growth.threshold_for(5,"gold_slime",1)==480 and state.growth.threshold_for(9,"gold_slime",1)==2610 and state.growth.threshold_for(14,"campaign",1)==5400,"Dungeon and later-level costs are separate,finite and increasing")
	verify.call(state.growth.XP_REQUIREMENT_MULTIPLIER==3 and state.hp==100 and state.magic.mana==100 and state.stats.physical_penetration==.15,"Pacing preserves XP3x and locked hero/penetration stats")
	state.add_pickup(state.player)
	verify.call(state.pickups[0].value==5,"Unmodified normal XP pickup remains5")
	state.grant_xp(4224)
	verify.call(state.growth.level==12 and state.growth.pending==11 and state.growth.xp==0 and state.growth.owned=={"gun_rifle":1},"4224actual XP funds11choices without auto-granted ranks")
	state=fresh("gold_slime")
	state.grant_xp(4740)
	verify.call(state.growth.level==9 and state.growth.pending==8 and state.growth.xp==0,"Gold dungeon4740XP funds8choices under its own curve")
	state=fresh()
	state.growth.owned={"gun_rifle":4,"gun_grenade":1,"passive_power":1}
	state.growth.level=10
	state.growth.pending=1
	state._begin_choice_if_needed()
	var focused:Dictionary=Snapshot.capture(state)
	verify.call(state.growth.offer.has("gun_rifle") and state.growth.offer.size()==3 and state.growth.owned.gun_rifle==4,"At least one owned attack upgrade is offered;rank is unchanged until selection")
	var ids:={}
	for id in state.growth.offer:ids[id]=true
	verify.call(ids.size()==3 and state.growth.pool.size()==18,"Focused offer retains18candidate pool and3unique choices")
	var legacy=fresh()
	legacy.growth.owned=state.growth.owned.duplicate(true)
	legacy.growth.level=10
	legacy.growth.pending=1
	legacy.growth.pacing_version=0
	legacy._begin_choice_if_needed()
	verify.call(legacy.growth.rng.state==state.growth.rng.state,"Owned-upgrade inclusion consumes exactly the original shuffle RNG,not extra rerolls")
	var copy=State.new()
	verify.call(Snapshot.restore(focused,copy) and copy.growth.offer==state.growth.offer and copy.growth.pacing_version==1 and copy.growth.pacing_mode=="campaign","Focused pending offer/pacing survive exact snapshot restoration")
	copy.set_paused(false)
	var ticket:int=copy.growth.ticket
	verify.call(copy.select_skill("gun_rifle",ticket) and copy.growth.owned.gun_rifle==5 and not copy.select_skill("gun_rifle",ticket),"Choosing the rank4upgrade reaches actual Lv5 once;stale callback cannot buy twice")
	for mutation in ["version","legacy","missing"]:
		var bad:Dictionary=focused.duplicate(true)
		if mutation=="version":bad.growth.pacing_version=2
		elif mutation=="legacy":bad.growth.ruleset="legacy"
		else:bad.growth.erase("pacing_version")
		var frozen:Dictionary=Campaign.comparable(copy)
		verify.call(not Snapshot.restore(bad,copy) and frozen==Campaign.comparable(copy),"Invalid pacing snapshot fails before mutation: "+mutation)
	var bad_data:Dictionary=state.growth.pacing.data.duplicate(true)
	bad_data.profiles.campaign.base_requirements[2]=1
	verify.call(not state.growth.pacing.valid(bad_data),"Non-increasing XP data is rejected")
	bad_data=state.growth.pacing.data.duplicate(true)
	bad_data.profiles.gold_slime.base_requirements[0]=NAN
	verify.call(not state.growth.pacing.valid(bad_data),"Non-finite XP data is rejected")
	state=fresh("gold_slime")
	state.growth.pacing_version=0
	state.hp=61
	state.magic.mana=33.25
	state.grant_xp(1320)
	var old:Dictionary=Snapshot.capture(state)
	old.version=13
	old.rules=Snapshot.GAME021_RULES
	old.growth.erase("pacing_version")
	verify.call(Snapshot.restore(old,copy) and copy.growth.pacing_version==0 and copy.growth.pacing_mode=="gold_slime" and copy.growth.offer==state.growth.offer and copy.hp==61 and copy.magic.mana==33.25,"Published13 dungeon retains old curve/offers/resources while upgrading storage only")
	verify.call(copy.growth.threshold()==228 and copy.growth.level==12 and copy.growth.pending==11,"Continued old dungeon retains its old next-level threshold and queued choices")
	verify.call(state.growth.threshold_for(5,"campaign",0)==102 and state.growth.threshold_for(5,"gold_slime",0)==102,"Old campaign and dungeon use the exact published linear formula")
	for version in [0,1]:
		state=fresh()
		state.growth.pacing_version=version
		state.request_transition("restart",state.navigation_ticket)
		verify.call(state.confirm_transition(state.navigation_ticket) and state.growth.pacing_version==version,"Confirmed campaign restart retains its saved pacing version"+str(version))
	target_checks(verify)
	# Existing scene,not another product/project; use its actual departure flow.
	host.begin_run()
	verify.call(host.simulation.growth.pacing_version==1,"Existing production scene departures select the new growth version")
	var unchanged:Dictionary=Campaign.comparable(host.simulation)
	host.view.queue_redraw()
	await host.get_tree().process_frame
	verify.call(unchanged==Campaign.comparable(host.simulation),"Growth hint/rendering cannot spend XP,change offers or consume RNG")
static func target_checks(verify:Callable)->void:
	for version in [0,1]:
		var state=fresh()
		state.growth.pacing_version=version
		state.add_enemy(state.player+Vector2(120,70))
		state.add_enemy(state.player+Vector2(300,0),"boss")
		state._auto_fire()
		var desired:=Vector2.RIGHT if version==1 else Vector2(120,70).normalized()
		verify.call(not state.bullets.is_empty() and state.bullets[0].direction.is_equal_approx(desired),"Actual starter gun targeting preserves old policy/selects in-range boss for pacing"+str(version))
	var state=fresh()
	state.add_enemy(state.player+Vector2(120,70))
	state.add_enemy(state.player+Vector2(700,0),"boss")
	state._auto_fire()
	verify.call(state.bullets[0].direction.is_equal_approx(Vector2(120,70).normalized()),"Out-of-range boss does not steal a valid nearby target")
