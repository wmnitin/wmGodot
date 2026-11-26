extends Node3D

signal match_finished(victory: bool)
signal restart_requested

## Sim space stays in pixels. The view maps that onto a small 3D meadow.
const WORLD_SCALE := 0.012
const PITCH_DEG := 48.0
const FLOOR_H := 0.98

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
var _preview_ok: StandardMaterial3D
var _preview_dim: StandardMaterial3D
var _preview_blocked: StandardMaterial3D
var _blob_mat: StandardMaterial3D
var _blob_mesh: PlaneMesh
var _dash_mesh: BoxMesh
var _smoke_mat: StandardMaterial3D


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
	env.background_color = Color("8EC6F2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("FFE4C0")
	env.ambient_light_energy = 0.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = Color("FFE0A8")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.shadow_blur = 1.8
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 0.8
	add_child(sun)
	_make_blob()

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
	ground.material_override = _solid(Color("63C63A"), 0.95)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	var field := BattleRules.FIELD_SIZE * WORLD_SCALE
	var meadow := MeshInstance3D.new()
	meadow.position = Vector3(0, 0.02, 0)
	meadow.material_override = _grass_material()
	meadow.mesh = _grass_mesh(field)
	meadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(meadow)
	_add_sand(field)
	_add_grass(field)
	_add_decor(field)
	_add_hedges()

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
	_hover_ring.mesh = _models.chamfer_mesh()
	_hover_ring.material_override = _solid(Palette.GOLD, 0.45)
	_hover_ring.scale = Vector3(1.7, 0.08, 1.7)
	_hover_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hover_ring.visible = false
	add_child(_hover_ring)


func _grass_mesh(field: Vector2) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 22
	var nz := 32
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for z in nz + 1:
		for x in nx + 1:
			var u := float(x) / float(nx)
			var v := float(z) / float(nz)
			var n := sin(u * 17.0) * sin(v * 13.0) * 0.5 + sin(u * 6.0 + v * 8.0) * 0.35 + sin(u * 23.0 + 1.7) * sin(v * 19.0) * 0.2
			var mix := clampf(n * 0.5 + 0.5, 0.0, 1.0)
			var color := Color("3EAE30").lerp(Color("7ED85A"), mix)
			verts.append(Vector3((u - 0.5) * field.x, 0.0, (v - 0.5) * field.y))
			cols.append(color)
	for z in nz:
		for x in nx:
			var i00 := z * (nx + 1) + x
			var i10 := i00 + 1
			var i01 := i00 + nx + 1
			var i11 := i01 + 1
			_grass_tri(tool, verts, cols, i00, i10, i11)
			_grass_tri(tool, verts, cols, i00, i11, i01)
	return tool.commit()


func _grass_tri(tool: SurfaceTool, verts: PackedVector3Array, cols: PackedColorArray, a: int, b: int, c: int) -> void:
	tool.set_normal(Vector3.UP)
	tool.set_color(cols[a])
	tool.add_vertex(verts[a])
	tool.set_normal(Vector3.UP)
	tool.set_color(cols[b])
	tool.add_vertex(verts[b])
	tool.set_normal(Vector3.UP)
	tool.set_color(cols[c])
	tool.add_vertex(verts[c])


func _grass_material() -> StandardMaterial3D:
	var mat := _models.vertex_material()
	mat.roughness = 0.92
	return mat


func _add_sand(field: Vector2) -> void:
	for side in [-1.0, 1.0]:
		var strip := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.orientation = PlaneMesh.FACE_Y
		mesh.size = Vector2(field.x + 2.4, 2.1)
		strip.mesh = mesh
		strip.position = Vector3(0, 0.012, side * (field.y * 0.5 + 0.55))
		strip.material_override = _solid(Color("E7C98A"), 0.95)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(strip)


func _add_grass(_field: Vector2) -> void:
	pass


func _add_decor(field: Vector2) -> void:
	var edge := field.y * 0.5 + 0.35
	var props := [
		{"at": Vector3(-2.2, 0, -edge), "kind": "crate"},
		{"at": Vector3(1.4, 0, -edge - 0.15), "kind": "barrel"},
		{"at": Vector3(2.6, 0, -edge + 0.1), "kind": "rock"},
		{"at": Vector3(-0.2, 0, -edge + 0.25), "kind": "log"},
		{"at": Vector3(-3.0, 0, edge), "kind": "tyre"},
		{"at": Vector3(-1.1, 0, edge + 0.2), "kind": "rock"},
		{"at": Vector3(1.8, 0, edge), "kind": "crate"},
		{"at": Vector3(3.1, 0, edge - 0.1), "kind": "barrel"},
		{"at": Vector3(0.2, 0, edge + 0.15), "kind": "log"},
	]
	for prop in props:
		_drop_prop(prop.at, str(prop.kind))
	for i in 7:
		var z := lerpf(-field.y * 0.42, field.y * 0.42, float(i) / 6.0)
		_plant_pine(Vector3(-field.x * 0.56, 0, z), 0.75 + float(i % 3) * 0.08)
		_plant_pine(Vector3(field.x * 0.56, 0, z + 0.35), 0.8 + float((i + 1) % 3) * 0.07)


func _add_hedges() -> void:
	for obstacle in sim.obstacles:
		if str(obstacle.get("shape", "")) != "circle":
			continue
		var center := _to_world(obstacle.pos)
		for i in 7:
			var along := float(i) - 3.0
			_plant_pine(center + Vector3(along * 0.34, 0, sin(along) * 0.12), 0.72 + float(i % 2) * 0.12)


func _plant_cluster(center: Vector3, count: int) -> void:
	for i in count:
		_plant_pine(center + Vector3(float(i) * 0.3, 0, 0), 0.8)


func _plant_pine(at: Vector3, scale: float) -> void:
	var pine := MeshInstance3D.new()
	pine.mesh = _models.pine_mesh()
	pine.material_override = _models.vertex_material()
	pine.position = at
	pine.scale = Vector3.ONE * scale
	pine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pine)


