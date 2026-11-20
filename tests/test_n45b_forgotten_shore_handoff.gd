extends SceneTree

## N4.5-B / N4.5-C Unit & Lifecycle Suite for pl_09 Forgotten Shore Handoff.
## Verifies two-stage lifecycle (profile stays false until destination ack),
## token/destination/duplicate/stale/failure guards, persistence failure safety,
## real pl_09 presentation beats and exact CHAPTER I — FORGOTTEN SHORE title,
## Skip non-marking, cancel/dev-exit/unload invalidation, and real-file hygiene.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const PROLOGUE_SHELL_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const TEST_DIR: String = "user://n45b_test"
const PROFILE_FIXTURE: String = "user://n45b_test/profile_false.json"
const SAVE_FIXTURE: String = "user://n45b_test/save_none.json"
const REAL_PROFILE_PATH: String = "user://player_profile.json"
const AUTOSTART_META: String = "crownfall_prologue_autostart"
const EXPLORATION_META: String = "crownfall_prologue_exploration"
const MAX_WAIT_FRAMES: int = 1800

var _checks: int = 0
var _failures: int = 0
var _real_profile_snap: Dictionary = {}
var _real_save_snap: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		print("PASS: " + message)
		return true
	_failures += 1
	printerr("TEST FAILURE: [N45B] " + message)
	return false


func _snapshot_file(path: String) -> Dictionary:
	var existed: bool = FileAccess.file_exists(path)
	var content: String = FileAccess.get_file_as_string(path) if existed else ""
	return {"existed": existed, "content": content}


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _reset_profile_fixture(completed_value: bool = false) -> void:
	PrologueHandoffBridge.reset_for_tests()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	for p: String in [PROFILE_FIXTURE, SAVE_FIXTURE]:
		_rm(p)
		for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
			_rm(p + suffix)
	var f: FileAccess = FileAccess.open(PROFILE_FIXTURE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"schema_version": 1, "prologue_completed_once": completed_value}, "\t"))
		f.flush()
		f.close()
	Engine.set_meta("crownfall_profile_path", PROFILE_FIXTURE)
	Engine.set_meta("crownfall_menu_save_path", SAVE_FIXTURE)


func _read_fixture_completed_flag() -> bool:
	var prof := PlayerProfile.new()
	prof.set_profile_path(PROFILE_FIXTURE)
	prof.load_profile()
	return prof.is_prologue_completed_once()


