extends Control

const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"

@onready var continue_button: Button = get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button

var _new_game_confirmed: bool = false
var _confirm_overlay: Control = null


func _ready() -> void:
	refresh_continue_state()


func refresh_continue_state(save_path: String = SaveManager.DEFAULT_SAVE_PATH) -> void:
	if continue_button != null:
		var save_mgr: SaveManager = SaveManager.new()
		continue_button.disabled = not save_mgr.has_valid_save(save_path)


func has_valid_save(save_path: String = SaveManager.DEFAULT_SAVE_PATH) -> bool:
	var save_mgr: SaveManager = SaveManager.new()
	return save_mgr.has_valid_save(save_path)


func _on_play_button_pressed() -> void:
	# DECIDED (technical design D3): a new game can later overwrite an
	# existing saved reign via autosave/manual save, so require explicit
	# confirmation first.
	if not _new_game_confirmed and has_valid_save():
		_show_new_game_confirm()
		return
	_start_new_game()


func _start_new_game() -> void:
	Engine.set_meta("crownfall_load_on_start", false)
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(FORGOTTEN_SHORE_SCENE)


func _on_continue_button_pressed() -> void:
	Engine.set_meta("crownfall_load_on_start", true)
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(FORGOTTEN_SHORE_SCENE)


func _on_exit_button_pressed() -> void:
	if is_inside_tree() and get_tree() != null:
		get_tree().quit()


func _show_new_game_confirm() -> void:
	if _confirm_overlay != null:
		_confirm_overlay.visible = true
		return
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.02, 0.02, 0.05, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	var title: Label = Label.new()
	title.text = "START NEW GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var body: Label = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "A saved reign already exists. Starting a new game will replace it the next time the kingdom is saved."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	var confirm_btn: Button = Button.new()
	confirm_btn.name = "ConfirmNewGameButton"
	confirm_btn.text = "Start New Game"
	confirm_btn.pressed.connect(_on_confirm_new_game)
	row.add_child(confirm_btn)
	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_cancel_new_game)
	row.add_child(cancel_btn)
	_confirm_overlay = overlay


func _on_confirm_new_game() -> void:
	_new_game_confirmed = true
	if _confirm_overlay != null:
		_confirm_overlay.visible = false
	_start_new_game()


func _on_cancel_new_game() -> void:
	if _confirm_overlay != null:
		_confirm_overlay.visible = false
