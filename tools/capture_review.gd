extends Node

## Opening frames for levels 1, 5, and 10, plus one battle with soldiers on the ribbons.
##   godot --path . --rendering-method gl_compatibility --scene res://tools/capture_review.tscn

const OUT := "/opt/cursor/artifacts"

var _main: Node
var _tick := 0
var _phase := "open"
var _levels := [1, 5, 10]
var _index := 0


func _ready() -> void:
	print("CAPTURE_START")
	DirAccess.make_dir_recursive_absolute(OUT)
	_begin_level()


func _begin_level() -> void:
	if is_instance_valid(_main):
		_main.queue_free()
		_main = null
	_main = load("res://scripts/main.gd").new()
	add_child(_main)
	var level := 1
	if _phase == "open":
		level = _levels[_index]
	_main.start_level(level)
	var game = _find_game()
	if game != null:
		game.sim.ai_enabled = false


func _process(_delta: float) -> void:
	_tick += 1
	if _phase == "open":
		if _tick < 6:
			return
		var game = _find_game()
		if game != null:
			game._fit_camera(true)
		_save("level_%02d_opening" % _levels[_index])
		_index += 1
		_tick = 0
		if _index >= _levels.size():
			_phase = "battle"
		_begin_level()
		return
	if _tick == 3:
		var game = _find_game()
		if game == null:
			print("CAPTURE_NO_GAME")
			get_tree().quit(1)
			return
		for pair in [["p_w", "n_w"], ["p_e", "n_e"], ["p_e", "n_c"], ["e_w", "n_w"], ["e_e", "n_e"]]:
			var result: Dictionary = game.sim.try_connect(pair[0], pair[1])
			print("link %s -> %s %s" % [pair[0], pair[1], str(result.get("reason", ""))])
		for _i in 90:
			game.sim.step(1.0 / 60.0)
		game._sync(0.016)
		game._fit_camera(true)
	elif _tick == 5:
		_save("battle")
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
