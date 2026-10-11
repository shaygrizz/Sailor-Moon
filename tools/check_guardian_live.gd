extends SceneTree
var failures=0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/action/main.tscn").instantiate()
	game.settings_file="user://guardian_live_test.json"
	root.add_child(game)
	game.saves.directory="user://guardian_live_tests"
	game._start("practice","mercury")
	await create_timer(1.2).timeout
	for enemy in game.level.foes:enemy.set_physics_process(false)
	var p=game.level.player
	for id in game.db.characters:
		if id=="moon":continue
		game._action("choose",{"id":id})
		p.position=Vector2(180,610)
		p.velocity=Vector2.ZERO
		p.facing=1;p.energy=p.actor.energy;p.skill_cooldown=0;p.invulnerable=0;p.hurt_left=0
		p.try_ability(p.actor.special,true)
		await create_timer(2.16).timeout
		if p.sprite.animation!="special_cast" or p.sprite.frame<5:
			failures+=1;printerr(id+" live animation did not reach release")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/guardian-live-"+id+".png")
		await create_timer(0.3).timeout
	game.queue_free()
	await process_frame
	print("GUARDIAN LIVE CASTS: %d failures"%failures)
	quit(failures)
