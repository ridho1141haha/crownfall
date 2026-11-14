extends SceneTree

const TEST_SAVE_PATH: String = "user://test_m8_integration_save.json"
const MAX_WAIT_FRAMES: int = 120

var _stage: int = 0
var _wait_frames: int = 0
var _checks: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		printerr("TEST FAILURE [test_integration_m8_slice]: " + msg)
		quit(1)
		return false
	return true


func _initialize() -> void:
	Engine.set_meta("crownfall_load_on_start", false)
	var err: Error = change_scene_to_file("res://scenes/main/Main.tscn")
	_check(err == OK, "Initial change_scene_to_file to Main.tscn")


func _process(_delta: float) -> bool:
	_wait_frames += 1
	if _wait_frames > MAX_WAIT_FRAMES:
		_check(false, "Scene transition timed out at stage %d" % _stage)
		return true

	match _stage:
		0:
			if current_scene == null or current_scene.name != "Main":
				return false
			var play_btn: Button = current_scene.get_node_or_null("CenterContainer/VBoxContainer/PlayButton") as Button
			if not _check(play_btn != null, "PlayButton exists on Main.tscn"):
				return true
			play_btn.pressed.emit()
			_wait_frames = 0
			_stage = 1
			return false

		1:
			if current_scene == null or current_scene.name != "ForgottenShore":
				return false
			var session: ForgottenShoreSession = current_scene as ForgottenShoreSession
			if not _check(session != null and session.time_manager != null, "ForgottenShoreSession and @onready time_manager ready"):
				return true
			session.time_manager.auto_advance = false

			if not _check(not session.execute_command(&"interact", 0.0), "Empty interact returns false"):
				return true
			if not _check(session.execute_command(&"interact", -480.0), "Collect west gold chest"):
				return true
			if not _check(not session.execute_command(&"interact", -480.0), "Duplicate interact returns false"):
				return true
			if not _check(session.execute_command(&"interact", -110.0), "Collect timber pile"):
				return true
			if not _check(session.execute_command(&"interact", 190.0), "Collect stone outcrop"):
				return true
			if not _check(session.execute_command(&"interact", -780.0), "Collect shrine cache"):
				return true
			if not _check(session.economy.get_amount(&"gold") == 9 and session.economy.get_amount(&"wood") == 7 and session.economy.get_amount(&"stone") == 4, "Collected balances match 9G/7W/4S"):
				return true

			if not _check(not session.execute_command(&"recruit", 100.0), "Out-of-range recruit rejected"):
				return true
			if not _check(session.execute_command(&"recruit", -220.0), "Recruit Villager at Camp"):
				return true
			if not _check(not session.execute_command(&"recruit", -220.0), "Duplicate recruit rejected"):
				return true
			if not _check(not session.execute_command(&"build_wall", 0.0), "Out-of-range build_wall rejected"):
				return true
			if not _check(session.execute_command(&"build_wall", 360.0), "Fund Wooden Wall at x=360"):
				return true
			if not _check(not session.execute_command(&"build_wall", 360.0), "Duplicate build_wall rejected"):
				return true

			for _step: int in range(12):
				session._process(1.0)
			if not _check(session.building_mgr.state == BuildingManager.WallState.COMPLETED and session.building_mgr.durability == 150, "Builder completed wall to 150 HP"):
				return true

			session.time_manager.advance_time(480.0)
			if not _check(session.time_manager.current_phase == TimeManager.Phase.SUNSET and session.builder_npc.safety_override_active, "Sunset triggers Builder safety override"):
				return true
			for _step: int in range(5):
				session._process(1.0)
			if not _check(absf(session.builder_npc.position_x - NPCBuilderAgent.SAFE_ZONE_X) <= NPCBuilderAgent.WORK_RANGE, "Builder reached safe zone"):
				return true

			session.time_manager.advance_time(60.0)
			if not _check(session.time_manager.current_phase == TimeManager.Phase.NIGHT, "Night started"):
				return true
			for _step: int in range(6):
				session._process(1.0)
			var mid_night_x: float = session.night_mgr.enemy_x
			var mid_night_hp: int = session.night_mgr.enemy_hp
			if not _check(session.save_game_state(TEST_SAVE_PATH), "Mid-night save succeeded"):
				return true

			for _step: int in range(174):
				session._process(1.0)
			session.time_manager.advance_time(180.0)
			if not _check(session.time_manager.current_day == 2 and session.night_mgr.first_night_survived and session.building_mgr.durability == 15, "Survived 3-wave Night 1 with 15 HP wall"):
				return true

			if not _check(session.load_game_state(TEST_SAVE_PATH), "Mid-night state reload succeeded"):
				return true
			if not _check(is_equal_approx(session.night_mgr.enemy_x, mid_night_x) and session.night_mgr.enemy_hp == mid_night_hp, "Mid-night enemy position and HP preserved"):
				return true

			for _step: int in range(174):
				session._process(1.0)
			session.player.global_position.x = 340.0
			session.time_manager.advance_time(180.0)
			if not _check(SaveManager.new().has_valid_save(), "Sunrise Day 2 autosave exists and is valid"):
				return true

			var err_back: Error = change_scene_to_file("res://scenes/main/Main.tscn")
			if not _check(err_back == OK, "Transition back to Main.tscn"):
				return true
			_wait_frames = 0
			_stage = 2
			return false

		2:
			if current_scene == null or current_scene.name != "Main":
				return false
			var continue_btn: Button = current_scene.get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button
			if not _check(continue_btn != null and not continue_btn.disabled, "ContinueButton enabled on Main.tscn"):
				return true
			continue_btn.pressed.emit()
			_wait_frames = 0
			_stage = 3
			return false

		3:
			if current_scene == null or current_scene.name != "ForgottenShore":
				return false
			var loaded_session: ForgottenShoreSession = current_scene as ForgottenShoreSession
			if not _check(loaded_session != null and loaded_session.time_manager != null, "Continue transitioned to ForgottenShoreSession"):
				return true
			if not _check(loaded_session.time_manager.current_day == 2 and loaded_session.night_mgr.first_night_survived, "Continue loaded Day 2 survived state"):
				return true
			if not _check(is_equal_approx(loaded_session.player.global_position.x, 340.0), "Continue restored player position_x == 340.0"):
				return true
			if not _check(loaded_session.builder_npc.recruited and loaded_session.building_mgr.durability == 15, "Continue loaded Builder and 15 HP wall"):
				return true
			if not _check(not bool(loaded_session.collected_node_ids.get("timber_pile_west", false)) and not bool(loaded_session.collected_node_ids.get("stone_outcrop_east", false)), "Continue restores renewable Wood/Stone nodes as available on Day 2"):
				return true
			if not _check(bool(loaded_session.collected_node_ids.get("cache_gold_west", false)) and bool(loaded_session.collected_node_ids.get("shrine_cache_far_west", false)), "Continue keeps non-renewable Gold caches collected"):
				return true
			if not _check(loaded_session.execute_command(&"repair_wall", 360.0) and loaded_session.building_mgr.durability == 150, "Day 2 wall repair to 150 HP"):
				return true

			print("PASS: All %d M8 Multi-Frame Scene Transition & Save/Continue Integration Checks succeeded!" % _checks)
			quit(0)
			return true

	return false
