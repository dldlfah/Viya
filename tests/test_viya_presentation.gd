extends RefCounted
const Campaign=preload("res://tests/test_campaign.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const IDLE="res://assets/characters/pilot_32/textures/viya_idle_e.png"

static func run(host,verify:Callable) -> void:
	var folder:="user://viya-presentation-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	var ui=Campaign.make_ui(host,folder)
	Campaign.depart(ui)
	var view=ui.view
	var state=ui.simulation
	state.player=Vector2(2500,1700);state.spawn_clock=999;state.shot_clock=999;state._scatter_clock=999;state._swarm_clock=999
	var asset:SpriteFrames=view.art.resource("viya_battle")
	var all_alpha:=true
	for animation in asset.get_animation_names():
		for index in range(asset.get_frame_count(animation)):
			all_alpha=all_alpha and view.viya.transparent(asset.get_frame_texture(animation,index))
	verify.call(all_alpha and view.viya._alpha.size()==208,"Every shipped directional frame actually decodes with transparent corners in Godot, not an opaque/white import")
	var opaque:=Image.create(200,248,false,Image.FORMAT_RGBA8)
	opaque.fill(Color.WHITE)
	verify.call(not view.viya.transparent(ImageTexture.create_from_image(opaque)),"Lost-alpha white texture is rejected before it can be drawn as a rectangle")
	for direction in ["e","w"]:
		var path:String=IDLE.get_base_dir().path_join("viya_idle_"+direction+".png")
		var recovered:Texture2D=view.viya.decoded(path)
		var pixels:=Image.new()
		pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		verify.call(recovered!=null and view.viya.transparent(recovered) and recovered.get_image().get_data()==pixels.get_data(),"Raw PNG recovery of left/right bypasses a stale opaque import with the exact original alpha/pixels:"+direction)
	var original:Texture2D=asset.get_frame_texture("idle_w",0)
	view.viya._alpha[original.get_instance_id()]=false # Inject the rejected-import path.
	var recovered_pose:Dictionary={"pose":"idle","moving":false,"direction":"w","facing":Vector2.LEFT,"clock":0.0,"sample":{}}
	view.viya.apply(view,recovered_pose)
	verify.call(not recovered_pose.sample.is_empty() and is_same(recovered_pose.sample.texture,view.viya.decoded(original.resource_path)),"Actual hero sampling replaces a rejected left import with original transparent pixels instead of a white box or another character")
	view.viya._alpha[original.get_instance_id()]=true
	var east:Texture2D=asset.get_frame_texture("idle_e",0)
	asset.set_frame("idle_e",0,ImageTexture.create_from_image(opaque))
	var failed_import:Dictionary={"pose":"idle","moving":false,"direction":"e","facing":Vector2.RIGHT,"clock":0.0,"sample":{}}
	view.viya.apply(view,failed_import)
	verify.call(not failed_import.sample.is_empty() and view.viya.transparent(failed_import.sample.texture) and is_same(failed_import.sample.texture,view.viya.decoded(IDLE)),"A wholly opaque cached frame with a missing resource path recovers the correct canonical east frame rather than drawing a white square")
	asset.set_frame("idle_e",0,east)
	for index in range(8):
		var direction:String=view.actors.DIRECTIONS[index]
		var visual:Dictionary={"pose":"run","direction":direction,"facing":Vector2.from_angle(index*PI/4),"clock":.06,"moving":true,"distance":80.0,"sample":{}}
		view.viya.apply(view,visual)
		var texture:Texture2D=visual.sample.texture
		var region:Rect2=visual.region
		var registered:Rect2=view.viya.body_rect(view.actor_art,visual,Vector2(200,180))
		var grounded:=true
		for frame in view.viya.config.directions[direction].run:
			grounded=grounded and frame.region[1]+frame.region[3]>=240 and frame.region[3]>=230 and frame.index>=0 and frame.index<11
		visual.pose="attack";visual.clock=.01;view.viya.apply(view,visual)
		verify.call(grounded and registered.end.y==180 and is_equal_approx(registered.size.x/region.size.x,registered.size.y/region.size.y) and is_same(visual.sample.texture,texture) and visual.region==region and visual.recoil>0,"Distance gait plants feet without stretching source proportions and continues the same phase through auto fire:"+direction)
		visual.moving=false;view.viya.apply(view,visual)
		var idle:Texture2D=visual.sample.texture
		visual.clock=.1;view.viya.apply(view,visual)
		verify.call(visual.sample.animation=="idle_"+direction and visual.sample.index==0 and is_same(visual.sample.texture,idle),"Stationary fire never advances or replaces the planted leg frame:"+direction)
		var world_direction:Vector2=view.input_direction(Vector2.from_angle(index*PI/4))
		state.facing=world_direction;view.actors.reset(state.run_id)
		var bullet:Dictionary={"p":state.player,"direction":world_direction,"life":.75,"speed":920.0,"source":"rifle"}
		view.viya._shot_offsets.clear()
		var before:Dictionary=Snapshot.capture(state)
		var shown:Dictionary=view.viya.projectile(view,bullet)
		var current:Dictionary=view.actor_visual()
		var muzzle:Vector2=view.viya.muzzle(view.actor_art,current,view.world_to_screen(state.player))
		verify.call(shown.p.distance_to(muzzle)<.001 and shown.p.distance_to(view.world_to_screen(state.player))>45 and Snapshot.capture(state)==before,"Fresh visual bullet starts at the registered gun muzzle without changing authoritative projectile/player/RNG:"+direction)
	var before:Dictionary=Snapshot.capture(state)
	var rune:Dictionary={"p":state.player,"direction":state.facing,"life":.75,"speed":920.0,"source":"viya_runebullet_v1"}
	verify.call(view.viya.projectile(view,rune).p.distance_to(view.world_to_screen(state.player))>45,"Viya's exclusive rune bullet also emits at gun height rather than under her feet")
	var held:Dictionary={"pose":"run","moving":true,"direction":"e","facing":view.input_direction(Vector2.RIGHT),"gun_aim":view.input_direction(Vector2.LEFT),"motion":view.input_direction(Vector2.RIGHT),"shot_age":.25,"clock":.25,"distance":40.0,"sample":{}}
	view.viya.apply(view,held)
	var held_index:int=held.sample.index
	held.pose="attack";held.shot_age=0.0;view.viya.apply(view,held)
	verify.call(held.direction=="w" and held.sample.index==held_index,"Automatic fire holds aim through attack/run transitions while backward movement keeps its distance-driven leg phase")
	ui.movement.axis=Vector2.RIGHT
	for i in range(6):ui._physics_process(.05)
	var distance:float=view.actors.pose(state).distance
	verify.call(is_equal_approx(distance,235.0*.3),"Hero gait follows actual traveled world distance, not the fire animation clock")
	ui.movement.axis=Vector2.ZERO
	for i in range(6):ui._physics_process(.05)
	verify.call(view.actor_visual().sample.animation.begins_with("idle_") and view.actors.pose(state).distance==distance,"Released input immediately stops the legs and freezes gait distance")
	ui.pause_game();before=Snapshot.capture(state);var pose:Dictionary=view.actor_visual()
	for i in range(4):ui._physics_process(.05)
	verify.call(Snapshot.capture(state)==before and view.actor_visual().sample.index==pose.sample.index and view.actors.pose(state).distance==distance,"Pause freezes derived gait and authoritative state together")
	ui.queue_free();await host.get_tree().process_frame
	for file in DirAccess.get_files_at(folder):DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
