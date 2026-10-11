extends Control
## Small native developer tool for all JSON catalogs. Not included in the Web build.
const Database = preload("res://scripts/core/content_database.gd")
const ThemeKit = preload("res://scripts/ui/skin.gd")
var db = Database.new()
var selector: OptionButton
var editor: CodeEdit
var feedback: Label
var paths: Array[String] = []

func _ready() -> void:
	theme = ThemeKit.make_theme()
	var layout = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 24
	layout.offset_top = 24
	layout.offset_right = -24
	layout.offset_bottom = -24
	add_child(layout)
	layout.add_child(ThemeKit.label("Moonveil · Content Studio", 30))
	layout.add_child(ThemeKit.paragraph("Редактируйте JSON-каталоги. Некорректные изменения отклоняются до записи файла.", 18))
	selector = OptionButton.new()
	selector.custom_minimum_size.y = 52
	layout.add_child(selector)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/manifest.json"))
	for catalog in manifest.catalogs:
		selector.add_item(catalog)
		paths.append(manifest.catalogs[catalog])
	selector.item_selected.connect(_load_catalog)
	editor = CodeEdit.new()
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.code_completion_enabled = false
	editor.gutters_draw_line_numbers = true
	layout.add_child(editor)
	feedback = ThemeKit.paragraph("", 18)
	layout.add_child(feedback)
	layout.add_child(ThemeKit.button("Проверить и сохранить", _save, true))
	_load_catalog(0)

func _load_catalog(index: int) -> void:
	editor.text = FileAccess.get_file_as_string(paths[index])
	feedback.text = paths[index]

func _save() -> void:
	var parser = JSON.new()
	if parser.parse(editor.text) != OK or not parser.data is Dictionary:
		feedback.text = "Ошибка JSON, строка %d: %s" % [parser.get_error_line(), parser.get_error_message()]
		return
	# Validate the candidate in memory before touching the source file.
	if not db.load_all():
		feedback.text = "Текущие данные некорректны: " + str(db.errors)
		return
	var catalog = selector.get_item_text(selector.selected)
	db.catalogs[catalog] = parser.data
	db.errors.clear()
	db.validate()
	if not db.errors.is_empty():
		feedback.text = "Не сохранено: " + str(db.errors)
		return
	var path = paths[selector.selected]
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		feedback.text = "Нет доступа к файлу."
		return
	file.store_string(JSON.stringify(parser.data, "  ") + "\n")
	file.close()
	feedback.text = "Сохранено. Перезапустите игру, чтобы применить изменения."
