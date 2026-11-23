class_name EldergroveNightSurvival
extends RefCounted

## N6.4: Minimal, deterministic Eldergrove night survival & First Camp defense.
##
## Distinguishes two explicit threat classes:
##   - ThreatClass.ORDINARY ("raider"): blocked strictly outside First Camp's
##     protected zone when First Camp is constructed (zero random bypass).
##   - ThreatClass.BREACH_CAPABLE ("brute"): explicitly capable of penetrating
##     First Camp's protective boundary on scheduled breach nights (every 5th day).
##
## Tracks explicit per-day outcomes (DayOutcome) so sunrise without an encounter
## never falsely marks an encounter as resolved.
## Driven strictly by existing TimeManager phases/signals; no parallel clock.

signal encounter_started(day_number: int, threat_class: int, archetype: String)
signal threat_blocked_by_camp(day_number: int, threat_x: float)
signal camp_protection_breached(day_number: int, archetype: String, threat_x: float)
signal encounter_resolved(day_number: int, survived: bool, camp_breached: bool)
signal defense_pulse_activated(day_number: int, threat_class: int, new_threat_x: float, repelled_breach: bool)
signal camp_integrity_changed(current_integrity: int, max_integrity: int, delta: int)
signal threat_health_changed(day_number: int, current_hp: int, max_hp: int, damage: int)
signal threat_defeated(day_number: int, archetype: String)
signal player_hit_by_threat(day_number: int, current_vitality: int, max_vitality: int, knockback_dir: int)
signal player_overwhelmed(day_number: int, archetype: String)

enum ThreatClass {
	ORDINARY,
	BREACH_CAPABLE,
}

enum EncounterState {
	IDLE,
	ACTIVE,
	RESOLVED,
}

