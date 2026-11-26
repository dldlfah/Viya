extends RefCounted
## Optional shared textures/SpriteFrames and separate map pilot overrides.
var definitions: Dictionary = {}
var map_definitions: Dictionary = {}
var _resources := {}
func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation_slots.json"))
	if parsed is Dictionary:
		definitions = parsed
	var maps:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/map_presentation_slots.json"))
	if maps is Dictionary:map_definitions=maps

func map_texture(id:String,map_id:String) -> Texture2D:
	var slots:Variant=map_definitions.get(map_id,{})
	var path:Variant=slots.get(id,"") if slots is Dictionary else ""
	if path is String and not path.is_empty() and ResourceLoader.exists(path):
		if not _resources.has(path):_resources[path]=load(path)
		var asset:Resource=_resources[path]
		if asset is Texture2D:return asset
	return texture(id)

func resource(id: String) -> Resource:
	var value:Variant=definitions.get(id,"")
	if not value is String:return null
	var path:String=value
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if not _resources.has(path):
		_resources[path] = load(path)
	return _resources[path]

func texture(id: String, pose: String = "idle", clock: float = 0.0) -> Texture2D:
	var asset:Resource=resource(id)
	if asset is Texture2D:
		return asset
	if asset is SpriteFrames:
		var animation: String = pose if asset.has_animation(pose) else "idle"
		if not asset.has_animation(animation) or asset.get_frame_count(animation) == 0:
			return null
		var frame: int = int(clock * asset.get_animation_speed(animation)) % asset.get_frame_count(animation)
		return asset.get_frame_texture(animation,frame)
	return null
