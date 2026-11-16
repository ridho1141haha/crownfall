class_name NarrativeState
extends RefCounted

## In-memory, per-run narrative completion state.
##
## DECIDED (docs/narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md, decision D1):
## the linear non-resumable Prologue needs no persisted narrative state, so
## this object is never serialized and never touches SaveManager or
## ProgressionState. It only guards per-run idempotence: one-shot sequences
## complete exactly once, and a replay/skip can never duplicate them.

var _completed: Dictionary = {}


func is_completed(sequence_id: String) -> bool:
	return _completed.has(sequence_id)


## Records a completion. Returns true only on the first call for an ID
## (idempotent; a duplicate is a rejected no-op, never an error).
func mark_completed(sequence_id: String) -> bool:
	if _completed.has(sequence_id):
		return false
	_completed[sequence_id] = true
	return true


func completed_count() -> int:
	return _completed.size()


func clear() -> void:
	_completed.clear()
