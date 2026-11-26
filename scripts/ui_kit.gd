extends RefCounted
class_name UiKit


static func button(text: String, bg: Color, font_size: int, height: float) -> Button:
	var control := Button.new()
	control.text = text
	control.focus_mode = Control.FOCUS_NONE
	control.custom_minimum_size = Vector2(0, height)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := _box(bg)
	var hover := _box(bg.lightened(0.08))
	var pressed := _box(bg.darkened(0.1))
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_stylebox_override("hover", hover)
	control.add_theme_stylebox_override("pressed", pressed)
	control.add_theme_stylebox_override("focus", normal)
	control.add_theme_color_override("font_color", Palette.CREAM)
	control.add_theme_color_override("font_hover_color", Palette.CREAM)
	control.add_theme_color_override("font_pressed_color", Palette.CREAM)
	control.add_theme_color_override("font_focus_color", Palette.CREAM)
	control.add_theme_font_size_override("font_size", font_size)
	return control


static func _box(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(28)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.08, 0.14, 0.28, 0.22)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


static func full_rect(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0


static func outlined(label: Label, color: Color, outline: Color, size: int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", maxi(4, size / 7))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
