extends SceneTree

## N6.12 Deterministic Multi-Threat Night Encounters integration & regression suite.

const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const TEST_DIR: String = "user://n612_test"
const SAVE_RESOLVED: String = "user://n612_test/save_resolved.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _base_payload: Dictionary = {}
var _defeat_signals: int = 0
var _resolved_signals: int = 0
var _hit_signals: int = 0
var _retreat_signals: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n612_multi_threat_encounters] " + msg)
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
	_rm(SAVE_RESOLVED)
	for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
		_rm(SAVE_RESOLVED + suffix)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	_cleanup()


func _process(_delta: float) -> bool:
	_wait_frames += 1
	if _wait_frames > MAX_WAIT_FRAMES:
		_check(false, "Timed out at stage %d" % _stage)
		return true

	# Stage 0: Verify deterministic encounter schedule & load ForgottenShore base payload
	if _stage == 0:
		_check(EldergroveNightSurvival.get_scheduled_threat_count(1) == 1 and EldergroveNightSurvival.get_scheduled_threat_class(1) == EldergroveNightSurvival.ThreatClass.ORDINARY, "Day 1 schedule is single Ordinary Threat")
		_check(EldergroveNightSurvival.get_scheduled_threat_count(2) == 1 and EldergroveNightSurvival.get_scheduled_threat_class(2) == EldergroveNightSurvival.ThreatClass.ORDINARY, "Day 2 schedule is single Ordinary Threat")
		_check(EldergroveNightSurvival.get_scheduled_threat_count(3) == 2 and EldergroveNightSurvival.get_scheduled_threat_class(3) == EldergroveNightSurvival.ThreatClass.ORDINARY, "Day 3 schedule is two simultaneous Ordinary Threats")
		_check(EldergroveNightSurvival.get_scheduled_threat_count(4) == 2 and EldergroveNightSurvival.get_scheduled_threat_class(4) == EldergroveNightSurvival.ThreatClass.ORDINARY, "Day 4 schedule is two simultaneous Ordinary Threats")
		_check(EldergroveNightSurvival.get_scheduled_threat_count(5) == 1 and EldergroveNightSurvival.get_scheduled_threat_class(5) == EldergroveNightSurvival.ThreatClass.BREACH_CAPABLE, "Day 5 schedule is single Gloom Brute")
		_check(EldergroveNightSurvival.get_scheduled_threat_count(6) == 1 and EldergroveNightSurvival.get_scheduled_threat_class(6) == EldergroveNightSurvival.ThreatClass.ORDINARY, "Day 6 schedule returns to single Ordinary Threat")

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
		eg_payload["day_count"] = 3
		eg_payload["world_time"] = 5.0
		eg_payload["world_phase"] = "daylight"
		eg_payload["resources"] = {"gold": 2, "wood": 8, "stone": 2}

		var prog := ProgressionState.new()
		prog.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)
		var era := EraProgressionManager.new()
		Engine.set_meta("crownfall_menu_save_path", SAVE_RESOLVED)
		Engine.set_meta("crownfall_load_on_start", false)
		var tok: int = EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {
			"progression": prog,
			"era_mgr": era,
			"save_path": SAVE_RESOLVED,
			"base_save_payload": eg_payload,
		})
		_check(tok > 0, "Authorized N5.5 handoff into Eldergrove")
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Transitioned to EldergroveForest.tscn")
		_stage = 2
		_wait_frames = 0
		return false

	# Stage 2: Verify multi-threat state, targeting, Ward Pulse, Camp protection, Vulnerability, Sunrise & Save
	if _stage == 2:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg.time_manager.auto_advance = false
		var surv: EldergroveNightSurvival = eg.night_survival
		var pres: EldergroveThreatPresenter = eg.threat_presenter
		_defeat_signals = 0
		_resolved_signals = 0
		_hit_signals = 0
		_retreat_signals = 0
		surv.threat_defeated.connect(func(_d: int, _a: String) -> void: _defeat_signals += 1)
		surv.encounter_resolved.connect(func(_d: int, _s: bool, _b: bool) -> void: _resolved_signals += 1)
		surv.player_hit_by_threat.connect(func(_d: int, _v: int, _m: int, _k: int) -> void: _hit_signals += 1)
		eg.player_retreated.connect(func(_d: int, _g: int) -> void: _retreat_signals += 1)

		# Build First Camp (4W 2S -> leaves 4W, 2G)
		_check(bool(eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X).get("ok", false)), "Constructed First Camp (4W 2S -> 4W, 2G left)")

		# 1. Day 3 Night spawns 2 simultaneous Ordinary Threats with independent IDs, positions, HP, and presenter actors
		eg.player.global_position.x = EldergroveForestArrival.CAMP_SITE_X
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		_check(surv.is_encounter_active() and surv.get_total_threat_count() == 2 and surv.get_active_threat_count() == 2, "Day 3 Night creates two simultaneous Ordinary Threats")
		var list3: Array[Dictionary] = surv.get_threats()
		_check(String(list3[0]["id"]) != String(list3[1]["id"]) and not is_equal_approx(float(list3[0]["x"]), float(list3[1]["x"])), "Each threat has an independent ID and position")
		_check(int(list3[0]["hp"]) == 2 and int(list3[1]["hp"]) == 2, "Each Ordinary Threat starts with independent 2/2 HP")
		_check(pres.get_visible_threat_count() == 2, "Presenter renders two independent threat actors")

		# 2. Nearest-eligible melee targeting + single-target damage + shared cooldown
		# Place threats close (e.g. player at x=695 facing right: threat 0 is at ~670 behind, threat 1 is at ~730 ahead)
		var t0_x: float = float(surv.threats[0]["x"])
		var t1_x: float = float(surv.threats[1]["x"])
		var mid_x: float = (t0_x + t1_x) * 0.5
		var res_hit1: Dictionary = eg.try_attack_threat(mid_x - 10.0, 1) # facing right -> should hit threat 1 only
		_check(bool(res_hit1.get("ok", false)) and String(res_hit1["target_id"]) == String(list3[1]["id"]), "Melee chooses nearest eligible target in facing direction")
		_check(int(surv.threats[1]["hp"]) == 1 and int(surv.threats[0]["hp"]) == 2, "One attack damages at most one target (threat 1: 2->1, threat 0: 2)")
		var res_cd: Dictionary = eg.try_attack_threat(mid_x + 10.0, -1)
		_check(not bool(res_cd.get("ok", true)) and bool(res_cd.get("on_cooldown", false)), "Attack cooldown is shared across player attacks")

		# Defeat threat 1 -> encounter stays ACTIVE because threat 0 remains!
		eg._update_night_survival(0.5)
		var res_kill1: Dictionary = eg.try_attack_threat(float(surv.threats[1]["x"]) - 10.0, 1)
		_check(bool(res_kill1.get("defeated", false)) and int(res_kill1["remaining_active_threats"]) == 1, "Defeating first threat leaves 1 active threat remaining")
		_check(surv.is_encounter_active() and _defeat_signals == 1 and _resolved_signals == 0, "Defeating one threat does NOT resolve encounter while another survives")
		_check(pres.get_visible_threat_count() == 1, "Presenter hides defeated threat while keeping surviving threat visible")

		# Ward Pulse affects surviving threat 0 ONLY (does NOT affect defeated threat 1, spends 1 Wood once: 4W -> 3W)
		var dead1_x: float = float(surv.threats[1]["x"])
		var res_pulse1: Dictionary = eg.try_attack_threat(dead1_x - 10.0, 1)
		_check(not bool(res_pulse1.get("ok", true)), "Defeated threat cannot be attacked again")
		var pulse_res: Dictionary = eg.try_activate_camp_defense(EldergroveForestArrival.CAMP_SITE_X)
		_check(bool(pulse_res.get("ok", false)) and int(pulse_res["affected_count"]) == 1 and eg.ledger.get_amount(&"wood") == 3, "Ward Pulse affects only surviving threat, skips defeated threat, and spends 1 Wood once")
		_check(is_equal_approx(float(surv.threats[1]["x"]), dead1_x) and float(surv.threats[0]["stagger_remaining"]) > 0.0, "Defeated threat untouched by Ward Pulse while surviving threat is staggered")

		# Defeat final threat 0 -> resolves Day 3 encounter exactly once
		eg._update_night_survival(3.1) # expire stagger
		eg.try_attack_threat(float(surv.threats[0]["x"]) - 20.0, 1)
		eg._update_night_survival(0.5)
		var res_kill0: Dictionary = eg.try_attack_threat(float(surv.threats[0]["x"]) - 20.0, 1)
		_check(bool(res_kill0.get("defeated", false)) and int(res_kill0["remaining_active_threats"]) == 0, "Defeating final threat leaves 0 active threats")
		_check(not surv.is_encounter_active() and _defeat_signals == 2 and _resolved_signals == 1 and surv.is_day_resolved(3), "Defeating final threat resolves Day 3 encounter exactly once")
		_check(pres.get_visible_threat_count() == 0, "Presenter hides all threats after encounter resolution")

		# 3. Advance to Day 4 Daylight, then Day 4 Night: 2 simultaneous Ordinary Threats
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + 1.0)
		eg.time_manager.advance_time(eg.time_manager.daylight_duration + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		_check(surv.is_encounter_active() and surv.get_total_threat_count() == 2, "Day 4 Night creates two simultaneous Ordinary Threats")

		# Ward Pulse with BOTH threats alive affects both independently and spends 1 Wood once (3W -> 2W)
		var pulse_both: Dictionary = eg.try_activate_camp_defense(EldergroveForestArrival.CAMP_SITE_X)
		_check(bool(pulse_both.get("ok", false)) and int(pulse_both["affected_count"]) == 2 and eg.ledger.get_amount(&"wood") == 2, "Ward Pulse affects both active threats and spends Wood exactly once")
		_check(float(surv.threats[0]["stagger_remaining"]) > 0.0 and float(surv.threats[1]["stagger_remaining"]) > 0.0, "Both threats have independent stagger timers")

		# Expire stagger & let both Ordinary Threats march into First Camp boundary -> both blocked outside [-4, 164]
		eg._update_night_survival(3.1)
		for _i: int in range(25):
			eg._update_night_survival(0.5)
		var right_edge: float = EldergroveNightSurvival.CAMP_CENTER_X + EldergroveNightSurvival.CAMP_PROTECTION_RADIUS
		_check(float(surv.threats[0]["x"]) > right_edge and float(surv.threats[1]["x"]) > right_edge, "Both Ordinary Threats blocked outside First Camp protection")
		_check(eg.get_camp_integrity() == 3, "First Camp integrity remains 3/3 against multiple Ordinary Threats")

		# Place unprotected player overlapping BOTH threats in a single tick -> invulnerability blocks double hit!
		eg.player.global_position.x = float(surv.threats[0]["x"]) + 2.0
		var hits_before: int = _hit_signals
		eg._update_night_survival(0.05)
		_check(_hit_signals == hits_before + 1 and surv.get_player_vitality() == 2, "Multiple threats in one tick cannot bypass player invulnerability (exactly 1 hit)")

		# Overwhelmed retreat & Gold loss still work
		for _s: int in range(2):
			eg._update_night_survival(1.3)
			eg.player.global_position.x = float(surv.threats[0]["x"]) + 2.0
			eg._update_night_survival(0.05)
		_check(_retreat_signals == 1 and eg.ledger.get_amount(&"gold") == 1 and is_equal_approx(eg.player.global_position.x, EldergroveForestArrival.CAMP_SITE_X), "Overwhelmed retreat and 1 Gold penalty remain intact")

		# Sunrise resolves active multi-threat Day 4 encounter once
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + 1.0)
		_check(eg.time_manager.current_day == 5 and not surv.is_encounter_active() and _resolved_signals == 2 and surv.is_day_resolved(4), "Sunrise resolves active multi-threat encounter exactly once")

		# 4. Day 5 Breach-Capable Gloom Brute: single threat, breaches once (-1 integrity), repair [F] works
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		_check(surv.get_total_threat_count() == 1 and surv.threat_class == EldergroveNightSurvival.ThreatClass.BREACH_CAPABLE, "Day 5 spawns single Gloom Brute")
		for _i: int in range(30):
			eg._update_night_survival(0.5)
		_check(surv.camp_breached and eg.get_camp_integrity() == 2, "Gloom Brute breaches once and damages First Camp (3 -> 2)")
		var res_rep: Dictionary = eg.try_repair_first_camp(EldergroveForestArrival.CAMP_SITE_X, true)
		_check(bool(res_rep.get("ok", false)) and eg.get_camp_integrity() == 3 and eg.ledger.get_amount(&"wood") == 0, "Camp repair [F] restores 2 -> 3 for 2 Wood")
		_check(surv.resolve_encounter(true), "Resolved Day 5 encounter explicitly")

		_check(eg.save_game_state(SAVE_RESOLVED), "Saved Day 5 resolved state under SaveManager schema v2")
		_check(eg.return_to_main_menu(), "Exited Eldergrove cleanly to Main.tscn")
		_stage = 3
		_wait_frames = 0
		return false

	# Stage 3: Continue SAVE_RESOLVED
	if _stage == 3:
		if current_scene == null or current_scene.name != "Main":
			return false
		var main_node: Node = current_scene
		main_node.call("set_route_transition", Callable())
		Engine.set_meta("crownfall_menu_save_path", SAVE_RESOLVED)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_stage = 4
		_wait_frames = 0
		return false

	# Stage 4: Continue does not replay resolved encounters & schema v2 unchanged
	if _stage == 4:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg2: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg2.time_manager.auto_advance = false
		_check(eg2.is_restored_from_continue() and eg2.night_survival.is_day_resolved(3) and eg2.night_survival.is_day_resolved(4) and eg2.night_survival.is_day_resolved(5), "Continue restored all resolved days")
		eg2._update_night_survival(0.5)
		_check(not eg2.night_survival.is_encounter_active() and eg2.threat_presenter.get_visible_threat_count() == 0, "Continue does NOT replay resolved encounters")
		_check(SaveManager.SCHEMA_VERSION == 2, "SaveManager schema version remains v2")

		_cleanup()
		print("PASS: All %d N612 Multi-Threat Encounters checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
