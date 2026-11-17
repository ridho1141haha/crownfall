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
##  - cancel() halts the run (flags + generation token) without completion and
##    safely stops any awaiting coroutine; late continuations become no-ops,
##  - every cleanup is scoped to the run generation that owns it (_cleanup(gen)
##    no-ops for stale runs), so a cancelled run can never touch a newer run,
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
var _generation: int = 0


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


## Starts playback. Returns false when already running, misconfigured, or the
## payload failed validation (fail-closed: nothing runs on an invalid sequence).
func play(sequence: Dictionary) -> bool:
	if _running:
		return false
	if _state == null or _panel == null or _lock == null:
		return false
	if not NarrativeData.validate_sequence(sequence):
		return false
	_generation += 1
	var gen: int = _generation
	_current_id = String(sequence["id"])
	_running = true
	_skip_requested = false
	_cancel_requested = false
	_scene_changed = false
	_completion_emitted = false
	_panel_open = false
	sequence_started.emit(_current_id)
	_execute(sequence, gen)
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


## Aborts without completion. Control and panel state are always restored, and
## any coroutine still awaiting on the panel/frames halts before running the
## next step (run generation token invalidates stale continuations).
func cancel() -> void:
	_cancel_requested = true
	_running = false
	if _panel_open and _panel != null and is_instance_valid(_panel):
		_panel.close()
	_panel_open = false
	_cleanup(_generation)


func _execute(sequence: Dictionary, gen: int) -> void:
	var steps: Array = sequence.get("steps", []) as Array
	for i: int in range(steps.size()):
		if _cancel_requested or not _running or gen != _generation:
			_cleanup(gen)
			return
		var step: Dictionary = steps[i] as Dictionary
		var op: String = String(step.get("op", ""))
		if _skip_requested:
			if op == "change_scene":
				_perform_change_scene(step, gen)
			continue
		match op:
			"dialogue":
				if not await _run_dialogue(step, gen):
					_cleanup(gen)
					return
			"wait":
				await _run_wait(step, gen)
				if _cancel_requested or not _running or gen != _generation:
					_cleanup(gen)
					return
			"lock_control":
				_lock.lock(_control_target)
			"unlock_control":
				_lock.unlock()
			"play_cue":
				_run_cue(step)
			"change_scene":
				if _cancel_requested or not _running or gen != _generation:
					_cleanup(gen)
					return
				_perform_change_scene(step, gen)
				if _cancel_requested or not _running or gen != _generation:
					_cleanup(gen)
					return
				_finalize_completion(gen)
				return
			"finish":
				break
			_:
				_fail(gen, "unknown sequence op: %s" % op)
				return
		if _cancel_requested or not _running or gen != _generation:
			_cleanup(gen)
			return
	if _cancel_requested or not _running or gen != _generation:
		_cleanup(gen)
		return
	_finalize_completion(gen)


func _run_dialogue(step: Dictionary, gen: int) -> bool:
	if _panel == null or not is_instance_valid(_panel):
		_fail(gen, "dialogue panel unavailable")
		return false
	var lines: Array = step.get("lines", []) as Array
	var typed_lines: Array[Dictionary] = []
	for line: Variant in lines:
		typed_lines.append(line as Dictionary)
	_panel.open_lines(typed_lines)
	_panel_open = true
	await _panel.dialogue_finished
	_panel_open = false
	if _cancel_requested or not _running or gen != _generation:
		return false
	return true


func _run_wait(step: Dictionary, gen: int) -> void:
	var remaining: float = float(step.get("seconds", 0.0))
	while remaining > 0.0 and not _cancel_requested and not _skip_requested and _running and gen == _generation:
		await get_tree().process_frame
		remaining -= get_process_delta_time()


func _run_cue(step: Dictionary) -> void:
	if _cue_player.is_valid():
		_cue_player.call(String(step.get("cue_id", "")))


func _perform_change_scene(step: Dictionary, gen: int) -> void:
	if _scene_changed:
		return
	var scene_path: String = String(step.get("scene_path", ""))
	if not _allowed_scenes.has(scene_path):
		_fail(gen, "scene transition not allowed: %s" % scene_path)
		return
	_scene_changed = true
	if _scene_transition.is_valid():
		_scene_transition.call(scene_path)
	elif is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(scene_path)


func _finalize_completion(gen: int) -> void:
	if _completion_emitted:
		_cleanup(gen)
		return
	_completion_emitted = true
	if _state != null:
		_state.mark_completed(_current_id)
	_cleanup(gen)
	sequence_completed.emit(_current_id)


func _fail(gen: int, reason: String) -> void:
	_cleanup(gen)
	sequence_failed.emit(_current_id, reason)


func _cleanup(gen: int) -> void:
	if gen != _generation:
		return
	_running = false
	_skip_requested = false
	_cancel_requested = false
	if _lock != null:
		_lock.unlock()
	if _panel != null and is_instance_valid(_panel) and _panel.is_open():
		_panel.close()
	_panel_open = false


func _exit_tree() -> void:
	if _running or _cancel_requested:
		_cancel_requested = true
		_running = false
		if _panel_open and _panel != null and is_instance_valid(_panel):
			_panel.close()
		_panel_open = false
		_cleanup(_generation)
