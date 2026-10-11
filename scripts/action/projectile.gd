extends Node2D
signal expired
var skill: Dictionary
var origin: Vector2
var direction: int = 1
var age: float = 0
var hits: Dictionary = {}
var hostile: bool = false
var previous: Vector2
var pixel_heart: Texture2D
var pixel_effect: Texture2D

func setup(definition: Dictionary, start: Vector2, facing: int) -> void:
	skill = definition
	position = start
	origin = start
	previous = start
	direction = facing
	if definition.has("id") and definition.id != "heart":
		pixel_effect = preload("res://scripts/action/guardian_motion.gd").effect(definition.id)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if skill.effect == "hearts":
		pixel_heart = preload("res://scripts/action/moon_motion.gd").heart()
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _physics_process(delta: float) -> void:
	previous = position
	age += delta
	var travel = age
	if skill.effect == "boomerang":
		travel = sin(age / skill.lifetime * PI) * skill.lifetime / PI
	position.x = origin.x + direction * skill.speed * travel
	if skill.effect in ["hearts", "wave"]: position.y = origin.y + sin(age * 9) * 12
	if skill.effect == "ground": position.y = origin.y + 32
	if age >= skill.lifetime:
		expired.emit()
		queue_free()
	queue_redraw()

func collides(point: Vector2, radius: float) -> bool:
	var closest = Geometry2D.get_closest_point_to_segment(point, previous, global_position)
	return closest.distance_to(point) <= radius + skill.radius

func _draw() -> void:
	var color = Color(skill.color)
	var fade = minf(1, (skill.lifetime - age) * 5)
	color.a = fade
	var kind = skill.effect
	if pixel_effect != null:
		_draw_pixel_effect(fade)
		return
	if kind == "hearts":
		for i in range(3):
			var size = 28 - i * 4
			var center = Vector2(-direction * i * 25, roundf(sin(age * 10 + i) * 10))
			draw_texture_rect(pixel_heart, Rect2(center - Vector2.ONE * size/2,Vector2.ONE*size), false, Color(1,1,1,fade*(1-i*0.2)))
	elif kind == "boomerang":
		draw_set_transform(Vector2.ZERO, age * 20)
		draw_arc(Vector2.ZERO, 22, 0.2, 5.2, 16, color, 5)
		draw_circle(Vector2(17, 0), 5, Color.WHITE)
	elif kind == "lightning":
		var points = PackedVector2Array()
		for i in range(8): points.append(Vector2(-direction * i * 15, sin(i * 7 + age * 35) * 20))
		draw_polyline(points, color, 6)
		draw_polyline(points, Color(1, 1, 1, fade), 2)
	elif kind == "chain":
		for i in range(9): draw_arc(Vector2(-direction * i * 14, sin(i * 0.7 + age * 12) * 13), 9, 0, TAU, 10, color, 3)
	elif kind == "mist":
		for i in range(10):
			var offset = Vector2(cos(i * 2.4 + age) * (28 + i * 4), sin(i * 2.4 + age) * 34)
			draw_circle(offset, 24 + sin(age * 5 + i) * 5, Color(color, fade * 0.2))
	elif kind == "glaive":
		draw_arc(Vector2.ZERO, 92, -PI * 0.8, PI * 0.8, 28, color, 11)
		draw_line(Vector2(-12, -78), Vector2(12, 78), Color.WHITE, 4)
	elif kind == "fire":
		for i in range(6):
			var angle = age * 12 + TAU * i / 6
			draw_circle(Vector2(cos(angle), sin(angle)) * 23, 10, color)
		draw_circle(Vector2.ZERO, 13, Color("ffe6ab"))
	elif kind == "wave":
		for i in range(4): draw_arc(Vector2(-direction * i * 12, 0), 26 - i * 3, -PI / 2, PI / 2, 18, Color(color, fade * (1 - i * 0.18)), 5)
	elif kind == "ice":
		draw_colored_polygon(PackedVector2Array([Vector2(-26, 0), Vector2(0, -20), Vector2(34, 0), Vector2(0, 20)]), color)
		draw_line(Vector2(-20, 0), Vector2(26, 0), Color.WHITE, 2)
	else:
		draw_circle(Vector2.ZERO, 23, Color(color, fade * 0.22))
		draw_circle(Vector2.ZERO, 15, color)
		draw_arc(Vector2.ZERO, 27, age * 8, age * 8 + 5, 20, Color.WHITE, 2)

func _heart(center: Vector2, radius: float, color: Color) -> void:
	var points = PackedVector2Array()
	for i in range(24):
		var t = TAU * i / 24
		points.append(center + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2*t) - 2 * cos(3*t) - cos(4*t))) * radius / 16)
	draw_colored_polygon(points, color)

func _draw_pixel_effect(fade: float) -> void:
	var kind: String = skill.effect
	var count = 3 if kind in ["hearts","lightning","chain","mist"] else 1
	for i in count:
		var offset = Vector2(-direction*i*24,roundf(sin(age*10+i)*5))
		var size = Vector2(pixel_effect.get_size())
		if kind == "mist":
			offset = Vector2(roundf(sin(age*5+i*2)*30),roundf(cos(age*5+i*2)*22))
		var rect = Rect2((offset-size/2).round(),size)
		if direction < 0:
			rect.position.x += size.x
			rect.size.x = -size.x
		draw_texture_rect(pixel_effect,rect,false,Color(1,1,1,fade*(1-i*0.18)))
