extends Control
## Fixed-size analytic particle pool: no per-frame allocations or spawned nodes.
var particles: Array[Vector3] = []
var time: float = 0.0
var speed: float = 12.0

func configure(count: int, fall_speed: float) -> void:
	speed = fall_speed
	var rng = RandomNumberGenerator.new()
	rng.seed = 7241
	for i in range(count):
		particles.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(1, 3)))
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	for particle in particles:
		var point = Vector2(fposmod(particle.x * size.x + sin(time * 0.2 + particle.y * 20) * 25, maxf(size.x, 1)), fposmod(particle.y * size.y + time * speed * particle.z * 0.3, maxf(size.y, 1)))
		draw_circle(point, particle.z, Color(0.95, 0.75, 0.87, 0.22 + sin(time + particle.x * 12) * 0.13))
