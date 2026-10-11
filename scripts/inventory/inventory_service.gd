extends RefCounted
var state
var db
var bus

func _init(session, database, events) -> void:
	state = session
	db = database
	bus = events

func count(id: String) -> int:
	return int(state.data.inventory.get(id, 0))

func add(id: String, amount: int = 1) -> bool:
	if not db.table("items").has(id) or amount <= 0:
		return false
	state.data.inventory[id] = count(id) + amount
	bus.publish("inventory_changed", {"id": id, "count": count(id)})
	return true

func consume(id: String) -> bool:
	if count(id) < 1:
		return false
	state.data.inventory[id] = count(id) - 1
	bus.publish("inventory_changed", {"id": id, "count": count(id)})
	return true
