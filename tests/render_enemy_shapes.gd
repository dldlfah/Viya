extends SceneTree
## GUI reference check: original primitive silhouettes versus cached vectors.
const Native=preload("res://tests/fixtures/game063/battle_forms_before.gd")
const Forms=preload("res://scripts/combat/battle_forms.gd")
const Cache=preload("res://scripts/combat/enemy_shape_cache.gd")
class ShapePanel:
	extends Control
	var native:bool=true
	var phase:float=0
	var cache=Cache.new()
	func _draw():
		draw_rect(Rect2(Vector2.ZERO,size),Color("302d2a"))
		for row in range(4):
			for column in range(5):
				var variant:String=["normal","ranged","fast","heavy","flier"][column]
				var tint:Color=[Color("b07670"),Color("d4ccaf"),Color("bd85db"),Color("ee7777")][row]
				var height:float=[40.0,50.0,66.0,92.0][row]
				var feet:=Vector2(column*130+65,row*125+118)
				var motion:Dictionary={"moving":phase>=0,"move_clock":maxf(0,phase)}
				if native:Native.enemy(self,feet,variant,tint,height,row%2==1,motion)
				else:Forms.enemy(self,feet,variant,tint,height,row%2==1,motion,cache)
func _initialize():call_deferred("run")
func run():
	var folder:String="res://"+".local_validation/GAME063/shapes"
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(650,500);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var panel:=ShapePanel.new();panel.size=Vector2(650,500);root.add_child(panel)
	var rows:Array=[];var maximum:int=0
	for phase in [-1.0,0.0,.03125,.09375,.2]:
		var images:Array[Image]=[]
		for native in [true,false]:
			panel.native=native;panel.phase=phase;panel.queue_redraw()
			await process_frame;await RenderingServer.frame_post_draw
			images.append(root.get_texture().get_image())
		var changed:int=0;var local_max:int=0
		var a:PackedByteArray=images[0].get_data();var b:PackedByteArray=images[1].get_data()
		for i in range(a.size()):
			var delta:int=absi(int(a[i])-int(b[i]));local_max=maxi(local_max,delta)
			if delta>0:changed+=1
		maximum=maxi(maximum,local_max)
		rows.append({"move_clock":phase,"bodies":20,"max_channel_difference":local_max,"changed_channels":changed})
		if phase==.09375:
			images[0].save_png(folder.path_join("native.png"));images[1].save_png(folder.path_join("cached.png"))
	var report:Dictionary={"status":"PASS" if maximum<=1 else "FAIL","rows":rows,"maximum_channel_difference":maximum,"scope":"100 body poses against untouched pre-GAME063 primitives; at most1/255 vertex-colour encoding difference, original ordering/AA/shape/colours retained."}
	FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));panel.queue_free();await process_frame;quit(0 if maximum<=1 else 1)
