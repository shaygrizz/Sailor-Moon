extends Control
signal action_requested(id: String, payload: Dictionary)
const RiotButton = preload("res://scripts/action/menu_button.gd")
const Atlas = preload("res://scripts/action/atlas.gd")
const FittedLabel = preload("res://scripts/action/fitted_label.gd")
var language: String = "ru"
var translations: Dictionary = {}
var translation_keys: Array = []
var poster_cache: Dictionary = {}
var personalized_poster: bool = false
var translation_cache: Dictionary = {}
var db
var page: Control
var overlay: Control
var title_art: TextureRect
var elapsed: float = 0
var page_kind: String = ""
var hp_bar: ProgressBar
var energy_bar: ProgressBar
var hud_name: Label
var hud_skill: Label
var hud_objective: Label
var toast: Label
var toast_time: float = 0
var cast_banner: Label
var cast_time: float = 0
var serif: Font
var selected_character: String = "moon"
var profiles: Dictionary = {}
var masks: Masks
var controls_hint: Label
var hud_age: float = 0

## Hearts drawn like Hollow Knight masks; the one just lost flashes before fading.
class Masks extends Control:
	var current: float = 5
	var total: int = 5
	var lost_flash: float = 0
	var gained_flash: float = 0
	func set_value(value: float, maximum: int) -> void:
		if value < current: lost_flash = 0.5
		elif value > current: gained_flash = 0.5
		current = value
		total = maximum
		queue_redraw()
	func _process(delta: float) -> void:
		if lost_flash > 0 or gained_flash > 0:
			lost_flash = maxf(0, lost_flash - delta)
			gained_flash = maxf(0, gained_flash - delta)
			queue_redraw()
	func _heart(center: Vector2, radius: float) -> PackedVector2Array:
		var points = PackedVector2Array()
		for i in range(28):
			var t = TAU * i / 28
			points.append(center + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2*t) - 2 * cos(3*t) - cos(4*t))) * radius / 16)
		return points
	func _draw() -> void:
		for i in range(total):
			var center = Vector2(16 + i * 36, 16)
			var filled = i < int(current)
			var radius = 15.0
			if filled and i == int(current) - 1 and gained_flash > 0: radius += gained_flash * 8
			var shape = _heart(center, radius)
			if filled:
				draw_colored_polygon(shape, Color("ff5f93"))
				draw_colored_polygon(_heart(center + Vector2(-4, -4), 5), Color(1, 1, 1, 0.55))
			else:
				draw_colored_polygon(shape, Color("1c1424"))
				if i == int(current) and lost_flash > 0: draw_colored_polygon(shape, Color(1, 1, 1, lost_flash * 1.6))
			shape.append(shape[0])
			draw_polyline(shape, Color("fff0f6") if filled else Color("6b4f6e"), 2, true)

func configure(database) -> void:
	db = database
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://data/action/profiles.json"))
	translations = JSON.parse_string(FileAccess.get_file_as_string("res://data/action/localization.json"))
	translation_keys = translations.en.keys()
	translation_keys.sort_custom(func(a, b): return a.length() > b.length())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	serif = load("res://assets/fonts/CormorantGaramond.ttf")
	theme = Theme.new()
	theme.default_font_size = 22
	var font = ThemeDB.fallback_font.duplicate()
	font.fallbacks = [load("res://assets/fonts/NotoSansSymbols2-Regular.ttf")]
	theme.default_font = font
	theme.set_color("font_color", "Label", Color("fff6ef"))
	theme.set_color("font_color", "Button", Color("fff6ef"))
	for name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box = StyleBoxFlat.new()
		box.bg_color = Color("e92e56") if name in ["hover", "focus", "pressed"] else Color("18141e")
		box.border_color = Color("ede3d4")
		box.set_border_width_all(1)
		box.content_margin_left = 18
		box.content_margin_right = 18
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		theme.set_stylebox(name, "Button", box)

func _emit(id: String, payload: Dictionary = {}) -> void:
	action_requested.emit(id, payload)

func tx(value: String) -> String:
	if language == "ru": return value
	var cache_key = language + ":" + value
	if translation_cache.has(cache_key): return translation_cache[cache_key]
	var dictionary: Dictionary = translations.get(language, {})
	if dictionary.has(value): return dictionary[value]
	for key in translation_keys:
		if value.contains(key): value = value.replace(key, dictionary.get(key, key))
	translation_cache[cache_key] = value
	return value

