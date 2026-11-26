extends RefCounted
## Fixed-foot, nonmirrored actor frames. Optional art, never a gameplay clock.
var specs:Dictionary={}
var _checked:Dictionary={}

func _init() -> void:
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_presentation.json"))
	if parsed is Dictionary and parsed.get("schema_version")==1:specs=parsed

static func pair(value:Variant, low:float, high:float) -> bool:
	return value is Array and value.size()==2 and value.all(func(v):return (v is int or v is float) and is_finite(v) and v>=low and v<=high)

func spec_for(id:String) -> Dictionary:
	var listing:Variant=specs.get("actors",{})
	if not listing is Dictionary:return {}
	var spec:Variant=listing.get(id,specs.get("defaults",{}))
	if not spec is Dictionary or not pair(spec.get("size"),1,512) or not pair(spec.get("pivot"),0,1) or not pair(spec.get("canvas"),0,8192):return {}
	if (spec.canvas[0]==0)!=(spec.canvas[1]==0):return {}
	if spec.has("reference_view_height"):
		var reference:Variant=spec.reference_view_height
		if str(id)!="viya_battle" or not (reference is int or reference is float) or not is_finite(reference) or reference<1 or reference>16384:return {}
	return spec

func consistent(asset:Resource, canvas:Vector2) -> bool:
	var key:String=str(asset.get_instance_id())+str(canvas)
	if _checked.has(key):return _checked[key]
	var textures:Array=[]
	if asset is Texture2D:textures.append(asset)
	elif asset is SpriteFrames:
		for animation in asset.get_animation_names():
			for index in range(asset.get_frame_count(animation)):textures.append(asset.get_frame_texture(animation,index))
	var expected:Vector2=canvas
	var valid:bool=not textures.is_empty()
	for texture in textures:
		if not texture is Texture2D:
			valid=false
			break
		if expected==Vector2.ZERO:expected=texture.get_size()
		if texture.get_size()!=expected:valid=false
	_checked[key]=valid
	return valid

func frame(slots, candidates:Array, pose:String, direction:String, clock:float, viewport:Vector2=Vector2.ZERO) -> Dictionary:
	if not is_finite(clock):return {}
	for id in candidates:
		var asset:Resource=slots.resource(str(id))
		if not asset is Texture2D and not asset is SpriteFrames:continue
		var spec:Dictionary=spec_for(str(id))
		if spec.is_empty() or not consistent(asset,Vector2(spec.canvas[0],spec.canvas[1])):continue
		var texture:Texture2D
		var animation:String="texture"
		var index:=0
		if asset is Texture2D:texture=asset
		else:
			# Identity wins over a generic actor. Missing west never mirrors east.
			for name in [pose+"_"+direction,pose,"idle_"+direction,"idle","default"]:
				if not asset.has_animation(name) or asset.get_frame_count(name)==0:continue
				animation=name
				var total:=0.0
				for i in range(asset.get_frame_count(name)):total+=asset.get_frame_duration(name,i)
				var tick:float=maxf(0,clock)*asset.get_animation_speed(name)
				if asset.get_animation_loop(name) and total>0:tick=fmod(tick,total)
				index=asset.get_frame_count(name)-1
				for i in range(asset.get_frame_count(name)):
					if tick<asset.get_frame_duration(name,i):
						index=i
						break
					tick-=asset.get_frame_duration(name,i)
				texture=asset.get_frame_texture(name,index)
				break
		if texture:
			var draw_size:=Vector2(spec["size"][0],spec["size"][1])
			if spec.has("reference_view_height") and viewport.is_finite() and viewport.y>0:
				# Keep the silhouette proportional to battle space, capped at source pixels.
				var native:Vector2=texture.get_size()/draw_size
				draw_size*=minf(viewport.y/float(spec.reference_view_height),minf(native.x,native.y))
			return {"texture":texture,"slot":str(id),"animation":animation,"index":index,"size":draw_size,"pivot":Vector2(spec.pivot[0],spec.pivot[1])}
	return {}

static func rectangle(sample:Dictionary, feet:Vector2) -> Rect2:
	return Rect2(feet-sample["size"]*sample.pivot,sample["size"])
