extends RefCounted
## Orthographic high-angle prototype: unrotated world axes, 60 degrees above
## the ground. Upright billboards are separate from this ground transform.
const ELEVATION_DEGREES := 60.0
const GROUND_Y := 0.8660254037844386

static func transform(center: Vector2, viewport: Vector2) -> Transform2D:
	var basis := Transform2D(Vector2.RIGHT, Vector2(0, GROUND_Y), Vector2.ZERO)
	basis.origin = viewport * 0.5 - basis * center
	return basis

static func world_to_screen(at: Vector2, center: Vector2, viewport: Vector2) -> Vector2:
	return transform(center, viewport) * at

static func screen_to_world(at: Vector2, center: Vector2, viewport: Vector2) -> Vector2:
	return transform(center, viewport).affine_inverse() * at

static func world_view_size(viewport: Vector2) -> Vector2:
	return Vector2(viewport.x, viewport.y / GROUND_Y)

static func visible_world(center: Vector2, viewport: Vector2) -> Rect2:
	var extent := world_view_size(viewport)
	return Rect2(center - extent * 0.5, extent)

static func obstacle_bounds(box: Rect2, height: float, center: Vector2, viewport: Vector2) -> Rect2:
	var top := world_to_screen(box.position, center, viewport) - Vector2(0, height)
	return Rect2(top, Vector2(box.size.x, box.size.y * GROUND_Y + height))

static func occludes_player(box: Rect2, height: float, player: Vector2, center: Vector2, viewport: Vector2) -> bool:
	var feet := world_to_screen(player, center, viewport)
	var body := Rect2(feet - Vector2(19, 56), Vector2(38, 57))
	return player.y < box.end.y and obstacle_bounds(box, height, center, viewport).intersects(body)
