extends Node2D
## Static level geometry: moonlit cobblestone street, marble ledges, misty pits and Dark Kingdom
## crystal spikes. Drawn once; lights and mist are child nodes so they stay additive.
const Style = preload("res://scripts/action/style.gd")
var definition: Dictionary
var hazards: Array[Rect2] = []

func build(level_definition: Dictionary, hazard_rects: Array[Rect2]) -> void:
	definition = level_definition
	hazards = hazard_rects
	for p in definition.platforms:
		var rect = Rect2(p[0], p[1], p[2], p[3])
		if rect.size.y < 100:
			add_child(Style.light(Vector2(rect.get_center().x, rect.end.y + 10), rect.size.x * 0.55, Color(Style.ROSE, 0.10)))
	for hazard in hazards:
		var pit = hazard.end.y >= definition.size[1] - 1
		add_child(Style.light(Vector2(hazard.get_center().x, hazard.end.y), maxf(hazard.size.x * 0.7, 60), Color(0.55, 0.3, 0.95, 0.30 if pit else 0.22)))
		if pit:
			var mist = CPUParticles2D.new()
			mist.position = Vector2(hazard.get_center().x, definition.size[1] - 10)
			mist.amount = int(clampf(hazard.size.x / 20, 6, 18))
			mist.lifetime = 3.5
			mist.preprocess = 3.5
			mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			mist.emission_rect_extents = Vector2(hazard.size.x / 2, 6)
			mist.direction = Vector2.UP
			mist.spread = 15
			mist.gravity = Vector2.ZERO
			mist.initial_velocity_min = 12
			mist.initial_velocity_max = 30
			mist.texture = Style.glow()
			mist.scale_amount_min = 0.35
			mist.scale_amount_max = 0.7
			mist.color_ramp = _fade(Color(0.6, 0.4, 1.0, 0.22))
			mist.material = Style.additive()
			add_child(mist)
	queue_redraw()

static func _fade(tint: Color) -> Gradient:
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	gradient.colors = PackedColorArray([Color(tint, 0), tint, Color(tint, 0)])
	return gradient

func _noise(x: float, salt: float = 0) -> float:
	return fposmod(sin(x * 12.9898 + salt * 78.233) * 43758.5453, 1.0)

func _draw() -> void:
	if definition.is_empty(): return
	var ground_y: float = definition.ground_y
	var bottom: float = definition.size[1]
	for hazard in hazards:
		if hazard.end.y >= bottom - 1:
			for i in range(10):
				var t = i / 10.0
				draw_rect(Rect2(hazard.position.x, ground_y + t * (bottom - ground_y), hazard.size.x, (bottom - ground_y) / 10.0 + 1), Color("07050f").lerp(Color("1a0f33"), t * t))
	for p in definition.platforms:
		var rect = Rect2(p[0], p[1], p[2], p[3])
		if rect.size.y >= 100: _stone(rect)
		else: _ledge(rect)
	for hazard in hazards: _crystals(hazard)

## Street and pillars: a moonlit cobble cap, brick face fading into night, ivy over the edge.
func _stone(rect: Rect2) -> void:
	draw_rect(rect, Color("120f24"))
	var rows = int(ceil((rect.size.y - 14) / 20.0))
	for row in range(rows):
		var y = rect.position.y + 14 + row * 20
		var depth = clampf(row / 5.0, 0, 1)
		var shift = 0.0 if row % 2 == 0 else 22.0
		var x = rect.position.x - shift
		while x < rect.end.x:
			var w = 44.0
			var shade = 0.8 + _noise(x, row) * 0.35
			var block = Rect2(maxf(x, rect.position.x) + 1, y + 1, minf(x + w, rect.end.x) - maxf(x, rect.position.x) - 2, 18)
			if block.size.x > 0 and block.end.y <= rect.end.y:
				draw_rect(block, Color(0.13 * shade, 0.11 * shade, 0.23 * shade).lerp(Color("0c0a18"), depth))
			x += w
	for i in range(6): draw_rect(Rect2(rect.position.x, rect.position.y + 14 + i * 5, rect.size.x, 5), Color(0, 0, 0, 0.32 - i * 0.05))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 14)), Style.STONE_LIGHT)
	var x2 = rect.position.x
	while x2 < rect.end.x - 2:
		var w2 = 16.0 + _noise(x2, 3) * 14.0
		draw_rect(Rect2(x2 + 1, rect.position.y + 3, minf(w2 - 2, rect.end.x - x2 - 2), 9), Color("5b4f82").lerp(Color("6c5f94"), _noise(x2, 5)))
		x2 += w2
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), Color(0.93, 0.86, 0.97, 0.85))
	draw_rect(Rect2(rect.position + Vector2(0, 12), Vector2(rect.size.x, 2)), Color("1a1530"))
	_ivy(rect, 0.22)

