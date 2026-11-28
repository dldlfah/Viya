extends RefCounted
## Producer-accepted gait; engine checks do not certify foot-contact quality.
const Prior=preload("res://assets/characters/pilot_32/game069_s_run_fire/viya_game069_frames.tres")
const Reader=preload("res://tests/test_viya_game069.gd")
const Presenter=preload("res://scripts/combat/viya_presentation.gd")
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const Campaign = preload("res://tests/test_campaign.gd")
const Folder="res://"+"assets/characters/pilot_32/game070_sw_run/"

static func verify_skipped_draws(ui, verify: Callable) -> void:
	var state = ui.simulation
	var view = ui.view
	var initial: Dictionary = Snapshot.capture(state)
	var presenter = view.viya
	var audio_enabled: bool = ui.combat_audio.enabled
	ui.combat_audio.enabled = false
	var results: Array[Dictionary] = []
	for sample_each_tick in [true, false]:
		if not Snapshot.restore(initial, state):
			verify.call(false, "SW cadence fixture restores the starting battle")
			ui.combat_audio.enabled = audio_enabled
			return
		state.set_paused(false)
		state.player = Vector2(2500, 1200)
		state.shot_clock = 999.0
		state.spawn_clock = 999.0
		view.actors.reset()
		view.camera.reset()
		view.viya = Presenter.new()
		var motion := Vector2(-1, 1).normalized()
		var forward: Vector2 = view.input_direction(motion)
		ui.movement.axis = motion
		view.actor_visual()
		var verified_turn := true
		for tick in range(12):
			if tick == 4:
				state.add_enemy(state.player - forward * 250)
				state.enemies[-1].speed = 0
				state.enemies[-1].hp = 100000
				state.enemies[-1].max_hp = 100000
				state.shot_clock = 0
			elif tick == 9:
				state.enemies[-1].p = state.player + forward * 250
				state.shot_clock = 0
			ui._physics_process(1.0 / 60)
			if sample_each_tick:
				var visible: Dictionary = view.actor_visual()
				var expected_direction := "ne" if tick >= 4 and tick < 9 else "sw"
				verified_turn = verified_turn and visible.direction == expected_direction
		var final_pose: Dictionary = view.actor_visual()
		results.append({"phase": final_pose.gait_phase, "clip": final_pose.sample.animation,
			"frame": final_pose.sample.index, "turn": verified_turn, "shots": state.shots,
			"state": Campaign.comparable(state)})
	var regular := results[0]
	var skipped := results[1]
	var phase_difference := wrapf(float(regular.phase) - float(skipped.phase), -0.5, 0.5)
	verify.call(regular.turn and regular.shots == 2 and regular.clip == "run_fire_sw", "Real southwest movement aims back and then southwest again as two shots commit")
	verify.call(is_zero_approx(phase_difference) and regular.clip == skipped.clip and regular.frame == skipped.frame, "Omitting intermediate draws keeps the ending SW17 phase and frame across aim reversals")
	verify.call(regular.state == skipped.state, "Sampling cadence does not change the authoritative battle")
	ui.movement.axis = Vector2.ZERO
	verify.call(Snapshot.restore(initial, state), "SW cadence check restores the original battle fixture")
	state.set_paused(false)
	view.actors.reset()
	view.camera.reset()
	view.viya = presenter
	ui.combat_audio.enabled = audio_enabled

static func begin(view,phase:float) -> Dictionary:
	var forward:Vector2=view.input_direction(Vector2(-1,1).normalized())
	var visual:Dictionary={"pose":"run","direction":"sw","facing":forward,"motion":forward,"clock":0.0,"moving":true,"distance":0.0,"shot_age":1000.0,"gun_aim":Vector2.ZERO,"sample":{}}
	view.viya._gait_run="";view.viya.apply(view,visual)
	visual.distance=fposmod(phase,1.0)*155.0;view.viya.apply(view,visual)
	return visual
