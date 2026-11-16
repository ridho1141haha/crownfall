class_name ResearchManager
extends RefCounted

## Phase 4 research system foundation: technology requirements, transactional
## research starts, authoritative world-time progress, exactly-once
## completion, and deterministic persistence.
##
## Ownership boundaries (docs/PROGRESSION_FOUNDATION_DESIGN.md section 5):
##   - Technology definitions live in TechnologyCatalog (data/technologies.json).
##   - Research runtime state (completed technologies + the single active
##     project) lives HERE and is persisted as the optional top-level save key
##     "research" (schema stays version 2; old saves without the key load with
##     an empty research state).
##   - Requirement facts stay in ProgressionState; requirement evaluation uses
##     the existing progression evaluator semantics (all_of / any_of groups of
##     registered fact IDs). Scientist recruitment is a data-defined
##     requirement (fact scientist_recruited), not hardcoded logic.
##   - Resource costs flow through the atomic EconomyLedger: validate ->
##     spend -> start. A failed start never deducts resources; a loaded
##     active project never re-deducts its cost.
##   - The session feeds advance_research(delta) with the same scaled sim
##     delta every other world-time system uses (no UI timers, no frame
##     counting, no independent clocks).
##   - Completion applies effects exactly once: the active project is cleared
##     synchronously when it completes, and completion rewards are derived
##     (get_effect_total) from the completed set, so loading can never
##     re-apply them.

signal research_started(technology_id: String)
signal research_completed(technology_id: String)
signal research_rejected(reason: String)

const STATUS_UNAVAILABLE: String = "unavailable"
const STATUS_AVAILABLE: String = "available"
const STATUS_IN_PROGRESS: String = "in_progress"
const STATUS_COMPLETED: String = "completed"

const EFFECT_SHRINE_OFFERING_GOLD_BONUS: String = "shrine_offering_gold_bonus"
const EFFECT_FLARE_DURATION_BONUS_SEC: String = "flare_duration_bonus_sec"

var catalog: TechnologyCatalog

# tech_id -> true for completed technologies. Never returned by reference.
var _completed: Dictionary = {}
var _active_tech_id: String = ""
var _active_elapsed: float = 0.0

# Static registry of technology IDs from the validated data file (loaded once
# per process, mirroring HearthSystem's validated-tier cache pattern).
# Fail-closed: a missing or malformed data file rejects every saved ID.
static var _known_tech_ids_cache: Array[String] = []


static func _get_known_tech_ids() -> Array[String]:
	if _known_tech_ids_cache.is_empty():
		var probe: TechnologyCatalog = TechnologyCatalog.new()
		if not probe.is_empty():
			_known_tech_ids_cache = probe.get_technology_ids()
	return _known_tech_ids_cache


static func is_known_tech_id(tech_id: String) -> bool:
	return _get_known_tech_ids().has(tech_id)


func _init(catalog_override: TechnologyCatalog = null) -> void:
	catalog = catalog_override if catalog_override != null else TechnologyCatalog.new()


func get_technology_ids() -> Array[String]:
	return catalog.get_technology_ids()


func get_technology_definition(tech_id: String) -> Dictionary:
	return catalog.get_technology(tech_id)


func get_technology_display_name(tech_id: String) -> String:
	return String(catalog.get_technology(tech_id).get("display_name", tech_id))


func is_completed(tech_id: String) -> bool:
	return _completed.has(tech_id)


func get_completed_tech_ids() -> Array[String]:
	var ids: Array[String] = []
	for tech_id: Variant in _completed.keys():
		ids.append(String(tech_id))
	ids.sort()
	return ids


func has_active_research() -> bool:
	return not _active_tech_id.is_empty()


func get_active_tech_id() -> String:
	return _active_tech_id


func get_active_elapsed() -> float:
	return _active_elapsed


func get_active_progress_ratio() -> float:
	if _active_tech_id.is_empty():
		return 0.0
	var def: Dictionary = catalog.get_technology(_active_tech_id)
	var duration: float = float(def.get("duration_sec", 1.0))
	if duration <= 0.0:
		return 0.0
	return clampf(_active_elapsed / duration, 0.0, 1.0)


