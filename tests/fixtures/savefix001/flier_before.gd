extends "res://scripts/combat/run_state.gd"
func _move_fliers(dt: float) -> void:
	_push_candidates=null
	for index in range(enemies.size() - 1, -1, -1):
		var flier: Dictionary = enemies[index]
		if flier.variant != "flier":
			continue
		flier.life -= dt
		if flier.life <= 0.0:
			enemies.remove_at(index) # Expiry never awards a kill or loot.
			continue
		if _push_candidates==null and enemies.size()>=96:
			_push_candidates=SpatialCandidates.new()
			if not _push_candidates.build([enemies],true):_push_candidates=null
		var previous: Vector2 = flier.p
		flier.p += flier.velocity * dt * WeaponModules.speed_scale(flier)
		_push_ground(previous, flier.p)
	_push_candidates=null
