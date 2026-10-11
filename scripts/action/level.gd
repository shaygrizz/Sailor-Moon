extends Node2D
signal checkpoint_reached(position_value: Vector2)
signal completed
signal player_defeated
signal feedback(kind: String)
signal story_cue(id: String)
const Player = preload("res://scripts/action/player.gd")
const Enemy = preload("res://scripts/action/enemy.gd")
const Projectile = preload("res://scripts/action/projectile.gd")
const Atlas = preload("res://scripts/action/atlas.gd")
const Burst = preload("res://scripts/action/burst.gd")
var db
var definition: Dictionary
var player
var camera: Camera2D
var practice: bool = false
var foes: Array = []
var projectiles: Array = []
var collected: Dictionary = {}
var hazards: Array[Rect2] = []
var boss_alive: bool = true
var boss
var checkpoint_used: bool = false
var boss_intro: bool = false
var arena_locked: bool = false
var arena_wall: StaticBody2D
var finished: bool = false
var background: Texture2D
var luna: Texture2D
var shake: float = 0
var clock: float = 0
var hitstop_token: int = 0
var rest_hint: bool = false
var tips_shown: Dictionary = {}
var translator: Callable

func setup(database, mode: String, character_id: String, snapshot: Dictionary = {}) -> void:
	db = database
	practice = mode == "practice"
	definition = db.levels[db.config.initial_level]
	background = load(definition.background)
	if ResourceLoader.exists("res://assets/sprites/yoma_luna.png"):
		luna = Atlas.region({"sheet": "res://assets/sprites/yoma_luna.png", "columns": 4, "rows": 2, "row": 1, "y_start": 900, "cell_height": 280}, 0)
	_build_background()
	for rect in definition.platforms:
		var body = StaticBody2D.new()
		body.collision_layer = 1
		var collider = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(rect[2], rect[3])
		collider.shape = shape
		body.position = Vector2(rect[0] + rect[2] / 2, rect[1] + rect[3] / 2)
		body.add_child(collider)
		add_child(body)
	for rect in definition.get("hazards", []): hazards.append(Rect2(rect[0], rect[1], rect[2], rect[3]))
	player = Player.new()
	player.configure(db, character_id, practice)
	var spawn = snapshot.get("position", definition.spawn)
	player.position = Vector2(spawn[0], spawn[1])
	player.safe_position = player.position
	add_child(player)
	player.hp = clampf(snapshot.get("hp", player.max_hp), 1, player.max_hp)
	player.energy = clampf(snapshot.get("energy", player.actor.energy), 0, player.actor.energy)
	collected = snapshot.get("collected", {}).duplicate()
	checkpoint_used = snapshot.get("checkpoint", false)
	boss_alive = not snapshot.get("boss_defeated", false)
	player.ability_used.connect(_cast)
	player.melee_used.connect(_melee)
	player.defeated.connect(func():
		player.visible = false
		Burst.spawn(self, player.position + Vector2(0, -40), Color(player.actor.color), 26, 520, 0.8, Vector2.ZERO, 0, 90)
		player_defeated.emit())
	player.healed.connect(func(): Burst.spawn(self, player.position + Vector2(0, -40), Color("fff3a6"), 16, 260, 0.6, Vector2.UP, -200, 70))
	player.feedback.connect(func(kind):
		feedback.emit(kind)
		if kind == "hurt":
			shake = db.config.visual.screen_shake * 1.6
			hitstop(db.config.combat.hitstop_heavy)
		elif kind == "pogo": Burst.spawn(self, player.position + Vector2(0, 6), Color("fff6ef"), 8, 300, 0.25, Vector2.DOWN))
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = db.config.visual.camera_smoothing
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(definition.size[0])
	camera.limit_bottom = int(definition.size[1])
	camera.position = player.position + Vector2(150, -150)
	add_child(camera)
	camera.make_current()
	for entry in definition.get("practice_enemies" if practice else "enemies", []):
		_spawn_enemy(Vector2(entry.at[0], entry.at[1]), entry.kind)
	if boss_alive:
		boss = _spawn_enemy(Vector2(definition.boss_position[0], definition.boss_position[1]), "boss")
		boss.dormant = true
		boss.phase_changed.connect(func():
			shake = db.config.visual.screen_shake * 2.5
			Burst.spawn(self, boss.position + Vector2(0, -80), Color("ff8a3d"), 24, 480, 0.7, Vector2.ZERO, 0, 140)
			feedback.emit("phase"))

## Far city art scrolls slower than the street, so the level reads with depth.
func _build_background() -> void:
	var parallax = Parallax2D.new()
	parallax.scroll_scale = Vector2(0.45, 1)
	parallax.repeat_size = Vector2(2560, 0)
	parallax.repeat_times = 2
	parallax.z_index = -10
	# The art is not seamless, so every second copy is mirrored and the edges always match.
	for i in range(2):
		var art = Sprite2D.new()
		art.texture = background
		art.centered = false
		art.flip_h = i == 1
		art.position.x = i * 1280
		art.scale = Vector2(1280.0 / background.get_width(), 720.0 / background.get_height())
		parallax.add_child(art)
	add_child(parallax)

