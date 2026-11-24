extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Audio=preload("res://scripts/combat/combat_audio.gd")
const Bank=preload("res://scripts/combat/combat_audio_bank.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")

static func quiet(seed_value:int=3101):
	var state=State.new()
	state.start(seed_value,"viya",null,"prologue_wall","weapons_v1")
	state.player=Vector2(2500,1700)
	state.spawn_clock=999
	state.shot_clock=999
	state._scatter_clock=999
	state._swarm_clock=999
	return state

static func count(audio,kind:String) -> int:
	return int(audio.played.get(kind,0))

static func run(host,verify:Callable)->void:
	var original_db:float=AudioServer.get_bus_volume_db(0)
	var original_mute:bool=AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0,false)
	var state=quiet()
	var saved:Dictionary=Snapshot.capture(state)
	var valid:=true
	for kind in Bank.SPECS:
		var stream:AudioStreamWAV=Bank.stream(kind)
		valid=valid and stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate==22050 and not stream.stereo
		var peak:=0
		for index in range(0,stream.data.size(),2):peak=maxi(peak,absi(stream.data.decode_s16(index)))
		valid=valid and peak>1000 and peak<=5900 and stream.data.decode_s16(0)==0 and stream.data.decode_s16(stream.data.size()-2)==0
	verify.call(valid and Bank.cache.size()==9,"Nine cached16bit PCM placeholders have audible nonzero data,bounded peaks and zero endpoints")
	verify.call(is_same(Bank.stream("fire"),Bank.stream("fire")) and Snapshot.capture(state)==saved,"PCM caching allocates no repeated stream and touches no gameplay/RNG")
	var audio=Audio.new()
	host.get_tree().root.add_child(audio)
	verify.call(audio.voices.size()==6 and audio.get_child_count()==6 and audio.voices.all(func(v):return v.player.bus=="Master"),"One adapter owns six shared Master-bus players rather than per-enemy audio nodes")
	# Direct pool stress is an explicit playback fixture,not a combat trigger.
	for index in range(6):audio._play("magic",index*.5)
	verify.call(audio.active_count()<=6 and not audio._play("pickup",10),"Low-priority pickup cannot evict a pool of higher-priority magic")
	verify.call(audio._play("defeat",10) and audio.voices.any(func(v):return v.kind=="defeat") and audio.active_count()<=6,"A result sound preempts lower-priority audio within the same six voices")
	audio.stop_all()
	audio.next_allowed.clear()
	audio.played.clear()
	state=quiet(3102)
	state.add_enemy(state.player+Vector2(100,0),"boss")
	audio.prepare(state)
	state.cast_ultimate(state.magic.ticket)
	state.damage_player(5)
	state._projectile(Vector2.RIGHT,1,1)
	state.add_pickup(state.player,5)
	state._collect_pickups(.05)
	saved=Snapshot.capture(state)
	var visual:Dictionary=state.cues.snapshot()
	audio.finish(state,true)
	verify.call(count(audio,"hurt")==1 and count(audio,"magic")==1 and count(audio,"hit")==1 and count(audio,"fire")==0 and count(audio,"pickup")==0,"A mixed batch plays at most3sounds in hurt/magic/impact priority order")
	verify.call(saved==Snapshot.capture(state) and visual==state.cues.snapshot(),"Audio observation/playback never mutates HP/MP/growth/rewards/sevenRNG or cues")
	audio.prepare(state)
	audio.finish(state,true)
	verify.call(count(audio,"magic")==1 and count(audio,"hit")==1,"Unchanged committed counters/events are not replayed on the next observation")
	audio.stop_all()
	audio.next_allowed.clear()
	audio.played.clear()
	state=quiet(3103)
	state.add_enemy(state.player+Vector2(100,0))
	state.enemies[0].speed=0
	state.map_space.solids.clear()
	state.map_space.solids.append(Rect2(state.player+Vector2(35,-40),Vector2(20,80)))
	state.shot_clock=0
	audio.prepare(state)
	state.step(.05,Vector2.ZERO)
	audio.finish(state,true)
	verify.call(count(audio,"fire")==1 and count(audio,"hit")==0,"An actual shot stopped by a wall plays firing without a false hit")
	state.map_space.solids.clear()
	audio.next_allowed.clear()
	audio.prepare(state)
	state._damage_enemy(int(state.enemies[0].id),1)
	audio.finish(state,true)
	var old_event:Dictionary=state.cues.events[0]
	audio.next_allowed.clear() # Isolate merge detection from the documented rate cap.
	audio.prepare(state)
	state._damage_enemy(int(state.enemies[0].id),1)
	audio.finish(state,true)
	verify.call(is_same(old_event,state.cues.events[0]) and count(audio,"hit")==2,"An increased amount on the same merged hit dictionary remains a new actual impact")
	audio.prepare(state)
	audio.finish(state,true)
	verify.call(count(audio,"hit")==2,"A retained hit number cannot create repeated impact sounds")
	state=quiet(3104)
	state.stats.damage_reduction=.03
	state._damage_reduction_remainder=.99
	audio.prepare(state)
	state.damage_player(1)
	var hurts:int=count(audio,"hurt")
	audio.finish(state,true)
	verify.call(state.hp==100 and count(audio,"hurt")==hurts,"Fully prevented HP loss produces no hurt sound")
	state=quiet(3105)
	audio.prepare(state)
	state.add_pickup(state.player,state.growth.threshold())
	state.step(.05,Vector2.ZERO)
	audio.finish(state,true,false)
	verify.call(state.phase==State.Phase.CHOOSING and count(audio,"level")==1,"A real XP collection entering choice plays one growth cue,not queued combat sounds")
	audio.prepare(state,false)
	audio.finish(state,false,false)
	verify.call(count(audio,"level")==1,"Remaining in the same choice screen does not repeat the growth cue")
	state=quiet(3106)
	state.elapsed=359.96
	state._boss_spawned=true
	state._boss_defeated=true
	audio.prepare(state)
	state.step(.05,Vector2.ZERO)
	audio.finish(state,true,false)
	verify.call(state.phase==State.Phase.CLEARED and count(audio,"clear")==1,"The actual clear transition emits its one result cue")
	audio.guard(state,false)
	verify.call(audio.active_count()==1,"A result tail may finish while its result overlay remains visible")
	audio.prepare(state,false)
	audio.finish(state,false,false)
	verify.call(count(audio,"clear")==1,"An unchanged result screen cannot replay its stinger")
	state=quiet(3107)
	audio.prepare(state)
	state.damage_player(10000)
	audio.finish(state,true,false)
	verify.call(state.phase==State.Phase.DEFEAT and count(audio,"defeat")==1,"Committed defeat emits a single result cue")
	audio.stop_all()
	var ui=load("res://scenes/main.tscn").instantiate()
	var folder:="user://audio-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	ui.run_store.path=folder.path_join("battle.save")
	ui.gold_progress.path=folder.path_join("gold.cfg")
	ui.settings_path=folder.path_join("settings.cfg")
	host.get_tree().root.add_child(ui)
	ui.set_physics_process(false)
	await host.get_tree().process_frame
	Campaign.depart(ui)
	state=ui.simulation
	state.spawn_clock=999
	state.shot_clock=999
	state._scatter_clock=999
	state._swarm_clock=999
	ui._set_volume(.5)
	var ticket:int=state.magic.ticket
	ui._cast_magic(ticket)
	ui._cast_magic(ticket)
	verify.call(state.magic.casts==1 and count(ui.combat_audio,"magic")==1,"Actual mobile magic callback plays once for accepted MP,not stale/repeated requests")
	ui.pause_game()
	verify.call(state.phase==State.Phase.PAUSED and ui.combat_audio.active_count()==0,"Opening the existing pause menu immediately stops active voices")
	var casts:int=count(ui.combat_audio,"magic")
	ui._physics_process(.5)
	ui.resume_button.pressed.emit()
	ui._physics_process(.05)
	verify.call(count(ui.combat_audio,"magic")==casts,"Pause/resume consumes no old MP sound and creates no pending burst")
	ui._set_volume(0)
	ui._cast_magic(state.magic.ticket)
	verify.call(AudioServer.is_bus_mute(0) and state.magic.casts==2 and count(ui.combat_audio,"magic")==casts and ui.combat_audio.active_count()==0,"Master0remains successful silent gameplay with no queued audio")
	var cfg:=ConfigFile.new()
	cfg.load(ui.settings_path)
	verify.call(cfg.get_value("audio","master")==0.0,"The existing settings file persists master mute")
	ui._set_volume(.5)
	ui._physics_process(.05)
	verify.call(count(ui.combat_audio,"magic")==casts,"Unmuting cannot replay the muted cast")
	state.magic.mana=state.magic.maximum_mana() # Explicit audio-input fixture,not natural regeneration.
	ui.combat_audio.next_allowed.clear()
	ui._cast_magic(state.magic.ticket)
	verify.call(count(ui.combat_audio,"magic")==casts+1,"A new accepted cast after unmute is audible again")
	ui.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	verify.call(state.phase==State.Phase.PAUSED and ui.combat_audio.suspended and ui.combat_audio.active_count()==0,"Application focus loss pauses the existing battle and silences the shared pool")
	ui.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	verify.call(state.phase==State.Phase.PAUSED and not ui.combat_audio.suspended and ui.combat_audio.active_count()==0,"Focus regain alone cannot resume audio or gameplay")
	saved=Snapshot.capture(state)
	var restored=State.new()
	verify.call(Snapshot.restore(saved,restored),"Audio adds no version15save fields or invalid fingerprint")
	audio.played.clear()
	audio.prepare(restored,false)
	audio.finish(restored,false,false)
	restored.set_paused(false)
	audio.prepare(restored)
	audio.finish(restored,true)
	verify.call(audio.played.is_empty(),"Fresh restore/Continue never interprets cumulative shots/casts or saved result as new audio")
	ui.resume_button.pressed.emit()
	ui.combat_audio.enabled=false
	var reference=State.new()
	Snapshot.restore(Snapshot.capture(state),reference)
	reference.set_paused(false)
	var same:=true
	for frame in range(100):
		var direction:=Vector2.RIGHT if frame<50 else Vector2.ZERO
		reference.step(.05,direction)
		ui.movement.axis=direction
		ui._physics_process(.05)
		same=same and Campaign.comparable(reference)==Campaign.comparable(state)
	verify.call(same,"A disabled audio observer preserves100actual production steps and all gameplay/RNG")
	ui.combat_audio.enabled=true
	state.elapsed=state.stage_duration # Explicit terminal-transition fixture,not natural balance.
	state._boss_spawned=true
	state._boss_defeated=false
	state.enemies.clear()
	state.add_enemy(state.player+Vector2(100,0),"boss")
	state.enemies[-1].hp=1
	state.magic.mana=100
	ui._cast_magic(state.magic.ticket)
	verify.call(state.phase==State.Phase.CLEARED and ui.overlay.visible and count(ui.combat_audio,"clear")==1,"A manual magic terminal transition builds its actual result before playing the stinger")
	ui._physics_process(.05)
	verify.call(count(ui.combat_audio,"clear")==1 and ui.combat_audio.active_count()==1,"The next UI sync cannot cut or restart a manual-action result cue")
	ui.queue_free()
	audio.queue_free()
	await host.get_tree().process_frame
	# AudioServer releases a stopped playback on its next mixer slice.
	await host.get_tree().create_timer(.06).timeout
	AudioServer.set_bus_volume_db(0,original_db)
	AudioServer.set_bus_mute(0,original_mute)
