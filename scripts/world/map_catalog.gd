extends RefCounted
const PATH := "res://data/maps.json"
const BATTLEFIELD_PATH := "res://data/campaign_battlefield.json"
const BATTLEFIELD_ID := "siege_battlefield"
var data: Dictionary = {}
var battlefield: Dictionary = {}
func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		data = parsed
	var stage_map:Variant=JSON.parse_string(FileAccess.get_file_as_string(BATTLEFIELD_PATH))
	if stage_map is Dictionary and stage_map.get("schema_version")==1 and stage_map.get("map_id")==BATTLEFIELD_ID:
		battlefield=stage_map
func definition(id: String) -> Dictionary:
	var found: Variant = preload("res://scripts/combat/gold_dungeon.gd").new().data.get("map") if id=="gold_slime" else (battlefield.get("map") if id==BATTLEFIELD_ID else data.get(id))
	return found.duplicate(true) if valid(found) else {}
static func pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and value.all(func(v): return (v is float or v is int) and is_finite(v))
static func rect(value: Variant) -> bool:
	return value is Array and value.size() == 4 and value.all(func(v): return (v is float or v is int) and is_finite(v)) and value[2] > 0 and value[3] > 0
static func rectangle(value: Array) -> Rect2:
	return Rect2(value[0], value[1], value[2], value[3])
static func valid(value: Variant) -> bool:
	if not value is Dictionary or not pair(value.get("size")) or not pair(value.get("start")) or not rect(value.get("camera")) or not rect(value.get("walkable")):
		return false
	var size := Vector2(value["size"][0], value["size"][1])
	if size.x < 1800 or size.y < 1200 or size.x > 20000 or size.y > 20000:
		return false
	var bounds := Rect2(Vector2.ZERO, size)
	var start := Vector2(value.start[0], value.start[1])
	if not bounds.grow(-30).has_point(start) or not bounds.encloses(rectangle(value.camera)) or not bounds.encloses(rectangle(value.walkable)) or not rectangle(value.walkable).grow(-30).has_point(start):
		return false
	if value.get("mode") not in ["legacy", "frontline", "perimeter"] or not value.get("name") is String:
		return false
	if not value.get("obstacles") is Array or value.obstacles.size() > 24 or not value.get("zones") is Array or value.zones.is_empty():
		return false
	for obstacle in value.obstacles:
		if not obstacle is Dictionary or not rect(obstacle.get("rect")) or not obstacle.get("solid") is bool or not bounds.encloses(rectangle(obstacle.rect)):
			return false
		if obstacle.solid and rectangle(obstacle.rect).grow(30).has_point(start):
			return false
	for zone in value.zones:
		if not zone is Dictionary or not rect(zone.get("rect")) or not bounds.encloses(rectangle(zone.rect)) or zone.get("side") not in ["front", "left", "right", "all"]:
			return false
		if not zone.get("from") is float or zone.from < 0 or zone.from > 36000 or not zone.get("roles") is Array or zone.roles.is_empty():
			return false
		if not zone.get("weights") is Array or zone.weights.is_empty():
			return false
		var previous := -1.0
		for item in zone.weights:
			if not item is Dictionary or not item.get("from") is float or not item.get("weight") is float or not is_finite(item.from) or not is_finite(item.weight) or item.from <= previous or item.from < 0 or item.from > 36000 or item.weight <= 0 or item.weight > 1000:
				return false
			previous = item.from
		if zone.weights[0].from != 0.0:
			return false
		for role in zone.roles:
			if role not in ["normal", "elite", "boss"]:
				return false
	return true
