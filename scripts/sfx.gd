extends Node
## Звуки и музыка. SFX лежат в res://assets/sfx/<имя>.wav, музыка — любой файл в res://assets/music/.

const NAMES := ["shot", "hit", "death", "dash", "possess", "chaos", "eat", "boom", "click", "win"]
const EXT := ["ogg", "mp3", "wav"]

var streams := {}
var pool: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var tracks: Array = []


func _ready() -> void:
	for n in NAMES:
		var p := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(p):
			streams[n] = load(p)
	for i in 20:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		pool.append(pl)
	music = AudioStreamPlayer.new()
	add_child(music)
	music.finished.connect(_next_track)
	_scan_music()


func _scan_music() -> void:
	tracks.clear()
	for f in DirAccess.get_files_at("res://assets/music"):
		var n: String = f.trim_suffix(".import").trim_suffix(".remap")
		if n.get_extension().to_lower() in EXT and not tracks.has(n):
			tracks.append("res://assets/music/" + n)
	tracks.shuffle()


func play_music() -> void:
	if music.playing or tracks.is_empty():
		return
	_next_track()


func _next_track() -> void:
	if tracks.is_empty():
		return
	var s = load(tracks[randi() % tracks.size()])
	if s == null:
		return
	music.stream = s
	music.volume_db = linear_to_db(maxf(G.vol_music, 0.0001)) - 4.0
	music.play()


func refresh_volume() -> void:
	music.volume_db = linear_to_db(maxf(G.vol_music, 0.0001)) - 4.0


func play(n: String, pitch := 1.0, vol := 0.0) -> void:
	if not streams.has(n):
		return
	for pl in pool:
		if not pl.playing:
			pl.stream = streams[n]
			pl.pitch_scale = pitch * randf_range(0.94, 1.06)
			pl.volume_db = linear_to_db(maxf(G.vol_sfx, 0.0001)) + vol
			pl.play()
			return
