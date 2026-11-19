extends SceneTree

class FailingCrownPrompt extends PrologueRuinsEnvironment:
	func _create_crown_prompt(_ground_y: float) -> Label:
		return null

const BUILD_ARGS: Array[float] = [-800.0, 2200.0, 200.0, -240.0, 240.0]
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
		printerr("TEST FAILURE: [N44C] " + message)
	return condition


func _run() -> void:
	await _test_component_eligibility_and_prompt()
	await _test_stage_d5_gate_and_rejection_retry()
	await _test_shell_cancel_unload_and_ownership()
	Input.action_release("interact")
	Input.action_release("move_left")
	Input.action_release("move_right")
	if _failures == 0:
		print("PASS: All %d N44C Crown Interaction checks completed with 0 failures." % _checks)
		quit(0)
	else:
		printerr("FAIL: N44C Crown Interaction finished with %d failures out of %d checks." % [_failures, _checks])
		quit(1)


func _build_ruins(component: PrologueRuinsEnvironment) -> bool:
	return component.build(BUILD_ARGS[0], BUILD_ARGS[1], BUILD_ARGS[2], BUILD_ARGS[3], BUILD_ARGS[4])


func _test_component_eligibility_and_prompt() -> void:
	var failed := FailingCrownPrompt.new()
	get_root().add_child(failed)
	_check(not _build_ruins(failed) and not failed.is_valid() and failed.get_child_count() == 0, "crown prompt factory failure fails build atomically")
	_check(failed.crown_prompt() == null, "failed crown prompt build clears prompt ref")
	failed.queue_free()

	var ruins := PrologueRuinsEnvironment.new()
	get_root().add_child(ruins)
	await process_frame
	_check(_build_ruins(ruins) and ruins.get_child_count() == 1, "valid ruins build keeps single staging child")
	var prompt: Label = ruins.crown_prompt()
	_check(prompt != null and prompt.text == PrologueBeats.ALTAR_PROMPT_PROPOSAL_TEXT and not ruins.is_crown_prompt_visible(), "crown prompt uses provisional O5 constant and starts hidden")
	_check(not ruins.is_crown_eligible(PrologueRuinsEnvironment.ALTAR_X), "ineligible before chamber reveal")
	ruins.set_crown_prompt_visible(true)
	_check(not ruins.is_crown_prompt_visible() and not ruins.consume_crown_interaction(), "prompt hidden and consume rejected before reveal")

	ruins.update_explorer_x(PrologueRuinsEnvironment.INTERIOR_END_X)
	_check(ruins.is_chamber_revealed(), "chamber revealed after crossing interior threshold")
	_check(not ruins.is_crown_eligible(PrologueRuinsEnvironment.ALTAR_X - PrologueRuinsEnvironment.CROWN_INTERACT_RANGE_X - 5.0), "ineligible out of range")
	_check(ruins.is_crown_eligible(PrologueRuinsEnvironment.ALTAR_X), "eligible in range after reveal")
	ruins.set_crown_prompt_visible(true)
	_check(ruins.is_crown_prompt_visible(), "prompt visible when eligible")
	ruins.set_crown_prompt_visible(false)
	_check(not ruins.is_crown_prompt_visible(), "prompt hides when gated or out of range")

	ruins.set_crown_prompt_visible(true)
	_check(ruins.consume_crown_interaction() and ruins.is_crown_consumed(), "first consumption succeeds")
	_check(not ruins.is_crown_prompt_visible() and not ruins.is_crown_eligible(PrologueRuinsEnvironment.ALTAR_X) and not ruins.consume_crown_interaction(), "consumed crown hides prompt and rejects duplicates")
	ruins.release_crown_interaction_for_retry()
	_check(not ruins.is_crown_consumed() and ruins.is_crown_eligible(PrologueRuinsEnvironment.ALTAR_X), "retry release restores eligibility")

	ruins.set_crown_prompt_visible(true)
	ruins.teardown()
	_check(not ruins.is_crown_prompt_visible() and not ruins.is_crown_eligible(PrologueRuinsEnvironment.ALTAR_X) and not ruins.consume_crown_interaction(), "teardown hides prompt and disables interaction")
	ruins.release_crown_interaction_for_retry()
	_check(not ruins.is_crown_eligible(PrologueRuinsEnvironment.ALTAR_X), "retry release after teardown is inert")
	ruins.queue_free()


func _make_stage_fixture() -> Dictionary:
	var panel := DialoguePanel.new()
	get_root().add_child(panel)
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var stage := PrologueExplorationStage.new()
	get_root().add_child(stage)
	return {"ok": stage.setup(panel, texture), "stage": stage, "panel": panel}


func _pulse_interact() -> void:
	Input.action_release("interact")
	await physics_frame
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await physics_frame


