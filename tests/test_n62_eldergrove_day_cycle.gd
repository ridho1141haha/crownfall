extends SceneTree

## N6.2 Eldergrove Day Cycle & Resource Renewal integration & regression suite.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const TEST_DIR: String = "user://n62_test"
const SAVE_ELDERGROVE: String = "user://n62_test/save_eldergrove.json"
const SAVE_SHORE: String = "user://n62_test/save_shore.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _base_payload: Dictionary = {}
var _saved_day: int = 0
var _saved_phase: String = ""
var _saved_gold: int = 0
var _saved_wood: int = 0
var _saved_stone: int = 0
var _routed_scenes: Array[String] = []


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n62_eldergrove_day_cycle] " + msg)
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
		eg_start_payload["world_time"] = 10.0
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

	# Stage 2: Verify clock init, HUD, phase visuals, sunrise renewal, non-renewable lock, idempotency, camp + save
	if _stage == 2:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(eg.is_initialization_valid(), "Eldergrove initializes with valid TimeManager")
		_check(eg.time_manager != null and eg.time_manager.current_day == 2 and eg.time_manager.current_phase == TimeManager.Phase.DAYLIGHT, "Authoritative TimeManager hydrated to Day 2 Daylight")
		_check(eg.clock_label != null and eg.clock_label.text.contains("Day 2") and eg.clock_label.text.contains("Daylight"), "Clock HUD reflects authoritative day and phase")
		_check(eg.sky_background != null and eg.sky_background.color == EldergroveForestArrival.SKY_COLOR_DAYLIGHT, "Daylight visual tint applied")

		# Collect all 3 clearing nodes (2 renewable: Timber + Stone; 1 non-renewable: Supply Crate) and build First Camp
		_check(bool(eg.try_interact_at(-60.0).get("ok", false)), "Collected renewable Fallen Timber (+4W)")
		_check(bool(eg.try_interact_at(220.0).get("ok", false)), "Collected renewable Mossy Stone (+3S)")
		_check(bool(eg.try_interact_at(500.0).get("ok", false)), "Collected non-renewable Supply Crate (+3G)")
		_check(bool(eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X).get("ok", false)), "Constructed First Camp (4W 2S)")
		_check(eg.is_first_camp_built(), "First Camp built before day cycle transition")
		_check(eg.ledger.get_amount(&"gold") == 5 and eg.ledger.get_amount(&"wood") == 0 and eg.ledger.get_amount(&"stone") == 1, "Balances accurate before sunrise (5G/0W/1S)")

		# Drive authoritative TimeManager through Daylight -> Sunset -> Night -> Sunrise
		eg.time_manager.auto_advance = false
		eg.time_manager.advance_time(eg.time_manager.daylight_duration)
		_check(eg.time_manager.current_phase == TimeManager.Phase.SUNSET, "TimeManager transitioned Daylight -> Sunset")
		_check(eg.sky_background.color == EldergroveForestArrival.SKY_COLOR_SUNSET, "Sunset sky tint applied")
		_check(eg.clock_label.text.contains("Sunset"), "Clock HUD updated to Sunset")

		eg.time_manager.advance_time(eg.time_manager.sunset_duration)
		_check(eg.time_manager.current_phase == TimeManager.Phase.NIGHT, "TimeManager transitioned Sunset -> Night")
		_check(eg.sky_background.color == EldergroveForestArrival.SKY_COLOR_NIGHT, "Night sky tint applied")
		_check(eg.clock_label.text.contains("Night"), "Clock HUD updated to Night")

		_check(eg.resource_mgr.is_collected("eldergrove_fallen_timber_01") and eg.resource_mgr.is_collected("eldergrove_mossy_stone_01"), "Renewable nodes remain collected before sunrise")

		eg.time_manager.advance_time(eg.time_manager.night_duration)
		_check(eg.time_manager.current_day == 3 and eg.time_manager.current_phase == TimeManager.Phase.DAYLIGHT, "TimeManager transitioned Night -> Day 3 Daylight (Sunrise)")
		_check(eg.sky_background.color == EldergroveForestArrival.SKY_COLOR_DAYLIGHT, "Daylight sky tint restored at sunrise")
		_check(eg.clock_label.text.contains("Day 3") and eg.clock_label.text.contains("Daylight"), "Clock HUD updated to Day 3 Daylight")
		_check(eg.get_sunrise_renewal_count() == 1, "Sunrise renewal executed exactly once for completed Day 2")

		_check(not eg.resource_mgr.is_collected("eldergrove_fallen_timber_01"), "Renewable Fallen Timber replenished at sunrise")
		_check(not eg.resource_mgr.is_collected("eldergrove_mossy_stone_01"), "Renewable Mossy Stone replenished at sunrise")
		_check(eg.resource_mgr.is_collected("eldergrove_foraged_supply_01"), "Non-renewable Supply Crate stays collected after sunrise")
		_check(eg.ledger.get_amount(&"gold") == 5 and eg.ledger.get_amount(&"wood") == 0 and eg.ledger.get_amount(&"stone") == 1, "Sunrise renewal does not bypass EconomyLedger or grant free resources")

		# Collect renewed Timber once, then replay duplicate sunrise_reached(2) signal -> must NOT re-renew
		_check(bool(eg.try_interact_at(-60.0).get("ok", false)), "Player can re-gather replenished Timber (+4W) on Day 3")
		_check(eg.ledger.get_amount(&"wood") == 4, "EconomyLedger credited +4W from renewed Timber")
		eg.time_manager.sunrise_reached.emit(2)
		_check(eg.get_sunrise_renewal_count() == 1, "Duplicate sunrise_reached(2) ignored deterministically")
		_check(eg.resource_mgr.is_collected("eldergrove_fallen_timber_01"), "Duplicate sunrise event does not re-open already-collected Day 3 Timber")
		_check(eg.ledger.get_amount(&"wood") == 4, "Duplicate sunrise event does not duplicate resource rewards")

		# Advance partially into Sunset and save under SaveManager schema v2
		eg.time_manager.advance_time(eg.time_manager.daylight_duration + 15.0)
		_check(eg.time_manager.current_phase == TimeManager.Phase.SUNSET, "Advanced to Day 3 Sunset before saving")
		_check(eg.save_game_state(SAVE_ELDERGROVE), "Saved Eldergrove Day 3 Sunset state under schema v2")
		_saved_day = eg.time_manager.current_day
		_saved_phase = eg.time_manager.get_phase_id()
		_saved_gold = eg.ledger.get_amount(&"gold")
		_saved_wood = eg.ledger.get_amount(&"wood")
		_saved_stone = eg.ledger.get_amount(&"stone")

		# Verify fail-safe behavior when TimeManager dependency is missing
		var saved_tm: TimeManager = eg.time_manager
		eg.time_manager = null
		_check(not eg.validate_initialization(), "Missing TimeManager fails validate_initialization() safely")
		_check(eg.get_clock_status_text().is_empty(), "Missing TimeManager returns empty clock status safely")
		eg._on_toggle_fast_clock()
		eg._apply_phase_visuals()
		eg.time_manager = saved_tm

		_check(eg.return_to_main_menu(), "Exited Eldergrove cleanly to Main.tscn")
		_stage = 3
		_wait_frames = 0
		return false

	# Stage 3: Verify Forgotten Shore Continue regression, then Continue back into Eldergrove
	if _stage == 3:
		if current_scene == null or current_scene.name != "Main":
			return false
		var main_node: Node = current_scene
		_routed_scenes.clear()
		main_node.call("set_route_transition", func(path: String) -> void: _routed_scenes.append(path))
		Engine.set_meta("crownfall_menu_save_path", SAVE_SHORE)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_check(_routed_scenes.size() == 1 and _routed_scenes[0] == FORGOTTEN_SHORE_SCENE, "Regression: Forgotten Shore Continue unaffected")

		main_node.call("set_route_transition", Callable())
		Engine.set_meta("crownfall_menu_save_path", SAVE_ELDERGROVE)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_stage = 4
		_wait_frames = 0
		return false

	# Stage 4: Verify Continue restores clock, visuals, renewable/non-renewable node states, balances, and First Camp
	if _stage == 4:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg2: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(eg2.is_restored_from_continue(), "Eldergrove restored via Continue")
		_check(eg2.time_manager.current_day == _saved_day and eg2.time_manager.get_phase_id() == _saved_phase, "Continue restores saved day_count and world_phase (Day 3 Sunset)")
		_check(eg2.sky_background.color == EldergroveForestArrival.SKY_COLOR_SUNSET, "Continue restores Sunset visual state")
		_check(eg2.is_first_camp_built(), "First Camp state remains intact after save/load")
		_check(eg2.ledger.get_amount(&"gold") == _saved_gold and eg2.ledger.get_amount(&"wood") == _saved_wood and eg2.ledger.get_amount(&"stone") == _saved_stone, "Resource balances preserved after save/load")
		_check(eg2.resource_mgr.is_collected("eldergrove_fallen_timber_01"), "Day 3 collected Timber stays collected after Continue")
		_check(not eg2.resource_mgr.is_collected("eldergrove_mossy_stone_01"), "Day 3 uncollected replenished Stone stays available after Continue")
		_check(eg2.resource_mgr.is_collected("eldergrove_foraged_supply_01"), "Non-renewable Supply Crate remains collected after Continue")
		_check(SaveManager.SCHEMA_VERSION == 2, "SaveManager schema version remains v2")

		_cleanup()
		print("PASS: All %d N62 Eldergrove Day Cycle checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
