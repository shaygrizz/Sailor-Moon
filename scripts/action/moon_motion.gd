extends RefCounted
## Import generated art onto the native SNES pixel grid; never filter sprite edges.
static var run_frames: Array[Texture2D] = []
static var heart_texture: Texture2D

static func hard_alpha(pixels: Image) -> void:
	for y in pixels.get_height():
		for x in pixels.get_width():
			var c = pixels.get_pixel(x,y)
			c.a = 1.0 if c.a >= 0.5 else 0.0
			pixels.set_pixel(x,y,c)

static func install(frames: SpriteFrames) -> void:
	if run_frames.is_empty():
		var source: Texture2D = load("res://assets/sprites/snes/moon_run.png")
		var original = source.get_image()
		for i in 8:
			var pixels = original.get_region(Rect2i((i%4)*384,50+(i/4)*484,384,450))
			pixels.convert(Image.FORMAT_RGBA8)
			pixels.resize(106,124,Image.INTERPOLATE_NEAREST)
			hard_alpha(pixels)
			var atlas = AtlasTexture.new()
			atlas.atlas = ImageTexture.create_from_image(pixels)
			atlas.region = Rect2(0,0,106,124)
			# Torso is at x=255, ground at y=460 in the first source cell.
			atlas.margin = Rect2(10,31,54,20)
			atlas.filter_clip = true
			run_frames.append(atlas)
	frames.clear("run")
	frames.set_animation_speed("run",12)
	for frame in run_frames: frames.add_frame("run",frame)

static func heart() -> Texture2D:
	if heart_texture == null:
		var source: Texture2D = load("res://assets/sprites/snes/moon_heart.png")
		var pixels = source.get_image()
		pixels.convert(Image.FORMAT_RGBA8)
		hard_alpha(pixels)
		pixels = pixels.get_region(pixels.get_used_rect())
		pixels.resize(24,24,Image.INTERPOLATE_NEAREST)
		heart_texture = ImageTexture.create_from_image(pixels)
	return heart_texture
