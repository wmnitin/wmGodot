extends SceneTree

## Loads the main scene, starts a match, and runs a few seconds of frames.
##   godot --headless --path . -s res://tools/smoke_scene.gd


func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var watcher := Node.new()
	watcher.set_script(load("res://tools/smoke_watcher.gd"))
	watcher.set("host", main)
	root.add_child(watcher)
