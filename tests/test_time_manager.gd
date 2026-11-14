extends SceneTree

const TimeManagerScript = preload("res://scripts/world/TimeManager.gd")

var _checks: int = 0


func _check(cond: bool, msg: String) -> bool:
\t_checks += 1
\tif not cond:
\t\tprinterr("TEST FAILURE [test_time_manager]: " + msg)
\t\tquit(1)
\t\treturn false
\treturn true


func _init() -> void:
\tvar events: Array[String] = []
\tvar tm: TimeManager = TimeManagerScript.new()
\ttm.auto_advance = false
\ttm.daylight_duration = 8.0
\ttm.sunset_duration = 1.0
\ttm.night_duration = 3.0

\ttm.daylight_started.connect(func(d: int) -> void: events.append("daylight:%d" % d))
\ttm.sunset_started.connect(func(d: int) -> void: events.append("sunset:%d" % d))
\ttm.night_started.connect(func(d: int) -> void: events.append("night:%d" % d))
\ttm.sunrise_reached.connect(func(d: int) -> void: events.append("sunrise:%d" % d))

\ttm.advance_time(0.0)
\ttm.advance_time(-2.0)
\tif not _check(tm.current_day == 1 and tm.current_phase == TimeManager.Phase.DAYLIGHT, "Non-positive delta keeps Day 1 DAYLIGHT"):
\t\treturn

\ttm.advance_time(8.0)
\tif not _check(tm.current_phase == TimeManager.Phase.SUNSET, "Expected SUNSET after 8s"):
\t\treturn
\ttm.advance_time(1.0)
\tif not _check(tm.current_phase == TimeManager.Phase.NIGHT, "Expected NIGHT after 9s"):
\t\treturn
\ttm.advance_time(3.0)
\tif not _check(tm.current_day == 2 and tm.current_phase == TimeManager.Phase.DAYLIGHT, "Expected Day 2 DAYLIGHT after 12s"):
\t\treturn

\tvar expected: Array[String] = ["daylight:1", "sunset:1", "night:1", "sunrise:1", "daylight:2"]
\tif not _check(events == expected, "Unexpected transition sequence: %s" % str(events)):
\t\treturn

\tprint("PASS: test_time_manager (%d checks, %d transitions verified)" % [_checks, events.size()])
\ttm.free()
\tquit(0)
