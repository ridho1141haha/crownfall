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
const WEST_WALL_ID: String = "wall_west_01"
const WATCHTOWER_ID: String = "watchtower_east_01"
const FARM_WEST_ID: String = "farm_west_01"
const FARM_EAST_ID: String = "farm_east_01"

const WALL_POSITION_X: float = 380.0
const WEST_WALL_POSITION_X: float = -400.0
const WATCHTOWER_POSITION_X: float = 210.0
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
	# Konstanta di bawah hanya fallback instan; konfigurasi sebenarnya berasal
	# dari data/buildings.json (termasuk wall_east_01) via apply_data_configs().
	register_plot(WALL_ID, "wooden_wall", WALL_POSITION_X, WALL_BUILD_COST, WALL_REPAIR_COST, BUILD_DURATION, REINFORCED_MAX_DURABILITY)
	# Terapkan konfigurasi JSON ke plot utama TANPA mendaftarkan plot baru, agar
	# manager segar tetap hanya berisi wall_east_01 (kontrak uji M4 dipertahankan).
	apply_data_configs("res://data/buildings.json", false)


func register_forgotten_shore_expansion_plots() -> void:
	# data/buildings.json adalah sumber kebenaran; entri untuk plot yang sudah
	# terdaftar (mis. wall_east_01 dari _init) tetap dibaca dan diterapkan.
	apply_data_configs("res://data/buildings.json", true)
	# Fallback per-plot jika file JSON korup/kosong atau ada plot ekspansi yang terlewat
	if not has_plot(WATCHTOWER_ID):
		register_plot(WATCHTOWER_ID, "watchtower", WATCHTOWER_POSITION_X, WATCHTOWER_BUILD_COST, WALL_REPAIR_COST, 3.5, WATCHTOWER_MAX_DURABILITY)
	if not has_plot(FARM_WEST_ID):
		register_plot(FARM_WEST_ID, "farm_plot", FARM_WEST_POSITION_X, FARM_BUILD_COST, FARM_REPAIR_COST, 3.5, FARM_MAX_DURABILITY)
	if not has_plot(FARM_EAST_ID):
		register_plot(FARM_EAST_ID, "farm_plot", FARM_EAST_POSITION_X, FARM_BUILD_COST, FARM_REPAIR_COST, 3.5, FARM_MAX_DURABILITY)
	if not has_plot(WEST_WALL_ID):
		register_plot(WEST_WALL_ID, "wooden_wall", WEST_WALL_POSITION_X, WALL_BUILD_COST, WALL_REPAIR_COST, BUILD_DURATION, REINFORCED_MAX_DURABILITY)


static func _as_cost_dict(value: Variant, fallback: Dictionary) -> Dictionary:
	# Kast aman: JSON yang tidak berbentuk Dictionary tidak boleh mematikan loader.
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate()
	return fallback.duplicate()


static func format_cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for res_id: String in ["gold", "wood", "stone"]:
		var amount: int = int(cost.get(res_id, 0))
		if amount > 0:
			parts.append("%d%s" % [amount, res_id[0].to_upper()])
	if parts.is_empty():
		return "Free"
	return " ".join(parts)


