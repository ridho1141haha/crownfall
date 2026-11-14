class_name NPCBuilderAgent
extends RefCounted

signal npc_state_changed(npc_id: String, role: String, state_name: String, position_x: float)
signal task_released(npc_id: String, task_id: String, reason: String)
signal safety_path_failed(npc_id: String, reason: String)
signal recruitment_rejected(reason: String)
signal farm_gold_earned(npc_id: String, amount: int)
signal archer_volley_fired(npc_id: String, damage: int, from_watchtower: bool)

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
const FARMER_HARVEST_SEC: float = 60.0
const FARMER_GOLD_YIELD: int = 2
const ARCHER_FIRE_INTERVAL: float = 1.2
const ARCHER_BASE_DAMAGE: int = 20
const ARCHER_GROUND_RANGE: float = 240.0
const ARCHER_TOWER_RANGE: float = 360.0

var npc_id: String = NPC_ID
var recruited: bool = false
var role: String = "villager"
var state: State = State.UNRECRUITED
var position_x: float = CAMP_POSITION_X
var assigned_task_id: String = ""
var cached_target_x: float = SAFE_ZONE_X
var safety_override_active: bool = false
var navigation_blocked: bool = false
var _repair_accumulator: float = 0.0
var _farm_timer: float = 0.0
var _archer_cooldown: float = 0.0


func _init(custom_id: String = NPC_ID) -> void:
	npc_id = custom_id


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


func set_role(new_role: String, building_mgr: BuildingManager = null) -> void:
	if building_mgr != null:
		building_mgr.release_all_claims_for_npc(npc_id)
	assigned_task_id = ""
	role = new_role
	state = State.IDLE
	_emit_state()


func request_recruit(player_x: float, ledger: EconomyLedger, assigned_role: String = "builder") -> bool:
	if recruited:
		recruitment_rejected.emit("Villager is already recruited")
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
	role = assigned_role
	state = State.IDLE
	assigned_task_id = ""
	cached_target_x = SAFE_ZONE_X
	_emit_state()
	return true


func set_dusk_or_night_safety(is_unsafe_phase: bool, building_mgr: BuildingManager = null) -> void:
	safety_override_active = is_unsafe_phase
	if not recruited:
		return
	if safety_override_active and role != "archer":
		if not assigned_task_id.is_empty():
			_release_task("dusk_safety_override", building_mgr)
		state = State.RETURNING_TO_SAFETY
		cached_target_x = SAFE_ZONE_X
		_emit_state()


func validate_current_task(building_mgr: BuildingManager) -> bool:
	if assigned_task_id.is_empty() or building_mgr == null:
		return false
	if not building_mgr.has_plot(assigned_task_id):
		_release_task("target_missing", building_mgr)
		return false
	var owner: String = building_mgr.get_plot_claimant(assigned_task_id)
	if not owner.is_empty() and owner != npc_id:
		_release_task("claimed_by_other", building_mgr)
		return false
	if role == "builder" and not building_mgr.is_plot_needing_work(assigned_task_id):
		_release_task("task_completed_or_cancelled", building_mgr)
		return false
	return true


func tick(delta: float, building_mgr: BuildingManager, night_mgr: NightEncounterManager = null) -> void:
	if not recruited or delta <= 0.0:
		return

	if role == "archer":
		_tick_archer(delta, building_mgr, night_mgr)
		return

	# Priority 1: Immediate Dusk/Night Safety Override for non-combatants
	if safety_override_active:
		if not assigned_task_id.is_empty():
			_release_task("dusk_safety_override", building_mgr)
		if navigation_blocked:
			safety_path_failed.emit(npc_id, "Safe path to Town Center blocked")
			return
		state = State.RETURNING_TO_SAFETY
		cached_target_x = SAFE_ZONE_X
		_move_toward(cached_target_x, delta)
		if absf(position_x - SAFE_ZONE_X) <= WORK_RANGE:
			state = State.IDLE
		_emit_state()
		return

	if role == "farmer":
		_tick_farmer(delta, building_mgr)
		return

	if role == "villager":
		_move_to_safe_idle(delta)
		return

	# Builder AI with Task Claiming Lock
	if not validate_current_task(building_mgr) and building_mgr != null:
		var next_task: Dictionary = building_mgr.select_highest_priority_task(position_x, npc_id)
		if not next_task.is_empty():
			var pid: String = String(next_task["id"])
			if building_mgr.claim_plot(pid, npc_id):
				assigned_task_id = pid
				cached_target_x = float(next_task["position_x"])

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
			_release_task("work_finished", building_mgr)
			state = State.IDLE
		_emit_state()
		return

	_move_to_safe_idle(delta)


