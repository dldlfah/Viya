extends RefCounted
## Static map geometry and derived route cache, never a second combat state.
const Catalog = preload("res://scripts/world/map_catalog.gd")
var definition: Dictionary
var world_size := Vector2(1800,1200)
var start := Vector2(900,600)
var camera_bounds := Rect2(Vector2.ZERO,world_size)
var play_bounds := Rect2(Vector2.ZERO,world_size)
var solids: Array[Rect2] = []
var _nodes: Array[Vector2] = []
var _edges: Array = []
var _costs: Array[float] = []
var _radius: float = -1.0
var _goal := Vector2(INF,INF)
# Derived geometry only; excluded from saves and rebuilt after data changes.
const MAX_WALL_RADII := 16
var _wall_solids: Array[Rect2] = []
var _wall_cache: Dictionary = {}
func _walls(radius: float) -> Dictionary:
	if _wall_solids != solids:
		_wall_solids.assign(solids)
		_wall_cache.clear()
		_radius = -1.0
	if not _wall_cache.has(radius):
		if _wall_cache.size() >= MAX_WALL_RADII:_wall_cache.clear()
		var boxes: Array[Rect2] = []
		var corners: Array = []
		var limits := PackedFloat64Array()
		for solid in solids:
			var wall := solid.grow(radius)
			boxes.append(wall)
			corners.append([wall.position,Vector2(wall.end.x,wall.position.y),wall.end,Vector2(wall.position.x,wall.end.y)])
			limits.append_array(PackedFloat64Array([wall.position.x,wall.end.x,wall.position.y,wall.end.y]))
		_wall_cache[radius] = {"boxes":boxes,"corners":corners,"limits":limits}
	return _wall_cache[radius]
func _init(data: Dictionary) -> void:
	definition = data.duplicate(true)
	world_size = Vector2(data["size"][0],data["size"][1])
	start = Vector2(data.start[0],data.start[1])
	camera_bounds = Catalog.rectangle(data.camera)
	play_bounds = Catalog.rectangle(data.walkable)
	for obstacle in data.obstacles:
		if obstacle.solid:
			solids.append(Catalog.rectangle(obstacle.rect))
func camera_center(player: Vector2, viewport: Vector2) -> Vector2:
	var half := viewport * 0.5
	var low := camera_bounds.position + half
	var high := camera_bounds.end - half
	return Vector2(clampf(player.x, low.x, high.x) if low.x <= high.x else camera_bounds.get_center().x, clampf(player.y, low.y, high.y) if low.y <= high.y else camera_bounds.get_center().y)
func valid_position(at: Vector2, radius: float) -> bool:
	if not at.is_finite() or at.x < play_bounds.position.x+radius or at.y < play_bounds.position.y+radius or at.x > play_bounds.end.x-radius or at.y > play_bounds.end.y-radius:
		return false
	for obstacle in solids:
		if obstacle.grow(radius).has_point(at):
			return false
	return true
func move(at: Vector2, displacement: Vector2, radius: float) -> Vector2:
	# Axis sweeps slide along walls and stop large-frame tunnelling.
	var result := at.clamp(play_bounds.position+Vector2.ONE * radius,play_bounds.end - Vector2.ONE * radius)
	var boxes:Array[Rect2]=_walls(radius+.01).boxes
	for axis in range(2):
		var other := 1 - axis
		var next := clampf(result[axis] + displacement[axis],play_bounds.position[axis]+radius,play_bounds.end[axis]-radius)
		for wall in boxes:
			if result[other] < wall.position[other] or result[other] > wall.end[other]:
				continue
			if displacement[axis] > 0 and result[axis] <= wall.position[axis] and next > wall.position[axis]:
				next = wall.position[axis]
			elif displacement[axis] < 0 and result[axis] >= wall.end[axis] and next < wall.end[axis]:
				next = wall.end[axis]
		result[axis] = next
	return result
func wall_fraction(from: Vector2, to: Vector2, radius: float = 0.0) -> float:
	var distance := from.distance_to(to)
	var first := 1.0
	# Conservative rejection only. Actual intersections keep the published math,
	# wall/edge order and endpoint handling, including starts inside a wall.
	var low := Vector2(minf(from.x,to.x),minf(from.y,to.y))-Vector2.ONE*.01
	var high := Vector2(maxf(from.x,to.x),maxf(from.y,to.y))+Vector2.ONE*.01
	var walls:=_walls(radius)
	var limits:PackedFloat64Array=walls.limits
	for index in range(walls.boxes.size()):
		var offset:=index*4
		if high.x < limits[offset] or low.x > limits[offset+1] or high.y < limits[offset+2] or low.y > limits[offset+3]:continue
		var wall:Rect2=walls.boxes[index]
		if wall.has_point(from):return 0.0
		var points:Array=walls.corners[index]
		for i in range(4):
			var hit: Variant = Geometry2D.segment_intersects_segment(from,to,points[i],points[(i+1)%4])
			if hit is Vector2:first = minf(first,from.distance_to(hit)/maxf(distance,0.000001))
	return first
