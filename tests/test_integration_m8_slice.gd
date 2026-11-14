extends SceneTree

const TEST_SAVE_PATH: String = "user://test_m8_integration_save.json"

var _stage: int = 0


func _initialize() -> void:
	# Ensure a clean start and load Main.tscn as the active SceneTree.current_scene
	Engine.set_meta("crownfall_load_on_start", false)
	var err: Error = change_scene_to_file("res://scenes/main/Main.tscn")
	assert(err == OK, "Failed initial change_scene_to_file to Main.tscn")


func _process(_delta: float) -> bool:
	match _stage:
		0:
			# Wait for Main.tscn to become the active current_scene, then press PlayButton
			if current_scene == null or current_scene.name != "Main":
				return false
			var play_btn: Button = current_scene.get_node_or_null("CenterContainer/VBoxContainer/PlayButton") as Button
			assert(play_btn != null, "PlayButton missing on Main.tscn")
			play_btn.pressed.emit()
			_stage = 1
			return false

		1:
			# Verify PlayButton actually transitioned current_scene to ForgottenShore.tscn!
			if current_scene == null or current_scene.name != "ForgottenShore":
				return false
			var session: ForgottenShoreSession = current_scene as ForgottenShoreSession
			assert(session != null, "Active current_scene is not ForgottenShoreSession")
			session.time_manager.auto_advance = false

			# 1. Verify command return accuracy in empty space
			assert(not session.execute_command(&"interact", 0.0))

			# 2. Collect all 4 Forgotten Shore caches and verify duplicate interact returns false
			assert(session.execute_command(&"interact", -480.0)) # +4 Gold -> 6 Gold
			assert(not session.execute_command(&"interact", -480.0))
			assert(session.execute_command(&"interact", -110.0)) # +5 Wood -> 7 Wood
			assert(session.execute_command(&"interact", 190.0))  # +3 Stone -> 4 Stone
			assert(session.execute_command(&"interact", -780.0)) # +3 Gold (Shrine) -> 9 Gold
			assert(session.economy.get_amount(&"gold") == 9)
			assert(session.economy.get_amount(&"wood") == 7)
			assert(session.economy.get_amount(&"stone") == 4)

			# 3. Recruit Villager at Camp (x=-220) and fund Wooden Wall at x=360
			assert(not session.execute_command(&"recruit", 100.0))
			assert(session.execute_command(&"recruit", -220.0))
			assert(not session.execute_command(&"recruit", -220.0))
			assert(not session.execute_command(&"build_wall", 0.0))
			assert(session.execute_command(&"build_wall", 360.0))
			assert(not session.execute_command(&"build_wall", 360.0))

			# 4. Tick Daylight so Builder completes the wall (150 HP)
			for _step: int in range(12):
				session._process(1.0)
			assert(session.building_mgr.state == BuildingManager.WallState.COMPLETED)
			assert(session.building_mgr.durability == 150)

			# 5. Advance to Sunset -> verify Builder retreats to Town Center safe zone
			session.time_manager.advance_time(480.0)
			assert(session.time_manager.current_phase == TimeManager.Phase.SUNSET)
			assert(session.builder_npc.safety_override_active)
			for _step: int in range(5):
				session._process(1.0)
			assert(absf(session.builder_npc.position_x - NPCBuilderAgent.SAFE_ZONE_X) <= NPCBuilderAgent.WORK_RANGE)

			# 6. Advance to Night -> test mid-night encounter save/load preservation
			session.time_manager.advance_time(60.0)
			assert(session.time_manager.current_phase == TimeManager.Phase.NIGHT)
			for _step: int in range(6):
				session._process(1.0)
			var mid_night_x: float = session.night_mgr.enemy_x
			var mid_night_hp: int = session.night_mgr.enemy_hp
			assert(session.save_game_state(TEST_SAVE_PATH))

			# 7. Complete the 180s Night through Sunrise -> auto-saves to user://save_slot_0.json
			for _step: int in range(174):
				session._process(1.0)
			session.time_manager.advance_time(180.0)
			assert(session.time_manager.current_day == 2)
			assert(session.night_mgr.first_night_survived)
			assert(session.building_mgr.durability == 15)

			# Verify mid-night save restores exact enemy position before transitioning back to Main.tscn
			assert(session.load_game_state(TEST_SAVE_PATH))
			assert(is_equal_approx(session.night_mgr.enemy_x, mid_night_x))
			assert(session.night_mgr.enemy_hp == mid_night_hp)

			# Re-apply Day 2 Sunrise save to default slot so Main.tscn ContinueButton loads Day 2
			for _step: int in range(174):
				session._process(1.0)
			session.time_manager.advance_time(180.0)
			assert(session.save_game_state())

			# Transition back to Main.tscn to test real ContinueButton scene transition
			var err_back: Error = change_scene_to_file("res://scenes/main/Main.tscn")
			assert(err_back == OK)
			_stage = 2
			return false

		2:
			# Wait for Main.tscn to become current_scene, verify ContinueButton is enabled, and press it!
			if current_scene == null or current_scene.name != "Main":
				return false
			var continue_btn: Button = current_scene.get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button
			assert(continue_btn != null and not continue_btn.disabled, "ContinueButton should be enabled when valid save exists")
			continue_btn.pressed.emit()
			_stage = 3
			return false

		3:
			# Verify ContinueButton transitioned current_scene to ForgottenShore.tscn AND auto-loaded Day 2 state!
			if current_scene == null or current_scene.name != "ForgottenShore":
				return false
			var loaded_session: ForgottenShoreSession = current_scene as ForgottenShoreSession
			assert(loaded_session != null)
			assert(loaded_session.time_manager.current_day == 2, "Loaded current_scene should be on Day 2")
			assert(loaded_session.night_mgr.first_night_survived, "Loaded current_scene should preserve first_night_survived")
			assert(loaded_session.builder_npc.recruited, "Loaded current_scene should preserve recruited Builder")
			assert(loaded_session.building_mgr.durability == 15, "Loaded current_scene should preserve damaged wall (15 HP)")

			# Repair damaged wall on loaded scene and verify completion
			assert(loaded_session.execute_command(&"repair_wall", 360.0))
			assert(loaded_session.building_mgr.state == BuildingManager.WallState.COMPLETED)
			assert(loaded_session.building_mgr.durability == 150)
			print("PASS: M8 Full Multi-Frame Scene Transition & Save/Continue Integration Test!")
			quit(0)
			return true

	return false
