extends SceneTree

## N4.4-A WINDOWED VISUAL PASS (Phase 7 evidence harness).
##
## Run WITHOUT --headless under Xvfb, e.g.:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility \
##     --script res://scripts/tools/n44a_visual_pass.gd
##
## Drives the REAL production flow (production defaults: the pl_01 auto-start
## path, exploration enabled) and saves PNG screenshots of the N4.4-A
## player-facing presentation as evidence. This is NOT an assertion suite: it
## waits for the same state transitions the headless N44A suite proves
## deterministically, captures the frame, and exits non-zero only when a
## transition never happens (timeout) or a screenshot could not be saved.
## Screenshot interpretation is a human review step (the N44A report §Visual).
##
## Isolation: same Engine-meta injection convention as the headless suites —
## the real user:// profile/save files are never touched; fixtures live under
## user://n44a_visual_test/ and are removed at the end.

const PROLOGUE_SHELL_SCRIPT: GDScript = preload("res://scripts/narrative/PrologueShell.gd")
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const PROLOGUE_SHELL_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const BEAT_01: String = "pl_01_lost_world"
const BEAT_02: String = "pl_02_faint_resonance"
const BEAT_03: String = "pl_03_wanderer"
const BEAT_04: String = "pl_04_repeated_mark"
const BEAT_05: String = "pl_05_forgotten_ruins"
const BEAT_06: String = "pl_06_crowns_call"
const SHOT_DIR: String = "/home/z/my-project/download/n44a_visual"
const TEST_DIR: String = "user://n44a_visual_test"
const MAX_WAIT_FRAMES: int = 3600
const INTERACT_RETRY_BUDGET_FRAMES: int = 60

var _stage: int = 0
var _wait_frames: int = 0
var _captures: int = 0
## Re-entry guard: a pending capture must never double-save (the await yields
## control back to the frame loop while the capture is in flight).
var _capture_in_flight: bool = false


func _shot(shot_name: String) -> void:
	if _capture_in_flight:
		return
	_capture_in_flight = true
	_captures += 1
	_capture_async("%02d_%s" % [_captures, shot_name])


