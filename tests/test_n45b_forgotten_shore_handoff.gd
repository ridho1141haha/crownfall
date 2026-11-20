extends SceneTree

## N4.5-B Forgotten Shore Landing (pl_09) & Chapter I Handoff Suite.
## Verifies pl_09 data/lore fence, early rejection, full completion + PlayerProfile
## completion persistence + single ForgottenShore.tscn handoff, Skip non-marking,
## cancel/dev-exit/direct-unload safety, fail-closed invalid sequence rejection,
## and byte-exact preservation of real user files.

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


func _reset_profile_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	for p: String in [PROFILE_FIXTURE, SAVE_FIXTURE]:
		_rm(p)
		for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
			_rm(p + suffix)
	var f: FileAccess = FileAccess.open(PROFILE_FIXTURE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"schema_version": 1, "prologue_completed_once": false}, "\t"))
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
	for key: String in [AUTOSTART_META, EXPLORATION_META, "crownfall_profile_path", "crownfall_menu_save_path"]:
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
	shell.call("skip_current_exploration_beat") # pl_03
	shell.call("skip_current_exploration_beat") # pl_04
	shell.call("skip_current_exploration_beat") # pl_05
	shell.call("skip_current_exploration_beat") # pl_06 -> N4.4 boundary
	if not bool(shell.call("start_voyage_sequence")):
		return false
	await process_frame
	shell.call("skip_sequence") # pl_07
	for _i: int in range(MAX_WAIT_FRAMES):
		if String(shell.call("active_voyage_beat")) == PrologueBeats.PL_08_SHIPWRECK:
			break
		await process_frame
	shell.call("skip_sequence") # pl_08 -> N4.5-A boundary
	for _i: int in range(MAX_WAIT_FRAMES):
		if bool(shell.call("n45a_boundary_reached")):
			return true
		await process_frame
	return false


func _run() -> void:
	_real_profile_snap = _snapshot_file(REAL_PROFILE_PATH)
	_real_save_snap = _snapshot_file(SaveManager.DEFAULT_SAVE_PATH)
	_reset_profile_fixture()

	_test_data_and_lore_fence()
	await _test_normal_handoff_marks_profile_and_transitions()
	await _test_skip_during_pl09_never_marks_profile()
	await _test_cancel_during_pl09_records_nothing()
	await _test_dev_exit_during_pl09_returns_to_menu()
	await _test_direct_unload_during_pl09()
	await _test_invalid_pl09_sequence_rejected_fail_closed()

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


func _test_data_and_lore_fence() -> void:
	var seq: Dictionary = PrologueBeats.shore_handoff_sequence()
	_check(NarrativeData.validate_sequence(seq) and String(seq["id"]) == PrologueBeats.PL_09_FORGOTTEN_SHORE, "Data: pl_09_forgotten_shore validates under NarrativeData")
	var has_dialogue: bool = false
	for step: Variant in (seq["steps"] as Array):
		if String((step as Dictionary).get("op", "")) == "dialogue":
			has_dialogue = true
	_check(not has_dialogue, "Data: pl_09 has no dialogue explaining crown survival")
	for cid: String in [PrologueBeats.CUE_PL09_SHORE_WAKE, PrologueBeats.CUE_PL09_CROWN_CONTINUITY, PrologueBeats.CUE_PL09_CHAPTER_TITLE]:
		var cap: String = PrologueBeats.stage_caption(cid)
		_check(cap.begins_with("[Placeholder art]"), "Data: cue %s uses labelled [Placeholder art] caption" % cid)


func _test_normal_handoff_marks_profile_and_transitions() -> void:
	_reset_profile_fixture()
	var shell: Control = await _load_fresh_shell()
	if not _check(shell != null, "Case 1: PrologueShell loaded"):
		return
	_check(not bool(shell.call("start_shore_handoff")), "Case 1: start_shore_handoff rejected before Prologue starts")
	if not _check(await _advance_to_n45a_boundary(shell), "Case 1: reached N4.5-A boundary (8 beats)"):
		return
	var state: NarrativeState = shell.call("narrative_state") as NarrativeState
	var cues: Array[String] = []
	var exits: Array[String] = []
	shell.call("set_cue_player", func(cid: String) -> void: cues.append(cid))
	shell.call("set_exit_transition", func(path: String) -> void: exits.append(path))
	_check(bool(shell.call("start_shore_handoff")), "Case 1: start_shore_handoff accepted at N4.5-A boundary")
	_check(not bool(shell.call("start_shore_handoff")), "Case 1: duplicate start_shore_handoff rejected while running")
	_check(bool(shell.call("is_handoff_active")) and bool(shell.call("is_voyage_overlay_visible")), "Case 1: pl_09 active with camera-immune overlay visible")
	for _i: int in range(MAX_WAIT_FRAMES):
		if bool(shell.call("is_handoff_completed")):
			break
		await process_frame
	var expected_cues: Array[String] = [
		PrologueBeats.CUE_PL09_SHORE_WAKE,
		PrologueBeats.CUE_PL09_CROWN_CONTINUITY,
		PrologueBeats.CUE_PL09_CHAPTER_TITLE,
	]
	_check(cues == expected_cues, "Case 1: exact pl_09 cue order played (wake -> crown continuity -> Chapter I title)")
	_check(bool(state.is_completed(PrologueBeats.PL_09_FORGOTTEN_SHORE)) and state.completed_count() == 9, "Case 1: pl_09 recorded once (total 9 beats)")
	_check(bool(shell.call("was_profile_marked_completed")) and _read_fixture_completed_flag(), "Case 1: normal full completion marks PlayerProfile.prologue_completed_once = true")
	_check(exits == [FORGOTTEN_SHORE_SCENE], "Case 1: transitioned exactly once to ForgottenShore.tscn")
	_check(not bool(shell.call("is_handoff_active")) and not bool(shell.call("is_voyage_overlay_visible")) and not bool(shell.call("start_shore_handoff")), "Case 1: overlay hidden and duplicate post-handoff call rejected")


