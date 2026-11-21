class_name EldergroveNightSurvival
extends RefCounted

## N6.4: Minimal, deterministic Eldergrove night survival & First Camp defense.
##
## Distinguishes two explicit threat classes:
##   - ThreatClass.ORDINARY ("raider"): blocked strictly outside First Camp's
##     protected zone when First Camp is constructed (zero random bypass).
##   - ThreatClass.BREACH_CAPABLE ("brute"): explicitly capable of penetrating
##     First Camp's protective boundary on scheduled breach nights (every 3rd day).
##
## Driven strictly by existing TimeManager phases/signals; no parallel clock.

signal encounter_started(day_number: int, threat_class: int, archetype: String)
signal threat_blocked_by_camp(day_number: int, threat_x: float)
signal camp_protection_breached(day_number: int, archetype: String, threat_x: float)
signal encounter_resolved(day_number: int, survived: bool, camp_breached: bool)

enum ThreatClass {
	ORDINARY,
	BREACH_CAPABLE,
}

enum EncounterState {
	IDLE,
	ACTIVE,
	RESOLVED,
}

const CAMP_CENTER_X: float = 80.0
const CAMP_PROTECTION_RADIUS: float = 84.0
const CAMP_BLOCK_MARGIN: float = 1.0
const THREAT_SPAWN_X: float = 680.0
const MIN_WORLD_X: float = -760.0
const MAX_WORLD_X: float = 760.0
const ENCOUNTER_START_OFFSET_SEC: float = 45.0
const THREAT_CONTACT_RANGE: float = 28.0
const ORDINARY_SPEED: float = 95.0
const BREACH_SPEED: float = 55.0
const BREACH_NIGHT_INTERVAL: int = 3
const RESOLVED_DAY_KEY_PREFIX: String = "eldergrove_night_resolved_day_"

var state: EncounterState = EncounterState.IDLE
var active_day: int = 0
var threat_class: ThreatClass = ThreatClass.ORDINARY
var threat_archetype: String = "raider"
var threat_x: float = THREAT_SPAWN_X
var threat_blocked: bool = false
var camp_breached: bool = false
var player_threatened: bool = false
var _resolved_days: Dictionary = {}


static func can_penetrate_camp_protection(t_class: ThreatClass) -> bool:
	return t_class == ThreatClass.BREACH_CAPABLE


static func get_scheduled_threat_class(day_number: int) -> ThreatClass:
	if day_number > 0 and (day_number % BREACH_NIGHT_INTERVAL) == 0:
		return ThreatClass.BREACH_CAPABLE
	return ThreatClass.ORDINARY


static func get_archetype_for_class(t_class: ThreatClass) -> String:
	return "brute" if t_class == ThreatClass.BREACH_CAPABLE else "raider"


static func get_threat_display_name(t_class: ThreatClass) -> String:
	return "Breach Threat (Gloom Brute)" if t_class == ThreatClass.BREACH_CAPABLE else "Ordinary Threat (Night Raider)"


func is_camp_protection_active(camp_built: bool) -> bool:
	return camp_built


func is_x_inside_camp_protection(world_x: float, camp_built: bool) -> bool:
	if not camp_built:
		return false
	return absf(world_x - CAMP_CENTER_X) <= CAMP_PROTECTION_RADIUS


func is_encounter_active() -> bool:
	return state == EncounterState.ACTIVE


func is_day_resolved(day_number: int) -> bool:
	return bool(_resolved_days.get(day_number, false))


func should_start_encounter(day_number: int, phase_elapsed: float) -> bool:
	if day_number <= 0:
		return false
	if is_encounter_active() or is_day_resolved(day_number):
		return false
	return phase_elapsed >= ENCOUNTER_START_OFFSET_SEC


func start_encounter(day_number: int, forced_class: int = -1) -> bool:
	if day_number <= 0:
		return false
	if is_day_resolved(day_number):
		return false
	if is_encounter_active() and active_day == day_number:
		return false
	state = EncounterState.ACTIVE
	active_day = day_number
	if forced_class == ThreatClass.ORDINARY or forced_class == ThreatClass.BREACH_CAPABLE:
		threat_class = forced_class as ThreatClass
	else:
		threat_class = get_scheduled_threat_class(day_number)
	threat_archetype = get_archetype_for_class(threat_class)
	threat_x = THREAT_SPAWN_X
	threat_blocked = false
	camp_breached = false
	player_threatened = false
	encounter_started.emit(active_day, threat_class, threat_archetype)
	return true


