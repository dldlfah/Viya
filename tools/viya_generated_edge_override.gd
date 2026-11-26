extends RefCounted
## Validated offline artwork derivatives only. Canonical PNGs never change.
const MANIFEST="res://assets/characters/pilot_32/edge_repair/manifest.json"
const SOURCE_ROOT="res://assets/characters/pilot_32/frames/"
const OUTPUT_ROOT="res://assets/characters/pilot_32/edge_repair/final/"
const MASK_ROOT="res://assets/characters/pilot_32/edge_repair/alpha_masks/"
const FRAME_COUNT=11
const RADIUS=3
const TRANSPARENT_THRESHOLD=16
const ALPHA_REPAIR_MIN_RGB=200
const ALPHA_REPAIR_MAX_RGB_RANGE=35

static func rejected(message:String)->Dictionary:
	return {"ok":false,"error":message,"enabled":false,"frames":{}}

## RGB edits may touch the source silhouette band, a validated white-residue mask
## and its radius-3 neighbourhood, or fully transparent padding.
## The band is a square (Chebyshev) radius around source alpha <16, including
## the transparent area outside the canvas. Alpha may only decrease inside an
## explicit binary mask over bright neutral source pixels. All other alpha and
## protected interior RGB must match the source.
static func validate_pixels(source:Image,candidate:Image,alpha_repair_mask:Image=null)->Dictionary:
	if source==null or candidate==null or source.is_empty() or candidate.is_empty():
		return rejected("Source or validated image is empty")
	if source.get_size()!=candidate.get_size():
		return rejected("Validated image changed the source canvas")
	var original:Image=source.duplicate();original.convert(Image.FORMAT_RGBA8)
	var result:Image=candidate.duplicate();result.convert(Image.FORMAT_RGBA8)
	var before:PackedByteArray=original.get_data();var after:PackedByteArray=result.get_data()
	var width:int=original.get_width();var height:int=original.get_height()
	var mask:PackedByteArray=[]
	if alpha_repair_mask!=null:
		if alpha_repair_mask.is_empty() or alpha_repair_mask.get_size()!=original.get_size() or alpha_repair_mask.get_format()!=Image.FORMAT_L8:
			return rejected("Alpha repair mask must be a same-canvas L8 grayscale PNG")
		mask=alpha_repair_mask.get_data()
	var changed_visible:int=0;var decreased_alpha:int=0;var masked_pixels:int=0
	for y in range(height):
		for x in range(width):
			var at:int=(y*width+x)*4
			var masked:bool=not mask.is_empty() and mask[y*width+x]==255
			if not mask.is_empty() and mask[y*width+x]!=0 and mask[y*width+x]!=255:
				return rejected("Alpha repair mask must contain only 0 and 255")
			if masked:
				var low:int=mini(before[at],mini(before[at+1],before[at+2]))
				var high:int=maxi(before[at],maxi(before[at+1],before[at+2]))
				if before[at+3]<=TRANSPARENT_THRESHOLD or low<ALPHA_REPAIR_MIN_RGB or high-low>ALPHA_REPAIR_MAX_RGB_RANGE:
					return rejected("Alpha repair mask is outside bright neutral source residue at %s,%s" % [x,y])
				masked_pixels+=1
			if before[at+3]!=after[at+3]:
				if not masked:return rejected("Validated image changed source alpha outside its repair mask at %s,%s" % [x,y])
				if after[at+3]>before[at+3]:return rejected("Validated image increased source alpha at %s,%s" % [x,y])
				decreased_alpha+=1
			if before[at+3]==0 or (before[at]==after[at] and before[at+1]==after[at+1] and before[at+2]==after[at+2]):continue
			var edge:bool=false
			for dy in range(-RADIUS,RADIUS+1):
				for dx in range(-RADIUS,RADIUS+1):
					var px:int=x+dx;var py:int=y+dy
					if px<0 or py<0 or px>=width or py>=height or before[(py*width+px)*4+3]<TRANSPARENT_THRESHOLD or (not mask.is_empty() and mask[py*width+px]==255):
						edge=true;break
				if edge:break
			if not edge:
				return rejected("Validated image changed protected interior RGB at %s,%s" % [x,y])
			changed_visible+=1
	return {"ok":true,"changed_visible_pixels":changed_visible,"alpha_decreased_pixels":decreased_alpha,"alpha_repair_mask_pixels":masked_pixels}

