extends SceneTree

## N5.6 Island-Aware Continue & Save Restoration integration & contract suite.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const PROLOGUE_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const TEST_DIR: String = "user://n56_test"
const SAVE_SHORE: String = "user://n56_test/save_shore.json"
const SAVE_ELDERGROVE: String = "user://n56_test/save_eldergrove.json"
const SAVE_IRON_NO_FACT: String = "user://n56_test/save_iron_no_fact.json"
const SAVE_MALFORMED: String = "user://n56_test/save_malformed.json"
const PROFILE_FALSE: String = "user://n56_test/profile_false.json"
const PROFILE_TRUE: String = "user://n56_test/profile_true.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _base_payload: Dictionary = {}
var _eldergrove_save_bytes: String = ""
var _shore_save_bytes: String = ""
var _routed_scenes: Array[String] = []


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n56_island_continue] " + msg)
		_cleanup()
		quit(1)
		return false
	print("PASS: " + msg)
	return true


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_raw(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.flush()
		f.close()


func _cleanup() -> void:
	EldergroveHandoffBridge.reset_for_tests()
	for meta_key: String in ["crownfall_menu_save_path", "crownfall_profile_path", "crownfall_load_on_start"]:
		if Engine.has_meta(meta_key):
			Engine.remove_meta(meta_key)
	for path: String in [SAVE_SHORE, SAVE_ELDERGROVE, SAVE_IRON_NO_FACT, SAVE_MALFORMED, PROFILE_FALSE, PROFILE_TRUE]:
		_rm(path)
		for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
			_rm(path + suffix)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	_cleanup()


func _process(_delta: float) -> bool:
	_wait_frames += 1
	if _wait_frames > MAX_WAIT_FRAMES:
		_check(false, "Timed out at stage %d" % _stage)
		return true

	if _stage == 0:
		Engine.set_meta("crownfall_load_on_start", false)
		_check(change_scene_to_file(FORGOTTEN_SHORE_SCENE) == OK, "Loaded ForgottenShore.tscn to build valid v2 fixtures")
		_stage = 1
		_wait_frames = 0
		return false

	if _stage == 1:
		if current_scene == null or not (current_scene is ForgottenShoreSession):
			return false
		var sess: ForgottenShoreSession = current_scene as ForgottenShoreSession
		_base_payload = sess.build_save_payload()

		var sm := SaveManager.new()
		var shore_payload: Dictionary = _base_payload.duplicate(true)
		(shore_payload["progression_flags"] as Dictionary)["era_id"] = "stone_age"
		(shore_payload["progression_flags"] as Dictionary)["progression_facts"] = [
			ProgressionState.FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2,
			ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY,
		]
		_check(sm.save_state(shore_payload, SAVE_SHORE), "Wrote valid Forgotten Shore save fixture")
		_shore_save_bytes = FileAccess.get_file_as_string(SAVE_SHORE)

		var eg_payload: Dictionary = _base_payload.duplicate(true)
		(eg_payload["progression_flags"] as Dictionary)["era_id"] = "iron_age"
		(eg_payload["progression_flags"] as Dictionary)["progression_facts"] = [
			ProgressionState.FACT_ELDERGROVE_REACHED,
			ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY,
		]
		_check(sm.save_state(eg_payload, SAVE_ELDERGROVE), "Wrote valid Eldergrove save fixture")
		_eldergrove_save_bytes = FileAccess.get_file_as_string(SAVE_ELDERGROVE)

		var iron_no_fact: Dictionary = _base_payload.duplicate(true)
		(iron_no_fact["progression_flags"] as Dictionary)["era_id"] = "iron_age"
		(iron_no_fact["progression_flags"] as Dictionary)["progression_facts"] = [
			ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY,
		]
		_check(sm.save_state(iron_no_fact, SAVE_IRON_NO_FACT), "Wrote iron_age-without-fact fixture")

		_write_raw(SAVE_MALFORMED, "{not valid json")
		_write_raw(PROFILE_FALSE, JSON.stringify({"schema_version": 1, "prologue_completed_once": false}, "	"))
		_write_raw(PROFILE_TRUE, JSON.stringify({"schema_version": 1, "prologue_completed_once": true}, "	"))

		_check(change_scene_to_file(MAIN_SCENE) == OK, "Loaded Main.tscn for destination resolution and routing tests")
		_stage = 2
		_wait_frames = 0
		return false

	if _stage == 2:
		if current_scene == null or current_scene.name != "Main":
			return false
		var main_node: Node = current_scene

		_check(String(main_node.call("resolve_continue_destination", SAVE_SHORE)) == FORGOTTEN_SHORE_SCENE, "Resolution: Forgotten Shore save without Eldergrove fact routes to Forgotten Shore")
		_check(String(main_node.call("resolve_continue_destination", SAVE_ELDERGROVE)) == ELDERGROVE_SCENE, "Resolution: save with FACT_ELDERGROVE_REACHED routes to Eldergrove")

		var raw_iron_payload: Dictionary = _base_payload.duplicate(true)
		(raw_iron_payload["progression_flags"] as Dictionary)["era_id"] = "iron_age"
		(raw_iron_payload["progression_flags"] as Dictionary)["progression_facts"] = [ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY]
		_check(String(main_node.call("resolve_continue_destination_from_payload", raw_iron_payload)) == FORGOTTEN_SHORE_SCENE, "Resolution: iron_age without FACT_ELDERGROVE_REACHED in payload does not route to Eldergrove")
		_check(String(main_node.call("resolve_continue_destination", SAVE_IRON_NO_FACT)) == FORGOTTEN_SHORE_SCENE, "Resolution: iron_age without FACT_ELDERGROVE_REACHED on disk does not route to Eldergrove")

		_check(String(main_node.call("resolve_continue_destination", SAVE_MALFORMED)) == FORGOTTEN_SHORE_SCENE, "Resolution: malformed save does not route to Eldergrove")
		_check(String(main_node.call("resolve_continue_destination_from_payload", "bad")) == FORGOTTEN_SHORE_SCENE, "Resolution: non-dictionary payload does not route to Eldergrove")

		var missing_pf: Dictionary = _base_payload.duplicate(true)
		missing_pf.erase("progression_flags")
		_check(String(main_node.call("resolve_continue_destination_from_payload", missing_pf)) == FORGOTTEN_SHORE_SCENE, "Resolution: missing progression_flags fails safely to Forgotten Shore")

		_routed_scenes.clear()
		main_node.call("set_route_transition", func(path: String) -> void: _routed_scenes.append(path))

		Engine.set_meta("crownfall_profile_path", PROFILE_FALSE)
		Engine.set_meta("crownfall_menu_save_path", SAVE_MALFORMED)
		main_node.set("_route_started", false)
		main_node.call("_begin_new_game_entry")
		_check(_routed_scenes.size() == 1 and _routed_scenes[0] == PROLOGUE_SCENE, "Regression: New Game with uncompleted profile routes to Prologue")

		_routed_scenes.clear()
		Engine.set_meta("crownfall_profile_path", PROFILE_TRUE)
		main_node.set("_route_started", false)
		main_node.call("_start_new_game")
		_check(_routed_scenes.size() == 1 and _routed_scenes[0] == FORGOTTEN_SHORE_SCENE and not bool(Engine.get_meta("crownfall_load_on_start", true)), "Regression: Skip Prologue starts fresh Forgotten Shore session")

		_routed_scenes.clear()
		Engine.set_meta("crownfall_menu_save_path", SAVE_SHORE)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_check(_routed_scenes.size() == 1 and _routed_scenes[0] == FORGOTTEN_SHORE_SCENE and bool(Engine.get_meta("crownfall_load_on_start", false)), "Regression: Continue with Forgotten Shore save routes to Forgotten Shore")

		EldergroveHandoffBridge.reset_for_tests()
		main_node.call("set_route_transition", Callable())
		Engine.set_meta("crownfall_menu_save_path", SAVE_ELDERGROVE)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_stage = 3
		_wait_frames = 0
		return false

	if _stage == 3:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var arrival: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(arrival.is_initialization_valid(), "Continue: EldergroveForest validates initialization")
		_check(arrival.is_restored_from_continue(), "Continue: EldergroveForest initializes via Continue without N5.5 handoff token")
		_check(not arrival.is_handoff_acknowledged(), "Continue: does not fake or trigger N5.5 departure handoff acknowledgement")
		_check(not EldergroveHandoffBridge.has_pending_intent(), "Continue: no lingering N5.5 handoff intent")
		_check(arrival.progression != null and arrival.progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED), "Continue: FACT_ELDERGROVE_REACHED restored on progression")
		_check(arrival.progression.has_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY), "Continue: existing vessel-ready fact preserved on progression")
		_check(arrival.progression.fact_count() == 2, "Continue: exact saved fact count restored without duplicate recording")
		_check(arrival.era_mgr != null and arrival.era_mgr.get_era_id() == "iron_age", "Continue: saved iron_age era restored consistently")
		_check(not arrival.was_persisted_on_arrival(), "Continue: does not rewrite save during Continue restoration")
		_check(FileAccess.get_file_as_string(SAVE_ELDERGROVE) == _eldergrove_save_bytes, "Continue: existing Eldergrove save on disk left untouched byte-exact")
		_check(arrival.is_player_control_restored(), "Continue: player control restored after successful restoration")
		_check(not paused, "Continue: SceneTree not paused after restoration")

		Engine.set_meta("crownfall_menu_save_path", SAVE_SHORE)
		Engine.set_meta("crownfall_load_on_start", true)
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Loaded EldergroveForest for missing-fact Continue failure test")
		_stage = 4
		_wait_frames = 0
		return false

	if _stage == 4:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var arr_missing_fact: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(not arr_missing_fact.is_restored_from_continue(), "Failed Continue (missing Eldergrove fact): not reported as restored")
		_check(arr_missing_fact.get_last_status_reason() == "missing_eldergrove_fact", "Failed Continue (missing Eldergrove fact): reports missing_eldergrove_fact")
		_check(arr_missing_fact.progression == null, "Failed Continue (missing Eldergrove fact): no partial progression state")
		_check(FileAccess.get_file_as_string(SAVE_SHORE) == _shore_save_bytes, "Failed Continue (missing Eldergrove fact): previous valid save untouched byte-exact")
		_check(arr_missing_fact.is_player_control_restored(), "Failed Continue (missing Eldergrove fact): player control restored safely")

		Engine.set_meta("crownfall_menu_save_path", SAVE_MALFORMED)
		Engine.set_meta("crownfall_load_on_start", true)
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Loaded EldergroveForest for malformed-save Continue failure test")
		_stage = 5
		_wait_frames = 0
		return false

	if _stage == 5:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var arr_malformed: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(not arr_malformed.is_restored_from_continue(), "Failed Continue (malformed save): not reported as restored")
		_check(arr_malformed.get_last_status_reason() == "save_load_failed", "Failed Continue (malformed save): reports save_load_failed")
		_check(arr_malformed.is_player_control_restored(), "Failed Continue (malformed save): player control restored safely")
		_check(FileAccess.get_file_as_string(SAVE_ELDERGROVE) == _eldergrove_save_bytes, "Failed Continue (malformed save): valid Eldergrove save unaffected")

		_cleanup()
		print("PASS: All %d N56 Island Continue checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
