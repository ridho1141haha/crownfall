extends SceneTree

## N6.5 Eldergrove Threat Encounters & Pixel-Art Presentation integration & regression suite.

const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const RAIDER_SHEET_PATH: String = "res://assets/enemies/first_enemy/enemy_greedling_raider_sheet.png"
const CAMP_TENT_PATH: String = "res://assets/buildings/camp/building_vagrant_tent.png"
const TEST_DIR: String = "user://n65_test"
const SAVE_ELDERGROVE: String = "user://n65_test/save_eldergrove.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _base_payload: Dictionary = {}


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n65_eldergrove_threat_encounters] " + msg)
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

	# Stage 0: Verify existing pixel-art sprite sheet references & load ForgottenShore fixture
	if _stage == 0:
		_check(ResourceLoader.exists(RAIDER_SHEET_PATH), "Verified existing Greedling Raider sprite sheet exists")
		var raider_tex: Texture2D = load(RAIDER_SHEET_PATH) as Texture2D
		_check(raider_tex != null and raider_tex.get_width() == 128 and raider_tex.get_height() == 32, "Greedling Raider sheet loads as 128x32 Texture2D (4 frames of 32x32)")
		_check(ResourceLoader.exists(CAMP_TENT_PATH), "Verified existing First Camp tent sprite exists")

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
		eg_payload["resources"] = {"gold": 2, "wood": 4, "stone": 2}

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

	# Stage 2: Verify presentation adapter, Ordinary blocking, Breach crossing, missing resources, placeholder swap & N6.4 compatibility
	if _stage == 2:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg.time_manager.auto_advance = false
		var surv: EldergroveNightSurvival = eg.night_survival
		var pres: EldergroveThreatPresenter = eg.threat_presenter
		_check(pres != null, "EldergroveForest.tscn contains EldergroveThreatPresenter")

		# 1. Hidden outside active encounters; perimeter posts hidden before First Camp construction
		_check(not pres.is_threat_visible() and pres.get_visual_state() == "hidden", "Threat visual is hidden when no encounter is active")
		_check(not pres.is_perimeter_visible(), "Camp protection perimeter visuals hidden before First Camp construction")

		# Build First Camp -> perimeter visuals become visible at authoritative bounds
		_check(bool(eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X).get("ok", false)), "Constructed First Camp (4W 2S)")
		_check(pres.is_perimeter_visible(), "Camp protection perimeter visuals appear after First Camp construction")

		# 2. Day 4 Night (Ordinary threat): visual appears, mirrors simulation position/ground/filter, stops at camp boundary
		eg.player.global_position.x = EldergroveForestArrival.CAMP_SITE_X
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.25)
		_check(surv.is_encounter_active() and pres.is_threat_visible(), "Threat visual appears when Day 4 Ordinary encounter activates")
		_check(pres.has_valid_texture() and pres.threat_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Ordinary threat uses valid pixel-art texture with nearest-neighbor filtering")
		_check(is_equal_approx(pres.threat_actor.position.x, roundf(surv.threat_x)) and is_equal_approx(pres.threat_actor.position.y, 0.0), "Threat visual position matches authoritative threat_x and ground baseline y=0")
		_check(not pres.threat_sprite.flip_h, "Threat approaching from East faces West (left) in side view")
		_check(pres.get_visual_state() == "approaching", "Initial encounter visual state is approaching")

		# Advance Ordinary threat to First Camp boundary
		for _i: int in range(20):
			eg._update_night_survival(0.5)
		var right_edge: float = EldergroveNightSurvival.CAMP_CENTER_X + EldergroveNightSurvival.CAMP_PROTECTION_RADIUS
		_check(surv.threat_blocked and pres.get_visual_state() == "blocked", "Ordinary threat enters visual blocked state when simulation blocks it")
		_check(pres.threat_actor.position.x > right_edge and is_equal_approx(pres.threat_actor.position.x, roundf(surv.threat_x)), "Ordinary threat visual stops outside First Camp boundary matching simulation")
		_check(not eg.can_rest_at_camp(), "N6.4 compatibility: rest remains rejected during active encounter")

		# 3. Sunrise resolves Day 4 encounter -> threat visual hides immediately
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + 1.0)
		_check(eg.time_manager.current_day == 5 and eg.time_manager.current_phase == TimeManager.Phase.DAYLIGHT, "Sunrise transitions cleanly to Day 5 Daylight")
		_check(not surv.is_encounter_active() and not pres.is_threat_visible() and pres.get_visual_state() == "hidden", "Encounter resolution at sunrise hides threat presentation")

		# 4. Day 5 Night (Breach-Capable threat): crosses boundary ONLY when simulation confirms breach
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		_check(surv.is_encounter_active() and surv.threat_class == EldergroveNightSurvival.ThreatClass.BREACH_CAPABLE, "Day 5 Night spawns Breach-Capable threat")
		_check(pres.is_threat_visible() and pres.get_visual_state() == "approaching" and not surv.camp_breached, "Breach threat visual starts approaching before crossing boundary")
		_check(pres.threat_sprite.scale == Vector2(2.0, 2.0), "Brute placeholder uses exact 2x integer pixel-art scale")

		for _i: int in range(30):
			eg._update_night_survival(0.5)
		_check(surv.camp_breached and pres.get_visual_state() == "breached", "Breach visual state activates only after simulation confirms breach")
		_check(is_equal_approx(pres.threat_actor.position.x, roundf(surv.threat_x)) and surv.is_x_inside_camp_protection(pres.threat_actor.position.x, true), "Breach visual crosses inside First Camp boundary matching simulation")
		_check(eg.feedback_label != null and eg.feedback_label.text.contains("BREACHED"), "HUD displays clear breach feedback")

		# 5. Placeholder replacement does not change authoritative gameplay logic
		var before_x: float = surv.threat_x
		var before_breached: bool = surv.camp_breached
		pres.set_visual_profile("brute", {
			"texture_path": RAIDER_SHEET_PATH,
			"sprite_scale": Vector2(1.0, 1.0),
			"is_placeholder": false,
			"display_label": "Final Brute",
		})
		pres.sync_from_survival(surv, eg.player.global_position.x, eg.is_first_camp_built(), 0.1)
		_check(pres.threat_sprite.scale == Vector2(1.0, 1.0) and pres.threat_label.text.begins_with("Final Brute"), "Swapping visual profile updates presentation cleanly")
		_check(is_equal_approx(surv.threat_x, before_x) and surv.camp_breached == before_breached and EldergroveNightSurvival.can_penetrate_camp_protection(EldergroveNightSurvival.ThreatClass.BREACH_CAPABLE), "Placeholder replacement does not alter authoritative gameplay state or rules")

		# 6. Missing visual resource fails safely without crashing or breaking tracking
		pres.set_visual_profile("brute", {"texture_path": "res://assets/enemies/missing_nonexistent_sheet.png"})
		pres.sync_from_survival(surv, eg.player.global_position.x, eg.is_first_camp_built(), 0.1)
		_check(not pres.has_valid_texture() and pres.is_threat_visible() and is_equal_approx(pres.threat_actor.position.x, roundf(surv.threat_x)), "Missing visual resource fails safely while preserving position tracking")

		# 7. Explicit resolution hides threat and restores N6.4 rest eligibility + schema v2 untouched
		_check(surv.resolve_encounter(true), "Resolved Day 5 Breach encounter explicitly")
		_check(not pres.is_threat_visible() and pres.get_visual_state() == "hidden", "Explicit encounter resolution hides threat presentation immediately")
		_check(eg.can_rest_at_camp(), "Rest becomes available after encounter resolves")
		var res_rest: Dictionary = eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X)
		_check(bool(res_rest.get("ok", false)) and eg.time_manager.current_day == 6, "N6.4 rest lifecycle advances cleanly to Day 6")
		_check(SaveManager.SCHEMA_VERSION == 2, "SaveManager schema version remains v2")

		_cleanup()
		print("PASS: All %d N65 Eldergrove Threat Encounters checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