## Requirement evaluation: requirement fact groups (all_of / any_of, via the
## existing progression evaluator) plus prerequisite technologies.
func is_requirement_met(tech_id: String, progression: ProgressionState) -> bool:
	var def: Dictionary = catalog.get_technology(tech_id)
	if def.is_empty() or progression == null:
		return false
	if def.has("requires"):
		if not ProgressionUnlockEvaluator.is_unlock_satisfied({"requires": def["requires"].duplicate(true)}, progression):
			return false
	for pre: Variant in (def.get("prerequisites", []) as Array):
		if not _completed.has(String(pre)):
			return false
	return true


## Deterministic availability query. Exactly one project may run at a time,
## so an occupied research bench makes every other technology unavailable.
func get_research_status(tech_id: String, progression: ProgressionState) -> String:
	var def: Dictionary = catalog.get_technology(tech_id)
	if def.is_empty():
		return STATUS_UNAVAILABLE
	if _completed.has(tech_id):
		return STATUS_COMPLETED
	if _active_tech_id == tech_id:
		return STATUS_IN_PROGRESS
	if not _active_tech_id.is_empty():
		return STATUS_UNAVAILABLE
	if not is_requirement_met(tech_id, progression):
		return STATUS_UNAVAILABLE
	return STATUS_AVAILABLE


## First available technology in stable sorted-ID order (used for the empty
## interaction target and HUD queries; deterministic by construction).
func get_first_available_technology_id(progression: ProgressionState) -> String:
	for tech_id: String in catalog.get_technology_ids():
		if get_research_status(tech_id, progression) == STATUS_AVAILABLE:
			return tech_id
	return ""


## Research start transaction. Order of operations:
##   1. Validate definition, completion/duplicate guards and requirements.
##   2. Spend the cost through the atomic EconomyLedger.
##   3. Set the active project (elapsed 0) and emit the signal.
## A failure at any step leaves balances and research state untouched.
func try_start(tech_id: String, progression: ProgressionState, economy: EconomyLedger) -> bool:
	var def: Dictionary = catalog.get_technology(tech_id)
	if def.is_empty():
		research_rejected.emit("Unknown technology: %s" % tech_id)
		return false
	if _completed.has(tech_id):
		research_rejected.emit("%s has already been researched" % String(def["display_name"]))
		return false
	if not _active_tech_id.is_empty():
		research_rejected.emit("Already researching %s (one project at a time)" % get_technology_display_name(_active_tech_id))
		return false
	if not is_requirement_met(tech_id, progression):
		research_rejected.emit("Requirements for %s are not met yet" % String(def["display_name"]))
		return false
	if economy == null:
		research_rejected.emit("Economy ledger unavailable")
		return false
	if not economy.try_spend((def["cost"] as Dictionary).duplicate()):
		# The ledger emitted the precise insufficient-resource reason.
		research_rejected.emit("Cannot afford to research %s" % String(def["display_name"]))
		return false
	_active_tech_id = tech_id
	_active_elapsed = 0.0
	research_started.emit(tech_id)
	return true


## Advances the active project by authoritative world-simulation time.
## Returns true only on the frame the project completes (exactly once: the
## active project is cleared synchronously here).
func advance_research(delta: float) -> bool:
	if delta <= 0.0 or _active_tech_id.is_empty():
		return false
	var tech_id: String = _active_tech_id
	_active_elapsed += delta
	var def: Dictionary = catalog.get_technology(tech_id)
	var duration: float = float(def.get("duration_sec", 0.0))
	if duration <= 0.0 or _active_elapsed < duration:
		return false
	_completed[tech_id] = true
	_active_tech_id = ""
	_active_elapsed = 0.0
	research_completed.emit(tech_id)
	return true


## Aggregated completion effects (int amounts). Unknown effect IDs yield 0;
## only registry-approved effects can exist in validated definitions.
func get_effect_total(effect_id: String) -> int:
	var total: int = 0
	for tech_id: Variant in _completed.keys():
		var def: Dictionary = catalog.get_technology(String(tech_id))
		if def.is_empty():
			continue
		total += int((def.get("effects", {}) as Dictionary).get(effect_id, 0))
	return total


