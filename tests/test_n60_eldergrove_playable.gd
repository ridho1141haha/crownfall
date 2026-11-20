extends SceneTree

## N6.0 Eldergrove First Playable Slice integration & regression suite.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const PROLOGUE_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const TEST_DIR: String = "user://n60_test"
const SAVE_ELDERGROVE: String = "user://n60_test/save_eldergrove.json"
const SAVE_SHORE: String = "user://n60_test/save_shore.json"
const PROFILE_FALSE: String = "user://n60_test/profile_false.json"
const PROFILE_TRUE: String = "user://n60_test/profile_true.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _base_payload: Dictionary = {}
var _saved_gold_after: int = 0
var _saved_wood_after: int = 0
var _saved_stone_after: int = 0
var _saved_player_x: float = 0.0
var _saved_bytes_after_play: String = ""
var _routed_scenes: Array[String] = []


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n60_eldergrove_playable] " + msg)
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
	Input.action_release("move_left")
	Input.action_release("move_right")
	EldergroveHandoffBridge.reset_for_tests()
	for meta_key: String in ["crownfall_menu_save_path", "crownfall_profile_path", "crownfall_load_on_start"]:
		if Engine.has_meta(meta_key):
			Engine.remove_meta(meta_key)
	for path: String in [SAVE_ELDERGROVE, SAVE_SHORE, PROFILE_FALSE, PROFILE_TRUE]:
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

	# Stage 0: Load ForgottenShore to build valid schema v2 fixtures
	if _stage == 0:
		Engine.set_meta("crownfall_load_on_start", false)
		_check(change_scene_to_file(FORGOTTEN_SHORE_SCENE) == OK, "Loaded ForgottenShore.tscn to build valid v2 fixtures")
		_stage = 1
		_wait_frames = 0
		return false

	# Stage 1: Build Eldergrove & Forgotten Shore fixtures, then enter Eldergrove via N5.5 handoff
	if _stage == 1:
		if current_scene == null or not (current_scene is ForgottenShoreSession):
			return false
		var sess: ForgottenShoreSession = current_scene as ForgottenShoreSession
		_base_payload = sess.build_save_payload()

		var sm := SaveManager.new()
		var shore_payload: Dictionary = _base_payload.duplicate(true)
		(shore_payload["progression_flags"] as Dictionary)["era_id"] = "stone_age"
		(shore_payload["progression_flags"] as Dictionary)["progression_facts"] = [
			ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY,
		]
		_check(sm.save_state(shore_payload, SAVE_SHORE), "Wrote valid Forgotten Shore legacy fixture")

		_write_raw(PROFILE_FALSE, JSON.stringify({"schema_version": 1, "prologue_completed_once": false}, "	"))
		_write_raw(PROFILE_TRUE, JSON.stringify({"schema_version": 1, "prologue_completed_once": true}, "	"))

		var prog := ProgressionState.new()
		prog.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)
		var era := EraProgressionManager.new()
		Engine.set_meta("crownfall_menu_save_path", SAVE_ELDERGROVE)
		Engine.set_meta("crownfall_load_on_start", false)
		var tok: int = EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {
			"progression": prog,
			"era_mgr": era,
			"save_path": SAVE_ELDERGROVE,
			"base_save_payload": _base_payload,
		})
		_check(tok > 0, "Authorized N5.5 departure handoff into Eldergrove")
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Transitioned to EldergroveForest.tscn")
		_stage = 2
		_wait_frames = 0
		return false

	# Stage 2: Verify Eldergrove initialization, spawn, movement, bounds, interaction, and save
	if _stage == 2:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(eg.is_initialization_valid(), "Eldergrove scene initializes validly")
		_check(eg.is_handoff_acknowledged(), "N5.5 arrival handoff acknowledged")
		_check(eg.was_persisted_on_arrival(), "N5.5 arrival persisted cleanly")
		_check(eg.is_player_control_restored(), "Player control restored on entry")
		_check(eg.player != null and is_equal_approx(eg.player.global_position.x, EldergroveForestArrival.PLAYER_SPAWN_X), "Player spawns at intentional Eldergrove clearing position")
		_check(eg.player.min_bound_x == EldergroveForestArrival.MIN_BOUND_X and eg.player.max_bound_x == EldergroveForestArrival.MAX_BOUND_X, "Player movement bounds configured to Eldergrove clearing")
		var cam: Camera2D = eg.player.get_node_or_null("Camera2D") as Camera2D
		_check(cam != null and cam.limit_left == -800 and cam.limit_right == 800, "Camera2D limits match Eldergrove bounds")

		# Movement integration using real PlayerController._physics_process + Input actions
		var start_x: float = eg.player.global_position.x
		Input.action_press("move_right")
		for _i: int in range(20):
			eg.player._physics_process(0.016)
		Input.action_release("move_right")
		var moved_right_x: float = eg.player.global_position.x
		_check(moved_right_x > start_x + 20.0, "PlayerController moves right with move_right input")

		Input.action_press("move_left")
		for _i: int in range(10):
			eg.player._physics_process(0.016)
		Input.action_release("move_left")
		_check(eg.player.global_position.x < moved_right_x - 10.0, "PlayerController moves left with move_left input")

		# Navigation / boundary clamping
		eg.player.global_position.x = EldergroveForestArrival.MAX_BOUND_X + 200.0
		eg.player._physics_process(0.016)
		_check(eg.player.global_position.x <= EldergroveForestArrival.MAX_BOUND_X, "Player position clamped at east clearing boundary")
		eg.player.global_position.x = EldergroveForestArrival.MIN_BOUND_X - 200.0
		eg.player._physics_process(0.016)
		_check(eg.player.global_position.x >= EldergroveForestArrival.MIN_BOUND_X, "Player position clamped at west clearing boundary")

		# Out-of-range interaction rejected cleanly
		eg.player.global_position.x = EldergroveForestArrival.PLAYER_SPAWN_X
		var res_far: Dictionary = eg.try_interact_at(eg.player.global_position.x)
		_check(not bool(res_far.get("ok", true)), "Interaction rejected when out of range of clearing nodes")

		# Move into range of first clearing resource node (Fallen Timber at x = -60.0)
		eg.player.global_position.x = -60.0
		var resolved: Dictionary = eg.resolve_nearest_interaction(eg.player.global_position.x)
		_check(bool(resolved.get("has_target", false)) and String(resolved.get("target_id", "")) == "eldergrove_fallen_timber_01", "InteractionResolver detects nearest Eldergrove resource node")

		var wood_before: int = eg.ledger.get_amount(&"wood")
		var res_collect: Dictionary = eg.try_interact_at(eg.player.global_position.x)
		_check(bool(res_collect.get("ok", false)), "Player collects Eldergrove Fallen Timber node")
		_check(eg.ledger.get_amount(&"wood") == wood_before + 4, "EconomyLedger credited +4 wood from Eldergrove interaction")
		_check(eg.resource_mgr.is_collected("eldergrove_fallen_timber_01"), "Collected Eldergrove node marked collected")
		_check(eg.has_unsaved_progress(), "Unsaved progress flag set after Eldergrove interaction")

		# Duplicate interaction at same node rejected
		var res_dup: Dictionary = eg.try_interact_at(eg.player.global_position.x)
		_check(not bool(res_dup.get("ok", true)), "Duplicate collection of already-gathered node rejected")
		_check(eg.ledger.get_amount(&"wood") == wood_before + 4, "Rejected duplicate interaction grants zero extra wood")

		# Move to second node (Mossy Stone at x = 220.0) and verify manual save
		eg.player.global_position.x = 220.0
		var stone_before: int = eg.ledger.get_amount(&"stone")
		_check(bool(eg.try_interact_at(eg.player.global_position.x).get("ok", false)), "Player collects Eldergrove Mossy Stone node")
		_check(eg.ledger.get_amount(&"stone") == stone_before + 3, "EconomyLedger credited +3 stone")

		# Verify failed save does not overwrite valid save
		var before_fail_bytes: String = FileAccess.get_file_as_string(SAVE_ELDERGROVE)
		_check(not eg.save_game_state(SAVE_ELDERGROVE, true), "Simulated save failure returns false")
		_check(FileAccess.get_file_as_string(SAVE_ELDERGROVE) == before_fail_bytes, "Failed save leaves existing valid save untouched byte-exact")
		_check(not eg.save_game_state("../unsafe_escape.json"), "Unsafe save path rejected safely")

		# Perform real manual save in Eldergrove
		_check(eg._on_manual_save(), "Manual save succeeds in Eldergrove using SaveManager schema v2")
		_check(not eg.has_unsaved_progress(), "Unsaved progress flag cleared after successful save")
		_saved_gold_after = eg.ledger.get_amount(&"gold")
		_saved_wood_after = eg.ledger.get_amount(&"wood")
		_saved_stone_after = eg.ledger.get_amount(&"stone")
		_saved_player_x = eg.player.global_position.x
		_saved_bytes_after_play = FileAccess.get_file_as_string(SAVE_ELDERGROVE)

		# Verify schema v2 unchanged and no duplicate progression facts
		var sm_chk := SaveManager.new()
		var reloaded: Dictionary = sm_chk.load_state(SAVE_ELDERGROVE)
		_check(bool(reloaded.get("ok", false)), "Saved Eldergrove payload passes SaveManager v2 validation")
		var d: Dictionary = reloaded["data"] as Dictionary
		_check(int(d.get("schema_version", 0)) == SaveManager.SCHEMA_VERSION and SaveManager.SCHEMA_VERSION == 2, "SaveManager schema version remains v2")
		var pf: Dictionary = d["progression_flags"] as Dictionary
		var facts: Array = pf.get("progression_facts", []) as Array
		_check(facts.count(ProgressionState.FACT_ELDERGROVE_REACHED) == 1, "FACT_ELDERGROVE_REACHED appears exactly once in saved progression_facts")

		# Exit scene cleanly to Main Menu
		_check(eg.return_to_main_menu(), "Cleanly exited Eldergrove scene to Main.tscn")
		_stage = 3
		_wait_frames = 0
		return false

	# Stage 3: From Main.tscn, verify legacy/New Game regressions, then Continue back into Eldergrove
	if _stage == 3:
		if current_scene == null or current_scene.name != "Main":
			return false
		var main_node: Node = current_scene
		_check(not paused, "SceneTree unpaused after returning to Main Menu")
		_check(not EldergroveHandoffBridge.has_pending_intent(), "No stray N5.5 handoff intent after exiting Eldergrove")

		# Regression: Forgotten Shore Continue & New Game flows remain intact
		_routed_scenes.clear()
		main_node.call("set_route_transition", func(path: String) -> void: _routed_scenes.append(path))

		Engine.set_meta("crownfall_profile_path", PROFILE_FALSE)
		Engine.set_meta("crownfall_menu_save_path", SAVE_SHORE)
		main_node.set("_route_started", false)
		main_node.call("_begin_new_game_entry")
		_check(_routed_scenes.size() == 1 and _routed_scenes[0] == PROLOGUE_SCENE, "Regression: New Game with uncompleted profile routes to Prologue")

		_routed_scenes.clear()
		Engine.set_meta("crownfall_profile_path", PROFILE_TRUE)
		main_node.set("_route_started", false)
		main_node.call("_start_new_game")
		_check(_routed_scenes.size() == 1 and _routed_scenes[0] == FORGOTTEN_SHORE_SCENE, "Regression: Skip Prologue starts fresh Forgotten Shore session")

		_routed_scenes.clear()
		Engine.set_meta("crownfall_menu_save_path", SAVE_SHORE)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_check(_routed_scenes.size() == 1 and _routed_scenes[0] == FORGOTTEN_SHORE_SCENE, "Regression: Legacy Forgotten Shore Continue routes to Forgotten Shore")

		# Now Continue into Eldergrove with the saved gameplay state
		main_node.call("set_route_transition", Callable())
		Engine.set_meta("crownfall_menu_save_path", SAVE_ELDERGROVE)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_stage = 4
		_wait_frames = 0
		return false

	# Stage 4: Verify re-entry via Continue restores gameplay state without replaying N5.5 arrival
	if _stage == 4:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg2: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(eg2.is_initialization_valid(), "Re-entered Eldergrove scene validly via Continue")
		_check(eg2.is_restored_from_continue(), "Continue restoration path active on re-entry")
		_check(not eg2.is_handoff_acknowledged(), "N5.5 voyage/arrival handoff NOT replayed on Continue")
		_check(not eg2.was_persisted_on_arrival(), "Continue restoration does not rewrite save on load")
		_check(FileAccess.get_file_as_string(SAVE_ELDERGROVE) == _saved_bytes_after_play, "Save file untouched byte-exact during Continue load")
		_check(eg2.is_player_control_restored(), "Player control restored after Continue re-entry")
		_check(eg2.progression != null and eg2.progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED), "FACT_ELDERGROVE_REACHED preserved after re-entry")
		_check(eg2.progression.fact_count() == 2, "No duplicate progression facts created across save/exit/re-entry")
		_check(eg2.era_mgr != null and eg2.era_mgr.get_era_id() == "iron_age", "Saved iron_age era preserved after re-entry")
		_check(eg2.ledger.get_amount(&"gold") == _saved_gold_after and eg2.ledger.get_amount(&"wood") == _saved_wood_after and eg2.ledger.get_amount(&"stone") == _saved_stone_after, "Saved EconomyLedger balances restored across exit/re-entry")
		_check(eg2.resource_mgr.is_collected("eldergrove_fallen_timber_01"), "Collected Fallen Timber node stays collected after Continue")
		_check(eg2.resource_mgr.is_collected("eldergrove_mossy_stone_01"), "Collected Mossy Stone node stays collected after Continue")
		_check(not eg2.resource_mgr.is_collected("eldergrove_foraged_supply_01"), "Uncollected Supply Crate remains available after Continue")
		_check(is_equal_approx(eg2.player.global_position.x, _saved_player_x), "Saved Eldergrove player position restored on Continue")

		# Verify uncollected 3rd node is still interactable after Continue re-entry
		eg2.player.global_position.x = 500.0
		_check(bool(eg2.try_interact_at(eg2.player.global_position.x).get("ok", false)), "Remaining clearing node interactable after Continue re-entry")
		_check(eg2.ledger.get_amount(&"gold") == _saved_gold_after + 3, "EconomyLedger credited +3 gold after Continue re-entry")

		_cleanup()
		print("PASS: All %d N60 Eldergrove Playable checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
