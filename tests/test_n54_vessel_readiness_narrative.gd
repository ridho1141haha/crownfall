extends SceneTree

## N5.4 Vessel Readiness Narrative (ch1_07_prepare_vessel) Integration Suite.

const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const TEST_DIR: String = "user://n54_test"
const SAVE_STAGE_2: String = "user://n54_test/save_stage2.json"
const SAVE_STAGE_3: String = "user://n54_test/save_stage3.json"
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
	printerr("TEST FAILURE: [N54] " + message)
	return false


func _snapshot_file(path: String) -> Dictionary:
	var existed: bool = FileAccess.file_exists(path)
	var content: String = FileAccess.get_file_as_string(path) if existed else ""
	return {"existed": existed, "content": content}


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup_fixtures() -> void:
	for p: String in [SAVE_STAGE_2, SAVE_STAGE_3]:
		_rm(p)
		for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
			_rm(p + suffix)
	var abs_dir: String = ProjectSettings.globalize_path(TEST_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.remove_absolute(abs_dir)
	for key: String in ["crownfall_load_on_start", "crownfall_menu_save_path"]:
		if Engine.has_meta(key):
			Engine.remove_meta(key)


func _load_shore(load_on_start: bool, save_path: String = SAVE_STAGE_3) -> Node:
	Engine.set_meta("crownfall_load_on_start", load_on_start)
	Engine.set_meta("crownfall_menu_save_path", save_path)
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


func _run() -> void:
	_real_profile_snap = _snapshot_file(REAL_PROFILE_PATH)
	_real_save_snap = _snapshot_file(SaveManager.DEFAULT_SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	await _test_repair_stages_and_set_sail_non_gating()
	await _test_contention_priority_skip_restore_and_teardown()
	await _test_continue_migration_and_schema_v2()
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
	_check(_snapshot_file(REAL_PROFILE_PATH) == _real_profile_snap, "Hygiene: real user://player_profile.json untouched")
	_check(_snapshot_file(SaveManager.DEFAULT_SAVE_PATH) == _real_save_snap, "Hygiene: real user://save_slot_0.json untouched")
	_cleanup_fixtures()
	if _failures == 0:
		print("PASS: All %d N54 Vessel Readiness Narrative checks completed with 0 failures." % _checks)
		quit(0)
	else:
		printerr("FAIL: N54 Vessel Readiness Narrative finished with %d failures out of %d checks." % [_failures, _checks])
		quit(1)


func _test_repair_stages_and_set_sail_non_gating() -> void:
	var s: Node = await _load_shore(false)
	if not _check(s != null, "1. Fresh Stage-0 ForgottenShore loaded"):
		return
	var a: ChapterOneNarrativeAdapter = s.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var prog: ProgressionState = s.get("progression") as ProgressionState
	var ledger: EconomyLedger = s.get("economy") as EconomyLedger
	var panel: DialoguePanel = a.dialogue_panel()
	_check(not panel.is_open() and int(s.get("shipwreck_stage")) == 0, "1. Fresh Stage-0 shows no readiness beat")
	prog.record_fact(ProgressionState.FACT_SHRINE_OF_GROWTH_ACTIVATED)
	_check(not panel.is_open() and not a.narrative_state().is_completed(ChapterOneNarrativeAdapter.BEAT_CH1_07_PREPARE_VESSEL), "9. Other progression facts do not trigger readiness beat")
	ledger.try_add_bundle({"gold": 4, "wood": 6, "stone": 3})
	_check(bool(s.call("_on_player_interact_shipwreck", ForgottenShoreSession.SHIPWRECK_X)) and not panel.is_open(), "2. Stage-1 repair shows no readiness beat")
	_check(bool(s.call("_on_player_interact_shipwreck", ForgottenShoreSession.SHIPWRECK_X)) and not panel.is_open(), "3. Stage-2 repair shows no readiness beat")
	_check(bool(s.call("save_game_state", SAVE_STAGE_2)), "Saved Stage-2 fixture")
	ledger.try_spend({"gold": ledger.get_amount(&"gold"), "wood": ledger.get_amount(&"wood"), "stone": ledger.get_amount(&"stone")})
	_check(not bool(s.call("_on_player_interact_shipwreck", ForgottenShoreSession.SHIPWRECK_X)) and not prog.has_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY) and not panel.is_open(), "8. Insufficient-resource Stage-3 repair does not record fact or show dialogue")
	ledger.try_add_bundle({"gold": 2, "wood": 2, "stone": 1})
	_check(bool(s.call("_on_player_interact_shipwreck", ForgottenShoreSession.SHIPWRECK_X)), "4 & 10. Live Stage-3 repair succeeded without Scientist or research")
	_check(int(s.get("shipwreck_stage")) == 3 and prog.has_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY), "4. Vessel-ready fact recorded on Stage-3 repair")
	_check(panel.is_open() and a.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_07_PREPARE_VESSEL, "5. Live Stage-3 repair triggers ch1_07_prepare_vessel once")
	_check(panel.get_speaker_text() == "Monarch" and panel.get_body_text() == ChapterOneNarrativeAdapter.VESSEL_READY_LINE, "6. Monarch speaker and exact readiness line verified")
	_check(not a.control_lock().is_locked() and not paused, "Non-gating: no lock and no pause")
	prog.fact_recorded.emit(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)
	_check(not a.has_pending_vessel_ready(), "7 & 23. Duplicate fact_recorded signal ignored")
	_check(bool(s.call("_on_player_interact_shipwreck", ForgottenShoreSession.SHIPWRECK_X)) and int(s.get("reign_state")) == ForgottenShoreSession.ReignState.ISLAND_CLEARED, "11 & 12. Set Sail still succeeds while readiness dialogue is open")
	_check(not prog.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED), "13 & 14. N5.4 never records FACT_ELDERGROVE_REACHED")
	panel.advance()
	_check(not panel.is_open() and a.narrative_state().is_completed(ChapterOneNarrativeAdapter.BEAT_CH1_07_PREPARE_VESSEL), "19. Normal close marks ch1_07_prepare_vessel complete once")
	_check(bool(s.call("save_game_state", SAVE_STAGE_3)), "Saved Stage-3 fixture")


