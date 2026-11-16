extends SceneTree

## Phase 2 Era Progression Correction test suite. Follows the repo test
## conventions: fail-fast _check helper, tab indentation, no raw engine assert
## calls, and no scene-tree child injection. Covers the corrected era semantics
## (Shipwreck Stage 3 = voyage readiness only; Iron Age requires the Eldergrove
## milestone), the conservative legacy iron_age save migration policy, save
## round-trips, unlock-definition data contracts, and regression coverage for
## wall upgrade / shipwreck / economy behavior, plus strict malformed
## progression_facts field rejection (absent field vs explicitly present null).
## Phase 2.2 additionally proves that a present-but-malformed value skips the
## whole progression migration section (no era inference/correction, no
## backfills, no canonicalization) and is rejected wholesale, while the
## genuinely-absent field and valid-array paths keep their existing behavior.

const FACT: String = "forgotten_shore_first_stone_wall_tier_2"
const VESSEL_FACT: String = "forgotten_shore_vessel_ready"
const ELDERGROVE_FACT: String = "eldergrove_reached"

const SAVE_LEGACY_IRON_WALL: String = "user://test_phase2_legacy_iron_wall.json"
const SAVE_MALFORMED_IRON: String = "user://test_phase2_malformed_iron.json"
const SAVE_MALFORMED_NULL_FACTS: String = "user://test_phase2_malformed_null_facts.json"
const SAVE_MALFORMED_NULL_IRON: String = "user://test_phase2_malformed_null_iron.json"
const SAVE_ROUNDTRIP_PATH: String = "user://test_phase2_roundtrip.json"
const SAVE_IRON_ROUNDTRIP_PATH: String = "user://test_phase2_iron_roundtrip.json"

var _failures: int = 0
var _checks: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE [test_progression_phase2]: " + msg)
		quit(1)
		return false
	return true


func _fresh_session() -> ForgottenShoreSession:
	var session_script: GDScript = load("res://scripts/world/ForgottenShoreSession.gd")
	return session_script.new() as ForgottenShoreSession


func _fund(sess: ForgottenShoreSession, gold: int, wood: int, stone: int) -> bool:
	return sess.economy.set_balances_from_dict({"gold": gold, "wood": wood, "stone": stone})


## Drives the real player command path: build the east wall, complete it, and
## upgrade it to Stone Wall Tier 2 (the Stone Age milestone).
func _reach_stone_age(sess: ForgottenShoreSession) -> bool:
	if not sess.execute_command(&"build_wall", BuildingManager.WALL_POSITION_X):
		return false
	if not sess.building_mgr.advance_construction(8.0, BuildingManager.WALL_ID):
		return false
	return sess.execute_command(&"upgrade_wall", BuildingManager.WALL_POSITION_X)


## Drives the real player command path for one Shipwreck repair stage.
func _repair_ship_stage(sess: ForgottenShoreSession) -> bool:
	return sess.execute_command(&"shipwreck", ForgottenShoreSession.SHIPWRECK_X)


# ---------------------------------------------------------------- Suite 1 ---
func _test_fresh_start_and_stone_age_path() -> bool:
	var sess: ForgottenShoreSession = _fresh_session()
	var feedback: Array = []
	sess.feedback_message.connect(func(text: String) -> void: feedback.append(text))

	# 1) New games start in Wood Age with an empty fact set.
	if not _check(sess.era_mgr.get_era_id() == "wood_age" and sess.progression.fact_count() == 0, "New game starts in Wood Age with no progression facts"):
		return false

	var catalog: ProgressionUnlockCatalog = ProgressionUnlockCatalog.new()
	if not _check(not catalog.is_empty() and catalog.get_definition_ids() == ["forgotten_shore_voyage_ready", "iron_age_era", "stone_age_era"], "Unlock catalog loads exactly the three Phase 2 definitions (stable IDs, no duplicates)"):
		return false
	if not _check(not ProgressionUnlockEvaluator.is_unlock_satisfied(catalog.get_definition("iron_age_era"), sess.progression), "iron_age_era unlock is locked for a fresh game"):
		return false

	# 2) First successful Stone Wall Tier 2 upgrade unlocks Stone Age.
	if not _check(_fund(sess, 60, 60, 60), "Suite1 setup: economy funded"):
		return false
	if not _check(sess.execute_command(&"build_wall", BuildingManager.WALL_POSITION_X), "Wall blueprint funded via real command path"):
		return false
	if not _check(sess.building_mgr.advance_construction(8.0, BuildingManager.WALL_ID), "Builder completes wall construction"):
		return false
	var before_gold: int = sess.economy.get_amount(&"gold")
	var before_wood: int = sess.economy.get_amount(&"wood")
	var before_stone: int = sess.economy.get_amount(&"stone")
	var upg_cost: Dictionary = sess.building_mgr.get_plot_upgrade_cost(BuildingManager.WALL_ID)
	if not _check(sess.execute_command(&"upgrade_wall", BuildingManager.WALL_POSITION_X), "Stone Wall Tier 2 upgrade succeeds via real command path"):
		return false

	if not _check(sess.era_mgr.get_era_id() == "stone_age", "First successful Stone Wall Tier 2 upgrade unlocks Stone Age"):
		return false
	if not _check(sess.progression.fact_count() == 1 and sess.progression.has_fact(FACT), "Stone Age milestone fact recorded exactly once"):
		return false
	if not _check(String(feedback[feedback.size() - 1]).contains("The Stone Age has begun!"), "Existing Stone Age feedback message unchanged"):
		return false

	# Regression guard: the upgrade transaction still charges exactly the
	# configured data-driven upgrade cost (no balance drift).
	if not _check(sess.economy.get_amount(&"gold") == before_gold - int(upg_cost.get("gold", 0)) and sess.economy.get_amount(&"wood") == before_wood - int(upg_cost.get("wood", 0)) and sess.economy.get_amount(&"stone") == before_stone - int(upg_cost.get("stone", 0)), "Wall upgrade still charges exactly the configured cost"):
		return false

	# 3) A failed wall upgrade records nothing.
	var poor: ForgottenShoreSession = _fresh_session()
	if not _check(_fund(poor, 4, 6, 3), "Suite1 setup: poor economy funded (enough to build, not to upgrade)"):
		return false
	if not _check(poor.execute_command(&"build_wall", BuildingManager.WALL_POSITION_X), "Poor session builds the wall"):
		return false
	if not _check(poor.building_mgr.advance_construction(8.0, BuildingManager.WALL_ID), "Poor session completes wall construction"):
		return false
	if not _check(not poor.execute_command(&"upgrade_wall", BuildingManager.WALL_POSITION_X), "Underfunded Stone Wall Tier 2 upgrade is rejected"):
		return false
	if not _check(poor.era_mgr.get_era_id() == "wood_age" and poor.progression.fact_count() == 0, "Failed wall upgrade records no milestone and unlocks no era"):
		return false

	# 4) Repeated milestone notifications stay idempotent (west wall + direct re-record).
	if not _check(not sess.era_mgr.notify_stone_wall_built(), "Repeated Stone Age era notification is idempotent"):
		return false
	if not _check(sess.progression.record_fact(FACT) and sess.progression.fact_count() == 1, "Re-recording the Stone Age fact is idempotent"):
		return false
	sess.building_mgr.register_forgotten_shore_expansion_plots()
	if not _check(sess.execute_command(&"build_wall", BuildingManager.WEST_WALL_POSITION_X, {"plot_id": BuildingManager.WEST_WALL_ID}), "West wall blueprint funded"):
		return false
	if not _check(sess.building_mgr.advance_construction(8.0, BuildingManager.WEST_WALL_ID), "Builder completes west wall"):
		return false
	if not _check(sess.execute_command(&"upgrade_wall", BuildingManager.WEST_WALL_POSITION_X, {"plot_id": BuildingManager.WEST_WALL_ID}), "West wall upgraded to Stone Tier 2"):
		return false
	if not _check(sess.progression.fact_count() == 1 and sess.era_mgr.get_era_id() == "stone_age", "Second stone wall upgrade does not duplicate the fact or change the era"):
		return false

	print("PASS: Phase 2 Fresh Start, Stone Age Path & Upgrade Transaction Regression")
	return true


