class_name NightEncounterManager
extends RefCounted

signal enemy_updated(active: bool, position_x: float, hp: int, max_hp: int)
signal wave_spawned(wave_index: int, total_waves: int)
signal enemy_defeated(archetype: String, reward_gold: int, position_x: float)
signal night_encounter_resolved(survived: bool, wall_held: bool)

const SPAWN_X: float = 820.0
const WEST_SPAWN_X: float = -820.0
const TOWN_CENTER_X: float = 0.0
const MOVE_SPEED: float = 95.0
const ATTACK_RANGE: float = 26.0
const ATTACK_INTERVAL: float = 1.0
const ATTACK_DAMAGE: int = 15
const ENEMY_MAX_HP: int = 45
const MAX_POSSIBLE_ENEMY_HP: int = 160
const WALL_THORN_DAMAGE: int = 15
const KILL_GOLD_REWARD: int = 1
const WAVE_SPAWN_TIMES: Array[float] = [0.0, 55.0, 110.0]
const ESCALATED_WAVE_TIMES: Array[float] = [0.0, 42.0, 84.0, 126.0]
const WEST_SCOUT_TIMES: Array[float] = [20.0, 90.0]

const DEFAULT_ARCHETYPES: Dictionary = {
	"raider": {"name": "Greedling Raider", "hp": 45, "speed": 95.0, "damage": 15},
	"crawler": {"name": "Shadow Crawler", "hp": 45, "speed": 135.0, "damage": 12},
	"brute": {"name": "Gloom Brute", "hp": 160, "speed": 55.0, "damage": 35},
}

var archetypes: Dictionary = {}
var night_active: bool = false
var night_elapsed: float = 0.0
var spawned_wave_count: int = 0
var enemy_active: bool = false
var enemy_x: float = SPAWN_X
var enemy_hp: int = 0
var enemy_max_hp: int = ENEMY_MAX_HP
var enemy_archetype: String = "raider"
var current_day_number: int = 1
var settlement_breached: bool = false
var first_night_survived: bool = false
var _attack_timer: float = 0.0
var _light_burn_acc: float = 0.0

# Day 2+ West Scout lane
var west_spawned_count: int = 0
var west_enemy_active: bool = false
var west_enemy_x: float = WEST_SPAWN_X
var west_enemy_hp: int = 0
var _west_attack_timer: float = 0.0
var _west_burn_acc: float = 0.0
var _east_trampled: Array[String] = []
var _west_trampled: Array[String] = []


func _init() -> void:
	load_archetypes_from_data()


func load_archetypes_from_data(path: String = "res://data/enemies.json") -> void:
	archetypes = DEFAULT_ARCHETYPES.duplicate(true)
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("archetypes"):
			var raw_map: Variant = (parsed as Dictionary)["archetypes"]
			if typeof(raw_map) == TYPE_DICTIONARY:
				for k: Variant in (raw_map as Dictionary).keys():
					var entry: Variant = (raw_map as Dictionary)[k]
					if typeof(entry) == TYPE_DICTIONARY:
						var ed: Dictionary = entry as Dictionary
						archetypes[String(k)] = {
							"name": String(ed.get("name", String(k))),
							"hp": int(roundf(float(ed.get("hp", ENEMY_MAX_HP)))),
							"speed": float(ed.get("speed", MOVE_SPEED)),
							"damage": int(roundf(float(ed.get("damage", ATTACK_DAMAGE)))),
						}


static func get_hearth_radius(hearth_level: int) -> float:
	match hearth_level:
		2:
			return 320.0
		3:
			return 460.0
		_:
			return 180.0


static func get_hearth_burn_dps(hearth_level: int) -> float:
	return 4.0 if hearth_level >= 3 else 2.0


static func get_night_forecast(day_num: int) -> String:
	if day_num <= 1:
		return "Tonight (East): 3 Waves • Greedling Raider"
	if day_num == 2:
		return "Tonight (East & West): 4 East + 2 West Scouts"
	return "Tonight (Both Sides): Raider, Crawler, Brute + West Scouts"


