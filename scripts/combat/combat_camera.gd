extends RefCounted
## Presentation only: hold the view inside a central dead zone, never anticipate
## movement or drift after release. The published spawn envelope stays unchanged.
const Ground=preload("res://scripts/combat/battle_projection.gd")
const DEADZONE_FRACTION := .06
const MAX_OFFSET_FRACTION := .08
const RESPONSE := 6.0
var offset := Vector2.ZERO # Normalized presentation lag, bounded per axis.
var run_id: String = ""
var _player := Vector2.ZERO
var _viewport := Vector2.ZERO
var _initialized:bool=false

func reset(id: String="") -> void:
	offset=Vector2.ZERO
	run_id=id
	_initialized=false
	_viewport=Vector2.ZERO

func advance(state,viewport:Vector2,displacement:Vector2,delta:float,active:bool) -> void:
	if state.run_id!=run_id or (_initialized and viewport!=_viewport):reset(state.run_id)
	if not is_finite(delta) or delta<=0 or not displacement.is_finite() or not viewport.is_finite() or viewport.x<=0 or viewport.y<=0:return
	var extent:Vector2=Ground.world_view_size(viewport)
	if not _initialized:
		if not active:return
		_player=state.player-displacement
		_viewport=viewport
		_initialized=true
	if (state.player-_player-displacement).length_squared()>.01:
		# An unobserved teleport/restore is rebuilt neutrally, never swept across the map.
		offset=Vector2.ZERO
		_player=state.player
		return
	var previous:Vector2=_player+offset*extent
	_player=state.player
	if displacement.is_zero_approx():return
	if not active:
		# A final movement step may open a choice/pause. Remember it without
		# introducing a recenter jump when explicit Continue resumes the run.
		offset=((previous-state.player)/extent).clamp(-Vector2.ONE*MAX_OFFSET_FRACTION,Vector2.ONE*MAX_OFFSET_FRACTION)
		return
	var radius:Vector2=extent*DEADZONE_FRACTION
	var target:Vector2=state.player-(state.player-previous).clamp(-radius,radius)
	var motion:Vector2=(target-previous)*(1.0-exp(-RESPONSE*minf(delta,.05)))
	for axis in range(2):
		# Reversing or slowing down cannot keep panning in the old direction,
		# or make the background move faster than the actual player displacement.
		motion[axis]=clampf(motion[axis],-absf(displacement[axis]),absf(displacement[axis])) if motion[axis]*displacement[axis]>0 else 0.0
	offset=((previous+motion-state.player)/extent).clamp(-Vector2.ONE*MAX_OFFSET_FRACTION,Vector2.ONE*MAX_OFFSET_FRACTION)

static func guard_size(viewport: Vector2) -> Vector2:
	return Ground.world_view_size(viewport)*(1.0+2.0*MAX_OFFSET_FRACTION)

func center(state, viewport: Vector2) -> Vector2:
	var extent:=Ground.world_view_size(viewport)
	var lag:Vector2=offset if state.run_id==run_id and _initialized and viewport==_viewport else Vector2.ZERO
	var at:Vector2=state.player+lag*extent
	return at if state.map_id=="legacy_arena" else state.map_space.camera_center(at,extent)
