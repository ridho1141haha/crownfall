extends SceneTree

## Phase 4 Research System Foundation test suite. Follows the repo test
## conventions: fail-fast _check helper, tab indentation, no raw engine assert
## calls, and no scene-tree child injection. Covers technology definition
## validation (fail-safe catalog, prerequisite graph, cycles, effect registry),
## authoritative requirement evaluation, transactional research starts through
## the atomic EconomyLedger, authoritative world-time progress with
## exactly-once completion, save/load persistence (active project resumes
## without re-deducting costs, completed techs never re-apply rewards,
## malformed data rejected wholesale, old saves without the research key keep
## loading), the real session command/effect paths (shrine offering and flare
## bonuses), and era-safety regression (no Iron Age, milestones untouched).

const T1: String = "inscription_studies"
const T2: String = "improved_flares"
const SCIENTIST_X: float = -1010.0
const SAVE_ROUNDTRIP_PATH: String = "user://test_research_roundtrip.json"
const SAVE_ACTIVE_PATH: String = "user://test_research_active.json"
const SAVE_MALFORMED_PATH: String = "user://test_research_malformed.json"

var _failures: int = 0
var _checks: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE [test_research_foundation]: " + msg)
		quit(1)
		return false
	return true


func _fresh_session() -> ForgottenShoreSession:
	var session_script: GDScript = load("res://scripts/world/ForgottenShoreSession.gd")
	return session_script.new() as ForgottenShoreSession


func _expand_plots(sess: ForgottenShoreSession) -> void:
	sess.building_mgr.register_forgotten_shore_expansion_plots()


func _fund(sess: ForgottenShoreSession, gold: int, wood: int, stone: int) -> bool:
	return sess.economy.set_balances_from_dict({"gold": gold, "wood": wood, "stone": stone})


## Drives the real recruitment path for the Scientist (discovery + housing +
## recruitment) so research requirements are met through genuine gameplay.
func _recruit_scientist(sess: ForgottenShoreSession) -> bool:
	sess.building_mgr.register_forgotten_shore_expansion_plots()
	if not _fund(sess, 10, 10, 10):
		return false
	if not sess.specialists.try_discover(SCIENTIST_X, "scientist", sess.progression):
		return false
	if not sess.building_mgr.request_start_construction(-980.0, sess.economy, "hut_scientist_01"):
		return false
	if not sess.building_mgr.advance_construction(8.0, "hut_scientist_01"):
		return false
	if not _fund(sess, 10, 10, 10):
		return false
	return sess.specialists.try_recruit(SCIENTIST_X, "scientist", sess.progression, sess.building_mgr, sess.economy)


