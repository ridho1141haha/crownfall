extends SceneTree

## Phase 3 Specialist Domain Foundation test suite. Follows the repo test
## conventions: fail-fast _check helper, tab indentation, no raw engine assert
## calls, and no scene-tree child injection. Covers specialist definition
## validation (fail-safe all-or-nothing catalog), the four logically
## distinguishable lifecycle states, discovery as a separate idempotent
## operation, authoritative recruitment requirements (discovery, requirement
## facts, housing completed in the real BuildingManager, affordable cost),
## duplicate-recruitment prevention, failed-transaction atomicity, the real
## session command paths, save/load compatibility (schema v2 unchanged, facts
## and housing round-trip, legacy saves without specialists load, malformed
## data rejected), and villager-population separation.

const SP: String = "scientist"
const HUT: String = "hut_scientist_01"
const HUT_X: float = -980.0
const SCIENTIST_X: float = -1010.0
const SAVE_ROUNDTRIP_PATH: String = "user://test_specialist_roundtrip.json"
const SAVE_LEGACY_PATH: String = "user://test_specialist_legacy.json"
const SAVE_MALFORMED_PATH: String = "user://test_specialist_malformed.json"

var _failures: int = 0
var _checks: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE [test_specialist_domain]: " + msg)
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


# ---------------------------------------------------------------- Suite 1 ---
func _test_definition_validation_and_catalog() -> bool:
	var catalog: SpecialistCatalog = SpecialistCatalog.new()
	if not _check(not catalog.is_empty() and catalog.get_specialist_ids() == ["architect", "blacksmith", "scholar", "scientist"], "Specialists data file loads exactly the four roster definitions with stable unique IDs"):
		return false
	var sci: Dictionary = catalog.get_specialist(SP)
	if not _check(String(sci.get("role", "")) == "research" and String(sci.get("island_id", "")) == "forgotten_shore", "Scientist definition carries the established role and island"):
		return false
	if not _check(String(sci.get("discovery_fact", "")) == "scientist_discovered" and String(sci.get("recruitment_fact", "")) == "scientist_recruited", "Scientist definition binds the stable discovery/recruitment facts"):
		return false
	if not _check((sci.get("recruitment_cost", {}) as Dictionary) == {"gold": 3, "wood": 2}, "Scientist recruitment cost is the data-defined 3G 2W"):
		return false
	if not _check(String(sci.get("housing_plot_id", "")) == HUT and is_equal_approx(float(sci.get("world_x", 0.0)), SCIENTIST_X), "Scientist definition references its housing plot and world position"):
		return false
	var black: Dictionary = catalog.get_specialist("blacksmith")
	if not _check(String(black.get("island_id", "")) == "eldergrove_forest" and not black.has("world_x") and not black.has("housing_plot_id"), "Future-island specialists omit world position and housing (fail-closed until their islands ship)"):
		return false

	# Registry integration: specialist facts are now registered, unknown ones are not.
	if not _check(ProgressionState.is_valid_fact_id("scientist_discovered") and ProgressionState.is_valid_fact_id("scholar_recruited"), "Specialist fact IDs are registry-approved"):
		return false
	if not _check(not ProgressionState.is_valid_fact_id("mount_tamed") and ProgressionState.is_valid_stable_id("mount_tamed"), "Non-specialist well-formed IDs stay unregistered"):
		return false

	var errs: Array[String] = []
	var good: Dictionary = catalog.get_specialist("architect")

	# Malformed payloads must be rejected all-or-nothing.
	var bad_payloads: Array = [
		42,
		{"no_specialists": []},
		{"specialists": []},
		{"specialists": [42]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}, "housing_plot_id": HUT, "world_x": -1010.0, "extra_field": 1}]},
		{"specialists": [{"role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}}]},
		{"specialists": [{"id": "scientist", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}}]},
		{"specialists": [{"id": "Bad_ID", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}}]},
		{"specialists": [{"id": "scientist", "role": "wizard", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "  ", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "atlantis", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "wrong_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_joined", "recruitment_cost": {"gold": 1}}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {}}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"iron": 1}}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 0}}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": -2}}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1.5}}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}, "housing_plot_id": "Not_Valid"}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}, "requires": {"sometimes": ["scientist_discovered"]}}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}, "requires": {"all_of": []}}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}, "requires": {"all_of": ["mount_tamed"]}}]},
		{"specialists": [{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}, "requires": {"all_of": ["scientist_discovered", "scientist_discovered"]}}]},
	]
	for bad_payload: Variant in bad_payloads:
		errs.clear()
		if not _check(SpecialistCatalog.validate_specialists_payload(bad_payload, errs).is_empty() and not errs.is_empty(), "Malformed specialist payload rejected with reason: %s" % str(bad_payload)):
			return false

	# Duplicate ID rejection with a valid two-entry set.
	errs.clear()
	var dup: Dictionary = {"specialists": [
		{"id": "scientist", "role": "research", "display_name": "S", "description": "D", "island_id": "forgotten_shore", "discovery_fact": "scientist_discovered", "recruitment_fact": "scientist_recruited", "recruitment_cost": {"gold": 1}},
		{"id": "scientist", "role": "crafting", "display_name": "S2", "description": "D2", "island_id": "eldergrove_forest", "discovery_fact": "blacksmith_discovered", "recruitment_fact": "blacksmith_recruited", "recruitment_cost": {"gold": 1}},
	]}
	if not _check(SpecialistCatalog.validate_specialists_payload(dup, errs).is_empty(), "Duplicate specialist IDs rejected"):
		return false

	# A valid payload with requirement fact groups normalizes and validates.
	errs.clear()
	var valid_req: Dictionary = {"specialists": [
		{"id": "blacksmith", "role": "crafting", "display_name": "B", "description": "D", "island_id": "eldergrove_forest", "discovery_fact": "blacksmith_discovered", "recruitment_fact": "blacksmith_recruited", "recruitment_cost": {"gold": 2}, "requires": {"any_of": ["eldergrove_reached", "forgotten_shore_vessel_ready"]}},
	]}
	var validated: Dictionary = SpecialistCatalog.validate_specialists_payload(valid_req, errs)
	if not _check(not validated.is_empty() and errs.is_empty() and (validated["blacksmith"] as Dictionary).get("requires", {}) == {"any_of": ["eldergrove_reached", "forgotten_shore_vessel_ready"]}, "Valid requirement fact groups normalize and validate"):
		return false

	# All-or-nothing: one bad entry rejects the whole set.
	errs.clear()
	var mixed: Dictionary = {"specialists": [
		good,
		{"id": "bad_one", "role": "crafting", "display_name": "X", "description": "D", "island_id": "eldergrove_forest", "discovery_fact": "blacksmith_discovered", "recruitment_fact": "blacksmith_recruited", "recruitment_cost": {"gold": 0}},
	]}
	if not _check(SpecialistCatalog.validate_specialists_payload(mixed, errs).is_empty(), "One malformed entry rejects the whole definition set (no partial catalog)"):
		return false

	# get_specialist returns a defensive copy.
	var tampered: Dictionary = catalog.get_specialist(SP)
	tampered["recruitment_cost"]["gold"] = 999
	if not _check((catalog.get_specialist(SP).get("recruitment_cost", {}) as Dictionary).get("gold", 0) == 3, "get_specialist returns a defensive copy"):
		return false

	print("PASS: Specialist Definition Validation & Fail-Safe Catalog")
	return true


