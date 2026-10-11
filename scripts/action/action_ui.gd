extends Control
## Interface in the "Moonlight" direction (see style.gd): indigo glass, hairline gold, serif titles,
## letter-spaced captions and one rose accent. Screens: title, loading, HUD, overlays, dialogue.
signal action_requested(id: String, payload: Dictionary)
const RiotButton = preload("res://scripts/action/menu_button.gd")
const Atlas = preload("res://scripts/action/atlas.gd")
const FittedLabel = preload("res://scripts/action/fitted_label.gd")
const Style = preload("res://scripts/action/style.gd")
var language: String = "ru"
var translations: Dictionary = {}
var translation_keys: Array = []
var poster_cache: Dictionary = {}
var round_cache: Dictionary = {}
var personalized_poster: bool = false
var translation_cache: Dictionary = {}
var db
var page: Control
var overlay: Control
var title_art: TextureRect
var elapsed: float = 0
var page_kind: String = ""
var hp_bar: ProgressBar
var hud_name: Label
var hud_skill: Label
var hud_objective: Label
var toast: Label
var toast_line: Control
var toast_shade: TextureRect
var toast_time: float = 0
var cast_banner: Label
var cast_time: float = 0
var serif: Font
var caps: FontVariation
var selected_character: String = "moon"
var profiles: Dictionary = {}
var masks: Masks
var orb: Orb
var boss_bar: BossBar
var controls_hint: Label
var hud_age: float = 0
var luna_face: Texture2D

## Hearts; the one just lost flashes white, a healed one swells.
class Masks extends Control:
	const S = preload("res://scripts/action/style.gd")
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
		for i in range(32):
			var t = TAU * i / 32
			points.append(center + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2*t) - 2 * cos(3*t) - cos(4*t))) * radius / 16)
		return points
	func _draw() -> void:
		for i in range(total):
			var center = Vector2(13 + i * 30, 14)
			var filled = i < int(current)
			var radius = 11.5
			if filled and i == int(current) - 1 and gained_flash > 0: radius += gained_flash * 7
			var shape = _heart(center, radius)
			if filled:
				draw_colored_polygon(_heart(center, radius + 4), Color(S.HEART, 0.12))
				draw_colored_polygon(shape, S.HEART)
				draw_colored_polygon(_heart(center + Vector2(-3, -3), 3.6), Color(1, 1, 1, 0.65))
			else:
				draw_colored_polygon(shape, Color(0.05, 0.04, 0.12, 0.7))
				if i == int(current) and lost_flash > 0: draw_colored_polygon(shape, Color(1, 1, 1, lost_flash * 1.6))
			shape.append(shape[0])
			draw_polyline(shape, Color(S.CREAM, 0.9) if filled else Color(S.MUTED, 0.7), 1.5, true)

## Round portrait framed by the energy arc (the "soul vessel"); ticks mark one heal each.
class Orb extends Control:
	const S = preload("res://scripts/action/style.gd")
	var face: Texture2D
	var ratio: float = 1.0
	var step: float = 0.33
	var tint: Color = Color.WHITE
	func set_energy(value: float) -> void:
		if absf(value - ratio) > 0.002:
			ratio = value
			queue_redraw()
	func _draw() -> void:
		var center = size / 2
		var radius = size.x / 2 - 6
		draw_circle(center, radius + 5, Color(0.04, 0.035, 0.1, 0.85))
		if face != null: draw_texture_rect(face, Rect2(center - Vector2.ONE * (radius - 3), Vector2.ONE * (radius - 3) * 2), false)
		draw_arc(center, radius + 1, 0, TAU, 64, Color(S.MUTED, 0.45), 3, true)
		if ratio > 0:
			draw_arc(center, radius + 1, PI / 2, PI / 2 + TAU * ratio, 64, Color(S.ROSE, 0.35), 7, true)
			draw_arc(center, radius + 1, PI / 2, PI / 2 + TAU * ratio, 64, S.GOLD.lerp(S.ROSE, 0.35), 3, true)
		var t = step
		while t < 1.0:
			var angle = PI / 2 + TAU * t
			draw_line(center + Vector2.from_angle(angle) * (radius - 3), center + Vector2.from_angle(angle) * (radius + 6), Color(S.INK, 0.9), 2)
			t += step
		draw_arc(center, radius + 6, 0, TAU, 64, Color(S.GOLD, 0.55), 1, true)
		S.crescent(self, center + Vector2(radius * 0.72, -radius * 0.72), 9, S.GOLD, -0.6)

