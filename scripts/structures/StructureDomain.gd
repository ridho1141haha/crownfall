class_name StructureDomain
extends RefCounted

## Phase 5 structure domain: authoritative Shrine / Statue / Temple activation
## transactions over the validated StructureCatalog.
##
## Ownership boundaries (docs/PROGRESSION_FOUNDATION_DESIGN.md section 5):
##   - Static definitions live in StructureCatalog (data/structures.json).
##   - Durable activation state lives in ProgressionState facts (one pinned
##     `<structure_id>_activated` fact per structure) — the domain keeps NO
##     save fields of its own, so schema v2 stays untouched and legacy saves
##     never fabricate activations.
##   - Lifecycle states are DERIVED queries over facts + definitions, never
##     stored: locked -> available -> activated.
##   - Resource costs flow through the atomic EconomyLedger: validate ->
##     spend -> record fact. A failed activation never deducts resources or
##     mutates facts; a repeated activation is a rejected no-op that never
##     spends twice (idempotent fact guard).
##   - Buff effects granted by activated structures are aggregated by
##     BuffDomain from the activation facts (derived on every query — nothing
##     is pushed, stored, or re-applied on load).
##   - The session only forwards player requests and renders feedback; it owns
##     no activation rules.

signal structure_activated(structure_id: String)
signal structure_action_rejected(reason: String)

const STATE_LOCKED: String = "locked"
const STATE_AVAILABLE: String = "available"
const STATE_ACTIVATED: String = "activated"

const INTERACT_RANGE: float = 96.0

var catalog: StructureCatalog
var buff_domain: BuffDomain


func _init(catalog_override: StructureCatalog = null, buff_domain_override: BuffDomain = null) -> void:
	catalog = catalog_override if catalog_override != null else StructureCatalog.new()
	buff_domain = buff_domain_override if buff_domain_override != null else BuffDomain.new(catalog)


func get_structure_ids() -> Array[String]:
	return catalog.get_structure_ids()


func get_structure_definition(structure_id: String) -> Dictionary:
	return catalog.get_structure(structure_id)


func get_structure_display_name(structure_id: String) -> String:
	return String(catalog.get_structure(structure_id).get("display_name", structure_id))


func get_activation_cost(structure_id: String) -> Dictionary:
	var def: Dictionary = catalog.get_structure(structure_id)
	if def.is_empty():
		return {}
	return (def["activation_cost"] as Dictionary).duplicate()


func is_activated(structure_id: String, progression: ProgressionState) -> bool:
	var def: Dictionary = catalog.get_structure(structure_id)
	if def.is_empty() or progression == null:
		return false
	return progression.has_fact(String(def["activation_fact"]))


func get_activated_structure_ids(progression: ProgressionState) -> Array[String]:
	var ids: Array[String] = []
	for sid: String in catalog.get_structure_ids():
		if is_activated(sid, progression):
			ids.append(sid)
	return ids


func _requirements_satisfied(def: Dictionary, progression: ProgressionState) -> bool:
	if not def.has("requires"):
		return true
	return ProgressionUnlockEvaluator.is_unlock_satisfied(
		{"requires": (def["requires"] as Dictionary).duplicate(true)},
		progression
	)


## Derived lifecycle (never stored):
##   - ACTIVATED: the durable activation fact is present;
##   - AVAILABLE: requirements satisfied, awaiting the player's activation;
##   - LOCKED: requirements not met.
## Unknown structure IDs return an empty string (fail closed for queries).
func get_lifecycle_state(structure_id: String, progression: ProgressionState) -> String:
	var def: Dictionary = catalog.get_structure(structure_id)
	if def.is_empty() or progression == null:
		return ""
	if progression.has_fact(String(def["activation_fact"])):
		return STATE_ACTIVATED
	if _requirements_satisfied(def, progression):
		return STATE_AVAILABLE
	return STATE_LOCKED


## Buff effect totals granted by every activated structure. Delegates the
## authoritative aggregation to BuffDomain; unknown effect types return 0.
func get_effect_total(effect_type: String, progression: ProgressionState) -> int:
	if progression == null:
		return 0
	return buff_domain.get_effect_total(effect_type, get_activated_structure_ids(progression))


## Display-ready blessing summaries granted by one ACTIVATED structure
## (deep-derived from the BuffCatalog; presentation only — call this only
## with structures whose activation fact is present, e.g. right after a
## successful activation or for HUD summaries of activated structures).
func get_structure_buff_summaries(structure_id: String) -> Array[String]:
	return buff_domain.get_buff_summaries([structure_id])


## Display summary of activated structures and their blessings for the HUD
## (presentation only — the HUD never owns or mutates this state). Empty
## when nothing is activated.
func get_hud_text(progression: ProgressionState) -> String:
	var activated: Array[String] = get_activated_structure_ids(progression)
	if activated.is_empty():
		return ""
	var entries: Array[String] = []
	for sid: String in activated:
		var entry: String = get_structure_display_name(sid)
		var blessings: Array[String] = get_structure_buff_summaries(sid)
		if not blessings.is_empty():
			entry += " (%s)" % ", ".join(blessings)
		entries.append(entry)
	return "Structures: %s" % ", ".join(entries)


## Activation transaction. Order of operations:
##   1. Validate the definition, duplicate-activation guard, world presence,
##      active island, proximity and requirement facts (all authoritative reads).
##   2. Spend the activation cost through the atomic EconomyLedger.
##   3. Record the durable activation fact.
##   4. Emit the signal.
## A failure at any step leaves balances, facts and lifecycle untouched.
## Repeated activation is rejected BEFORE any spend, so it can never deduct
## resources a second time.
func try_activate(actor_x: float, structure_id: String, progression: ProgressionState, economy: EconomyLedger) -> bool:
	var def: Dictionary = catalog.get_structure(structure_id)
	if def.is_empty():
		structure_action_rejected.emit("Unknown structure: %s" % structure_id)
		return false
	if progression == null:
		structure_action_rejected.emit("Progression state unavailable")
		return false
	var display_name: String = String(def["display_name"])
	if progression.has_fact(String(def["activation_fact"])):
		structure_action_rejected.emit("%s has already been activated" % display_name)
		return false
	if String(def.get("island_id", "")) != SpecialistDomain.ACTIVE_ISLAND_ID:
		structure_action_rejected.emit("%s belongs to another island" % display_name)
		return false
	if not def.has("world_x"):
		structure_action_rejected.emit("%s is not present in this world yet" % display_name)
		return false
	var world_x: float = float(def["world_x"])
	if absf(actor_x - world_x) > INTERACT_RANGE:
		structure_action_rejected.emit("Move closer to %s (x=%.0f) to activate it" % [display_name, world_x])
		return false
	if not _requirements_satisfied(def, progression):
		structure_action_rejected.emit("%s is not ready to be awakened yet" % display_name)
		return false
	if economy == null:
		structure_action_rejected.emit("Economy ledger unavailable")
		return false
	var cost: Dictionary = (def["activation_cost"] as Dictionary).duplicate()
	if not economy.try_spend(cost):
		# The ledger emitted transaction_rejected with the precise
		# insufficient-resource reason; no state changed.
		structure_action_rejected.emit("Cannot afford to activate %s yet" % display_name)
		return false
	if not progression.record_fact(String(def["activation_fact"])):
		# Unreachable for validated definitions (the fact ID is
		# registry-approved at load time), but fail loud if it happens:
		# refund the committed spend so no partial activation can exist.
		economy.try_add_bundle(cost)
		structure_action_rejected.emit("Activation fact could not be recorded")
		return false
	structure_activated.emit(structure_id)
	return true