func _drop_prop(at: Vector3, kind: String) -> void:
	var node := MeshInstance3D.new()
	node.mesh = _models.chamfer_mesh()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	match kind:
		"rock":
			node.scale = Vector3(0.55, 0.32, 0.42)
			node.position.y = 0.16
			node.material_override = _models.flat_material(Color("8D939C"))
		"crate":
			node.scale = Vector3(0.42, 0.42, 0.42)
			node.position.y = 0.22
			node.material_override = _models.flat_material(Color("C4843A"))
		"barrel":
			node.scale = Vector3(0.32, 0.4, 0.32)
			node.position.y = 0.2
			node.material_override = _models.flat_material(Color("8A5A32"))
		"log":
			node.scale = Vector3(0.7, 0.16, 0.16)
			node.position.y = 0.1
			node.rotation.y = 0.4
			node.material_override = _models.flat_material(Color("7A4E2A"))
		"tyre":
			node.scale = Vector3(0.4, 0.16, 0.4)
			node.position.y = 0.28
			node.material_override = _models.flat_material(Color("2C3138"))
			var mid := MeshInstance3D.new()
			mid.mesh = _models.chamfer_mesh()
			mid.scale = Vector3(0.4, 0.16, 0.4)
			mid.position = at + Vector3(0, 0.12, 0)
			mid.material_override = _models.flat_material(Color("3A414A"))
			mid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mid)
		_:
			node.scale = Vector3(0.3, 0.3, 0.3)
	add_child(node)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	UiKit.full_rect(root)

	var you_pill := _hud_pill(Palette.PLAYER)
	root.add_child(you_pill)
	you_pill.position = Vector2(28, 28)
	you_pill.size = Vector2(280, 92)
	_you_label = you_pill.get_node("Text")

	var name_pill := _hud_pill(Color("1B3A6B"))
	root.add_child(name_pill)
	name_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	name_pill.offset_left = -280
	name_pill.offset_right = 280
	name_pill.offset_top = 28
	name_pill.offset_bottom = 120
	_name_label = name_pill.get_node("Text")
	_name_label.text = sim.level_name
	UiKit.outlined(_name_label, Palette.CREAM, Palette.DEEP, 40)

	var red_pill := _hud_pill(Palette.ENEMY)
	root.add_child(red_pill)
	red_pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	red_pill.offset_left = -308
	red_pill.offset_right = -28
	red_pill.offset_top = 28
	red_pill.offset_bottom = 120
	_red_label = red_pill.get_node("Text")

	var restart := UiKit.button("Restart", Color("3E4C63"), 30, 84)
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


