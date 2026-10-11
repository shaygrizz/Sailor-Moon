extends RefCounted
## Ordered, idempotent objectives listen to domain events, never to UI nodes.
var state
var db
var bus
var inventory

func _init(session, database, events, bag) -> void:
	state = session
	db = database
	bus = events
	inventory = bag
	bus.event_published.connect(_on_event)

func progress(id: String) -> int:
	return int(state.data.quest_steps.get(id, 0))

func complete(id: String) -> bool:
	return progress(id) >= db.entry("quests", id).steps.size()

func objective(id: String) -> String:
	if complete(id):
		return "Первая звезда снова сияет. Глава завершена."
	return db.entry("quests", id).steps[progress(id)].text

func _on_event(topic: String, payload: Dictionary) -> void:
	for id in state.data.get("quest_steps", {}):
		if complete(id):
			continue
		var quest = db.entry("quests", id)
		var step = quest.steps[progress(id)]
		if step.topic != topic or (step.has("match") and payload.get("id", "") != step.match):
			continue
		state.data.quest_steps[id] = progress(id) + 1
		if complete(id):
			state.data.gold += quest.reward.gold
			for item in quest.reward.items:
				inventory.add(item, int(quest.reward.items[item]))
		bus.publish("quest_changed", {"id": id, "complete": complete(id)})
