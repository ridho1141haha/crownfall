extends SceneTree

## N5.3 Optional Scientist & Research Narrative Integration Suite.

const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const TEST_DIR: String = "user://n53_test"
const SAVE_DISC_ONLY: String = "user://n53_test/save_disc.json"
const SAVE_RECRUITED: String = "user://n53_test/save_recruited.json"
const SAVE_ACTIVE_RES: String = "user://n53_test/save_active_res.json"
const SAVE_DONE_RES: String = "user://n53_test/save_done_res.json"
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
	printerr("TEST FAILURE: [N53] " + message)
	return false


func _snapshot_file(path: String) -> Dictionary:
	var existed: bool = FileAccess.file_exists(path)
	var content: String = FileAccess.get_file_as_string(path) if existed else ""
	return {"existed": existed, "content": content}


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup_fixtures() -> void:
	for p: String in [SAVE_DISC_ONLY, SAVE_RECRUITED, SAVE_ACTIVE_RES, SAVE_DONE_RES]:
		_rm(p)
		for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
			_rm(p + suffix)
	var abs_dir: String = ProjectSettings.globalize_path(TEST_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.remove_absolute(abs_dir)
	for key: String in ["crownfall_load_on_start", "crownfall_menu_save_path"]:
		if Engine.has_meta(key):
			Engine.remove_meta(key)


func _load_shore(load_on_start: bool, save_path: String = SAVE_DISC_ONLY) -> Node:
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


func _build_scientist_hut(session: Node) -> void:
	var bm: BuildingManager = session.get("building_mgr") as BuildingManager
	var ledger: EconomyLedger = session.get("economy") as EconomyLedger
	ledger.try_add_bundle({"gold": 30, "wood": 30, "stone": 30})
	var hut_x: float = float((bm.get_plot(SpecialistDomain.SCIENTIST_HUT_PLOT_ID) as Dictionary).get("position_x", -980.0))
	bm.request_start_construction(hut_x, ledger, SpecialistDomain.SCIENTIST_HUT_PLOT_ID)
	bm.advance_construction(BuildingManager.BUILD_DURATION * 2.0, SpecialistDomain.SCIENTIST_HUT_PLOT_ID)


func _run() -> void:
	_real_profile_snap = _snapshot_file(REAL_PROFILE_PATH)
	_real_save_snap = _snapshot_file(SaveManager.DEFAULT_SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	await _test_discovery_recruitment_and_research_flow()
	await _test_optionality_for_vessel_departure()
	await _test_contention_ordering_skip_and_teardown()
	await _test_continue_restore_silence_and_schema_v2()
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
		print("PASS: All %d N53 Scientist Research Narrative checks completed with 0 failures." % _checks)
		quit(0)
	else:
		printerr("FAIL: N53 Scientist Research Narrative finished with %d failures out of %d checks." % [_failures, _checks])
		quit(1)


func _test_discovery_recruitment_and_research_flow() -> void:
	var s: Node = await _load_shore(false)
	if not _check(s != null, "1. Fresh ForgottenShore loaded"):
		return
	var a: ChapterOneNarrativeAdapter = s.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var sp: SpecialistDomain = s.get("specialists") as SpecialistDomain
	var rm: ResearchManager = s.get("research_mgr") as ResearchManager
	var prog: ProgressionState = s.get("progression") as ProgressionState
	var ledger: EconomyLedger = s.get("economy") as EconomyLedger
	var bm: BuildingManager = s.get("building_mgr") as BuildingManager
	var panel: DialoguePanel = a.dialogue_panel()
	_check(a != null and a.is_active(), "1. Fresh session has active adapter")
	_check(not sp.try_discover(0.0, "scientist", prog) and not panel.is_open(), "5. Out-of-range discovery fails and shows no dialogue")
	sp.specialist_discovered.emit("blacksmith")
	_check(not panel.is_open() and a.narrative_state().completed_count() == 0, "6. Other specialist ID does not trigger Scientist beat")
	ledger.try_add_bundle({"gold": 30, "wood": 30, "stone": 30})
	_check(not rm.try_start("inscription_studies", prog, ledger) and not panel.is_open(), "13 & 15. Research blocked before Scientist recruitment with no dialogue")
	_check(sp.try_discover(-1010.0, "scientist", prog), "2. Real Scientist discovery succeeded")
	_check(panel.is_open() and a.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_05_SCIENTIST_DISCOVERY, "2. Discovery opens ch1_05_scientist_discovery")
	_check(panel.get_speaker_text() == "The Scientist" and panel.get_body_text() == ChapterOneNarrativeAdapter.SCIENTIST_DISCOVERY_LINE_1, "3. Discovery line 1 speaker and text match")
	panel.advance()
	_check(panel.is_open() and panel.get_speaker_text() == "Monarch" and panel.get_body_text() == ChapterOneNarrativeAdapter.SCIENTIST_DISCOVERY_LINE_2, "3. Discovery line 2 Monarch response matches")
	panel.advance()
	_check(not panel.is_open() and a.narrative_state().is_completed(ChapterOneNarrativeAdapter.BEAT_CH1_05_SCIENTIST_DISCOVERY), "2. Discovery completed once")
	_check(not prog.has_fact(ProgressionState.FACT_SCIENTIST_RECRUITED), "7. Discovery does not set recruitment fact")
	sp.specialist_discovered.emit("scientist")
	_check(not panel.is_open() and a.narrative_state().completed_count() == 1, "4. Duplicate discovery does not replay")
	_check(bool(s.call("save_game_state", SAVE_DISC_ONLY)), "Saved discovered-only fixture")
	_check(not sp.try_recruit(-1010.0, "scientist", prog, bm, ledger) and not panel.is_open(), "9. Missing housing rejects recruitment and shows no dialogue")
	_build_scientist_hut(s)
	_check(sp.try_recruit(-1010.0, "scientist", prog, bm, ledger), "8. Real Scientist recruitment succeeded")
	_check(panel.is_open() and a.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_05_SCIENTIST_RECRUITMENT, "8. Recruitment opens separate ch1_05_scientist_recruitment beat")
	_check(panel.get_speaker_text() == "The Scientist" and panel.get_body_text() == ChapterOneNarrativeAdapter.SCIENTIST_RECRUITMENT_LINE, "8. Recruitment speaker and text match")
	panel.advance()
	_check(not panel.is_open() and a.narrative_state().is_completed(ChapterOneNarrativeAdapter.BEAT_CH1_05_SCIENTIST_RECRUITMENT), "11. Both discovery and recruitment completed in one session")
	sp.specialist_recruited.emit("scientist")
	_check(not panel.is_open() and a.narrative_state().completed_count() == 2, "10. Duplicate recruitment does not replay")
	_check(bool(s.call("save_game_state", SAVE_RECRUITED)), "Saved recruited-only fixture")
	_check(not rm.try_start("nonexistent_tech", prog, ledger) and not panel.is_open(), "15. Invalid tech start rejected with no dialogue")
	_check(rm.try_start("inscription_studies", prog, ledger), "14. Real first research started")
	_check(panel.is_open() and a.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_06_RESEARCH, "14. First research opens ch1_06_research")
	_check(panel.get_speaker_text() == "Monarch" and panel.get_body_text() == ChapterOneNarrativeAdapter.FIRST_RESEARCH_LINE, "14. Research Monarch line matches")
	panel.advance()
	_check(not panel.is_open() and a.narrative_state().is_completed(ChapterOneNarrativeAdapter.BEAT_CH1_06_RESEARCH), "14. Research beat marked complete once")
	_check(bool(s.call("save_game_state", SAVE_ACTIVE_RES)), "Saved active-research fixture")
	rm.advance_research(999.0)
	_check(rm.is_completed("inscription_studies") and not panel.is_open() and a.narrative_state().completed_count() == 3, "16 & 17. Research completes normally without replaying ch1_06_research")
	_check(bool(s.call("save_game_state", SAVE_DONE_RES)), "Saved completed-research fixture")


func _test_optionality_for_vessel_departure() -> void:
	var s: Node = await _load_shore(false)
	var prog: ProgressionState = s.get("progression") as ProgressionState
	var rm: ResearchManager = s.get("research_mgr") as ResearchManager
	var ledger: EconomyLedger = s.get("economy") as EconomyLedger
	ledger.try_add_bundle({"gold": 99, "wood": 99, "stone": 99})
	_check(not prog.has_fact(ProgressionState.FACT_SCIENTIST_DISCOVERED) and not prog.has_fact(ProgressionState.FACT_SCIENTIST_RECRUITED) and rm.get_completed_tech_ids().is_empty(), "12 & 18. Starting with no Scientist and no research")
	for _step: int in range(3):
		_check(bool(s.call("_on_player_interact_shipwreck", ForgottenShoreSession.SHIPWRECK_X)), "12 & 18. Shipwreck repair stage succeeded without Scientist/research")
	_check(prog.has_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY), "12 & 18. Vessel ready recorded without Scientist/research")
	_check(bool(s.call("_on_player_interact_shipwreck", ForgottenShoreSession.SHIPWRECK_X)) and bool(s.call("is_departure_in_progress")) and EldergroveHandoffBridge.has_pending_intent() and int(s.get("reign_state")) == ForgottenShoreSession.ReignState.ACTIVE, "12 & 18. Set Sail succeeds without Scientist or research")
	s.call("cancel_voyage_transition", "n53_test_cleanup")


func _test_contention_ordering_skip_and_teardown() -> void:
	var s1: Node = await _load_shore(false)
	var a1: ChapterOneNarrativeAdapter = s1.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var bm1: BuildingManager = s1.get("building_mgr") as BuildingManager
	var sp1: SpecialistDomain = s1.get("specialists") as SpecialistDomain
	var rm1: ResearchManager = s1.get("research_mgr") as ResearchManager
	var prog1: ProgressionState = s1.get("progression") as ProgressionState
	var ledger1: EconomyLedger = s1.get("economy") as EconomyLedger
	var p1: DialoguePanel = a1.dialogue_panel()
	ledger1.try_add_bundle({"gold": 60, "wood": 60, "stone": 60})
	_build_scientist_hut(s1)
	bm1.request_start_construction(BuildingManager.WALL_POSITION_X, ledger1, BuildingManager.WALL_ID)
	bm1.advance_construction(BuildingManager.BUILD_DURATION, BuildingManager.WALL_ID)
	_check(p1.is_open() and a1.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_02_FOOTHOLD, "19. N5.1 panel open before rapid N5.3 events")
	_check(sp1.try_discover(-1010.0, "scientist", prog1), "19. Discovery succeeded while panel open")
	_check(sp1.try_recruit(-1010.0, "scientist", prog1, bm1, ledger1), "20. Recruitment succeeded while panel open")
	_check(rm1.try_start("inscription_studies", prog1, ledger1), "21. Research started while panel open")
	_check(a1.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_02_FOOTHOLD and a1.has_any_pending_beat(), "19-22. Open panel was never overwritten and pending beats preserved")
	_check(a1.skip_active_beat() and a1.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_05_SCIENTIST_DISCOVERY, "22 & 23. Closing foothold opens pending Scientist discovery")
	_check(a1.skip_active_beat() and a1.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_05_SCIENTIST_RECRUITMENT, "22 & 23. Skipping discovery opens pending Scientist recruitment")
	_check(a1.skip_active_beat() and a1.active_beat_id() == ChapterOneNarrativeAdapter.BEAT_CH1_06_RESEARCH, "22 & 23. Skipping recruitment opens pending first research")
	p1.advance()
	_check(not p1.is_open() and not a1.has_any_pending_beat() and a1.narrative_state().completed_count() == 4, "22 & 23. All 4 beats completed once in deterministic order")
	var s2: Node = await _load_shore(false)
	var a2: ChapterOneNarrativeAdapter = s2.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var sp2: SpecialistDomain = s2.get("specialists") as SpecialistDomain
	var bm2: BuildingManager = s2.get("building_mgr") as BuildingManager
	var prog2: ProgressionState = s2.get("progression") as ProgressionState
	var ledger2: EconomyLedger = s2.get("economy") as EconomyLedger
	var p2: DialoguePanel = a2.dialogue_panel()
	ledger2.try_add_bundle({"gold": 40, "wood": 40, "stone": 40})
	_build_scientist_hut(s2)
	sp2.try_discover(-1010.0, "scientist", prog2)
	sp2.try_recruit(-1010.0, "scientist", prog2, bm2, ledger2)
	_check(p2.is_open() and a2.has_any_pending_beat(), "24 & 25. Active discovery + pending recruitment before teardown")
	a2.teardown()
	_check(a2.is_torn_down() and not p2.is_open() and not a2.has_any_pending_beat() and a2.tracked_connection_count() == 0, "24, 25, 26. Teardown closes panel, clears pending, disconnects all signals")
	_check(a2.narrative_state().completed_count() == 0, "24. Cancelled active/pending beats not marked complete")


func _test_continue_restore_silence_and_schema_v2() -> void:
	var s_disc: Node = await _load_shore(true, SAVE_DISC_ONLY)
	var a_disc: ChapterOneNarrativeAdapter = s_disc.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var sp_disc: SpecialistDomain = s_disc.get("specialists") as SpecialistDomain
	var bm_disc: BuildingManager = s_disc.get("building_mgr") as BuildingManager
	var prog_disc: ProgressionState = s_disc.get("progression") as ProgressionState
	var ledger_disc: EconomyLedger = s_disc.get("economy") as EconomyLedger
	_check(prog_disc.has_fact(ProgressionState.FACT_SCIENTIST_DISCOVERED) and not a_disc.is_active() and not a_disc.dialogue_panel().is_open(), "27. Continue with discovery fact does not replay discovery")
	_build_scientist_hut(s_disc)
	_check(sp_disc.try_recruit(-1010.0, "scientist", prog_disc, bm_disc, ledger_disc) and prog_disc.has_fact(ProgressionState.FACT_SCIENTIST_RECRUITED) and not a_disc.dialogue_panel().is_open(), "31. Discovered-only save still permits normal recruitment while staying restore-silent")
	var s_rec: Node = await _load_shore(true, SAVE_RECRUITED)
	var a_rec: ChapterOneNarrativeAdapter = s_rec.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	_check(not a_rec.is_active() and not a_rec.dialogue_panel().is_open() and a_rec.narrative_state().completed_count() == 0, "28. Continue with recruitment fact does not replay discovery or recruitment")
	var s_act: Node = await _load_shore(true, SAVE_ACTIVE_RES)
	var a_act: ChapterOneNarrativeAdapter = s_act.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var rm_act: ResearchManager = s_act.get("research_mgr") as ResearchManager
	_check(rm_act.has_active_research() and not a_act.is_active() and not a_act.dialogue_panel().is_open(), "29. Continue with active research does not replay ch1_06_research")
	var s_done: Node = await _load_shore(true, SAVE_DONE_RES)
	var a_done: ChapterOneNarrativeAdapter = s_done.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var rm_done: ResearchManager = s_done.get("research_mgr") as ResearchManager
	_check(not rm_done.get_completed_tech_ids().is_empty() and not a_done.is_active() and not a_done.dialogue_panel().is_open(), "30. Continue with completed research does not replay ch1_06_research")
	var s_live: Node = await _load_shore(false)
	var a_live: ChapterOneNarrativeAdapter = s_live.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var sp_live: SpecialistDomain = s_live.get("specialists") as SpecialistDomain
	var prog_live: ProgressionState = s_live.get("progression") as ProgressionState
	sp_live.try_discover(-1010.0, "scientist", prog_live)
	_check(bool(s_live.call("load_game_state", SAVE_RECRUITED)), "32. In-session restore succeeded")
	_check(not a_live.is_active() and not a_live.has_any_pending_beat() and not a_live.dialogue_panel().is_open(), "32. In-session restore cancels active/pending beats and stays silent")
	var payload: Dictionary = s_live.call("build_save_payload")
	var sm := SaveManager.new()
	_check(SaveManager.SCHEMA_VERSION == 2 and int(payload.get("schema_version", 0)) == 2 and sm.validate_payload(payload), "33. SaveManager schema v2 unchanged and payload valid")
	_check(not payload.has("ch1_05_scientist") and not payload.has("ch1_06_research") and not payload.has("chapter1_narrative"), "34. Zero N5.3 beat flags or adapter state in serialized payload")
