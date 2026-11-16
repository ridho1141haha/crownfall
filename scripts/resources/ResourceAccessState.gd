class_name ResourceAccessState
extends RefCounted

## Phase 5 resource-access state: deterministic, fail-closed ACCESS queries
## derived from the validated ResourceCatalog plus durable ProgressionState
## facts.
##
## Core rules (docs/PROGRESSION_IMPLEMENTATION_ROADMAP.md Phase 5):
##   - Access is NEVER inferred from EconomyLedger balances. A resource can be
##     accessible with a zero balance, and unavailable with a nonzero balance
##     carried by an old save.
##   - Access is derived from explicit, durable evidence: registered unlock
##     conditions (catalog definitions) evaluated against registered
##     progression facts. Unknown resource IDs and unknown/unregistered facts
##     fail closed (never satisfied, never granted).
##   - Evaluation never mutates state and never touches the ledger.
##   - No save fields: access is re-derived from the restored fact set after
##     every load, so old saves can never fabricate access and loading always
##     REPLACES the previous runtime answer instead of merging it.

var catalog: ResourceCatalog


func _init(catalog_override: ResourceCatalog = null) -> void:
	catalog = catalog_override if catalog_override != null else ResourceCatalog.new()


## Deterministic access evaluation:
##   - unknown resource ID -> false (fail closed);
##   - definition with base_accessible -> true;
##   - definition with unlock_requires -> the shared all_of/any_of evaluator
##     semantics over registered progression facts;
##   - null progression state -> only base-accessible resources pass.
func is_accessible(resource_id: String, progression: ProgressionState) -> bool:
	var def: Dictionary = catalog.get_resource(resource_id)
	if def.is_empty():
		return false
	if def.has("base_accessible"):
		return bool(def["base_accessible"])
	if def.has("unlock_requires"):
		if progression == null:
			return false
		return ProgressionUnlockEvaluator.is_unlock_satisfied(
			{"requires": (def["unlock_requires"] as Dictionary).duplicate(true)},
			progression
		)
	return false


## Sorted IDs of every defined resource that is currently accessible.
func get_accessible_ids(progression: ProgressionState) -> Array[String]:
	var ids: Array[String] = []
	for rid: String in catalog.get_resource_ids():
		if is_accessible(rid, progression):
			ids.append(rid)
	return ids


## Sorted IDs of every defined resource that is currently NOT accessible.
func get_locked_ids(progression: ProgressionState) -> Array[String]:
	var ids: Array[String] = []
	for rid: String in catalog.get_resource_ids():
		if not is_accessible(rid, progression):
			ids.append(rid)
	return ids
