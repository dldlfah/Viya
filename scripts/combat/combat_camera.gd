extends RefCounted
## Reconstructible presentation only. A fixed spawn envelope covers every lead
## position, so smoothing history is never an unsaved gameplay/RNG input.
const Ground=preload("res://scripts/combat/battle_projection.gd")
const LEAD_FRACTION := .08
const RESPONSE := 6.0
var offset := Vector2.ZERO # Fraction of the projected viewport, bounded by8%.
var run_id: String = ""

func reset(id: String="") -> void:
	offset=Vector2.ZERO
	run_id=id

func advance(id: String, displacement: Vector2, delta: float, active: bool) -> void:
	if id!=run_id:reset(id)
	if not active or not is_finite(delta) or delta<=0:return
	var direction:=Vector2(displacement.x,displacement.y*Ground.GROUND_Y)
	var target:=direction.normalized()*LEAD_FRACTION if direction.length_squared()>.0001 else Vector2.ZERO
	offset=offset.lerp(target,1.0-exp(-RESPONSE*minf(delta,.05)))
	if offset.length_squared()<.00000001:offset=Vector2.ZERO

static func guard_size(viewport: Vector2) -> Vector2:
	return Ground.world_view_size(viewport)*(1.0+2.0*LEAD_FRACTION)

func center(state, viewport: Vector2) -> Vector2:
	var extent:=Ground.world_view_size(viewport)
	var lead:Vector2=offset if state.run_id==run_id else Vector2.ZERO
	var at:Vector2=state.player+lead*extent
	return at if state.map_id=="legacy_arena" else state.map_space.camera_center(at,extent)
