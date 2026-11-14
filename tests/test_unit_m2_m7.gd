extends SceneTree

const TimeManagerScript = preload("res://scripts/world/TimeManager.gd")
const EconomyLedgerScript = preload("res://scripts/economy/EconomyLedger.gd")
const BuildingManagerScript = preload("res://scripts/kingdom/BuildingManager.gd")
const NPCBuilderAgentScript = preload("res://scripts/npc/NPCBuilderAgent.gd")
const NightEncounterManagerScript = preload("res://scripts/survival/NightEncounterManager.gd")
const SaveManagerScript = preload("res://scripts/save/SaveManager.gd")


func _init() -> void:
	_test_m2_world_clock()
	_test_m3_economy_invariants()
	_test_m4_building_and_multiplot()
	_test_m5_npc_builder_and_safety()
	_test_m6_three_balance_scenarios()
	_test_m7_atomic_save_and_rollback()
	print("PASS: All P0 Unit Tests (M2-M7) completed successfully.")
	quit(0)


func _test_m2_world_clock() -> void:
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
	tm.advance_time(-3.0)
	assert(tm.current_day == 1 and tm.current_phase == TimeManager.Phase.DAYLIGHT)
	tm.advance_time(8.0)
	assert(tm.current_phase == TimeManager.Phase.SUNSET)
	tm.advance_time(1.0)
	assert(tm.current_phase == TimeManager.Phase.NIGHT)
	tm.advance_time(3.0)
	assert(tm.current_day == 2 and tm.current_phase == TimeManager.Phase.DAYLIGHT)
	assert(events == ["daylight:1", "sunset:1", "night:1", "sunrise:1", "daylight:2"])
	tm.free()
	print("PASS: M2 World Clock Unit Test")


func _test_m3_economy_invariants() -> void:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 2, "wood": 2, "stone": 1})
	assert(not ledger.try_add(&"iron", 5))
	assert(not ledger.try_add(&"gold", 0))
	assert(not ledger.try_add(&"gold", -3))
	assert(not ledger.try_add(&"gold", 1.5))
	assert(not ledger.try_spend({"gold": 1.25}))
	assert(not ledger.try_add(&"gold", 2000000))
	assert(ledger.get_amount(&"gold") == 2)

	assert(not ledger.try_spend({"gold": 1, "wood": 1, "stone": 5}))
	assert(ledger.get_amount(&"gold") == 2 and ledger.get_amount(&"wood") == 2 and ledger.get_amount(&"stone") == 1)

	assert(ledger.try_add(&"gold", 4))
	assert(ledger.try_add(&"wood", 5))
	assert(ledger.try_add(&"stone", 3))
	assert(ledger.try_spend({"gold": 2, "wood": 4, "stone": 2}))
	assert(ledger.get_amount(&"gold") == 4 and ledger.get_amount(&"wood") == 3 and ledger.get_amount(&"stone") == 2)
	print("PASS: M3 Economy Ledger Unit Test")


func _test_m4_building_and_multiplot() -> void:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 4, "wood": 8, "stone": 4})
	var bm: BuildingManager = BuildingManagerScript.new()
	bm.register_plot("wall_west_01", "wooden_wall", -360.0)

	assert(not bm.request_start_construction(0.0, ledger))
	assert(bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger, "wall_east_01"))
	assert(bm.request_start_construction(-360.0, ledger, "wall_west_01"))
	bm.advance_construction(2.0, "wall_east_01")
	bm.advance_construction(4.0, "wall_west_01")

	var saved_plots: Array[Dictionary] = bm.to_save_array()
	assert(saved_plots.size() == 2)

	var bm_restored: BuildingManager = BuildingManagerScript.new()
	assert(bm_restored.apply_save_array(saved_plots))
	assert(bm_restored.has_plot("wall_west_01"))
	assert(bm_restored.is_standing("wall_west_01"))
	assert(is_equal_approx(bm_restored.construction_progress, 0.5))
	print("PASS: M4 Building Manager & Multi-Plot Persistence Unit Test")


func _test_m5_npc_builder_and_safety() -> void:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 4, "wood": 4, "stone": 2})
	var bm: BuildingManager = BuildingManagerScript.new()
	var npc: NPCBuilderAgent = NPCBuilderAgentScript.new()

	assert(not npc.request_recruit(300.0, ledger))
	assert(npc.request_recruit(NPCBuilderAgent.CAMP_POSITION_X, ledger))
	assert(not npc.request_recruit(NPCBuilderAgent.CAMP_POSITION_X, ledger))
	assert(bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger))

	npc.tick(5.0, bm)
	assert(bm.construction_progress > 0.0)

	npc.set_dusk_or_night_safety(true)
	var prev_x: float = npc.position_x
	npc.tick(1.0, bm)
	assert(npc.position_x < prev_x)

	npc.navigation_blocked = true
	var failed_reasons: Array[String] = []
	npc.safety_path_failed.connect(func(_id: String, reason: String) -> void: failed_reasons.append(reason))
	var stuck_x: float = npc.position_x
	npc.tick(1.0, bm)
	assert(is_equal_approx(npc.position_x, stuck_x) and failed_reasons.size() == 1)
	print("PASS: M5 NPC Builder & Safety Unit Test")