## Floating marble ledge with a gold inlay and a soft shadow beneath.
func _ledge(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(6, 10), rect.size), Color(0, 0, 0, 0.28))
	draw_rect(rect, Color("2c2550"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 7)), Color("4b4180"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), Color(0.97, 0.9, 0.98, 0.9))
	draw_rect(Rect2(rect.position + Vector2(0, 7), Vector2(rect.size.x, 1)), Style.GOLD_SOFT)
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 2), Vector2(rect.size.x, 2)), Color("17132d"))
	for x in [rect.position.x + 10, rect.end.x - 10]:
		Style.diamond(self, Vector2(x, rect.position.y + 11), 3, Style.GOLD_SOFT)
	_ivy(rect, 0.5)

func _ivy(rect: Rect2, chance: float) -> void:
	var x = rect.position.x + 8
	while x < rect.end.x - 8:
		if _noise(x, 11) < chance:
			var length = 10 + _noise(x, 13) * (34 if rect.size.y >= 100 else 22)
			var sway = (_noise(x, 17) - 0.5) * 8
			var top = Vector2(x, rect.position.y + 2)
			var end = top + Vector2(sway, length)
			draw_line(top, end, Color("1f3a3c"), 1.5)
			var leaves = int(length / 7)
			for i in range(leaves):
				var at = top.lerp(end, (i + 1.0) / (leaves + 1))
				var side = 1 if i % 2 == 0 else -1
				Style.diamond(self, at + Vector2(side * 3, 0), 3.2, Color("2f5a55").lerp(Color("4b8270"), _noise(x + i, 19)))
			draw_colored_polygon(PackedVector2Array([top + Vector2(-7, 1), top + Vector2(0, -4), top + Vector2(7, 1)]), Color("2c5550"))
		x += 18 + _noise(x, 23) * 26

## Dark Kingdom crystal shards: uneven heights, a lit facet and a pale tip.
func _crystals(hazard: Rect2) -> void:
	var count = maxi(2, int(hazard.size.x / 15))
	var w = hazard.size.x / count
	for i in range(count):
		var x = hazard.position.x + i * w
		var height = hazard.size.y * (0.7 + _noise(x, 29) * 0.3)
		var lean = (_noise(x, 31) - 0.5) * w * 0.5
		var base_l = Vector2(x - w * 0.1, hazard.end.y)
		var base_r = Vector2(x + w * 1.1, hazard.end.y)
		var tip = Vector2(x + w / 2 + lean, hazard.end.y - height)
		var mid = Vector2(x + w / 2 + lean * 0.4, hazard.end.y)
		draw_colored_polygon(PackedVector2Array([base_l, tip, mid]), Color("2b1d4d"))
		draw_colored_polygon(PackedVector2Array([mid, tip, base_r]), Color("6b52a8"))
		draw_line(tip, tip.lerp(mid, 0.5), Color(0.92, 0.85, 1.0, 0.8), 1.2)
		draw_circle(tip, 1.6, Color(1, 0.92, 1, 0.9))
