extends CharacterBody2D
signal ability_used(id: String, origin: Vector2, direction: int)
signal melee_used(origin: Vector2, aim: Vector2, multiplier: float)
signal health_changed
signal defeated
signal healed
signal feedback(kind: String)
const Atlas = preload("res://scripts/action/atlas.gd")
const SnesAtlas = preload("res://scripts/action/snes_atlas.gd")
const Motion = preload("res://scripts/action/guardian_motion.gd")
var db
var actor: Dictionary
var sprite: AnimatedSprite2D
## Health is counted in whole hearts, like masks: every hit costs exactly one.
var hp: float
var max_hp: int
## Energy is earned by landing melee hits and spent on spells or on focusing to heal.
var energy: float
var facing: int = 1
var aim: Vector2 = Vector2.RIGHT
var control_enabled: bool = true
var practice: bool = false
var invulnerable: float = 0
var dash_left: float = 0
var dash_cooldown: float = 0
var attack_left: float = 0
var attack_cooldown: float = 0
var skill_cooldown: float = 0
var hurt_left: float = 0
var recoil_left: float = 0
var respawn_left: float = 0
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
var focus_left: float = 0.0
var ground_time: float = 0.0
var safe_position: Vector2
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
	max_hp = int(db.config.combat.masks)
	hp = max_hp
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
	var energy_ratio = energy / actor.energy
	cancel_special()
	actor = db.characters[id]
	energy = energy_ratio * actor.energy
	_set_art()
	health_changed.emit()
	return true

func hurtbox() -> Rect2:
	return Rect2(global_position + Vector2(-12, -70), Vector2(24, 70))

