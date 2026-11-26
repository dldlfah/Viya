extends RefCounted
## A durable intent precedes deletion of the two existing local save owners.
## Startup completes interrupted resets before either account or battle is read.
const INTENT := "VIYA-LOCAL-ACCOUNT-RESET-1\n"

static func pending(account_path: String) -> bool:
	return FileAccess.file_exists(account_path+".reset")

static func begin(account_path: String, battle_path: String) -> Error:
	var marker:=account_path+".reset"
	var file:=FileAccess.open(marker+".tmp",FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(INTENT)
	file.flush()
	var error:Error=file.get_error()
	file.close()
	if error!=OK:return error
	error=DirAccess.rename_absolute(ProjectSettings.globalize_path(marker+".tmp"),ProjectSettings.globalize_path(marker))
	return recover(account_path,battle_path) if error==OK else error

static func recover(account_path: String, battle_path: String) -> Error:
	var marker:=account_path+".reset"
	if not pending(account_path):return OK
	var file:=FileAccess.open(marker,FileAccess.READ)
	if file==null:return FileAccess.get_open_error()
	if file.get_length()!=INTENT.length() or file.get_as_text()!=INTENT:return ERR_FILE_CORRUPT
	file.close()
	# Exact known files only. No directories, asset files or display/audio settings.
	for path in [battle_path+".tmp",battle_path,account_path+".tmp",account_path]:
		if DirAccess.dir_exists_absolute(path):return ERR_FILE_CANT_WRITE
		if not FileAccess.file_exists(path):continue
		var error:=DirAccess.remove_absolute(path)
		if error!=OK:return error
	return DirAccess.remove_absolute(marker) # Last commit: no old data can revive.
