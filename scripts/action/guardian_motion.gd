extends RefCounted
## Shared native-size animation interface for the full playable roster.
const Snes = preload("res://scripts/action/snes_atlas.gd")
const Pixel = preload("res://scripts/action/moon_motion.gd")
const INNER = ["moon","mercury","mars","jupiter","venus"]
static var specs: Dictionary = {}
static var cache: Dictionary = {}
static var images: Dictionary = {}
static var effects: Dictionary = {}

static func canvas(id: String) -> Vector2:
	return Vector2(160,144) if id == "moon" else Vector2(200,200)

static func definitions() -> Dictionary:
	if specs.is_empty(): specs = JSON.parse_string(FileAccess.get_file_as_string("res://data/action/guardian_motion.json"))
	return specs

static func generated_frame(id: String, index: int) -> AtlasTexture:
	var spec: Dictionary = definitions()[id]
	if not images.has(id):
		var source: Texture2D = load(spec.sheet)
		images[id] = source.get_image()
	var entry: Dictionary = spec.frames[index]
	var r = entry.rect
	var pixels: Image = images[id].get_region(Rect2i(r[0],r[1],r[2],r[3]))
	pixels.convert(Image.FORMAT_RGBA8)
	for span in entry.get("exclusions",[]): pixels.fill_rect(Rect2i(span[0],span[1],span[2],span[3]),Color.TRANSPARENT)
	var factor: float = spec.scale
	pixels.resize(maxi(1,roundi(r[2]*factor)),maxi(1,roundi(r[3]*factor)),Image.INTERPOLATE_NEAREST)
	Pixel.hard_alpha(pixels)
	var pivot = Vector2(entry.pivot[0],entry.pivot[1])*factor
	var result = AtlasTexture.new()
	result.atlas = ImageTexture.create_from_image(pixels)
	result.region = Rect2(Vector2.ZERO,pixels.get_size())
	result.margin = Rect2((Vector2(100,200)-pivot).round(),Vector2(200,200)-Vector2(pixels.get_size()))
	result.filter_clip = true
	return result

static func frames(id: String) -> SpriteFrames:
	if id == "moon": return Snes.frames("moon")
	if cache.has(id): return cache[id]
	var result: SpriteFrames
	var spec: Dictionary = definitions()[id]
	if id in INNER: result = Snes.frames(id).duplicate()
	else:
		result = SpriteFrames.new()
		result.remove_animation("default")
	var textures: Array[Texture2D] = []
	for i in spec.frames.size(): textures.append(generated_frame(id,i))
	for name in spec.animations:
		var animation: Dictionary = spec.animations[name]
		if result.has_animation(name): result.clear(name)
		else: result.add_animation(name)
		result.set_animation_loop(name,name in ["idle","walk","run"])
		result.set_animation_speed(name,animation.fps)
		for i in animation.frames.size():
			result.add_frame(name,textures[int(animation.frames[i])],animation.get("durations",[])[i] if animation.has("durations") else 1.0)
	cache[id] = result
	return result

static func effect(id: String) -> Texture2D:
	if not definitions().get("effects",{}).has(id): return null
	if not effects.has(id):
		var spec: Dictionary = definitions().effects[id]
		var source: Texture2D = load("res://assets/sprites/snes/guardian_effects.png")
		var r = spec.rect
		var pixels = source.get_image().get_region(Rect2i(r[0],r[1],r[2],r[3]))
		pixels.convert(Image.FORMAT_RGBA8)
		for span in spec.get("exclusions",[]): pixels.fill_rect(Rect2i(span[0],span[1],span[2],span[3]),Color.TRANSPARENT)
		pixels.resize(spec.size[0],spec.size[1],Image.INTERPOLATE_NEAREST)
		Pixel.hard_alpha(pixels)
		effects[id] = ImageTexture.create_from_image(pixels)
	return effects[id]
