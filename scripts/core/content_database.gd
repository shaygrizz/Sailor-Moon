extends RefCounted
## Loads catalogs and deterministic, ordered content-pack overrides before play.
var catalogs: Dictionary = {}
var errors: Array[String] = []

func load_all(manifest_path: String = "res://data/manifest.json") -> bool:
	catalogs.clear()
	errors.clear()
	var manifest = _read(manifest_path)
	for key in manifest.get("catalogs", {}):
		catalogs[key] = _read(manifest.catalogs[key])
	for path in manifest.get("mods", []):
		var pack = _read(path)
		for catalog in pack.get("catalogs", {}):
			if not catalogs.has(catalog) or catalog == "config":
				errors.append("Unsupported mod catalog: " + catalog)
				continue
			catalogs[catalog].merge(pack.catalogs[catalog], true)
	validate()
	return errors.is_empty()

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("Missing file: " + path)
		return {}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		errors.append("Invalid JSON object: " + path)
		return {}
	return parser.data

func table(catalog: String) -> Dictionary:
	return catalogs.get(catalog, {})

func entry(catalog: String, id: String) -> Dictionary:
	return table(catalog).get(id, {})

func validate() -> void:
	for key in ["config", "characters", "enemies", "skills", "items", "quests", "dialogues", "maps", "encounters", "interactions"]:
		if table(key).is_empty():
			errors.append("Empty catalog: " + key)
	if not errors.is_empty():
		return
	_validate_shapes()
	if not errors.is_empty():
		return
	for catalog in ["characters", "enemies"]:
		for id in table(catalog):
			var actor = entry(catalog, id)
			for stat in ["max_hp", "max_mp", "attack", "defense", "speed"]:
				if not actor.get(stat) is float and not actor.get(stat) is int:
					errors.append(id + ": invalid " + stat)
				elif actor[stat] < 0 or (stat == "max_hp" and actor[stat] == 0):
					errors.append(id + ": negative/zero stat " + stat)
			for skill in actor.get("skills", []):
				_reference("skills", skill, id)
			if catalog == "characters":
				_reference("skills", actor.ultimate, id)
	for id in table("skills"):
		var skill = entry("skills", id)
		if skill.get("kind", "") not in ["damage", "heal", "guard"] or skill.get("target", "") not in ["enemy", "ally", "self", "all_enemies"]:
			errors.append("Invalid skill: " + id)
		if skill.get("cost", -1) < 0 or skill.get("power", -1) < 0:
			errors.append("Invalid skill cost/power: " + id)
	for id in table("encounters"):
		for enemy in entry("encounters", id).get("enemies", []):
			_reference("enemies", enemy, id)
	for id in table("maps"):
		for point in entry("maps", id).get("points", []):
			_reference("interactions", point.get("interaction", ""), id)
	for id in table("interactions"):
		for branch in table("interactions")[id]:
			for command in branch.commands:
				if command.type in ["travel", "battle", "dialogue", "item"]:
					var catalog = {"travel": "maps", "battle": "encounters", "dialogue": "dialogues", "item": "items"}[command.type]
					_reference(catalog, command.id, id)
	for id in table("config").initial_party:
		_reference("characters", id, "initial_party")
	_reference("maps", table("config").initial_map, "config")
	_reference("quests", table("config").initial_quest, "config")

func _reference(catalog: String, id: String, owner: String) -> void:
	if not table(catalog).has(id):
		errors.append(owner + " references missing " + catalog + "/" + id)

func _fields(value, spec: Dictionary, owner: String) -> bool:
	if not value is Dictionary:
		errors.append(owner + " must be an object")
		return false
	var valid = true
	for key in spec:
		var field = value.get(key)
		var matches = false
		match spec[key]:
			"string": matches = field is String
			"number": matches = (field is float or field is int) and is_finite(float(field))
			"array": matches = field is Array
			"object": matches = field is Dictionary
			"bool": matches = field is bool
		if not matches:
			errors.append(owner + "." + key + " must be " + spec[key])
			valid = false
	return valid

func _ids(values: Array, owner: String) -> void:
	if values.is_empty():
		errors.append(owner + " cannot be empty")
	for value in values:
		if not value is String:
			errors.append(owner + " must contain string ids")

func _vector(value: Array, count: int, owner: String) -> void:
	if value.size() != count:
		errors.append(owner + " has wrong length")
	for number in value:
		if not (number is float or number is int):
			errors.append(owner + " must contain numbers")