func apply_data_configs(path: String = "res://data/buildings.json", register_missing_plots: bool = false) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var root_d: Dictionary = parsed as Dictionary
	if not root_d.has("plots") or typeof(root_d["plots"]) != TYPE_ARRAY:
		return false
	var any_applied: bool = false
	for entry: Variant in (root_d["plots"] as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry as Dictionary
		var pid: String = String(d.get("id", ""))
		if pid.is_empty():
			continue
		if has_plot(pid):
			_apply_json_config_to_plot(pid, d)
		elif register_missing_plots:
			register_plot(
				pid,
				String(d.get("type", "wooden_wall")),
				float(d.get("position_x", 0.0)),
				_as_cost_dict(d.get("build_cost", null), WALL_BUILD_COST),
				_as_cost_dict(d.get("repair_cost", null), WALL_REPAIR_COST),
				_finite_positive(d.get("build_duration", BUILD_DURATION), BUILD_DURATION),
				maxi(1, int(d.get("max_durability", REINFORCED_MAX_DURABILITY))),
				_collect_extra_props(d)
			)
		_apply_config_extras(pid, d)
		any_applied = true
	return any_applied


static func _finite_positive(value: Variant, fallback: float) -> float:
	var v: float = float(value)
	if is_nan(v) or is_inf(v) or v <= 0.0:
		return fallback
	return v


func _collect_extra_props(d: Dictionary) -> Dictionary:
	var extra_props: Dictionary = {}
	if d.has("support_damage") and EconomyLedger.is_exact_int_value(d["support_damage"]):
		extra_props["support_damage"] = int(d["support_damage"])
	if d.has("harvest_interval"):
		var hiv: float = float(d["harvest_interval"])
		if not is_nan(hiv) and not is_inf(hiv) and hiv > 0.0:
			extra_props["harvest_interval"] = hiv
	if d.has("gold_yield") and EconomyLedger.is_exact_int_value(d["gold_yield"]):
		extra_props["gold_yield"] = int(d["gold_yield"])
	return extra_props


func _apply_json_config_to_plot(plot_id: String, d: Dictionary) -> void:
	# Perbarui hanya konfigurasi data-driven; state runtime (state/level/durability/
	# progress/claim) tidak di-reset, sehingga aman dipanggil ulang kapan pun.
	if not _plots.has(plot_id):
		return
	var plot: Dictionary = _plots[plot_id]
	if d.has("type") and typeof(d["type"]) == TYPE_STRING and not String(d["type"]).is_empty():
		plot["type"] = String(d["type"])
	if d.has("position_x"):
		var px_v: float = float(d["position_x"])
		if not is_nan(px_v) and not is_inf(px_v):
			plot["position_x"] = px_v
	plot["build_cost"] = _as_cost_dict(d.get("build_cost", null), plot["build_cost"] as Dictionary)
	plot["repair_cost"] = _as_cost_dict(d.get("repair_cost", null), plot["repair_cost"] as Dictionary)
	if d.has("build_duration"):
		plot["build_duration"] = _finite_positive(d["build_duration"], float(plot["build_duration"]))
	if d.has("max_durability") and EconomyLedger.is_exact_int_value(d["max_durability"]):
		plot["max_durability"] = maxi(1, int(d["max_durability"]))
	_apply_config_extras(plot_id, d)
	_sync_primary_mirror()
	_emit_plot_state(plot_id)


func _apply_config_extras(plot_id: String, d: Dictionary) -> void:
	if not _plots.has(plot_id):
		return
	var plot: Dictionary = _plots[plot_id]
	if d.has("title") and typeof(d["title"]) == TYPE_STRING and not String(d["title"]).is_empty():
		plot["title"] = String(d["title"])
	if d.has("cost_label") and typeof(d["cost_label"]) == TYPE_STRING and not String(d["cost_label"]).is_empty():
		plot["cost_label"] = String(d["cost_label"])
	else:
		plot["cost_label"] = format_cost_text(plot["build_cost"] as Dictionary)
	if d.has("upgrade") and typeof(d["upgrade"]) == TYPE_DICTIONARY:
		var upg: Dictionary = d["upgrade"] as Dictionary
		var upg_cost: Dictionary = _as_cost_dict(upg.get("cost", null), STONE_WALL_UPGRADE_COST)
		plot["upgrade_cost"] = upg_cost
		if upg.has("cost_label") and typeof(upg["cost_label"]) == TYPE_STRING and not String(upg["cost_label"]).is_empty():
			plot["upgrade_cost_label"] = String(upg["cost_label"])
		else:
			plot["upgrade_cost_label"] = format_cost_text(upg_cost)
		if upg.has("max_durability") and EconomyLedger.is_exact_int_value(upg["max_durability"]):
			plot["upgrade_max_durability"] = maxi(1, int(upg["max_durability"]))
		if upg.has("thorn_damage") and EconomyLedger.is_exact_int_value(upg["thorn_damage"]):
			plot["upgrade_thorn_damage"] = int(upg["thorn_damage"])
		if upg.has("target_type") and typeof(upg["target_type"]) == TYPE_STRING and not String(upg["target_type"]).is_empty():
			plot["upgrade_target_type"] = String(upg["target_type"])


func register_plot(
	plot_id: String,
	building_type: String,
	pos_x: float,
	build_cost: Dictionary = WALL_BUILD_COST,
	repair_cost: Dictionary = WALL_REPAIR_COST,
	duration: float = BUILD_DURATION,
	max_dur: int = REINFORCED_MAX_DURABILITY,
	extra_props: Dictionary = {}
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
		"claimed_by_npc_id": "",
	}
	for prop_key: String in extra_props.keys():
		_plots[plot_id][prop_key] = extra_props[prop_key]
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


func get_nearest_actionable_plot_id(candidate_x: float, max_range: float = INTERACT_RANGE, mode: String = "any") -> String:
	var best_id: String = ""
	var best_dist: float = max_range + 0.001
	for plot_id: String in _plots.keys():
		var plot: Dictionary = _plots[plot_id]
		var dist: float = absf(candidate_x - float(plot["position_x"]))
		if dist > max_range or dist >= best_dist:
			continue
		var st: int = int(plot["state"])
		var actionable: bool = false
		match mode:
			"build_or_upgrade":
				actionable = (st == WallState.PLACEHOLDER or st == WallState.DESTROYED or can_upgrade_wall(candidate_x, plot_id))
			"repair":
				actionable = (st == WallState.DAMAGED)
			"upgrade":
				actionable = can_upgrade_wall(candidate_x, plot_id)
			_:
				actionable = (st == WallState.PLACEHOLDER or st == WallState.DESTROYED or st == WallState.DAMAGED or can_upgrade_wall(candidate_x, plot_id))
		if actionable:
			best_dist = dist
			best_id = plot_id
	return best_id


func get_thorn_damage(plot_id: String = WALL_ID) -> int:
	if not _plots.has(plot_id):
		return 15
	var plot: Dictionary = _plots[plot_id]
	var lvl: int = int(plot.get("level", 1))
	if lvl >= 2:
		if plot.has("upgrade_thorn_damage"):
			return int(plot["upgrade_thorn_damage"])
		return 20
	return 5


func is_fully_operational(plot_id: String = WALL_ID) -> bool:
	if not _plots.has(plot_id):
		return false
	return int(_plots[plot_id]["state"]) == WallState.COMPLETED


func get_watchtower_support_damage(plot_id: String = WATCHTOWER_ID) -> int:
	if is_fully_operational(plot_id):
		var plot: Dictionary = _plots.get(plot_id, {})
		if plot.has("support_damage"):
			return int(plot["support_damage"])
		return WATCHTOWER_SUPPORT_DAMAGE
	return 0


func get_farm_harvest_interval(plot_id: String = FARM_WEST_ID) -> float:
	var plot: Dictionary = _plots.get(plot_id, {})
	if plot.has("harvest_interval"):
		return maxf(0.1, float(plot["harvest_interval"]))
	return 60.0


func get_farm_gold_yield(plot_id: String = FARM_WEST_ID) -> int:
	var plot: Dictionary = _plots.get(plot_id, {})
	if plot.has("gold_yield"):
		return int(plot["gold_yield"])
	return 2


func get_plot_title(plot_id: String = WALL_ID) -> String:
	var plot: Dictionary = _plots.get(plot_id, {})
	if plot.has("title"):
		return String(plot["title"])
	match String(plot.get("type", "wooden_wall")):
		"watchtower":
			return "Watchtower"
		"farm_plot":
			return "Farm Plot"
		"stone_wall":
			return "Stone Wall"
		_:
			return "Wall Plot"


func get_plot_cost_label(plot_id: String = WALL_ID) -> String:
	var plot: Dictionary = _plots.get(plot_id, {})
	if plot.has("cost_label"):
		return String(plot["cost_label"])
	return format_cost_text(plot.get("build_cost", WALL_BUILD_COST) as Dictionary)


func get_plot_upgrade_cost(plot_id: String = WALL_ID) -> Dictionary:
	var plot: Dictionary = _plots.get(plot_id, {})
	if plot.has("upgrade_cost"):
		return (plot["upgrade_cost"] as Dictionary).duplicate()
	return STONE_WALL_UPGRADE_COST.duplicate()


func get_plot_upgrade_cost_label(plot_id: String = WALL_ID) -> String:
	var plot: Dictionary = _plots.get(plot_id, {})
	if plot.has("upgrade_cost_label"):
		return String(plot["upgrade_cost_label"])
	if plot.has("upgrade_cost"):
		return format_cost_text(plot["upgrade_cost"] as Dictionary)
	return format_cost_text(STONE_WALL_UPGRADE_COST)


func apply_damage(amount: int, plot_id: String = WALL_ID) -> int:
	return apply_enemy_damage(amount, plot_id)


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
	var upg_cost: Dictionary = (plot["upgrade_cost"] as Dictionary) if plot.has("upgrade_cost") else STONE_WALL_UPGRADE_COST
	var upg_max: int = int(plot.get("upgrade_max_durability", STONE_WALL_MAX_DURABILITY))
	if not ledger.try_spend(upg_cost):
		building_action_rejected.emit("Need %s for Stone Wall Tier 2" % get_plot_upgrade_cost_label(plot_id))
		return false

	plot["level"] = 2
	plot["type"] = String(plot.get("upgrade_target_type", "stone_wall"))
	plot["max_durability"] = upg_max
	plot["durability"] = upg_max
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


func request_repair(candidate_x: float, ledger: EconomyLedger, plot_id: String = WALL_ID, extra_cost: Dictionary = {}) -> bool:
	if ledger == null or not _plots.has(plot_id):
		return false
	var plot: Dictionary = _plots[plot_id]
	if int(plot["state"]) != WallState.DAMAGED:
		building_action_rejected.emit("Structure does not need repair right now")
		return false
	if absf(candidate_x - float(plot["position_x"])) > INTERACT_RANGE:
		building_action_rejected.emit("Move closer to the damaged structure to repair")
		return false
	var total_cost: Dictionary = (plot["repair_cost"] as Dictionary).duplicate()
	for k: Variant in extra_cost.keys():
		var key_str: String = String(k)
		total_cost[key_str] = int(total_cost.get(key_str, 0)) + int(extra_cost[k])
	if not ledger.try_spend(total_cost):
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




func claim_plot(plot_id: String, npc_id: String) -> bool:
	if not _plots.has(plot_id) or npc_id.is_empty():
		return false
	var current_owner: String = String(_plots[plot_id].get("claimed_by_npc_id", ""))
	if not current_owner.is_empty() and current_owner != npc_id:
		return false
	_plots[plot_id]["claimed_by_npc_id"] = npc_id
	return true


func release_plot_claim(plot_id: String, npc_id: String = "") -> void:
	if not _plots.has(plot_id):
		return
	var current_owner: String = String(_plots[plot_id].get("claimed_by_npc_id", ""))
	if npc_id.is_empty() or current_owner == npc_id:
		_plots[plot_id]["claimed_by_npc_id"] = ""


func release_all_claims_for_npc(npc_id: String) -> void:
	if npc_id.is_empty():
		return
	for pid: String in _plots.keys():
		if String(_plots[pid].get("claimed_by_npc_id", "")) == npc_id:
			_plots[pid]["claimed_by_npc_id"] = ""


func get_plot_claimant(plot_id: String) -> String:
	if not _plots.has(plot_id):
		return ""
	return String(_plots[plot_id].get("claimed_by_npc_id", ""))


func select_available_farm_plot(from_x: float, claimant_id: String) -> Dictionary:
	var best_id: String = ""
	var best_dist: float = INF
	for pid: String in _plots.keys():
		var plot: Dictionary = _plots[pid]
		if String(plot.get("type", "")) != "farm_plot":
			continue
		if int(plot.get("state", WallState.PLACEHOLDER)) != WallState.COMPLETED:
			continue
		var owner: String = String(plot.get("claimed_by_npc_id", ""))
		if not owner.is_empty() and owner != claimant_id:
			continue
		var dist: float = absf(float(plot["position_x"]) - from_x)
		if dist < best_dist:
			best_dist = dist
			best_id = pid
	if best_id.is_empty():
		return {}
	return _plots[best_id]


func select_highest_priority_task(from_x: float = 0.0, claimant_id: String = "") -> Dictionary:
	var best_plot_id: String = ""
	var best_rank: int = 999
	var best_dist: float = INF

	for plot_id: String in _plots.keys():
		if not is_plot_needing_work(plot_id):
			continue
		var plot: Dictionary = _plots[plot_id]
		var owner: String = String(plot.get("claimed_by_npc_id", ""))
		if not claimant_id.is_empty() and not owner.is_empty() and owner != claimant_id:
			continue
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
	if d.has("level"):
		if not EconomyLedger.is_exact_int_value(d["level"]):
			return false
		var lvl_chk: int = int(roundf(float(d["level"])))
		if lvl_chk < 1 or lvl_chk > 2:
			return false
	var btype_chk: String = String(d.get("type", "wooden_wall"))
	var eff_lvl: int = int(roundf(float(d.get("level", 1))))
	if btype_chk == "stone_wall" and eff_lvl < 2:
		return false
	if (btype_chk == "watchtower" or btype_chk == "farm_plot") and eff_lvl != 1:
		return false
	if (st_str == "PLACEHOLDER" or st_str == "DESTROYED") and dur != 0:
		return false
	if (st_str == "COMPLETED" or st_str == "DAMAGED") and dur <= 0:
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
