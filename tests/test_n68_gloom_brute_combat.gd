extends SceneTree

## N6.8 Gloom Brute Combat & Threat Defeat integration & regression suite.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ELDERGROVE_SCENE: String = "res://scenes/world/EldergroveForest.tscn"
const TEST_DIR: String = "user://n68_test"
const SAVE_DEFEATED: String = "user://n68_test/save_defeated.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _base_payload: Dictionary = {}
var _defeat_signals: int = 0
var _resolved_signals: int = 0
var _hp_signals: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n68_gloom_brute_combat] " + msg)
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

	# Stage 0: Verify project input map has "attack" mapped to J & load ForgottenShore base payload
	if _stage == 0:
		_check(InputMap.has_action("attack"), "InputMap defines dedicated attack action")
		var events: Array[InputEvent] = InputMap.action_get_events("attack")
		var has_j: bool = false
		for ev: InputEvent in events:
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_J:
				has_j = true
		_check(has_j, "attack input action is mapped to KEY_J")

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

	# Stage 2: Combat eligibility, damage, defeat before breach, defeat after breach, Ward Pulse & N6.7 repair
	if _stage == 2:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg.time_manager.auto_advance = false
		var surv: EldergroveNightSurvival = eg.night_survival
		var pres: EldergroveThreatPresenter = eg.threat_presenter
		_defeat_signals = 0
		_resolved_signals = 0
		_hp_signals = 0
		surv.threat_defeated.connect(func(_d: int, _a: String) -> void: _defeat_signals += 1)
		surv.encounter_resolved.connect(func(_d: int, _s: bool, _b: bool) -> void: _resolved_signals += 1)
		surv.threat_health_changed.connect(func(_d: int, _c: int, _m: int, _dmg: int) -> void: _hp_signals += 1)

		# Build First Camp (4W 2S -> 5W left, 3/3 integrity)
		_check(bool(eg.try_interact_at(EldergroveForestArrival.CAMP_SITE_X).get("ok", false)), "Constructed First Camp (3/3 integrity)")

		# 1. No attack without active encounter
		var res_idle: Dictionary = eg.try_attack_threat(EldergroveForestArrival.CAMP_SITE_X, 1)
		_check(not bool(res_idle.get("ok", true)) and bool(res_idle.get("not_active", false)), "Attack rejected when no encounter is active")

		# 2. Ordinary Threat cannot be attacked
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		_check(surv.is_encounter_active() and surv.threat_class == EldergroveNightSurvival.ThreatClass.ORDINARY, "Day 4 Ordinary Threat active")
		var res_ord: Dictionary = eg.try_attack_threat(surv.threat_x - 20.0, 1)
		_check(not bool(res_ord.get("ok", true)) and bool(res_ord.get("wrong_target", false)), "Ordinary Threat cannot be attacked")
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + 1.0)
		_check(eg.time_manager.current_day == 5 and _resolved_signals == 1, "Day 4 Ordinary encounter resolved at Day 5 Sunrise")

		# 3. Day 5 Breach-Capable Gloom Brute: starts at 3 HP; test out-of-range, wrong-facing, echo press, cooldown, Ward Pulse (0 dmg), and kill BEFORE breach
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + eg.time_manager.sunset_duration + EldergroveNightSurvival.ENCOUNTER_START_OFFSET_SEC)
		eg._update_night_survival(0.1)
		_check(surv.is_encounter_active() and surv.threat_class == EldergroveNightSurvival.ThreatClass.BREACH_CAPABLE, "Day 5 Gloom Brute encounter active")
		_check(surv.threat_hp == 3 and surv.threat_max_hp == 3 and pres.is_hp_bar_visible(), "Gloom Brute starts at 3/3 HP with HP bar visible")

		# Out-of-range rejected
		var res_far: Dictionary = eg.try_attack_threat(surv.threat_x - 100.0, 1)
		_check(not bool(res_far.get("ok", true)) and bool(res_far.get("out_of_range", false)) and surv.threat_hp == 3, "Out-of-range attack rejected with zero damage")

		# Wrong-facing rejected
		var res_back: Dictionary = eg.try_attack_threat(surv.threat_x - 30.0, -1)
		_check(not bool(res_back.get("ok", true)) and bool(res_back.get("wrong_facing", false)) and surv.threat_hp == 3, "Wrong-facing attack rejected with zero damage")

		# Verify Ward Pulse works on Brute and deals ZERO damage
		var res_pulse: Dictionary = eg.try_activate_camp_defense(EldergroveForestArrival.CAMP_SITE_X)
		_check(bool(res_pulse.get("ok", false)) and surv.threat_hp == 3 and eg.ledger.get_amount(&"wood") == 4, "N6.6 Ward Pulse still works (costs 1W) and deals zero damage to Brute")

		# Verify key echo press in PlayerController produces ZERO attacks, while real press produces ONE attack
		eg.player.global_position.x = surv.threat_x - 32.0
		eg.player.facing_direction = 1
		var echo_ev := InputEventKey.new()
		echo_ev.physical_keycode = KEY_J
		echo_ev.pressed = true
		echo_ev.echo = true
		eg.player._unhandled_input(echo_ev)
		_check(surv.threat_hp == 3, "Held key echo produces zero repeated hits")

		var press_ev := InputEventKey.new()
		press_ev.physical_keycode = KEY_J
		press_ev.pressed = true
		press_ev.echo = false
		eg.player._unhandled_input(press_ev)
		_check(surv.threat_hp == 2 and _hp_signals == 1 and surv.is_attack_on_cooldown(), "Single [J] press deals exactly 1 damage (3 -> 2) and starts cooldown")

		# Cooldown rejects immediate second attack
		var res_cd: Dictionary = eg.try_attack_threat(surv.threat_x - 32.0, 1)
		_check(not bool(res_cd.get("ok", true)) and bool(res_cd.get("on_cooldown", false)) and surv.threat_hp == 2, "Attack cooldown rejects immediate follow-up hit")

		# Advance cooldown and deal hits 2 and 3 BEFORE Brute reaches First Camp
		eg._update_night_survival(0.5)
		var res_hit2: Dictionary = eg.try_attack_threat(surv.threat_x - 32.0, 1)
		_check(bool(res_hit2.get("ok", false)) and surv.threat_hp == 1 and not bool(res_hit2.get("defeated", true)), "Second hit reduces Brute HP to 1/3")

		eg._update_night_survival(0.5)
		var res_hit3: Dictionary = eg.try_attack_threat(surv.threat_x - 32.0, 1)
		_check(bool(res_hit3.get("ok", false)) and surv.threat_hp == 0 and bool(res_hit3.get("defeated", false)), "Third hit defeats Gloom Brute (HP 0/3, non-negative)")
		_check(_defeat_signals == 1 and _resolved_signals == 2 and surv.is_day_resolved(5), "Defeat emitted once and resolved Day 5 encounter once")
		_check(not surv.is_encounter_active() and not pres.is_threat_visible() and not pres.is_hp_bar_visible(), "Defeated Brute hidden immediately from presentation")
		_check(eg.get_camp_integrity() == 3, "Defeating Brute before breach prevented First Camp damage (3/3 intact)")

		# Defeated Brute cannot move, breach, be attacked again, or be affected by Ward Pulse
		var dead_x: float = surv.threat_x
		surv.tick(2.0, EldergroveForestArrival.CAMP_SITE_X, true)
		_check(is_equal_approx(surv.threat_x, dead_x) and eg.get_camp_integrity() == 3, "Defeated Brute cannot move or breach First Camp")
		var res_dead_atk: Dictionary = eg.try_attack_threat(dead_x - 20.0, 1)
		_check(not bool(res_dead_atk.get("ok", true)) and surv.threat_hp == 0 and _defeat_signals == 1, "Defeated Brute cannot be attacked again")

		# Save defeated Day 5 state for Continue check later, then advance to Day 6 Sunrise -> NO double resolution
		_check(eg.save_game_state(SAVE_DEFEATED), "Saved defeated Day 5 Night state under SaveManager schema v2")
		eg.time_manager.advance_time(eg.time_manager.get_current_phase_duration() - eg.time_manager.phase_elapsed + 1.0)
		_check(eg.time_manager.current_day == 6 and _resolved_signals == 2, "Day 6 Sunrise does not double-resolve already-defeated Day 5 encounter")

		# 4. New Breach encounter (Day 10) resets Brute HP to 3; let it breach First Camp (3 -> 2), then defeat it -> camp damage stays 2/3; repair restores 2 -> 3
		_check(surv.start_encounter(10, EldergroveNightSurvival.ThreatClass.BREACH_CAPABLE), "Started Day 10 Breach encounter")
		_check(surv.threat_hp == 3 and not surv.is_threat_defeated(), "New encounter resets Gloom Brute HP to 3/3 cleanly")
		for _i: int in range(30):
			surv.tick(0.5, EldergroveForestArrival.CAMP_SITE_X, true)
		_check(surv.camp_breached and eg.get_camp_integrity() == 2, "Day 10 Brute breached First Camp and reduced integrity to 2/3")
		for _h: int in range(3):
			surv.tick(0.5, EldergroveForestArrival.CAMP_SITE_X, true)
			eg.try_attack_threat(surv.threat_x - 20.0, 1)
		_check(surv.is_threat_defeated() and _defeat_signals == 2 and eg.get_camp_integrity() == 2, "Defeating Brute after breach does NOT reverse N6.7 camp damage (stays 2/3)")
		var res_rep: Dictionary = eg.try_repair_first_camp(EldergroveForestArrival.CAMP_SITE_X, true)
		_check(bool(res_rep.get("ok", false)) and eg.get_camp_integrity() == 3 and eg.ledger.get_amount(&"wood") == 2, "N6.7 repair still restores integrity (2 -> 3) for 2 Wood")

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

	# Stage 4: Continue does NOT replay defeated Day 5 encounter; SaveManager schema remains v2
	if _stage == 4:
		if current_scene == null or not (current_scene is EldergroveForestArrival):
			return false
		var eg2: EldergroveForestArrival = current_scene as EldergroveForestArrival
		eg2.time_manager.auto_advance = false
		_check(eg2.is_restored_from_continue() and eg2.night_survival.is_day_resolved(5), "Continue restored defeated Day 5 as resolved")
		eg2._update_night_survival(0.5)
		_check(not eg2.night_survival.is_encounter_active(), "Continue does NOT replay defeated Day 5 encounter")
		_check(SaveManager.SCHEMA_VERSION == 2, "SaveManager schema version remains v2")

		_cleanup()
		print("PASS: All %d N68 Gloom Brute Combat checks completed with 0 failures." % _checks)
		quit(0)
		return true

	return false
