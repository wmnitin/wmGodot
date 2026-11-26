extends Node2D

signal match_finished(victory: bool)
signal restart_requested

const HIT_RADIUS := 112.0
const DISC_SCALE := BattleRules.TOWER_RADIUS / ArtLibrary.DISC_TEX_RADIUS

var sim: MatchSim
var _origin := Vector2(40, 250)
var _towers := {}
var _links := {}
var _soldiers := {}
var _punch := {}
var _prev_owner := {}
var _prev_count := {}

var _pointer := -1
var _mode := ""
var _source_id := ""
var _slash_prev := Vector2.ZERO
var _hover_id := ""
var _preview_edge: Line2D
var _preview_core: Line2D
var _hover_ring: Sprite2D

var _you_label: Label
var _red_label: Label
var _name_label: Label
var _hint: Label
var _toast: Label
var _toast_time := 0.0
var _hint_time := 0.0
var _over := false
var _end_delay := 0.0
var _link_root: Node2D
var _soldier_root: Node2D
var _tower_root: Node2D


func _ready() -> void:
	sim = MatchSim.new()
	if not sim.load_level(GameSettings.level_path):
		sim = null
		_show_error("Could not load the level.")
		return
	sim.configure(GameSettings.params(), randi())
	sim.ai_enabled = true
	_layout()
	_build_static()
	_build_hud()
	_build_towers()
	AudioHooks.start_music()


func _layout() -> void:
	var vp := get_viewport_rect().size
	if vp.x < 10.0:
		vp = Vector2(1080, 1920)
	_origin = Vector2((vp.x - BattleRules.FIELD_SIZE.x) * 0.5, 250)


func _build_static() -> void:
	var bg := Sprite2D.new()
	bg.texture = ArtLibrary.texture(ArtLibrary.BACKGROUND)
	bg.centered = false
	bg.z_index = -10
	if bg.texture:
		var vp := get_viewport_rect().size
		if vp.x < 10.0:
			vp = Vector2(1080, 1920)
		var tex_size := bg.texture.get_size()
		var cover := maxf(vp.x / tex_size.x, vp.y / tex_size.y)
		bg.scale = Vector2(cover, cover)
		bg.position = (vp - tex_size * cover) * 0.5
	add_child(bg)

	_link_root = Node2D.new()
	_link_root.z_index = 1
	add_child(_link_root)
	_soldier_root = Node2D.new()
	_soldier_root.z_index = 2
	add_child(_soldier_root)
	_tower_root = Node2D.new()
	_tower_root.z_index = 3
	add_child(_tower_root)

	_preview_edge = _make_line(Color(1, 1, 1, 0.9), 22)
	_preview_core = _make_line(Color(1, 1, 1, 0.95), 8)
	_preview_edge.visible = false
	_preview_core.visible = false
	add_child(_preview_edge)
	add_child(_preview_core)

	_hover_ring = Sprite2D.new()
	_hover_ring.texture = ArtLibrary.texture(ArtLibrary.RIM)
	_hover_ring.scale = Vector2.ONE * DISC_SCALE * 1.18
	_hover_ring.modulate = Palette.GOLD
	_hover_ring.visible = false
	_hover_ring.z_index = 4
	add_child(_hover_ring)


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
	restart.size_flags_horizontal = Control.SIZE_SHRINK_END
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


func _build_towers() -> void:
	for child in _tower_root.get_children():
		child.queue_free()
	_towers.clear()
	for entry in sim.towers:
		var node := _make_tower(entry)
		_tower_root.add_child(node)
		_towers[str(entry.id)] = node
		_punch[str(entry.id)] = 1.0
		_prev_owner[str(entry.id)] = str(entry.owner)
		_prev_count[str(entry.id)] = int(entry.count)


