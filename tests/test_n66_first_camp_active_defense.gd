extends SceneTree

## N6.6 First Camp Active Defense & Player Response integration & regression suite.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const TEST_DIR: String = "user://n66_test"
const SAVE_ELDERGROVE: String = "user://n66_test/save_eldergrove.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _base_payload: Dictionary = {}
var _defense_signals: int = 0
var _saved_wood: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n66_first_camp_active_defense] " + msg)
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
	_rm(SAVE_ELDERGROVE)
	for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
		_rm(SAVE_ELDERGROVE + suffix)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	_cleanup()


func _process(_delta: float) -> bool:
	_wait_frames += 1
	if _wait_frames > MAX_WAIT_FRAMES:
		_check(false, "Timed out at stage %d" % _stage)
		return true

	# Stage 0: Load ForgottenShore to build valid schema v2 fixture
	if _stage == 0:
		Engine.set_meta("crownfall_load_on_start", false)
		_check(change_scene_to_file(FORGOTTEN_SHORE_SCENE) == OK, "Loaded ForgottenShore.tscn to build valid v2 fixture")
		_stage = 1
		_wait_frames = 0
		return false

	# Stage 1: Enter EldergroveForest.tscn via N5.5 handoff
	if _stage == 1:
		if current_scene == null or not (current_scene is ForgottenShoreSession):
			return false
		var sess: ForgottenShoreSession = current_scene as ForgottenShoreSession
		_base_payload = sess.build_save_payload()

		var eg_payload: Dictionary = _base_payload.duplicate(true)
		eg_payload["day_count"] = 4
		eg_payload["world_time"] = 5.0
		eg_payload["world_phase"] = "daylight"
		eg_payload["resources"] = {"gold": 2, "wood": 6, "stone": 2}

		var prog := ProgressionState.new()
		prog.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)
		var era := EraProgressionManager.new()
		Engine.set_meta("crownfall_menu_save_path", SAVE_ELDERGROVE)
		Engine.set_meta("crownfall_load_on_start", false)
		var tok: int = EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {
			"progression": prog,
			"era_mgr": era,
			"save_path": SAVE_ELDERGROVE,
			"base_save_payload": eg_payload,
		})
		_check(tok > 0, "Authorized N5.5 handoff into Eldergrove")
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Transitioned to EldergroveForest.tscn")
		_stage = 2
		_wait_frames = 0
		return false

	# Stage 2: Exercise active defense eligibility, Ordinary pushback, cooldown, insufficient Wood, Breach repel, and save
	if _stage == 2:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg.time_manager.auto_advance = false
		var surv: EldergroveNightSurvival = eg.night_survival
		var pres: EldergroveThreatPresenter = eg.threat_presenter
		_defense_signals = 0
		eg.camp_defense_activated.connect(func(_d: int, _c: int, _r: bool) -> void: _defense_signals += 1)

		# 1. Rejected before First Camp construction
		var res_unbuilt: Dictionary = eg.try_activate_camp_defense(EldergroveForestArrival.CAMP_SITE_X)
		_check(not bool(res_unbuilt.get("ok", true)) and eg.ledger.get_amount(&"wood") == 6, "Ward Pulse rejected before First Camp construction with zero Wood spent")

		# Build First Camp (spends 4W 2S -> leaves 2W)
		_check(bool(eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X).get("ok", false)), "Constructed First Camp (4W 2S -> 2W remaining)")
		_check(eg.ledger.get_amount(&"wood") == 2, "Wood balance is 2 after First Camp construction")

		# 2. Rejected outside active night encounter (Daylight)
		var res_day: Dictionary = eg.try_activate_camp_defense(EldergroveForestArrival.CAMP_SITE_X)
		_check(not bool(res_day.get("ok", true)) and bool(res_day.get("not_active", false)), "Ward Pulse rejected outside active encounter")

		# 3. Day 4 Night (Ordinary threat): activate encounter and test out-of-range rejection
		eg.player.global_position.x = EldergroveForestArrival.CAMP_SITE_X
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		_check(surv.is_encounter_active() and surv.threat_class == EldergroveNightSurvival.ThreatClass.ORDINARY, "Day 4 Ordinary night encounter active")
		var res_far: Dictionary = eg.try_activate_camp_defense(-300.0)
		_check(not bool(res_far.get("ok", true)) and bool(res_far.get("out_of_range", false)), "Ward Pulse rejected when player is outside First Camp defense range")

		# Advance Ordinary threat until blocked outside First Camp
		for _i: int in range(20):
			eg._update_night_survival(0.5)
		var pre_pulse_x: float = surv.threat_x
		_check(surv.threat_blocked and pre_pulse_x > EldergroveNightSurvival.CAMP_CENTER_X + EldergroveNightSurvival.CAMP_PROTECTION_RADIUS, "Ordinary threat blocked outside First Camp before Ward Pulse")

		# 4. Trigger Ward Pulse via PlayerController.kindle_flare_requested ([Space])
		eg.player.kindle_flare_requested.emit()
		_check(_defense_signals == 1 and eg.ledger.get_amount(&"wood") == 1, "Ward Pulse activated via PlayerController signal and spent 1 Wood (1W left)")
		_check(surv.threat_x >= pre_pulse_x + EldergroveNightSurvival.ORDINARY_PUSHBACK_PX - 0.1, "Ward Pulse pushed Ordinary threat back authoritatively (+140px)")
		_check(surv.is_threat_staggered() and surv.is_defense_on_cooldown(), "Ward Pulse staggered Ordinary threat and started cooldown")
		_check(surv.is_encounter_active() and eg.time_manager.current_day == 4 and eg.time_manager.current_phase == TimeManager.Phase.NIGHT, "Ward Pulse does NOT auto-resolve encounter or skip Night")
		_check(pres.get_visual_state() == "staggered" and pres.is_pulse_visual_active(), "Presentation mirrors staggered threat and active Ward Pulse visual")
		_check(eg.feedback_label != null and eg.feedback_label.text.contains("Ward Pulse"), "HUD feedback confirms Ward Pulse activation")

		# 5. Repeated input during cooldown is rejected safely
		var res_cd: Dictionary = eg.try_activate_camp_defense(EldergroveForestArrival.CAMP_SITE_X)
		_check(not bool(res_cd.get("ok", true)) and bool(res_cd.get("on_cooldown", false)) and eg.ledger.get_amount(&"wood") == 1, "Repeated Ward Pulse during cooldown rejected without spending Wood")

		# Stagger holds threat stationary, then threat resumes approaching
		var staggered_x: float = surv.threat_x
		eg._update_night_survival(1.0)
		_check(is_equal_approx(surv.threat_x, staggered_x), "Staggered threat does not advance during stagger window")

		# Advance to Day 5 Daylight -> Day 4 resolves cleanly
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + 1.0)
		_check(eg.time_manager.current_day == 5 and not surv.is_encounter_active() and surv.is_day_resolved(4), "Day 4 resolves cleanly at Day 5 Sunrise")

		# 6. Day 5 Night (Breach-Capable threat): Breach enters camp, Ward Pulse drives it back outside, then 0W rejects next pulse
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		_check(surv.is_encounter_active() and surv.threat_class == EldergroveNightSurvival.ThreatClass.BREACH_CAPABLE, "Day 5 Breach-Capable encounter active")
		for _i: int in range(30):
			eg._update_night_survival(0.5)
		_check(surv.camp_breached and surv.is_x_inside_camp_protection(surv.threat_x, true), "Breach-capable threat penetrated First Camp before Ward Pulse")

		var res_breach_pulse: Dictionary = eg.try_activate_camp_defense(EldergroveForestArrival.CAMP_SITE_X)
		_check(bool(res_breach_pulse.get("ok", false)) and bool(res_breach_pulse.get("repelled_breach", false)), "Ward Pulse repelled Breach threat back outside First Camp")
		_check(not surv.camp_breached and not surv.is_x_inside_camp_protection(surv.threat_x, true), "Breached state cleared when Brute is forced outside protected zone")
		_check(surv.is_encounter_active() and eg.ledger.get_amount(&"wood") == 0, "Encounter stays active and Wood balance is now 0")

		# Tick past cooldown (9s) -> now try Ward Pulse with 0 Wood -> rejected for insufficient resources
		for _i: int in range(18):
			eg._update_night_survival(0.5)
		_check(not surv.is_defense_on_cooldown(), "Cooldown expired after 9s of simulation ticks")
		var res_no_wood: Dictionary = eg.try_activate_camp_defense(EldergroveForestArrival.CAMP_SITE_X)
		_check(not bool(res_no_wood.get("ok", true)) and bool(res_no_wood.get("insufficient_resources", false)), "Ward Pulse rejected cleanly when Wood is insufficient")

		# Resolve Day 5, save under schema v2, exit to Main, and Continue
		_check(surv.resolve_encounter(true), "Resolved Day 5 encounter explicitly")
		_saved_wood = eg.ledger.get_amount(&"wood")
		_check(eg.save_game_state(SAVE_ELDERGROVE), "Saved post-defense state under SaveManager schema v2")
		_check(eg.return_to_main_menu(), "Exited Eldergrove cleanly to Main.tscn")
		_stage = 3
		_wait_frames = 0
		return false

	# Stage 3: Continue back into Eldergrove
	if _stage == 3:
		if current_scene == null or current_scene.name != "Main":
			return false
		var main_node: Node = current_scene
		main_node.call("set_route_transition", Callable())
		Engine.set_meta("crownfall_menu_save_path", SAVE_ELDERGROVE)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_stage = 4
		_wait_frames = 0
		return false

	# Stage 4: Verify Continue preserves Wood spent, First Camp, resolved Day 5, and schema v2
	if _stage == 4:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg2: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg2.time_manager.auto_advance = false
		_check(eg2.is_restored_from_continue() and eg2.is_first_camp_built(), "Continue restored Eldergrove and First Camp state")
		_check(eg2.ledger.get_amount(&"wood") == _saved_wood, "Wood spent on Ward Pulse persisted accurately through SaveManager v2")
		_check(eg2.night_survival.is_day_resolved(5) and not eg2.night_survival.is_defense_on_cooldown(), "Resolved Day 5 preserved and transient defense cooldown reset cleanly")
		_check(SaveManager.SCHEMA_VERSION == 2, "SaveManager schema version remains v2")

		_cleanup()
		print("PASS: All %d N66 First Camp Active Defense checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
