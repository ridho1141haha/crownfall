class_name SequenceRunner
extends Node

## Minimal linear sequence runner (technical design, section E).
##
## Executes NarrativeData-validated sequences with typed, allowlisted steps:
## dialogue, wait (frame-counted, no Timer nodes), lock_control,
## unlock_control, play_cue, change_scene (allowlisted, at most once), finish.
##
## Guarantees:
##  - completion is emitted exactly once per run (_completion_emitted guard),
##  - NarrativeState records completion idempotently,
##  - skip() fast-forwards remaining steps (only a pending change_scene may
##    still execute, at most once) and still completes exactly once,
##  - cancel() cleans up without completion,
##  - _exit_tree always restores control and closes the panel.

signal sequence_started(sequence_id: String)
signal sequence_completed(sequence_id: String)
signal sequence_failed(sequence_id: String, reason: String)

var _state: NarrativeState = null
var _panel: DialoguePanel = null
var _lock: PlayerControlLock = null
var _control_target: Node = null
var _cue_player: Callable = Callable()
var _scene_transition: Callable = Callable()
var _allowed_scenes: Array[String] = []

var _running: bool = false
var _skip_requested: bool = false
var _cancel_requested: bool = false
var _scene_changed: bool = false
var _completion_emitted: bool = false
var _panel_open: bool = false
var _current_id: String = ""


## Binds the collaborators. cue_player receives cue_id strings; scene_transition
## receives allowed scene paths (default falls back to the SceneTree).
func configure(
	state: NarrativeState,
	panel: DialoguePanel,
	control_target: Node,
	cue_player: Callable = Callable(),
	scene_transition: Callable = Callable(),
	allowed_scenes: Array[String] = []
) -> void:
	_state = state
	_panel = panel
	_control_target = control_target
	_cue_player = cue_player
	_scene_transition = scene_transition
	_allowed_scenes = allowed_scenes.duplicate()
	if _lock == null:
		_lock = PlayerControlLock.new()


func is_running() -> bool:
	return _running


func current_sequence_id() -> String:
	return _current_id


## Starts playback. Returns false when already running or misconfigured.
func play(sequence: Dictionary) -> bool:
	if _running:
		return false
	if _state == null or _panel == null or _lock == null:
		return false
	if not sequence.has("id") or not sequence.has("steps"):
		return false
	_current_id = String(sequence["id"])
	_running = true
	_skip_requested = false
	_cancel_requested = false
	_scene_changed = false
	_completion_emitted = false
	_panel_open = false
	sequence_started.emit(_current_id)
	_execute(sequence)
	return true


## Fast-forwards the remaining steps. Only a pending, allowlisted change_scene
## may still execute (at most once). Completion still fires exactly once and
## all control is restored.
func skip() -> void:
	if not _running:
		return
	_skip_requested = true
	if _panel_open:
		_panel.close()


## Aborts without completion. Control and panel state are always restored.
func cancel() -> void:
	_cancel_requested = true
	if _panel_open:
		_panel.close()
	_cleanup()


func _execute(sequence: Dictionary) -> void:
	var steps: Array = sequence.get("steps", []) as Array
	for i: int in range(steps.size()):
		if _cancel_requested:
			_cleanup()
			return
		var step: Dictionary = steps[i] as Dictionary
		var op: String = String(step.get("op", ""))
		if _skip_requested:
			if op == "change_scene":
				_perform_change_scene(step)
			continue
		match op:
			"dialogue":
				if not await _run_dialogue(step):
					return
			"wait":
				await _run_wait(step)
			"lock_control":
				_lock.lock(_control_target)
			"unlock_control":
				_lock.unlock()
			"play_cue":
				_run_cue(step)
			"change_scene":
				_perform_change_scene(step)
				if not _cancel_requested and _running:
					_finalize_completion()
				return
			"finish":
				break
		if _cancel_requested:
			_cleanup()
			return
	if _cancel_requested:
		_cleanup()
		return
	_finalize_completion()


func _run_dialogue(step: Dictionary) -> bool:
	if _panel == null or not is_instance_valid(_panel):
		_fail("dialogue panel unavailable")
		return false
	var lines: Array = step.get("lines", []) as Array
	var typed_lines: Array[Dictionary] = []
	for line: Variant in lines:
		typed_lines.append(line as Dictionary)
	_panel.open_lines(typed_lines)
	_panel_open = true
	await _panel.dialogue_finished
	_panel_open = false
	if _cancel_requested:
		return false
	return true


func _run_wait(step: Dictionary) -> void:
	var remaining: float = float(step.get("seconds", 0.0))
	while remaining > 0.0 and not _cancel_requested and not _skip_requested:
		await get_tree().process_frame
		remaining -= get_process_delta_time()


func _run_cue(step: Dictionary) -> void:
	if _cue_player.is_valid():
		_cue_player.call(String(step.get("cue_id", "")))


func _perform_change_scene(step: Dictionary) -> void:
	if _scene_changed:
		return
	var scene_path: String = String(step.get("scene_path", ""))
	if not _allowed_scenes.has(scene_path):
		_fail("scene transition not allowed: %s" % scene_path)
		return
	_scene_changed = true
	if _scene_transition.is_valid():
		_scene_transition.call(scene_path)
	elif is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(scene_path)


func _finalize_completion() -> void:
	if _completion_emitted:
		_cleanup()
		return
	_completion_emitted = true
	if _state != null:
		_state.mark_completed(_current_id)
	_cleanup()
	sequence_completed.emit(_current_id)


func _fail(reason: String) -> void:
	_cleanup()
	sequence_failed.emit(_current_id, reason)


func _cleanup() -> void:
	_running = false
	_skip_requested = false
	_cancel_requested = false
	if _lock != null:
		_lock.unlock()
	if _panel != null and is_instance_valid(_panel) and _panel.is_open():
		_panel.close()
	_panel_open = false


func _exit_tree() -> void:
	if _running:
		_cancel_requested = true
		if _panel_open and _panel != null and is_instance_valid(_panel):
			_panel.close()
		_cleanup()
