class_name SaveIO
extends RefCounted
## Writing save files safely: write to a temporary file first, then swap it
## in. If the game crashes or the power goes mid-save, you keep the old save
## instead of a half-written, broken one ("atomic" saving).

static func write_json(path: String, data: Variant) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	if FileAccess.file_exists(path):
		dir.remove(path.get_file())
	return dir.rename(tmp.get_file(), path.get_file()) == OK
