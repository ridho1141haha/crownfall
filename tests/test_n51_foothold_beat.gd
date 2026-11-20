extends SceneTree

## N5.1 First Foothold Milestone (ch1_02_foothold) Test Suite.
## Exercises the real ForgottenShoreSession, BuildingManager, DialoguePanel,
## PlayerControlLock, NarrativeState, and ChapterOneNarrativeAdapter.

const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const TEST_DIR: String = "user://n51_test"
const TEST_SAVE_PATH: String = "user://n51_test/save_slot_0.json"
const REAL_PROFILE_PATH: String = "user://player_profile.json"
const MAX_WAIT_FRAMES: int = 600

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
	printerr("TEST FAILURE: [N51] " + message)
	return false


func _snapshot_file(path: String) -> Dictionary:
	var existed: bool = FileAccess.file_exists(path)
	var content: String = FileAccess.get_file_as_string(path) if existed else ""
	return {"existed": existed, "content": content}


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup_fixtures() -> void:
	_rm(TEST_SAVE_PATH)
	for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
		_rm(TEST_SAVE_PATH + suffix)
	var abs_dir: String = ProjectSettings.globalize_path(TEST_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.remove_absolute(abs_dir)
	for key: String in ["crownfall_load_on_start", "crownfall_menu_save_path"]:
		if Engine.has_meta(key):
			Engine.remove_meta(key)


func _load_shore(load_on_start: bool) -> Node:
	Engine.set_meta("crownfall_load_on_start", load_on_start)
	Engine.set_meta("crownfall_menu_save_path", TEST_SAVE_PATH)
	change_scene_to_file(MAIN_SCENE)
	for _i: int in range(120):
		if current_scene != null and current_scene.name == "Main":
			break
		await process_frame
	change_scene_to_file(FORGOTTEN_SHORE_SCENE)
	for _i: int in range(MAX_WAIT_FRAMES):
		if current_scene != null and current_scene.scene_file_path == FORGOTTEN_SHORE_SCENE:
			await process_frame
			return current_scene
		await process_frame
	return null


func _build_wall_to_completed(session: Node, plot_id: String, at_x: float) -> void:
	var bm: BuildingManager = session.get("building_mgr") as BuildingManager
	var ledger: EconomyLedger = session.get("economy") as EconomyLedger
	ledger.try_add_bundle({"gold": 20, "wood": 20, "stone": 20})
	bm.request_start_construction(at_x, ledger, plot_id)
	bm.advance_construction(BuildingManager.BUILD_DURATION, plot_id)


func _run() -> void:
	_real_profile_snap = _snapshot_file(REAL_PROFILE_PATH)
	_real_save_snap = _snapshot_file(SaveManager.DEFAULT_SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))

	await _test_fresh_trigger_filters_normal_close_and_rebuild_no_replay()
	await _test_skip_and_teardown_while_active()
	await _test_startup_continue_and_in_session_restore_silence()

	_check(_snapshot_file(REAL_PROFILE_PATH) == _real_profile_snap, "Hygiene: real user://player_profile.json untouched")
	_check(_snapshot_file(SaveManager.DEFAULT_SAVE_PATH) == _real_save_snap, "Hygiene: real user://save_slot_0.json untouched")
	_cleanup_fixtures()

	if _failures == 0:
		print("PASS: All %d N51 First Foothold checks completed with 0 failures." % _checks)
		quit(0)
	else:
		printerr("FAIL: N51 First Foothold finished with %d failures out of %d checks." % [_failures, _checks])
		quit(1)


