extends Control
## View adapter. Emits intentions; all state changes are owned by injected services.
signal action_requested(action: String, payload: Dictionary)
const ThemeKit = preload("res://scripts/ui/skin.gd")
const WorldView = preload("res://scripts/world/world_view.gd")
const Particles = preload("res://scripts/effects/ambient_particles.gd")
var db
var session
var journal
var bag
var battle
var world_view
var modal: Control
var screen: Control
var selected_skill: String = ""
var selected_item: String = ""
var screen_kind: String = "title"
var toast_label: Label
var toast_timer: float = 0.0
var debug_label: Label
var show_debug: bool = false

func setup(database, state, quests, inventory, combat) -> void:
	db = database
	session = state
	journal = quests
	bag = inventory
	battle = combat
	theme = ThemeKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _clear(kind: String) -> void:
	screen_kind = kind
	world_view = null
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var background = ColorRect.new()
	background.color = Color("0c1025")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(background)
	if is_instance_valid(modal):
		modal.move_to_front()
	if is_instance_valid(toast_label):
		toast_label.move_to_front()
	if is_instance_valid(debug_label):
		debug_label.move_to_front()

func _emit(action: String, payload: Dictionary = {}) -> void:
	action_requested.emit(action, payload)

func _place(node: Control, position_value: Vector2, size_value: Vector2, parent: Node = null) -> void:
	(parent if parent != null else screen).add_child(node)
	node.position = position_value
	node.size = size_value

func _texture(path: String) -> TextureRect:
	var node = TextureRect.new()
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _particles() -> void:
	var effect = Particles.new()
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect.configure(int(db.table("config").presentation.particle_count), db.table("config").presentation.particle_speed)
	screen.add_child(effect)

func title(has_save: bool) -> void:
	_clear("title")
	var narrow = size.x < 900
	_place(_texture("res://assets/maps/sanctuary.svg"), Vector2.ZERO, size)
	var veil = ColorRect.new()
	veil.color = Color(0.03, 0.04, 0.10, 0.64)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(veil, Vector2.ZERO, size)
	_place(ThemeKit.label("✦  A CELESTIAL TALE", 18, Color("dfc99c")), Vector2(46, 34), Vector2(400, 32))
	_place(ThemeKit.label("ГЛАВА 01  /  ПЕРВАЯ ЗВЕЗДА", 17, Color("c4b8d0")), Vector2(46, size.y - 42), Vector2(600, 30))
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	var width_value = minf(size.x - 92, 510)
	_place(column, Vector2(46, maxf(110, size.y * 0.20)), Vector2(width_value, 470))
	column.add_child(ThemeKit.label("M O O N V E I L", 48 if narrow else 58, Color("f5e4dc")))
	column.add_child(ThemeKit.label("T H E   F I R S T   S T A R", 19, Color("dfc99c")))
	column.add_child(ThemeKit.paragraph("Когда гаснут звёзды,\nнадежда учится сиять.", 30))
	column.add_child(ThemeKit.paragraph("Две хранительницы. Одно обещание.\nНачните путешествие за лунным светом.", 20))
	column.add_child(ThemeKit.button("Начать путешествие   ▸", func(): _emit("new_game"), true))
	var resume_button = ThemeKit.button("Продолжить", func(): _emit("load", {"slot": 0}))
	resume_button.disabled = not has_save
	column.add_child(resume_button)
	column.add_child(ThemeKit.button("Сохранения и настройки", func(): _emit("menu")))
	if not narrow:
		var illustration = _texture("res://assets/portraits/selene.svg")
		_place(illustration, Vector2(size.x - 380, size.y * 0.32), Vector2(290, 362))
		illustration.modulate = Color(0.9, 0.86, 1, 0.8)
	_particles()
	column.get_child(4).grab_focus()

func _header(title_text: String, subtitle: String) -> void:
	_place(ThemeKit.label(title_text, 30), Vector2(28, 18), Vector2(size.x - 245, 40))
	_place(ThemeKit.label(subtitle, 13, Color("dfc99c")), Vector2(29, 60), Vector2(size.x - 245, 22))
	_place(ThemeKit.button("◇  Меню", func(): _emit("menu")), Vector2(size.x - 184, 24), Vector2(156, 56))