func _test_stage_d5_gate_and_rejection_retry() -> void:
	var fx: Dictionary = _make_stage_fixture()
	var stage: PrologueExplorationStage = fx["stage"] as PrologueExplorationStage
	var panel: DialoguePanel = fx["panel"] as DialoguePanel
	if not _check(bool(fx["ok"]), "stage fixture builds"):
		stage.queue_free()
		panel.queue_free()
		return
	var ruins: PrologueRuinsEnvironment = stage.ruins()
	var explorer: PrologueExplorer = stage.explorer()
	var gens: Array[int] = []
	stage.crown_awakening_requested.connect(func(g: int) -> void: gens.append(g))

	stage.set_active_beat(PrologueBeats.PL_05_FORGOTTEN_RUINS)
	explorer.position.x = PrologueRuinsEnvironment.INTERIOR_END_X + 20.0
	await physics_frame
	await physics_frame
	_check(ruins.is_chamber_revealed() and not ruins.is_crown_prompt_visible(), "R6: pl_05 never shows crown prompt")
	explorer.position.x = PrologueRuinsEnvironment.ALTAR_X
	await _pulse_interact()
	_check(gens.is_empty() and not ruins.is_crown_prompt_visible(), "R6: pl_05 interact never triggers crown awakening")

	var fx_unrev: Dictionary = _make_stage_fixture()
	var stage_u: PrologueExplorationStage = fx_unrev["stage"] as PrologueExplorationStage
	var panel_u: DialoguePanel = fx_unrev["panel"] as DialoguePanel
	var u_gens: Array[int] = []
	stage_u.crown_awakening_requested.connect(func(g: int) -> void: u_gens.append(g))
	stage_u.set_active_beat(PrologueBeats.PL_06_CROWNS_CALL)
	stage_u.explorer().position.x = PrologueRuinsEnvironment.ALTAR_X
	await _pulse_interact()
	_check(u_gens.is_empty() and not stage_u.ruins().is_crown_prompt_visible(), "pl_06 interact before reveal is a no-op")
	stage_u.queue_free()
	panel_u.queue_free()

	stage.set_active_beat(PrologueBeats.PL_06_CROWNS_CALL)
	explorer.position.x = PrologueRuinsEnvironment.INTERIOR_END_X + 20.0
	await physics_frame
	_check(not ruins.is_crown_prompt_visible(), "pl_06 out of range hides prompt")
	await _pulse_interact()
	_check(gens.is_empty(), "pl_06 out of range interact is a no-op")

	explorer.position.x = PrologueRuinsEnvironment.ALTAR_X
	await physics_frame
	_check(ruins.is_crown_prompt_visible(), "pl_06 in range shows provisional prompt")
	panel.open_lines([{"speaker": "Monarch", "text": "Gate check."}])
	await physics_frame
	_check(not ruins.is_crown_prompt_visible(), "dialogue open hides crown prompt")
	await _pulse_interact()
	_check(gens.is_empty(), "interact during dialogue is a no-op")
	panel.close()
	await physics_frame

	var accept: Array[bool] = [false]
	stage.set_awakening_handoff_handler(func(_g: int) -> bool: return accept[0])
	await _pulse_interact()
	_check(gens.size() == 1 and not stage.is_awakening_armed() and not stage.is_awakening_locked() and stage.is_input_enabled(), "rejected start releases lock, disarms awakening, and restores input")
	_check(not ruins.is_crown_consumed() and not stage.reject_crown_awakening(gens[0]), "rejected start permits retry and ignores stale rejection")

	accept[0] = true
	await physics_frame
	await _pulse_interact()
	_check(gens.size() == 2 and stage.is_awakening_armed() and stage.is_awakening_locked() and not stage.is_input_enabled(), "retry arms awakening and acquires actor lock")
	var locked_x: float = explorer.position.x
	Input.action_press("move_left")
	for _i: int in range(6):
		await physics_frame
	Input.action_release("move_left")
	_check(is_equal_approx(explorer.position.x, locked_x), "held movement cannot move locked explorer")
	await _pulse_interact()
	_check(gens.size() == 2, "duplicate interact while armed does not re-emit")

	_check(stage.reject_crown_awakening(gens[1], true) and not stage.is_awakening_armed() and not stage.is_awakening_locked(), "external rejection releases lock")
	await _pulse_interact()
	var td_gen: int = gens[2]
	stage.teardown()
	_check(not stage.is_awakening_armed() and not stage.is_awakening_locked() and not stage.is_awakening_generation_current(td_gen), "teardown invalidates generation and releases lock")
	_check(not stage.reject_crown_awakening(td_gen), "stale callback after teardown is ignored")
	await _pulse_interact()
	_check(gens.size() == 3, "interact after teardown is a no-op")
	stage.queue_free()
	panel.queue_free()


func _load_shell_at_pl05() -> Dictionary:
	Engine.set_meta("crownfall_prologue_autostart", false)
	Engine.set_meta("crownfall_prologue_exploration", true)
	_check(change_scene_to_file("res://scenes/narrative/PrologueShell.tscn") == OK, "loads PrologueShell")
	var shell: Control = null
	for _i: int in range(1800):
		if current_scene != null and current_scene.name == "PrologueShell":
			shell = current_scene as Control
			break
		await process_frame
	if not _check(shell != null, "PrologueShell active"):
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
	return {"ok": stage != null, "shell": shell, "stage": stage}