# ---------------------------------------------------------------- Suite 1 ---
func _test_technology_catalog_validation() -> bool:
	var catalog: TechnologyCatalog = TechnologyCatalog.new()
	if not _check(not catalog.is_empty() and catalog.get_technology_ids() == ["improved_flares", "inscription_studies"], "Technologies data file loads exactly the two Forgotten Shore technologies with stable unique IDs (sorted)"):
		return false
	var t1: Dictionary = catalog.get_technology(T1)
	if not _check(t1.get("requires", {}) == {"all_of": ["scientist_recruited"]} and (t1.get("prerequisites", []) as Array).is_empty(), "First technology requires only the recruited scientist"):
		return false
	if not _check(t1.get("effects", {}) == {"shrine_offering_gold_bonus": 3} and is_equal_approx(float(t1.get("duration_sec", 0.0)), 90.0), "First technology defines its effect amount and research duration"):
		return false
	var t2: Dictionary = catalog.get_technology(T2)
	if not _check((t2.get("prerequisites", []) as Array) == [T1] and t2.get("requires", {}) == {"all_of": ["scientist_recruited", "forgotten_shore_first_stone_wall_tier_2"]}, "Second technology chains the prerequisite and the Stone Age fact gate"):
		return false
	if not _check(not TechnologyCatalog.KNOWN_EFFECT_IDS.has("made_up_effect") and TechnologyCatalog.KNOWN_EFFECT_IDS.has("shrine_offering_gold_bonus"), "Effect registry covers exactly the implemented consumers"):
		return false

	var errs: Array[String] = []
	var good: Dictionary = catalog.get_technology(T1)
	var bad_payloads: Array = [
		42,
		{"no_technologies": []},
		{"technologies": []},
		{"technologies": [42]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}, "bonus": 1}]},
		{"technologies": [{"display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}}]},
		{"technologies": [{"id": T1, "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}}]},
		{"technologies": [{"id": "Bad_ID", "display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}}]},
		{"technologies": [{"id": T1, "display_name": "  ", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": 0.0, "effects": {"shrine_offering_gold_bonus": 1}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": -5.0, "effects": {"shrine_offering_gold_bonus": 1}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": "ten", "effects": {"shrine_offering_gold_bonus": 1}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"iron": 2}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 0}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": -3}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 2.5}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"made_up_effect": 1}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 0}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": -1}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}, "requires": {"all_of": ["mount_tamed"]}}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}, "prerequisites": ["missing_tech"]}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}, "prerequisites": [T1]}]},
		{"technologies": [{"id": T1, "display_name": "T", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}, "prerequisites": [T1, T1]}]},
	]
	for bad_payload: Variant in bad_payloads:
		errs.clear()
		if not _check(TechnologyCatalog.validate_technologies_payload(bad_payload, errs).is_empty() and not errs.is_empty(), "Malformed technology payload rejected with reason: %s" % str(bad_payload)):
			return false

	# Duplicate IDs and prerequisite cycles reject the whole set.
	errs.clear()
	var dup: Dictionary = {"technologies": [
		good,
		{"id": T1, "display_name": "T2", "description": "D2", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"flare_duration_bonus_sec": 1}},
	]}
	if not _check(TechnologyCatalog.validate_technologies_payload(dup, errs).is_empty(), "Duplicate technology IDs rejected"):
		return false
	errs.clear()
	var cycle: Dictionary = {"technologies": [
		{"id": "tech_a", "display_name": "A", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}, "prerequisites": ["tech_b"]},
		{"id": "tech_b", "display_name": "B", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}, "prerequisites": ["tech_a"]},
	]}
	if not _check(TechnologyCatalog.validate_technologies_payload(cycle, errs).is_empty() and String(errs[0]).contains("cycle"), "Prerequisite cycles rejected with a reported chain"):
		return false
	errs.clear()
	var self_ref: Dictionary = {"technologies": [
		{"id": "tech_a", "display_name": "A", "description": "D", "cost": {"gold": 1}, "duration_sec": 10.0, "effects": {"shrine_offering_gold_bonus": 1}, "prerequisites": ["tech_a"]},
	]}
	if not _check(TechnologyCatalog.validate_technologies_payload(self_ref, errs).is_empty(), "Self-referencing prerequisites rejected"):
		return false

	print("PASS: Technology Definition Validation & Fail-Safe Catalog")
	return true


# ---------------------------------------------------------------- Suite 2 ---
func _test_requirements_and_status() -> bool:
	var sess: ForgottenShoreSession = _fresh_session()
	var research: ResearchManager = sess.research_mgr
	var progression: ProgressionState = sess.progression

	if not _check(research.get_research_status(T1, progression) == ResearchManager.STATUS_UNAVAILABLE, "Fresh kingdom has no available technology (scientist not recruited)"):
		return false
	if not _check(research.get_first_available_technology_id(progression).is_empty(), "No first-available technology before recruitment"):
		return false

	if not _check(_recruit_scientist(sess), "Suite2 setup: scientist recruited through the real path"):
		return false
	if not _check(research.get_research_status(T1, progression) == ResearchManager.STATUS_AVAILABLE, "Recruited scientist makes the first technology available"):
		return false
	if not _check(research.get_research_status(T2, progression) == ResearchManager.STATUS_UNAVAILABLE, "Second technology stays unavailable (prerequisite and Stone Age fact missing)"):
		return false
	if not _check(research.get_first_available_technology_id(progression) == T1, "First-available resolves the stable sorted order"):
		return false

	# Stone Age fact alone is not enough (prerequisite still missing).
	if not _check(progression.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2), "Suite2 setup: stone fact recorded"):
		return false
	if not _check(research.get_research_status(T2, progression) == ResearchManager.STATUS_UNAVAILABLE, "Stone Age fact without the completed prerequisite keeps the second technology unavailable"):
		return false

	# Completing the prerequisite (directly, for evaluation-only coverage) unlocks it.
	var eval_only: ResearchManager = ResearchManager.new()
	eval_only._completed[T1] = true
	var fact_only: ProgressionState = ProgressionState.new()
	fact_only.record_fact("scientist_recruited")
	fact_only.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2)
	if not _check(eval_only.get_research_status(T2, fact_only) == ResearchManager.STATUS_AVAILABLE, "Completed prerequisite plus scientist and Stone Age facts make the second technology available"):
		return false
	var no_sci: ProgressionState = ProgressionState.new()
	if not _check(eval_only.get_research_status(T2, no_sci) == ResearchManager.STATUS_UNAVAILABLE, "Prerequisite completion without the scientist fact stays unavailable"):
		return false

	if not _check(research.is_requirement_met(T1, progression) and not research.is_requirement_met("unknown_tech", progression), "Requirement evaluation is fail-closed for unknown technologies"):
		return false

	print("PASS: Research Requirements & Availability States")
	return true


# ---------------------------------------------------------------- Suite 3 ---
func _test_transactions() -> bool:
	var sess: ForgottenShoreSession = _fresh_session()
	var research: ResearchManager = sess.research_mgr
	var progression: ProgressionState = sess.progression
	var started_ids: Array = []
	research.research_started.connect(func(tech_id: String) -> void: started_ids.append(tech_id))
	var rejected: Array = []
	research.research_rejected.connect(func(reason: String) -> void: rejected.append(reason))

	if not _check(not research.try_start(T1, progression, sess.economy) and not rejected.is_empty(), "Starting research without a scientist is rejected"):
		return false
	if not _check(_recruit_scientist(sess), "Suite3 setup: scientist recruited"):
		return false

	# Insufficient resources: rejected, nothing deducted, nothing started.
	if not _fund(sess, 1, 5, 5):
		return false
	rejected.clear()
	if not _check(not research.try_start(T1, progression, sess.economy), "Unaffordable research start is rejected"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 1 and sess.economy.get_amount(&"wood") == 5 and sess.economy.get_amount(&"stone") == 5, "Failed start leaves balances exactly unchanged (no partial deduction)"):
		return false
	if not _check(not research.has_active_research() and rejected.size() == 1, "Failed start leaves no active project and reports the rejection"):
		return false

	# Unknown technology: rejected.
	rejected.clear()
	if not _check(not research.try_start("unknown_tech", progression, sess.economy) and rejected.size() == 1, "Unknown technology start is rejected"):
		return false

	# Successful start: exact atomic deduction and active project.
	if not _fund(sess, 10, 10, 10):
		return false
	if not _check(research.try_start(T1, progression, sess.economy), "Affordable research start succeeds"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 7 and sess.economy.get_amount(&"wood") == 8 and sess.economy.get_amount(&"stone") == 10, "Start deducts exactly the data-defined cost (3G 2W)"):
		return false
	if not _check(research.get_active_tech_id() == T1 and is_equal_approx(research.get_active_elapsed(), 0.0) and started_ids == [T1], "Active project set with zero elapsed time and the started signal emitted"):
		return false

	# One project at a time: second start rejected without spending.
	rejected.clear()
	if not _check(not research.try_start(T2, progression, sess.economy), "Starting a second project while one is active is rejected"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 7 and rejected.size() == 1, "Second-start rejection never deducts resources"):
		return false

	print("PASS: Transactional Research Starts")
	return true


# ---------------------------------------------------------------- Suite 4 ---
func _test_timing_and_completion() -> bool:
	var sess: ForgottenShoreSession = _fresh_session()
	var research: ResearchManager = sess.research_mgr
	var progression: ProgressionState = sess.progression
	var completed_ids: Array = []
	research.research_completed.connect(func(tech_id: String) -> void: completed_ids.append(tech_id))

	if not _check(_recruit_scientist(sess), "Suite4 setup: scientist recruited"):
		return false
	if not _check(research.try_start(T1, progression, sess.economy), "Suite4 setup: research started"):
		return false

	# Partial progress: below duration nothing completes.
	if not _check(not research.advance_research(45.0), "Partial advance does not complete the project"):
		return false
	if not _check(is_equal_approx(research.get_active_elapsed(), 45.0) and not research.is_completed(T1) and completed_ids.is_empty(), "Partial advance accumulates authoritative elapsed time without completing"):
		return false
	if not _check(is_equal_approx(research.get_active_progress_ratio(), 0.5), "Progress ratio reflects half completion"):
		return false

	# Negative/zero deltas are ignored.
	if not _check(not research.advance_research(0.0) and not research.advance_research(-3.0), "Zero and negative deltas never advance research"):
		return false

	# Completion at the duration boundary: exactly once.
	if not _check(research.advance_research(45.0), "Reaching the duration completes the project"):
		return false
	if not _check(research.is_completed(T1) and not research.has_active_research() and completed_ids == [T1], "Completion marks the technology, clears the project and emits the signal once"):
		return false

	# Exactly-once protection: further advances are no-ops.
	if not _check(not research.advance_research(500.0) and completed_ids.size() == 1, "Advancing after completion is a no-op (completion happens exactly once)"):
		return false

	# Effects become observable exactly once (no reward duplication on repeats).
	if not _check(research.get_effect_total(ResearchManager.EFFECT_SHRINE_OFFERING_GOLD_BONUS) == 3 and research.get_effect_total(ResearchManager.EFFECT_FLARE_DURATION_BONUS_SEC) == 0, "Completion effect total matches the definition"):
		return false
	if not _check(research.get_effect_total("made_up_effect") == 0, "Unknown effect IDs aggregate to zero"):
		return false

	# The second technology can now start after its Stone Age fact is recorded.
	if not _check(progression.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2), "Suite4 setup: stone fact"):
		return false
	if not _check(research.get_research_status(T2, progression) == ResearchManager.STATUS_AVAILABLE, "Completed prerequisite unlocks the chained technology"):
		return false
	if not _check(research.try_start(T2, progression, sess.economy), "Second project starts after the first completes"):
		return false
	if not _check(research.advance_research(120.0) and research.is_completed(T2), "Second project completes over its own duration"):
		return false
	if not _check(research.get_effect_total(ResearchManager.EFFECT_FLARE_DURATION_BONUS_SEC) == 4, "Second completion effect becomes observable"):
		return false

	print("PASS: Authoritative Timing & Exactly-Once Completion")
	return true


