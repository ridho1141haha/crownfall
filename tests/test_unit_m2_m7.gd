extends SceneTree

const TimeManagerScript = preload("res://scripts/world/TimeManager.gd")
const EconomyLedgerScript = preload("res://scripts/economy/EconomyLedger.gd")
const BuildingManagerScript = preload("res://scripts/kingdom/BuildingManager.gd")
const NPCBuilderAgentScript = preload("res://scripts/npc/NPCBuilderAgent.gd")
const NightEncounterManagerScript = preload("res://scripts/survival/NightEncounterManager.gd")
const SaveManagerScript = preload("res://scripts/save/SaveManager.gd")

var _failures: int = 0
var _checks: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE [test_unit_m2_m7]: " + msg)
		quit(1)
		return false
	return true


func _init() -> void:
	if not _test_m2_world_clock():
		return
	if not _test_m3_economy_invariants():
		return
	if not _test_m4_building_and_multiplot():
		return
	if not _test_m5_npc_builder_and_safety():
		return
	if not _test_m6_three_balance_scenarios():
		return
	if not _test_m7_atomic_save_and_rollback():
		return
	if not _test_p1_p2_farm_watchtower_stone_wall():
		return
	if _failures > 0:
		quit(1)
		return
	print("PASS: All %d P0 Unit Checks (M2-M7) completed with 0 failures." % _checks)
	quit(0)


func _test_m2_world_clock() -> bool:
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
	if not _check(tm.current_day == 1 and tm.current_phase == TimeManager.Phase.DAYLIGHT, "M2 initial day/phase"):
		return false
	tm.advance_time(8.0)
	if not _check(tm.current_phase == TimeManager.Phase.SUNSET, "M2 transition to SUNSET"):
		return false
	tm.advance_time(1.0)
	if not _check(tm.current_phase == TimeManager.Phase.NIGHT, "M2 transition to NIGHT"):
		return false
	tm.advance_time(3.0)
	if not _check(tm.current_day == 2 and tm.current_phase == TimeManager.Phase.DAYLIGHT, "M2 transition to Day 2 DAYLIGHT"):
		return false
	if not _check(events == ["daylight:1", "sunset:1", "night:1", "sunrise:1", "daylight:2"], "M2 exact signal order"):
		return false
	tm.free()
	print("PASS: M2 World Clock Unit Test")
	return true


func _test_m3_economy_invariants() -> bool:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 2, "wood": 2, "stone": 1})
	if not _check(not ledger.try_add(&"iron", 5), "M3 reject unknown resource"):
		return false
	if not _check(not ledger.try_add(&"gold", 0), "M3 reject zero add"):
		return false
	if not _check(not ledger.try_add(&"gold", -3), "M3 reject negative add"):
		return false
	if not _check(not ledger.try_add(&"gold", 1.5), "M3 reject fractional float add"):
		return false
	if not _check(not ledger.try_spend({"gold": 1.25}), "M3 reject fractional float spend"):
		return false
	if not _check(not ledger.try_add(&"gold", 2000000), "M3 reject cap overflow"):
		return false
	if not _check(ledger.get_amount(&"gold") == 2, "M3 unchanged balance after rejections"):
		return false

	if not _check(not ledger.try_spend({"gold": 1, "wood": 1, "stone": 5}), "M3 reject partial multi-spend"):
		return false
	if not _check(ledger.get_amount(&"gold") == 2 and ledger.get_amount(&"wood") == 2 and ledger.get_amount(&"stone") == 1, "M3 atomic rollback"):
		return false

	if not _check(ledger.try_add(&"gold", 4) and ledger.try_add(&"wood", 5) and ledger.try_add(&"stone", 3), "M3 valid adds"):
		return false
	if not _check(ledger.try_spend({"gold": 2, "wood": 4, "stone": 2}), "M3 valid multi-spend"):
		return false
	if not _check(ledger.get_amount(&"gold") == 4 and ledger.get_amount(&"wood") == 3 and ledger.get_amount(&"stone") == 2, "M3 final balances"):
		return false
	print("PASS: M3 Economy Ledger Unit Test")
	return true


func _test_m4_building_and_multiplot() -> bool:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 4, "wood": 8, "stone": 4})
	var bm: BuildingManager = BuildingManagerScript.new()
	bm.register_plot("wall_west_01", "wooden_wall", -360.0)

	if not _check(not bm.request_start_construction(0.0, ledger), "M4 reject out-of-range placement"):
		return false
	if not _check(bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger, "wall_east_01"), "M4 start east wall"):
		return false
	if not _check(bm.request_start_construction(-360.0, ledger, "wall_west_01"), "M4 start west wall"):
		return false
	bm.advance_construction(2.0, "wall_east_01")
	bm.advance_construction(4.0, "wall_west_01")

	var saved_plots: Array[Dictionary] = bm.to_save_array()
	if not _check(saved_plots.size() == 2, "M4 to_save_array size == 2"):
		return false

	var bm_restored: BuildingManager = BuildingManagerScript.new()
	if not _check(bm_restored.apply_save_array(saved_plots), "M4 apply_save_array succeeds"):
		return false
	if not _check(bm_restored.has_plot("wall_west_01") and bm_restored.is_standing("wall_west_01"), "M4 restored west wall standing"):
		return false
	if not _check(is_equal_approx(bm_restored.construction_progress, 0.5), "M4 restored east wall 50% progress"):
		return false
	print("PASS: M4 Building Manager & Multi-Plot Persistence Unit Test")
	return true


