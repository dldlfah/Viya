extends RefCounted
## Prototype data, NOT final content/balance approval. Runtime rejects malformed pools.
const DATA_PATH := "res://data/prototype_skills.json"
var common: Array[Dictionary] = []
var characters: Dictionary = {}
var error: String = ""

func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary:
		error = "Invalid skill catalog JSON"
		return
	for entry in parsed.get("common", []):
		if entry is Dictionary:
			common.append(entry.duplicate(true))
	characters = parsed.get("characters", {}).duplicate(true)

func pool_for(character_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not error.is_empty() or not characters.has(character_id):
		return result
	for entry in common:
		result.append(entry.duplicate(true))
	for entry in characters[character_id].get("skills", []):
		result.append(entry.duplicate(true))
	return result

func validate_pool(pool: Array[Dictionary], character_id: String) -> bool:
	if pool.size() != 18:
		return false
	var ids: Dictionary = {}
	var counts := {"attack": 0, "passive": 0, "character": 0, "ultimate": 0}
	for entry in pool:
		var id: String = entry.get("id", "")
		var kind: String = entry.get("kind", "")
		var owner: String = entry.get("owner", "")
		if id.is_empty() or ids.has(id) or not counts.has(kind):
			return false
		if int(entry.get("max_level", 0)) < 1 or not entry.get("prototype", false):
			return false
		if kind in ["character", "ultimate"]:
			if owner != character_id:
				return false
		elif not owner.is_empty():
			return false
		if kind == "passive" and str(entry.get("effect", "")).contains("resist"):
			return false
		if not str(entry.get("name", "")).begins_with("[임시] "):
			return false
		ids[id] = true
		counts[kind] += 1
	return counts == {"attack": 8, "passive": 8, "character": 1, "ultimate": 1}
