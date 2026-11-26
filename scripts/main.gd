extends Control

var _title: Control
var _select: Control
var _game: Node
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
	if is_instance_valid(_select):
		_select.queue_free()
		_select = null
	if is_instance_valid(_title):
		_title.queue_free()
	_title = load("res://scripts/game/title_screen.gd").new()
	_title.play_requested.connect(_start_match)
	_title.levels_requested.connect(_show_levels)
	add_child(_title)


func start_level(index: int) -> void:
	GameSettings.set_level_index(index)
	_start_match()


func _show_levels() -> void:
	_clear_match()
	if is_instance_valid(_title):
		_title.queue_free()
		_title = null
	if is_instance_valid(_select):
		_select.queue_free()
	_select = load("res://scripts/game/level_select.gd").new()
	_select.level_chosen.connect(start_level)
	_select.back_requested.connect(_show_title)
	add_child(_select)


func _start_match() -> void:
	if is_instance_valid(_title):
		_title.queue_free()
		_title = null
	if is_instance_valid(_select):
		_select.queue_free()
		_select = null
	_clear_match()
	_game = load("res://scripts/game/game_view.gd").new()
	_game.match_finished.connect(_on_finished)
	_game.restart_requested.connect(_start_match)
	add_child(_game)
	move_child(_game, 0)


func _on_finished(victory: bool) -> void:
	if not is_instance_valid(_game):
		return
	var has_next := victory and GameSettings.level_index < BattleRules.LEVEL_COUNT
	if victory:
		GameSettings.note_victory()
	_dismiss_result()
	var screen = load("res://scripts/game/result_screen.gd").new()
	screen.setup(victory, has_next)
	screen.restart_requested.connect(_start_match)
	screen.next_requested.connect(_start_next)
	screen.menu_requested.connect(_show_title)
	# Above the meadow (z-index) and the HUD canvas layer, so the banner stays readable.
	_result_layer = CanvasLayer.new()
	_result_layer.layer = 40
	add_child(_result_layer)
	_result_layer.add_child(screen)


func _start_next() -> void:
	GameSettings.set_level_index(GameSettings.level_index + 1)
	_start_match()


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