func _hud_pill(color: Color) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(46)
	style.border_width_bottom = 8
	style.border_color = color.darkened(0.25)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.name = "Text"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.outlined(label, Palette.CREAM, color.darkened(0.45), 42)
	panel.add_child(label)
	return panel


func _ensure_burst(unit: Node3D) -> void:
	if bool(unit.get_meta("burst", false)):
		return
	unit.set_meta("burst", true)
	var root := Node3D.new()
	root.name = "Burst"
	root.position = unit.global_position + Vector3(0, 0.4, 0)
	_units.add_child(root)
	unit.set_meta("burst_node", root)
	for i in 6:
		var dust := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.12
		ball.height = 0.22
		ball.radial_segments = 8
		ball.rings = 3
		dust.mesh = ball
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("E7D2B0") if i % 2 == 0 else Color("C4A574")
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dust.material_override = mat
		dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * float(i) / 6.0
		dust.set_meta("dir", Vector3(cos(angle), 0.35, sin(angle)))
		root.add_child(dust)
	for i in 4:
		var star := MeshInstance3D.new()
		star.mesh = _models.chamfer_mesh()
		var spark := StandardMaterial3D.new()
		spark.albedo_color = Color("FFF2B0")
		spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		star.material_override = spark
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * float(i) / 4.0 + 0.4
		star.set_meta("dir", Vector3(cos(angle) * 0.7, 0.8, sin(angle) * 0.7))
		root.add_child(star)


