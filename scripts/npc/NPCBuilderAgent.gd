class_name NPCBuilderAgent
extends RefCounted

signal npc_state_changed(npc_id: String, role: String, state_name: String, position_x: float)
signal task_released(npc_id: String, task_id: String, reason: String)
signal safety_path_failed(npc_id: String, reason: String)
signal recruitment_rejected(reason: String)

enum State {
	UNRECRUITED,
	IDLE,
	MOVING_TO_TASK,
	WORKING,
	RETURNING_TO_SAFETY,
}

const NPC_ID: String = "npc_01"
const RECRUIT_COST: Dictionary = {"gold": 2}
const CAMP_POSITION_X: float = -220.0
const SAFE_ZONE_X: float = 0.0
const MOVE_SPEED: float = 130.0
const WORK_RANGE: float = 28.0
const REPAIR_RATE_PER_SEC: float = 18.0

var recruited: bool = false
var role: String = "villager"
var state: State = State.UNRECRUITED
var position_x: float = CAMP_POSITION_X
var assigned_task_id: String = ""
var cached_target_x: float = SAFE_ZONE_X
var safety_override_active: bool = false
var navigation_blocked: bool = false
var _repair_accumulator: float = 0.0


func get_state_name() -> String:
	match state:
		State.UNRECRUITED:
			return "UNRECRUITED"
		State.IDLE:
			return "IDLE"
		State.MOVING_TO_TASK:
			return "MOVING_TO_TASK"
		State.WORKING:
			return "WORKING"
		State.RETURNING_TO_SAFETY:
			return "RETURNING_TO_SAFETY"
	return "IDLE"


func request_recruit(player_x: float, ledger: EconomyLedger) -> bool:
	if recruited:
		recruitment_rejected.emit("Villager is already recruited as Builder")
		return false
	if ledger == null:
		recruitment_rejected.emit("Economy ledger unavailable")
		return false
	if absf(player_x - CAMP_POSITION_X) > 96.0:
		recruitment_rejected.emit("Move closer to Vagrant Camp (x=%.0f) to recruit" % CAMP_POSITION_X)
		return false
	if not ledger.try_spend(RECRUIT_COST):
		recruitment_rejected.emit("Need 2 Gold to recruit Villager")
		return false

	recruited = true
	role = "builder"
	state = State.IDLE
	assigned_task_id = ""
	cached_target_x = SAFE_ZONE_X
	_emit_state()
	return true


func set_dusk_or_night_safety(is_unsafe_phase: bool) -> void:
	safety_override_active = is_unsafe_phase
	if not recruited:
		return
	if safety_override_active:
		if not assigned_task_id.is_empty():
			_release_task("dusk_safety_override")
		state = State.RETURNING_TO_SAFETY
		cached_target_x = SAFE_ZONE_X
		_emit_state()


func validate_current_task(building_mgr: BuildingManager) -> bool:
	if assigned_task_id.is_empty() or building_mgr == null:
		return false
	if not building_mgr.has_plot(assigned_task_id):
		_release_task("target_missing")
		return false
	if not building_mgr.is_plot_needing_work(assigned_task_id):
		_release_task("task_completed_or_cancelled")
		return false
	return true


