## Reproducible engine mixer QA;unique output folder,never linked from player menus.
extends SceneTree
var ui
var capture:AudioEffectCapture
var rows:Array=[]
var failures:Array=[]
var folder:String=""
func expect(condition:bool,label:String):
	if not condition:failures.append(label)
func _initialize():
	var output_root:="user://combat-audio-qa"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):output_root=arg.trim_prefix("--output-dir=")
		else:
			printerr("Unknown audio QA argument: ",arg)
			quit(2)
			return
	folder=output_root.path_join("run-"+Crypto.new().generate_random_bytes(8).hex_encode())
	call_deferred("run")
func window(label:String,seconds:float,nonzero:bool,save:bool=false):
	capture.clear_buffer()
	await create_timer(seconds).timeout
	var samples:PackedVector2Array=capture.get_buffer(capture.get_frames_available())
	var peak:=0.0
	var energy:=0.0
	for frame in samples:
		peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
		energy+=frame.length_squared()
	expect(samples.size()>4000,label+" contains actual mixer frames")
	expect(peak>.005 if nonzero else peak<.000001,label+" expected signal or silence")
	var state=ui.simulation
	rows.append({"case":label,"frames":samples.size(),"peak":peak,"rms":sqrt(energy/maxi(1,samples.size()*2)),"master_muted":AudioServer.is_bus_mute(0),"master_db":AudioServer.get_bus_volume_db(0),"active_voices":ui.combat_audio.active_count(),"casts":state.magic.casts,"played":ui.combat_audio.played.duplicate(),"phase":int(state.phase)})
	if save:
		var data:=PackedByteArray()
		data.resize(samples.size()*4)
		for index in range(samples.size()):
			data.encode_s16(index*4,roundi(clampf(samples[index].x,-1,1)*32767))
			data.encode_s16(index*4+2,roundi(clampf(samples[index].y,-1,1)*32767))
		var wav:=AudioStreamWAV.new()
		wav.format=AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate=roundi(AudioServer.get_mix_rate())
		wav.stereo=true
		wav.data=data
		expect(wav.save_to_wav(folder.path_join(label+".wav"))==OK,"write mixer recording")
func run():
	DirAccess.make_dir_recursive_absolute(folder)
	ui=load("res://scenes/main.tscn").instantiate()
	ui.run_store.path=folder.path_join("battle.save")
	ui.gold_progress.path=folder.path_join("gold.cfg")
	ui.settings_path=folder.path_join("settings.cfg")
	root.add_child(ui)
	ui.set_physics_process(false)
	await process_frame
	preload("res://tests/test_campaign.gd").depart(ui)
	var state=ui.simulation
	state.spawn_clock=999
	state.shot_clock=999
	state._scatter_clock=999
	state._swarm_clock=999
	capture=AudioEffectCapture.new()
	capture.buffer_length=2
	AudioServer.add_bus_effect(0,capture)
	ui._set_volume(.7)
	ui._cast_magic(state.magic.ticket)
	await window("magic",.6,true,true)
	ui._set_volume(0)
	ui._cast_magic(state.magic.ticket)
	await create_timer(.08).timeout
	await window("muted_success",.25,false)
	expect(state.magic.casts==2 and ui.combat_audio.played.get("magic",0)==1,"muted success is consumed once without playback")
	ui._set_volume(.5)
	await window("unmute_without_action",.25,false)
	state.magic.mana=100 # Explicit repeatable audio fixture.
	ui.combat_audio.next_allowed.clear()
	ui._cast_magic(state.magic.ticket)
	await window("unmuted_new_magic",.6,true,true)
	state.magic.mana=100
	ui.combat_audio.next_allowed.clear()
	ui._cast_magic(state.magic.ticket)
	await create_timer(.04).timeout
	ui.pause_game()
	await create_timer(.08).timeout
	await window("paused_tail_stopped",.25,false)
	ui.resume_button.pressed.emit()
	await window("resume_no_backlog",.25,false)
	state.elapsed=359.96
	state._boss_spawned=true
	state._boss_defeated=true
	ui._physics_process(.05)
	await window("clear",.65,true,true)
	ui._physics_process(.05)
	await window("result_no_replay",.25,false)
	expect(ui.combat_audio.played.get("clear",0)==1,"one clear cue")
	var bank=preload("res://scripts/combat/combat_audio_bank.gd")
	var bank_rows:Array=[]
	for kind in bank.SPECS:
		var stream:AudioStreamWAV=bank.stream(kind)
		var pcm:PackedByteArray=stream.data
		var peak:=0
		for index in range(0,pcm.size(),2):peak=maxi(peak,absi(pcm.decode_s16(index)))
		expect(stream.save_to_wav(folder.path_join(kind+"_source.wav"))==OK,"write placeholder source")
		var digest:=HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(pcm)
		bank_rows.append({"kind":kind,"samples":pcm.size()/2,"peak_int16":peak,"bytes":pcm.size(),"sha256_pcm":digest.finish().hex_encode()})
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	var result:Dictionary={"output_folder":folder,"status":"PASS" if failures.is_empty() else "FAIL","driver":AudioServer.get_driver_name(),"mix_rate":AudioServer.get_mix_rate(),"capture_stage":"Master bus AudioEffectCapture is PRE master gain/mute. Silence cases verify actual application voice gating/stop;master mute/db independently observed. Does not capture OS/device output.","failures":failures,"windows":rows,"source_pcm":bank_rows,"physical_speaker":"NOT_VERIFIED","human_listening":"NOT_VERIFIED","mobile_audio":"NOT_VERIFIED"}
	var file:=FileAccess.open(folder.path_join("results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	ui.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