# ---------------------------------------------------------------- Suite 2 ---
func _test_lifecycle_and_discovery() -> bool:
	var domain: SpecialistDomain = SpecialistDomain.new()
	var progression: ProgressionState = ProgressionState.new()

	if not _check(domain.has_specialist(SP) and not domain.get_specialist_definition("unknown_one").has("id"), "Domain exposes catalog definitions; unknown IDs yield empty definitions"):
		return false
	if not _check(domain.get_lifecycle_state(SP, progression, null) == SpecialistDomain.STATE_UNDISCOVERED and not domain.is_discovered(SP, progression) and not domain.is_recruited(SP, progression), "Fresh scientist starts undiscovered and unrecruited"):
		return false
	if not _check(domain.get_lifecycle_state("unknown_one", progression, null) == SpecialistDomain.STATE_UNDISCOVERED, "Unknown specialist reports undiscovered (fail-closed)"):
		return false

	var rejected: Array = []
	domain.specialist_action_rejected.connect(func(reason: String) -> void: rejected.append(reason))
	var discovered_ids: Array = []
	domain.specialist_discovered.connect(func(sp_id: String) -> void: discovered_ids.append(sp_id))

	# Future-island specialists cannot be discovered (no world position).
	if not _check(not domain.try_discover(0.0, "blacksmith", progression) and not rejected.is_empty() and progression.fact_count() == 0, "Eldergrove specialist cannot be discovered from Forgotten Shore (no world position)"):
		return false
	if not _check(not domain.try_discover(0.0, "unknown_one", progression), "Unknown specialist discovery rejected"):
		return false

	# Wrong position: rejected, no fact, no signal.
	rejected.clear()
	if not _check(not domain.try_discover(0.0, SP, progression) and progression.fact_count() == 0 and discovered_ids.is_empty(), "Discovery at the wrong position is rejected without recording anything"):
		return false
	if not _check(not rejected.is_empty() and String(rejected[0]).contains("Move closer"), "Discovery rejection explains the required position"):
		return false

	# Correct position: discovery transaction succeeds exactly once.
	if not _check(domain.try_discover(SCIENTIST_X, SP, progression), "Discovery at the scientist position succeeds"):
		return false
	if not _check(progression.has_fact("scientist_discovered") and progression.fact_count() == 1 and discovered_ids == [SP], "Discovery records the durable fact once and emits the signal once"):
		return false

	# Idempotent repeat: success without a second signal or duplicate fact.
	if not _check(domain.try_discover(SCIENTIST_X, SP, progression) and progression.fact_count() == 1 and discovered_ids.size() == 1, "Repeated discovery is an idempotent no-op"):
		return false

	# Discovered but NOT recruitable (housing missing) and NOT recruited.
	if not _check(domain.get_lifecycle_state(SP, progression, null) == SpecialistDomain.STATE_DISCOVERED, "Discovered scientist without housing stays discovered (discovery does not imply recruitment)"):
		return false
	if not _check(not domain.is_recruitment_requirement_met(SP, progression, null), "Recruitment requirements unmet without housing"):
		return false
	if not _check(not domain.is_recruited(SP, progression), "Discovery never implies recruitment"):
		return false

	# is_any_recruited_specialist_near stays false before recruitment.
	if not _check(not domain.is_any_recruited_specialist_near(SCIENTIST_X, progression), "No recruited specialist nearby before recruitment"):
		return false

	print("PASS: Specialist Lifecycle & Discovery Transactions")
	return true


