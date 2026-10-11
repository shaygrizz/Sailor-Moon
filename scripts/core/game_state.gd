extends RefCounted
## Mutable session data only. Services receive this instance by injection.
var data: Dictionary = {}
var db
var bus

func _init(database, events) -> void:
	db = database
	bus = events

func reset() -> void:
	var cfg = db.table("config")
	var party: Array = []
	for id in cfg.initial_party:
		var actor = db.entry("characters", id)
		party.append({"id": id, "hp": actor.max_hp, "mp": actor.max_mp, "level": 1, "xp": 0})
	data = {"version": cfg.schema_version, "map": cfg.initial_map,
		"position": cfg.world.player_spawn.duplicate(), "party": party,
		"inventory": cfg.initial_inventory.duplicate(true), "gold": cfg.initial_gold,
		"quest_steps": {cfg.initial_quest: 0}, "flags": {}, "play_seconds": 0.0}
	bus.publish("state_reset")

func stats(member: Dictionary) -> Dictionary:
	var actor = db.entry("characters", member.id).duplicate(true)
	for key in db.table("config").battle.level_growth:
		actor[key] += (member.level - 1) * db.table("config").battle.level_growth[key]
	return actor

func restore_party() -> void:
	for member in data.party:
		var actor = stats(member)
		member.hp = actor.max_hp
		member.mp = actor.max_mp
	bus.publish("party_changed")

func award_xp(amount: int) -> void:
	var thresholds = db.table("config").battle.level_thresholds
	for member in data.party:
		member.xp += amount
		var old_level = member.level
		while member.level < thresholds.size() and member.xp >= thresholds[member.level]:
			member.level += 1
		if old_level != member.level:
			var actor = stats(member)
			member.hp = actor.max_hp
			member.mp = actor.max_mp
			bus.publish("level_up", {"id": member.id, "level": member.level})
	bus.publish("party_changed")
