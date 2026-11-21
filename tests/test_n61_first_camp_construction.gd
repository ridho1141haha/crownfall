extends SceneTree

## N6.1 Eldergrove First Camp Construction Loop integration & regression suite.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const TEST_DIR: String = "user://n61_test"
const SAVE_ELDERGROVE: String = "user://n61_test/save_eldergrove.json"
const SAVE_SHORE: String = "user://n61_test/save_shore.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _base_payload: Dictionary = {}
var _camp_built_signals: int = 0
var _saved_gold: int = 0
var _saved_wood: int = 0
var _saved_stone: int = 0
var _saved_bytes: String = ""
var _routed_scenes: Array[String] = []


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n61_first_camp_construction] " + msg)
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
	for path: String in [SAVE_ELDERGROVE, SAVE_SHORE]:
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

	# Stage 0: Build valid schema v2 base fixture from ForgottenShore
	if _stage == 0:
		Engine.set_meta("crownfall_load_on_start", false)
		_check(change_scene_to_file(FORGOTTEN_SHORE_SCENE) == OK, "Loaded ForgottenShore.tscn to build valid v2 fixture")
		_stage = 1
		_wait_frames = 0
		return false

	# Stage 1: Prepare zero-wood/stone arrival fixture so player must gather before building
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
		_check(sm.save_state(shore_payload, SAVE_SHORE), "Wrote valid Forgotten Shore legacy save fixture")

		var eg_start_payload: Dictionary = _base_payload.duplicate(true)
		eg_start_payload["resources"] = {"gold": 2, "wood": 0, "stone": 0}

		var prog := ProgressionState.new()
		prog.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)
		var era := EraProgressionManager.new()
		Engine.set_meta("crownfall_menu_save_path", SAVE_ELDERGROVE)
		Engine.set_meta("crownfall_load_on_start", false)
		var tok: int = EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {
			"progression": prog,
			"era_mgr": era,
			"save_path": SAVE_ELDERGROVE,
			"base_save_payload": eg_start_payload,
		})
		_check(tok > 0, "Authorized N5.5 departure handoff into Eldergrove")
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Transitioned to EldergroveForest.tscn")
		_stage = 2
		_wait_frames = 0
		return false

	# Stage 2: Verify construction site init, insufficient resources, gathering, construction, idempotency, save
	if _stage == 2:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(eg.is_initialization_valid(), "Eldergrove scene initializes validly")
		_check(eg.camp_site_node != null and eg.camp_site_marker != null and eg.camp_shelter_sprite != null, "First Camp construction site visual nodes exist")
		_check(not eg.is_first_camp_built(), "First Camp starts not constructed")
		_check(eg.camp_site_marker.visible and not eg.camp_shelter_sprite.visible, "Initial visual state shows site marker and hides completed shelter")

		_camp_built_signals = 0
		eg.camp_constructed.connect(func(_cid: String, _cost: Dictionary) -> void: _camp_built_signals += 1)

		# Move to construction site with 0W / 0S and resolve interaction
		eg.player.global_position.x = EldergroveForestArrival.CAMP_SITE_X
		var target_before: Dictionary = eg.resolve_nearest_interaction(eg.player.global_position.x)
		_check(bool(target_before.get("has_target", false)) and String(target_before.get("target_id", "")) == EldergroveForestArrival.CAMP_SITE_ID, "InteractionResolver resolves First Camp construction site")
		_check(String(target_before.get("prompt_text", "")).contains("Need"), "Prompt distinguishes insufficient resources before gathering")

		# Attempt construction with insufficient resources -> rejected, zero deduction
		var res_insuff: Dictionary = eg.try_interact_at(eg.player.global_position.x)
		_check(not bool(res_insuff.get("ok", true)), "Insufficient resources prevent First Camp construction")
		_check(not eg.is_first_camp_built(), "Failed construction keeps First Camp unbuilt")
		_check(eg.ledger.get_amount(&"gold") == 2 and eg.ledger.get_amount(&"wood") == 0 and eg.ledger.get_amount(&"stone") == 0, "Failed construction deducts zero resources")
		_check(_camp_built_signals == 0, "Failed construction emits no camp_constructed signal")

		# Gather existing N6.0 Timber (+4W) and Stone (+3S) clearing nodes
		eg.player.global_position.x = -60.0
		_check(bool(eg.try_interact_at(eg.player.global_position.x).get("ok", false)), "N6.0 Timber node collection still works (+4W)")
		eg.player.global_position.x = 220.0
		_check(bool(eg.try_interact_at(eg.player.global_position.x).get("ok", false)), "N6.0 Stone node collection still works (+3S)")
		_check(eg.ledger.get_amount(&"wood") == 4 and eg.ledger.get_amount(&"stone") == 3, "Ledger holds gathered 4W and 3S")

		# Return to construction site -> prompt shows buildable, construction succeeds
		eg.player.global_position.x = EldergroveForestArrival.CAMP_SITE_X
		var target_ready: Dictionary = eg.resolve_nearest_interaction(eg.player.global_position.x)
		_check(String(target_ready.get("prompt_text", "")).contains("Build First Camp (4W 2S)"), "Prompt updates once resources meet 4W 2S requirement")

		var res_build: Dictionary = eg.try_interact_at(eg.player.global_position.x)
		_check(bool(res_build.get("ok", false)), "First Camp construction succeeds with sufficient resources")
		_check(eg.is_first_camp_built(), "Construction state flips to built")
		_check(_camp_built_signals == 1, "camp_constructed emitted exactly once")
		_check(eg.ledger.get_amount(&"wood") == 0 and eg.ledger.get_amount(&"stone") == 1 and eg.ledger.get_amount(&"gold") == 2, "Exact construction cost (4W 2S) deducted once")
		_check(not eg.camp_site_marker.visible and eg.camp_shelter_sprite.visible, "Completed visual state hides site marker and reveals shelter sprite")

		# Repeated interaction after construction is idempotent and never double-charges
		var res_repeat: Dictionary = eg.try_interact_at(eg.player.global_position.x)
		_check(not bool(res_repeat.get("ok", true)) and bool(res_repeat.get("already_built", false)), "Repeated interaction reports already built")
		_check(_camp_built_signals == 1, "Repeated interaction does not re-emit construction")
		_check(eg.ledger.get_amount(&"wood") == 0 and eg.ledger.get_amount(&"stone") == 1 and eg.ledger.get_amount(&"gold") == 2, "Repeated interaction does not double-charge resources")

		# Failed save must not report durable success or corrupt disk save
		var bytes_before_fail: String = FileAccess.get_file_as_string(SAVE_ELDERGROVE)
		_check(not eg.save_game_state(SAVE_ELDERGROVE, true), "Failed save returns false and never claims durable success")
		_check(FileAccess.get_file_as_string(SAVE_ELDERGROVE) == bytes_before_fail, "Failed save preserves previous valid save byte-exact")

		# Save constructed state under SaveManager schema v2
		_check(eg.save_game_state(SAVE_ELDERGROVE), "Saved Eldergrove state with constructed First Camp")
		_saved_gold = eg.ledger.get_amount(&"gold")
		_saved_wood = eg.ledger.get_amount(&"wood")
		_saved_stone = eg.ledger.get_amount(&"stone")
		_saved_bytes = FileAccess.get_file_as_string(SAVE_ELDERGROVE)

		var sm_chk := SaveManager.new()
		var loaded: Dictionary = sm_chk.load_state(SAVE_ELDERGROVE)
		_check(bool(loaded.get("ok", false)) and SaveManager.SCHEMA_VERSION == 2, "Constructed save passes SaveManager schema v2 validation unchanged")
		var pf: Dictionary = (loaded["data"] as Dictionary)["progression_flags"] as Dictionary
		var ns: Dictionary = pf.get("node_states", {}) as Dictionary
		_check(bool(ns.get(EldergroveForestArrival.CAMP_BUILT_STATE_KEY, false)), "Saved node_states persists eldergrove_first_camp_built = true")

		_check(eg.return_to_main_menu(), "Exited Eldergrove cleanly to Main.tscn")
		_stage = 3
		_wait_frames = 0
		return false

	# Stage 3: Verify Forgotten Shore Continue regression, then Continue into Eldergrove
	if _stage == 3:
		if current_scene == null or current_scene.name != "Main":
			return false
		var main_node: Node = current_scene
		_routed_scenes.clear()
		main_node.call("set_route_transition", func(path: String) -> void: _routed_scenes.append(path))
		Engine.set_meta("crownfall_menu_save_path", SAVE_SHORE)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_check(_routed_scenes.size() == 1 and _routed_scenes[0] == FORGOTTEN_SHORE_SCENE, "Regression: Legacy Forgotten Shore Continue remains unaffected")

		main_node.call("set_route_transition", Callable())
		Engine.set_meta("crownfall_menu_save_path", SAVE_ELDERGROVE)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_stage = 4
		_wait_frames = 0
		return false

	# Stage 4: Verify Continue restores built First Camp, visuals, balances, and node states without re-charging
	if _stage == 4:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg2: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(eg2.is_restored_from_continue(), "Eldergrove restored via N5.6 Continue path")
		_check(not eg2.is_handoff_acknowledged(), "N5.5 arrival handoff not replayed on Continue")
		_check(FileAccess.get_file_as_string(SAVE_ELDERGROVE) == _saved_bytes, "Continue restoration leaves disk save untouched byte-exact")
		_check(eg2.is_first_camp_built(), "Continue restores First Camp built state")
		_check(not eg2.camp_site_marker.visible and eg2.camp_shelter_sprite.visible, "Continue restores completed shelter visual state")
		_check(eg2.ledger.get_amount(&"gold") == _saved_gold and eg2.ledger.get_amount(&"wood") == _saved_wood and eg2.ledger.get_amount(&"stone") == _saved_stone, "Continue preserves exact resource balances without re-charging")
		_check(eg2.resource_mgr.is_collected("eldergrove_fallen_timber_01") and eg2.resource_mgr.is_collected("eldergrove_mossy_stone_01"), "Continue preserves collected N6.0 resource node states")
		_check(not eg2.resource_mgr.is_collected("eldergrove_foraged_supply_01"), "Uncollected Supply Crate remains available after Continue")

		var post_repeat: Dictionary = eg2.try_interact_at(EldergroveForestArrival.CAMP_SITE_X)
		_check(not bool(post_repeat.get("ok", true)) and bool(post_repeat.get("already_built", false)), "Post-Continue interaction on built First Camp stays idempotent")
		_check(eg2.ledger.get_amount(&"wood") == _saved_wood and eg2.ledger.get_amount(&"stone") == _saved_stone, "Post-Continue interaction deducts zero resources")

		_cleanup()
		print("PASS: All %d N61 First Camp Construction checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
