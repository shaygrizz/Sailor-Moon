extends Node
## External Music/audio.json overrides packaged paths. WAV/OGG/MP3 load without re-export.
var catalog: Dictionary
var config_path: String
var base_directory: String
var players: Array[AudioStreamPlayer] = []
var sfx_players: Array[AudioStreamPlayer] = []
var front: int = 0
var current: String = ""
var enabled: bool = true
var music_volume: float = 0.75
var master_volume: float = 0.65
var sfx_volume: float = 0.6
var crossfade: Tween

func configure(defaults: Dictionary, override_directory: String = "") -> void:
	base_directory = override_directory if override_directory != "" else (ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir())
	catalog = defaults.duplicate(true)
	config_path = base_directory.path_join("Music/audio.json")
	if FileAccess.file_exists(config_path):
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(config_path)) == OK and parser.data is Dictionary:
			for key in ["tracks", "sfx"]:
				if parser.data.get(key) is Dictionary: catalog[key].merge(parser.data[key], true)
	for i in range(2):
		var player = AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	for i in range(10):
		var player = AudioStreamPlayer.new()
		add_child(player)
		sfx_players.append(player)
	master_volume = catalog.master_volume
	music_volume = catalog.music_volume
	sfx_volume = catalog.sfx_volume

func resolve_stream(entry: Dictionary) -> AudioStream:
	var external = str(entry.get("external", ""))
	var external_path = base_directory.path_join(external)
	if external != "" and FileAccess.file_exists(external_path):
		var stream: AudioStream
		match external_path.get_extension().to_lower():
			"ogg": stream = AudioStreamOggVorbis.load_from_file(external_path)
			"wav": stream = AudioStreamWAV.load_from_file(external_path)
			"mp3": stream = AudioStreamMP3.load_from_file(external_path)
		if stream != null: return _loop(stream, entry.get("loop", false))
	var packaged = str(entry.get("path", ""))
	if ResourceLoader.exists(packaged):
		return _loop(load(packaged).duplicate(), entry.get("loop", false))
	return null

func _loop(stream: AudioStream, should_loop: bool) -> AudioStream:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = should_loop
	return stream

func play_music(id: String) -> void:
	if current == id or not catalog.tracks.has(id): return
	current = id
	if crossfade != null and crossfade.is_running(): crossfade.kill()
	var previous = players[front]
	front = 1 - front
	var next = players[front]
	next.stream = resolve_stream(catalog.tracks[id])
	if next.stream == null: return
	next.volume_db = -70
	next.play()
	crossfade = create_tween().set_parallel(true)
	crossfade.tween_property(previous, "volume_db", -70.0, catalog.crossfade_seconds)
	crossfade.tween_property(next, "volume_db", _music_db(), catalog.crossfade_seconds)
	crossfade.chain().tween_callback(previous.stop)

func _music_db() -> float:
	return linear_to_db(maxf(0.0001, master_volume * music_volume)) + catalog.tracks.get(current, {}).get("gain_db", 0) if enabled else -70.0

func update_volume() -> void:
	if crossfade != null and crossfade.is_running(): crossfade.kill()
	players[1-front].stop()
	players[front].volume_db = _music_db()

func play_sfx(id: String) -> void:
	if not enabled or not catalog.sfx.has(id): return
	for player in sfx_players:
		if player.playing: continue
		player.stream = resolve_stream(catalog.sfx[id])
		if player.stream == null: return
		player.volume_db = linear_to_db(maxf(0.0001, master_volume * sfx_volume)) + catalog.sfx[id].get("gain_db", 0)
		player.pitch_scale = randf_range(0.93, 1.07) if id in ["slash", "attack", "hit", "jump", "pogo", "kill"] else 1.0
		player.play()
		return

func _exit_tree() -> void:
	for player in players + sfx_players:
		player.stop()
		player.stream = null