func poster(id: String = "") -> Texture2D:
	if id == "" and not personalized_poster: return load(db.config.menu_art)
	var key = selected_character if id == "" else id
	if not poster_cache.has(key):
		var path = "res://assets/art/guardians/" + key + ".png"
		poster_cache[key] = load(path) if ResourceLoader.exists(path) else load(db.config.menu_art)
	return poster_cache[key]

func portrait(id: String) -> AtlasTexture:
	var source = poster(id)
	var crop = AtlasTexture.new()
	crop.atlas = source
	crop.region = Rect2(source.get_width()*0.52, source.get_height()*0.05, source.get_width()*0.43, source.get_height()*0.72)
	crop.filter_clip = true
	return crop

func _new_page(kind: String) -> void:
	page_kind = kind
	title_art = null
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page = Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	close_overlay()

func _label(text: String, at: Vector2, width_value: float, font_size: int = 22, color: Color = Color("fff6ef"), parent: Node = null, display_font: bool = false) -> Label:
	var label = FittedLabel.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.preferred_size = font_size
	label.translator = tx
	label.text = tx(text)
	label.position = at
	label.size = Vector2(width_value, maxf(34, font_size * 1.4 * (text.count("\n") + 1)))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if display_font: label.add_theme_font_override("font", serif)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else page).add_child(label)
	return label

func _polygon(points: PackedVector2Array, color: Color, parent: Node = null) -> Polygon2D:
	var polygon = Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	(parent if parent != null else page).add_child(polygon)
	return polygon

func _texture(texture: Texture2D, at: Vector2, extent: Vector2, parent: Node = null) -> TextureRect:
	var art = TextureRect.new()
	art.texture = texture
	art.position = at
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else page).add_child(art)
	art.size = extent
	return art

func _button(text: String, at: Vector2, extent: Vector2, callback: Callable, parent: Node = null) -> Button:
	var button = Button.new()
	button.text = tx(text)
	button.clip_text = true
	button.position = at
	button.size = extent
	button.pressed.connect(callback, Object.CONNECT_DEFERRED)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	(parent if parent != null else page).add_child(button)
	return button