func exploration() -> void:
	_clear("world")
	selected_skill = ""
	selected_item = ""
	var map = db.entry("maps", session.data.map)
	_header(map.name, map.region)
	var narrow = size.x < 900
	var map_rect = Rect2(24, 104, size.x - (48 if narrow else 368), size.y - (470 if narrow else 240))
	world_view = WorldView.new()
	_place(world_view, map_rect.position, map_rect.size)
	world_view.setup(map, db.table("config").world, session.data.position)
	world_view.point_reached.connect(func(id): _emit("interact", {"id": id}))
	world_view.position_changed.connect(func(point): _emit("position", {"value": point}))
	var quest_rect = Rect2(24, map_rect.end.y + 16, size.x - 48, 200) if narrow else Rect2(size.x - 328, 104, 304, size.y - 240)
	var quest_box = ThemeKit.panel(screen, quest_rect)
	quest_box.add_child(ThemeKit.label("✦  ПУТЕВОДНАЯ ЗВЕЗДА", 16, Color("dfc99c")))
	quest_box.add_child(ThemeKit.label("Первая звезда", 27))
	quest_box.add_child(ThemeKit.paragraph(journal.objective(db.table("config").initial_quest), 22))
	if not narrow:
		quest_box.add_child(HSeparator.new())
		quest_box.add_child(ThemeKit.paragraph("Коснитесь места, чтобы подойти.\n\nWASD — движение\nE / A — взаимодействие\nEsc — меню", 17))
		quest_box.add_child(ThemeKit.label("◇  %d  лунного золота" % session.data.gold, 18, Color("dfc99c")))
	_party_row(size.y - 118)
	var controls = HBoxContainer.new()
	_place(controls, Vector2(38, map_rect.end.y - 64), Vector2(330, 56))
	for entry in [["◀", Vector2.LEFT], ["▲", Vector2.UP], ["▼", Vector2.DOWN], ["▸", Vector2.RIGHT]]:
		var button = ThemeKit.button(entry[0], func(): pass)
		button.custom_minimum_size = Vector2(58, 56)
		button.button_down.connect(func():
			if is_instance_valid(world_view): world_view.touch_direction = entry[1])
		button.button_up.connect(func():
			if is_instance_valid(world_view): world_view.touch_direction = Vector2.ZERO)
		controls.add_child(button)
	_particles()

func _party_row(y: float) -> void:
	var width_value = (size.x - 64) / session.data.party.size()
	for i in range(session.data.party.size()):
		var member = session.data.party[i]
		var actor = session.stats(member)
		var column = ThemeKit.panel(screen, Rect2(24 + i * (width_value + 16), y, width_value, 94))
		var row = HBoxContainer.new()
		column.add_child(row)
		var portrait_node = _texture(actor.portrait)
		portrait_node.custom_minimum_size = Vector2(36, 45) if size.x < 900 else Vector2(52, 65)
		row.add_child(portrait_node)
		var stats_box = VBoxContainer.new()
		stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_box.add_theme_constant_override("separation", 5)
		row.add_child(stats_box)
		stats_box.add_child(ThemeKit.label("%s · %d" % [actor.name, member.level] if size.x < 900 else "%s  ·  Ур. %d" % [actor.name, member.level], 20))
		var stats_text = "%d HP · %d MP" % [member.hp, member.mp] if size.x < 900 else "HP %d / %d     MP %d / %d" % [member.hp, actor.max_hp, member.mp, actor.max_mp]
		stats_box.add_child(ThemeKit.label(stats_text, 16, Color("b9bbd5")))
		stats_box.add_child(ThemeKit.bar(member.hp, actor.max_hp, Color(actor.color)))

