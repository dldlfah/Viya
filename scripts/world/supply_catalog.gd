extends RefCounted
## Stateless supply definitions; the existing RunState owns damage, loot and RNG.
const PATH := "res://data/destructibles.json"
const DROP_CHANCE := 0.20
const RECOVERY_FRACTION := 0.30 # Provisional, before account HP healing efficiency.
const RESPAWN_SECONDS := 45.0 # Active combat time after each destruction.
const ITEM_KINDS := ["hp", "mp", "magnet", "purge"]
const ITEM_NAMES := {"hp": "체력 회복", "mp": "마나 회복", "magnet": "맵 전체 자석", "purge": "보스 제외 적 제거"}
const RADIUS := 24.0
const MAX_STRUCTURES := 64
var layouts: Dictionary = {}

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		layouts = parsed
		layouts["gold_slime"]=[] # No campaign supply/respawn changes in this mode.
	var catalog=preload("res://scripts/world/map_catalog.gd").new()
	layouts[catalog.BATTLEFIELD_ID]=catalog.battlefield.get("destructibles")

func create(map_id: String, space) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var layout: Variant = layouts.get(map_id)
	if not valid_layout(layout, space):
		return result
	for index in range(layout.size()):
		var entry: Dictionary = layout[index]
		result.append({"id": -index - 2, "p": Vector2(entry.p[0], entry.p[1]),
			"style": entry.style, "hp": int(entry.hp), "max_hp": int(entry.hp),
			"generation": 0, "respawn_left": 0.0})
	return result

static func valid_layout(layout: Variant, space) -> bool:
	if not layout is Array or layout.size() > MAX_STRUCTURES:
		return false
	var positions: Array[Vector2] = []
	for entry in layout:
		if not entry is Dictionary or entry.get("style") not in ["crate", "urn", "debris"] or not entry.get("hp") is float or entry.hp != floor(entry.hp) or entry.hp < 1 or entry.hp > 10000:
			return false
		if not entry.get("p") is Array or entry.p.size() != 2 or not entry.p.all(func(v): return (v is float or v is int) and is_finite(v)):
			return false
		var at := Vector2(entry.p[0], entry.p[1])
		if not space.valid_position(at, RADIUS) or at.distance_to(space.start) < 90.0 or positions.any(func(p): return p.distance_to(at) < RADIUS * 2.0):
			return false
		positions.append(at)
	return true

static func item_for_roll(drop_roll: float, kind_roll: float) -> String:
	if drop_roll >= DROP_CHANCE:
		return ""
	if kind_roll < 0.40:
		return "hp"
	if kind_roll < 0.80:
		return "mp"
	return "magnet" if kind_roll < 0.90 else "purge"

static func roll_item(generator: RandomNumberGenerator) -> String:
	var roll := generator.randf()
	return item_for_roll(roll, generator.randf()) if roll < DROP_CHANCE else ""
