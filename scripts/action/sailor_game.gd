extends Node
## Windows action-game composition root. All story content is supplied by action catalogs.
const Catalog = preload("res://scripts/action/catalog.gd")
const Controls = preload("res://scripts/action/controls.gd")
const UI = preload("res://scripts/action/action_ui.gd")
const Level = preload("res://scripts/action/level.gd")
const Save = preload("res://scripts/action/native_save.gd")
const Music = preload("res://scripts/action/music_director.gd")
var db = Catalog.new()
var ui
var level
var music
var saves
var mode: String = "title"
var selected: String = "moon"
var dialog_id: String = ""
var dialog_index: int = 0
var overlay_kind: String = ""
var pending: Dictionary = {}
var loading_paths: Array[String] = []
var loading_age: float = 0
var checkpoint: Dictionary = {}
var settings_file: String = "user://action_settings.json"
var language: String = "ru"

func _ready() -> void:
	Controls.install()
	if not db.load_all():
		push_error(str(db.errors))
		return
	saves = Save.new(db)
	music = Music.new()
	add_child(music)
	music.configure(db.audio)
	_load_settings()
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	ui = UI.new()
	canvas.add_child(ui)
	ui.configure(db)
	ui.language = language
	ui.selected_character = selected
	ui.action_requested.connect(_action)
	_show_title()

func _show_title() -> void:
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	level = null
	mode = "title"
	ui.selected_character = selected
	ui.title(not saves.load_game().is_empty())
	overlay_kind = ""
	dialog_id = ""
	music.play_music("menu")

func _start(game_mode: String, actor_id: String, snapshot: Dictionary = {}) -> void:
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	level = null
	overlay_kind = ""
	dialog_id = ""
	pending = {"mode": game_mode, "actor": actor_id, "snapshot": snapshot}
	mode = "loading"
	loading_paths.clear()
	for path in [db.levels[db.config.initial_level].background, db.characters[actor_id].sheet, "res://assets/sprites/yoma_luna.png"]:
		loading_paths.append(path)
		ResourceLoader.load_threaded_request(path)
	loading_age = 0
	ui.selected_character = actor_id
	ui.loading(0)

func _process(delta: float) -> void:
	if mode == "loading":
		loading_age += delta
		var total: float = 0
		var all_ready = true
		for path in loading_paths:
			var progress: Array = []
			var status = ResourceLoader.load_threaded_get_status(path, progress)
			if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_show_title()
				ui.dialogue("Ошибка загрузки", "Не удалось загрузить ресурс: " + path)
				overlay_kind = "error"
				return
			total += float(progress[0]) if not progress.is_empty() else 0
			if status != ResourceLoader.THREAD_LOAD_LOADED: all_ready = false
		ui.loading(total / loading_paths.size())
		if all_ready and loading_age >= 0.45:
			for path in loading_paths: ResourceLoader.load_threaded_get(path)
			_finish_start()
	elif is_instance_valid(level):
		ui.update_hud(level.player, level.boss_alive)

func _finish_start() -> void:
	mode = pending.mode
	selected = pending.actor
	level = Level.new()
	add_child(level)
	level.setup(db, mode, selected, pending.snapshot)
	level.checkpoint_reached.connect(_checkpoint)
	level.player_defeated.connect(_defeated)
	level.completed.connect(_complete)
	level.story_cue.connect(_dialogue)
	level.feedback.connect(_feedback)
	ui.hud(level.player.actor, mode)
	music.play_music("exploration")
	checkpoint = level.snapshot(mode)
	if pending.snapshot.is_empty():
		_save()
		if mode == "story": _dialogue("intro")
	elif pending.snapshot.get("completed", false):
		_pause()
		overlay_kind = "result"
		ui.result(true, mode == "practice")
	pending.clear()

func _pause() -> void:
	if is_instance_valid(level): level.process_mode = Node.PROCESS_MODE_DISABLED

func _resume() -> void:
	ui.close_overlay()
	overlay_kind = ""
	dialog_id = ""
	if is_instance_valid(level): level.process_mode = Node.PROCESS_MODE_INHERIT

