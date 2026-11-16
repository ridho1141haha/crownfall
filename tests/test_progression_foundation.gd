extends SceneTree

## Phase 1 Progression Foundation test suite. Follows the repo test conventions:
## fail-fast _check helper, tab indentation, no raw engine assert calls, and no
## scene-tree child injection. Covers fact recording/idempotency/validation,
## serialization round-trips, definition validation, all_of/any_of evaluation,
## the Stone Age milestone integration, and save compatibility/migration.

const FACT: String = "forgotten_shore_first_stone_wall_tier_2"
const BAD_SAVE_PATH: String = "user://test_progression_bad_defs.json"
const SAVE_ROUNDTRIP_PATH: String = "user://test_progression_roundtrip.json"
const SAVE_MALFORMED_FACTS_PATH: String = "user://test_progression_malformed_facts.json"

var _failures: int = 0
var _checks: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE [test_progression_foundation]: " + msg)
		quit(1)
		return false
	return true


func _fresh_session() -> ForgottenShoreSession:
	var session_script: GDScript = load("res://scripts/world/ForgottenShoreSession.gd")
	return session_script.new() as ForgottenShoreSession


# ---------------------------------------------------------------- Suite 1 ---
func _test_fact_recording_basics() -> bool:
	var p: ProgressionState = ProgressionState.new()
	if not _check(p.fact_count() == 0 and not p.has_fact(FACT), "Fresh ProgressionState starts empty"):
		return false

	var recorded: Array = []
	p.fact_recorded.connect(func(fid: String) -> void: recorded.append(fid))

	if not _check(p.record_fact(FACT), "Recording a valid fact succeeds"):
		return false
	if not _check(p.has_fact(FACT) and p.fact_count() == 1, "Recorded fact is present exactly once"):
		return false

	if not _check(p.record_fact(FACT), "Duplicate recording returns true (idempotent)"):
		return false
	if not _check(p.fact_count() == 1 and recorded.size() == 1, "Duplicate recording emits no second signal and does not duplicate"):
		return false

	# Invalid IDs must be rejected without touching state.
	var invalid_ids: Array = [
		"", "   ", "Stone_Wall", "stone wall", "stone-wall", "trailing_",
		"_leading", "double__underscore", "9starts_digit", "stône", 42, null,
		"a".repeat(ProgressionState.MAX_STABLE_ID_LENGTH + 1),
	]
	for bad_id: Variant in invalid_ids:
		if not _check(not p.record_fact(bad_id), "Invalid fact id rejected: %s" % str(bad_id)):
			return false
	if not _check(p.fact_count() == 1, "Invalid IDs never mutate state"):
		return false

	# Well-formed but unknown to the registry: rejected (no ghost facts).
	if not _check(not p.record_fact("eldergrove_reached"), "Unknown well-formed fact id is rejected by registry"):
		return false
	if not _check(not ProgressionState.is_valid_fact_id("eldergrove_reached"), "is_valid_fact_id rejects unknown id"):
		return false
	if not _check(ProgressionState.is_valid_stable_id("eldergrove_reached") and not ProgressionState.is_valid_fact_id("eldergrove_reached"), "Unknown id is well-formed but not registry-approved"):
		return false

	# Internal collection is never exposed: get_fact_ids returns a copy.
	var ids: Array[String] = p.get_fact_ids()
	ids.append("tampered")
	if not _check(p.fact_count() == 1 and p.get_fact_ids() == [FACT], "get_fact_ids returns a defensive copy"):
		return false
	if not _check(not p.has_fact("") and not p.has_fact("UPPER"), "has_fact is false for malformed ids"):
		return false

	print("PASS: Progression Fact Recording, Idempotency & ID Validation")
	return true


