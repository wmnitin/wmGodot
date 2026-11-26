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
	elif _phase == "tank_shot" and _tick == 3:
		_save("tank_on_the_move")
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
	_queue = ["l1", "l2", "l3", "max", "factory", "soldier", "soldier_side", "tank", "tank_side"]
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
	if item == "l1":
		_show_tower("p_w", 4, "tower_level_1", 0.7)
	elif item == "l2":
		_show_tower("p_w", 18, "tower_level_2", 1.15)
	elif item == "l3":
		_show_tower("p_w", 40, "tower_level_3", 1.6)
	elif item == "max":
		_show_tower("p_w", 60, "tower_max", 1.9)
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
			_frame(Vector3(0, 0.28, 0.02), Vector3(1.15, 0.72, 1.85))
		else:
			_studio.rotation.y = 0.35
			_studio.get_node("Sword").rotation = Vector3(-0.9, 0.0, -0.4)
			_frame(Vector3(0, 0.3, 0), Vector3(1.35, 0.48, 0.55))
	else:
		_hide_towers()
		_studio = _game._models.make_tank("player")
		_studio.name = "tank" if item == "tank" else "tank_side"
		_game.add_child(_studio)
		_studio.position = Vector3(0, 0, 0)
		if item == "tank":
			_studio.rotation.y = -0.6
			_frame(Vector3(0, 0.28, 0), Vector3(1.55, 0.85, 1.7))
		else:
			_studio.rotation.y = 0.4
			_frame(Vector3(0, 0.26, 0), Vector3(1.9, 0.6, 0.45))


func _show_tower(id: String, count: int, file_name: String, focus_y: float) -> void:
	for key in _game._towers.keys():
		_game._towers[key].visible = str(key) == id
	_game.sim.force_count(id, count)
	_game._sync_towers(0.0)
	var tower: Node3D = _game._towers[id]
	_studio = Node3D.new()
	_studio.name = file_name
	var focus: Vector3 = tower.global_position + Vector3(0, focus_y, 0)
	_frame(focus, Vector3(4.4, 2.8, 5.2))


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
