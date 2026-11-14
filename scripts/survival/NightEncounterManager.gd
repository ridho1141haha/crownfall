class_name NightEncounterManager
extends RefCounted

signal enemy_updated(active: bool, position_x: float, hp: int, max_hp: int)
signal night_encounter_resolved(survived: bool, wall_held: bool)

const SPAWN_X: float = 820.0
const TOWN_CENTER_X: float = 0.0
const MOVE_SPEED: float = 95.0
const ATTACK_RANGE: float = 26.0
const ATTACK_INTERVAL: float = 1.0
const ATTACK_DAMAGE: int = 15
const ENEMY_MAX_HP: int = 60
const WALL_THORN_DAMAGE: int = 10

var enemy_active: bool = false
var enemy_x: float = SPAWN_X
var enemy_hp: int = ENEMY_MAX_HP
var settlement_breached: bool = false
var first_night_survived: bool = false
var _attack_timer: float = 0.0


func on_night_started() -> void:
	enemy_active = true
	enemy_x = SPAWN_X
	enemy_hp = ENEMY_MAX_HP
	settlement_breached = false
	_attack_timer = 0.0
	enemy_updated.emit(enemy_active, enemy_x, enemy_hp, ENEMY_MAX_HP)


func on_sunrise_reached(building_mgr: BuildingManager) -> void:
	var wall_held: bool = building_mgr != null and building_mgr.is_standing()
	var survived: bool = not settlement_breached
	if survived:
		first_night_survived = true
	enemy_active = false
	enemy_updated.emit(false, enemy_x, enemy_hp, ENEMY_MAX_HP)
	night_encounter_resolved.emit(survived, wall_held)


func tick(delta: float, is_night: bool, building_mgr: BuildingManager) -> void:
	if not is_night or not enemy_active or delta <= 0.0:
		return

	# If Wooden Wall is standing, enemy stops at the wall and attacks it
	if building_mgr != null and building_mgr.is_standing():
		var stop_x: float = building_mgr.position_x + ATTACK_RANGE
		if enemy_x > stop_x:
			enemy_x = maxf(stop_x, enemy_x - MOVE_SPEED * delta)
		else:
			_attack_timer += delta
			while _attack_timer >= ATTACK_INTERVAL and building_mgr.is_standing() and enemy_active:
				_attack_timer -= ATTACK_INTERVAL
				building_mgr.apply_enemy_damage(ATTACK_DAMAGE)
				enemy_hp = maxi(0, enemy_hp - WALL_THORN_DAMAGE)
				if enemy_hp <= 0:
					enemy_active = false
		enemy_updated.emit(enemy_active, enemy_x, enemy_hp, ENEMY_MAX_HP)
		return

	# If wall is not built or destroyed, enemy marches to Town Center
	if enemy_x > TOWN_CENTER_X:
		enemy_x = maxf(TOWN_CENTER_X, enemy_x - MOVE_SPEED * delta)
		if enemy_x <= TOWN_CENTER_X + 8.0:
			settlement_breached = true
			enemy_active = false
	enemy_updated.emit(enemy_active, enemy_x, enemy_hp, ENEMY_MAX_HP)