# ---------------------------------------------------------------- Suite 2 ---
func _test_shipwreck_vessel_readiness_and_era_lock() -> bool:
	var sess: ForgottenShoreSession = _fresh_session()
	var feedback: Array = []
	sess.feedback_message.connect(func(text: String) -> void: feedback.append(text))
	if not _check(_fund(sess, 60, 60, 60), "Suite2 setup: economy funded"):
		return false

	# 5) Shipwreck Stage 3 records vessel readiness through the real command path.
	if not _check(_repair_ship_stage(sess), "Shipwreck Stage 1 repair succeeds"):
		return false
	if not _check(sess.shipwreck_stage == 1 and sess.progression.fact_count() == 0, "Stage 1 records no progression fact yet"):
		return false
	if not _check(_repair_ship_stage(sess), "Shipwreck Stage 2 repair succeeds"):
		return false
	if not _check(sess.shipwreck_stage == 2 and sess.progression.fact_count() == 0, "Stage 2 records no progression fact yet"):
		return false
	if not _check(_repair_ship_stage(sess), "Shipwreck Stage 3 repair succeeds"):
		return false
	if not _check(sess.shipwreck_stage == 3 and sess.progression.fact_count() == 1 and sess.progression.has_fact(VESSEL_FACT), "Shipwreck Stage 3 records the vessel readiness fact exactly once"):
		return false
	if not _check(String(feedback[feedback.size() - 1]).contains("vessel is ready"), "Stage 3 feedback announces voyage readiness (no Iron Age message)"):
		return false
	for msg: String in feedback:
		if not _check(not msg.contains("Iron Age"), "No gameplay message claims Shipwreck unlocks Iron Age"):
			return false

	# Regression guard: the three repair transactions still cost exactly 6G 8W 4S.
	if not _check(sess.economy.get_amount(&"gold") == 54 and sess.economy.get_amount(&"wood") == 52 and sess.economy.get_amount(&"stone") == 56, "Shipwreck stages still cost exactly 6G 8W 4S in total"):
		return false

	# 6) Shipwreck Stage 3 does NOT unlock Iron Age.
	if not _check(sess.era_mgr.get_era_id() == "wood_age", "Era stays Wood Age after Shipwreck Stage 3 (no Iron Age from the vessel)"):
		return false
	var catalog: ProgressionUnlockCatalog = ProgressionUnlockCatalog.new()
	if not _check(not ProgressionUnlockEvaluator.is_unlock_satisfied(catalog.get_definition("iron_age_era"), sess.progression), "iron_age_era unlock remains locked with only the vessel fact"):
		return false
	if not _check(ProgressionUnlockEvaluator.is_unlock_satisfied(catalog.get_definition("forgotten_shore_voyage_ready"), sess.progression), "forgotten_shore_voyage_ready unlock is satisfied by the vessel fact"):
		return false

	# 7) Repeated vessel readiness notifications stay idempotent: the repeat
	#    interaction takes the existing ISLAND_CLEARED path and duplicates nothing.
	var era_changes: Array = []
	sess.era_mgr.era_changed.connect(func(eid: String, ename: String) -> void: era_changes.append(eid))
	if not _check(_repair_ship_stage(sess), "Repeated Stage 3 interaction still succeeds (Set Sail path)"):
		return false
	if not _check(sess.reign_state == ForgottenShoreSession.ReignState.ISLAND_CLEARED, "Repeated Stage 3 interaction keeps the existing ISLAND_CLEARED behavior"):
		return false
	if not _check(sess.progression.fact_count() == 1 and era_changes.is_empty(), "Repeated vessel readiness duplicates neither facts nor era changes"):
		return false

	# 5b) A failed Stage 3 repair (insufficient funds) records nothing.
	var poor: ForgottenShoreSession = _fresh_session()
	if not _check(_fund(poor, 4, 6, 3), "Suite2 setup: poor economy funded (covers stages 1-2 only)"):
		return false
	if not _check(_repair_ship_stage(poor) and _repair_ship_stage(poor), "Poor session completes Shipwreck stages 1-2"):
		return false
	if not _check(not _repair_ship_stage(poor), "Underfunded Stage 3 repair is rejected"):
		return false
	if not _check(poor.shipwreck_stage == 2 and poor.progression.fact_count() == 0 and poor.era_mgr.get_era_id() == "wood_age", "Failed Stage 3 repair records no vessel fact and changes no era"):
		return false

	print("PASS: Phase 2 Shipwreck Vessel Readiness & Iron Age Lock")
	return true