# ---------------------------------------------------------------- Suite 5 ---
func _test_save_load_and_compatibility() -> bool:
	var sm: SaveManager = SaveManager.new()

	# Static structural validator rejections.
	var bad_dicts: Array = [
		42,
		{"completed_techs": "not_an_array"},
		{"active_research": null},
		{"completed_techs": [], "active_research": {}},
		{"completed_techs": [], "active_research": {"technology_id": "Bad_ID", "elapsed_sec": 1.0}},
		{"completed_techs": [], "active_research": {"technology_id": T1}},
		{"completed_techs": [], "active_research": {"technology_id": T1, "elapsed_sec": -1.0}},
		{"completed_techs": [], "active_research": {"technology_id": T1, "elapsed_sec": "ten"}},
		{"completed_techs": [], "active_research": {"technology_id": T1, "elapsed_sec": 1.0, "extra": true}},
		{"completed_techs": [T1, T1], "active_research": null},
		{"completed_techs": ["Bad_ID"], "active_research": null},
		{"completed_techs": [42], "active_research": null},
		{"completed_techs": [], "active_research": null, "extra_field": 1},
	]
	for bad: Variant in bad_dicts:
		if not _check(not ResearchManager.is_valid_saved_research_dict(bad), "Malformed research save dict rejected: %s" % str(bad)):
			return false
	if not _check(ResearchManager.is_valid_saved_research_dict({"completed_techs": [T1], "active_research": null}), "Valid completed-only research dict accepted"):
		return false

	# Instance-level apply: unknown technology IDs rejected with zero mutation.
	var research: ResearchManager = ResearchManager.new()
	if not _check(not research.apply_save_dict({"completed_techs": ["unknown_tech_x"], "active_research": null}), "Unknown completed technology ID rejected at apply time"):
		return false
	if not _check(research.get_completed_tech_ids().is_empty() and not research.has_active_research(), "Failed apply leaves research state untouched"):
		return false
	if not _check(not research.apply_save_dict({"completed_techs": [], "active_research": {"technology_id": T1, "elapsed_sec": 500.0}}), "Active project with elapsed beyond its duration is rejected"):
		return false

	# Active research round-trip through the real session save pipeline.
	var src: ForgottenShoreSession = _fresh_session()
	_expand_plots(src)
	if not _check(_recruit_scientist(src), "Suite5 setup: scientist recruited"):
		return false
	if not _fund(src, 10, 10, 10):
		return false
	if not _check(src.research_mgr.try_start(T1, src.progression, src.economy), "Suite5 setup: research started"):
		return false
	if not _check(not src.research_mgr.advance_research(30.0), "Suite5 setup: partial advance does not complete"):
		return false
	var before_gold: int = src.economy.get_amount(&"gold")
	var payload: Dictionary = src.build_save_payload()
	if not _check(sm.validate_payload(payload), "Payload with an active research project passes strict validation"):
		return false
	var res_dict: Dictionary = payload["research"] as Dictionary
	if not _check((res_dict["completed_techs"] as Array).is_empty() and String((res_dict["active_research"] as Dictionary)["technology_id"]) == T1 and is_equal_approx(float((res_dict["active_research"] as Dictionary)["elapsed_sec"]), 30.0), "Active project serializes with its exact elapsed time"):
		return false
	if not _check(sm.save_state(payload.duplicate(true), SAVE_ACTIVE_PATH), "Active-research save written"):
		return false

	var dst: ForgottenShoreSession = _fresh_session()
	_expand_plots(dst)
	if not _fund(dst, 1, 1, 1):
		return false
	if not _check(dst.load_game_state(SAVE_ACTIVE_PATH), "Active-research save loads into a fresh session"):
		return false
	if not _check(dst.research_mgr.get_active_tech_id() == T1 and is_equal_approx(dst.research_mgr.get_active_elapsed(), 30.0), "Active project resumes with its exact elapsed time"):
		return false
	if not _check(dst.economy.get_amount(&"gold") == before_gold, "Loading an active project never re-deducts its cost"):
		return false
	if not _check(dst.research_mgr.advance_research(59.0) == false and is_equal_approx(dst.research_mgr.get_active_elapsed(), 89.0), "Research continues deterministically after load"):
		return false
	if not _check(dst.research_mgr.advance_research(1.0) and dst.research_mgr.is_completed(T1) and not dst.research_mgr.has_active_research(), "Project completes exactly once after resuming"):
		return false

	# Completed-research round-trip: reward applied exactly once across loads.
	if not _check(sm.save_state(dst.build_save_payload().duplicate(true), SAVE_ROUNDTRIP_PATH), "Completed-research save written"):
		return false
	var dst2: ForgottenShoreSession = _fresh_session()
	_expand_plots(dst2)
	if not _check(dst2.load_game_state(SAVE_ROUNDTRIP_PATH), "Completed-research save loads"):
		return false
	if not _check(dst2.research_mgr.is_completed(T1) and dst2.research_mgr.get_effect_total(ResearchManager.EFFECT_SHRINE_OFFERING_GOLD_BONUS) == 3, "Completed technology restores its effect total exactly"):
		return false
	if not _check(dst2.research_mgr.advance_research(999.0) == false, "Loading a completed project does not re-apply or re-complete anything"):
		return false

	# Old saves without the research key keep loading (schema v2 unchanged).
	var old_payload: Dictionary = dst.build_save_payload()
	old_payload.erase("research")
	if not _check(sm.validate_payload(old_payload), "Payload without the research key still validates (schema v2 unchanged)"):
		return false
	var legacy_sess: ForgottenShoreSession = _fresh_session()
	if not _check(legacy_sess.research_mgr.get_completed_tech_ids().is_empty() and not legacy_sess.research_mgr.has_active_research(), "Sessions without research data default to an empty research state"):
		return false

	# Explicit "research": null is malformed (not the same as an absent field):
	# strict validation rejects it wholesale, exactly like the Phase 2.1/2.2
	# progression_facts policy.
	var null_research: Dictionary = dst.build_save_payload()
	null_research["research"] = null
	if not _check(not sm.validate_payload(null_research), "Explicit null research key is rejected as malformed (absent key stays valid)"):
		return false

	# Corrupt research data inside a save file is rejected wholesale.
	var bad_payload: Dictionary = dst.build_save_payload()
	bad_payload["research"] = {"completed_techs": ["unknown_tech_y"], "active_research": null}
	if not _check(not sm.validate_payload(bad_payload), "Unknown technology ID in the research save key is rejected by strict validation"):
		return false
	var bf: FileAccess = FileAccess.open(SAVE_MALFORMED_PATH, FileAccess.WRITE)
	bf.store_string(JSON.stringify(bad_payload))
	bf.close()
	var victim: ForgottenShoreSession = _fresh_session()
	_expand_plots(victim)
	var facts_before: Array = victim.progression.get_fact_ids()
	if not _check(not victim.load_game_state(SAVE_MALFORMED_PATH) and victim.research_mgr.get_completed_tech_ids().is_empty() and victim.progression.get_fact_ids() == facts_before, "Corrupt research save fails to load without partially mutating live state"):
		return false

	print("PASS: Research Save/Load, Compatibility & Rejection")
	return true


