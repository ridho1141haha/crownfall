extends SceneTree

## N5.2 Mandatory First-Night Resolution (ch1_03_first_night) Integration Suite.
## Exercises real ForgottenShoreSession, TimeManager, NightEncounterManager,
## BuildingManager, DialoguePanel, and ChapterOneNarrativeAdapter.

const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const TEST_DIR: String = "user://n52_test"
const TEST_SAVE_PATH: String = "user://n52_test/save_slot_0.json"
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
	printerr("TEST FAILURE: [N52] " + message)
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


func _trigger_real_sunrise_from_night(session: Node, day_num: int) -> void:
	var tm: TimeManager = session.get("time_manager") as TimeManager
	tm.auto_advance = false
	tm.current_day = day_num
	tm.current_phase = TimeManager.Phase.SUNSET
	tm.advance_time(tm.get_current_phase_duration() + 0.1)
	tm.advance_time(tm.get_current_phase_duration() + 0.1)


func _run() -> void:
	_real_profile_snap = _snapshot_file(REAL_PROFILE_PATH)
	_real_save_snap = _snapshot_file(SaveManager.DEFAULT_SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))

	await _test_e2e_day1_defense_held_day2_ignored_and_duplicates()
	await _test_outcome_wall_fell_and_breach_recovery()
	await _test_island_cleared_ignored()
	await _test_dialogue_contention_pending_and_teardown()
	await _test_continue_day2_restore_silence_and_schema_v2()

	# Restore default save slot touched by real Day 1 sunrise autosave (run_all.sh also sandboxes user://).
	if bool(_real_save_snap.get("existed", false)):
		var rf: FileAccess = FileAccess.open(SaveManager.DEFAULT_SAVE_PATH, FileAccess.WRITE)
		if rf != null:
			rf.store_string(String(_real_save_snap.get("content", "")))
			rf.flush()
			rf.close()
	else:
		_rm(SaveManager.DEFAULT_SAVE_PATH)
	for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
		_rm(SaveManager.DEFAULT_SAVE_PATH + suffix)
	_check(_snapshot_file(REAL_PROFILE_PATH) == _real_profile_snap, "26. Real user://player_profile.json untouched")
	_check(_snapshot_file(SaveManager.DEFAULT_SAVE_PATH) == _real_save_snap, "26. Real user://save_slot_0.json restored byte-exact after sunrise autosave")
	_cleanup_fixtures()

	if _failures == 0:
		print("PASS: All %d N52 First Night Narrative checks completed with 0 failures." % _checks)
		quit(0)
	else:
		printerr("FAIL: N52 First Night Narrative finished with %d failures out of %d checks." % [_failures, _checks])
		quit(1)


