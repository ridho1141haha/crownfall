class_name StructureCatalog
extends RefCounted

## Phase 5 structure foundation: validated, data-driven Shrine / Statue / Temple
## definitions (data/structures.json).
##
## Loading contract (mirrors SpecialistCatalog / TechnologyCatalog):
##   - all-or-nothing: any validation error leaves the catalog EMPTY with
##     reasons in get_validation_errors(), so malformed data can never grant a
##     partial or ghost structure;
##   - strict field sets, stable unique IDs, whitelisted categories and
##     islands, pinned activation facts validated against the registered
##     progression fact registry, and positive EconomyLedger costs;
##   - optional requirement groups reuse the shared all_of/any_of validator
##     (known fact IDs only; unknown references are rejected, never satisfied).
##
## Ownership (docs/PROGRESSION_FOUNDATION_DESIGN.md section 5): static structure
## definitions live here. Durable activation state lives in ProgressionState
## facts; activation transactions live in StructureDomain; buff effects live in
## the BuffCatalog linked by `source_structure` (single directional reference,
## so catalog validation never needs a cycle).

const DATA_PATH: String = "res://data/structures.json"

const VALID_STRUCTURE_KEYS: Array[String] = [
	"id",
	"category",
	"display_name",
	"description",
	"island_id",
	"activation_fact",
	"activation_cost",
	"world_x",
	"requires",
]
const REQUIRED_STRUCTURE_KEYS: Array[String] = [
	"id",
	"category",
	"display_name",
	"description",
	"island_id",
	"activation_fact",
	"activation_cost",
]
const OPTIONAL_STRUCTURE_KEYS: Array[String] = ["world_x", "requires"]

## The three structure categories are distinguishable by definition; they share
## the same domain infrastructure and validation rules.
const VALID_CATEGORIES: Array[String] = ["shrine", "statue", "temple"]

## Islands reuse the established specialist whitelist so no parallel island
## registry can drift out of sync.
const KNOWN_ISLAND_IDS: Array[String] = ["forgotten_shore", "eldergrove_forest", "ancient_kingdom"]

var _definitions: Dictionary = {}
var _validation_errors: Array[String] = []


func _init() -> void:
	load_from_data()


