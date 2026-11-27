extends RefCounted
## Account-side Viya imprint rules and the inventory item's definition.
const SCHEMA := 1
const FIRST_STAR := 3
const LAST_STAR := 6
const IMPRINTS_PER_STAR := 5
const VIYA_SHARD := "viya_shard"
const ITEMS := {VIYA_SHARD: {"name": "비야의 조각", "description": "비야 전용 각인 재료"}}
const VIYA_IMPRINT_COSTS := {} # Per-star arrays of shard costs. Unset until the economy is decided.

static func empty() -> Dictionary:
	return {"viya": {"stars": FIRST_STAR, "imprints": 0}, "items": {}}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2 or not value.get("viya") is Dictionary or not value.get("items") is Dictionary:
		return false
	var viya: Dictionary = value.viya
	if viya.size() != 2 or not viya.get("stars") is int or not viya.get("imprints") is int:
		return false
	var max_imprints := IMPRINTS_PER_STAR if viya.stars == LAST_STAR else IMPRINTS_PER_STAR - 1
	if viya.stars < FIRST_STAR or viya.stars > LAST_STAR or viya.imprints < 0 or viya.imprints > max_imprints:
		return false
	for id in value.items:
		var count: Variant = value.items[id]
		if not ITEMS.has(id) or not count is int or count < 0:
			return false
	return true

static func is_complete(viya: Dictionary) -> bool:
	return viya.stars == LAST_STAR and viya.imprints == IMPRINTS_PER_STAR

static func shard_cost(viya: Dictionary) -> int:
	var costs: Array = VIYA_IMPRINT_COSTS.get(viya.stars, [])
	return costs[viya.imprints] if viya.imprints < costs.size() else 0

static func after_success(current: Dictionary, cost: int) -> Dictionary:
	if not valid(current) or cost <= 0 or is_complete(current.viya) or int(current.items.get(VIYA_SHARD, 0)) < cost:
		return {}
	var updated := current.duplicate(true)
	updated.items[VIYA_SHARD] -= cost
	updated.viya.imprints += 1
	if updated.viya.imprints == IMPRINTS_PER_STAR and updated.viya.stars < LAST_STAR:
		updated.viya.stars += 1
		updated.viya.imprints = 0
	return updated
