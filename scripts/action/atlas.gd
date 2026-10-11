extends RefCounted
## Original RGBA sheets are preserved; AtlasTexture regions are sliced in-engine.
static var measured: Dictionary = {}
static var isolated: Dictionary = {}

static func region(actor: Dictionary, frame: int) -> AtlasTexture:
	var texture = load(actor.sheet)
	if actor.has("atlas_id"):
		if measured.is_empty():
			measured = JSON.parse_string(FileAccess.get_file_as_string("res://data/action/sprite_regions.json"))
		var definition: Dictionary = measured[actor.atlas_id]
		var rect: Array = definition.rects[frame]
		var canvas = Vector2(definition.canvas[0], definition.canvas[1])
		var result = AtlasTexture.new()
		result.atlas = texture
		result.region = Rect2(rect[0], rect[1], rect[2], rect[3])
		var exclusions: Array = definition.get("exclusions", [])[frame]
		if not exclusions.is_empty():
			var key = str(actor.atlas_id) + ":" + str(frame)
			if not isolated.has(key):
				# Runtime atlas isolation: preserve source PNG, hide neighbouring poses.
				var pixels = texture.get_image().get_region(Rect2i(rect[0],rect[1],rect[2],rect[3]))
				for span in exclusions:
					pixels.fill_rect(Rect2i(span[0],span[1],span[2],span[3]), Color.TRANSPARENT)
				isolated[key] = ImageTexture.create_from_image(pixels)
			result.atlas = isolated[key]
			result.region.position = Vector2.ZERO
		result.margin = Rect2(Vector2((canvas.x-rect[2])*0.5, canvas.y-rect[3]-4), canvas-Vector2(rect[2],rect[3]))
		result.filter_clip = true
		return result
	var cell = Vector2(texture.get_width() / float(actor.columns), texture.get_height() / float(actor.rows))
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	var start = Vector2(round(frame * cell.x), round(actor.row * cell.y))
	var end = Vector2(round((frame + 1) * cell.x), round((actor.row + 1) * cell.y))
	if actor.has("y_start"):
		start.y = actor.y_start
		end.y = actor.y_start + actor.cell_height
	atlas.region = Rect2(start, end - start)
	atlas.filter_clip = true
	return atlas

static func frames(actor: Dictionary, animations: Dictionary, visual: Dictionary) -> SpriteFrames:
	var result = SpriteFrames.new()
	result.remove_animation("default")
	for name in animations:
		result.add_animation(name)
		result.set_animation_loop(name, name in ["idle", "run"])
		result.set_animation_speed(name, visual.get(name + "_fps", visual.cast_fps))
		for index in animations[name]:
			result.add_frame(name, region(actor, int(index)))
	return result
