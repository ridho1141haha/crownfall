class_name SpecialistCatalog
extends RefCounted

## Phase 3 specialist domain foundation: validated, data-driven specialist
## definitions (data/specialists.json).
##
## Definitions are static data describing the specialist roster (stable IDs,
## roles, intended islands, discovery/recruitment fact bindings, recruitment
## costs and housing plot references). They are never copied into saves and
## never grant anything by themselves; lifecycle state is derived from
## ProgressionState facts plus current building state by SpecialistDomain.
##
## Loader contract (fail-safe, all-or-nothing):
##   - any validation error leaves the catalog EMPTY and reports the reason,
##   - missing or malformed data can never make a specialist discoverable or
##     recruitable,
##   - duplicate specialist IDs and unknown fact bindings are rejected,
##   - future-island specialists may omit world_x / housing_plot_id: their
##     recruitment then fails closed (housing can never be satisfied) until
##     their islands actually exist.
##
## No script expressions, no eval, no personalities, no skill trees.

const DATA_PATH: String = "res://data/specialists.json"

const VALID_SPECIALIST_KEYS: Array[String] = [
	"id", "role", "display_name", "description", "island_id",
	"discovery_fact", "recruitment_fact", "recruitment_cost",
	"housing_plot_id", "world_x", "requires",
]
const REQUIRED_SPECIALIST_KEYS: Array[String] = [
	"id", "role", "display_name", "description", "island_id",
	"discovery_fact", "recruitment_fact", "recruitment_cost",
]
const OPTIONAL_SPECIALIST_KEYS: Array[String] = [
	"housing_plot_id", "world_x", "requires",
]
const VALID_ROLES: Array[String] = ["research", "crafting", "construction", "knowledge"]
const KNOWN_ISLAND_IDS: Array[String] = ["forgotten_shore", "eldergrove_forest", "ancient_kingdom"]
const VALID_REQUIRE_KEYS: Array[String] = ["all_of", "any_of"]

# specialist_id -> normalized definition Dictionary. Never returned by reference.
var _definitions: Dictionary = {}
var _validation_errors: Array[String] = []


func _init() -> void:
	load_from_data()


