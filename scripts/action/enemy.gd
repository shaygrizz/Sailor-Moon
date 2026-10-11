extends CharacterBody2D
## Data-driven foe. Every attack has a readable wind-up (red glow + shake) before it becomes dangerous.
## crawler: patrols and turns at ledges; lunger: charges after a wind-up; flyer: hovers and swoops;
## boss: cycles volley / slam / charge and speeds up below phase_ratio health.
signal fell(enemy)
signal hit
signal shot(origin: Vector2, velocity_value: Vector2)
signal slammed(origin: Vector2)
signal phase_changed
signal warned
const Atlas = preload("res://scripts/action/atlas.gd")
const SnesAtlas = preload("res://scripts/action/snes_atlas.gd")
const Burst = preload("res://scripts/action/burst.gd")
var use_beryl: bool = false
var db
var target
var kind: String = "lunger"
var stats: Dictionary
var boss: bool = false
var hp: float
var max_hp: float
var slow_left: float = 0
var hurt_left: float = 0
var flash_left: float = 0
var knock_left: float = 0
var state: String = "idle"
var state_left: float = 0
var next_attack: String = ""
var last_attack: String = ""
var attack_dir: int = 1
var phase: int = 1
var home: Vector2
var patrol_dir: int = -1
var size_value: Vector2
var sprite: AnimatedSprite2D
var clock: float = 0
var cooldown: float = 0
## A dormant foe (the boss before its arena closes) stands still and deals no damage.
var dormant: bool = false

func configure(database, player, enemy_kind: String, beryl_art: bool = false) -> void:
	db = database
	target = player
	kind = enemy_kind
	stats = db.enemies[kind]
	boss = kind == "boss"
	use_beryl = boss and beryl_art
	hp = db.config.combat.boss_hp if boss else stats.hp
	max_hp = hp
	collision_layer = 4
	collision_mask = 0 if kind == "flyer" else 1
	if kind == "flyer": motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	size_value = Vector2(stats.size[0], stats.size[1])
	var collider = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size_value
	collider.shape = shape
	collider.position.y = -size_value.y / 2
	add_child(collider)
	state_left = randf_range(0.2, 0.8)
	if use_beryl:
		sprite = AnimatedSprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.sprite_frames = SnesAtlas.frames("beryl")
		sprite.position.y = -SnesAtlas.definition("beryl").canvas[1] / 2.0
	elif kind in ["lunger", "boss"] and ResourceLoader.exists("res://assets/sprites/yoma_luna.png"):
		sprite = AnimatedSprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var actor = {"sheet": "res://assets/sprites/yoma_luna.png", "columns": 4, "rows": 2, "row": 0, "y_start": 145, "cell_height": 580}
		sprite.sprite_frames = Atlas.frames(actor, {"idle": [0], "run": [0, 1], "attack": [2], "hurt": [3]}, db.config.visual)
		var frame = sprite.sprite_frames.get_frame_texture("idle", 0)
		sprite.scale = Vector2.ONE * stats.sprite_height / frame.get_height()
		sprite.position.y = -stats.sprite_height / 2.0
	if sprite != null:
		sprite.material = Burst.flash_material()
		add_child(sprite)
		sprite.play("idle")

func _ready() -> void:
	home = position

func hurtbox() -> Rect2:
	return Rect2(global_position + Vector2(-size_value.x / 2, -size_value.y), size_value)

func telegraphing() -> bool:
	return state == "windup"

func _physics_process(delta: float) -> void:
	if hp <= 0: return
	if position.y > 1100:
		take_damage(hp)
		return
	clock += delta
	cooldown = maxf(0, cooldown - delta)
	slow_left = maxf(0, slow_left - delta)
	hurt_left = maxf(0, hurt_left - delta)
	flash_left = maxf(0, flash_left - delta)
	knock_left = maxf(0, knock_left - delta)
	state_left -= delta * (0.4 if slow_left > 0 else 1.0)
	var offset = target.global_position - global_position
	var active = absf(offset.x) < stats.get("trigger_range", 700) + 450 and absf(offset.y) < 360
	if kind != "flyer": velocity.y = minf(velocity.y + db.config.movement.gravity * delta, db.config.movement.max_fall_speed)
	if dormant:
		velocity.x = 0
		move_and_slide()
		_animate(offset)
		queue_redraw()
		return
	if knock_left > 0:
		velocity.x = move_toward(velocity.x, 0, 1400 * delta)
		if kind == "flyer": velocity = velocity.move_toward(Vector2.ZERO, 1400 * delta)
	else:
		match kind:
			"crawler": _crawl()
			"lunger": _lunge(offset, active)
			"flyer": _fly(offset, active, delta)
			"boss": _boss(offset, active)
	if slow_left > 0 and state != "attack": velocity.x *= 0.4
	var was_airborne = not is_on_floor()
	move_and_slide()
	if boss and state == "air" and was_airborne and is_on_floor() and state_left <= 0:
		velocity.x = 0
		slammed.emit(global_position)
		_enter("recover", stats.recover)
	if target.hurtbox().intersects(hurtbox()):
		target.take_damage(stats.contact, global_position.x)
	_animate(offset)
	queue_redraw()

