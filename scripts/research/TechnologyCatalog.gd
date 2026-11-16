class_name TechnologyCatalog
extends RefCounted

## Phase 4 research system foundation: validated, data-driven technology
## definitions (data/technologies.json).
##
## Definitions are static data describing what can be researched, at what
## cost, for how long, and with which completion effects. They are never
## copied into saves and never grant anything by themselves; research
## requirements are evaluated by ResearchManager against ProgressionState
## facts and this catalog's prerequisite graph.
##
## Loader contract (fail-safe, all-or-nothing):
##   - any validation error leaves the catalog EMPTY and reports the reason,
##   - duplicate technology IDs, unknown prerequisite references, prerequisite
##     cycles, invalid resources/costs, non-positive durations, unknown or
##     non-positive effects and unknown requirement fact IDs are all rejected,
##   - no script expressions, no eval, no large technology tree.

const DATA_PATH: String = "res://data/technologies.json"

const VALID_TECH_KEYS: Array[String] = [
		"id", "display_name", "description", "requires", "prerequisites",
		"cost", "duration_sec", "effects",
]
const REQUIRED_TECH_KEYS: Array[String] = [
		"id", "display_name", "description", "cost", "duration_sec", "effects",
]
## Completion-effect registry: effect IDs no consumer implements are rejected
## so data can never ship a technology whose effect is silently ignored.
const KNOWN_EFFECT_IDS: Array[String] = [
		"shrine_offering_gold_bonus",
		"flare_duration_bonus_sec",
]
const VALID_REQUIRE_KEYS: Array[String] = ["all_of", "any_of"]

# technology_id -> normalized definition Dictionary. Never returned by reference.
var _definitions: Dictionary = {}
var _validation_errors: Array[String] = []


func _init() -> void:
	load_from_data()