func _test_m6_three_balance_scenarios() -> void:
	# Scenario A: Completed Wall (150 HP) holds against all 3 waves across 180s night and ends DAMAGED (15 HP left)
	var ledger_a: EconomyLedger = EconomyLedgerScript.new({"gold": 2, "wood": 4, "stone": 2})
	var bm_a: BuildingManager = BuildingManagerScript.new()
	var night_a: NightEncounterManager = NightEncounterManagerScript.new()
	bm_a.request_start_construction(BuildingManager.WALL_POSITION_X, ledger_a)
	bm_a.advance_construction(4.0)
	night_a.on_night_started()
	for _sec: int in range(180):
		night_a.tick(1.0, true, bm_a)
	assert(night_a.spawned_wave_count == 3)
	assert(bm_a.is_standing() and bm_a.durability == 15)
	night_a.on_sunrise_reached(bm_a)
	assert(night_a.first_night_survived and not night_a.settlement_breached)

	# Scenario B: Partially Built Wall (50% progress -> 40 HP makeshift barricade) absorbs Wave 1 hits before breaking
	var ledger_b: EconomyLedger = EconomyLedgerScript.new({"gold": 2, "wood": 4, "stone": 2})
	var bm_b: BuildingManager = BuildingManagerScript.new()
	var night_b: NightEncounterManager = NightEncounterManagerScript.new()
	bm_b.request_start_construction(BuildingManager.WALL_POSITION_X, ledger_b)
	bm_b.advance_construction(2.0)
	assert(bm_b.has_defensive_barrier())
	night_b.on_night_started()
	for _sec: int in range(25):
		night_b.tick(1.0, true, bm_b)
	assert(bm_b.state == BuildingManager.WallState.DESTROYED)
	assert(night_b.enemy_hp < NightEncounterManager.ENEMY_MAX_HP)

	# Scenario C: Unbuilt Wall -> Raider marches straight to Town Center and breaches settlement
	var bm_c: BuildingManager = BuildingManagerScript.new()
	var night_c: NightEncounterManager = NightEncounterManagerScript.new()
	night_c.on_night_started()
	for _sec: int in range(15):
		night_c.tick(1.0, true, bm_c)
	assert(night_c.settlement_breached)
	print("PASS: M6 Night Encounter Balance (Completed Wall, Partial Barricade, Unbuilt Breach)")


func _test_m7_atomic_save_and_rollback() -> void:
	var sm: SaveManager = SaveManagerScript.new()
	var test_path: String = "user://test_unit_save.json"
	var night_mgr: NightEncounterManager = NightEncounterManagerScript.new()
	night_mgr.on_night_started()
	night_mgr.tick(3.0, true, null)

	var payload: Dictionary = {
		"schema_version": 1,
		"world_id": "aetherion",
		"island_id": "forgotten_shore",
		"day_count": 2,
		"world_time": 18.5,
		"world_phase": "night",
		"resources": {"gold": 5, "wood": 3, "stone": 1},
		"buildings": [{"id": "wall_east_01", "type": "wooden_wall", "position_x": 360.0, "level": 1, "state": "COMPLETED", "durability": 120, "max_durability": 150, "progress": 1.0}],
		"npcs": [{"id": "npc_01", "recruited": true, "role": "builder", "state": "IDLE", "position_x": 0.0}],
		"night_encounter": night_mgr.to_save_dict(),
		"progression_flags": {"first_night_survived": false},
	}

	assert(not sm.save_state(payload, "res://hack.json"))
	assert(not sm.save_state(payload, "user://../hack.json"))
	assert(sm.save_state(payload, test_path))

	# Update to Day 3, then simulate both write failure and replacement failure; verify Day 3 remains intact
	payload["day_count"] = 3
	assert(sm.save_state(payload, test_path))
	var payload_day4: Dictionary = payload.duplicate(true)
	payload_day4["day_count"] = 4
	assert(not sm.save_state(payload_day4, test_path, true, false))
	assert(not sm.save_state(payload_day4, test_path, false, true))

	var loaded: Dictionary = sm.load_state(test_path)
	assert(bool(loaded["ok"]) and int(loaded["data"]["day_count"]) == 3)
	assert(not FileAccess.file_exists(test_path + ".tmp"))
	assert(not FileAccess.file_exists(test_path + ".old"))
	assert(not FileAccess.file_exists(test_path + ".bak.tmp"))

	# Extreme Case: Active file completely missing after external crash, leaving only .bak -> load_state self-heals active file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	assert(not FileAccess.file_exists(test_path))
	var healed: Dictionary = sm.load_state(test_path)
	assert(bool(healed["ok"]) and bool(healed["recovered_from_backup"]))
	assert(FileAccess.file_exists(test_path))

	# Corrupt active save -> automatic self-healing recovery from verified .bak
	var corrupt_file: FileAccess = FileAccess.open(test_path, FileAccess.WRITE)
	corrupt_file.store_string("{corrupt_json}")
	corrupt_file.close()
	var recovered: Dictionary = sm.load_state(test_path)
	assert(bool(recovered["ok"]) and bool(recovered["recovered_from_backup"]))
	print("PASS: M7 SaveManager Safe Replacement, Rollback & Backup Self-Healing")
