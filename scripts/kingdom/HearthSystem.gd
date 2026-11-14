class_name HearthSystem
extends RefCounted

signal hearth_upgraded(new_level: int, tier_name: String, new_radius_px: float)

const HEARTH_POSITION_X: float = 0.0
const INTERACT_RANGE: float = 80.0
const MAX_LEVEL: int = 3

const DEFAULT_TIERS: Array[Dictionary] = [
	{"level": 1, "name": "Ember Hearth", "radius_px": 180.0, "texture_scale": 2.6, "burn_dps": 2.0, "weakened_pct": 0.20, "upgrade_cost": {}},
	{"level": 2, "name": "Beacon Fire", "radius_px": 320.0, "texture_scale": 4.2, "burn_dps": 2.0, "weakened_pct": 0.20, "upgrade_cost": {"gold": 4, "wood": 4, "stone": 2}},
	{"level": 3, "name": "Solar Brazier", "radius_px": 460.0, "texture_scale": 5.8, "burn_dps": 4.0, "weakened_pct": 0.20, "upgrade_cost": {"gold": 6, "wood": 5, "stone": 4}},
]

var tiers: Array[Dictionary] = []
var hearth_level: int = 1


func _init() -> void:
	load_from_data()


func load_from_data(path: String = "res://data/lighting.json") -> void:
	tiers.clear()
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("hearth_tiers"):
			for item: Variant in (parsed as Dictionary)["hearth_tiers"]:
				if typeof(item) == TYPE_DICTIONARY:
					tiers.append(item as Dictionary)
	if tiers.size() < MAX_LEVEL:
		tiers.assign(DEFAULT_TIERS)


func get_tier(level: int = -1) -> Dictionary:
	var target: int = hearth_level if level <= 0 else level
	var idx: int = clampi(target - 1, 0, tiers.size() - 1)
	return tiers[idx]


func get_tier_name() -> String:
	return String(get_tier()["name"])


func get_radius_px() -> float:
	return float(get_tier()["radius_px"])


func get_texture_scale() -> float:
	return float(get_tier()["texture_scale"])


func get_burn_dps() -> float:
	return float(get_tier()["burn_dps"])


func get_weakened_pct() -> float:
	return float(get_tier()["weakened_pct"])


func is_in_light(pos_x: float) -> bool:
	return absf(pos_x - HEARTH_POSITION_X) <= get_radius_px()


func can_upgrade() -> bool:
	return hearth_level < MAX_LEVEL


func get_next_upgrade_cost() -> Dictionary:
	if not can_upgrade():
		return {}
	return (get_tier(hearth_level + 1).get("upgrade_cost", {}) as Dictionary).duplicate()


func try_upgrade(actor_x: float, ledger: EconomyLedger) -> Dictionary:
	if absf(actor_x - HEARTH_POSITION_X) > INTERACT_RANGE:
		return {"ok": false, "reason": "Move closer to Town Center Hearth (x=0) to upgrade"}
	if not can_upgrade():
		return {"ok": false, "reason": "Solar Brazier is already at maximum Tier 3"}
	if ledger == null:
		return {"ok": false, "reason": "Economy ledger unavailable"}
	var cost: Dictionary = get_next_upgrade_cost()
	if not ledger.try_spend(cost):
		return {"ok": false, "reason": "Insufficient resources to upgrade Hearth"}
	hearth_level += 1
	hearth_upgraded.emit(hearth_level, get_tier_name(), get_radius_px())
	return {"ok": true, "reason": "", "level": hearth_level}


func apply_save_level(lvl: int) -> void:
	hearth_level = clampi(lvl, 1, MAX_LEVEL)
