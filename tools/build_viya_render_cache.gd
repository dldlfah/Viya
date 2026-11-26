extends SceneTree
## Reproducible render derivatives only; canonical package and timing stay intact.
const Filter=preload("res://tools/viya_edge_filter.gd")
const GeneratedEdge=preload("res://tools/viya_generated_edge_override.gd")
const SOURCE="res://assets/characters/pilot_32/source_manifest.json"
const RAW="res://assets/characters/pilot_32/resources/viya_directional_motion.tres"
const OUTPUT="res://assets/characters/pilot_32/render_cache/viya_render_frames.tres"
func _initialize()->void:call_deferred("run")
func run()->void:
	var overrides:Dictionary=GeneratedEdge.load_validated()
	if not overrides.ok:
		push_error(str(overrides.error));quit(1);return
	var original:SpriteFrames=load(RAW)
	DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir())
	var rows:Array=[]
	for animation in original.get_animation_names():
		for index in range(original.get_frame_count(animation)):
			var source:Texture2D=original.get_frame_texture(animation,index)
			var image:=Image.new()
			if image.load_png_from_buffer(FileAccess.get_file_as_bytes(source.resource_path))!=OK:quit(1);return
			var overridden:bool=overrides.frames.has(source.resource_path)
			var prepared:Image=overrides.frames[source.resource_path].image if overridden else Filter.prepare(image)
			var output:String=OUTPUT.get_base_dir().path_join(source.resource_path.get_file())
			if prepared.save_png(output)!=OK:quit(1);return
			var row:Dictionary={"source":source.resource_path,"source_sha256":FileAccess.get_sha256(source.resource_path),"output":output,"sha256":FileAccess.get_sha256(output),"method":"higgsfield_edge_override" if overridden else "edge_filter"}
			if overridden:
				var validated:Dictionary=overrides.frames[source.resource_path]
				row.approved_output=validated.record.approved_output
				row.approved_output_sha256=validated.record.approved_output_sha256
				row.alpha_edge_normalization="godot_fix_alpha_edges"
				row.changed_visible_pixels=validated.changed_visible_pixels
				row.alpha_decreased_pixels=validated.alpha_decreased_pixels
				row.alpha_repair_mask_pixels=validated.alpha_repair_mask_pixels
				if validated.record.has("alpha_repair_mask_path"):
					row.alpha_repair_mask_path=validated.record.alpha_repair_mask_path
					row.alpha_repair_mask_sha256=validated.record.alpha_repair_mask_sha256
			rows.append(row)
	# Preserve stable source IDs/order/timing, pointing at display derivatives.
	var lines:PackedStringArray=[]
	for line in FileAccess.get_file_as_string(RAW).split("\n"):
		if line.begins_with("[ext_resource"):
			var path:String=line.get_slice('path="',1).get_slice('"',0)
			line=line.replace(path,path.get_file())
		lines.append(line)
	var resource_file=FileAccess.open(OUTPUT,FileAccess.WRITE);resource_file.store_string("\n".join(lines));resource_file.close()
	var manifest={"schema":2,"source_manifest_sha256":FileAccess.get_sha256(SOURCE),"generator_sha256":FileAccess.get_sha256("res://tools/build_viya_render_cache.gd"),"filter_sha256":FileAccess.get_sha256("res://tools/viya_edge_filter.gd"),"override_helper_sha256":FileAccess.get_sha256("res://tools/viya_generated_edge_override.gd"),"edge_repair_manifest_sha256":overrides.manifest_sha256,"override_count":overrides.frames.size(),"logical_canvas":[200,248],"render_pixels":[200,248],"logical_size":[69,85.56],"frames":rows}
	var file=FileAccess.open(OUTPUT.get_base_dir().path_join("manifest.json"),FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n")
	print(JSON.stringify({"status":"PASS","frames":rows.size(),"overrides":overrides.frames.size(),"resource":OUTPUT}));quit()
