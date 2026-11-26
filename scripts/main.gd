extends Control

var _title: Control
var _game: Node2D
var _result_layer: CanvasLayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DisplayServer.get_name() != "headless":
		get_window().title = "Capy Tower Wars"
	_apply_font()
	_show_title()


func start_match() -> void:
	_start_match()


func _apply_font() -> void:
	var path := "res://assets/fonts/Nunito-ExtraBold.ttf"
	if not ResourceLoader.exists(path):
		return
	var theme := Theme.new()
	var font: Font = load(path)
	theme.default_font = font
	theme.default_font_size = 36
	get_tree().root.theme = theme


func _show_title() -> void:
	_clear_match()
	if is_instance_valid(_title):
		_title.queue_free()
	_title = load("res://scripts/game/title_screen.gd").new()
	_title.play_requested.connect(_start_match)
	add_child(_title)


func _start_match() -> void:
	if is_instance_valid(_title):
		_title.queue_free()
		_title = null
	_clear_match()
	_game = load("res://scripts/game/game_view.gd").new()
	_game.match_finished.connect(_on_finished)
	_game.restart_requested.connect(_start_match)
	add_child(_game)
	move_child(_game, 0)


func _on_finished(victory: bool) -> void:
	if not is_instance_valid(_game):
		return
	_dismiss_result()
	var screen = load("res://scripts/game/result_screen.gd").new()
	screen.setup(victory)
	screen.restart_requested.connect(_start_match)
	screen.menu_requested.connect(_show_title)
	# Above the meadow (z-index) and the HUD canvas layer, so the banner stays readable.
	_result_layer = CanvasLayer.new()
	_result_layer.layer = 40
	add_child(_result_layer)
	_result_layer.add_child(screen)


func _dismiss_result() -> void:
	if is_instance_valid(_result_layer):
		_result_layer.queue_free()
	_result_layer = null


func _clear_match() -> void:
	if is_instance_valid(_game):
		_game.set_process(false)
		_game.set_process_unhandled_input(false)
		_game.queue_free()
	_game = null
	_dismiss_result()
