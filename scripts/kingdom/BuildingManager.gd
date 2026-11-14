class_name BuildingManager
extends RefCounted

signal wall_state_changed(wall_id: String, new_state: String, progress: float, durability: int, max_durability: int)
signal building_action_rejected(reason: String)

enum WallState {
	PLACEHOLDER,
	UNDER_CONSTRUCTION,
	COMPLETED,
	DAMAGED,
	DESTROYED,
}

const WALL_ID: String = "wall_east_01"
const WATCHTOWER_ID: String = "watchtower_east_01"
const FARM_WEST_ID: String = "farm_west_01"
const FARM_EAST_ID: String = "farm_east_01"

const WALL_POSITION_X: float = 360.0
const WATCHTOWER_POSITION_X: float = 290.0
const FARM_WEST_POSITION_X: float = -310.0
const FARM_EAST_POSITION_X: float = 120.0

const BUILD_DURATION: float = 4.0
const BASE_MAX_DURABILITY: int = 100
const REINFORCED_MAX_DURABILITY: int = 150
const STONE_WALL_MAX_DURABILITY: int = 260
const WATCHTOWER_MAX_DURABILITY: int = 120
const FARM_MAX_DURABILITY: int = 80
const WATCHTOWER_SUPPORT_DAMAGE: int = 10
const INTERACT_RANGE: float = 96.0

const WALL_BUILD_COST: Dictionary = {
	"gold": 2,
	"wood": 4,
	"stone": 2,
}

const WALL_REPAIR_COST: Dictionary = {
	"wood": 2,
	"stone": 1,
}

const STONE_WALL_UPGRADE_COST: Dictionary = {
	"gold": 3,
	"wood": 2,
	"stone": 5,
}

const WATCHTOWER_BUILD_COST: Dictionary = {
	"gold": 3,
	"wood": 3,
	"stone": 3,
}

const FARM_BUILD_COST: Dictionary = {
	"gold": 3,
	"wood": 4,
}

const FARM_REPAIR_COST: Dictionary = {
	"wood": 2,
}

# Scalable multi-plot registry keyed by plot_id
var _plots: Dictionary = {}

# Primary plot properties kept synchronized for clean convenience access
var state: WallState = WallState.PLACEHOLDER
var construction_progress: float = 0.0
var max_durability: int = BASE_MAX_DURABILITY
var durability: int = 0
var position_x: float = WALL_POSITION_X


func _init() -> void:
	register_plot(WALL_ID, "wooden_wall", WALL_POSITION_X, WALL_BUILD_COST, WALL_REPAIR_COST, BUILD_DURATION, REINFORCED_MAX_DURABILITY)


