extends Node

## Drop matching audio files into res://assets/audio later.
## Missing files and disabled toggles are silent no-ops.

const SFX := {
	"ui": "res://assets/audio/ui.ogg",
	"connect": "res://assets/audio/connect.ogg",
	"cut": "res://assets/audio/cut.ogg",
	"capture": "res://assets/audio/capture.ogg",
	"win": "res://assets/audio/win.ogg",
	"lose": "res://assets/audio/lose.ogg",
}
const MUSIC := "res://assets/audio/music.ogg"

var _sfx: AudioStreamPlayer
var _music: AudioStreamPlayer


func _ready() -> void:
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	if not GameSettings.settings_changed.is_connected(_on_settings):
		GameSettings.settings_changed.connect(_on_settings)


func play_sfx(id: String) -> void:
	if not GameSettings.sound_enabled:
		return
	var path: String = str(SFX.get(id, ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream == null:
		return
	_sfx.stream = stream
	_sfx.play()


func start_music() -> void:
	if not GameSettings.music_enabled:
		stop_music()
		return
	if not ResourceLoader.exists(MUSIC):
		return
	if _music.playing:
		return
	_music.stream = load(MUSIC)
	_music.volume_db = -8.0
	_music.play()


func stop_music() -> void:
	if _music and _music.playing:
		_music.stop()


func _on_settings() -> void:
	if not GameSettings.music_enabled:
		stop_music()
	else:
		start_music()