## Missing manifest preserves the existing filter-only workflow. An existing but
## incomplete/invalid manifest is an error, never a silent fallback. Preflight all
## eleven frames before the builder writes any render-cache output.
static func load_validated()->Dictionary:
	if not FileAccess.file_exists(MANIFEST):
		return {"ok":true,"enabled":false,"frames":{},"manifest_sha256":""}
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if typeof(parsed)!=TYPE_DICTIONARY:return rejected("Edge repair manifest is not a JSON object")
	var manifest:Dictionary=parsed
	if manifest.get("schema")!=1 or manifest.get("status")!="validated" or manifest.get("service")!="Higgsfield":
		return rejected("Edge repair manifest requires schema 1, status validated, service Higgsfield")
	var canvas_value:Variant=manifest.get("canvas")
	if typeof(canvas_value)!=TYPE_ARRAY:return rejected("Edge repair canvas must remain 200x248")
	var canvas:Array=canvas_value
	if canvas.size()!=2 or typeof(canvas[0]) not in [TYPE_INT,TYPE_FLOAT] or typeof(canvas[1]) not in [TYPE_INT,TYPE_FLOAT]:
		return rejected("Edge repair canvas must contain two numeric dimensions")
	# JSON numbers decode as floats; compare numeric values, not typed Array identity.
	if float(canvas[0])!=200.0 or float(canvas[1])!=248.0:return rejected("Edge repair canvas must remain 200x248")
	var band_value:Variant=manifest.get("edit_band")
	if typeof(band_value)!=TYPE_DICTIONARY:return rejected("Edge repair edit_band is missing")
	var band:Dictionary=band_value
	if band.get("kind")!="source_alpha_neighborhood" or band.get("radius_px")!=RADIUS or band.get("transparent_threshold")!=TRANSPARENT_THRESHOLD:
		return rejected("Edge repair requires the fixed radius-3, alpha<16 source silhouette band")
	var rows_value:Variant=manifest.get("frames")
	if typeof(rows_value)!=TYPE_ARRAY:return rejected("Edge repair frames must be an array")
	var rows:Array=rows_value
	if rows.size()!=FRAME_COUNT:return rejected("Edge repair requires all eleven E run frames")
	var allowed:Dictionary={}
	for index in range(FRAME_COUNT):
		var filename:String="viya_run_e_%02d.png" % index
		allowed[SOURCE_ROOT+filename]=OUTPUT_ROOT+filename
	var validated:Dictionary={}
	for value in rows:
		if typeof(value)!=TYPE_DICTIONARY:return rejected("Edge repair frame is not an object")
		var row:Dictionary=value
		var source_path:String=str(row.get("source",""))
		var output_path:String=str(row.get("approved_output",""))
		if row.get("status")!="validated" or not allowed.has(source_path) or validated.has(source_path):
			return rejected("Edge repair frame is unvalidated, duplicated, or outside E run00-10: "+source_path)
		if output_path!=allowed[source_path]:return rejected("Unexpected validated output path: "+output_path)
		if not FileAccess.file_exists(source_path) or not FileAccess.file_exists(output_path):
			return rejected("Missing edge repair input or validated PNG: "+source_path)
		if FileAccess.get_sha256(source_path)!=str(row.get("source_sha256","")):
			return rejected("Canonical source hash mismatch: "+source_path)
		if FileAccess.get_sha256(output_path)!=str(row.get("approved_output_sha256","")):
			return rejected("Validated output hash mismatch: "+output_path)
		var source:=Image.new();var candidate:=Image.new()
		if source.load_png_from_buffer(FileAccess.get_file_as_bytes(source_path))!=OK or candidate.load_png_from_buffer(FileAccess.get_file_as_bytes(output_path))!=OK:
			return rejected("Could not decode edge repair PNGs: "+source_path)
		if source.get_size()!=Vector2i(200,248):return rejected("Canonical runtime PNG must remain 200x248: "+source_path)
		var alpha_repair_mask:Image=null
		if row.has("alpha_repair_mask_path") or row.has("alpha_repair_mask_sha256"):
			var mask_path:String=str(row.get("alpha_repair_mask_path",""))
			if mask_path!=MASK_ROOT+source_path.get_file():return rejected("Unexpected alpha repair mask path: "+mask_path)
			if not FileAccess.file_exists(mask_path) or FileAccess.get_sha256(mask_path)!=str(row.get("alpha_repair_mask_sha256","")):
				return rejected("Missing alpha repair mask or hash mismatch: "+mask_path)
			alpha_repair_mask=Image.new()
			if alpha_repair_mask.load_png_from_buffer(FileAccess.get_file_as_bytes(mask_path))!=OK:
				return rejected("Could not decode alpha repair mask: "+mask_path)
		var check:Dictionary=validate_pixels(source,candidate,alpha_repair_mask)
		if not check.ok:return rejected(source_path+": "+str(check.error))
		# Match the existing Godot texture import step before writing the cache.
		# This also pads the newly opened gaps; the same source/mask restrictions
		# are checked again so import normalization cannot alter protected artwork.
		candidate.fix_alpha_edges()
		check=validate_pixels(source,candidate,alpha_repair_mask)
		if not check.ok:return rejected(source_path+" after alpha-edge normalization: "+str(check.error))
		validated[source_path]={"image":candidate,"record":row,"changed_visible_pixels":check.changed_visible_pixels,"alpha_decreased_pixels":check.alpha_decreased_pixels,"alpha_repair_mask_pixels":check.alpha_repair_mask_pixels}
	return {"ok":true,"enabled":true,"frames":validated,"manifest_sha256":FileAccess.get_sha256(MANIFEST)}
