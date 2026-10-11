extends Control
## Presentation and input only. Normalized coordinates are independent of resolution.
signal point_reached(id: String)
signal position_changed(normalized: Vector2)
const ThemeKit = preload("res://scripts/ui/skin.gd")
var map_data: Dictionary
var settings: Dictionary
var player = Vector2(0.5, 0.8)
var target = Vector2(0.5, 0.8)
var pending_point: String = ""
var time: float = 0.0
var enabled: bool = true
var touch_direction = Vector2.ZERO
var point_buttons: Array = []

func setup(map_definition: Dictionary, config: Dictionary, start: Array) -> void:
	map_data = map_definition
	settings = config
	player = Vector2(start[0], start[1])
	target = player
	clip_contents = true
	var background = TextureRect.new()
	background.texture = load(map_data.background)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var drawing = Node2D.new()
	drawing.draw.connect(_draw_avatar.bind(drawing))
	drawing.name = "Avatar"
	add_child(drawing)
	for point in map_data.points:
		var button = ThemeKit.button(point.icon + "  " + point.name, func(): go_to(point))
		button.add_theme_font_size_override("font_size", 18)
		button.custom_minimum_size = Vector2(178, 54)
		button.size = Vector2(206, 54)
		button.tooltip_text = "Подойти и взаимодействовать"
		add_child(button)
		point_buttons.append({"node": button, "point": point})
	resized.connect(_layout_points)
	_layout_points()

func _layout_points() -> void:
	var occupied: Array[Rect2] = []
	for entry in point_buttons:
		var width_value = 178.0 if size.x < 600 else 206.0
		entry.node.custom_minimum_size.x = width_value
		entry.node.size.x = width_value
		entry.node.clip_text = true
		entry.node.add_theme_font_size_override("font_size", 16 if size.x < 600 else 18)
		var at = Vector2(entry.point.position[0], entry.point.position[1]) * size - Vector2(width_value / 2, 72)
		at.x = clampf(at.x, 8, maxf(8, size.x - width_value - 8))
		var rect = Rect2(at, Vector2(width_value, 56))
		for prior in occupied:
			if prior.grow(4).intersects(rect):
				rect.position.y = prior.end.y + 8
		entry.node.position = rect.position
		occupied.append(rect)

func go_to(point: Dictionary) -> void:
	if not enabled:
		return
	target = Vector2(point.position[0], point.position[1])
	pending_point = point.id

func _gui_input(event: InputEvent) -> void:
	if enabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		target = _bounded(event.position / size)
		pending_point = ""

func _process(delta: float) -> void:
	time += delta
	get_node("Avatar").queue_redraw()
	if not enabled:
		return
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down") + touch_direction
	if direction.length() > 0.1:
		target = _bounded(player + direction.normalized() * settings.speed * delta)
		pending_point = ""
	var previous = player
	player = player.move_toward(target, settings.speed * delta)
	if previous != player:
		position_changed.emit(player)
	if pending_point != "" and player.distance_to(target) <= settings.arrival_distance:
		var id = pending_point
		pending_point = ""
		point_reached.emit(id)
	if Input.is_action_just_pressed("interact"):
		interact_nearest()

func interact_nearest() -> void:
	if not enabled:
		return
	var closest: Dictionary = {}
	var distance: float = settings.interact_distance
	for point in map_data.points:
		var candidate = player.distance_to(Vector2(point.position[0], point.position[1]))
		if candidate <= distance:
			closest = point
			distance = candidate
	if not closest.is_empty():
		point_reached.emit(closest.id)

func _bounded(value: Vector2) -> Vector2:
	var bounds = settings.bounds
	return Vector2(clampf(value.x, bounds[0], bounds[2]), clampf(value.y, bounds[1], bounds[3]))

func _draw_avatar(canvas: Node2D) -> void:
	var p = player * size
	var bob = sin(time * 3.0) * 2.0
	canvas.draw_set_transform(p + Vector2(0, bob))
	canvas.draw_arc(Vector2(0, 7), 21, 0, TAU, 32, Color("dfc99c"), 1.5, true)
	canvas.draw_circle(Vector2(0, 4), 17, Color(0.05, 0.03, 0.12, 0.4))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-13, 0), Vector2(13, 0), Vector2(7, -26), Vector2(-7, -26)]), Color("efb5d0"))
	canvas.draw_line(Vector2(-5, 0), Vector2(-6, 11), Color("eee1ef"), 5)
	canvas.draw_line(Vector2(5, 0), Vector2(6, 11), Color("eee1ef"), 5)
	canvas.draw_circle(Vector2(0, -32), 12, Color("cfbad7"))
	canvas.draw_circle(Vector2(0, -29), 8, Color("f3cec6"))
	canvas.draw_line(Vector2(15, -15), Vector2(25, -37), Color("dfc99c"), 3)
	canvas.draw_circle(Vector2(26, -39), 5, Color("f9dcf0"))
	canvas.draw_set_transform(Vector2.ZERO)
