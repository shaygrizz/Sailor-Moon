extends Node2D
## Short-lived spark burst for hits, deaths, healing and pogo bounces. Drawn procedurally, frees itself.
const FLASH_SHADER = "shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, tint.rgb, flash);
}"
static var shader: Shader
var sparks: Array = []
var color: Color
var life: float = 0.35
var age: float = 0
var gravity: float = 0
var ring: float = 0

static func flash_material() -> ShaderMaterial:
	if shader == null:
		shader = Shader.new()
		shader.code = FLASH_SHADER
	var material = ShaderMaterial.new()
	material.shader = shader
	return material

static func spawn(parent: Node, at: Vector2, tint: Color, count: int = 10, speed: float = 380, duration: float = 0.35, direction: Vector2 = Vector2.ZERO, fall: float = 0, ring_size: float = 0) -> void:
	var burst = load("res://scripts/action/burst.gd").new()
	burst.position = at
	burst.color = tint
	burst.life = duration
	burst.gravity = fall
	burst.ring = ring_size
	burst.z_index = 5
	for i in range(count):
		var angle = randf() * TAU
		if direction != Vector2.ZERO: angle = direction.angle() + randf_range(-0.7, 0.7)
		burst.sparks.append({"position": Vector2.ZERO, "velocity": Vector2.from_angle(angle) * speed * randf_range(0.45, 1.0), "length": randf_range(6, 16)})
	parent.add_child(burst)

func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	for spark in sparks:
		spark.velocity.y += gravity * delta
		spark.velocity *= 1.0 - delta * 4.0
		spark.position += spark.velocity * delta
	queue_redraw()

func _draw() -> void:
	var fade = 1.0 - age / life
	var tint = Color(color, fade)
	for spark in sparks:
		var tail = spark.velocity.normalized() * spark.length * fade
		draw_line(spark.position - tail, spark.position, tint, 3)
		draw_circle(spark.position, 2, Color(1, 1, 1, fade))
	if ring > 0: draw_arc(Vector2.ZERO, ring * (0.3 + age / life), 0, TAU, 32, tint, 4 * fade + 1)
