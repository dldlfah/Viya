extends RefCounted
## Data-only mode rules; all actors and clocks belong to the existing RunState.
const PATH := "res://data/gold_dungeon.json"
const MODE := "gold_slime"
var data: Dictionary = {}
const REWARD_PATH:="res://data/gold_rewards.json"
var rewards:Dictionary={}
static func valid_rewards(value:Variant)->bool:
	if not value is Dictionary or value.get("schema_version")!=1 or not value.get("gold_slime") is Dictionary:return false
	var entry:Dictionary=value.gold_slime
	for key in ["minimum","maximum","average_clear_target"]:
		if not entry.get(key) is float or not is_finite(entry[key]) or entry[key]!=floor(entry[key]) or entry[key]<1 or entry[key]>1000000:return false
	return entry.minimum<=entry.maximum
func drop_range(version:int)->Vector2i:
	return Vector2i(int(rewards.minimum),int(rewards.maximum)) if version==1 and not rewards.is_empty() else Vector2i(10,50)
func _init() -> void:
	var reward_data:Variant=JSON.parse_string(FileAccess.get_file_as_string(REWARD_PATH))
	if valid_rewards(reward_data):rewards=reward_data.gold_slime
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and parsed.get("schema_version")==1 and parsed.get("duration")==180.0 and parsed.get("checkpoints")==[60.0,120.0] and parsed.get("daily_entries")==2 and parsed.get("utc_offset_seconds")==32400 and parsed.get("horde_interval")==4.0 and parsed.get("max_enemies")==360 and parsed.get("contact_damage")==6 and parsed.get("waves") is Array and parsed.waves.size()==3 and parsed.get("map") is Dictionary:
		data=parsed
func rules(baseline: Dictionary) -> Dictionary:
	if data.is_empty():return {}
	var result:=baseline.duplicate(true)
	result.merge({"map_id":MODE,"duration":data.duration,"checkpoints":data.checkpoints.duplicate(),"waves":data.waves.duplicate(true),"clear_gold":0.0,"elites":[60.0,120.0],"boss_at":150.0,"enemy_mix":{"normal":100.0,"ranged":0.0,"fast":0.0,"heavy":0.0}},true)
	result.scatter.interval=float(data.horde_interval)
	result.scatter.spacing=72.0
	result.scatter.jitter=8.0
	return result
func species(wave: Dictionary) -> Dictionary:
	return {"name":"골드 슬라임","kind":"normal","variant":"normal","hp":int(wave.hp),"speed":float(wave.speed),"contact_damage":int(data.contact_damage),"shot":""} if not data.is_empty() else {}
static func day_index(unix_seconds: int) -> int:
	return floori(float(unix_seconds+32400)/86400.0)