func prepare_routes(goal: Vector2, radius: float) -> void:
	_walls(radius)
	if radius != _radius:
		_radius = radius
		_nodes.clear()
		_edges.clear()
		for solid in solids:
			var box := solid.grow(radius + 2.0)
			for at in [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]:
				if valid_position(at,radius):
					_nodes.append(at)
		for a in range(_nodes.size()):
			var adjacent := {}
			for b in range(_nodes.size()):
				if a != b and wall_fraction(_nodes[a],_nodes[b],radius) >= 1.0:
					adjacent[b] = _nodes[a].distance_to(_nodes[b])
			_edges.append(adjacent)
		_goal = Vector2(INF,INF)
	if goal == _goal:
		return
	_goal = goal
	_costs.clear()
	var visited := {}
	for at in _nodes:
		_costs.append(at.distance_to(goal) if wall_fraction(at,goal,radius) >= 1.0 else INF)
	for iteration in range(_nodes.size()):
		var nearest := -1
		var best := INF
		for i in range(_nodes.size()):
			if not visited.has(i) and _costs[i] < best:
				nearest = i
				best = _costs[i]
		if nearest < 0:
			break
		visited[nearest] = true
		for target in _edges[nearest]:
			_costs[target] = minf(_costs[target],best + float(_edges[nearest][target]))
func route_target(from: Vector2, goal: Vector2, radius: float) -> Vector2:
	if solids.is_empty() or wall_fraction(from,goal,radius) >= 1.0:return goal
	prepare_routes(goal,radius)
	# Test the cheapest complete route first. Float64 costs retain the original
	# arithmetic; equal costs resolve in original node order, never sort order.
	var costs := PackedFloat64Array()
	costs.resize(_nodes.size())
	for i in range(_nodes.size()):
		costs[i] = INF if from.distance_squared_to(_nodes[i]) < .01 else from.distance_to(_nodes[i]) + _costs[i]
	var ordered := costs.duplicate()
	ordered.sort()
	var previous := -INF
	var next_index := 0
	for cost in ordered:
		if not is_finite(cost):break
		var index := costs.find(cost,next_index if cost==previous else 0)
		previous = cost
		next_index = index+1
		if wall_fraction(from,_nodes[index],radius) >= 1.0:return _nodes[index]
	return from
func spawn_anchor(generator: RandomNumberGenerator, player: Vector2, elapsed: float, role: String, visible: Rect2, footprint: float = 0.0) -> Variant:
	var eligible: Array = definition.zones.filter(func(zone): return role in zone.roles and elapsed >= zone.from)
	var reach := maxf(590.0,visible.size.length()*0.5 + footprint + 96.0)
	for attempt in range(64):
		if eligible.is_empty():
			return null
		var weights: Array[float] = []
		var total := 0.0
		for candidate in eligible:
			var weight := 1.0
			for entry in candidate.weights:
				if elapsed >= entry.from:
					weight = float(entry.weight)
			weights.append(weight)
			total += weight
		var roll := generator.randf() * total
		var zone: Dictionary = eligible[-1]
		for index in range(eligible.size()):
			roll -= weights[index]
			if roll < 0:
				zone = eligible[index]
				break
		var box := Catalog.rectangle(zone.rect)
		var angle := generator.randf_range(0.0,TAU)
		if definition.mode == "frontline":
			match zone.side:
				"front": angle = generator.randf_range(PI * 0.30,PI * 0.70)
				"left": angle = generator.randf_range(PI * 0.80,PI * 1.20)
				"right": angle = generator.randf_range(-PI * 0.20,PI * 0.20)
		var at := player + Vector2.from_angle(angle) * reach
		if attempt >= 32:
			at = Vector2(generator.randf_range(box.position.x,box.end.x),generator.randf_range(box.position.y,box.end.y))
		if box.has_point(at) and valid_position(at,maxf(24.0,footprint)) and at.distance_to(player) >= 160.0 + footprint and not visible.grow(32.0+footprint).has_point(at):
			return at
	return null
