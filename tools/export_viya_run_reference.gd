extends SceneTree
## Replay the accepted E run as a clean motion reference, never new firing art.
const Actors=preload("res://scripts/ui/actor_assets.gd")
const Slots=preload("res://scripts/ui/asset_slots.gd")
const FOLDER="res://"+".local_validation/GAME065_REFERENCE"
class ReferenceCanvas:
	extends Control
	var sample:Dictionary={}
	func _draw():
		draw_rect(Rect2(Vector2.ZERO,size),Color("626870"))
		if not sample.is_empty():draw_texture_rect(sample.texture,Rect2(Vector2.ZERO,size),false)
func _initialize():call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless":print('{"status":"BLOCKED","reason":"Display required"}');quit(2);return
	DirAccess.make_dir_recursive_absolute(FOLDER.path_join("frames"))
	root.size=Vector2i(600,744);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var canvas:=ReferenceCanvas.new();canvas.size=Vector2(600,744);root.add_child(canvas)
	var slots=Slots.new();var actors=Actors.new();var seen:Dictionary={}
	for step in range(198):
		canvas.sample=actors.frame(slots,["viya_battle"],"run","e",step/60.0)
		if canvas.sample.is_empty():printerr("Missing accepted E run");quit(1);return
		seen[canvas.sample.index]=true;canvas.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(FOLDER.path_join("frames/frame_%03d.png" % step))!=OK:quit(1);return
	var report:Dictionary={"status":"PASS" if seen.size()==47 else "FAIL","frames":198,"fps":60,"nominal_cycles":5,"cycle_seconds":.66,"canvas":[600,744],"source_canvas":[200,248],"scale":3,"source_frames_seen":seen.keys(),"source_resource":slots.resource("viya_battle").resource_path,"scope":"Replay of accepted full-body E run on neutral gray for motion-control input. No new poses,shooting frames,limb edits or production asset changes; captured-frame export,not real-time FPS."}
	FileAccess.open(FOLDER.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));canvas.queue_free();await process_frame;quit(0 if report.status=="PASS" else 1)
