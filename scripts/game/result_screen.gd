extends Control

signal restart_requested
signal menu_requested

var _victory := false


func is_result_screen() -> bool:
	return true


func setup(victory: bool) -> void:
	_victory = victory


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.12, 0.22, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	UiKit.full_rect(dim)

	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.CREAM
	style.set_corner_radius_all(40)
	style.border_color = Palette.GOLD if _victory else Palette.ENEMY
	style.set_border_width_all(8)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -420
	panel.offset_top = -460
	panel.offset_right = 420
	panel.offset_bottom = 460

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 48
	box.offset_top = 48
	box.offset_right = -48
	box.offset_bottom = -48

	var icon := TextureRect.new()
	icon.texture = ArtLibrary.texture(ArtLibrary.ICON)
	icon.custom_minimum_size = Vector2(200, 200)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var heading := Label.new()
	heading.text = "The meadow is yours!" if _victory else "Your herd retreated."
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.outlined(heading, Palette.PLAYER if _victory else Palette.ENEMY, Palette.INK, 52)
	box.add_child(heading)

	var detail := Label.new()
	detail.text = "Every red tower was taken." if _victory else "You have no towers left."
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.outlined(detail, Palette.INK, Palette.CREAM, 28)
	box.add_child(detail)

	var again := UiKit.button("Play again", Palette.PLAYER, 36, 100)
	again.pressed.connect(func():
		AudioHooks.play_sfx("ui")
		restart_requested.emit()
	)
	box.add_child(again)

	var menu := UiKit.button("Menu", Color("5E6B80"), 32, 88)
	menu.pressed.connect(func():
		AudioHooks.play_sfx("ui")
		menu_requested.emit()
	)
	box.add_child(menu)