func _spawn_enemy(at: Vector2, kind: String):
	var enemy = Enemy.new()
	enemy.configure(db, player, kind, practice and kind == "boss")
	enemy.position = at
	add_child(enemy)
	foes.append(enemy)
	enemy.fell.connect(func(value):
		var tint = Color(value.stats.get("color", "#49336a")).lightened(0.4)
		Burst.spawn(self, value.position + Vector2(0, -value.size_value.y / 2), tint, 22 if not value.boss else 48, 460, 0.6, Vector2.ZERO, 500, 60 if not value.boss else 180)
		hitstop(db.config.combat.hitstop_heavy * (3 if value.boss else 1))
		if value.boss:
			boss_alive = false
			_unlock_arena()
		foes.erase(value)
		feedback.emit("victory" if value.boss else "kill"))
	enemy.hit.connect(func(): shake = maxf(shake, db.config.visual.screen_shake * 0.6))
	enemy.shot.connect(_hostile)
	enemy.slammed.connect(_slam)
	enemy.warned.connect(func(): feedback.emit("windup"))
	return enemy

func hitstop(seconds: float) -> void:
	if seconds <= 0 or not is_inside_tree(): return
	hitstop_token += 1
	Engine.time_scale = 0.05
	get_tree().create_timer(seconds, true, false, true).timeout.connect(_end_hitstop.bind(hitstop_token))

func _end_hitstop(token: int) -> void:
	if token == hitstop_token: Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _lock_arena() -> void:
	arena_locked = true
	var left = float(definition.arena[0])
	arena_wall = StaticBody2D.new()
	var collider = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 900)
	collider.shape = shape
	arena_wall.position = Vector2(left - 20, 300)
	arena_wall.add_child(collider)
	add_child(arena_wall)
	camera.limit_left = int(left - 30)
	if is_instance_valid(boss): boss.dormant = false
	shake = db.config.visual.screen_shake
	feedback.emit("arena")
	if not practice:
		boss_intro = true
		story_cue.emit("boss")

func _unlock_arena() -> void:
	if is_instance_valid(arena_wall): arena_wall.queue_free()
	camera.limit_left = 0

func _physics_process(delta: float) -> void:
	if player == null: return
	player.combat_ready = false
	for enemy in foes:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.hp > 0:
			var offset = enemy.position - player.position
			if absf(offset.x) <= 440 and absf(offset.y) <= 200:
				player.combat_ready = true
				break
	clock += delta
	player.position.x = clampf(player.position.x, 24, definition.size[0] - 24)
	var body = player.hurtbox()
	if player.position.y > definition.size[1] + 60: player.hazard_hit()
	else:
		for hazard in hazards:
			if body.intersects(hazard):
				player.hazard_hit()
				break
	var look = Vector2(player.facing * 120, -150)
	if Input.is_action_pressed("a_up") and player.is_on_floor() and absf(player.velocity.x) < 10: look.y -= 120
	elif Input.is_action_pressed("a_down") and player.is_on_floor() and absf(player.velocity.x) < 10: look.y += 120
	camera.position = player.position + look
	shake = move_toward(shake, 0, delta * 25)
	camera.offset = Vector2(sin(clock * 111), cos(clock * 83)) * shake
	for i in range(definition.pickups.size()):
		var point = Vector2(definition.pickups[i][0], definition.pickups[i][1])
		if not collected.has(str(i)) and player.position.distance_to(point + Vector2(0, 42)) < 58:
			collected[str(i)] = true
			player.energy = minf(player.actor.energy, player.energy + definition.pickup_energy)
			player.hp = minf(player.max_hp, player.hp + definition.pickup_heal)
			player.health_changed.emit()
			Burst.spawn(self, point, Color("efbde3"), 14, 300, 0.45, Vector2.ZERO, 0, 40)
			feedback.emit("pickup")
	var near_bench = absf(player.position.x - definition.checkpoint[0]) < 75 and absf(player.position.y - definition.checkpoint[1]) < 80
	rest_hint = near_bench and checkpoint_used
	if near_bench and (not checkpoint_used or (Input.is_action_just_pressed("a_up") and player.is_on_floor())):
		checkpoint_used = true
		player.hp = player.max_hp
		player.energy = player.actor.energy
		player.health_changed.emit()
		Burst.spawn(self, Vector2(definition.checkpoint[0], definition.checkpoint[1] - 40), Color("80e4de"), 20, 240, 0.8, Vector2.UP, -150, 80)
		checkpoint_reached.emit(Vector2(definition.checkpoint[0], definition.checkpoint[1]))
	for i in range(definition.get("tips", []).size()):
		var tip = definition.tips[i]
		if not tips_shown.has(i) and player.position.x > tip[0]:
			tips_shown[i] = true
			if not practice: feedback.emit("tip:" + tip[1])
	if boss_alive and not arena_locked and definition.has("arena") and player.position.x > definition.arena[0] + 80:
		_lock_arena()
	for projectile in projectiles.duplicate():
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			projectiles.erase(projectile)
			continue
		if projectile.hostile:
			if projectile.collides(player.position + Vector2(0, -40), 18):
				if player.take_damage(projectile.skill.damage, projectile.position.x): projectile.queue_free()
			continue
		for enemy in foes.duplicate():
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): continue
			var key = enemy.get_instance_id()
			if not projectile.hits.has(key) and projectile.collides(enemy.position + Vector2(0, -enemy.size_value.y / 2), maxf(24, enemy.size_value.x / 2)):
				projectile.hits[key] = true
				Burst.spawn(self, projectile.position, Color(projectile.skill.color), 8, 320, 0.3)
				enemy.take_damage(projectile.skill.damage, projectile.skill.slow_seconds, Vector2(projectile.direction, -0.2))
				if not projectile.skill.piercing:
					projectile.queue_free()
					break
	if not boss_alive and not finished and player.position.x > definition.exit_x:
		finished = true
		completed.emit()
	queue_redraw()