func register_forgotten_shore_expansion_plots() -> void:
	var loaded_from_data: bool = false
	if FileAccess.file_exists("res://data/buildings.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
		if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("plots"):
			loaded_from_data = true
			for entry: Variant in (parsed as Dictionary)["plots"]:
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var d: Dictionary = entry as Dictionary
				var pid: String = String(d.get("id", ""))
				if pid.is_empty() or has_plot(pid):
					continue
				register_plot(
					pid,
					String(d.get("type", "wooden_wall")),
					float(d.get("position_x", 0.0)),
					d.get("build_cost", WALL_BUILD_COST) as Dictionary,
					d.get("repair_cost", WALL_REPAIR_COST) as Dictionary,
					float(d.get("build_duration", BUILD_DURATION)),
					int(d.get("max_durability", REINFORCED_MAX_DURABILITY))
				)
	if not loaded_from_data:
		if not has_plot(WATCHTOWER_ID):
			register_plot(WATCHTOWER_ID, "watchtower", WATCHTOWER_POSITION_X, WATCHTOWER_BUILD_COST, WALL_REPAIR_COST, 3.5, WATCHTOWER_MAX_DURABILITY)
		if not has_plot(FARM_WEST_ID):
			register_plot(FARM_WEST_ID, "farm_plot", FARM_WEST_POSITION_X, FARM_BUILD_COST, FARM_REPAIR_COST, 3.5, FARM_MAX_DURABILITY)
		if not has_plot(FARM_EAST_ID):
			register_plot(FARM_EAST_ID, "farm_plot", FARM_EAST_POSITION_X, FARM_BUILD_COST, FARM_REPAIR_COST, 3.5, FARM_MAX_DURABILITY)


func register_plot(
	plot_id: String,
	building_type: String,
	pos_x: float,
	build_cost: Dictionary = WALL_BUILD_COST,
	repair_cost: Dictionary = WALL_REPAIR_COST,
	duration: float = BUILD_DURATION,
	max_dur: int = REINFORCED_MAX_DURABILITY
) -> void:
	_plots[plot_id] = {
		"id": plot_id,
		"type": building_type,
		"position_x": pos_x,
		"level": 1,
		"state": WallState.PLACEHOLDER,
		"progress": 0.0,
		"durability": 0,
		"max_durability": max_dur,
		"build_duration": maxf(0.1, duration),
		"build_cost": build_cost.duplicate(),
		"repair_cost": repair_cost.duplicate(),
		"cancelled": false,
	}
	_sync_primary_mirror()


func has_plot(plot_id: String) -> bool:
	return _plots.has(plot_id)


func get_plot(plot_id: String = WALL_ID) -> Dictionary:
	return _plots.get(plot_id, {})


func get_all_plot_ids() -> Array[String]:
	var ids: Array[String] = []
	for k: String in _plots.keys():
		ids.append(k)
	return ids


func get_nearest_plot_id(candidate_x: float, max_range: float = INTERACT_RANGE) -> String:
	var best_id: String = ""
	var best_dist: float = max_range + 0.001
	for plot_id: String in _plots.keys():
		var plot: Dictionary = _plots[plot_id]
		var dist: float = absf(candidate_x - float(plot["position_x"]))
		if dist < best_dist:
			best_dist = dist
			best_id = plot_id
	return best_id


func get_thorn_damage(plot_id: String = WALL_ID) -> int:
	if not _plots.has(plot_id):
		return 15
	var lvl: int = int(_plots[plot_id].get("level", 1))
	return 20 if lvl >= 2 else 15


func get_watchtower_support_damage() -> int:
	if is_standing(WATCHTOWER_ID):
		return WATCHTOWER_SUPPORT_DAMAGE
	return 0


func get_state_name(plot_id: String = WALL_ID) -> String:
	var plot: Dictionary = _plots.get(plot_id, {})
	var st: int = int(plot.get("state", state))
	match st:
		WallState.PLACEHOLDER:
			return "PLACEHOLDER"
		WallState.UNDER_CONSTRUCTION:
			return "UNDER_CONSTRUCTION"
		WallState.COMPLETED:
			return "COMPLETED"
		WallState.DAMAGED:
			return "DAMAGED"
		WallState.DESTROYED:
			return "DESTROYED"
	return "PLACEHOLDER"


func can_place_wall(candidate_x: float, plot_id: String = WALL_ID) -> bool:
	if not _plots.has(plot_id):
		return false
	var plot: Dictionary = _plots[plot_id]
	var st: int = int(plot["state"])
	if st != WallState.PLACEHOLDER and st != WallState.DESTROYED:
		return false
	return absf(candidate_x - float(plot["position_x"])) <= INTERACT_RANGE


func can_upgrade_wall(candidate_x: float, plot_id: String = WALL_ID) -> bool:
	if not _plots.has(plot_id):
		return false
	var plot: Dictionary = _plots[plot_id]
	if String(plot.get("type", "")) != "wooden_wall":
		return false
	if int(plot.get("state", WallState.PLACEHOLDER)) != WallState.COMPLETED:
		return false
	if int(plot.get("level", 1)) >= 2:
		return false
	return absf(candidate_x - float(plot["position_x"])) <= INTERACT_RANGE


func request_start_construction(candidate_x: float, ledger: EconomyLedger, plot_id: String = WALL_ID) -> bool:
	if ledger == null:
		building_action_rejected.emit("Economy ledger unavailable")
		return false
	if not _plots.has(plot_id):
		building_action_rejected.emit("Unknown building plot: %s" % plot_id)
		return false
	var plot: Dictionary = _plots[plot_id]
	var st: int = int(plot["state"])
	if st != WallState.PLACEHOLDER and st != WallState.DESTROYED:
		building_action_rejected.emit("%s is already built or under construction" % plot_id)
		return false
	if not can_place_wall(candidate_x, plot_id):
		building_action_rejected.emit("Move closer to plot (x=%.0f) to build" % float(plot["position_x"]))
		return false
	var cost: Dictionary = plot["build_cost"]
	if not ledger.try_spend(cost):
		building_action_rejected.emit("Insufficient resources to build %s" % String(plot["type"]))
		return false

	plot["state"] = WallState.UNDER_CONSTRUCTION
	plot["progress"] = 0.0
	plot["durability"] = 0
	plot["cancelled"] = false
	_sync_primary_mirror()
	_emit_plot_state(plot_id)
	return true


func request_upgrade_wall(candidate_x: float, ledger: EconomyLedger, plot_id: String = WALL_ID) -> bool:
	if ledger == null or not _plots.has(plot_id):
		building_action_rejected.emit("Invalid upgrade target")
		return false
	var plot: Dictionary = _plots[plot_id]
	if String(plot.get("type", "")) != "wooden_wall" and String(plot.get("type", "")) != "stone_wall":
		building_action_rejected.emit("Only Wooden Wall supports Stone Tier 2 upgrade")
		return false
	if int(plot.get("level", 1)) >= 2:
		building_action_rejected.emit("Wall is already Stone Tier 2")
		return false
	if int(plot.get("state", WallState.PLACEHOLDER)) != WallState.COMPLETED:
		building_action_rejected.emit("Wall must be COMPLETED before upgrading to Stone Tier 2")
		return false
	if absf(candidate_x - float(plot["position_x"])) > INTERACT_RANGE:
		building_action_rejected.emit("Move closer to Wall (x=%.0f) to upgrade" % float(plot["position_x"]))
		return false
	if not ledger.try_spend(STONE_WALL_UPGRADE_COST):
		building_action_rejected.emit("Need 3 Gold, 2 Wood, 5 Stone for Stone Wall Tier 2")
		return false

	plot["level"] = 2
	plot["type"] = "stone_wall"
	plot["max_durability"] = STONE_WALL_MAX_DURABILITY
	plot["durability"] = STONE_WALL_MAX_DURABILITY
	_sync_primary_mirror()
	_emit_plot_state(plot_id)
	return true


func cancel_construction(plot_id: String = WALL_ID) -> bool:
	if not _plots.has(plot_id):
		return false
	var plot: Dictionary = _plots[plot_id]
	if int(plot["state"]) != WallState.UNDER_CONSTRUCTION:
		return false
	plot["state"] = WallState.PLACEHOLDER
	plot["progress"] = 0.0
	plot["durability"] = 0
	plot["cancelled"] = true
	_sync_primary_mirror()
	_emit_plot_state(plot_id)
	return true


func advance_construction(work_seconds: float, plot_id: String = WALL_ID) -> bool:
	if not _plots.has(plot_id) or work_seconds <= 0.0:
		return false
	var plot: Dictionary = _plots[plot_id]
	if int(plot["state"]) != WallState.UNDER_CONSTRUCTION:
		return false

	var duration: float = float(plot["build_duration"])
	var next_prog: float = clampf(float(plot["progress"]) + (work_seconds / duration), 0.0, 1.0)
	plot["progress"] = next_prog
	if next_prog >= 1.0:
		plot["state"] = WallState.COMPLETED
		plot["durability"] = int(plot["max_durability"])
	_sync_primary_mirror()
	_emit_plot_state(plot_id)
	return true


func has_defensive_barrier(plot_id: String = WALL_ID) -> bool:
	if not _plots.has(plot_id):
		return false
	var plot: Dictionary = _plots[plot_id]
	var st: int = int(plot["state"])
	if st == WallState.COMPLETED or st == WallState.DAMAGED:
		return int(plot["durability"]) > 0
	if st == WallState.UNDER_CONSTRUCTION and float(plot["progress"]) >= 0.25:
		return true
	return false


func apply_enemy_damage(amount: int, plot_id: String = WALL_ID) -> int:
	if amount <= 0 or not _plots.has(plot_id):
		return 0
	var plot: Dictionary = _plots[plot_id]
	var st: int = int(plot["state"])
	if st == WallState.UNDER_CONSTRUCTION and float(plot["progress"]) >= 0.25:
		var makeshift_hp: int = maxi(15, int(roundf(float(plot["progress"]) * 80.0)))
		plot["durability"] = makeshift_hp
		plot["state"] = WallState.DAMAGED
		st = WallState.DAMAGED
	if st != WallState.COMPLETED and st != WallState.DAMAGED:
		return 0

	var cur_hp: int = int(plot["durability"])
	var applied: int = mini(cur_hp, amount)
	cur_hp -= applied
	plot["durability"] = cur_hp
	if cur_hp <= 0:
		plot["durability"] = 0
		plot["state"] = WallState.DESTROYED
	else:
		plot["state"] = WallState.DAMAGED
	_sync_primary_mirror()
	_emit_plot_state(plot_id)
	return applied


func request_repair(candidate_x: float, ledger: EconomyLedger, plot_id: String = WALL_ID) -> bool:
	if ledger == null or not _plots.has(plot_id):
		return false
	var plot: Dictionary = _plots[plot_id]
	if int(plot["state"]) != WallState.DAMAGED:
		building_action_rejected.emit("Structure does not need repair right now")
		return false
	if absf(candidate_x - float(plot["position_x"])) > INTERACT_RANGE:
		building_action_rejected.emit("Move closer to the damaged structure to repair")
		return false
	if not ledger.try_spend(plot["repair_cost"]):
		building_action_rejected.emit("Insufficient repair resources")
		return false

	plot["durability"] = int(plot["max_durability"])
	plot["state"] = WallState.COMPLETED
	_sync_primary_mirror()
	_emit_plot_state(plot_id)
	return true


func builder_repair_step(repair_points: int, plot_id: String = WALL_ID) -> bool:
	if repair_points <= 0 or not _plots.has(plot_id):
		return false
	var plot: Dictionary = _plots[plot_id]
	if int(plot["state"]) != WallState.DAMAGED:
		return false
	var max_dur: int = int(plot["max_durability"])
	var next_hp: int = mini(max_dur, int(plot["durability"]) + repair_points)
	plot["durability"] = next_hp
	if next_hp >= max_dur:
		plot["state"] = WallState.COMPLETED
	_sync_primary_mirror()
	_emit_plot_state(plot_id)
	return true


func needs_builder_work(plot_id: String = WALL_ID) -> bool:
	return is_plot_needing_work(plot_id)


func is_plot_needing_work(plot_id: String = WALL_ID) -> bool:
	if not _plots.has(plot_id):
		return false
	var plot: Dictionary = _plots[plot_id]
	if bool(plot.get("cancelled", false)):
		return false
	var st: int = int(plot["state"])
	return st == WallState.UNDER_CONSTRUCTION or st == WallState.DAMAGED


func select_highest_priority_task(from_x: float = 0.0) -> Dictionary:
	var best_plot_id: String = ""
	var best_rank: int = 999
	var best_dist: float = INF

	for plot_id: String in _plots.keys():
		if not is_plot_needing_work(plot_id):
			continue
		var plot: Dictionary = _plots[plot_id]
		var st: int = int(plot["state"])
		var prog: float = float(plot["progress"])
		var rank: int = 3
		if st == WallState.DAMAGED:
			rank = 1
		elif st == WallState.UNDER_CONSTRUCTION and prog > 0.0:
			rank = 2
		var dist: float = absf(float(plot["position_x"]) - from_x)
		if rank < best_rank or (rank == best_rank and dist < best_dist):
			best_rank = rank
			best_dist = dist
			best_plot_id = plot_id

	if best_plot_id.is_empty():
		return {}
	return _plots[best_plot_id]


func is_standing(plot_id: String = WALL_ID) -> bool:
	if not _plots.has(plot_id):
		return false
	var st: int = int(_plots[plot_id]["state"])
	return st == WallState.COMPLETED or st == WallState.DAMAGED


func to_save_dict(plot_id: String = WALL_ID) -> Dictionary:
	var plot: Dictionary = _plots.get(plot_id, _plots[WALL_ID])
	return {
		"id": String(plot["id"]),
		"type": String(plot["type"]),
		"position_x": float(plot["position_x"]),
		"level": int(plot["level"]),
		"state": get_state_name(String(plot["id"])),
		"progress": snappedf(float(plot["progress"]), 0.001),
		"durability": int(plot["durability"]),
		"max_durability": int(plot["max_durability"]),
	}


func to_save_array() -> Array[Dictionary]:
	var arr: Array[Dictionary] = []
	for plot_id: String in _plots.keys():
		arr.append(to_save_dict(plot_id))
	return arr


static func is_valid_saved_building_dict(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data as Dictionary
	if not d.has("id") or not d.has("state") or not d.has("durability"):
		return false
	if String(d["id"]).strip_edges().is_empty():
		return false
	var st_str: String = String(d["state"])
	if not ["PLACEHOLDER", "UNDER_CONSTRUCTION", "COMPLETED", "DAMAGED", "DESTROYED"].has(st_str):
		return false
	if not EconomyLedger.is_exact_int_value(d["durability"]):
		return false
	var dur: int = int(roundf(float(d["durability"])))
	var max_dur: int = int(roundf(float(d.get("max_durability", REINFORCED_MAX_DURABILITY))))
	if max_dur <= 0 or dur < 0 or dur > max_dur:
		return false
	var prog: float = float(d.get("progress", 0.0))
	if is_nan(prog) or is_inf(prog) or prog < 0.0 or prog > 1.0:
		return false
	return true


func apply_save_array(buildings_arr: Array) -> bool:
	if buildings_arr.is_empty():
		return false
	for item: Variant in buildings_arr:
		if not is_valid_saved_building_dict(item):
			return false
	for item: Variant in buildings_arr:
		var d: Dictionary = item as Dictionary
		if not apply_save_dict(d):
			return false
	return true


func apply_save_dict(data: Dictionary) -> bool:
	if not is_valid_saved_building_dict(data):
		return false
	var plot_id: String = String(data["id"])
	if not _plots.has(plot_id):
		register_plot(
			plot_id,
			String(data.get("type", "wooden_wall")),
			float(data.get("position_x", WALL_POSITION_X))
		)
	var plot: Dictionary = _plots[plot_id]
	var state_str: String = String(data["state"])
	match state_str:
		"PLACEHOLDER":
			plot["state"] = WallState.PLACEHOLDER
		"UNDER_CONSTRUCTION":
			plot["state"] = WallState.UNDER_CONSTRUCTION
		"COMPLETED":
			plot["state"] = WallState.COMPLETED
		"DAMAGED":
			plot["state"] = WallState.DAMAGED
		"DESTROYED":
			plot["state"] = WallState.DESTROYED

	plot["type"] = String(data.get("type", plot["type"]))
	plot["level"] = maxi(1, int(roundf(float(data.get("level", 1)))))
	plot["progress"] = clampf(float(data.get("progress", 0.0)), 0.0, 1.0)
	plot["max_durability"] = maxi(1, int(roundf(float(data.get("max_durability", REINFORCED_MAX_DURABILITY)))))
	plot["durability"] = clampi(int(roundf(float(data["durability"]))), 0, int(plot["max_durability"]))
	plot["cancelled"] = false
	_sync_primary_mirror()
	_emit_plot_state(plot_id)
	return true


func _sync_primary_mirror() -> void:
	if not _plots.has(WALL_ID):
		return
	var p: Dictionary = _plots[WALL_ID]
	state = int(p["state"]) as WallState
	construction_progress = float(p["progress"])
	max_durability = int(p["max_durability"])
	durability = int(p["durability"])
	position_x = float(p["position_x"])


func _emit_plot_state(plot_id: String) -> void:
	if not _plots.has(plot_id):
		return
	var p: Dictionary = _plots[plot_id]
	wall_state_changed.emit(
		plot_id,
		get_state_name(plot_id),
		float(p["progress"]),
		int(p["durability"]),
		int(p["max_durability"])
	)
