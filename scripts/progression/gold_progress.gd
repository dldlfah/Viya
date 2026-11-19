extends RefCounted
## One account file commits wallet, stage progress and talents together.
const Talents = preload("res://scripts/progression/account_talents.gd")
var path: String = "user://viya_gold.cfg"
var total: int = 0
var next_stage: int = 1
var last_run: String = ""
var loaded: bool = false
var dungeon: Dictionary = empty_dungeon()
static func empty_dungeon() -> Dictionary:
	return {"day":-1,"used":0,"initial":{},"closed_id":"","closed_outcome":"","closed_reward":0}
static func valid_dungeon(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=6 or not value.get("day") is int or value.day< -1 or value.day>100000000 or not value.get("used") is int or value.used<0 or value.used>2 or not value.get("initial") is Dictionary or not value.get("closed_id") is String or not value.get("closed_outcome") is String or not value.get("closed_reward") is int or value.closed_reward<0 or value.closed_reward>1000000000:
		return false
	if value.closed_id.is_empty():
		if value.closed_outcome!="" or value.closed_reward!=0:return false
	elif value.closed_id.length()!=32 or not value.closed_id.is_valid_hex_number(false) or value.closed_outcome not in ["cleared","defeat","abandoned"] or (value.closed_outcome!="cleared" and value.closed_reward!=0):return false
	if not value.initial.is_empty():
		var run: Variant=value.initial.get("run")
		if not run is Dictionary or run.get("run_mode")!="gold_slime" or run.get("phase")!=1 or run.get("elapsed")!=0.0 or run.get("dungeon_day")!=value.day or not run.get("run_id") is String or run.run_id.length()!=32 or not run.run_id.is_valid_hex_number(false) or run.run_id==value.closed_id or value.used<1:return false
	return value.day>=0 or (value.used==0 and value.initial.is_empty() and value.closed_id.is_empty())

func dungeon_remaining(unix_seconds: int = -1) -> int:
	var now:=int(Time.get_unix_time_from_system()) if unix_seconds<0 else unix_seconds
	var today:=preload("res://scripts/combat/gold_dungeon.gd").day_index(now)
	if not loaded or today<dungeon.day:return 0 # A backward clock never grants another daily budget.
	return 2 if today>dungeon.day else 2-int(dungeon.used)

func admit_dungeon(snapshot: Dictionary, unix_seconds: int = -1) -> Error:
	if not loaded or not dungeon.initial.is_empty() or dungeon_remaining(unix_seconds)<=0:return ERR_UNAVAILABLE
	var today:=preload("res://scripts/combat/gold_dungeon.gd").day_index(int(Time.get_unix_time_from_system()) if unix_seconds<0 else unix_seconds)
	var next:=dungeon.duplicate(true)
	next.used=1 if today>next.day else int(next.used)+1
	next.day=today
	next.initial=snapshot.duplicate(true)
	if not valid_dungeon(next):return ERR_INVALID_PARAMETER
	return _commit(total,next_stage,last_run,talent_levels,next)

func dungeon_allows(run: Dictionary) -> bool:
	if run.get("run_mode")!="gold_slime":return false
	if not dungeon.initial.is_empty() and run.get("run_id")==dungeon.initial.run.run_id:
		return run.get("dungeon_day")==dungeon.initial.run.dungeon_day and run.get("stage")==dungeon.initial.run.stage
	return run.get("run_id")==dungeon.closed_id and run.get("end_reason")==dungeon.closed_outcome and run.get("phase") in [3,5,6]

func finish_dungeon(result: Dictionary) -> Error:
	if not loaded or result.get("run_mode")!="gold_slime" or result.get("outcome") not in ["cleared","defeat","abandoned"] or not result.get("run_id") is String:return ERR_INVALID_PARAMETER
	var reward: Variant=result.get("gold_reward")
	if not reward is int or reward<0 or reward>1000000000 or (result.outcome!="cleared" and reward!=0):return ERR_INVALID_PARAMETER
	if result.run_id==dungeon.closed_id:
		return OK if result.outcome==dungeon.closed_outcome and reward==dungeon.closed_reward else ERR_INVALID_PARAMETER
	if dungeon.initial.is_empty() or result.run_id!=dungeon.initial.run.run_id or result.get("dungeon_day")!=dungeon.initial.run.dungeon_day or result.get("stage")!=dungeon.initial.run.stage:return ERR_INVALID_PARAMETER
	var next:=dungeon.duplicate(true)
	next.initial={}
	next.closed_id=result.run_id
	next.closed_outcome=result.outcome
	next.closed_reward=reward
	return _commit(total+reward,next_stage,last_run,talent_levels,next)
var talent_levels: Dictionary = Talents.empty_levels()
var attack_level: int: # Compatibility view of the original power talent.
	get: return int(talent_levels.attack_power)
	set(value): talent_levels.attack_power = value

func load_progress() -> Error:
	loaded = false
	if not FileAccess.file_exists(path):
		total = 0
		next_stage = 1
		last_run = ""
		talent_levels = Talents.empty_levels()
		dungeon = empty_dungeon()
		loaded = true
		return OK
	var file := ConfigFile.new()
	var error := file.load(path)
	if error != OK:
		return error
	var saved_total: Variant = file.get_value("gold", "total", -1)
	var saved_stage: Variant = file.get_value("gold", "next_stage", -1)
	var saved_run: Variant = file.get_value("gold", "last_run", "")
	if not saved_total is int or saved_total < 0 or not saved_stage is int or saved_stage < 1:
		return ERR_FILE_CORRUPT
	if not saved_run is String or saved_run.is_empty():
		return ERR_FILE_CORRUPT
	var saved_levels := Talents.empty_levels()
	if file.has_section("account"):
		var schema: Variant = file.get_value("account", "schema", -1)
		var saved_attack: Variant = file.get_value("account", "attack_level", -1)
		if not schema is int or not Talents.valid_level(saved_attack):
			return ERR_FILE_CORRUPT
		if schema == 1:
			saved_levels = Talents.from_attack(saved_attack)
		elif schema == 2:
			saved_levels = Talents.expand_six(file.get_value("account", "talent_levels", {}))
			if saved_levels.is_empty() or saved_levels.attack_power != saved_attack:
				return ERR_FILE_CORRUPT
		elif schema == Talents.SCHEMA:
			var saved: Variant = file.get_value("account", "talent_levels", {})
			if not Talents.valid_levels(saved) or saved.attack_power != saved_attack:
				return ERR_FILE_CORRUPT
			saved_levels = saved.duplicate(true)
		else:
			return ERR_FILE_CORRUPT
	var saved_dungeon: Variant=file.get_value("gold_dungeon","state",empty_dungeon())
	if file.has_section("gold_dungeon") and file.get_value("gold_dungeon","schema",-1)!=1:return ERR_FILE_CORRUPT
	if not valid_dungeon(saved_dungeon):return ERR_FILE_CORRUPT
	dungeon=saved_dungeon.duplicate(true)
	total = saved_total
	next_stage = saved_stage
	last_run = saved_run
	talent_levels = saved_levels
	loaded = true
	return OK

func settle(result: Dictionary) -> Error:
	if result.get("run_mode","campaign")=="gold_slime":return finish_dungeon(result)
	if result.get("run_mode","campaign")!="campaign":return ERR_INVALID_PARAMETER
	if not loaded or result.get("outcome", "") != "cleared":
		return ERR_INVALID_PARAMETER
	var run_id: String = str(result.get("run_id", ""))
	if run_id.is_empty():
		return ERR_INVALID_PARAMETER
	if run_id==dungeon.closed_id or (not dungeon.initial.is_empty() and run_id==dungeon.initial.run.run_id):return ERR_INVALID_PARAMETER
	if run_id == last_run:
		return OK
	var reward: int = int(result.get("gold_reward", -1))
	if int(result.get("stage", 0)) != next_stage or reward < 0:
		return ERR_INVALID_PARAMETER
	return _commit(total + reward, next_stage + 1, run_id, talent_levels)

func purchase_attack(expected_level: int) -> Error:
	return purchase_talent("attack_power", expected_level)

func purchase_talent(id: String, expected_level: int) -> Error:
	if not loaded or id not in Talents.IDS or not Talents.valid_level(expected_level) or expected_level != talent_levels[id]:
		return ERR_INVALID_PARAMETER
	if not Talents.can_purchase(talent_levels, id, expected_level):
		return ERR_UNAVAILABLE
	if total < int(Talents.ATTACK_COSTS[expected_level]):
		return ERR_UNAVAILABLE
	var disk = get_script().new()
	disk.path = path
	var error: Error = disk.load_progress()
	if error != OK:
		return error
	if not _matches(disk):
		return ERR_BUSY
	var next_levels: Dictionary = talent_levels.duplicate(true)
	next_levels[id] += 1
	return _commit(total - int(Talents.ATTACK_COSTS[expected_level]), next_stage, last_run, next_levels)

func _matches(other) -> bool:
	return other.total == total and other.next_stage == next_stage and other.last_run == last_run and other.talent_levels == talent_levels and other.dungeon==dungeon

func _commit(balance: int, stage_number: int, run_id: String, levels: Dictionary, next_dungeon: Variant = null) -> Error:
	var saved_dungeon: Dictionary=dungeon.duplicate(true) if next_dungeon==null else next_dungeon.duplicate(true)
	if not valid_dungeon(saved_dungeon):return ERR_INVALID_PARAMETER
	if run_id.is_empty():run_id="account-created"
	var file := ConfigFile.new()
	if FileAccess.file_exists(path):
		var read_error := file.load(path)
		if read_error != OK:
			return read_error
		var disk = get_script().new()
		disk.path = path
		var error: Error = disk.load_progress()
		if error != OK:
			return error
		if not _matches(disk):
			return ERR_BUSY
	file.set_value("gold_dungeon","schema",1)
	file.set_value("gold_dungeon","state",saved_dungeon)
	file.set_value("gold", "total", balance)
	file.set_value("gold", "next_stage", stage_number)
	file.set_value("gold", "last_run", run_id)
	file.set_value("account", "schema", Talents.SCHEMA)
	file.set_value("account", "attack_level", levels.attack_power)
	file.set_value("account", "talent_levels", levels.duplicate(true))
	var temporary := path + ".tmp"
	var error := file.save(temporary)
	if error != OK:
		return error
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if error != OK:
		return error
	dungeon=saved_dungeon.duplicate(true)
	total = balance
	next_stage = stage_number
	last_run = run_id
	talent_levels = levels.duplicate(true)
	return OK
