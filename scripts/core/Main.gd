extends Control

signal scene_transition_requested(target_scene_path: String, load_saved: bool)

const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"

var last_requested_scene: String = ""
@onready var continue_button: Button = get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button


func _ready() -> void:
	refresh_continue_state()


func refresh_continue_state(save_path: String = SaveManager.DEFAULT_SAVE_PATH) -> void:
	if continue_button != null:
		var save_mgr: SaveManager = SaveManager.new()
		continue_button.disabled = not save_mgr.has_valid_save(save_path)


func _on_play_button_pressed() -> void:
	Engine.set_meta("crownfall_load_on_start", false)
	last_requested_scene = FORGOTTEN_SHORE_SCENE
	scene_transition_requested.emit(FORGOTTEN_SHORE_SCENE, false)
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(FORGOTTEN_SHORE_SCENE)


func _on_continue_button_pressed() -> void:
	Engine.set_meta("crownfall_load_on_start", true)
	last_requested_scene = FORGOTTEN_SHORE_SCENE
	scene_transition_requested.emit(FORGOTTEN_SHORE_SCENE, true)
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(FORGOTTEN_SHORE_SCENE)


func _on_exit_button_pressed() -> void:
	if is_inside_tree() and get_tree() != null:
		get_tree().quit()
