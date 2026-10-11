extends Node
## Separate music and feedback players; playback begins after user input for browser audio policies.
var music: AudioStreamPlayer
var feedback: AudioStreamPlayer
var enabled: bool = false
var current_track: String = ""
var config: Dictionary

func configure(settings: Dictionary) -> void:
	config = settings
	music = AudioStreamPlayer.new()
	music.volume_db = config.music_volume_db
	add_child(music)
	feedback = AudioStreamPlayer.new()
	feedback.volume_db = config.sfx_volume_db
	add_child(feedback)

func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		music.stop()
	elif current_track != "":
		play_music(current_track, true)

func play_music(track: String, force: bool = false) -> void:
	if current_track == track and not force:
		return
	current_track = track
	var path = "res://assets/audio/music/" + track + ".wav"
	if enabled and ResourceLoader.exists(path):
		music.stream = load(path)
		if music.stream is AudioStreamWAV:
			music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			music.stream.loop_end = int(music.stream.get_length() * music.stream.mix_rate)
		music.play()

func click() -> void:
	if enabled and ResourceLoader.exists("res://assets/audio/sfx/chime.wav"):
		feedback.stream = load("res://assets/audio/sfx/chime.wav")
		feedback.play()

func _exit_tree() -> void:
	for player in [music, feedback]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