func _test_contention_priority_skip_restore_and_teardown() -> void:
	# 15, 16, 17, 18. Contention across N5.1, N5.2, N5.3 and exact priority order
	var s1: Node = await _load_shore(false)
	var a1: ChapterOneNarrativeAdapter = s1.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var bm1: BuildingManager = s1.get("building_mgr") as BuildingManager
	var sp1: SpecialistDomain = s1.get("specialists") as SpecialistDomain
	var tm1: TimeManager = s1.get("time_manager") as TimeManager
	var prog1: ProgressionState = s1.get("progression") as ProgressionState
	var ledger1: EconomyLedger = s1.get("economy") as EconomyLedger
	var p1: DialoguePanel = a1.dialogue_panel()
	ledger1.try_add_bundle({"gold": 60, "wood": 60, "stone": 60})
	bm1.request_start_construction(BuildingManager.WALL_POSITION_X, ledger1, BuildingManager.WALL_ID)
	bm1.advance_construction(BuildingManager.BUILD_DURATION, BuildingManager.WALL_ID)
	_check(a1.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_02_FOOTHOLD, "15. N5.1 foothold open before rapid events")
	# Trigger N5.3 discovery, N5.4 vessel ready, and N5.2 first night while N5.1 is open
	sp1.try_discover(-1010.0, "scientist", prog1)
	for _k: int in range(3):
		s1.call("_on_player_interact_shipwreck", ForgottenShoreSession.SHIPWRECK_X)
	tm1.auto_advance = false
	tm1.current_day = 1
	tm1.current_phase = TimeManager.Phase.SUNSET
	tm1.advance_time(tm1.get_current_phase_duration() + 0.1)
	tm1.advance_time(tm1.get_current_phase_duration() + 0.1)
	_check(a1.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_02_FOOTHOLD and a1.has_pending_vessel_ready(), "15-17. Open panel not overwritten and vessel_ready queued")
	_check(a1.skip_active_beat() and a1.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_03_FIRST_NIGHT, "18 & 19. Priority 1: first_night opens after foothold skip")
	_check(a1.skip_active_beat() and a1.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_07_PREPARE_VESSEL, "18 & 19. Priority 2: vessel_ready opens before scientist_discovery")
	_check(a1.skip_active_beat() and a1.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_05_SCIENTIST_DISCOVERY, "18 & 19. Priority 3: scientist_discovery opens after vessel_ready skip")
	a1.skip_active_beat()
	_check(not p1.is_open() and not a1.has_any_pending_beat(), "19. All queued beats drained cleanly")

	# 20, 21, 22. begin_save_restore & teardown clear pending and stay silent
	var s2: Node = await _load_shore(false)
	var a2: ChapterOneNarrativeAdapter = s2.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var bm2: BuildingManager = s2.get("building_mgr") as BuildingManager
	var ledger2: EconomyLedger = s2.get("economy") as EconomyLedger
	ledger2.try_add_bundle({"gold": 60, "wood": 60, "stone": 60})
	bm2.request_start_construction(BuildingManager.WALL_POSITION_X, ledger2, BuildingManager.WALL_ID)
	bm2.advance_construction(BuildingManager.BUILD_DURATION, BuildingManager.WALL_ID)
	for _k: int in range(3):
		s2.call("_on_player_interact_shipwreck", ForgottenShoreSession.SHIPWRECK_X)
	_check(a2.has_pending_vessel_ready(), "20. Pending vessel_ready set before restore")
	_check(bool(s2.call("load_game_state", SAVE_STAGE_3)), "20 & 21. In-session restore succeeded")
	_check(not a2.has_pending_vessel_ready() and not a2.dialogue_panel().is_open() and not a2.is_active(), "20 & 21. Restore clears pending and remains silent")
	a2.teardown()
	_check(a2.is_torn_down() and a2.tracked_connection_count() == 0, "22. Teardown disconnects callbacks cleanly")