func _enter(next_state: String, seconds: float) -> void:
	state = next_state
	state_left = seconds
	if next_state == "windup": warned.emit()

func _crawl() -> void:
	var space = get_world_2d().direct_space_state
	var probe = PhysicsPointQueryParameters2D.new()
	probe.position = global_position + Vector2(patrol_dir * (size_value.x / 2 + 6), 8)
	probe.collision_mask = 1
	var ledge = is_on_floor() and space.intersect_point(probe, 1).is_empty()
	if is_on_wall() or ledge or absf(position.x - home.x) > stats.patrol and signf(position.x - home.x) == patrol_dir:
		patrol_dir = -patrol_dir
	velocity.x = patrol_dir * stats.speed

func _lunge(offset: Vector2, active: bool) -> void:
	match state:
		"idle":
			velocity.x = signf(offset.x) * stats.speed if active and absf(offset.x) > 40 else 0.0
			if active and absf(offset.x) < stats.trigger_range and absf(offset.y) < 90 and state_left <= 0:
				attack_dir = 1 if offset.x > 0 else -1
				velocity.x = 0
				_enter("windup", stats.windup)
		"windup":
			velocity.x = 0
			if state_left <= 0: _enter("attack", stats.lunge_seconds)
		"attack":
			velocity.x = attack_dir * stats.lunge_speed
			if state_left <= 0 or is_on_wall(): _enter("recover", stats.recover)
		"recover":
			velocity.x = move_toward(velocity.x, 0, 60)
			if state_left <= 0: _enter("idle", 0.4)

func _fly(offset: Vector2, active: bool, delta: float) -> void:
	match state:
		"idle", "recover":
			var anchor = home if not active else target.global_position + Vector2(-signf(offset.x) * 150, -stats.hover_height)
			anchor.y += sin(clock * 2.6) * 18
			velocity = velocity.lerp((anchor - global_position).limit_length(stats.speed * 1.6), minf(1, delta * 3))
			if state == "recover" and state_left <= 0: state = "idle"
			if state == "idle" and active and offset.length() < stats.trigger_range and state_left <= 0:
				velocity = Vector2.ZERO
				_enter("windup", stats.windup)
		"windup":
			velocity = velocity.move_toward(Vector2.ZERO, 900 * delta)
			if state_left <= 0:
				velocity = (target.global_position + Vector2(0, -35) - global_position).normalized() * stats.swoop_speed
				_enter("attack", stats.swoop_seconds)
		"attack":
			if state_left <= 0: _enter("recover", stats.recover)

func _boss(offset: Vector2, active: bool) -> void:
	var fast = 1.35 if phase == 2 else 1.0
	match state:
		"idle":
			velocity.x = signf(offset.x) * stats.speed * fast if active and absf(offset.x) > 140 else 0.0
			if active and state_left <= 0:
				var options = ["volley", "slam", "charge"]
				options.erase(last_attack)
				next_attack = options[randi() % options.size()]
				last_attack = next_attack
				attack_dir = 1 if offset.x > 0 else -1
				velocity.x = 0
				_enter("windup", stats.windup / fast)
		"windup":
			velocity.x = 0
			if state_left <= 0: _boss_strike(offset)
		"attack":
			velocity.x = attack_dir * stats.charge_speed * fast
			if state_left <= 0 or is_on_wall():
				velocity.x = 0
				_enter("recover", stats.recover * 1.3)
		"air":
			pass
		"recover":
			velocity.x = 0
			if state_left <= 0: _enter("idle", stats.pause / fast)

func _boss_strike(offset: Vector2) -> void:
	match next_attack:
		"volley":
			var count = int(stats.volley_phase2 if phase == 2 else stats.volley)
			var base = (offset + Vector2(0, -30)).angle()
			for i in range(count):
				var spread = (i - (count - 1) / 2.0) * stats.volley_spread
				shot.emit(global_position + Vector2(attack_dir * 30, -70), Vector2.from_angle(base + spread) * stats.projectile_speed)
			_enter("recover", stats.recover)
		"slam":
			velocity = Vector2(clampf(offset.x * 1.1, -520, 520), -stats.slam_jump)
			_enter("air", 0.25)
		"charge":
			_enter("attack", stats.charge_seconds)