# ---------------------------------------------------------------- Suite 3 ---
func _test_iron_age_requires_eldergrove_milestone() -> bool:
	# 8) Without the Eldergrove milestone, Iron Age stays locked everywhere.
	var prog: ProgressionState = ProgressionState.new()
	if not _check(prog.record_fact(FACT) and prog.record_fact(VESSEL_FACT), "Suite3 setup: stone + vessel facts recorded"):
		return false
	var catalog: ProgressionUnlockCatalog = ProgressionUnlockCatalog.new()
	if not _check(not ProgressionUnlockEvaluator.is_unlock_satisfied(catalog.get_definition("iron_age_era"), prog), "iron_age_era stays locked even with stone + vessel facts"):
		return false

	var era: EraProgressionManager = EraProgressionManager.new()
	if not _check(not era.notify_eldergrove_milestone(null), "notify_eldergrove_milestone(null) is fail-closed"):
		return false
	if not _check(not era.notify_eldergrove_milestone(prog), "notify_eldergrove_milestone without the Eldergrove fact is fail-closed"):
		return false
	if not _check(era.get_era_id() == "wood_age", "Era never advances to Iron Age without the Eldergrove fact"):
		return false

	# 9) A valid Eldergrove milestone unlocks Iron Age through the intended path:
	#    the future Eldergrove session records the durable fact, then requests the
	#    era advance; both the era manager and the data-driven evaluator agree.
	if not _check(prog.record_fact(ELDERGROVE_FACT), "Eldergrove milestone fact recorded (future integration contract)"):
		return false
	var era_changes: Array = []
	era.era_changed.connect(func(eid: String, ename: String) -> void: era_changes.append(eid))
	if not _check(era.notify_eldergrove_milestone(prog), "notify_eldergrove_milestone advances the era with the fact present"):
		return false
	if not _check(era.get_era_id() == "iron_age" and era_changes == ["iron_age"], "Era reaches Iron Age exactly once via the Eldergrove gate"):
		return false
	if not _check(ProgressionUnlockEvaluator.is_unlock_satisfied(catalog.get_definition("iron_age_era"), prog), "iron_age_era unlock is satisfied by the Eldergrove fact"):
		return false
	if not _check(not era.notify_eldergrove_milestone(prog), "Repeated Eldergrove notification is idempotent (era unchanged)"):
		return false
	if not _check(era.get_era_id() == "iron_age", "Era stays Iron Age after the repeated notification"):
		return false

	# End-to-end on a real session: wall + shipwreck path, then the Eldergrove
	# gate; the resulting iron_age payload must validate and round-trip.
	var sess: ForgottenShoreSession = _fresh_session()
	if not _check(_fund(sess, 60, 60, 60), "Suite3 setup: session economy funded"):
		return false
	if not _check(_reach_stone_age(sess), "Session reaches Stone Age"):
		return false
	if not _check(_repair_ship_stage(sess) and _repair_ship_stage(sess) and _repair_ship_stage(sess), "Session completes Shipwreck Stage 3"):
		return false
	if not _check(sess.era_mgr.get_era_id() == "stone_age" and sess.progression.fact_count() == 2, "Session stays Stone Age with stone + vessel facts before the Eldergrove gate"):
		return false
	if not _check(sess.progression.record_fact(ELDERGROVE_FACT) and sess.era_mgr.notify_eldergrove_milestone(sess.progression), "Session Eldergrove gate records the fact and advances the era"):
		return false
	if not _check(sess.era_mgr.get_era_id() == "iron_age", "Session era reaches Iron Age only through the Eldergrove gate"):
		return false

	var sm: SaveManager = SaveManager.new()
	var payload: Dictionary = sess.build_save_payload()
	var pf: Dictionary = payload["progression_flags"] as Dictionary
	if not _check(String(pf.get("era_id", "")) == "iron_age" and pf.get("progression_facts", []) == [ELDERGROVE_FACT, FACT, VESSEL_FACT], "Iron Age payload carries era_id and all three sorted facts"):
		return false
	if not _check(sm.validate_payload(payload), "Iron Age payload passes strict validation"):
		return false
	if not _check(sess.save_game_state(SAVE_IRON_ROUNDTRIP_PATH), "Iron Age session saves successfully"):
		return false
	var loaded: Dictionary = sm.load_state(SAVE_IRON_ROUNDTRIP_PATH)
	if not _check(bool(loaded.get("ok", false)), "Iron Age save loads back"):
		return false
	var sess2: ForgottenShoreSession = _fresh_session()
	if not _check(sess2._apply_loaded_payload(loaded["data"]), "Iron Age payload applies transactionally to a fresh session"):
		return false
	if not _check(sess2.era_mgr.get_era_id() == "iron_age" and sess2.progression.fact_count() == 3 and sess2.progression.has_fact(ELDERGROVE_FACT), "Round trip preserves the Iron Age era and the Eldergrove evidence"):
		return false

	print("PASS: Phase 2 Iron Age Eldergrove Gate (Fail-Closed + Intended Path Round-Trip)")
	return true


# ---------------------------------------------------------------- Suite 4 ---
func _legacy_payload(building_type: String, era_id: String, stage: int, facts: Variant, reign_state: String) -> Dictionary:
	var sess: ForgottenShoreSession = _fresh_session()
	var b_dict: Dictionary = {"id": "wall_east_01", "type": building_type, "state": "COMPLETED", "durability": 260, "max_durability": 260, "progress": 1.0}
	if building_type == "wooden_wall":
		b_dict["level"] = 1
		b_dict["durability"] = 150
	else:
		b_dict["level"] = 2
	var pf: Dictionary = {"first_night_survived": true, "hearth_level": 2, "shipwreck_stage": stage, "portal_relic_looted": false, "reign_state": reign_state, "era_id": era_id}
	if facts != null:
		pf["progression_facts"] = facts
	return {
		"schema_version": 2, "world_id": "aetherion", "island_id": "forgotten_shore",
		"day_count": 3, "world_time": 12.0, "world_phase": "daylight",
		"player": {"position_x": -1350.0, "facing_direction": -1},
		"resources": {"gold": 5, "wood": 4, "stone": 2},
		"buildings": [b_dict],
		"npcs": [{"id": "npc_01", "recruited": true, "role": "builder", "state": "IDLE", "position_x": 0.0}],
		"night_encounter": sess.night_mgr.to_save_dict(),
		"progression_flags": pf,
	}


## Builds a legacy payload whose progression_facts field is EXPLICITLY present
## with the given (possibly malformed) value — distinct from the field being
## absent, which _legacy_payload(..., null, ...) expresses.
func _legacy_payload_with_explicit_facts(building_type: String, era_id: String, stage: int, explicit_facts: Variant, reign_state: String) -> Dictionary:
	var payload: Dictionary = _legacy_payload(building_type, era_id, stage, null, reign_state)
	(payload["progression_flags"] as Dictionary)["progression_facts"] = explicit_facts
	return payload


