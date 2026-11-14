class_name NightEncounterManager
extends RefCounted

signal enemy_updated(active: bool, position_x: float, hp: int, max_hp: int)
signal wave_spawned(wave_index: int, total_waves: int)
signal night_encounter_resolved(survived: bool, wall_held: bool)

const SPAWN_X: float = 820.0
const TOWN_CENTER_X: float = 0.0
const MOVE_SPEED: float = 95.0
const ATTACK_RANGE: float = 26.0
const ATTACK_INTERVAL: float = 1.0
const ATTACK_DAMAGE: int = 15
const ENEMY_MAX_HP: int = 45
const WALL_THORN_DAMAGE: int = 15
const WAVE_SPAWN_TIMES: Array[float] = [0.0, 55.0, 110.0]

var night_active: bool = false
var night_elapsed: float = 0.0
var spawned_wave_count: int = 0
var enemy_active: bool = false
var enemy_x: float = SPAWN_X
var enemy_hp: int = 0
var settlement_breached: bool = false
var first_night_survived: bool = false
var _attack_timer: float = 0.0


func on_night_started() -> void:
	night_active = true
	night_elapsed = 0.0
	spawned_wave_count = 0
	settlement_breached = false
	_attack_timer = 0.0
	_spawn_next_wave()


func on_sunrise_reached(building_mgr: BuildingManager) -> void:
	var wall_held: bool = building_mgr != null and building_mgr.is_standing()
	var survived: bool = not settlement_breached
	if survived:
		first_night_survived = true
	night_active = false
	enemy_active = false
	enemy_hp = 0
	enemy_updated.emit(false, enemy_x, enemy_hp, ENEMY_MAX_HP)
	night_encounter_resolved.emit(survived, wall_held)


func tick(delta: float, is_night: bool, building_mgr: BuildingManager) -> void:
	if not is_night or not night_active or delta <= 0.0:
		return

	night_elapsed += delta

	# Check if the next scheduled night wave should spawn when current enemy is defeated
	if not enemy_active and not settlement_breached and spawned_wave_count < WAVE_SPAWN_TIMES.size():
		var next_wave_time: float = WAVE_SPAWN_TIMES[spawned_wave_count]
		if night_elapsed >= next_wave_time:
			_spawn_next_wave()

	if not enemy_active:
		return

	# If Wooden Wall (or partial makeshift barricade >=25%) is standing, enemy stops and attacks it
	if building_mgr != null and building_mgr.has_defensive_barrier():
		var stop_x: float = building_mgr.position_x + ATTACK_RANGE
		if enemy_x > stop_x:
			enemy_x = maxf(stop_x, enemy_x - MOVE_SPEED * delta)
		else:
			_attack_timer += delta
			while _attack_timer >= ATTACK_INTERVAL and building_mgr.has_defensive_barrier() and enemy_active:
				_attack_timer -= ATTACK_INTERVAL
				building_mgr.apply_enemy_damage(ATTACK_DAMAGE)
				enemy_hp = maxi(0, enemy_hp - WALL_THORN_DAMAGE)
				if enemy_hp <= 0:
					enemy_active = false
		enemy_updated.emit(enemy_active, enemy_x, enemy_hp, ENEMY_MAX_HP)
		return

	# If wall is unbuilt or destroyed, enemy marches toward Town Center
	if enemy_x > TOWN_CENTER_X:
		enemy_x = maxf(TOWN_CENTER_X, enemy_x - MOVE_SPEED * delta)
		if enemy_x <= TOWN_CENTER_X + 8.0:
			settlement_breached = true
			enemy_active = false
	enemy_updated.emit(enemy_active, enemy_x, enemy_hp, ENEMY_MAX_HP)


func _spawn_next_wave() -> void:
	spawned_wave_count += 1
	enemy_active = true
	enemy_x = SPAWN_X
	enemy_hp = ENEMY_MAX_HP
	_attack_timer = 0.0
	wave_spawned.emit(spawned_wave_count, WAVE_SPAWN_TIMES.size())
	enemy_updated.emit(enemy_active, enemy_x, enemy_hp, ENEMY_MAX_HP)


func to_save_dict() -> Dictionary:
	return {
		"night_active": night_active,
		"night_elapsed": snappedf(night_elapsed, 0.001),
		"spawned_wave_count": spawned_wave_count,
		"enemy_active": enemy_active,
		"enemy_x": snappedf(enemy_x, 0.1),
		"enemy_hp": enemy_hp,
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
	if waves < 0 or waves > WAVE_SPAWN_TIMES.size() or hp < 0 or hp > ENEMY_MAX_HP:
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
	settlement_breached = bool(data["settlement_breached"])
	first_night_survived = bool(data["first_night_survived"])
	_attack_timer = 0.0
	enemy_updated.emit(enemy_active, enemy_x, enemy_hp, ENEMY_MAX_HP)
	return true
