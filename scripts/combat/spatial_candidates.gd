extends RefCounted
## Temporary broadphase only. Actors, damage and order remain in RunState.
const CELL_SIZE := 128.0
const MAX_QUERY_CELLS := 4096
var _buckets: Dictionary = {}
var _entries: Dictionary = {}
var _ordered: Array[Dictionary] = []

func cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x/CELL_SIZE),floori(at.y/CELL_SIZE))

func build(groups: Array, ground_only: bool = false) -> bool:
	_buckets.clear();_entries.clear();_ordered.clear()
	var order := 0
	for group in groups:
		for actor in group:
			order += 1
			if actor.hp<=0 or (ground_only and actor.get("variant","")=="flier"):continue
			var id:int=actor.id
			if _entries.has(id):
				_buckets.clear();_entries.clear();_ordered.clear()
				return false # Malformed diagnostic input uses the original scan.
			var key:=cell(actor.p)
			var entry:Dictionary={"actor":actor,"order":order,"cell":key}
			_entries[id]=entry
			_ordered.append(actor)
			if not _buckets.has(key):_buckets[key]={}
			_buckets[key][id]=entry
	return true

func moved(actor: Dictionary) -> void:
	var id:int=actor.id
	if not _entries.has(id):return
	var entry:Dictionary=_entries[id]
	var key:=cell(actor.p)
	if key==entry.cell:return
	_buckets[entry.cell].erase(id)
	if _buckets[entry.cell].is_empty():_buckets.erase(entry.cell)
	entry.cell=key
	if not _buckets.has(key):_buckets[key]={}
	_buckets[key][id]=entry

func segment(from: Vector2, to: Vector2, padding: float) -> Array[Dictionary]:
	# Include a conservative edge margin; exact hit/push tests stay unchanged.
	var low:=Vector2(minf(from.x,to.x),minf(from.y,to.y))-Vector2.ONE*(padding+.1)
	var high:=Vector2(maxf(from.x,to.x),maxf(from.y,to.y))+Vector2.ONE*(padding+.1)
	var first:=cell(low)
	var last:=cell(high)
	if (last.x-first.x+1)*(last.y-first.y+1)>MAX_QUERY_CELLS:return _ordered.duplicate()
	var found:Array[Dictionary]=[]
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			for entry in _buckets.get(Vector2i(x,y),{}).values():
				var actor:Dictionary=entry.actor
				var at:Vector2=actor.p
				if actor.hp>0 and at.x>=low.x and at.x<=high.x and at.y>=low.y and at.y<=high.y:found.append(entry)
	# Grid traversal must never reorder equal hits, crit rolls or drop RNG.
	found.sort_custom(func(a,b):return a.order<b.order)
	var result:Array[Dictionary]=[]
	for entry in found:result.append(entry.actor)
	return result
