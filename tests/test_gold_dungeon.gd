extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Wallet=preload("res://scripts/progression/gold_progress.gd")
const Campaign=preload("res://tests/test_campaign.gd")

static func fresh(day: int=20000):
	var state=State.new()
	state.start(2021,"viya",null,"gold_slime","weapons_v1",{},"gold_slime",day)
	return state
static func finish(state) -> Dictionary:
	state.elapsed=179.99
	state.enemies.clear()
	state.spawn_clock=999
	state._scatter_clock=999
	state.step(.02,Vector2.ZERO)
	return state.result_summary()
static func run(host, verify: Callable) -> void:
	var state=fresh()
	verify.call(state.run_mode=="gold_slime" and state.stage_duration==180 and state.stage_clear_gold==0 and state.map_id=="gold_slime" and state.gold_drop_chance==1,"Gold dungeon uses3minute boss-free rules and guaranteed gold in the existing RunState")
	verify.call(state.hp==100 and state.magic.mana==100 and state.stats.speed==235 and state.growth.owned=={"gun_rifle":1} and state.stats.physical_penetration==.15,"Dungeon retains locked hero/account/skill/armor rules")
	var frozen: Dictionary=Campaign.comparable(state)
	verify.call(not state.add_enemy(state.player,"boss") and not state.add_enemy(state.player,"normal","ranged") and not state.add_enemy(state.player,"normal","normal",0,"goblin_raider") and frozen==Campaign.comparable(state),"Dungeon cannot spawn campaign species/ranged/elites/bosses or consume RNG on rejection")
	for wave in range(3):
		state.elapsed=wave*60.0
		state.add_enemy(state.player+Vector2(100,0))
		var actor: Dictionary=state.enemies[-1]
		verify.call(actor.species=="gold_slime" and actor.hp==[20,28,36][wave] and actor.speed==[32,36,40][wave] and actor.contact_damage==6,"Slow slime fixed phase stats/actual actor: "+str(wave))
	state=fresh()
	verify.call(state._spawn_scatter() and state.enemies.size()==30 and state.enemies.all(func(e):return e.species=="gold_slime" and e.scatter_group==1 and not state.visible_world().grow(32).has_point(e.p)),"Whole30slimes spawn offscreen as an added horde")
	state.elapsed=12.0
	state._spawn_scatter()
	verify.call(state.enemies.size()==60 and Snapshot.valid(Snapshot.capture(state),state),"Multiple all-slime horde groups serialize without campaign variant rotation")
	for index in range(10):state._spawn_scatter()
	frozen=Campaign.comparable(state)
	verify.call(state.enemies.size()==360 and not state._spawn_scatter() and frozen==Campaign.comparable(state),"Dungeon horde budget360 rejects a whole pack without partial actors/RNG changes")
	state=fresh()
	state.add_enemy(state.player)
	state._move_enemies(0.0)
	verify.call(state.hp==94,"Actual slime contact removes6HP through existing hit/invulnerability path")
	state=fresh()
	var rolled:=0
	for index in range(100):
		state.add_enemy(state.player+Vector2(50,0))
		state._damage_enemy(int(state.enemies[-1].id),10000)
		var value: int=state.gold_pickups[-1].value
		if value>=10 and value<=50:rolled+=1
	verify.call(state.kills==100 and state.gold_pickups.size()==100 and rolled==100,"Every committed slime kill drops exactly10-50gold with normal XP/kill credit")
	state.gold_collected=17
	var expected:=17
	for pickup in state.gold_pickups:expected+=int(pickup.value)
	var result:=finish(state)
	verify.call(result.outcome=="cleared" and result.elapsed==180 and result.gold_reward==expected and result.gold_bonus==0 and not state._boss_spawned and not state._boss_defeated and state.checkpoint_index==2,"180seconds clears without boss, sweeps only earned gold and awards no campaign bonus")
	verify.call(Snapshot.valid(Snapshot.capture(state),state),"Terminal dungeon snapshot is valid without fabricated boss flags")
	state=fresh()
	state.elapsed=59.99
	state.add_enemy(state.player+Vector2(500,0))
	state.enemies[0].hp=13
	state.spawn_clock=999
	state._scatter_clock=.3
	state.step(.02,Vector2.ZERO)
	state.set_paused(true)
	var copy=State.new()
	var snap: Dictionary=Snapshot.capture(state)
	verify.call(state.checkpoint_index==1 and Snapshot.restore(snap,copy) and copy.enemies[0].hp==13 and copy.enemies[0].max_hp==20 and Campaign.comparable(state)==Campaign.comparable(copy),"One-minute checkpoint retains wounded prior-phase slime and all resources/RNG")
	state.set_paused(false)
	copy.set_paused(false)
	for frame in range(30):
		state.step(.05,Vector2.RIGHT)
		copy.step(.05,Vector2.RIGHT)
	verify.call(Campaign.comparable(state)==Campaign.comparable(copy),"Next horde/movement after checkpoint resume matches uninterrupted play exactly")
	for key in ["mode","day","species","contact","speed","wave","boss","array"]:
		var bad: Dictionary=Snapshot.capture(state)
		match key:
			"mode":bad.run.run_mode="campaign"
			"day":bad.run.dungeon_day=-1
			"species":bad.run.enemies[0].species="goblin_raider"
			"contact":bad.run.enemies[0].contact_damage=20
			"speed":bad.run.enemies[0].speed=235
			"wave":bad.run.enemies[0].spawn_wave=99
			"boss":bad.run._boss_spawned=true
			"array":bad.run.enemy_bullets=17
		frozen=Campaign.comparable(copy)
		verify.call(not Snapshot.restore(bad,copy) and frozen==Campaign.comparable(copy),"Malformed dungeon save rejected before mutation: "+key)
	verify.call(state.request_transition("restart",state.navigation_ticket) and not state.confirm_transition(state.navigation_ticket),"RunState restart cannot bypass account admission")
	account_checks(verify)
	await ui_checks(host,verify)

