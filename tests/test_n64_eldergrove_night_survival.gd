extends SceneTree

## N6.4 Eldergrove Night Survival & First Camp Defense integration & regression suite.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const TEST_DIR: String = "user://n64_test"
const SAVE_ELDERGROVE: String = "user://n64_test/save_eldergrove.json"
const SAVE_SHORE: String = "user://n64_test/save_shore.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _base_payload: Dictionary = {}
var _started_events: int = 0
var _blocked_events: int = 0
var _breach_events: int = 0
var _resolved_events: int = 0
var _routed_scenes: Array[String] = []


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n64_eldergrove_night_survival] " + msg)
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
		eg_start_payload["resources"] = {"gold": 2, "wood": 4, "stone": 2}

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

	# Stage 2: Verify all N6.4 survival, protection, rest policy, resolution semantics, and save rules
	if _stage == 2:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg.time_manager.auto_advance = false
		var surv: EldergroveNightSurvival = eg.night_survival
		_started_events = 0
		_blocked_events = 0
		_breach_events = 0
		_resolved_events = 0
		surv.encounter_started.connect(func(_d: int, _c: int, _a: String) -> void: _started_events += 1)
		surv.threat_blocked_by_camp.connect(func(_d: int, _x: float) -> void: _blocked_events += 1)
		surv.camp_protection_breached.connect(func(_d: int, _a: String, _x: float) -> void: _breach_events += 1)
		surv.encounter_resolved.connect(func(_d: int, _s: bool, _b: bool) -> void: _resolved_events += 1)

		# 1. Protection unavailable before First Camp construction
		_check(not surv.is_camp_protection_active(eg.is_first_camp_built()), "First Camp protection unavailable before construction")
		_check(not surv.is_x_inside_camp_protection(EldergroveForestArrival.CAMP_SITE_X, eg.is_first_camp_built()), "Camp coordinates unprotected when camp is unbuilt")

		# 2. Sunrise without an encounter does NOT falsely mark encounter as resolved
		eg.time_manager.advance_time(eg.time_manager.daylight_duration + eg.time_manager.sunset_duration + eg.time_manager.night_duration)
		_check(eg.time_manager.current_day == 3 and eg.time_manager.current_phase == TimeManager.Phase.DAYLIGHT, "Day 2 passed to Day 3 Daylight without starting an encounter")
		_check(not surv.is_day_resolved(2) and surv.is_day_passed_without_encounter(2), "Sunrise without encounter marks Day 2 PASSED_NO_ENCOUNTER, not RESOLVED")
		_check(_resolved_events == 0 and not surv.to_save_node_states().has("eldergrove_night_resolved_day_2"), "Unstarted night emits no resolution and does not persist as resolved")

		# 3. Construct First Camp and verify threat class capabilities
		_check(bool(eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X).get("ok", false)), "Constructed First Camp (4W 2S)")
		_check(surv.is_camp_protection_active(eg.is_first_camp_built()), "First Camp protection active after construction")
		_check(not EldergroveNightSurvival.can_penetrate_camp_protection(EldergroveNightSurvival.ThreatClass.ORDINARY), "Ordinary threat explicitly cannot penetrate camp protection")
		_check(EldergroveNightSurvival.can_penetrate_camp_protection(EldergroveNightSurvival.ThreatClass.BREACH_CAPABLE), "Breach-capable threat explicitly can penetrate camp protection")

		# 4. Day 3 Sunset rest (Ordinary night): MUST process encounter (never silently bypass)
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + 1.0)
		_check(eg.time_manager.current_day == 3 and eg.time_manager.current_phase == TimeManager.Phase.SUNSET, "Advanced to Day 3 Sunset (Ordinary night)")
		var res_sunset_ord: Dictionary = eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X)
		_check(bool(res_sunset_ord.get("ok", false)) and eg.time_manager.current_day == 4 and eg.time_manager.current_phase == TimeManager.Phase.DAYLIGHT, "Day 3 Sunset rest on Ordinary night advances cleanly to Day 4 Daylight")
		_check(_started_events == 1 and _blocked_events == 1 and _resolved_events == 1, "Day 3 Sunset rest processed Ordinary encounter (started, blocked by camp, resolved once)")
		_check(surv.is_day_resolved(3) and surv.get_day_outcome(3) == EldergroveNightSurvival.DayOutcome.RESOLVED, "Day 3 marked RESOLVED after legitimate processing")

		# 5. Day 4 Night: before activation follows policy; at/past activation rejects rest; ordinary threat strictly blocked
		eg.player.global_position.x = EldergroveForestArrival.CAMP_SITE_X
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + 20.0)
		_check(eg.time_manager.current_day == 4 and eg.time_manager.current_phase == TimeManager.Phase.NIGHT, "Advanced to Day 4 Night (20s, pre-activation)")
		_check(eg.can_rest_at_camp(), "Ordinary Night rest before activation offset is eligible under documented policy")

		# Advance past activation offset without ticking _process -> rest MUST NOT bypass due encounter
		eg.time_manager.advance_time(EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		_check(not eg.can_rest_at_camp(), "can_rest_at_camp() is false once Night reaches encounter activation offset")
		var res_due_rest: Dictionary = eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X)
		_check(not bool(res_due_rest.get("ok", true)) and bool(res_due_rest.get("encounter_active", false)), "Night rest at/past activation offset activates encounter and rejects rest")
		_check(surv.is_encounter_active() and surv.threat_class == EldergroveNightSurvival.ThreatClass.ORDINARY, "Day 4 Ordinary encounter is active")

		# Tick Ordinary threat heavily toward player inside First Camp -> strictly blocked outside boundary
		for _i: int in range(20):
			eg._update_night_survival(0.5)
		var right_edge: float = EldergroveNightSurvival.CAMP_CENTER_X + EldergroveNightSurvival.CAMP_PROTECTION_RADIUS
		_check(surv.threat_x > right_edge and not surv.is_x_inside_camp_protection(surv.threat_x, true), "Ordinary threat blocked strictly outside First Camp protected boundary")
		_check(surv.threat_blocked and _blocked_events == 2, "Ordinary threat block recorded cleanly")
		_check(not surv.camp_breached and _breach_events == 0, "Ordinary threat cannot breach camp through any fallback path")

		# Rest during active encounter remains rejected
		var res_active_rest: Dictionary = eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X)
		_check(not bool(res_active_rest.get("ok", true)) and bool(res_active_rest.get("encounter_active", false)), "Rest rejected with clear feedback while encounter is active")
		_check(eg.time_manager.current_day == 4 and eg.time_manager.current_phase == TimeManager.Phase.NIGHT, "Rejected rest during active encounter does not skip Night")

		# Sunrise with active encounter resolves it exactly once and renews Timber
		_check(bool(eg.try_interact_at(-60.0).get("ok", false)), "Gathered Timber before Day 5 sunrise (+4W)")
		eg.player.global_position.x = EldergroveForestArrival.CAMP_SITE_X
		var prev_renewals: int = eg.get_sunrise_renewal_count()
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + 1.0)
		_check(eg.time_manager.current_day == 5 and eg.time_manager.current_phase == TimeManager.Phase.DAYLIGHT, "Sunrise transitions to Day 5 Daylight")
		_check(not surv.is_encounter_active() and surv.is_day_resolved(4) and _resolved_events == 2, "Sunrise with active Day 4 encounter resolved it exactly once")
		_check(eg.get_sunrise_renewal_count() == prev_renewals + 1 and not eg.resource_mgr.is_collected("eldergrove_fallen_timber_01"), "Sunrise renewal ran once and replenished Timber")

		# 6. Day 5 (day % 5 == 0, Breach Night): Sunset rest AND pre-activation Night rest MUST BE REJECTED
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + 1.0)
		_check(eg.time_manager.current_day == 5 and eg.time_manager.current_phase == TimeManager.Phase.SUNSET, "Advanced to Day 5 Sunset (Breach night)")
		_check(not eg.can_rest_at_camp(), "can_rest_at_camp() is false on Breach night Sunset")
		var res_sunset_breach: Dictionary = eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X)
		_check(not bool(res_sunset_breach.get("ok", true)) and bool(res_sunset_breach.get("breach_night", false)), "Sunset rest cannot bypass Breach night encounter")
		_check(eg.time_manager.current_day == 5 and eg.time_manager.current_phase == TimeManager.Phase.SUNSET, "Rejected Breach Sunset rest does not advance clock")

		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + 15.0)
		_check(eg.time_manager.current_day == 5 and eg.time_manager.current_phase == TimeManager.Phase.NIGHT, "Advanced to Day 5 Night (15s, pre-activation Breach night)")
		var res_early_breach: Dictionary = eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X)
		_check(not bool(res_early_breach.get("ok", true)) and bool(res_early_breach.get("breach_night", false)), "Pre-activation Night rest rejected on Breach night")

		# Activate Day 5 Breach-Capable threat -> penetrates First Camp protection with player-visible feedback
		eg.time_manager.advance_time(EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		_check(surv.is_encounter_active() and surv.threat_class == EldergroveNightSurvival.ThreatClass.BREACH_CAPABLE, "Day 5 Night spawns Breach-Capable threat deterministically")
		for _i: int in range(30):
			eg._update_night_survival(0.5)
		_check(surv.camp_breached and _breach_events == 1, "Breach-capable threat explicitly penetrates First Camp protection")
		_check(surv.is_x_inside_camp_protection(surv.threat_x, true), "Breach-capable threat entered protected zone")
		_check(eg.feedback_label != null and eg.feedback_label.text.contains("BREACHED"), "Player-visible HUD feedback shown when First Camp is breached")

		# Resolve Day 5 encounter explicitly, save, and verify malformed state fail-safety
		_check(surv.resolve_encounter(true), "Resolved Day 5 Breach encounter explicitly")
		_check(not surv.is_encounter_active() and surv.is_day_resolved(5) and _resolved_events == 3, "Day 5 marked resolved cleanly")
		_check(eg.save_game_state(SAVE_ELDERGROVE), "Saved Day 5 Night resolved state under SaveManager schema v2")

		var probe := EldergroveNightSurvival.new()
		probe.apply_save_node_states({"eldergrove_night_resolved_day_bad": true, "eldergrove_night_resolved_day_2": "not_bool"})
		_check(not probe.is_day_resolved(2), "Malformed saved survival state fails safely")

		_check(eg.return_to_main_menu(), "Exited Eldergrove cleanly to Main.tscn")
		_stage = 3
		_wait_frames = 0
		return false

	# Stage 3: Verify Forgotten Shore Continue regression, then Continue back into Day 5 Night (resolved)
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

	# Stage 4: Continue must NOT replay resolved Day 5 encounter; Day 2 (unstarted) stays unresolved; rest advances to Day 6
	if _stage == 4:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg2: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg2.time_manager.auto_advance = false
		_check(eg2.is_restored_from_continue(), "Eldergrove restored via Continue")
		_check(eg2.is_first_camp_built(), "First Camp protection state preserved after Continue")
		_check(eg2.night_survival.is_day_resolved(5) and eg2.night_survival.is_day_restored_from_save(5), "Resolved Day 5 encounter restored with RESTORED_RESOLVED outcome")
		_check(not eg2.night_survival.is_day_resolved(2), "Unstarted Day 2 was never falsely saved as resolved")
		eg2._update_night_survival(0.5)
		_check(not eg2.night_survival.is_encounter_active(), "Continue does NOT replay already-resolved Day 5 encounter")
		_check(eg2.can_rest_at_camp(), "Rest is available after Continue once Breach encounter is resolved")
		var res_rest: Dictionary = eg2.try_interact_at(EldergroveForestArrival.CAMP_SITE_X)
		_check(bool(res_rest.get("ok", false)) and eg2.time_manager.current_day == 6 and eg2.time_manager.current_phase == TimeManager.Phase.DAYLIGHT, "Rest after resolved encounter advances cleanly to Day 6 Daylight")
		_check(SaveManager.SCHEMA_VERSION == 2, "SaveManager schema version remains v2")

		_cleanup()
		print("PASS: All %d N64 Eldergrove Night Survival checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
