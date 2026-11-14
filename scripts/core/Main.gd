extends Control

const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"

@onready var continue_button: Button = get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button


func _ready() -> void:
	if continue_button != null:
		var save_mgr: SaveManager = SaveManager.new()
		continue_button.disabled = not save_mgr.has_valid_save()


func _on_play_button_pressed() -> void:
	Engine.set_meta("crownfall_load_on_start", false)
	get_tree().change_scene_to_file(FORGOTTEN_SHORE_SCENE)


func _on_continue_button_pressed() -> void:
	Engine.set_meta("crownfall_load_on_start", true)
	get_tree().change_scene_to_file(FORGOTTEN_SHORE_SCENE)


func _on_exit_button_pressed() -> void:
	get_tree().quit()
