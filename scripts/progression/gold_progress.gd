extends RefCounted
## One account file commits wallet, stage progress and talents together.
const Talents = preload("res://scripts/progression/account_talents.gd")
var path: String = "user://viya_gold.cfg"
var total: int = 0
var next_stage: int = 1
var last_run: String = ""
var loaded: bool = false
var attack_level: int = 0

func load_progress() -> Error:
	loaded = false
	if not FileAccess.file_exists(path):
		total = 0
		next_stage = 1
		last_run = ""
		attack_level = 0
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
	var saved_attack: Variant = 0 # Older currency files have no account section.
	if file.has_section("account"):
		var schema: Variant = file.get_value("account", "schema", -1)
		saved_attack = file.get_value("account", "attack_level", -1)
		if not schema is int or schema != Talents.SCHEMA or not Talents.valid_level(saved_attack):
			return ERR_FILE_CORRUPT
	total = saved_total
	next_stage = saved_stage
	last_run = saved_run
	attack_level = saved_attack
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
	return _commit(total + reward, next_stage + 1, run_id, attack_level)

func purchase_attack(expected_level: int) -> Error:
	if not loaded or not Talents.valid_level(expected_level) or expected_level != attack_level:
		return ERR_INVALID_PARAMETER
	if attack_level >= Talents.ATTACK_COSTS.size() or total < int(Talents.ATTACK_COSTS[attack_level]):
		return ERR_UNAVAILABLE
	# A delayed request or a second account instance cannot spend a stale balance.
	var disk = get_script().new()
	disk.path = path
	var error: Error = disk.load_progress()
	if error != OK:
		return error
	if disk.total != total or disk.next_stage != next_stage or disk.last_run != last_run or disk.attack_level != attack_level:
		return ERR_BUSY
	return _commit(total - int(Talents.ATTACK_COSTS[attack_level]), next_stage, last_run, attack_level + 1)

func _commit(balance: int, stage_number: int, run_id: String, level: int) -> Error:
	var file := ConfigFile.new()
	if FileAccess.file_exists(path):
		var read_error := file.load(path)
		if read_error != OK:
			return read_error
		if file.get_value("gold", "total", -1) != total or file.get_value("gold", "next_stage", -1) != next_stage or file.get_value("gold", "last_run", "") != last_run or file.get_value("account", "attack_level", 0) != attack_level:
			return ERR_BUSY
	file.set_value("gold", "total", balance)
	file.set_value("gold", "next_stage", stage_number)
	file.set_value("gold", "last_run", run_id)
	file.set_value("account", "schema", Talents.SCHEMA)
	file.set_value("account", "attack_level", level)
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
	attack_level = level
	return OK
