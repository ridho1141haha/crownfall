extends SceneTree

## N4.4-B visual evidence harness. Run windowed under Xvfb on Godot 4.7.2.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility --script res://scripts/tools/n44b_visual_pass.gd

const SHELL_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const SHELL_SCRIPT: GDScript = preload("res://scripts/narrative/PrologueShell.gd")
const TEST_DIR: String = "user://n44b_visual_test"
const PROFILE_PATH: String = TEST_DIR + "/profile_missing.json"
const SAVE_PATH: String = TEST_DIR + "/save_none.json"
const MAX_WAIT_FRAMES: int = 3600

var _shot_dir: String = ""
var _shot_count: int = 0
var _observed_cue_id: String = ""
var _shell: Control = null


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	printerr("N44B VISUAL PASS FAILED: " + message)
	_cleanup()
	quit(1)


func _run() -> void:
	_shot_dir = OS.get_environment("N44B_VISUAL_DIR")
	if _shot_dir.is_empty():
		_shot_dir = "/tmp/crownfall_n44b_visual"
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	Engine.set_meta("crownfall_profile_path", PROFILE_PATH)
	Engine.set_meta("crownfall_menu_save_path", SAVE_PATH)
	Engine.set_meta("crownfall_prologue_autostart", false)
	Engine.set_meta("crownfall_prologue_exploration", true)
	if change_scene_to_file(SHELL_SCENE) != OK:
		_fail("could not open the live PrologueShell")
		return
	if not await _wait_for_shell():
		_fail("live PrologueShell did not become ready")
		return
	_shell.call("start_prologue")
	await _wait_frames(2)
	_shell.call("skip_sequence")
	await _wait_frames(2)
	_shell.call("skip_sequence")
	if not await _wait_for_exploration():
		_fail("the opening beats did not enter the exploration stage")
		return
	if not bool(_shell.call("skip_current_exploration_beat")) or not bool(_shell.call("skip_current_exploration_beat")):
		_fail("could not advance pl_03/pl_04 to pl_05 for visual inspection")
		return
	await _wait_frames(3)
	var stage: PrologueExplorationStage = _shell.call("exploration_stage") as PrologueExplorationStage
	if stage == null or stage.explorer() == null or stage.ruins() == null:
		_fail("pl_05 stage, explorer, or ruins component is missing")
		return
	var explorer: PrologueExplorer = stage.explorer()
	var ruins: PrologueRuinsEnvironment = stage.ruins()

	explorer.position.x = 1100.0
	await _wait_frames(50)
	if not await _capture("01_ruins_exterior_polish"):
		return
	explorer.position.x = 1660.0
	await _wait_frames(50)
	if not await _capture("02_interior_passage_pre_reveal"):
		return
	explorer.position.x = 1790.0
	await _wait_frames(8)
	explorer.position.x = 1820.0
	await _wait_frames(6)
	if not ruins.is_chamber_revealed() or not ruins.is_reveal_active() or ruins.reveal_veil().color.a <= 0.0:
		_fail("chamber reveal did not enter its visible mid-fade state")
		return
	if not await _capture("03_chamber_reveal_framing"):
		return
	explorer.position.x = PrologueRuinsEnvironment.ALTAR_X
	await _wait_frames(60)
	if ruins.is_reveal_active() or not is_equal_approx(ruins.reveal_veil().color.a, 0.0) or not ruins.is_reveal_overlay_visible():
		_fail("veil did not fade while letterbox overlay persisted")
		return
	if not await _capture("04_chamber_altar_settled"):
		return
	_shell.call("cancel_sequence")
	await _wait_frames(4)
	if not ruins.is_torn_down() or ruins.is_reveal_overlay_visible():
		_fail("shell cancellation did not tear down the reveal overlay")
		return
	if not await _capture("05_chamber_post_teardown"):
		return

	Engine.set_meta("crownfall_prologue_exploration", false)
	if change_scene_to_file(SHELL_SCENE) != OK or not await _wait_for_shell():
		_fail("could not create a fresh idle shell for storyboard previews")
		return
	_shell.call("set_cue_player", func(cue_id: String) -> void: _observed_cue_id = cue_id)
	var cue_ids: Array[String] = [PrologueBeats.CUE_PL06_AWAKENING]
	for fragment: Dictionary in PrologueBeats.vision_fragments():
		cue_ids.append(String(fragment["cue_id"]))
	var shot_names: Array[String] = [
		"06_storyboard_awakening_cue",
		"07_storyboard_vision_01_kingdom",
		"08_storyboard_vision_02_silhouette",
		"09_storyboard_vision_03_symbol",
		"10_storyboard_vision_04_fading_light",
		"11_storyboard_vision_05_destruction",
	]
	for index: int in range(cue_ids.size()):
		_observed_cue_id = ""
		var preview: Dictionary = {
			"id": "n44b_preview_%02d" % index,
			"skip_allowed": true,
			"steps": [
				{"op": "play_cue", "cue_id": cue_ids[index]},
				{"op": "wait", "seconds": 0.25},
				{"op": "finish"},
			],
		}
		if not bool(_shell.call("play_sequence", preview)):
			_fail("public play_sequence rejected preview cue %s" % cue_ids[index])
			return
		var runner: SequenceRunner = _shell.call("sequence_runner") as SequenceRunner
		var waited: int = 0
		while runner.is_running() and waited < 180:
			await process_frame
			waited += 1
		if runner.is_running():
			_fail("preview sequence timed out for %s" % cue_ids[index])
			return
		var backdrop := _shell.get_node_or_null("StageBackdrop") as ColorRect
		var caption := _shell.get_node_or_null("StageBackdrop/StageCaption") as Label
		if _observed_cue_id != cue_ids[index] or backdrop == null or caption == null or not backdrop.visible or not caption.visible or caption.text != PrologueBeats.stage_caption(cue_ids[index]):
			_fail("storyboard cue did not render expected visible caption: %s" % cue_ids[index])
			return
		await _wait_frames(2)
		if not await _capture(shot_names[index]):
			return
		_shell.call("cancel_sequence")
		await _wait_frames(1)
	print("N44B VISUAL PASS captured %d screenshots in %s" % [_shot_count, _shot_dir])
	_cleanup()
	quit(0)


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame


func _wait_for_shell() -> bool:
	for _i: int in range(MAX_WAIT_FRAMES):
		if current_scene != null and current_scene.name == "PrologueShell" and current_scene.get_script() == SHELL_SCRIPT:
			_shell = current_scene as Control
			return true
		await process_frame
	return false


func _wait_for_exploration() -> bool:
	for _i: int in range(MAX_WAIT_FRAMES):
		if _shell != null and bool(_shell.call("in_exploration")) and _shell.call("exploration_stage") != null:
			return true
		await process_frame
	return false


func _capture(name: String) -> bool:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _shot_dir.path_join(name + ".png")
	var error: Error = image.save_png(path)
	if error != OK:
		_fail("could not save screenshot %s (error %d)" % [path, error])
		return false
	_shot_count += 1
	print("SHOT saved: " + path)
	return true


func _cleanup() -> void:
	for key: String in ["crownfall_profile_path", "crownfall_menu_save_path", "crownfall_prologue_autostart", "crownfall_prologue_exploration"]:
		if Engine.has_meta(key):
			Engine.remove_meta(key)
