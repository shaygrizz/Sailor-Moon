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
	check(not level.player.take_damage(10,0), "Dash invulnerability")
	check(level.player.hp == hp_before, "Blocked damage preserves HP")
	await frames(60)
	level.player.invulnerable = 0
	check(level.player.take_damage(10,0), "Normal damage works")
	check(not level.player.take_damage(10,0), "Hurt invulnerability prevents repeated damage")
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
