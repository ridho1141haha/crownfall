extends SceneTree

const MainScene = preload("res://scenes/main/Main.tscn")
const ForgottenShoreScene = preload("res://scenes/world/ForgottenShore.tscn")


func _init() -> void:
	_test_m8_full_scene_and_gameplay_loop()
	print("PASS: M8 Full Scene & Vertical Slice Integration Test completed successfully.")
	quit(0)


func _test_m8_full_scene_and_gameplay_loop() -> void:
	var test_save_path: String = "user://test_m8_integration_save.json"

	# 1. Instantiate Main.tscn (Godot automatically calls _ready() on root.add_child) and trigger PlayButton transition
	var main_menu: Control = MainScene.instantiate() as Control
	root.add_child(main_menu)
	var play_btn: Button = main_menu.get_node_or_null("CenterContainer/VBoxContainer/PlayButton") as Button
	var continue_btn: Button = main_menu.get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button
	assert(play_btn != null and continue_btn != null)

	var transitioned_scenes: Array[String] = []
	var transitioned_load_flags: Array[bool] = []
	main_menu.connect("scene_transition_requested", func(path: String, load_flag: bool) -> void:
		transitioned_scenes.append(path)
		transitioned_load_flags.append(load_flag)
	)
	play_btn.pressed.emit()
	assert(transitioned_scenes == ["res://scenes/world/ForgottenShore.tscn"])
	assert(transitioned_load_flags == [false])
	assert(not bool(Engine.get_meta("crownfall_load_on_start")))
	main_menu.free()

	# 2. Instantiate ForgottenShore.tscn (lifecycle _ready() runs automatically once via add_child)
	var session: ForgottenShoreSession = ForgottenShoreScene.instantiate() as ForgottenShoreSession
	root.add_child(session)
	session.time_manager.auto_advance = false

	# 3. Verify command return accuracy: interacting in empty space returns false
	assert(not session.execute_command(&"interact", 0.0))

	# 4. Move player across Forgotten Shore to collect Gold, Wood, and Stone caches
	assert(session.execute_command(&"interact", -480.0)) # +4 Gold -> 6 Gold
	assert(not session.execute_command(&"interact", -480.0)) # Duplicate collection must return false
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
	assert(not session.execute_command(&"repair_wall", 360.0))

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

	# Reload mid-night save into a second session (no manual _ready() call) and confirm enemy did NOT reset
	var mid_session: ForgottenShoreSession = ForgottenShoreScene.instantiate() as ForgottenShoreSession
	root.add_child(mid_session)
	mid_session.time_manager.auto_advance = false
	assert(mid_session.load_game_state(test_save_path))
	assert(is_equal_approx(mid_session.night_mgr.enemy_x, mid_night_enemy_x))
	assert(mid_session.night_mgr.enemy_hp == mid_night_hp)
	mid_session.free()

	# 10. Finish the 180s Night through Sunrise -> verify survival, wall damaged (15 HP left), and sunrise save
	for _step: int in range(174):
		session._process(1.0)
	session.time_manager.advance_time(180.0)
	assert(session.time_manager.current_day == 2)
	assert(session.time_manager.current_phase == TimeManager.Phase.DAYLIGHT)
	assert(session.night_mgr.first_night_survived)
	assert(session.building_mgr.is_standing() and session.building_mgr.state == BuildingManager.WallState.DAMAGED)
	assert(session.building_mgr.durability == 15)
	assert(session.save_game_state(test_save_path))
	assert(session.save_game_state()) # Also write default save_slot_0.json so Main.tscn ContinueButton enables

	# 11. Verify Main.tscn ContinueButton enables and transitions with crownfall_load_on_start = true
	var main_menu_after: Control = MainScene.instantiate() as Control
	root.add_child(main_menu_after)
	var cont_btn_after: Button = main_menu_after.get_node("CenterContainer/VBoxContainer/ContinueButton") as Button
	assert(not cont_btn_after.disabled)
	cont_btn_after.pressed.emit()
	assert(bool(Engine.get_meta("crownfall_load_on_start")))
	Engine.set_meta("crownfall_load_on_start", false)
	main_menu_after.free()

	# 12. Repair damaged wall on Day 2 and verify return value
	assert(session.execute_command(&"repair_wall", 360.0))
	assert(session.building_mgr.state == BuildingManager.WallState.COMPLETED)
	assert(not session.execute_command(&"repair_wall", 360.0))

	session.free()