# ---------------------------------------------------------------- Suite 6 ---
func _test_session_effects_and_regression() -> bool:
	var sess: ForgottenShoreSession = _fresh_session()
	_expand_plots(sess)
	var feedback: Array = []
	sess.feedback_message.connect(func(text: String) -> void: feedback.append(text))
	# Tree-less sessions skip _ready/_wire_signals, so mirror the real wiring.
	sess.research_mgr.research_started.connect(sess._on_research_started)
	sess.research_mgr.research_completed.connect(sess._on_research_completed)
	sess.research_mgr.research_rejected.connect(sess._record_rejection)

	# Fresh session: shrine offering yields the original 2 gold.
	if not _fund(sess, 10, 10, 10):
		return false
	if not _check(sess.progression.record_fact("shrine_cache_far_west_marker") == false, "Unknown fact stays rejected (registry integrity unaffected by Phase 4)"):
		return false
	sess.set_actor_position("player_1", -780.0)
	if not _check(bool(sess.execute_world_command("player_1", &"shrine_offering", "").get("ok", false)), "Suite6 setup: shrine offering accepted on a fresh session"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 12, "Fresh shrine offering yields the original +2 gold"):
		return false

	# Without a recruited specialist the research command is rejected.
	sess.set_actor_position("player_1", -780.0)
	if not _check(not bool(sess.execute_world_command("player_1", &"start_research", "").get("ok", false)), "Research command without a recruited specialist is rejected"):
		return false

	# Full path: recruit the scientist, start research via command, complete it.
	if not _check(_recruit_scientist(sess), "Suite6 setup: scientist recruited"):
		return false
	if not _fund(sess, 10, 10, 10):
		return false
	sess.set_actor_position("player_1", SCIENTIST_X)
	if not _check(bool(sess.execute_world_command("player_1", &"start_research", "").get("ok", false)), "Research command with an empty target starts the first available technology"):
		return false
	if not _check(sess.research_mgr.get_active_tech_id() == T1 and not feedback.is_empty(), "Research start emits feedback through the session handler"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 7 and sess.economy.get_amount(&"wood") == 8, "Command-started research deducts exactly 3G 2W"):
		return false

	# Second start while active: rejected via the command path.
	if not _check(not bool(sess.execute_world_command("player_1", &"start_research", T2).get("ok", false)), "Duplicate research start via command is rejected"):
		return false

	# Advance to completion and observe the shrine effect change.
	sess.research_mgr.advance_research(90.0)
	if not _check(sess.research_mgr.is_completed(T1) and not feedback.is_empty(), "Completion emits feedback through the session handler"):
		return false
	if not _fund(sess, 10, 10, 10):
		return false
	sess.shrine_offering_used_today = false
	sess.set_actor_position("player_1", -780.0)
	if not _check(bool(sess.execute_world_command("player_1", &"shrine_offering", "").get("ok", false)), "Post-research shrine offering accepted"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 15, "Post-research shrine offering yields 2 + 3 bonus gold (data-driven effect)"):
		return false

	# Flare effect: complete the second technology first, then verify the
	# night-gated command reflects the data-driven bonus duration.
	if not _check(sess.progression.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2), "Suite6 setup: Stone Age fact recorded"):
		return false
	if not _fund(sess, 10, 10, 10):
		return false
	sess.set_actor_position("player_1", SCIENTIST_X)
	if not _check(bool(sess.execute_world_command("player_1", &"start_research", T2).get("ok", false)), "Second technology starts via the command path"):
		return false
	sess.research_mgr.advance_research(120.0)
	if not _check(sess.research_mgr.is_completed(T2), "Second technology completes over its duration"):
		return false
	var tm: TimeManager = TimeManager.new()
	tm.current_phase = TimeManager.Phase.NIGHT
	sess.time_manager = tm
	if not _fund(sess, 10, 10, 10):
		return false
	sess.set_actor_position("player_1", 0.0)
	if not _check(bool(sess.execute_world_command("player_1", &"kindle_flare", "").get("ok", false)), "Flare command accepted at night"):
		return false
	if not _check(is_equal_approx(sess.flare_active_timer, 12.0), "Flare duration applies the data-driven research bonus (8s + 4s)"):
		return false

	# Resolver offers research only for the recruited scientist without an
	# active project.
	sess.research_mgr.advance_research(0.0)
	var tgt: Dictionary = InteractionResolver.resolve_nearest(SCIENTIST_X, sess.resource_mgr, sess.building_mgr, sess.pop_mgr, sess.hearth_sys, sess.shipwreck_stage, ForgottenShoreSession.SHIPWRECK_X, ForgottenShoreSession.PORTAL_X, sess.portal_relic_looted, sess.shrine_offering_used_today, sess.tree_mgr, sess.specialists, sess.progression, sess.research_mgr)
	if not _check(String(tgt.get("kind", "")) != "research", "No research interaction while another project is active"):
		return false

	# Era safety regression: research never touches era progression.
	if not _check(sess.era_mgr.get_era_id() == "wood_age", "Era stays Wood Age through the full research loop"):
		return false
	if not _check(not sess.progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED), "No Eldergrove fact is ever fabricated by research"):
		return false
	if not _check(sess.era_mgr.notify_eldergrove_milestone(sess.progression) == false, "Iron Age gate stays fail-closed on Forgotten Shore"):
		return false

	print("PASS: Session Effect Integration & Era-Safety Regression")
	return true


func _init() -> void:
	var suite_names: Array[String] = [
		"Technology Validation & Catalog", "Requirements & Availability",
		"Transactional Starts", "Timing & Completion",
		"Save/Load & Compatibility", "Session Effects & Regression",
	]
	var suites: Array[Callable] = [
		_test_technology_catalog_validation, _test_requirements_and_status,
		_test_transactions, _test_timing_and_completion,
		_test_save_load_and_compatibility, _test_session_effects_and_regression,
	]
	var failed_suites: Array[String] = []
	for i: int in range(suites.size()):
		var checks_before: int = _checks
		var ok: bool = false
		ok = suites[i].call()
		if not ok:
			failed_suites.append("%s (after %d checks)" % [suite_names[i], _checks - checks_before])
	if _failures > 0 or not failed_suites.is_empty():
		printerr("RECAP: %d/%d suites FAILED -> %s" % [failed_suites.size(), suites.size(), ", ".join(failed_suites)])
		quit(1)
		return
	print("PASS: All %d Research System Foundation Checks completed with 0 failures across %d suites." % [_checks, suites.size()])
	quit(0)
