extends SceneTree

## N6.7 First Camp Breach Damage & Repair integration & regression suite.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const TEST_DIR: String = "user://n67_test"
const SAVE_PARTIAL: String = "user://n67_test/save_partial.json"
const SAVE_ZERO: String = "user://n67_test/save_zero.json"
const SAVE_LEGACY: String = "user://n67_test/save_legacy.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _base_payload: Dictionary = {}
var _integrity_events: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n67_first_camp_integrity_repair] " + msg)
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
	for path: String in [SAVE_PARTIAL, SAVE_ZERO, SAVE_LEGACY]:
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

	# Stage 0: Load ForgottenShore to build valid schema v2 base payload
	if _stage == 0:
		Engine.set_meta("crownfall_load_on_start", false)
		_check(change_scene_to_file(FORGOTTEN_SHORE_SCENE) == OK, "Loaded ForgottenShore.tscn to build valid v2 fixture")
		_stage = 1
		_wait_frames = 0
		return false

	# Stage 1: Write legacy fixture (built camp without integrity keys) & enter Eldergrove
	if _stage == 1:
		if current_scene == null or not (current_scene is ForgottenShoreSession):
			return false
		var sess: ForgottenShoreSession = current_scene as ForgottenShoreSession
		_base_payload = sess.build_save_payload()

		var legacy_payload: Dictionary = _base_payload.duplicate(true)
		legacy_payload["day_count"] = 4
		legacy_payload["world_time"] = 10.0
		legacy_payload["world_phase"] = "daylight"
		legacy_payload["resources"] = {"gold": 2, "wood": 4, "stone": 2}
		(legacy_payload["progression_flags"] as Dictionary)["progression_facts"] = [
			ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY,
			ProgressionState.FACT_ELDERGROVE_REACHED,
		]
		(legacy_payload["progression_flags"] as Dictionary)["node_states"] = {
			EldergroveForestArrival.CAMP_BUILT_STATE_KEY: true,
		}
		var sm := SaveManager.new()
		_check(sm.save_state(legacy_payload, SAVE_LEGACY), "Saved legacy v2 fixture without camp integrity keys")

		var eg_payload: Dictionary = _base_payload.duplicate(true)
		eg_payload["day_count"] = 4
		eg_payload["world_time"] = 5.0
		eg_payload["world_phase"] = "daylight"
		eg_payload["resources"] = {"gold": 2, "wood": 9, "stone": 2}

		var prog := ProgressionState.new()
		prog.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)
		var era := EraProgressionManager.new()
		Engine.set_meta("crownfall_menu_save_path", SAVE_PARTIAL)
		Engine.set_meta("crownfall_load_on_start", false)
		var tok: int = EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {
			"progression": prog,
			"era_mgr": era,
			"save_path": SAVE_PARTIAL,
			"base_save_payload": eg_payload,
		})
		_check(tok > 0, "Authorized N5.5 handoff into Eldergrove")
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Transitioned to EldergroveForest.tscn")
		_stage = 2
		_wait_frames = 0
		return false

	# Stage 2: Damage, Protection, Repair, Zero-Integrity, Clamping, Debounce, Malformed & Save
	if _stage == 2:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg.time_manager.auto_advance = false
		var surv: EldergroveNightSurvival = eg.night_survival
		var pres: EldergroveThreatPresenter = eg.threat_presenter
		_integrity_events = 0
		surv.camp_integrity_changed.connect(func(_c: int, _m: int, _d: int) -> void: _integrity_events += 1)

		# 1. Repair rejected on unconstructed camp
		var res_unbuilt: Dictionary = eg.try_repair_first_camp(EldergroveForestArrival.CAMP_SITE_X, true)
		_check(not bool(res_unbuilt.get("ok", true)) and bool(res_unbuilt.get("unbuilt", false)) and eg.ledger.get_amount(&"wood") == 9, "Repair rejected on unconstructed camp without spending Wood")

		# 2. Construct First Camp -> starts at MAX_CAMP_INTEGRITY (3/3), repair at full rejected
		_check(bool(eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X).get("ok", false)), "Constructed First Camp (4W 2S -> 5W left)")
		_check(eg.get_camp_integrity() == EldergroveNightSurvival.MAX_CAMP_INTEGRITY, "Newly constructed First Camp starts at maximum integrity (3/3)")
		var res_full: Dictionary = eg.try_repair_first_camp(EldergroveForestArrival.CAMP_SITE_X, true)
		_check(not bool(res_full.get("ok", true)) and bool(res_full.get("already_full", false)) and eg.ledger.get_amount(&"wood") == 5, "Repair at full integrity rejected without spending Wood")

		# 3. Ordinary Threat cannot damage camp integrity
		eg.player.global_position.x = EldergroveForestArrival.CAMP_SITE_X
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		for _i: int in range(20):
			eg._update_night_survival(0.5)
		_check(surv.threat_blocked and eg.get_camp_integrity() == 3, "Ordinary Threat blocked and causes zero camp integrity damage")

		# Resolve Day 4 at Sunrise -> no duplicate damage
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + 1.0)
		_check(eg.time_manager.current_day == 5 and eg.get_camp_integrity() == 3, "Sunrise resolution causes zero camp integrity damage")

		# 4. Day 5 Breach-Capable threat damages camp EXACTLY ONCE (3 -> 2), repeated frames cause no extra damage
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		for _i: int in range(30):
			eg._update_night_survival(0.5)
		_check(surv.camp_breached and eg.get_camp_integrity() == 2, "Successful Breach-Capable penetration damages First Camp exactly once (3 -> 2)")
		for _i: int in range(20):
			eg._update_night_survival(0.5)
		_check(eg.get_camp_integrity() == 2, "Repeated simulation ticks while threat stays inside do not apply duplicate damage")
		_check(surv.is_camp_protection_active(true), "Damaged but nonzero camp (2/3) preserves protection")

		# Resolve Day 5 and save partial integrity (2/3)
		_check(surv.resolve_encounter(true), "Resolved Day 5 encounter explicitly")
		_check(eg.save_game_state(SAVE_PARTIAL), "Saved partial integrity (2/3) under SaveManager schema v2")

		# 5. Repair via PlayerController.repair_wall_requested ([F]) spends 2W and restores 2 -> 3; immediate duplicate debounced
		eg.player.repair_wall_requested.emit(EldergroveForestArrival.CAMP_SITE_X)
		_check(eg.get_camp_integrity() == 3 and eg.ledger.get_amount(&"wood") == 3, "Repair via [F] restored integrity (2 -> 3) and spent 2 Wood (3W left)")
		var res_dup: Dictionary = eg.try_repair_first_camp(EldergroveForestArrival.CAMP_SITE_X, false)
		_check(not bool(res_dup.get("ok", true)) and eg.ledger.get_amount(&"wood") == 3 and eg.get_camp_integrity() == 3, "Repeated repair input cannot double-spend or exceed maximum integrity")

		# 6. Drive camp integrity down to 0 across 3 breach events and verify clamping + loss of protection
		for b_day: int in [10, 15, 20, 25]:
			surv.start_encounter(b_day, EldergroveNightSurvival.ThreatClass.BREACH_CAPABLE)
			for _i: int in range(30):
				surv.tick(0.5, EldergroveForestArrival.CAMP_SITE_X, true)
			surv.resolve_encounter(true)
		_check(eg.get_camp_integrity() == 0, "Camp integrity clamps cleanly at 0 after repeated breaches")
		_check(surv.is_camp_compromised(true) and not surv.is_camp_protection_active(true), "Zero-integrity camp is structurally compromised and provides no normal protection")
		eg._sync_threat_presentation(0.0)
		_check(not pres.is_perimeter_visible(), "Zero-integrity camp hides protective perimeter ward posts")

		# Verify Ordinary Threat is NOT blocked when camp integrity is 0
		surv.start_encounter(26, EldergroveNightSurvival.ThreatClass.ORDINARY)
		for _i: int in range(25):
			surv.tick(0.5, EldergroveForestArrival.CAMP_SITE_X, true)
		_check(not surv.threat_blocked and absf(surv.threat_x - EldergroveForestArrival.CAMP_SITE_X) < EldergroveNightSurvival.CAMP_PROTECTION_RADIUS, "Ordinary Threat passes through zero-integrity compromised camp")
		surv.resolve_encounter(true)

		# Save zero-integrity state before repairing
		_check(eg.save_game_state(SAVE_ZERO), "Saved zero-integrity (0/3) state under SaveManager schema v2")

		# 7. Repair from 0 -> 1 restores protection (3W -> 1W), then insufficient Wood (1W < 2W) rejects safely
		var res_rep0: Dictionary = eg.try_repair_first_camp(EldergroveForestArrival.CAMP_SITE_X, true)
		_check(bool(res_rep0.get("ok", false)) and eg.get_camp_integrity() == 1 and eg.ledger.get_amount(&"wood") == 1, "Repair restored compromised camp (0 -> 1) for 2 Wood (1W left)")
		_check(surv.is_camp_protection_active(true) and pres.is_perimeter_visible(), "Restored 1/3 integrity camp re-enables protection and perimeter wards")
		var res_low_w: Dictionary = eg.try_repair_first_camp(EldergroveForestArrival.CAMP_SITE_X, true)
		_check(not bool(res_low_w.get("ok", true)) and bool(res_low_w.get("insufficient_resources", false)) and eg.get_camp_integrity() == 1 and eg.ledger.get_amount(&"wood") == 1, "Repair with insufficient Wood (1W < 2W) rejected without changing integrity or balance")

		# 8. Malformed integrity data fails safely
		var probe := EldergroveNightSurvival.new()
		probe.apply_save_node_states({"eldergrove_camp_integrity_tracked": true, "eldergrove_camp_integrity_1": false, "eldergrove_camp_integrity_2": true, "eldergrove_camp_integrity_3": false}, true)
		_check(probe.get_camp_integrity() == EldergroveNightSurvival.MAX_CAMP_INTEGRITY, "Non-contiguous malformed integrity bits fail safely to MAX_CAMP_INTEGRITY")
		probe.apply_save_node_states({"eldergrove_camp_integrity_tracked": true, "eldergrove_camp_integrity_99": true}, true)
		_check(probe.get_camp_integrity() == EldergroveNightSurvival.MAX_CAMP_INTEGRITY, "Out-of-range malformed integrity key fails safely")

		_check(eg.return_to_main_menu(), "Exited Eldergrove cleanly to Main.tscn")
		_stage = 3
		_wait_frames = 0
		return false

	# Stage 3: Continue SAVE_PARTIAL (2/3 integrity)
	if _stage == 3:
		if current_scene == null or current_scene.name != "Main":
			return false
		var main_node: Node = current_scene
		main_node.call("set_route_transition", Callable())
		Engine.set_meta("crownfall_menu_save_path", SAVE_PARTIAL)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_stage = 4
		_wait_frames = 0
		return false

	# Stage 4: Verify partial integrity (2/3) restored without replaying breach damage, then load SAVE_ZERO
	if _stage == 4:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg2: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg2.time_manager.auto_advance = false
		_check(eg2.is_restored_from_continue() and eg2.get_camp_integrity() == 2, "Continue restored exact partial integrity (2/3)")
		eg2._update_night_survival(0.5)
		_check(eg2.get_camp_integrity() == 2 and not eg2.night_survival.is_encounter_active(), "Continue does not replay breach or apply damage again")
		_check(eg2.return_to_main_menu(), "Returned to Main.tscn for zero-integrity Continue test")
		_stage = 5
		_wait_frames = 0
		return false

	# Stage 5: Continue SAVE_ZERO (0/3 compromised camp)
	if _stage == 5:
		if current_scene == null or current_scene.name != "Main":
			return false
		var main_node: Node = current_scene
		main_node.call("set_route_transition", Callable())
		Engine.set_meta("crownfall_menu_save_path", SAVE_ZERO)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_stage = 6
		_wait_frames = 0
		return false

	# Stage 6: Verify zero-integrity stays compromised after Continue, then load SAVE_LEGACY
	if _stage == 6:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg3: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg3.time_manager.auto_advance = false
		_check(eg3.get_camp_integrity() == 0 and eg3.night_survival.is_camp_compromised(true), "Zero-integrity camp remains compromised after Continue until repaired")
		_check(not eg3.night_survival.is_camp_protection_active(true), "Zero-integrity camp provides no protection after Continue")
		_check(eg3.return_to_main_menu(), "Returned to Main.tscn for legacy Continue test")
		_stage = 7
		_wait_frames = 0
		return false

	# Stage 7: Continue SAVE_LEGACY (missing integrity keys)
	if _stage == 7:
		if current_scene == null or current_scene.name != "Main":
			return false
		var main_node: Node = current_scene
		main_node.call("set_route_transition", Callable())
		Engine.set_meta("crownfall_menu_save_path", SAVE_LEGACY)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_stage = 8
		_wait_frames = 0
		return false

	# Stage 8: Verify legacy save initializes to full integrity (3/3) and schema v2 unchanged
	if _stage == 8:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg4: EldergroveForestArrival = current_scene as EldergroveForestArrival
		_check(eg4.is_first_camp_built() and eg4.get_camp_integrity() == EldergroveNightSurvival.MAX_CAMP_INTEGRITY, "Missing legacy integrity data safely initializes constructed camp to 3/3")
		_check(SaveManager.SCHEMA_VERSION == 2, "SaveManager schema version remains v2")

		_cleanup()
		print("PASS: All %d N67 First Camp Integrity & Repair checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
