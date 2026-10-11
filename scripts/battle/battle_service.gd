extends RefCounted
## Pure turn resolver: no nodes, timers or UI. The view schedules AI turns.
var db
var state
var bus
var inventory
var rng = RandomNumberGenerator.new()
var actors: Array = []
var order: Array = []
var cursor: int = 0
var round_number: int = 0
var gauge: int = 0
var active: bool = false
var outcome: String = ""
var encounter_id: String = ""
var log_lines: Array[String] = []
var rules: Dictionary

func _init(database, session, events, bag) -> void:
	db = database
	state = session
	bus = events
	inventory = bag
	rules = db.table("config").battle
	rng.randomize()

func start(id: String, seed_value: int = -1) -> void:
	actors.clear()
	log_lines.clear()
	encounter_id = id
	active = true
	outcome = ""
	if seed_value >= 0:
		rng.seed = seed_value
	gauge = int(rules.start_gauge)
	round_number = 0
	for member in state.data.party:
		var actor = state.stats(member)
		actor.merge({"id": member.id, "side": "party", "hp": member.hp, "mp": member.mp, "guard": false}, true)
		actors.append(actor)
	var enemy_index = 0
	for enemy_id in db.entry("encounters", id).enemies:
		var actor = db.entry("enemies", enemy_id).duplicate(true)
		actor.merge({"id": enemy_id + str(enemy_index), "side": "enemy", "hp": actor.max_hp, "mp": actor.max_mp, "guard": false}, true)
		actors.append(actor)
		enemy_index += 1
	_new_round()
	_note("Тени преграждают путь. Найдите их слабость.")
	bus.publish("battle_changed")

func current() -> Dictionary:
	if not active or order.is_empty():
		return {}
	return actors[order[cursor]]

func living(side: String) -> Array:
	return actors.filter(func(actor): return actor.side == side and actor.hp > 0)

func actor_by_id(id: String) -> Dictionary:
	for actor in actors:
		if actor.id == id:
			return actor
	return {}

func can_use(skill_id: String) -> bool:
	var actor = current()
	var skill = db.entry("skills", skill_id)
	if actor.is_empty() or skill.is_empty():
		return false
	if not skill_id in actor.skills and actor.get("ultimate", "") != skill_id:
		return false
	if skill.get("ultimate", false) and (gauge < rules.ultimate_cost or living("party").size() != state.data.party.size()):
		return false
	return actor.mp >= skill.cost

func act(skill_id: String, target_id: String = "") -> bool:
	if not can_use(skill_id):
		return false
	var actor = current()
	var skill = db.entry("skills", skill_id)
	var targets: Array = []
	var target_side = actor.side if skill.target in ["ally", "self"] else ("enemy" if actor.side == "party" else "party")
	if skill.target == "self":
		targets = [actor]
	elif skill.target == "all_enemies":
		targets = living(target_side)
	else:
		var target = actor_by_id(target_id)
		if target.is_empty() or target.hp <= 0 or target.side != target_side:
			return false
		targets = [target]
	actor.mp -= skill.cost
	if skill.get("ultimate", false):
		gauge -= int(rules.ultimate_cost)
	for target in targets:
		_resolve(actor, target, skill)
	_finish_action()
	return true

func use_item(item_id: String, target_id: String) -> bool:
	var actor = current()
	var target = actor_by_id(target_id)
	var item = db.entry("items", item_id)
	if actor.is_empty() or actor.side != "party" or target.is_empty() or target.side != "party" or target.hp <= 0 or item.get("kind", "") != "heal":
		return false
	if not inventory.consume(item_id):
		return false
	var healed = mini(int(item.power), int(target.max_hp - target.hp))
	target.hp += healed
	_note("%s: %s, +%d HP" % [target.name, item.name, healed])
	_finish_action()
	return true

func ai_turn() -> void:
	if current().is_empty() or current().side != "enemy":
		return
	var choices = living("party")
	if choices.is_empty():
		return
	var actor = current()
	var skill_id = actor.skills[rng.randi_range(0, actor.skills.size() - 1)]
	act(skill_id, choices[rng.randi_range(0, choices.size() - 1)].id)

func _resolve(actor: Dictionary, target: Dictionary, skill: Dictionary) -> void:
	if skill.kind == "guard":
		actor.guard = true
		actor.mp = mini(int(actor.max_mp), int(actor.mp + rules.guard_mana))
		_note(actor.name + " защищается и восстанавливает ману.")
	elif skill.kind == "heal":
		var healed = mini(int(skill.power), int(target.max_hp - target.hp))
		target.hp += healed
		_note("%s ▸ %s: +%d HP" % [skill.name, target.name, healed])
	else:
		var weak = target.get("weakness", "") == skill.element
		var crit = rng.randf() < rules.critical_chance
		var raw = actor.attack * skill.power - target.defense * rules.defense_factor
		raw *= rng.randf_range(rules.variance[0], rules.variance[1])
		if weak:
			raw *= rules.weakness_multiplier
		if crit:
			raw *= rules.critical_multiplier
		if target.guard:
			raw *= rules.guard_multiplier
		var damage = maxi(int(rules.minimum_damage), int(round(raw)))
		target.hp = maxi(0, int(target.hp) - damage)
		if actor.side == "party":
			gauge = mini(int(rules.ultimate_cost), gauge + int(rules.gauge_per_hit))
		_note("%s ▸ %s: −%d HP%s%s" % [skill.name, target.name, damage, " · СЛАБОСТЬ" if weak else "", " · КРИТ" if crit else ""])
		bus.publish("battle_hit", {"id": target.id, "damage": damage, "weak": weak})

func _finish_action() -> void:
	if living("enemy").is_empty():
		_end("victory")
	elif living("party").is_empty():
		_end("defeat")
	else:
		cursor += 1
		while cursor < order.size() and actors[order[cursor]].hp <= 0:
			cursor += 1
		if cursor >= order.size():
			_new_round()
		if active:
			current().guard = false
	bus.publish("battle_changed")

func _new_round() -> void:
	round_number += 1
	if round_number > rules.max_rounds:
		_end("defeat")
		return
	order.clear()
	for i in range(actors.size()):
		if actors[i].hp > 0:
			order.append(i)
	order.sort_custom(func(a, b): return actors[a].speed > actors[b].speed)
	cursor = 0

func _end(result: String) -> void:
	active = false
	outcome = result
	if result == "victory":
		for member in state.data.party:
			var actor = actor_by_id(member.id)
			member.hp = maxi(1, int(actor.hp))
			member.mp = actor.mp
		var encounter = db.entry("encounters", encounter_id)
		state.data.gold += encounter.gold
		state.award_xp(int(encounter.xp))
		state.data.flags["won_" + encounter_id] = true
		bus.publish("battle_won", {"id": encounter_id})
	else:
		state.restore_party()
	bus.publish("battle_ended", {"outcome": result, "id": encounter_id})

func _note(message: String) -> void:
	log_lines.append(message)
	bus.publish("battle_log", {"text": message})