enum DayOutcome {
	UNPROCESSED,
	PASSED_NO_ENCOUNTER,
	RESOLVED,
	RESTORED_RESOLVED,
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
const BREACH_NIGHT_INTERVAL: int = 5
const RESOLVED_DAY_KEY_PREFIX: String = "eldergrove_night_resolved_day_"
const DEFENSE_PULSE_COOLDOWN_SEC: float = 8.0
const DEFENSE_PULSE_VISUAL_SEC: float = 0.6
const ORDINARY_PUSHBACK_PX: float = 140.0
const ORDINARY_STAGGER_SEC: float = 3.0
const BREACH_PUSHBACK_PX: float = 96.0
const BREACH_STAGGER_SEC: float = 1.5
const MAX_CAMP_INTEGRITY: int = 3
const BREACH_DAMAGE: int = 1
const CAMP_REPAIR_AMOUNT: int = 1
const CAMP_INTEGRITY_TRACKED_KEY: String = "eldergrove_camp_integrity_tracked"
const CAMP_INTEGRITY_BIT_PREFIX: String = "eldergrove_camp_integrity_"
const ORDINARY_MAX_HP: int = 2
const BRUTE_MAX_HP: int = 3
const PLAYER_ATTACK_DAMAGE: int = 1
const PLAYER_ATTACK_REACH: float = 64.0
const PLAYER_ATTACK_COOLDOWN_SEC: float = 0.45
const HIT_FLASH_VISUAL_SEC: float = 0.2
const PLAYER_MAX_VITALITY: int = 3
const PLAYER_HIT_INVULN_SEC: float = 1.2
const PLAYER_RETREAT_INVULN_SEC: float = 2.0
const PLAYER_HIT_FLASH_SEC: float = 0.2
const PLAYER_KNOCKBACK_PX: float = 48.0

var state: EncounterState = EncounterState.IDLE
var active_day: int = 0
var threat_class: ThreatClass = ThreatClass.ORDINARY
var threat_archetype: String = "raider"
var threat_x: float = THREAT_SPAWN_X
var threat_blocked: bool = false
var camp_breached: bool = false
var player_threatened: bool = false
var defense_cooldown_remaining: float = 0.0
var threat_stagger_remaining: float = 0.0
var defense_pulse_visual_remaining: float = 0.0
var defense_pulse_count: int = 0
var camp_integrity: int = 0
var threat_hp: int = 0
var threat_max_hp: int = 0
var threat_is_defeated: bool = false
var attack_cooldown_remaining: float = 0.0
var hit_flash_remaining: float = 0.0
var player_vitality: int = PLAYER_MAX_VITALITY
var player_invuln_remaining: float = 0.0
var player_hit_flash_remaining: float = 0.0
var player_overwhelmed_count: int = 0
var _day_outcomes: Dictionary = {}


static func can_penetrate_camp_protection(t_class: ThreatClass) -> bool:
	return t_class == ThreatClass.BREACH_CAPABLE


static func get_scheduled_threat_class(day_number: int) -> ThreatClass:
	if day_number > 0 and (day_number % BREACH_NIGHT_INTERVAL) == 0:
		return ThreatClass.BREACH_CAPABLE
	return ThreatClass.ORDINARY


static func is_breach_night(day_number: int) -> bool:
	return get_scheduled_threat_class(day_number) == ThreatClass.BREACH_CAPABLE


static func get_archetype_for_class(t_class: ThreatClass) -> String:
	return "brute" if t_class == ThreatClass.BREACH_CAPABLE else "raider"


static func get_threat_display_name(t_class: ThreatClass) -> String:
	return "Breach Threat (Gloom Brute)" if t_class == ThreatClass.BREACH_CAPABLE else "Ordinary Threat (Night Raider)"


func get_camp_integrity() -> int:
	return camp_integrity


func get_max_camp_integrity() -> int:
	return MAX_CAMP_INTEGRITY


func is_camp_compromised(camp_built: bool) -> bool:
	return camp_built and camp_integrity <= 0


func is_camp_damaged(camp_built: bool) -> bool:
	return camp_built and camp_integrity < MAX_CAMP_INTEGRITY


func on_first_camp_built() -> void:
	var prev: int = camp_integrity
	camp_integrity = MAX_CAMP_INTEGRITY
	if camp_integrity != prev:
		camp_integrity_changed.emit(camp_integrity, MAX_CAMP_INTEGRITY, camp_integrity - prev)


func repair_camp(camp_built: bool, amount: int = CAMP_REPAIR_AMOUNT) -> Dictionary:
	if not camp_built:
		return {"ok": false, "unbuilt": true, "reason": "Build First Camp before repairing."}
	if amount <= 0:
		return {"ok": false, "reason": "Invalid repair amount."}
	if camp_integrity >= MAX_CAMP_INTEGRITY:
		return {"ok": false, "already_full": true, "reason": "First Camp is already at full integrity (%d/%d)." % [camp_integrity, MAX_CAMP_INTEGRITY]}
	var prev: int = camp_integrity
	camp_integrity = mini(MAX_CAMP_INTEGRITY, camp_integrity + amount)
	var restored: int = camp_integrity - prev
	camp_integrity_changed.emit(camp_integrity, MAX_CAMP_INTEGRITY, restored)
	return {
		"ok": true,
		"previous_integrity": prev,
		"new_integrity": camp_integrity,
		"max_integrity": MAX_CAMP_INTEGRITY,
		"restored": restored,
	}


func is_camp_protection_active(camp_built: bool) -> bool:
	return camp_built and camp_integrity > 0


func is_x_inside_camp_protection(world_x: float, camp_built: bool) -> bool:
	if not is_camp_protection_active(camp_built):
		return false
	return absf(world_x - CAMP_CENTER_X) <= CAMP_PROTECTION_RADIUS


func is_encounter_active() -> bool:
	return state == EncounterState.ACTIVE


func get_day_outcome(day_number: int) -> DayOutcome:
	return int(_day_outcomes.get(day_number, DayOutcome.UNPROCESSED)) as DayOutcome


func is_day_resolved(day_number: int) -> bool:
	var outcome: DayOutcome = get_day_outcome(day_number)
	return outcome == DayOutcome.RESOLVED or outcome == DayOutcome.RESTORED_RESOLVED


func is_day_passed_without_encounter(day_number: int) -> bool:
	return get_day_outcome(day_number) == DayOutcome.PASSED_NO_ENCOUNTER


func is_day_restored_from_save(day_number: int) -> bool:
	return get_day_outcome(day_number) == DayOutcome.RESTORED_RESOLVED


func is_rest_blocked_by_breach_night(day_number: int) -> bool:
	if day_number <= 0:
		return false
	if is_day_resolved(day_number):
		return false
	return is_breach_night(day_number)


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
	defense_cooldown_remaining = 0.0
	threat_stagger_remaining = 0.0
	defense_pulse_visual_remaining = 0.0
	defense_pulse_count = 0
	threat_is_defeated = false
	attack_cooldown_remaining = 0.0
	hit_flash_remaining = 0.0
	if threat_class == ThreatClass.BREACH_CAPABLE:
		threat_max_hp = BRUTE_MAX_HP
		threat_hp = BRUTE_MAX_HP
	else:
		threat_max_hp = ORDINARY_MAX_HP
		threat_hp = ORDINARY_MAX_HP
	encounter_started.emit(active_day, threat_class, threat_archetype)
	return true


func is_defense_on_cooldown() -> bool:
	return defense_cooldown_remaining > 0.0


func is_threat_staggered() -> bool:
	return threat_stagger_remaining > 0.0


func is_attack_on_cooldown() -> bool:
	return attack_cooldown_remaining > 0.0


func is_threat_defeated() -> bool:
	return threat_is_defeated


func get_player_vitality() -> int:
	return player_vitality


func get_player_max_vitality() -> int:
	return PLAYER_MAX_VITALITY


func is_player_invulnerable() -> bool:
	return player_invuln_remaining > 0.0


func is_player_hit_flash_active() -> bool:
	return player_hit_flash_remaining > 0.0


func restore_player_vitality() -> void:
	player_vitality = PLAYER_MAX_VITALITY
	player_invuln_remaining = 0.0
	player_hit_flash_remaining = 0.0


func can_player_attack(player_x: float, facing_dir: int) -> Dictionary:
	if not is_encounter_active():
		return {"ok": false, "not_active": true, "reason": "No active night threat to attack."}
	if threat_is_defeated:
		return {"ok": false, "already_defeated": true, "reason": "Threat is already defeated."}
	if threat_class == ThreatClass.ORDINARY and is_threat_staggered():
		return {"ok": false, "staggered": true, "reason": "Ordinary Threat is staggered and cannot be struck right now."}
	if is_attack_on_cooldown():
		return {
			"ok": false,
			"on_cooldown": true,
			"cooldown_remaining": attack_cooldown_remaining,
			"reason": "Attack recharging (%.2fs)." % attack_cooldown_remaining,
		}
	var target_name: String = "Gloom Brute" if threat_class == ThreatClass.BREACH_CAPABLE else "Night Raider"
	var dx: float = threat_x - player_x
	if absf(dx) > PLAYER_ATTACK_REACH:
		return {"ok": false, "out_of_range": true, "distance": absf(dx), "reason": "Move closer to attack %s." % target_name}
	var norm_facing: int = -1 if facing_dir < 0 else 1
	if not is_zero_approx(dx) and ((dx > 0.0 and norm_facing < 0) or (dx < 0.0 and norm_facing > 0)):
		return {"ok": false, "wrong_facing": true, "reason": "Face %s to attack." % target_name}
	return {"ok": true}


func apply_player_attack(player_x: float, facing_dir: int) -> Dictionary:
	var check: Dictionary = can_player_attack(player_x, facing_dir)
	if not bool(check.get("ok", false)):
		return check
	var target_day: int = active_day
	var target_arch: String = threat_archetype
	attack_cooldown_remaining = PLAYER_ATTACK_COOLDOWN_SEC
	var prev_hp: int = threat_hp
	threat_hp = maxi(0, threat_hp - PLAYER_ATTACK_DAMAGE)
	var dealt: int = prev_hp - threat_hp
	hit_flash_remaining = HIT_FLASH_VISUAL_SEC
	threat_health_changed.emit(target_day, threat_hp, threat_max_hp, dealt)

