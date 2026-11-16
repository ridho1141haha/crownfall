class_name BuffCatalog
extends RefCounted

## Phase 5 buff foundation: validated, data-driven gameplay buff definitions
## (data/buffs.json) granted by activated structures.
##
## Loading contract (mirrors the other catalogs):
##   - all-or-nothing: any validation error leaves the catalog EMPTY with
##     reasons in get_validation_errors(), so malformed data can never grant a
##     partial or ghost buff;
##   - strict field sets, stable unique IDs, a registry of effect types that
##     ONLY contains types with a real gameplay consumer (unimplemented effect
##     types are rejected — no placeholder effects that claim to work), a
##     stacking-policy whitelist, exact positive magnitudes, and a validated
##     source_structure reference into the structure catalog.
##
## Stacking policy (Phase 5 scope):
##   - "additive": the effect contributes its magnitude to the authoritative
##     total for its effect type. Duplicate application is structurally
##     impossible: BuffDomain aggregates DERIVED totals from the activation
##     facts on every query, so re-activation (impossible — one-time fact) or
##     repeated loads can never multiply an effect.
##   - "unique" and multiplicative stacking modes are deliberately NOT
##     implemented: no Phase 5 gameplay consumer requires them. Unsupported
##     values fail closed at load time.
##
## Duration policy:
##   - Phase 5 ships permanent blessings only (duration_sec == 0). Timed buffs
##     would need an authoritative world-time runtime consumer; definitions
##     with duration_sec > 0 are rejected fail-closed until that consumer
##     exists, so no data can promise an effect the runtime does not implement.
##
## Ownership: buff definitions live here; aggregation lives in BuffDomain;
## activation facts stay in ProgressionState (owned by StructureDomain
## transactions); consumers query totals — nothing writes derived values.

const DATA_PATH: String = "res://data/buffs.json"

const VALID_BUFF_KEYS: Array[String] = [
	"id",
	"effect_type",
	"magnitude",
	"stacking",
	"duration_sec",
	"source_structure",
	"display_name",
]
const REQUIRED_BUFF_KEYS: Array[String] = [
	"id",
	"effect_type",
	"magnitude",
	"stacking",
	"duration_sec",
	"source_structure",
]
const OPTIONAL_BUFF_KEYS: Array[String] = ["display_name"]

## Effect type registry. Every registered type MUST have a real gameplay
## consumer implemented in this build (same rule as TechnologyCatalog's
## KNOWN_EFFECT_IDS): registering an effect without a consumer is rejected.
## Current consumers (ForgottenShoreSession):
##   - wood_gathering_bonus: extra wood added to every wood acquisition
##     (resource-node collection and tree felling).
const KNOWN_EFFECT_TYPES: Array[String] = ["wood_gathering_bonus"]

const EFFECT_WOOD_GATHERING_BONUS: String = "wood_gathering_bonus"

const VALID_STACKING_MODES: Array[String] = ["additive"]

var _definitions: Dictionary = {}
var _validation_errors: Array[String] = []


func _init(structure_catalog: StructureCatalog = null) -> void:
	var structure_ids: Array[String] = []
	if structure_catalog != null:
		structure_ids = structure_catalog.get_structure_ids()
	load_from_data(DATA_PATH, structure_ids)


