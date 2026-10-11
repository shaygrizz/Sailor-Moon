extends CharacterBody2D
signal ability_used(id: String, origin: Vector2, direction: int)
signal melee_used(origin: Vector2, direction: int, multiplier: float)
signal health_changed
signal defeated
signal feedback(kind: String)
const Atlas = preload("res://scripts/action/atlas.gd")
const SnesAtlas = preload("res://scripts/action/snes_atlas.gd")
const Motion = preload("res://scripts/action/guardian_motion.gd")
var db
var actor: Dictionary
var sprite: AnimatedSprite2D
var hp: float
var energy: float
var facing: int = 1
var control_enabled: bool = true
var practice: bool = false
var invulnerable: float = 0
var dash_left: float = 0
var dash_cooldown: float = 0
var attack_left: float = 0
var attack_cooldown: float = 0
var skill_cooldown: float = 0
var hurt_left: float = 0
var coyote: float = 0
var jump_buffer: float = 0
var air_jumps: int = 0
var combo: int = 0
var combo_left: float = 0
var clock: float = 0
var cast: bool = false
var pending_melee: bool = false
var landing_left: float = 0
var combat_ready: bool = false
var pending_special: String = ""
var special_left: float = 0.0
const SPECIAL_SECONDS: float = 2.4

func cancel_special() -> void:
	pending_special = ""
	special_left = 0.0
	attack_left = 0.0
	pending_melee = false

func configure(database, id: String, is_practice: bool) -> void:
	db = database
	practice = is_practice
	actor = db.characters[id]
	hp = actor.hp
	energy = actor.energy
	collision_layer = 2
	collision_mask = 1
	var shape = CollisionShape2D.new()
	var capsule = CapsuleShape2D.new()
	capsule.radius = 13
	capsule.height = 70
	shape.shape = capsule
	shape.position.y = -36
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_set_art()

func _set_art() -> void:
	sprite.sprite_frames = Motion.frames(actor.id)
	sprite.scale = Vector2.ONE
	sprite.position.y = -Motion.canvas(actor.id).y/2
	sprite.play("idle")

func change_character(id: String) -> bool:
	if not practice or not db.characters.has(id): return false
	var hp_ratio = hp / actor.hp
	var energy_ratio = energy / actor.energy
	cancel_special()
	actor = db.characters[id]
	hp = hp_ratio * actor.hp
	energy = energy_ratio * actor.energy
	_set_art()
	health_changed.emit()
	return true

func _physics_process(delta: float) -> void:
	if db == null: return
	clock += delta
	if special_left > 0:
		if not control_enabled: cancel_special()
		else:
			special_left = maxf(0, special_left - delta)
			var release_left = 0.0 if actor.id == "moon" else 0.3
			if special_left <= release_left and not pending_special.is_empty():
				var released = pending_special
				pending_special = ""
				ability_used.emit(released, global_position + Vector2(facing * 34,-45), facing)
	landing_left = maxf(0, landing_left - delta)
	var move = db.config.movement
	var combat = db.config.combat
	for field in ["invulnerable", "dash_left", "dash_cooldown", "attack_left", "attack_cooldown", "skill_cooldown", "hurt_left", "coyote", "jump_buffer", "combo_left"]:
		set(field, maxf(0, get(field) - delta))
	if combo_left <= 0: combo = 0
	energy = minf(actor.energy, energy + combat.energy_regen * delta)
	if is_on_floor():
		coyote = move.coyote_seconds
		air_jumps = int(move.air_jumps)
	var axis = Input.get_axis("a_left", "a_right") if control_enabled else 0.0
	if special_left > 0: axis = 0.0
	if control_enabled and special_left <= 0:
		if Input.is_action_just_pressed("a_jump"): jump_buffer = move.jump_buffer_seconds
		if Input.is_action_just_released("a_jump") and velocity.y < 0: velocity.y *= move.jump_release_factor
		if Input.is_action_just_pressed("a_dash"): try_dash()
		if Input.is_action_just_pressed("a_attack"): try_melee()
		if Input.is_action_just_pressed("a_primary"): try_ability(actor.primary)
		if Input.is_action_just_pressed("a_special"):
			if practice: try_ability(actor.special,true)
			else: feedback.emit("locked")
	if special_left > 0: axis = 0.0
	if jump_buffer > 0:
		if is_on_wall() and not is_on_floor():
			velocity.x = get_wall_normal().x * move.wall_jump_x
			velocity.y = -move.wall_jump_y
			jump_buffer = 0
		elif coyote > 0 or air_jumps > 0:
			if coyote <= 0: air_jumps -= 1
			velocity.y = -move.jump_speed
			coyote = 0
			jump_buffer = 0
	if dash_left > 0:
		velocity = Vector2(facing * move.dash_speed, 0)
	elif hurt_left <= 0:
		var speed: float = move.speed * (0.65 if not combat_ready else 1.0)
		velocity.x = move_toward(velocity.x, axis * speed, (move.acceleration if axis else move.friction) * delta)
		velocity.y = minf(velocity.y + move.gravity * delta, move.max_fall_speed)
		if is_on_wall() and axis != 0 and velocity.y > 0: velocity.y = minf(velocity.y, move.wall_slide_speed)
	else:
		velocity.y += move.gravity * delta
	if absf(axis) > 0.1 and dash_left <= 0: facing = 1 if axis > 0 else -1
	var was_grounded = is_on_floor()
	move_and_slide()
	if not was_grounded and is_on_floor(): landing_left = 0.12
	if pending_melee and attack_left < combat.melee_seconds * 0.55:
		pending_melee = false
		melee_used.emit(global_position + Vector2(0, -42), facing, combat.combo_multipliers[combo])
	var animation = "idle"
	if hurt_left > 0: animation = "hurt"
	elif special_left > 0: animation = "special_cast"
	elif dash_left > 0: animation = "dash"
	elif attack_left > 0: animation = "cast" if cast else "attack"
	elif not is_on_floor(): animation = "jump" if velocity.y < 0 else "fall"
	elif absf(velocity.x) > 20: animation = "walk" if not combat_ready else "run"
	elif landing_left > 0 and sprite.sprite_frames.has_animation("land"): animation = "land"
	if sprite.animation != animation: sprite.play(animation)
	sprite.flip_h = facing < 0
	sprite.position.y = -Motion.canvas(actor.id).y/2
	sprite.modulate.a = 0.4 if invulnerable > 0 and int(clock * 18) % 2 == 0 else 1.0
	queue_redraw()

