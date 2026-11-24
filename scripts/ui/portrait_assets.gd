extends RefCounted
## Four optional expressions, independent of the existing shared 53 art slots.
const PATH := "res://data/portrait_presentation.json"
const EXPRESSIONS := ["normal", "hurt", "heal", "levelup"]
var definitions: Dictionary = {}
var _loaded: Dictionary = {}
var legacy

func _init(adapter = null) -> void:
	legacy = adapter if adapter != null else preload("res://scripts/ui/asset_slots.gd").new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if valid_data(parsed):
		definitions = parsed.viya.duplicate(true)

static func valid_data(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema_version") != 1 or not value.get("viya") is Dictionary:
		return false
	if value.viya.size() != EXPRESSIONS.size():
		return false
	for key in EXPRESSIONS:
		if not value.viya.get(key) is String:
			return false
		if not value.viya[key].is_empty() and not value.viya[key].begins_with("res://"):
			return false
	return true

func _texture(path: String, expression: String) -> Texture2D:
	if path.is_empty() or not path.begins_with("res://"):
		return null
	if not _loaded.has(path):
		_loaded[path] = load(path) if ResourceLoader.exists(path) else null
	var resource: Resource = _loaded[path]
	if resource is Texture2D:
		return resource
	if resource is SpriteFrames:
		var pose: String = expression if resource.has_animation(expression) else "idle"
		if resource.has_animation(pose) and resource.get_frame_count(pose) > 0:
			return resource.get_frame_texture(pose, 0)
	return null

func resolve(expression: String) -> Dictionary:
	var key: String = expression if expression in EXPRESSIONS else "normal"
	var texture: Texture2D = _texture(str(definitions.get(key, "")), key)
	if texture != null:
		return {"texture":texture, "exact":true, "key":key}
	var shared: Resource = legacy.resource("viya_portrait")
	if shared is SpriteFrames and shared.has_animation(key) and shared.get_frame_count(key) > 0:
		return {"texture":shared.get_frame_texture(key, 0), "exact":true, "key":key}
	texture = _texture(str(definitions.get("normal", "")), "normal")
	if texture == null:
		texture = legacy.texture("viya_portrait", key)
	return {"texture":texture, "exact":key == "normal" and texture != null, "key":key}