func _cleanup_isolation() -> void:
	PrologueHandoffBridge.reset_for_tests()
	Input.action_release("interact")
	Input.action_release("move_left")
	Input.action_release("move_right")
	for p: String in [PROFILE_FIXTURE, SAVE_FIXTURE]:
		_rm(p)
		for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
			_rm(p + suffix)
	var abs_dir: String = ProjectSettings.globalize_path(TEST_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.remove_absolute(abs_dir)
	for key: String in [AUTOSTART_META, EXPLORATION_META, "crownfall_profile_path", "crownfall_menu_save_path", "crownfall_load_on_start"]:
		if Engine.has_meta(key):
			Engine.remove_meta(key)


func _load_fresh_shell() -> Control:
	Engine.set_meta(AUTOSTART_META, false)
	Engine.set_meta(EXPLORATION_META, true)
	change_scene_to_file(MAIN_SCENE)
	for _i: int in range(120):
		if current_scene != null and current_scene.name == "Main":
			break
		await process_frame
	change_scene_to_file(PROLOGUE_SHELL_SCENE)
	for _i: int in range(MAX_WAIT_FRAMES):
		if current_scene != null and current_scene.name == "PrologueShell":
			return current_scene as Control
		await process_frame
	return null


func _advance_to_n45a_boundary(shell: Control) -> bool:
	shell.call("start_prologue")
	await process_frame
	shell.call("skip_sequence")
	for _i: int in range(MAX_WAIT_FRAMES):
		if String(shell.call("current_beat_id")) == "pl_02_faint_resonance":
			break
		await process_frame
	shell.call("skip_sequence")
	for _i: int in range(MAX_WAIT_FRAMES):
		if bool(shell.call("in_exploration")):
			break
		await process_frame
	shell.call("skip_current_exploration_beat")
	shell.call("skip_current_exploration_beat")
	shell.call("skip_current_exploration_beat")
	shell.call("skip_current_exploration_beat")
	if not bool(shell.call("start_voyage_sequence")):
		return false
	await process_frame
	shell.call("skip_sequence")
	for _i: int in range(MAX_WAIT_FRAMES):
		if String(shell.call("active_voyage_beat")) == PrologueBeats.PL_08_SHIPWRECK:
			break
		await process_frame
	shell.call("skip_sequence")
	for _i: int in range(MAX_WAIT_FRAMES):
		if bool(shell.call("n45a_boundary_reached")):
			return true
		await process_frame
	return false


func _run() -> void:
	_real_profile_snap = _snapshot_file(REAL_PROFILE_PATH)
	_real_save_snap = _snapshot_file(SaveManager.DEFAULT_SAVE_PATH)
	_reset_profile_fixture()

	_test_data_and_exact_title()
	await _test_two_stage_handoff_and_presentation()
	_test_bridge_guards_and_persistence_failure()
	await _test_skip_during_pl09_never_marks_profile()
	await _test_cancel_dev_exit_unload_and_invalid_seq()

	var prof_now: Dictionary = _snapshot_file(REAL_PROFILE_PATH)
	var save_now: Dictionary = _snapshot_file(SaveManager.DEFAULT_SAVE_PATH)
	_check(prof_now == _real_profile_snap, "Hygiene: real user://player_profile.json untouched")
	_check(save_now == _real_save_snap, "Hygiene: real user://save_slot_0.json untouched")
	_cleanup_isolation()

	if _failures == 0:
		print("PASS: All %d N45B Forgotten Shore Handoff checks completed with 0 failures." % _checks)
		quit(0)
	else:
		printerr("FAIL: N45B Forgotten Shore Handoff finished with %d failures out of %d checks." % [_failures, _checks])
		quit(1)


func _test_data_and_exact_title() -> void:
	var seq: Dictionary = PrologueBeats.shore_handoff_sequence()
	_check(NarrativeData.validate_sequence(seq) and String(seq["id"]) == PrologueBeats.PL_09_FORGOTTEN_SHORE, "Data: pl_09_forgotten_shore validates under NarrativeData")
	var has_dialogue: bool = false
	for step: Variant in (seq["steps"] as Array):
		if String((step as Dictionary).get("op", "")) == "dialogue":
			has_dialogue = true
	_check(not has_dialogue, "Data: pl_09 has no lore-bearing dialogue")
	_check(PrologueBeats.CHAPTER_I_TITLE == "CHAPTER I — FORGOTTEN SHORE", "Data: exact approved Chapter I title string with em dash")
	_check(PrologueBeats.stage_caption(PrologueBeats.CUE_PL09_CHAPTER_TITLE) == "CHAPTER I — FORGOTTEN SHORE", "Data: title cue resolves to exact approved title string")


func _test_two_stage_handoff_and_presentation() -> void:
	_reset_profile_fixture(false)
	var shell: Control = await _load_fresh_shell()
	if not _check(shell != null and await _advance_to_n45a_boundary(shell), "Case 1: reached N4.5-A boundary"):
		return
	var state: NarrativeState = shell.call("narrative_state") as NarrativeState
	var cues: Array[String] = []
	var exits: Array[String] = []
	var saw_crown_hidden_on_wake: Array[bool] = [false]
	var saw_crown_visible_on_continuity: Array[bool] = [false]
	var saw_exact_title_card: Array[bool] = [false]
	shell.call("set_cue_player", func(cid: String) -> void:
		cues.append(cid)
		if cid == PrologueBeats.CUE_PL09_SHORE_WAKE:
			saw_crown_hidden_on_wake[0] = true
		elif cid == PrologueBeats.CUE_PL09_CROWN_CONTINUITY:
			saw_crown_visible_on_continuity[0] = true
		elif cid == PrologueBeats.CUE_PL09_CHAPTER_TITLE:
			saw_exact_title_card[0] = true
	)
	shell.call("set_exit_transition", func(path: String) -> void: exits.append(path))
	_check(bool(shell.call("start_shore_handoff")), "Case 1: start_shore_handoff accepted at N4.5-A boundary")
	_check(bool(shell.call("is_shore_landing_visible")), "Case 1: ShoreLandingLayer visible during pl_09")
	for _i: int in range(MAX_WAIT_FRAMES):
		if bool(shell.call("is_handoff_completed")):
			break
		await process_frame
	_check(cues == [PrologueBeats.CUE_PL09_SHORE_WAKE, PrologueBeats.CUE_PL09_CROWN_CONTINUITY, PrologueBeats.CUE_PL09_CHAPTER_TITLE], "Case 1: wake -> crown continuity -> title played in exact order")
	_check(saw_crown_hidden_on_wake[0] and saw_crown_visible_on_continuity[0] and saw_exact_title_card[0], "Case 1: all three pl_09 presentation stages observed")
	_check(bool(state.is_completed(PrologueBeats.PL_09_FORGOTTEN_SHORE)) and state.completed_count() == 9, "Case 1: pl_09 recorded once in-memory (total 9)")
	_check(exits == [FORGOTTEN_SHORE_SCENE], "Case 1: transition requested once to ForgottenShore.tscn")
	_check(PrologueHandoffBridge.has_pending_intent() and int(shell.call("handoff_token")) > 0, "Case 1: one-shot fresh handoff intent authorized with unique token")
	_check(not _read_fixture_completed_flag(), "Case 1: profile remains FALSE before ForgottenShoreSession acknowledges initialization")
	_check(not bool(shell.call("is_shore_landing_visible")), "Case 1: ShoreLandingLayer hidden after handoff")

	# Now simulate destination ack and verify exactly-once persistence
	var tok: int = int(shell.call("handoff_token"))
	var ack_ok: Dictionary = PrologueHandoffBridge.acknowledge_destination_ready(FORGOTTEN_SHORE_SCENE, true, false, tok)
	_check(bool(ack_ok.get("ok", false)) and bool(ack_ok.get("persisted", false)) and _read_fixture_completed_flag(), "Case 1: profile becomes TRUE only after destination-ready acknowledgment")
	var ack_dup: Dictionary = PrologueHandoffBridge.acknowledge_destination_ready(FORGOTTEN_SHORE_SCENE, true, false, tok)
	_check(not bool(ack_dup.get("ok", true)) and not PrologueHandoffBridge.has_pending_intent(), "Case 1: duplicate destination acknowledgment rejected")


func _test_bridge_guards_and_persistence_failure() -> void:
	# Stale token rejected
	_reset_profile_fixture(false)
	var tok1: int = PrologueHandoffBridge.authorize_fresh_handoff(FORGOTTEN_SHORE_SCENE, PROFILE_FIXTURE)
	var r_stale: Dictionary = PrologueHandoffBridge.acknowledge_destination_ready(FORGOTTEN_SHORE_SCENE, true, false, tok1 + 99)
	_check(not bool(r_stale["ok"]) and String(r_stale["reason"]) == "stale_token" and not _read_fixture_completed_flag(), "Bridge: stale token rejected without persisting profile")

	# Wrong destination rejected
	var r_dest: Dictionary = PrologueHandoffBridge.acknowledge_destination_ready(MAIN_SCENE, true, false, tok1)
	_check(not bool(r_dest["ok"]) and String(r_dest["reason"]) == "wrong_destination" and not _read_fixture_completed_flag(), "Bridge: wrong destination rejected without persisting profile")

	# Target setup failure rejected
	var r_fail: Dictionary = PrologueHandoffBridge.acknowledge_destination_ready(FORGOTTEN_SHORE_SCENE, false, false, tok1)
	_check(not bool(r_fail["ok"]) and String(r_fail["reason"]) == "session_invalid" and not _read_fixture_completed_flag() and not PrologueHandoffBridge.has_pending_intent(), "Bridge: failed target setup rejected and consumes intent without writing profile")

	# Loaded-from-save (Continue) rejected
	var tok2: int = PrologueHandoffBridge.authorize_fresh_handoff(FORGOTTEN_SHORE_SCENE, PROFILE_FIXTURE)
	var r_load: Dictionary = PrologueHandoffBridge.acknowledge_destination_ready(FORGOTTEN_SHORE_SCENE, true, true, tok2)
	_check(not bool(r_load["ok"]) and String(r_load["reason"]) == "loaded_from_save" and not _read_fixture_completed_flag(), "Bridge: Continue load never marks Prologue complete")

	# Persistence failure (unsafe path) keeps session alive, bounded retries, reports error
	var tok3: int = PrologueHandoffBridge.authorize_fresh_handoff(FORGOTTEN_SHORE_SCENE, "/invalid/outside_user.json")
	var r_err: Dictionary = PrologueHandoffBridge.acknowledge_destination_ready(FORGOTTEN_SHORE_SCENE, true, false, tok3)
	_check(bool(r_err["ok"]) and not bool(r_err["persisted"]) and String(r_err["reason"]) == "profile_write_failed", "Bridge: persistence failure reports diagnostic without trapping session")

	# Replay never downgrades an already-true profile flag
	_reset_profile_fixture(true)
	var tok4: int = PrologueHandoffBridge.authorize_fresh_handoff(FORGOTTEN_SHORE_SCENE, PROFILE_FIXTURE)
	PrologueHandoffBridge.invalidate_pending("replay_cancelled")
	_check(_read_fixture_completed_flag() and tok4 > 0, "Bridge: replay cancel never downgrades an existing true profile flag")


func _test_skip_during_pl09_never_marks_profile() -> void:
	_reset_profile_fixture(false)
	var shell: Control = await _load_fresh_shell()
	if not _check(shell != null and await _advance_to_n45a_boundary(shell), "Case 2: reached N4.5-A boundary for skip"):
		return
	var exits: Array[String] = []
	shell.call("set_exit_transition", func(path: String) -> void: exits.append(path))
	shell.call("start_shore_handoff")
	await process_frame
	shell.call("skip_sequence")
	for _i: int in range(MAX_WAIT_FRAMES):
		if bool(shell.call("is_handoff_completed")):
			break
		await process_frame
	_check(not PrologueHandoffBridge.has_pending_intent() and not _read_fixture_completed_flag() and exits == [FORGOTTEN_SHORE_SCENE], "Case 2: skip never authorizes profile completion and still transitions to Forgotten Shore")


func _test_cancel_dev_exit_unload_and_invalid_seq() -> void:
	# Cancel
	_reset_profile_fixture(false)
	var s1: Control = await _load_fresh_shell()
	if _check(s1 != null and await _advance_to_n45a_boundary(s1), "Case 3: cancel setup"):
		s1.call("start_shore_handoff")
		await process_frame
		s1.call("cancel_sequence")
		for _i: int in range(15):
			await process_frame
		_check(not PrologueHandoffBridge.has_pending_intent() and not _read_fixture_completed_flag() and not bool(s1.call("is_shore_landing_visible")), "Case 3: cancel invalidates intent, hides overlay, leaves profile false")

	# Dev exit
	_reset_profile_fixture(false)
	var s2: Control = await _load_fresh_shell()
	if _check(s2 != null and await _advance_to_n45a_boundary(s2), "Case 4: dev exit setup"):
		var exits2: Array[String] = []
		s2.call("set_exit_transition", func(path: String) -> void: exits2.append(path))
		s2.call("start_shore_handoff")
		await process_frame
		s2.call("request_main_menu_return")
		for _i: int in range(15):
			await process_frame
		_check(exits2 == [MAIN_SCENE] and not PrologueHandoffBridge.has_pending_intent() and not _read_fixture_completed_flag(), "Case 4: dev exit invalidates intent and returns to Main only")

	# Direct unload
	_reset_profile_fixture(false)
	var s3: Control = await _load_fresh_shell()
	if _check(s3 != null and await _advance_to_n45a_boundary(s3), "Case 5: unload setup"):
		s3.call("start_shore_handoff")
		await process_frame
		change_scene_to_file(MAIN_SCENE)
		for _i: int in range(20):
			await process_frame
		_check(not is_instance_valid(s3) and not PrologueHandoffBridge.has_pending_intent() and not _read_fixture_completed_flag(), "Case 5: direct unload invalidates intent and leaves profile false")

	# Invalid pl_09 sequence
	_reset_profile_fixture(false)
	var s4: Control = await _load_fresh_shell()
	if _check(s4 != null and await _advance_to_n45a_boundary(s4), "Case 6: invalid seq setup"):
		s4.call("set_handoff_sequence_provider", func(_bid: String) -> Dictionary: return {"id": "bad", "steps": []})
		_check(not bool(s4.call("start_shore_handoff")) and not PrologueHandoffBridge.has_pending_intent() and not _read_fixture_completed_flag(), "Case 6: invalid pl_09 rejected fail-closed")