func busy() -> bool:
	return not control_enabled or special_left > 0 or hurt_left > 0 or respawn_left > 0

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
	for field in ["invulnerable", "dash_left", "dash_cooldown", "attack_left", "attack_cooldown", "skill_cooldown", "hurt_left", "recoil_left", "respawn_left", "coyote", "jump_buffer", "combo_left"]:
		set(field, maxf(0, get(field) - delta))
	if combo_left <= 0: combo = 0
	if practice: energy = minf(actor.energy, energy + combat.energy_regen * delta)
	if respawn_left > 0:
		velocity = Vector2.ZERO
		sprite.modulate.a = 1.0 - respawn_left / combat.hazard_respawn_seconds
		return
	if is_on_floor():
		coyote = move.coyote_seconds
		air_jumps = int(move.air_jumps)
		ground_time += delta
		if ground_time > 0.25 and hurt_left <= 0: safe_position = global_position
	else: ground_time = 0
	var axis = Input.get_axis("a_left", "a_right") if control_enabled else 0.0
	var vertical = Input.get_axis("a_up", "a_down") if control_enabled else 0.0
	if special_left > 0: axis = 0.0
	_update_focus(delta)
	if focus_left > 0: axis = 0.0
	if control_enabled and special_left <= 0 and focus_left <= 0:
		if Input.is_action_just_pressed("a_jump"): jump_buffer = move.jump_buffer_seconds
		if Input.is_action_just_released("a_jump") and velocity.y < 0: velocity.y *= move.jump_release_factor
		if Input.is_action_just_pressed("a_dash"): try_dash()
		if Input.is_action_just_pressed("a_attack"):
			var attack_aim = Vector2(facing, 0)
			if vertical < -0.5: attack_aim = Vector2.UP
			elif vertical > 0.5 and not is_on_floor(): attack_aim = Vector2.DOWN
			try_melee(attack_aim)
		if Input.is_action_just_pressed("a_primary"): try_ability(actor.primary)
		if Input.is_action_just_pressed("a_special"):
			if practice: try_ability(actor.special,true)
			else: feedback.emit("locked")
	if jump_buffer > 0:
		if is_on_wall() and not is_on_floor():
			velocity.x = get_wall_normal().x * move.wall_jump_x
			velocity.y = -move.wall_jump_y
			jump_buffer = 0
			feedback.emit("jump")
		elif coyote > 0 or air_jumps > 0:
			if coyote <= 0: air_jumps -= 1
			velocity.y = -move.jump_speed
			coyote = 0
			jump_buffer = 0
			feedback.emit("jump")
	if dash_left > 0:
		velocity = Vector2(facing * move.dash_speed, 0)
	elif hurt_left <= 0:
		var speed: float = move.speed
		if recoil_left <= 0:
			velocity.x = move_toward(velocity.x, axis * speed, (move.acceleration if axis else move.friction) * delta)
		velocity.y = minf(velocity.y + move.gravity * delta, move.max_fall_speed)
		if is_on_wall() and axis != 0 and velocity.y > 0: velocity.y = minf(velocity.y, move.wall_slide_speed)
	else:
		velocity.y += move.gravity * delta
	if absf(axis) > 0.1 and dash_left <= 0 and attack_left <= 0: facing = 1 if axis > 0 else -1
	var was_grounded = is_on_floor()
	move_and_slide()
	if not was_grounded and is_on_floor(): landing_left = 0.12
	if pending_melee and attack_left < combat.melee_seconds * 0.7:
		pending_melee = false
		melee_used.emit(global_position + Vector2(0, -40), aim, combat.combo_multipliers[combo])
	var animation = "idle"
	if hurt_left > 0: animation = "hurt"
	elif special_left > 0 or focus_left > 0: animation = "special_cast"
	elif dash_left > 0: animation = "dash"
	elif attack_left > 0: animation = "cast" if cast else "attack"
	elif not is_on_floor(): animation = "jump" if velocity.y < 0 else "fall"
	elif absf(velocity.x) > 20: animation = "run" if absf(velocity.x) > move.speed * 0.6 or combat_ready else "walk"
	elif landing_left > 0 and sprite.sprite_frames.has_animation("land"): animation = "land"
	if not sprite.sprite_frames.has_animation(animation): animation = "cast" if animation == "special_cast" else "run"
	if sprite.animation != animation: sprite.play(animation)
	sprite.flip_h = facing < 0
	sprite.position.y = -Motion.canvas(actor.id).y/2
	sprite.modulate = Color(1.0, 0.85 + 0.15 * sin(clock * 30), 1.0) if focus_left > 0 else Color.WHITE
	sprite.modulate.a = 0.4 if invulnerable > 0 and int(clock * 18) % 2 == 0 else 1.0
	queue_redraw()

## Hold focus on the ground to turn stored energy into one heart. Any hit interrupts it.
func _update_focus(delta: float) -> void:
	var combat = db.config.combat
	var wants = control_enabled and Input.is_action_pressed("a_focus") and (is_on_floor() or coyote > 0) and not busy() and attack_left <= 0 and dash_left <= 0
	if not wants or hp >= max_hp or energy < combat.focus_cost:
		if wants and focus_left <= 0 and Input.is_action_just_pressed("a_focus"): feedback.emit("empty" if energy < combat.focus_cost else "full")
		focus_left = 0
		return
	if focus_left <= 0: feedback.emit("focus")
	focus_left += delta
	velocity.x = 0
	if focus_left >= combat.focus_seconds:
		focus_left = 0
		energy -= combat.focus_cost
		hp = minf(max_hp, hp + 1)
		health_changed.emit()
		healed.emit()
		feedback.emit("heal")

func try_dash() -> bool:
	if dash_cooldown > 0 or busy(): return false
	dash_left = db.config.movement.dash_seconds
	dash_cooldown = db.config.movement.dash_cooldown
	focus_left = 0
	feedback.emit("dash")
	return true

func try_melee(attack_aim: Vector2 = Vector2.ZERO) -> bool:
	if attack_cooldown > 0 or busy(): return false
	aim = attack_aim if attack_aim != Vector2.ZERO else Vector2(facing, 0)
	combo = (combo + 1) % db.config.combat.combo_multipliers.size() if combo_left > 0 and aim.y == 0 else 0
	combo_left = db.config.combat.combo_window
	attack_left = db.config.combat.melee_seconds
	attack_cooldown = db.config.combat.melee_cooldown
	cast = false
	pending_melee = true
	focus_left = 0
	sprite.play("attack")
	sprite.set_frame_and_progress(0, 0)
	feedback.emit("attack")
	return true

