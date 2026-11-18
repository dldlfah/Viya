extends RefCounted
## Optional textures/SpriteFrames, all blank in prototype data. No generated art.
var definitions: Dictionary = {}
var _resources := {}
func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation_slots.json"))
	if parsed is Dictionary:
		definitions = parsed
func texture(id: String, pose: String = "idle", clock: float = 0.0) -> Texture2D:
	var path: String = str(definitions.get(id,""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if not _resources.has(path):
		_resources[path] = load(path)
	var asset: Resource = _resources[path]
	if asset is Texture2D:
		return asset
	if asset is SpriteFrames:
		var animation: String = pose if asset.has_animation(pose) else "idle"
		if not asset.has_animation(animation) or asset.get_frame_count(animation) == 0:
			return null
		var frame: int = int(clock * asset.get_animation_speed(animation)) % asset.get_frame_count(animation)
		return asset.get_frame_texture(animation,frame)
	return null