## Hairline that fades towards both ends, with a small diamond at its centre or left end.
class Ornament extends Control:
	const S = preload("res://scripts/action/style.gd")
	var tint: Color = Color("e8c98e")
	var centered: bool = true
	func _draw() -> void:
		var y = size.y / 2
		var steps = 32
		for i in range(steps):
			var a = float(i) / steps
			var b = float(i + 1) / steps
			var fade = (1.0 - absf((a + b) - 1.0)) if centered else (1.0 - (a + b) / 2.0)
			draw_line(Vector2(size.x * a, y), Vector2(size.x * b, y), Color(tint, tint.a * clampf(fade * 1.4, 0, 1)), 1)
		S.diamond(self, Vector2(size.x / 2 if centered else 4, y), 4, tint)

class BossBar extends Control:
	const S = preload("res://scripts/action/style.gd")
	var ratio: float = 1.0
	var enraged: bool = false
	func _draw() -> void:
		var bar = Rect2(Vector2(0, size.y - 8), Vector2(size.x, 6))
		draw_rect(bar.grow(1), Color(S.INK, 0.8))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), S.DANGER.lerp(Color("ff9a5c"), 1.0 if enraged else 0.0))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 1)), Color(1, 1, 1, 0.5))
		draw_rect(bar.grow(1), Color(S.GOLD, 0.5), false, 1)
		for x in [0.0, size.x]: S.diamond(self, Vector2(x, bar.get_center().y), 5, S.GOLD)

class Crest extends Control:
	const S = preload("res://scripts/action/style.gd")
	var radius: float = 14
	func _draw() -> void:
		S.crescent(self, size / 2, radius, S.GOLD, -0.6)
		for star in [Vector2(radius * 0.9, -radius * 1.35), Vector2(-radius * 1.45, -radius * 0.75)]:
			S.diamond(self, size / 2 + star, 2.5, Color(S.CREAM, 0.8))

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
	caps = FontVariation.new()
	caps.base_font = font
	caps.spacing_glyph = 2
	theme.set_color("font_color", "Label", Style.CREAM)
	for type in ["Button", "OptionButton"]:
		theme.set_color("font_color", type, Style.CREAM)
		theme.set_color("font_hover_color", type, Style.GOLD)
		theme.set_color("font_focus_color", type, Style.GOLD)
		theme.set_color("font_pressed_color", type, Style.CREAM)
		theme.set_color("font_disabled_color", type, Color(Style.MUTED, 0.6))
		for name in ["normal", "hover", "pressed", "focus", "disabled"]:
			var box = Style.panel(4, Color(0.07, 0.06, 0.16, 0.72), Style.GOLD_SOFT)
			box.shadow_size = 0
			if name in ["hover", "focus"]:
				box.bg_color = Color(0.95, 0.66, 0.8, 0.14)
				box.border_color = Style.GOLD
			elif name == "pressed": box.bg_color = Color(0.91, 0.79, 0.56, 0.26)
			elif name == "disabled": box.border_color = Color(Style.MUTED, 0.3)
			box.content_margin_left = 18
			box.content_margin_right = 18
			box.content_margin_top = 8
			box.content_margin_bottom = 8
			theme.set_stylebox(name, type, box)
	theme.set_stylebox("panel", "PopupMenu", Style.panel(4, Color(0.06, 0.05, 0.14, 0.97)))
	theme.set_color("font_color", "PopupMenu", Style.CREAM)
	theme.set_color("font_hover_color", "PopupMenu", Style.GOLD)
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.95, 0.66, 0.8, 0.16)
	theme.set_stylebox("hover", "PopupMenu", hover)
	var track = StyleBoxFlat.new()
	track.bg_color = Color(Style.MUTED, 0.35)
	track.content_margin_top = 1
	track.content_margin_bottom = 1
	theme.set_stylebox("slider", "HSlider", track)
	var fill = StyleBoxFlat.new()
	fill.bg_color = Style.GOLD
	fill.content_margin_top = 1
	fill.content_margin_bottom = 1
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	theme.set_icon("grabber", "HSlider", Style.dot(16, Style.CREAM))
	theme.set_icon("grabber_highlight", "HSlider", Style.dot(18, Style.GOLD))
	if ResourceLoader.exists("res://assets/sprites/yoma_luna.png"):
		luna_face = Atlas.region({"sheet": "res://assets/sprites/yoma_luna.png", "columns": 4, "rows": 2, "row": 1, "y_start": 900, "cell_height": 280}, 0)

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

