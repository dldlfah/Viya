extends RefCounted
## Bounded presentation data. Receives committed events; never owns gameplay or RNG.
const MAX_EVENTS := 48
const MAX_FLASHES := 80
const FLASH_SECONDS := 0.12
const HIT_SECONDS := 0.50
const KILL_SECONDS := 0.35
const XP_SECONDS := 0.70
const HIT_MERGE_WINDOW := 0.06
const XP_MERGE_WINDOW := 0.10
var enabled: bool = true
var events: Array[Dictionary] = []
var flashes: Dictionary = {}

func reset() -> void:
	events.clear()
	flashes.clear()

func set_enabled(value: bool) -> void:
	# Diagnostic switch: no influence on the authoritative simulation.
	enabled = value
	if not enabled:
		reset()

func record_hit(id: int, at: Vector2, hp_lost: int, critical: bool) -> void:
	if not enabled or hp_lost <= 0:
		return
	if not flashes.has(id) and flashes.size() >= MAX_FLASHES:
		flashes.erase(flashes.keys()[0])
	flashes[id] = FLASH_SECONDS
	# Shotgun pellets on one target share a short number, not a node per pellet.
	var recent: Dictionary = _recent("hit", id, HIT_MERGE_WINDOW)
	if not recent.is_empty():
		recent["amount"] += hp_lost
		recent["critical"] = bool(recent["critical"]) or critical
		recent["p"] = at
		recent["life"] = HIT_SECONDS
		return
	_push("hit", id, at, float(hp_lost), critical, HIT_SECONDS)

func record_kill(id: int, at: Vector2) -> void:
	if not enabled:
		return
	flashes.erase(id)
	_push("kill", id, at, 0.0, false, KILL_SECONDS)

func record_collected_xp(at: Vector2, amount: float) -> void:
	if not enabled or amount <= 0.0 or not is_finite(amount):
		return
	var recent: Dictionary = _recent("xp", 0, XP_MERGE_WINDOW)
	if not recent.is_empty():
		recent["amount"] += amount
		recent["p"] = at
		recent["life"] = XP_SECONDS
		return
	_push("xp", 0, at, amount, false, XP_SECONDS)

func _recent(kind: String, id: int, window: float) -> Dictionary:
	for i in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[i]
		if event["kind"] == kind and int(event["id"]) == id:
			if float(event["duration"]) - float(event["life"]) <= window:
				return event
			break
	return {}

func _push(kind: String, id: int, at: Vector2, amount: float, critical: bool, duration: float) -> void:
	if events.size() >= MAX_EVENTS:
		events.pop_front() # Drop only an old visual; never damage or XP rewards.
	events.append({"kind": kind, "id": id, "p": at, "amount": amount,
		"critical": critical, "life": duration, "duration": duration})

func advance(delta: float) -> void:
	# RunState calls this once, after its RUNNING guard, with simulation delta.
	if not enabled or delta <= 0.0 or not is_finite(delta):
		return
	for id in flashes.keys():
		var remaining: float = maxf(0.0, float(flashes[id]) - delta)
		if remaining <= 0.0:
			flashes.erase(id)
		else:
			flashes[id] = remaining
	for i in range(events.size() - 1, -1, -1):
		events[i]["life"] = maxf(0.0, float(events[i]["life"]) - delta)
		if float(events[i]["life"]) <= 0.0:
			events.remove_at(i)

func flash_alpha(id: int) -> float:
	if not enabled:
		return 0.0
	return clampf(float(flashes.get(id, 0.0)) / FLASH_SECONDS, 0.0, 1.0)

func snapshot() -> Dictionary:
	return {"events": events.duplicate(true), "flashes": flashes.duplicate(true)}
