extends SceneTree
const Atlas = preload("res://scripts/action/atlas.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func shot(name: String) -> void:
	await create_timer(0.4).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")

func run() -> void:
	var game = load("res://scenes/action/main.tscn").instantiate()
	game.settings_file = "user://sprite_upgrade_test_settings.json"
	root.add_child(game)
	game.saves.directory = "user://sprite_upgrade_tests"
	check(game.ui.poster().resource_path == game.db.config.menu_art, "Every launch begins with ensemble poster")
	await shot("restored-start-screen")
	game._action("roster", {})
	game._action("inspect", {"id":"uranus"})
	check(not game.ui.personalized_poster, "Browsing does not confirm a choice")
	game._action("choose", {"id":"uranus"})
	check(game.ui.poster().resource_path.ends_with("guardians/uranus.png"), "Explicit selection activates personal poster")
	await shot("confirmed-guardian-screen")
	game._start("practice", "moon")
	await create_timer(1.0).timeout
	for id in game.db.characters:
		game.level.player.change_character(id)
		var frames = game.level.player.sprite.sprite_frames
		check(frames.get_frame_count("run") == 8, id + " has eight running poses")
		check(frames.get_frame_count("idle") == 4, id + " has four idle poses")
		check(frames.get_frame_count("jump") == 4, id + " has four jump poses")
		var expected_size = frames.get_frame_texture("idle",0).get_size()
		for animation in frames.get_animation_names():
			for index in range(frames.get_frame_count(animation)):
				var frame = frames.get_frame_texture(animation,index)
				check(frame.get_size() == expected_size, id + ": constant canvas for " + animation)
	game.level.player.change_character("moon")
	game.level.player.position = Vector2(1150,500)
	game.level.player.velocity = Vector2(0,-450)
	await shot("clean-moon-gameplay")
	game.queue_free()
	await create_timer(0.4).timeout
	var db = preload("res://scripts/action/catalog.gd").new()
	db.load_all()
	var gallery = Node2D.new()
	root.add_child(gallery)
	for id in db.characters:
		for child in gallery.get_children(): child.free()
		for frame in range(32):
			var tile = ColorRect.new()
			tile.color = Color("242638") if frame % 2 else Color("454659")
			tile.position = Vector2((frame%8)*160, (frame/8)*180)
			tile.size = Vector2(160,180)
			gallery.add_child(tile)
			var sprite = Sprite2D.new()
			sprite.texture = Atlas.region(db.characters[id],frame)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2.ONE * (145.0/sprite.texture.get_height())
			sprite.position = tile.position + Vector2(80,83)
			gallery.add_child(sprite)
			var label = Label.new()
			label.text = id + " / %02d" % frame
			label.position = tile.position + Vector2(12,157)
			gallery.add_child(label)
		await shot("sprite-frames-" + id)
	gallery.queue_free()
	await create_timer(0.3).timeout
	print("SPRITE UPGRADE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