## Square face crop of a poster with a soft circular alpha edge, for orbs.
func round_portrait(id: String) -> Texture2D:
	if round_cache.has(id): return round_cache[id]
	var source: Image = poster(id).get_image()
	if source == null: return null
	if source.is_compressed(): source.decompress()
	var side = int(source.get_width() * 0.36)
	var image = source.get_region(Rect2i(int(source.get_width() * 0.555), int(source.get_height() * 0.07), side, side))
	image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var d = Vector2(x + 0.5 - 64, y + 0.5 - 64).length()
			var color = image.get_pixel(x, y)
			color.a *= clampf(64 - d, 0, 1)
			image.set_pixel(x, y, color)
	round_cache[id] = ImageTexture.create_from_image(image)
	return round_cache[id]

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

func _label(text: String, at: Vector2, width_value: float, font_size: int = 22, color: Color = Style.CREAM, parent: Node = null, display_font: bool = false) -> Label:
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

## Letter-spaced small caption.
func _caps(text: String, at: Vector2, width_value: float, font_size: int = 13, color: Color = Style.GOLD, parent: Node = null) -> Label:
	var label = _label(text, at, width_value, font_size, color, parent)
	label.add_theme_font_override("font", caps)
	label.uppercase = true
	return label

func _ornament(at: Vector2, width_value: float, parent: Node = null, centered: bool = true, tint: Color = Style.GOLD_SOFT) -> Ornament:
	var line = Ornament.new()
	line.position = at
	line.size = Vector2(width_value, 10)
	line.tint = tint
	line.centered = centered
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else page).add_child(line)
	return line

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

func _veil(at: Vector2, extent: Vector2, colors: PackedColorArray, offsets: PackedFloat32Array, vertical: bool, parent: Node = null) -> TextureRect:
	var veil = _texture(Style.gradient_rect(colors, offsets, vertical), at, extent, parent)
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	return veil

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

func _crest(at: Vector2, radius: float, parent: Node = null) -> void:
	var crest = Crest.new()
	crest.radius = radius
	crest.position = at - Vector2.ONE * radius * 2
	crest.size = Vector2.ONE * radius * 4
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else page).add_child(crest)

