extends Control

const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(FORGOTTEN_SHORE_SCENE)