# ---------------------------------------------------------------- Suite 2 ---
func _test_fact_serialization_roundtrip() -> bool:
	var p: ProgressionState = ProgressionState.new()
	if not _check(p.record_fact(FACT), "Suite2 setup: record fact"):
		return false

	var arr: Array = p.to_save_array()
	if not _check(arr == [FACT], "to_save_array serializes sorted plain strings"):
		return false

	# JSON round-trip: stringify -> parse -> restore into a fresh state.
	var parsed: Variant = JSON.parse_string(JSON.stringify(arr))
	if not _check(typeof(parsed) == TYPE_ARRAY, "JSON round-trip keeps an array of strings"):
		return false
	var restored: ProgressionState = ProgressionState.new()
	if not _check(restored.apply_save_state(parsed) and restored.has_fact(FACT) and restored.fact_count() == 1, "Serialization and restoration round-trip preserves the fact"):
		return false

	# Absent field (null) deterministically clears.
	if not _check(p.apply_save_state(null) and p.fact_count() == 0, "apply_save_state(null) deterministically clears"):
		return false
	if not _check(p.apply_save_state([FACT]) and p.fact_count() == 1, "Valid array restores state"):
		return false

	# Invalid payloads: rejected with zero partial mutation.
	var invalid_payloads: Array = [
		FACT, 42, {}, {"forgotten_shore_first_stone_wall_tier_2": true},
		[42], [""], ["BAD ID"], ["stone-wall"], ["eldergrove_reached"],
		[FACT, FACT], [FACT, ""], [FACT, "eldergrove_reached"],
	]
	for bad_payload: Variant in invalid_payloads:
		var before: Array = p.get_fact_ids()
		if not _check(not p.apply_save_state(bad_payload), "Invalid restore payload rejected: %s" % str(bad_payload)):
			return false
		if not _check(p.get_fact_ids() == before, "Rejected payload mutated nothing (still %s)" % str(before)):
			return false

	if not _check(ProgressionState.is_valid_fact_array([FACT]) and not ProgressionState.is_valid_fact_array("x") and not ProgressionState.is_valid_fact_array([FACT, FACT]), "is_valid_fact_array matches apply_save_state contract"):
		return false

	print("PASS: Progression Fact Serialization, Restore & Transactional Rejection")
	return true


# ---------------------------------------------------------------- Suite 3 ---
func _test_definition_validation() -> bool:
	# Real shipped data file loads and contains the Stone Age definition.
	var catalog: ProgressionUnlockCatalog = ProgressionUnlockCatalog.new()
	if not _check(not catalog.is_empty() and catalog.has_definition("stone_age_era"), "Shipped data/unlocks.json loads with stone_age_era definition"):
		return false
	var def: Dictionary = catalog.get_definition("stone_age_era")
	if not _check(String(def.get("id", "")) == "stone_age_era" and (def.get("requires", {}) as Dictionary).get("all_of", []) == [FACT], "stone_age_era definition requires the stone wall fact via all_of"):
		return false
	if not _check(catalog.get_definition_ids() == ["stone_age_era"], "Catalog exposes exactly the shipped definition IDs"):
		return false
	# Defensive copies: mutating a returned definition cannot corrupt the catalog.
	var tampered: Dictionary = catalog.get_definition("stone_age_era")
	(tampered["requires"] as Dictionary)["all_of"] = ["tampered_id"]
	if not _check((catalog.get_definition("stone_age_era")["requires"] as Dictionary)["all_of"] == [FACT], "get_definition returns a defensive deep copy"):
		return false

	# Pure static validator: malformed payloads (no files needed).
	var errors: Array[String] = []
	errors.clear()
	var non_object: Dictionary = ProgressionUnlockCatalog.validate_definitions_payload(null, errors)
	if not _check(non_object.is_empty() and not errors.is_empty(), "Non-object payload rejected with a reported reason"):
		return false

	var malformed: Array = [
		{}, {"unlocks": "x"}, {"unlocks": [42]}, {"unlocks": [{}]},
		{"unlocks": [{"requires": {"all_of": [FACT]}}]},
		{"unlocks": [{"id": "def_a", "requires": {}}]},
		{"unlocks": [{"id": "def_a"}]},
		{"unlocks": [{"id": "Def_A", "requires": {"all_of": [FACT]}}]},
		{"unlocks": [{"id": "def_a", "extra": 1, "requires": {"all_of": [FACT]}}]},
		{"unlocks": [{"id": "def_a", "requires": {"all_of": []}}]},
		{"unlocks": [{"id": "def_a", "requires": {"any_of": []}}]},
		{"unlocks": [{"id": "def_a", "requires": {"all_of": [FACT], "bogus": [FACT]}}]},
		{"unlocks": [{"id": "def_a", "requires": {"all_of": ["eldergrove_reached"]}}]},
		{"unlocks": [{"id": "def_a", "requires": {"all_of": FACT}}]},
		{"unlocks": [{"id": "def_a", "requires": {"all_of": [FACT, FACT]}}]},
		{"unlocks": [{"id": "def_a", "requires": {"all_of": [FACT]}}, {"id": "def_a", "requires": {"any_of": [FACT]}}]},
	]
	for bad_payload: Variant in malformed:
		errors.clear()
		var result: Dictionary = ProgressionUnlockCatalog.validate_definitions_payload(bad_payload, errors)
		if not _check(result.is_empty() and not errors.is_empty(), "Malformed definition payload rejected with reason: %s" % str(bad_payload)):
			return false

	# Valid combined all_of + any_of normalizes and passes.
	errors.clear()
	var combined: Dictionary = ProgressionUnlockCatalog.validate_definitions_payload(
		{"unlocks": [{"id": "def_a", "requires": {"all_of": [FACT], "any_of": [FACT]}}]}, errors)
	if not _check(not combined.is_empty() and errors.is_empty(), "Combined all_of + any_of definition validates"):
		return false

	# Loader fail-safety: missing file and malformed file on disk.
	var missing: ProgressionUnlockCatalog = ProgressionUnlockCatalog.new()
	if not _check(not missing.load_from_data("res://data/does_not_exist_unlocks.json"), "Missing definitions file fails to load"):
		return false
	if not _check(missing.is_empty() and not missing.get_validation_errors().is_empty(), "Failed load leaves an empty catalog and reports errors"):
		return false

	var f: FileAccess = FileAccess.open(BAD_SAVE_PATH, FileAccess.WRITE)
	f.store_string("{\"unlocks\": [{\"id\": \"bad def id\"}]}")
	f.close()
	var bad_loader: ProgressionUnlockCatalog = ProgressionUnlockCatalog.new()
	if not _check(not bad_loader.load_from_data(BAD_SAVE_PATH), "Malformed definitions file fails to load"):
		return false
	if not _check(bad_loader.is_empty(), "Malformed file load is transactional (catalog stays empty)"):
		return false
	if not _check(bad_loader.load_from_data(ProgressionUnlockCatalog.DATA_PATH) and bad_loader.has_definition("stone_age_era"), "Reloading valid data recovers the catalog"):
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BAD_SAVE_PATH))

	print("PASS: Unlock Definition Loader, Strict Validation & Fail-Safe Loading")
	return true


