class_name PlayerControlLock
extends RefCounted

## Locks a control target (the Monarch) while a narrative sequence runs.
##
## DECIDED (technical design, section D4): while locked, the target's physics
## processing and unhandled-input processing are disabled, so held movement
## (Input.get_axis in _physics_process) and discrete action keys
## (E/Q/R/B/F/K in _unhandled_input) cannot reach gameplay during dialogue or
## a sequence. Both are restored by unlock(), and the runner/panel always
## release through their cleanup paths.

var _target: Node = null


## Locks the given node. Locking a different target releases the previous
## one first; locking the same target again is a no-op (idempotent).
func lock(target: Node) -> bool:
	if target == null:
		return false
	if _target == target:
		return false
	unlock()
	_target = target
	_target.set_physics_process(false)
	_target.set_process_unhandled_input(false)
	return true


## Restores physics and unhandled-input processing. Safe to call repeatedly
## and safe when the target was freed (is_instance_valid guard).
func unlock() -> void:
	if _target == null:
		return
	if is_instance_valid(_target):
		_target.set_physics_process(true)
		_target.set_process_unhandled_input(true)
	_target = null


func is_locked() -> bool:
	return _target != null