func _action(id: String, payload: Dictionary) -> void:
	if id != "volume": music.play_sfx("menu")
	match id:
		"story": _start("story", "moon")
		"practice": _start("practice", selected)
		"continue":
			var snapshot = saves.load_game()
			if not snapshot.is_empty(): _start(snapshot.mode, snapshot.character, snapshot)
		"title":
			if is_instance_valid(level) and level.player.hp > 0: _save()
			_show_title()
		"roster":
			_pause()
			overlay_kind = "roster"
			ui.roster(selected, mode in ["title", "practice"])
		"inspect":
			ui.roster(payload.id, mode in ["title", "practice"])
		"choose":
			selected = payload.id
			ui.personalized_poster = true
			ui.selected_character = selected
			_store_settings()
			if mode == "practice" and is_instance_valid(level):
				level.player.change_character(selected)
				ui.hud(level.player.actor, mode)
				_resume()
			else:
				ui.title(not saves.load_game().is_empty())
				overlay_kind = ""
		"settings":
			_pause()
			overlay_kind = "settings"
			ui.settings(music, DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		"volume":
			music.set(payload.field, clampf(payload.value,0,1))
			music.update_volume()
			_store_settings()
		"language":
			if payload.id not in ["ru", "en", "it"]: return
			language = payload.id
			ui.language = language
			_store_settings()
			if mode == "title": ui.title(not saves.load_game().is_empty())
			elif is_instance_valid(level): ui.hud(level.player.actor, mode)
			ui.settings(music, DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		"fullscreen":
			_toggle_fullscreen()
			ui.settings(music, DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		"back":
			if overlay_kind == "dialogue": return
			if overlay_kind == "result":
				_show_title()
			else: _resume()
		"save":
			_save()
			_resume()
			ui.notice("Сохранено")
		"next":
			if dialog_id != "":
				dialog_index += 1
				if dialog_index < db.story[dialog_id].size(): _show_line()
				elif dialog_id == "ending":
					dialog_id = ""
					overlay_kind = "result"
					ui.result(true, false)
				else: _resume()
			elif overlay_kind == "error": _show_title()
		"retry": _start(mode, selected, checkpoint)
		"quit":
			if is_instance_valid(level) and level.player.hp > 0: _save()
			get_tree().quit()

func _dialogue(id: String) -> void:
	_pause()
	if id == "boss": music.play_music("battle")
	dialog_id = id
	dialog_index = 0
	overlay_kind = "dialogue"
	_show_line()

func _show_line() -> void:
	var line = db.story[dialog_id][dialog_index]
	ui.dialogue(line.speaker, line.text)

func _checkpoint(position_value: Vector2) -> void:
	checkpoint = level.snapshot(mode)
	checkpoint.position = [position_value.x, position_value.y]
	saves.save_game(checkpoint)
	ui.notice("Лунный рубеж: здоровье и энергия восстановлены")

func _defeated() -> void:
	_pause()
	overlay_kind = "result"
	ui.result(false, mode == "practice")

func _complete() -> void:
	_save()
	_pause()
	music.play_music("victory")
	if mode == "story": _dialogue("ending")
	else:
		overlay_kind = "result"
		ui.result(true, true)

func _save() -> void:
	if is_instance_valid(level) and not saves.save_game(level.snapshot(mode)):
		ui.notice(saves.error)

func _feedback(kind: String) -> void:
	if kind.begins_with("cast:"):
		var id = kind.trim_prefix("cast:")
		ui.ability_banner(db.skills[id].canonical_name)
	elif kind == "locked": ui.notice("Этот приём появится позже по сюжету. Он доступен в тренировке.")
	elif kind == "empty": ui.notice("Недостаточно энергии")
	elif kind == "pickup": music.play_sfx("menu")
	else: music.play_sfx(kind)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11: _toggle_fullscreen()
	if event.is_action_pressed("ui_cancel"):
		if mode in ["story", "practice"]:
			if overlay_kind == "":
				_pause()
				overlay_kind = "pause"
				ui.pause_menu()
			elif overlay_kind not in ["dialogue", "result"]: _resume()
		elif mode == "title": _resume()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("a_roster") and mode in ["story", "practice"] and overlay_kind == "":
		_action("roster", {})

func _toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _load_settings() -> void:
	if not FileAccess.file_exists(settings_file): return
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(settings_file)) != OK or not parser.data is Dictionary: return
	if parser.data.get("language", "ru") in ["ru", "en", "it"]: language = parser.data.get("language", "ru")
	if db.characters.has(parser.data.get("selected", "moon")): selected = parser.data.get("selected", "moon")
	for key in ["master_volume", "music_volume", "sfx_volume"]:
		if parser.data.get(key) is float or parser.data.get(key) is int: music.set(key, clampf(parser.data[key], 0, 1))

func _store_settings() -> void:
	var file = FileAccess.open(settings_file, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"master_volume": music.master_volume, "music_volume": music.music_volume, "sfx_volume": music.sfx_volume, "language": language, "selected": selected}))
