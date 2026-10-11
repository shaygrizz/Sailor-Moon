extends RefCounted
## Separate action-mode content boundary; legacy JRPG data is never interpreted here.
var config: Dictionary
var characters: Dictionary
var skills: Dictionary
var levels: Dictionary
var story: Dictionary
var audio: Dictionary
var errors: Array[String] = []

func load_all() -> bool:
	config = _read("config")
	characters = _read("characters")
	skills = _read("skills")
	levels = _read("levels")
	story = _read("story")
	audio = _read("audio")
	if not errors.is_empty(): return false
	for id in characters:
		var actor = characters[id]
		for field in ["name", "title", "sheet", "primary", "special", "row", "columns", "rows", "hp", "energy", "color"]:
			if not actor.has(field): errors.append("Missing character field: " + id + "/" + field)
		if not skills.has(actor.get("primary", "")) or not skills.has(actor.get("special", "")):
			errors.append("Unknown ability: " + id)
	for id in skills:
		for key in ["damage", "cost", "cooldown", "speed", "lifetime", "radius", "slow_seconds"]:
			if not skills[id].get(key) is float and not skills[id].get(key) is int:
				errors.append("Invalid ability number: " + id + "/" + key)
	return errors.is_empty()

func _read(id: String) -> Dictionary:
	var parser = JSON.new()
	var path = "res://data/action/%s.json" % id
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		errors.append("Invalid action catalog: " + path)
		return {}
	return parser.data