# ---------------------------------------------------------------- Suite 3 ---
func _test_housing_and_recruitment() -> bool:
	var sess: ForgottenShoreSession = _fresh_session()
	_expand_plots(sess)
	var domain: SpecialistDomain = sess.specialists
	var progression: ProgressionState = sess.progression
	var discovered_ids: Array = []
	domain.specialist_discovered.connect(func(sp_id: String) -> void: discovered_ids.append(sp_id))
	var recruited_ids: Array = []
	domain.specialist_recruited.connect(func(sp_id: String) -> void: recruited_ids.append(sp_id))

	if not _check(sess.building_mgr.has_plot(HUT), "Scientist housing plot is registered from the data-driven building config"):
		return false

	# Housing is not satisfied while the hut is only a placeholder.
	if not _check(not domain.is_housing_satisfied(SP, sess.building_mgr), "Placeholder housing plot does not satisfy the housing requirement"):
		return false
	if not _check(not domain.is_housing_satisfied("blacksmith", sess.building_mgr), "Future specialist without housing definition never satisfies housing (fail-closed)"):
		return false

	# Recruit BEFORE discovery: rejected, nothing changes.
	if not _fund(sess, 10, 10, 10):
		return false
	if not _check(not domain.try_recruit(SCIENTIST_X, SP, progression, sess.building_mgr, sess.economy), "Recruitment before discovery is rejected"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 10 and sess.economy.get_amount(&"wood") == 10 and progression.fact_count() == 0, "Failed recruitment consumes nothing and records nothing"):
		return false

	# Discover, then build the hut through the real building transactions.
	if not _check(domain.try_discover(SCIENTIST_X, SP, progression), "Suite3 setup: discovery succeeds"):
		return false
	if not _check(sess.building_mgr.request_start_construction(HUT_X, sess.economy, HUT), "Suite3 setup: hut blueprint funded"):
		return false
	if not _check(sess.building_mgr.advance_construction(8.0, HUT), "Suite3 setup: hut construction completes"):
		return false
	if not _check(domain.is_housing_satisfied(SP, sess.building_mgr), "COMPLETED hut satisfies the housing requirement"):
		return false
	if not _check(domain.get_lifecycle_state(SP, progression, sess.building_mgr) == SpecialistDomain.STATE_RECRUITABLE, "Discovered scientist with completed housing becomes recruitable"):
		return false

	# Recruitable but unaffordable: rejected with exact balances preserved.
	if not _fund(sess, 2, 10, 10):
		return false
	if not _check(not domain.try_recruit(SCIENTIST_X, SP, progression, sess.building_mgr, sess.economy), "Unaffordable recruitment is rejected"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 2 and sess.economy.get_amount(&"wood") == 10 and sess.economy.get_amount(&"stone") == 10 and progression.fact_count() == 1, "Unaffordable recruitment leaves balances and facts untouched"):
		return false

	# A destroyed hut no longer satisfies housing (recruitment fails closed).
	if not _fund(sess, 10, 10, 10):
		return false
	sess.building_mgr.apply_damage(999, HUT)
	if not _check(int(sess.building_mgr.get_plot(HUT)["state"]) == BuildingManager.WallState.DESTROYED and not domain.is_housing_satisfied(SP, sess.building_mgr), "Destroyed housing plot no longer satisfies the requirement"):
		return false
	if not _check(not domain.try_recruit(SCIENTIST_X, SP, progression, sess.building_mgr, sess.economy) and sess.economy.get_amount(&"gold") == 10, "Recruitment with destroyed housing is rejected without spending"):
		return false

	# Rebuild the destroyed hut through the real construction transactions,
	# fund exactly the recruitment cost, and recruit successfully.
	if not _fund(sess, 10, 10, 10):
		return false
	if not _check(sess.building_mgr.request_start_construction(HUT_X, sess.economy, HUT), "Suite3 setup: destroyed hut rebuilt (funded)"):
		return false
	if not _check(sess.building_mgr.advance_construction(8.0, HUT), "Suite3 setup: destroyed hut rebuilt (completed)"):
		return false
	if not _fund(sess, 3, 2, 0):
		return false
	if not _check(domain.try_recruit(SCIENTIST_X, SP, progression, sess.building_mgr, sess.economy), "Recruitment with discovery, housing and exact funds succeeds"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 0 and sess.economy.get_amount(&"wood") == 0, "Recruitment deducts exactly the data-defined cost (3G 2W)"):
		return false
	if not _check(progression.has_fact("scientist_recruited") and progression.fact_count() == 2 and recruited_ids == [SP], "Recruitment records the durable fact once and emits the signal once"):
		return false
	if not _check(domain.get_lifecycle_state(SP, progression, sess.building_mgr) == SpecialistDomain.STATE_RECRUITED and domain.is_recruited(SP, progression), "Lifecycle reaches recruited"):
		return false
	if not _check(domain.is_any_recruited_specialist_near(SCIENTIST_X, progression) and not domain.is_any_recruited_specialist_near(0.0, progression), "Recruited-specialist proximity reflects the world position"):
		return false

	# Duplicate recruitment: rejected, no double spend, no duplicate fact.
	if not _fund(sess, 10, 10, 10):
		return false
	if not _check(not domain.try_recruit(SCIENTIST_X, SP, progression, sess.building_mgr, sess.economy), "Duplicate recruitment is rejected"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 10 and recruited_ids.size() == 1 and progression.fact_count() == 2, "Duplicate recruitment never double-spends or duplicates progress"):
		return false

	print("PASS: Housing Requirement & Recruitment Transactions")
	return true


