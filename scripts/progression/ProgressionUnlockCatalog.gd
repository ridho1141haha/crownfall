class_name ProgressionUnlockCatalog
extends RefCounted

## Phase 1 progression foundation: validated, data-driven unlock definitions.
##
## Definitions are static data (data/unlocks.json) describing what can be
## unlocked and which progression facts it requires. They are never copied into
## saves and never grant anything by themselves; evaluation is done by
## ProgressionUnlockEvaluator against ProgressionState facts.
##
## Loader contract (fail-safe, all-or-nothing):
##   - any validation error leaves the catalog EMPTY and reports the reason,
##   - missing/malformed data can never grant unlocks,
##   - duplicate definition IDs and unknown requirement fact IDs are rejected,
##   - no script expressions, no eval, no generic quest framework.

const DATA_PATH: String = "res://data/unlocks.json"

const VALID_DEFINITION_KEYS: Array[String] = ["id", "requires"]
const VALID_REQUIRE_KEYS: Array[String] = ["all_of", "any_of"]

# definition_id -> normalized definition Dictionary. Never returned by reference.
var _definitions: Dictionary = {}
var _validation_errors: Array[String] = []


func _init() -> void:
	load_from_data()


## Loads and validates a definitions file. On any error the catalog is left
## empty, the reasons are available via get_validation_errors(), and false is
## returned (missing or malformed data must not grant unlocks).
func load_from_data(path: String = DATA_PATH) -> bool:
	_definitions.clear()
	_validation_errors.clear()
	var parsed: Variant = null
	if FileAccess.file_exists(path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	else:
		_validation_errors.append("Definitions data file not found: %s" % path)
		return false
	var validated: Dictionary = validate_definitions_payload(parsed, _validation_errors)
	if not _validation_errors.is_empty():
		_definitions.clear()
		return false
	_definitions = validated
	return true


func has_definition(def_id: String) -> bool:
	return _definitions.has(def_id)


## Returns a defensive deep copy; missing IDs yield an empty Dictionary.
func get_definition(def_id: String) -> Dictionary:
	if not _definitions.has(def_id):
		return {}
	return (_definitions[def_id] as Dictionary).duplicate(true)


## Sorted copy of all definition IDs.
func get_definition_ids() -> Array[String]:
	var ids: Array[String] = []
	for def_id: Variant in _definitions.keys():
		ids.append(String(def_id))
	ids.sort()
	return ids


## Defensive deep copies of every normalized definition.
func get_all_definitions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def_id: Variant in _definitions.keys():
		out.append((_definitions[def_id] as Dictionary).duplicate(true))
	return out


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func is_empty() -> bool:
	return _definitions.is_empty()


## Pure, file-less validator so malformed payloads can be tested without
## fixtures on disk. Returns normalized definitions ({definition_id -> dict});
## on any problem returns an empty Dictionary and appends human-readable
## reasons to `errors`. Transactional: one bad definition rejects the whole set
## (partial catalogs could silently grant or silently hide unlocks).
static func validate_definitions_payload(data: Variant, errors: Array[String]) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("Definitions payload must be a JSON object")
		return {}
	var payload: Dictionary = data as Dictionary
	if not payload.has("unlocks") or typeof(payload["unlocks"]) != TYPE_ARRAY:
		errors.append("Definitions payload must contain an 'unlocks' array")
		return {}

	var raw_defs: Array = payload["unlocks"] as Array
	var validated: Dictionary = {}
	for i: int in range(raw_defs.size()):
		var entry: Variant = raw_defs[i]
		var where: String = "unlocks[%d]" % i
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("%s must be an object" % where)
			return {}
		var def: Dictionary = entry as Dictionary

		for key: Variant in def.keys():
			if String(key) not in VALID_DEFINITION_KEYS:
				errors.append("%s has unknown field '%s'" % [where, String(key)])
				return {}
		if not def.has("id"):
			errors.append("%s is missing required field 'id'" % where)
			return {}
		if not ProgressionState.is_valid_stable_id(def["id"]):
			errors.append("%s has invalid definition id: %s" % [where, str(def["id"])])
			return {}
		var def_id: String = def["id"]
		if validated.has(def_id):
			errors.append("%s duplicates definition id '%s'" % [where, def_id])
			return {}

		if not def.has("requires"):
			errors.append("'%s' is missing required field 'requires'" % def_id)
			return {}
		var requires: Variant = def["requires"]
		if typeof(requires) != TYPE_DICTIONARY:
			errors.append("'%s' requires must be an object" % def_id)
			return {}
		var req_dict: Dictionary = requires as Dictionary
		if req_dict.is_empty():
			errors.append("'%s' has empty requirement groups (would never unlock)" % def_id)
			return {}
		for key: Variant in req_dict.keys():
			if String(key) not in VALID_REQUIRE_KEYS:
				errors.append("'%s' has unknown requirement group '%s'" % [def_id, String(key)])
				return {}

		var normalized_groups: Dictionary = {}
		for group_name: String in VALID_REQUIRE_KEYS:
			if not req_dict.has(group_name):
				continue
			var group: Variant = req_dict[group_name]
			if typeof(group) != TYPE_ARRAY or (group as Array).is_empty():
				errors.append("'%s' requirement group '%s' must be a non-empty fact ID array" % [def_id, group_name])
				return {}
			var fact_ids: Array = []
			for item: Variant in (group as Array):
				if not ProgressionState.is_valid_fact_id(item):
					errors.append("'%s' requirement group '%s' references unknown or invalid fact id: %s" % [def_id, group_name, str(item)])
					return {}
				var fid: String = item
				if fact_ids.has(fid):
					errors.append("'%s' requirement group '%s' lists fact '%s' more than once" % [def_id, group_name, fid])
					return {}
				fact_ids.append(fid)
			normalized_groups[group_name] = fact_ids

		validated[def_id] = {"id": def_id, "requires": normalized_groups}
	return validated
