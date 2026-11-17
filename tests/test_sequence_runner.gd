extends SceneTree

## N3 sequence runner tests: deterministic execution, lock/unlock, exactly-once
## completion, skip fast-forward, cancel cleanup, allowlisted single scene
## transition, and unload cleanup. All sequences are NON-CANON test fixtures
## built in-code and validated through NarrativeData first.

const SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const FORGOTTEN_SHORE: String = "res://scenes/world/ForgottenShore.tscn"

var _checks: int = 0
var _stage: int = 0
var _frames: int = 0
var _session: ForgottenShoreSession = null
var _panel: DialoguePanel = null
var _runner: SequenceRunner = null
var _state: NarrativeState = null
var _cues: Array[String] = []
var _transitions: Array[String] = []
var _completed_ids: Array[String] = []
var _failed: Array = []
var _x0: float = 0.0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		printerr("TEST FAILURE [test_sequence_runner]: " + msg)
		quit(1)
		return false
	print("PASS: " + msg)
	return true


func _record_cue(cue_id: String) -> void:
	_cues.append(cue_id)


func _record_transition(scene_path: String) -> void:
	_transitions.append(scene_path)


func _initialize() -> void:
	Engine.set_meta("crownfall_load_on_start", false)
	change_scene_to_file(SCENE)


func _send_key(keycode: Key, pressed: bool) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _sequence_a() -> Dictionary:
	return {
		"id": "probe_runner_a",
		"skip_allowed": false,
		"steps": [
			{"op": "lock_control"},
			{"op": "dialogue", "lines": [
				{"speaker": "Test Speaker", "text": "runner line one"},
				{"speaker": "Test Speaker", "text": "runner line two"},
			]},
			{"op": "wait", "seconds": 0.1},
			{"op": "play_cue", "cue_id": "cue_a"},
			{"op": "unlock_control"},
			{"op": "finish"},
		],
	}


func _sequence_b() -> Dictionary:
	return {
		"id": "probe_runner_b",
		"skip_allowed": true,
		"steps": [
			{"op": "dialogue", "lines": [
				{"speaker": "Test Speaker", "text": "handoff"},
			]},
			{"op": "change_scene", "scene_path": FORGOTTEN_SHORE},
			{"op": "change_scene", "scene_path": FORGOTTEN_SHORE},
		],
	}