func _test_e2e_day1_defense_held_day2_ignored_and_duplicates() -> void:
	var s: Node = await _load_shore(false)
	if not _check(s != null, "1. Fresh Day 1 ForgottenShore loaded"):
		return
	var a: ChapterOneNarrativeAdapter = s.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var tm: TimeManager = s.get("time_manager") as TimeManager
	var bm: BuildingManager = s.get("building_mgr") as BuildingManager
	var nm: NightEncounterManager = s.get("night_mgr") as NightEncounterManager
	var ledger: EconomyLedger = s.get("economy") as EconomyLedger
	var panel: DialoguePanel = a.dialogue_panel()
	var player_node: Node = s.get("player") as Node

	ledger.try_add_bundle({"gold": 20, "wood": 20, "stone": 20})
	bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger, BuildingManager.WALL_ID)
	bm.advance_construction(BuildingManager.BUILD_DURATION, BuildingManager.WALL_ID)
	a.skip_active_beat()

	tm.auto_advance = false
	tm.advance_time(tm.get_current_phase_duration() + 0.1)
	_check(not panel.is_open() and not a.narrative_state().is_completed(ChapterOneNarrativeAdapter.BEAT_CH1_03_FIRST_NIGHT), "1. Sunset emits no N5.2 beat")
	tm.advance_time(tm.get_current_phase_duration() + 0.1)
	_check(not panel.is_open() and nm.current_day_number == 1, "1. Night 1 start emits no N5.2 beat and sets night_mgr.current_day_number == 1")

	tm.advance_time(tm.get_current_phase_duration() + 0.1)
	_check(tm.current_day == 2 and nm.current_day_number == 1, "6. TimeManager.current_day already advanced to 2 while night_mgr.current_day_number stayed 1")
	_check(panel.is_open() and a.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_03_FIRST_NIGHT, "2. Real Day 1 sunrise opens ch1_03_first_night")
	_check(panel.get_speaker_text() == "Monarch" and panel.get_body_text() == ChapterOneNarrativeAdapter.FIRST_NIGHT_HELD_TEXT, "7. Defense-held outcome selects exact success line")
	_check(not paused and not a.control_lock().is_locked() and player_node.is_physics_processing() and player_node.is_processing_unhandled_input(), "10 & 14. Panel open leaves world unpaused and player responsive")

	var prev_elapsed: float = tm.phase_elapsed
	tm.advance_time(5.0)
	_check(tm.phase_elapsed > prev_elapsed, "14. Day 2 TimeManager continues advancing while N5.2 panel is open")

	nm.night_encounter_resolved.emit(true, true)
	panel.advance()
	_check(not panel.is_open() and a.narrative_state().is_completed(ChapterOneNarrativeAdapter.BEAT_CH1_03_FIRST_NIGHT), "13. Normal close marks ch1_03_first_night complete once")
	nm.night_encounter_resolved.emit(true, true)
	_check(not panel.is_open() and a.narrative_state().completed_count() == 2, "4. Duplicate night_encounter_resolved does not reopen or duplicate")

	_trigger_real_sunrise_from_night(s, 2)
	_check(nm.current_day_number == 2 and not panel.is_open(), "3. Day 2 sunrise never triggers N5.2")

	_check(bool(s.call("save_game_state", TEST_SAVE_PATH)), "Saved Day 2+ fixture for Continue test")


func _test_outcome_wall_fell_and_breach_recovery() -> void:
	var s1: Node = await _load_shore(false)
	var a1: ChapterOneNarrativeAdapter = s1.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	_trigger_real_sunrise_from_night(s1, 1)
	_check(a1.dialogue_panel().is_open() and a1.dialogue_panel().get_body_text() == ChapterOneNarrativeAdapter.FIRST_NIGHT_WALL_FELL_TEXT, "8. Survived with wall not held selects exact wall-fell line")
	_check(a1.skip_active_beat() and a1.narrative_state().is_completed(ChapterOneNarrativeAdapter.BEAT_CH1_03_FIRST_NIGHT), "13. Skip completes ch1_03_first_night cleanly")

	var s2: Node = await _load_shore(false)
	var a2: ChapterOneNarrativeAdapter = s2.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var tm2: TimeManager = s2.get("time_manager") as TimeManager
	var nm2: NightEncounterManager = s2.get("night_mgr") as NightEncounterManager
	var p2: Node = s2.get("player") as Node
	tm2.auto_advance = false
	tm2.current_day = 1
	tm2.current_phase = TimeManager.Phase.SUNSET
	tm2.advance_time(tm2.get_current_phase_duration() + 0.1)
	nm2.settlement_breached = true
	tm2.advance_time(tm2.get_current_phase_duration() + 0.1)
	_check(int(s2.get("reign_state")) == ForgottenShoreSession.ReignState.BREACH_PENALTY, "9. Existing BREACH_PENALTY state preserved")
	_check(a2.dialogue_panel().is_open() and a2.dialogue_panel().get_body_text() == ChapterOneNarrativeAdapter.FIRST_NIGHT_BREACH_TEXT, "9. Breach outcome selects exact breach-recovery line")
	_check(not paused and not a2.control_lock().is_locked() and p2.is_physics_processing(), "10. Breach recovery leaves player responsive and unpaused")


func _test_island_cleared_ignored() -> void:
	var s: Node = await _load_shore(false)
	var a: ChapterOneNarrativeAdapter = s.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	s.set("reign_state", ForgottenShoreSession.ReignState.ISLAND_CLEARED)
	_trigger_real_sunrise_from_night(s, 1)
	_check(not a.dialogue_panel().is_open() and not a.narrative_state().is_completed(ChapterOneNarrativeAdapter.BEAT_CH1_03_FIRST_NIGHT), "5. ISLAND_CLEARED ignores first-night narrative")


