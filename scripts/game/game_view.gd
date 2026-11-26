extends Node3D

signal match_finished(victory: bool)
signal restart_requested

## Sim space stays in pixels. The view maps that onto a small 3D meadow.
const WORLD_SCALE := 0.012
const PITCH_DEG := 52.0
const FLOOR_H := 0.82

var sim: MatchSim
var _models := CapyModels.new()
var _camera: Camera3D
var _towers := {}
var _links := {}
var _active := {}
var _pool := {}
var _punch := {}
var _prev_owner := {}
var _prev_count := {}
var _prev_level := {}

var _pointer := -1
var _mode := ""
var _source_id := ""
var _slash_prev := Vector2.ZERO
var _hover_id := ""
var _preview: MeshInstance3D
var _hover_ring: MeshInstance3D
var _beam_mesh: BoxMesh
var _link_root: Node3D
var _actors: Node3D
var _units: Node3D

var _you_label: Label
var _red_label: Label
var _name_label: Label
var _hint: Label
var _toast: Label
var _toast_time := 0.0
var _hint_time := 0.0
var _over := false
var _paused := false
var _settings: Control
var _heard_cancels := 0
var _heard_tanks := 0
var _end_delay := 0.0
var _view_size := Vector2.ZERO
var _lip_mats := {}
var _link_mats := {}
var _pip_gold: StandardMaterial3D
var _pip_idle: StandardMaterial3D
var _preview_ok: StandardMaterial3D
var _preview_dim: StandardMaterial3D


func _ready() -> void:
	sim = MatchSim.new()
	if not sim.load_level(GameSettings.level_path):
		sim = null
		_show_error("Could not load the level.")
		return
	sim.configure(GameSettings.params(), randi())
	sim.ai_enabled = true
	_build_world()
	_build_hud()
	_build_towers()
	_fit_camera()
	AudioHooks.start_music()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8EC8F0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("FFF6E8")
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -32, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	add_child(sun)

	_camera = Camera3D.new()
	_camera.fov = 36.0
	_camera.near = 0.05
	_camera.far = 80.0
	add_child(_camera)
	_camera.make_current()

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	ground.material_override = _solid(Color("5E9A52"), 0.95)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	var field := BattleRules.FIELD_SIZE * WORLD_SCALE
	var meadow := MeshInstance3D.new()
	var patch := PlaneMesh.new()
	patch.size = Vector2(field.x + 1.4, field.y + 1.4)
	meadow.mesh = patch
	meadow.position = Vector3(0, 0.012, 0)
	meadow.material_override = _solid(Color("7EBE68"), 0.9)
	meadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(meadow)
	_add_grass(field)
	_add_decor(field)

	_beam_mesh = BoxMesh.new()
	_beam_mesh.size = Vector3(1, 1, 1)
	_link_root = Node3D.new()
	_link_root.name = "Links"
	add_child(_link_root)
	_actors = Node3D.new()
	_actors.name = "Actors"
	add_child(_actors)
	_units = Node3D.new()
	_units.name = "Units"
	add_child(_units)

	_preview = MeshInstance3D.new()
	_preview.mesh = _beam_mesh
	_preview.material_override = _solid(Palette.PLAYER, 0.4)
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.visible = false
	add_child(_preview)

	_hover_ring = MeshInstance3D.new()
	_hover_ring.mesh = _models.lip_mesh()
	_hover_ring.material_override = _solid(Palette.GOLD, 0.45)
	_hover_ring.scale = Vector3(1.35, 1.0, 1.35)
	_hover_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hover_ring.visible = false
	add_child(_hover_ring)


func _add_grass(field: Vector2) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var tuft := SphereMesh.new()
	tuft.radius = 0.1
	tuft.height = 0.26
	tuft.radial_segments = 5
	tuft.rings = 2
	multi.mesh = tuft
	multi.instance_count = 24
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in multi.instance_count:
		var x := rng.randf_range(-field.x * 0.62, field.x * 0.62)
		var z := rng.randf_range(-field.y * 0.55, field.y * 0.55)
		var h := rng.randf_range(0.55, 1.15)
		var basis := Basis.IDENTITY.scaled(Vector3(1.0, h, 1.0))
		multi.set_instance_transform(i, Transform3D(basis, Vector3(x, 0.06, z)))
	var grass := MultiMeshInstance3D.new()
	grass.multimesh = multi
	grass.material_override = _solid(Color("8FCB6E"), 0.85)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)


