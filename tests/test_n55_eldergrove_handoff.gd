extends SceneTree

## N5.5 Voyage & Eldergrove Arrival handoff integration & contract suite.

const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const TEST_DIR: String = "user://n55_test"
const TEST_SAVE_PATH: String = "user://n55_test/save_slot_0.json"
const TEST_SAVE_FAIL_PATH: String = "user://n55_test/save_slot_fail.json"
const TEST_PROFILE_PATH: String = "user://n55_test/player_profile.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _auth_progression: ProgressionState = null
var _auth_era: EraProgressionManager = null
var _saved_before: String = ""
var _valid_base_payload: Dictionary = {}
var _fact_signal_count: int = 0
var _neg_progression: ProgressionState = null
var _fail_progression: ProgressionState = null
var _fail_era: EraProgressionManager = null
var _fail_save_before: String = ""


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n55_eldergrove_handoff] " + msg)
		_cleanup()
		quit(1)
		return false
	print("PASS: " + msg)
	return true


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup() -> void:
	EldergroveHandoffBridge.reset_for_tests()
	for meta_key: String in ["crownfall_menu_save_path", "crownfall_profile_path", "crownfall_load_on_start"]:
		if Engine.has_meta(meta_key):
			Engine.remove_meta(meta_key)
	for path: String in [TEST_SAVE_PATH, TEST_SAVE_FAIL_PATH, TEST_PROFILE_PATH]:
		_rm(path)
		for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
			_rm(path + suffix)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	_cleanup()


func _close_active_dialogue_if_any(session: Node) -> void:
	for child: Node in session.get_children():
		if child is DialoguePanel and (child as DialoguePanel).is_open():
			(child as DialoguePanel).close()


func _run_bridge_unit_tests() -> void:
	EldergroveHandoffBridge.reset_for_tests()
	_check(EldergroveHandoffBridge.authorize_departure("", {}) == 0, "Bridge rejects empty destination")
	_check(not EldergroveHandoffBridge.has_pending_intent(), "No pending intent after empty destination")

	var res_missing: Dictionary = EldergroveHandoffBridge.acknowledge_destination_ready(ELDERGROVE_SCENE, true, 1)
	_check(not bool(res_missing.get("ok", true)) and String(res_missing.get("reason", "")) == "no_pending_intent", "Bridge rejects ack when no intent is pending")

	var tok: int = EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {"source": "unit"})
	_check(tok > 0, "Bridge creates positive one-shot token")
	_check(EldergroveHandoffBridge.has_pending_intent(), "Bridge reports pending intent after authorization")
	_check(EldergroveHandoffBridge.pending_token() == tok, "pending_token() matches authorized token")

	var res_wrong_dest: Dictionary = EldergroveHandoffBridge.acknowledge_destination_ready("res://scenes/world/Other.tscn", true, tok)
	_check(not bool(res_wrong_dest.get("ok", true)) and String(res_wrong_dest.get("reason", "")) == "wrong_destination", "Bridge rejects wrong destination")
	_check(EldergroveHandoffBridge.has_pending_intent(), "Pending intent remains unconsumed after wrong_destination")

	var res_stale: Dictionary = EldergroveHandoffBridge.acknowledge_destination_ready(ELDERGROVE_SCENE, true, tok + 99)
	_check(not bool(res_stale.get("ok", true)) and String(res_stale.get("reason", "")) == "stale_token", "Bridge rejects stale token")

	var res_ok: Dictionary = EldergroveHandoffBridge.acknowledge_destination_ready(ELDERGROVE_SCENE, true, tok)
	_check(bool(res_ok.get("ok", false)) and int(res_ok.get("token", 0)) == tok, "Bridge accepts valid destination and matching token")
	_check(not EldergroveHandoffBridge.has_pending_intent(), "One-shot intent consumed on valid ack")

	var res_dup: Dictionary = EldergroveHandoffBridge.acknowledge_destination_ready(ELDERGROVE_SCENE, true, tok)
	_check(not bool(res_dup.get("ok", true)) and String(res_dup.get("reason", "")) == "no_pending_intent", "Bridge rejects duplicate acknowledgement")

	var tok_inv: int = EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {})
	_check(tok_inv > tok, "Token sequence increments monotonically")
	var res_bad_init: Dictionary = EldergroveHandoffBridge.acknowledge_destination_ready(ELDERGROVE_SCENE, false, tok_inv)
	_check(not bool(res_bad_init.get("ok", true)) and String(res_bad_init.get("reason", "")) == "destination_invalid", "Bridge rejects invalid destination init")
	_check(not EldergroveHandoffBridge.has_pending_intent(), "Invalid destination init clears pending intent")

	EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {})
	EldergroveHandoffBridge.invalidate_pending("explicit_cancel")
	_check(not EldergroveHandoffBridge.has_pending_intent(), "Explicit invalidation clears pending intent")
	_check(String(EldergroveHandoffBridge.last_result().get("reason", "")) == "explicit_cancel", "Explicit invalidation records reason")


