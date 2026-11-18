extends SceneTree

## N4.3-C WINDOWED VISUAL PASS (Phase 5 evidence harness).
##
## Run WITHOUT --headless under Xvfb, e.g.:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility \
##     --script res://scripts/tools/n43c_visual_pass.gd
##
## Drives the REAL production flow (production defaults: the pl_01 auto-start
## path, exploration enabled) and saves PNG screenshots of the player-facing
## presentation as evidence. This is NOT an assertion suite: it waits for the
## same state transitions the headless integration suite proves deterministically,
## captures the frame, and exits non-zero only when a transition never happens
## (timeout) or a screenshot could not be saved. Screenshot interpretation is a
## human review step (see docs/narrative/N43C_IMPLEMENTATION_REPORT.md §5).
##
## Isolation: same Engine-meta injection convention as the headless suites —
## the real user:// profile/save files are never touched; fixtures live under
## user://n43c_visual_test/ and are removed at the end.

const PROLOGUE_SHELL_SCRIPT: GDScript = preload("res://scripts/narrative/PrologueShell.gd")
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const PROLOGUE_SHELL_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const AUTOSTART_META: String = "crownfall_prologue_autostart"
const BEAT_01: String = "pl_01_lost_world"
const BEAT_02: String = "pl_02_faint_resonance"
const BEAT_03: String = "pl_03_wanderer"
const BEAT_04: String = "pl_04_repeated_mark"
const SHOT_DIR: String = "/home/z/my-project/download/n43c_visual"
const TEST_DIR: String = "user://n43c_visual_test"
const MAX_WAIT_FRAMES: int = 3600
const INTERACT_RETRY_BUDGET_FRAMES: int = 60

var _stage: int = 0
var _wait_frames: int = 0
var _captures: int = 0


func _shot(shot_name: String) -> void:
	_captures += 1
	_capture_async("%02d_%s" % [_captures, shot_name])


## Saves the NEXT rendered frame (await the draw, then grab the viewport).
func _capture_async(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var err := img.save_png(SHOT_DIR + "/" + shot_name + ".png")
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


func _inspectables_of(shell: Control) -> PrologueMarkInspectables:
	var stage := _stage_node(shell)
	return stage.inspectables() if stage != null else null


func _advance_if_open(shell: Control) -> void:
	var panel := _panel_of(shell)
	if panel.is_open():
		panel.advance()


func _teleport(explorer: PrologueExplorer, x: float) -> void:
	explorer.position = Vector2(x, PrologueExplorationStage.GROUND_Y)


func _recognition_open() -> bool:
	if current_scene == null or current_scene.name != "PrologueShell":
		return false
	var panel := _panel_of(current_scene as Control)
	return panel.is_open() and panel.get_speaker_text() == "Monarch" and panel.get_body_text().contains("I've seen this mark before...")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	# Isolated profile/save injection (the suites' convention): the real user
	# files are never read or written by this pass.
	Engine.set_meta("crownfall_profile_path", TEST_DIR + "/profile_missing.json")
	Engine.set_meta("crownfall_menu_save_path", TEST_DIR + "/save_none.json")
	# PRODUCTION auto-start stays ON: the visual pass must show exactly what a
	# player sees from New Game, including the pl_01 entry.
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
			if not bool(shell.call("is_sequence_running")):
				return false
			if _wait_frames < 20:
				return false
			_shot("pl01_cinematic_prosperity")
			_stage = 3
			_wait_frames = 0
			return false
		3:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(state.is_completed(BEAT_01)):
				_advance_if_open(shell)
				return false
			if _wait_frames < 20:
				return false
			_shot("pl02_faint_resonance")
			_stage = 4
			_wait_frames = 0
			return false
		4:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(state.is_completed(BEAT_02)):
				_advance_if_open(shell)
				return false
			if not bool(shell.call("in_exploration")):
				return false
			if _wait_frames < 40:
				return false
			_shot("pl03_intro_road_start")
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
			# Movement is enabled here (the intro closed): walk east.
			Input.action_press("move_right")
			var explorer := _explorer_of(shell)
			if explorer == null:
				return false
			if explorer.position.x < -100.0:
				return false
			Input.action_release("move_right")
			if _wait_frames < 10:
				return false
			_shot("pl03_walking_the_road")
			_stage = 6
			_wait_frames = 0
			return false
		6:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(state.is_completed(BEAT_03)):
				Input.action_press("move_right")
				return false
			Input.action_release("move_right")
			_teleport(_explorer_of(shell), 430.0)
			_stage = 7
			_wait_frames = 0
			return false
		7:
			if not _on_shell():
				return false
			if _wait_frames < 20:
				return false
			var shell: Control = _shell()
			var prompt: Label = _inspectables_of(shell).prompt()
			if prompt == null or not prompt.visible:
				return false
			_shot("pl04_prompt_object_a")
			Input.action_press("interact")
			_stage = 8
			_wait_frames = 0
			return false
		8:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if inspectables.distinct_inspected_count() < 1:
				if _wait_frames > INTERACT_RETRY_BUDGET_FRAMES:
					Input.action_release("interact")
					_wait_frames = 0
					Input.action_press("interact")
					return false
				return false
			Input.action_release("interact")
			_teleport(_explorer_of(shell), 630.0)
			Input.action_press("interact")
			_stage = 9
			_wait_frames = 0
			return false
		9:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not _recognition_open():
				return false
			if _wait_frames < 20:
				return false
			_shot("pl04_recognition_dialogue")
			_stage = 10
			_wait_frames = 0
			return false
		10:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel := _panel_of(shell)
			if panel.is_open():
				panel.advance()
				return false
			Input.action_release("interact")
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(shell.call("n43_segment_complete")):
				return false
			if _wait_frames < 20:
				return false
			_shot("terminal_n43_boundary")
			_stage = 11
			_wait_frames = 0
			return false
		11:
			if _wait_frames < 20:
				return false
			print("VISUAL PASS complete: %d screenshots in %s" % [_captures, SHOT_DIR])
			Engine.remove_meta(AUTOSTART_META)
			Engine.remove_meta("crownfall_profile_path")
			Engine.remove_meta("crownfall_menu_save_path")
			if DirAccess.dir_exists_absolute(TEST_DIR):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
			quit(0)
			return true
	return false
