extends RefCounted
## Pickup flags are authoritative; trails are reconstructed from position/target.
const MIN_SPEED := 1000.0
const DISTANCE_GAIN := 3.0
const MAX_SPEED := 7200.0

static func activate(pickups: Array) -> int:
	for pickup in pickups:
		pickup["magnet"] = true
	return pickups.size()

static func move(pickup: Dictionary, target: Vector2, radius: float, dt: float) -> Vector2:
	var at: Vector2 = pickup.p
	if pickup.get("magnet", false):
		return at.move_toward(target, clampf(at.distance_to(target) * DISTANCE_GAIN, MIN_SPEED, MAX_SPEED) * dt)
	return at.move_toward(target, 420.0 * dt) if at.distance_squared_to(target) <= radius * radius else at

static func valid(pickup: Dictionary, version: int) -> bool:
	return not pickup.has("magnet") or (version == 1 and pickup.magnet is bool and pickup.magnet == true)

static func draw_trail(canvas, pickup: Dictionary, target: Vector2, gold: bool) -> void:
	if not pickup.get("magnet", false):
		return
	var at: Vector2 = pickup.p
	var direction := at.direction_to(target)
	var tint := Color("f7cd69") if gold else Color("8ce4d5")
	# Three short strokes per visible pickup; no nodes, emitters or global lines.
	canvas.draw_line(at - direction * 30.0, at - direction * 7.0, Color(tint, 0.28), 4.0, true)
	canvas.draw_line(at - direction * 20.0, at, Color(tint, 0.8), 2.0, true)
	canvas.draw_circle(at, 8.0, Color(tint, 0.18))