## Called by the level when a slash connects. Down-slashes bounce (pogo), side slashes push back.
func on_melee_hit(hit_aim: Vector2, struck_enemy: bool) -> void:
	var combat = db.config.combat
	if struck_enemy: energy = minf(actor.energy, energy + combat.energy_on_hit)
	if hit_aim.y > 0:
		velocity.y = -combat.pogo_speed
		air_jumps = int(db.config.movement.air_jumps)
		dash_cooldown = 0
		feedback.emit("pogo")
	elif hit_aim.y == 0 and hurt_left <= 0:
		velocity.x = -hit_aim.x * combat.recoil_x
		recoil_left = combat.recoil_seconds
	health_changed.emit()

func try_ability(id: String, charged: bool = false) -> bool:
	if not control_enabled or skill_cooldown > 0 or hurt_left > 0 or special_left > 0 or respawn_left > 0 or not db.skills.has(id): return false
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
	focus_left = 0
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
	if hp <= 0 or invulnerable > 0 or respawn_left > 0 or (dash_left > 0 and db.config.movement.dash_invulnerability): return false
	cancel_special()
	focus_left = 0
	ground_time = 0
	hp = maxf(0, hp - clampf(roundf(amount), 1, 2))
	invulnerable = db.config.combat.hurt_invulnerability
	hurt_left = db.config.combat.hurt_seconds
	velocity = Vector2((1 if global_position.x >= from_x else -1) * db.config.combat.knockback_x, -db.config.combat.knockback_y)
	health_changed.emit()
	feedback.emit("hurt")
	if hp <= 0:
		control_enabled = false
		defeated.emit()
	return true

## Spikes and pits always cost a heart and return the guardian to the last safe ground.
func hazard_hit() -> bool:
	if hp <= 0 or respawn_left > 0: return false
	cancel_special()
	focus_left = 0
	hp = maxf(0, hp - db.config.combat.hazard_damage)
	health_changed.emit()
	feedback.emit("hurt")
	if hp <= 0:
		control_enabled = false
		defeated.emit()
		return true
	global_position = safe_position
	velocity = Vector2.ZERO
	respawn_left = db.config.combat.hazard_respawn_seconds
	invulnerable = db.config.combat.hurt_invulnerability
	return true

func _draw() -> void:
	if dash_left > 0:
		for i in range(4):
			draw_line(Vector2(-facing * (20 + i * 17), -25 - i * 12), Vector2(-facing * (75 + i * 20), -25 - i * 12), Color(actor.color, 0.4 - i * 0.08), 3)
	if attack_left > 0 and not cast:
		var progress = 1.0 - attack_left / db.config.combat.melee_seconds
		var reach = db.config.combat.melee_range * 0.62
		var center = Vector2(0, -40)
		var base = aim.angle()
		var sweep = -1.3 + progress * 2.6
		var color = Color(actor.color, 0.9 * (1.0 - progress * 0.6))
		draw_arc(center, reach, base - 1.25, base + sweep, 20, color, 7, true)
		draw_arc(center, reach - 9, base - 1.0, base + sweep * 0.9, 20, Color(1, 1, 1, 0.75 * (1.0 - progress)), 3, true)
	if focus_left > 0:
		var ratio = focus_left / db.config.combat.focus_seconds
		draw_arc(Vector2(0, -40), 44, -PI / 2, -PI / 2 + TAU * ratio, 32, Color("fff3a6"), 3, true)
		for i in range(5):
			var angle = clock * 3 + i * TAU / 5
			draw_circle(Vector2(cos(angle) * 30, -40 + sin(angle) * 30 - ratio * 12), 2.5, Color(1, 0.95, 0.7, ratio))