func _test_legacy_migration_policy() -> bool:
	var sm: SaveManager = SaveManager.new()

	# 10) Legacy Wood Age saves still load correctly and gain no facts.
	var wood_mig: Dictionary = SaveManager.migrate_payload(_legacy_payload("wooden_wall", "wood_age", 0, null, "ACTIVE")) as Dictionary
	var wood_pf: Dictionary = wood_mig["progression_flags"] as Dictionary
	if not _check(String(wood_pf.get("era_id", "")) == "wood_age" and not wood_pf.has("progression_facts") and sm.validate_payload(wood_mig), "Legacy Wood Age save loads with unchanged era and no invented facts"):
		return false

	# 11) Legacy Stone Age saves still load correctly (Phase 1 backfill intact).
	var stone_mig: Dictionary = SaveManager.migrate_payload(_legacy_payload("stone_wall", "stone_age", 0, null, "ACTIVE")) as Dictionary
	var stone_pf: Dictionary = stone_mig["progression_flags"] as Dictionary
	if not _check(String(stone_pf.get("era_id", "")) == "stone_age" and stone_pf.get("progression_facts", []) == [FACT] and sm.validate_payload(stone_mig), "Legacy Stone Age save keeps its era and gains exactly the stone fact"):
		return false

	# 12a) Legacy iron_age + stage 3 + real stone wall: conservative downgrade to
	#      stone_age; vessel fact preserved from stage 3; stone fact backfilled;
	#      no Eldergrove fact fabricated.
	var iron_wall: Dictionary = _legacy_payload("stone_wall", "iron_age", 3, null, "ISLAND_CLEARED")
	var iron_wall_mig: Dictionary = SaveManager.migrate_payload(iron_wall.duplicate(true)) as Dictionary
	var iron_wall_pf: Dictionary = iron_wall_mig["progression_flags"] as Dictionary
	if not _check(String(iron_wall_pf.get("era_id", "")) == "stone_age", "Legacy iron_age save with stone-wall evidence is downgraded to stone_age"):
		return false
	if not _check(iron_wall_pf.get("progression_facts", []) == [FACT, VESSEL_FACT], "Downgraded save keeps stone progress, gains vessel fact from shipwreck_stage 3, and fabricates no Eldergrove fact"):
		return false
	if not _check(int(iron_wall_pf.get("shipwreck_stage", 0)) == 3 and String(iron_wall_pf.get("reign_state", "")) == "ISLAND_CLEARED", "Shipwreck stage and reign state are preserved untouched by the migration"):
		return false
	if not _check(sm.validate_payload(iron_wall_mig), "Downgraded iron_age payload passes strict validation"):
		return false

	# Full pipeline: raw legacy file -> load_state (migrate + validate) -> apply.
	var fw: FileAccess = FileAccess.open(SAVE_LEGACY_IRON_WALL, FileAccess.WRITE)
	fw.store_string(JSON.stringify(iron_wall))
	fw.close()
	var loaded: Dictionary = sm.load_state(SAVE_LEGACY_IRON_WALL)
	if not _check(bool(loaded.get("ok", false)), "Raw legacy iron_age save loads through the real SaveManager pipeline"):
		return false
	var restored: ForgottenShoreSession = _fresh_session()
	if not _check(restored._apply_loaded_payload(loaded["data"]), "Migrated legacy payload applies transactionally to a fresh session"):
		return false
	if not _check(restored.era_mgr.get_era_id() == "stone_age" and restored.progression.fact_count() == 2 and restored.progression.has_fact(FACT) and restored.progression.has_fact(VESSEL_FACT) and not restored.progression.has_fact(ELDERGROVE_FACT), "Restored session is Stone Age with stone + vessel facts and no Eldergrove claim"):
		return false

	# 12b) Legacy iron_age + stage 3 + NO stone wall: downgrade to wood_age,
	#      vessel fact preserved from stage 3, no stone fact invented.
	var iron_nostone_mig: Dictionary = SaveManager.migrate_payload(_legacy_payload("wooden_wall", "iron_age", 3, null, "ISLAND_CLEARED")) as Dictionary
	var iron_nostone_pf: Dictionary = iron_nostone_mig["progression_flags"] as Dictionary
	if not _check(String(iron_nostone_pf.get("era_id", "")) == "wood_age" and iron_nostone_pf.get("progression_facts", []) == [VESSEL_FACT], "Legacy iron_age save without stone-wall evidence downgrades to wood_age keeping only vessel readiness"):
		return false
	if not _check(sm.validate_payload(iron_nostone_mig), "Wood-downgraded iron_age payload passes strict validation"):
		return false

	# 12c) Legacy iron_age + stage 0: no vessel evidence, nothing is invented.
	var iron_idle_mig: Dictionary = SaveManager.migrate_payload(_legacy_payload("wooden_wall", "iron_age", 0, null, "ACTIVE")) as Dictionary
	var iron_idle_pf: Dictionary = iron_idle_mig["progression_flags"] as Dictionary
	if not _check(String(iron_idle_pf.get("era_id", "")) == "wood_age" and not iron_idle_pf.has("progression_facts"), "Legacy iron_age save without shipwreck evidence downgrades to wood_age with no fabricated facts"):
		return false

	# 12d) New-format iron_age save WITH the Eldergrove fact: evidence is real,
	#      Iron Age is preserved as-is (deterministic and non-destructive).
	var new_iron: Dictionary = _legacy_payload("stone_wall", "iron_age", 3, [ELDERGROVE_FACT, FACT, VESSEL_FACT], "ISLAND_CLEARED")
	var new_iron_mig: Dictionary = SaveManager.migrate_payload(new_iron.duplicate(true)) as Dictionary
	var new_iron_pf: Dictionary = new_iron_mig["progression_flags"] as Dictionary
	if not _check(String(new_iron_pf.get("era_id", "")) == "iron_age" and new_iron_pf.get("progression_facts", []) == [ELDERGROVE_FACT, FACT, VESSEL_FACT], "Save carrying the Eldergrove fact keeps Iron Age and all facts unchanged"):
		return false
	if not _check(sm.validate_payload(new_iron_mig), "New-format Iron Age payload passes strict validation"):
		return false

	# 13) Migration is deterministic and idempotent for every policy branch.
	for fixture: Dictionary in [iron_wall, new_iron, _legacy_payload("wooden_wall", "iron_age", 0, null, "ACTIVE"), _legacy_payload("stone_wall", "stone_age", 0, null, "ACTIVE")]:
		var once: Dictionary = SaveManager.migrate_payload(fixture.duplicate(true)) as Dictionary
		var twice: Dictionary = SaveManager.migrate_payload(once.duplicate(true)) as Dictionary
		var again: Dictionary = SaveManager.migrate_payload(fixture.duplicate(true)) as Dictionary
		if not _check(once.hash() == twice.hash() and once.hash() == again.hash(), "Migration is deterministic and idempotent (double pass changes nothing)"):
			return false

	# 14) Invalid or malformed progression facts are handled safely: never
	#     repaired, never partially applied.
	var bad_id: Dictionary = _legacy_payload("stone_wall", "iron_age", 3, ["BAD ID"], "ISLAND_CLEARED")
	var bad_id_mig: Dictionary = SaveManager.migrate_payload(bad_id) as Dictionary
	if not _check(not sm.validate_payload(bad_id_mig), "Malformed fact array is rejected, not repaired"):
		return false
	var fbad: FileAccess = FileAccess.open(SAVE_MALFORMED_IRON, FileAccess.WRITE)
	fbad.store_string(JSON.stringify(bad_id))
	fbad.close()
	if not _check(not bool(sm.load_state(SAVE_MALFORMED_IRON).get("ok", false)), "Save file with malformed facts fails to load safely"):
		return false

	var unknown_id: Dictionary = _legacy_payload("stone_wall", "iron_age", 3, ["mount_tamed"], "ACTIVE")
	if not _check(not sm.validate_payload(SaveManager.migrate_payload(unknown_id)), "Well-formed but unknown fact id is rejected from save data"):
		return false

	var non_array: Dictionary = _legacy_payload("stone_wall", "iron_age", 3, "not_an_array", "ACTIVE")
	if not _check(not sm.validate_payload(SaveManager.migrate_payload(non_array)), "Non-array progression_facts value is rejected"):
		return false

	# Eldergrove claim inside an otherwise invalid array: since Phase 2.2 the
	# whole progression migration is skipped for a present-but-invalid fact
	# array, so era_id is NOT corrected, the malformed array is left untouched
	# (no vessel backfill despite Stage 3), and the payload is still rejected
	# wholesale (no partial grant, no partial migration mutation).
	var mixed: Dictionary = _legacy_payload("stone_wall", "iron_age", 3, [ELDERGROVE_FACT, "BAD ID"], "ACTIVE")
	var mixed_mig: Dictionary = SaveManager.migrate_payload(mixed) as Dictionary
	var mixed_pf: Dictionary = mixed_mig["progression_flags"] as Dictionary
	if not _check(String(mixed_pf.get("era_id", "")) == "iron_age" and mixed_pf.get("progression_facts", []) == [ELDERGROVE_FACT, "BAD ID"] and not sm.validate_payload(mixed_mig), "Invalid fact array never counts as Eldergrove evidence; era stays untouched and payload is rejected wholesale"):
		return false

	print("PASS: Phase 2 Conservative Legacy iron_age Migration (Deterministic, Idempotent, Fail-Safe)")
	return true


