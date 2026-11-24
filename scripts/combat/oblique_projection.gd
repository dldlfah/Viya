extends RefCounted
## Stage-only fixed camera azimuth. Published camera/spawn bounds remain legacy.
const Ground = preload("res://scripts/combat/battle_projection.gd")
const YAW := -PI / 10.0 # -18 degrees; fixed, never turns with movement.
const GROUND_Y := 0.8191520442889918 # sin(55 degrees)
static var _viewport := Vector2.ZERO
static var _basis := Transform2D.IDENTITY

static func basis(viewport: Vector2) -> Transform2D:
	if viewport == _viewport:return _basis
	var raw := Transform2D(Vector2(cos(YAW),sin(YAW)*GROUND_Y),Vector2(-sin(YAW),cos(YAW)*GROUND_Y),Vector2.ZERO)
	var extent := Ground.world_view_size(viewport)
	var inverse := raw.affine_inverse()
	var required := Vector2(absf(inverse.x.x)*viewport.x+absf(inverse.y.x)*viewport.y,absf(inverse.x.y)*viewport.x+absf(inverse.y.y)*viewport.y)
	# Fit the rotated viewport INSIDE the existing envelope, never exposing spawns.
	var zoom := maxf(required.x/maxf(1,extent.x),required.y/maxf(1,extent.y))
	_basis=Transform2D(raw.x*zoom,raw.y*zoom,Vector2.ZERO)
	_viewport=viewport
	return _basis

static func transform(center: Vector2, viewport: Vector2) -> Transform2D:
	var result := basis(viewport)
	result.origin=viewport*.5-result*center
	return result

static func visible_world(center: Vector2, viewport: Vector2) -> Rect2:
	return transform(center,viewport).affine_inverse()*Rect2(Vector2.ZERO,viewport)

static func depth(at: Vector2) -> float:
	return at.x*sin(YAW)+at.y*cos(YAW)

static func screen_direction(direction: Vector2, viewport: Vector2) -> Vector2:
	return basis(viewport)*direction

static func input_direction(direction: Vector2, viewport: Vector2) -> Vector2:
	if direction.is_zero_approx():return Vector2.ZERO
	return (basis(viewport).affine_inverse()*direction).normalized()*minf(1,direction.length())
