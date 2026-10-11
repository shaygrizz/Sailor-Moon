extends Node2D
## Mood layers around the playfield: night grading + vignette + soft bloom (post layer),
## drifting motes and sakura petals that follow the camera, a dark foreground of shrubs and
## railings for depth, and lamp glows pinned to the painted background.
const Style = preload("res://scripts/action/style.gd")
const POST_SHADER = "shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.42;
uniform float bloom = 0.32;
uniform vec4 shadow_tint : source_color = vec4(0.16, 0.11, 0.34, 1.0);
uniform vec4 light_tint : source_color = vec4(1.0, 0.95, 0.9, 1.0);
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	vec3 soft = textureLod(screen_tex, uv, 2.5).rgb * 0.5 + textureLod(screen_tex, uv, 4.0).rgb * 0.5;
	c += max(soft - vec3(0.5), vec3(0.0)) * bloom;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, c * 0.82 + shadow_tint.rgb * 0.16, 1.0 - smoothstep(0.05, 0.45, luma));
	c *= mix(vec3(1.0), light_tint.rgb, smoothstep(0.5, 1.0, luma));
	vec2 d = (uv - 0.5) * vec2(1.25, 1.0);
	c *= 1.0 - vignette * smoothstep(0.32, 0.9, length(d));
	COLOR = vec4(c, 1.0);
}"
## Lamp heads and the jeweller's crystal in the painted street (1672×941 source pixels).
const LAMPS = [[193, 515, 1.0], [530, 515, 1.0], [1070, 515, 1.0], [1420, 515, 1.0], [237, 640, 0.6], [617, 628, 0.6], [858, 628, 0.6], [1136, 642, 0.6], [1365, 642, 0.6]]
const CRYSTAL = [1563, 565]
const MOON = [430, 105]
var motes: CPUParticles2D
var petals: CPUParticles2D
var post: CanvasLayer
var lamp_lights: Array = []
var clock: float = 0

func build(level: Node2D, parallax: Parallax2D, art_size: Vector2) -> void:
	_post_layer(level)
	_background_lights(parallax, art_size)
	var tree = Node2D.new()
	tree.draw.connect(func(): _draw_sakura(tree, Vector2(1280, 612)))
	parallax.add_child(tree)
	motes = _particles(42, 9.0, Style.glow(), 0.05, 0.13)
	motes.direction = Vector2(0.2, -1)
	motes.spread = 50
	motes.initial_velocity_min = 6
	motes.initial_velocity_max = 20
	motes.gravity = Vector2(0, -3)
	var tints = Gradient.new()
	tints.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	tints.colors = PackedColorArray([Color(1.0, 0.85, 0.55, 0.9), Color(1.0, 0.7, 0.85, 0.9), Color(0.65, 0.75, 1.0, 0.9)])
	motes.color_initial_ramp = tints
	motes.material = Style.additive()
	petals = _particles(16, 13.0, Style.petal(), 0.9, 1.5)
	petals.direction = Vector2(-1, 0.45)
	petals.spread = 20
	petals.initial_velocity_min = 22
	petals.initial_velocity_max = 48
	petals.gravity = Vector2(0, 6)
	petals.angular_velocity_min = -140
	petals.angular_velocity_max = 140
	petals.angle_min = 0
	petals.angle_max = 360
	petals.color = Color(1, 0.82, 0.9, 0.85)
	level.add_child(_foreground(level))

func _particles(amount: int, life: float, texture: Texture2D, scale_min: float, scale_max: float) -> CPUParticles2D:
	var particles = CPUParticles2D.new()
	particles.amount = amount
	particles.lifetime = life
	particles.preprocess = life
	particles.local_coords = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(820, 420)
	particles.texture = texture
	particles.scale_amount_min = scale_min
	particles.scale_amount_max = scale_max
	var fade = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	particles.color_ramp = fade
	particles.z_index = 12
	add_child(particles)
	return particles

func _post_layer(level: Node2D) -> void:
	post = CanvasLayer.new()
	post.layer = 5
	var screen = ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = POST_SHADER
	var material = ShaderMaterial.new()
	material.shader = shader
	screen.material = material
	post.add_child(screen)
	level.add_child(post)

func _background_lights(parallax: Parallax2D, art_size: Vector2) -> void:
	var scale = Vector2(1280.0 / art_size.x, 720.0 / art_size.y)
	for tile in range(2):
		var place = func(x: float, y: float) -> Vector2:
			var local = Vector2(x * scale.x, y * scale.y)
			return Vector2(tile * 1280 + (1280 - local.x if tile == 1 else local.x), local.y)
		for lamp in LAMPS:
			var glow = Style.light(place.call(lamp[0], lamp[1]), 70 * lamp[2], Color(1.0, 0.72, 0.38, 0.42 * lamp[2]))
			parallax.add_child(glow)
			glow.set_meta("base", 0.42 * lamp[2])
			lamp_lights.append(glow)
		parallax.add_child(Style.light(place.call(CRYSTAL[0], CRYSTAL[1]), 110, Color(0.85, 0.55, 1.0, 0.35)))
		parallax.add_child(Style.light(place.call(MOON[0], MOON[1]), 230, Color(1.0, 0.95, 0.85, 0.16)))