func _tick_burst(unit: Node3D, age: float) -> void:
	if not unit.has_meta("burst_node"):
		return
	var burst: Node = unit.get_meta("burst_node")
	if not (burst is Node3D) or not is_instance_valid(burst):
		return
	var k := clampf((age - 0.12) / 0.42, 0.0, 1.0)
	for child in burst.get_children():
		var dir: Vector3 = child.get_meta("dir", Vector3.UP)
		child.position = dir * (0.15 + k * 0.7)
		var fade := 1.0 - k
		child.scale = Vector3.ONE * (0.15 + k * 0.55) * maxf(fade, 0.05)
		var mat := child.material_override as StandardMaterial3D
		if mat:
			var color := mat.albedo_color
			color.a = fade
			mat.albedo_color = color


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
	node.add_child(_make_blob_node(2.8 if factory else 2.3))

	var mat := _models.team_material(team)
	var band := _models.flat_material(Color("F4F7FB"))
	var slit_mat := _models.flat_material(Color("243044"))
	for i in 3:
		var floor := Node3D.new()
		floor.name = "Floor%d" % i
		var body := _block("Body", mat)
		var stripe := _block("Band", band)
		var frame := _block("Frame", band)
		var slit := _block("Slit", slit_mat)
		floor.add_child(body)
		floor.add_child(stripe)
		floor.add_child(frame)
		floor.add_child(slit)
		node.add_child(floor)
	var door_frame := _block("DoorFrame", _models.shade_material(team, 0.35))
	node.add_child(door_frame)
	var door := _block("Door", slit_mat)
	node.add_child(door)
	var base := _block("Base", _models.shade_material(team, 0.45))
	node.add_child(base)
	var roof := _block("Roof", mat)
	node.add_child(roof)
	var lip := _block("RoofLip", mat)
	node.add_child(lip)
	var flag := Node3D.new()
	flag.name = "Flag"
	flag.visible = false
	var pole := _block("Pole", _models.flat_material(Color("5C4632")))
	pole.scale = Vector3(0.06, 0.7, 0.06)
	pole.position = Vector3(0, 0.35, 0)
	var cloth := _block("Cloth", _models.flat_material(Palette.GOLD))
	cloth.scale = Vector3(0.36, 0.2, 0.05)
	cloth.position = Vector3(0.18, 0.55, 0)
	flag.add_child(pole)
	flag.add_child(cloth)
	node.add_child(flag)
	if factory:
		var chimney := _block("Chimney", _models.flat_material(Color("6A5344")))
		node.add_child(chimney)
		for s in 3:
			var puff := MeshInstance3D.new()
			puff.name = "Smoke%d" % s
			var ball := SphereMesh.new()
			ball.radius = 0.12
			ball.height = 0.24
			ball.radial_segments = 8
			ball.rings = 4
			puff.mesh = ball
			puff.material_override = _smoke_material()
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(puff)

	var count := Label3D.new()
	count.name = "Count"
	count.font_size = 96
	count.pixel_size = 0.012
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

	var dots := Label3D.new()
	dots.name = "Dots"
	dots.font_size = 72
	dots.pixel_size = 0.01
	dots.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dots.modulate = Color.WHITE
	dots.outline_size = 8
	dots.outline_modulate = Palette.INK
	dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(dots)
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
		var floors := TowerLook.floor_count(int(entry.count))
		var cursor := 0.0
		var wide := 3.05 if factory else 2.2
		var deep := 2.25 if factory else 2.05
		var floor_h := 0.72 if factory else FLOOR_H
		for i in 3:
			var floor: Node3D = node.get_node("Floor%d" % i)
			var show_floor := show_count and i < floors
			floor.visible = show_floor
			if not show_floor:
				continue
			var body: MeshInstance3D = floor.get_node("Body")
			body.scale = Vector3(wide - float(i) * 0.08, floor_h, deep - float(i) * 0.08)
			body.position = Vector3(0, cursor + floor_h * 0.5, 0)
			var band: MeshInstance3D = floor.get_node("Band")
			band.scale = Vector3(body.scale.x * 1.08, 0.16, body.scale.z * 1.08)
			band.position = Vector3(0, cursor + floor_h - 0.02, 0)
			var frame: MeshInstance3D = floor.get_node("Frame")
			frame.scale = Vector3(body.scale.x * 0.5, 0.12, 0.1)
			frame.position = Vector3(0, cursor + floor_h * 0.55, body.scale.z * 0.48)
			var slit: MeshInstance3D = floor.get_node("Slit")
			slit.scale = Vector3(body.scale.x * 0.4, 0.07, 0.06)
			slit.position = Vector3(0, cursor + floor_h * 0.55, body.scale.z * 0.52)
			cursor += floor_h
		var roof: MeshInstance3D = node.get_node("Roof")
		roof.visible = show_count
		roof.scale = Vector3(wide + 0.28, 0.2, deep + 0.28)
		roof.position = Vector3(0, cursor + 0.1, 0)
		var lip: MeshInstance3D = node.get_node("RoofLip")
		lip.visible = show_count
		lip.scale = Vector3(wide + 0.5, 0.08, deep + 0.5)
		lip.position = Vector3(0, cursor + 0.02, 0)
		var base: MeshInstance3D = node.get_node("Base")
		base.visible = show_count
		base.scale = Vector3(wide * 1.04, 0.16, deep * 1.04)
		base.position = Vector3(0, 0.08, 0)
		var door: MeshInstance3D = node.get_node("Door")
		var frame_door: MeshInstance3D = node.get_node("DoorFrame")
		door.visible = show_count
		frame_door.visible = show_count
		door.scale = Vector3(0.62 if factory else 0.38, 0.48 if factory else 0.42, 0.08)
		frame_door.scale = door.scale + Vector3(0.14, 0.12, 0.02)
		door.position = Vector3(0, door.scale.y * 0.5, deep * 0.52)
		frame_door.position = Vector3(0, frame_door.scale.y * 0.45, deep * 0.48)
		var flag: Node3D = node.get_node("Flag")
		flag.visible = show_count and sim.is_full(entry)
		flag.position = Vector3(wide * 0.38, cursor + 0.15, -deep * 0.2)
		if factory:
			var chimney: MeshInstance3D = node.get_node("Chimney")
			chimney.scale = Vector3(0.22, 0.72, 0.22)
			chimney.position = Vector3(wide * 0.32, cursor + 0.4, -deep * 0.22)
			for s in 3:
				var puff: MeshInstance3D = node.get_node("Smoke%d" % s)
				var rise := fmod(sim.elapsed * 0.35 + float(s) * 0.33, 1.0)
				puff.position = chimney.position + Vector3(0, 0.4 + rise * 0.7, 0)
				puff.scale = Vector3.ONE * (0.4 + rise * 0.85)
		var roof_y := cursor + 0.22
		var count: Label3D = node.get_node("Count")
		count.visible = show_count
		count.text = str(int(entry.count))
		count.scale = Vector3.ONE * float(_punch[id])
		count.position = Vector3(0, roof_y + 0.55, 0.05)
		var full := show_count and sim.is_full(entry)
		var badge: Label3D = node.get_node("MaxBadge")
		badge.visible = full
		badge.position = Vector3(0.42, roof_y + 0.42, 0)
		var used := sim.outgoing(id).size()
		var marks := ""
		for i in floors:
			marks += "● " if i < used else "○ "
		var dots: Label3D = node.get_node("Dots")
		dots.visible = show_count
		dots.text = marks.strip_edges()
		dots.position = Vector3(0, roof_y + 0.18, 0.35)
		var grab := 1.05 if id == _source_id and _mode == "link" else 1.0
		node.scale = Vector3.ONE * grab