## Loads and validates the technologies data file. On any error the catalog is
## left empty, the reasons are available via get_validation_errors(), and
## false is returned.
func load_from_data(path: String = DATA_PATH) -> bool:
	_definitions.clear()
	_validation_errors.clear()
	var parsed: Variant = null
	if FileAccess.file_exists(path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	else:
		_validation_errors.append("Technologies data file not found: %s" % path)
		return false
	var validated: Dictionary = validate_technologies_payload(parsed, _validation_errors)
	if not _validation_errors.is_empty():
		_definitions.clear()
		return false
	_definitions = validated
	return true


func has_technology(tech_id: String) -> bool:
	return _definitions.has(tech_id)


## Returns a defensive deep copy; missing IDs yield an empty Dictionary.
func get_technology(tech_id: String) -> Dictionary:
	if not _definitions.has(tech_id):
		return {}
	return (_definitions[tech_id] as Dictionary).duplicate(true)


## Sorted copy of all technology IDs (deterministic iteration order).
func get_technology_ids() -> Array[String]:
	var ids: Array[String] = []
	for def_id: Variant in _definitions.keys():
		ids.append(String(def_id))
	ids.sort()
	return ids


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func is_empty() -> bool:
	return _definitions.is_empty()


## Pure, file-less validator so malformed payloads can be tested without
## fixtures on disk. Returns normalized definitions ({technology_id -> dict});
## on any problem returns an empty Dictionary and appends human-readable
## reasons to `errors`. Transactional: one bad definition rejects the whole
## set. Prerequisite references must resolve inside the set and the graph
## must be cycle-free.
static func validate_technologies_payload(data: Variant, errors: Array[String]) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("Technologies payload must be a JSON object")
		return {}
	var payload: Dictionary = data as Dictionary
	if not payload.has("technologies") or typeof(payload["technologies"]) != TYPE_ARRAY:
		errors.append("Technologies payload must contain a 'technologies' array")
		return {}

	var raw_defs: Array = payload["technologies"] as Array
	if raw_defs.is_empty():
		errors.append("Technologies payload must contain at least one definition")
		return {}
	var validated: Dictionary = {}
	for i: int in range(raw_defs.size()):
		var entry: Variant = raw_defs[i]
		var where: String = "technologies[%d]" % i
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("%s must be an object" % where)
			return {}
		var def: Dictionary = entry as Dictionary

		for key: Variant in def.keys():
			if String(key) not in VALID_TECH_KEYS:
				errors.append("%s has unknown field '%s'" % [where, String(key)])
				return {}
		for req_key: String in REQUIRED_TECH_KEYS:
			if not def.has(req_key):
				errors.append("%s is missing required field '%s'" % [where, req_key])
				return {}

		var tech_id: String = def["id"]
		if not ProgressionState.is_valid_stable_id(tech_id):
			errors.append("%s has invalid technology id: %s" % [where, str(def["id"])])
			return {}
		if validated.has(tech_id):
			errors.append("%s duplicates technology id '%s'" % [where, tech_id])
			return {}
		if String(def["display_name"]).strip_edges().is_empty():
			errors.append("'%s' display_name must be a non-empty string" % tech_id)
			return {}
		if String(def["description"]).strip_edges().is_empty():
			errors.append("'%s' description must be a non-empty string" % tech_id)
			return {}

		var duration: float = float(def["duration_sec"])
		if typeof(def["duration_sec"]) not in [TYPE_FLOAT, TYPE_INT] or is_nan(duration) or is_inf(duration) or duration <= 0.0:
			errors.append("'%s' duration_sec must be a positive finite number" % tech_id)
			return {}

		var cost_val: Variant = def["cost"]
		if typeof(cost_val) != TYPE_DICTIONARY or (cost_val as Dictionary).is_empty():
			errors.append("'%s' cost must be a non-empty resource dictionary" % tech_id)
			return {}
		var normalized_cost: Dictionary = {}
		for raw_key: Variant in (cost_val as Dictionary).keys():
			var res_id: StringName = StringName(String(raw_key))
			if not EconomyLedger.VALID_RESOURCES.has(res_id):
				errors.append("'%s' cost references unknown resource '%s'" % [tech_id, String(raw_key)])
				return {}
			var raw_amt: Variant = (cost_val as Dictionary)[raw_key]
			if not EconomyLedger.is_exact_int_value(raw_amt) or int(roundf(float(raw_amt))) <= 0:
				errors.append("'%s' cost amount for '%s' must be a positive integer" % [tech_id, String(raw_key)])
				return {}
			normalized_cost[String(raw_key)] = int(roundf(float(raw_amt)))

		var effects_val: Variant = def["effects"]
		if typeof(effects_val) != TYPE_DICTIONARY or (effects_val as Dictionary).is_empty():
			errors.append("'%s' effects must be a non-empty effect dictionary (fake technologies are rejected)" % tech_id)
			return {}
		var normalized_effects: Dictionary = {}
		for raw_key2: Variant in (effects_val as Dictionary).keys():
			var effect_id: String = String(raw_key2)
			if effect_id not in KNOWN_EFFECT_IDS:
				errors.append("'%s' effects reference unknown effect id '%s'" % [tech_id, effect_id])
				return {}
			var raw_eff: Variant = (effects_val as Dictionary)[raw_key2]
			if not EconomyLedger.is_exact_int_value(raw_eff) or int(roundf(float(raw_eff))) <= 0:
				errors.append("'%s' effect '%s' must be a positive integer" % [tech_id, effect_id])
				return {}
			normalized_effects[effect_id] = int(roundf(float(raw_eff)))

		var normalized: Dictionary = {
			"id": tech_id,
			"display_name": String(def["display_name"]),
			"description": String(def["description"]),
			"cost": normalized_cost,
			"duration_sec": duration,
			"effects": normalized_effects,
		}

		if def.has("requires"):
			var req_val: Variant = def["requires"]
			if typeof(req_val) != TYPE_DICTIONARY or (req_val as Dictionary).is_empty():
				errors.append("'%s' requires must be a non-empty requirement object" % tech_id)
				return {}
			var groups: Dictionary = SpecialistCatalog._validate_requirement_groups(req_val as Dictionary, tech_id, errors)
			if groups.is_empty():
				return {}
			normalized["requires"] = groups

		var prereqs: Array[String] = []
		if def.has("prerequisites"):
			var pre_val: Variant = def["prerequisites"]
			if typeof(pre_val) != TYPE_ARRAY:
				errors.append("'%s' prerequisites must be an array of technology IDs" % tech_id)
				return {}
			for item: Variant in (pre_val as Array):
				if not ProgressionState.is_valid_stable_id(item):
					errors.append("'%s' prerequisites contain an invalid technology id: %s" % [tech_id, str(item)])
					return {}
				var pid: String = item
				if pid == tech_id:
					errors.append("'%s' cannot list itself as a prerequisite" % tech_id)
					return {}
				if prereqs.has(pid):
					errors.append("'%s' lists prerequisite '%s' more than once" % [tech_id, pid])
					return {}
				prereqs.append(pid)
			normalized["prerequisites"] = prereqs

		validated[tech_id] = normalized

	# Prerequisite references must exist inside the validated set.
	for tech_id2: String in validated.keys():
		var prereqs2: Array = (validated[tech_id2] as Dictionary).get("prerequisites", [])
		for pid2: Variant in prereqs2:
			if not validated.has(String(pid2)):
				errors.append("'%s' references unknown prerequisite technology '%s'" % [tech_id2, String(pid2)])
				return {}

	if _has_prerequisite_cycle(validated, errors):
		return {}
	return validated


## Depth-first cycle detection over the prerequisite graph (visited colors:
## 1 = visiting, 2 = done). Reports the offending chain in `errors`.
static func _has_prerequisite_cycle(defs: Dictionary, errors: Array[String]) -> bool:
	var state: Dictionary = {}
	var stack: Array[String] = []
	for tech_id: String in defs.keys():
		if _dfs_visit(defs, tech_id, state, stack, errors):
			return true
	return false


static func _dfs_visit(defs: Dictionary, node: String, state: Dictionary, stack: Array[String], errors: Array[String]) -> bool:
	var st: int = int(state.get(node, 0))
	if st == 2:
		return false
	if st == 1:
		stack.append(node)
		var start: int = stack.find(node)
		errors.append("Prerequisite cycle detected: %s" % " -> ".join(stack.slice(start)))
		return true
	state[node] = 1
	stack.append(node)
	for nxt: Variant in ((defs[node] as Dictionary).get("prerequisites", []) as Array):
		if _dfs_visit(defs, String(nxt), state, stack, errors):
			return true
	stack.pop_back()
	state[node] = 2
	return false