func _add_decor(field: Vector2) -> void:
	var spots := [
		Vector3(-field.x * 0.72, 0, -field.y * 0.42),
		Vector3(field.x * 0.7, 0, -field.y * 0.38),
		Vector3(-field.x * 0.68, 0, field.y * 0.46),
		Vector3(field.x * 0.74, 0, field.y * 0.4),
		Vector3(0, 0, -field.y * 0.62),
		Vector3(-field.x * 0.2, 0, field.y * 0.64),
	]
	for spot in spots:
		var bush := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.38
		mesh.height = 0.62
		mesh.radial_segments = 6
		mesh.rings = 3
		bush.mesh = mesh
		bush.position = spot + Vector3(0, 0.28, 0)
		bush.material_override = _solid(Color("3E8A45"), 0.8)
		bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bush)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	UiKit.full_rect(root)

	_you_label = Label.new()
	_you_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.outlined(_you_label, Palette.PLAYER, Palette.INK, 40)
	_you_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(_you_label)
	_you_label.position = Vector2(36, 36)
	_you_label.size = Vector2(320, 120)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.text = sim.level_name
	UiKit.outlined(_name_label, Palette.CREAM, Palette.DEEP, 36)
	root.add_child(_name_label)
	_name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_name_label.offset_left = -260
	_name_label.offset_right = 260
	_name_label.offset_top = 48
	_name_label.offset_bottom = 120

	_red_label = Label.new()
	_red_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.outlined(_red_label, Palette.ENEMY, Palette.INK, 40)
	_red_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_red_label)
	_red_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_red_label.offset_left = -340
	_red_label.offset_right = -36
	_red_label.offset_top = 36
	_red_label.offset_bottom = 120

	var restart := UiKit.button("Restart", Color("5E6B80"), 26, 72)
	restart.custom_minimum_size = Vector2(180, 72)
	restart.pressed.connect(func():
		AudioHooks.play_sfx("ui")
		restart_requested.emit()
	)
	root.add_child(restart)
	restart.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	restart.offset_left = -220
	restart.offset_right = -28
	restart.offset_top = 128
	restart.offset_bottom = 200

	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.text = sim.level_blurb if sim.level_blurb != "" else "Drag your tower. Swipe your line to cut it."
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiKit.outlined(_hint, Palette.INK, Palette.CREAM, 28)
	root.add_child(_hint)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -460
	_hint.offset_right = 460
	_hint.offset_top = -150
	_hint.offset_bottom = -40

	_toast = Label.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	UiKit.outlined(_toast, Palette.CREAM, Palette.DEEP, 32)
	root.add_child(_toast)
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -460
	_toast.offset_right = 460
	_toast.offset_top = -280
	_toast.offset_bottom = -170

	var gear := UiKit.icon_button(ArtLibrary.texture(ArtLibrary.GEAR), 88)
	gear.pressed.connect(_open_settings)
	root.add_child(gear)
	gear.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	gear.offset_left = 28
	gear.offset_top = -268
	gear.offset_right = 116
	gear.offset_bottom = -180

	_settings = load("res://scripts/game/settings_panel.gd").new()
	_settings.closed.connect(func(): _paused = false)
	root.add_child(_settings)
	if not GameSettings.settings_changed.is_connected(_apply_live_settings):
		GameSettings.settings_changed.connect(_apply_live_settings)


func _open_settings() -> void:
	_paused = true
	AudioHooks.play_sfx("ui")
	_settings.open_panel()


func _apply_live_settings() -> void:
	if sim == null:
		return
	sim.ai_params = GameSettings.params().duplicate()


func _build_towers() -> void:
	for id in _towers.keys():
		var old: Node = _towers[id]
		if is_instance_valid(old):
			old.queue_free()
	_towers.clear()
	for id in _active.keys():
		var unit: Node = _active[id]
		if is_instance_valid(unit):
			unit.queue_free()
	_active.clear()
	_pool.clear()
	for entry in sim.towers:
		var node := _make_tower(entry)
		_actors.add_child(node)
		_towers[str(entry.id)] = node
		_punch[str(entry.id)] = 1.0
		_prev_owner[str(entry.id)] = str(entry.owner)
		_prev_count[str(entry.id)] = int(entry.count)
		_prev_level[str(entry.id)] = sim.level_of(int(entry.count))


