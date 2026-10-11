extends Control
## Composition root: owns lifetimes and connects services to the replaceable Godot view.
const Database = preload("res://scripts/core/content_database.gd")
const EventBus = preload("res://scripts/core/event_bus.gd")
const State = preload("res://scripts/core/game_state.gd")
const Inventory = preload("res://scripts/inventory/inventory_service.gd")
const Quests = preload("res://scripts/quests/quest_service.gd")
const Saves = preload("res://scripts/save/save_service.gd")
const Combat = preload("res://scripts/battle/battle_service.gd")
const World = preload("res://scripts/world/world_service.gd")
const View = preload("res://scripts/ui/game_ui.gd")
const Audio = preload("res://scripts/audio/audio_service.gd")
const InputSetup = preload("res://scripts/input/input_setup.gd")
const ThemeKit = preload("res://scripts/ui/skin.gd")
var db = Database.new()
var bus = EventBus.new()
var session
var inventory
var quests
var saves
var battle
var world
var ui
var audio
var mode: String = "title"
var dialogue_lines: Array = []
var dialogue_index: int = 0
var dialogue_topic: String = ""
var ai_timer: Timer
var refresh_pending: bool = false
var resize_pending: bool = false

func _ready() -> void:
	InputSetup.install()
	if not db.load_all():
		var failure = Label.new()
		failure.text = "Content validation failed:\n" + "\n".join(db.errors)
		add_child(failure)
		push_error(failure.text)
		return
	session = State.new(db, bus)
	session.reset()
	inventory = Inventory.new(session, db, bus)
	quests = Quests.new(session, db, bus, inventory)
	saves = Saves.new(session, db, bus)
	battle = Combat.new(db, session, bus, inventory)
	world = World.new(session, db, bus, quests, inventory)
	ui = View.new()
	add_child(ui)
	ui.setup(db, session, quests, inventory, battle)
	ui.action_requested.connect(_on_action)
	world.dialogue_requested.connect(_start_dialogue)
	world.battle_requested.connect(_start_battle)
	world.notice_requested.connect(func(message): ui.notify(message))
	bus.event_published.connect(_on_event)
	audio = Audio.new()
	add_child(audio)
	audio.configure(db.table("config").presentation)
	ai_timer = Timer.new()
	ai_timer.one_shot = true
	ai_timer.wait_time = db.table("config").battle.turn_delay
	add_child(ai_timer)
	ai_timer.timeout.connect(func():
		if mode == "battle" and not is_instance_valid(ui.modal): battle.ai_turn())
	resized.connect(_schedule_resize)
	_resize_and_render()

func _process(delta: float) -> void:
	if session != null and mode != "title":
		session.data.play_seconds += delta

func _schedule_resize() -> void:
	if not resize_pending:
		resize_pending = true
		call_deferred("_resize_and_render")

func _resize_and_render() -> void:
	resize_pending = false
	var window = get_window()
	var portrait = float(window.size.x) / maxf(window.size.y, 1) < 0.85
	var reference = Vector2i(540, 960) if portrait else Vector2i(1280, 720)
	if window.content_scale_size != reference:
		window.content_scale_size = reference
	if ui != null:
		_render()
		if not dialogue_lines.is_empty():
			_show_dialogue()
		elif is_instance_valid(ui.modal):
			_menu()

func _render() -> void:
	refresh_pending = false
	match mode:
		"title": ui.title(saves.exists(0))
		"world": ui.exploration()
		"battle": ui.combat()
	if is_instance_valid(ui.modal) and is_instance_valid(ui.world_view):
		ui.world_view.enabled = false
	if mode == "battle" and battle.active and battle.current().side == "enemy" and not is_instance_valid(ui.modal) and ai_timer.is_stopped():
		ai_timer.start()

func _refresh() -> void:
	if not refresh_pending:
		refresh_pending = true
		call_deferred("_render")