static func run(view,asset:SpriteFrames,verify:Callable) -> void:
	var preserved:=true
	var total:=0
	for name in Prior.get_animation_names():
		if name=="run_sw":continue
		var count:int=Prior.get_frame_count(name);total+=count
		preserved=preserved and asset.get_frame_count(name)==count and asset.get_animation_speed(name)==Prior.get_animation_speed(name) and asset.get_animation_loop(name)==Prior.get_animation_loop(name)
		for i in range(count):preserved=preserved and asset.get_frame_texture(name,i).resource_path==Prior.get_frame_texture(name,i).resource_path and asset.get_frame_duration(name,i)==Prior.get_frame_duration(name,i)
	verify.call(preserved and total==331 and asset.get_animation_names().size()==36,"GAME070 preserves other34clips331frames, texture paths, weights, speeds, loops")
	var timing:Array=Reader.read_timing(Folder+"provenance/frame_timing.csv")
	var meta:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Folder+"provenance/clip_metadata.json"))
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Folder+"manifest.json"))
	var rows:Array=view.viya.config.directions.sw.run
	verify.call(asset.resource_path=="res://assets/characters/pilot_32/game075_sw_run_fire_candidate03/viya_game075_frames.tres" and timing.size()==17 and rows.size()==17 and asset.get_frame_count("run_sw")==17,"Active GAME070 slot replaces only SW11 with17 measured native source frames")
	if timing.size()!=17 or rows.size()!=17:return
	var original=view.viya;view.viya=Presenter.new()
	var elapsed:=0.0
	var phase:float=meta.phase_origin
	var speed:float=asset.get_animation_speed("run_sw")
	for i in range(17):
		var t:Dictionary=timing[i]
		var image:=Image.new();var path:String=rows[i].texture
		var valid:bool=image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))==OK
		verify.call(valid and image.get_size()==Vector2i(200,248) and image.get_data()==asset.get_frame_texture("run_sw",i).get_image().get_data() and FileAccess.get_sha256(path)==manifest.frame_checks[i].sha256,"SW imported RGBA is exact delivered PNG:"+str(i))
		verify.call(t.duration_ms>0 and absf(t.start_ms-elapsed)<.000001 and absf(asset.get_frame_duration("run_sw",i)/speed*1000.0-t.duration_ms)<.000001,"SW measured duration retained:"+str(i))
		elapsed+=t.duration_ms
		var visual:Dictionary=begin(view,(t.start_ms+t.duration_ms*.5)/660.0-phase)
		var muzzle:Array=rows[i].muzzle
		verify.call(visual.sample.animation=="run_sw" and visual.sample.index==i and visual.muzzle==Vector2(muzzle[0],muzzle[1]) and visual.sample["size"]==Vector2(69,85.56) and visual.sample.pivot==Vector2(.5,1),"SW midpoint selects whole frame and independent muzzle at common size/root:"+str(i))
		if i<16:
			var before:Dictionary=begin(view,(elapsed-.001)/660-phase)
			var after:Dictionary=begin(view,(elapsed+.001)/660-phase)
			verify.call(before.sample.index==i and after.sample.index==i+1,"SW CSV boundary at plus/minus1microsecond:"+str(i))
	verify.call(absf(elapsed-660)<.000001 and is_equal_approx(view.viya.config.directions.sw.phase_origin,phase),"SW cycle660 and independently fitted phase are connected")
	var visual:Dictionary=begin(view,(660-.001)/660-phase)
	var last:bool=visual.sample.index==16
	visual.distance+=.002/660*155;view.viya.apply(view,visual)
	verify.call(last and visual.sample.index==0,"SW last-to-first wraps without resetting traveled distance")
	visual=begin(view,.37);var held:float=visual.gait_phase;var index:int=visual.sample.index
	visual.direction="s";visual.facing=view.input_direction(Vector2.DOWN);visual.motion=visual.facing;view.viya.apply(view,visual)
	var turn:bool=visual.sample.animation=="run_s" and is_equal_approx(visual.gait_phase,held)
	visual.direction="sw";visual.facing=view.input_direction(Vector2(-1,1).normalized());visual.motion=visual.facing;view.viya.apply(view,visual)
	verify.call(turn and visual.sample.animation=="run_sw" and visual.sample.index==index and is_equal_approx(visual.gait_phase,held),"S/SW roundtrip retains distance phase and exact returning SW pose; no physical-contact claim")
	view.viya=original
