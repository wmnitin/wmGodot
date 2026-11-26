extends Node

var host: Node
var frames := 0


func _process(_delta: float) -> void:
	frames += 1
	if frames == 8 and host and host.has_method("start_match"):
		host.start_match()
	if frames < 160:
		return
	var playing := false
	if host:
		for child in host.get_children():
			if child is Node2D and child.get("sim") != null:
				playing = str(child.sim.state) == "playing" or str(child.sim.state) == "victory" or str(child.sim.state) == "defeat"
	if playing:
		get_tree().quit(0)
	else:
		push_error("Smoke test: the match view did not start.")
		get_tree().quit(1)
