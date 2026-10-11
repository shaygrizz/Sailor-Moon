extends SceneTree
const Motion = preload("res://scripts/action/guardian_motion.gd")
const Catalog = preload("res://scripts/action/catalog.gd")
const Level = preload("res://scripts/action/level.gd")
const Controls = preload("res://scripts/action/controls.gd")
var failures = 0
var checks = 0
var releases: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(description)
func shot(name: String) -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func run() -> void:
	Controls.install()
	var db = Catalog.new()
	check(db.load_all(),"Catalog loads")
	var gallery = Node2D.new()
	root.add_child(gallery)
	for id in db.characters:
		for child in gallery.get_children(): child.free()
		var frames = Motion.frames(id)
		var index=0
		for name in ["idle","walk","run","jump","fall","dash","attack","cast","special_cast","hurt","land"]:
			check(frames.has_animation(name),id+" missing "+name)
			check(frames.get_frame_count(name)>0,id+" empty "+name)
			if name == "special_cast":
				var duration=0.0
				for i in frames.get_frame_count(name):duration+=frames.get_frame_duration(name,i)/frames.get_animation_speed(name)
				check(absf(duration-2.4)<0.001,id+" incorrect cast length")
			for i in frames.get_frame_count(name):
				var texture: AtlasTexture = frames.get_frame_texture(name,i)
				check(texture.region.size.x>0 and texture.region.size.y>0,id+" invalid crop")
				check(texture.margin.position.x>=0 and texture.margin.position.y>=0,id+" outside canvas "+name+str(i))
				if name not in ["idle","walk","run","special_cast"]:continue
				var bg=ColorRect.new()
				bg.color=Color("283750") if index%2 else Color("586278")
				bg.position=Vector2(index%10*128,index/10*144)
				bg.size=Vector2(127,143)
				gallery.add_child(bg)
				var sprite=Sprite2D.new()
				sprite.texture=texture
				sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.position=bg.position+Vector2(64,132-Motion.canvas(id).y/2)
				gallery.add_child(sprite)
				index+=1
		await shot("guardian-frames-"+id)
	gallery.free()
	var level=Level.new()
	root.add_child(level)
	level.setup(db,"practice","moon")
	await create_timer(1.0).timeout
	level.set_physics_process(false)
	for enemy in level.foes: enemy.set_physics_process(false)
	var p=level.player
	p.set_physics_process(false)
	p.ability_used.connect(func(id,_origin,_direction): releases.append(id))
	for id in db.characters:
		check(p.change_character(id),id+" switch failed")
		p.position=Vector2(220,610)
		p.velocity=Vector2.ZERO
		p.hurt_left=0;p.invulnerable=0;p.skill_cooldown=0;p.energy=p.actor.energy
		p.hp=p.max_hp;p.control_enabled=true
		p.facing=-1
		p._physics_process(1.0/60)
		check(p.sprite.flip_h,id+" did not face left")
		p.facing=1
		p.combat_ready=false
		Input.action_press("a_right")
		for i in 15:p._physics_process(1.0/60)
		check(p.sprite.animation=="run",id+" full-speed movement not run")
		p.combat_ready=true
		p._physics_process(1.0/60)
		check(p.sprite.animation=="run",id+" combat movement not run")
		Input.action_release("a_right")
		p.skill_cooldown=0
		var before=releases.size()
		check(p.try_ability(p.actor.primary),id+" primary failed")
		check(releases.size()==before+1,id+" primary no longer immediate")
		p.skill_cooldown=0;p.energy=p.actor.energy
		before=releases.size()
		check(p.try_ability(p.actor.special,true),id+" charged cast failed")
		check(not p.try_dash() and not p.try_melee(),id+" cast not protected")
		for i in 120:p._physics_process(1.0/60)
		check(releases.size()==before,id+" released before 2 seconds")
		for i in 30:p._physics_process(1.0/60)
		check(releases.size()==before+1 and releases.back()==p.actor.special,id+" wrong or duplicate release")
		p.skill_cooldown=0;p.energy=p.actor.energy
		p.try_ability(p.actor.special,true)
		p.take_damage(1,p.position.x-20)
		check(p.pending_special.is_empty(),id+" damage did not cancel")
		p.hurt_left=0;p.skill_cooldown=0;p.energy=p.actor.energy
		p.try_ability(p.actor.special,true)
		p.change_character("moon" if id!="moon" else "mercury")
		check(p.pending_special.is_empty() and p.special_left==0,id+" switch did not cancel")
		if id!="moon":check(Motion.effect(p.db.characters[id].special)!=null,id+" missing pixel effect")
	level.queue_free()
	await process_frame
	print("GUARDIAN MOTION: %d checks, %d failures" % [checks,failures])
	quit(failures)
