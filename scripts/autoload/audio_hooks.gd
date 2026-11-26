extends Node

## Plays the files in res://assets/audio. See assets/audio/CREDITS.md.
## Missing files and disabled toggles stay silent. Several voices so a
## spawn pop does not cut off a capture fanfare.

const SFX := {
	"ui": "res://assets/audio/ui.wav",
	"connect": "res://assets/audio/connect.wav",
	"cut": "res://assets/audio/cut.wav",
	"capture": "res://assets/audio/capture.wav",
	"spawn": "res://assets/audio/spawn.wav",
	"clash": "res://assets/audio/clash.wav",
	"level_up": "res://assets/audio/level_up.wav",
	"win": "res://assets/audio/win.wav",
	"lose": "res://assets/audio/lose.wav",
	"tank_shot": "res://assets/audio/tank_shot.wav",
}
const MUSIC := "res://assets/audio/music.wav"
const RUMBLE := "res://assets/audio/tank_rumble.wav"
const VOICE_COUNT := 6

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _streams := {}
var _music: AudioStreamPlayer
var _music_stream: AudioStream
var _rumble: AudioStreamPlayer
var _rumble_stream: AudioStream


func _ready() -> void:
	for _i in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_rumble = AudioStreamPlayer.new()
	add_child(_rumble)
	for id in SFX.keys():
		_streams[id] = _load_stream(str(SFX[id]), false)
	_music_stream = _load_stream(MUSIC, true)
	_rumble_stream = _load_stream(RUMBLE, true)
	if not GameSettings.settings_changed.is_connected(_on_settings):
		GameSettings.settings_changed.connect(_on_settings)
	_apply_volumes()


func play_sfx(id: String) -> void:
	if not GameSettings.sound_enabled or GameSettings.sound_volume <= 0.001:
		return
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = _db(GameSettings.sound_volume)
	voice.play()


func start_music() -> void:
	if not GameSettings.music_enabled or GameSettings.music_volume <= 0.001:
		stop_music()
		return
	if _music_stream == null:
		return
	_apply_volumes()
	if _music.playing:
		return
	_music.stream = _music_stream
	_music.play()


func stop_music() -> void:
	if _music and _music.playing:
		_music.stop()


func set_rumble(active: bool) -> void:
	if _rumble == null or _rumble_stream == null:
		return
	var want := active and GameSettings.sound_enabled and GameSettings.sound_volume > 0.001
	if not want:
		if _rumble.playing:
			_rumble.stop()
		return
	_rumble.volume_db = _db(GameSettings.sound_volume * 0.55)
	if _rumble.playing:
		return
	_rumble.stream = _rumble_stream
	_rumble.play()


func music_is_looping() -> bool:
	if _music_stream == null:
		_music_stream = _load_stream(MUSIC, true)
	return _music_stream is AudioStreamWAV and _music_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD


func _on_settings() -> void:
	_apply_volumes()
	if not GameSettings.music_enabled or GameSettings.music_volume <= 0.001:
		stop_music()
	elif not _music.playing:
		start_music()


func _apply_volumes() -> void:
	if _music:
		_music.volume_db = _db(GameSettings.music_volume)
	for voice in _voices:
		voice.volume_db = _db(GameSettings.sound_volume)


func _load_stream(path: String, looped: bool) -> AudioStream:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var loaded = load(path)
	if loaded == null:
		return null
	var stream := loaded.duplicate() as AudioStream
	if looped and stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.mix_rate * wav.get_length())
	return stream


func _db(linear: float) -> float:
	if linear <= 0.001:
		return -80.0
	return linear_to_db(linear)