func _test_continue_migration_and_schema_v2() -> void:
	# 24 & 25. Continue with Stage-3 + vessel-ready fact stays silent
	var s3: Node = await _load_shore(true, SAVE_STAGE_3)
	var a3: ChapterOneNarrativeAdapter = s3.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var p3: ProgressionState = s3.get("progression") as ProgressionState
	_check(int(s3.get("shipwreck_stage")) == 3 and p3.has_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY), "24 & 25. Continue restored Stage-3 + vessel-ready fact")
	_check(not a3.is_active() and not a3.dialogue_panel().is_open() and a3.narrative_state().completed_count() == 0, "24 & 25. Continue with vessel-ready fact stays silent")
	var payload: Dictionary = s3.call("build_save_payload")

	# 26. Continue with Stage < 3 and no fact still permits Stage-3 repair cleanly
	var s2_cont: Node = await _load_shore(true, SAVE_STAGE_2)
	var p2_cont: ProgressionState = s2_cont.get("progression") as ProgressionState
	var l2_cont: EconomyLedger = s2_cont.get("economy") as EconomyLedger
	l2_cont.try_add_bundle({"gold": 10, "wood": 10, "stone": 10})
	_check(int(s2_cont.get("shipwreck_stage")) == 2 and not p2_cont.has_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY), "26. Stage-2 Continue restored without vessel-ready fact")
	_check(bool(s2_cont.call("_on_player_interact_shipwreck", ForgottenShoreSession.SHIPWRECK_X)) and p2_cont.has_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY), "26. Stage-2 Continue can still complete Stage-3 repair cleanly")

	# 27 & 28. SaveManager schema v2 invariant

	var sm := SaveManager.new()
	_check(SaveManager.SCHEMA_VERSION == 2 and int(payload.get("schema_version", 0)) == 2 and sm.validate_payload(payload), "27. SaveManager schema v2 unchanged and payload valid")
	_check(not payload.has("ch1_07_prepare_vessel") and not payload.has("chapter1_narrative"), "28. Zero N5.4 beat flags or adapter state in serialized payload")
