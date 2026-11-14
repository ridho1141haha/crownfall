extends SceneTree

const MainScene = preload("res://scenes/main/Main.tscn")
const ForgottenShoreScene = preload("res://scenes/world/ForgottenShore.tscn")


func _init() -> void:
	_test_m8_full_scene_and_gameplay_loop()
	print("PASS: M8 Full Scene & Vertical Slice Integration Test completed successfully.")
	quit(0)


func _test_m8_full_scene_and_gameplay_loop() -> void:
	var test_save_path: String = "user://test_m8_integration_save.json"

	# 1. Instantiate Main.tscn and verify UI buttons
	var main_menu: Control = MainScene.instantiate() as Control
	root.add_child(main_menu)
	var play_btn: Button = main_menu.get_node_or_null("CenterContainer/VBoxContainer/PlayButton") as Button
	var continue_btn: Button = main_menu.get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button
	assert(play_btn != null and continue_btn != null)
	main_menu.free()

	# 2. Instantiate ForgottenShore.tscn and verify child systems
	var session: ForgottenShoreSession = ForgottenShoreScene.instantiate() as ForgottenShoreSession
	root.add_child(session)
	session._ready()
	session.time_manager.auto_advance = false

	# 3. Verify command return accuracy: interacting in empty space returns false
	assert(not session.execute_command(&"interact", 0.0))

	# 4. Move player across Forgotten Shore to collect Gold, Wood, and Stone caches
	assert(session.execute_command(&"interact", -480.0)) # +4 Gold -> 6 Gold
	assert(not session.execute_command(&"interact", -480.0)) # Duplicate collection must return false!
	assert(session.execute_command(&"interact", -110.0)) # +5 Wood -> 7 Wood
	assert(session.execute_command(&"interact", 190.0))  # +3 Stone -> 4 Stone
	assert(session.execute_command(&"interact", -780.0)) # +3 Gold (Shrine POI) -> 9 Gold
	assert(session.economy.get_amount(&"gold") == 9)
	assert(session.economy.get_amount(&"wood") == 7)
	assert(session.economy.get_amount(&"stone") == 4)

	# 5. Recruit Villager at Camp (x=-220) and verify duplicate recruit returns false
	assert(not session.execute_command(&"recruit", 100.0))
	assert(session.execute_command(&"recruit", -220.0))
	assert(not session.execute_command(&"recruit", -220.0))
	assert(session.builder_npc.recruited)

	# 6. Fund Wooden Wall construction at x=360 and verify duplicate build returns false
	assert(not session.execute_command(&"build_wall", 0.0))
	assert(session.execute_command(&"build_wall", 360.0))
	assert(not session.execute_command(&"build_wall", 360.0))
	assert(not session.execute_command(&"repair_wall", 360.0)) # Cannot repair before damaged

	# 7. Simulate Daylight so Builder walks from x=-220 to x=360 and completes the wall
	for _step: int in range(12):
		session._process(1.0)
	assert(session.building_mgr.state == BuildingManager.WallState.COMPLETED)
	assert(session.building_mgr.durability == 150)

	# 8. Advance TimeManager to Sunset -> verify Builder safety override activates
	session.time_manager.advance_time(480.0)
	assert(session.time_manager.current_phase == TimeManager.Phase.SUNSET)
	assert(session.builder_npc.safety_override_active)
	for _step: int in range(5):
		session._process(1.0)
	assert(absf(session.builder_npc.position_x - NPCBuilderAgent.SAFE_ZONE_X) <= NPCBuilderAgent.WORK_RANGE)

	# 9. Advance TimeManager to Night -> test mid-night save/load encounter state preservation
	session.time_manager.advance_time(60.0)
	assert(session.time_manager.current_phase == TimeManager.Phase.NIGHT)
	assert(session.night_mgr.night_active and session.night_mgr.enemy_active)
	for _step: int in range(6):
		session._process(1.0)
	var mid_night_enemy_x: float = session.night_mgr.enemy_x
	var mid_night_hp: int = session.night_mgr.enemy_hp
	assert(mid_night_enemy_x < NightEncounterManager.SPAWN_X)
	assert(session.save_game_state(test_save_path))

	# Reload mid-night save into a second session and confirm enemy did NOT reset to SPAWN_X
	var mid_session: ForgottenShoreSession = ForgottenShoreScene.instantiate() as ForgottenShoreSession
	root.add_child(mid_session)
	mid_session._ready()
	mid_session.time_manager.auto_advance = false
	assert(mid_session.load_game_state(test_save_path))
	assert(is_equal_approx(mid_session.night_mgr.enemy_x, mid_night_enemy_x))
	assert(mid_session.night_mgr.enemy_hp == mid_night_hp)
	mid_session.free()

	# 10. Finish the 180s Night through Sunrise -> verify survival, wall damaged, and sunrise save
	for _step: int in range(174):
		session._process(1.0)
	session.time_manager.advance_time(180.0)
	assert(session.time_manager.current_day == 2)
	assert(session.time_manager.current_phase == TimeManager.Phase.DAYLIGHT)
	assert(session.night_mgr.first_night_survived)
	assert(session.building_mgr.is_standing() and session.building_mgr.state == BuildingManager.WallState.DAMAGED)
	assert(session.save_game_state(test_save_path))

	# 11. Repair damaged wall on Day 2 and verify return value
	assert(session.execute_command(&"repair_wall", 360.0))
	assert(session.building_mgr.state == BuildingManager.WallState.COMPLETED)
	assert(not session.execute_command(&"repair_wall", 360.0))

	session.free()