# ---------------------------------------------------------------- Suite 4 ---
func _test_session_commands_and_resolver() -> bool:
	var sess: ForgottenShoreSession = _fresh_session()
	_expand_plots(sess)
	var feedback: Array = []
	sess.feedback_message.connect(func(text: String) -> void: feedback.append(text))
	var rejected_reasons: Array = []
	sess.specialists.specialist_action_rejected.connect(func(reason: String) -> void: rejected_reasons.append(reason))
	# Tree-less sessions skip _ready/_wire_signals, so mirror the real wiring.
	sess.specialists.specialist_discovered.connect(sess._on_specialist_discovered)
	sess.specialists.specialist_recruited.connect(sess._on_specialist_recruited)
	sess.specialists.specialist_action_rejected.connect(sess._record_rejection)

	# Resolver: undiscovered scientist offers discovery, hut plot offers build.
	var tgt: Dictionary = InteractionResolver.resolve_nearest(SCIENTIST_X, sess.resource_mgr, sess.building_mgr, sess.pop_mgr, sess.hearth_sys, sess.shipwreck_stage, ForgottenShoreSession.SHIPWRECK_X, ForgottenShoreSession.PORTAL_X, sess.portal_relic_looted, sess.shrine_offering_used_today, sess.tree_mgr, sess.specialists, sess.progression)
	if not _check(String(tgt.get("kind", "")) == "specialist" and String(tgt.get("target_id", "")) == SP and String(tgt.get("primary_command", "")) == "discover_specialist", "Resolver offers discovery at the scientist position"):
		return false
	var hut_tgt: Dictionary = InteractionResolver.resolve_nearest(HUT_X, sess.resource_mgr, sess.building_mgr, sess.pop_mgr, sess.hearth_sys, sess.shipwreck_stage, ForgottenShoreSession.SHIPWRECK_X, ForgottenShoreSession.PORTAL_X, sess.portal_relic_looted, sess.shrine_offering_used_today, sess.tree_mgr, sess.specialists, sess.progression)
	if not _check(String(hut_tgt.get("kind", "")) == "building" and String(hut_tgt.get("target_id", "")) == HUT and String(hut_tgt.get("primary_command", "")) == "build", "Resolver offers the hut build at the housing plot position"):
		return false

	# Command path with an explicit target and the wrong position.
	sess.set_actor_position("player_1", 0.0)
	var wrong: Dictionary = sess.execute_world_command("player_1", &"discover_specialist", SP)
	if not _check(not bool(wrong.get("ok", false)) and not rejected_reasons.is_empty(), "Discovery command from the wrong position is rejected"):
		return false

	# Command path: discovery with explicit target and empty target.
	sess.set_actor_position("player_1", SCIENTIST_X)
	if not _check(bool(sess.execute_world_command("player_1", &"discover_specialist", SP).get("ok", false)), "Discovery world command succeeds"):
		return false
	if not _check(sess.progression.has_fact("scientist_discovered") and not feedback.is_empty(), "Discovery command records the fact and emits feedback"):
		return false
	if not _check(sess.execute_command(&"discover_specialist", SCIENTIST_X), "Discovery command with an empty target resolves the nearby scientist (idempotent)"):
		return false

	# Housing through the real build command, then recruitment command.
	if not _fund(sess, 10, 10, 10):
		return false
	sess.set_actor_position("player_1", HUT_X)
	if not _check(bool(sess.execute_world_command("player_1", &"build", HUT).get("ok", false)), "Hut build command funds the blueprint"):
		return false
	if not _check(sess.building_mgr.advance_construction(8.0, HUT), "Hut construction completes"):
		return false
	sess.set_actor_position("player_1", SCIENTIST_X)
	if not _check(bool(sess.execute_world_command("player_1", &"recruit_specialist", SP).get("ok", false)), "Recruitment world command succeeds through the real path"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 5 and sess.economy.get_amount(&"wood") == 3 and sess.progression.has_fact("scientist_recruited"), "Command recruitment deducts exactly 3G 2W and records the fact"):
		return false

	# Duplicate recruitment through the command path is rejected.
	var dup_res: Dictionary = sess.execute_world_command("player_1", &"recruit_specialist", SP)
	if not _check(not bool(dup_res.get("ok", false)) and String(dup_res.get("reason", "")).is_empty() == false, "Duplicate recruitment command is rejected with a reason"):
		return false
	if not _check(sess.economy.get_amount(&"gold") == 5, "Duplicate recruitment command never double-spends"):
		return false

	# Recruited scientist no longer offers discovery/recruit prompts.
	var after: Dictionary = InteractionResolver.resolve_nearest(SCIENTIST_X, sess.resource_mgr, sess.building_mgr, sess.pop_mgr, sess.hearth_sys, sess.shipwreck_stage, ForgottenShoreSession.SHIPWRECK_X, ForgottenShoreSession.PORTAL_X, sess.portal_relic_looted, sess.shrine_offering_used_today, sess.tree_mgr, sess.specialists, sess.progression)
	if not _check(String(after.get("kind", "")) != "specialist", "Recruited scientist offers no specialist interaction prompt"):
		return false

	# Villager recruitment regression: separate domain, unchanged behavior.
	if not _fund(sess, 10, 10, 10):
		return false
	sess.set_actor_position("player_1", NPCBuilderAgent.CAMP_POSITION_X)
	if not _check(sess.execute_command(&"recruit", NPCBuilderAgent.CAMP_POSITION_X), "Villager recruitment at the vagrant camp still works"):
		return false
	if not _check(sess.pop_mgr.get_recruited_count() == 1 and sess.pop_mgr.agents.size() == 1, "Specialists never enter the villager population roster"):
		return false
	if not _check(not sess.specialists.is_recruited("blacksmith", sess.progression), "Future-island specialists stay untouched by Forgotten Shore gameplay"):
		return false

	print("PASS: Session Commands, Resolver Integration & Population Separation")
	return true


