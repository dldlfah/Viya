extends RefCounted
## One account file commits wallet, stage progress and talents together.
const Talents = preload("res://scripts/progression/account_talents.gd")
var path: String = "user://viya_gold.cfg"
var total: int = 0
var next_stage: int = 1
var last_run: String = ""
var loaded: bool = false
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
	total = saved_total
	next_stage = saved_stage
	last_run = saved_run
	talent_levels = saved_levels
	loaded = true
	return OK

func settle(result: Dictionary) -> Error:
	if not loaded or result.get("outcome", "") != "cleared":
		return ERR_INVALID_PARAMETER
	var run_id: String = str(result.get("run_id", ""))
	if run_id.is_empty():
		return ERR_INVALID_PARAMETER
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
	return other.total == total and other.next_stage == next_stage and other.last_run == last_run and other.talent_levels == talent_levels

func _commit(balance: int, stage_number: int, run_id: String, levels: Dictionary) -> Error:
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
	total = balance
	next_stage = stage_number
	last_run = run_id
	talent_levels = levels.duplicate(true)
	return OK
