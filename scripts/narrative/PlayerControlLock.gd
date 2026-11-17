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
##
## Lock records the target state observed at lock time and unlock() restores
## exactly that state, so the pre-lock configuration survives repeated or
## consecutive lock/unlock cycles (including target switches).

var _target: Node = null
var _initial_physics: bool = true
var _initial_unhandled: bool = true
var _locked: bool = false


## Locks the given node. Locking a different target releases the previous one
## first (restoring its initial state); locking the same target again is a no-op
## (idempotent). Returns false when the target is null or already locked on it.
func lock(target: Node) -> bool:
	if target == null:
		return false
	if _locked and _target == target:
		return false
	if _locked and is_instance_valid(_target) and _target != target:
		_release_locked_target()
	_target = target
	_locked = true
	_initial_physics = _target.is_physics_processing()
	_initial_unhandled = _target.is_processing_unhandled_input()
	if is_instance_valid(_target):
		_target.set_physics_process(false)
		_target.set_process_unhandled_input(false)
	return true


## Restores the physics and unhandled-input processing the target had before
## it was locked. Safe to call repeatedly and safe when the target was freed.
func unlock() -> void:
	if not _locked:
		return
	if is_instance_valid(_target):
		_target.set_physics_process(_initial_physics)
		_target.set_process_unhandled_input(_initial_unhandled)
	_locked = false
	_target = null


## Releases the currently locked target, restoring its initial state.
func _release_locked_target() -> void:
	if is_instance_valid(_target):
		_target.set_physics_process(_initial_physics)
		_target.set_process_unhandled_input(_initial_unhandled)
	_locked = false
	_target = null


func is_locked() -> bool:
	return _locked
