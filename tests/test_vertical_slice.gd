extends SceneTree

const UnitSuiteScript = preload("res://tests/test_unit_m2_m7.gd")
const IntegrationSuiteScript = preload("res://tests/test_integration_m8_slice.gd")
const MainScene = preload("res://scenes/main/Main.tscn")
const ForgottenShoreScene = preload("res://scenes/world/ForgottenShore.tscn")
const TimeManagerScript = preload("res://scripts/world/TimeManager.gd")
const EconomyLedgerScript = preload("res://scripts/economy/EconomyLedger.gd")
const BuildingManagerScript = preload("res://scripts/kingdom/BuildingManager.gd")
const NPCBuilderAgentScript = preload("res://scripts/npc/NPCBuilderAgent.gd")
const NightEncounterManagerScript = preload("res://scripts/survival/NightEncounterManager.gd")
const SaveManagerScript = preload("res://scripts/save/SaveManager.gd")


func _init() -> void:
	# Run P0 Unit Checks (M2-M7) + P0 Full Scene Integration Check (M8)
	_run_p0_unit_checks()
	_run_m8_scene_integration_check()
	print("ALL M0-M8 P0 VERTICAL SLICE UNIT & SCENE INTEGRATION TESTS PASSED!")
	quit(0)


func _run_p0_unit_checks() -> void:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 2, "wood": 4, "stone": 2})
	var bm: BuildingManager = BuildingManagerScript.new()
	var night: NightEncounterManager = NightEncounterManagerScript.new()
	assert(not ledger.try_add(&"gold", 1.5))
	assert(bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger))
	bm.advance_construction(4.0)
	night.on_night_started()
	for _s: int in range(180):
		night.tick(1.0, true, bm)
	night.on_sunrise_reached(bm)
	assert(night.first_night_survived and bm.is_standing())
	print("PASS: P0 Core Unit Checks (M2-M7)")


func _run_m8_scene_integration_check() -> void:
	var test_save_path: String = "user://test_master_slice_save.json"
	var session: ForgottenShoreSession = ForgottenShoreScene.instantiate() as ForgottenShoreSession
	root.add_child(session)
	session.time_manager.auto_advance = false

	assert(not session.execute_command(&"interact", 0.0))
	assert(session.execute_command(&"interact", -480.0))
	assert(not session.execute_command(&"interact", -480.0))
	assert(session.execute_command(&"interact", -110.0))
	assert(session.execute_command(&"interact", 190.0))
	assert(session.execute_command(&"recruit", -220.0))
	assert(not session.execute_command(&"recruit", -220.0))
	assert(session.execute_command(&"build_wall", 360.0))
	assert(not session.execute_command(&"build_wall", 360.0))

	for _step: int in range(12):
		session._process(1.0)
	assert(session.building_mgr.state == BuildingManager.WallState.COMPLETED)

	session.time_manager.advance_time(480.0)
	assert(session.time_manager.current_phase == TimeManager.Phase.SUNSET)
	session.time_manager.advance_time(60.0)
	assert(session.time_manager.current_phase == TimeManager.Phase.NIGHT)
	for _step: int in range(180):
		session._process(1.0)
	session.time_manager.advance_time(180.0)
	assert(session.night_mgr.first_night_survived)
	assert(session.save_game_state(test_save_path))
	session.free()
	print("PASS: M8 Scene Integration Check (Main -> ForgottenShore -> Full Loop -> Save/Reload)")
