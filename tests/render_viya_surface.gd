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
			var box:Rect2=preload("res://scripts/combat/viya_presentation.gd").body_rect(art,visual,feet)
			draw_texture_rect_region(visual.sample.texture,box,visual.region)
		else:preload("res://scripts/combat/viya_presentation.gd").draw(self,art,visual,feet)
func _initialize()->void:call_deferred("run")
func run()->void:
	if DisplayServer.get_name()=="headless":
		print('{"status":"BLOCKED","reason":"Actual display required"}');quit(2);return
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/viya_motion.json"))
	var bodies:Array=[]
	var directions=["e","se","s","sw","w","nw","n","ne"]
	for i in range(8):
		var row:Dictionary=config.directions[directions[i]]
		for j in range(2):
			var body:=Body.new();body.reference=j==1;body.position=Vector2(i*160,j*360)
			body.visual={"sample":{"texture":load(IDLE.get_base_dir().path_join("viya_idle_"+directions[i]+".png")),"size":Vector2(125,155),"pivot":Vector2(.5,1)},"region":Rect2(row.idle_region[0],row.idle_region[1],row.idle_region[2],row.idle_region[3]),"recoil":0.0,"facing":Vector2.RIGHT,"pose":"idle","muzzle":Vector2(row.muzzle[0],row.muzzle[1]),"shot_age":1.0}
			root.add_child(body)
			if j==0:bodies.append(body)
	var failures:Array=[];var checks:=0
	for frame in range(40):
		var age:float=frame*.025
		for body in bodies:
			body.visual.pose="attack" if frame<5 else "idle"
			body.visual.shot_age=age
			body.visual.recoil=maxf(0,1-age/.12)
			body.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		var pixels:Image=root.get_texture().get_image()
		for i in range(8):
			var upper:Image=pixels.get_region(Rect2i(i*160+15,246,130,36))
			var lower:Image=pixels.get_region(Rect2i(i*160+15,606,130,36))
			checks+=1
			if upper.get_data()!=lower.get_data():failures.append("foot:"+directions[i]+":"+str(frame))
			if frame==39:
				checks+=1
				if pixels.get_region(Rect2i(i*160,100,160,190)).get_data()!=pixels.get_region(Rect2i(i*160,460,160,190)).get_data():failures.append("body:"+directions[i])
	print(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"frames":40,"directions":8,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"scope":"Linux/display pixels; Windows driver confirmation remains separate"}))
	quit(0 if failures.is_empty() else 1)
