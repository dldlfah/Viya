extends RefCounted
## Strict GAME066 evidence on top of GAME065: only SE run is replaced by 18 delivered RGBA frames.
const Older=preload("res://assets/characters/pilot_32/game065_e_run_fire/viya_game065_frames.tres")
const Slots=preload("res://scripts/ui/asset_slots.gd")
const META="res://assets/characters/pilot_32/game066_se_run/provenance/source_registration.json"
const CSV="res://assets/characters/pilot_32/game066_se_run/provenance/frame_timing.csv"
const FIRST="res://assets/characters/pilot_32/game066_se_run/frames/viya_run_se_000.png"
const RESOURCE="res://assets/characters/pilot_32/game075_sw_run_fire_candidate03/viya_game075_frames.tres"

static func run(view,asset:SpriteFrames,verify:Callable) -> void:
	var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(META))
	var slots=Slots.new()
	verify.call(data is Dictionary and asset.resource_path==RESOURCE and slots.definitions.viya_battle==RESOURCE,"GAME066 active slot and metadata are from one approved derived resource")
	if not data is Dictionary:return
	# GAME068 replaces S; its separate suite proves the live33other clips unchanged.
	var preserved_asset:SpriteFrames=load("res://assets/characters/pilot_32/game067_se_run_fire/viya_game067_frames.tres")
	var other_animations:=true
	var old_frames:int=0
	for name:StringName in Older.get_animation_names():
		if not preserved_asset.has_animation(name):
			other_animations=false
			continue
		if name==&"run_se":continue
		var count:int=Older.get_frame_count(name)
		old_frames+=count
		other_animations=other_animations and preserved_asset.get_frame_count(name)==count and preserved_asset.get_animation_speed(name)==Older.get_animation_speed(name) and preserved_asset.get_animation_loop(name)==Older.get_animation_loop(name)
		for i in range(count):
			var a:Texture2D=preserved_asset.get_frame_texture(name,i)
			var b:Texture2D=Older.get_frame_texture(name,i)
			other_animations=other_animations and a!=null and b!=null and a.resource_path==b.resource_path and preserved_asset.get_frame_duration(name,i)==Older.get_frame_duration(name,i)
	verify.call(other_animations and old_frames==280 and preserved_asset.get_animation_names().size()==34,"GAME066 preserves the other32animations and280existing resolved frames and timings")
	var count:int=asset.get_frame_count(&"run_se")
	verify.call(count==18 and is_equal_approx(asset.get_animation_speed(&"run_se"),18.0/.66) and asset.get_animation_loop(&"run_se"),"GAME066 SE has a genuine18frame 660ms looping clip")
	var metadata_valid:bool=data.has("frame_checks") and data.frame_checks.size()==18
	var frame_sha:Dictionary={}
	var muzzle_ok:=true
	var alpha_ok:=true
	var res_ok:=true
	var motion=view.viya.config.directions.se
	var rows:Variant=motion.get("run")
	if rows is Array:res_ok=res_ok and rows.size()==18
	else:res_ok=false
	for i in range(count):
		var path:String=FIRST.get_base_dir().path_join("viya_run_se_%03d.png" % i)
		var frame:Texture2D=asset.get_frame_texture(&"run_se",i)
		var pic:=Image.new()
		var image_ok:bool=pic.load_png_from_buffer(FileAccess.get_file_as_bytes(path))==OK
		if not image_ok:
			alpha_ok=false
			continue
		var dimensions_ok:bool=pic.get_size()==Vector2i(200,248)
		alpha_ok=alpha_ok and dimensions_ok and pic.get_pixel(0,0).a==0.0 and pic.get_pixel(199,0).a==0.0 and pic.get_pixel(0,247).a==0.0 and pic.get_pixel(199,247).a==0.0
		if frame==null:res_ok=false
		else:res_ok=res_ok and frame.get_size()==Vector2(200,248) and frame.resource_path==path and asset.get_frame_duration(&"run_se",i)==1.0
		var sha:String=FileAccess.get_sha256(path)
		frame_sha[sha]=true
		if metadata_valid:res_ok=res_ok and sha==data.frame_checks[i].sha256
		if res_ok and rows is Array:
			var row:Dictionary=rows[i]
			res_ok=res_ok and int(row.index)==i and str(row.texture)==path and row.region.size()==4 and int(row.region[0])==0 and int(row.region[1])==0 and int(row.region[2])==200 and int(row.region[3])==248
			if metadata_valid:muzzle_ok=muzzle_ok and row.muzzle==data.frame_checks[i].muzzle
	verify.call(alpha_ok and frame_sha.size()==18 and metadata_valid,"All GAME066 RGBA18 frames have fixed200x248 canvas, clear corners and unique preserved PNG hashes")
	print("GAME066_meta res_ok=",res_ok," muzzle_ok=",muzzle_ok," phase=",motion.phase_origin)
	verify.call(res_ok and muzzle_ok and is_equal_approx(float(motion.phase_origin),3.0/11.0),"Each SE frame resolves from measured texture/independent muzzle and preserves original SE phase origin")
	var csv_ok:=true
	var f:=FileAccess.open(CSV,FileAccess.READ)
	if f==null:csv_ok=false
	else:
		var header:PackedStringArray=f.get_csv_line()
		csv_ok=header==PackedStringArray(["frame","filename","source_frame","duration_ms","start_ms","phase"])
		var accum:float=0.0
		for i in range(18):
			var cells:PackedStringArray=f.get_csv_line()
			if cells.size()!=6:csv_ok=false;break
			csv_ok=csv_ok and int(cells[0])==i and cells[1]=="viya_run_se_%03d.png" % i and int(cells[2])==36+i and absf(float(cells[3])-660.0/18)<.000001 and absf(float(cells[4])-accum)<.000001
			accum+=float(cells[3])
		csv_ok=csv_ok and absf(accum-660.0)<.0001
		f.close()
	verify.call(csv_ok,"GAME066 uses18consecutive native generated poses with no repeated endpoint, exact660ms retime and full authored timing CSV")
	var direct_ok:=true
	for i in range(18):
		var at:float=.66*(i+.5)/18.0
		var sample:Dictionary=view.actor_art.frame(view.art,["viya_battle"],"run","se",at)
		direct_ok=direct_ok and not sample.is_empty() and sample.animation=="run_se" and sample.index==i
	var end_sample:Dictionary=view.actor_art.frame(view.art,["viya_battle"],"run","se",.660001)
	direct_ok=direct_ok and end_sample.index==0
	verify.call(direct_ok,"All SE18 animation indices are reachable with a true last-to-first loop")
	var original_viya=view.viya
	var phase_ok:=true
	var last_phase:=0.0
	var directions:=[view.input_direction(Vector2.RIGHT),view.input_direction(Vector2(1,1).normalized())]
	for i in range(120):
		var dir:String="e" if i%10<5 else "se"
		var facing:Vector2=directions[0 if dir=="e" else 1]
		var distance:float=i*155.0/120.0
		var visual:Dictionary={"pose":"run","direction":dir,"facing":facing,"motion":facing,"moving":true,"clock":0.0,"distance":distance,"shot_age":1000.0,"gun_aim":Vector2.ZERO,"sample":{}}
		view.viya.apply(view,visual)
		phase_ok=phase_ok and visual.sample.animation=="run_"+dir and absf(float(visual.gait_phase)-fposmod(distance/155.0,1.0))<.0001
		last_phase=float(visual.gait_phase)
	verify.call(phase_ok,"Real display adapter turns E<->SE without resetting common distance-driven gait phase or switching a pose to the wrong direction")
