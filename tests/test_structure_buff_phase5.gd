extends SceneTree

## Phase 5 Shrine / Statue / Temple, Resource Access & Gameplay Buff
## foundation test suite. Follows the repo test conventions: fail-fast _check
## helper, tab indentation, no raw engine assert calls, no scene-tree child
## injection. Covers structure definition validation (fail-safe catalog,
## pinned activation facts, cost/resource/requirement references), derived
## lifecycle and transactional activation through the atomic EconomyLedger
## (duplicate activation never spends twice), buff definition validation and
## the authoritative derived aggregation (no duplicate application, additive
## stacking, unsupported modes rejected), explicit resource access separated
## from ledger quantity (zero balance while unlocked, nonzero balance while
## locked, unknown IDs fail closed), the real session command/resolver/blessing
## paths, Phase 5 save/load behavior (schema v2 unchanged, activation facts
## replace state, legacy saves into non-empty Phase 5 sessions, rollback), and
## regression guards for specialists, research, offerings, economy and
## progression.

const SHRINE_ID: String = "shrine_of_growth"
const STATUE_ID: String = "statue_of_the_first_sailor"
const TEMPLE_ID: String = "temple_of_the_dawn"
const SHRINE_X: float = 820.0
const STONE_AGE_FACT: String = "forgotten_shore_first_stone_wall_tier_2"
const TIMBER_NODE: String = "timber_pile_west"
const TIMBER_X: float = -110.0
const TREE_EAST_02: String = "tree_east_02"
const TREE_EAST_02_X: float = 690.0
const SAVE_ROUNDTRIP_PATH: String = "user://test_phase5_roundtrip.json"
const SAVE_LEGACY_PATH: String = "user://test_phase5_legacy.json"
const SAVE_ROLLBACK_PATH: String = "user://test_phase5_rollback.json"
const SAVE_MALFORMED_FACTS_PATH: String = "user://test_phase5_malformed_facts.json"
const LOCKED_RESOURCES_PATH: String = "user://test_phase5_locked_resources.json"
const FUTURE_ISLAND_PATH: String = "user://test_phase5_future_island.json"

var _failures: int = 0
var _checks: int = 0


## Test double: fails exactly one apply_save_array call (the failed load
## attempt) and delegates every later call to the real implementation (the
## session rollback retry). Simulates "structure/facts restoration succeeded,
## then a later subsystem failed" so the existing session rollback path is
## exercised end to end with Phase 5 state live.
class FailOncePopulationManager extends NPCPopulationManager:
	var _failing_calls_left: int = 1

	func apply_save_array(npcs_arr: Array) -> bool:
		if _failing_calls_left > 0:
			_failing_calls_left -= 1
			return false
		return super.apply_save_array(npcs_arr)


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE [test_structure_buff_phase5]: " + msg)
		quit(1)
		return false
	return true


func _fresh_session() -> ForgottenShoreSession:
	var session_script: GDScript = load("res://scripts/world/ForgottenShoreSession.gd")
	return session_script.new() as ForgottenShoreSession


func _fund(sess: ForgottenShoreSession, gold: int, wood: int, stone: int) -> bool:
	return sess.economy.set_balances_from_dict({"gold": gold, "wood": wood, "stone": stone})


func _grant_stone_age(sess: ForgottenShoreSession) -> bool:
	# The stone-wall milestone fact is the authoritative requirement evidence;
	# its real gameplay recording path (wall upgrade transaction) is already
	# covered by the Phase 1/2 suites, so suites here record it directly.
	return sess.progression.record_fact(STONE_AGE_FACT)