func _sequence_c() -> Dictionary:
	return {
		"id": "probe_runner_c",
		"skip_allowed": true,
		"steps": [
			{"op": "dialogue", "lines": [
				{"speaker": "Test Speaker", "text": "skip me one"},
				{"speaker": "Test Speaker", "text": "skip me two"},
			]},
			{"op": "wait", "seconds": 3.0},
			{"op": "play_cue", "cue_id": "cue_c"},
			{"op": "unlock_control"},
			{"op": "finish"},
		],
	}


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 4000:
		_check(false, "sequence runner test timed out")
		return true
	match _stage:
		0:
			if current_scene == null or String(current_scene.name) != "ForgottenShore":
				return false
			_session = current_scene as ForgottenShoreSession
			if _session == null or _session.player == null:
				return false
			_session.time_manager.auto_advance = false
			_session.set_process(false)
			var valid: Dictionary = NarrativeData.validate_sequences_payload({"sequences": [_sequence_a(), _sequence_b(), _sequence_c()]})
			_check(bool(valid.get("ok", false)), "built-in test sequences validate")
			_state = NarrativeState.new()
			_panel = DialoguePanel.new()
			get_root().add_child(_panel)
			_runner = SequenceRunner.new()
			get_root().add_child(_runner)
			_runner.sequence_completed.connect(func(id: String) -> void: _completed_ids.append(id))
			_runner.sequence_failed.connect(func(id: String, reason: String) -> void: _failed.append([id, reason]))
			_runner.configure(_state, _panel, _session.player, Callable(self, "_record_cue"), Callable(self, "_record_transition"), [FORGOTTEN_SHORE])
			_check(_runner.play(_sequence_a()), "sequence A starts")
			_check(not _runner.play(_sequence_a()), "concurrent play rejected while running")
			_stage = 1
			_frames = 0
			return false
		1:
			if not _panel.is_open():
				return false
			_check(not _session.player.is_physics_processing(), "lock step disabled player physics")
			_check(not _session.player.is_processing_unhandled_input(), "lock step disabled player unhandled input")
			_x0 = _session.player.global_position.x
			Input.action_press("move_right")
			_stage = 2
			_frames = 0
			return false
		2:
			if _frames < 10:
				return false
			Input.action_release("move_right")
			_check(is_equal_approx(_session.player.global_position.x, _x0), "locked player does not move")
			_send_key(KEY_ENTER, true)
			_stage = 3
			_frames = 0
			return false
		3:
			if _frames < 3:
				return false
			_send_key(KEY_ENTER, false)
			_check(_panel.get_body_text() == "runner line two", "first advance shows second line")
			_send_key(KEY_ENTER, true)
			_stage = 4
			_frames = 0
			return false
		4:
			if _frames < 3:
				return false
			_send_key(KEY_ENTER, false)
			_stage = 5
			_frames = 0
			return false
		5:
			if _runner.is_running():
				if _frames < 240:
					return false
				_check(false, "sequence A did not finish in time")
				return true
			_check(_completed_ids == ["probe_runner_a"], "sequence A completed exactly once")
			_check(_state.is_completed("probe_runner_a"), "state records A completion")
			_check(_cues == ["cue_a"], "cue played once")
			_check(_session.player.is_physics_processing(), "control unlocked after completion")
			_check(_session.player.is_processing_unhandled_input(), "unhandled input restored after completion")
			# replay: per-run completion fires again, state stays idempotent
			_check(_runner.play(_sequence_a()), "replay of A starts")
			_stage = 6
			_frames = 0
			return false
		6:
			if not _panel.is_open():
				return false
			# advance the replay's dialogue once (line one), then cancel
			_send_key(KEY_ENTER, true)
			_stage = 7
			_frames = 0
			return false
		7:
			if _frames < 3:
				return false
			_send_key(KEY_ENTER, false)
			_runner.cancel()
			_stage = 8
			_frames = 0
			return false
		8:
			if _runner.is_running() or _frames < 3:
				return false
			_check(_completed_ids == ["probe_runner_a"], "cancel adds no completion")
			_check(_state.completed_count() == 1, "state completion stays idempotent across runs")
			_check(not _panel.is_open(), "cancel closed the panel")
			_check(_session.player.is_physics_processing(), "cancel restored physics")
			# skip fast-forward on C
			_check(_runner.play(_sequence_c()), "sequence C starts")
			_stage = 9
			_frames = 0
			return false
		9:
			if not _panel.is_open():
				return false
			_send_key(KEY_ENTER, true)
			_stage = 10
			_frames = 0
			return false
		10:
			if _frames < 3:
				return false
			_send_key(KEY_ENTER, false)
			_runner.skip()
			_stage = 11
			_frames = 0
			return false
		11:
			if _runner.is_running():
				if _frames < 60:
					return false
				_check(false, "skip did not finish in time")
				return true
			_check(_completed_ids.size() == 2 and _completed_ids[1] == "probe_runner_c", "skip still completes exactly once")
			_check(not _cues.has("cue_c"), "skip fast-forwards past play_cue")
			_check(_session.player.is_physics_processing(), "skip restored physics")
			_check(not _panel.is_open(), "skip closed the panel")
			# allowlisted single transition (B has duplicate change_scene steps)
			_check(_runner.play(_sequence_b()), "sequence B starts")
			_stage = 12
			_frames = 0
			return false
		12:
			if not _panel.is_open():
				return false
			_send_key(KEY_ENTER, true)
			_stage = 13
			_frames = 0
			return false
		13:
			if _frames < 3:
				return false
			_send_key(KEY_ENTER, false)
			_stage = 14
			_frames = 0
			return false
		14:
			if _runner.is_running():
				if _frames < 60:
					return false
				_check(false, "sequence B did not finish in time")
				return true
			_check(_transitions == [FORGOTTEN_SHORE], "scene transition executed exactly once despite duplicate step")
			_check(_completed_ids.size() == 3 and _completed_ids[2] == "probe_runner_b", "sequence B completed exactly once")
			# unload cleanup: free the runner while a sequence is open
			_check(_runner.play(_sequence_a()), "sequence A starts for unload test")
			_stage = 15
			_frames = 0
			return false
		15:
			if not _panel.is_open():
				return false
			_runner.queue_free()
			_stage = 16
			_frames = 0
			return false
		16:
			if _frames < 3:
				return false
			_check(not is_instance_valid(_runner), "runner freed while running")
			_check(not _panel.is_open(), "runner unload closed the panel")
			_check(_session.player.is_physics_processing(), "runner unload restored physics")
			_check(_session.player.is_processing_unhandled_input(), "runner unload restored unhandled input")
			_check(_failed.is_empty(), "no sequence failures occurred")
			print("PASS: All %d Sequence Runner checks completed with 0 failures." % _checks)
			quit(0)
			return true
	return false
