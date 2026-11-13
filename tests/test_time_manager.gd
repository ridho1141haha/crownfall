extends SceneTree

const TimeManagerScript = preload("res://scripts/world/TimeManager.gd")


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

	# Non-positive delta must not advance time
	tm.advance_time(0.0)
	tm.advance_time(-2.0)
	assert(tm.current_day == 1, "Day should remain 1")
	assert(tm.current_phase == TimeManager.Phase.DAYLIGHT, "Phase should remain DAYLIGHT")

	# Step through a full 12s test cycle
	tm.advance_time(8.0)
	assert(tm.current_phase == TimeManager.Phase.SUNSET, "Expected SUNSET after 8s")
	tm.advance_time(1.0)
	assert(tm.current_phase == TimeManager.Phase.NIGHT, "Expected NIGHT after 9s")
	tm.advance_time(3.0)
	assert(tm.current_day == 2, "Expected Day 2 after 12s")
	assert(tm.current_phase == TimeManager.Phase.DAYLIGHT, "Expected DAYLIGHT on Day 2")

	var expected: Array[String] = ["daylight:1", "sunset:1", "night:1", "sunrise:1", "daylight:2"]
	assert(events == expected, "Unexpected transition sequence: %s" % str(events))

	print("PASS: test_time_manager (%d transitions verified)" % events.size())
	tm.free()
	quit(0)
