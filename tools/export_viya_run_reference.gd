extends SceneTree
## Replay one current run direction as a clean reference, never new animation.
const Actors=preload("res://scripts/ui/actor_assets.gd")
const Slots=preload("res://scripts/ui/asset_slots.gd")
const FOLDER="res://"+".local_validation/GAME065_REFERENCE"
var output_folder:String=FOLDER
var direction:String="e"
class ReferenceCanvas:
	extends Control
	var sample:Dictionary={}
	func _draw():
		draw_rect(Rect2(Vector2.ZERO,size),Color("626870"))
		if not sample.is_empty():draw_texture_rect(sample.texture,Rect2(Vector2.ZERO,size),false)
func _initialize():call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless":print('{"status":"BLOCKED","reason":"Display required"}');quit(2);return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--direction="):direction=argument.trim_prefix("--direction=")
		if argument.begins_with("--output="):output_folder=argument.trim_prefix("--output=")
	if direction not in ["e","se","s","sw","w","nw","n","ne"] or not output_folder.begins_with("res://.local_validation/") or ".." in output_folder:
		printerr("Use a known direction and an isolated res://.local_validation/ output");quit(2);return
	DirAccess.make_dir_recursive_absolute(output_folder.path_join("frames"))
	root.size=Vector2i(600,744);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var canvas:=ReferenceCanvas.new();canvas.size=Vector2(600,744);root.add_child(canvas)
	var slots=Slots.new();var actors=Actors.new();var seen:Dictionary={}
	var asset:SpriteFrames=slots.resource("viya_battle")
	var animation:String="run_"+direction
	if asset==null or not asset.has_animation(animation) or asset.get_animation_speed(animation)<=0:
		printerr("Missing current run direction");quit(1);return
	var count:int=asset.get_frame_count(animation)
	var duration:float=0.0
	for index in range(count):duration+=asset.get_frame_duration(animation,index)/asset.get_animation_speed(animation)
	if count==0 or not is_finite(duration) or duration<=0:
		printerr("Invalid current run timing");quit(1);return
	var steps:int=ceili(duration*5*60-.000001)
	for step in range(steps):
		canvas.sample=actors.frame(slots,["viya_battle"],"run",direction,step/60.0)
		if canvas.sample.is_empty():printerr("Missing current run frame");quit(1);return
		seen[canvas.sample.index]=true;canvas.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(output_folder.path_join("frames/frame_%03d.png" % step))!=OK:quit(1);return
	var report:Dictionary={"status":"PASS" if seen.size()==count else "FAIL","direction":direction,"source_frame_count":count,"frames":steps,"fps":60,"nominal_cycles":5,"cycle_seconds":duration,"canvas":[600,744],"source_canvas":[200,248],"scale":3,"source_frames_seen":seen.keys(),"source_resource":asset.resource_path,"scope":"Replay of current full-body run on neutral gray for motion-control input. No new poses,shooting frames,limb edits or production asset changes; captured-frame export,not real-time FPS."}
	FileAccess.open(output_folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));canvas.queue_free();await process_frame;quit(0 if report.status=="PASS" else 1)