func _test_fresh_trigger_filters_normal_close_and_rebuild_no_replay() -> void:
	var session: Node = await _load_shore(false)
	if not _check(session != null, "1. Fresh ForgottenShore loaded"):
		return
	var adapter: ChapterOneNarrativeAdapter = session.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var bm: BuildingManager = session.get("building_mgr") as BuildingManager
	var ledger: EconomyLedger = session.get("economy") as EconomyLedger
	var panel: DialoguePanel = adapter.dialogue_panel()
	var player_node: Node = session.get("player") as Node
	ledger.try_add_bundle({"gold": 50, "wood": 50, "stone": 50})

	# 2. Unrelated building (wall_west_01) reaching COMPLETED does NOT trigger
	_build_wall_to_completed(session, BuildingManager.WEST_WALL_ID, BuildingManager.WEST_WALL_POSITION_X)
	_check(not panel.is_open() and adapter.narrative_state().completed_count() == 0, "2. Unrelated wall_west_01 reaching COMPLETED does not fire beat")

	# 3. Eastern wall UNDER_CONSTRUCTION does NOT trigger
	_check(bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger, BuildingManager.WALL_ID), "3. Started wall_east_01 construction")
	bm.advance_construction(1.0, BuildingManager.WALL_ID)
	_check(not panel.is_open() and adapter.narrative_state().completed_count() == 0, "3. Non-standing UNDER_CONSTRUCTION state does not fire beat")

	# 1. Eastern wall transitions to COMPLETED live -> fires once, no world pause
	bm.advance_construction(BuildingManager.BUILD_DURATION, BuildingManager.WALL_ID)
	_check(panel.is_open() and adapter.is_beat_active() and adapter.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_02_FOOTHOLD, "1. Eastern wall COMPLETED opens ch1_02_foothold dialogue")
	_check(panel.get_speaker_text() == "Monarch" and panel.get_body_text() == ChapterOneNarrativeAdapter.FOOTHOLD_LINE_TEXT, "1. Exact approved Monarch internal line displayed")
	_check(not adapter.control_lock().is_locked() and player_node.is_physics_processing() and player_node.is_processing_unhandled_input() and not paused, "1. Non-gating acknowledgement leaves movement/gameplay actions unblocked and world unpaused")

	# 4. Duplicate COMPLETED emission while active does not reopen or duplicate
	bm.wall_state_changed.emit(BuildingManager.WALL_ID, "COMPLETED", 1.0, 100, 100)
	_check(panel.is_open() and adapter.narrative_state().completed_count() == 0, "4. Duplicate COMPLETED signal while active does not duplicate completion")

	# 9a. Normal close finishes beat once and releases lock
	panel.advance()
	_check(not panel.is_open() and not adapter.is_beat_active() and not adapter.control_lock().is_locked() and player_node.is_physics_processing(), "9a. Normal advance closes panel and restores player control")
	_check(adapter.narrative_state().is_completed(ChapterOneNarrativeAdapter.BEAT_CH1_02_FOOTHOLD) and adapter.narrative_state().completed_count() == 1, "1. ch1_02_foothold recorded exactly once in NarrativeState")

	# 5. Same-session destroy + rebuild to COMPLETED does NOT replay
	bm.apply_enemy_damage(999, BuildingManager.WALL_ID)
	_check(bm.get_state_name(BuildingManager.WALL_ID) == "DESTROYED" and not panel.is_open(), "5. Eastern wall destroyed without triggering dialogue")
	bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger, BuildingManager.WALL_ID)
	bm.advance_construction(BuildingManager.BUILD_DURATION, BuildingManager.WALL_ID)
	_check(bm.get_state_name(BuildingManager.WALL_ID) == "COMPLETED" and not panel.is_open() and adapter.narrative_state().completed_count() == 1, "5. Same-session destroy and rebuild never replays ch1_02_foothold")

	# Save standing-wall state to isolated fixture for Continue & restore tests
	_check(bool(session.call("save_game_state", TEST_SAVE_PATH)), "Saved standing-wall fixture for Continue/restore tests")