func _make_tower(entry: Dictionary) -> Node3D:
	var node := Node3D.new()
	var team := str(entry.owner)
	var factory := str(entry.type) == "tank_factory"
	node.set_meta("factory", factory)
	node.set_meta("team", team)
	node.position = _to_world(entry.pos)

	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	shadow.mesh = _models.lip_mesh()
	shadow.scale = Vector3(1.25, 0.15, 1.25)
	shadow.position = Vector3(0, 0.03, 0)
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0, 0, 0, 0.28)
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shade
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(shadow)

	var mat := _models.team_material(team)
	for i in 3:
		var floor := MeshInstance3D.new()
		floor.name = "Floor%d" % i
		floor.mesh = _models.factory_mesh() if factory else _models.floor_mesh()
		floor.material_override = mat
		floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(floor)
		var lip := MeshInstance3D.new()
		lip.name = "Lip%d" % i
		lip.mesh = _models.lip_mesh()
		lip.material_override = _lip_material(team)
		lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(lip)

	if factory:
		var chimney := MeshInstance3D.new()
		chimney.name = "Chimney"
		chimney.mesh = _models.floor_mesh()
		chimney.material_override = _solid(Color("5C4A3A"), 0.7)
		chimney.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(chimney)
		var bay := _models.make_tank(team)
		bay.name = "Bay"
		bay.scale = Vector3(0.55, 0.55, 0.55)
		node.add_child(bay)

	var capy := _models.make_soldier(team)
	capy.name = "Capy"
	capy.scale = Vector3(1.15, 1.15, 1.15)
	node.add_child(capy)

	var count := Label3D.new()
	count.name = "Count"
	count.font_size = 72
	count.pixel_size = 0.007
	count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	count.outline_size = 18
	count.modulate = Palette.CREAM
	count.outline_modulate = Palette.INK
	count.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(count)

	var badge := Label3D.new()
	badge.name = "MaxBadge"
	badge.text = "MAX"
	badge.font_size = 54
	badge.pixel_size = 0.007
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.modulate = Color("1A1206")
	badge.outline_size = 14
	badge.outline_modulate = Palette.GOLD
	badge.visible = false
	badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(badge)

	var pips := Node3D.new()
	pips.name = "Pips"
	node.add_child(pips)
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = 0.07
	pip_mesh.height = 0.14
	pip_mesh.radial_segments = 6
	pip_mesh.rings = 2
	for i in 3:
		var pip := MeshInstance3D.new()
		pip.name = "Pip%d" % i
		pip.mesh = pip_mesh
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pips.add_child(pip)
	return node


func _process(delta: float) -> void:
	if sim == null:
		return
	if _paused:
		return
	if sim.state == "playing":
		sim.step(delta)
	elif not _over:
		_end_delay += delta
		if _end_delay >= 0.45:
			_over = true
			set_process_unhandled_input(false)
			AudioHooks.set_rumble(false)
			var victory := sim.state == "victory"
			AudioHooks.play_sfx("win" if victory else "lose")
			match_finished.emit(victory)
	_sync(delta)
	_hint_time += delta
	if _hint and _hint_time > 7.0:
		_hint.modulate.a = maxf(0.0, _hint.modulate.a - delta * 0.8)
	if _toast and _toast.visible:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast.visible = false


func _sync(delta: float) -> void:
	_fit_camera()
	var cancels := int(sim.stats.get("cancelled", 0))
	if cancels > _heard_cancels:
		AudioHooks.play_sfx("clash")
	_heard_cancels = cancels
	var tank_hits := int(sim.stats.get("tank_arrivals", 0))
	if tank_hits > _heard_tanks:
		AudioHooks.play_sfx("tank_shot")
	_heard_tanks = tank_hits
	_you_label.text = "You  %d" % sim.victory_count("player")
	_red_label.text = "Red  %d" % sim.victory_count("enemy")
	_sync_towers(delta)
	_sync_links()
	_sync_soldiers()
	AudioHooks.set_rumble(_any_tank())


