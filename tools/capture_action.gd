extends SceneTree
## Native renderer QA; run without --headless. Screenshots do not touch user saves.
func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")

func run() -> void:
	root.size = Vector2i(1280,720)
	var game = load("res://scenes/action/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.5).timeout
	game.saves.directory = "user://action_visual_tests"
	await shot("windows-title")
	game._action("roster", {})
	await create_timer(0.4).timeout
	await shot("windows-roster")
	for id in ["mercury", "mars", "jupiter", "venus", "saturn"]:
		game._action("inspect", {"id": id})
		await create_timer(0.3).timeout
		await shot("windows-dossier-" + id)
	game._action("back", {})
	game._start("practice", "moon")
	await create_timer(1.6).timeout
	await shot("windows-gameplay")
	game.level.player.position = Vector2(1150,580)
	game.level.player.try_ability("heart")
	await create_timer(0.25).timeout
	await shot("windows-heart-attack")
	game._action("settings", {})
	await create_timer(0.3).timeout
	await shot("windows-settings")
	game.queue_free()
	await create_timer(0.2).timeout
	quit()
