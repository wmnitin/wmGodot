extends Node

## Difficulty and audio options. Saved to user:// so they survive a restart.
## The settings panel and AudioHooks both listen to settings_changed.

signal settings_changed

const SAVE_PATH := "user://capy_tower_wars_settings.cfg"
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
var music_volume := 0.7
var sound_volume := 0.85
var level_path := BattleRules.LEVEL_PATH
var level_index := 1
var unlocked_level := 1
var cleared := {}


func _ready() -> void:
	load_settings()


func params() -> Dictionary:
	return DIFFICULTIES[difficulty]


func set_difficulty(id: String) -> void:
	if not DIFFICULTIES.has(id) or id == difficulty:
		return
	difficulty = id
	_commit()


func set_music_enabled(enabled: bool) -> void:
	if enabled == music_enabled:
		return
	music_enabled = enabled
	_commit()


func set_sound_enabled(enabled: bool) -> void:
	if enabled == sound_enabled:
		return
	sound_enabled = enabled
	_commit()


func set_music_volume(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, music_volume):
		return
	music_volume = next
	_commit()


func set_sound_volume(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, sound_volume):
		return
	sound_volume = next
	_commit()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	var stored := str(config.get_value("game", "difficulty", difficulty))
	if DIFFICULTIES.has(stored):
		difficulty = stored
	music_enabled = bool(config.get_value("audio", "music_enabled", music_enabled))
	sound_enabled = bool(config.get_value("audio", "sound_enabled", sound_enabled))
	music_volume = clampf(float(config.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sound_volume = clampf(float(config.get_value("audio", "sound_volume", sound_volume)), 0.0, 1.0)
	if config.has_section_key("progress", "unlocked"):
		unlocked_level = clampi(int(config.get_value("progress", "unlocked", 1)), 1, BattleRules.LEVEL_COUNT)
	if config.has_section_key("progress", "cleared"):
		cleared = {}
		for piece in str(config.get_value("progress", "cleared", "")).split(",", false):
			cleared[piece] = true
	settings_changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "difficulty", difficulty)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sound_enabled", sound_enabled)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sound_volume", sound_volume)
	config.set_value("progress", "unlocked", unlocked_level)
	var ids: PackedStringArray = PackedStringArray()
	for key in cleared.keys():
		ids.append(str(key))
	ids.sort()
	config.set_value("progress", "cleared", ",".join(ids))
	config.save(SAVE_PATH)


func _commit() -> void:
	save_settings()
	settings_changed.emit()


func set_level_index(index: int) -> void:
	level_index = clampi(index, 1, BattleRules.LEVEL_COUNT)
	level_path = BattleRules.level_path(level_index)


func is_level_unlocked(index: int) -> bool:
	return index >= 1 and index <= unlocked_level


func is_level_cleared(index: int) -> bool:
	return cleared.has(str(index))


func note_victory() -> void:
	cleared[str(level_index)] = true
	unlocked_level = maxi(unlocked_level, mini(BattleRules.LEVEL_COUNT, level_index + 1))
	_commit()