func _tick_farmer(delta: float, building_mgr: BuildingManager) -> void:
	if building_mgr == null:
		_move_to_safe_idle(delta)
		return
	if assigned_task_id.is_empty():
		var farm: Dictionary = building_mgr.select_available_farm_plot(position_x, npc_id)
		if not farm.is_empty():
			var fid: String = String(farm["id"])
			if building_mgr.claim_plot(fid, npc_id):
				assigned_task_id = fid
				cached_target_x = float(farm["position_x"])
	if not assigned_task_id.is_empty():
		var plot: Dictionary = building_mgr.get_plot(assigned_task_id)
		if plot.is_empty() or int(plot.get("state", 0)) != BuildingManager.WallState.COMPLETED:
			_release_task("farm_unavailable", building_mgr)
		else:
			cached_target_x = float(plot["position_x"])
			if absf(position_x - cached_target_x) > WORK_RANGE:
				state = State.MOVING_TO_TASK
				_move_toward(cached_target_x, delta)
			else:
				state = State.WORKING
				_farm_timer += delta
				while _farm_timer >= FARMER_HARVEST_SEC:
					_farm_timer -= FARMER_HARVEST_SEC
					farm_gold_earned.emit(npc_id, FARMER_GOLD_YIELD)
			_emit_state()
			return
	_move_to_safe_idle(delta)


func _tick_archer(delta: float, building_mgr: BuildingManager, night_mgr: NightEncounterManager) -> void:
	var on_tower: bool = false
	var guard_x: float = SAFE_ZONE_X
	if building_mgr != null:
		if building_mgr.has_plot(BuildingManager.WATCHTOWER_ID) and building_mgr.is_standing(BuildingManager.WATCHTOWER_ID):
			var owner: String = building_mgr.get_plot_claimant(BuildingManager.WATCHTOWER_ID)
			if owner.is_empty() or owner == npc_id:
				building_mgr.claim_plot(BuildingManager.WATCHTOWER_ID, npc_id)
				assigned_task_id = BuildingManager.WATCHTOWER_ID
				guard_x = BuildingManager.WATCHTOWER_POSITION_X
				on_tower = true
		if not on_tower and building_mgr.is_standing(BuildingManager.WALL_ID):
			guard_x = BuildingManager.WALL_POSITION_X - 36.0

	if absf(position_x - guard_x) > 12.0:
		state = State.MOVING_TO_TASK
		_move_toward(guard_x, delta)
	else:
		state = State.WORKING if (night_mgr != null and night_mgr.night_active) else State.IDLE

	_archer_cooldown = maxf(0.0, _archer_cooldown - delta)
	if night_mgr != null and night_mgr.enemy_active and _archer_cooldown <= 0.0:
		var attack_range: float = ARCHER_TOWER_RANGE if on_tower else ARCHER_GROUND_RANGE
		if absf(night_mgr.enemy_x - position_x) <= attack_range:
			var dmg: int = ARCHER_BASE_DAMAGE * (2 if on_tower else 1)
			night_mgr.apply_external_damage(dmg)
			_archer_cooldown = ARCHER_FIRE_INTERVAL
			archer_volley_fired.emit(npc_id, dmg, on_tower)
	_emit_state()


func _move_to_safe_idle(delta: float) -> void:
	cached_target_x = SAFE_ZONE_X
	if absf(position_x - SAFE_ZONE_X) > WORK_RANGE:
		state = State.MOVING_TO_TASK
		_move_toward(SAFE_ZONE_X, delta)
	else:
		state = State.IDLE
	_emit_state()


func _release_task(reason: String, building_mgr: BuildingManager = null) -> void:
	var prev_id: String = assigned_task_id
	assigned_task_id = ""
	if building_mgr != null and not prev_id.is_empty():
		building_mgr.release_plot_claim(prev_id, npc_id)
	if not prev_id.is_empty():
		task_released.emit(npc_id, prev_id, reason)


func to_save_dict() -> Dictionary:
	return {
		"id": npc_id,
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
	npc_id = String(data["id"])
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
	npc_state_changed.emit(npc_id, role, get_state_name(), position_x)
