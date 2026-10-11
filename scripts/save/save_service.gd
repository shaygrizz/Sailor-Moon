extends RefCounted
## JSON snapshots, atomic replacement and explicit migration. Replace this provider for cloud.
var state
var db
var bus
var directory: String
var last_error: String = ""

func _init(session, database, events, storage_directory: String = "user://saves") -> void:
	state = session
	db = database
	bus = events
	directory = storage_directory
	DirAccess.make_dir_recursive_absolute(directory)

func _path(slot: int) -> String:
	return directory.path_join("slot_%d.json" % slot)

func exists(slot: int) -> bool:
	return FileAccess.file_exists(_path(slot))

func save_slot(slot: int) -> bool:
	if slot < 0 or slot > int(db.table("config").save_slots):
		last_error = "Недопустимый слот."
		return false
	var path = _path(slot)
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Хранилище недоступно."
		return false
	file.store_string(JSON.stringify(state.data))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		if DirAccess.rename_absolute(path, path + ".bak") != OK:
			last_error = "Не удалось обновить резервную копию."
			return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(path + ".bak", path)
		last_error = "Не удалось записать сохранение."
		return false
	last_error = ""
	bus.publish("saved", {"slot": slot})
	return true

func load_slot(slot: int) -> bool:
	var candidate = read_snapshot(_path(slot))
	if candidate.is_empty():
		candidate = read_snapshot(_path(slot) + ".bak")
	if candidate.is_empty():
		last_error = "Сохранение отсутствует, повреждено или несовместимо."
		return false
	state.data = candidate
	last_error = ""
	bus.publish("loaded", {"slot": slot})
	return true

func read_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return {}
	var candidate: Dictionary = parser.data.duplicate(true)
	if int(candidate.get("version", 0)) == 1:
		candidate["play_seconds"] = candidate.get("play_seconds", 0.0)
		candidate["version"] = 2
	if not valid(candidate):
		return {}
	return candidate

func valid(candidate: Dictionary) -> bool:
	if int(candidate.get("version", 0)) != int(db.table("config").schema_version):
		return false
	for field in ["party", "position"]:
		if not candidate.get(field) is Array:
			return false
	for field in ["inventory", "quest_steps", "flags"]:
		if not candidate.get(field) is Dictionary:
			return false
	if not db.table("maps").has(candidate.get("map", "")) or candidate.position.size() != 2:
		return false
	for value in candidate.position:
		if not _number(value) or value < 0 or value > 1:
			return false
	if not _number(candidate.get("gold")) or candidate.gold < 0 or not _number(candidate.get("play_seconds")):
		return false
	if candidate.party.size() != db.table("config").initial_party.size():
		return false
	var ids: Array = []
	var living_members = 0
	for member in candidate.party:
		if not member is Dictionary or not db.table("characters").has(member.get("id", "")) or member.id in ids:
			return false
		ids.append(member.id)
		for stat in ["hp", "mp", "level", "xp"]:
			if not _number(member.get(stat)) or member[stat] < 0:
				return false
		if member.level < 1 or member.level > db.table("config").battle.level_thresholds.size():
			return false
		if member.level != floor(member.level):
			return false
		if member.hp > 0:
			living_members += 1
		var actor = state.stats(member)
		if member.hp > actor.max_hp or member.mp > actor.max_mp:
			return false
	if living_members == 0:
		return false
	for id in candidate.inventory:
		if not db.table("items").has(id) or not _number(candidate.inventory[id]) or candidate.inventory[id] < 0:
			return false
	if not candidate.quest_steps.has(db.table("config").initial_quest):
		return false
	for id in candidate.quest_steps:
		if not db.table("quests").has(id) or not _number(candidate.quest_steps[id]) or candidate.quest_steps[id] < 0 or candidate.quest_steps[id] > db.entry("quests", id).steps.size():
			return false
	return true

func _number(value) -> bool:
	return (value is float or value is int) and is_finite(float(value))