func tick(delta: float, player_x: float, camp_built: bool) -> void:
	if not is_encounter_active() or delta <= 0.0:
		return
	var spd: float = BREACH_SPEED if threat_class == ThreatClass.BREACH_CAPABLE else ORDINARY_SPEED
	var dir: float = signf(player_x - threat_x)
	if is_zero_approx(dir):
		dir = -1.0
	var desired_x: float = clampf(threat_x + dir * spd * delta, MIN_WORLD_X, MAX_WORLD_X)

	# Explicit First Camp protection enforcement:
	# Ordinary threats are strictly blocked outside the protected zone with no fallback bypass.
	if camp_built and not can_penetrate_camp_protection(threat_class):
		var left_edge: float = CAMP_CENTER_X - CAMP_PROTECTION_RADIUS
		var right_edge: float = CAMP_CENTER_X + CAMP_PROTECTION_RADIUS
		var would_enter: bool = desired_x >= left_edge and desired_x <= right_edge
		var crosses_zone: bool = (threat_x > right_edge and desired_x <= right_edge) or (threat_x < left_edge and desired_x >= left_edge)
		if would_enter or crosses_zone:
			var clamped_x: float = (right_edge + CAMP_BLOCK_MARGIN) if threat_x >= CAMP_CENTER_X else (left_edge - CAMP_BLOCK_MARGIN)
			threat_x = clamped_x
			if not threat_blocked:
				threat_blocked = true
				threat_blocked_by_camp.emit(active_day, threat_x)
			player_threatened = false
			return

	threat_x = desired_x
	if camp_built and can_penetrate_camp_protection(threat_class) and is_x_inside_camp_protection(threat_x, camp_built):
		if not camp_breached:
			camp_breached = true
			camp_protection_breached.emit(active_day, threat_archetype, threat_x)

	player_threatened = absf(threat_x - player_x) <= THREAT_CONTACT_RANGE


func resolve_encounter(survived: bool = true) -> bool:
	if not is_encounter_active():
		return false
	var resolved_day: int = active_day
	var was_breached: bool = camp_breached
	_resolved_days[resolved_day] = true
	state = EncounterState.RESOLVED
	threat_blocked = false
	player_threatened = false
	encounter_resolved.emit(resolved_day, survived, was_breached)
	return true


func on_sunrise_reached(completed_day: int) -> void:
	if completed_day <= 0:
		return
	if is_encounter_active() and active_day == completed_day:
		resolve_encounter(true)
	else:
		_resolved_days[completed_day] = true
		if state == EncounterState.RESOLVED:
			state = EncounterState.IDLE


func get_status_text() -> String:
	if not is_encounter_active():
		return ""
	if camp_breached:
		return "Night Threat: %s BREACHED First Camp!" % get_threat_display_name(threat_class)
	if threat_blocked:
		return "Night Threat: %s held outside First Camp." % get_threat_display_name(threat_class)
	return "Night Threat: %s approaching (x=%.0f)" % [get_threat_display_name(threat_class), threat_x]


func to_save_node_states() -> Dictionary:
	var out: Dictionary = {}
	for day_key: Variant in _resolved_days.keys():
		var day_num: int = int(day_key)
		if day_num > 0 and bool(_resolved_days[day_key]):
			out[RESOLVED_DAY_KEY_PREFIX + str(day_num)] = true
	return out


func apply_save_node_states(saved_node_states: Variant) -> void:
	_resolved_days.clear()
	state = EncounterState.IDLE
	active_day = 0
	threat_blocked = false
	camp_breached = false
	player_threatened = false
	if typeof(saved_node_states) != TYPE_DICTIONARY:
		return
	var d: Dictionary = saved_node_states as Dictionary
	for raw_k: Variant in d.keys():
		var k: String = String(raw_k)
		if not k.begins_with(RESOLVED_DAY_KEY_PREFIX):
			continue
		if typeof(d[raw_k]) != TYPE_BOOL or not bool(d[raw_k]):
			continue
		var suffix: String = k.substr(RESOLVED_DAY_KEY_PREFIX.length())
		if suffix.is_valid_int():
			var day_num: int = int(suffix)
			if day_num > 0:
				_resolved_days[day_num] = true