func _paint_tower(node: Node3D, team: String) -> void:
	node.set_meta("team", team)
	var mat := _models.team_material(team)
	for i in 3:
		var body: MeshInstance3D = node.get_node("Floor%d/Body" % i)
		body.material_override = mat
	var roof: MeshInstance3D = node.get_node("Roof")
	roof.material_override = mat
	node.get_node("RoofLip").material_override = mat
	node.get_node("Base").material_override = _models.shade_material(team, 0.45)
	node.get_node("DoorFrame").material_override = _models.shade_material(team, 0.28)


func _sync_links() -> void:
	var live := {}
	var period := 0.62
	var dash_len := 0.28
	var shift := fmod(sim.elapsed * 0.75, period)
	for link in sim.links:
		var id := int(link.id)
		live[id] = true
		var ribbon: Node3D = _links.get(id)
		if ribbon == null:
			ribbon = Node3D.new()
			var bed := MeshInstance3D.new()
			bed.name = "Bed"
			bed.mesh = _dash_box()
			bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ribbon.add_child(bed)
			_link_root.add_child(ribbon)
			_links[id] = ribbon
		var ends := sim.path_ends(str(link.source_id), str(link.target_id))
		var a := _to_world(ends[0])
		var b := _to_world(ends[1])
		var delta := Vector3(b.x - a.x, 0.0, b.z - a.z)
		var length := delta.length()
		var dir := delta / length if length > 0.05 else Vector3(0, 0, 1)
		var count := int(length / period) + 2
		while ribbon.get_child_count() < count + 1:
			var dash := MeshInstance3D.new()
			dash.mesh = _dash_box()
			dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ribbon.add_child(dash)
		var mat := _link_material(str(link.owner))
		var bed: MeshInstance3D = ribbon.get_node("Bed")
		bed.material_override = mat
		bed.visible = length > 0.05
		if bed.visible:
			var mid_bed := (a + b) * 0.5
			bed.position = Vector3(mid_bed.x, 0.035, mid_bed.z)
			bed.look_at(bed.position + dir, Vector3.UP)
			bed.scale = Vector3(0.42, 0.02, length)
		for i in ribbon.get_child_count():
			var dash: MeshInstance3D = ribbon.get_child(i)
			if dash.name == "Bed":
				continue
			var along := shift + float(i) * period
			if along > length - dash_len * 0.35:
				dash.visible = false
				continue
			dash.visible = true
			dash.material_override = mat
			var mid := a + dir * (along + dash_len * 0.5)
			dash.position = Vector3(mid.x, 0.055, mid.z)
			if dir.length_squared() > 0.0001:
				dash.look_at(dash.position + dir, Vector3.UP)
			# Wide dash, pinched at the front so it reads as a chevron.
			dash.scale = Vector3(0.34, 0.03, dash_len)
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
		var showing_swing := swung >= 0.0 and sim.elapsed - swung < 0.62
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
	var swung := float(soldier.get("swing", -1.0))
	var age := sim.elapsed - swung if swung >= 0.0 else -1.0
	var dying := bool(soldier.dead)
	var fx := str(soldier.get("fx", ""))
	var sway := 0.0 if dying else sin(sim.elapsed * 9.0 + float(soldier.id)) * 0.035
	unit.position = along + side * sway
	var step := sin(sim.elapsed * 11.0 + float(soldier.id))
	unit.position.y = 0.0 if dying else absf(step) * 0.09
	if flat.length_squared() > 0.0004:
		unit.look_at(unit.position + flat, Vector3.UP)
		unit.rotate_y(PI)
	if not dying:
		unit.rotate_object_local(Vector3.RIGHT, step * 0.14)
	var kind := str(soldier.get("kind", "soldier"))
	var base_scale := 1.45 if kind == "tank" else 1.55
	if kind == "tank":
		var turret: Node3D = unit.get_node("Turret")
		turret.rotation.y = sin(sim.elapsed * 1.6 + float(soldier.id)) * 0.18
		var flash := 1.0
		if not dying and age >= 0.0 and age < 0.28:
			flash = 1.0 + 0.16 * sin(age * 48.0)
		unit.scale = Vector3.ONE * base_scale * flash
		for puff_i in 2:
			var exhaust := unit.get_node_or_null("Exhaust%d" % puff_i)
			if exhaust == null:
				continue
			var puffing := float(soldier.progress) < 0.22 and not dying
			exhaust.visible = puffing
			if puffing:
				var rise := fmod(sim.elapsed * 1.4 + float(puff_i) * 0.5, 1.0)
				exhaust.position = Vector3(0.0, 0.35 + rise * 0.35, -0.35)
				exhaust.scale = Vector3.ONE * (0.4 + rise)
	else:
		var sword: Node3D = unit.get_node("Sword")
		if dying and fx == "door":
			unit.scale = Vector3.ONE * 0.01
			sword.visible = false
			_ensure_burst(unit)
		elif dying and age >= 0.0:
			if age < 0.2:
				sword.visible = true
				sword.rotation = Vector3(-0.9 + sin(age / 0.2 * PI) * -1.3, 0.15, -0.35)
				unit.scale = Vector3.ONE * base_scale
			else:
				var fall := clampf((age - 0.2) / 0.38, 0.0, 1.0)
				sword.visible = false
				unit.rotate_object_local(Vector3.FORWARD, fall * 1.4)
				unit.scale = Vector3.ONE * base_scale * (1.0 - fall * 0.92)
				unit.position.y = lerpf(0.0, 0.05, fall)
				_ensure_burst(unit)
		else:
			sword.visible = true
			sword.rotation = Vector3(-0.9, 0.15, -0.35)
			var wiggle := 1.0 + 0.03 * step
			unit.scale = Vector3(wiggle, 1.0 / wiggle, 1.0) * base_scale
	_tick_burst(unit, age)


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
	made.add_child(_make_blob_node(1.15 if kind == "tank" else 0.7))
	_units.add_child(made)
	return made


