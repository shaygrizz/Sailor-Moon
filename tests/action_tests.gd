extends SceneTree
const Catalog = preload("res://scripts/action/catalog.gd")
const Controls = preload("res://scripts/action/controls.gd")
const Level = preload("res://scripts/action/level.gd")
const Save = preload("res://scripts/action/native_save.gd")
const Music = preload("res://scripts/action/music_director.gd")
var checks = 0
var failures = 0
var db = Catalog.new()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + description)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func hollow_systems(level) -> void:
	var player = level.player
	player.change_character("moon")
	check(player.max_hp == int(db.config.combat.masks), "Health is counted in hearts")
	player.hp = player.max_hp
	player.invulnerable = 0
	player.dash_left = 0
	player.take_damage(1, 0)
	check(player.hp == player.max_hp - 1, "A normal hit costs exactly one heart")
	player.invulnerable = 0
	player.take_damage(14, 0)
	check(player.hp == player.max_hp - 3, "Even a huge hit costs at most two hearts")
	player.hp = player.max_hp - 1
	player.invulnerable = 100
	await frames(40)
	player.energy = player.actor.energy
	Input.action_press("a_focus")
	await frames(int(db.config.combat.focus_seconds * 60) + 12)
	Input.action_release("a_focus")
	check(player.hp == player.max_hp, "Holding focus heals one heart")
	check(player.energy < player.actor.energy - db.config.combat.focus_cost * 0.5, "Focus spends energy")
	player.energy = 0
	player.velocity = Vector2.ZERO
	player.on_melee_hit(Vector2.DOWN, true)
	check(player.velocity.y <= -db.config.combat.pogo_speed + 1, "Down-slash hit bounces upward (pogo)")
	check(player.energy == db.config.combat.energy_on_hit, "Hits charge energy")
	var origin = player.position + Vector2(0, -40)
	var below = level._spawn_enemy(player.position + Vector2(0, 70), "crawler")
	below.dormant = true
	var above = level._spawn_enemy(player.position + Vector2(0, -110), "crawler")
	above.dormant = true
	await frames(1)
	var hp_below = below.hp
	var hp_above = above.hp
	level._melee(player.position + Vector2(0, -40), Vector2.DOWN, 1.0)
	check(below.hp < hp_below and above.hp == hp_above, "Down-slash hits only below")
	level._melee(player.position + Vector2(0, -40), Vector2.UP, 1.0)
	check(above.hp < hp_above, "Up-slash hits above")
	check(level.melee_box(origin, Vector2(-1, 0)).end.x <= origin.x + 13, "Side slash faces its direction")
	for foe in [below, above]:
		level.foes.erase(foe)
		foe.queue_free()
	await frames(20)
	Engine.time_scale = 1.0
	player.hp = player.max_hp
	player.invulnerable = 0
	player.safe_position = Vector2(200, 580)
	var pit = level.hazards[0]
	player.position = pit.get_center()
	await frames(2)
	check(player.hp == player.max_hp - 1, "Spikes cost one heart")
	check(player.position.distance_to(Vector2(200, 580)) < 40, "Spikes return the guardian to safe ground")
	await frames(40)
	player.invulnerable = 100
	var soldier = level._spawn_enemy(player.position + Vector2(160, 0), "lunger")
	var warned = [false]
	soldier.warned.connect(func(): warned[0] = true)
	for i in range(90):
		await physics_frame
		if soldier.state == "attack": break
	check(warned[0] and soldier.state == "attack", "Lunger winds up before it charges")
	level.foes.erase(soldier)
	soldier.queue_free()
	check(level.boss != null and level.boss.dormant, "Boss waits until the arena closes")
	player.position = Vector2(level.definition.arena[0] + 140, 560)
	await frames(3)
	check(level.arena_locked and not level.boss.dormant, "Arena closes and the boss awakens")
	var boss_hp = level.boss.hp
	level.boss.take_damage(level.boss.max_hp * 0.6)
	check(level.boss.phase == 2 and level.boss.hp < boss_hp, "Boss enters its second phase")
	player.position = Vector2(300, 560)
	player.invulnerable = 0
	player.hp = player.max_hp
	await frames(20)
	Engine.time_scale = 1.0

## Real inputs: a running jump clears the first pit, a double jump clears the stone pillar.
func traversal(level) -> void:
	var player = level.player
	for foe in level.foes: foe.dormant = true
	player.hp = player.max_hp
	player.invulnerable = 0
	player.velocity = Vector2.ZERO
	player.position = Vector2(1180, 600)
	await frames(30)
	var hearts = player.hp
	Input.action_press("a_right")
	for i in range(120):
		await physics_frame
		if player.position.x > 1285: break
	Input.action_press("a_jump")
	await frames(24)
	Input.action_release("a_jump")
	await frames(40)
	Input.action_release("a_right")
	await frames(20)
	check(player.position.x > 1460 and player.hp == hearts and player.is_on_floor(), "Running jump clears the first pit")
	player.position = Vector2(4030, 600)
	await frames(30)
	Input.action_press("a_jump")
	await frames(16)
	Input.action_release("a_jump")
	await frames(2)
	Input.action_press("a_jump")
	await frames(6)
	Input.action_press("a_right")
	await frames(20)
	Input.action_release("a_jump")
	await frames(50)
	Input.action_release("a_right")
	check(player.position.x > 4150 and player.hp == hearts, "Double jump clears the stone pillar")
	for foe in level.foes: foe.dormant = false
	player.position = Vector2(300, 560)