func tick(delta: float, building_mgr: BuildingManager) -> void:
	if not recruited or delta <= 0.0:
		return

	# Priority 1: Immediate Dusk/Night Safety Override (never silently teleport)
	if safety_override_active:
		if not assigned_task_id.is_empty():
			_release_task("dusk_safety_override")
		if navigation_blocked:
			safety_path_failed.emit(NPC_ID, "Safe path to Town Center blocked")
			return
		state = State.RETURNING_TO_SAFETY
		cached_target_x = SAFE_ZONE_X
		_move_toward(cached_target_x, delta)
		if absf(position_x - SAFE_ZONE_X) <= WORK_RANGE:
			state = State.IDLE
		_emit_state()
		return

	# Validate existing task or select highest-priority available task (Priority 2 > 3 > 4)
	if not validate_current_task(building_mgr) and building_mgr != null:
		var next_task: Dictionary = building_mgr.select_highest_priority_task(position_x)
		if not next_task.is_empty():
			assigned_task_id = String(next_task["id"])
			cached_target_x = float(next_task["position_x"])

	# Execute assigned task if valid
	if validate_current_task(building_mgr):
		var plot: Dictionary = building_mgr.get_plot(assigned_task_id)
		cached_target_x = float(plot["position_x"])
		if absf(position_x - cached_target_x) > WORK_RANGE:
			state = State.MOVING_TO_TASK
			_move_toward(cached_target_x, delta)
			_emit_state()
			return

		state = State.WORKING
		var plot_state: int = int(plot["state"])
		if plot_state == BuildingManager.WallState.UNDER_CONSTRUCTION:
			building_mgr.advance_construction(delta, assigned_task_id)
		elif plot_state == BuildingManager.WallState.DAMAGED:
			_repair_accumulator += delta * REPAIR_RATE_PER_SEC
			var pts: int = int(_repair_accumulator)
			if pts >= 1:
				_repair_accumulator -= float(pts)
				building_mgr.builder_repair_step(pts, assigned_task_id)

		if not building_mgr.is_plot_needing_work(assigned_task_id):
			_release_task("work_finished")
			state = State.IDLE
		_emit_state()
		return

	# Priority 6: Return to idle near Town Center safe zone
	cached_target_x = SAFE_ZONE_X
	if absf(position_x - SAFE_ZONE_X) > WORK_RANGE:
		state = State.MOVING_TO_TASK
		_move_toward(SAFE_ZONE_X, delta)
	else:
		state = State.IDLE
	_emit_state()


func _release_task(reason: String) -> void:
	var prev_id: String = assigned_task_id
	assigned_task_id = ""
	if not prev_id.is_empty():
		task_released.emit(NPC_ID, prev_id, reason)


func to_save_dict() -> Dictionary:
	return {
		"id": NPC_ID,
		"recruited": recruited,
		"role": role,
		"state": get_state_name(),
		"position_x": snappedf(position_x, 0.1),
	}


static func is_valid_saved_npc_dict(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data as Dictionary
	if not d.has("id") or not d.has("recruited") or not d.has("role") or not d.has("state"):
		return false
	if String(d["id"]).strip_edges().is_empty():
		return false
	if typeof(d["recruited"]) != TYPE_BOOL:
		return false
	var st: String = String(d["state"])
	if not ["UNRECRUITED", "IDLE", "MOVING_TO_TASK", "WORKING", "RETURNING_TO_SAFETY"].has(st):
		return false
	var pos: float = float(d.get("position_x", CAMP_POSITION_X))
	if is_nan(pos) or is_inf(pos):
		return false
	return true


func apply_save_dict(data: Dictionary) -> bool:
	if not is_valid_saved_npc_dict(data):
		return false
	recruited = bool(data["recruited"])
	role = String(data["role"])
	position_x = float(data.get("position_x", CAMP_POSITION_X))
	assigned_task_id = ""
	var st: String = String(data["state"])
	match st:
		"UNRECRUITED":
			state = State.UNRECRUITED
		"IDLE":
			state = State.IDLE
		"MOVING_TO_TASK":
			state = State.MOVING_TO_TASK
		"WORKING":
			state = State.WORKING
		"RETURNING_TO_SAFETY":
			state = State.RETURNING_TO_SAFETY
	_emit_state()
	return true


func _move_toward(target_x: float, delta: float) -> void:
	var diff: float = target_x - position_x
	var step: float = MOVE_SPEED * delta
	if absf(diff) <= step:
		position_x = target_x
	else:
		position_x += signf(diff) * step


func _emit_state() -> void:
	npc_state_changed.emit(NPC_ID, role, get_state_name(), position_x)