func _sync_towers(delta: float) -> void:
	for entry in sim.towers:
		var id := str(entry.id)
		var node: Node3D = _towers.get(id)
		if node == null:
			continue
		node.position = _to_world(entry.pos)
		var level := sim.level_of(int(entry.count))
		var prior_level := int(_prev_level.get(id, level))
		if level > prior_level:
			AudioHooks.play_sfx("level_up")
		_prev_level[id] = level
		if int(entry.count) != int(_prev_count.get(id, -1)):
			_punch[id] = 1.12
		var team := str(entry.owner)
		if team != str(_prev_owner.get(id, "")):
			_punch[id] = 1.18
			if str(_prev_owner.get(id, "")) != "" and sim.state == "playing":
				AudioHooks.play_sfx("capture")
			_paint_tower(node, team)
		_prev_count[id] = int(entry.count)
		_prev_owner[id] = team
		_punch[id] = lerpf(float(_punch[id]), 1.0, 1.0 - exp(-10.0 * delta))

		var spec: Dictionary = sim.spec_of(entry)
		var show_count := bool(spec.can_be_targeted)
		var factory := bool(node.get_meta("factory"))
		var amounts := TowerLook.floor_amounts(int(entry.count))
		var cursor := 0.0
		for i in 3:
			var amount := float(amounts[i])
			var floor: MeshInstance3D = node.get_node("Floor%d" % i)
			var lip: MeshInstance3D = node.get_node("Lip%d" % i)
			var show_floor := show_count and amount > 0.02
			floor.visible = show_floor
			lip.visible = show_floor and not factory
			if not show_floor:
				continue
			var height := FLOOR_H * amount
			var widen := 1.0 - float(i) * 0.06
			if factory:
				floor.scale = Vector3(widen, height, widen)
			else:
				floor.scale = Vector3(widen, height, widen)
			floor.position = Vector3(0, cursor + height * 0.5, 0)
			lip.scale = Vector3(1.02 * widen, 1.0, 1.02 * widen)
			lip.position = Vector3(0, cursor + height + 0.04, 0)
			cursor = cursor + height + 0.07
		if factory:
			var chimney: MeshInstance3D = node.get_node("Chimney")
			chimney.scale = Vector3(0.22, maxf(cursor, 0.4) + 0.55, 0.22)
			chimney.position = Vector3(0.78, chimney.scale.y * 0.5, 0.62)
			var bay: Node3D = node.get_node("Bay")
			bay.position = Vector3(-0.2, 0.02, 1.35)
			bay.rotation.y = PI
		var bob := sin(sim.elapsed * 2.2 + float(hash(id)) * 0.001) * 0.04
		var capy: Node3D = node.get_node("Capy")
		capy.position = Vector3(0, cursor + bob, 0)
		capy.rotation.y = PI
		var held: Node3D = capy.get_node("Sword")
		held.rotation = Vector3(-0.7, 0.2, -1.15)
		var count: Label3D = node.get_node("Count")
		count.visible = show_count
		count.text = str(int(entry.count))
		count.scale = Vector3.ONE * float(_punch[id])
		count.position = Vector3(0, maxf(0.45, cursor * 0.55), 0.95)
		var full := show_count and sim.is_full(entry)
		var badge: Label3D = node.get_node("MaxBadge")
		badge.visible = full
		badge.position = Vector3(0, cursor + 0.72, 0.2)
		var used := sim.outgoing(id).size()
		var gap := 0.22
		var start := -float(maxi(level - 1, 0)) * gap * 0.5
		for i in 3:
			var pip: MeshInstance3D = node.get_node("Pips/Pip%d" % i)
			pip.visible = show_count and i < level
			pip.position = Vector3(start + float(i) * gap, 0.16, 1.05)
			pip.material_override = _pip_material(i < used)
		var grab := 1.05 if id == _source_id and _mode == "link" else 1.0
		node.scale = Vector3.ONE * grab


func _paint_tower(node: Node3D, team: String) -> void:
	node.set_meta("team", team)
	var mat := _models.team_material(team)
	var lip := _lip_material(team)
	for i in 3:
		var floor: MeshInstance3D = node.get_node("Floor%d" % i)
		floor.material_override = mat
		var lip_node: MeshInstance3D = node.get_node("Lip%d" % i)
		lip_node.material_override = lip
	var capy: Node3D = node.get_node("Capy")
	var body: MeshInstance3D = capy.get_child(0)
	body.mesh = _models.soldier_mesh(team)
	if bool(node.get_meta("factory")):
		var bay: Node3D = node.get_node("Bay")
		var hull: MeshInstance3D = bay.get_child(0)
		hull.mesh = _models.tank_hull_mesh(team)
		var turret: Node3D = bay.get_node("Turret")
		var turret_mesh: MeshInstance3D = turret.get_child(0)
		turret_mesh.mesh = _models.tank_turret_mesh(team)


