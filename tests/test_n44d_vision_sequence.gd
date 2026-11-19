extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		print("PASS: " + message)
	else:
		_failures += 1
		printerr("TEST FAILURE: [N44D] " + message)
	return condition


func _run() -> void:
	_test_vision_and_dialogue_data()
	await _test_normal_vision_dialogue_boundary()
	await _test_o4_skip_during_vision_and_dialogue()
	await _test_cancel_and_unload_paths()
	Input.action_release("interact")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Engine.remove_meta("crownfall_prologue_autostart")
	Engine.remove_meta("crownfall_prologue_exploration")
	if _failures == 0:
		print("PASS: All %d N44D Vision Sequence checks completed with 0 failures." % _checks)
		quit(0)
	else:
		printerr("FAIL: N44D Vision Sequence finished with %d failures out of %d checks." % [_failures, _checks])
		quit(1)


func _test_vision_and_dialogue_data() -> void:
	var seq: Dictionary = PrologueBeats.vision_sequence()
	_check(NarrativeData.validate_sequence(seq), "vision_sequence passes NarrativeData validation with existing ops only")
	_check(String(seq["id"]) == PrologueBeats.PL_06_VISION_SEQUENCE_ID and not PrologueBeats.is_beat(PrologueBeats.PL_06_VISION_SEQUENCE_ID), "pl_06_vision stays outside BEAT_IDS")
	var lines: Array[Dictionary] = PrologueBeats.exploration_post_vision_lines()
	_check(lines.size() == 2 and String(lines[0]["text"]) == "What... was that?" and String(lines[1]["text"]) == "I've never seen those places before.", "R15 post-vision dialogue matches exact approved verbatim lines and order")
	_check(bool(PrologueBeats.validate_vision_fragments(PrologueBeats.vision_fragments())["ok"]), "R12/R13 fragment validation remains green")


func _pulse_interact() -> void:
	Input.action_release("interact")
	await physics_frame
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await physics_frame


func _setup_shell_at_pl06() -> Dictionary:
	Engine.set_meta("crownfall_prologue_autostart", false)
	Engine.set_meta("crownfall_prologue_exploration", true)
	change_scene_to_file("res://scenes/main/Main.tscn")
	await process_frame
	change_scene_to_file("res://scenes/narrative/PrologueShell.tscn")
	var shell: Control = null
	for _i: int in range(1800):
		if current_scene != null and current_scene.name == "PrologueShell":
			shell = current_scene as Control
			break
		await process_frame
	if not _check(shell != null, "PrologueShell loaded"):
		return {"ok": false}
	shell.call("start_prologue")
	await process_frame
	shell.call("skip_sequence")
	for _i: int in range(1800):
		if String(shell.call("current_beat_id")) == "pl_02_faint_resonance":
			break
		await process_frame
	shell.call("skip_sequence")
	for _i: int in range(1800):
		if bool(shell.call("in_exploration")):
			break
		await process_frame
	var stage: PrologueExplorationStage = shell.call("exploration_stage") as PrologueExplorationStage
	shell.call("skip_current_exploration_beat")
	shell.call("skip_current_exploration_beat")
	var explorer: PrologueExplorer = stage.explorer()
	explorer.position.x = PrologueRuinsEnvironment.INTERIOR_END_X + 20.0
	await physics_frame
	await physics_frame
	explorer.position.x = PrologueRuinsEnvironment.ALTAR_X
	await physics_frame
	await physics_frame
	return {"ok": true, "shell": shell, "stage": stage, "ruins": stage.ruins(), "panel": shell.call("dialogue_panel"), "state": shell.call("narrative_state")}


func _test_normal_vision_dialogue_boundary() -> void:
	var fx: Dictionary = await _setup_shell_at_pl06()
	if not bool(fx.get("ok", false)):
		return
	var shell: Control = fx["shell"]
	var stage: PrologueExplorationStage = fx["stage"]
	var ruins: PrologueRuinsEnvironment = fx["ruins"]
	var panel: DialoguePanel = fx["panel"]
	var state: NarrativeState = fx["state"]
	var seen_cues: Array[String] = []
	shell.call("set_cue_player", func(cid: String) -> void: seen_cues.append(cid))
	var start_x: float = stage.explorer().position.x
	await _pulse_interact()
	_check(bool(shell.call("is_awakening_handoff_active")) and stage.is_awakening_locked() and ruins.is_vision_overlay_visible(), "crown interact starts N4.4-D vision sequence with lock and camera-immune overlay")
	Input.action_press("move_left")
	for _i: int in range(600):
		if panel.is_open():
			break
		await process_frame
	Input.action_release("move_left")
	var expected_cues: Array[String] = [PrologueBeats.CUE_PL06_AWAKENING, PrologueBeats.CUE_PL06_VISION_KINGDOM, PrologueBeats.CUE_PL06_VISION_SILHOUETTE, PrologueBeats.CUE_PL06_VISION_SYMBOL, PrologueBeats.CUE_PL06_VISION_FADING_LIGHT, PrologueBeats.CUE_PL06_VISION_DESTRUCTION]
	_check(seen_cues == expected_cues, "awakening cue + all 5 R12 vision fragments played in exact canonical order")
	_check(is_equal_approx(stage.explorer().position.x, start_x), "vision presentation does not leak movement input")
	_check(not ruins.is_vision_overlay_visible() and panel.is_open(), "vision ends abruptly and opens post-vision R15 dialogue")
	_check(panel.get_body_text() == "What... was that?" and not bool(state.is_completed(PrologueBeats.PL_06_CROWNS_CALL)), "R15 line 1 displays before pl_06 completion")
	panel.advance()
	_check(panel.is_open() and panel.get_body_text() == "I've never seen those places before.", "R15 line 2 displays in exact order")
	panel.advance()
	await process_frame
	_check(not panel.is_open() and bool(state.is_completed(PrologueBeats.PL_06_CROWNS_CALL)) and state.completed_count() == 6, "pl_06 recorded exactly once only after R15 dialogue closes")
	_check(bool(shell.call("n43_segment_complete")) and String(shell.call("active_exploration_beat")) == "" and stage.is_segment_ended() and not stage.is_input_enabled() and not stage.is_awakening_locked() and not ruins.is_crown_prompt_visible() and not ruins.is_vision_overlay_visible(), "N4.4 boundary freezes actor, releases locks, hides prompt/overlay, never starts pl_07")