	var defeated_now: bool = false
	if threat_hp <= 0 and not threat_is_defeated:
		threat_is_defeated = true
		defeated_now = true
		threat_defeated.emit(target_day, target_arch)
		resolve_encounter(true)

	return {
		"ok": true,
		"day": target_day,
		"damage": dealt,
		"remaining_hp": threat_hp,
		"max_hp": threat_max_hp,
		"defeated": defeated_now,
	}


func apply_camp_defense_pulse(camp_built: bool) -> Dictionary:
	if not camp_built:
		return {"ok": false, "reason": "Build First Camp before activating Ward Pulse."}
	if not is_encounter_active() or threat_is_defeated:
		return {"ok": false, "not_active": true, "reason": "Ward Pulse can only be used during an active night threat."}
	if is_defense_on_cooldown():
		return {
			"ok": false,
			"on_cooldown": true,
			"cooldown_remaining": defense_cooldown_remaining,
			"reason": "Ward Pulse recharging (%.1fs)." % defense_cooldown_remaining,
		}

	var push_dir: float = 1.0 if threat_x >= CAMP_CENTER_X else -1.0
	var push_dist: float = BREACH_PUSHBACK_PX if threat_class == ThreatClass.BREACH_CAPABLE else ORDINARY_PUSHBACK_PX
	var stagger_sec: float = BREACH_STAGGER_SEC if threat_class == ThreatClass.BREACH_CAPABLE else ORDINARY_STAGGER_SEC
	var was_breached: bool = camp_breached

