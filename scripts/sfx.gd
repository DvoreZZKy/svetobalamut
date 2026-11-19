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


# Minimum gap between two plays of the same sound, so a 10-player firefight doesn't turn into a buzz.
const MIN_GAP_MS := {"shot": 45, "hit": 35, "eat": 60, "dash": 50, "click": 30}
# Sounds that must always be heard, even if every voice is busy (they steal one).
const IMPORTANT := ["death", "boom", "chaos", "win", "possess"]
var last_played := {}


func play(n: String, pitch := 1.0, vol := 0.0) -> void:
	if not streams.has(n):
		return
	var now := Time.get_ticks_msec()
	var gap: int = MIN_GAP_MS.get(n, 0)
	if gap > 0:
		if now - int(last_played.get(n, -1000)) < gap:
			return
		last_played[n] = now
	var target: AudioStreamPlayer = null
	for pl in pool:
		if not pl.playing:
			target = pl
			break
	if target == null:
		if not IMPORTANT.has(n):
			return
		target = pool[0]
		for pl in pool:
			if pl.get_playback_position() > target.get_playback_position():
				target = pl  # steal the voice that is furthest along
	target.stream = streams[n]
	target.pitch_scale = pitch * randf_range(0.94, 1.06)
	target.volume_db = linear_to_db(maxf(G.vol_sfx, 0.0001)) + vol
	target.play()