func _recycle(unit: Node3D) -> void:
	unit.visible = false
	unit.rotation = Vector3.ZERO
	if unit.has_meta("burst_node"):
		var burst: Node = unit.get_meta("burst_node")
		if is_instance_valid(burst):
			burst.queue_free()
	if unit.has_meta("burst"):
		unit.remove_meta("burst")
	if unit.has_meta("burst_node"):
		unit.remove_meta("burst_node")
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
	var blocked := valid and sim.path_blocked(_source_id, str(hit.id))
	if blocked:
		_preview.material_override = _preview_blocked_material()
	else:
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
			text = "That line is blocked."
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
		var height := _stack_world(int(entry.count)) + 0.9
		var half := Vector3(1.85, height * 0.5, 1.85)
		var center := base + Vector3(0, half.y, 0)
		var dist := _ray_box(origin, dir, center, half)
		if dist >= 0.0 and dist < best_t:
			best_t = dist
			best = entry
	if best != null:
		return best
	var vp := get_viewport().get_visible_rect().size
	var reach := maxf(96.0, vp.y * 0.055)
	var best_d := reach
	for entry in sim.towers:
		var base := _to_world(entry.pos)
		var top := base + Vector3(0, _stack_world(int(entry.count)) + 0.4, 0)
		if _camera.is_position_behind(base) and _camera.is_position_behind(top):
			continue
		var foot := _camera.unproject_position(base)
		var roof := _camera.unproject_position(top)
		var dist := Geom.point_segment_distance(screen, foot, roof)
		if dist < best_d:
			best_d = dist
			best = entry
	return best


func _stack_world(count: int) -> float:
	return FLOOR_H * float(TowerLook.floor_count(count)) + 0.16


func _ray_box(origin: Vector3, dir: Vector3, center: Vector3, half: Vector3) -> float:
	var t0 := _axis_enter(origin.x - center.x, dir.x, half.x, 0.0, 1.0e6)
	if t0.y < 0.0:
		return -1.0
	var t1 := _axis_enter(origin.y - center.y, dir.y, half.y, t0.x, t0.y)
	if t1.y < 0.0:
		return -1.0
	var t2 := _axis_enter(origin.z - center.z, dir.z, half.z, t1.x, t1.y)
	if t2.y < 0.0:
		return -1.0
	if t2.x >= 0.0:
		return t2.x
	return t2.y if t2.y >= 0.0 else -1.0