# ---------------------------------------------------------------- Suite 4 ---
func _test_unlock_evaluation() -> bool:
	var state: ProgressionState = ProgressionState.new()
	var catalog: ProgressionUnlockCatalog = ProgressionUnlockCatalog.new()

	# Real catalog definition: locked without the fact, available with it.
	if not _check(not ProgressionUnlockEvaluator.is_unlock_satisfied(catalog.get_definition("stone_age_era"), state), "stone_age_era locked without the stone wall fact"):
		return false
	if not _check(state.record_fact(FACT) and ProgressionUnlockEvaluator.is_unlock_satisfied(catalog.get_definition("stone_age_era"), state), "stone_age_era available once the fact exists"):
		return false

	# all_of truth table (synthetic definitions).
	var other: String = ProgressionState.KNOWN_FACT_IDS[0]
	var defs := {
		"all_met": {"id": "all_met", "requires": {"all_of": [FACT]}},
		"all_missing": {"id": "all_missing", "requires": {"all_of": [other, "x_never_recorded_xyz"]}},
		"any_met": {"id": "any_met", "requires": {"any_of": [other, "x_never_recorded_xyz"]}},
		"any_missing": {"id": "any_missing", "requires": {"any_of": ["x_a_not_real", "x_b_not_real"]}},
		"combined_met": {"id": "combined_met", "requires": {"all_of": [FACT], "any_of": ["x_a_not_real", other]}},
		"combined_all_fail": {"id": "combined_all_fail", "requires": {"all_of": ["x_a_not_real"], "any_of": [other]}},
		"combined_any_fail": {"id": "combined_any_fail", "requires": {"all_of": [FACT], "any_of": ["x_a_not_real"]}},
	}
	if not _check(ProgressionUnlockEvaluator.is_unlock_satisfied(defs["all_met"], state), "all_of satisfied when every fact exists"):
		return false
	if not _check(not ProgressionUnlockEvaluator.is_unlock_satisfied(defs["all_missing"], state), "all_of unsatisfied when one fact is missing"):
		return false
	if not _check(ProgressionUnlockEvaluator.is_unlock_satisfied(defs["any_met"], state), "any_of satisfied when at least one fact exists"):
		return false
	if not _check(not ProgressionUnlockEvaluator.is_unlock_satisfied(defs["any_missing"], state), "any_of unsatisfied when no fact exists"):
		return false
	if not _check(ProgressionUnlockEvaluator.is_unlock_satisfied(defs["combined_met"], state), "Combined all_of + any_of satisfied only when both groups pass"):
		return false
	if not _check(not ProgressionUnlockEvaluator.is_unlock_satisfied(defs["combined_all_fail"], state), "Combined definition with failing all_of never unlocks"):
		return false
	if not _check(not ProgressionUnlockEvaluator.is_unlock_satisfied(defs["combined_any_fail"], state), "Combined definition with failing any_of never unlocks"):
		return false

	# Empty/invalid requirement groups never unlock (fail-closed, defense in
	# depth even though the catalog already rejects these at load time).
	var fail_closed: Array = [
		{"id": "e1", "requires": {"all_of": []}},
		{"id": "e2", "requires": {"any_of": []}},
		{"id": "e3", "requires": {}},
		{"id": "e4", "requires": {"all_of": ["eldergrove_reached"]}},
		{"id": "e5", "requires": {"bogus_group": [FACT]}},
		null, 42, "x", {}, {"id": "e6"},
		{"id": "e7", "requires": "x"},
	]
	for bad_def: Variant in fail_closed:
		if not _check(not ProgressionUnlockEvaluator.is_unlock_satisfied(bad_def, state), "Evaluator never grants an invalid/empty requirement definition: %s" % str(bad_def)):
			return false

	# Evaluation is a pure read: state is untouched by any evaluation above.
	if not _check(state.get_fact_ids() == [FACT] and state.fact_count() == 1, "Evaluation never mutates progression state"):
		return false
	if not _check(not ProgressionUnlockEvaluator.is_unlock_satisfied(catalog.get_definition("stone_age_era"), null), "Null state never unlocks"):
		return false

	print("PASS: Unlock Evaluation (all_of / any_of / Combined / Fail-Closed)")
	return true