func _make_tower(entry: Dictionary) -> Node2D:
	var node := Node2D.new()
	node.position = _to_screen(entry.pos)
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = ArtLibrary.texture(ArtLibrary.SHADOW)
	shadow.scale = Vector2(DISC_SCALE * 1.2, DISC_SCALE * 0.55)
	shadow.position = Vector2(0, 18)
	shadow.modulate = Color(0, 0, 0, 0.35)
	node.add_child(shadow)

	var rim := Sprite2D.new()
	rim.name = "Rim"
	rim.texture = ArtLibrary.texture(ArtLibrary.RIM)
	rim.scale = Vector2.ONE * DISC_SCALE
	node.add_child(rim)

	var gold := Sprite2D.new()
	gold.name = "GoldRim"
	gold.texture = ArtLibrary.texture(ArtLibrary.RIM)
	gold.scale = Vector2.ONE * DISC_SCALE * 1.2
	gold.modulate = Palette.GOLD
	gold.visible = false
	node.add_child(gold)

	var disc := Sprite2D.new()
	disc.name = "Disc"
	disc.texture = ArtLibrary.texture(ArtLibrary.DISC)
	disc.scale = Vector2.ONE * DISC_SCALE * 0.92
	disc.modulate = Palette.team(str(entry.owner))
	node.add_child(disc)

	var capy := Sprite2D.new()
	capy.name = "Capy"
	capy.texture = ArtLibrary.portrait(str(entry.type))
	capy.scale = Vector2.ONE * 0.46
	capy.position = Vector2(0, -96)
	node.add_child(capy)

	var count := Label.new()
	count.name = "Count"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.position = Vector2(-80, -48)
	count.size = Vector2(160, 96)
	count.pivot_offset = Vector2(80, 48)
	UiKit.outlined(count, Palette.CREAM, Palette.INK, 58)
	node.add_child(count)

	var pips := Node2D.new()
	pips.name = "Pips"
	node.add_child(pips)
	for i in 3:
		var pip := Sprite2D.new()
		pip.name = "Pip%d" % i
		pip.texture = ArtLibrary.texture(ArtLibrary.PIP)
		pip.scale = Vector2.ONE * 0.55
		pip.position = Vector2((i - 1) * 32, 100)
		pips.add_child(pip)
	return node


func _process(delta: float) -> void:
	if sim == null:
		return
	if sim.state == "playing":
		sim.step(delta)
	elif not _over:
		_end_delay += delta
		if _end_delay >= 0.45:
			_over = true
			set_process_unhandled_input(false)
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
	_you_label.text = "You  %d" % sim.victory_count("player")
	_red_label.text = "Red  %d" % sim.victory_count("enemy")
	_sync_towers(delta)
	_sync_links()
	_sync_soldiers()


func _sync_towers(delta: float) -> void:
	for entry in sim.towers:
		var id := str(entry.id)
		var node: Node2D = _towers.get(id)
		if node == null:
			continue
		var level := sim.level_of(int(entry.count))
		var level_scale := 0.94
		if level == 2:
			level_scale = 1.0
		elif level >= 3:
			level_scale = 1.08
		if int(entry.count) != int(_prev_count.get(id, -1)):
			_punch[id] = 1.16
		if str(entry.owner) != str(_prev_owner.get(id, "")):
			_punch[id] = 1.24
			if str(_prev_owner.get(id, "")) != "" and sim.state == "playing":
				AudioHooks.play_sfx("capture")
		_prev_count[id] = int(entry.count)
		_prev_owner[id] = str(entry.owner)
		_punch[id] = lerpf(float(_punch[id]), 1.0, 1.0 - exp(-10.0 * delta))

		var disc: Sprite2D = node.get_node("Disc")
		var rim: Sprite2D = node.get_node("Rim")
		var gold: Sprite2D = node.get_node("GoldRim")
		var capy: Sprite2D = node.get_node("Capy")
		var count: Label = node.get_node("Count")
		var spec: Dictionary = sim.spec_of(entry)
		var show_count := bool(spec.can_be_targeted)
		disc.modulate = Palette.team(str(entry.owner))
		disc.scale = Vector2.ONE * DISC_SCALE * 0.92 * level_scale * float(_punch[id])
		rim.scale = Vector2.ONE * DISC_SCALE * level_scale
		gold.visible = level >= 3 and show_count
		capy.position = Vector2(0, -96 + sin(sim.elapsed * 2.4 + float(hash(id)) * 0.001) * 4.0)
		count.visible = show_count
		count.text = str(int(entry.count))
		count.scale = Vector2.ONE * float(_punch[id])
		var used := sim.outgoing(id).size()
		for i in 3:
			var pip: Sprite2D = node.get_node("Pips/Pip%d" % i)
			pip.visible = show_count and i < level
			if i < used:
				pip.modulate = Palette.GOLD
			else:
				pip.modulate = Color(1, 1, 1, 0.55)
		if id == _source_id and _mode == "link":
			node.scale = Vector2.ONE * 1.06
		else:
			node.scale = Vector2.ONE


