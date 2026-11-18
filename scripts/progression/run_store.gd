extends RefCounted
const Snapshot = preload("res://scripts/progression/run_snapshot.gd")
const MAGIC := "VIYA-RUN-1\n"
const MAX_BYTES := 2097152
var path: String = "user://viya_run.save"
var pending: Dictionary = {}
var error: Error = OK

func load_saved(state) -> Error:
	pending.clear()
	if not FileAccess.file_exists(path):
		error = OK
		return OK
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = FileAccess.get_open_error()
		return error
	if file.get_length() == 0:
		error = OK
		return OK
	if file.get_length() > MAX_BYTES or file.get_line() + "\n" != MAGIC:
		error = ERR_FILE_CORRUPT
		return error
	var digest := file.get_line()
	var payload := file.get_buffer(file.get_length() - file.get_position())
	if checksum(payload) != digest:
		error = ERR_FILE_CORRUPT
		return error
	var decoded: Variant = bytes_to_var(payload)
	if decoded is Dictionary:
		decoded = Snapshot.upgrade_legacy(decoded, state)
	if not decoded is Dictionary or not Snapshot.valid(decoded, state):
		error = ERR_FILE_CORRUPT
		return error
	pending = decoded
	error = OK
	return OK

func save_current(state) -> Error:
	return write_snapshot(Snapshot.capture(state))

func write_snapshot(snapshot: Dictionary) -> Error:
	var payload := var_to_bytes(snapshot)
	if payload.size() > MAX_BYTES:
		error = ERR_OUT_OF_MEMORY
		return error
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = FileAccess.get_open_error()
		return error
	file.store_string(MAGIC + checksum(payload) + "\n")
	file.store_buffer(payload)
	file.flush()
	error = file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if error == OK:
		pending = snapshot.duplicate(true)
	return error

static func checksum(payload: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return context.finish().hex_encode()

func discard() -> Error:
	# Atomic empty tombstone. A failed deletion must not revive an old checkpoint.
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = FileAccess.get_open_error()
		return error
	file.close()
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if error == OK:
		pending.clear()
	return error
