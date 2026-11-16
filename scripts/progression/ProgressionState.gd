class_name ProgressionState
extends RefCounted

## Phase 1 progression foundation: durable milestone facts with stable IDs.
##
## A fact represents a player accomplishment that has actually happened
## (e.g. the first Stone Wall Tier 2 was built). Facts are:
##   - stable lowercase snake_case IDs validated against KNOWN_FACT_IDS,
##   - recorded only after the corresponding gameplay transaction succeeds,
##   - idempotent (re-recording never duplicates),
##   - never exposed as a mutable internal collection,
##   - serialized as a sorted plain Array of Strings for save payloads.
##
## Ownership (docs/PROGRESSION_FOUNDATION_DESIGN.md section 5): this service owns
## durable milestone facts only. Era advancement stays with EraProgressionManager;
## requirement evaluation stays with ProgressionUnlockEvaluator.

## Emitted only when a fact transitions from absent to present (event-driven
## evaluation hook; there is deliberately no per-frame polling API).
signal fact_recorded(fact_id: String)

## Stone Age milestone fact: the first wall plot reached Stone Wall Tier 2.
## Recorded after a successful wall upgrade transaction; era advancement itself
## remains owned by EraProgressionManager.
const FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2: String = "forgotten_shore_first_stone_wall_tier_2"

## Registry of every fact this build can record or restore. Save data and
## unlock definitions referencing IDs outside this registry are rejected, so
## unknown IDs can never be silently granted or smuggled into a save.
const KNOWN_FACT_IDS: Array[String] = [
	FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2,
]

## Stable IDs are compact; the cap only rejects absurd payloads, not future IDs.
const MAX_STABLE_ID_LENGTH: int = 64

# Internal set semantics (fact_id -> true). Never returned by reference.
var _facts: Dictionary = {}


## Pure stable-ID format check: non-empty lowercase snake_case, must start with
## a letter, no leading/trailing/consecutive underscores, no non-ASCII, bounded
## length. Shared by fact IDs and unlock definition IDs.
static func is_valid_stable_id(id: Variant) -> bool:
	if typeof(id) != TYPE_STRING:
		return false
	var s: String = id
	if s.is_empty() or s.length() > MAX_STABLE_ID_LENGTH:
		return false
	if s[0] < "a" or s[0] > "z":
		return false
	if s.ends_with("_") or s.contains("__"):
		return false
	for i: int in range(s.length()):
		var c: String = s[i]
		var is_lower: bool = c >= "a" and c <= "z"
		var is_digit: bool = c >= "0" and c <= "9"
		if not (is_lower or is_digit or c == "_"):
			return false
	return true


## Format check plus registry membership. Unknown well-formed IDs are rejected
## so typos cannot create ghost facts.
static func is_valid_fact_id(id: Variant) -> bool:
	if not is_valid_stable_id(id):
		return false
	return KNOWN_FACT_IDS.has(id)


## Strict save-array validation used by SaveManager.validate_payload and by
## apply_save_state: an Array of unique, known, well-formed fact IDs.
static func is_valid_fact_array(data: Variant) -> bool:
	if typeof(data) != TYPE_ARRAY:
		return false
	var seen: Dictionary = {}
	for item: Variant in (data as Array):
		if not is_valid_fact_id(item):
			return false
		var fid: String = item
		if seen.has(fid):
			return false
		seen[fid] = true
	return true


func has_fact(fact_id: String) -> bool:
	return _facts.has(fact_id)


## Records a fact. Returns false when the ID is malformed or unknown to the
## registry. Recording an already-present fact is a successful no-op
## (idempotent) and does not re-emit fact_recorded.
func record_fact(fact_id: Variant) -> bool:
	if not is_valid_fact_id(fact_id):
		return false
	var fid: String = fact_id
	if _facts.has(fid):
		return true
	_facts[fid] = true
	fact_recorded.emit(fid)
	return true


func fact_count() -> int:
	return _facts.size()


## Sorted copy of the recorded fact IDs (defensive duplicate of internal state).
func get_fact_ids() -> Array[String]:
	var ids: Array[String] = []
	for fid: Variant in _facts.keys():
		ids.append(String(fid))
	ids.sort()
	return ids


## Save serialization: sorted plain Array of Strings (JSON-stable, deterministic
## payload hash for unsaved-progress detection).
func to_save_array() -> Array:
	var ids: Array[String] = get_fact_ids()
	var out: Array = []
	for fid: String in ids:
		out.append(fid)
	return out


## Transactional restore. Whole-payload contract:
##   - null (field absent in an old save) -> deterministic clear, returns true;
##   - a valid fact array -> replaces all facts atomically, returns true;
##   - anything invalid -> returns false with zero mutation (no partial state).
func apply_save_state(data: Variant) -> bool:
	if data == null:
		_facts.clear()
		return true
	if not is_valid_fact_array(data):
		return false
	var next_facts: Dictionary = {}
	for item: Variant in (data as Array):
		next_facts[String(item)] = true
	_facts = next_facts
	return true