# ---------------------------------------------------------------- Suite 5 ---
func _test_save_roundtrip_preserves_facts_and_era() -> bool:
	var sm: SaveManager = SaveManager.new()
	var sess: ForgottenShoreSession = _fresh_session()
	if not _check(_fund(sess, 60, 60, 60), "Suite5 setup: economy funded"):
		return false
	if not _check(_reach_stone_age(sess), "Suite5 setup: Stone Age milestone reached"):
		return false
	if not _check(_repair_ship_stage(sess) and _repair_ship_stage(sess) and _repair_ship_stage(sess), "Suite5 setup: Shipwreck Stage 3 completed"):
		return false

	# 15) Save/load round trip preserves all valid facts and era_id behavior.
	if not _check(sess.progression.fact_count() == 2 and sess.era_mgr.get_era_id() == "stone_age", "Session holds exactly stone + vessel facts in Stone Age"):
		return false
	if not _check(sess.save_game_state(SAVE_ROUNDTRIP_PATH), "save_game_state writes a valid save"):
		return false
	var loaded: Dictionary = sm.load_state(SAVE_ROUNDTRIP_PATH)
	if not _check(bool(loaded.get("ok", false)), "load_state reads the save back"):
		return false
	var data_pf: Dictionary = (loaded["data"] as Dictionary)["progression_flags"] as Dictionary
	if not _check(data_pf.get("progression_facts", []) == [FACT, VESSEL_FACT] and String(data_pf.get("era_id", "")) == "stone_age" and int(data_pf.get("shipwreck_stage", 0)) == 3, "Loaded payload preserves facts, era_id and shipwreck stage"):
		return false
	var sess2: ForgottenShoreSession = _fresh_session()
	if not _check(sess2._apply_loaded_payload(loaded["data"]), "Round-trip payload applies transactionally"):
		return false
	if not _check(sess2.progression.fact_count() == 2 and sess2.era_mgr.get_era_id() == "stone_age" and sess2.shipwreck_stage == 3, "Round trip preserves all valid progression facts and the era"):
		return false
	var catalog: ProgressionUnlockCatalog = ProgressionUnlockCatalog.new()
	if not _check(ProgressionUnlockEvaluator.is_unlock_satisfied(catalog.get_definition("stone_age_era"), sess2.progression) and ProgressionUnlockEvaluator.is_unlock_satisfied(catalog.get_definition("forgotten_shore_voyage_ready"), sess2.progression) and not ProgressionUnlockEvaluator.is_unlock_satisfied(catalog.get_definition("iron_age_era"), sess2.progression), "Restored facts evaluate to Stone Age + voyage ready, Iron Age still locked"):
		return false

	print("PASS: Phase 2 Save/Load Round-Trip Preservation (facts + era_id)")
	return true


# ---------------------------------------------------------------- Suite 6 ---
func _test_gameplay_regression_guards() -> bool:
	# Shipwreck costs and the Set Sail win-condition behavior are untouched.
	var total: Dictionary = {"gold": 0, "wood": 0, "stone": 0}
	for cost: Dictionary in ForgottenShoreSession.SHIPWRECK_COSTS:
		for key: String in total.keys():
			total[key] += int(cost.get(key, 0))
	if not _check(total["gold"] == 6 and total["wood"] == 8 and total["stone"] == 4, "Shipwreck total cost unchanged (6G 8W 4S)"):
		return false

	# Stone Age era definition data contract is unchanged (still the stone fact).
	var catalog: ProgressionUnlockCatalog = ProgressionUnlockCatalog.new()
	if not _check(not catalog.is_empty(), "Suite6 setup: unlock catalog loads"):
		return false
	var stone_def: Dictionary = catalog.get_definition("stone_age_era")
	if not _check((stone_def.get("requires", {}) as Dictionary).get("all_of", []) == [FACT], "stone_age_era definition still requires exactly the stone-wall fact"):
		return false
	var iron_def: Dictionary = catalog.get_definition("iron_age_era")
	if not _check((iron_def.get("requires", {}) as Dictionary).get("all_of", []) == [ELDERGROVE_FACT], "iron_age_era definition requires exactly the Eldergrove fact"):
		return false
	var voyage_def: Dictionary = catalog.get_definition("forgotten_shore_voyage_ready")
	if not _check((voyage_def.get("requires", {}) as Dictionary).get("all_of", []) == [VESSEL_FACT], "voyage definition requires exactly the vessel fact"):
		return false

	# Era manager data contract is unchanged for non-Iron eras.
	var era: EraProgressionManager = EraProgressionManager.new()
	if not _check(era.get_era_id() == "wood_age" and era.notify_stone_wall_built() and era.get_era_id() == "stone_age", "Wood -> Stone era advancement via wall milestone unchanged"):
		return false
	if not _check(era.apply_save_era("iron_age") and era.to_save_id() == "iron_age", "apply_save_era still restores a valid iron_age era id (save-format behavior)"):
		return false

	print("PASS: Phase 2 Gameplay & Data Contract Regression Guards")
	return true