## Compact HUD summary (presentation helper; never mutates state).
func get_hud_text(progression: ProgressionState) -> String:
	if not _active_tech_id.is_empty():
		return "Research: %s (%d%%)" % [get_technology_display_name(_active_tech_id), int(roundf(get_active_progress_ratio() * 100.0))]
	var next_id: String = get_first_available_technology_id(progression)
	if not next_id.is_empty():
		return "Research available: %s" % get_technology_display_name(next_id)
	if _completed.is_empty():
		return "Research: requires a Scientist"
	return "Research: all studies complete"


## Save serialization: completed technologies (sorted) plus the active project
## with its elapsed time (deterministically snapped). Costs are NOT stored:
## they were spent when the project started and are never re-deducted on load.
func to_save_dict() -> Dictionary:
	var out: Dictionary = {"completed_techs": get_completed_tech_ids()}
	if _active_tech_id.is_empty():
		out["active_research"] = null
	else:
		out["active_research"] = {
			"technology_id": _active_tech_id,
			"elapsed_sec": snappedf(_active_elapsed, 0.001),
		}
	return out


## Strict structural validation used by SaveManager.validate_payload: known
## field set only, unique well-formed technology IDs, and an active project
## that is well-formed, finite, non-negative and not simultaneously completed.
## Catalog membership is enforced at apply time (instance-level).
static func is_valid_saved_research_dict(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data as Dictionary
	for key: Variant in d.keys():
		if String(key) not in ["completed_techs", "active_research"]:
			return false
	if not d.has("completed_techs") or typeof(d["completed_techs"]) != TYPE_ARRAY:
		return false
	var seen: Dictionary = {}
	for item: Variant in (d["completed_techs"] as Array):
		if not ProgressionState.is_valid_stable_id(item):
			return false
		var tech_id: String = item
		if seen.has(tech_id):
			return false
		if not is_known_tech_id(tech_id):
			return false
		seen[tech_id] = true
	var active: Variant = d.get("active_research", null)
	if active == null:
		return true
	if typeof(active) != TYPE_DICTIONARY:
		return false
	var a: Dictionary = active as Dictionary
	for key2: Variant in a.keys():
		if String(key2) not in ["technology_id", "elapsed_sec"]:
			return false
	if not a.has("technology_id") or not ProgressionState.is_valid_stable_id(a["technology_id"]):
		return false
	if seen.has(String(a["technology_id"])):
		return false
	if not is_known_tech_id(String(a["technology_id"])):
		return false
	if not a.has("elapsed_sec") or typeof(a["elapsed_sec"]) not in [TYPE_FLOAT, TYPE_INT]:
		return false
	var elapsed: float = float(a["elapsed_sec"])
	if is_nan(elapsed) or is_inf(elapsed) or elapsed < 0.0:
		return false
	return true


## Transactional restore. Whole-payload contract:
##   - a structurally valid payload whose IDs all exist in the catalog replaces
##     the research state atomically and returns true,
##   - anything invalid (structure, unknown technology IDs, elapsed beyond the
##     definition duration) returns false with zero mutation, so a failed load
##     can never partially mutate live research state.
func apply_save_dict(data: Variant) -> bool:
	if not is_valid_saved_research_dict(data):
		return false
	var d: Dictionary = data as Dictionary
	var completed_arr: Array = d["completed_techs"] as Array
	for item: Variant in completed_arr:
		if not catalog.has_technology(String(item)):
			return false
	var active: Variant = d.get("active_research", null)
	var next_active_id: String = ""
	var next_elapsed: float = 0.0
	if active != null:
		var a: Dictionary = active as Dictionary
		var tech_id: String = String(a["technology_id"])
		if not catalog.has_technology(tech_id):
			return false
		var elapsed: float = float(a["elapsed_sec"])
		var duration: float = float((catalog.get_technology(tech_id) as Dictionary).get("duration_sec", 0.0))
		if elapsed > duration:
			return false
		next_active_id = tech_id
		next_elapsed = elapsed
	var next_completed: Dictionary = {}
	for item2: Variant in completed_arr:
		next_completed[String(item2)] = true
	_completed = next_completed
	_active_tech_id = next_active_id
	_active_elapsed = next_elapsed
	return true