func _test_m5_npc_builder_and_safety() -> bool:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 4, "wood": 4, "stone": 2})
	var bm: BuildingManager = BuildingManagerScript.new()
	var npc: NPCBuilderAgent = NPCBuilderAgentScript.new()

	if not _check(not npc.request_recruit(300.0, ledger), "M5 reject out-of-range recruit"):
		return false
	if not _check(npc.request_recruit(NPCBuilderAgent.CAMP_POSITION_X, ledger), "M5 valid recruit at Camp"):
		return false
	if not _check(not npc.request_recruit(NPCBuilderAgent.CAMP_POSITION_X, ledger), "M5 reject duplicate recruit"):
		return false
	if not _check(bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger), "M5 fund wall for Builder"):
		return false

	# Phase 1: Movement ticks (from x=-220 to x=360 at 130 px/s takes ~4.46s; 5x 1.0s ticks arrive at x=360)
	for _step: int in range(5):
		npc.tick(1.0, bm)
	if not _check(absf(npc.position_x - BuildingManager.WALL_POSITION_X) <= NPCBuilderAgent.WORK_RANGE, "M5 Builder arrived within work range"):
		return false

	# Phase 2: Construction work ticks (2x 1.0s ticks on a 4.0s build duration -> 50% progress)
	npc.tick(1.0, bm)
	npc.tick(1.0, bm)
	if not _check(npc.state == NPCBuilderAgent.State.WORKING, "M5 Builder is in WORKING state"):
		return false
	if not _check(is_equal_approx(bm.construction_progress, 0.5), "M5 Builder advanced construction to 50%"):
		return false

	# Phase 3: Dusk safety override interrupts unfinished work and navigates toward Town Center (x=0.0)
	npc.set_dusk_or_night_safety(true)
	var prev_x: float = npc.position_x
	npc.tick(1.0, bm)
	if not _check(npc.state == NPCBuilderAgent.State.RETURNING_TO_SAFETY, "M5 Builder enters RETURNING_TO_SAFETY"):
		return false
	if not _check(npc.position_x < prev_x, "M5 Builder moved toward safe zone"):
		return false

	# Phase 4: Navigation failure emits safety_path_failed without silent teleportation
	npc.navigation_blocked = true
	var failed_reasons: Array[String] = []
	npc.safety_path_failed.connect(func(_id: String, reason: String) -> void: failed_reasons.append(reason))
	var stuck_x: float = npc.position_x
	npc.tick(1.0, bm)
	if not _check(is_equal_approx(npc.position_x, stuck_x) and failed_reasons.size() == 1, "M5 no silent teleport when blocked"):
		return false
	print("PASS: M5 NPC Builder Movement, Construction, Dusk Override & Blocked Path Unit Test")
	return true


func _test_m6_three_balance_scenarios() -> bool:
	# Scenario A: Completed Wall (150 HP) holds against all 3 waves across 180s night and ends DAMAGED (15 HP left)
	var ledger_a: EconomyLedger = EconomyLedgerScript.new({"gold": 2, "wood": 4, "stone": 2})
	var bm_a: BuildingManager = BuildingManagerScript.new()
	var night_a: NightEncounterManager = NightEncounterManagerScript.new()
	bm_a.request_start_construction(BuildingManager.WALL_POSITION_X, ledger_a)
	bm_a.advance_construction(4.0)
	night_a.on_night_started()
	for _sec: int in range(180):
		night_a.tick(1.0, true, bm_a)
	if not _check(night_a.spawned_wave_count == 3, "M6 Scenario A spawned all 3 waves"):
		return false
	if not _check(bm_a.is_standing() and bm_a.durability == 15, "M6 Scenario A wall survives with 15 HP"):
		return false
	night_a.on_sunrise_reached(bm_a)
	if not _check(night_a.first_night_survived and not night_a.settlement_breached, "M6 Scenario A sunrise survived"):
		return false

	# Scenario B: Partially Built Wall (50% progress -> 40 HP makeshift barricade) absorbs Wave 1 hits before breaking
	var ledger_b: EconomyLedger = EconomyLedgerScript.new({"gold": 2, "wood": 4, "stone": 2})
	var bm_b: BuildingManager = BuildingManagerScript.new()
	var night_b: NightEncounterManager = NightEncounterManagerScript.new()
	bm_b.request_start_construction(BuildingManager.WALL_POSITION_X, ledger_b)
	bm_b.advance_construction(2.0)
	if not _check(bm_b.has_defensive_barrier(), "M6 Scenario B partial wall acts as barrier"):
		return false
	night_b.on_night_started()
	for _sec: int in range(25):
		night_b.tick(1.0, true, bm_b)
	if not _check(bm_b.state == BuildingManager.WallState.DESTROYED and night_b.enemy_hp < NightEncounterManager.ENEMY_MAX_HP, "M6 Scenario B partial wall damaged raider before breaking"):
		return false

	# Scenario C: Unbuilt Wall -> Raider marches to Town Center and breaches settlement
	var bm_c: BuildingManager = BuildingManagerScript.new()
	var night_c: NightEncounterManager = NightEncounterManagerScript.new()
	night_c.on_night_started()
	for _sec: int in range(15):
		night_c.tick(1.0, true, bm_c)
	if not _check(night_c.settlement_breached, "M6 Scenario C unbuilt wall breaches Town Center"):
		return false
	print("PASS: M6 Night Encounter Balance (Completed Wall, Partial Barricade, Unbuilt Breach)")
	return true