func load_from_data(path: String = DATA_PATH) -> bool:
	_definitions.clear()
	_validation_errors.clear()
	if not FileAccess.file_exists(path):
		_validation_errors.append("Structure data file not found: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		_validation_errors.append("Structure data is not a valid JSON object: %s" % path)
		return false
	var validated: Dictionary = validate_structures_payload(parsed, _validation_errors)
	if not _validation_errors.is_empty():
		_definitions.clear()
		return false
	_definitions = validated
	return true


## Pure, file-less payload validation. Returns the normalized definition map
## (definition_id -> definition Dictionary) or an empty Dictionary after
## appending human-readable reasons to `errors`. Unknown or malformed values
## fail closed: nothing is repaired, defaulted, or partially accepted.
static func validate_structures_payload(data: Variant, errors: Array[String]) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("Structure payload must be a JSON object with a 'structures' array")
		return {}
	var root: Dictionary = data as Dictionary
	for key: Variant in root.keys():
		if String(key) != "structures":
			errors.append("Structure payload has unknown top-level field '%s'" % String(key))
			return {}
	if not root.has("structures") or typeof(root["structures"]) != TYPE_ARRAY:
		errors.append("Structure payload must contain a non-empty 'structures' array")
		return {}
	var items: Array = root["structures"] as Array
	if items.is_empty():
		errors.append("Structure payload must contain at least one structure definition")
		return {}

	var validated: Dictionary = {}
	for i: int in range(items.size()):
		var item: Variant = items[i]
		if typeof(item) != TYPE_DICTIONARY:
			errors.append("structures[%d] must be an object" % i)
			return {}
		var def: Dictionary = item as Dictionary

		for key: Variant in def.keys():
			if String(key) not in VALID_STRUCTURE_KEYS:
				errors.append("structures[%d] has unknown field '%s'" % [i, String(key)])
				return {}
		for req_key: String in REQUIRED_STRUCTURE_KEYS:
			if not def.has(req_key):
				errors.append("structures[%d] is missing required field '%s'" % [i, req_key])
				return {}

		var sid_val: Variant = def["id"]
		if not ProgressionState.is_valid_stable_id(sid_val):
			errors.append("structures[%d] has invalid or malformed id: %s" % [i, str(sid_val)])
			return {}
		var sid: String = sid_val
		if validated.has(sid):
			errors.append("Duplicate structure id: %s" % sid)
			return {}

		var category: String = String(def["category"])
		if not VALID_CATEGORIES.has(category):
			errors.append("'%s' has unsupported category '%s' (expected shrine|statue|temple)" % [sid, category])
			return {}

		var display_name: String = String(def["display_name"])
		if display_name.strip_edges().is_empty():
			errors.append("'%s' display_name must be a non-empty string" % sid)
			return {}
		var description: String = String(def["description"])
		if description.strip_edges().is_empty():
			errors.append("'%s' description must be a non-empty string" % sid)
			return {}

		var island_id: String = String(def["island_id"])
		if not KNOWN_ISLAND_IDS.has(island_id):
			errors.append("'%s' references unknown island_id '%s'" % [sid, island_id])
			return {}

		# Activation facts are pinned to the stable pattern <structure_id>_activated
		# and must be registry-approved, so no unregistered fact can be smuggled in.
		var fact_val: Variant = def["activation_fact"]
		var expected_fact: String = "%s_activated" % sid
		if typeof(fact_val) != TYPE_STRING or String(fact_val) != expected_fact:
			errors.append("'%s' activation_fact must be '%s' (pinned <id>_activated pattern)" % [sid, expected_fact])
			return {}
		if not ProgressionState.is_valid_fact_id(fact_val):
			errors.append("'%s' activation_fact '%s' is not a registered progression fact" % [sid, String(fact_val)])
			return {}

		var cost_val: Variant = def["activation_cost"]
		if typeof(cost_val) != TYPE_DICTIONARY or (cost_val as Dictionary).is_empty():
			errors.append("'%s' activation_cost must be a non-empty resource dictionary" % sid)
			return {}
		var normalized_cost: Dictionary = {}
		for res_key: Variant in (cost_val as Dictionary).keys():
			var res_id: String = String(res_key)
			if not EconomyLedger.VALID_RESOURCES.has(StringName(res_id)):
				errors.append("'%s' activation_cost references unknown resource '%s'" % [sid, res_id])
				return {}
			var amount: Variant = (cost_val as Dictionary)[res_key]
			if not EconomyLedger.is_exact_int_value(amount) or int(roundf(float(amount))) <= 0:
				errors.append("'%s' activation_cost['%s'] must be a positive whole number" % [sid, res_id])
				return {}
			normalized_cost[res_id] = int(roundf(float(amount)))

		var normalized: Dictionary = {
			"id": sid,
			"category": category,
			"display_name": display_name,
			"description": description,
			"island_id": island_id,
			"activation_fact": String(fact_val),
			"activation_cost": normalized_cost,
		}

		if def.has("world_x"):
			var wx_val: Variant = def["world_x"]
			if typeof(wx_val) != TYPE_FLOAT and typeof(wx_val) != TYPE_INT:
				errors.append("'%s' world_x must be a number" % sid)
				return {}
			var wx: float = float(wx_val)
			if is_nan(wx) or is_inf(wx) or wx < WorldConstants.WORLD_MIN_X or wx > WorldConstants.WORLD_MAX_X:
				errors.append("'%s' world_x %s is outside the playable world bounds" % [sid, str(wx_val)])
				return {}
			normalized["world_x"] = wx

		if def.has("requires"):
			var req_val: Variant = def["requires"]
			if typeof(req_val) != TYPE_DICTIONARY:
				errors.append("'%s' requires must be an all_of/any_of group object" % sid)
				return {}
			if (req_val as Dictionary).is_empty():
				errors.append("'%s' requires must not be empty; a structure with no requirement groups would unlock unconditionally" % sid)
				return {}
			var groups: Dictionary = SpecialistCatalog._validate_requirement_groups(req_val as Dictionary, sid, errors)
			if groups.is_empty():
				return {}
			normalized["requires"] = groups

		validated[sid] = normalized
	return validated


func has_structure(structure_id: String) -> bool:
	return _definitions.has(structure_id)


## Deep defensive copy; unknown IDs return an empty Dictionary.
func get_structure(structure_id: String) -> Dictionary:
	if not _definitions.has(structure_id):
		return {}
	return (_definitions[structure_id] as Dictionary).duplicate(true)


func get_structure_ids() -> Array[String]:
	var ids: Array[String] = []
	for sid: Variant in _definitions.keys():
		ids.append(String(sid))
	ids.sort()
	return ids


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func is_empty() -> bool:
	return _definitions.is_empty()