static func account_checks(verify: Callable) -> void:
	var path: String="user://dungeon-account-"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg"
	var wallet=Wallet.new()
	wallet.path=path
	var now:=20000*86400-32400+100
	verify.call(wallet.load_progress()==OK and wallet.dungeon_remaining(now)==2,"Old/new empty account receives two entries without a reset write")
	var state=fresh()
	var initial: Dictionary=Snapshot.capture(state)
	verify.call(wallet.admit_dungeon(initial,now)==OK and wallet.dungeon_remaining(now)==1 and wallet.dungeon.initial==initial and wallet.next_stage==1 and wallet.total==0,"Admission atomically saves one consumed entry and recoverable initial battle without gold/stage changes")
	var disk=Wallet.new()
	disk.path=path
	verify.call(disk.load_progress()==OK and disk.dungeon==wallet.dungeon,"Account reload retains exact initial snapshot/daily ledger")
	verify.call(wallet.admit_dungeon(Snapshot.capture(fresh()),now)==ERR_UNAVAILABLE and wallet.dungeon.used==1,"Double admission/active entry cannot charge or start a second battle")
	var result:=finish(state)
	result.gold_collected=1234
	result.gold_reward=1234
	var campaign_forgery: Dictionary=result.duplicate(true)
	campaign_forgery.erase("run_mode")
	verify.call(wallet.settle(campaign_forgery)==ERR_INVALID_PARAMETER and wallet.next_stage==1 and wallet.total==0,"Admitted dungeon ID cannot be relabelled as campaign to unlock a stage")
	DirAccess.make_dir_absolute(path+".tmp")
	verify.call(wallet.finish_dungeon(result)!=OK and wallet.total==0 and wallet.dungeon.initial==initial,"Settlement write failure preserves active entry and unpaid balance for retry")
	DirAccess.remove_absolute(path+".tmp")
	verify.call(wallet.finish_dungeon(result)==OK and wallet.total==1234 and wallet.next_stage==1 and wallet.dungeon.initial.is_empty(),"Clear credits earned gold exactly once without advancing campaign")
	verify.call(wallet.settle(result)==OK and wallet.total==1234,"Repeated result settlement is idempotent")
	verify.call(not wallet.dungeon_allows(initial.run) and wallet.settle(campaign_forgery)==ERR_INVALID_PARAMETER and wallet.next_stage==1,"Paid dungeon checkpoints cannot be revived or reclassified for campaign reward")
	var forged: Dictionary=result.duplicate(true)
	forged.gold_reward+=1
	verify.call(wallet.finish_dungeon(forged)!=OK and wallet.total==1234,"Changed reward cannot replay a closed entry")
	verify.call(disk.finish_dungeon(result)==ERR_BUSY and disk.total==0,"Stale account instance cannot overwrite an already settled wallet")
	state=fresh()
	verify.call(wallet.admit_dungeon(Snapshot.capture(state),now)==OK and wallet.dungeon_remaining(now)==0,"Second daily entry is durable")
	state._finish_run("abandoned")
	verify.call(wallet.finish_dungeon(state.result_summary())==OK and wallet.total==1234 and wallet.admit_dungeon(Snapshot.capture(fresh()),now)==ERR_UNAVAILABLE,"Forfeit gives no reward/refund and third entry is rejected")
	verify.call(wallet.dungeon_remaining(20001*86400-32400-1)==0 and wallet.dungeon_remaining(20001*86400-32400)==2,"Daily budget resets at exactly00:00 Korea time")
	state=fresh(20001)
	verify.call(wallet.admit_dungeon(Snapshot.capture(state),20001*86400-32400)==OK and wallet.dungeon_remaining(now)==0,"Stored day high-water prevents backward-clock refill")
	state._finish_run("defeat")
	verify.call(wallet.finish_dungeon(state.result_summary())==OK and wallet.total==1234,"Defeat consumes entry and gives no partial payout")
	var cfg:=ConfigFile.new()
	cfg.load(path)
	cfg.set_value("custom","keep","unrelated")
	cfg.save(path)
	wallet.load_progress()
	state=fresh(20002)
	wallet.admit_dungeon(Snapshot.capture(state),20002*86400-32400)
	cfg.load(path)
	verify.call(cfg.get_value("custom","keep")=="unrelated" and wallet.talent_levels==wallet.Talents.empty_levels(),"Dungeon account commits preserve unknown sections and all existing talents")
	cfg.set_value("gold_dungeon","schema",99)
	cfg.save(path)
	verify.call(disk.load_progress()==ERR_FILE_CORRUPT and not disk.loaded,"Unknown/corrupt dungeon ledger blocks mutation rather than refilling entries")
	var failed=Wallet.new()
	failed.path="user://missing-"+Crypto.new().generate_random_bytes(8).hex_encode()+"/wallet.cfg"
	failed.load_progress()
	verify.call(failed.admit_dungeon(initial,now)!=OK and failed.dungeon==Wallet.empty_dungeon() and failed.total==0,"Failed admission write cannot consume a ticket or credit gold")
	DirAccess.remove_absolute(path)

