extends RefCounted
const Feedback=preload("res://scripts/combat/feedback_state.gd")
const Portraits=preload("res://scripts/ui/portrait_assets.gd")
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Supplies=preload("res://tests/test_supplies.gd")
const Campaign=preload("res://tests/test_campaign.gd")

static func texture(color:Color)->GradientTexture2D:
	var result=GradientTexture2D.new();result.width=32;result.height=48
	result.gradient=Gradient.new();result.gradient.colors=PackedColorArray([color,color])
	return result

static func run(host,verify:Callable):
	var f=Feedback.new()
	verify.call(f.snapshot(100,100).expression=="normal","Neutral battle has the normal expression")
	f.trigger("magic")
	verify.call(f.current(100,100)=="magic" and f.snapshot(100,100).expression=="normal","Magic keeps its existing feedback but does not require a fifth portrait")
	f.level_up(1);f.trigger("heal");f.trigger("hurt")
	verify.call(f.snapshot(20,100).expression=="hurt" and f.snapshot(20,100).low_hp,"Pain expression preserves a simultaneous low-HP warning")
	f.advance(.55,true)
	verify.call(f.snapshot(20,100).expression=="heal" and is_equal_approx(f.clocks.heal,1.0),"Covered recovery retains its full visible duration after pain")
	f.advance(1.0,true);f.advance(.90,true)
	verify.call(f.snapshot(100,100).expression=="levelup","Queued original level-up event selects the fourth,joy expression")
	f.advance(1.2,true)
	verify.call(f.snapshot(20,100).expression=="normal" and f.snapshot(20,100).low_hp,"Low HP is an independent warning rather than a fifth expression")
	f.trigger("heal");f.set_persistent_pain(true)
	var clocks:Dictionary=f.clocks.duplicate(true);f.advance(10,true)
	verify.call(f.snapshot(100,100).expression=="hurt" and f.clocks==clocks,"Prepared persistent-ailment hook holds pain and preserves queued reactions")
	f.set_persistent_pain(false)
	verify.call(f.snapshot(100,100).expression=="heal","Clearing persistent pain resumes pending recovery")
	f.finish()
	verify.call(f.snapshot(100,100).key=="defeat" and not f.trigger("heal") and not f.set_persistent_pain(true),"Terminal feedback clears reactions and rejects new portrait events")
	f.reset()
	verify.call(not f.persistent_pain and f.clocks.size()==4 and f.snapshot(100,100).expression=="normal","New run resets all four bounded clocks and persistent presentation flags")
	var state=Supplies.quiet();state.hp=10
	var item:Dictionary=Supplies.drop(state,"hp");item.p=state.player
	state._collect_items(0)
	verify.call(state.hp==40 and state.feedback.current(state.hp,state.max_hp)=="heal" and state.feedback.snapshot(state.hp,state.max_hp).expression=="heal","Actual destroyed HP item heals through the existing path and triggers recovery portrait")
	var frozen:Dictionary=state.feedback.clocks.duplicate(true);state._collect_items(0)
	verify.call(state.feedback.clocks==frozen,"Consumed item cannot refresh the reaction a second time")
	state.set_paused(true);state.step(.05,Vector2.RIGHT)
	verify.call(state.feedback.clocks==frozen,"Pause freezes the four expression clocks")
	state.set_paused(false);state.grant_xp(state.growth.threshold());frozen=state.feedback.clocks.duplicate(true);state.step(.05,Vector2.RIGHT)
	verify.call(state.phase==State.Phase.CHOOSING and state.feedback.clocks==frozen,"Real level choice freezes current and pending expression durations")
	var restored=State.new()
	verify.call(Snapshot.restore(Snapshot.capture(state),restored) and restored.growth.offer==state.growth.offer and restored.feedback.current(restored.hp,restored.max_hp)=="normal","Restore retains exact resources/offer and resets transient portraits without replaying an item")
	state=Supplies.quiet();state.hp=state.max_hp
	item=Supplies.drop(state,"hp");item.p=state.player;state._collect_items(0)
	verify.call(state.hp==state.max_hp and state.feedback.current(state.hp,state.max_hp)=="heal" and state.cues.events[-1].supply.hp==0,"Full-HP item consumption reacts without claiming fictional healing")
	state.feedback.reset();state.hp=10;state._heal_hp(10)
	verify.call(state.hp==20 and state.feedback.snapshot(state.hp,state.max_hp).expression=="normal" and state.feedback.clocks.heal==0,"Ordinary regeneration/heal helpers do not repeatedly trigger item expression")
	state._apply_supply("mp")
	verify.call(state.feedback.snapshot(state.hp,state.max_hp).expression=="normal" and state.feedback.clocks.heal==0,"MP supply cannot masquerade as the HP item expression")
	# No approved character art is generated: temporary flat textures only exercise binding.
	var config:Variant=JSON.parse_string(FileAccess.get_file_as_string(Portraits.PATH))
	verify.call(Portraits.valid_data(config) and config.viya.values().all(func(p):return p==""),"All four shipped portrait paths are intentionally empty")
	for bad_kind in ["missing","type","external","extra"]:
		var bad:Dictionary=config.duplicate(true)
		match bad_kind:
			"missing":bad.viya.erase("hurt")
			"type":bad.viya.heal=15
			"external":bad.viya.normal="https://example.invalid/portrait.png"
			"extra":bad.viya.magic=""
		verify.call(not Portraits.valid_data(bad),"Reject malformed portrait configuration: "+bad_kind)
	var folder:String="res://".path_join(".godot").path_join("portrait-test-"+Crypto.new().generate_random_bytes(8).hex_encode())
	DirAccess.make_dir_recursive_absolute(folder)
	var assets=Portraits.new();var colors:Array=[Color.RED,Color.BLUE,Color.GREEN,Color.YELLOW]
	for index in range(Portraits.EXPRESSIONS.size()):
		var key:String=Portraits.EXPRESSIONS[index]
		var path:String=folder.path_join(key+".tres")
		verify.call(ResourceSaver.save(texture(colors[index]),path)==OK,"Create isolated test texture: "+key)
		assets.definitions[key]=path
		var resolved:Dictionary=assets.resolve(key)
		await host.get_tree().process_frame
		verify.call(resolved.exact and resolved.texture.get_image().get_pixel(0,0).is_equal_approx(colors[index]),"Independent portrait texture binds to expression: "+key)
	verify.call(assets._loaded.size()==4 and is_same(assets.resolve("hurt").texture,assets.resolve("hurt").texture),"Portrait resources are cached instead of loaded each frame")
	assets.definitions.heal=folder.path_join("missing.tres")
	verify.call(not assets.resolve("heal").exact and assets.resolve("heal").texture.get_image().get_pixel(0,0).is_equal_approx(Color.RED),"Missing expression art safely falls back to configured normal portrait")
	var frames=SpriteFrames.new();frames.add_animation("hurt");frames.add_frame("hurt",texture(Color.MAGENTA))
	var shared:String=folder.path_join("shared.tres");ResourceSaver.save(frames,shared)
	assets.definitions.hurt="";assets.legacy.definitions.viya_portrait=shared
	var shared_portrait:Dictionary=assets.resolve("hurt")
	await host.get_tree().process_frame
	verify.call(shared_portrait.exact and shared_portrait.texture.get_image().get_pixel(0,0).is_equal_approx(Color.MAGENTA),"Existing shared SpriteFrames expression remains compatible")
	var panel=preload("res://scripts/ui/responsive_feedback_panel.gd").new()
	host.add_child(panel);panel.size=Vector2(110,110);panel.portrait_assets=assets
	state.feedback.reset();state.feedback.trigger("hurt");panel.present(state.feedback.snapshot(state.hp,state.max_hp))
	verify.call(panel.expression_key=="hurt" and panel.expression_has_art and panel.portrait.visible and panel.portrait.modulate.a==1,"Existing combat portrait area presents the selected art at full opacity")
	panel.fit_compact(true)
	verify.call(not panel.context_text.visible and panel.portrait.mouse_filter==Control.MOUSE_FILTER_IGNORE and panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Compact image/caption layout preserves touch pass-through")
	var gameplay:Dictionary=Campaign.comparable(state);var reactions:Dictionary=state.feedback.clocks.duplicate(true)
	for index in range(20):panel.present(state.feedback.snapshot(state.hp,state.max_hp))
	verify.call(Campaign.comparable(state)==gameplay and state.feedback.clocks==reactions,"Portrait presentation is read-only for resources,clocks,input ownership and seven RNG")
	panel.queue_free();await host.get_tree().process_frame
	for path in DirAccess.get_files_at(folder):DirAccess.remove_absolute(folder.path_join(path))
	DirAccess.remove_absolute(folder)