	threat_x = clampf(threat_x + push_dir * push_dist, MIN_WORLD_X, MAX_WORLD_X)
	threat_stagger_remaining = stagger_sec
	defense_cooldown_remaining = DEFENSE_PULSE_COOLDOWN_SEC
	defense_pulse_visual_remaining = DEFENSE_PULSE_VISUAL_SEC
	defense_pulse_count += 1
	threat_blocked = false
	player_threatened = false

	var repelled_breach: bool = false
	if was_breached and not is_x_inside_camp_protection(threat_x, camp_built):
		camp_breached = false
		repelled_breach = true

	defense_pulse_activated.emit(active_day, threat_class, threat_x, repelled_breach)
	return {
		"ok": true,
		"day": active_day,
		"threat_class": threat_class,
		"new_threat_x": threat_x,
		"pushback": push_dist,
		"stagger_sec": stagger_sec,
		"repelled_breach": repelled_breach,
	}


func tick(delta: float, player_x: float, camp_built: bool) -> void:
	if delta <= 0.0:
		return
	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - delta)
	if hit_flash_remaining > 0.0:
		hit_flash_remaining = maxf(0.0, hit_flash_remaining - delta)
	if player_invuln_remaining > 0.0:
		player_invuln_remaining = maxf(0.0, player_invuln_remaining - delta)
	if player_hit_flash_remaining > 0.0:
		player_hit_flash_remaining = maxf(0.0, player_hit_flash_remaining - delta)
	if not is_encounter_active() or threat_is_defeated:
		return
	if defense_cooldown_remaining > 0.0:
		defense_cooldown_remaining = maxf(0.0, defense_cooldown_remaining - delta)
	if defense_pulse_visual_remaining > 0.0:
		defense_pulse_visual_remaining = maxf(0.0, defense_pulse_visual_remaining - delta)
	if threat_stagger_remaining > 0.0:
		threat_stagger_remaining = maxf(0.0, threat_stagger_remaining - delta)
		player_threatened = false
		return
	var spd: float = BREACH_SPEED if threat_class == ThreatClass.BREACH_CAPABLE else ORDINARY_SPEED
	var dir: float = signf(player_x - threat_x)
	if is_zero_approx(dir):
		dir = -1.0
	var desired_x: float = clampf(threat_x + dir * spd * delta, MIN_WORLD_X, MAX_WORLD_X)

	# Explicit First Camp protection enforcement:
	# Ordinary threats are strictly blocked outside the protected zone when protection is active (built & integrity > 0).
	if is_camp_protection_active(camp_built) and not can_penetrate_camp_protection(threat_class):
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
	if is_camp_protection_active(camp_built) and can_penetrate_camp_protection(threat_class) and is_x_inside_camp_protection(threat_x, camp_built):
		if not camp_breached:
			camp_breached = true
			var prev_int: int = camp_integrity
			camp_integrity = maxi(0, camp_integrity - BREACH_DAMAGE)
			if camp_integrity != prev_int:
				camp_integrity_changed.emit(camp_integrity, MAX_CAMP_INTEGRITY, camp_integrity - prev_int)
			camp_protection_breached.emit(active_day, threat_archetype, threat_x)

	player_threatened = absf(threat_x - player_x) <= THREAT_CONTACT_RANGE
	if player_threatened and not is_player_invulnerable():
		var shielded_by_camp: bool = threat_class == ThreatClass.ORDINARY and is_x_inside_camp_protection(player_x, camp_built)
		if not shielded_by_camp:
			var knock_dir: int = -1 if player_x <= threat_x else 1
			player_vitality = maxi(0, player_vitality - 1)
			player_hit_flash_remaining = PLAYER_HIT_FLASH_SEC
			if player_vitality <= 0:
				player_overwhelmed_count += 1
				player_vitality = PLAYER_MAX_VITALITY
				player_invuln_remaining = PLAYER_RETREAT_INVULN_SEC
				player_hit_by_threat.emit(active_day, 0, PLAYER_MAX_VITALITY, knock_dir)
				player_overwhelmed.emit(active_day, threat_archetype)
			else:
				player_invuln_remaining = PLAYER_HIT_INVULN_SEC
				player_hit_by_threat.emit(active_day, player_vitality, PLAYER_MAX_VITALITY, knock_dir)


func resolve_encounter(survived: bool = true) -> bool:
	if not is_encounter_active():
		return false
	var resolved_day: int = active_day
	var was_breached: bool = camp_breached
	_day_outcomes[resolved_day] = DayOutcome.RESOLVED
	state = EncounterState.RESOLVED
	threat_blocked = false
	player_threatened = false
	defense_cooldown_remaining = 0.0
	threat_stagger_remaining = 0.0
	defense_pulse_visual_remaining = 0.0
	attack_cooldown_remaining = 0.0
	hit_flash_remaining = 0.0
	encounter_resolved.emit(resolved_day, survived, was_breached)
	return true


