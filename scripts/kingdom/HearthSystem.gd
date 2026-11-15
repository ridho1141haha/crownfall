class_name HearthSystem
extends RefCounted

signal hearth_upgraded(new_level: int, tier_name: String, new_radius_px: float)
signal hearth_boost_started(duration: float)

const HEARTH_POSITION_X: float = 0.0
const INTERACT_RANGE: float = 80.0
const MAX_LEVEL: int = 3

const BOOST_RADIUS_MULT: float = 1.3
const BOOST_BURN_ADD: float = 2.0
const BOOST_DURATION_SEC: float = 60.0
const BOOST_COST: Dictionary = {"wood": 1}

const DEFAULT_TIERS: Array[Dictionary] = [
	{"level": 1, "name": "Ember Hearth", "radius_px": 180.0, "texture_scale": 2.6, "burn_dps": 2.0, "weakened_pct": 0.20, "upgrade_cost": {}},
	{"level": 2, "name": "Beacon Fire", "radius_px": 320.0, "texture_scale": 4.2, "burn_dps": 2.0, "weakened_pct": 0.20, "upgrade_cost": {"gold": 4, "wood": 4, "stone": 2}},
	{"level": 3, "name": "Solar Brazier", "radius_px": 460.0, "texture_scale": 5.8, "burn_dps": 4.0, "weakened_pct": 0.20, "upgrade_cost": {"gold": 6, "wood": 5, "stone": 4}},
]

var tiers: Array[Dictionary] = []
var hearth_level: int = 1
var boost_remaining: float = 0.0

const DEFAULT_LIGHTING_PATH: String = "res://data/lighting.json"

# Cache statis tingkat hearth yang SUDAH divalidasi — satu-satunya sumber untuk
# semua konsumen (HearthSystem instans, NightEncounterManager, HUD forecast),
# sehingga tidak ada lagi loader lighting.json ganda tanpa validasi.
static var _validated_tiers_cache: Array[Dictionary] = []


func _init() -> void:
	load_from_data()


static func is_valid_tier_dict(d: Dictionary, expected_level: int) -> bool:
	if int(d.get("level", 0)) != expected_level:
		return false
	if not d.has("radius_px") or not d.has("texture_scale") or not d.has("burn_dps") or not d.has("upgrade_cost"):
		return false
	var rad: float = float(d["radius_px"])
	var scl: float = float(d["texture_scale"])
	var dps: float = float(d["burn_dps"])
	if is_nan(rad) or is_inf(rad) or rad <= 0.0 or is_nan(scl) or is_inf(scl) or scl <= 0.0 or is_nan(dps) or is_inf(dps) or dps < 0.0:
		return false
	return typeof(d["upgrade_cost"]) == TYPE_DICTIONARY


func load_from_data(path: String = DEFAULT_LIGHTING_PATH) -> void:
	tiers.clear()
	if path == DEFAULT_LIGHTING_PATH:
		tiers.assign(get_validated_tiers().duplicate(true))
		return
	var staged: Array[Dictionary] = _parse_validated_tiers(path)
	if staged.size() >= MAX_LEVEL:
		tiers.assign(staged)
	else:
		tiers.assign(DEFAULT_TIERS)


static func _parse_validated_tiers(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("hearth_tiers") and typeof((parsed as Dictionary)["hearth_tiers"]) == TYPE_ARRAY:
			var raw_arr: Array = (parsed as Dictionary)["hearth_tiers"]
			if raw_arr.size() >= MAX_LEVEL:
				var valid_all: bool = true
				for i: int in range(MAX_LEVEL):
					if typeof(raw_arr[i]) != TYPE_DICTIONARY or not is_valid_tier_dict(raw_arr[i] as Dictionary, i + 1):
						valid_all = false
						break
					out.append(raw_arr[i] as Dictionary)
				if not valid_all:
					out.clear()
	return out


static func get_validated_tiers() -> Array[Dictionary]:
	if _validated_tiers_cache.is_empty():
		var staged: Array[Dictionary] = _parse_validated_tiers(DEFAULT_LIGHTING_PATH)
		if staged.size() < MAX_LEVEL:
			staged = DEFAULT_TIERS.duplicate(true)
		_validated_tiers_cache = staged
	return _validated_tiers_cache


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


func get_effective_texture_scale() -> float:
	var scl: float = get_texture_scale()
	if is_boost_active():
		scl *= BOOST_RADIUS_MULT
	return scl


func get_burn_dps() -> float:
	return float(get_tier()["burn_dps"])


func is_boost_active() -> bool:
	return boost_remaining > 0.0


func get_effective_radius_px() -> float:
	var radius: float = get_radius_px()
	if is_boost_active():
		radius *= BOOST_RADIUS_MULT
	return radius


func get_effective_burn_dps() -> float:
	var dps: float = get_burn_dps()
	if is_boost_active():
		dps += BOOST_BURN_ADD
	return dps


func tick_boost(delta: float) -> void:
	boost_remaining = maxf(0.0, boost_remaining - delta)


func try_stoke(actor_x: float, ledger: EconomyLedger) -> Dictionary:
	if absf(actor_x - HEARTH_POSITION_X) > INTERACT_RANGE:
		return {"ok": false, "reason": "Move closer to Town Center Hearth (x=0) to stoke the fire"}
	if ledger == null:
		return {"ok": false, "reason": "Economy ledger unavailable"}
	if is_boost_active():
		return {"ok": false, "reason": "The stoked fire is already burning (%.0fs left)" % boost_remaining}
	if not ledger.try_spend(BOOST_COST):
		return {"ok": false, "reason": "Stoke Fire needs 1 Wood"}
	boost_remaining = BOOST_DURATION_SEC
	hearth_boost_started.emit(BOOST_DURATION_SEC)
	return {"ok": true, "reason": "", "duration": BOOST_DURATION_SEC}


func get_weakened_pct() -> float:
	return float(get_tier()["weakened_pct"])


func is_in_light(pos_x: float) -> bool:
	return absf(pos_x - HEARTH_POSITION_X) <= get_effective_radius_px()


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


func apply_save_boost(rem: float) -> void:
	if is_nan(rem) or is_inf(rem):
		boost_remaining = 0.0
		return
	boost_remaining = clampf(rem, 0.0, BOOST_DURATION_SEC)
