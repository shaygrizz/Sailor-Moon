extends SceneTree
var failures: int = 0
var checks: int = 0
var game
var russian = RegEx.new()

func _initialize() -> void:
	russian.compile("[А-Яа-яЁё]")
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func inspect(node: Node, language: String) -> void:
	if node is Label:
		if language != "ru": check(russian.search(node.text) == null, "Untranslated: " + node.text)
		if node.text != "":
			check(node.get_visible_line_count() >= node.get_line_count(), "Clipped: " + node.text + str(node.size))
	if node is Button and not node is OptionButton:
		if language != "ru": check(russian.search(node.text) == null, "Untranslated button: " + node.text)
		check(node.get_theme_font("font").get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, node.get_theme_font_size("font_size")).x <= node.size.x, "Button text too wide: " + node.text)
	for child in node.get_children(): inspect(child, language)

func shot(id: String) -> void:
	await create_timer(0.5).timeout
	inspect(game.ui.overlay if is_instance_valid(game.ui.overlay) else game.ui.page, game.ui.language)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/" + id + ".png")

func run() -> void:
	game = load("res://scenes/action/main.tscn").instantiate()
	game.settings_file = "user://presentation_test_settings.json"
	root.add_child(game)
	game.saves.directory = "user://presentation_tests"
	for language in ["ru","en","it"]:
		game.ui.language = language
		game.language = language
		game.selected = "uranus"
		game._show_title()
		await shot("title-" + language)
		for id in game.db.characters:
			game.ui.roster(id, true)
			await shot("dossier-" + id + "-" + language)
		game.ui.dialogue("Луна", game.db.story.intro[0].text)
		await shot("dialogue-" + language)
		for section in ["intro", "boss", "ending"]:
			for line in game.db.story[section]:
				game.ui.dialogue(line.speaker, line.text)
				await create_timer(0.25).timeout
				inspect(game.ui.overlay, language)
		game.ui.pause_menu()
		await shot("pause-" + language)
		game.ui.result(true, false)
		await shot("result-" + language)
		game.ui.settings(game.music, false)
		await shot("settings-" + language)
		game.ui.selected_character = "uranus"
		game.ui.loading(0.75)
		await shot("loading-" + language)
	game._action("language", {"id":"it"})
	game._action("choose", {"id":"neptune"})
	game.language = "ru"
	game.selected = "moon"
	game._load_settings()
	check(game.language == "it" and game.selected == "neptune", "Language and guardian persist")
	game.queue_free()
	await create_timer(0.4).timeout
	print("PRESENTATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