func combat() -> void:
	_clear("battle")
	_header("Сад сновидений", "ЛУННОЕ ЭХО  /  ПОШАГОВЫЙ БОЙ")
	var narrow = size.x < 900
	var stage_height = size.y - (550 if narrow else 380)
	var backdrop = _texture("res://assets/maps/dream.svg")
	_place(backdrop, Vector2(24, 104), Vector2(size.x - 48, stage_height))
	backdrop.modulate = Color(0.63, 0.63, 0.75)
	var timeline = "ХОД %d   " % battle.round_number
	for i in range(battle.cursor, battle.order.size()):
		var actor = battle.actors[battle.order[i]]
		if actor.hp > 0:
			timeline += ("  ›  " if i != battle.cursor else "") + actor.name
	var timeline_label = ThemeKit.label(timeline, 16, Color("dfc99c"))
	timeline_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(timeline_label, Vector2(42, 118), Vector2(size.x - 84, 32))
	var party = battle.actors.filter(func(actor): return actor.side == "party")
	var enemies = battle.actors.filter(func(actor): return actor.side == "enemy")
	for side in [party, enemies]:
		for i in range(side.size()):
			var actor = side[i]
			var is_party = actor.side == "party"
			var x = size.x * (0.09 + i * 0.19) if is_party else size.x * (0.56 + i * 0.21)
			var art_size = Vector2(70, 88) if narrow else Vector2(125, 156)
			var y = 160 + stage_height * 0.15
			if is_party:
				var portrait_node = _texture(actor.portrait)
				_place(portrait_node, Vector2(x, y), art_size)
				portrait_node.modulate.a = 1.0 if actor.hp > 0 else 0.2
			else:
				var spirit = ThemeKit.label("✧" if i == 0 else "♜", 104, Color(actor.color))
				spirit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_place(spirit, Vector2(x, y), art_size)
				spirit.modulate.a = 1.0 if actor.hp > 0 else 0.15
			var column = VBoxContainer.new()
			column.add_theme_constant_override("separation", 5)
			_place(column, Vector2(x - (8 if narrow else 20), y + art_size.y + 10), Vector2(size.x * 0.17 if narrow else 190, 65))
			var name_label = ThemeKit.label(actor.name, 16)
			name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			column.add_child(name_label)
			column.add_child(ThemeKit.bar(actor.hp, actor.max_hp, Color(actor.color)))
			column.add_child(ThemeKit.label("%d/%d%s" % [actor.hp, actor.max_hp, " ЩИТ" if actor.guard else ""], 16))
	var bottom_y = 120 + stage_height
	var info = ThemeKit.panel(screen, Rect2(24, bottom_y, size.x - 48, 76))
	info.add_child(ThemeKit.paragraph(battle.log_lines.back() if not battle.log_lines.is_empty() else "", 18))
	if not battle.active:
		var text = "Победа  ·  +%d опыта, +%d золота" % [db.entry("encounters", battle.encounter_id).xp, db.entry("encounters", battle.encounter_id).gold] if battle.outcome == "victory" else "Свет ещё не погас. Отдохните и попробуйте снова."
		var result_box = ThemeKit.panel(screen, Rect2(24, bottom_y + 90, size.x - 48, 120))
		result_box.add_child(ThemeKit.label(text, 22, Color("dfc99c")))
		result_box.add_child(ThemeKit.button("Продолжить   ▸", func(): _emit("battle_exit"), true))
		return
	var current = battle.current()
	var commands = ThemeKit.panel(screen, Rect2(24, bottom_y + 90, size.x - 48, size.y - bottom_y - 114))
	commands.add_child(ThemeKit.label("%s  ·  %d MP       ✦  Резонанс %d / %d" % [current.name, current.mp, battle.gauge, db.table("config").battle.ultimate_cost], 20, Color("dfc99c")))
	if current.side == "enemy":
		commands.add_child(ThemeKit.label("Тени собираются…", 22))
		return
	if selected_skill != "" or selected_item != "":
		var skill = db.entry("skills", selected_skill) if selected_skill != "" else {"target": "ally", "name": db.entry("items", selected_item).name}
		commands.add_child(ThemeKit.label(skill.name + " — выберите цель", 20))
		var row = GridContainer.new()
		row.columns = 1 if narrow else 3
		commands.add_child(row)
		for actor in battle.living("party" if skill.target == "ally" else "enemy"):
			var button = ThemeKit.button(actor.name, func(): _emit("battle_target", {"id": actor.id}))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(button)
		row.add_child(ThemeKit.button("Назад", func(): _emit("battle_cancel")))
		row.get_child(0).grab_focus()
	else:
		var grid = GridContainer.new()
		grid.columns = 2 if narrow else 6
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		commands.add_child(grid)
		var skills = current.skills.duplicate()
		skills.append(current.ultimate)
		for id in skills:
			var skill = db.entry("skills", id)
			var text = skill.name + (" · %d" % skill.cost if skill.cost > 0 else "")
			var button = ThemeKit.button(text, func(): _emit("battle_skill", {"id": id}))
			button.add_theme_font_size_override("font_size", 18)
			button.tooltip_text = skill.get("description", "")
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.disabled = not battle.can_use(id)
			grid.add_child(button)
		var item_button = ThemeKit.button("Капля ×%d" % bag.count("stardrop"), func(): _emit("battle_item", {"id": "stardrop"}))
		item_button.add_theme_font_size_override("font_size", 18)
		item_button.disabled = bag.count("stardrop") == 0
		grid.add_child(item_button)
		grid.get_child(0).grab_focus()
	_particles()