# ---------------------------------------------------------------- Suite 1 ---
func _test_structure_catalog_validation() -> bool:
	var catalog: StructureCatalog = StructureCatalog.new()
	if not _check(not catalog.is_empty() and catalog.get_structure_ids() == [SHRINE_ID, STATUE_ID, TEMPLE_ID], "Structures data file loads exactly the three registered structures with stable unique IDs (sorted)"):
		return false
	var shrine: Dictionary = catalog.get_structure(SHRINE_ID)
	if not _check(String(shrine.get("category", "")) == "shrine" and is_equal_approx(float(shrine.get("world_x", 0.0)), SHRINE_X), "Shrine of Growth is a data-defined shrine with its world position"):
		return false
	if not _check(shrine.get("activation_fact", "") == "shrine_of_growth_activated" and shrine.get("requires", {}) == {"all_of": [STONE_AGE_FACT]}, "Shrine activation fact is pinned to the stable pattern and gated on the Stone Age milestone"):
		return false
	if not _check(shrine.get("activation_cost", {}) == {"gold": 4, "wood": 2, "stone": 3}, "Shrine activation cost is a validated EconomyLedger cost"):
		return false
	var statue: Dictionary = catalog.get_structure(STATUE_ID)
	var temple: Dictionary = catalog.get_structure(TEMPLE_ID)
	if not _check(String(statue.get("category", "")) == "statue" and String(temple.get("category", "")) == "temple", "Statue and Temple categories are distinguishable in their definitions"):
		return false
	if not _check(not statue.has("world_x") and not temple.has("world_x"), "Statue and Temple ship without a world position and fail closed until placed"):
		return false
	if not _check(catalog.get_structure("unknown_structure").is_empty(), "Unknown structure IDs return an empty definition (fail closed)"):
		return false

	var errs: Array[String] = []
	var bad_payloads: Array = [
		42,
		{"no_structures": []},
		{"structures": []},
		{"structures": [42]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}, "extra_field": 1}]},
		{"structures": [{"category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}}]},
		{"structures": [{"id": SHRINE_ID, "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}}]},
		{"structures": [{"id": SHRINE_ID, "category": "monument", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "  ", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "atlantis", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_activated", "activation_cost": {"gold": 1}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "not_a_registered_fact", "activation_cost": {"gold": 1}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": 42, "activation_cost": {"gold": 1}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"iron": 2}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 0}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": -2}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 2.5}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}, "world_x": "east"}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}, "world_x": 999999.0}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}, "requires": {"all_of": ["not_a_registered_fact"]}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}, "requires": {"all_of": []}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}, "requires": {"wrong_group": [STONE_AGE_FACT]}}]},
		{"structures": [{"id": SHRINE_ID, "category": "shrine", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}}, {"id": SHRINE_ID, "category": "statue", "display_name": "S2", "description": "D", "island_id": "forgotten_shore", "activation_fact": "shrine_of_growth_activated", "activation_cost": {"gold": 1}}]},
	]
	for bad: Variant in bad_payloads:
		errs.clear()
		if not _check(StructureCatalog.validate_structures_payload(bad, errs).is_empty() and not errs.is_empty(), "Malformed structure payload rejected with a reason: %s" % str(bad).left(90)):
			return false

	# A temple definition on a future island validates (categories and islands
	# are whitelisted; the activation fact is a registered ID) but must never
	# activate on Forgotten Shore (Suite 2 drives the real rejection).
	errs.clear()
	var future_island: Dictionary = StructureCatalog.validate_structures_payload(
		{"structures": [{"id": TEMPLE_ID, "category": "temple", "display_name": "Temple of the Dawn", "description": "Future island temple.", "island_id": "ancient_kingdom", "activation_fact": "temple_of_the_dawn_activated", "activation_cost": {"gold": 1}, "world_x": 100.0}]},
		errs
	)
	if not _check(not future_island.is_empty() and errs.is_empty(), "A valid future-island temple definition passes validation (registered fact + known island)"):
		return false
	return true


# ---------------------------------------------------------------- Suite 2 ---
func _test_structure_lifecycle_and_activation() -> bool:
	var domain: StructureDomain = StructureDomain.new()
	var progression: ProgressionState = ProgressionState.new()

	# Derived lifecycle before any requirement fact.
	if not _check(domain.get_lifecycle_state(SHRINE_ID, progression) == StructureDomain.STATE_LOCKED, "Shrine starts LOCKED (Stone Age requirement unmet)"):
		return false
	if not _check(domain.get_lifecycle_state(STATUE_ID, progression) == StructureDomain.STATE_AVAILABLE, "Statue without requirements starts AVAILABLE (activation still fails closed without a world position)"):
		return false
	if not _check(domain.get_lifecycle_state("unknown_structure", progression) == "", "Unknown structure lifecycle is an empty string (fail closed)"):
		return false
	if not _check(not domain.is_activated(SHRINE_ID, progression) and domain.get_activated_structure_ids(progression).is_empty(), "No structure is activated on a fresh progression state (nothing fabricated)"):
		return false

	var economy: EconomyLedger = EconomyLedger.new()
	if not _fund_wrapper(economy, 10, 10, 10):
		return false

	# Unknown ID / progression / ledger guards never touch balances.
	if not _check(not domain.try_activate(SHRINE_X, "unknown_structure", progression, economy), "Activating an unknown structure is rejected"):
		return false
	if not _check(not domain.try_activate(SHRINE_X, SHRINE_ID, null, economy), "Activation without a progression state is rejected"):
		return false
	if not _check(economy.get_amount(&"gold") == 10, "Failed unknown-ID activation leaves balances untouched"):
		return false

	# Requirements gate (locked).
	if not _check(not domain.try_activate(SHRINE_X, SHRINE_ID, progression, economy), "Locked shrine activation is rejected while requirements are unmet"):
		return false
	if not _check(economy.get_amount(&"gold") == 10 and not progression.has_fact("shrine_of_growth_activated"), "Rejected locked activation spent nothing and recorded no fact"):
		return false

	# Future-placed structures fail closed on world presence before any spend.
	if not _check(not domain.try_activate(0.0, STATUE_ID, progression, economy), "Statue without a world position is rejected"):
		return false
	if not _check(not domain.try_activate(0.0, TEMPLE_ID, progression, economy), "Temple without a world position is rejected"):
		return false

	# Requirements met -> AVAILABLE; proximity enforced.
	if not _check(_grant_stone_age_wrapper(progression), "Stone Age milestone fact recorded for the activation gate"):
		return false
	if not _check(domain.get_lifecycle_state(SHRINE_ID, progression) == StructureDomain.STATE_AVAILABLE, "Shrine becomes AVAILABLE once requirements are satisfied"):
		return false
	if not _check(not domain.try_activate(SHRINE_X + 200.0, SHRINE_ID, progression, economy), "Activation out of interaction range is rejected"):
		return false
	if not _check(economy.get_amount(&"gold") == 10, "Out-of-range rejection spent nothing"):
		return false

	# Successful transaction: atomic spend, durable fact, signal.
	var activated_capture: Dictionary = {}
	domain.structure_activated.connect(func(sid: String) -> void: activated_capture["id"] = sid)
	if not _check(domain.try_activate(SHRINE_X, SHRINE_ID, progression, economy), "Shrine activation succeeds through the authoritative transaction"):
		return false
	if not _check(String(activated_capture.get("id", "")) == SHRINE_ID, "structure_activated signal carries the structure ID"):
		return false
	if not _check(economy.get_amount(&"gold") == 6 and economy.get_amount(&"wood") == 8 and economy.get_amount(&"stone") == 7, "Activation deducts exactly the 4G 2W 3S cost"):
		return false
	if not _check(progression.has_fact("shrine_of_growth_activated") and domain.is_activated(SHRINE_ID, progression), "Durable activation fact recorded exactly once"):
		return false
	if not _check(domain.get_lifecycle_state(SHRINE_ID, progression) == StructureDomain.STATE_ACTIVATED, "Shrine lifecycle is ACTIVATED after the transaction"):
		return false

	# Duplicate activation: rejected before any spend, never double-deducts.
	var gold_before: int = economy.get_amount(&"gold")
	if not _check(not domain.try_activate(SHRINE_X, SHRINE_ID, progression, economy), "Repeated activation is rejected (idempotent fact guard)"):
		return false
	if not _check(economy.get_amount(&"gold") == gold_before, "Repeated activation never spends resources a second time"):
		return false

	# Insufficient funds: atomic (no partial deduction, no fact).
	var progression2: ProgressionState = ProgressionState.new()
	_grant_stone_age_wrapper(progression2)
	var economy2: EconomyLedger = EconomyLedger.new()
	if not _fund_wrapper(economy2, 2, 2, 2):
		return false
	if not _check(not domain.try_activate(SHRINE_X, SHRINE_ID, progression2, economy2), "Insufficient funds reject activation"):
		return false
	if not _check(economy2.get_amount(&"gold") == 2 and economy2.get_amount(&"wood") == 2 and economy2.get_amount(&"stone") == 2, "Failed activation leaves all balances untouched (atomic two-phase spend)"):
		return false
	if not _check(not progression2.has_fact("shrine_of_growth_activated"), "Failed activation records no fact"):
		return false

	# A future-island definition (validated in Suite 1) never activates here.
	var future_file: FileAccess = FileAccess.open(FUTURE_ISLAND_PATH, FileAccess.WRITE)
	if not _check(future_file != null, "Suite2 setup: future-island catalog file opened"):
		return false
	future_file.store_string(JSON.stringify({
		"structures": [{"id": TEMPLE_ID, "category": "temple", "display_name": "Temple of the Dawn", "description": "Future island temple.", "island_id": "ancient_kingdom", "activation_fact": "temple_of_the_dawn_activated", "activation_cost": {"gold": 1}, "world_x": 100.0}]
	}))
	future_file.close()
	var future_catalog: StructureCatalog = StructureCatalog.new()
	if not _check(future_catalog.load_from_data(FUTURE_ISLAND_PATH) and not future_catalog.is_empty(), "Suite2 setup: future-island temple catalog loads"):
		return false
	var reject_capture: Dictionary = {}
	var future_domain: StructureDomain = StructureDomain.new(future_catalog)
	future_domain.structure_action_rejected.connect(func(reason: String) -> void: reject_capture["reason"] = reason)
	if not _check(not future_domain.try_activate(100.0, TEMPLE_ID, progression, economy), "Future-island temple cannot activate on Forgotten Shore (fail closed)"):
		return false
	if not _check(String(reject_capture.get("reason", "")).contains("another island"), "Future-island rejection explains the island boundary"):
		return false
	if not _check(economy.get_amount(&"gold") == 6, "Future-island rejection spent nothing"):
		return false
	return true


func _fund_wrapper(economy: EconomyLedger, gold: int, wood: int, stone: int) -> bool:
	return economy.set_balances_from_dict({"gold": gold, "wood": wood, "stone": stone})


func _grant_stone_age_wrapper(progression: ProgressionState) -> bool:
	return progression.record_fact(STONE_AGE_FACT)


# ---------------------------------------------------------------- Suite 3 ---
func _test_buff_catalog_and_aggregation() -> bool:
	var structure_catalog: StructureCatalog = StructureCatalog.new()
	var buff_catalog: BuffCatalog = BuffCatalog.new(structure_catalog)
	if not _check(not buff_catalog.is_empty() and buff_catalog.get_buff_ids() == ["grove_timber_blessing"], "Buff data file loads exactly the shipped blessing with a stable unique ID"):
		return false
	var blessing: Dictionary = buff_catalog.get_buff("grove_timber_blessing")
	if not _check(String(blessing.get("effect_type", "")) == BuffCatalog.EFFECT_WOOD_GATHERING_BONUS and int(blessing.get("magnitude", 0)) == 1, "Growth Blessing targets the consumer-backed wood-gathering effect with magnitude 1"):
		return false
	if not _check(String(blessing.get("stacking", "")) == "additive" and is_equal_approx(float(blessing.get("duration_sec", 1.0)), 0.0), "Growth Blessing is an additive permanent buff"):
		return false
	if not _check(String(blessing.get("source_structure", "")) == SHRINE_ID, "Blessing is linked to its source structure (single directional reference)"):
		return false
	if not _check(not BuffCatalog.KNOWN_EFFECT_TYPES.has("made_up_effect") and not buff_catalog.has_buff("made_up_blessing"), "Effect registry contains only types with real consumers"):
		return false

	var errs: Array[String] = []
	var known_ids: Array[String] = structure_catalog.get_structure_ids()
	var base_def: Dictionary = {
		"id": "test_blessing",
		"effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS,
		"magnitude": 1,
		"stacking": "additive",
		"duration_sec": 0,
		"source_structure": SHRINE_ID,
	}
	var bad_payloads: Array = [
		42,
		{"no_buffs": []},
		{"buffs": []},
		{"buffs": [42]},
		{"buffs": [base_def.duplicate(), base_def.duplicate()]},
		{"buffs": [{"effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, "magnitude": 1, "stacking": "additive", "duration_sec": 0, "source_structure": SHRINE_ID}]},
		{"buffs": [{"id": "Bad_ID", "effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, "magnitude": 1, "stacking": "additive", "duration_sec": 0, "source_structure": SHRINE_ID}]},
		{"buffs": [{"id": "test_blessing", "effect_type": "made_up_effect", "magnitude": 1, "stacking": "additive", "duration_sec": 0, "source_structure": SHRINE_ID}]},
		{"buffs": [{"id": "test_blessing", "effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, "magnitude": 0, "stacking": "additive", "duration_sec": 0, "source_structure": SHRINE_ID}]},
		{"buffs": [{"id": "test_blessing", "effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, "magnitude": -2, "stacking": "additive", "duration_sec": 0, "source_structure": SHRINE_ID}]},
		{"buffs": [{"id": "test_blessing", "effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, "magnitude": 1.5, "stacking": "additive", "duration_sec": 0, "source_structure": SHRINE_ID}]},
		{"buffs": [{"id": "test_blessing", "effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, "magnitude": 1, "stacking": "unique", "duration_sec": 0, "source_structure": SHRINE_ID}]},
		{"buffs": [{"id": "test_blessing", "effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, "magnitude": 1, "stacking": "multiplicative", "duration_sec": 0, "source_structure": SHRINE_ID}]},
		{"buffs": [{"id": "test_blessing", "effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, "magnitude": 1, "stacking": "additive", "duration_sec": 30.0, "source_structure": SHRINE_ID}]},
		{"buffs": [{"id": "test_blessing", "effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, "magnitude": 1, "stacking": "additive", "duration_sec": -1.0, "source_structure": SHRINE_ID}]},
		{"buffs": [{"id": "test_blessing", "effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, "magnitude": 1, "stacking": "additive", "duration_sec": "forever", "source_structure": SHRINE_ID}]},
		{"buffs": [{"id": "test_blessing", "effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, "magnitude": 1, "stacking": "additive", "duration_sec": 0, "source_structure": "unknown_structure"}]},
		{"buffs": [{"id": "test_blessing", "effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, "magnitude": 1, "stacking": "additive", "duration_sec": 0, "source_structure": 42}]},
		{"buffs": [{"id": "test_blessing", "effect_type": BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, "magnitude": 1, "stacking": "additive", "duration_sec": 0, "source_structure": SHRINE_ID, "display_name": "  "}]},
	]
	for bad: Variant in bad_payloads:
		errs.clear()
		if not _check(BuffCatalog.validate_buffs_payload(bad, known_ids, errs).is_empty() and not errs.is_empty(), "Malformed buff payload rejected with a reason: %s" % str(bad).left(90)):
			return false

	# Authoritative aggregation: derived from activation facts, never stored.
	var progression: ProgressionState = ProgressionState.new()
	var domain: StructureDomain = StructureDomain.new(structure_catalog, BuffDomain.new(structure_catalog))
	if not _check(domain.get_effect_total(BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, progression) == 0, "No activated structure grants no effect"):
		return false
	if not _check(domain.buff_domain.get_effect_total(BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, []) == 0, "Empty activation evidence grants nothing (aggregation is derived, never pushed)"):
		return false
	if not _check(progression.record_fact("shrine_of_growth_activated"), "Suite3 setup: shrine activation fact recorded"):
		return false
	if not _check(domain.get_effect_total(BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, progression) == 1, "Activated shrine grants its additive buff total exactly once"):
		return false
	if not _check(domain.buff_domain.get_effect_total(BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, [SHRINE_ID, SHRINE_ID, SHRINE_ID]) == 1, "Duplicate structure IDs in the aggregation input collapse (accidental duplicate application impossible)"):
		return false
	if not _check(domain.buff_domain.get_effect_total("made_up_effect", [SHRINE_ID]) == 0, "Unknown effect type totals fail closed to 0"):
		return false
	var summaries: Array[String] = domain.get_structure_buff_summaries(SHRINE_ID)
	if not _check(summaries == ["Growth Blessing (+1)"], "Blessing summary is display-ready for feedback"):
		return false
	if not _check(domain.get_structure_buff_summaries(STATUE_ID).is_empty(), "Structures without buffs grant nothing"):
		return false
	# Re-recording the fact is idempotent: totals never accumulate.
	if not _check(progression.record_fact("shrine_of_growth_activated") and domain.get_effect_total(BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, progression) == 1, "Idempotent re-recording never accumulates the derived effect"):
		return false

	# Catalog integrity: source references must resolve into the structure set.
	var bad_ref_catalog: BuffCatalog = BuffCatalog.new()
	if not _check(bad_ref_catalog.load_from_data("res://data/buffs.json", ["some_other_structure"]) == false and bad_ref_catalog.is_empty(), "Buff catalog rejects source structures outside the provided structure set (all-or-nothing)"):
		return false
	return true


# ---------------------------------------------------------------- Suite 4 ---
func _test_resource_access() -> bool:
	var access: ResourceAccessState = ResourceAccessState.new()
	var progression: ProgressionState = ProgressionState.new()

	# Base resources: accessible with a zero balance.
	if not _check(access.is_accessible("gold", progression) and access.is_accessible("wood", progression) and access.is_accessible("stone", progression), "Base resources are explicitly accessible on a fresh reign"):
		return false
	if not _check(access.get_accessible_ids(progression) == ["gold", "stone", "wood"] and access.get_locked_ids(progression).is_empty(), "Access lists are deterministic and sorted"):
		return false
	var economy: EconomyLedger = EconomyLedger.new()
	if not _fund_wrapper(economy, 0, 0, 0):
		return false
	if not _check(access.is_accessible("wood", progression), "Zero balance while unlocked: access is NOT inferred from quantity"):
		return false

	# Unknown IDs fail closed; null progression only affects requires-based access.
	if not _check(not access.is_accessible("iron", progression) and not access.is_accessible("", progression), "Unknown or blank resource IDs are inaccessible (fail closed)"):
		return false
	if not _check(access.is_accessible("gold", null), "Base-accessible resources pass even with a null progression state"):
		return false

	# Locked resource via a test catalog: access comes only from durable facts.
	var locked_file: FileAccess = FileAccess.open(LOCKED_RESOURCES_PATH, FileAccess.WRITE)
	if not _check(locked_file != null, "Suite4 setup: locked-resources test file opened"):
		return false
	locked_file.store_string(JSON.stringify({
		"resources": [
			{"id": "gold", "base_accessible": true},
			{"id": "pearl", "unlock_requires": {"all_of": ["shrine_of_growth_activated"]}},
			{"id": "coral", "unlock_requires": {"any_of": ["shrine_of_growth_activated", "statue_of_the_first_sailor_activated"]}},
			{"id": "driftwood", "unlock_requires": {"all_of": ["forgotten_shore_first_stone_wall_tier_2"]}},
		]
	}))
	locked_file.close()
	var locked_catalog: ResourceCatalog = ResourceCatalog.new()
	if not _check(locked_catalog.load_from_data(LOCKED_RESOURCES_PATH) and not locked_catalog.is_empty(), "Test resource catalog with locked resources loads"):
		return false
	var locked_access: ResourceAccessState = ResourceAccessState.new(locked_catalog)
	if not _check(not locked_access.is_accessible("pearl", progression) and not locked_access.is_accessible("coral", progression), "Requires-based resources start locked without their facts"):
		return false
	if not _check(not locked_access.is_accessible("driftwood", progression), "Stone-Age-gated resource starts locked"):
		return false

	# Nonzero balance while locked: the ledger quantity never grants access.
	var funded: EconomyLedger = EconomyLedger.new()
	if not _fund_wrapper(funded, 5, 5, 5):
		return false
	if not _check(not locked_access.is_accessible("pearl", progression), "A funded ledger never unlocks a locked resource (quantity and access are separate systems)"):
		return false

	# Multiple valid unlock sources: either fact satisfies the any_of group.
	if not _check(progression.record_fact("shrine_of_growth_activated"), "Suite4 setup: shrine fact recorded"):
		return false
	if not _check(locked_access.is_accessible("pearl", progression) and locked_access.is_accessible("coral", progression), "Shrine activation unlocks both the all_of and any_of resources"):
		return false
	var progression_b: ProgressionState = ProgressionState.new()
	if not _check(progression_b.record_fact("statue_of_the_first_sailor_activated") and locked_access.is_accessible("coral", progression_b) and not locked_access.is_accessible("pearl", progression_b), "any_of group: the second registered unlock source satisfies the same resource independently"):
		return false
	if not _check(progression_b.record_fact(STONE_AGE_FACT) and locked_access.is_accessible("driftwood", progression_b), "Milestone facts unlock their gated resources"):
		return false

	# Definition validation: ambiguous or source-less definitions fail closed.
	var errs: Array[String] = []
	var bad_defs: Array = [
		42,
		{"no_resources": []},
		{"resources": []},
		{"resources": [{"id": "gold", "base_accessible": true, "unlock_requires": {"all_of": [STONE_AGE_FACT]}}]},
		{"resources": [{"id": "gold"}]},
		{"resources": [{"id": "Bad_ID", "base_accessible": true}]},
		{"resources": [{"id": "gold", "base_accessible": false}]},
		{"resources": [{"id": "gold", "base_accessible": "yes"}]},
		{"resources": [{"id": "gold", "base_accessible": true}, {"id": "gold", "unlock_requires": {"all_of": [STONE_AGE_FACT]}}]},
		{"resources": [{"id": "pearl", "unlock_requires": {"all_of": ["not_a_registered_fact"]}}]},
		{"resources": [{"id": "pearl", "unlock_requires": {}}]},
		{"resources": [{"id": "pearl", "unlock_requires": {"all_of": []}}]},
		{"resources": [{"id": "pearl", "extra": true}]},
	]
	for bad: Variant in bad_defs:
		errs.clear()
		if not _check(ResourceCatalog.validate_resources_payload(bad, errs).is_empty() and not errs.is_empty(), "Malformed resource payload rejected with a reason: %s" % str(bad).left(90)):
			return false

	# Legacy compatibility: an old schema-v2 save (no Phase 5 evidence at all)
	# loads and re-derives access from the restored (empty) fact set.
	var sm: SaveManager = SaveManager.new()
	var legacy_sess: ForgottenShoreSession = _fresh_session()
	if not _check(sm.save_state(legacy_sess.build_save_payload().duplicate(true), SAVE_LEGACY_PATH), "Suite4 setup: legacy session payload saved"):
		return false
	var reader: ForgottenShoreSession = _fresh_session()
	if not _check(reader.load_game_state(SAVE_LEGACY_PATH), "Legacy save loads into a fresh session"):
		return false
	if not _check(locked_access.is_accessible("gold", reader.progression) and not locked_access.is_accessible("pearl", reader.progression), "Access re-derives from restored facts: base unlocked, locked stays locked (nothing fabricated)"):
		return false
	return true


# ---------------------------------------------------------------- Suite 5 ---
func _test_session_integration_and_blessings() -> bool:
	var sess: ForgottenShoreSession = _fresh_session()
	# Tree-less sessions skip _ready/_wire_signals, so mirror the real wiring
	# for the structure domain (same pattern as the research suite).
	sess.structures.structure_activated.connect(sess._on_structure_activated)
	sess.structures.structure_action_rejected.connect(sess._record_rejection)

	# Locked shrine: the real command path rejects with feedback.
	sess.set_actor_position("player_1", SHRINE_X)
	var locked_res: Dictionary = sess.execute_world_command("player_1", &"activate_structure", SHRINE_ID)
	if not _check(not bool(locked_res.get("ok", false)) and String(locked_res.get("reason", "")).contains("not ready"), "Locked shrine activation through the session command is rejected with an actionable reason"):
		return false
	if not _check(sess.get_last_rejection_reason().contains("not ready"), "Rejection feedback recorded for the locked shrine"):
		return false

	if not _check(_grant_stone_age(sess), "Suite5 setup: Stone Age fact granted through the progression service"):
		return false

	# Resolver integration: the available shrine offers the activation command.
	var tgt: Dictionary = InteractionResolver.resolve_nearest(SHRINE_X, sess.resource_mgr, sess.building_mgr, sess.pop_mgr, sess.hearth_sys, sess.shipwreck_stage, ForgottenShoreSession.SHIPWRECK_X, ForgottenShoreSession.PORTAL_X, sess.portal_relic_looted, sess.shrine_offering_used_today, sess.tree_mgr, sess.specialists, sess.progression, sess.research_mgr, sess.structures)
	if not _check(String(tgt.get("kind", "")) == "structure" and String(tgt.get("target_id", "")) == SHRINE_ID and tgt.get("primary_command", &"") == &"activate_structure", "Resolver resolves the available shrine as a structure target with the activation command"):
		return false
	if not _check(String(tgt.get("prompt_text", "")).contains("Activate Shrine of Growth"), "Structure prompt shows the activation action and cost"):
		return false

	# Insufficient funds through the real command path (atomic rejection).
	if not _fund(sess, 1, 1, 1):
		return false
	var poor_res: Dictionary = sess.execute_world_command("player_1", &"activate_structure", SHRINE_ID)
	if not _check(not bool(poor_res.get("ok", false)) and sess.economy.get_amount(&"gold") == 1, "Insufficient-funds activation through the session command leaves balances untouched"):
		return false

	# Successful activation through the real command path.
	if not _fund(sess, 10, 10, 10):
		return false
	var ok_res: Dictionary = sess.execute_world_command("player_1", &"activate_structure", SHRINE_ID)
	if not _check(bool(ok_res.get("ok", false)), "Shrine activates through the real session command"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 6 and sess.economy.get_amount(&"wood") == 8 and sess.economy.get_amount(&"stone") == 7, "Session activation deducts exactly 4G 2W 3S"):
		return false
	if not _check(sess.progression.has_fact("shrine_of_growth_activated"), "Session activation records the durable fact"):
		return false

	# Duplicate activation through the command path: rejected, never re-spends.
	var dup_res: Dictionary = sess.execute_world_command("player_1", &"activate_structure", SHRINE_ID)
	if not _check(not bool(dup_res.get("ok", false)) and sess.economy.get_amount(&"gold") == 6, "Duplicate session activation is rejected without a second spend"):
		return false
	if not _check(String(dup_res.get("reason", "")).contains("already been activated"), "Duplicate rejection explains the already-activated state"):
		return false

	# Resolver after activation: the shrine no longer offers an interaction.
	var tgt_after: Dictionary = InteractionResolver.resolve_nearest(SHRINE_X, sess.resource_mgr, sess.building_mgr, sess.pop_mgr, sess.hearth_sys, sess.shipwreck_stage, ForgottenShoreSession.SHIPWRECK_X, ForgottenShoreSession.PORTAL_X, sess.portal_relic_looted, sess.shrine_offering_used_today, sess.tree_mgr, sess.specialists, sess.progression, sess.research_mgr, sess.structures)
	if not _check(String(tgt_after.get("kind", "")) != "structure", "Activated shrine offers no interaction target (idempotent by design)"):
		return false

	# Blessing consumer 1: wood node collection gains exactly +1.
	if not _fund(sess, 0, 0, 0):
		return false
	sess.set_actor_position("player_1", TIMBER_X)
	var col_res: Dictionary = sess.execute_world_command("player_1", &"collect", TIMBER_NODE)
	if not _check(bool(col_res.get("ok", false)) and sess.economy.get_amount(&"wood") == 6, "Timber collection with the blessing yields node amount +1 (5+1)"):
		return false
	# The node is one-shot until sunrise: collecting again must fail cleanly.
	if not _check(not bool(sess.execute_world_command("player_1", &"collect", TIMBER_NODE).get("ok", false)), "Already-collected node stays collected (existing behavior unchanged)"):
		return false

	# Blessing consumer 2: tree felling gains exactly +1 (3 chops).
	if not _fund(sess, 0, 0, 0):
		return false
	sess.set_actor_position("player_1", TREE_EAST_02_X)
	if not _check(bool(sess.execute_world_command("player_1", &"chop_tree", TREE_EAST_02).get("ok", false)), "First chop lands (east tree near the shrine)"):
		return false
	if not _check(bool(sess.execute_world_command("player_1", &"chop_tree", TREE_EAST_02).get("ok", false)), "Second chop lands"):
		return false
	var fell_res: Dictionary = sess.execute_world_command("player_1", &"chop_tree", TREE_EAST_02)
	if not _check(bool(fell_res.get("ok", false)) and sess.economy.get_amount(&"wood") == 5, "Tree felling with the blessing yields 4+1 wood through the real command path"):
		return false

	# Non-wood resources are NOT blessed.
	if not _fund(sess, 0, 0, 0):
		return false
	var stone_res: Dictionary = sess.execute_command_detailed(&"collect", -600.0, {})
	if not _check(bool(stone_res.get("ok", false)) and sess.economy.get_amount(&"stone") == 3, "Stone collection is unchanged (no cross-resource blessing)"):
		return false

	# Without the blessing the amounts are the untouched base values.
	var plain_sess: ForgottenShoreSession = _fresh_session()
	if not _fund(plain_sess, 0, 0, 0):
		return false
	plain_sess.set_actor_position("player_1", TIMBER_X)
	if not _check(bool(plain_sess.execute_world_command("player_1", &"collect", TIMBER_NODE).get("ok", false)) and plain_sess.economy.get_amount(&"wood") == 5, "Fresh session timber collection keeps the exact base amount (no blessing)"):
		return false

	# Resource access gate through the real command path (base resources pass).
	if not _check(String(sess.resource_access.catalog.get_resource("wood").get("id", "")) == "wood", "Session resource access uses the validated real catalog"):
		return false

	# HUD text is presentation-only and derived.
	if not _check(sess.structures.get_hud_text(sess.progression) == "Structures: Shrine of Growth", "HUD blessings text reflects the activated structure"):
		return false
	return true


# ---------------------------------------------------------------- Suite 6 ---
func _test_save_load_phase5_state() -> bool:
	var sm: SaveManager = SaveManager.new()

	# Round trip: activation + blessing survive save/load; costs never re-deduct.
	var src: ForgottenShoreSession = _fresh_session()
	if not _check(_grant_stone_age(src), "Suite6 setup: Stone Age fact"):
		return false
	if not _fund(src, 10, 10, 10):
		return false
	src.set_actor_position("player_1", SHRINE_X)
	if not _check(bool(src.execute_world_command("player_1", &"activate_structure", SHRINE_ID).get("ok", false)), "Suite6 setup: shrine activated"):
		return false
	var payload: Dictionary = src.build_save_payload()
	if not _check(int(payload["schema_version"]) == SaveManager.SCHEMA_VERSION and not payload.has("structures") and not payload.has("buffs") and not payload.has("resource_access"), "Schema stays version 2 with NO new Phase 5 save keys (activation rides the strictly validated facts)"):
		return false
	var pf: Dictionary = payload["progression_flags"] as Dictionary
	if not _check((pf["progression_facts"] as Array).has("shrine_of_growth_activated"), "Payload carries the activation fact inside progression_facts"):
		return false
	if not _check(sm.save_state(payload.duplicate(true), SAVE_ROUNDTRIP_PATH), "Phase 5 round-trip save written"):
		return false

	var dst: ForgottenShoreSession = _fresh_session()
	if not _fund(dst, 0, 0, 0):
		return false
	if not _check(dst.load_game_state(SAVE_ROUNDTRIP_PATH), "Phase 5 save loads into a fresh session"):
		return false
	if not _check(dst.structures.is_activated(SHRINE_ID, dst.progression), "Shrine activation restored through the fact set"):
		return false
	if not _check(dst.structures.get_effect_total(BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, dst.progression) == 1, "Derived blessing recalculated correctly after loading"):
		return false
	if not _check(dst.economy.get_amount(&"gold") == 6 and dst.economy.get_amount(&"wood") == 8 and dst.economy.get_amount(&"stone") == 7, "Restored balances match the save exactly (activation cost not deducted again)"):
		return false
	if not _check(not bool(dst.execute_world_command("player_1", &"activate_structure", SHRINE_ID).get("ok", false)) and dst.economy.get_amount(&"gold") == 6, "Duplicate activation after restore is still rejected without spending"):
		return false
	if not _check(dst.structures.get_lifecycle_state(STATUE_ID, dst.progression) == StructureDomain.STATE_AVAILABLE and not dst.structures.is_activated(STATUE_ID, dst.progression), "Statue stays a non-activated definition after restore (nothing fabricated)"):
		return false

	# Legacy save loaded into a session with NON-EMPTY Phase 5 state: the save
	# is the authority; activation facts are replaced, effects disappear.
	var legacy_donor: ForgottenShoreSession = _fresh_session()
	var legacy_payload: Dictionary = legacy_donor.build_save_payload()
	if not _check(not ((legacy_payload["progression_flags"] as Dictionary)["progression_facts"] as Array).has("shrine_of_growth_activated"), "Legacy payload carries no structure activation"):
		return false
	if not _check(sm.save_state(legacy_payload.duplicate(true), SAVE_LEGACY_PATH), "Legacy Phase 5 save written"):
		return false
	if not _fund(dst, 3, 3, 3):
		return false
	if not _check(dst.load_game_state(SAVE_LEGACY_PATH), "Legacy save loads into the Phase-5-active session (replace, not merge)"):
		return false
	if not _check(not dst.structures.is_activated(SHRINE_ID, dst.progression) and dst.structures.get_lifecycle_state(SHRINE_ID, dst.progression) == StructureDomain.STATE_LOCKED, "Loading a legacy save resets structure activation (stale runtime state replaced)"):
		return false
	if not _check(dst.structures.get_effect_total(BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, dst.progression) == 0, "No stale effect after loading a different save"):
		return false
	if not _check(dst.economy.get_amount(&"gold") == 2 and dst.economy.get_amount(&"wood") == 2 and dst.economy.get_amount(&"stone") == 1, "Balances come from the legacy payload exactly"):
		return false

	# Rollback: a later subsystem restore failure restores the previous
	# Phase 5 state through the existing snapshot mechanism.
	var victim: ForgottenShoreSession = _fresh_session()
	if not _check(_grant_stone_age(victim), "Rollback setup: Stone Age fact"):
		return false
	if not _fund(victim, 10, 10, 10):
		return false
	victim.set_actor_position("player_1", SHRINE_X)
	if not _check(bool(victim.execute_world_command("player_1", &"activate_structure", SHRINE_ID).get("ok", false)), "Rollback setup: shrine activated before the failed load"):
		return false
	victim.pop_mgr = FailOncePopulationManager.new()
	if not _check(not victim.load_game_state(SAVE_ROUNDTRIP_PATH), "Load with a failing later subsystem is rejected (transactional)"):
		return false
	if not _check(victim.structures.is_activated(SHRINE_ID, victim.progression) and victim.structures.get_effect_total(BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, victim.progression) == 1, "Rollback restores the previous activation fact and derived effect"):
		return false
	if not _check(victim.economy.get_amount(&"gold") == 6 and victim.economy.get_amount(&"wood") == 8 and victim.economy.get_amount(&"stone") == 7, "Rollback restores the previous balances exactly (no deduction during restoration)"):
		return false

	# Malformed fact arrays are rejected wholesale by strict validation.
	var malformed: Dictionary = src.build_save_payload()
	(malformed["progression_flags"] as Dictionary)["progression_facts"] = ["not_a_registered_fact"]
	if not _check(not sm.validate_payload(malformed), "Save with an unknown structure fact ID is rejected by strict validation"):
		return false
	var malformed_file: FileAccess = FileAccess.open(SAVE_MALFORMED_FACTS_PATH, FileAccess.WRITE)
	if not _check(malformed_file != null, "Malformed-facts save file opened"):
		return false
	malformed_file.store_string(JSON.stringify(malformed))
	malformed_file.close()
	var reader2: ForgottenShoreSession = _fresh_session()
	if not _fund(reader2, 1, 1, 1):
		return false
	if not _check(not reader2.load_game_state(SAVE_MALFORMED_FACTS_PATH), "Malformed facts save fails to load"):
		return false
	if not _check(not reader2.structures.is_activated(SHRINE_ID, reader2.progression) and reader2.economy.get_amount(&"gold") == 1, "Rejected save leaves the live session untouched (no partial mutation)"):
		return false
	return true


# ---------------------------------------------------------------- Suite 7 ---
func _test_existing_systems_regression() -> bool:
	var sess: ForgottenShoreSession = _fresh_session()
	sess.building_mgr.register_forgotten_shore_expansion_plots()

	# Shrine Offering keeps its exact base economy (no structure interference).
	if not _fund(sess, 10, 10, 10):
		return false
	sess.set_actor_position("player_1", -780.0)
	var col_res: Dictionary = sess.execute_world_command("player_1", &"collect", "shrine_cache_far_west")
	if not _check(bool(col_res.get("ok", false)), "Regression setup: Forgotten Shrine cache collected (gold node untouched by the access gate)"):
		return false
	var off_res: Dictionary = sess.execute_world_command("player_1", &"shrine_offering", "")
	if not _check(bool(off_res.get("ok", false)), "Shrine Offering still succeeds on the legacy path"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 15 and sess.economy.get_amount(&"wood") == 6 and sess.economy.get_amount(&"stone") == 8, "Shrine Offering keeps the exact base economy: 10G +3 cache +2 offering, 10W -4, 10S -2 (no structure interference)"):
		return false

	# Scientist recruitment + research still work with Phase 5 members live.
	if not _fund(sess, 10, 10, 10):
		return false
	if not _check(sess.specialists.try_discover(-1010.0, "scientist", sess.progression), "Specialist discovery still works"):
		return false
	if not _check(sess.building_mgr.request_start_construction(-980.0, sess.economy, "hut_scientist_01"), "Specialist hut construction still works"):
		return false
	if not _check(sess.building_mgr.advance_construction(8.0, "hut_scientist_01"), "Hut completes"):
		return false
	if not _fund(sess, 10, 10, 10):
		return false
	if not _check(sess.specialists.try_recruit(-1010.0, "scientist", sess.progression, sess.building_mgr, sess.economy), "Specialist recruitment still works"):
		return false
	if not _check(sess.research_mgr.try_start("inscription_studies", sess.progression, sess.economy), "Research start still works"):
		return false
	if not _check(sess.research_mgr.advance_research(90.0) and sess.research_mgr.is_completed("inscription_studies"), "Research still completes exactly once"):
		return false

	# Research and structure blessings stay separate sources with no double
	# granting: the tech effect never leaks into the wood-gathering path.
	if not _check(sess.research_mgr.get_effect_total(ResearchManager.EFFECT_SHRINE_OFFERING_GOLD_BONUS) == 3 and sess.structures.get_effect_total(BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, sess.progression) == 0, "Research effects and structure buffs remain independent (no duplicated technology effects)"):
		return false

	# Wall building / economy behavior unchanged.
	if not _fund(sess, 10, 10, 10):
		return false
	var build_res: Dictionary = sess.execute_command_detailed(&"build_wall", 380.0, {})
	if not _check(bool(build_res.get("ok", false)) and sess.building_mgr.get_plot("wall_east_01")["state"] == BuildingManager.WallState.UNDER_CONSTRUCTION, "Wall construction still works through the existing building system"):
		return false

	# Progression behavior: fact recording, registry membership and save array.
	if not _check(sess.progression.has_fact("scientist_recruited") and ProgressionState.is_valid_fact_id("shrine_of_growth_activated"), "New activation facts are registry members while existing facts keep recording"):
		return false
	var facts: Array = sess.progression.to_save_array()
	if not _check(facts.has("scientist_recruited") and facts.has("forgotten_shore_vessel_ready") == false, "Fact save array stays sorted/validated with the existing registry semantics"):
		return false

	# Era safety: no Iron Age path appeared with Phase 5.
	if not _check(sess.era_mgr.get_era_id() == "wood_age", "Era stays Wood Age on Forgotten Shore (no Phase 5 Iron Age leak)"):
		return false
	return true


func _init() -> void:
	var suite_names: Array[String] = [
		"Structure Catalog Validation", "Structure Lifecycle & Activation",
		"Buff Catalog & Aggregation", "Resource Access",
		"Session Integration & Blessings", "Save/Load Phase 5 State",
		"Existing Systems Regression",
	]
	var suites: Array[Callable] = [
		_test_structure_catalog_validation, _test_structure_lifecycle_and_activation,
		_test_buff_catalog_and_aggregation, _test_resource_access,
		_test_session_integration_and_blessings, _test_save_load_phase5_state,
		_test_existing_systems_regression,
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
	print("PASS: All %d Phase 5 Structure & Buff Foundation Checks completed with 0 failures across %d suites." % [_checks, suites.size()])
	quit(0)
