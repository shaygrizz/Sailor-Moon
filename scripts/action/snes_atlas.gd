extends RefCounted
## Exact supplied pixels, manual rectangles and pivots. No generated/interpolated art.
static var definitions: Dictionary = {}
static var textures: Dictionary = {}
static var animations_cache: Dictionary = {}
static var cropped: Dictionary = {}

static func definition(id: String) -> Dictionary:
	if definitions.is_empty():
		definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/action/snes_sprites.json"))
	return definitions[id]

static func texture(id: String) -> Texture2D:
	if not textures.has(id):
		var spec = definition(id)
		var original: Texture2D = load(spec.sheet)
		if spec.has("color_key"):
			var pixels = original.get_image()
			pixels.convert(Image.FORMAT_RGBA8)
			var key = Color(spec.color_key)
			for y in range(pixels.get_height()):
				for x in range(pixels.get_width()):
					var color = pixels.get_pixel(x,y)
					if color.r8 == key.r8 and color.g8 == key.g8 and color.b8 == key.b8:
						pixels.set_pixel(x,y,Color.TRANSPARENT)
			textures[id] = ImageTexture.create_from_image(pixels)
		else: textures[id] = original
	return textures[id]

static func frame(id: String, name: String) -> AtlasTexture:
	var spec = definition(id)
	var entry = spec.frames[name]
	var rect = entry.rect
	var pivot = entry.pivot
	var canvas = Vector2(spec.canvas[0], spec.canvas[1])
	var result = AtlasTexture.new()
	result.atlas = texture(id)
	result.region = Rect2(rect[0],rect[1],rect[2],rect[3])
	if not entry.get("exclusions",[]).is_empty():
		var key = id+":"+name
		if not cropped.has(key):
			var pixels = texture(id).get_image().get_region(Rect2i(rect[0],rect[1],rect[2],rect[3]))
			for span in entry.exclusions: pixels.fill_rect(Rect2i(span[0],span[1],span[2],span[3]),Color.TRANSPARENT)
			cropped[key] = ImageTexture.create_from_image(pixels)
		result.atlas = cropped[key]
		result.region.position = Vector2.ZERO
	result.margin = Rect2(Vector2(canvas.x/2-pivot[0],canvas.y-pivot[1]),canvas-Vector2(rect[2],rect[3]))
	result.filter_clip = true
	return result

static func frames(id: String) -> SpriteFrames:
	if animations_cache.has(id): return animations_cache[id]
	var spec = definition(id)
	var result = SpriteFrames.new()
	result.remove_animation("default")
	for name in spec.animations:
		var animation = spec.animations[name]
		result.add_animation(name)
		result.set_animation_loop(name, animation.get("loop",false))
		result.set_animation_speed(name, animation.fps)
		for key in animation.frames: result.add_frame(name,frame(id,key))
	if id == "moon": preload("res://scripts/action/moon_motion.gd").install(result)
	animations_cache[id] = result
	return result
