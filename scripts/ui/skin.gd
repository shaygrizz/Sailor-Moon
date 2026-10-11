extends RefCounted
## Presentation constants belong to the theme, not the combat rules.
static func box(color: Color, border: Color = Color("45405c"), radius: int = 18) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func make_theme() -> Theme:
	var result = Theme.new()
	var font = ThemeDB.fallback_font.duplicate()
	font.fallbacks = [load("res://assets/fonts/NotoSansSymbols2-Regular.ttf")]
	result.default_font = font
	result.default_font_size = 22
	result.set_color("font_color", "Label", Color("f5edee"))
	result.set_color("font_color", "Button", Color("eee4eb"))
	result.set_color("font_hover_color", "Button", Color("ffffff"))
	result.set_color("font_disabled_color", "Button", Color("676982"))
	result.set_stylebox("normal", "Button", box(Color("25263e")))
	result.set_stylebox("hover", "Button", box(Color("41364f"), Color("dfc99c")))
	result.set_stylebox("pressed", "Button", box(Color("5a405a"), Color("efb5d0")))
	result.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), Color("f2d7a8")))
	result.set_stylebox("disabled", "Button", box(Color("171c31"), Color("30354a")))
	result.set_stylebox("panel", "PanelContainer", box(Color("151a34")))
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 12)
	return result

static func label(text: String, size: int = 22, color: Color = Color("f5edee")) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func paragraph(text: String, size: int = 22) -> Label:
	var node = label(text, size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

static func button(text: String, callback: Callable, primary: bool = false) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size.y = 56
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		node.add_theme_stylebox_override("normal", box(Color("c491b1"), Color("edc2d8")))
		node.add_theme_color_override("font_color", Color("19192e"))
		node.add_theme_color_override("font_hover_color", Color("19192e"))
		node.add_theme_stylebox_override("hover", box(Color("e8b9d0"), Color("f5dcec")))
	# Replacing a screen inside a touch dispatch detaches the active button too early.
	node.pressed.connect(callback, Object.CONNECT_DEFERRED)
	return node

static func panel(parent: Node, rect: Rect2) -> VBoxContainer:
	var panel_node = PanelContainer.new()
	panel_node.position = rect.position
	panel_node.size = rect.size
	parent.add_child(panel_node)
	var column = VBoxContainer.new()
	panel_node.add_child(column)
	return column

static func bar(value: float, maximum: float, color: Color) -> ProgressBar:
	var node = ProgressBar.new()
	node.max_value = maximum
	node.value = value
	node.show_percentage = false
	node.custom_minimum_size.y = 6
	var background = box(Color("34364c"), Color("34364c"), 3)
	var fill = box(color, color, 3)
	for style in [background, fill]:
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		style.content_margin_left = 0
		style.content_margin_right = 0
	node.add_theme_stylebox_override("background", background)
	node.add_theme_stylebox_override("fill", fill)
	return node
