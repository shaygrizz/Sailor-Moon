extends SceneTree
const Sheets = preload("res://scripts/action/snes_atlas.gd")
var failures = 0
var releases = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		printerr(text)
func shot(name: String) -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func run() -> void:
	var gallery = Node2D.new()
	root.add_child(gallery)
	var frames = Sheets.frames("moon")
	for kind in ["special_cast","run"]:
		for child in gallery.get_children(): child.free()
		for i in frames.get_frame_count(kind):
			var bg = ColorRect.new()
			bg.color = Color("29384d")
			bg.position = Vector2(i%9*140,i/9*165)
			bg.size = Vector2(139,164)
			gallery.add_child(bg)
			var sprite = Sprite2D.new()
			sprite.texture = frames.get_frame_texture(kind,i)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = bg.position+Vector2(70,75)
			gallery.add_child(sprite)
		await shot("moon-"+kind+"-frames")
	gallery.free()
	var game = load("res://scenes/action/main.tscn").instantiate()
	game.settings_file = "user://moon_motion_test.json"
	root.add_child(game)
	game.saves.directory = "user://moon_motion_tests"
	game._start("practice","moon")
	await create_timer(1.2).timeout
	var player = game.level.player
	for enemy in game.level.foes: enemy.set_physics_process(false)
	player.ability_used.connect(func(_id,_origin,_direction): releases += 1)
	check(player.sprite.animation == "idle","Side idle not active")
	await shot("moon-side-idle")
	check(player.try_ability(player.actor.special),"Special rejected")
	check(releases==0,"Premature heart release")
	check(not player.try_dash() and not player.try_melee(),"Cast can be overwritten")
	await create_timer(1.2).timeout
	check(releases==0 and player.sprite.animation=="special_cast","Cast did not hold")
	await shot("moon-cast-middle")
	await create_timer(0.8).timeout
	check(releases==0,"Heart appeared before two seconds")
	await create_timer(0.5).timeout
	check(releases==1,"Heart must release exactly once")
	await shot("moon-heart-release")
	player.skill_cooldown=0
	player.energy=player.actor.energy
	player.try_ability(player.actor.special)
	player.invulnerable=0
	player.take_damage(1,player.position.x-30)
	check(player.pending_special.is_empty() and player.special_left==0,"Damage failed to cancel cast")
	await create_timer(2.5).timeout
	check(releases==1,"Cancelled cast released a ghost projectile")
	player.hurt_left=0
	player.position=Vector2(180,610)
	Input.action_press("a_right")
	await create_timer(0.15).timeout
	check(player.sprite.animation=="run","Full-speed movement should run")
	await shot("moon-run")
	player.position=game.level.foes[0].position-Vector2(220,0)
	await create_timer(0.15).timeout
	check(player.sprite.animation=="run","Enemy proximity should run")
	await shot("moon-combat-run")
	Input.action_release("a_right")
	game.queue_free()
	await process_frame
	print("MOON MOTION: %d failures" % failures)
	quit(failures)
