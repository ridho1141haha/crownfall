extends SceneTree

## N6.3 First Camp Rest & Time Skip integration & regression suite.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const TEST_DIR: String = "user://n63_test"
const SAVE_ELDERGROVE: String = "user://n63_test/save_eldergrove.json"
const SAVE_SHORE: String = "user://n63_test/save_shore.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _base_payload: Dictionary = {}
var _sunrise_signals: int = 0
var _night_signals: int = 0
var _saved_gold: int = 0
var _saved_wood: int = 0
var _saved_stone: int = 0
var _routed_scenes: Array[String] = []


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n63_first_camp_rest] " + msg)
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

	# Stage 0: Load ForgottenShore to build valid schema v2 fixtures
	if _stage == 0:
		Engine.set_meta("crownfall_load_on_start", false)
		_check(change_scene_to_file(FORGOTTEN_SHORE_SCENE) == OK, "Loaded ForgottenShore.tscn to build valid v2 fixtures")
		_stage = 1
		_wait_frames = 0
		return false

	# Stage 1: Prepare fixtures and enter Eldergrove via N5.5 handoff
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
		_check(sm.save_state(shore_payload, SAVE_SHORE), "Wrote Forgotten Shore legacy fixture")

		var eg_start_payload: Dictionary = _base_payload.duplicate(true)
		eg_start_payload["day_count"] = 2
		eg_start_payload["world_time"] = 5.0
		eg_start_payload["world_phase"] = "daylight"
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

	# Stage 2: Test unbuilt rest rejection, construction, Daylight rejection, Sunset rest, Night rest, and save
	if _stage == 2:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg.time_manager.auto_advance = false
		_sunrise_signals = 0
		_night_signals = 0
		eg.time_manager.sunrise_reached.connect(func(_d: int) -> void: _sunrise_signals += 1)
		eg.time_manager.night_started.connect(func(_d: int) -> void: _night_signals += 1)

		# 1. Rest unavailable before First Camp construction (even during Sunset)
		eg.time_manager.advance_time(eg.time_manager.daylight_duration)
		_check(eg.time_manager.current_phase == TimeManager.Phase.SUNSET, "Advanced to Day 2 Sunset before camp build")
		_check(not eg.can_rest_at_camp(), "can_rest_at_camp() is false before First Camp is built")
		var res_unbuilt: Dictionary = eg.try_rest_at_camp(EldergroveForestArrival.CAMP_SITE_X)
		_check(not bool(res_unbuilt.get("ok", true)), "Rest rejected before First Camp construction")
		_check(eg.time_manager.current_day == 2 and eg.time_manager.current_phase == TimeManager.Phase.SUNSET, "Rejected unbuilt rest does not advance clock")

		# 2. Gather clearing resources and construct First Camp (existing N6.1 flow intact)
		_check(bool(eg.try_interact_at(-60.0).get("ok", false)), "Collected renewable Fallen Timber (+4W)")
		_check(bool(eg.try_interact_at(220.0).get("ok", false)), "Collected renewable Mossy Stone (+3S)")
		_check(bool(eg.try_interact_at(500.0).get("ok", false)), "Collected non-renewable Supply Crate (+3G)")
		var target_unbuilt: Dictionary = eg.resolve_nearest_interaction(EldergroveForestArrival.CAMP_SITE_X)
		_check(String(target_unbuilt.get("primary_command", "")) == "build_camp", "Unbuilt camp site still resolves build_camp")
		_check(bool(eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X).get("ok", false)), "Constructed First Camp (4W 2S)")
		_check(eg.is_first_camp_built(), "First Camp is now constructed")
		_check(eg.ledger.get_amount(&"gold") == 5 and eg.ledger.get_amount(&"wood") == 0 and eg.ledger.get_amount(&"stone") == 1, "Balances accurate after camp build (5G/0W/1S)")

		# 3. Rest available during Sunset -> advances through Night to Day 3 Daylight
		var target_sunset: Dictionary = eg.resolve_nearest_interaction(EldergroveForestArrival.CAMP_SITE_X)
		_check(String(target_sunset.get("primary_command", "")) == "rest_camp" and String(target_sunset.get("prompt_text", "")) == "[E] Rest until Sunrise", "Built camp shows [E] Rest until Sunrise during Sunset")
		var res_sunset_rest: Dictionary = eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X)
		_check(bool(res_sunset_rest.get("ok", false)), "Sunset rest via real First Camp interaction succeeds")
		_check(eg.time_manager.current_day == 3 and eg.time_manager.current_phase == TimeManager.Phase.DAYLIGHT, "Sunset rest advanced through Night to Day 3 Daylight")
		_check(_night_signals == 1, "Sunset rest traversed Night phase through TimeManager")
		_check(_sunrise_signals == 1 and eg.get_sunrise_renewal_count() == 1, "Sunrise signal and N6.2 renewal fired exactly once on Sunset rest")
		_check(not eg.resource_mgr.is_collected("eldergrove_fallen_timber_01") and not eg.resource_mgr.is_collected("eldergrove_mossy_stone_01"), "Renewable Timber and Stone refreshed via N6.2 handler")
		_check(eg.resource_mgr.is_collected("eldergrove_foraged_supply_01"), "Non-renewable Supply Crate stayed collected after Sunset rest")
		_check(eg.ledger.get_amount(&"gold") == 5 and eg.ledger.get_amount(&"wood") == 0 and eg.ledger.get_amount(&"stone") == 1, "Sunset rest did not modify EconomyLedger balances directly")

		# 4. Rest unavailable during Daylight; repeated interaction does not duplicate sunrise or rewards
		var target_day: Dictionary = eg.resolve_nearest_interaction(EldergroveForestArrival.CAMP_SITE_X)
		_check(String(target_day.get("prompt_text", "")).contains("Sunset/Night"), "Built camp shows rest-unavailable prompt during Daylight")
		var res_day_rest: Dictionary = eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X)
		_check(not bool(res_day_rest.get("ok", true)) and bool(res_day_rest.get("already_built", false)), "Rest rejected during Daylight with clear feedback")
		_check(eg.time_manager.current_day == 3 and eg.time_manager.current_phase == TimeManager.Phase.DAYLIGHT, "Repeated interaction in Daylight does not advance clock")
		_check(_sunrise_signals == 1 and eg.get_sunrise_renewal_count() == 1, "Repeated interaction produces no duplicate sunrise events")

		# 5. Gather Day 3 Timber, advance to Night, test Night rest -> Day 4 Daylight
		_check(bool(eg.try_interact_at(-60.0).get("ok", false)), "Gathered renewed Day 3 Timber (+4W)")
		eg.time_manager.advance_time(eg.time_manager.daylight_duration + eg.time_manager.sunset_duration + 30.0)
		_check(eg.time_manager.current_day == 3 and eg.time_manager.current_phase == TimeManager.Phase.NIGHT, "Advanced to Day 3 Night")
		var target_night: Dictionary = eg.resolve_nearest_interaction(EldergroveForestArrival.CAMP_SITE_X)
		_check(String(target_night.get("prompt_text", "")) == "[E] Rest until Sunrise", "Built camp shows [E] Rest until Sunrise during Night")
		var res_night_rest: Dictionary = eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X)
		_check(bool(res_night_rest.get("ok", false)), "Night rest via real First Camp interaction succeeds")
		_check(eg.time_manager.current_day == 4 and eg.time_manager.current_phase == TimeManager.Phase.DAYLIGHT, "Night rest advanced to Day 4 Daylight")
		_check(_sunrise_signals == 2 and eg.get_sunrise_renewal_count() == 2, "Sunrise fired exactly once for Night rest")
		_check(not eg.resource_mgr.is_collected("eldergrove_fallen_timber_01"), "Day 3 Timber replenished again on Day 4 sunrise")
		_check(eg.resource_mgr.is_collected("eldergrove_foraged_supply_01"), "Non-renewable Supply Crate remains collected on Day 4")
		_check(eg.ledger.get_amount(&"gold") == 5 and eg.ledger.get_amount(&"wood") == 4 and eg.ledger.get_amount(&"stone") == 1, "Night rest did not alter resource balances")

		# 6. Collect Day 4 Stone, advance to Day 4 Night, save, exit, and verify Continue + post-Continue rest
		_check(bool(eg.try_interact_at(220.0).get("ok", false)), "Gathered Day 4 Mossy Stone (+3S)")
		eg.time_manager.advance_time(eg.time_manager.daylight_duration + eg.time_manager.sunset_duration + 20.0)
		_check(eg.time_manager.current_day == 4 and eg.time_manager.current_phase == TimeManager.Phase.NIGHT, "Advanced to Day 4 Night before saving")
		_check(eg.save_game_state(SAVE_ELDERGROVE), "Saved Day 4 Night state under SaveManager schema v2")
		_saved_gold = eg.ledger.get_amount(&"gold")
		_saved_wood = eg.ledger.get_amount(&"wood")
		_saved_stone = eg.ledger.get_amount(&"stone")

		# 7. Fail-safe check when TimeManager is missing
		var saved_tm: TimeManager = eg.time_manager
		eg.time_manager = null
		_check(not eg.can_rest_at_camp(), "Missing TimeManager disables rest safely")
		_check(not bool(eg.try_rest_at_camp(EldergroveForestArrival.CAMP_SITE_X).get("ok", true)), "Missing TimeManager rejects rest safely")
		eg.time_manager = saved_tm

		_check(eg.return_to_main_menu(), "Exited Eldergrove cleanly to Main.tscn")
		_stage = 3
		_wait_frames = 0
		return false

	# Stage 3: Verify Forgotten Shore Continue regression, then Continue back into Day 4 Night Eldergrove
	if _stage == 3:
		if current_scene == null or current_scene.name != "Main":
			return false
		var main_node: Node = current_scene
		_routed_scenes.clear()
		main_node.call("set_route_transition", func(path: String) -> void: _routed_scenes.append(path))
		Engine.set_meta("crownfall_menu_save_path", SAVE_SHORE)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_check(_routed_scenes.size() == 1 and _routed_scenes[0] == FORGOTTEN_SHORE_SCENE, "Regression: Forgotten Shore Continue remains unchanged")

		main_node.call("set_route_transition", Callable())
		Engine.set_meta("crownfall_menu_save_path", SAVE_ELDERGROVE)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_stage = 4
		_wait_frames = 0
		return false

	# Stage 4: Verify Continue restores Day 4 Night + First Camp, and resting after Continue advances to Day 5 Daylight
	if _stage == 4:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg2: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg2.time_manager.auto_advance = false
		_check(eg2.is_restored_from_continue(), "Eldergrove restored via Continue")
		_check(eg2.is_first_camp_built(), "First Camp state restored after Continue")
		_check(eg2.time_manager.current_day == 4 and eg2.time_manager.current_phase == TimeManager.Phase.NIGHT, "Continue restored Day 4 Night clock state")
		_check(eg2.resource_mgr.is_collected("eldergrove_mossy_stone_01"), "Collected Day 4 Stone preserved on Continue")
		_check(eg2.can_rest_at_camp(), "Rest is immediately eligible after Continuing a Night save")

		var res_post_continue_rest: Dictionary = eg2.try_interact_at(EldergroveForestArrival.CAMP_SITE_X)
		_check(bool(res_post_continue_rest.get("ok", false)), "Rest succeeds after Continue restores Night save")
		_check(eg2.time_manager.current_day == 5 and eg2.time_manager.current_phase == TimeManager.Phase.DAYLIGHT, "Post-Continue rest advanced to Day 5 Daylight")
		_check(not eg2.resource_mgr.is_collected("eldergrove_mossy_stone_01"), "Post-Continue rest refreshed renewable Stone via N6.2 handler")
		_check(eg2.resource_mgr.is_collected("eldergrove_foraged_supply_01"), "Non-renewable Supply Crate remains collected after post-Continue rest")
		_check(eg2.ledger.get_amount(&"gold") == _saved_gold and eg2.ledger.get_amount(&"wood") == _saved_wood and eg2.ledger.get_amount(&"stone") == _saved_stone, "Post-Continue rest did not alter resource balances")
		_check(SaveManager.SCHEMA_VERSION == 2, "SaveManager schema version remains v2")

		_cleanup()
		print("PASS: All %d N63 First Camp Rest checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