func get_wave_schedule(day_num: int) -> Array[float]:
	return WAVE_SPAWN_TIMES if day_num <= 1 else ESCALATED_WAVE_TIMES


func get_wave_archetype(day_num: int, wave_idx_zero_based: int) -> String:
	if day_num <= 1:
		return "raider"
	if day_num == 2:
		return "crawler" if (wave_idx_zero_based % 2 == 1) else "raider"
	if wave_idx_zero_based == 3:
		return "brute"
	if wave_idx_zero_based >= 1:
		return "crawler"
	return "raider"


func get_enemy_display_name() -> String:
	var d: Dictionary = archetypes.get(enemy_archetype, DEFAULT_ARCHETYPES["raider"]) as Dictionary
	return String(d["name"])


func apply_external_damage(amount: int) -> bool:
	if not enemy_active or amount <= 0:
		return false
	enemy_hp = maxi(0, enemy_hp - amount)
	if enemy_hp <= 0:
		enemy_active = false
		enemy_defeated.emit(enemy_archetype, KILL_GOLD_REWARD, enemy_x)
	enemy_updated.emit(enemy_active, enemy_x, enemy_hp, enemy_max_hp)
	return true


func apply_west_external_damage(amount: int) -> bool:
	if not west_enemy_active or amount <= 0:
		return false
	west_enemy_hp = maxi(0, west_enemy_hp - amount)
	if west_enemy_hp <= 0:
		west_enemy_active = false
		enemy_defeated.emit("raider", KILL_GOLD_REWARD, west_enemy_x)
	return true


