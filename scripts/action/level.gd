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
var db
var definition: Dictionary
var player
var camera: Camera2D
var practice: bool = false
var foes: Array = []
var projectiles: Array = []
var collected: Dictionary = {}
var boss_alive: bool = true
var checkpoint_used: bool = false
var boss_intro: bool = false
var finished: bool = false
var background: Texture2D
var luna: Texture2D
var shake: float = 0
var clock: float = 0

func setup(database, mode: String, character_id: String, snapshot: Dictionary = {}) -> void:
	db = database
	practice = mode == "practice"
	definition = db.levels[db.config.initial_level]
	background = load(definition.background)
	if ResourceLoader.exists("res://assets/sprites/yoma_luna.png"):
		luna = Atlas.region({"sheet": "res://assets/sprites/yoma_luna.png", "columns": 4, "rows": 2, "row": 1, "y_start": 900, "cell_height": 280}, 0)
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
	player = Player.new()
	player.configure(db, character_id, practice)
	var spawn = snapshot.get("position", definition.spawn)
	player.position = Vector2(spawn[0], spawn[1])
	add_child(player)
	player.hp = snapshot.get("hp", player.actor.hp)
	player.energy = snapshot.get("energy", player.actor.energy)
	collected = snapshot.get("collected", {}).duplicate()
	checkpoint_used = snapshot.get("checkpoint", false)
	boss_alive = not snapshot.get("boss_defeated", false)
	player.ability_used.connect(_cast)
	player.melee_used.connect(_melee)
	player.defeated.connect(func(): player_defeated.emit())
	player.feedback.connect(func(kind):
		feedback.emit(kind)
		if kind == "hurt": shake = db.config.visual.screen_shake)
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
	if practice:
		for at in definition.practice_enemies: _spawn_enemy(Vector2(at[0], at[1]), false)
	if boss_alive: _spawn_enemy(Vector2(definition.boss_position[0], definition.boss_position[1]), true)

func _spawn_enemy(at: Vector2, boss: bool) -> void:
	var enemy = Enemy.new()
	enemy.configure(db, player, boss, practice and boss)
	enemy.position = at
	add_child(enemy)
	foes.append(enemy)
	enemy.fell.connect(func(value):
		if value.boss: boss_alive = false
		foes.erase(value)
		feedback.emit("victory"))
	enemy.hit.connect(func(): shake = db.config.visual.screen_shake * 0.6)
	enemy.shot.connect(_hostile)

func _physics_process(delta: float) -> void:
	if player == null: return
	player.combat_ready = false
	for enemy in foes:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.hp > 0:
			var offset = enemy.position - player.position
			if absf(offset.x) <= 440 and absf(offset.y) <= 160:
				player.combat_ready = true
				break
	clock += delta
	player.position.x = clampf(player.position.x, 24, definition.size[0] - 24)
	if player.position.y > definition.size[1] + 100:
		player.take_damage(player.actor.hp, player.position.x)
	camera.position = player.position + Vector2(player.facing * 120, -150)
	shake = move_toward(shake, 0, delta * 25)
	camera.offset = Vector2(sin(clock * 111), cos(clock * 83)) * shake
	for i in range(definition.pickups.size()):
		var point = Vector2(definition.pickups[i][0], definition.pickups[i][1])
		if not collected.has(str(i)) and player.position.distance_to(point + Vector2(0, 42)) < 58:
			collected[str(i)] = true
			player.energy = minf(player.actor.energy, player.energy + definition.pickup_energy)
			player.hp = minf(player.actor.hp, player.hp + definition.pickup_heal)
			feedback.emit("pickup")
	if not checkpoint_used and absf(player.position.x - definition.checkpoint[0]) < 75:
		checkpoint_used = true
		player.hp = player.actor.hp
		player.energy = player.actor.energy
		checkpoint_reached.emit(Vector2(definition.checkpoint[0], definition.checkpoint[1]))
	if not practice and not boss_intro and player.position.x > definition.boss_position[0] - 520 and boss_alive:
		boss_intro = true
		story_cue.emit("boss")
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
			if not projectile.hits.has(key) and projectile.collides(enemy.position + Vector2(0, -45), 24):
				projectile.hits[key] = true
				enemy.take_damage(projectile.skill.damage, projectile.skill.slow_seconds)
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

func _hostile(origin: Vector2, direction: int) -> void:
	if projectiles.size() >= db.config.combat.effect_budget: return
	var effect = Projectile.new()
	effect.setup({"effect": "orb", "color": "#e54b86", "speed": db.config.combat.boss_projectile_speed,
		"lifetime": 3.0, "radius": db.config.combat.projectile_radius, "damage": db.config.combat.enemy_damage}, origin, direction)
	effect.hostile = true
	add_child(effect)
	projectiles.append(effect)

func _melee(origin: Vector2, direction: int, multiplier: float) -> void:
	for enemy in foes.duplicate():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): continue
		var distance = enemy.position + Vector2(0, -40) - origin
		if absf(distance.y) < 80 and distance.x * direction >= -15 and absf(distance.x) < db.config.combat.melee_range:
			enemy.take_damage(db.config.combat.melee_damage * multiplier)

func snapshot(mode: String) -> Dictionary:
	return {"version": 1, "mode": mode, "character": player.actor.id, "position": [player.position.x, player.position.y], "hp": maxf(1, player.hp), "energy": player.energy,
		"collected": collected.duplicate(), "checkpoint": checkpoint_used, "boss_defeated": not boss_alive, "completed": finished}

func _draw() -> void:
	if definition.is_empty(): return
	for i in range(3): draw_texture_rect(background, Rect2(i * 1280, 0, 1280, 720), false)
	for i in range(1, definition.platforms.size()):
		var p = definition.platforms[i]
		var rect = Rect2(p[0], p[1], p[2], p[3])
		draw_rect(rect, Color("24203b"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), Color("9b799e"))
		for x in range(int(rect.position.x), int(rect.end.x), 24): draw_line(Vector2(x, rect.position.y + 5), Vector2(x, rect.end.y), Color("51415e"), 1)
	for i in range(definition.pickups.size()):
		if collected.has(str(i)): continue
		var at = Vector2(definition.pickups[i][0], definition.pickups[i][1] + sin(clock * 3 + i) * 5)
		draw_circle(at, 15, Color(1, 0.72, 0.87, 0.1))
		draw_colored_polygon(PackedVector2Array([at + Vector2(0,-9), at + Vector2(6,0), at + Vector2(0,9), at + Vector2(-6,0)]), Color("efbde3"))
	var point = Vector2(definition.checkpoint[0], definition.checkpoint[1] - 40)
	draw_arc(point, 28, clock, clock + 5.7, 30, Color("80e4de") if checkpoint_used else Color("ddbf8d"), 3)
	if luna != null:
		var at = Vector2(definition.luna_position[0], definition.luna_position[1])
		draw_texture_rect(luna, Rect2(at - Vector2(32, 51), Vector2(64, 56)), false)
	if not boss_alive:
		var at = Vector2(definition.exit_x, definition.ground_y - 64)
		draw_arc(at, 60, 0, TAU, 40, Color("ffc9e2"), 3)
