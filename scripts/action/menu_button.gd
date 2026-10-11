extends Button
## Serif menu entry: on focus a gold crescent slides in, the label drifts right and turns gold,
## and a hairline draws itself under the text.
const Style = preload("res://scripts/action/style.gd")
var index: int = 0
var amount: float = 0
var plate: Node2D
var margin: StyleBoxEmpty

func _ready() -> void:
	plate = Node2D.new()
	plate.show_behind_parent = true
	add_child(plate)
	plate.draw.connect(_draw_plate)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): if not disabled: grab_focus())
	margin = StyleBoxEmpty.new()
	margin.content_margin_left = 34
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, margin)
	add_theme_color_override("font_color", Color(Style.CREAM, 0.86))
	add_theme_color_override("font_hover_color", Style.GOLD)
	add_theme_color_override("font_focus_color", Style.GOLD)
	add_theme_color_override("font_pressed_color", Style.CREAM)
	add_theme_color_override("font_disabled_color", Color(Style.MUTED, 0.45))
	alignment = HORIZONTAL_ALIGNMENT_LEFT

func _process(delta: float) -> void:
	var target = 1.0 if (is_hovered() or has_focus()) and not disabled else 0.0
	if absf(amount - target) < 0.001: return
	amount = move_toward(amount, target, delta * 6)
	margin.content_margin_left = 34 + 10 * _ease(amount)
	plate.queue_redraw()

func _ease(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3)

func _draw_plate() -> void:
	if amount <= 0: return
	var t = _ease(amount)
	var mid = size.y / 2 + 2
	var glow = Style.glow()
	plate.draw_texture_rect(glow, Rect2(Vector2(-30, mid - 40), Vector2(size.x * 0.9, 80)), false, Color(Style.ROSE, 0.10 * t))
	Style.crescent(plate, Vector2(8 + 8 * t, mid), 9, Color(Style.GOLD, t), -0.6)
	var text_width = get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x
	var start = 34 + 10 * t
	plate.draw_line(Vector2(start, size.y - 4), Vector2(start + text_width * t, size.y - 4), Color(Style.GOLD, 0.6 * t), 1)
