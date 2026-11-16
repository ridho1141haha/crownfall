class_name SpecialistDomain
extends RefCounted

## Phase 3 specialist domain foundation: specialist lifecycle and transactions.
##
## Lifecycle (logically distinguishable states, derived — never stored):
##   undiscovered -> discovered -> recruitable -> recruited
##
## State ownership (docs/PROGRESSION_FOUNDATION_DESIGN.md section 5):
##   - Durable specialist accomplishments live in ProgressionState facts
##     (`<specialist>_discovered` / `<specialist>_recruited`), recorded only
##     after the corresponding gameplay transaction succeeds. Because the
##     facts are persisted and strictly validated by the existing save
##     pipeline, this domain keeps NO extra save fields of its own.
##   - Housing is current gameplay state owned by BuildingManager (the
##     specialist's housing plot must be COMPLETED).
##   - Availability is derived here from definitions + facts + building state;
##     UI never becomes the source of truth.
##
## Transaction rules:
##   - Discovery and recruitment are separate operations.
##   - Recruitment requires the authoritative checks: definition exists,
##     discovered, optional requirement facts, housing satisfied, affordable.
##   - EconomyLedger.try_spend is atomic: a failed recruitment never deducts
##     resources and never mutates progression state.
##   - Duplicate recruitment is rejected (never silently idempotent — it is a
##     paid transaction).
##   - Signals are emitted only after the state transition succeeded.

signal specialist_discovered(specialist_id: String)
signal specialist_recruited(specialist_id: String)
signal specialist_action_rejected(reason: String)

const INTERACT_RANGE: float = 96.0
const ACTIVE_ISLAND_ID: String = "forgotten_shore"

## The Scientist's housing plot id (data/buildings.json). Lives here so the
## save validator, the building data and the specialist definition share one
## stable id instead of duplicated string literals.
const SCIENTIST_HUT_PLOT_ID: String = "hut_scientist_01"

const STATE_UNDISCOVERED: String = "undiscovered"
const STATE_DISCOVERED: String = "discovered"
const STATE_RECRUITABLE: String = "recruitable"
const STATE_RECRUITED: String = "recruited"

var catalog: SpecialistCatalog


func _init(catalog_override: SpecialistCatalog = null) -> void:
	catalog = catalog_override if catalog_override != null else SpecialistCatalog.new()


func get_specialist_ids() -> Array[String]:
	return catalog.get_specialist_ids()


func has_specialist(specialist_id: String) -> bool:
	return catalog.has_specialist(specialist_id)


## Defensive copy; missing IDs yield an empty Dictionary.
func get_specialist_definition(specialist_id: String) -> Dictionary:
	return catalog.get_specialist(specialist_id)


func get_display_name(specialist_id: String) -> String:
	return String(catalog.get_specialist(specialist_id).get("display_name", ""))


func get_world_x(specialist_id: String) -> float:
	var def: Dictionary = catalog.get_specialist(specialist_id)
	if not def.has("world_x"):
		return INF
	return float(def["world_x"])


func get_recruitment_cost(specialist_id: String) -> Dictionary:
	return (catalog.get_specialist(specialist_id).get("recruitment_cost", {}) as Dictionary).duplicate()


## True when the specialist has actually been found (durable discovery fact).
func is_discovered(specialist_id: String, progression: ProgressionState) -> bool:
	var def: Dictionary = catalog.get_specialist(specialist_id)
	if def.is_empty() or progression == null:
		return false
	return progression.has_fact(String(def["discovery_fact"]))


## True when the specialist has actually joined the kingdom (durable fact).
func is_recruited(specialist_id: String, progression: ProgressionState) -> bool:
	var def: Dictionary = catalog.get_specialist(specialist_id)
	if def.is_empty() or progression == null:
		return false
	return progression.has_fact(String(def["recruitment_fact"]))


## Housing requirement (minimal, well-defined): the specialist definition may
## reference a housing plot; the plot must exist and be COMPLETED in the
## authoritative BuildingManager. A definition without housing (future island
## specialists) never satisfies housing (fail-closed) until its island ships.
func is_housing_satisfied(specialist_id: String, building_mgr: BuildingManager) -> bool:
	var def: Dictionary = catalog.get_specialist(specialist_id)
	if not def.has("housing_plot_id") or building_mgr == null:
		return false
	var plot_id: String = String(def["housing_plot_id"])
	if not building_mgr.has_plot(plot_id):
		return false
	return building_mgr.is_fully_operational(plot_id)


## Requirement facts defined on the specialist (evaluated with the existing
## progression evaluator semantics; specialists without `requires` pass).
func _requirement_facts_satisfied(def: Dictionary, progression: ProgressionState) -> bool:
	if not def.has("requires"):
		return true
	if progression == null:
		return false
	return ProgressionUnlockEvaluator.is_unlock_satisfied(
		{"requires": def["requires"].duplicate(true)}, progression)


## All recruitment requirements satisfied (discovery is a prerequisite of
## recruitment but housing/requirements decide recruitable vs discovered).
func is_recruitment_requirement_met(specialist_id: String, progression: ProgressionState, building_mgr: BuildingManager) -> bool:
	var def: Dictionary = catalog.get_specialist(specialist_id)
	if def.is_empty():
		return false
	if progression == null or not progression.has_fact(String(def["discovery_fact"])):
		return false
	if not _requirement_facts_satisfied(def, progression):
		return false
	return is_housing_satisfied(specialist_id, building_mgr)


