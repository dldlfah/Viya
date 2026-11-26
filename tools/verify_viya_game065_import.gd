extends SceneTree
## Compare the actual imported texture pixels against the delivered PNG bytes.
## This verifies lossless RGBA preservation, not visual/art approval.
func _initialize():
	var resource:SpriteFrames=load("res://assets/characters/pilot_32/game065_e_run_fire/viya_game065_frames.tres")
	var errors:Array=[]
	var frames:Array=[]
	for index in range(resource.get_frame_count("run_fire_e")):
		var texture:Texture2D=resource.get_frame_texture("run_fire_e",index)
		var imported:Image=texture.get_image()
		var original:=Image.new()
		var decoded:bool=original.load_png_from_buffer(FileAccess.get_file_as_bytes(texture.resource_path))==OK
		var setting:=ConfigFile.new()
		var setting_ok:bool=setting.load(texture.resource_path+".import")==OK
		setting_ok=setting_ok and setting.get_value("params","process/fix_alpha_border",true)==false
		if imported.is_compressed():imported.decompress()
		imported.convert(Image.FORMAT_RGBA8);original.convert(Image.FORMAT_RGBA8)
		var same:bool=decoded and imported.get_size()==Vector2i(200,248) and imported.get_data()==original.get_data()
		if not same or not setting_ok:errors.append(index)
		frames.append({"index":index,"path":texture.resource_path,"imported_rgba_bytes_equal_png":same,"alpha_border_fix_disabled":setting_ok})
	var result:Dictionary={"status":"PASS" if errors.is_empty() and not frames.is_empty() else "FAIL","errors":errors,"frames":frames,"frame_count":frames.size(),"engine":Engine.get_version_info(),"scope":"Actual Godot-imported RGBA pixels equal source PNG data; no transparent-edge color replacement by import."}
	var folder:="res://.local_validation/GAME065_INTEGRATION"
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder.path_join("import_report.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify({"status":result.status,"frames":frames.size(),"errors":errors}))
	quit(0 if result.status=="PASS" else 1)