func on_sunrise_reached(completed_day: int) -> void:
	if completed_day <= 0:
		return
	restore_player_vitality()
	if is_encounter_active() and active_day == completed_day:
		resolve_encounter(true)
		return
	if is_day_resolved(completed_day):
		if state == EncounterState.RESOLVED:
			state = EncounterState.IDLE
		return
	# Night passed without an encounter being scheduled/started: do NOT mark resolved.
	_day_outcomes[completed_day] = DayOutcome.PASSED_NO_ENCOUNTER
	if state == EncounterState.RESOLVED:
		state = EncounterState.IDLE


func get_status_text() -> String:
	if not is_encounter_active():
		return ""
	if camp_breached:
		return "Night Threat: %s BREACHED First Camp!" % get_threat_display_name(threat_class)
	if is_threat_staggered():
		return "Ward Pulse: %s repelled and staggered!" % get_threat_display_name(threat_class)
	if threat_blocked:
		return "Night Threat: %s held outside First Camp." % get_threat_display_name(threat_class)
	return "Night Threat: %s approaching (x=%.0f)" % [get_threat_display_name(threat_class), threat_x]


func to_save_node_states(camp_built: bool = false) -> Dictionary:
	var out: Dictionary = {}
	for day_key: Variant in _day_outcomes.keys():
		var day_num: int = int(day_key)
		if day_num > 0 and is_day_resolved(day_num):
			out[RESOLVED_DAY_KEY_PREFIX + str(day_num)] = true
	if camp_built:
		var clamped: int = clampi(camp_integrity, 0, MAX_CAMP_INTEGRITY)
		out[CAMP_INTEGRITY_TRACKED_KEY] = true
		for level: int in range(1, MAX_CAMP_INTEGRITY + 1):
			out[CAMP_INTEGRITY_BIT_PREFIX + str(level)] = (clamped >= level)
	return out


func apply_save_node_states(saved_node_states: Variant, camp_built: bool = false) -> void:
	_day_outcomes.clear()
	state = EncounterState.IDLE
	active_day = 0
	threat_blocked = false
	camp_breached = false
	player_threatened = false
	defense_cooldown_remaining = 0.0
	threat_stagger_remaining = 0.0
	defense_pulse_visual_remaining = 0.0
	defense_pulse_count = 0
	threat_hp = 0
	threat_max_hp = 0
	threat_is_defeated = false
	attack_cooldown_remaining = 0.0
	hit_flash_remaining = 0.0
	player_vitality = PLAYER_MAX_VITALITY
	player_invuln_remaining = 0.0
	player_hit_flash_remaining = 0.0
	player_overwhelmed_count = 0
	camp_integrity = MAX_CAMP_INTEGRITY if camp_built else 0
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
				_day_outcomes[day_num] = DayOutcome.RESTORED_RESOLVED

	if not camp_built:
		camp_integrity = 0
		return

	var tracked_val: Variant = d.get(CAMP_INTEGRITY_TRACKED_KEY, null)
	if typeof(tracked_val) != TYPE_BOOL or not bool(tracked_val):
		return

	var valid_bits: bool = true
	for raw_k: Variant in d.keys():
		var k: String = String(raw_k)
		if k == CAMP_INTEGRITY_TRACKED_KEY or not k.begins_with(CAMP_INTEGRITY_BIT_PREFIX):
			continue
		var suffix: String = k.substr(CAMP_INTEGRITY_BIT_PREFIX.length())
		if not suffix.is_valid_int() or typeof(d[raw_k]) != TYPE_BOOL:
			valid_bits = false
			break
		var idx: int = int(suffix)
		if idx < 1 or idx > MAX_CAMP_INTEGRITY:
			valid_bits = false
			break
	if not valid_bits:
		camp_integrity = MAX_CAMP_INTEGRITY
		return

	var restored_val: int = 0
	var saw_false: bool = false
	for level: int in range(1, MAX_CAMP_INTEGRITY + 1):
		var bit_key: String = CAMP_INTEGRITY_BIT_PREFIX + str(level)
		if not d.has(bit_key) or typeof(d[bit_key]) != TYPE_BOOL:
			valid_bits = false
			break
		var bit_on: bool = bool(d[bit_key])
		if bit_on:
			if saw_false:
				valid_bits = false
				break
			restored_val = level
		else:
			saw_false = true
	camp_integrity = clampi(restored_val, 0, MAX_CAMP_INTEGRITY) if valid_bits else MAX_CAMP_INTEGRITY
