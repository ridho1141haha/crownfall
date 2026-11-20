extends Control

const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
## N4.1 route target: the functional Prologue shell (scripts/narrative/
## PrologueShell.gd — per-run narrative runtime + lifecycle, no story beats
## until N4.2–N4.5). The entry-gate routing below is unchanged since N4.0.
const PROLOGUE_ROUTE_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"

## Engine-meta injection points (same contract style as crownfall_load_on_start).
## They exist so headless tests can isolate the menu from the developer's real
## profile/world-save files; when unset, production defaults apply.
const PROFILE_PATH_META: String = "crownfall_profile_path"
const MENU_SAVE_PATH_META: String = "crownfall_menu_save_path"

@onready var continue_button: Button = get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button

var _new_game_confirmed: bool = false
var _confirm_overlay: Control = null
var _choice_overlay: Control = null
var _route_started: bool = false
var _route_transition: Callable = Callable()


func _ready() -> void:
	refresh_continue_state()


## Overrides the scene-transition call used by the entry routes (SequenceRunner
## scene_transition convention). Used by headless tests to observe routing
## decisions; production falls back to SceneTree.change_scene_to_file.
func set_route_transition(transition: Callable) -> void:
	_route_transition = transition


func refresh_continue_state(save_path: String = "") -> void:
	if continue_button != null:
		var save_mgr: SaveManager = SaveManager.new()
		continue_button.disabled = not save_mgr.has_valid_save(_resolve_save_path(save_path))


func has_valid_save(save_path: String = "") -> bool:
	var save_mgr: SaveManager = SaveManager.new()
	return save_mgr.has_valid_save(_resolve_save_path(save_path))


func _resolve_save_path(save_path: String = "") -> String:
	if not save_path.is_empty():
		return save_path
	if Engine.has_meta(MENU_SAVE_PATH_META):
		return String(Engine.get_meta(MENU_SAVE_PATH_META))
	return SaveManager.DEFAULT_SAVE_PATH


func _resolve_profile_path() -> String:
	if Engine.has_meta(PROFILE_PATH_META):
		return String(Engine.get_meta(PROFILE_PATH_META))
	return PlayerProfile.DEFAULT_PROFILE_PATH


func _on_play_button_pressed() -> void:
	# DECIDED (technical design D3): a new game can later overwrite an
	# existing saved reign via autosave/manual save, so require explicit
	# confirmation first. After the confirmation point, N4.0 consults the
	# global player profile for the Prologue entry gate (D7/D8).
	if _route_started:
		return
	if not _new_game_confirmed and has_valid_save():
		_show_new_game_confirm()
		return
	_begin_new_game_entry()


func _begin_new_game_entry() -> void:
	# Entry gate (production breakdown N4.0): the profile is independent of the
	# world save; a missing/invalid profile fails safe to "not completed",
	# which routes to the Prologue with Skip locked (no Skip is offered on the
	# first-ever playthrough). It never blocks New Game.
	var profile: PlayerProfile = PlayerProfile.new()
	profile.load_profile(_resolve_profile_path())
	if profile.is_prologue_completed_once():
		_show_prologue_choice_overlay()
	else:
		_route_to_prologue()


## Prologue route (N4.0): transition to the route target with the load-on-start
## flag explicitly cleared — the Prologue route never consumes a world save.
func _route_to_prologue() -> void:
	if _route_started:
		return
	_route_started = true
	PrologueHandoffBridge.invalidate_pending("route_to_prologue")
	Engine.set_meta("crownfall_load_on_start", false)
	_change_scene(PROLOGUE_ROUTE_SCENE)


## Fresh Forgotten Shore session (Skip destination and existing New Game
## behavior): the load-on-start flag is cleared so the previous world save is
## neither consumed nor loaded. The player profile is NOT touched here — Skip
## must never set or revoke the completion flag.
func _start_new_game() -> void:
	if _route_started:
		return
	_route_started = true
	PrologueHandoffBridge.invalidate_pending("start_new_game")
	Engine.set_meta("crownfall_load_on_start", false)
	_change_scene(FORGOTTEN_SHORE_SCENE)


func _change_scene(scene_path: String) -> void:
	if _route_transition.is_valid():
		_route_transition.call(scene_path)
		return
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(scene_path)


func _on_continue_button_pressed() -> void:
	# Continue is independent of PlayerProfile: it never shows the Prologue
	# choice, never starts the Prologue, and stays available for legacy saves.
	if _route_started:
		return
	_route_started = true
	PrologueHandoffBridge.invalidate_pending("continue_saved_reign")
	Engine.set_meta("crownfall_load_on_start", true)
	_change_scene(FORGOTTEN_SHORE_SCENE)


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
	cancel_btn.name = "CancelNewGameButton"
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_cancel_new_game)
	row.add_child(cancel_btn)
	_confirm_overlay = overlay


func _on_confirm_new_game() -> void:
	_new_game_confirmed = true
	if _confirm_overlay != null:
		_confirm_overlay.visible = false
	_begin_new_game_entry()


func _on_cancel_new_game() -> void:
	if _confirm_overlay != null:
		_confirm_overlay.visible = false


## Returning-player choice (only reachable when the profile records one
## successful full Prologue completion): play the Prologue again, skip ahead to
## a fresh Forgotten Shore session, or cancel back into the main menu.
func _show_prologue_choice_overlay() -> void:
	if _choice_overlay != null:
		_choice_overlay.visible = true
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
	body.text = "You have completed the Prologue before. Play it again, or skip it and start a fresh Forgotten Shore session."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	var play_again_btn: Button = Button.new()
	play_again_btn.name = "PlayPrologueAgainButton"
	play_again_btn.text = "Play Prologue Again"
	play_again_btn.pressed.connect(_route_to_prologue)
	row.add_child(play_again_btn)
	var skip_btn: Button = Button.new()
	skip_btn.name = "SkipPrologueButton"
	skip_btn.text = "Skip Prologue"
	skip_btn.pressed.connect(_start_new_game)
	row.add_child(skip_btn)
	var cancel_btn: Button = Button.new()
	cancel_btn.name = "CancelPrologueChoiceButton"
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_cancel_prologue_choice)
	row.add_child(cancel_btn)
	_choice_overlay = overlay


func _on_cancel_prologue_choice() -> void:
	# Canceling the returning-player choice also revokes the pending New Game
	# confirmation (review fix): the next Play press must run the normal
	# overwrite confirmation again when a valid save exists. The existing save
	# itself is never cleared or modified on Cancel.
	_new_game_confirmed = false
	if _choice_overlay != null:
		_choice_overlay.visible = false