func _axis_enter(origin: float, delta: float, half: float, t0: float, t1: float) -> Vector2:
	if absf(delta) < 0.000001:
		if absf(origin) > half:
			return Vector2(t0, -1.0)
		return Vector2(t0, t1)
	var inv := 1.0 / delta
	var ta := (-half - origin) * inv
	var tb := (half - origin) * inv
	if ta > tb:
		var swap := ta
		ta = tb
		tb = swap
	var lo := maxf(t0, ta)
	var hi := minf(t1, tb)
	if lo > hi:
		return Vector2(lo, -1.0)
	return Vector2(lo, hi)


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
	var dist := 21.0
	if vp.x > vp.y:
		dist = 16.0
	var target := Vector3(0, 0.9, 0.2)
	_camera.fov = 46.0
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
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _block(node_name: String, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = _models.chamfer_mesh()
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A slightly smaller solid box fills any gap in the bevel so the bunker stays closed.
	var core := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.86, 0.86, 0.86)
	core.mesh = box
	core.material_override = mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.add_child(core)
	return mesh


func _make_blob() -> void:
	_blob_mesh = PlaneMesh.new()
	_blob_mesh.orientation = PlaneMesh.FACE_Y
	_blob_mesh.size = Vector2(1, 1)
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y in 48:
		for x in 48:
			var d := Vector2(float(x) - 23.5, float(y) - 23.5).length() / 24.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			image.set_pixel(x, y, Color(0, 0, 0, a * 0.5))
	var tex := ImageTexture.create_from_image(image)
	_blob_mat = StandardMaterial3D.new()
	_blob_mat.albedo_texture = tex
	_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blob_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dash_mesh = BoxMesh.new()
	_dash_mesh.size = Vector3(1, 1, 1)


func _make_blob_node(size: float) -> MeshInstance3D:
	if _blob_mesh == null:
		_make_blob()
	var blob := MeshInstance3D.new()
	blob.name = "Shadow"
	blob.mesh = _blob_mesh
	blob.material_override = _blob_mat
	blob.scale = Vector3(size, 1.0, size * 0.72)
	blob.position = Vector3(0.08, 0.03, 0.1)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return blob


func _smoke_material() -> StandardMaterial3D:
	if _smoke_mat == null:
		_smoke_mat = StandardMaterial3D.new()
		_smoke_mat.albedo_color = Color(0.95, 0.96, 0.98, 0.4)
		_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _smoke_mat


func _dash_box() -> BoxMesh:
	if _dash_mesh == null:
		_dash_mesh = BoxMesh.new()
		_dash_mesh.size = Vector3(1, 1, 1)
	return _dash_mesh


func _preview_material(valid: bool) -> StandardMaterial3D:
	if valid:
		if _preview_ok == null:
			_preview_ok = _glass(Color(Palette.PLAYER.r, Palette.PLAYER.g, Palette.PLAYER.b, 0.72))
		return _preview_ok
	if _preview_dim == null:
		_preview_dim = _glass(Color(0.75, 0.78, 0.84, 0.55))
	return _preview_dim


func _preview_blocked_material() -> StandardMaterial3D:
	if _preview_blocked == null:
		_preview_blocked = _glass(Color(0.95, 0.28, 0.32, 0.8))
	return _preview_blocked


func _glass(color: Color) -> StandardMaterial3D:
	var mat := _solid(color, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _lip_material(team: String) -> StandardMaterial3D:
	if _lip_mats.has(team):
		return _lip_mats[team]
	var mat := _solid(Palette.team(team).lightened(0.38), 0.4)
	_lip_mats[team] = mat
	return mat


func _link_material(owner: String) -> StandardMaterial3D:
	if _link_mats.has(owner):
		return _link_mats[owner]
	var tint := Palette.ENEMY if owner == "enemy" else Palette.PLAYER
	var mat := _glass(Color(tint.r, tint.g, tint.b, 0.78))
	_link_mats[owner] = mat
	return mat


func _show_error(message: String) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = message
	label.position = Vector2(80, 400)
	layer.add_child(label)
