extends RefCounted
## Immutable rule catalogs only. All attack state remains in the one RunState.
const Previous=preload("res://scripts/combat/enemy_patterns_v1.gd")
const Revised=preload("res://scripts/combat/enemy_patterns_v2.gd")
const Curse=preload("res://scripts/combat/enemy_patterns_v3.gd")
var previous=Previous.new()
var revised=Revised.new()
var current=Curse.new()
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
	return previous.error.is_empty() and (version not in [2,3] or revised.error.is_empty()) and (version!=3 or current.error.is_empty())

func specification(version:int,species:String=Previous.SPECIES) -> Dictionary:
	if version==3:return (current.curse if species==Curse.CASTER else current.data.get(Previous.SPECIES,{})).duplicate(true)
	return (revised.data if version==2 else previous.data).get(Previous.SPECIES,{}).duplicate(true)

func _rules(version:int):
	if version==3:return current
	return revised if version==2 else previous

func is_curse(state,bullet:Dictionary) -> bool:
	return current.is_curse(state,bullet)

func move_curse(state,bullet:Dictionary,dt:float) -> bool:
	return current.move_curse(state,bullet,dt)

func valid_curse(run:Dictionary,bullet:Dictionary) -> bool:
	return current.error.is_empty() and current.valid_bullet(run,bullet)

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
