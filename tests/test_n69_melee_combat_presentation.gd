extends SceneTree

## N6.9 Melee Combat Presentation & Feedback integration & regression suite.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const TEST_DIR: String = "user://n69_test"
const SAVE_DEFEATED: String = "user://n69_test/save_defeated.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _base_payload: Dictionary = {}
var _defeat_signals: int = 0
var _resolved_signals: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n69_melee_combat_presentation] " + msg)
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
	_rm(SAVE_DEFEATED)
	for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
		_rm(SAVE_DEFEATED + suffix)


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

	# Stage 1: Enter EldergroveForest.tscn via N5.5 handoff
	if _stage == 1:
		if current_scene == null or not (current_scene is ForgottenShoreSession):
			return false
		var sess: ForgottenShoreSession = current_scene as ForgottenShoreSession
		_base_payload = sess.build_save_payload()

		var eg_payload: Dictionary = _base_payload.duplicate(true)
		eg_payload["day_count"] = 5
		eg_payload["world_time"] = 5.0
		eg_payload["world_phase"] = "daylight"
		eg_payload["resources"] = {"gold": 2, "wood": 9, "stone": 2}

		var prog := ProgressionState.new()
		prog.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)
		var era := EraProgressionManager.new()
		Engine.set_meta("crownfall_menu_save_path", SAVE_DEFEATED)
		Engine.set_meta("crownfall_load_on_start", false)
		var tok: int = EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {
			"progression": prog,
			"era_mgr": era,
			"save_path": SAVE_DEFEATED,
			"base_save_payload": eg_payload,
		})
		_check(tok > 0, "Authorized N5.5 handoff into Eldergrove")
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Transitioned to EldergroveForest.tscn")
		_stage = 2
		_wait_frames = 0
		return false

	# Stage 2: Verify N6.9 attack cue, facing, expiration, miss vs hit, recoil recovery, HP bar, defeat, Ward Pulse & N6.7 repair
	if _stage == 2:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg.time_manager.auto_advance = false
		var surv: EldergroveNightSurvival = eg.night_survival
		var pres: EldergroveThreatPresenter = eg.threat_presenter
		_defeat_signals = 0
		_resolved_signals = 0
		surv.threat_defeated.connect(func(_d: int, _a: String) -> void: _defeat_signals += 1)
		surv.encounter_resolved.connect(func(_d: int, _s: bool, _b: bool) -> void: _resolved_signals += 1)

		# Verify N6.8 combat constants untouched
		_check(EldergroveNightSurvival.BRUTE_MAX_HP == 3 and EldergroveNightSurvival.PLAYER_ATTACK_DAMAGE == 1 and is_equal_approx(EldergroveNightSurvival.PLAYER_ATTACK_REACH, 64.0) and is_equal_approx(EldergroveNightSurvival.PLAYER_ATTACK_COOLDOWN_SEC, 0.45), "N6.8 combat balance values remain completely unchanged")

		# Build First Camp (4W 2S -> 5W left, 3/3 integrity)
		_check(bool(eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X).get("ok", false)), "Constructed First Camp (3/3 integrity)")

		# 1. Start Day 5 Breach-Capable Gloom Brute
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		_check(surv.is_encounter_active() and surv.threat_class == EldergroveNightSurvival.ThreatClass.BREACH_CAPABLE, "Day 5 Gloom Brute encounter active")
		_check(not pres.is_attack_cue_visible() and not pres.is_impact_cue_visible(), "Attack and impact cues start hidden")

		# 2. Missed/rejected attack (out of range) -> shows muted attack cue facing right, NO impact cue
		var miss_x: float = surv.threat_x - 120.0
		var res_miss: Dictionary = eg.try_attack_threat(miss_x, 1)
		_check(not bool(res_miss.get("ok", true)) and bool(res_miss.get("out_of_range", false)), "Out-of-range attack rejected cleanly")
		_check(pres.is_attack_cue_visible() and pres.get_attack_cue_facing() == 1 and pres.get_attack_cue_position().x > miss_x, "Attack cue appears on attack event facing right")
		_check(not pres.is_impact_cue_visible() and not pres.is_brute_hit_feedback_active(), "Missed/rejected attack does NOT show hit impact or Brute recoil feedback")

		# 3. Attack cue facing left (wrong facing)
		var wrong_x: float = surv.threat_x - 32.0
		var res_wrong: Dictionary = eg.try_attack_threat(wrong_x, -1)
		_check(not bool(res_wrong.get("ok", true)) and bool(res_wrong.get("wrong_facing", false)), "Wrong-facing attack rejected cleanly")
		_check(pres.is_attack_cue_visible() and pres.get_attack_cue_facing() == -1 and pres.get_attack_cue_position().x < wrong_x, "Attack cue respects left facing direction")
		_check(not pres.is_impact_cue_visible(), "Wrong-facing attack shows zero impact feedback")

		# 4. Attack cue expires correctly
		eg._update_night_survival(0.25)
		_check(not pres.is_attack_cue_visible(), "Attack cue expires cleanly after duration")

		# 5. Successful hit triggers attack cue, impact cue, Brute recoil & flash, and updates HP bar
		var hit_x: float = surv.threat_x - 32.0
		var res_hit1: Dictionary = eg.try_attack_threat(hit_x, 1)
		_check(bool(res_hit1.get("ok", false)) and surv.threat_hp == 2, "Successful hit deals 1 damage (3 -> 2)")
		_check(pres.is_attack_cue_visible() and pres.is_impact_cue_visible() and pres.is_brute_hit_feedback_active(), "Successful hit triggers attack cue, impact cue, and Brute hit recoil")
		_check(pres.is_hp_bar_visible() and is_equal_approx(pres.brute_hp_fill.size.x, roundf(EldergroveThreatPresenter.HP_BAR_WIDTH * (2.0 / 3.0))), "Brute HP bar remains synchronized at 2/3")

		# Cooldown rejection does NOT trigger hit impact
		var res_cd: Dictionary = eg.try_attack_threat(hit_x, 1)
		_check(not bool(res_cd.get("ok", true)) and bool(res_cd.get("on_cooldown", false)), "Cooldown still rejects immediate follow-up attack")

		# 6. Brute hit feedback expires and returns to normal approaching visual state without permanent override
		eg._update_night_survival(0.5)
		_check(not pres.is_attack_cue_visible() and not pres.is_impact_cue_visible() and not pres.is_brute_hit_feedback_active(), "Attack cue, impact cue, and Brute hit recoil all expire cleanly")
		_check(pres.get_visual_state() == "approaching" and is_equal_approx(pres.threat_actor.position.x, roundf(surv.threat_x)), "Brute returns to normal approaching state aligned to authoritative threat_x")

		# 7. Existing Ward Pulse behavior remains unchanged (1W, staggered, 0 damage)
		var res_pulse: Dictionary = eg.try_activate_camp_defense(EldergroveForestArrival.CAMP_SITE_X)
		_check(bool(res_pulse.get("ok", false)) and surv.threat_hp == 2 and pres.get_visual_state() == "staggered" and eg.ledger.get_amount(&"wood") == 4, "Ward Pulse behavior and staggered presentation remain unchanged")

		# 8. Complete Brute defeat -> impact cue shows on killing blow, Brute hides, resolves once
		var res_hit2: Dictionary = eg.try_attack_threat(surv.threat_x - 32.0, 1)
		_check(bool(res_hit2.get("ok", false)) and surv.threat_hp == 1 and is_equal_approx(pres.brute_hp_fill.size.x, roundf(EldergroveThreatPresenter.HP_BAR_WIDTH * (1.0 / 3.0))), "Second hit updates HP bar to 1/3")
		eg._update_night_survival(0.5)
		var res_hit3: Dictionary = eg.try_attack_threat(surv.threat_x - 32.0, 1)
		_check(bool(res_hit3.get("ok", false)) and bool(res_hit3.get("defeated", false)) and surv.threat_hp == 0, "Third hit defeats Brute cleanly")
		_check(_defeat_signals == 1 and _resolved_signals == 1 and not pres.is_threat_visible() and pres.is_impact_cue_visible(), "Defeat resolves once, hides Brute, and shows killing-blow impact cue")
		eg._update_night_survival(0.25)
		_check(not pres.is_impact_cue_visible() and not pres.is_attack_cue_visible(), "Post-defeat impact and attack cues expire cleanly")

		# Save defeated Day 5 state for Continue no-replay verification
		_check(eg.save_game_state(SAVE_DEFEATED), "Saved defeated Day 5 state under SaveManager schema v2")

		# 9. Existing camp breach damage and [F] repair remain unchanged
		_check(surv.start_encounter(10, EldergroveNightSurvival.ThreatClass.BREACH_CAPABLE), "Started Day 10 Breach encounter")
		for _i: int in range(30):
			surv.tick(0.5, EldergroveForestArrival.CAMP_SITE_X, true)
		_check(surv.camp_breached and eg.get_camp_integrity() == 2, "Existing N6.7 camp breach damage remains unchanged (3 -> 2)")
		var res_rep: Dictionary = eg.try_repair_first_camp(EldergroveForestArrival.CAMP_SITE_X, true)
		_check(bool(res_rep.get("ok", false)) and eg.get_camp_integrity() == 3 and eg.ledger.get_amount(&"wood") == 2, "Existing N6.7 repair remains unchanged (2 -> 3 for 2W)")

		_check(eg.return_to_main_menu(), "Exited Eldergrove cleanly to Main.tscn")
		_stage = 3
		_wait_frames = 0
		return false

	# Stage 3: Continue SAVE_DEFEATED
	if _stage == 3:
		if current_scene == null or current_scene.name != "Main":
			return false
		var main_node: Node = current_scene
		main_node.call("set_route_transition", Callable())
		Engine.set_meta("crownfall_menu_save_path", SAVE_DEFEATED)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_stage = 4
		_wait_frames = 0
		return false

	# Stage 4: Continue does not replay resolved encounter & schema remains v2
	if _stage == 4:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg2: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg2.time_manager.auto_advance = false
		_check(eg2.is_restored_from_continue() and eg2.night_survival.is_day_resolved(5), "Continue restored resolved Day 5 encounter")
		eg2._update_night_survival(0.5)
		_check(not eg2.night_survival.is_encounter_active() and not eg2.threat_presenter.is_threat_visible(), "Continue does NOT replay resolved encounter or show threat visuals")
		_check(SaveManager.SCHEMA_VERSION == 2, "SaveManager schema version remains v2")

		_cleanup()
		print("PASS: All %d N69 Melee Combat Presentation checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