## Deterministic lifecycle query. Unknown IDs report undiscovered (fail-closed:
## nothing about an undefined specialist can ever be claimed).
func get_lifecycle_state(specialist_id: String, progression: ProgressionState, building_mgr: BuildingManager) -> String:
	var def: Dictionary = catalog.get_specialist(specialist_id)
	if def.is_empty() or progression == null:
		return STATE_UNDISCOVERED
	if progression.has_fact(String(def["recruitment_fact"])):
		return STATE_RECRUITED
	if not progression.has_fact(String(def["discovery_fact"])):
		return STATE_UNDISCOVERED
	if _requirement_facts_satisfied(def, progression) and is_housing_satisfied(specialist_id, building_mgr):
		return STATE_RECRUITABLE
	return STATE_DISCOVERED


## Discovery transaction: records the durable discovery fact after the player
## actually finds the specialist in the world. Idempotent: discovering an
## already-discovered specialist is a successful no-op (no second signal).
## Future-island specialists (no world_x) can never be discovered here.
func try_discover(player_x: float, specialist_id: String, progression: ProgressionState) -> bool:
	var def: Dictionary = catalog.get_specialist(specialist_id)
	if def.is_empty():
		specialist_action_rejected.emit("Unknown specialist: %s" % specialist_id)
		return false
	if progression == null:
		specialist_action_rejected.emit("Progression state unavailable")
		return false
	if not def.has("world_x"):
		specialist_action_rejected.emit("%s is not present in this world" % String(def["display_name"]))
		return false
	var world_x: float = float(def["world_x"])
	if absf(player_x - world_x) > INTERACT_RANGE:
		specialist_action_rejected.emit("Move closer to %s (x=%.0f) to find them" % [String(def["display_name"]), world_x])
		return false
	var already: bool = progression.has_fact(String(def["discovery_fact"]))
	if not progression.record_fact(String(def["discovery_fact"])):
		specialist_action_rejected.emit("Discovery fact could not be recorded")
		return false
	if not already:
		specialist_discovered.emit(specialist_id)
	return true


## Recruitment transaction. Order of operations:
##   1. Validate definition, duplicate-recruitment guard, proximity, discovery,
##      requirement facts and housing (all authoritative reads).
##   2. Spend the recruitment cost through the atomic EconomyLedger.
##   3. Record the durable recruitment fact.
##   4. Emit the signal.
## A failure at any step leaves balances, facts and lifecycle untouched.
func try_recruit(player_x: float, specialist_id: String, progression: ProgressionState, building_mgr: BuildingManager, economy: EconomyLedger) -> bool:
	var def: Dictionary = catalog.get_specialist(specialist_id)
	if def.is_empty():
		specialist_action_rejected.emit("Unknown specialist: %s" % specialist_id)
		return false
	if progression == null:
		specialist_action_rejected.emit("Progression state unavailable")
		return false
	if progression.has_fact(String(def["recruitment_fact"])):
		specialist_action_rejected.emit("%s has already joined the kingdom" % String(def["display_name"]))
		return false
	if not def.has("world_x"):
		specialist_action_rejected.emit("%s is not present in this world" % String(def["display_name"]))
		return false
	var world_x: float = float(def["world_x"])
	if absf(player_x - world_x) > INTERACT_RANGE:
		specialist_action_rejected.emit("Move closer to %s (x=%.0f) to recruit them" % [String(def["display_name"]), world_x])
		return false
	if not progression.has_fact(String(def["discovery_fact"])):
		specialist_action_rejected.emit("Find %s before recruiting them" % String(def["display_name"]))
		return false
	if not _requirement_facts_satisfied(def, progression):
		specialist_action_rejected.emit("%s is not ready to join the kingdom yet" % String(def["display_name"]))
		return false
	if not is_housing_satisfied(specialist_id, building_mgr):
		specialist_action_rejected.emit("%s needs completed housing (%s) before joining" % [
			String(def["display_name"]),
			String(def.get("housing_plot_id", "a residence")),
		])
		return false
	if economy == null:
		specialist_action_rejected.emit("Economy ledger unavailable")
		return false
	var cost: Dictionary = (def["recruitment_cost"] as Dictionary).duplicate()
	if not economy.try_spend(cost):
		# The ledger emitted transaction_rejected with the precise
		# insufficient-resource reason; no state changed.
		specialist_action_rejected.emit("Cannot afford to recruit %s yet" % String(def["display_name"]))
		return false
	if not progression.record_fact(String(def["recruitment_fact"])):
		# Unreachable for validated definitions (the fact ID is
		# registry-approved at load time), but fail loud if it happens:
		# no partial recruitment may exist.
		specialist_action_rejected.emit("Recruitment fact could not be recorded")
		return false
	specialist_recruited.emit(specialist_id)
	return true


## True when any recruited specialist stands within interaction range of the
## player (used as the world-side proximity gate for research commands).
func is_any_recruited_specialist_near(player_x: float, progression: ProgressionState) -> bool:
	for sp_id: String in catalog.get_specialist_ids():
		var def: Dictionary = catalog.get_specialist(sp_id)
		if def.is_empty() or not def.has("world_x"):
			continue
		if not is_recruited(sp_id, progression):
			continue
		if absf(player_x - float(def["world_x"])) <= INTERACT_RANGE:
			return true
	return false