func title(has_save: bool) -> void:
	_new_page("title")
	title_art = _texture(poster(), Vector2(-12, -8), size + Vector2(24, 16))
	_polygon(PackedVector2Array([Vector2(0,0),Vector2(660,0),Vector2(495,720),Vector2(0,720)]), Color(0.025,0.015,0.035,0.35))
	_label("PRETTY GUARDIAN", Vector2(53, 32), 500, 18, Color("7fe9e6"))
	var name_label = _label("SAILOR\nMOON", Vector2(45, 66), 650, 92, Color("fff6ef"), null, true)
	name_label.add_theme_constant_override("line_spacing", -40)
	name_label.size.y = 180
	name_label.rotation = deg_to_rad(-5)
	_label("IN THE NAME OF THE MOON", Vector2(62, 240), 520, 15, Color("ffb8ca"))
	var entries = [["НАЧАТЬ ИГРУ", "story"], ["ПРОДОЛЖИТЬ", "continue"], ["ХРАНИТЕЛЬНИЦЫ", "roster"], ["ТРЕНИРОВКА", "practice"], ["НАСТРОЙКИ", "settings"], ["ВЫХОД", "quit"]]
	for i in range(entries.size()):
		var button = RiotButton.new()
		button.text = tx(entries[i][0])
		button.clip_text = true
		button.size = Vector2(510, 56)
		button.position = Vector2(62 + i * 9, 286 + i * 57)
		button.rotation = deg_to_rad(-4)
		button.add_theme_font_override("font", serif)
		button.add_theme_font_size_override("font_size", 42 if i != 2 else 38)
		button.disabled = entries[i][1] == "continue" and not has_save
		button.pressed.connect(func(): _emit(entries[i][1]), Object.CONNECT_DEFERRED)
		page.add_child(button)
		var destination = button.position.x
		button.position.x = -600
		create_tween().tween_property(button, "position:x", destination, db.config.visual.menu_slide_seconds + i * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if i == 0: button.grab_focus()
	_label("ACT 01  /  DARK KINGDOM", Vector2(63, 661), 520, 16, Color("e9c9b8"))
	_label("ENTER — ВЫБРАТЬ     ↑ ↓ — МЕНЮ", Vector2(863, 675), 390, 14)

func loading(progress: float) -> void:
	if page_kind != "loading":
		_new_page("loading")
		title_art = _texture(poster(), Vector2(-12,-8), size + Vector2(24,16))
		_polygon(PackedVector2Array([Vector2(0,470),Vector2(780,430),Vector2(660,720),Vector2(0,720)]), Color("08070d"))
		_label(db.characters[selected_character].title.to_upper(), Vector2(46,465), 650, 52, Color.WHITE, null, true)
		_label("ЗАГРУЗКА", Vector2(50,530), 580, 42)
		hp_bar = _bar(Vector2(50,610), Vector2(500,12), Color("ff376b"))
	hp_bar.value = progress * 100

func _bar(at: Vector2, extent: Vector2, color: Color, parent: Node = null) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.position = at
	bar.show_percentage = false
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color("352735")
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	(parent if parent != null else page).add_child(bar)
	bar.size = extent
	return bar

func hud(actor: Dictionary, mode: String) -> void:
	_new_page("hud")
	_polygon(PackedVector2Array([Vector2(0,0),Vector2(490,0),Vector2(450,136),Vector2(0,110)]), Color("080911"))
	_polygon(PackedVector2Array([Vector2(0,108),Vector2(450,130),Vector2(430,138),Vector2(0,116)]), Color("f02c5b"))
	_texture(portrait(actor.id), Vector2(16,15), Vector2(88,80))
	hud_name = _label(actor.title.to_upper(), Vector2(118,12), 310, 24)
	masks = Masks.new()
	masks.position = Vector2(118, 44)
	masks.size = Vector2(300, 34)
	masks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(masks)
	energy_bar = _bar(Vector2(118,82), Vector2(245,8), Color("fa74b7"))
	hud_skill = _label("", Vector2(118,91), 320, 14, Color("e7d5e1"))
	var tag = "ТРЕНИРОВКА / ВСЕ ХРАНИТЕЛЬНИЦЫ" if mode == "practice" else "ACT 1 / УСАГИ — SAILOR MOON"
	_label(tag, Vector2(780,24), 470, 16, Color("fff0da"))
	hud_objective = _label("Доберитесь до ювелирного магазина", Vector2(780,55), 470, 18)
	hud_age = 0
	controls_hint = _label("A D  ДВИЖЕНИЕ    SPACE  ПРЫЖОК    J  УДАР (+W / S — ВВЕРХ / ВНИЗ)    SHIFT  РЫВОК    F  ЛЕЧЕНИЕ    K/Q  ПРИЁМ    L/E  СПЕЦПРИЁМ    ESC  МЕНЮ", Vector2(24,687), 1240, 14)
	toast = _label("", Vector2(330,145), 650, 24, Color("fff0d1"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cast_banner = _label("", Vector2(570,590), 680, 36, Color("ffcae2"), null, true)
	cast_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func update_hud(player, boss_alive: bool) -> void:
	if page_kind != "hud": return
	masks.set_value(player.hp, player.max_hp)
	energy_bar.value = player.energy / player.actor.energy * 100
	var heals = int(player.energy / db.config.combat.focus_cost)
	hud_skill.text = "ЭНЕРГИЯ %d   /   F — ЛЕЧЕНИЙ: %d" % [player.energy, heals]
	hud_objective.text = "Победите ёму и спасите Нару" if boss_alive else "Нару спасена — пройдите к свету справа"

func notice(text: String) -> void:
	if not is_instance_valid(toast): return
	toast.text = text
	toast.show()
	toast_time = 3.2

func ability_banner(text: String) -> void:
	if not is_instance_valid(cast_banner): return
	cast_banner.text = text
	cast_banner.show()
	cast_time = 1.4
	cast_banner.position.x = 650
	create_tween().tween_property(cast_banner, "position:x", 570.0, 0.16)

func close_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = null

func _overlay(title_text: String) -> Control:
	var previous = overlay
	overlay = null
	if is_instance_valid(previous):
		_set_input_passthrough(previous)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade = ColorRect.new()
	shade.color = Color(0.015,0.008,0.025,0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	_polygon(PackedVector2Array([Vector2(0,0),Vector2(770,0),Vector2(710,88),Vector2(0,130)]), Color("f32d59"), overlay)
	_label(title_text, Vector2(42,14), 1060, 54, Color.WHITE, overlay, true)
	var tween = create_tween()
	overlay.modulate.a = 0
	tween.tween_property(overlay,"modulate:a",1.0,db.config.visual.fade_seconds)
	if is_instance_valid(previous):
		var dismiss = create_tween()
		dismiss.tween_property(previous, "modulate:a", 0.0, db.config.visual.fade_seconds)
		dismiss.tween_callback(previous.queue_free)
	return overlay

func _set_input_passthrough(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if node is BaseButton: node.disabled = true
	for child in node.get_children(): _set_input_passthrough(child)

func roster(selected: String, can_select: bool) -> void:
	selected_character = selected
	var host = _overlay("ХРАНИТЕЛЬНИЦЫ")
	var backdrop = _texture(poster(selected), Vector2.ZERO, size, host)
	host.move_child(backdrop, 0)
	var ids = db.characters.keys()
	for i in range(ids.size()):
		var actor = db.characters[ids[i]]
		var at = Vector2(30 + (i % 2) * 8, 112 + i * 53)
		var card = _button("", at, Vector2(326,49), func(): _emit("inspect", {"id": actor.id}), host)
		card.rotation = deg_to_rad(-2)
		card.clip_contents = true
		_texture(portrait(actor.id), Vector2(3,1), Vector2(64,47), card)
		_label(actor.name, Vector2(75,-3), 242, 18, Color.WHITE, card)
		_label(actor.title, Vector2(76,23), 242, 13, Color(actor.color), card)
		if actor.id == selected: card.grab_focus()
	var actor = db.characters[selected]
	var dossier: Dictionary = profiles.get(selected, {})
	var accent = Color(actor.color)
	_polygon(PackedVector2Array([Vector2(404,150),Vector2(675,119),Vector2(635,589),Vector2(365,622)]), Color(accent, 0.14), host)
	_polygon(PackedVector2Array([Vector2(383,583),Vector2(647,553),Vector2(626,613),Vector2(367,640)]), accent, host)
	var emblem = _label(dossier.get("symbol", "★"), Vector2(532,99), 150, 112, Color(accent,0.25), host)
	emblem.add_theme_font_override("font", load("res://assets/fonts/NotoSansSymbols2-Regular.ttf"))
	var portrait_texture = portrait(selected)
	var full = _texture(portrait_texture, Vector2(382,155), Vector2(273,421), host)
	full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	full.modulate.a = 0
	full.position.x += 18
	var reveal = create_tween().set_parallel(true)
	reveal.tween_property(full,"modulate:a",1.0,0.32)
	reveal.tween_property(full,"position:x",382.0,0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_label("GUARDIAN / %02d" % (ids.find(selected)+1), Vector2(399,590), 240, 18, Color("100d18"), host)
	_label("ЛИЧНОЕ ДЕЛО  /  " + actor.tagline.to_upper(), Vector2(698,109), 555, 13, accent, host)
	_label(actor.name.to_upper(), Vector2(695,143), 560, 43, Color.WHITE, host, true)
	_label(actor.title, Vector2(699,193), 550, 21, accent, host)
	var bio = _label("", Vector2(699,238), 529, 19, Color("e6dce4"), host)
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bio.text = tx(dossier.get("bio", actor.tagline))
	bio.size = Vector2(529,100)
	_label("ХАРАКТЕР", Vector2(699,337), 520, 12, accent, host)
	_label(dossier.get("traits", ""), Vector2(699,360), 535, 18, Color.WHITE, host)
	_label("ЛИЧНОЕ  /  " + dossier.get("interest", ""), Vector2(699,398), 535, 16, Color("bfb1bd"), host)
	_polygon(PackedVector2Array([Vector2(699,446),Vector2(1230,434),Vector2(1230,462),Vector2(699,474)]), Color(accent,0.2), host)
	_label("В БОЮ  /  " + dossier.get("role", ""), Vector2(711,441), 505, 16, accent, host)
	for i in range(2):
		var skill = db.skills[actor.primary if i == 0 else actor.special]
		var y = 486 + i * 46
		_label("K / Q" if i == 0 else "L / E", Vector2(699,y), 77, 16, accent, host)
		_label(skill.name, Vector2(780,y), 445, 19, Color.WHITE, host)
	_label("ВСЕ ХРАНИТЕЛЬНИЦЫ — В ТРЕНИРОВКЕ", Vector2(699,578), 530, 12, Color("bfb1bd"), host)
	if can_select:
		_button("ВЫБРАТЬ ХРАНИТЕЛЬНИЦУ", Vector2(699,620), Vector2(530,49), func(): _emit("choose", {"id": selected}), host)
	_button("НАЗАД / ESC", Vector2(390,657), Vector2(255,40), func(): _emit("back"), host)

func pause_menu() -> void:
	var host = _overlay("ЛУННАЯ ПАУЗА")
	var entries = [["ПРОДОЛЖИТЬ", "back"], ["ХРАНИТЕЛЬНИЦЫ", "roster"], ["СОХРАНИТЬ", "save"], ["НАСТРОЙКИ", "settings"], ["ГЛАВНОЕ МЕНЮ", "title"]]
	for i in range(entries.size()):
		var button = _button(entries[i][0], Vector2(120,164+i*83), Vector2(510,64), func(): _emit(entries[i][1]), host)
		if i==0: button.grab_focus()

func settings(audio, fullscreen: bool) -> void:
	var host = _overlay("НАСТРОЙКИ")
	var specs = [["Общая громкость", "master_volume"], ["Музыка", "music_volume"], ["Эффекты", "sfx_volume"]]
	for i in range(specs.size()):
		_label(specs[i][0], Vector2(100,130+i*80), 400, 27, Color.WHITE, host)
		var slider = HSlider.new()
		slider.position = Vector2(530,140+i*80)
		slider.size = Vector2(500,35)
		slider.max_value = 1
		slider.step = 0.01
		slider.value = audio.get(specs[i][1])
		slider.value_changed.connect(func(value): _emit("volume", {"field": specs[i][1], "value": value}))
		host.add_child(slider)
	_label("ЯЗЫК", Vector2(100,378), 350, 24, Color.WHITE, host)
	var languages = OptionButton.new()
	languages.position = Vector2(530,375)
	languages.size = Vector2(500,48)
	for title in ["Русский", "English", "Italiano"]: languages.add_item(title)
	languages.select(["ru","en","it"].find(language))
	languages.item_selected.connect(func(index): _emit("language", {"id":["ru","en","it"][index]}), Object.CONNECT_DEFERRED)
	host.add_child(languages)
	_button("ПОЛНЫЙ ЭКРАН: " + ("ВКЛ" if fullscreen else "ВЫКЛ"), Vector2(100,460), Vector2(600,58), func(): _emit("fullscreen"), host)
	_label("Музыку можно заменить в папке Music рядом с игрой.\nУправление: J — удар (W / S — вверх / вниз), F — лечение, K/Q — приём, L/E — спецприём.\nГеймпад: A — прыжок, X — удар, Y — приём, RB — рывок, RT — лечение, LB — спецприём.", Vector2(100,565), 1090, 19, Color("cfbdcc"), host)
	_button("НАЗАД", Vector2(990,650), Vector2(220,45), func(): _emit("back"), host)

func dialogue(speaker: String, text: String) -> void:
	var host = _overlay(speaker.to_upper())
	var line = _label(text, Vector2(110,185), 1030, 34, Color.WHITE, host)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size.y = 260
	_button("ДАЛЕЕ  /  ENTER", Vector2(755,550), Vector2(420,62), func(): _emit("next"), host).grab_focus()

func result(victory: bool, practice: bool) -> void:
	var host = _overlay("ВО ИМЯ ЛУНЫ" if victory else "ЕЩЁ ОДНА ПОПЫТКА")
	_label("ТРЕНИРОВКА ЗАВЕРШЕНА" if practice and victory else ("ACT 1 / НАРУ СПАСЕНА" if victory else "Последний рубеж помнит ваш свет."), Vector2(120,220), 1050, 36, Color("f2bdce"), host)
	_label("Пролог завершён. Следующие акты манги — в разработке." if victory and not practice else "Прыжок и рывок помогают уходить от атак. Следите за энергией.", Vector2(120,305), 1050, 23, Color.WHITE, host)
	_button("В ГЛАВНОЕ МЕНЮ", Vector2(120,450), Vector2(500,65), func(): _emit("title"), host)
	_button("ТРЕНИРОВКА" if victory else "ПОВТОРИТЬ", Vector2(670,450), Vector2(500,65), func(): _emit("practice" if victory else "retry"), host).grab_focus()

func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(controls_hint):
		hud_age += delta
		controls_hint.modulate.a = clampf(1.0 - (hud_age - 25.0) / 2.0, 0.0, 1.0)
	if is_instance_valid(title_art):
		title_art.position = Vector2(-12 + sin(elapsed * 0.23) * 7, -8 + cos(elapsed * 0.19) * 4)
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0 and is_instance_valid(toast): toast.hide()
	if cast_time > 0:
		cast_time -= delta
		if cast_time <= 0 and is_instance_valid(cast_banner): cast_banner.hide()