func _sync_links() -> void:
	var live := {}
	for link in sim.links:
		var id := int(link.id)
		live[id] = true
		var beam: MeshInstance3D = _links.get(id)
		if beam == null:
			beam = MeshInstance3D.new()
			beam.mesh = _beam_mesh
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_link_root.add_child(beam)
			_links[id] = beam
		var ends := sim.path_ends(str(link.source_id), str(link.target_id))
		_aim_beam(beam, _to_world(ends[0]), _to_world(ends[1]), 0.16)
		beam.material_override = _link_material(str(link.owner))
	var stale: Array = []
	for id in _links.keys():
		if not live.has(id):
			stale.append(id)
	for id in stale:
		_links[id].queue_free()
		_links.erase(id)


func _sync_soldiers() -> void:
	var live := {}
	for soldier in sim.soldiers:
		var swung := float(soldier.get("swing", -1.0))
		var showing_swing := swung >= 0.0 and sim.elapsed - swung < 0.36
		if bool(soldier.dead) and not showing_swing:
			continue
		var id := int(soldier.id)
		live[id] = true
		var unit: Node3D = _active.get(id)
		if unit == null:
			unit = _borrow_unit(str(soldier.get("kind", "soldier")), str(soldier.team))
			_active[id] = unit
			AudioHooks.play_sfx("spawn")
		_place_unit(unit, soldier)
	var stale: Array = []
	for id in _active.keys():
		if not live.has(id):
			stale.append(id)
	for id in stale:
		_recycle(_active[id])
		_active.erase(id)


func _place_unit(unit: Node3D, soldier: Dictionary) -> void:
	var ends := sim.path_ends(str(soldier.source_id), str(soldier.target_id))
	var a := _to_world(ends[0])
	var b := _to_world(ends[1])
	var along := a.lerp(b, clampf(float(soldier.progress), 0.0, 1.0))
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var side := Vector3.ZERO
	if flat.length_squared() > 0.0001:
		side = flat.normalized().cross(Vector3.UP)
	var bob := sin(sim.elapsed * 8.0 + float(soldier.id)) * 0.05
	unit.position = along + side * bob
	unit.position.y = 0.0
	if flat.length_squared() > 0.0004:
		unit.look_at(unit.position + flat, Vector3.UP)
		unit.rotate_y(PI)
	var kind := str(soldier.get("kind", "soldier"))
	if kind == "tank":
		unit.scale = Vector3(1.05, 1.05, 1.05)
		var turret: Node3D = unit.get_node("Turret")
		turret.rotation.y = sin(sim.elapsed * 1.6 + float(soldier.id)) * 0.18
	else:
		var wiggle := 1.0 + 0.04 * sin(sim.elapsed * 10.0 + float(soldier.id))
		unit.scale = Vector3(wiggle, 1.0 / wiggle, 1.0)
		var sword: Node3D = unit.get_node("Sword")
		var swung := float(soldier.get("swing", -1.0))
		if swung >= 0.0 and sim.elapsed - swung < 0.34:
			var k := (sim.elapsed - swung) / 0.34
			sword.rotation = Vector3(sin(k * PI) * -1.7, 0.0, -0.35)
		else:
			sword.rotation = Vector3(-0.4, 0.0, -0.55)


func _borrow_unit(kind: String, team: String) -> Node3D:
	var key := kind + ":" + team
	if not _pool.has(key):
		_pool[key] = []
	var list: Array = _pool[key]
	if not list.is_empty():
		var reused: Node3D = list.pop_back()
		reused.visible = true
		return reused
	var made := _models.make_tank(team) if kind == "tank" else _models.make_soldier(team)
	made.set_meta("pool", key)
	_units.add_child(made)
	return made


func _recycle(unit: Node3D) -> void:
	unit.visible = false
	var key := str(unit.get_meta("pool", "soldier:player"))
	if not _pool.has(key):
		_pool[key] = []
	_pool[key].append(unit)


