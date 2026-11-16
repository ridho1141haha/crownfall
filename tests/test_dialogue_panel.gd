extends SceneTree

## N2 dialogue panel tests: presentation, advance/end, input isolation via
## PlayerControlLock + panel input consumption, pause/resume, cleanup, long
## text, and non-interference with the gameplay feedback channel.
## Uses NON-CANON test fixture text only.

const SCENE: String = "res://scenes/world/ForgottenShore.tscn"

var _checks: int = 0
var _stage: int = 0
var _frames: int = 0
var _panel: DialoguePanel = null
var _lock: PlayerControlLock = null
var _session: ForgottenShoreSession = null
var _done_emitted: int = 0
var _x0: float = 0.0
var _gold0: int = 0
var _state0_name: String = ""


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		printerr("TEST FAILURE [test_dialogue_panel]: " + msg)
		quit(1)
		return false
	print("PASS: " + msg)
	return true


func _initialize() -> void:
	Engine.set_meta("crownfall_load_on_start", false)
	change_scene_to_file(SCENE)


func _send_key(keycode: Key, pressed: bool) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 4000:
		_check(false, "dialogue panel test timed out")
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
			_session.feedback_message.emit("probe gameplay feedback")
			_panel = DialoguePanel.new()
			get_root().add_child(_panel)
			_lock = PlayerControlLock.new()
			_panel.dialogue_finished.connect(func() -> void: _done_emitted += 1)
			_check(not _panel.is_open(), "panel starts closed")
			_stage = 1
			_frames = 0
			return false
		1:
			if _frames < 2:
				return false
			_panel.open_lines([
				{"speaker": "Test Speaker", "text": "Non-canon first line."},
				{"speaker": "Test Speaker", "text": "Non-canon second line."},
			])
			_check(_panel.is_open(), "panel opens with lines")
			_check(_panel.get_speaker_text() == "Test Speaker", "speaker name shown")
			_check(_panel.get_body_text() == "Non-canon first line.", "first body line shown")
			_lock.lock(_session.player)
			_check(_lock.is_locked(), "control lock engaged")
			_x0 = _session.player.global_position.x
			Input.action_press("move_right")
			_stage = 2
			_frames = 0
			return false
		2:
			if _frames < 15:
				return false
			Input.action_release("move_right")
			_check(is_equal_approx(_session.player.global_position.x, _x0), "movement input does not move player during dialogue")
			_gold0 = _session.economy.get_amount(&"gold")
			_state0_name = _session.building_mgr.get_state_name(BuildingManager.WALL_ID)
			_send_key(KEY_B, true)
			_stage = 3
			_frames = 0
			return false
		3:
			if _frames < 3:
				return false
			_send_key(KEY_B, false)
			_check(_session.economy.get_amount(&"gold") == _gold0, "build key does not charge during dialogue")
			_check(_session.building_mgr.get_state_name(BuildingManager.WALL_ID) == _state0_name, "build key does not start construction during dialogue")
			_send_key(KEY_ENTER, true)
			_stage = 4
			_frames = 0
			return false
		4:
			if _frames < 3:
				return false
			_send_key(KEY_ENTER, false)
			_check(_panel.get_body_text() == "Non-canon second line.", "advance shows the second line")
			_stage = 5
			_frames = 0
			return false
		5:
			if _frames < 2:
				return false
			_send_key(KEY_ENTER, true)
			_stage = 6
			_frames = 0
			return false
		6:
			if _frames < 3:
				return false
			_send_key(KEY_ENTER, false)
			_check(not _panel.is_open(), "panel closes after the last line")
			_check(_done_emitted == 1, "dialogue_finished emitted exactly once")
			_check(_lock.is_locked(), "lock still held after close (runner owns unlock)")
			_lock.unlock()
			_check(not _lock.is_locked(), "unlock releases the control lock")
			_x0 = _session.player.global_position.x
			Input.action_press("move_right")
			_stage = 7
			_frames = 0
			return false
		7:
			if _frames < 20:
				return false
			Input.action_release("move_right")
			_check(_session.player.global_position.x > _x0 + 5.0, "movement resumes after dialogue closes")
			_panel.open_lines([
				{"speaker": "Test Speaker", "text": "pause line one"},
				{"speaker": "Test Speaker", "text": "pause line two"},
			])
			_lock.lock(_session.player)
			paused = true
			_send_key(KEY_ENTER, true)
			_stage = 8
			_frames = 0
			return false
		8:
			if _frames < 3:
				return false
			_send_key(KEY_ENTER, false)
			_check(_panel.get_body_text() == "pause line two", "panel advances while the tree is paused")
			paused = false
			_stage = 9
			_frames = 0
			return false
		9:
			if _frames < 2:
				return false
			var fb: Label = _session.get_node_or_null("ClockHUD/MarginContainer/VBoxContainer/FeedbackLabel") as Label
			_session.feedback_message.emit("after dialogue feedback")
			_check(fb != null and fb.text == "after dialogue feedback", "gameplay feedback channel unaffected by dialogue")
			var long_text: String = "L".repeat(512)
			_panel.close()
			_lock.unlock()
			_panel.open_lines([{"speaker": "Long Speaker", "text": long_text}])
			_check(_panel.get_body_text().length() == 512, "512-char line sets without error")
			_panel.queue_free()
			_stage = 10
			_frames = 0
			return false
		10:
			if _frames < 3:
				return false
			_check(not is_instance_valid(_panel), "panel freed cleanly while open")
			_check(not paused, "tree not paused at end")
			print("PASS: All %d Dialogue Panel checks completed with 0 failures." % _checks)
			quit(0)
			return true
	return false