# ---------------------------------------------------------------- Suite 7 ---
func _test_strict_malformed_facts_field_rejection() -> bool:
	var sm: SaveManager = SaveManager.new()

	# Case A: a legacy save with NO progression_facts field is a legitimate
	# legacy condition — deterministic migration/backfill must keep working.
	var absent_stage3: Dictionary = _legacy_payload("wooden_wall", "wood_age", 3, null, "ACTIVE")
	if not _check(not (absent_stage3["progression_flags"] as Dictionary).has("progression_facts"), "Case A fixture sanity: fact field is genuinely absent"):
		return false
	var absent_mig: Dictionary = SaveManager.migrate_payload(absent_stage3.duplicate(true)) as Dictionary
	var absent_pf: Dictionary = absent_mig["progression_flags"] as Dictionary
	if not _check(absent_pf.get("progression_facts", []) == [VESSEL_FACT] and sm.validate_payload(absent_mig), "Missing fact field plus shipwreck_stage 3 still backfills vessel readiness and migrates successfully"):
		return false

	# Case A: a legacy iron_age save with no fact field has no Eldergrove
	# evidence channel at all (evidence only lives in the fact array), so the
	# conservative downgrade is unchanged; valid Eldergrove evidence carried by
	# the fact array still retains Iron Age.
	var iron_no_field_mig: Dictionary = SaveManager.migrate_payload(_legacy_payload("wooden_wall", "iron_age", 0, null, "ACTIVE").duplicate(true)) as Dictionary
	var iron_no_field_pf: Dictionary = iron_no_field_mig["progression_flags"] as Dictionary
	if not _check(String(iron_no_field_pf.get("era_id", "")) == "wood_age" and not iron_no_field_pf.has("progression_facts") and sm.validate_payload(iron_no_field_mig), "Legacy iron_age without fact field or evidence still downgrades to wood_age with no invented facts"):
		return false
	var iron_eldergrove_mig: Dictionary = SaveManager.migrate_payload(_legacy_payload("stone_wall", "iron_age", 0, [ELDERGROVE_FACT], "ACTIVE").duplicate(true)) as Dictionary
	var iron_eldergrove_pf: Dictionary = iron_eldergrove_mig["progression_flags"] as Dictionary
	if not _check(String(iron_eldergrove_pf.get("era_id", "")) == "iron_age" and iron_eldergrove_pf.get("progression_facts", []) == [ELDERGROVE_FACT] and sm.validate_payload(iron_eldergrove_mig), "Valid Eldergrove evidence in the fact array still retains Iron Age"):
		return false

	# Case B: an explicitly present `progression_facts: null` is a malformed
	# payload, NOT a missing legacy field — never backfilled, never repaired;
	# strict validation rejects the whole payload.
	var null_facts: Dictionary = _legacy_payload_with_explicit_facts("wooden_wall", "wood_age", 0, null, "ACTIVE")
	if not _check((null_facts["progression_flags"] as Dictionary).has("progression_facts") and (null_facts["progression_flags"] as Dictionary)["progression_facts"] == null, "Case B fixture sanity: fact field is explicitly present as null"):
		return false
	var null_mig: Dictionary = SaveManager.migrate_payload(null_facts.duplicate(true)) as Dictionary
	var null_mig_pf: Dictionary = null_mig["progression_flags"] as Dictionary
	if not _check(null_mig_pf.has("progression_facts") and null_mig_pf["progression_facts"] == null, "Explicit progression_facts: null is not replaced or repaired by migration"):
		return false
	if not _check(not sm.validate_payload(null_mig), "Explicit progression_facts: null payload is rejected by strict validation"):
		return false

	# Case B: explicit null combined with shipwreck_stage == 3 is still rejected
	# and does NOT receive the vessel-readiness backfill (the second backfill
	# caller is equally strict for a stone_age save).
	var null_stage3: Dictionary = _legacy_payload_with_explicit_facts("wooden_wall", "wood_age", 3, null, "ACTIVE")
	var null_stage3_mig: Dictionary = SaveManager.migrate_payload(null_stage3.duplicate(true)) as Dictionary
	var null_stage3_pf: Dictionary = null_stage3_mig["progression_flags"] as Dictionary
	if not _check(null_stage3_pf.has("progression_facts") and null_stage3_pf["progression_facts"] == null, "Explicit null with Stage 3 evidence receives no vessel-readiness backfill"):
		return false
	if not _check(not sm.validate_payload(null_stage3_mig), "Explicit progression_facts: null with shipwreck_stage 3 is still rejected"):
		return false
	var null_stone_mig: Dictionary = SaveManager.migrate_payload(_legacy_payload_with_explicit_facts("stone_wall", "stone_age", 0, null, "ACTIVE").duplicate(true)) as Dictionary
	var null_stone_pf: Dictionary = null_stone_mig["progression_flags"] as Dictionary
	if not _check(not sm.validate_payload(null_stone_mig) and null_stone_pf.has("progression_facts") and null_stone_pf["progression_facts"] == null, "Explicit progression_facts: null on a stone_age save is rejected without the stone-fact backfill"):
		return false
	# Full pipeline: the malformed file fails to load through the real SaveManager.
	var nf: FileAccess = FileAccess.open(SAVE_MALFORMED_NULL_FACTS, FileAccess.WRITE)
	nf.store_string(JSON.stringify(null_stage3))
	nf.close()
	if not _check(not bool(sm.load_state(SAVE_MALFORMED_NULL_FACTS).get("ok", false)), "Save file with explicit progression_facts: null fails to load safely"):
		return false

	# Case B: other explicitly malformed values are rejected untouched even when
	# Stage 3 evidence is present.
	var str_mig: Dictionary = SaveManager.migrate_payload(_legacy_payload_with_explicit_facts("wooden_wall", "wood_age", 3, "invalid", "ACTIVE").duplicate(true)) as Dictionary
	var str_pf: Dictionary = str_mig["progression_flags"] as Dictionary
	if not _check(typeof(str_pf["progression_facts"]) == TYPE_STRING and String(str_pf["progression_facts"]) == "invalid" and not sm.validate_payload(str_mig), "Explicit malformed string facts value is left untouched and rejected"):
		return false
	var dict_mig: Dictionary = SaveManager.migrate_payload(_legacy_payload_with_explicit_facts("wooden_wall", "wood_age", 3, {}, "ACTIVE").duplicate(true)) as Dictionary
	var dict_pf: Dictionary = dict_mig["progression_flags"] as Dictionary
	if not _check(typeof(dict_pf["progression_facts"]) == TYPE_DICTIONARY and (dict_pf["progression_facts"] as Dictionary).is_empty() and not sm.validate_payload(dict_mig), "Explicit malformed dictionary facts value is left untouched and rejected"):
		return false

	# Rejection never mutates the caller's payload and never partially mutates
	# live progression state.
	var original: Dictionary = _legacy_payload_with_explicit_facts("wooden_wall", "wood_age", 3, null, "ACTIVE")
	SaveManager.migrate_payload(original)
	var original_pf: Dictionary = original["progression_flags"] as Dictionary
	if not _check(original_pf.has("progression_facts") and original_pf["progression_facts"] == null and int(original_pf.get("shipwreck_stage", 0)) == 3, "Migration never mutates the caller's payload (input stays explicitly null)"):
		return false
	var live: ProgressionState = ProgressionState.new()
	if not _check(live.record_fact(FACT) and live.record_fact(VESSEL_FACT) and live.fact_count() == 2, "Live state setup: two facts recorded"):
		return false
	var before_ids: Array = live.get_fact_ids()
	for bad_apply: Variant in ["invalid", 123, {}, ["BAD ID"]]:
		if not _check(not live.apply_save_state(bad_apply), "apply_save_state rejects malformed explicit value: %s" % str(bad_apply)):
			return false
		if not _check(live.get_fact_ids() == before_ids and live.fact_count() == 2, "Rejected apply mutated nothing (facts intact): %s" % str(bad_apply)):
			return false
	if not _check(not sm.has_valid_save(SAVE_MALFORMED_NULL_FACTS) and live.get_fact_ids() == before_ids and live.fact_count() == 2, "Failed malformed-file load leaves live progression state fully intact"):
		return false

	# Deterministic and idempotent rejection; existing migration idempotency is
	# unchanged for both fixture families.
	var null_once: Dictionary = SaveManager.migrate_payload(null_stage3.duplicate(true)) as Dictionary
	var null_twice: Dictionary = SaveManager.migrate_payload(null_once.duplicate(true)) as Dictionary
	var null_again: Dictionary = SaveManager.migrate_payload(null_stage3.duplicate(true)) as Dictionary
	if not _check(null_once.hash() == null_twice.hash() and null_once.hash() == null_again.hash(), "Malformed-payload migration stays deterministic and idempotent (double pass changes nothing)"):
		return false
	var absent_once: Dictionary = SaveManager.migrate_payload(absent_stage3.duplicate(true)) as Dictionary
	var absent_twice: Dictionary = SaveManager.migrate_payload(absent_once.duplicate(true)) as Dictionary
	if not _check(absent_once.hash() == absent_twice.hash(), "Absent-field migration idempotency continues to pass"):
		return false

	print("PASS: Phase 2 Strict Malformed progression_facts Field Rejection (Absent vs Explicit)")
	return true