func _on_action(action: String, payload: Dictionary) -> void:
	if action != "position":
		audio.click()
	match action:
		"new_game":
			if saves.exists(0):
				var body = ui.open_modal("Новое путешествие")
				body.add_child(ThemeKit.paragraph("Автосохранение будет заменено. Ручные слоты останутся доступны."))
				body.add_child(ThemeKit.button("Начать новую игру", func(): _new_game(), true))
			else:
				_new_game()
		"position": session.data.position = [payload.value.x, payload.value.y]
		"interact":
			world.interact(payload.id)
			if mode == "world":
				_autosave()
				_refresh()
		"menu": _menu()
		"close_modal":
			dialogue_lines.clear()
			ui.close_modal()
			_render()
		"dialogue_next":
			dialogue_index += 1
			if dialogue_index < dialogue_lines.size():
				_show_dialogue()
			else:
				dialogue_lines.clear()
				ui.close_modal()
				if dialogue_topic != "":
					bus.publish(dialogue_topic)
				_autosave()
				_render()
		"load":
			if saves.load_slot(int(payload.slot)):
				battle.active = false
				ai_timer.stop()
				dialogue_lines.clear()
				mode = "world"
				ui.close_modal()
				audio.set_enabled(true)
				audio.play_music("exploration")
				_render()
			else:
				ui.notify(saves.last_error)
		"save":
			if mode == "world":
				ui.notify("Сохранено в слот %d" % payload.slot if saves.save_slot(int(payload.slot)) else saves.last_error)
		"battle_skill":
			var skill = db.entry("skills", payload.id)
			if skill.target in ["self", "all_enemies"]:
				battle.act(payload.id)
			else:
				ui.selected_skill = payload.id
				ui.selected_item = ""
				_render()
		"battle_item":
			ui.selected_item = payload.id
			ui.selected_skill = ""
			_render()
		"battle_target":
			var accepted = battle.use_item(ui.selected_item, payload.id) if ui.selected_item != "" else battle.act(ui.selected_skill, payload.id)
			if accepted:
				ui.selected_skill = ""
				ui.selected_item = ""
			else:
				ui.notify("Сейчас это действие недоступно.")
		"battle_cancel":
			ui.selected_item = ""
			ui.selected_skill = ""
			_render()
		"battle_exit":
			if battle.active:
				return
			mode = "world"
			if battle.outcome == "defeat":
				session.data.map = db.table("config").initial_map
				session.data.position = db.table("config").world.player_spawn.duplicate()
			audio.play_music("exploration")
			_autosave()
			_render()

func _new_game() -> void:
	session.reset()
	mode = "world"
	ui.close_modal()
	audio.set_enabled(true)
	audio.play_music("exploration")
	_autosave()
	_render()
	_start_dialogue("intro", "")

func _start_dialogue(id: String, topic: String) -> void:
	dialogue_lines = db.table("dialogues")[id]
	dialogue_index = 0
	dialogue_topic = topic
	_show_dialogue()

func _show_dialogue() -> void:
	var line = dialogue_lines[dialogue_index]
	ui.dialogue(line.speaker, line.text, dialogue_index == dialogue_lines.size() - 1)

func _start_battle(id: String) -> void:
	_autosave()
	mode = "battle"
	ui.close_modal()
	battle.start(id)
	audio.play_music("battle")
	_render()

func _autosave() -> void:
	if not saves.save_slot(0):
		ui.notify(saves.last_error)

func _on_event(topic: String, payload: Dictionary) -> void:
	if topic == "battle_changed":
		_refresh()
	elif topic == "quest_changed":
		ui.notify("Глава завершена! Награда добавлена в сумку." if payload.complete else "Дневник обновлён")
	elif topic == "level_up":
		ui.notify("%s достигает уровня %d" % [db.entry("characters", payload.id).name, payload.level])

func _menu() -> void:
	ai_timer.stop()
	var body = ui.open_modal("Лунный дневник")
	if mode != "title":
		body.add_child(ThemeKit.paragraph(quests.objective(db.table("config").initial_quest)))
		body.add_child(ThemeKit.label("Сумка  ·  %d золота" % session.data.gold, 22, Color("dfc99c")))
		for id in session.data.inventory:
			if inventory.count(id) > 0:
				var item = db.entry("items", id)
				body.add_child(ThemeKit.paragraph("%s ×%d — %s" % [item.name, inventory.count(id), item.description], 18))
	body.add_child(ThemeKit.label("Сохранения", 22, Color("dfc99c")))
	var auto_button = ThemeKit.button("Загрузить автосохранение", func(): _on_action("load", {"slot": 0}))
	auto_button.disabled = not saves.exists(0)
	body.add_child(auto_button)
	for slot in range(1, int(db.table("config").save_slots) + 1):
		var row = HBoxContainer.new()
		body.add_child(row)
		var save_button = ThemeKit.button("Сохранить · %d" % slot, func(): _on_action("save", {"slot": slot}))
		save_button.disabled = mode != "world"
		save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(save_button)
		var load_button = ThemeKit.button("Загрузить · %d" % slot, func(): _on_action("load", {"slot": slot}))
		load_button.disabled = not saves.exists(slot)
		load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(load_button)
	var sound_button = CheckButton.new()
	sound_button.text = "Музыка и звуки"
	sound_button.button_pressed = audio.enabled
	sound_button.toggled.connect(func(value): audio.set_enabled(value))
	body.add_child(sound_button)
	body.add_child(ThemeKit.paragraph("Сохранения хранятся в этом браузере. Очистка данных сайта удаляет их. В бою доступна загрузка, а сохранение — после боя.", 17))
	var debug_button = CheckButton.new()
	debug_button.text = "Монитор производительности (F3)"
	debug_button.button_pressed = ui.show_debug
	debug_button.toggled.connect(func(value): ui.show_debug = value)
	body.add_child(debug_button)
	if mode != "title":
		body.add_child(ThemeKit.button("На главный экран", func():
			if mode == "world": _autosave()
			battle.active = false
			dialogue_lines.clear()
			mode = "title"
			ui.close_modal()
			_render()))

func _unhandled_input(event: InputEvent) -> void:
	if ui == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		ui.show_debug = not ui.show_debug
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(ui.modal):
			_on_action("close_modal", {})
		else:
			_menu()
		get_viewport().set_input_as_handled()