func _test_o4_skip_during_vision_and_dialogue() -> void:
	# Skip during active vision playback (O4 Option A)
	var fx1: Dictionary = await _setup_shell_at_pl06()
	var shell1: Control = fx1["shell"]
	var stage1: PrologueExplorationStage = fx1["stage"]
	var ruins1: PrologueRuinsEnvironment = fx1["ruins"]
	var panel1: DialoguePanel = fx1["panel"]
	var state1: NarrativeState = fx1["state"]
	await _pulse_interact()
	_check(bool(shell1.call("is_sequence_running")) and ruins1.is_vision_overlay_visible(), "vision running before mid-vision skip")
	_check(bool(shell1.call("skip_current_exploration_beat")), "O4 Option A allows skip during vision playback")
	for _i: int in range(15):
		await process_frame
	_check(state1.completed_count() == 6 and bool(state1.is_completed(PrologueBeats.PL_06_CROWNS_CALL)) and not stage1.crown_completion_emitted(), "mid-vision skip records pl_06 once without normal-completion emission")
	_check(not bool(shell1.call("is_sequence_running")) and not panel1.is_open() and not stage1.is_awakening_locked() and not ruins1.is_vision_overlay_visible() and not ruins1.is_crown_prompt_visible(), "mid-vision skip terminates runner, releases locks, hides overlay/prompt")
	_check(not bool(shell1.call("skip_current_exploration_beat")) and state1.completed_count() == 6, "repeated skip after boundary is rejected and never duplicates completion")

	# Skip during post-vision R15 dialogue (O4 Option A)
	var fx2: Dictionary = await _setup_shell_at_pl06()
	var shell2: Control = fx2["shell"]
	var stage2: PrologueExplorationStage = fx2["stage"]
	var panel2: DialoguePanel = fx2["panel"]
	var state2: NarrativeState = fx2["state"]
	await _pulse_interact()
	for _i: int in range(600):
		if panel2.is_open():
			break
		await process_frame
	_check(panel2.is_open() and bool(shell2.call("skip_current_exploration_beat")), "O4 Option A allows skip during post-vision dialogue")
	for _i: int in range(10):
		await process_frame
	_check(not panel2.is_open() and state2.completed_count() == 6 and not stage2.crown_completion_emitted() and not stage2.is_awakening_locked(), "dialogue skip closes panel, releases locks, records pl_06 once")


func _test_cancel_and_unload_paths() -> void:
	# Cancel during vision records nothing
	var fx1: Dictionary = await _setup_shell_at_pl06()
	var shell1: Control = fx1["shell"]
	var stage1: PrologueExplorationStage = fx1["stage"]
	var ruins1: PrologueRuinsEnvironment = fx1["ruins"]
	var state1: NarrativeState = fx1["state"]
	await _pulse_interact()
	var gen1: int = int(shell1.call("awakening_handoff_generation"))
	shell1.call("cancel_sequence")
	for _i: int in range(15):
		await process_frame
	_check(state1.completed_count() == 5 and not bool(state1.is_completed(PrologueBeats.PL_06_CROWNS_CALL)) and not bool(shell1.call("is_sequence_running")), "cancel during vision stops runner and records nothing")
	_check(not stage1.is_awakening_locked() and not stage1.is_awakening_generation_current(gen1) and not ruins1.is_vision_overlay_visible() and not ruins1.is_crown_prompt_visible(), "cancel during vision releases locks, invalidates generation, hides overlay/prompt")

	# Cancel during post-vision dialogue records nothing (isolated vision runner prevents NarrativeState pollution)
	var fx2: Dictionary = await _setup_shell_at_pl06()
	var shell2: Control = fx2["shell"]
	var stage2: PrologueExplorationStage = fx2["stage"]
	var panel2: DialoguePanel = fx2["panel"]
	var state2: NarrativeState = fx2["state"]
	await _pulse_interact()
	for _i: int in range(600):
		if panel2.is_open():
			break
		await process_frame
	shell2.call("cancel_sequence")
	for _i: int in range(10):
		await process_frame
	_check(not panel2.is_open() and state2.completed_count() == 5 and not bool(state2.is_completed(PrologueBeats.PL_06_CROWNS_CALL)) and not stage2.is_awakening_locked(), "cancel during post-vision dialogue closes panel, releases locks, and records nothing")

	# Scene unload mid-vision records nothing and leaves no stale lock
	var fx3: Dictionary = await _setup_shell_at_pl06()
	var stage3: PrologueExplorationStage = fx3["stage"]
	var state3: NarrativeState = fx3["state"]
	await _pulse_interact()
	change_scene_to_file("res://scenes/main/Main.tscn")
	for _i: int in range(20):
		await process_frame
	_check(state3.completed_count() == 5 and not bool(state3.is_completed(PrologueBeats.PL_06_CROWNS_CALL)) and not is_instance_valid(stage3), "scene unload mid-vision records nothing and frees stage cleanly")
