extends RefCounted
## Data and pure policy only. XP/owned skills/RNG stay in the existing GrowthState.
const PATH := "res://data/combat_pacing.json"
var data:Dictionary={}
func _init()->void:
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if valid(parsed):data=parsed
static func valid(value:Variant)->bool:
	if not value is Dictionary or value.get("schema_version")!=1 or not value.get("boss_priority") is bool or not value.get("focus_from_level") is float or value.focus_from_level<2 or value.focus_from_level>20 or value.focus_from_level!=floor(value.focus_from_level) or not value.get("profiles") is Dictionary or value.profiles.size()!=2:return false
	for mode in ["campaign","gold_slime"]:
		var p:Variant=value.profiles.get(mode)
		if not p is Dictionary or not p.get("base_requirements") is Array or p.base_requirements.size()<4 or p.base_requirements.size()>30 or not p.get("tail_increment") is float or not is_finite(p.tail_increment) or p.tail_increment<=0 or p.tail_increment>10000 or not p.get("choice_target") is Array or p.choice_target.size()!=2:return false
		var last:=0.0
		for n in p.base_requirements:
			if not n is float or not is_finite(n) or n!=floor(n) or n<=last or n>100000:return false
			last=n
		if not p.choice_target.all(func(n):return n is float and n==floor(n) and n>=1 and n<=30) or p.choice_target[0]>p.choice_target[1]:return false
	return true
func base_requirement(level:int,mode:String)->float:
	if data.is_empty() or not data.profiles.has(mode) or level<1:return INF
	var p:Dictionary=data.profiles[mode]
	return float(p.base_requirements[level-1]) if level<=p.base_requirements.size() else float(p.base_requirements[-1])+(level-p.base_requirements.size())*float(p.tail_increment)
func focus(growth)->String:
	if data.is_empty() or growth.pacing_version!=1 or growth.level<int(data.focus_from_level):return ""
	var found:=""
	var rank:=0
	for id in growth.eligible():
		if growth.definition(id).row=="attack" and growth.skill_level(id)>rank:
			found=id
			rank=growth.skill_level(id)
	return found
