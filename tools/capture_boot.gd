extends SceneTree

## Loads the screenshot driver. The project main scene is the title, so a
## loose script path does not replace it.
##   godot --path . --rendering-method gl_compatibility -s res://tools/capture_boot.gd


func _init() -> void:
	var driver = load("res://tools/capture_shots.gd").new()
	root.add_child(driver)