func _test_skip_during_pl09_never_marks_profile() -> void:
	_reset_profile_fixture()
	var shell: Control = await _load_fresh_shell()
	if not _check(shell != null and await _advance_to_n45a_boundary(shell), "Case 2: reached N4.5-A boundary for skip"):
		return
	var state: NarrativeState = shell.call("narrative_state") as NarrativeState
	var exits: Array[String] = []
	shell.call("set_exit_transition", func(path: String) -> void: exits.append(path))
	_check(bool(shell.call("start_shore_handoff")), "Case 2: pl_09 started for skip test")
	await process_frame
	shell.call("skip_sequence")
	for _i: int in range(MAX_WAIT_FRAMES):
		if bool(shell.call("is_handoff_completed")):
			break
		await process_frame
	_check(bool(state.is_completed(PrologueBeats.PL_09_FORGOTTEN_SHORE)) and state.completed_count() == 9, "Case 2: skip completes pl_09 once")
	_check(not bool(shell.call("was_profile_marked_completed")) and not _read_fixture_completed_flag(), "Case 2: skip NEVER marks PlayerProfile.prologue_completed_once")
	_check(exits == [FORGOTTEN_SHORE_SCENE], "Case 2: skip still hands off once to ForgottenShore.tscn")


func _test_cancel_during_pl09_records_nothing() -> void:
	_reset_profile_fixture()
	var shell: Control = await _load_fresh_shell()
	if not _check(shell != null and await _advance_to_n45a_boundary(shell), "Case 3: reached N4.5-A boundary for cancel"):
		return
	var state: NarrativeState = shell.call("narrative_state") as NarrativeState
	var exits: Array[String] = []
	shell.call("set_exit_transition", func(path: String) -> void: exits.append(path))
	_check(bool(shell.call("start_shore_handoff")), "Case 3: pl_09 started for cancel test")
	var gen_before: int = int(shell.call("handoff_generation"))
	await process_frame
	shell.call("cancel_sequence")
	for _i: int in range(20):
		await process_frame
	_check(state.completed_count() == 8 and not bool(state.is_completed(PrologueBeats.PL_09_FORGOTTEN_SHORE)), "Case 3: cancel during pl_09 records nothing")
	_check(int(shell.call("handoff_generation")) > gen_before and not bool(shell.call("is_handoff_active")) and not bool(shell.call("is_voyage_overlay_visible")), "Case 3: cancel invalidates generation and hides overlay")
	_check(exits.is_empty() and not _read_fixture_completed_flag(), "Case 3: cancel never transitions to Forgotten Shore or marks profile")


func _test_dev_exit_during_pl09_returns_to_menu() -> void:
	_reset_profile_fixture()
	var shell: Control = await _load_fresh_shell()
	if not _check(shell != null and await _advance_to_n45a_boundary(shell), "Case 4: reached N4.5-A boundary for dev exit"):
		return
	var state: NarrativeState = shell.call("narrative_state") as NarrativeState
	var exits: Array[String] = []
	shell.call("set_exit_transition", func(path: String) -> void: exits.append(path))
	shell.call("start_shore_handoff")
	await process_frame
	_check(bool(shell.call("request_main_menu_return")) and not bool(shell.call("request_main_menu_return")), "Case 4: dev exit fires once during pl_09")
	for _i: int in range(15):
		await process_frame
	_check(exits == [MAIN_SCENE] and state.completed_count() == 8 and not _read_fixture_completed_flag(), "Case 4: dev exit targets Main menu only, records nothing, and leaves profile false")


func _test_direct_unload_during_pl09() -> void:
	_reset_profile_fixture()
	var shell: Control = await _load_fresh_shell()
	if not _check(shell != null and await _advance_to_n45a_boundary(shell), "Case 5: reached N4.5-A boundary for unload"):
		return
	var state: NarrativeState = shell.call("narrative_state") as NarrativeState
	shell.call("start_shore_handoff")
	await process_frame
	change_scene_to_file(MAIN_SCENE)
	for _i: int in range(25):
		await process_frame
	_check(not is_instance_valid(shell) and state.completed_count() == 8 and not _read_fixture_completed_flag(), "Case 5: direct scene unload during pl_09 frees cleanly, records nothing, and leaves profile false")


func _test_invalid_pl09_sequence_rejected_fail_closed() -> void:
	_reset_profile_fixture()
	var shell: Control = await _load_fresh_shell()
	if not _check(shell != null and await _advance_to_n45a_boundary(shell), "Case 6: reached N4.5-A boundary for invalid seq"):
		return
	var state: NarrativeState = shell.call("narrative_state") as NarrativeState
	shell.call("set_handoff_sequence_provider", func(_bid: String) -> Dictionary: return {"id": "bad_id", "steps": []})
	_check(not bool(shell.call("start_shore_handoff")), "Case 6: invalid pl_09 sequence rejected fail-closed")
	_check(state.completed_count() == 8 and not bool(shell.call("is_handoff_active")) and not _read_fixture_completed_flag(), "Case 6: rejected pl_09 mutates no state, locks, or profile")
