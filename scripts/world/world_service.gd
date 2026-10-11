extends RefCounted
## Declarative command runner. Map/NPC/story content is supplied by JSON.
signal dialogue_requested(id: String, completion_topic: String)
signal battle_requested(id: String)
signal notice_requested(message: String)
signal location_changed
var state
var db
var bus
var inventory

func _init(session, database, events, _journal, bag) -> void:
	state = session
	db = database
	bus = events
	inventory = bag

func interact(point_id: String) -> void:
	for point in db.entry("maps", state.data.map).points:
		if point.id != point_id:
			continue
		for branch in db.table("interactions").get(point.interaction, []):
			if _matches(branch.when):
				for command in branch.commands:
					_execute(command)
				return

func _matches(conditions: Array) -> bool:
	for condition in conditions:
		var value = state.data
		for key in condition.path.split("."):
			value = value.get(key) if value is Dictionary else null
		if value != condition.equals:
			return false
	return true

func _execute(command: Dictionary) -> void:
	match command.type:
		"dialogue": dialogue_requested.emit(command.id, command.get("topic", ""))
		"notice": notice_requested.emit(command.text)
		"restore_party": state.restore_party()
		"flag": state.data.flags[command.id] = command.value
		"item": inventory.add(command.id, int(command.amount))
		"event": bus.publish(command.topic, command.get("payload", {}))
		"battle": battle_requested.emit(command.id)
		"travel":
			state.data.map = command.id
			state.data.position = db.table("config").world.player_spawn.duplicate()
			location_changed.emit()
			bus.publish("world_changed")
