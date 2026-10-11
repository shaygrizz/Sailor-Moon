extends Button
var index: int = 0
var accent = Color("ff335d")
var amount: float = 0
var rest_x: float = 0
var plate: Node2D

func _ready() -> void:
	plate = Node2D.new()
	plate.show_behind_parent = true
	add_child(plate)
	plate.draw.connect(_draw_plate)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_theme_color_override("font_color", Color("fff6ef"))
	add_theme_color_override("font_hover_color", Color("0b0c10"))
	add_theme_color_override("font_focus_color", Color("0b0c10"))
	add_theme_color_override("font_pressed_color", Color("fff6ef"))
	add_theme_color_override("font_disabled_color", Color("777078"))
	alignment = HORIZONTAL_ALIGNMENT_LEFT

func _process(delta: float) -> void:
	amount = move_toward(amount, 1 if (is_hovered() or has_focus()) and not disabled else 0, delta * 9)
	plate.queue_redraw()

func _draw_plate() -> void:
	if amount > 0:
		var points = PackedVector2Array([Vector2(-14, 5), Vector2(size.x - 35, -3), Vector2(size.x, size.y - 8), Vector2(-5, size.y + 1)])
		plate.draw_colored_polygon(points, Color(accent, amount))
		plate.draw_line(Vector2(-8, size.y + 5), Vector2(size.x - 15, size.y - 5), Color("fef0d9", amount), 3)
