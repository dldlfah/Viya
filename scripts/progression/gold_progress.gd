extends RefCounted
## Only cleared stages enter the persistent wallet. Replace the file atomically.
var path: String = "user://viya_gold.cfg"
var total: int = 0
var next_stage: int = 1
var last_run: String = ""
var loaded: bool = false

func load_progress() -> Error:
	loaded = false
	if not FileAccess.file_exists(path):
		total = 0
		next_stage = 1
		last_run = ""
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
	total = saved_total
	next_stage = saved_stage
	last_run = saved_run
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
	var file := ConfigFile.new()
	file.set_value("gold", "total", total + reward)
	file.set_value("gold", "next_stage", next_stage + 1)
	file.set_value("gold", "last_run", run_id)
	var temporary := path + ".tmp"
	var error := file.save(temporary)
	if error != OK:
		return error
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if error != OK:
		return error
	total += reward
	next_stage += 1
	last_run = run_id
	return OK