# ---------------------------------------------------------------- Suite 5 ---
func _test_session_stone_age_integration() -> bool:
	var sess: ForgottenShoreSession = _fresh_session()
	var feedback: Array = []
	sess.feedback_message.connect(func(text: String) -> void: feedback.append(text))

	if not _check(sess.era_mgr.get_era_id() == "wood_age" and sess.progression.fact_count() == 0, "Fresh session starts Wood Age with no progression facts"):
		return false

	if not _check(sess.economy.set_balances_from_dict({"gold": 60, "wood": 60, "stone": 60}), "Test setup: economy funded"):
		return false

	# Build the east wall to COMPLETED, then upgrade to Stone Wall Tier 2 via
	# the real command path (the same path a player triggers).
	if not _check(sess.execute_command(&"build_wall", BuildingManager.WALL_POSITION_X), "Wooden Wall blueprint funded via command"):
		return false
	if not _check(sess.building_mgr.advance_construction(8.0, BuildingManager.WALL_ID), "Builder completes wall construction"):
		return false
	if not _check(sess.execute_command(&"upgrade_wall", BuildingManager.WALL_POSITION_X), "Stone Wall Tier 2 upgrade succeeds via command"):
		return false

	# 1) Stone Wall Tier 2 still unlocks Stone Age (behavior unchanged).
	if not _check(sess.era_mgr.get_era_id() == "stone_age", "Stone Wall Tier 2 unlocks Stone Age"):
		return false
	# 2) The milestone fact was recorded exactly once.
	if not _check(sess.progression.fact_count() == 1 and sess.progression.has_fact(FACT), "Stone Age fact recorded exactly once after successful upgrade"):
		return false
	# 3) Existing UI feedback keeps working.
	if not _check(feedback.size() > 0 and String(feedback[feedback.size() - 1]).contains("The Stone Age has begun!"), "Era feedback message intact after upgrade"):
		return false

	# Repeating the milestone notification must not duplicate progression:
	# era notification is idempotent and a second successful wall upgrade
	# (west wall) records nothing new.
	if not _check(not sess.era_mgr.notify_stone_wall_built(), "Repeated Stone Age milestone notification is idempotent"):
		return false
	if not _check(sess.progression.record_fact(FACT) and sess.progression.fact_count() == 1, "Re-recording the Stone Age fact is idempotent"):
		return false

	sess.building_mgr.register_forgotten_shore_expansion_plots()
	if not _check(sess.execute_command(&"build_wall", BuildingManager.WEST_WALL_POSITION_X, {"plot_id": BuildingManager.WEST_WALL_ID}), "West wall blueprint funded"):
		return false
	if not _check(sess.building_mgr.advance_construction(8.0, BuildingManager.WEST_WALL_ID), "Builder completes west wall"):
		return false
	if not _check(sess.execute_command(&"upgrade_wall", BuildingManager.WEST_WALL_POSITION_X, {"plot_id": BuildingManager.WEST_WALL_ID}), "West wall also upgraded to Stone Tier 2"):
		return false
	if not _check(sess.progression.fact_count() == 1, "Second stone wall upgrade does not duplicate the fact"):
		return false

	# Foundation query path: real catalog + evaluator against session facts.
	var catalog: ProgressionUnlockCatalog = ProgressionUnlockCatalog.new()
	if not _check(ProgressionUnlockEvaluator.is_unlock_satisfied(catalog.get_definition("stone_age_era"), sess.progression), "stone_age_era unlock evaluates satisfied for the session facts"):
		return false

	print("PASS: Session Stone Age Milestone Integration (Fact Recorded Once, Era Intact)")
	return true


