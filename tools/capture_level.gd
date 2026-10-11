extends SceneTree
## Story-level visual QA; run without --headless: godot --path . --script tools/capture_level.gd -- <output dir>
var out: String = "res://artifacts"

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))

func visit(game, x: float, y: float, name: String, wait: float = 0.6) -> void:
	game.level.player.position = Vector2(x, y)
	game.level.player.safe_position = Vector2(x, y)
	game.level.player.invulnerable = 100
	await create_timer(wait).timeout
	await shot(name)

func run() -> void:
	var args = OS.get_cmdline_user_args()
	if not args.is_empty(): out = args[0]
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/action/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	game.saves.directory = "user://action_visual_tests"
	game._start("story", "moon")
	await create_timer(1.2).timeout
	for i in range(3): game._action("next", {})
	await visit(game, 300, 580, "level-01-start")
	await visit(game, 1240, 580, "level-02-pit")
	await visit(game, 1900, 580, "level-03-lunger", 1.4)
	await visit(game, 2440, 580, "level-04-altar")
	await visit(game, 2700, 500, "level-05-wide-pit", 0.3)
	await visit(game, 3600, 400, "level-06-spikes", 0.3)
	await visit(game, 4000, 580, "level-07-wall")
	game.level.player.position = Vector2(4700, 580)
	await create_timer(0.4).timeout
	for i in range(2): game._action("next", {})
	await visit(game, 4700, 580, "level-08-arena", 2.0)
	await visit(game, 4900, 580, "level-09-boss-fight", 1.5)
	game.level.player.try_melee(Vector2.UP)
	await create_timer(0.08).timeout
	await shot("level-10-slash")
	game.queue_free()
	await create_timer(0.2).timeout
	quit()