# ---------------------------------------------------------------- Suite 8 ---
## Phase 2.2 regression: when progression_facts is EXPLICITLY present but
## malformed, migrate_payload must skip the whole progression migration section
## (no era inference or legacy Iron Age correction, no vessel/Stone Age
## backfills, no canonicalization) and let validate_payload reject the payload
## wholesale — while the genuinely-absent-field and valid-array paths keep
## their existing deterministic migration behavior. Every case checks both the
## migrated copy and the original input dictionary.
func _test_malformed_facts_skip_progression_migration() -> bool:
	var sm: SaveManager = SaveManager.new()

	# Case A — explicit `progression_facts: null` on a legacy iron_age save with
	# Stage 3 evidence: no era correction, no vessel backfill, value stays
	# explicitly present and null; validation rejects; input dict untouched.
	var null_iron: Dictionary = _legacy_payload_with_explicit_facts("stone_wall", "iron_age", 3, null, "ISLAND_CLEARED")
	if not _check((null_iron["progression_flags"] as Dictionary).has("progression_facts") and (null_iron["progression_flags"] as Dictionary)["progression_facts"] == null, "Case A fixture sanity: fact field is explicitly present as null on a legacy iron_age save"):
		return false
	var null_iron_mig: Dictionary = SaveManager.migrate_payload(null_iron) as Dictionary
	var null_iron_pf: Dictionary = null_iron_mig["progression_flags"] as Dictionary
	if not _check(String(null_iron_pf.get("era_id", "")) == "iron_age", "Case A: migration does not change era_id (no legacy Iron Age correction for an explicit null)"):
		return false
	if not _check(null_iron_pf.has("progression_facts") and null_iron_pf["progression_facts"] == null, "Case A: progression_facts stays explicitly present and null (no vessel-ready or Stone Age backfill)"):
		return false
	if not _check(not sm.validate_payload(null_iron_mig), "Case A: migrated payload is rejected by strict validation"):
		return false
	var null_iron_orig_pf: Dictionary = null_iron["progression_flags"] as Dictionary
	if not _check(String(null_iron_orig_pf.get("era_id", "")) == "iron_age" and null_iron_orig_pf.has("progression_facts") and null_iron_orig_pf["progression_facts"] == null and int(null_iron_orig_pf.get("shipwreck_stage", 0)) == 3, "Case A: original input dictionary remains unchanged (era_id, explicit null and Stage 3 intact)"):
		return false
	var nif: FileAccess = FileAccess.open(SAVE_MALFORMED_NULL_IRON, FileAccess.WRITE)
	nif.store_string(JSON.stringify(null_iron))
	nif.close()
	if not _check(not bool(sm.load_state(SAVE_MALFORMED_NULL_IRON).get("ok", false)), "Case A: iron_age save file with explicit null facts fails to load safely through the real pipeline"):
		return false

	# Case B — explicit malformed string with legacy Iron Age + Stage 3 evidence:
	# era untouched, value untouched, rejected, input dict untouched.
	var str_iron: Dictionary = _legacy_payload_with_explicit_facts("stone_wall", "iron_age", 3, "corrupted", "ACTIVE")
	var str_iron_mig: Dictionary = SaveManager.migrate_payload(str_iron) as Dictionary
	var str_iron_pf: Dictionary = str_iron_mig["progression_flags"] as Dictionary
	if not _check(String(str_iron_pf.get("era_id", "")) == "iron_age" and typeof(str_iron_pf["progression_facts"]) == TYPE_STRING and String(str_iron_pf["progression_facts"]) == "corrupted" and not sm.validate_payload(str_iron_mig), "Case B: malformed string facts skips era correction, stays untouched, payload rejected"):
		return false
	var str_iron_orig_pf: Dictionary = str_iron["progression_flags"] as Dictionary
	if not _check(String(str_iron_orig_pf.get("era_id", "")) == "iron_age" and String(str_iron_orig_pf["progression_facts"]) == "corrupted", "Case B: original input dictionary remains unchanged"):
		return false

	# Case C — explicit malformed dictionary with legacy Iron Age + Stage 3
	# evidence: era untouched, value untouched, rejected, input dict untouched.
	var dict_iron: Dictionary = _legacy_payload_with_explicit_facts("stone_wall", "iron_age", 3, {"facts": "not_an_array"}, "ACTIVE")
	var dict_iron_mig: Dictionary = SaveManager.migrate_payload(dict_iron) as Dictionary
	var dict_iron_pf: Dictionary = dict_iron_mig["progression_flags"] as Dictionary
	if not _check(String(dict_iron_pf.get("era_id", "")) == "iron_age" and typeof(dict_iron_pf["progression_facts"]) == TYPE_DICTIONARY and String((dict_iron_pf["progression_facts"] as Dictionary).get("facts", "")) == "not_an_array" and not sm.validate_payload(dict_iron_mig), "Case C: malformed dictionary facts skips era correction, stays untouched, payload rejected"):
		return false
	var dict_iron_orig_pf: Dictionary = dict_iron["progression_flags"] as Dictionary
	if not _check(String(dict_iron_orig_pf.get("era_id", "")) == "iron_age" and String((dict_iron_orig_pf["progression_facts"] as Dictionary).get("facts", "")) == "not_an_array", "Case C: original input dictionary remains unchanged"):
		return false

	# Case D — invalid fact arrays (unknown ID / duplicate IDs) with legacy Iron
	# Age + Stage 3 evidence: no correction, no backfill, no deduplication, no
	# reordering; rejected wholesale, input dict untouched.
	var unknown_iron: Dictionary = _legacy_payload_with_explicit_facts("stone_wall", "iron_age", 3, ["mount_tamed"], "ACTIVE")
	var unknown_iron_mig: Dictionary = SaveManager.migrate_payload(unknown_iron) as Dictionary
	var unknown_iron_pf: Dictionary = unknown_iron_mig["progression_flags"] as Dictionary
	if not _check(String(unknown_iron_pf.get("era_id", "")) == "iron_age" and unknown_iron_pf.get("progression_facts", []) == ["mount_tamed"] and not sm.validate_payload(unknown_iron_mig), "Case D: unknown fact ID receives no era correction or vessel backfill; payload rejected"):
		return false
	if not _check(String((unknown_iron["progression_flags"] as Dictionary).get("era_id", "")) == "iron_age", "Case D: original input dictionary remains unchanged (unknown ID case)"):
		return false
	var dup_iron: Dictionary = _legacy_payload_with_explicit_facts("stone_wall", "iron_age", 3, [FACT, FACT], "ACTIVE")
	var dup_iron_mig: Dictionary = SaveManager.migrate_payload(dup_iron) as Dictionary
	var dup_iron_pf: Dictionary = dup_iron_mig["progression_flags"] as Dictionary
	if not _check(String(dup_iron_pf.get("era_id", "")) == "iron_age" and dup_iron_pf.get("progression_facts", []) == [FACT, FACT] and not sm.validate_payload(dup_iron_mig), "Case D: duplicate fact IDs are not deduplicated, sorted, or corrected; payload rejected"):
		return false
	if not _check(String((dup_iron["progression_flags"] as Dictionary).get("era_id", "")) == "iron_age", "Case D: original input dictionary remains unchanged (duplicate ID case)"):
		return false

	# Case E — the fact field genuinely ABSENT on a valid legacy save: the
	# existing deterministic migration keeps working unchanged (conservative era
	# correction from real evidence, Stage-3 vessel backfill, stone-fact
	# backfill when the corrected era is stone_age).
	var legacy_iron_mig: Dictionary = SaveManager.migrate_payload(_legacy_payload("stone_wall", "iron_age", 3, null, "ISLAND_CLEARED").duplicate(true)) as Dictionary
	var legacy_iron_pf: Dictionary = legacy_iron_mig["progression_flags"] as Dictionary
	if not _check(String(legacy_iron_pf.get("era_id", "")) == "stone_age" and legacy_iron_pf.get("progression_facts", []) == [FACT, VESSEL_FACT] and sm.validate_payload(legacy_iron_mig), "Case E: absent fact field still migrates legacy iron_age to stone_age with stone + vessel facts backfilled"):
		return false
	var legacy_wood_mig: Dictionary = SaveManager.migrate_payload(_legacy_payload("wooden_wall", "iron_age", 3, null, "ISLAND_CLEARED").duplicate(true)) as Dictionary
	var legacy_wood_pf: Dictionary = legacy_wood_mig["progression_flags"] as Dictionary
	if not _check(String(legacy_wood_pf.get("era_id", "")) == "wood_age" and legacy_wood_pf.get("progression_facts", []) == [VESSEL_FACT] and sm.validate_payload(legacy_wood_mig), "Case E: absent fact field without stone evidence still downgrades to wood_age keeping only vessel readiness"):
		return false

	# Case F — a valid existing fact array: valid Eldergrove evidence retains
	# Iron Age, the array stays intact apart from deterministic canonicalization
	# (sorted, matching the to_save_array() contract), and the payload validates.
	var valid_iron_mig: Dictionary = SaveManager.migrate_payload(_legacy_payload("stone_wall", "iron_age", 3, [VESSEL_FACT, ELDERGROVE_FACT], "ISLAND_CLEARED").duplicate(true)) as Dictionary
	var valid_iron_pf: Dictionary = valid_iron_mig["progression_flags"] as Dictionary
	if not _check(String(valid_iron_pf.get("era_id", "")) == "iron_age" and valid_iron_pf.get("progression_facts", []) == [ELDERGROVE_FACT, VESSEL_FACT] and sm.validate_payload(valid_iron_mig), "Case F: valid Eldergrove evidence keeps Iron Age and the valid array stays deterministically sorted"):
		return false

	# Case G — idempotency: migrating twice changes nothing for the absent-field
	# path, the valid-array path, or the malformed-payload rejection path; facts
	# never duplicate.
	var e_once: Dictionary = SaveManager.migrate_payload(_legacy_payload("stone_wall", "iron_age", 3, null, "ISLAND_CLEARED").duplicate(true)) as Dictionary
	var e_twice: Dictionary = SaveManager.migrate_payload(e_once.duplicate(true)) as Dictionary
	if not _check(e_once.hash() == e_twice.hash() and (e_once["progression_flags"] as Dictionary).get("progression_facts", []) == [FACT, VESSEL_FACT], "Case G: absent-field legacy migration is idempotent (second pass identical, no duplicate facts)"):
		return false
	var f_once: Dictionary = SaveManager.migrate_payload(_legacy_payload("stone_wall", "iron_age", 3, [VESSEL_FACT, ELDERGROVE_FACT], "ISLAND_CLEARED").duplicate(true)) as Dictionary
	var f_twice: Dictionary = SaveManager.migrate_payload(f_once.duplicate(true)) as Dictionary
	if not _check(f_once.hash() == f_twice.hash(), "Case G: valid-array migration is idempotent (second pass identical)"):
		return false
	var a_once: Dictionary = SaveManager.migrate_payload(_legacy_payload_with_explicit_facts("stone_wall", "iron_age", 3, null, "ISLAND_CLEARED").duplicate(true)) as Dictionary
	var a_twice: Dictionary = SaveManager.migrate_payload(a_once.duplicate(true)) as Dictionary
	var a_again: Dictionary = SaveManager.migrate_payload(_legacy_payload_with_explicit_facts("stone_wall", "iron_age", 3, null, "ISLAND_CLEARED").duplicate(true)) as Dictionary
	if not _check(a_once.hash() == a_twice.hash() and a_once.hash() == a_again.hash(), "Case G: malformed-payload migration stays deterministic and idempotent"):
		return false

	# Rejection never partially mutates live progression state: the migrated
	# malformed payloads are rejected before any apply, and a direct
	# apply_save_state of the malformed values mutates nothing. (Explicit null
	# is rejected at the payload level in Case A; apply_save_state(null) keeps
	# its separate, documented Phase 1 "field absent" clear contract.)
	var live: ProgressionState = ProgressionState.new()
	if not _check(live.record_fact(FACT) and live.fact_count() == 1, "Phase 2.2 live-state setup: one fact recorded"):
		return false
	var live_before: Array = live.get_fact_ids()
	for bad_value: Variant in ["corrupted", {"facts": "not_an_array"}, ["mount_tamed"], [FACT, FACT]]:
		if not _check(not live.apply_save_state(bad_value), "Phase 2.2 live apply rejects malformed facts value: %s" % str(bad_value)):
			return false
		if not _check(live.get_fact_ids() == live_before and live.fact_count() == 1, "Phase 2.2 live state unchanged after rejected apply: %s" % str(bad_value)):
			return false

	print("PASS: Phase 2.2 Malformed progression_facts Skips Progression Migration (Absent vs Valid vs Malformed)")
	return true


func _init() -> void:
	var suite_names: Array[String] = [
		"Fresh Start & Stone Age Path", "Shipwreck Vessel Readiness & Era Lock",
		"Iron Age Eldergrove Gate", "Legacy Migration Policy",
		"Save/Load Round-Trip", "Regression Guards", "Strict Malformed Facts Rejection",
		"Phase 2.2 Malformed Facts Migration Isolation",
	]
	var suites: Array[Callable] = [
		_test_fresh_start_and_stone_age_path, _test_shipwreck_vessel_readiness_and_era_lock,
		_test_iron_age_requires_eldergrove_milestone, _test_legacy_migration_policy,
		_test_save_roundtrip_preserves_facts_and_era, _test_gameplay_regression_guards,
		_test_strict_malformed_facts_field_rejection,
		_test_malformed_facts_skip_progression_migration,
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
	print("PASS: All %d Phase 2 Era Correction Checks completed with 0 failures across %d suites." % [_checks, suites.size()])
	quit(0)
