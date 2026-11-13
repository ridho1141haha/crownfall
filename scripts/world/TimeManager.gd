class_name TimeManager
extends Node

signal daylight_started(day_number: int)
signal sunset_started(day_number: int)
signal night_started(day_number: int)
signal sunrise_reached(completed_day: int)

enum Phase {
	DAYLIGHT,
	SUNSET,
	NIGHT,
}

@export var daylight_duration: float = 480.0
@export var sunset_duration: float = 60.0
@export var night_duration: float = 180.0
@export var time_scale: float = 1.0
@export var auto_advance: bool = true

var current_day: int = 1
var current_phase: Phase = Phase.DAYLIGHT
var phase_elapsed: float = 0.0
var _started: bool = false


func _ready() -> void:
	_emit_initial_phase_if_needed()


func _process(delta: float) -> void:
	if not auto_advance:
		return
	advance_time(delta * time_scale)


func advance_time(delta: float) -> void:
	if delta <= 0.0:
		return
	_emit_initial_phase_if_needed()

	var remaining: float = delta
	while remaining > 0.0:
		var duration: float = get_current_phase_duration()
		var time_left: float = duration - phase_elapsed
		if remaining < time_left:
			phase_elapsed += remaining
			remaining = 0.0
		else:
			remaining -= time_left
			_transition_to_next_phase()


func get_current_phase_duration() -> float:
	match current_phase:
		Phase.DAYLIGHT:
			return maxf(daylight_duration, 0.01)
		Phase.SUNSET:
			return maxf(sunset_duration, 0.01)
		Phase.NIGHT:
			return maxf(night_duration, 0.01)
	return 1.0


func get_phase_progress() -> float:
	return clampf(phase_elapsed / get_current_phase_duration(), 0.0, 1.0)


func get_phase_name() -> String:
	match current_phase:
		Phase.DAYLIGHT:
			return "Daylight"
		Phase.SUNSET:
			return "Sunset"
		Phase.NIGHT:
			return "Night"
	return "Unknown"


func _emit_initial_phase_if_needed() -> void:
	if _started:
		return
	_started = true
	daylight_started.emit(current_day)


func _transition_to_next_phase() -> void:
	phase_elapsed = 0.0
	match current_phase:
		Phase.DAYLIGHT:
			current_phase = Phase.SUNSET
			sunset_started.emit(current_day)
		Phase.SUNSET:
			current_phase = Phase.NIGHT
			night_started.emit(current_day)
		Phase.NIGHT:
			var completed_day: int = current_day
			sunrise_reached.emit(completed_day)
			current_day += 1
			current_phase = Phase.DAYLIGHT
			daylight_started.emit(current_day)
