extends RefCounted
## Fixed camera azimuth at world scale. Hero sizing is a separate billboard.
const Ground = preload("res://scripts/combat/battle_projection.gd")
const YAW := -PI / 10.0 # -18 degrees; fixed, never turns with movement.
const GROUND_Y := 0.8191520442889918 # sin(55 degrees)
static var _viewport := Vector2.ZERO
static var _basis := Transform2D.IDENTITY

static func basis(viewport: Vector2) -> Transform2D:
	if viewport == _viewport:return _basis
	var raw := Transform2D(Vector2(cos(YAW),sin(YAW)*GROUND_Y),Vector2(-sin(YAW),cos(YAW)*GROUND_Y),Vector2.ZERO)
	# Do not zoom the entire battlefield to fit the old unrotated envelope.
	# Spawn protection and map clamping use the actual inverse viewport below.
	_basis=raw
	_viewport=viewport
	return _basis

static func transform(center: Vector2, viewport: Vector2) -> Transform2D:
	var result := basis(viewport)
	result.origin=viewport*.5-result*center
	return result

static func visible_world(center: Vector2, viewport: Vector2) -> Rect2:
	return transform(center,viewport).affine_inverse()*Rect2(Vector2.ZERO,viewport)

static func world_view_size(viewport: Vector2) -> Vector2:
	return visible_world(Vector2.ZERO,viewport).size

static func keep_player_visible(player: Vector2, center: Vector2, viewport: Vector2) -> Vector2:
	# At a map corner, a rotated rectangle cannot both stay in map bounds and
	# contain the player. Prefer a fully visible hero over clipping her at the HUD.
	var screen:Vector2=transform(center,viewport)*player
	var margin:Vector2=Vector2(minf(128,viewport.y*.16),viewport.y*.36)
	var safe:Vector2=screen.clamp(margin,viewport-Vector2(margin.x,minf(48,viewport.y*.08)))
	return center+basis(viewport).affine_inverse()*(screen-safe)

static func depth(at: Vector2) -> float:
	return at.x*sin(YAW)+at.y*cos(YAW)

static func screen_direction(direction: Vector2, viewport: Vector2) -> Vector2:
	return basis(viewport)*direction

static func input_direction(direction: Vector2, viewport: Vector2) -> Vector2:
	if direction.is_zero_approx():return Vector2.ZERO
	return (basis(viewport).affine_inverse()*direction).normalized()*minf(1,direction.length())