## Saves the NEXT rendered frame (await the draw, then grab the viewport).
func _capture_async(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var err := img.save_png(SHOT_DIR + "/" + shot_name + ".png")
	_capture_in_flight = false
	if err == OK:
		print("SHOT saved: ", shot_name)
	else:
		printerr("SHOT FAILED: ", shot_name, " (error ", err, ")")
		quit(1)


func _on_main() -> bool:
	return current_scene != null and current_scene.name == "Main"


func _on_shell() -> bool:
	if current_scene == null or current_scene.name != "PrologueShell":
		return false
	return current_scene.get_script() == PROLOGUE_SHELL_SCRIPT


func _shell() -> Control:
	return current_scene as Control


func _panel_of(shell: Control) -> DialoguePanel:
	return shell.call("dialogue_panel") as DialoguePanel


func _stage_node(shell: Control) -> PrologueExplorationStage:
	return shell.call("exploration_stage") as PrologueExplorationStage


func _explorer_of(shell: Control) -> PrologueExplorer:
	var stage := _stage_node(shell)
	return stage.explorer() if stage != null else null


func _advance_if_open(shell: Control) -> void:
	var panel := _panel_of(shell)
	if panel.is_open():
		panel.advance()


func _teleport_and_settle(next_stage: int, x: float, shot_name: String, settle: int = 50) -> void:
	var shell: Control = _shell()
	_teleport(_explorer_of(shell), x)
	_settled_shot(next_stage, shot_name, settle)


func _teleport(explorer: PrologueExplorer, x: float) -> void:
	explorer.position.x = x


## Waits for the camera smoothing to settle at the teleported position, then
## captures the labelled evidence frame.
func _settled_shot(next_stage: int, shot_name: String, settle: int) -> void:
	if _wait_frames < settle:
		return
	_shot(shot_name)
	_stage = next_stage
	_wait_frames = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	Engine.set_meta("crownfall_profile_path", TEST_DIR + "/profile_missing.json")
	Engine.set_meta("crownfall_menu_save_path", TEST_DIR + "/save_none.json")
	_stage = 1
	change_scene_to_file(MAIN_SCENE)


func _process(_delta: float) -> bool:
	_wait_frames += 1
	if _wait_frames > MAX_WAIT_FRAMES:
		printerr("VISUAL PASS timed out at stage %d" % _stage)
		quit(1)
		return true
	match _stage:
		1:
			if not _on_main():
				return false
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 2
			_wait_frames = 0
			return false
		2:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			# Fast-forward the authored beats (their presentation is N4.2
			# evidence, already captured by the N4.3-C pass).
			if not bool(state.is_completed(BEAT_01)) or not bool(state.is_completed(BEAT_02)):
				_advance_if_open(shell)
				return false
			if not bool(shell.call("in_exploration")):
				return false
			var explorer := _explorer_of(shell)
			if explorer == null:
				return false
			_stage = 3
			_wait_frames = 0
			return false
		3:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			# pl_03 skip (the road flow is N4.3-C evidence) -> pl_04 marks.
			if not bool(state.is_completed(BEAT_03)):
				shell.call("skip_current_exploration_beat")
				return false
			var inspectables := _stage_node(shell).inspectables()
			var explorer := _explorer_of(shell)
			if inspectables.distinct_inspected_count() == 0:
				_teleport(explorer, 430.0)
				if _wait_frames % 12 == 0:
					Input.action_release("interact")
					Input.action_press("interact")
				return false
			_teleport(explorer, 630.0)
			Input.action_release("interact")
			_stage = 4
			_wait_frames = 0
			return false
		4:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel := _panel_of(shell)
			if not panel.is_open():
				if _wait_frames % 12 == 0:
					Input.action_release("interact")
					Input.action_press("interact")
				return false
			Input.action_release("interact")
			if _wait_frames < 20:
				return false
			_shot("pl04_recognition_dialogue")
			_stage = 5
			_wait_frames = 0
			return false
		5:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel := _panel_of(shell)
			if panel.is_open():
				panel.advance()
				return false
			# The recognition closed normally: pl_05 is ACTIVE (N4.4-A entry).
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(state.is_completed(BEAT_04)):
				return false
			if String(shell.call("active_exploration_beat")) != BEAT_05:
				return false
			if _wait_frames < 30:
				return false
			_shot("pl05_entry_from_pl04_completion")
			_stage = 6
			_wait_frames = 0
			return false
		6:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel := _panel_of(shell)
			if panel.is_open():
				panel.advance()
				return false
			# The recognition closed normally: pl_05 is ACTIVE (N4.4-A entry).
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(state.is_completed(BEAT_04)):
				return false
			if String(shell.call("active_exploration_beat")) != BEAT_05:
				return false
			if _wait_frames < 30:
				return false
			_shot("pl05_entry_from_pl04_completion")
			_stage = 7
			_wait_frames = 0
			return false
		7:
			# Walk east naturally into the ruin exterior (traversability).
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			Input.action_press("move_right")
			if explorer == null or explorer.position.x < 880.0:
				return false
			Input.action_release("move_right")
			if _wait_frames < 10:
				return false
			_shot("pl05_exterior_threshold")
			_stage = 8
			_wait_frames = 0
			return false
		8:
			if not _on_shell():
				return false
			_teleport_and_settle(9, 1000.0, "pl05_exterior_walls_and_glyph", 50)
			return false
		9:
			if not _on_shell():
				return false
			_teleport_and_settle(10, 1500.0, "pl05_interior_passage", 50)
			return false
		10:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var ruins: PrologueRuinsEnvironment = _stage_node(shell).ruins()
			# Enter the chamber: the stage's per-frame poll advances the zone
			# machine and fires the reveal at the authored threshold.
			_teleport(_explorer_of(shell), 1830.0)
			if ruins == null or not ruins.is_chamber_revealed():
				return false
			if _wait_frames < 50:
				return false
			_shot("pl05_hidden_chamber_reveal")
			_stage = 11
			_wait_frames = 0
			return false
		11:
			if not _on_shell():
				return false
			_teleport_and_settle(12, 1980.0, "pl05_altar_approach", 50)
			return false
		12:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			var stage := _stage_node(shell)
			# Walk the final stretch to the altar: the natural completion.
			Input.action_press("move_right")
			if _altar_emissions(shell) < 1:
				return false
			Input.action_release("move_right")
			if not bool(state.is_completed(BEAT_05)):
				return false
			if String(shell.call("active_exploration_beat")) != BEAT_06:
				return false
			if _wait_frames < 30:
				return false
			_shot("pl06_dormant_completion_boundary")
			_stage = 13
			_wait_frames = 0
			return false
		13:
			if not _on_shell():
				return false
			# The extended east bound with the persistent shell UI on-screen.
			_teleport_and_settle(14, 2200.0, "east_bound_shell_ui_camera_independent", 50)
			return false
		14:
			if _wait_frames < 20:
				return false
			print("VISUAL PASS complete: %d screenshots in %s" % [_captures, SHOT_DIR])
			Engine.remove_meta("crownfall_profile_path")
			Engine.remove_meta("crownfall_menu_save_path")
			if DirAccess.dir_exists_absolute(TEST_DIR):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
			quit(0)
			return true
	return false


func _altar_emissions(shell: Control) -> int:
	var stage := _stage_node(shell)
	return 1 if stage != null and stage.altar_request_emitted() else 0