func open_modal(title_text: String) -> VBoxContainer:
	close_modal()
	if is_instance_valid(world_view):
		world_view.enabled = false
		world_view.touch_direction = Vector2.ZERO
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.07, 0.83)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var width_value = minf(size.x - 48, 760)
	var height_value = minf(size.y - 64, 620)
	var column = ThemeKit.panel(modal, Rect2((size.x - width_value) / 2, (size.y - height_value) / 2, width_value, height_value))
	column.add_child(ThemeKit.label(title_text, 30, Color("dfc99c")))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	column.add_child(ThemeKit.button("Закрыть", func(): _emit("close_modal")))
	var tween = create_tween()
	modal.modulate.a = 0
	tween.tween_property(modal, "modulate:a", 1.0, db.table("config").presentation.transition_seconds)
	return body

func close_modal() -> void:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal = null
	if is_instance_valid(world_view):
		world_view.enabled = true

func dialogue(speaker: String, text: String, final_line: bool) -> void:
	var body = open_modal(speaker)
	if speaker in ["Селена", "Ирис"]:
		var portrait_node = _texture(db.entry("characters", "selene" if speaker == "Селена" else "iris").portrait)
		portrait_node.custom_minimum_size = Vector2(100, 125)
		portrait_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		body.add_child(portrait_node)
	body.add_child(ThemeKit.paragraph(text, 27))
	var next = ThemeKit.button("Продолжить" if final_line else "Далее   ▸", func(): _emit("dialogue_next"), true)
	body.add_child(next)
	next.grab_focus()

func notify(message: String) -> void:
	if not is_instance_valid(toast_label):
		toast_label = ThemeKit.paragraph(message, 21)
		toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		toast_label.add_theme_color_override("font_color", Color("ffe3bb"))
		toast_label.add_theme_color_override("font_outline_color", Color("0c1025"))
		toast_label.add_theme_constant_override("outline_size", 9)
		add_child(toast_label)
	toast_label.text = message
	toast_label.position = Vector2(40, 82)
	toast_label.size = Vector2(size.x - 80, 62)
	toast_label.move_to_front()
	toast_label.show()
	toast_timer = 4.0

func _process(delta: float) -> void:
	if toast_timer > 0:
		toast_timer -= delta
		if toast_timer <= 0 and is_instance_valid(toast_label):
			toast_label.hide()
	if show_debug:
		if not is_instance_valid(debug_label):
			debug_label = ThemeKit.label("", 16, Color("c0ffe0"))
			add_child(debug_label)
		debug_label.position = Vector2(24, 0)
		debug_label.text = "%d FPS | %.1f MB | %d nodes | %s" % [Engine.get_frames_per_second(), OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), screen_kind]
		debug_label.show()
		debug_label.move_to_front()
	elif is_instance_valid(debug_label):
		debug_label.hide()
