extends Node

## Saves the level select screen and one opening frame of each meadow.
##   godot --path . --rendering-method gl_compatibility res://tools/capture_shots.gd

const OUT := "/opt/cursor/artifacts"

var _main: Node
var _select: Control
var _tick := 0
var _phase := "select"
var _index := 1


func _ready() -> void:
	print("CAPTURE_START")
	DirAccess.make_dir_recursive_absolute(OUT)
	var settings = get_node("/root/GameSettings")
	settings.unlocked_level = 4
	settings.cleared = {"1": true, "2": true}
	_select = load("res://scripts/game/level_select.gd").new()
	add_child(_select)


func _process(_delta: float) -> void:
	_tick += 1
	if _phase == "select" and _tick == 4:
		_save("level_select")
		_select.queue_free()
		_select = null
		_phase = "opening"
		_tick = 0
		_index = 1
		return
	if _phase != "opening":
		return
	if _tick == 1:
		if is_instance_valid(_main):
			_main.queue_free()
		_main = load("res://scripts/main.gd").new()
		add_child(_main)
		_main.start_level(_index)
		var game = _find_game()
		if game != null:
			game.sim.ai_enabled = false
	elif _tick == 8:
		_save("level_%02d_opening" % _index)
		_index += 1
		_tick = 0
		if _index > BattleRules.LEVEL_COUNT:
			print("CAPTURE_DONE")
			get_tree().quit(0)


func _find_game():
	if _main == null:
		return null
	for child in _main.get_children():
		if child.get("sim") != null:
			return child
	return null


func _save(file_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT, file_name]
	var err := image.save_png(path)
	print("shot %s %s err=%s" % [file_name, image.get_size(), err])
