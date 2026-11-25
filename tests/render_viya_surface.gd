extends SceneTree
const IDLE="res://assets/characters/pilot_32/textures/viya_idle_e.png"
## GPU regression: actual surface pixels, fractional positions and planted feet.
## Run with a display; headless execution cannot certify rendered seams.
class Body:
	extends Node2D
	var visual:Dictionary
	var reference:bool=false
	var art=preload("res://scripts/ui/actor_assets.gd").new()
	func project_direction(v:Vector2)->Vector2:return v
	func _draw()->void:
		var feet:=Vector2(80.3,280.6)
		if reference:
			var box:Rect2=art.rectangle(visual.sample,feet)
			draw_texture_rect(visual.sample.texture,box,false)
		else:preload("res://scripts/combat/viya_presentation.gd").draw(self,art,visual,feet)
func _initialize()->void:call_deferred("run")
func run()->void:
	if DisplayServer.get_name()=="headless":
		print('{"status":"BLOCKED","reason":"Actual display required"}');quit(2);return
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/viya_motion.json"))
	var native:SpriteFrames=preload("res://assets/characters/pilot_32/render_cache/viya_render_frames.tres")
	var bodies:Array=[]
	var references:Array=[]
	var directions=["e","se","s","sw","w","nw","n","ne"]
	for i in range(8):
		var row:Dictionary=config.directions[directions[i]]
		for j in range(2):
			var body:=Body.new();body.reference=j==1;body.position=Vector2(i*160,0);body.visible=j==0
			body.visual={"sample":{"texture":load(IDLE.get_base_dir().path_join("viya_idle_"+directions[i]+".png")),"size":Vector2(69,85.56),"pivot":Vector2(.5,1)},"region":Rect2(row.idle_region[0],row.idle_region[1],row.idle_region[2],row.idle_region[3]),"recoil":0.0,"facing":Vector2.RIGHT,"pose":"idle","muzzle":Vector2(row.muzzle[0],row.muzzle[1]),"shot_age":1.0}
			root.add_child(body)
			if j==0:bodies.append(body)
			else:references.append(body)
	var failures:Array=[];var checks:=0
	for frame in range(52):
		var age:float=frame*.025
		for i in range(8):
			var step:int=frame%26
			var pose:String="run" if step<11 else ("attack" if step<19 else ("hurt" if step<25 else "idle"))
			var index:int=step if step<11 else (step-11 if step<19 else (step-19 if step<25 else 0))
			for body in [bodies[i],references[i]]:
				body.visual.pose=pose
				body.visual.sample.texture=native.get_frame_texture(pose+"_"+directions[i],index)
				body.visual.shot_age=1.0 # Compare body pixels without a muzzle flash.
				body.visual.recoil=0.0
				body.queue_redraw()
		# Compare at identical screen coordinates. Translating the reference360px
		# changed fractional raster precision at69x85.56 and caused false1LSB diffs.
		for i in range(8):bodies[i].visible=true;references[i].visible=false
		await process_frame;await RenderingServer.frame_post_draw
		var actual:Image=root.get_texture().get_image()
		for i in range(8):bodies[i].visible=false;references[i].visible=true
		await process_frame;await RenderingServer.frame_post_draw
		var expected:Image=root.get_texture().get_image()
		for i in range(8):
			checks+=1
			if actual.get_region(Rect2i(i*160+15,246,130,36)).get_data()!=expected.get_region(Rect2i(i*160+15,246,130,36)).get_data():failures.append("foot:"+directions[i]+":"+str(frame))
			checks+=1
			if actual.get_region(Rect2i(i*160,100,160,190)).get_data()!=expected.get_region(Rect2i(i*160,100,160,190)).get_data():failures.append("body:"+directions[i]+":"+str(frame))
	print(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"native_poses_per_direction":26,"frames":104,"pairs":52,"directions":8,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"scope":"Linux/display pixels at identical fractional coordinates, strict byte equality; Windows driver confirmation remains separate"}))
	quit(0 if failures.is_empty() else 1)
