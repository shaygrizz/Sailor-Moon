extends RefCounted
## "Moonlight" art direction shared by the world and the interface: deep indigo night,
## hairline gold, rose accents and soft additive glow. Change colours here, not at call sites.
const INK = Color("0a0918")
const NIGHT = Color("15122f")
const PANEL = Color(0.055, 0.047, 0.13, 0.88)
const GOLD = Color("e8c98e")
const GOLD_SOFT = Color(0.91, 0.79, 0.56, 0.42)
const ROSE = Color("f3a8c8")
const CREAM = Color("fff5e6")
const MIST = Color("b8acd9")
const MUTED = Color("8f86ad")
const HEART = Color("ff8fb5")
const DANGER = Color("ff4f7e")
const STONE = Color("231d3d")
const STONE_LIGHT = Color("4a3f6b")

static var _glow: Texture2D
static var _add: CanvasItemMaterial
static var _dots: Dictionary = {}
static var _petal: Texture2D

## Soft radial falloff, white so it can be tinted with modulate.
static func glow() -> Texture2D:
	if _glow == null:
		var gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0)])
		var texture = GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 128
		texture.height = 128
		_glow = texture
	return _glow

static func additive() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add

## Additive light sprite centred on `at`.
static func light(at: Vector2, radius: float, tint: Color) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = glow()
	sprite.material = additive()
	sprite.position = at
	sprite.scale = Vector2.ONE * radius / 64.0
	sprite.modulate = tint
	return sprite

static func dot(diameter: int, tint: Color) -> Texture2D:
	var key = str(diameter) + tint.to_html()
	if not _dots.has(key):
		var image = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
		var r = diameter / 2.0
		for y in diameter:
			for x in diameter:
				var d = Vector2(x + 0.5 - r, y + 0.5 - r).length()
				image.set_pixel(x, y, Color(tint, clampf(r - d, 0, 1) * tint.a))
		_dots[key] = ImageTexture.create_from_image(image)
	return _dots[key]

static func petal() -> Texture2D:
	if _petal == null:
		var image = Image.create(10, 7, false, Image.FORMAT_RGBA8)
		for y in 7:
			for x in 10:
				var p = Vector2((x + 0.5 - 5) / 5.0, (y + 0.5 - 3.5) / 3.5)
				var inside = 1.0 - p.length_squared()
				image.set_pixel(x, y, Color(1, 0.86, 0.92, clampf(inside * 3, 0, 1)))
		_petal = ImageTexture.create_from_image(image)
	return _petal

static func gradient_rect(colors: PackedColorArray, offsets: PackedFloat32Array, vertical: bool) -> GradientTexture2D:
	var gradient = Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(0, 1) if vertical else Vector2(1, 0)
	return texture

static func panel(radius: int = 6, fill: Color = PANEL, border: Color = GOLD_SOFT) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 12
	box.anti_aliasing = true
	return box

static func crescent(canvas: CanvasItem, center: Vector2, radius: float, tint: Color, angle: float = -0.5) -> void:
	# Outer disc minus a smaller disc shifted towards `angle`; the lit side faces away from it.
	var cutter = center + Vector2.from_angle(angle) * radius * 0.45
	var cut_radius = radius * 0.86
	var points = PackedVector2Array()
	var steps = 48
	for i in range(steps + 1):
		var p = center + Vector2.from_angle(angle + TAU * i / steps) * radius
		if p.distance_to(cutter) >= cut_radius: points.append(p)
	var inner = PackedVector2Array()
	for i in range(steps + 1):
		var p = cutter + Vector2.from_angle(angle + TAU * i / steps) * cut_radius
		if p.distance_to(center) <= radius: inner.append(p)
	inner.reverse()
	points.append_array(inner)
	if points.size() >= 3: canvas.draw_colored_polygon(points, tint)

static func diamond(canvas: CanvasItem, center: Vector2, size: float, tint: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -size), center + Vector2(size * 0.7, 0), center + Vector2(0, size), center + Vector2(-size * 0.7, 0)]), tint)
