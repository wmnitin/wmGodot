extends Control

signal play_requested
signal levels_requested

var _difficulty_label: Label
var _settings: Control


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

	_difficulty_label = Label.new()
	_difficulty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.outlined(_difficulty_label, Palette.INK, Palette.CREAM, 28)
	box.add_child(_difficulty_label)
	_refresh_difficulty()
	if not GameSettings.settings_changed.is_connected(_refresh_difficulty):
		GameSettings.settings_changed.connect(_refresh_difficulty)

	var play := UiKit.button("Play", Palette.PLAYER, 48, 120)
	play.pressed.connect(_on_play)
	box.add_child(play)

	var hint := Label.new()
	hint.text = "Drag from your tower. Swipe a line to cut it."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.outlined(hint, Palette.INK, Palette.CREAM, 26)
	box.add_child(hint)

	var gear := UiKit.icon_button(ArtLibrary.texture(ArtLibrary.GEAR), 96)
	gear.pressed.connect(_open_settings)
	add_child(gear)
	gear.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -140
	gear.offset_top = 36
	gear.offset_right = -36
	gear.offset_bottom = 132

	_settings = load("res://scripts/game/settings_panel.gd").new()
	add_child(_settings)


func _open_settings() -> void:
	AudioHooks.play_sfx("ui")
	_settings.open_panel()


func _refresh_difficulty() -> void:
	if _difficulty_label == null:
		return
	var label := str(GameSettings.DIFFICULTIES[GameSettings.difficulty]["label"])
	_difficulty_label.text = "Difficulty: %s" % label


func _add_background() -> void:
	var rect := TextureRect.new()
	rect.texture = ArtLibrary.texture(ArtLibrary.BACKGROUND)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	UiKit.full_rect(rect)


func _on_play() -> void:
	AudioHooks.play_sfx("ui")
	levels_requested.emit()
