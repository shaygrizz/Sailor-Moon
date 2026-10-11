extends SceneTree
const Database = preload("res://scripts/core/content_database.gd")
const EventBus = preload("res://scripts/core/event_bus.gd")
const State = preload("res://scripts/core/game_state.gd")
const Inventory = preload("res://scripts/inventory/inventory_service.gd")
const Quests = preload("res://scripts/quests/quest_service.gd")
const Saves = preload("res://scripts/save/save_service.gd")
const Combat = preload("res://scripts/battle/battle_service.gd")
const World = preload("res://scripts/world/world_service.gd")
var failures: int = 0
var checks: int = 0
var db = Database.new()
var bus = EventBus.new()
var state
var bag
var quests
var saves
var combat

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(db.load_all(), "All catalogs validate: " + str(db.errors))
	state = State.new(db, bus)
	state.reset()
	bag = Inventory.new(state, db, bus)
	quests = Quests.new(state, db, bus, bag)
	saves = Saves.new(state, db, bus, "user://test_saves")
	combat = Combat.new(db, state, bus, bag)
	_test_content_errors()
	_test_quests_and_world()
	_test_saves()
	_test_combat()
	await _test_scene()
	print("TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_content_errors() -> void:
	var invalid = Database.new()
	invalid.load_all()
	invalid.catalogs.skills.moonbeam.cost = "six"
	invalid.validate()
	check(not invalid.errors.is_empty(), "Non-numeric skill cost rejected without crashing")
	invalid.load_all()
	invalid.catalogs.maps.sanctuary.points[0].erase("position")
	invalid.validate()
	check(not invalid.errors.is_empty(), "Malformed map point rejected")
	invalid.load_all()
	invalid.catalogs.interactions.keeper[0].commands[0].type = "unknown"
	invalid.validate()
	check(not invalid.errors.is_empty(), "Unknown event command rejected")

func _test_quests_and_world() -> void:
	var world = World.new(state, db, bus, quests, bag)
	bus.publish("shard_found")
	check(quests.progress("first_star") == 0, "Objectives cannot be skipped")
	world.interact("gate")
	check(state.data.map == "sanctuary", "Gate locked before key")
	world.interact("chest")
	check(bag.count("moonshard") == 0, "Chest waits for keeper")
	bus.publish("keeper_met")
	bus.publish("keeper_met")
	check(quests.progress("first_star") == 1, "Duplicate dialogue events are idempotent")
	world.interact("chest")
	world.interact("chest")
	check(bag.count("moonshard") == 1 and quests.progress("first_star") == 2, "Chest awards exactly once")
	world.interact("gate")
	check(state.data.map == "dream", "Key unlocks travel")
	bus.publish("battle_won", {"id": "other"})
	check(quests.progress("first_star") == 2, "Unrelated encounter cannot progress quest")
	bus.publish("battle_won", {"id": "eclipse"})
	bus.publish("light_restored")
	var gold = state.data.gold
	bus.publish("light_restored")
	check(quests.complete("first_star") and state.data.gold == gold, "Reward only once")
	check(not bag.consume("missing") and not bag.add("missing"), "Unknown items are rejected")

func _test_saves() -> void:
	state.reset()
	check(saves.save_slot(1), "Initial save succeeds")
	state.data.gold = 12
	check(saves.save_slot(1), "Atomic save replacement succeeds")
	state.data.gold = 999
	check(saves.load_slot(1) and state.data.gold == 12, "Save round trip")
	var original = state.data.duplicate(true)
	var corrupt = original.duplicate(true)
	corrupt.party[0].hp = -1
	check(not saves.valid(corrupt), "Negative HP rejected")
	corrupt = original.duplicate(true)
	corrupt.party[0].level = 999
	check(not saves.valid(corrupt), "Out-of-range level rejected")
	corrupt = original.duplicate(true)
	corrupt.party[0].id = "missing"
	check(not saves.valid(corrupt), "Missing actor rejected")
	corrupt = original.duplicate(true)
	corrupt.position = [0]
	check(not saves.valid(corrupt), "Invalid position rejected")
	corrupt = original.duplicate(true)
	corrupt.version = 999
	check(not saves.valid(corrupt), "Future schema rejected")
	var file = FileAccess.open("user://test_saves/slot_1.json", FileAccess.WRITE)
	file.store_string("broken{")
	file.close()
	check(saves.load_slot(1) and state.data.gold == 0, "Corrupt primary recovers backup")
	var legacy = original.duplicate(true)
	legacy.version = 1
	legacy.erase("play_seconds")
	file = FileAccess.open("user://test_saves/legacy.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(saves.read_snapshot("user://test_saves/legacy.json").get("version") == 2, "Version 1 migration")

func _test_combat() -> void:
	state.reset()
	combat.start("eclipse", 10)
	var mp = combat.current().mp
	check(not combat.act("moonbeam", "selene"), "Offensive skill rejects allied target")
	check(combat.current().mp == mp, "Invalid action has no mana cost")
	check(not combat.act("eclipse"), "Ultimate cannot fire without resonance")
	check(not combat.use_item("moonshard", "selene"), "Key item cannot heal")
	check(combat.act("guard"), "Guard is a valid self action")
	check(combat.actor_by_id("selene").guard, "Guard persists through other actors' turns")
	state.reset()
	combat.start("eclipse", 10)
	combat.current().mp = 0
	check(not combat.can_use("moonbeam"), "Insufficient mana disables ability")
	combat.actor_by_id("iris").hp = 0
	check(not combat.use_item("stardrop", "iris"), "Healing item does not silently revive")
	var victories = 0
	for seed_value in range(100):
		state.reset()
		combat.start("eclipse", seed_value)
		var turns = 0
		while combat.active and turns < 200:
			turns += 1
			if combat.current().side == "enemy":
				combat.ai_turn()
			else:
				strategy_turn()
		check(not combat.active, "Seed %d battle terminates" % seed_value)
		if combat.outcome == "victory":
			victories += 1
			check(state.data.party[0].level == 2, "Victory XP levels party")
			check(state.data.gold == db.entry("encounters", "eclipse").gold, "Victory reward")
	check(victories >= 90, "Tutorial battle is consistently winnable: %d/100" % victories)
	print("BATTLE SIMULATION: %d / 100 victories" % victories)

func strategy_turn() -> void:
	var actor = combat.current()
	var wounded = combat.living("party").filter(func(ally): return ally.hp < ally.max_hp * 0.4)
	if not wounded.is_empty() and bag.count("stardrop") > 0:
		combat.use_item("stardrop", wounded[0].id)
		return
	if combat.can_use("eclipse"):
		combat.act("eclipse")
		return
	var target = combat.living("enemy")[0]
	var skill = "moonbeam" if actor.id == "selene" else "starfall"
	combat.act(skill if combat.can_use(skill) else "strike", target.id)

func _test_scene() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.saves.directory = "user://test_saves"
	check(game.ui.screen_kind == "title", "Scene starts on title screen")
	game._new_game()
	for i in range(3):
		game._on_action("dialogue_next", {})
	check(game.mode == "world" and game.dialogue_lines.is_empty(), "Intro reaches playable world")
	game._on_action("interact", {"id": "keeper"})
	for i in range(3):
		game._on_action("dialogue_next", {})
	game._on_action("interact", {"id": "chest"})
	game._on_action("interact", {"id": "gate"})
	check(game.session.data.map == "dream", "Scene routes world travel")
	game._on_action("interact", {"id": "boss"})
	check(game.mode == "battle", "Scene enters battle")
	game._on_action("battle_skill", {"id": "moonbeam"})
	game._on_action("battle_target", {"id": "wisp0"})
	check(game.battle.current().id == "iris", "View intentions advance battle")
	var original_combat = combat
	var original_bag = bag
	combat = game.battle
	bag = game.inventory
	while combat.active:
		if combat.current().side == "enemy":
			combat.ai_turn()
		else:
			strategy_turn()
	check(combat.outcome == "victory", "Full scene battle is winnable")
	game._on_action("battle_exit", {})
	game._on_action("interact", {"id": "return"})
	game._on_action("interact", {"id": "keeper"})
	for i in range(3):
		game._on_action("dialogue_next", {})
	check(game.quests.complete("first_star"), "Chapter playable through final dialogue")
	check(game.session.data.gold == 75, "Battle and chapter rewards compose correctly")
	check(game.saves.load_slot(0) and game.quests.complete("first_star"), "Completed chapter survives save/load")
	combat = original_combat
	bag = original_bag
	await process_frame
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
