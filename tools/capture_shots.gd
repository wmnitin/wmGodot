extends Node

## Steps the 3D match and writes PNGs. No awaits: the first frame of a
## yielded main scene was not coming back on this machine.
##   godot --path . --rendering-method gl_compatibility res://tools/capture_shots.gd

const OUT := "/opt/cursor/artifacts"

var _main: Node
var _game
var _tick := 0
var _phase := "boot"
var _studio: Node3D


func _ready() -> void:
	print("CAPTURE_START")
	DirAccess.make_dir_recursive_absolute(OUT)
	_main = load("res://scripts/main.gd").new()
	add_child(_main)
	_main.start_match()
	_game = _find_game()
	if _game == null:
		push_error("Capture: no match view")
		get_tree().quit(1)
		return
	_game.sim.ai_enabled = false
	_phase = "opening"


func _process(_delta: float) -> void:
	_tick += 1
	if _game == null:
		return
	if _phase == "opening" and _tick == 4:
		_save("match_opening")
		_game.set_process(false)
		_game.sim.try_connect("p_w", "e_w")
		_game.sim.try_connect("e_w", "p_w")
		_phase = "clash"
		_tick = 0
	elif _phase == "clash" and _tick == 1:
		for _i in 160:
			_game.sim.step(0.05)
			var shown := false
			for soldier in _game.sim.soldiers:
				var swung := float(soldier.get("swing", -1.0))
				if swung >= 0.0 and _game.sim.elapsed - swung < 0.25:
					shown = true
			if shown:
				break
		_game._sync(0.05)
		_phase = "clash_shot"
		_tick = 0
	elif _phase == "clash_shot" and _tick == 1:
		_save("battle")
		var lane_a: Vector3 = _game._towers["p_w"].global_position
		var lane_b: Vector3 = _game._towers["e_w"].global_position
		_frame((lane_a + lane_b) * 0.5 + Vector3(0, 0.35, 0), Vector3(2.4, 2.0, 2.8))
	elif _phase == "clash_shot" and _tick == 4:
		_save("sword_clash")
		_game._fit_camera(true)
		for link in _game.sim.links.duplicate():
			_game.sim.try_cut(int(link.id))
		for soldier in _game.sim.soldiers:
			soldier.dead = true
			soldier.swing = -1.0
		_game.sim.step(0.4)
		var factory = _game.sim.tower("n_c")
		factory.owner = "player"
		factory.count = 14
		_game.sim.try_connect("n_c", "e_e")
		_phase = "tank"
		_tick = 0
	elif _phase == "tank" and _tick == 1:
		for _i in 90:
			_game.sim.step(0.05)
			var mid := false
			for soldier in _game.sim.soldiers:
				if str(soldier.get("kind", "")) == "tank" and not bool(soldier.dead):
					var progress := float(soldier.progress)
					if progress > 0.28 and progress < 0.72:
						mid = true
			if mid:
				break
		_game._sync(0.05)
		_phase = "tank_shot"
		_tick = 0
	elif _phase == "tank_shot" and _tick == 2:
		var tank_focus := Vector3(0, 0.4, 0)
		for id in _game._active.keys():
			var unit: Node3D = _game._active[id]
			if unit != null and unit.visible and str(unit.get_meta("pool", "")).begins_with("tank"):
				tank_focus = unit.global_position + Vector3(0, 0.35, 0)
				break
		_frame(tank_focus, Vector3(2.4, 1.7, 2.8))
	elif _phase == "tank_shot" and _tick == 5:
		_save("tank_on_the_move")
		for link in _game.sim.links.duplicate():
			_game.sim.try_cut(int(link.id))
		_game._sync(0.0)
		_game._fit_camera(true)
		var from: Vector3 = _game._to_world(_game.sim.tower("e_w").pos)
		var to: Vector3 = _game._to_world(_game.sim.tower("n_e").pos)
		_game._preview.visible = true
		_game._preview.material_override = _game._preview_blocked_material()
		_game._aim_beam(_game._preview, from + Vector3(0, 0.08, 0), to + Vector3(0, 0.08, 0), 0.18)
		_phase = "blocked"
		_tick = 0
	elif _phase == "blocked" and _tick == 3:
		_save("blocked_link")
		_game._preview.visible = false
		_begin_studio()
	elif _phase == "studio":
		if _tick == 2:
			_save(_studio.name)
			_next_studio()


func _begin_studio() -> void:
	_hide_hud()
	_game._link_root.visible = false
	_game._units.visible = false
	_phase = "studio"
	_tick = 0
	_queue = [
		"lineup",
		"blue1", "blue2", "blue3", "bluemax",
		"red1", "red2", "red3", "redmax",
		"neutral1", "neutral2", "neutral3", "neutralmax",
		"factory", "soldier", "soldier_side", "tank",
	]
	_next_studio()


var _queue: Array = []