func _sync_links() -> void:
	var live := {}
	for link in sim.links:
		var id := int(link.id)
		live[id] = true
		var node: Node2D = _links.get(id)
		if node == null:
			node = Node2D.new()
			var edge := _make_line(_line_color(str(link.owner), false), 26)
			edge.name = "Edge"
			var core := _make_line(_line_color(str(link.owner), true), 10)
			core.name = "Core"
			node.add_child(edge)
			node.add_child(core)
			_link_root.add_child(node)
			_links[id] = node
		var ends := sim.path_ends(str(link.source_id), str(link.target_id))
		var points := PackedVector2Array([_to_screen(ends[0]), _to_screen(ends[1])])
		node.get_node("Edge").points = points
		node.get_node("Core").points = points
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
		if bool(soldier.dead):
			continue
		var id := int(soldier.id)
		live[id] = true
		var sprite: Sprite2D = _soldiers.get(id)
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.texture = ArtLibrary.soldier(str(soldier.team))
			sprite.scale = Vector2.ONE * 0.42
			_soldier_root.add_child(sprite)
			_soldiers[id] = sprite
		var ends := sim.path_ends(str(soldier.source_id), str(soldier.target_id))
		var a := _to_screen(ends[0])
		var b := _to_screen(ends[1])
		var along := a.lerp(b, clampf(float(soldier.progress), 0.0, 1.0))
		var dir := b - a
		var side := Vector2(-dir.y, dir.x)
		if side.length_squared() > 1.0:
			side = side.normalized()
		else:
			side = Vector2.UP
		var bob := sin(sim.elapsed * 8.0 + float(id)) * 5.0
		sprite.position = along + side * bob
		if dir.length_squared() > 1.0:
			sprite.rotation = dir.angle()
		var wiggle := 0.9 + 0.1 * absf(sin(sim.elapsed * 10.0 + float(id)))
		sprite.scale = Vector2(0.42 * wiggle, 0.42 / wiggle)
	var stale: Array = []
	for id in _soldiers.keys():
		if not live.has(id):
			stale.append(id)
	for id in stale:
		_soldiers[id].queue_free()
		_soldiers.erase(id)


func _unhandled_input(event: InputEvent) -> void:
	if _over or sim == null or sim.state != "playing":
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
	_preview_edge.visible = false
	_preview_core.visible = false
	_hover_ring.visible = false


func _show_preview(screen: Vector2) -> void:
	var source = sim.tower(_source_id)
	if source.is_empty():
		return
	var from := _to_screen(source.pos)
	var hit = _tower_at(screen)
	var valid := hit != null and str(hit.id) != _source_id
	var color := Palette.PLAYER if valid else Color(0.75, 0.78, 0.84)
	_preview_edge.default_color = color
	_preview_core.default_color = Color(1, 1, 1, 0.9)
	_preview_edge.points = PackedVector2Array([from, screen])
	_preview_core.points = PackedVector2Array([from, screen])
	_preview_edge.visible = true
	_preview_core.visible = true
	if valid:
		_hover_id = str(hit.id)
		_hover_ring.visible = true
		_hover_ring.position = _to_screen(hit.pos)
	else:
		_hover_id = ""
		_hover_ring.visible = false


func _slash(a: Vector2, b: Vector2) -> void:
	var world_a := _to_world(a)
	var world_b := _to_world(b)
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
	var best = null
	var best_d := HIT_RADIUS
	var world := _to_world(screen)
	for entry in sim.towers:
		var dist := world.distance_to(entry.pos)
		if dist <= best_d:
			best_d = dist
			best = entry
	return best


func _to_screen(world: Vector2) -> Vector2:
	return _origin + world


func _to_world(screen: Vector2) -> Vector2:
	return screen - _origin


func _make_line(color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	return line


func _line_color(owner: String, core: bool) -> Color:
	if owner == "enemy":
		return Color(1.0, 0.82, 0.82) if core else Color(1.0, 0.42, 0.45)
	return Color(0.85, 0.95, 1.0) if core else Color(0.35, 0.62, 1.0)


func _show_error(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.position = Vector2(80, 400)
	add_child(label)
