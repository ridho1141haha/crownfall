extends Control

## N4.0 PLACEHOLDER — Prologue route target. NOT the Prologue.
##
## This inert stub exists only so the N4.0 entry gate can route Start New Game
## to a real, clearly-labelled destination instead of silently dropping the
## player into Forgotten Shore while claiming the Prologue played. It contains:
##   - NO Prologue beats, dialogue, cinematics, or staging (N4.1–N4.5 content).
##   - NO handoff to Forgotten Shore and NO PlayerProfile completion marking
##     (the real completion handoff is wired in N4.5 after pl_09 succeeds).
##   - A single "Return to Main Menu" button so the build cannot dead-end.
##
## N4.1 contract: replace THIS scene's content at the same path
## (res://scenes/narrative/PrologueShell.tscn) with the real Prologue shell, or
## point scripts/core/Main.gd PROLOGUE_ROUTE_SCENE at the real scene in the
## same PR. The routing decision in Main.gd does not change.

const MAIN_MENU_SCENE: String = "res://scenes/main/Main.tscn"

var _return_requested: bool = false


func _on_return_to_menu_button_pressed() -> void:
	if _return_requested:
		return
	_return_requested = true
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