func _test_m7_atomic_save_and_rollback() -> bool:
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

	if not _check(not sm.save_state(payload, "res://hack.json"), "M7 reject res:// save path"):
		return false
	if not _check(not sm.save_state(payload, "user://../hack.json"), "M7 reject traversal save path"):
		return false
	if not _check(sm.save_state(payload, test_path), "M7 initial save succeeds"):
		return false

	payload["day_count"] = 3
	if not _check(sm.save_state(payload, test_path), "M7 second save succeeds"):
		return false
	var payload_day4: Dictionary = payload.duplicate(true)
	payload_day4["day_count"] = 4
	if not _check(not sm.save_state(payload_day4, test_path, true, false), "M7 simulated tmp write failure rejected"):
		return false
	if not _check(not sm.save_state(payload_day4, test_path, false, true), "M7 simulated mid-swap failure rolled back"):
		return false

	var loaded: Dictionary = sm.load_state(test_path)
	if not _check(bool(loaded["ok"]) and int(loaded["data"]["day_count"]) == 3, "M7 Day 3 preserved after rollback"):
		return false
	if not _check(not FileAccess.file_exists(test_path + ".tmp") and not FileAccess.file_exists(test_path + ".old"), "M7 zero leftover .tmp/.old files"):
		return false

	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	var healed: Dictionary = sm.load_state(test_path)
	if not _check(bool(healed["ok"]) and bool(healed["recovered_from_backup"]) and FileAccess.file_exists(test_path), "M7 missing active file self-healed from .bak"):
		return false
	print("PASS: M7 SaveManager Safe Replacement, Rollback & Backup Self-Healing")
	return true


func _test_p1_p2_farm_watchtower_stone_wall() -> bool:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 12, "wood": 15, "stone": 12})
	var bm: BuildingManager = BuildingManagerScript.new()
	bm.register_forgotten_shore_expansion_plots()
	if not _check(bm.has_plot(BuildingManager.WATCHTOWER_ID) and bm.has_plot(BuildingManager.FARM_WEST_ID) and bm.has_plot(BuildingManager.FARM_EAST_ID), "P2 expansion plots registered"):
		return false
	if not _check(bm.request_start_construction(BuildingManager.FARM_WEST_POSITION_X, ledger, BuildingManager.FARM_WEST_ID), "P2 start Farm West build"):
		return false
	bm.advance_construction(3.5, BuildingManager.FARM_WEST_ID)
	if not _check(bm.is_standing(BuildingManager.FARM_WEST_ID), "P2 Farm West completed"):
		return false
	if not _check(bm.request_start_construction(BuildingManager.WATCHTOWER_POSITION_X, ledger, BuildingManager.WATCHTOWER_ID), "P2 start Watchtower build"):
		return false
	bm.advance_construction(3.5, BuildingManager.WATCHTOWER_ID)
	if not _check(bm.is_standing(BuildingManager.WATCHTOWER_ID), "P2 Watchtower completed"):
		return false
	if not _check(bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger, BuildingManager.WALL_ID), "P2 build Wooden Wall Lv1"):
		return false
	bm.advance_construction(4.0, BuildingManager.WALL_ID)
	if not _check(bm.request_upgrade_wall(BuildingManager.WALL_POSITION_X, ledger, BuildingManager.WALL_ID), "P2 upgrade to Stone Wall Lv2"):
		return false
	if not _check(bm.max_durability == BuildingManager.STONE_WALL_MAX_DURABILITY and bm.get_thorn_damage() == 20, "P2 Stone Wall Lv2 has 260 HP and 20 thorn dmg"):
		return false
	print("PASS: P1/P2 Farm Plot, Watchtower & Stone Wall Tier 2 Unit Test")
	return true
