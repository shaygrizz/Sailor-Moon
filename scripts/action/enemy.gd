extends CharacterBody2D
signal fell(enemy)
signal hit
signal shot(origin: Vector2, direction: int)
const Atlas = preload("res://scripts/action/atlas.gd")
const SnesAtlas = preload("res://scripts/action/snes_atlas.gd")
var use_beryl: bool = false
var attack_visual_left: float = 0
var db
var target
var boss: bool = false
var hp: float
var max_hp: float
var cooldown: float = 1.0
var slow_left: float = 0
var hurt_left: float = 0
var sprite: AnimatedSprite2D
var clock: float = 0

func configure(database, player, is_boss: bool, beryl_art: bool = false) -> void:
	db = database
	target = player
	boss = is_boss
	use_beryl = boss and beryl_art
	hp = db.config.combat.boss_hp if boss else db.config.combat.enemy_hp
	max_hp = hp
	collision_layer = 4
	collision_mask = 1
	var collider = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(34, 80)
	collider.shape = shape
	collider.position.y = -40
	add_child(collider)
	if use_beryl:
		sprite = AnimatedSprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.sprite_frames = SnesAtlas.frames("beryl")
		sprite.position.y = -SnesAtlas.definition("beryl").canvas[1] / 2.0
		add_child(sprite)
		sprite.play("idle")
		return
	if ResourceLoader.exists("res://assets/sprites/yoma_luna.png"):
		sprite = AnimatedSprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var actor = {"sheet": "res://assets/sprites/yoma_luna.png", "columns": 4, "rows": 2, "row": 0, "y_start": 145, "cell_height": 580}
		sprite.sprite_frames = Atlas.frames(actor, {"idle": [0], "run": [0, 1], "attack": [2], "hurt": [3]}, db.config.visual)
		var height_value = 152.0 if boss else 110.0
		var frame = sprite.sprite_frames.get_frame_texture("idle", 0)
		sprite.scale = Vector2.ONE * height_value / frame.get_height()
		sprite.position.y = -height_value / 2
		add_child(sprite)
		sprite.play("idle")

func _physics_process(delta: float) -> void:
	if hp <= 0: return
	clock += delta
	cooldown -= delta
	slow_left = maxf(0, slow_left - delta)
	hurt_left = maxf(0, hurt_left - delta)
	attack_visual_left = maxf(0, attack_visual_left - delta)
	velocity.y += db.config.movement.gravity * delta
	var distance = target.global_position.x - global_position.x
	var active = absf(distance) < 760
	velocity.x = signf(distance) * db.config.combat.enemy_speed * (0.25 if slow_left > 0 else 1) if active and absf(distance) > 58 else 0
	if hurt_left > 0: velocity.x *= -0.35
	move_and_slide()
	if active and cooldown <= 0:
		if boss:
			attack_visual_left = 0.3
			cooldown = db.config.combat.boss_attack_interval
			shot.emit(global_position + Vector2(0, -45), 1 if distance > 0 else -1)
		elif absf(distance) < db.config.combat.enemy_attack_range and absf(target.position.y - position.y) < 88:
			cooldown = db.config.combat.enemy_attack_interval
			target.take_damage(db.config.combat.enemy_damage, global_position.x)
	if absf(distance) < 32 and absf(target.position.y - position.y) < 72:
		target.take_damage(db.config.combat.contact_damage, global_position.x)
	if sprite != null:
		if use_beryl:
			sprite.flip_h = distance < 0
			var state = "hurt" if hurt_left > 0 else ("attack" if attack_visual_left > 0 else ("run" if absf(velocity.x) > 0 else "idle"))
			if sprite.animation != state: sprite.play(state)
			sprite.modulate = Color.WHITE
			queue_redraw()
			return
		sprite.flip_h = distance > 0
		sprite.play("hurt" if hurt_left > 0 else ("attack" if cooldown > db.config.combat.enemy_attack_interval - 0.3 else ("run" if absf(velocity.x) > 0 else "idle")))
		sprite.modulate = Color("a3eaff") if slow_left > 0 else (Color("ff99b8") if hurt_left > 0 else Color.WHITE)
	queue_redraw()

func take_damage(amount: float, slow: float = 0) -> void:
	if hp <= 0: return
	hp = maxf(0, hp - amount)
	slow_left = maxf(slow_left, slow)
	hurt_left = 0.18
	hit.emit()
	if hp <= 0:
		fell.emit(self)
		queue_free()

func _draw() -> void:
	if sprite == null:
		draw_circle(Vector2(0, -45), 30, Color("49336a"))
		draw_circle(Vector2(-9, -50), 4, Color("ff466e"))
		draw_circle(Vector2(9, -50), 4, Color("ff466e"))
	var width_value = 90 if boss else 55
	draw_rect(Rect2(-width_value / 2.0, -160 if boss else -118, width_value, 5), Color("1c172c"))
	draw_rect(Rect2(-width_value / 2.0, -160 if boss else -118, width_value * hp / max_hp, 5), Color("ff3266"))