func _cast(id: String, origin: Vector2, direction: int) -> void:
	if projectiles.size() >= db.config.combat.effect_budget: return
	var effect = Projectile.new()
	effect.setup(db.skills[id], origin, direction)
	add_child(effect)
	projectiles.append(effect)
	feedback.emit("cast:" + id)

func _hostile(origin: Vector2, velocity_value: Vector2) -> void:
	_enemy_projectile({"effect": "orb", "color": "#e54b86", "speed": velocity_value.length(), "lifetime": 3.0,
		"radius": db.config.combat.projectile_radius, "damage": db.config.combat.enemy_damage}, origin, velocity_value)

## The boss landing sends two shockwaves along the floor: jump over them.
func _slam(origin: Vector2) -> void:
	shake = db.config.visual.screen_shake * 2
	Burst.spawn(self, origin, Color("c79bff"), 18, 420, 0.5, Vector2.UP, 600)
	for side in [-1, 1]:
		_enemy_projectile({"effect": "shockwave", "color": "#c79bff", "speed": boss.stats.shockwave_speed if is_instance_valid(boss) else 420,
			"lifetime": 2.2, "radius": 34, "damage": db.config.combat.enemy_damage}, origin, Vector2(side * (boss.stats.shockwave_speed if is_instance_valid(boss) else 420), 0))

func _enemy_projectile(definition_value: Dictionary, origin: Vector2, velocity_value: Vector2) -> void:
	if projectiles.size() >= db.config.combat.effect_budget: return
	var effect = Projectile.new()
	effect.setup(definition_value, origin, 1 if velocity_value.x >= 0 else -1)
	effect.velocity_value = velocity_value
	effect.hostile = true
	add_child(effect)
	projectiles.append(effect)

func melee_box(origin: Vector2, aim: Vector2) -> Rect2:
	var reach: float = db.config.combat.melee_range
	if aim.y < 0: return Rect2(origin.x - 48, origin.y - reach, 96, reach + 10)
	if aim.y > 0: return Rect2(origin.x - 42, origin.y, 84, reach)
	return Rect2(origin.x - 12 if aim.x > 0 else origin.x - reach + 12, origin.y - 42, reach, 84)

func _melee(origin: Vector2, aim: Vector2, multiplier: float) -> void:
	var box = melee_box(origin, aim)
	var struck = false
	for enemy in foes.duplicate():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): continue
		if box.intersects(enemy.hurtbox()):
			struck = true
			var knock = Vector2(aim.x, -0.25) if aim.y == 0 else aim
			var center = enemy.hurtbox().get_center()
			Burst.spawn(self, center.lerp(origin, 0.3), Color(player.actor.color).lightened(0.3), 10, 420, 0.3, Vector2(aim.x, aim.y))
			enemy.take_damage(db.config.combat.melee_damage * multiplier, 0, knock)
	if struck:
		hitstop(db.config.combat.hitstop * (1.6 if multiplier > 1.4 else 1.0))
		player.on_melee_hit(aim, true)
		feedback.emit("hit")
		return
	if aim.y > 0:
		for hazard in hazards:
			if box.intersects(hazard):
				Burst.spawn(self, Vector2(origin.x, hazard.position.y), Color("fff6ef"), 8, 300, 0.25, Vector2.UP)
				player.on_melee_hit(aim, false)
				feedback.emit("hit")
				return