# ---------------------------------------------------------------- Suite 6 ---
func _test_save_compat_and_migration() -> bool:
	var sm: SaveManager = SaveManager.new()

	# Build a session that reached Stone Age, then check the payload contract.
	var sess: ForgottenShoreSession = _fresh_session()
	if not _check(sess.economy.set_balances_from_dict({"gold": 60, "wood": 60, "stone": 60}), "Suite6 setup: economy funded"):
		return false
	if not _check(sess.execute_command(&"build_wall", BuildingManager.WALL_POSITION_X) and sess.building_mgr.advance_construction(8.0, BuildingManager.WALL_ID) and sess.execute_command(&"upgrade_wall", BuildingManager.WALL_POSITION_X), "Suite6 setup: Stone Wall Tier 2 milestone reached"):
		return false

	var payload: Dictionary = sess.build_save_payload()
	var pf: Dictionary = payload["progression_flags"] as Dictionary
	if not _check(int(payload["schema_version"]) == SaveManager.SCHEMA_VERSION and SaveManager.SCHEMA_VERSION == 2, "Save schema stays at version 2 (no bump needed for the optional facts field)"):
		return false
	if not _check(pf.get("progression_facts", []) == [FACT] and String(pf.get("era_id", "")) == "stone_age", "Payload carries progression facts and unchanged era_id behavior"):
		return false
	if not _check(sm.validate_payload(payload), "Payload with progression facts passes strict validation"):
		return false

	# Full save -> load -> restore round trip through the real SaveManager.
	if not _check(sess.save_game_state(SAVE_ROUNDTRIP_PATH), "save_game_state writes a valid save"):
		return false
	var loaded: Dictionary = sm.load_state(SAVE_ROUNDTRIP_PATH)
	if not _check(bool(loaded.get("ok", false)), "load_state reads the save back"):
		return false
	var sess2: ForgottenShoreSession = _fresh_session()
	if not _check(sess2._apply_loaded_payload(loaded["data"]), "Transactional payload apply accepts the loaded data"):
		return false
	if not _check(sess2.progression.has_fact(FACT) and sess2.progression.fact_count() == 1 and sess2.era_mgr.get_era_id() == "stone_age", "Round trip preserves progression facts and era_id"):
		return false

	# Old v2 save without progression_facts: deterministic, idempotent backfill
	# from the authoritative era (stone_age proves the milestone happened).
	var v2_old: Dictionary = sess.build_save_payload()
	(v2_old["progression_flags"] as Dictionary).erase("progression_facts")
	var migrated_once: Dictionary = SaveManager.migrate_payload(v2_old.duplicate(true)) as Dictionary
	var migrated_twice: Dictionary = SaveManager.migrate_payload(migrated_once.duplicate(true)) as Dictionary
	if not _check((migrated_once["progression_flags"] as Dictionary).get("progression_facts", []) == [FACT], "Old v2 stone_age save gets the milestone fact backfilled"):
		return false
	if not _check(migrated_once.hash() == migrated_twice.hash(), "Migration is idempotent (second pass changes nothing)"):
		return false
	if not _check(sm.validate_payload(migrated_once), "Backfilled payload passes validation"):
		return false

	# v1 save with a stone wall building: era inference then fact backfill.
	var ne_v1: Dictionary = sess.night_mgr.to_save_dict()
	ne_v1.erase("current_day_number")
	var v1_stone: Dictionary = {
		"schema_version": 1, "world_id": "aetherion", "island_id": "forgotten_shore",
		"day_count": 2, "world_time": 10.0, "world_phase": "night",
		"resources": {"gold": 2, "wood": 2, "stone": 1},
		"buildings": [{"id": "wall_east_01", "type": "stone_wall", "state": "COMPLETED", "durability": 260, "max_durability": 260}],
		"npcs": [{"id": "npc_01", "recruited": true, "role": "builder", "state": "IDLE", "position_x": 0.0}],
		"night_encounter": ne_v1,
		"progression_flags": {"first_night_survived": false},
	}
	var v1_migrated: Dictionary = SaveManager.migrate_payload(v1_stone) as Dictionary
	var v1_pf: Dictionary = v1_migrated["progression_flags"] as Dictionary
	if not _check(String(v1_pf.get("era_id", "")) == "stone_age" and v1_pf.get("progression_facts", []) == [FACT] and int(v1_migrated["schema_version"]) == 2, "v1 save with stone wall migrates era and backfills the fact"):
		return false

	# v1 save without stone wall: Wood Age, and no fact is invented.
	var v1_wood: Dictionary = v1_stone.duplicate(true)
	(v1_wood["buildings"] as Array)[0] = {"id": "wall_east_01", "type": "wooden_wall", "state": "COMPLETED", "durability": 150, "max_durability": 150}
	var v1w_migrated: Dictionary = SaveManager.migrate_payload(v1_wood) as Dictionary
	var v1w_pf: Dictionary = v1w_migrated["progression_flags"] as Dictionary
	if not _check(String(v1w_pf.get("era_id", "")) == "wood_age" and not v1w_pf.has("progression_facts"), "v1 save without stone wall infers Wood Age and invents no facts"):
		return false
	if not _check(sm.validate_payload(v1w_migrated), "Wood-era migrated payload loads cleanly (old saves without facts load correctly)"):
		return false

	# Iron Age save (vessel-ready path can skip the stone wall): no inference.
	var v2_iron: Dictionary = v2_old.duplicate(true)
	var iron_pf: Dictionary = v2_iron["progression_flags"] as Dictionary
	iron_pf["era_id"] = "iron_age"
	iron_pf["shipwreck_stage"] = 3
	var iron_migrated: Dictionary = SaveManager.migrate_payload(v2_iron) as Dictionary
	if not _check(not (iron_migrated["progression_flags"] as Dictionary).has("progression_facts"), "Iron Age save never infers the stone wall fact (vessel path may have skipped it)"):
		return false

	# Malformed progression_facts: migration must not repair it; the save must
	# be rejected (never partially applied to live state).
	var bad_payload: Dictionary = sess.build_save_payload()
	(bad_payload["progression_flags"] as Dictionary)["progression_facts"] = ["BAD ID"]
	if not _check(not sm.validate_payload(SaveManager.migrate_payload(bad_payload)), "Malformed progression_facts payload is rejected, not repaired"):
		return false
	var bf: FileAccess = FileAccess.open(SAVE_MALFORMED_FACTS_PATH, FileAccess.WRITE)
	bf.store_string(JSON.stringify(SaveManager.migrate_payload(bad_payload)))
	bf.close()
	if not _check(not bool(sm.load_state(SAVE_MALFORMED_FACTS_PATH).get("ok", false)), "Save file with malformed progression_facts fails to load safely"):
		return false

	print("PASS: Save Compatibility, Migration Backfill & Transactional Rejection")
	return true


func _init() -> void:
	var suite_names: Array[String] = [
		"Fact Recording/Validation", "Serialization/Restore", "Definition Validation",
		"Unlock Evaluation", "Stone Age Session Integration", "Save Compat/Migration",
	]
	var suites: Array[Callable] = [
		_test_fact_recording_basics, _test_fact_serialization_roundtrip,
		_test_definition_validation, _test_unlock_evaluation,
		_test_session_stone_age_integration, _test_save_compat_and_migration,
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
	print("PASS: All %d Progression Foundation Checks (Phase 1) completed with 0 failures across %d suites." % [_checks, suites.size()])
	quit(0)
