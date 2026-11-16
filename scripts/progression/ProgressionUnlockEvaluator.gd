class_name ProgressionUnlockEvaluator
extends RefCounted

## Phase 1 progression foundation: deterministic unlock requirement evaluation.
##
## Evaluates unlock definitions (from ProgressionUnlockCatalog) against
## ProgressionState facts. Semantics:
##   - "all_of": every listed fact must be present,
##   - "any_of": at least one listed fact must be present,
##   - when both are present, BOTH groups must be satisfied,
##   - empty or missing requirement groups never unlock (fail-closed),
##   - unknown requirement group keys never unlock (fail-closed),
##   - unknown fact IDs simply never match (they cannot be silently satisfied),
##   - evaluation is a pure read: it never mutates progression state.
##
## The evaluator is defensive on purpose: even a malformed definition handed to
## it directly can never return true. The catalog additionally validates
## definitions at load time, so valid catalogs only contain strict shapes.

static func is_unlock_satisfied(definition: Variant, state: ProgressionState) -> bool:
	if state == null or typeof(definition) != TYPE_DICTIONARY:
		return false
	var requires: Variant = (definition as Dictionary).get("requires", null)
	if typeof(requires) != TYPE_DICTIONARY:
		return false
	var groups: Dictionary = requires as Dictionary
	if groups.is_empty():
		return false
	for key: Variant in groups.keys():
		var group_name: String = String(key)
		if group_name == "all_of":
			if not _is_all_satisfied(groups[key], state):
				return false
		elif group_name == "any_of":
			if not _is_any_satisfied(groups[key], state):
				return false
		else:
			# Unknown requirement group: never grant (fail-closed).
			return false
	return true


static func _is_all_satisfied(group: Variant, state: ProgressionState) -> bool:
	if typeof(group) != TYPE_ARRAY or (group as Array).is_empty():
		return false
	for item: Variant in (group as Array):
		if not state.has_fact(String(item)):
			return false
	return true


static func _is_any_satisfied(group: Variant, state: ProgressionState) -> bool:
	if typeof(group) != TYPE_ARRAY or (group as Array).is_empty():
		return false
	for item: Variant in (group as Array):
		if state.has_fact(String(item)):
			return true
	return false