func title(has_save: bool) -> void:
	_new_page("title")
	title_art = _texture(poster(), Vector2(-12, -8), size + Vector2(24, 16))
	_veil(Vector2.ZERO, Vector2(900, 720), PackedColorArray([Color(Style.INK, 0.95), Color(Style.INK, 0.78), Color(Style.INK, 0.0)]), PackedFloat32Array([0.0, 0.42, 1.0]), false)
	_veil(Vector2(0, 470), Vector2(1280, 250), PackedColorArray([Color(Style.INK, 0.0), Color(Style.INK, 0.85)]), PackedFloat32Array([0.0, 1.0]), true)
	_crest(Vector2(86, 66), 11)
	_caps("PRETTY GUARDIAN", Vector2(116, 56), 400, 13, Style.GOLD)
	_label("Sailor Moon", Vector2(64, 76), 620, 92, Style.CREAM, null, true).size.y = 120
	_ornament(Vector2(70, 196), 430, null, false)
	_caps("IN THE NAME OF THE MOON", Vector2(72, 212), 520, 12, Style.ROSE)
	var entries = [["НАЧАТЬ ИГРУ", "story"], ["ПРОДОЛЖИТЬ", "continue"], ["ХРАНИТЕЛЬНИЦЫ", "roster"], ["ТРЕНИРОВКА", "practice"], ["НАСТРОЙКИ", "settings"], ["ВЫХОД", "quit"]]
	for i in range(entries.size()):
		var button = RiotButton.new()
		button.text = tx(entries[i][0])
		button.clip_text = true
		button.size = Vector2(440, 50)
		button.position = Vector2(60, 268 + i * 56)
		button.add_theme_font_override("font", serif)
		button.add_theme_font_size_override("font_size", 34)
		button.disabled = entries[i][1] == "continue" and not has_save
		button.pressed.connect(func(): _emit(entries[i][1]), Object.CONNECT_DEFERRED)
		page.add_child(button)
		button.modulate.a = 0
		var reveal = create_tween().set_parallel(true)
		reveal.tween_property(button, "modulate:a", 1.0, 0.5).set_delay(0.08 * i)
		reveal.tween_property(button, "position:x", 60.0, 0.6).from(30.0).set_delay(0.08 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if i == 0: button.grab_focus()
	_caps("ACT I  ·  DARK KINGDOM", Vector2(72, 664), 520, 12, Style.MUTED)
	var help = _caps("ENTER — ВЫБРАТЬ     ↑ ↓ — МЕНЮ", Vector2(800, 664), 420, 12, Style.MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func loading(progress: float) -> void:
	if page_kind != "loading":
		_new_page("loading")
		title_art = _texture(poster(), Vector2(-12,-8), size + Vector2(24,16))
		_veil(Vector2(0, 300), Vector2(1280, 420), PackedColorArray([Color(Style.INK, 0.0), Color(Style.INK, 0.94)]), PackedFloat32Array([0.0, 0.75]), true)
		_crest(Vector2(86, 548), 11)
		_caps("ЗАГРУЗКА", Vector2(116, 538), 400, 13, Style.GOLD)
		_label(db.characters[selected_character].title, Vector2(66, 560), 760, 54, Style.CREAM, null, true)
		hp_bar = _bar(Vector2(72, 650), Vector2(480, 3), Style.GOLD)
	hp_bar.value = progress * 100

func _bar(at: Vector2, extent: Vector2, color: Color, parent: Node = null) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.position = at
	bar.show_percentage = false
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(Style.MUTED, 0.3)
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	(parent if parent != null else page).add_child(bar)
	bar.custom_minimum_size = Vector2.ZERO
	bar.size = extent
	return bar

func hud(actor: Dictionary, mode: String) -> void:
	_new_page("hud")
	var shade = _texture(_radial_shade(), Vector2(-120, -110), Vector2(700, 340))
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	var right_shade = _texture(_radial_shade(), Vector2(760, -110), Vector2(640, 300))
	right_shade.stretch_mode = TextureRect.STRETCH_SCALE
	orb = Orb.new()
	orb.position = Vector2(22, 16)
	orb.size = Vector2(104, 104)
	orb.face = round_portrait(actor.id)
	orb.step = db.config.combat.focus_cost / actor.energy
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(orb)
	hud_name = _caps(actor.title, Vector2(140, 22), 330, 13, Style.GOLD)
	masks = Masks.new()
	masks.position = Vector2(138, 44)
	masks.size = Vector2(300, 30)
	masks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(masks)
	hud_skill = _label("", Vector2(140, 78), 330, 13, Color(Style.MIST, 0.85))
	var tag = "ТРЕНИРОВКА / ВСЕ ХРАНИТЕЛЬНИЦЫ" if mode == "practice" else "ACT 1 / УСАГИ — SAILOR MOON"
	var tag_label = _caps(tag, Vector2(760, 22), 490, 12, Style.GOLD_SOFT.lightened(0.2))
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_objective = _label("Доберитесь до ювелирного магазина", Vector2(700, 42), 550, 18, Style.CREAM, null, false)
	hud_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ornament(Vector2(1010, 76), 240, null, true)
	hud_age = 0
	controls_hint = _caps("A D  ДВИЖЕНИЕ    SPACE  ПРЫЖОК    J  УДАР (+W / S — ВВЕРХ / ВНИЗ)    SHIFT  РЫВОК    F  ЛЕЧЕНИЕ    K/Q  ПРИЁМ    L/E  СПЕЦПРИЁМ    ESC  МЕНЮ", Vector2(40, 686), 1200, 11, Color(Style.MIST, 0.75))
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_shade = _texture(_radial_shade(), Vector2(240, 96), Vector2(800, 110))
	toast_shade.stretch_mode = TextureRect.STRETCH_SCALE
	toast_shade.hide()
	toast = _label("", Vector2(290, 132), 700, 21, Style.CREAM)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.hide()
	toast_line = _ornament(Vector2(490, 168), 300, null, true)
	toast_line.hide()
	cast_banner = _label("", Vector2(560, 590), 680, 40, Style.ROSE, null, true)
	cast_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_bar = BossBar.new()
	boss_bar.position = Vector2(340, 612)
	boss_bar.size = Vector2(600, 56)
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(boss_bar)
	var boss_name = _label(db.enemies.boss.get("name", "Морга"), Vector2(0, 0), 600, 26, Style.CREAM, boss_bar, true)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar.hide()

func _radial_shade() -> GradientTexture2D:
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(Style.INK, 0.62), Color(Style.INK, 0.3), Color(Style.INK, 0.0)])
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