func snapshot(mode: String) -> Dictionary:
	return {"version": 1, "mode": mode, "character": player.actor.id, "position": [player.position.x, player.position.y], "hp": maxf(1, player.hp), "energy": player.energy,
		"collected": collected.duplicate(), "checkpoint": checkpoint_used, "boss_defeated": not boss_alive, "completed": finished}

func _draw() -> void:
	if definition.is_empty(): return
	var ground_y: float = definition.ground_y
	for hazard in hazards:
		if hazard.end.y >= definition.size[1] - 1:
			draw_rect(Rect2(hazard.position.x, ground_y, hazard.size.x, definition.size[1] - ground_y), Color("07050d"))
			for i in range(6): draw_rect(Rect2(hazard.position.x, ground_y + i * 8, hazard.size.x, 8), Color(0.3, 0.12, 0.35, 0.18 - i * 0.03))
	for p in definition.platforms:
		var rect = Rect2(p[0], p[1], p[2], p[3])
		if rect.size.y >= 100:
			draw_rect(rect, Color("1b1629"))
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 12)), Color("5d4a70"))
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color("d9b6d3"))
			for row in range(4):
				var y = rect.position.y + 20 + row * 22
				var shift = 0 if row % 2 == 0 else 24
				draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("2a2240"), 2)
				for x in range(int(rect.position.x) + shift, int(rect.end.x), 48): draw_line(Vector2(x, y), Vector2(x, y + 22), Color("2a2240"), 2)
		else:
			draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), Color(0, 0, 0, 0.35))
			draw_rect(rect, Color("2b2442"))
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), Color("e6b8d6"))
			for x in range(int(rect.position.x) + 12, int(rect.end.x), 24): draw_line(Vector2(x, rect.position.y + 6), Vector2(x, rect.end.y), Color("51415e"), 1)
	for hazard in hazards:
		var count = int(hazard.size.x / 16)
		for i in range(count):
			var x = hazard.position.x + i * hazard.size.x / count
			var w = hazard.size.x / count
			var tip = Vector2(x + w / 2, hazard.position.y)
			draw_colored_polygon(PackedVector2Array([Vector2(x, hazard.end.y), tip, Vector2(x + w, hazard.end.y)]), Color("6e5a8a"))
			draw_line(tip, Vector2(x + w * 0.2, hazard.end.y), Color("d7c3ef"), 1)
	for i in range(definition.pickups.size()):
		if collected.has(str(i)): continue
		var at = Vector2(definition.pickups[i][0], definition.pickups[i][1] + sin(clock * 3 + i) * 5)
		draw_circle(at, 18, Color(1, 0.72, 0.87, 0.12 + 0.06 * sin(clock * 5)))
		draw_colored_polygon(PackedVector2Array([at + Vector2(0,-10), at + Vector2(7,0), at + Vector2(0,10), at + Vector2(-7,0)]), Color("efbde3"))
	var bench = Vector2(definition.checkpoint[0], definition.checkpoint[1] + 32)
	var lit = Color("80e4de") if checkpoint_used else Color("ddbf8d")
	draw_rect(Rect2(bench + Vector2(-46, -22), Vector2(92, 8)), Color("3d3150"))
	draw_rect(Rect2(bench + Vector2(-40, -14), Vector2(8, 14)), Color("3d3150"))
	draw_rect(Rect2(bench + Vector2(32, -14), Vector2(8, 14)), Color("3d3150"))
	draw_circle(bench + Vector2(0, -78), 26, Color(lit, 0.12 + 0.05 * sin(clock * 2)))
	draw_arc(bench + Vector2(0, -78), 18, 0.6, 5.0, 24, lit, 4)
	if rest_hint:
		var hint = translator.call("W — отдохнуть") if translator.is_valid() else "W — отдохнуть"
		draw_string(ThemeDB.fallback_font, bench + Vector2(-90, -118), hint, HORIZONTAL_ALIGNMENT_CENTER, 180, 16, Color("fff0da"))
	if luna != null:
		var at = Vector2(definition.luna_position[0], definition.luna_position[1])
		draw_texture_rect(luna, Rect2(at - Vector2(32, 51), Vector2(64, 56)), false)
	if arena_locked and boss_alive:
		var left = float(definition.arena[0])
		for i in range(6): draw_line(Vector2(left - 6 + i * 3, 0), Vector2(left - 6 + i * 3, ground_y), Color(1, 0.2, 0.4, 0.25 + 0.15 * sin(clock * 6 + i)), 2)
	if not boss_alive:
		var at = Vector2(definition.exit_x, ground_y - 64)
		draw_circle(at, 54, Color(1, 0.8, 0.9, 0.08 + 0.04 * sin(clock * 3)))
		draw_arc(at, 60, clock, clock + TAU * 0.85, 40, Color("ffc9e2"), 3)