func _validate_shapes() -> void:
	var cfg = table("config")
	if _fields(cfg, {"initial_map": "string", "initial_party": "array", "initial_inventory": "object", "initial_gold": "number", "initial_quest": "string", "schema_version": "number", "save_slots": "number", "world": "object", "battle": "object", "presentation": "object"}, "config"):
		_ids(cfg.initial_party, "initial_party")
		if _fields(cfg.world, {"speed": "number", "arrival_distance": "number", "interact_distance": "number", "player_spawn": "array", "bounds": "array"}, "world"):
			_vector(cfg.world.player_spawn, 2, "player_spawn")
			_vector(cfg.world.bounds, 4, "bounds")
			if cfg.world.speed <= 0:
				errors.append("world.speed must be positive")
		var battle_fields = {}
		for key in ["defense_factor", "minimum_damage", "critical_chance", "critical_multiplier", "weakness_multiplier", "guard_multiplier", "guard_mana", "ultimate_cost", "gauge_per_hit", "turn_delay", "max_rounds", "start_gauge"]:
			battle_fields[key] = "number"
		battle_fields.merge({"variance": "array", "level_thresholds": "array", "level_growth": "object"})
		if _fields(cfg.battle, battle_fields, "battle"):
			_vector(cfg.battle.variance, 2, "variance")
			if cfg.battle.level_thresholds.is_empty():
				errors.append("level_thresholds cannot be empty")
			for threshold in cfg.battle.level_thresholds:
				if not (threshold is float or threshold is int):
					errors.append("level_thresholds must contain numbers")
			_fields(cfg.battle.level_growth, {"max_hp": "number", "max_mp": "number", "attack": "number", "defense": "number", "speed": "number"}, "level_growth")
		_fields(cfg.presentation, {"transition_seconds": "number", "particle_count": "number", "particle_speed": "number", "music_volume_db": "number", "sfx_volume_db": "number"}, "presentation")
	var actors = {"name": "string", "color": "string", "max_hp": "number", "max_mp": "number", "attack": "number", "defense": "number", "speed": "number", "skills": "array"}
	for catalog in ["characters", "enemies"]:
		for id in table(catalog):
			var value = table(catalog)[id]
			if _fields(value, actors, id):
				_ids(value.skills, id + ".skills")
				if catalog == "characters":
					_fields(value, {"portrait": "string", "ultimate": "string"}, id)
	for id in table("skills"):
		_fields(table("skills")[id], {"name": "string", "kind": "string", "target": "string", "element": "string", "power": "number", "cost": "number"}, id)
	for id in table("items"):
		_fields(table("items")[id], {"name": "string", "kind": "string", "description": "string"}, id)
	for id in table("encounters"):
		var value = table("encounters")[id]
		if _fields(value, {"name": "string", "enemies": "array", "xp": "number", "gold": "number"}, id):
			_ids(value.enemies, id + ".enemies")
	for id in table("maps"):
		var value = table("maps")[id]
		if _fields(value, {"name": "string", "region": "string", "background": "string", "points": "array"}, id):
			for point in value.points:
				if _fields(point, {"id": "string", "name": "string", "icon": "string", "position": "array", "interaction": "string"}, id + ".point"):
					_vector(point.position, 2, id + ".point.position")
	for id in table("dialogues"):
		if not table("dialogues")[id] is Array or table("dialogues")[id].is_empty():
			errors.append(id + " must contain dialogue lines")
			continue
		for line in table("dialogues")[id]:
			_fields(line, {"speaker": "string", "text": "string"}, id)
	for id in table("quests"):
		var value = table("quests")[id]
		if _fields(value, {"name": "string", "steps": "array", "reward": "object"}, id):
			_fields(value.reward, {"gold": "number", "items": "object"}, id + ".reward")
			for step in value.steps:
				_fields(step, {"topic": "string", "text": "string"}, id + ".step")
	var commands = {"travel": {"id": "string"}, "battle": {"id": "string"}, "dialogue": {"id": "string"}, "item": {"id": "string", "amount": "number"}, "flag": {"id": "string", "value": "bool"}, "event": {"topic": "string"}, "notice": {"text": "string"}, "restore_party": {}}
	for id in table("interactions"):
		if not table("interactions")[id] is Array:
			errors.append(id + " must contain branches")
			continue
		for branch in table("interactions")[id]:
			if not _fields(branch, {"when": "array", "commands": "array"}, id):
				continue
			for condition in branch.when:
				if _fields(condition, {"path": "string"}, id) and not condition.has("equals"):
					errors.append(id + " condition needs equals")
			for command in branch.commands:
				if not _fields(command, {"type": "string"}, id):
					continue
				if not commands.has(command.type):
					errors.append(id + " unknown command: " + command.type)
				else:
					_fields(command, commands[command.type], id)