func run() -> void:
	Controls.install()
	check(db.load_all(), "Action catalogs validate")
	check(db.characters.size() == 10, "Ten canonical guardians")
	var level = Level.new()
	root.add_child(level)
	level.setup(db, "practice", "moon")
	await frames(40)
	check(level.player.is_on_floor(), "Player lands on ground")
	var origin = level.player.position
	Input.action_press("a_right")
	await frames(20)
	Input.action_release("a_right")
	check(level.player.position.x > origin.x + 50, "Move right with acceleration")
	Input.action_press("a_jump")
	await frames(5)
	Input.action_release("a_jump")
	check(level.player.velocity.y < 0, "Jump rises")
	await frames(10)
	Input.action_press("a_jump")
	await frames(3)
	Input.action_release("a_jump")
	check(level.player.air_jumps == 0, "Air jump consumed")
	check(level.player.try_dash(), "Dash available")
	check(not level.player.try_dash(), "Dash cooldown enforced")
	var hp_before = level.player.hp
	check(not level.player.take_damage(1,0), "Dash invulnerability")
	check(level.player.hp == hp_before, "Blocked damage preserves HP")
	await frames(60)
	level.player.invulnerable = 0
	check(level.player.take_damage(1,0), "Normal damage works")
	check(not level.player.take_damage(1,0), "Hurt invulnerability prevents repeated damage")
	await frames(20)
	level.player.energy = 0
	check(not level.player.try_ability("tiara"), "Insufficient energy rejects spell")
	level.player.energy = 100
	level.player.skill_cooldown = 0
	level.player.hurt_left = 0
	check(level.player.try_ability("tiara"), "Tiara casts")
	check(level.projectiles.size() > 0, "Spell creates projectile")
	check(not level.player.try_ability("tiara"), "Spell cooldown enforced")
	for id in db.characters:
		check(level.player.change_character(id), "Character switch: " + id)
		for animation in ["idle","run","jump","fall","attack","cast","hurt","dash"]:
			check(level.player.sprite.sprite_frames.has_animation(animation), id + ": " + animation)
		level.player.skill_cooldown = 0
		level.player.energy = 100
		check(level.player.try_ability(db.characters[id].special), "Special available: " + id)
	var enemy = level.foes[0]
	var old_hp = enemy.hp
	enemy.take_damage(10, 2)
	check(enemy.hp == old_hp - 10 and enemy.slow_left == 2, "Damage and slow applied")
	await hollow_systems(level)
	await traversal(level)
	level.player.practice = false
	level.player.actor = db.characters.moon
	level.player.skill_cooldown = 0
	check(not level.player.change_character("saturn"), "Story locks later characters")
	check(not level.player.try_ability("heart"), "Story locks later abilities")
	level.player.practice = true
	var saves = Save.new(db)
	saves.directory = "user://action_tests"
	var snapshot = level.snapshot("practice")
	check(saves.save_game(snapshot), "Save succeeds")
	check(saves.load_game().character == "moon", "Save round trip")
	var bad = snapshot.duplicate(true)
	bad.hp = -4
	check(not saves.valid(bad), "Negative HP rejected")
	bad = snapshot.duplicate(true)
	bad.mode = "story"
	bad.character = "saturn"
	check(not saves.valid(bad), "Save cannot unlock later story guardian")
	var music = Music.new()
	root.add_child(music)
	music.configure(db.audio)
	check(music.resolve_stream(db.audio.tracks.menu) != null, "Packaged audio fallback")
	var external_entry = {"external":"assets/audio/music/battle.wav", "loop":true}
	check(music.resolve_stream(external_entry) != null, "External WAV loads without import")
	level.queue_free()
	music.queue_free()
	await frames(3)
	var game = load("res://scenes/action/main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	game.saves.directory = "user://action_integration_tests"
	check(game.mode == "title", "Native main menu starts")
	game._start("story","moon")
	for i in range(180):
		await physics_frame
		if game.mode == "story": break
	check(game.mode == "story" and game.dialog_id == "intro", "Story begins with intro")
	for i in range(3): game._action("next", {})
	check(game.overlay_kind == "", "Dialogue resumes play")
	game._action("roster", {})
	check(game.level.process_mode == Node.PROCESS_MODE_DISABLED, "Roster pauses combat")
	game._action("back", {})
	check(game.level.process_mode == Node.PROCESS_MODE_INHERIT, "Closing roster resumes combat")
	game.level.player.invulnerable = 0
	game.level.player.dash_left = 0
	game.level.player.hp = 1
	var fallen_level = game.level
	check(game.level.player.take_damage(1, 0), "Final heart can be lost")
	await create_timer(1.6).timeout
	for i in range(240):
		await physics_frame
		if game.mode == "story" and game.level != fallen_level: break
	check(game.level != fallen_level and game.overlay_kind == "", "Defeat respawns at the altar without a menu")
	check(game.level.player.hp == db.config.combat.masks, "Respawn restores every heart")
	game.level.boss_alive = false
	game.level.player.position.x = game.level.definition.exit_x + 10
	await frames(3)
	check(game.dialog_id == "ending", "Boss victory reaches canonical ending")
	game._action("next", {})
	game._action("next", {})
	check(game.overlay_kind == "result", "Ending reaches results screen")
	check(game.saves.load_game().completed, "Completion persists")
	game.queue_free()
	await frames(10)
	await create_timer(0.3).timeout
	print("ACTION TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
