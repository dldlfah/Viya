extends RefCounted
## Immutable rule catalogs only. All attack state remains in the one RunState.
const Previous=preload("res://scripts/combat/enemy_patterns_v1.gd")
const Revised=preload("res://scripts/combat/enemy_patterns_v2.gd")
var previous=Previous.new()
var revised=Revised.new()
# Historical QA/catalog API remains bound to the published v1 table.
var data:Dictionary:
	get:return previous.data
var error:String:
	get:return previous.error
	set(value):previous.error=value

static func valid_data(value:Variant) -> bool:
	return Previous.valid_data(value)

static func hits(origin:Vector2,direction:Vector2,reach:float,half_angle:float,at:Vector2,radius:float) -> bool:
	return Previous.hits(origin,direction,reach,half_angle,at,radius)

func available(version:int) -> bool:
	return previous.error.is_empty() and (version!=2 or revised.error.is_empty())

func specification(version:int) -> Dictionary:
	return (revised.data if version==2 else previous.data).get(Previous.SPECIES,{}).duplicate(true)

func _rules(version:int):
	return revised if version==2 else previous

func applies(state,enemy:Dictionary) -> bool:
	return _rules(state.enemy_pattern_version).applies(state,enemy)

func attach(state,enemy:Dictionary) -> void:
	_rules(state.enemy_pattern_version).attach(state,enemy)

func locked(state,enemy:Dictionary) -> bool:
	return _rules(state.enemy_pattern_version).locked(state,enemy)

func tick(state,enemy:Dictionary,dt:float) -> bool:
	return _rules(state.enemy_pattern_version).tick(state,enemy,dt)

func valid_actor(run:Dictionary,enemy:Dictionary) -> bool:
	return _rules(run.enemy_pattern_version).valid_actor(run,enemy)