func load_from_data(path: String = DATA_PATH, known_structure_ids: Array[String] = []) -> bool:
	_definitions.clear()
	_validation_errors.clear()
	if not FileAccess.file_exists(path):
		_validation_errors.append("Buff data file not found: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		_validation_errors.append("Buff data is not a valid JSON object: %s" % path)
		return false
	var validated: Dictionary = validate_buffs_payload(parsed, known_structure_ids, _validation_errors)
	if not _validation_errors.is_empty():
		_definitions.clear()
		return false
	_definitions = validated
	return true


## Pure, file-less payload validation. Returns the normalized definition map
## (buff_id -> definition Dictionary) or an empty Dictionary after appending
## human-readable reasons to `errors`. Unknown or malformed values fail closed.
static func validate_buffs_payload(data: Variant, known_structure_ids: Array[String], errors: Array[String]) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("Buff payload must be a JSON object with a 'buffs' array")
		return {}
	var root: Dictionary = data as Dictionary
	for key: Variant in root.keys():
		if String(key) != "buffs":
			errors.append("Buff payload has unknown top-level field '%s'" % String(key))
			return {}
	if not root.has("buffs") or typeof(root["buffs"]) != TYPE_ARRAY:
		errors.append("Buff payload must contain a non-empty 'buffs' array")
		return {}
	var items: Array = root["buffs"] as Array
	if items.is_empty():
		errors.append("Buff payload must contain at least one buff definition")
		return {}

	var validated: Dictionary = {}
	for i: int in range(items.size()):
		var item: Variant = items[i]
		if typeof(item) != TYPE_DICTIONARY:
			errors.append("buffs[%d] must be an object" % i)
			return {}
		var def: Dictionary = item as Dictionary

		for key: Variant in def.keys():
			if String(key) not in VALID_BUFF_KEYS:
				errors.append("buffs[%d] has unknown field '%s'" % [i, String(key)])
				return {}
		for req_key: String in REQUIRED_BUFF_KEYS:
			if not def.has(req_key):
				errors.append("buffs[%d] is missing required field '%s'" % [i, req_key])
				return {}

		var bid_val: Variant = def["id"]
		if not ProgressionState.is_valid_stable_id(bid_val):
			errors.append("buffs[%d] has invalid or malformed id: %s" % [i, str(bid_val)])
			return {}
		var bid: String = bid_val
		if validated.has(bid):
			errors.append("Duplicate buff id: %s" % bid)
			return {}

		var effect_type: String = String(def["effect_type"])
		if not KNOWN_EFFECT_TYPES.has(effect_type):
			errors.append("'%s' references unsupported or unimplemented effect_type '%s'" % [bid, effect_type])
			return {}

		var mag_val: Variant = def["magnitude"]
		if not EconomyLedger.is_exact_int_value(mag_val) or int(roundf(float(mag_val))) <= 0:
			errors.append("'%s' magnitude must be a positive whole number" % bid)
			return {}

		var stacking: String = String(def["stacking"])
		if not VALID_STACKING_MODES.has(stacking):
			errors.append("'%s' has unsupported stacking policy '%s' (supported: %s)" % [bid, stacking, ", ".join(VALID_STACKING_MODES)])
			return {}

		var dur_val: Variant = def["duration_sec"]
		if typeof(dur_val) != TYPE_FLOAT and typeof(dur_val) != TYPE_INT:
			errors.append("'%s' duration_sec must be a number" % bid)
			return {}
		var duration: float = float(dur_val)
		if is_nan(duration) or is_inf(duration) or duration < 0.0:
			errors.append("'%s' duration_sec must be a finite non-negative number" % bid)
			return {}
		if duration > 0.0:
			# Fail-closed honesty: no timed-buff runtime consumer exists yet, so
			# timed definitions are rejected instead of being silently accepted
			# as permanent.
			errors.append("'%s' uses duration_sec %s, but timed buffs are not implemented yet; only permanent buffs (duration_sec 0) are supported" % [bid, str(dur_val)])
			return {}

		var normalized: Dictionary = {
			"id": bid,
			"effect_type": effect_type,
			"magnitude": int(roundf(float(mag_val))),
			"stacking": stacking,
			"duration_sec": duration,
			"source_structure": "",
		}

		if def.has("display_name"):
			var dn_val: Variant = def["display_name"]
			if typeof(dn_val) != TYPE_STRING or String(dn_val).strip_edges().is_empty():
				errors.append("'%s' display_name must be a non-empty string" % bid)
				return {}
			normalized["display_name"] = String(dn_val)

		var source_val: Variant = def["source_structure"]
		if not ProgressionState.is_valid_stable_id(source_val):
			errors.append("'%s' has invalid or malformed source_structure: %s" % [bid, str(source_val)])
			return {}
		var source_id: String = source_val
		if not known_structure_ids.has(source_id):
			errors.append("'%s' references unknown source_structure '%s'" % [bid, source_id])
			return {}

		normalized["source_structure"] = source_id
		validated[bid] = normalized
	return validated


func has_buff(buff_id: String) -> bool:
	return _definitions.has(buff_id)


## Deep defensive copy; unknown IDs return an empty Dictionary.
func get_buff(buff_id: String) -> Dictionary:
	if not _definitions.has(buff_id):
		return {}
	return (_definitions[buff_id] as Dictionary).duplicate(true)


func get_buff_ids() -> Array[String]:
	var ids: Array[String] = []
	for bid: Variant in _definitions.keys():
		ids.append(String(bid))
	ids.sort()
	return ids


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func is_empty() -> bool:
	return _definitions.is_empty()
