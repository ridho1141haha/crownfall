class_name ResourceCatalog
extends RefCounted

## Phase 5 resource-access foundation: validated, data-driven resource
## definitions (data/resources.json) that separate resource ACCESS from
## resource QUANTITY.
##
## The distinction is mandatory (docs/PROGRESSION_IMPLEMENTATION_ROADMAP.md
## Phase 5): a resource can be unlocked and accessible while its current
## balance is zero, and a resource can be unavailable even if an old save
## carries a nonzero balance. Availability is therefore NEVER inferred from
## EconomyLedger balances — the ledger keeps owning quantities; this catalog
## owns the access definitions.
##
## Definition contract (strictly validated, all-or-nothing):
##   - `id`: stable unique snake_case resource ID (unknown IDs fail closed at
##     query time, never implicitly accessible);
##   - exactly ONE access source per definition:
##       * `base_accessible: true` — the resource is accessible for the whole
##         Forgotten Shore vertical slice (shipped for gold/wood/stone so no
##         existing gameplay path is broken);
##       * `unlock_requires` — all_of/any_of groups of registered progression
##         facts (shared requirement validator). Multiple unlock sources for
##         one resource are expressed with `any_of`, and future sources
##         (shrine activation, milestones, research) are all expressible as
##         registered facts, so the foundation already supports them without
##         new machinery.
##   - A definition with neither source (never accessible) or both (ambiguous)
##     is invalid and rejected — fail closed instead of guessing.

const DATA_PATH: String = "res://data/resources.json"

const VALID_RESOURCE_KEYS: Array[String] = ["id", "base_accessible", "unlock_requires"]
const REQUIRED_RESOURCE_KEYS: Array[String] = ["id"]

var _definitions: Dictionary = {}
var _validation_errors: Array[String] = []


func _init() -> void:
	load_from_data()


func load_from_data(path: String = DATA_PATH) -> bool:
	_definitions.clear()
	_validation_errors.clear()
	if not FileAccess.file_exists(path):
		_validation_errors.append("Resource data file not found: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		_validation_errors.append("Resource data is not a valid JSON object: %s" % path)
		return false
	var validated: Dictionary = validate_resources_payload(parsed, _validation_errors)
	if not _validation_errors.is_empty():
		_definitions.clear()
		return false
	_definitions = validated
	return true


## Pure, file-less payload validation. Returns the normalized definition map
## (resource_id -> definition Dictionary) or an empty Dictionary after
## appending human-readable reasons to `errors`.
static func validate_resources_payload(data: Variant, errors: Array[String]) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("Resource payload must be a JSON object with a 'resources' array")
		return {}
	var root: Dictionary = data as Dictionary
	for key: Variant in root.keys():
		if String(key) != "resources":
			errors.append("Resource payload has unknown top-level field '%s'" % String(key))
			return {}
	if not root.has("resources") or typeof(root["resources"]) != TYPE_ARRAY:
		errors.append("Resource payload must contain a non-empty 'resources' array")
		return {}
	var items: Array = root["resources"] as Array
	if items.is_empty():
		errors.append("Resource payload must contain at least one resource definition")
		return {}

	var validated: Dictionary = {}
	for i: int in range(items.size()):
		var item: Variant = items[i]
		if typeof(item) != TYPE_DICTIONARY:
			errors.append("resources[%d] must be an object" % i)
			return {}
		var def: Dictionary = item as Dictionary

		for key: Variant in def.keys():
			if String(key) not in VALID_RESOURCE_KEYS:
				errors.append("resources[%d] has unknown field '%s'" % [i, String(key)])
				return {}
		for req_key: String in REQUIRED_RESOURCE_KEYS:
			if not def.has(req_key):
				errors.append("resources[%d] is missing required field 'id'" % i)
				return {}

		var rid_val: Variant = def["id"]
		if not ProgressionState.is_valid_stable_id(rid_val):
			errors.append("resources[%d] has invalid or malformed id: %s" % [i, str(rid_val)])
			return {}
		var rid: String = rid_val
		if validated.has(rid):
			errors.append("Duplicate resource id: %s" % rid)
			return {}

		var has_base: bool = def.has("base_accessible")
		var has_requires: bool = def.has("unlock_requires")
		if has_base and has_requires:
			errors.append("'%s' defines both base_accessible and unlock_requires; exactly one access source is required" % rid)
			return {}
		if not has_base and not has_requires:
			errors.append("'%s' defines neither base_accessible nor unlock_requires; a resource with no access source is invalid (fail closed)" % rid)
			return {}

		var normalized: Dictionary = {"id": rid}
		if has_base:
			var base_val: Variant = def["base_accessible"]
			if typeof(base_val) != TYPE_BOOL:
				errors.append("'%s' base_accessible must be a boolean" % rid)
				return {}
			if not bool(base_val):
				errors.append("'%s' base_accessible must be true; use unlock_requires for conditional access" % rid)
				return {}
			normalized["base_accessible"] = true
		else:
			var req_val: Variant = def["unlock_requires"]
			if typeof(req_val) != TYPE_DICTIONARY:
				errors.append("'%s' unlock_requires must be an all_of/any_of group object" % rid)
				return {}
			var groups: Dictionary = SpecialistCatalog._validate_requirement_groups(req_val as Dictionary, rid, errors)
			if groups.is_empty():
				return {}
			normalized["unlock_requires"] = groups

		validated[rid] = normalized
	return validated


func has_resource(resource_id: String) -> bool:
	return _definitions.has(resource_id)


## Deep defensive copy; unknown IDs return an empty Dictionary.
func get_resource(resource_id: String) -> Dictionary:
	if not _definitions.has(resource_id):
		return {}
	return (_definitions[resource_id] as Dictionary).duplicate(true)


func get_resource_ids() -> Array[String]:
	var ids: Array[String] = []
	for rid: Variant in _definitions.keys():
		ids.append(String(rid))
	ids.sort()
	return ids


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func is_empty() -> bool:
	return _definitions.is_empty()
