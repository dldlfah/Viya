extends SceneTree
func _initialize():
	var resource="res://assets/characters/pilot_32/render_cache/viya_render_frames.tres"
	var before=OS.get_static_memory_usage();var t=Time.get_ticks_usec()
	var a=load(resource);var first=(Time.get_ticks_usec()-t)/1000.0;var delta=OS.get_static_memory_usage()-before
	t=Time.get_ticks_usec();var b=load(resource);var repeated=(Time.get_ticks_usec()-t)/1000.0
	print(JSON.stringify({"first_load_ms":first,"repeat_load_ms":repeated,"same_resource":a==b,"static_memory_delta_bytes":delta,"animations":a.get_animation_names().size(),"scope":"Fresh OS process/resource cache, OS disk cache not flushed; tracked allocator delta, not total GPU memory."}));quit()