func _test_shell_cancel_unload_and_ownership() -> void:
	var s1: Dictionary = await _load_shell_at_pl05()
	if not bool(s1.get("ok", false)):
		return
	var shell: Control = s1["shell"] as Control
	var stage: PrologueExplorationStage = s1["stage"] as PrologueExplorationStage
	var explorer: PrologueExplorer = stage.explorer()
	var ruins: PrologueRuinsEnvironment = stage.ruins()
	var state: NarrativeState = shell.call("narrative_state") as NarrativeState

	# Wrong beat (pl_05) handoff request is rejected by shell.
	_check(not bool(shell.call("_handle_crown_awakening_handoff", 1)), "shell rejects crown handoff during pl_05")
	_check(not bool(shell.call("is_awakening_handoff_active")) and int(shell.call("crown_awakening_rejections")) == 1, "wrong-beat rejection tracked without activating handoff")

	# Natural pl_05 -> pl_06 progression remains unchanged.
	explorer.position.x = PrologueRuinsEnvironment.INTERIOR_END_X + 20.0
	await physics_frame
	await physics_frame
	explorer.position.x = PrologueRuinsEnvironment.ALTAR_X
	await physics_frame
	await physics_frame
	_check(String(shell.call("active_exploration_beat")) == PrologueBeats.PL_06_CROWNS_CALL and state.completed_count() == 5, "pl_05 recorded once and pl_06 active")

	# Rejecting vision starter releases lock and permits retry cleanly.
	shell.call("set_awakening_vision_starter", func(_g: int) -> bool: return false)
	await physics_frame
	_check(ruins.is_crown_prompt_visible(), "shell flow shows crown prompt in pl_06")
	await _pulse_interact()
	_check(int(shell.call("crown_awakening_requests_received")) == 1 and int(shell.call("crown_awakening_rejections")) == 2, "rejecting starter receives and rejects handoff cleanly")
	_check(not bool(shell.call("is_awakening_handoff_active")) and not stage.is_awakening_locked() and not stage.is_awakening_armed() and stage.is_input_enabled(), "starter rejection releases lock, restores input, and never leaves actor stuck")
	_check(not ruins.is_crown_consumed() and state.completed_count() == 5 and not bool(state.is_completed(PrologueBeats.PL_06_CROWNS_CALL)), "rejection permits retry and records no pl_06 completion")

	# Installed N4.4-D seam: first call rejects (retry allowed), second call accepts.
	var starter_calls: Array[int] = []
	shell.call("set_awakening_vision_starter", func(g: int) -> bool:
		starter_calls.append(g)
		return starter_calls.size() >= 2
	)
	await physics_frame
	await _pulse_interact()
	_check(starter_calls.size() == 1 and not bool(shell.call("is_awakening_handoff_active")) and not stage.is_awakening_locked() and stage.is_input_enabled(), "starter rejection releases actor lock and permits retry")
	await physics_frame
	await _pulse_interact()
	var active_gen: int = int(shell.call("awakening_handoff_generation"))
	_check(starter_calls.size() == 2 and bool(shell.call("is_awakening_handoff_active")) and active_gen == starter_calls[1] and int(shell.call("crown_awakening_acceptances")) == 1, "retry accepts current generation in active pl_06")
	_check(stage.is_awakening_armed() and stage.is_awakening_locked() and state.completed_count() == 5 and not bool(state.is_completed(PrologueBeats.PL_06_CROWNS_CALL)), "accepted handoff holds lock without recording pl_06")

	# Duplicate and stale/invalid generations are rejected.
	_check(not bool(shell.call("_handle_crown_awakening_handoff", active_gen)), "duplicate active-generation handoff is rejected")
	_check(not bool(shell.call("_handle_crown_awakening_handoff", active_gen - 1)) and not bool(shell.call("_handle_crown_awakening_handoff", 0)), "stale and invalid generations are rejected")
	_check(int(shell.call("crown_awakening_acceptances")) == 1, "acceptances remain 1 after duplicate/stale rejections")

	# Cancel invalidates pending generation, clears shell handoff state, releases lock, records nothing.
	shell.call("cancel_sequence")
	_check(not bool(shell.call("is_awakening_handoff_active")) and int(shell.call("awakening_handoff_generation")) == 0, "cancel_sequence clears shell handoff state")
	_check(stage.is_torn_down() and not stage.is_awakening_armed() and not stage.is_awakening_locked() and not stage.is_awakening_generation_current(active_gen), "cancel_sequence tears down stage and invalidates generation")
	_check(not bool(shell.call("_handle_crown_awakening_handoff", active_gen)), "post-cancel handoff request is rejected")
	_check(not ruins.is_crown_prompt_visible() and state.completed_count() == 5 and not bool(state.is_completed(PrologueBeats.PL_06_CROWNS_CALL)), "cancel hides prompt and records no pl_06 completion")
	Engine.remove_meta("crownfall_prologue_autostart")
	Engine.remove_meta("crownfall_prologue_exploration")