func get_nearest_active_enemy(from_x: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = INF
	if enemy_active:
		best_d = absf(enemy_x - from_x)
		best = {"x": enemy_x, "is_west": false}
	if west_enemy_active:
		var d: float = absf(west_enemy_x - from_x)
		if d < best_d:
			best_d = d
			best = {"x": west_enemy_x, "is_west": true}
	return best


func damage_nearest_enemy(from_x: float, max_range: float, amount: int) -> Dictionary:
	var tgt: Dictionary = get_nearest_active_enemy(from_x)
	if tgt.is_empty() or amount <= 0:
		return {"hit": false, "x": 0.0}
	var tx: float = float(tgt["x"])
	if absf(tx - from_x) > max_range:
		return {"hit": false, "x": tx}
	var ok: bool = apply_west_external_damage(amount) if bool(tgt["is_west"]) else apply_external_damage(amount)
	return {"hit": ok, "x": tx}


func _trample_interior(building_mgr: BuildingManager, enemy_x: float, plot_ids: Array[String], trampled: Array[String], dmg: int) -> void:
	if building_mgr == null or dmg <= 0:
		return
	for pid: String in plot_ids:
		if trampled.has(pid) or not building_mgr.is_standing(pid):
			continue
		var px: float = float((building_mgr.get_plot(pid) as Dictionary)["position_x"])
		if absf(enemy_x - px) <= ATTACK_RANGE:
			trampled.append(pid)
			building_mgr.apply_enemy_damage(dmg, pid)


func on_night_started(day_num: int = 1) -> void:
	current_day_number = maxi(1, day_num)
	night_active = true
	night_elapsed = 0.0
	spawned_wave_count = 0
	west_spawned_count = 0
	west_enemy_active = false
	west_enemy_hp = 0
	settlement_breached = false
	_attack_timer = 0.0
	_light_burn_acc = 0.0
	_west_attack_timer = 0.0
	_west_burn_acc = 0.0
	_east_trampled.clear()
	_west_trampled.clear()
	_spawn_next_wave()


func on_sunrise_reached(building_mgr: BuildingManager) -> void:
	var wall_held: bool = building_mgr != null and building_mgr.is_standing()
	var survived: bool = not settlement_breached
	if survived:
		first_night_survived = true
	night_active = false
	enemy_active = false
	enemy_hp = 0
	west_enemy_active = false
	west_enemy_hp = 0
	enemy_updated.emit(false, enemy_x, enemy_hp, enemy_max_hp)
	night_encounter_resolved.emit(survived, wall_held)


func tick(delta: float, is_night: bool, building_mgr: BuildingManager, hearth_level: int = 1, flare_active: bool = false) -> void:
	if not is_night or not night_active or delta <= 0.0:
		return

	night_elapsed += delta
	var schedule: Array[float] = get_wave_schedule(current_day_number)
	var light_mult: float = 1.5 if flare_active else 1.0

	if not enemy_active and not settlement_breached and spawned_wave_count < schedule.size():
		if night_elapsed >= schedule[spawned_wave_count]:
			_spawn_next_wave()

	# Day 2+ West Scout lane
	if current_day_number >= 2 and not west_enemy_active and not settlement_breached and west_spawned_count < WEST_SCOUT_TIMES.size():
		if night_elapsed >= WEST_SCOUT_TIMES[west_spawned_count]:
			_spawn_west_scout()

	if enemy_active:
		_tick_east_enemy(delta, building_mgr, hearth_level, light_mult)

	if west_enemy_active:
		_tick_west_enemy(delta, building_mgr, hearth_level, light_mult)


func _tick_east_enemy(delta: float, building_mgr: BuildingManager, hearth_level: int, light_mult: float) -> void:
	var stats: Dictionary = archetypes.get(enemy_archetype, DEFAULT_ARCHETYPES["raider"]) as Dictionary
	var spd: float = float(stats["speed"])
	var base_dmg: int = int(stats["damage"])

	var hearth_radius: float = get_hearth_radius(hearth_level)
	var in_hearth_light: bool = absf(enemy_x - TOWN_CENTER_X) <= hearth_radius
	if in_hearth_light:
		_light_burn_acc += delta * get_hearth_burn_dps(hearth_level) * light_mult
		var burn_pts: int = int(_light_burn_acc)
		if burn_pts >= 1:
			_light_burn_acc -= float(burn_pts)
			enemy_hp = maxi(0, enemy_hp - burn_pts)
			if enemy_hp <= 0:
				enemy_active = false
				enemy_defeated.emit(enemy_archetype, KILL_GOLD_REWARD, enemy_x)
				enemy_updated.emit(false, enemy_x, 0, enemy_max_hp)
				return

	var effective_dmg: int = int(roundf(float(base_dmg) * 0.8)) if in_hearth_light else base_dmg

	if building_mgr != null and building_mgr.has_defensive_barrier(BuildingManager.WALL_ID):
		var stop_x: float = building_mgr.position_x + ATTACK_RANGE
		if enemy_x > stop_x:
			enemy_x = maxf(stop_x, enemy_x - spd * delta)
		else:
			_attack_timer += delta
			var tower_dmg: int = int(roundf(float(building_mgr.get_watchtower_support_damage()) * light_mult))
			while _attack_timer >= ATTACK_INTERVAL and building_mgr.has_defensive_barrier(BuildingManager.WALL_ID) and enemy_active:
				_attack_timer -= ATTACK_INTERVAL
				building_mgr.apply_enemy_damage(effective_dmg, BuildingManager.WALL_ID)
				enemy_hp = maxi(0, enemy_hp - building_mgr.get_thorn_damage(BuildingManager.WALL_ID) - tower_dmg)
				if enemy_hp <= 0:
					enemy_active = false
					enemy_defeated.emit(enemy_archetype, KILL_GOLD_REWARD, enemy_x)
		enemy_updated.emit(enemy_active, enemy_x, enemy_hp, enemy_max_hp)
		return

	if enemy_x > TOWN_CENTER_X:
		enemy_x = maxf(TOWN_CENTER_X, enemy_x - spd * delta)
		_trample_interior(building_mgr, enemy_x, [BuildingManager.WATCHTOWER_ID, BuildingManager.FARM_EAST_ID], _east_trampled, base_dmg)
		if enemy_x <= TOWN_CENTER_X + 8.0:
			settlement_breached = true
			enemy_active = false
	enemy_updated.emit(enemy_active, enemy_x, enemy_hp, enemy_max_hp)


func _tick_west_enemy(delta: float, building_mgr: BuildingManager, hearth_level: int, light_mult: float) -> void:
	var stats: Dictionary = archetypes.get("raider", DEFAULT_ARCHETYPES["raider"]) as Dictionary
	var spd: float = float(stats["speed"])
	var base_dmg: int = int(stats["damage"])
	var hearth_radius: float = get_hearth_radius(hearth_level)
	var in_light: bool = absf(west_enemy_x - TOWN_CENTER_X) <= hearth_radius
	if in_light:
		_west_burn_acc += delta * get_hearth_burn_dps(hearth_level) * light_mult
		var bpts: int = int(_west_burn_acc)
		if bpts >= 1:
			_west_burn_acc -= float(bpts)
			west_enemy_hp = maxi(0, west_enemy_hp - bpts)
			if west_enemy_hp <= 0:
				west_enemy_active = false
				enemy_defeated.emit("raider", KILL_GOLD_REWARD, west_enemy_x)
				return

	var eff_dmg: int = int(roundf(float(base_dmg) * 0.8)) if in_light else base_dmg
	if building_mgr != null and building_mgr.has_plot(BuildingManager.WEST_WALL_ID) and building_mgr.has_defensive_barrier(BuildingManager.WEST_WALL_ID):
		var w_plot: Dictionary = building_mgr.get_plot(BuildingManager.WEST_WALL_ID)
		var stop_x: float = float(w_plot["position_x"]) - ATTACK_RANGE
		if west_enemy_x < stop_x:
			west_enemy_x = minf(stop_x, west_enemy_x + spd * delta)
		else:
			_west_attack_timer += delta
			while _west_attack_timer >= ATTACK_INTERVAL and building_mgr.has_defensive_barrier(BuildingManager.WEST_WALL_ID) and west_enemy_active:
				_west_attack_timer -= ATTACK_INTERVAL
				building_mgr.apply_enemy_damage(eff_dmg, BuildingManager.WEST_WALL_ID)
				west_enemy_hp = maxi(0, west_enemy_hp - building_mgr.get_thorn_damage(BuildingManager.WEST_WALL_ID))
				if west_enemy_hp <= 0:
					west_enemy_active = false
					enemy_defeated.emit("raider", KILL_GOLD_REWARD, west_enemy_x)
		return

	if west_enemy_x < TOWN_CENTER_X:
		west_enemy_x = minf(TOWN_CENTER_X, west_enemy_x + spd * delta)
		_trample_interior(building_mgr, west_enemy_x, [BuildingManager.FARM_WEST_ID], _west_trampled, base_dmg)
		if west_enemy_x >= TOWN_CENTER_X - 8.0:
			settlement_breached = true
			west_enemy_active = false


func _spawn_next_wave() -> void:
	var schedule: Array[float] = get_wave_schedule(current_day_number)
	enemy_archetype = get_wave_archetype(current_day_number, spawned_wave_count)
	var stats: Dictionary = archetypes.get(enemy_archetype, DEFAULT_ARCHETYPES["raider"]) as Dictionary
	spawned_wave_count += 1
	enemy_active = true
	enemy_x = SPAWN_X
	enemy_max_hp = int(stats["hp"])
	enemy_hp = enemy_max_hp
	_attack_timer = 0.0
	_light_burn_acc = 0.0
	_east_trampled.clear()
	_west_trampled.clear()
	wave_spawned.emit(spawned_wave_count, schedule.size())
	enemy_updated.emit(enemy_active, enemy_x, enemy_hp, enemy_max_hp)


func _spawn_west_scout() -> void:
	var stats: Dictionary = archetypes.get("raider", DEFAULT_ARCHETYPES["raider"]) as Dictionary
	west_spawned_count += 1
	west_enemy_active = true
	west_enemy_x = WEST_SPAWN_X
	west_enemy_hp = int(stats["hp"])
	_west_attack_timer = 0.0
	_west_burn_acc = 0.0
	_west_trampled.clear()


func to_save_dict() -> Dictionary:
	return {
		"night_active": night_active,
		"night_elapsed": snappedf(night_elapsed, 0.001),
		"spawned_wave_count": spawned_wave_count,
		"enemy_active": enemy_active,
		"enemy_x": snappedf(enemy_x, 0.1),
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max_hp,
		"enemy_archetype": enemy_archetype,
		"current_day_number": current_day_number,
		"west_spawned_count": west_spawned_count,
		"west_enemy_active": west_enemy_active,
		"west_enemy_x": snappedf(west_enemy_x, 0.1),
		"west_enemy_hp": west_enemy_hp,
		"settlement_breached": settlement_breached,
		"first_night_survived": first_night_survived,
	}


static func is_valid_saved_encounter_dict(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data as Dictionary
	for req: String in ["night_active", "night_elapsed", "spawned_wave_count", "enemy_active", "enemy_x", "enemy_hp", "settlement_breached", "first_night_survived"]:
		if not d.has(req):
			return false
	if typeof(d["night_active"]) != TYPE_BOOL or typeof(d["enemy_active"]) != TYPE_BOOL:
		return false
	if typeof(d["settlement_breached"]) != TYPE_BOOL or typeof(d["first_night_survived"]) != TYPE_BOOL:
		return false
	if not EconomyLedger.is_exact_int_value(d["spawned_wave_count"]) or not EconomyLedger.is_exact_int_value(d["enemy_hp"]):
		return false
	var waves: int = int(roundf(float(d["spawned_wave_count"])))
	var hp: int = int(roundf(float(d["enemy_hp"])))
	if waves < 0 or waves > ESCALATED_WAVE_TIMES.size() or hp < 0 or hp > MAX_POSSIBLE_ENEMY_HP:
		return false
	var el: float = float(d["night_elapsed"])
	var ex: float = float(d["enemy_x"])
	if is_nan(el) or is_inf(el) or el < 0.0 or is_nan(ex) or is_inf(ex):
		return false
	return true


func apply_save_dict(data: Dictionary) -> bool:
	if not is_valid_saved_encounter_dict(data):
		return false
	night_active = bool(data["night_active"])
	night_elapsed = float(data["night_elapsed"])
	spawned_wave_count = int(roundf(float(data["spawned_wave_count"])))
	enemy_active = bool(data["enemy_active"])
	enemy_x = float(data["enemy_x"])
	enemy_hp = int(roundf(float(data["enemy_hp"])))
	enemy_archetype = String(data.get("enemy_archetype", "raider"))
	var default_max: int = int((archetypes.get(enemy_archetype, DEFAULT_ARCHETYPES["raider"]) as Dictionary)["hp"])
	enemy_max_hp = int(roundf(float(data.get("enemy_max_hp", default_max))))
	current_day_number = maxi(1, int(roundf(float(data.get("current_day_number", 1)))))
	west_spawned_count = int(roundf(float(data.get("west_spawned_count", 0))))
	west_enemy_active = bool(data.get("west_enemy_active", false))
	west_enemy_x = float(data.get("west_enemy_x", WEST_SPAWN_X))
	west_enemy_hp = int(roundf(float(data.get("west_enemy_hp", 0))))
	settlement_breached = bool(data["settlement_breached"])
	first_night_survived = bool(data["first_night_survived"])
	_attack_timer = 0.0
	_light_burn_acc = 0.0
	_west_attack_timer = 0.0
	_west_burn_acc = 0.0
	_east_trampled.clear()
	_west_trampled.clear()
	enemy_updated.emit(enemy_active, enemy_x, enemy_hp, enemy_max_hp)
	return true