func _animate(offset: Vector2) -> void:
	var glow = 0.0
	if state == "windup": glow = 0.55 + 0.35 * sin(clock * 40)
	if sprite != null:
		sprite.position.x = sin(clock * 70) * 3 if state == "windup" else 0.0
		sprite.flip_h = (offset.x < 0) if use_beryl else (offset.x > 0)
		if state in ["windup", "attack"]: sprite.flip_h = (attack_dir < 0) if use_beryl else (attack_dir > 0)
		var animation = "hurt" if hurt_left > 0 else ("attack" if state in ["windup", "attack", "air"] else ("run" if absf(velocity.x) > 5 else "idle"))
		if sprite.animation != animation: sprite.play(animation)
		var material = sprite.material as ShaderMaterial
		if flash_left > 0:
			material.set_shader_parameter("tint", Color.WHITE)
			material.set_shader_parameter("flash", 0.85)
		elif glow > 0:
			material.set_shader_parameter("tint", Color("ff2050"))
			material.set_shader_parameter("flash", glow * 0.6)
		elif slow_left > 0:
			material.set_shader_parameter("tint", Color("a3eaff"))
			material.set_shader_parameter("flash", 0.4)
		else: material.set_shader_parameter("flash", 0.0)

func take_damage(amount: float, slow: float = 0, knock: Vector2 = Vector2.ZERO) -> void:
	if hp <= 0: return
	hp = maxf(0, hp - amount)
	slow_left = maxf(slow_left, slow)
	hurt_left = 0.18
	flash_left = 0.09
	if knock != Vector2.ZERO and state != "attack":
		var force = stats.knockback
		velocity.x = knock.x * force if knock.x != 0 else velocity.x
		if knock.y < 0 or kind == "flyer": velocity.y = knock.y * force * 0.8 if knock.y != 0 else velocity.y
		knock_left = 0.16 if not boss else 0.05
	hit.emit()
	if boss and phase == 1 and hp <= max_hp * stats.phase_ratio:
		phase = 2
		flash_left = 0.3
		phase_changed.emit()
	if hp <= 0:
		fell.emit(self)
		queue_free()

func _draw() -> void:
	var white = flash_left > 0
	var glow = state == "windup"
	if sprite == null:
		var body_color = Color.WHITE if white else (Color(stats.color).lerp(Color("ff2050"), 0.5 + 0.3 * sin(clock * 40)) if glow else Color(stats.color))
		var eye = Color(stats.eye)
		var shake = Vector2(sin(clock * 70) * 3, 0) if glow else Vector2.ZERO
		if kind == "crawler":
			var bob = sin(clock * 10) * 2
			var center = Vector2(0, -15 + bob) + shake
			draw_circle(center, 19, body_color)
			draw_rect(Rect2(center + Vector2(-23, 2), Vector2(46, 13)), body_color)
			for i in range(3):
				var leg = center + Vector2(-14 + i * 14, 14)
				draw_line(leg, leg + Vector2(sin(clock * 14 + i) * 5, 6 - bob), body_color.darkened(0.3), 3)
			draw_circle(center + Vector2(patrol_dir * 8, -4), 4, eye)
			draw_circle(center + Vector2(patrol_dir * 15, -2), 3, eye)
		elif kind == "flyer":
			var center = Vector2(0, -17) + shake
			var flap = absf(sin(clock * (22 if state == "attack" else 12)))
			for side in [-1, 1]:
				var wing = PackedVector2Array([center, center + Vector2(side * 34, -26 * flap - 6), center + Vector2(side * 30, 10), center + Vector2(side * 12, 14)])
				draw_colored_polygon(wing, Color(body_color, 0.85))
				draw_polyline(wing, Color("ffb8e8") if not white else Color.WHITE, 1.5)
			draw_circle(center, 12, body_color.darkened(0.25))
			draw_circle(center + Vector2(-5, -2), 3, eye)
			draw_circle(center + Vector2(5, -2), 3, eye)
	if glow:
		var top = -size_value.y - 26
		draw_colored_polygon(PackedVector2Array([Vector2(-6, top - 14), Vector2(6, top - 14), Vector2(2, top), Vector2(-2, top)]), Color("ff3a64"))
		draw_circle(Vector2(0, top + 6), 3, Color("ff3a64"))
	if hp < max_hp or boss:
		var width_value = 120 if boss else 46
		var y = -size_value.y - (70 if boss else 12)
		if use_beryl: y = -SnesAtlas.definition("beryl").canvas[1] - 10.0
		elif sprite != null: y = -stats.sprite_height - 10.0
		draw_rect(Rect2(-width_value / 2.0 - 1, y - 1, width_value + 2, 7), Color("0d0a16"))
		draw_rect(Rect2(-width_value / 2.0, y, width_value * hp / max_hp, 5), Color("ff3266") if phase == 1 else Color("ff8a3d"))
