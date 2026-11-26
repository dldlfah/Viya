extends RefCounted
const Filter=preload("res://tools/viya_edge_filter.gd")
const GeneratedEdge=preload("res://tools/viya_generated_edge_override.gd")
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
	verify.call(GeneratedEdge.validate_pixels(image,cleaned).ok,"Validated generated edits may repair the narrow source silhouette band")
	var changed_alpha:Image=cleaned.duplicate();changed_alpha.set_pixel(4,8,Color(.2,.1,.1,.5))
	var changed_interior:Image=cleaned.duplicate();changed_interior.set_pixel(11,11,Color(.3,.2,.2,1))
	verify.call(not GeneratedEdge.validate_pixels(image,changed_alpha).ok,"Generated edge overrides reject alpha changes without an explicit repair mask")
	verify.call(not GeneratedEdge.validate_pixels(image,changed_interior).ok,"Generated edge overrides reject RGB changes beyond the source silhouette band")
	var residue_source:Image=image.duplicate();residue_source.set_pixel(11,11,Color8(235,232,230,240))
	var residue_mask:=Image.create(24,24,false,Image.FORMAT_L8)
	residue_mask.fill(Color.BLACK);residue_mask.set_pixel(11,11,Color.WHITE)
	var removed_residue:Image=residue_source.duplicate();removed_residue.set_pixel(11,11,Color8(235,232,230,0))
	var repair:Dictionary=GeneratedEdge.validate_pixels(residue_source,removed_residue,residue_mask)
	verify.call(repair.ok and repair.alpha_decreased_pixels==1 and repair.alpha_repair_mask_pixels==1,"Binary mask permits alpha reduction only for bright neutral source residue")
	var increased_alpha:Image=removed_residue.duplicate();increased_alpha.set_pixel(11,11,Color8(235,232,230,250))
	verify.call(not GeneratedEdge.validate_pixels(residue_source,increased_alpha,residue_mask).ok,"Even a valid residue mask cannot increase alpha")
	var outside_alpha:Image=removed_residue.duplicate();outside_alpha.set_pixel(8,10,Color(.2,.1,.1,0))
	verify.call(not GeneratedEdge.validate_pixels(residue_source,outside_alpha,residue_mask).ok,"Every alpha byte outside the explicit repair mask stays identical")
	var dark_mask:Image=residue_mask.duplicate();dark_mask.set_pixel(9,11,Color.WHITE)
	verify.call(not GeneratedEdge.validate_pixels(residue_source,removed_residue,dark_mask).ok,"Alpha repair masks cannot erase darker source character pixels")
	var nonbinary_mask:Image=residue_mask.duplicate();nonbinary_mask.set_pixel(11,11,Color(.5,.5,.5))
	verify.call(not GeneratedEdge.validate_pixels(residue_source,removed_residue,nonbinary_mask).ok,"Alpha repair masks must be binary L8 images")
	var near_gap:Image=removed_residue.duplicate();near_gap.set_pixel(10,11,Color(.2,.1,.1,1))
	var far_gap:Image=near_gap.duplicate();far_gap.set_pixel(15,15,Color(.4,.3,.3,1))
	verify.call(GeneratedEdge.validate_pixels(residue_source,near_gap,residue_mask).ok and not GeneratedEdge.validate_pixels(residue_source,far_gap,residue_mask).ok,"RGB repair may extend three pixels around a validated gap mask while protected interior stays unchanged")
	var overrides:Dictionary=GeneratedEdge.load_validated()
	verify.call(overrides.ok,"Generated edge provenance validates E00-10 paths and hashes, canvas, restricted alpha masks and protected interior")
	if not overrides.ok:return
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CACHE))
	var exact:bool=manifest.get("schema")==2 and manifest.frames.size()==208 and FileAccess.get_sha256("res://tools/viya_edge_filter.gd")==manifest.filter_sha256 and FileAccess.get_sha256("res://tools/build_viya_render_cache.gd")==manifest.generator_sha256
	exact=exact and FileAccess.get_sha256("res://tools/viya_generated_edge_override.gd")==str(manifest.get("override_helper_sha256","")) and overrides.manifest_sha256==str(manifest.get("edge_repair_manifest_sha256","")) and overrides.frames.size()==int(manifest.get("override_count",-1))
	var recorded_overrides:int=0
	for row in manifest.frames:
		exact=exact and FileAccess.get_sha256(row.source)==row.source_sha256 and FileAccess.get_sha256(row.output)==row.sha256
		if overrides.frames.has(row.source):
			recorded_overrides+=1
			var record:Dictionary=overrides.frames[row.source].record
			exact=exact and row.get("method")=="higgsfield_edge_override" and row.get("approved_output")==record.approved_output and row.get("approved_output_sha256")==record.approved_output_sha256
			exact=exact and row.get("alpha_edge_normalization")=="godot_fix_alpha_edges"
			exact=exact and int(row.get("alpha_decreased_pixels",-1))==overrides.frames[row.source].alpha_decreased_pixels and int(row.get("alpha_repair_mask_pixels",-1))==overrides.frames[row.source].alpha_repair_mask_pixels
			if record.has("alpha_repair_mask_path"):
				exact=exact and row.get("alpha_repair_mask_path")==record.alpha_repair_mask_path and row.get("alpha_repair_mask_sha256")==record.alpha_repair_mask_sha256
			else:exact=exact and not row.has("alpha_repair_mask_path") and not row.has("alpha_repair_mask_sha256")
		else:exact=exact and row.get("method")=="edge_filter"
	exact=exact and recorded_overrides==overrides.frames.size()
	verify.call(exact,"All208prebuilt render frames match original PNG hashes and the current filter, generator and validated override provenance")
	var timing:=Frames.get_animation_names().size()==32;var alpha:=true
	var filtered_same:bool=true;var generated_same:bool=true
	var filtered_count:int=0;var generated_count:int=0
	for animation in Source.get_animation_names():
		timing=timing and Frames.get_frame_count(animation)==Source.get_frame_count(animation) and Frames.get_animation_speed(animation)==Source.get_animation_speed(animation) and Frames.get_animation_loop(animation)==Source.get_animation_loop(animation)
		for index in range(Source.get_frame_count(animation)):
			var texture:Texture2D=Frames.get_frame_texture(animation,index)
			timing=timing and Frames.get_frame_duration(animation,index)==Source.get_frame_duration(animation,index)
			var pixels:Image=texture.get_image()
			alpha=alpha and texture.get_size()==Vector2(200,248) and pixels.get_pixel(0,0).a==0 and pixels.get_pixel(199,247).a==0
			var source:Texture2D=Source.get_frame_texture(animation,index)
			var raw:=Image.new();var saved:=Image.new()
			var cache_path:String=CACHE.get_base_dir().path_join(source.resource_path.get_file())
			var loaded:bool=raw.load_png_from_buffer(FileAccess.get_file_as_bytes(source.resource_path))==OK and saved.load_png_from_buffer(FileAccess.get_file_as_bytes(cache_path))==OK
			if overrides.frames.has(source.resource_path):
				generated_count+=1
				var expected:Image=overrides.frames[source.resource_path].image
				generated_same=generated_same and loaded and saved.get_data()==expected.get_data() and _visible_same(pixels,expected)
			else:
				filtered_count+=1
				filtered_same=filtered_same and loaded and saved.get_data()==Filter.prepare(raw).get_data()
	verify.call(timing and alpha,"All32poses retain native order/count/timing while208display textures have transparent full-resolution200x248 canvases")
	verify.call(filtered_same and filtered_count==208-overrides.frames.size(),"Every non-overridden frame exactly reproduces the unchanged offline edge filter")
	verify.call(generated_same and generated_count==overrides.frames.size(),"Every validated generated frame reproduces its registered PNG after alpha-edge normalization in the cache and imported display texture")
	for direction in ["e","w"]:
		var source:Texture2D=Source.get_frame_texture("run_"+direction,0)
		var raw:=Image.new();raw.load_png_from_buffer(FileAccess.get_file_as_bytes(source.resource_path))
		var expected:Image=overrides.frames[source.resource_path].image if overrides.frames.has(source.resource_path) else Filter.prepare(raw)
		var actual:Image=Frames.get_frame_texture("run_"+direction,0).get_image()
		verify.call(_visible_same(actual,expected),"Imported left/right display pixels reproduce their validated full-resolution derivative without stale white-border imports:"+direction)

static func _visible_same(actual:Image,expected:Image)->bool:
	if actual==null or expected==null or actual.get_size()!=expected.get_size():return false
	for y in range(expected.get_height()):
		for x in range(expected.get_width()):
			var a:Color=actual.get_pixel(x,y);var b:Color=expected.get_pixel(x,y)
			if a.a!=b.a or (a.a>0 and a!=b):return false
	return true