func _any_tank() -> bool:
	for soldier in sim.soldiers:
		if bool(soldier.dead):
			continue
		if str(soldier.get("kind", "soldier")) == "tank":
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if _over or _paused or sim == null or sim.state != "playing":
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _pointer != -1:
				return
			_pointer = touch.index
			_begin(touch.position)
		elif touch.index == _pointer:
			_end(touch.position)
			_pointer = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _pointer:
			_drag(drag.position)


func _begin(screen: Vector2) -> void:
	var hit = _tower_at(screen)
	if hit != null and str(hit.owner) == "player" and sim.can_send_tower(hit):
		_mode = "link"
		_source_id = str(hit.id)
		_hover_id = ""
		_show_preview(screen)
	else:
		_mode = "slash"
		_source_id = ""
		_slash_prev = screen


func _drag(screen: Vector2) -> void:
	if _mode == "link":
		_show_preview(screen)
	elif _mode == "slash":
		if _slash_prev.distance_to(screen) >= 34.0:
			_slash(_slash_prev, screen)
		_slash_prev = screen


func _end(screen: Vector2) -> void:
	if _mode == "link" and _source_id != "":
		var hit = _tower_at(screen)
		if hit != null and str(hit.id) != _source_id:
			var result: Dictionary = sim.try_connect(_source_id, str(hit.id))
			if bool(result.get("ok", false)):
				AudioHooks.play_sfx("connect")
			else:
				_explain(str(result.get("reason", "")))
	_mode = ""
	_source_id = ""
	_hover_id = ""
	_preview.visible = false
	_hover_ring.visible = false


func _show_preview(screen: Vector2) -> void:
	var source = sim.tower(_source_id)
	if source.is_empty():
		return
	var from := _to_world(source.pos)
	from.y = 0.08
	var ground := _ground_point(screen)
	var hit = _tower_at(screen)
	var valid := hit != null and str(hit.id) != _source_id
	_preview.material_override = _preview_material(valid)
	_aim_beam(_preview, from, Vector3(ground.x, 0.08, ground.z), 0.12)
	_preview.visible = true
	if valid:
		_hover_id = str(hit.id)
		_hover_ring.visible = true
		_hover_ring.position = _to_world(hit.pos) + Vector3(0, 0.08, 0)
	else:
		_hover_id = ""
		_hover_ring.visible = false


func _slash(a: Vector2, b: Vector2) -> void:
	var world_a := _to_sim(_ground_point(a))
	var world_b := _to_sim(_ground_point(b))
	var cut_ids: Array = []
	for link in sim.links:
		if str(link.owner) != "player":
			continue
		var ends := sim.path_ends(str(link.source_id), str(link.target_id))
		if Geom.segments_near(world_a, world_b, ends[0], ends[1], 28.0):
			cut_ids.append(int(link.id))
	for link_id in cut_ids:
		if sim.try_cut(link_id):
			AudioHooks.play_sfx("cut")


func _explain(reason: String) -> void:
	var text := ""
	match reason:
		"link_cap":
			text = "Link limit reached. Swipe that tower's line to cut one."
		"blocked":
			text = "Bramble is in the way."
		"no_send":
			text = "That building cannot send troops."
		"no_target":
			text = "You cannot link to that."
		_:
			text = ""
	if text != "":
		_toast.text = text
		_toast.visible = true
		_toast_time = 1.8


func _tower_at(screen: Vector2):
	if _camera == null:
		return null
	var origin := _camera.project_ray_origin(screen)
	var dir := _camera.project_ray_normal(screen)
	var best = null
	var best_t := 1.0e9
	for entry in sim.towers:
		var base := _to_world(entry.pos)
		var height := maxf(1.1, _stack_world(int(entry.count)) + 0.8)
		var dist := _ray_column(origin, dir, base, 0.95, height)
		if dist >= 0.0 and dist < best_t:
			best_t = dist
			best = entry
	return best


func _stack_world(count: int) -> float:
	var amounts := TowerLook.floor_amounts(count)
	var total := 0.0
	for amount in amounts:
		if float(amount) > 0.02:
			total += FLOOR_H * float(amount) + 0.07
	return total


func _ray_column(origin: Vector3, dir: Vector3, base: Vector3, radius: float, height: float) -> float:
	var ox := origin.x - base.x
	var oz := origin.z - base.z
	var a := dir.x * dir.x + dir.z * dir.z
	if a < 0.000001:
		return -1.0
	var b := 2.0 * (ox * dir.x + oz * dir.z)
	var c := ox * ox + oz * oz - radius * radius
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var root := sqrt(disc)
	var t0 := (-b - root) / (2.0 * a)
	var t1 := (-b + root) / (2.0 * a)
	var t := t0 if t0 >= 0.0 else t1
	if t < 0.0:
		return -1.0
	var y := origin.y + dir.y * t
	if y < base.y - 0.2 or y > base.y + height:
		return -1.0
	return t