func update_hud(player, boss_alive: bool, boss = null) -> void:
	if page_kind != "hud": return
	masks.set_value(player.hp, player.max_hp)
	orb.set_energy(player.energy / player.actor.energy)
	var heals = int(player.energy / db.config.combat.focus_cost)
	hud_skill.text = "ЭНЕРГИЯ %d   ·   F — ЛЕЧЕНИЙ: %d" % [player.energy, heals]
	hud_objective.text = "Победите ёму и спасите Нару" if boss_alive else "Нару спасена — пройдите к свету справа"
	var show_boss = boss != null and is_instance_valid(boss) and boss.hp > 0
	boss_bar.visible = show_boss
	if show_boss:
		boss_bar.ratio = boss.hp / boss.max_hp
		boss_bar.enraged = boss.phase == 2
		boss_bar.queue_redraw()

func notice(text: String) -> void:
	if not is_instance_valid(toast): return
	toast.text = text
	toast.show()
	toast_line.show()
	toast_shade.show()
	toast_time = 3.4

func ability_banner(text: String) -> void:
	if not is_instance_valid(cast_banner): return
	cast_banner.text = text
	cast_banner.show()
	cast_time = 1.4
	cast_banner.position.x = 620
	cast_banner.modulate.a = 0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(cast_banner, "position:x", 560.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(cast_banner, "modulate:a", 1.0, 0.18)

func close_overlay() -> void:
	if is_instance_valid(page): page.modulate.a = 1.0
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = null

## Full overlays get a header (caption, serif title, gold hairline); light ones keep the world visible.
func _overlay(title_text: String, light: bool = false) -> Control:
	var previous = overlay
	overlay = null
	if is_instance_valid(previous):
		_set_input_passthrough(previous)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade = ColorRect.new()
	shade.color = Color(Style.INK, 0.3 if light else 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	if not light:
		if is_instance_valid(page): create_tween().tween_property(page, "modulate:a", 0.0, db.config.visual.fade_seconds)
		_crest(Vector2(78, 36), 9, overlay)
		_caps("SAILOR MOON", Vector2(102, 27), 400, 12, Style.GOLD_SOFT.lightened(0.2), overlay)
		_label(title_text, Vector2(62, 40), 1100, 50, Style.CREAM, overlay, true)
		_ornament(Vector2(64, 104), 1152, overlay, false)
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
		var at = Vector2(40, 122 + i * 52)
		var card = _button("", at, Vector2(318,46), func(): _emit("inspect", {"id": actor.id}), host)
		card.clip_contents = true
		_texture(portrait(actor.id), Vector2(2,1), Vector2(60,44), card)
		_label(actor.name, Vector2(74,-3), 236, 17, Style.CREAM, card)
		_label(actor.title, Vector2(75,21), 236, 12, Color(actor.color).lightened(0.15), card)
		if actor.id == selected: card.grab_focus()
	var actor = db.characters[selected]
	var dossier: Dictionary = profiles.get(selected, {})
	var accent = Color(actor.color)
	var frame = Panel.new()
	frame.position = Vector2(386, 130)
	frame.size = Vector2(278, 500)
	frame.add_theme_stylebox_override("panel", Style.panel(6, Color(accent, 0.1), Color(accent, 0.6)))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(frame)
	var emblem = _label(dossier.get("symbol", "★"), Vector2(540,108), 150, 96, Color(accent,0.22), host)
	emblem.add_theme_font_override("font", load("res://assets/fonts/NotoSansSymbols2-Regular.ttf"))
	var full = _texture(portrait(selected), Vector2(392,136), Vector2(266,446), host)
	full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	full.modulate.a = 0
	full.position.x += 18
	var reveal = create_tween().set_parallel(true)
	reveal.tween_property(full,"modulate:a",1.0,0.32)
	reveal.tween_property(full,"position:x",392.0,0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_caps("GUARDIAN / %02d" % (ids.find(selected)+1), Vector2(400,592), 250, 13, accent.lightened(0.25), host)
	_caps("ЛИЧНОЕ ДЕЛО  /  " + actor.tagline, Vector2(698,124), 555, 12, accent.lightened(0.2), host)
	_label(actor.name, Vector2(695,142), 560, 46, Style.CREAM, host, true)
	_label(actor.title, Vector2(699,196), 550, 20, accent.lightened(0.2), host)
	var bio = _label("", Vector2(699,238), 529, 18, Color(Style.CREAM, 0.88), host)
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bio.text = tx(dossier.get("bio", actor.tagline))
	bio.size = Vector2(529,100)
	_caps("ХАРАКТЕР", Vector2(699,340), 520, 11, Style.GOLD, host)
	_label(dossier.get("traits", ""), Vector2(699,360), 535, 17, Style.CREAM, host)
	_label("ЛИЧНОЕ  /  " + dossier.get("interest", ""), Vector2(699,398), 535, 15, Style.MIST, host)
	_ornament(Vector2(699,436), 530, host, false, Color(accent, 0.7))
	_caps("В БОЮ  /  " + dossier.get("role", ""), Vector2(699,450), 530, 13, accent.lightened(0.25), host)
	for i in range(2):
		var skill = db.skills[actor.primary if i == 0 else actor.special]
		var y = 488 + i * 42
		_caps("K / Q" if i == 0 else "L / E", Vector2(699,y + 2), 77, 13, Style.GOLD, host)
		_label(skill.name, Vector2(780,y), 445, 18, Style.CREAM, host)
	_caps("ВСЕ ХРАНИТЕЛЬНИЦЫ — В ТРЕНИРОВКЕ", Vector2(699,580), 530, 11, Style.MUTED, host)
	if can_select:
		_button("ВЫБРАТЬ ХРАНИТЕЛЬНИЦУ", Vector2(699,620), Vector2(530,49), func(): _emit("choose", {"id": selected}), host)
	_button("НАЗАД / ESC", Vector2(392,652), Vector2(266,40), func(): _emit("back"), host)

func pause_menu() -> void:
	var host = _overlay("ЛУННАЯ ПАУЗА")
	var entries = [["ПРОДОЛЖИТЬ", "back"], ["ХРАНИТЕЛЬНИЦЫ", "roster"], ["СОХРАНИТЬ", "save"], ["НАСТРОЙКИ", "settings"], ["ГЛАВНОЕ МЕНЮ", "title"]]
	for i in range(entries.size()):
		var button = RiotButton.new()
		button.text = tx(entries[i][0])
		button.size = Vector2(460, 50)
		button.position = Vector2(58, 150 + i * 62)
		button.add_theme_font_override("font", serif)
		button.add_theme_font_size_override("font_size", 32)
		button.pressed.connect(func(): _emit(entries[i][1]), Object.CONNECT_DEFERRED)
		host.add_child(button)
		if i==0: button.grab_focus()
	_crest(Vector2(940, 360), 70, host)
	var quote = _label("«Во имя Луны я покараю тебя!»", Vector2(700, 470), 480, 26, Color(Style.CREAM, 0.7), host, true)
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func settings(audio, fullscreen: bool) -> void:
	var host = _overlay("НАСТРОЙКИ")
	var specs = [["Общая громкость", "master_volume"], ["Музыка", "music_volume"], ["Эффекты", "sfx_volume"]]
	for i in range(specs.size()):
		_label(specs[i][0], Vector2(100,146+i*72), 400, 24, Style.CREAM, host)
		var slider = HSlider.new()
		slider.position = Vector2(530,152+i*72)
		slider.size = Vector2(500,30)
		slider.max_value = 1
		slider.step = 0.01
		slider.value = audio.get(specs[i][1])
		slider.value_changed.connect(func(value): _emit("volume", {"field": specs[i][1], "value": value}))
		host.add_child(slider)
	_label("ЯЗЫК", Vector2(100,370), 350, 22, Style.CREAM, host)
	var languages = OptionButton.new()
	languages.position = Vector2(530,364)
	languages.size = Vector2(500,46)
	for title in ["Русский", "English", "Italiano"]: languages.add_item(title)
	languages.select(["ru","en","it"].find(language))
	languages.item_selected.connect(func(index): _emit("language", {"id":["ru","en","it"][index]}), Object.CONNECT_DEFERRED)
	host.add_child(languages)
	_button("ПОЛНЫЙ ЭКРАН: " + ("ВКЛ" if fullscreen else "ВЫКЛ"), Vector2(100,450), Vector2(600,52), func(): _emit("fullscreen"), host)
	_ornament(Vector2(100, 540), 1080, host, false)
	_label("Музыку можно заменить в папке Music рядом с игрой.\nУправление: J — удар (W / S — вверх / вниз), F — лечение, K/Q — приём, L/E — спецприём.\nГеймпад: A — прыжок, X — удар, Y — приём, RB — рывок, RT — лечение, LB — спецприём.", Vector2(100,560), 1090, 17, Style.MIST, host)
	_button("НАЗАД", Vector2(990,650), Vector2(220,45), func(): _emit("back"), host)

## Visual-novel box: the world stays visible, the speaker sits in a moon orb, text types itself in.
func dialogue(speaker: String, text: String) -> void:
	var host = _overlay("", true)
	_veil(Vector2(0, 380), Vector2(1280, 340), PackedColorArray([Color(Style.INK, 0.0), Color(Style.INK, 0.8)]), PackedFloat32Array([0.0, 0.6]), true, host)
	var box = Panel.new()
	box.position = Vector2(150, 492)
	box.size = Vector2(1000, 186)
	box.add_theme_stylebox_override("panel", Style.panel(10))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(box)
	var face: Texture2D = null
	if speaker == "Луна": face = luna_face
	elif speaker == "Усаги": face = round_portrait("moon")
	var text_x = 196.0
	if face != null:
		var speaker_orb = Orb.new()
		speaker_orb.position = Vector2(92, 430)
		speaker_orb.size = Vector2(150, 150)
		speaker_orb.face = face
		speaker_orb.ratio = 0
		speaker_orb.step = 2
		speaker_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(speaker_orb)
		text_x = 268.0
	_label(speaker, Vector2(text_x, 500), 600, 30, Style.GOLD, host, true)
	_ornament(Vector2(text_x, 544), 320, host, false)
	var line = _label(text, Vector2(text_x, 558), 1130 - text_x, 23, Style.CREAM, host)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size.y = 72
	line.visible_ratio = 0
	create_tween().tween_property(line, "visible_ratio", 1.0, clampf(text.length() * 0.022, 0.3, 1.6))
	var next = _button("ДАЛЕЕ  ▸", Vector2(960, 634), Vector2(170, 34), func(): _emit("next"), host)
	next.add_theme_font_size_override("font_size", 15)
	next.grab_focus()

func result(victory: bool, practice: bool) -> void:
	var host = _overlay("ВО ИМЯ ЛУНЫ" if victory else "ЕЩЁ ОДНА ПОПЫТКА")
	_crest(Vector2(640, 214), 26, host)
	var heading = _label("ТРЕНИРОВКА ЗАВЕРШЕНА" if practice and victory else ("ACT 1 / НАРУ СПАСЕНА" if victory else "Последний рубеж помнит ваш свет."), Vector2(140,262), 1000, 40, Style.ROSE, host, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ornament(Vector2(440, 326), 400, host, true)
	var body = _label("Пролог завершён. Следующие акты манги — в разработке." if victory and not practice else "Прыжок и рывок помогают уходить от атак. Следите за энергией.", Vector2(140,346), 1000, 21, Style.CREAM, host)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button("В ГЛАВНОЕ МЕНЮ", Vector2(170,470), Vector2(450,58), func(): _emit("title"), host)
	_button("ТРЕНИРОВКА" if victory else "ПОВТОРИТЬ", Vector2(660,470), Vector2(450,58), func(): _emit("practice" if victory else "retry"), host).grab_focus()

func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(controls_hint):
		hud_age += delta
		controls_hint.modulate.a = clampf(1.0 - (hud_age - 25.0) / 2.0, 0.0, 1.0)
	if is_instance_valid(title_art):
		title_art.position = Vector2(-12 + sin(elapsed * 0.23) * 7, -8 + cos(elapsed * 0.19) * 4)
	if toast_time > 0 and is_instance_valid(toast):
		toast_time -= delta
		var alpha = clampf(minf(toast_time / 0.4, (3.4 - toast_time) / 0.25), 0, 1)
		toast.modulate.a = alpha
		toast_line.modulate.a = alpha
		toast_shade.modulate.a = alpha
		if toast_time <= 0:
			toast.hide()
			toast_line.hide()
			toast_shade.hide()
	if cast_time > 0:
		cast_time -= delta
		if is_instance_valid(cast_banner): cast_banner.modulate.a = clampf(cast_time / 0.3, 0, 1)
		if cast_time <= 0 and is_instance_valid(cast_banner): cast_banner.hide()
