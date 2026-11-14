class_name ContentExpansionM10
extends RefCounted

signal structure_upgraded(plot_id: String, new_tier: int, new_max_durability: int)
signal unit_assigned(unit_id: String, role: String)
signal farm_harvested(gold_yield: int)
signal tower_attack_fired(target_enemy_id: String, damage: int)
signal expansion_action_rejected(reason: String)

const STONE_WALL_UPGRADE_COST: Dictionary = {
	"gold": 3,
	"wood": 2,
	"stone": 5,
}
const STONE_WALL_MAX_DURABILITY: int = 260

const WATCHTOWER_PLOT_ID: String = "watchtower_east_01"
const WATCHTOWER_POSITION_X: float = 290.0
const WATCHTOWER_BUILD_COST: Dictionary = {
	"gold": 3,
	"wood": 3,
	"stone": 3,
}
const ARCHER_RECRUIT_COST: Dictionary = {"gold": 3, "wood": 1}
const FARMER_RECRUIT_COST: Dictionary = {"gold": 3, "stone": 1}
const FARM_CYCLE_SECONDS: float = 10.0
const FARM_GOLD_YIELD: int = 2
const ARCHER_DAMAGE: int = 20

const ENEMY_ARCHETYPES: Dictionary = {
	"greedling": {"hp": 60, "speed": 95.0, "wall_damage": 15},
	"crawler": {"hp": 45, "speed": 135.0, "wall_damage": 12},
	"brute": {"hp": 160, "speed": 55.0, "wall_damage": 35},
}

var archers_count: int = 0
var farmers_count: int = 0
var _farm_timer: float = 0.0


func register_expansion_plots(building_mgr: BuildingManager) -> void:
	if building_mgr == null:
		return
	if not building_mgr.has_plot(WATCHTOWER_PLOT_ID):
		building_mgr.register_plot(
			WATCHTOWER_PLOT_ID,
			"watchtower",
			WATCHTOWER_POSITION_X,
			WATCHTOWER_BUILD_COST,
			{"wood": 2, "stone": 2},
			3.0,
			120
		)


func upgrade_wall_to_stone(building_mgr: BuildingManager, ledger: EconomyLedger, plot_id: String = BuildingManager.WALL_ID) -> bool:
	if building_mgr == null or ledger == null or not building_mgr.has_plot(plot_id):
		expansion_action_rejected.emit("Invalid building manager or plot")
		return false
	var plot: Dictionary = building_mgr.get_plot(plot_id)
	if int(plot["state"]) != BuildingManager.WallState.COMPLETED:
		expansion_action_rejected.emit("Wall must be COMPLETED before upgrading to Stone Tier 2")
		return false
	if int(plot["level"]) >= 2:
		expansion_action_rejected.emit("Wall is already upgraded to Stone Tier 2")
		return false
	if not ledger.try_spend(STONE_WALL_UPGRADE_COST):
		expansion_action_rejected.emit("Insufficient resources for Stone Wall upgrade (3G, 2W, 5S)")
		return false

	plot["level"] = 2
	plot["max_durability"] = STONE_WALL_MAX_DURABILITY
	plot["durability"] = STONE_WALL_MAX_DURABILITY
	building_mgr.apply_save_dict({
		"id": plot_id,
		"type": "stone_wall",
		"position_x": float(plot["position_x"]),
		"level": 2,
		"state": "COMPLETED",
		"progress": 1.0,
		"durability": STONE_WALL_MAX_DURABILITY,
		"max_durability": STONE_WALL_MAX_DURABILITY,
	})
	structure_upgraded.emit(plot_id, 2, STONE_WALL_MAX_DURABILITY)
	return true


func recruit_archer(ledger: EconomyLedger) -> bool:
	if ledger == null or not ledger.try_spend(ARCHER_RECRUIT_COST):
		expansion_action_rejected.emit("Insufficient resources for Archer (3G, 1W)")
		return false
	archers_count += 1
	unit_assigned.emit("archer_%d" % archers_count, "archer")
	return true


func recruit_farmer(ledger: EconomyLedger) -> bool:
	if ledger == null or not ledger.try_spend(FARMER_RECRUIT_COST):
		expansion_action_rejected.emit("Insufficient resources for Farmer (3G, 1S)")
		return false
	farmers_count += 1
	unit_assigned.emit("farmer_%d" % farmers_count, "farmer")
	return true


func tick_daylight_production(delta: float, is_daylight: bool, ledger: EconomyLedger) -> int:
	if not is_daylight or farmers_count <= 0 or delta <= 0.0 or ledger == null:
		return 0
	_farm_timer += delta
	var total_added: int = 0
	while _farm_timer >= FARM_CYCLE_SECONDS:
		_farm_timer -= FARM_CYCLE_SECONDS
		var gold_gain: int = farmers_count * FARM_GOLD_YIELD
		if ledger.try_add(&"gold", gold_gain):
			total_added += gold_gain
			farm_harvested.emit(gold_gain)
	return total_added


func compute_archer_volley_damage(building_mgr: BuildingManager) -> int:
	if archers_count <= 0:
		return 0
	var tower_bonus: int = 1
	if building_mgr != null and building_mgr.has_plot(WATCHTOWER_PLOT_ID) and building_mgr.is_standing(WATCHTOWER_PLOT_ID):
		tower_bonus = 2
	var dmg: int = archers_count * ARCHER_DAMAGE * tower_bonus
	tower_attack_fired.emit("active_enemy", dmg)
	return dmg


static func get_enemy_archetype_stats(archetype_id: String) -> Dictionary:
	if not ENEMY_ARCHETYPES.has(archetype_id):
		return ENEMY_ARCHETYPES["greedling"].duplicate()
	return (ENEMY_ARCHETYPES[archetype_id] as Dictionary).duplicate()
