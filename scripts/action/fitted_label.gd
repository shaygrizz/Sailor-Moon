extends Label
## Wrap first, then reduce type only when the allocated rectangle requires it.
var preferred_size: int = 22
var translator: Callable
var signature: String = ""

func _process(_delta: float) -> void:
	if translator.is_valid():
		var translated: String = translator.call(text)
		if translated != text: text = translated
	var current = text + str(size)
	if current == signature: return
	signature = current
	add_theme_font_size_override("font_size", preferred_size)
	for font_size in range(preferred_size, 11, -1):
		add_theme_font_size_override("font_size", font_size)
		if get_line_count() * (get_line_height() + get_theme_constant("line_spacing")) <= size.y and get_visible_line_count() >= get_line_count(): break
