class_name BuffDomain
extends RefCounted

## Phase 5 buff domain: the authoritative calculation path for gameplay buff
## effects granted by activated structures.
##
## Calculation rules:
##   - Totals are DERIVED on every query from (a) the validated buff catalog
##     and (b) the caller-provided set of activated structure IDs (which comes
##     from durable ProgressionState facts). Nothing is ever stored, pushed, or
##     re-applied: loading a save, re-ticking frames, or re-querying cannot
##     duplicate an effect, because each activated structure contributes its
##     buff exactly once per query.
##   - "additive" stacking: each matching buff adds its magnitude to the total
##     for its effect type. The catalog rejects unsupported stacking modes, so
##     an unknown mode can never reach this path.
##   - Unknown effect types return 0 (fail closed for consumers' typos).
##   - Duplicate structure IDs in the input are collapsed: aggregation iterates
##     the activation SET semantics (a structure id contributes once), so even
##     a malformed caller list cannot double an effect.
##
## Ownership: definitions live in BuffCatalog; durable activation evidence
## (facts) stays in ProgressionState; consumers (session gameplay paths) query
## totals. No save fields: permanent buffs are re-derived after every load.

var catalog: BuffCatalog


func _init(structure_catalog: StructureCatalog = null, buff_catalog_override: BuffCatalog = null) -> void:
	if buff_catalog_override != null:
		catalog = buff_catalog_override
	else:
		catalog = BuffCatalog.new(structure_catalog)


## Buff definitions whose source is the given structure (deep copies).
func get_buffs_for_structure(structure_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for bid: String in catalog.get_buff_ids():
		var def: Dictionary = catalog.get_buff(bid)
		if String(def.get("source_structure", "")) == structure_id:
			out.append(def)
	return out


## Authoritative additive aggregation for one effect type over the activated
## structure set. Deterministic: definitions are iterated in sorted buff-ID
## order, so the result never depends on dictionary ordering.
func get_effect_total(effect_type: String, activated_structure_ids: Array[String]) -> int:
	if not BuffCatalog.KNOWN_EFFECT_TYPES.has(effect_type):
		return 0
	var activated: Dictionary = {}
	for sid: String in activated_structure_ids:
		activated[sid] = true
	var total: int = 0
	for bid: String in catalog.get_buff_ids():
		var def: Dictionary = catalog.get_buff(bid)
		if String(def.get("effect_type", "")) != effect_type:
			continue
		var source: String = String(def.get("source_structure", ""))
		if not activated.has(source):
			continue
		if String(def.get("stacking", "")) == "additive":
			total += int(def.get("magnitude", 0))
	return total


## Human-readable blessing summaries for the given activated structure set
## (empty input -> empty output; callers pass real activation evidence).
## Values are derived on the fly, never cached.
func get_buff_summaries(activated_structure_ids: Array[String]) -> Array[String]:
	var activated: Dictionary = {}
	for sid: String in activated_structure_ids:
		activated[sid] = true
	var summaries: Array[String] = []
	for bid: String in catalog.get_buff_ids():
		var def: Dictionary = catalog.get_buff(bid)
		if not activated.has(String(def.get("source_structure", ""))):
			continue
		var label: String = String(def.get("display_name", bid))
		summaries.append("%s (+%d)" % [label, int(def.get("magnitude", 0))])
	return summaries
