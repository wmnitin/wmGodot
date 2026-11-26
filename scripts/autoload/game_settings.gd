extends Node

## Persistent match options. A settings screen can bind to these later.
## Music and sound toggles are honored by AudioHooks even before that screen exists.

signal settings_changed

const DIFFICULTIES := {
	"easy": {
		"label": "Easy",
		"reaction_interval": 3.2,
		"mistake_chance": 0.40,
		"growth_multiplier": 0.75,
	},
	"normal": {
		"label": "Normal",
		"reaction_interval": 2.0,
		"mistake_chance": 0.15,
		"growth_multiplier": 1.0,
	},
	"hard": {
		"label": "Hard",
		"reaction_interval": 1.15,
		"mistake_chance": 0.05,
		"growth_multiplier": 1.30,
	},
}

var difficulty := "normal"
var music_enabled := true
var sound_enabled := true
var level_path := BattleRules.LEVEL_PATH


func params() -> Dictionary:
	return DIFFICULTIES[difficulty]


func set_difficulty(id: String) -> void:
	if not DIFFICULTIES.has(id):
		return
	difficulty = id
	settings_changed.emit()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	settings_changed.emit()


func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	settings_changed.emit()