func _test_skip_and_teardown_while_active() -> void:
	# 9b. Skip path finishes beat once and releases lock
	var s1: Node = await _load_shore(false)
	var a1: ChapterOneNarrativeAdapter = s1.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var p1: DialoguePanel = a1.dialogue_panel()
	_build_wall_to_completed(s1, BuildingManager.WALL_ID, BuildingManager.WALL_POSITION_X)
	a1.control_lock().lock(s1.get("player") as Node)
	_check(p1.is_open() and a1.control_lock().is_locked(), "9b. Beat active and lock seam held before skip")
	_check(a1.skip_active_beat() and not p1.is_open() and not a1.control_lock().is_locked(), "9b. Skip closes panel and releases control lock")
	_check(a1.narrative_state().is_completed(ChapterOneNarrativeAdapter.BEAT_CH1_02_FOOTHOLD) and a1.narrative_state().completed_count() == 1, "9b. Skip marks ch1_02_foothold complete exactly once")

	# 10. Teardown while beat is active disconnects signals, closes panel, releases lock, records nothing
	var s2: Node = await _load_shore(false)
	var a2: ChapterOneNarrativeAdapter = s2.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var bm2: BuildingManager = s2.get("building_mgr") as BuildingManager
	var p2: DialoguePanel = a2.dialogue_panel()
	_build_wall_to_completed(s2, BuildingManager.WALL_ID, BuildingManager.WALL_POSITION_X)
	a2.control_lock().lock(s2.get("player") as Node)
	_check(p2.is_open() and a2.control_lock().is_locked(), "10. Beat active and lock seam held before teardown")
	a2.teardown()
	_check(a2.is_torn_down() and a2.tracked_connection_count() == 0 and not p2.is_open() and not a2.control_lock().is_locked(), "10. Teardown disconnects signals, closes panel, and releases lock")
	_check(a2.narrative_state().completed_count() == 0, "10. Teardown while active does not mark beat completed")
	bm2.wall_state_changed.emit(BuildingManager.WALL_ID, "COMPLETED", 1.0, 100, 100)
	_check(not p2.is_open() and a2.narrative_state().completed_count() == 0, "10. Post-teardown wall signal cannot reopen beat")


func _test_startup_continue_and_in_session_restore_silence() -> void:
	# 6. Startup Continue with eastern wall already standing -> silent
	var s_cont: Node = await _load_shore(true)
	if not _check(s_cont != null and bool(s_cont.call("was_loaded_from_save_on_start")), "6. Startup Continue loaded standing-wall fixture"):
		return
	var a_cont: ChapterOneNarrativeAdapter = s_cont.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var bm_cont: BuildingManager = s_cont.get("building_mgr") as BuildingManager
	_check(bm_cont.is_standing(BuildingManager.WALL_ID) and not a_cont.is_active() and not a_cont.dialogue_panel().is_open() and a_cont.narrative_state().completed_count() == 0, "6. Startup Continue with standing wall remains completely silent")

	# 7 & 8. Fresh session performs in-session load_game_state() applying standing wall -> silent during & after restore
	var s_live: Node = await _load_shore(false)
	var a_live: ChapterOneNarrativeAdapter = s_live.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var bm_live: BuildingManager = s_live.get("building_mgr") as BuildingManager
	_check(bool(s_live.call("load_game_state", TEST_SAVE_PATH)), "7. In-session load_game_state() succeeded")
	_check(bm_live.is_standing(BuildingManager.WALL_ID) and not a_live.dialogue_panel().is_open() and a_live.narrative_state().completed_count() == 0, "7. In-session restore applying standing wall stays silent")
	bm_live.wall_state_changed.emit(BuildingManager.WALL_ID, "COMPLETED", 1.0, 100, 100)
	_check(not a_live.is_active() and not a_live.dialogue_panel().is_open() and a_live.narrative_state().completed_count() == 0, "8. Post-restore session does not re-enable historical dispatch")

	# 11. SaveManager schema v2 invariant (no per-beat keys)
	var payload: Dictionary = s_live.call("build_save_payload")
	var sm := SaveManager.new()
	_check(SaveManager.SCHEMA_VERSION == 2 and int(payload.get("schema_version", 0)) == 2 and sm.validate_payload(payload), "11. SaveManager schema v2 and payload validation unchanged")
	_check(not payload.has("ch1_02_foothold") and not payload.has("chapter1_narrative"), "11. Zero per-beat persistence keys added to save payload")
