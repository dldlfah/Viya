extends RefCounted
const Filter=preload("res://tools/viya_edge_filter.gd")
const CACHE="res://assets/characters/pilot_32/render_cache/manifest.json"
const Frames=preload("res://assets/characters/pilot_32/render_cache/viya_render_frames.tres")
const Source=preload("res://assets/characters/pilot_32/resources/viya_directional_motion.tres")
static func run(verify:Callable)->void:
	var image:=Image.create(24,24,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(4,4,16,16),Color(.2,.1,.1,1))
	for i in range(4,20):
		image.set_pixel(4,i,Color(.9,.9,.9,1));image.set_pixel(19,i,Color(.9,.9,.9,1))
		image.set_pixel(i,4,Color(.9,.9,.9,1));image.set_pixel(i,19,Color(.9,.9,.9,1))
	image.fill_rect(Rect2i(10,10,4,4),Color(.95,.9,.8,1)) # Real ivory/metal must survive.
	var cleaned:Image=Filter.clean(image)
	var alpha_same:=true;var inside_same:=true
	for y in range(24):
		for x in range(24):
			alpha_same=alpha_same and image.get_pixel(x,y).a==cleaned.get_pixel(x,y).a
			if x>=7 and x<=16 and y>=7 and y<=16:inside_same=inside_same and image.get_pixel(x,y)==cleaned.get_pixel(x,y)
	verify.call(cleaned.get_pixel(4,8).r<.4 and cleaned.get_pixel(19,8).r<.4,"Opaque white matte on either silhouette edge is removed using nearby body colour")
	verify.call(alpha_same and inside_same,"Matte cleanup keeps every alpha sample and genuine opaque ivory/metal interior unchanged")
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CACHE))
	var exact:bool=manifest.frames.size()==208 and FileAccess.get_sha256("res://tools/viya_edge_filter.gd")==manifest.filter_sha256 and FileAccess.get_sha256("res://tools/build_viya_render_cache.gd")==manifest.generator_sha256
	for row in manifest.frames:exact=exact and FileAccess.get_sha256(row.source)==row.source_sha256 and FileAccess.get_sha256(row.output)==row.sha256
	verify.call(exact,"All208prebuilt render frames match their original PNG hashes and the current offline filter/generator")
	var timing:=Frames.get_animation_names().size()==32;var alpha:=true
	for animation in Source.get_animation_names():
		timing=timing and Frames.get_frame_count(animation)==Source.get_frame_count(animation) and Frames.get_animation_speed(animation)==Source.get_animation_speed(animation) and Frames.get_animation_loop(animation)==Source.get_animation_loop(animation)
		for index in range(Source.get_frame_count(animation)):
			var texture:Texture2D=Frames.get_frame_texture(animation,index)
			timing=timing and Frames.get_frame_duration(animation,index)==Source.get_frame_duration(animation,index)
			var pixels:Image=texture.get_image()
			alpha=alpha and texture.get_size()==Vector2(200,248) and pixels.get_pixel(0,0).a==0 and pixels.get_pixel(199,247).a==0
	verify.call(timing and alpha,"All32poses retain native order/count/timing while208display textures have transparent full-resolution200x248 canvases")
	for direction in ["e","w"]:
		var source:Texture2D=Source.get_frame_texture("run_"+direction,0)
		var raw:=Image.new();raw.load_png_from_buffer(FileAccess.get_file_as_bytes(source.resource_path))
		var expected:Image=Filter.prepare(raw)
		var actual:Image=Frames.get_frame_texture("run_"+direction,0).get_image()
		var visible_same:=true
		for y in range(248):
			for x in range(200):
				var a:Color=actual.get_pixel(x,y);var b:Color=expected.get_pixel(x,y)
				visible_same=visible_same and a.a==b.a and (a.a==0 or a==b)
		verify.call(visible_same,"Imported left/right display pixels reproduce edge filtering at full resolution without stale white-border imports:"+direction)