func _test_dialogue_contention_pending_and_teardown() -> void:
	var s1: Node = await _load_shore(false)
	var a1: ChapterOneNarrativeAdapter = s1.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var bm1: BuildingManager = s1.get("building_mgr") as BuildingManager
	var ledger1: EconomyLedger = s1.get("economy") as EconomyLedger
	var panel1: DialoguePanel = a1.dialogue_panel()
	ledger1.try_add_bundle({"gold": 20, "wood": 20, "stone": 20})
	bm1.request_start_construction(BuildingManager.WALL_POSITION_X, ledger1, BuildingManager.WALL_ID)
	bm1.advance_construction(BuildingManager.BUILD_DURATION, BuildingManager.WALL_ID)
	_check(panel1.is_open() and a1.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_02_FOOTHOLD, "11. N5.1 foothold panel open before sunrise")
	_trigger_real_sunrise_from_night(s1, 1)
	_check(panel1.is_open() and a1.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_02_FOOTHOLD and a1.has_pending_first_night(), "11. N5.2 does not overwrite open N5.1 panel and queues single pending outcome")
	panel1.advance()
	_check(panel1.is_open() and a1.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_03_FIRST_NIGHT and not a1.has_pending_first_night(), "12. Closing N5.1 immediately presents pending N5.2 once")
	_check(panel1.get_body_text() == ChapterOneNarrativeAdapter.FIRST_NIGHT_HELD_TEXT, "12. Pending N5.2 preserved exact defense-held outcome")
	a1.teardown()
	_check(not panel1.is_open() and not a1.narrative_state().is_completed(ChapterOneNarrativeAdapter.BEAT_CH1_03_FIRST_NIGHT), "15. Teardown while N5.2 active closes panel and records no completion")

	var s2: Node = await _load_shore(false)
	var a2: ChapterOneNarrativeAdapter = s2.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var bm2: BuildingManager = s2.get("building_mgr") as BuildingManager
	var ledger2: EconomyLedger = s2.get("economy") as EconomyLedger
	var panel2: DialoguePanel = a2.dialogue_panel()
	ledger2.try_add_bundle({"gold": 20, "wood": 20, "stone": 20})
	bm2.request_start_construction(BuildingManager.WALL_POSITION_X, ledger2, BuildingManager.WALL_ID)
	bm2.advance_construction(BuildingManager.BUILD_DURATION, BuildingManager.WALL_ID)
	_trigger_real_sunrise_from_night(s2, 1)
	_check(a2.has_pending_first_night(), "16. N5.2 pending before teardown")
	a2.teardown()
	_check(not a2.has_pending_first_night() and not panel2.is_open() and not a2.narrative_state().is_completed(ChapterOneNarrativeAdapter.BEAT_CH1_03_FIRST_NIGHT), "16. Teardown while N5.2 pending clears it cleanly with no completion")


func _test_continue_day2_restore_silence_and_schema_v2() -> void:
	var s_cont: Node = await _load_shore(true)
	var a_cont: ChapterOneNarrativeAdapter = s_cont.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var tm_cont: TimeManager = s_cont.get("time_manager") as TimeManager
	var nm_cont: NightEncounterManager = s_cont.get("night_mgr") as NightEncounterManager
	_check(tm_cont.current_day >= 2 and nm_cont.first_night_survived, "17 & 19. Continue restored Day 2+ with first_night_survived=true")
	_check(not a_cont.is_active() and not a_cont.dialogue_panel().is_open() and a_cont.narrative_state().completed_count() == 0, "17 & 19. Startup Continue Day 2+ stays completely silent")

	var s_live: Node = await _load_shore(false)
	var a_live: ChapterOneNarrativeAdapter = s_live.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	_check(bool(s_live.call("load_game_state", TEST_SAVE_PATH)), "18. In-session restore succeeded")
	_check(not a_live.is_active() and not a_live.dialogue_panel().is_open() and a_live.narrative_state().completed_count() == 0, "18. In-session restore stays silent and keeps dispatch disabled")

	var payload: Dictionary = s_live.call("build_save_payload")
	var sm := SaveManager.new()
	_check(SaveManager.SCHEMA_VERSION == 2 and int(payload.get("schema_version", 0)) == 2 and sm.validate_payload(payload), "20. SaveManager schema v2 unchanged and payload valid")
	_check(not payload.has("ch1_03_first_night") and not payload.has("chapter1_narrative"), "20. Zero N5.2 per-beat fields in serialized payload")
