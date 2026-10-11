extends SceneTree
const Sheets = preload("res://scripts/action/snes_atlas.gd")
var failures: int = 0
var verified_pixels: int = 0
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	await create_timer(0.3).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func run() -> void:
	var gallery = Node2D.new()
	root.add_child(gallery)
	for id in ["moon","beryl","mercury","mars","jupiter","venus"]:
		for child in gallery.get_children(): child.free()
		var spec = Sheets.definition(id)
		var source = Image.load_from_file(spec.sheet)
		var index = 0
		for key in spec.frames:
			var frame = Sheets.frame(id,key)
			var visible = frame.atlas.get_image().get_region(Rect2i(frame.region))
			var count = 0
			var entry = spec.frames[key]
			for y in range(visible.get_height()):
				for x in range(visible.get_width()):
					var pixel = visible.get_pixel(x,y)
					if pixel.a == 0: continue
					count += 1
					verified_pixels += 1
					if pixel != source.get_pixel(entry.rect[0]+x,entry.rect[1]+y): failures += 1
			if count != entry.source_pixel_count:
				failures += 1
				printerr("Unexpected pixels: " + id + "/" + key)
			var bg = ColorRect.new()
			bg.color = Color("484c64") if index%2 else Color("22263b")
			bg.position = Vector2((index%8)*160,(index/8)*180)
			bg.size = Vector2(160,180)
			gallery.add_child(bg)
			var sprite = Sprite2D.new()
			sprite.texture = Sheets.frame(id,key)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = bg.position + Vector2(80,80)
			gallery.add_child(sprite)
			var label = Label.new()
			label.position = bg.position+Vector2(4,158)
			label.text = key
			gallery.add_child(label)
			index += 1
		await shot("snes-frames-"+id)
	gallery.queue_free()
	await process_frame
	var game = load("res://scenes/action/main.tscn").instantiate()
	game.settings_file = "user://snes_test_settings.json"
	root.add_child(game)
	game.saves.directory = "user://snes_tests"
	game._start("practice","moon")
	await create_timer(1.5).timeout
	game.level.player.position = Vector2(3110,610)
	await shot("snes-practice")
	var boss
	for enemy in game.level.foes:
		if enemy.boss: boss = enemy
	if boss == null or not boss.use_beryl: failures += 1
	for animation in ["idle","run","jump","attack","cast","hurt"]:
		game.level.process_mode = Node.PROCESS_MODE_DISABLED
		game.level.player.sprite.play(animation)
		boss.sprite.play("attack" if animation in ["cast","attack"] else "idle")
		await shot("snes-game-"+animation)
	game.queue_free()
	await create_timer(0.3).timeout
	print("SNES INTEGRATION: %d original foreground pixels verified, %d failures" % [verified_pixels, failures])
	quit(failures)
