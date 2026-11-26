extends Control

signal level_chosen(index: int)
signal back_requested


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := TextureRect.new()
	backdrop.texture = ArtLibrary.texture(ArtLibrary.BACKGROUND)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	UiKit.full_rect(backdrop)

	var root := MarginContainer.new()
	root.add_theme_constant_override("margin_left", 48)
	root.add_theme_constant_override("margin_right", 48)
	root.add_theme_constant_override("margin_top", 48)
	root.add_theme_constant_override("margin_bottom", 36)
	add_child(root)
	UiKit.full_rect(root)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	root.add_child(column)

	var heading := Label.new()
	heading.text = "Choose a meadow"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.outlined(heading, Palette.CREAM, Palette.DEEP, 54)
	column.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)

	for index in BattleRules.LEVEL_COUNT:
		var number := index + 1
		grid.add_child(_level_button(number))

	var back := UiKit.button("Back", Color("5E6B80"), 32, 88)
	back.pressed.connect(func():
		AudioHooks.play_sfx("ui")
		back_requested.emit()
	)
	column.add_child(back)


func _level_button(index: int) -> Button:
	var unlocked := GameSettings.is_level_unlocked(index)
	var cleared := GameSettings.is_level_cleared(index)
	var name := _level_name(index)
	var label := "%d\n%s" % [index, name if unlocked else "Locked"]
	if cleared:
		label += "\n★"
	var color := Palette.PLAYER if unlocked else Color("5E6B80")
	if cleared:
		color = Color("1B7A45")
	var button := UiKit.button(label, color, 28, 168)
	button.disabled = not unlocked
	button.pressed.connect(func():
		AudioHooks.play_sfx("ui")
		level_chosen.emit(index)
	)
	return button


func _level_name(index: int) -> String:
	var path := BattleRules.level_path(index)
	if not FileAccess.file_exists(path):
		return "Meadow %d" % index
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return "Meadow %d" % index
	return str(data.get("name", "Meadow %d" % index))
