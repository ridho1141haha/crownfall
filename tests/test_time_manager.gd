extends SceneTree

const TimeManagerScript = preload("res://scripts/world/TimeManager.gd")

var _checks: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		printerr("TEST FAILURE [test_time_manager]: " + msg)
		quit(1)
		return false
	return true


func _init() -> void:
	var events: Array[String] = []
	var tm: TimeManager = TimeManagerScript.new()
	tm.auto_advance = false
	tm.daylight_duration = 8.0
	tm.sunset_duration = 1.0
	tm.night_duration = 3.0

	tm.daylight_started.connect(func(d: int) -> void: events.append("daylight:%d" % d))
	tm.sunset_started.connect(func(d: int) -> void: events.append("sunset:%d" % d))
	tm.night_started.connect(func(d: int) -> void: events.append("night:%d" % d))
	tm.sunrise_reached.connect(func(d: int) -> void: events.append("sunrise:%d" % d))

	tm.advance_time(0.0)
	tm.advance_time(-2.0)
	if not _check(tm.current_day == 1 and tm.current_phase == TimeManager.Phase.DAYLIGHT, "Non-positive delta keeps Day 1 DAYLIGHT"):
		return

	tm.advance_time(8.0)
	if not _check(tm.current_phase == TimeManager.Phase.SUNSET, "Expected SUNSET after 8s"):
		return
	tm.advance_time(1.0)
	if not _check(tm.current_phase == TimeManager.Phase.NIGHT, "Expected NIGHT after 9s"):
		return
	tm.advance_time(3.0)
	if not _check(tm.current_day == 2 and tm.current_phase == TimeManager.Phase.DAYLIGHT, "Expected Day 2 DAYLIGHT after 12s"):
		return

	var expected: Array[String] = ["daylight:1", "sunset:1", "night:1", "sunrise:1", "daylight:2"]
	if not _check(events == expected, "Unexpected transition sequence: %s" % str(events)):
		return

	print("PASS: test_time_manager (%d checks, %d transitions verified)" % [_checks, events.size()])
	tm.free()
	quit(0)