## Loads and validates the specialists data file. On any error the catalog is
## left empty, the reasons are available via get_validation_errors(), and
## false is returned.
func load_from_data(path: String = DATA_PATH) -> bool:
	_definitions.clear()
	_validation_errors.clear()
	var parsed: Variant = null
	if FileAccess.file_exists(path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	else:
		_validation_errors.append("Specialists data file not found: %s" % path)
		return false
	var validated: Dictionary = validate_specialists_payload(parsed, _validation_errors)
	if not _validation_errors.is_empty():
		_definitions.clear()
		return false
	_definitions = validated
	return true


func has_specialist(specialist_id: String) -> bool:
	return _definitions.has(specialist_id)


## Returns a defensive deep copy; missing IDs yield an empty Dictionary.
func get_specialist(specialist_id: String) -> Dictionary:
	if not _definitions.has(specialist_id):
		return {}
	return (_definitions[specialist_id] as Dictionary).duplicate(true)


## Sorted copy of all specialist IDs (deterministic iteration order).
func get_specialist_ids() -> Array[String]:
	var ids: Array[String] = []
	for def_id: Variant in _definitions.keys():
		ids.append(String(def_id))
	ids.sort()
	return ids


## Defensive deep copies of every normalized definition.
func get_all_specialists() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def_id: Variant in _definitions.keys():
		out.append((_definitions[def_id] as Dictionary).duplicate(true))
	return out


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func is_empty() -> bool:
	return _definitions.is_empty()


## Pure, file-less validator so malformed payloads can be tested without
## fixtures on disk. Returns normalized definitions ({specialist_id -> dict});
## on any problem returns an empty Dictionary and appends human-readable
## reasons to `errors`. Transactional: one bad definition rejects the whole set.
static func validate_specialists_payload(data: Variant, errors: Array[String]) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("Specialists payload must be a JSON object")
		return {}
	var payload: Dictionary = data as Dictionary
	if not payload.has("specialists") or typeof(payload["specialists"]) != TYPE_ARRAY:
		errors.append("Specialists payload must contain a 'specialists' array")
		return {}

	var raw_defs: Array = payload["specialists"] as Array
	if raw_defs.is_empty():
		errors.append("Specialists payload must contain at least one definition")
		return {}
	var validated: Dictionary = {}
	for i: int in range(raw_defs.size()):
		var entry: Variant = raw_defs[i]
		var where: String = "specialists[%d]" % i
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("%s must be an object" % where)
			return {}
		var def: Dictionary = entry as Dictionary

		for key: Variant in def.keys():
			if String(key) not in VALID_SPECIALIST_KEYS:
				errors.append("%s has unknown field '%s'" % [where, String(key)])
				return {}
		for req_key: String in REQUIRED_SPECIALIST_KEYS:
			if not def.has(req_key):
				errors.append("%s is missing required field '%s'" % [where, req_key])
				return {}

		var sp_id: String = def["id"]
		if not ProgressionState.is_valid_stable_id(sp_id):
			errors.append("%s has invalid specialist id: %s" % [where, str(def["id"])])
			return {}
		if validated.has(sp_id):
			errors.append("%s duplicates specialist id '%s'" % [where, sp_id])
			return {}

		if String(def["role"]) not in VALID_ROLES:
			errors.append("'%s' has unknown role '%s'" % [sp_id, String(def["role"])])
			return {}
		if String(def["display_name"]).strip_edges().is_empty():
			errors.append("'%s' display_name must be a non-empty string" % sp_id)
			return {}
		if String(def["description"]).strip_edges().is_empty():
			errors.append("'%s' description must be a non-empty string" % sp_id)
			return {}
		if String(def["island_id"]) not in KNOWN_ISLAND_IDS:
			errors.append("'%s' references unknown island '%s'" % [sp_id, String(def["island_id"])])
			return {}

		# Fact bindings are pinned to the stable naming convention so
		# IDs stay consistent across definitions, saves and unlocks.
		var expected_discovery: String = "%s_discovered" % sp_id
		var expected_recruit: String = "%s_recruited" % sp_id
		if String(def["discovery_fact"]) != expected_discovery or not ProgressionState.is_valid_fact_id(expected_discovery):
			errors.append("'%s' discovery_fact must be the registered fact '%s'" % [sp_id, expected_discovery])
			return {}
		if String(def["recruitment_fact"]) != expected_recruit or not ProgressionState.is_valid_fact_id(expected_recruit):
			errors.append("'%s' recruitment_fact must be the registered fact '%s'" % [sp_id, expected_recruit])
			return {}

		var cost_val: Variant = def["recruitment_cost"]
		if typeof(cost_val) != TYPE_DICTIONARY or (cost_val as Dictionary).is_empty():
			errors.append("'%s' recruitment_cost must be a non-empty resource dictionary" % sp_id)
			return {}
		var normalized_cost: Dictionary = {}
		for raw_key: Variant in (cost_val as Dictionary).keys():
			var res_id: StringName = StringName(String(raw_key))
			if not EconomyLedger.VALID_RESOURCES.has(res_id):
				errors.append("'%s' recruitment_cost references unknown resource '%s'" % [sp_id, String(raw_key)])
				return {}
			var raw_amt: Variant = (cost_val as Dictionary)[raw_key]
			if not EconomyLedger.is_exact_int_value(raw_amt) or int(roundf(float(raw_amt))) <= 0:
				errors.append("'%s' recruitment_cost amount for '%s' must be a positive integer" % [sp_id, String(raw_key)])
				return {}
			normalized_cost[String(raw_key)] = int(roundf(float(raw_amt)))

		var normalized: Dictionary = {
			"id": sp_id,
			"role": String(def["role"]),
			"display_name": String(def["display_name"]),
			"description": String(def["description"]),
			"island_id": String(def["island_id"]),
			"discovery_fact": expected_discovery,
			"recruitment_fact": expected_recruit,
			"recruitment_cost": normalized_cost,
		}

		if def.has("housing_plot_id"):
			var plot_id: String = def["housing_plot_id"]
			if not ProgressionState.is_valid_stable_id(plot_id):
				errors.append("'%s' housing_plot_id is not a valid stable id: %s" % [sp_id, str(plot_id)])
				return {}
			normalized["housing_plot_id"] = plot_id
		if def.has("world_x"):
			var wx: float = float(def["world_x"])
			if is_nan(wx) or is_inf(wx):
				errors.append("'%s' world_x must be a finite number" % sp_id)
				return {}
			normalized["world_x"] = wx
		if def.has("requires"):
			var req_val: Variant = def["requires"]
			if typeof(req_val) != TYPE_DICTIONARY or (req_val as Dictionary).is_empty():
				errors.append("'%s' requires must be a non-empty requirement object" % sp_id)
				return {}
			var groups_err: Dictionary = _validate_requirement_groups(req_val as Dictionary, sp_id, errors)
			if groups_err.is_empty():
				return {}
			normalized["requires"] = groups_err

		validated[sp_id] = normalized
	return validated


## Validates all_of/any_of fact-ID requirement groups (same semantics as the
## progression unlock catalog: known registered fact IDs, non-empty groups,
## no duplicates inside a group). Returns normalized groups, or an empty
## Dictionary after appending reasons to `errors`.
static func _validate_requirement_groups(req: Dictionary, owner_id: String, errors: Array[String]) -> Dictionary:
	for key: Variant in req.keys():
		if String(key) not in VALID_REQUIRE_KEYS:
			errors.append("'%s' has unknown requirement group '%s'" % [owner_id, String(key)])
			return {}
	var normalized: Dictionary = {}
	for group_name: String in VALID_REQUIRE_KEYS:
		if not req.has(group_name):
			continue
		var group: Variant = req[group_name]
		if typeof(group) != TYPE_ARRAY or (group as Array).is_empty():
			errors.append("'%s' requirement group '%s' must be a non-empty fact ID array" % [owner_id, group_name])
			return {}
		var fact_ids: Array = []
		for item: Variant in (group as Array):
			if not ProgressionState.is_valid_fact_id(item):
				errors.append("'%s' requirement group '%s' references unknown or invalid fact id: %s" % [owner_id, group_name, str(item)])
				return {}
			var fid: String = item
			if fact_ids.has(fid):
				errors.append("'%s' requirement group '%s' lists fact '%s' more than once" % [owner_id, group_name, fid])
				return {}
			fact_ids.append(fid)
		normalized[group_name] = fact_ids
	return normalized
