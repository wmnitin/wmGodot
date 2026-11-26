extends Control

## Shared settings card. The title screen and the match both open this.
## Opening it during a match is the match's job; this panel only edits settings.

signal closed

var _pills := {}
var _music_toggle: Button
var _sound_toggle: Button
var _music_slider: HSlider
var _sound_slider: HSlider
var _busy := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 20
	UiKit.full_rect(self)
	_build()
	if not GameSettings.settings_changed.is_connected(_refresh):
		GameSettings.settings_changed.connect(_refresh)


func open_panel() -> void:
	_refresh()
	visible = true


func close_panel() -> void:
	visible = false
	closed.emit()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.14, 0.22, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	UiKit.full_rect(dim)

	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.CREAM
	style.set_corner_radius_all(36)
	style.set_border_width_all(8)
	style.border_color = Palette.GOLD
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -440
	panel.offset_top = -430
	panel.offset_right = 440
	panel.offset_bottom = 430

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	UiKit.full_rect(box)
	box.offset_left = 40
	box.offset_top = 36
	box.offset_right = -40
	box.offset_bottom = -36

	var heading := Label.new()
	heading.text = "Settings"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.outlined(heading, Palette.INK, Palette.CREAM, 52)
	box.add_child(heading)

	var diff := Label.new()
	diff.text = "Difficulty"
	diff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.outlined(diff, Palette.DEEP, Palette.CREAM, 28)
	box.add_child(diff)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for id in ["easy", "normal", "hard"]:
		var pill := UiKit.button(str(GameSettings.DIFFICULTIES[id]["label"]), Color("5E6B80"), 28, 80)
		pill.pressed.connect(_on_difficulty.bind(id))
		row.add_child(pill)
		_pills[id] = pill

	box.add_child(_audio_block("Music", true))
	box.add_child(_audio_block("Sound effects", false))

	var close := UiKit.button("Done", Palette.PLAYER, 36, 96)
	close.pressed.connect(_on_close)
	box.add_child(close)


func _audio_block(title: String, music: bool) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.outlined(label, Palette.INK, Palette.CREAM, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(label)
	var toggle := UiKit.button("On", Palette.PLAYER, 26, 64)
	toggle.custom_minimum_size = Vector2(150, 64)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.pressed.connect(_on_toggle_pressed.bind(music))
	header.add_child(toggle)
	block.add_child(header)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(0, 48)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_volume.bind(music))
	slider.drag_ended.connect(_on_volume_released.bind(music))
	block.add_child(slider)
	if music:
		_music_toggle = toggle
		_music_slider = slider
	else:
		_sound_toggle = toggle
		_sound_slider = slider
	return block


func _refresh() -> void:
	_busy = true
	for id in _pills.keys():
		var pill: Button = _pills[id]
		var bg := Palette.PLAYER if id == GameSettings.difficulty else Color("5E6B80")
		var plate := UiKit._box(bg)
		pill.add_theme_stylebox_override("normal", plate)
		pill.add_theme_stylebox_override("hover", UiKit._box(bg.lightened(0.08)))
		pill.add_theme_stylebox_override("pressed", UiKit._box(bg.darkened(0.1)))
		pill.add_theme_stylebox_override("focus", plate)
	_style_toggle(_music_toggle, GameSettings.music_enabled)
	_style_toggle(_sound_toggle, GameSettings.sound_enabled)
	_music_slider.value = GameSettings.music_volume * 100.0
	_sound_slider.value = GameSettings.sound_volume * 100.0
	_music_slider.editable = GameSettings.music_enabled
	_sound_slider.editable = GameSettings.sound_enabled
	_busy = false


func _on_difficulty(id: String) -> void:
	if _busy:
		return
	GameSettings.set_difficulty(id)
	AudioHooks.play_sfx("ui")
	_refresh()


func _style_toggle(toggle: Button, enabled: bool) -> void:
	toggle.text = "On" if enabled else "Off"
	var bg := Palette.PLAYER if enabled else Color("8A5360")
	var plate := UiKit._box(bg)
	toggle.add_theme_stylebox_override("normal", plate)
	toggle.add_theme_stylebox_override("hover", UiKit._box(bg.lightened(0.08)))
	toggle.add_theme_stylebox_override("pressed", UiKit._box(bg.darkened(0.1)))
	toggle.add_theme_stylebox_override("focus", plate)


func _on_toggle_pressed(music: bool) -> void:
	if _busy:
		return
	if music:
		GameSettings.set_music_enabled(not GameSettings.music_enabled)
	else:
		GameSettings.set_sound_enabled(not GameSettings.sound_enabled)
	AudioHooks.play_sfx("ui")
	_refresh()


func _on_volume(value: float, music: bool) -> void:
	if _busy:
		return
	var linear := clampf(value / 100.0, 0.0, 1.0)
	if music:
		GameSettings.set_music_volume(linear)
	else:
		GameSettings.set_sound_volume(linear)


func _on_volume_released(changed: bool, music: bool) -> void:
	if music:
		return
	AudioHooks.play_sfx("spawn")


func _on_close() -> void:
	AudioHooks.play_sfx("ui")
	close_panel()