func _ground_point(screen: Vector2) -> Vector3:
	if _camera == null:
		return Vector3.ZERO
	var origin := _camera.project_ray_origin(screen)
	var dir := _camera.project_ray_normal(screen)
	if absf(dir.y) < 0.00001:
		return Vector3(origin.x, 0, origin.z)
	var t := -origin.y / dir.y
	if t < 0.0:
		t = 0.0
	return origin + dir * t


func _to_world(sim_pos: Vector2) -> Vector3:
	var field := BattleRules.FIELD_SIZE
	return Vector3((sim_pos.x - field.x * 0.5) * WORLD_SCALE, 0.0, (sim_pos.y - field.y * 0.5) * WORLD_SCALE)


func _to_sim(world: Vector3) -> Vector2:
	var field := BattleRules.FIELD_SIZE
	return Vector2(world.x / WORLD_SCALE + field.x * 0.5, world.z / WORLD_SCALE + field.y * 0.5)


func _fit_camera(force: bool = false) -> void:
	if _camera == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 10.0:
		return
	if not force and vp.distance_to(_view_size) < 1.0:
		return
	_view_size = vp
	# Fixed portrait framing. 52 degrees off the horizontal, far enough that
	# the whole meadow, including the tallest tower, sits inside a phone screen.
	var pitch := deg_to_rad(PITCH_DEG)
	var dist := 44.0
	if vp.x > vp.y:
		dist = 30.0
	var target := Vector3(0, 0.7, 0)
	_camera.fov = 36.0
	var eye := target + Vector3(0, sin(pitch), cos(pitch)) * dist
	# One transform, so the camera cannot keep a flat forward from the old pose.
	_camera.global_transform = _look_transform(eye, target)


func _look_transform(eye: Vector3, target: Vector3) -> Transform3D:
	var forward := target - eye
	if forward.length_squared() < 0.0001:
		forward = Vector3(0, -1, -0.2)
	forward = forward.normalized()
	var z_axis := -forward
	var x_axis := Vector3.UP.cross(z_axis)
	if x_axis.length_squared() < 0.0001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Transform3D(Basis(x_axis, y_axis, z_axis), eye)


func _aim_beam(beam: MeshInstance3D, a: Vector3, b: Vector3, thickness: float) -> void:
	var delta := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := delta.length()
	if length < 0.04:
		beam.visible = false
		return
	beam.visible = true
	beam.position = Vector3((a.x + b.x) * 0.5, 0.08, (a.z + b.z) * 0.5)
	beam.look_at(beam.position + delta, Vector3.UP)
	beam.scale = Vector3(thickness, 0.045, length)


func _solid(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _pip_material(used: bool) -> StandardMaterial3D:
	if used:
		if _pip_gold == null:
			_pip_gold = _solid(Palette.GOLD, 0.45)
		return _pip_gold
	if _pip_idle == null:
		_pip_idle = _solid(Color(1, 1, 1, 0.7), 0.5)
	return _pip_idle


func _preview_material(valid: bool) -> StandardMaterial3D:
	if valid:
		if _preview_ok == null:
			_preview_ok = _solid(Palette.PLAYER, 0.35)
		return _preview_ok
	if _preview_dim == null:
		_preview_dim = _solid(Color(0.75, 0.78, 0.84), 0.45)
	return _preview_dim


func _lip_material(team: String) -> StandardMaterial3D:
	if _lip_mats.has(team):
		return _lip_mats[team]
	var mat := _solid(Palette.team(team).lightened(0.38), 0.4)
	_lip_mats[team] = mat
	return mat


func _link_material(owner: String) -> StandardMaterial3D:
	if _link_mats.has(owner):
		return _link_mats[owner]
	var color := Palette.ENEMY if owner == "enemy" else Palette.PLAYER
	var mat := _solid(color, 0.35)
	_link_mats[owner] = mat
	return mat


func _show_error(message: String) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = message
	label.position = Vector2(80, 400)
	layer.add_child(label)