# ---------------------------------------------------------------- Suite 5 ---
func _test_save_load_and_compatibility() -> bool:
	var sm: SaveManager = SaveManager.new()

	# Full scientist path, then a real file round-trip.
	var src: ForgottenShoreSession = _fresh_session()
	_expand_plots(src)
	if not _fund(src, 10, 10, 10):
		return false
	if not _check(src.specialists.try_discover(SCIENTIST_X, SP, src.progression), "Suite5 setup: discovery"):
		return false
	if not _check(src.building_mgr.request_start_construction(HUT_X, src.economy, HUT), "Suite5 setup: hut funded"):
		return false
	if not _check(src.building_mgr.advance_construction(8.0, HUT), "Suite5 setup: hut completed"):
		return false
	if not _fund(src, 5, 4, 1):
		return false
	if not _check(src.specialists.try_recruit(SCIENTIST_X, SP, src.progression, src.building_mgr, src.economy), "Suite5 setup: recruitment"):
		return false

	var payload: Dictionary = src.build_save_payload()
	if not _check(int(payload["schema_version"]) == SaveManager.SCHEMA_VERSION, "Schema stays version 2 with specialists"):
		return false
	if not _check(sm.validate_payload(payload), "Payload with the specialist hut, discovery and recruitment facts passes strict validation"):
		return false
	var pf: Dictionary = payload["progression_flags"] as Dictionary
	if not _check((pf["progression_facts"] as Array).size() == 2 and (pf["progression_facts"] as Array).has("scientist_recruited"), "Payload carries both specialist facts"):
		return false
	var hut_entry: Dictionary = {}
	for b: Variant in (payload["buildings"] as Array):
		if String((b as Dictionary)["id"]) == HUT:
			hut_entry = b as Dictionary
	if not _check(String(hut_entry.get("type", "")) == "specialist_hut" and String(hut_entry.get("state", "")) == "COMPLETED", "Housing plot serializes with its specialist_hut type and completed state"):
		return false

	if not _check(sm.save_state(payload.duplicate(true), SAVE_ROUNDTRIP_PATH), "Round-trip save succeeds"):
		return false
	var dst: ForgottenShoreSession = _fresh_session()
	_expand_plots(dst)
	if not _check(dst.load_game_state(SAVE_ROUNDTRIP_PATH), "Fresh session loads the specialist save"):
		return false
	if not _check(dst.specialists.is_recruited(SP, dst.progression) and dst.specialists.is_discovered(SP, dst.progression), "Discovery and recruitment facts restore transactionally"):
		return false
	if not _check(dst.specialists.get_lifecycle_state(SP, dst.progression, dst.building_mgr) == SpecialistDomain.STATE_RECRUITED, "Loaded scientist is recruited"):
		return false
	if not _check(dst.specialists.is_housing_satisfied(SP, dst.building_mgr) and int(dst.building_mgr.get_plot(HUT)["state"]) == BuildingManager.WallState.COMPLETED, "Housing state restores from the save"):
		return false

	# Legacy v2 save without specialist facts or the hut: loads fine, scientist
	# stays undiscovered, housing plot stays a fresh placeholder.
	var legacy: Dictionary = src.build_save_payload()
	var legacy_pf: Dictionary = legacy["progression_flags"] as Dictionary
	legacy_pf["progression_facts"] = ["forgotten_shore_first_stone_wall_tier_2"]
	var legacy_buildings: Array = []
	for b2: Variant in (legacy["buildings"] as Array):
		if String((b2 as Dictionary)["id"]) != HUT:
			legacy_buildings.append(b2)
	legacy["buildings"] = legacy_buildings
	var legacy_mig: Dictionary = SaveManager.migrate_payload(legacy) as Dictionary
	if not _check(sm.validate_payload(legacy_mig), "Legacy v2 payload without specialist data still validates"):
		return false
	if not _check(sm.save_state(legacy_mig.duplicate(true), SAVE_LEGACY_PATH), "Legacy save file written"):
		return false
	var legacy_sess: ForgottenShoreSession = _fresh_session()
	_expand_plots(legacy_sess)
	if not _check(legacy_sess.load_game_state(SAVE_LEGACY_PATH), "Legacy save loads into the specialist-enabled build"):
		return false
	if not _check(not legacy_sess.specialists.is_discovered(SP, legacy_sess.progression) and legacy_sess.specialists.get_lifecycle_state(SP, legacy_sess.progression, legacy_sess.building_mgr) == SpecialistDomain.STATE_UNDISCOVERED, "Legacy save keeps the scientist undiscovered"):
		return false
	if not _check(int(legacy_sess.building_mgr.get_plot(HUT)["state"]) == BuildingManager.WallState.PLACEHOLDER, "Legacy save leaves the housing plot a fresh placeholder"):
		return false

	# Malformed specialist fact data is rejected by the strict save pipeline.
	var bad: Dictionary = src.build_save_payload()
	(bad["progression_flags"] as Dictionary)["progression_facts"] = ["mount_tamed"]
	if not _check(not sm.validate_payload(SaveManager.migrate_payload(bad)), "Malformed specialist fact array (unknown ID) is rejected, not repaired"):
		return false
	var bf: FileAccess = FileAccess.open(SAVE_MALFORMED_PATH, FileAccess.WRITE)
	bf.store_string(JSON.stringify(SaveManager.migrate_payload(bad)))
	bf.close()
	var victim: ForgottenShoreSession = _fresh_session()
	_expand_plots(victim)
	var live_before: Array = victim.progression.get_fact_ids()
	if not _check(not victim.load_game_state(SAVE_MALFORMED_PATH) and victim.progression.get_fact_ids() == live_before, "Malformed specialist save fails to load without mutating live state"):
		return false

	print("PASS: Save/Load Round-Trip, Legacy Compatibility & Rejection")
	return true


func _init() -> void:
	var suite_names: Array[String] = [
		"Definition Validation & Catalog", "Lifecycle & Discovery",
		"Housing & Recruitment", "Session Commands & Resolver",
		"Save/Load & Compatibility",
	]
	var suites: Array[Callable] = [
		_test_definition_validation_and_catalog, _test_lifecycle_and_discovery,
		_test_housing_and_recruitment, _test_session_commands_and_resolver,
		_test_save_load_and_compatibility,
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
	print("PASS: All %d Specialist Domain Foundation Checks completed with 0 failures across %d suites." % [_checks, suites.size()])
	quit(0)