func try_dash() -> bool:
	if dash_cooldown > 0 or not control_enabled or special_left > 0: return false
	dash_left = db.config.movement.dash_seconds
	dash_cooldown = db.config.movement.dash_cooldown
	return true

func try_melee() -> bool:
	if attack_cooldown > 0 or hurt_left > 0 or not control_enabled or special_left > 0: return false
	combo = (combo + 1) % db.config.combat.combo_multipliers.size() if combo_left > 0 else 0
	combo_left = db.config.combat.combo_window
	attack_left = db.config.combat.melee_seconds
	attack_cooldown = db.config.combat.melee_cooldown
	cast = false
	pending_melee = true
	sprite.play("attack")
	sprite.set_frame_and_progress(0, 0)
	feedback.emit("attack")
	return true

func try_ability(id: String, charged: bool = false) -> bool:
	if not control_enabled or skill_cooldown > 0 or hurt_left > 0 or special_left > 0 or not db.skills.has(id): return false
	if not practice and (charged or id != actor.primary): return false
	var skill = db.skills[id]
	if energy < skill.cost:
		feedback.emit("empty")
		return false
	energy -= skill.cost
	skill_cooldown = skill.cooldown
	attack_left = db.config.combat.melee_seconds * 1.5
	cast = true
	pending_melee = false
	if charged or (id == actor.special and id != actor.primary):
		special_left = SPECIAL_SECONDS
		pending_special = id
		attack_left = SPECIAL_SECONDS
		skill_cooldown = SPECIAL_SECONDS + skill.cooldown
		dash_left = 0
		jump_buffer = 0
		velocity.x = 0
		sprite.play("special_cast")
	else:
		sprite.play("cast")
		var duration: float = 0
		for i in sprite.sprite_frames.get_frame_count("cast"):
			duration += sprite.sprite_frames.get_frame_duration("cast",i) / sprite.sprite_frames.get_animation_speed("cast")
		attack_left = maxf(attack_left,duration)
		ability_used.emit(id, global_position + Vector2(facing * 34, -45), facing)
	sprite.set_frame_and_progress(0, 0)
	feedback.emit("magic")
	health_changed.emit()
	return true

func take_damage(amount: float, from_x: float) -> bool:
	if hp <= 0 or invulnerable > 0 or (dash_left > 0 and db.config.movement.dash_invulnerability): return false
	cancel_special()
	hp = maxf(0, hp - amount)
	invulnerable = db.config.combat.hurt_invulnerability
	hurt_left = db.config.combat.hurt_seconds
	velocity = Vector2((1 if global_position.x >= from_x else -1) * db.config.combat.knockback_x, -db.config.combat.knockback_y)
	health_changed.emit()
	feedback.emit("hurt")
	if hp <= 0:
		control_enabled = false
		defeated.emit()
	return true

func _draw() -> void:
	if dash_left > 0:
		for i in range(4):
			draw_line(Vector2(-facing * (20 + i * 17), -25 - i * 12), Vector2(-facing * (75 + i * 20), -25 - i * 12), Color(actor.color, 0.4 - i * 0.08), 3)
	if attack_left > 0 and not cast:
		var progress = 1.0 - attack_left / db.config.combat.melee_seconds
		var start = -1.6 if facing > 0 else PI - 1.6
		draw_arc(Vector2(0, -40), db.config.combat.melee_range * 0.7, start + progress, start + 2.8 + progress, 18, Color(actor.color, 0.8), 5, false)