static func ui_checks(host,verify: Callable) -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	var suffix: String=Crypto.new().generate_random_bytes(8).hex_encode()
	var gold_path: String="user://dungeon-ui-"+suffix+".cfg"
	var run_path: String="user://dungeon-ui-"+suffix+".save"
	scene.gold_progress.path=gold_path
	scene.run_store.path=run_path
	scene.settings_path="user://dungeon-ui-"+suffix+"-settings.cfg"
	host.get_tree().root.add_child(scene)
	scene.set_physics_process(false)
	await host.get_tree().process_frame
	verify.call(is_instance_valid(scene.dungeon_button) and not scene.dungeon_button.disabled,"Actual lobby exposes an enabled dungeon entry")
	scene.dungeon_button.pressed.emit()
	var stale: Callable=scene._launch_gold_dungeon.bind(scene.simulation.navigation_ticket,scene._menu_revision)
	verify.call(scene._modal_kind=="gold_dungeon" and scene.dungeon_launch_button.text.contains("2"),"Dungeon screen shows three-minute rules and remaining entries")
	scene.dungeon_launch_button.pressed.emit()
	verify.call(scene.simulation.run_mode=="gold_slime" and scene.simulation.phase==State.Phase.RUNNING and scene.gold_progress.dungeon.used==1 and scene.run_store.pending.run.run_mode=="gold_slime","Actual launch persists admission and initial battle before play")
	stale.call()
	verify.call(scene.gold_progress.dungeon.used==1,"Delayed/double entry callbacks cannot charge twice")
	scene.simulation.hp=73
	scene.simulation.magic.mana=42.5
	scene.pause_game()
	scene._park_battle()
	verify.call(scene.simulation.phase==State.Phase.READY and scene.dungeon_button.disabled and scene._has_saved_battle(),"Parked dungeon occupies existing saved-battle slot and blocks replacement")
	scene.start_button.pressed.emit()
	verify.call(scene.simulation.phase==State.Phase.PAUSED and scene.simulation.hp==73 and scene.simulation.magic.mana==42.5 and scene.gold_progress.dungeon.used==1,"Lobby Continue restores resources without consuming another entry")
	scene.resume_button.pressed.emit()
	finish(scene.simulation)
	scene._sync_phase_ui()
	verify.call(scene.gold_error==OK and scene.gold_progress.next_stage==1 and scene.result_summary_label.text.contains("기본 보상 0"),"Actual terminal UI settles dungeon and keeps campaign unlock unchanged")
	scene._return_to_lobby(scene.simulation.navigation_ticket,scene._menu_revision)
	verify.call(scene.simulation.phase==State.Phase.READY and scene.dungeon_button.text.contains("1/2"),"Result returns to lobby with one daily entry remaining")
	# Crash between admission commit and first battle-file write: outbox recovery.
	scene.dungeon_button.pressed.emit()
	scene.dungeon_launch_button.pressed.emit()
	var entry_id: String=scene.simulation.run_id
	scene.run_store.discard()
	scene.queue_free()
	await host.get_tree().process_frame
	DirAccess.rename_absolute(gold_path,gold_path+".backup")
	var broken:=ConfigFile.new()
	broken.load(gold_path+".backup")
	broken.set_value("gold_dungeon","schema",99)
	broken.save(gold_path)
	var recovered=load("res://scenes/main.tscn").instantiate()
	recovered.gold_progress.path=gold_path
	recovered.run_store.path=run_path
	recovered.settings_path="user://dungeon-ui-"+suffix+"-settings.cfg"
	host.get_tree().root.add_child(recovered)
	recovered.set_physics_process(false)
	await host.get_tree().process_frame
	verify.call(recovered.gold_error!=OK and not recovered._has_saved_battle(),"Unreadable account blocks admission recovery without resetting ledger")
	DirAccess.rename_absolute(gold_path+".backup",gold_path)
	recovered._retry_gold_load()
	verify.call(recovered.battle_save_error==OK and recovered._has_saved_battle() and recovered.run_store.pending.run.run_id==entry_id and recovered.gold_progress.dungeon.used==2,"Fresh scene recovers admitted initial battle after missing first write with no extra charge")
	recovered.start_button.pressed.emit()
	verify.call(recovered.simulation.phase==State.Phase.PAUSED and recovered.simulation.run_id==entry_id,"Recovered admission is playable through actual guarded Continue")
	recovered._request_transition("leave",recovered.simulation.navigation_ticket,recovered._menu_revision)
	recovered.confirm_button.pressed.emit()
	verify.call(recovered.gold_error==OK and recovered.gold_progress.dungeon.initial.is_empty() and recovered.gold_progress.dungeon_remaining()==0,"Actual confirmed forfeit closes entry without refund")
	recovered.queue_free()
	await host.get_tree().process_frame
	for p in [gold_path,run_path,"user://dungeon-ui-"+suffix+"-settings.cfg"]:DirAccess.remove_absolute(p)
