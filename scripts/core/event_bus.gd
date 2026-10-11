extends RefCounted
## Injected signal boundary. No global singleton or service lookup.
signal event_published(topic: String, payload: Dictionary)

func publish(topic: String, payload: Dictionary = {}) -> void:
	event_published.emit(topic, payload)
