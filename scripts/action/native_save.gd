extends RefCounted
## Action saves use their own directory; legacy turn-based saves remain untouched.
var db
var directory: String = "user://action_saves"
var error: String = ""
func _init(database) -> void:
	db = database
	DirAccess.make_dir_recursive_absolute(directory)

func save_game(snapshot: Dictionary) -> bool:
	if not valid(snapshot):
		error = "Нельзя сохранить некорректное состояние."
		return false
	DirAccess.make_dir_recursive_absolute(directory)
	var path = directory.path_join("slot_0.json")
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "Нет доступа к сохранениям."
		return false
	file.store_string(JSON.stringify(snapshot))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		DirAccess.rename_absolute(path + ".bak", path)
		error = "Не удалось записать файл."
		return false
	return true

func load_game() -> Dictionary:
	for suffix in ["", ".bak"]:
		var path = directory.path_join("slot_0.json" + suffix)
		if not FileAccess.file_exists(path): continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) == OK and parser.data is Dictionary and valid(parser.data):
			return parser.data
	return {}

func valid(value: Dictionary) -> bool:
	if value.get("version") != 1 or value.get("mode", "") not in ["story", "practice"]: return false
	if not db.characters.has(value.get("character", "")): return false
	if value.mode == "story" and value.character != "moon": return false
	if not value.get("position") is Array or value.position.size() != 2: return false
	for number in value.position:
		if not (number is float or number is int) or not is_finite(float(number)): return false
	var bounds = db.levels[db.config.initial_level].size
	if value.position[0] < 0 or value.position[0] > bounds[0] or value.position[1] < -200 or value.position[1] > bounds[1]: return false
	for key in ["hp", "energy"]:
		var number = value.get(key)
		if not (number is float or number is int) or not is_finite(float(number)): return false
		if number < (1 if key == "hp" else 0) or number > db.characters[value.character][key]: return false
	if not value.get("collected") is Dictionary: return false
	for key in ["checkpoint", "boss_defeated", "completed"]:
		if not value.get(key) is bool: return false
	return true
