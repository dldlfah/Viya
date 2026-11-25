extends SceneTree
func read_png(path:String)->Image:
	var result:=Image.new()
	assert(result.load_png_from_buffer(FileAccess.get_file_as_bytes(path))==OK)
	return result
func _initialize()->void:
	var rows:Array=[]
	for index in range(11):
		var n:String="viya_run_e_%02d.png" % index
		var approved:Image=read_png("res://assets/characters/pilot_32/edge_repair/final/"+n)
		var expected:Image=approved.duplicate();expected.fix_alpha_edges()
		var repeat:Image=expected.duplicate();repeat.fix_alpha_edges()
		var cache:Image=read_png("res://assets/characters/pilot_32/render_cache/"+n)
		var texture:Texture2D=load("res://assets/characters/pilot_32/render_cache/"+n)
		var imported:Image=texture.get_image()
		var row:Dictionary={"name":n,"formats":[approved.get_format(),cache.get_format(),imported.get_format()],"cache_vs_expected_diff":0,"import_alpha_diff":0,"import_visible_rgb_diff":0,"import_transparent_rgb_diff":0,"prepare_alpha_diff":0,"repeat_prepare_visible_diff":0,"examples":[]}
		for y in range(248):
			for x in range(200):
				var a:Color=approved.get_pixel(x,y);var e:Color=expected.get_pixel(x,y);var r:Color=repeat.get_pixel(x,y);var c:Color=cache.get_pixel(x,y);var i:Color=imported.get_pixel(x,y)
				if e!=c:row.cache_vs_expected_diff+=1
				if a.a!=e.a:row.prepare_alpha_diff+=1
				if e.a>0 and e!=r:row.repeat_prepare_visible_diff+=1
				if e.a!=i.a:row.import_alpha_diff+=1
				if Vector3(e.r,e.g,e.b)!=Vector3(i.r,i.g,i.b):
					if e.a>0:row.import_visible_rgb_diff+=1
					else:row.import_transparent_rgb_diff+=1
					if e.a>0 and row.examples.size()<5:row.examples.append({"xy":[x,y],"expected":[e.r8,e.g8,e.b8,e.a8],"cache":[c.r8,c.g8,c.b8,c.a8],"imported":[i.r8,i.g8,i.b8,i.a8]})
		rows.append(row)
	print(JSON.stringify(rows))
	var exact:bool=true
	for row in rows:
		exact=exact and row.cache_vs_expected_diff==0 and row.import_alpha_diff==0 and row.import_visible_rgb_diff==0 and row.prepare_alpha_diff==0 and row.repeat_prepare_visible_diff==0
	print(JSON.stringify({"status":"PASS" if exact else "FAIL","frames":rows.size(),"scope":"Imported PNG pixel equality; not an actual display rendering test"}))
	quit(0 if exact else 1)
