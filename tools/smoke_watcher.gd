extends Node

var host: Node
var frames := 0
var _badge_ok := false


func _process(_delta: float) -> void:
	frames += 1
	if frames == 8 and host and host.has_method("start_match"):
		host.start_match()
	if frames == 14:
		_check_max_badge()
	if frames < 40:
		return
	if _badge_ok and _match_running():
		print("PASS  MAX badge hidden at 59 and shown at 60")
		get_tree().quit(0)
	else:
		push_error("Smoke test: match view or MAX badge check failed.")
		get_tree().quit(1)


func _match_running() -> bool:
	var game = _game()
	if game == null:
		return false
	var state := str(game.sim.state)
	return state == "playing" or state == "victory" or state == "defeat"


func _game():
	if host == null:
		return null
	for child in host.get_children():
		if child is Node2D and child.get("sim") != null:
			return child
	return null


func _check_max_badge() -> void:
	var game = _game()
	if game == null:
		return
	game.sim.ai_enabled = false
	game.sim.force_count("p_w", 59)
	game._sync_towers(0.0)
	if game._towers["p_w"].get_node("MaxBadge").visible:
		return
	game.sim.force_count("p_w", 60)
	game._sync_towers(0.0)
	if not game._towers["p_w"].get_node("MaxBadge").visible:
		return
	game.sim.force_count("p_w", 16)
	game._sync_towers(0.0)
	_badge_ok = true