func _process(_delta: float) -> bool:
	_wait_frames += 1
	if _wait_frames > MAX_WAIT_FRAMES:
		_check(false, "Timed out at stage %d" % _stage)
		return true

	if _stage == 0:
		_run_bridge_unit_tests()
		Engine.set_meta("crownfall_load_on_start", false)
		Engine.set_meta("crownfall_menu_save_path", TEST_SAVE_PATH)
		var err: Error = change_scene_to_file(FORGOTTEN_SHORE_SCENE)
		_check(err == OK, "Loaded ForgottenShore.tscn for source departure tests")
		_stage = 1
		_wait_frames = 0
		return false

	if _stage == 1:
		if current_scene == null or not (current_scene is ForgottenShoreSession):
			return false
		var session: ForgottenShoreSession = current_scene as ForgottenShoreSession
		_check(session.shipwreck_stage == 0, "Fresh ForgottenShore starts at shipwreck_stage 0")
		_check(not session._on_player_interact_shipwreck(ForgottenShoreSession.SHIPWRECK_X), "Departure rejected when ship not fully repaired (no resources)")
		_check(not EldergroveHandoffBridge.has_pending_intent(), "No handoff intent created when ship not repaired")

		session.shipwreck_stage = 3
		session.progression.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)
		var n54_was_open: bool = session._is_narrative_dialogue_busy()
		_check(not session.progression.has_fact(ProgressionState.FACT_SCIENTIST_RECRUITED), "Scientist not recruited before departure test")
		_check(session.research_mgr.get_completed_tech_ids().is_empty(), "No research completed before departure test")
		_check(not session._on_player_interact_shipwreck(0.0), "Departure rejected when player outside interaction range")

		_valid_base_payload = session.build_save_payload()
		_check(session.save_game_state(TEST_SAVE_PATH), "Saved baseline Forgotten Shore state")
		_saved_before = FileAccess.get_file_as_string(TEST_SAVE_PATH)

		session.set_voyage_scene_changer(func(_path: String) -> int: return ERR_CANT_OPEN)
		_check(session._on_player_interact_shipwreck(ForgottenShoreSession.SHIPWRECK_X), "Set Sail succeeds when ship repaired and in range without Scientist/research")
		if n54_was_open:
			_check(session._is_narrative_dialogue_busy(), "Set Sail does not close or interfere with active N5.4 readiness dialogue")
			_close_active_dialogue_if_any(session)
		_check(session.progression.has_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY), "Existing vessel-readiness fact remains intact")
		_check(not session.progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED), "FACT_ELDERGROVE_REACHED not recorded at departure")
		_check(session.reign_state != ForgottenShoreSession.ReignState.ISLAND_CLEARED, "No premature ISLAND_CLEARED set at departure")
		_check(not session._on_player_interact_shipwreck(ForgottenShoreSession.SHIPWRECK_X), "Duplicate Set Sail interaction rejected")
		_check(not paused, "SceneTree not paused during voyage transition")

		session.skip_voyage_transition()
		_check(not EldergroveHandoffBridge.has_pending_intent(), "Failed scene change invalidates pending intent")
		_check(not session.progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED), "Failed scene change does not record arrival fact")
		_check(session.reign_state == ForgottenShoreSession.ReignState.ACTIVE, "Failed scene change keeps reign_state ACTIVE")
		_check(session.player.is_physics_processing() and session.player.is_processing_unhandled_input(), "Failed scene change restores player control")
		_check(FileAccess.get_file_as_string(TEST_SAVE_PATH) == _saved_before, "Failed scene change preserves last known-good save")

		_check(session._on_player_interact_shipwreck(ForgottenShoreSession.SHIPWRECK_X), "Set Sail works again after failed transition recovery")
		session.cancel_voyage_transition("test_cancel")
		_check(not EldergroveHandoffBridge.has_pending_intent(), "Cancelled voyage invalidates pending intent")
		_check(not session.progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED), "Cancelled voyage does not record arrival fact")
		_check(session.player.is_physics_processing() and session.player.is_processing_unhandled_input(), "Cancelled voyage restores player control")

		session.set_voyage_scene_changer(Callable())
		_auth_progression = session.progression
		_auth_era = session.era_mgr
		_fact_signal_count = 0
		_auth_progression.fact_recorded.connect(func(fid: String) -> void:
			if fid == ProgressionState.FACT_ELDERGROVE_REACHED:
				_fact_signal_count += 1
		)
		_check(session._on_player_interact_shipwreck(ForgottenShoreSession.SHIPWRECK_X), "Committed real Set Sail departure")
		_check(EldergroveHandoffBridge.has_pending_intent(), "Pending intent exists before voyage completion")
		session.skip_voyage_transition()
		_stage = 2
		_wait_frames = 0
		return false

	if _stage == 2:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var arrival: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(arrival.is_initialization_valid(), "EldergroveForest validates initialization")
		_check(arrival.is_handoff_acknowledged(), "EldergroveForest acknowledges one-shot handoff")
		_check(arrival.is_runtime_milestone_recorded(), "EldergroveForest reports runtime milestone recorded")
		_check(arrival.was_persisted_on_arrival(), "EldergroveForest reports durable arrival persistence succeeded")
		_check(arrival.get_persistence_failure_reason().is_empty(), "No persistence failure reason on successful save")
		_check(not EldergroveHandoffBridge.has_pending_intent(), "Pending handoff intent consumed after arrival")
		_check(arrival.progression == _auth_progression, "EldergroveForest uses authoritative ProgressionState instance")
		_check(_auth_progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED), "FACT_ELDERGROVE_REACHED recorded after acknowledgement")
		_check(_fact_signal_count == 1, "FACT_ELDERGROVE_REACHED emitted exactly once")
		_check(_auth_era.get_era_id() == "iron_age", "EraProgressionManager notified after FACT_ELDERGROVE_REACHED recorded")
		_check(arrival.is_player_control_restored(), "Player control restored after Eldergrove arrival")
		_check(not paused, "SceneTree not paused after arrival")

		# Verify actual SaveManager output by reloading the saved payload from disk
		var sm_verify := SaveManager.new()
		var loaded_after: Dictionary = sm_verify.load_state(TEST_SAVE_PATH)
		_check(bool(loaded_after.get("ok", false)), "Reloading saved payload after arrival succeeds via SaveManager")
		var loaded_pf: Dictionary = (loaded_after["data"] as Dictionary)["progression_flags"] as Dictionary
		var loaded_facts: Array = loaded_pf.get("progression_facts", []) as Array
		_check(loaded_facts.has(ProgressionState.FACT_ELDERGROVE_REACHED), "Reloaded save payload preserves FACT_ELDERGROVE_REACHED")
		_check(String(loaded_pf.get("era_id", "")) == "iron_age", "Reloaded save payload preserves iron_age era_id")

		var dup_ack: Dictionary = EldergroveHandoffBridge.acknowledge_destination_ready(ELDERGROVE_SCENE, true, 0)
		_check(not bool(dup_ack.get("ok", true)), "Duplicate ack after arrival rejected")

		# Stage 3: Load EldergroveForest without pending intent
		EldergroveHandoffBridge.reset_for_tests()
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Reloaded EldergroveForest without pending intent")
		_stage = 3
		_wait_frames = 0
		return false

	if _stage == 3:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var arrival2: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(not arrival2.is_handoff_acknowledged(), "Destination without valid intent does not acknowledge")
		_check(not arrival2.is_runtime_milestone_recorded(), "Destination without valid intent does not record runtime milestone")
		_check(not arrival2.was_persisted_on_arrival(), "Destination without valid intent does not claim persistence")
		_check(arrival2.progression == null, "Destination without valid intent has no progression milestone mutation")
		_check(arrival2.is_player_control_restored(), "Destination without valid intent does not lock player permanently")

		# Stage 4: Missing ProgressionState in source_context
		EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {
			"era_mgr": EraProgressionManager.new(),
			"save_path": TEST_SAVE_PATH,
			"base_save_payload": _valid_base_payload,
		})
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Loaded EldergroveForest for missing ProgressionState test")
		_stage = 4
		_wait_frames = 0
		return false

	if _stage == 4:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var arr_no_prog: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(not arr_no_prog.is_handoff_acknowledged(), "Missing ProgressionState rejects handoff acknowledgement")
		_check(arr_no_prog.get_last_status_reason() == "missing_or_invalid_progression", "Missing ProgressionState reports missing_or_invalid_progression")
		_check(arr_no_prog.progression == null, "Missing ProgressionState never synthesizes a replacement ProgressionState")
		_check(not EldergroveHandoffBridge.has_pending_intent(), "Invalid context intent is invalidated")
		_check(arr_no_prog.is_player_control_restored(), "Player control restored after missing ProgressionState rejection")

		# Stage 5: Invalid ProgressionState reference (wrong type)
		EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {
			"progression": "not_a_progression_state",
			"era_mgr": EraProgressionManager.new(),
			"save_path": TEST_SAVE_PATH,
			"base_save_payload": _valid_base_payload,
		})
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Loaded EldergroveForest for invalid ProgressionState test")
		_stage = 5
		_wait_frames = 0
		return false

	if _stage == 5:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var arr_bad_prog: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(not arr_bad_prog.is_handoff_acknowledged(), "Invalid ProgressionState reference rejects handoff acknowledgement")
		_check(arr_bad_prog.get_last_status_reason() == "missing_or_invalid_progression", "Invalid ProgressionState reports missing_or_invalid_progression")
		_check(arr_bad_prog.is_player_control_restored(), "Player control restored after invalid ProgressionState rejection")

		# Stage 6: Missing EraProgressionManager
		_neg_progression = ProgressionState.new()
		EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {
			"progression": _neg_progression,
			"save_path": TEST_SAVE_PATH,
			"base_save_payload": _valid_base_payload,
		})
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Loaded EldergroveForest for missing EraProgressionManager test")
		_stage = 6
		_wait_frames = 0
		return false

	if _stage == 6:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var arr_no_era: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(not arr_no_era.is_handoff_acknowledged(), "Missing EraProgressionManager rejects handoff acknowledgement")
		_check(arr_no_era.get_last_status_reason() == "missing_or_invalid_era_manager", "Missing EraProgressionManager reports missing_or_invalid_era_manager")
		_check(not _neg_progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED), "Missing EraProgressionManager does not record FACT_ELDERGROVE_REACHED")
		_check(arr_no_era.is_player_control_restored(), "Player control restored after missing EraProgressionManager rejection")

		# Stage 7: Invalid persistence context (unsafe save path & malformed payload)
		_neg_progression = ProgressionState.new()
		EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {
			"progression": _neg_progression,
			"era_mgr": EraProgressionManager.new(),
			"save_path": "../escape.json",
			"base_save_payload": {},
		})
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Loaded EldergroveForest for invalid persistence context test")
		_stage = 7
		_wait_frames = 0
		return false

	if _stage == 7:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var arr_bad_persist: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(not arr_bad_persist.is_handoff_acknowledged(), "Invalid persistence context rejects handoff acknowledgement")
		_check(arr_bad_persist.get_last_status_reason() == "invalid_persistence_context", "Invalid persistence context reports invalid_persistence_context")
		_check(not _neg_progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED), "Invalid persistence context does not record FACT_ELDERGROVE_REACHED")
		_check(arr_bad_persist.is_player_control_restored(), "Player control restored after invalid persistence context rejection")

		# Stage 8: SaveManager persistence failure preserves previous valid save & exposes failure explicitly
		var sm_prep := SaveManager.new()
		_check(sm_prep.save_state(_valid_base_payload, TEST_SAVE_FAIL_PATH), "Prepared previous known-good save for persistence failure test")
		_fail_save_before = FileAccess.get_file_as_string(TEST_SAVE_FAIL_PATH)
		_fail_progression = ProgressionState.new()
		_fail_progression.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)
		_fail_era = EraProgressionManager.new()
		EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {
			"progression": _fail_progression,
			"era_mgr": _fail_era,
			"save_path": TEST_SAVE_FAIL_PATH,
			"base_save_payload": _valid_base_payload,
			"_test_simulate_save_failure": true,
		})
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Loaded EldergroveForest for save persistence failure test")
		_stage = 8
		_wait_frames = 0
		return false

	if _stage == 8:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var arr_fail_save: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(arr_fail_save.is_handoff_acknowledged(), "Persistence failure still acknowledges valid arrival handoff")
		_check(arr_fail_save.is_runtime_milestone_recorded() and _fail_progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED), "Persistence failure keeps runtime FACT_ELDERGROVE_REACHED intact")
		_check(not arr_fail_save.was_persisted_on_arrival(), "Persistence failure never reports durable persistence success")
		_check(not arr_fail_save.get_persistence_failure_reason().is_empty(), "Persistence failure exposes non-empty failure reason")
		_check(arr_fail_save.get_last_status_reason() == "arrival_persistence_failed", "Persistence failure exposes arrival_persistence_failed status")
		_check(arr_fail_save.get_persistence_attempts() == EldergroveForestArrival.MAX_PERSIST_ATTEMPTS, "Persistence failure performs bounded retries")
		_check(arr_fail_save.is_player_control_restored(), "Player control restored safely after persistence failure")
		_check(FileAccess.get_file_as_string(TEST_SAVE_FAIL_PATH) == _fail_save_before, "Persistence failure preserves previous valid save byte-exact")
		var sm_fail_chk := SaveManager.new()
		var fail_reloaded: Dictionary = sm_fail_chk.load_state(TEST_SAVE_FAIL_PATH)
		_check(bool(fail_reloaded.get("ok", false)), "Previous valid save remains loadable via SaveManager after persistence failure")
		var fail_pf: Dictionary = (fail_reloaded["data"] as Dictionary)["progression_flags"] as Dictionary
		_check(not (fail_pf.get("progression_facts", []) as Array).has(ProgressionState.FACT_ELDERGROVE_REACHED), "Previous valid save on disk does not falsely contain FACT_ELDERGROVE_REACHED")

		# Stage 9: Load Main.tscn for New Game / Continue invalidation tests
		_check(change_scene_to_file(MAIN_SCENE) == OK, "Loaded Main.tscn for New Game / Continue invalidation tests")
		_stage = 9
		_wait_frames = 0
		return false

	if _stage == 9:
		if current_scene == null or current_scene.name != "Main":
			return false
		var main_node: Node = current_scene
		main_node.call("set_route_transition", func(_p: String) -> void: pass)

		EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {})
		_check(EldergroveHandoffBridge.has_pending_intent(), "Pending intent set before New Game")
		main_node.call("_start_new_game")
		_check(not EldergroveHandoffBridge.has_pending_intent(), "New Game invalidates old pending Eldergrove intent")

		main_node.set("_route_started", false)
		EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {})
		_check(EldergroveHandoffBridge.has_pending_intent(), "Pending intent set before Continue")
		main_node.call("_on_continue_button_pressed")
		_check(not EldergroveHandoffBridge.has_pending_intent(), "Continue invalidates old pending Eldergrove intent")

		_cleanup()
		print("PASS: All %d N55 Eldergrove Handoff checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
