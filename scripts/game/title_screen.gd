extends Control

signal play_requested

var _pills := {}


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_add_background()
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	add_child(box)
	UiKit.full_rect(box)
	box.offset_left = 80
	box.offset_right = -80
	box.offset_top = 140
	box.offset_bottom = -120

	var icon := TextureRect.new()
	icon.texture = ArtLibrary.texture(ArtLibrary.ICON)
	icon.custom_minimum_size = Vector2(280, 280)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)

	var title := Label.new()
	title.text = "Capy Tower Wars"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.outlined(title, Palette.CREAM, Palette.DEEP, 78)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A tiny herd. A wide meadow."
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.outlined(subtitle, Palette.DEEP, Color(1, 1, 1, 0.7), 32)
	box.add_child(subtitle)

	var diff_label := Label.new()
	diff_label.text = "Difficulty"
	diff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.outlined(diff_label, Palette.INK, Palette.CREAM, 28)
	box.add_child(diff_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	for id in ["easy", "normal", "hard"]:
		var pill := UiKit.button(str(GameSettings.DIFFICULTIES[id]["label"]), Palette.NEUTRAL, 32, 88)
		pill.pressed.connect(_select_difficulty.bind(id))
		row.add_child(pill)
		_pills[id] = pill
	_refresh_pills()

	var play := UiKit.button("Play", Palette.PLAYER, 48, 120)
	play.pressed.connect(_on_play)
	box.add_child(play)

	var hint := Label.new()
	hint.text = "Drag from your tower. Swipe a line to cut it."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.outlined(hint, Palette.INK, Palette.CREAM, 26)
	box.add_child(hint)


func _add_background() -> void:
	var rect := TextureRect.new()
	rect.texture = ArtLibrary.texture(ArtLibrary.BACKGROUND)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	UiKit.full_rect(rect)


func _select_difficulty(id: String) -> void:
	GameSettings.set_difficulty(id)
	AudioHooks.play_sfx("ui")
	_refresh_pills()


func _refresh_pills() -> void:
	for id in _pills.keys():
		var pill: Button = _pills[id]
		var bg := Palette.PLAYER if id == GameSettings.difficulty else Color("5E6B80")
		var style := UiKit._box(bg)
		pill.add_theme_stylebox_override("normal", style)
		pill.add_theme_stylebox_override("hover", UiKit._box(bg.lightened(0.08)))
		pill.add_theme_stylebox_override("pressed", UiKit._box(bg.darkened(0.1)))
		pill.add_theme_stylebox_override("focus", style)


func _on_play() -> void:
	AudioHooks.play_sfx("ui")
	play_requested.emit()
