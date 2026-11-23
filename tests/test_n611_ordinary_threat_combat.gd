extends SceneTree

## N6.11 Ordinary Threat Melee Combat integration & regression suite.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const TEST_DIR: String = "user://n611_test"
const SAVE_ORDINARY_DEFEATED: String = "user://n611_test/save_ordinary_defeated.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _base_payload: Dictionary = {}
var _defeat_signals: int = 0
var _resolved_signals: int = 0
var _overwhelmed_signals: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n611_ordinary_threat_combat] " + msg)
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
	_rm(SAVE_ORDINARY_DEFEATED)
	for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
		_rm(SAVE_ORDINARY_DEFEATED + suffix)


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
		eg_payload["day_count"] = 2
		eg_payload["world_time"] = 5.0
		eg_payload["world_phase"] = "daylight"
		eg_payload["resources"] = {"gold": 2, "wood": 6, "stone": 2}

		var prog := ProgressionState.new()
		prog.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)
		var era := EraProgressionManager.new()
		Engine.set_meta("crownfall_menu_save_path", SAVE_ORDINARY_DEFEATED)
		Engine.set_meta("crownfall_load_on_start", false)
		var tok: int = EldergroveHandoffBridge.authorize_departure(ELDERGROVE_SCENE, {
			"progression": prog,
			"era_mgr": era,
			"save_path": SAVE_ORDINARY_DEFEATED,
			"base_save_payload": eg_payload,
		})
		_check(tok > 0, "Authorized N5.5 handoff into Eldergrove")
		_check(change_scene_to_file(ELDERGROVE_SCENE) == OK, "Transitioned to EldergroveForest.tscn")
		_stage = 2
		_wait_frames = 0
		return false

	# Stage 2: Verify all 15 N6.11 Ordinary Threat combat, stagger, multi-encounter, Brute, Camp & N6.10 scenarios
	if _stage == 2:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg.time_manager.auto_advance = false
		var surv: EldergroveNightSurvival = eg.night_survival
		var pres: EldergroveThreatPresenter = eg.threat_presenter
		_defeat_signals = 0
		_resolved_signals = 0
		_overwhelmed_signals = 0
		surv.threat_defeated.connect(func(_d: int, _a: String) -> void: _defeat_signals += 1)
		surv.encounter_resolved.connect(func(_d: int, _s: bool, _b: bool) -> void: _resolved_signals += 1)
		surv.player_overwhelmed.connect(func(_d: int, _a: String) -> void: _overwhelmed_signals += 1)

		# Build First Camp (4W 2S -> leaves 2W, 2G)
		_check(bool(eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X).get("ok", false)), "Constructed First Camp (3/3 integrity)")

		# 1. Start Day 2 Ordinary Threat (2/2 HP); verify First Camp still protects player inside camp
		eg.player.global_position.x = EldergroveForestArrival.CAMP_SITE_X
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		_check(surv.is_encounter_active() and surv.threat_class == EldergroveNightSurvival.ThreatClass.ORDINARY, "Day 2 Ordinary Threat active")
		_check(surv.threat_hp == 2 and surv.threat_max_hp == 2 and pres.is_hp_bar_visible(), "Ordinary Threat starts at 2/2 HP with HP bar visible")

		for _i: int in range(20):
			eg._update_night_survival(0.5)
		_check(surv.threat_blocked and surv.get_player_vitality() == 3 and eg.get_camp_integrity() == 3, "First Camp still blocks Ordinary Threat and shields player inside camp")

		# 2. Out-of-range and wrong-facing attacks rejected
		var res_far: Dictionary = eg.try_attack_threat(surv.threat_x - 100.0, 1)
		_check(not bool(res_far.get("ok", true)) and bool(res_far.get("out_of_range", false)) and surv.threat_hp == 2, "Out-of-range attack against Ordinary Threat rejected")
		var res_back: Dictionary = eg.try_attack_threat(surv.threat_x - 24.0, -1)
		_check(not bool(res_back.get("ok", true)) and bool(res_back.get("wrong_facing", false)) and surv.threat_hp == 2, "Wrong-facing attack against Ordinary Threat rejected")

		# 3. Staggered Ordinary Threat via Ward Pulse cannot receive melee damage
		_check(bool(eg.try_activate_camp_defense(EldergroveForestArrival.CAMP_SITE_X).get("ok", false)), "Ward Pulse staggered Ordinary Threat (-1W)")
		var res_stag: Dictionary = eg.try_attack_threat(surv.threat_x - 24.0, 1)
		_check(not bool(res_stag.get("ok", true)) and bool(res_stag.get("staggered", false)) and surv.threat_hp == 2, "Staggered Ordinary Threat rejects melee damage cleanly")

		# Wait for stagger to expire (3.0s)
		eg._update_night_survival(3.1)
		_check(not surv.is_threat_staggered(), "Ordinary Threat stagger expired")

		# 4. Valid melee hit deals 1 damage (2 -> 1), starts cooldown, shows hit/impact cues & HUD feedback
		var res_hit1: Dictionary = eg.try_attack_threat(surv.threat_x - 24.0, 1)
		_check(bool(res_hit1.get("ok", false)) and surv.threat_hp == 1 and not bool(res_hit1.get("defeated", true)), "First hit deals 1 damage to Ordinary Threat (2 -> 1)")
		_check(pres.is_impact_cue_visible() and eg.feedback_label != null and eg.feedback_label.text.contains("Night Raider"), "Hit shows impact cue and Night Raider HUD feedback")

		# 5. Cooldown rejects immediate second hit
		var res_cd: Dictionary = eg.try_attack_threat(surv.threat_x - 24.0, 1)
		_check(not bool(res_cd.get("ok", true)) and bool(res_cd.get("on_cooldown", false)) and surv.threat_hp == 1, "Cooldown enforced on Ordinary Threat melee attacks")

		# 6. Second hit defeats Ordinary Threat, resolves encounter once, hides presentation, repeated attacks rejected
		eg._update_night_survival(0.5)
		var res_hit2: Dictionary = eg.try_attack_threat(surv.threat_x - 24.0, 1)
		_check(bool(res_hit2.get("ok", false)) and surv.threat_hp == 0 and bool(res_hit2.get("defeated", false)), "Second hit defeats Ordinary Threat (HP 0/2)")
		_check(_defeat_signals == 1 and _resolved_signals == 1 and surv.is_day_resolved(2), "Day 2 Ordinary Threat defeat emits once and resolves encounter once")
		_check(not pres.is_threat_visible() and not pres.is_hp_bar_visible(), "Defeated Ordinary Threat hidden immediately")
		var res_dead: Dictionary = eg.try_attack_threat(surv.threat_x - 20.0, 1)
		_check(not bool(res_dead.get("ok", true)) and _defeat_signals == 1 and surv.threat_hp == 0, "Repeated attacks cannot damage defeated Ordinary Threat")

		# Save defeated Day 2 state for Continue test later, then advance to Day 3 Sunrise -> no double resolution
		_check(eg.save_game_state(SAVE_ORDINARY_DEFEATED), "Saved Day 2 Ordinary defeat under SaveManager schema v2")
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + 1.0)
		_check(eg.time_manager.current_day == 3 and _resolved_signals == 1, "Day 3 Sunrise does not double-resolve defeated Day 2 Ordinary encounter")

		# 7. Second independent Ordinary Threat (Day 3): starts fresh at 2/2 HP, tests N6.10 contact damage + overwhelmed retreat + 1G loss, then defeats independently
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		_check(surv.is_encounter_active() and surv.threat_class == EldergroveNightSurvival.ThreatClass.ORDINARY and surv.threat_hp == 2, "Day 3 independent Ordinary Threat spawns with fresh 2/2 HP")

		# Step outside camp to verify N6.10 contact damage + overwhelmed retreat + 1G drop still work
		for _strike: int in range(3):
			eg.player.global_position.x = surv.threat_x + 5.0
			eg._update_night_survival(0.05)
			if _strike < 2:
				eg._update_night_survival(1.3)
		_check(_overwhelmed_signals == 1 and eg.ledger.get_amount(&"gold") == 1 and is_equal_approx(eg.player.global_position.x, EldergroveForestArrival.CAMP_SITE_X), "N6.10 contact damage, overwhelmed retreat, and 1G loss remain intact")

		# Defeat Day 3 Ordinary Threat independently
		eg._update_night_survival(0.5)
		eg.try_attack_threat(surv.threat_x - 24.0, 1)
		eg._update_night_survival(0.5)
		var res_d3: Dictionary = eg.try_attack_threat(surv.threat_x - 24.0, 1)
		_check(bool(res_d3.get("defeated", false)) and _defeat_signals == 2 and _resolved_signals == 2 and surv.is_day_resolved(3), "Multiple Ordinary Threats (Day 2 & Day 3) resolve independently")

		# 8. Gloom Brute combat (Day 5) remains unchanged (3 HP, 3 hits to defeat)
		_check(surv.start_encounter(5, EldergroveNightSurvival.ThreatClass.BREACH_CAPABLE), "Started Day 5 Gloom Brute encounter")
		_check(surv.threat_hp == 3 and surv.threat_max_hp == 3, "Gloom Brute still starts at 3/3 HP unchanged")
		for _h: int in range(3):
			eg._update_night_survival(0.5)
			eg.try_attack_threat(surv.threat_x - 24.0, 1)
		_check(surv.is_threat_defeated() and _defeat_signals == 3 and _resolved_signals == 3, "Gloom Brute still takes 3 hits and defeats cleanly")

		_check(eg.return_to_main_menu(), "Exited Eldergrove cleanly to Main.tscn")
		_stage = 3
		_wait_frames = 0
		return false

	# Stage 3: Continue SAVE_ORDINARY_DEFEATED
	if _stage == 3:
		if current_scene == null or current_scene.name != "Main":
			return false
		var main_node: Node = current_scene
		main_node.call("set_route_transition", Callable())
		Engine.set_meta("crownfall_menu_save_path", SAVE_ORDINARY_DEFEATED)
		main_node.set("_route_started", false)
		main_node.call("_on_continue_button_pressed")
		_stage = 4
		_wait_frames = 0
		return false

	# Stage 4: Continue does not replay defeated Day 2 Ordinary encounter; SaveManager schema v2 unchanged
	if _stage == 4:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg2: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg2.time_manager.auto_advance = false
		_check(eg2.is_restored_from_continue() and eg2.night_survival.is_day_resolved(2), "Continue restored defeated Day 2 Ordinary encounter as resolved")
		eg2._update_night_survival(0.5)
		_check(not eg2.night_survival.is_encounter_active(), "Continue does NOT replay defeated Ordinary Threat encounter")
		_check(SaveManager.SCHEMA_VERSION == 2, "SaveManager schema version remains v2")

		_cleanup()
		print("PASS: All %d N611 Ordinary Threat Combat checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