## Near-black shrubs, flowers and iron railings in front of the street, scrolling faster.
func _foreground(level: Node2D) -> Parallax2D:
	var layer = Parallax2D.new()
	layer.scroll_scale = Vector2(1.3, 1)
	layer.repeat_size = Vector2(1700, 0)
	layer.repeat_times = 3
	layer.z_index = 20
	var art = Node2D.new()
	art.draw.connect(func(): _draw_foreground(art))
	layer.add_child(art)
	return layer

func _draw_foreground(canvas: Node2D) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	var x = 0.0
	while x < 1700:
		var kind = rng.randf()
		if kind < 0.55:
			var width = rng.randf_range(90, 190)
			for i in range(int(width / 16)):
				var center = Vector2(x + i * 16 + rng.randf_range(-4, 4), 708 - rng.randf_range(0, 30))
				var radius = rng.randf_range(14, 26)
				canvas.draw_circle(center, radius, Color(0.035, 0.03, 0.075, 0.97))
				canvas.draw_arc(center, radius - 1, PI * 1.15, PI * 1.85, 10, Color(Style.MIST, 0.16), 1.5)
				if rng.randf() < 0.35: canvas.draw_circle(center + Vector2(rng.randf_range(-8, 8), -radius * 0.6), 2.2, Color(Style.ROSE, 0.55))
			x += width + rng.randf_range(40, 160)
		else:
			var width = rng.randf_range(120, 220)
			canvas.draw_rect(Rect2(x, 676, width, 3), Color(0.03, 0.025, 0.06, 0.97))
			canvas.draw_rect(Rect2(x, 702, width, 18), Color(0.035, 0.03, 0.07, 0.97))
			var bar = x
			while bar < x + width:
				canvas.draw_rect(Rect2(bar, 668, 3, 40), Color(0.03, 0.025, 0.06, 0.97))
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(bar - 2, 668), Vector2(bar + 1.5, 660), Vector2(bar + 5, 668)]), Color(0.03, 0.025, 0.06, 0.97))
				bar += 14
			x += width + rng.randf_range(60, 180)

## Distant giant cherry tree in bloom, painted in the backdrop's palette. It frames the moon
## altar and covers the mirrored seam (and both mirrored towers) of the background.
func _draw_sakura(canvas: Node2D, root: Vector2) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 21
	var bark = Color("2b2045")
	canvas.draw_colored_polygon(PackedVector2Array([root + Vector2(-30, 0), root + Vector2(-16, -200), root + Vector2(-8, -330), root + Vector2(10, -330), root + Vector2(18, -200), root + Vector2(34, 0)]), bark)
	for branch in [[Vector2(-6, -280), Vector2(-250, -420)], [Vector2(6, -290), Vector2(260, -430)], [Vector2(0, -320), Vector2(-110, -520)], [Vector2(4, -320), Vector2(130, -520)], [Vector2(-10, -230), Vector2(-190, -300)], [Vector2(12, -240), Vector2(200, -310)]]:
		canvas.draw_line(root + branch[0], root + branch[1], bark, 10)
	var clusters: Array = []
	for i in range(34):
		var t = rng.randf_range(-1.0, 1.0)
		clusters.append(Vector2(t * 300, -440 + absf(t) * 90 + rng.randf_range(-110, 70)))
	var shades = [Color("4a2c62"), Color("8a4f8f"), Color("c983b8")]
	for layer in range(3):
		for cluster in clusters:
			var lift = layer * -10.0
			for i in range(14 - layer * 4):
				var at = root + cluster + Vector2(rng.randf_range(-46, 46), rng.randf_range(-30, 30) + lift)
				canvas.draw_circle(at, rng.randf_range(7, 14) * (1.0 - layer * 0.2), shades[layer].lerp(Color("6d4d9a"), rng.randf() * 0.25))
	for i in range(160):
		var cluster = clusters[rng.randi() % clusters.size()]
		canvas.draw_rect(Rect2(root + cluster + Vector2(rng.randf_range(-50, 50), rng.randf_range(-36, 30)), Vector2.ONE * 2), Color(1, 0.86, 0.94, rng.randf_range(0.5, 0.9)))

func follow(center: Vector2) -> void:
	motes.position = center
	petals.position = center + Vector2(200, -120)

func _process(delta: float) -> void:
	clock += delta
	for i in range(lamp_lights.size()):
		var base: float = lamp_lights[i].get_meta("base")
		lamp_lights[i].modulate.a = base * (0.88 + 0.08 * sin(clock * 2.3 + i * 1.7) + 0.04 * sin(clock * 11.0 + i))
