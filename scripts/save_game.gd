extends RefCounted
## Reads and writes the save file: one JSON document under user:// (on Windows,
## %APPDATA%\Godot\app_userdata\Inkwind). What goes inside is decided by
## main.gd; this script only cares about getting it to disk and back safely.

## Bump when the saved layout changes in a way old files cannot satisfy.
const VERSION := 1


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


## Writes `data` to `path`. Goes through a temporary file so a crash halfway
## never leaves a half-written save behind. Returns whether it worked.
static func write(path: String, data: Dictionary) -> bool:
	data["version"] = VERSION
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("Salvataggio non riuscito (%s): %s" % [
				path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var error := DirAccess.rename_absolute(temp, path)
	if error != OK:
		push_warning("Salvataggio non riuscito (%s): %s" % [path, error_string(error)])
	return error == OK


## Returns the saved data, or {} if there is no usable save. A file that cannot
## be understood is moved aside (".unreadable") instead of being overwritten.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# JSON.new().parse() rather than JSON.parse_string(): it reports failure
	# through its return value instead of logging an engine error.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) == OK:
		var parsed: Variant = json.data
		if parsed is Dictionary and int(parsed.get("version", 0)) == VERSION:
			return parsed
	push_warning("Salvataggio illeggibile, messo da parte: %s.unreadable" % path)
	DirAccess.rename_absolute(path, path + ".unreadable")
	return {}


static func erase(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