func _next_studio() -> void:
	if _studio != null and is_instance_valid(_studio):
		_studio.queue_free()
		_studio = null
	if _queue.is_empty():
		print("CAPTURE_DONE")
		get_tree().quit(0)
		return
	var item: String = _queue.pop_front()
	_tick = 0
	if item == "lineup":
		_show_lineup()
	elif item.begins_with("blue") or item.begins_with("red") or item.begins_with("neutral"):
		_show_team_tower(item)
	elif item == "factory":
		var factory = _game.sim.tower("n_c")
		factory.owner = "player"
		_show_tower("n_c", 36, "tank_factory", 1.7)
	elif item == "soldier" or item == "soldier_side":
		_hide_towers()
		_studio = _game._models.make_soldier("player")
		_studio.name = "capybara_soldier" if item == "soldier" else "capybara_soldier_side"
		_game.add_child(_studio)
		_studio.position = Vector3(0, 0, 0)
		if item == "soldier":
			_studio.rotation.y = -0.55
			_studio.get_node("Sword").rotation = Vector3(-0.35, 0.1, -0.7)
			_frame(Vector3(0, 0.32, 0.08), Vector3(0.7, 0.55, 1.7))
		else:
			_studio.rotation.y = 0.15
			_studio.get_node("Sword").rotation = Vector3(-0.6, 0.1, -0.2)
			_frame(Vector3(0, 0.3, 0), Vector3(1.7, 0.5, 0.35))
	else:
		_hide_towers()
		_studio = _game._models.make_tank("player")
		_studio.name = "tank" if item == "tank" else "tank_side"
		_game.add_child(_studio)
		_studio.position = Vector3(0, 0, 0)
		if item == "tank":
			_studio.rotation.y = -0.6
			_frame(Vector3(0, 0.32, 0), Vector3(1.9, 1.05, 2.1))
		else:
			_studio.rotation.y = 0.4
			_frame(Vector3(0, 0.26, 0), Vector3(1.9, 0.6, 0.45))


func _show_lineup() -> void:
	_hide_towers()
	_studio = Node3D.new()
	_studio.name = "towers_row"
	_game.add_child(_studio)
	var owners := ["player", "enemy", "neutral"]
	var counts := [4, 18, 40, 60]
	for r in 3:
		for c in 4:
			var entry := {
				"id": "row_%d_%d" % [r, c],
				"type": "outpost",
				"owner": owners[r],
				"count": counts[c],
				"pos": Vector2.ZERO,
			}
			var tower: Node3D = _game._make_tower(entry)
			_studio.add_child(tower)
			tower.position = Vector3((float(c) - 1.5) * 2.75, 0, (1.0 - float(r)) * 3.7)
			_game._layout_tower(tower, entry, 0.0)
	_game._camera.fov = 42.0
	_frame(Vector3(0, 1.8, 0), Vector3(16.0, 13.5, 22.0))


func _show_team_tower(item: String) -> void:
	var owner := "player"
	var id := "p_w"
	var tag := "blue"
	if item.begins_with("red"):
		owner = "enemy"
		id = "e_w"
		tag = "red"
	elif item.begins_with("neutral"):
		owner = "neutral"
		id = "n_w"
		tag = "neutral"
	var count := 4
	var focus := 0.9
	var suffix := "level_1"
	if item.ends_with("2"):
		count = 18
		focus = 1.5
		suffix = "level_2"
	elif item.ends_with("3"):
		count = 40
		focus = 2.15
		suffix = "level_3"
	elif item.ends_with("max"):
		count = 60
		focus = 2.25
		suffix = "max"
	var entry = _game.sim.tower(id)
	entry.owner = owner
	_show_tower(id, count, "tower_%s_%s" % [tag, suffix], focus)


func _show_tower(id: String, count: int, file_name: String, focus_y: float) -> void:
	for key in _game._towers.keys():
		_game._towers[key].visible = str(key) == id
	_game.sim.force_count(id, count)
	_game._sync_towers(0.0)
	var tower: Node3D = _game._towers[id]
	_studio = Node3D.new()
	_studio.name = file_name
	_game._camera.fov = 33.0
	var height: float = _game._stack_world(count, id == "n_c")
	var focus: Vector3 = tower.global_position + Vector3(0, height * 0.45, 0)
	var dist := maxf(height * 1.35, 3.6 if id != "n_c" else 6.5)
	_frame(focus, Vector3(dist * 0.85, dist * 0.62, dist * 1.15))
	if focus_y < 0.0:
		_frame(focus, Vector3(5.4, 3.3, 6.0))


func _hide_towers() -> void:
	for key in _game._towers.keys():
		_game._towers[key].visible = false


func _frame(focus: Vector3, offset: Vector3) -> void:
	var eye: Vector3 = focus + offset
	var forward := (focus - eye).normalized()
	var z_axis := -forward
	var x_axis := Vector3.UP.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	_game._camera.global_transform = Transform3D(Basis(x_axis, y_axis, z_axis), eye)


func _hide_hud() -> void:
	for child in _game.get_children():
		if child is CanvasLayer:
			child.visible = false


func _find_game():
	for child in _main.get_children():
		if child.get("sim") != null:
			return child
	return null


func _save(file_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT, file_name]
	var err := image.save_png(path)
	print("shot %s %s err=%s" % [file_name, image.get_size(), err])
