extends SceneTree

const TimeManagerScript = preload("res://scripts/world/TimeManager.gd")
const EconomyLedgerScript = preload("res://scripts/economy/EconomyLedger.gd")
const BuildingManagerScript = preload("res://scripts/kingdom/BuildingManager.gd")
const NPCBuilderAgentScript = preload("res://scripts/npc/NPCBuilderAgent.gd")
const NightEncounterManagerScript = preload("res://scripts/survival/NightEncounterManager.gd")
const SaveManagerScript = preload("res://scripts/save/SaveManager.gd")
const NPCPopulationManagerScript = preload("res://scripts/npc/NPCPopulationManager.gd")
const ResourceNodeManagerScript = preload("res://scripts/world/ResourceNodeManager.gd")
const HearthSystemScript = preload("res://scripts/kingdom/HearthSystem.gd")
const InteractionResolverScript = preload("res://scripts/player/InteractionResolver.gd")

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


func _test_v143_era_progression() -> bool:
	# 1. Wood Age bawaan; loader data-driven dari data/eras.json
	var era: EraProgressionManager = EraProgressionManager.new()
	if not _check(era.get_era_id() == "wood_age" and era.get_era_name() == "Wood Age", "v1.4.3 Era starts at Wood Age from data/eras.json"):
		return false

	# 2. Stone Age terbuka oleh Stone Wall Tier 2 (bertahap, tidak sekaligus)
	if not _check(era.notify_stone_wall_built() and era.get_era_id() == "stone_age", "v1.4.3 Stone Wall Tier 2 unlocks Stone Age"):
		return false
	if not _check(not era.notify_stone_wall_built(), "v1.4.3 Stone Age notification is idempotent"):
		return false

	# 3. Koreksi era Fase 2: Shipwreck Stage 3 TIDAK lagi membuka Iron Age.
	#    notify_vessel_ready() diganti notify_eldergrove_milestone() yang
	#    fail-closed: era hanya maju ke Iron Age bila fakta eldergrove_reached
	#    sudah tercatat di ProgressionState yang diberikan.
	var era2: EraProgressionManager = EraProgressionManager.new()
	var prog2: ProgressionState = ProgressionState.new()
	if not _check(not era2.notify_eldergrove_milestone(prog2) and era2.get_era_id() == "wood_age", "Phase 2 notify_eldergrove_milestone without the Eldergrove fact is fail-closed (era unchanged)"):
		return false
	if not _check(not era2.notify_eldergrove_milestone(null), "Phase 2 notify_eldergrove_milestone with null progression is fail-closed"):
		return false
	if not _check(prog2.record_fact(ProgressionState.FACT_ELDERGROVE_REACHED) and era2.notify_eldergrove_milestone(prog2) and era2.get_era_id() == "iron_age", "Phase 2 recorded Eldergrove milestone fact unlocks Iron Age"):
		return false

	# 4. Simpan/muat era
	var era3: EraProgressionManager = EraProgressionManager.new()
	if not _check(not era3.apply_save_era("bogus_era") and era3.get_era_id() == "wood_age", "v1.4.3 apply_save_era rejects unknown id"):
		return false
	if not _check(era3.apply_save_era("stone_age") and era3.to_save_id() == "stone_age", "v1.4.3 apply_save_era restores Stone Age"):
		return false

	# 5. Migrasi save lama: backfill current_day_number dari day_count dan
	#    inferensi era dari bangunan batu
	var ne_v1: Dictionary = NightEncounterManagerScript.new().to_save_dict()
	ne_v1.erase("current_day_number")
	var v1_payload: Dictionary = {
		"schema_version": 1, "world_id": "aetherion", "island_id": "forgotten_shore",
		"day_count": 2, "world_time": 10.0, "world_phase": "night",
		"resources": {"gold": 2, "wood": 2, "stone": 1},
		"buildings": [{"id": "wall_east_01", "type": "stone_wall", "state": "COMPLETED", "durability": 260, "max_durability": 260}],
		"npcs": [{"id": "npc_01", "recruited": true, "role": "builder", "state": "IDLE", "position_x": 0.0}],
		"night_encounter": ne_v1,
		"progression_flags": {"first_night_survived": false},
	}
	var migrated_v1: Dictionary = SaveManagerScript.migrate_payload(v1_payload) as Dictionary
	var mig_pf: Dictionary = migrated_v1["progression_flags"] as Dictionary
	if not _check(String(mig_pf.get("era_id", "")) == "stone_age", "v1.4.3 v1 migration infers Stone Age from stone wall"):
		return false
	if not _check(int((migrated_v1["night_encounter"] as Dictionary).get("current_day_number", 0)) == 2, "v1.4.3 migration backfills current_day_number from day_count"):
		return false
	var v1_wo: Dictionary = v1_payload.duplicate(true)
	(v1_wo["buildings"] as Array)[0] = {"id": "wall_east_01", "type": "wooden_wall", "state": "COMPLETED", "durability": 150, "max_durability": 150}
	var migrated_wo: Dictionary = SaveManagerScript.migrate_payload(v1_wo) as Dictionary
	if not _check(String((migrated_wo["progression_flags"] as Dictionary).get("era_id", "")) == "wood_age", "v1.4.3 migration infers Wood Age without stone wall"):
		return false

	# 6. Validasi ketat: era_id asing ditolak
	var sm_era: SaveManager = SaveManagerScript.new()
	var era_payload: Dictionary = {
		"schema_version": 2, "world_id": "aetherion", "island_id": "forgotten_shore",
		"day_count": 1, "world_time": 0.0, "world_phase": "daylight",
		"resources": {"gold": 2, "wood": 2, "stone": 1},
		"buildings": [{"id": "wall_east_01", "type": "wooden_wall", "state": "COMPLETED", "durability": 150, "max_durability": 150}],
		"npcs": [{"id": "npc_01", "recruited": true, "role": "builder", "state": "IDLE", "position_x": 0.0}],
		"night_encounter": NightEncounterManagerScript.new().to_save_dict(),
		"progression_flags": {"era_id": "space_age"},
	}
	if not _check(not sm_era.validate_payload(era_payload), "v1.4.3 SaveManager rejects unknown era_id"):
		return false

	# 7. Sesi: era tersimpan & dipulihkan lewat jalur apply transaksional
	var session_script2: GDScript = load("res://scripts/world/ForgottenShoreSession.gd")
	var sess_era: ForgottenShoreSession = session_script2.new()
	sess_era.era_mgr.apply_save_era("stone_age")
	var era_payload2: Dictionary = sess_era.build_save_payload()
	if not _check(String((era_payload2["progression_flags"] as Dictionary).get("era_id", "")) == "stone_age", "v1.4.3 session save payload carries era_id"):
		return false
	sess_era.era_mgr = EraProgressionManager.new()
	if not _check(sess_era.era_mgr.get_era_id() == "wood_age" and sess_era._apply_loaded_payload(era_payload2), "v1.4.3 transactional payload apply restores era"):
		return false
	if not _check(sess_era.era_mgr.get_era_id() == "stone_age", "v1.4.3 era restored after transactional payload apply"):
		return false

	print("PASS: v1.4.3 Era Progression + Phase 2 Eldergrove Iron Gate & Save Migration")
	return true


func _init() -> void:
	# Run EVERY suite even after failures, then report a full recap
	var suite_names: Array[String] = [
		"M2 World Clock", "M3 Economy", "M4 Buildings/Multi-plot", "M5 NPC Builder",
		"M6 Balance", "M6 Watchtower Support", "M7 Atomic Save", "P1/P2 Tier2",
		"M7 v1->v2 Migration", "P3 Multi-NPC", "P4 Last Light", "P5/P7 Shipwreck",
		"Task1 Modules", "Task2 Softlock/Flare", "P0 Atomicity/Bounds", "v1.4.1 Forest",
		"v1.4.3 Era",
	]
	var suites: Array[Callable] = [
		_test_m2_world_clock, _test_m3_economy_invariants, _test_m4_building_and_multiplot,
		_test_m5_npc_builder_and_safety, _test_m6_three_balance_scenarios,
		_test_m6_watchtower_support, _test_m7_atomic_save_and_rollback,
		_test_p1_p2_farm_watchtower_stone_wall, _test_m7_schema_v1_migration,
		_test_p3_multi_npc_tool_stands_and_lock, _test_p4_light_burn_and_enemy_archetypes,
		_test_p5_shipwreck_and_v2_save, _test_task1_modules_and_save_roundtrip,
		_test_task2_softlock_flare_west_lane, _test_p0_atomicity_and_bounds,
		_test_v141_forest_autochop_and_west_guard,
		_test_v143_era_progression,
	]
	var failed_suites: Array[String] = []
	for i: int in range(suites.size()):
		var checks_before: int = _checks
		var ok: bool = false
		ok = suites[i].call()
		if not ok:
			failed_suites.append("%s (after %d checks)" % [suite_names[i], _checks - checks_before])
	if _failures > 0 or not failed_suites.is_empty():
		printerr("RECAP: %d/%d suites FAILED -> %s" % [failed_suites.size(), suites.size(), ", ".join(failed_suites)])
		quit(1)
		return
	print("PASS: All %d P0 Unit Checks (M2-M7) completed with 0 failures across %d suites." % [_checks, suites.size()])
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
	# Scenario A: Passive thorn alone (5 dmg/hit) no longer holds Night 1 — wall falls during wave 2 and settlement breaches
	var ledger_a: EconomyLedger = EconomyLedgerScript.new({"gold": 2, "wood": 4, "stone": 2})
	var bm_a: BuildingManager = BuildingManagerScript.new()
	var night_a: NightEncounterManager = NightEncounterManagerScript.new()
	bm_a.request_start_construction(BuildingManager.WALL_POSITION_X, ledger_a)
	bm_a.advance_construction(4.0)
	night_a.on_night_started()
	for _sec: int in range(180):
		night_a.tick(1.0, true, bm_a)
	if not _check(night_a.spawned_wave_count == 2, "M6 Scenario A passive-only defense falls during wave 2 (wave 3 blocked after breach)"):
		return false
	if not _check(not bm_a.is_standing() and not bm_a.has_defensive_barrier(), "M6 Scenario A wooden wall destroyed without active defense"):
		return false
	if not _check(night_a.settlement_breached, "M6 Scenario A settlement breached when relying on thorn alone"):
		return false
	night_a.on_sunrise_reached(bm_a)
	if not _check(not night_a.first_night_survived, "M6 Scenario A first night NOT survived without active defense"):
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



func _test_m6_watchtower_support() -> bool:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 5, "wood": 7, "stone": 5})
	var bm: BuildingManager = BuildingManagerScript.new()
	bm.register_forgotten_shore_expansion_plots()
	var night: NightEncounterManager = NightEncounterManagerScript.new()
	if not _check(bm.get_watchtower_support_damage() == 0, "M6 Scenario D no tower support before Watchtower is built"):
		return false
	if not _check(bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger), "M6 Scenario D fund wall"):
		return false
	if not _check(bm.request_start_construction(BuildingManager.WATCHTOWER_POSITION_X, ledger, BuildingManager.WATCHTOWER_ID), "M6 Scenario D fund Watchtower"):
		return false
	bm.advance_construction(4.0)
	bm.advance_construction(3.5, BuildingManager.WATCHTOWER_ID)
	if not _check(bm.get_watchtower_support_damage() == BuildingManager.WATCHTOWER_SUPPORT_DAMAGE, "M6 Scenario D completed Watchtower grants support damage"):
		return false
	night.on_night_started()
	for _sec: int in range(180):
		night.tick(1.0, true, bm)
	if not _check(night.spawned_wave_count == 3, "M6 Scenario D spawned all 3 waves"):
		return false
	if not _check(bm.is_standing() and bm.durability == 15, "M6 Scenario D wall ends with 15 HP thanks to Watchtower support (5 thorn + 10 support kills raiders in 3 hits)"):
		return false
	night.on_sunrise_reached(bm)
	if not _check(night.first_night_survived and not night.settlement_breached, "M6 Scenario D sunrise survived"):
		return false
	print("PASS: M6 Watchtower Support Damage (wall 15 HP with tower vs passive-only breach)")
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


func _test_m7_schema_v1_migration() -> bool:
	var sm: SaveManager = SaveManagerScript.new()
	var v1_path: String = "user://test_unit_save_v1.json"
	var v1_payload: Dictionary = {
		"schema_version": 1,
		"world_id": "aetherion",
		"island_id": "forgotten_shore",
		"day_count": 2,
		"world_time": 5.0,
		"world_phase": "daylight",
		"resources": {"gold": 4, "wood": 3, "stone": 2},
		"buildings": [{"id": "wall_east_01", "state": "COMPLETED", "durability": 150, "max_durability": 150, "progress": 1.0}],
		"npcs": [{"id": "npc_01", "recruited": true, "role": "builder", "state": "IDLE", "position_x": 0.0}],
		"night_encounter": {"night_active": false, "night_elapsed": 0.0, "spawned_wave_count": 0, "enemy_active": false, "enemy_x": 820.0, "enemy_hp": 0, "settlement_breached": false, "first_night_survived": true},
		"progression_flags": {"first_night_survived": true},
	}
	var f: FileAccess = FileAccess.open(v1_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(v1_payload))
	f.close()
	var loaded: Dictionary = sm.load_state(v1_path)
	if not _check(bool(loaded.get("ok", false)), "M7 v1 legacy save loads cleanly via migration"):
		return false
	var d: Dictionary = loaded["data"]
	if not _check(int(d["schema_version"]) == 2 and d.has("player") and d["progression_flags"].has("reign_state"), "M7 v1 save migrated to schema_version 2"):
		return false
	print("PASS: M7 SaveManager v1 -> v2 Migration Test")
	return true


func _test_p3_multi_npc_tool_stands_and_lock() -> bool:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 15, "wood": 12, "stone": 12})
	var bm: BuildingManager = BuildingManagerScript.new()
	bm.register_forgotten_shore_expansion_plots()
	var pop: NPCPopulationManager = NPCPopulationManagerScript.new()
	pop.camp_vagrants_available = 2

	# Recruit npc_01 (builder) and npc_02 (villager -> farmer via scythe_stand)
	var a1: NPCBuilderAgent = pop.recruit_next_vagrant(-220.0, ledger)
	var a2: NPCBuilderAgent = pop.recruit_next_vagrant(-220.0, ledger)
	if not _check(a1 != null and a1.role == "builder" and a2 != null and a2.role == "villager", "P3 recruited npc_01 builder + npc_02 villager"):
		return false
	var farmer: NPCBuilderAgent = pop.assign_tool_stand("scythe_stand", ledger, bm)
	if not _check(farmer != null and farmer.role == "farmer", "P3 assigned villager to farmer via scythe_stand"):
		return false

	# Task claiming lock: npc_01 claims wall_east_01; another builder cannot double-claim it
	bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger, BuildingManager.WALL_ID)
	if not _check(bm.claim_plot(BuildingManager.WALL_ID, "npc_01") and not bm.claim_plot(BuildingManager.WALL_ID, "npc_03"), "P3 task claiming lock prevents double-claim"):
		return false
	bm.release_plot_claim(BuildingManager.WALL_ID, "npc_01")

	# Recruit npc_03 -> archer via bow_stand and verify Watchtower night volley
	pop.on_sunrise_refill()
	var a3: NPCBuilderAgent = pop.recruit_next_vagrant(-220.0, ledger)
	var archer: NPCBuilderAgent = pop.assign_tool_stand("bow_stand", ledger, bm)
	if not _check(a3 != null and archer != null and archer.role == "archer", "P3 assigned archer via bow_stand"):
		return false

	if not _check(bm.request_start_construction(BuildingManager.WATCHTOWER_POSITION_X, ledger, BuildingManager.WATCHTOWER_ID), "P3 fund Watchtower"):
		return false
	bm.advance_construction(3.5, BuildingManager.WATCHTOWER_ID)
	var night: NightEncounterManager = NightEncounterManagerScript.new()
	night.on_night_started()
	night.enemy_x = 320.0
	archer.position_x = BuildingManager.WATCHTOWER_POSITION_X
	archer.tick(0.5, bm, night)
	if not _check(night.enemy_hp == 5, "P3 Watchtower Archer dealt 40 volley dmg (45 -> 5 HP)"):
		return false

	var saved: Array[Dictionary] = pop.to_save_array()
	var pop2: NPCPopulationManager = NPCPopulationManagerScript.new()
	if not _check(pop2.apply_save_array(saved) and pop2.agents.size() == 3, "P3 multi-NPC save/load round-trip"):
		return false
	print("PASS: P3 Multi-NPC (Builder, Farmer, Archer), Tool Stands & Task Claiming Lock")
	return true


func _test_p4_light_burn_and_enemy_archetypes() -> bool:
	# Verify Day 3 spawns Brute (160 HP) and Solar Brazier Lv.3 (460 px) weakens wall damage by 20% + deals 4 dps burn
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 6, "wood": 6, "stone": 7})
	var bm: BuildingManager = BuildingManagerScript.new()
	bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger)
	bm.advance_construction(4.0)
	bm.request_upgrade_wall(BuildingManager.WALL_POSITION_X, ledger)

	var night: NightEncounterManager = NightEncounterManagerScript.new()
	night.on_night_started(3)
	if not _check(night.get_wave_archetype(3, 3) == "brute" and NightEncounterManager.get_hearth_radius(3) == 460.0, "P4 Day 3 wave 4 is Brute and Hearth Lv3 reaches 460 px"):
		return false

	# Tick 12s inside Hearth Lv3 light (enemy starts at 820, reaches 386 in ~4.6s, enters 460px at ~3.8s)
	for _s: int in range(12):
		night.tick(1.0, true, bm, NightEncounterManager.get_hearth_radius(3), NightEncounterManager.get_hearth_burn_dps(3))
	# Under Lv3 light, Raider deals 12 dmg/hit instead of 15 (weakened 20%) and takes burn DoT
	if not _check(bm.durability > 260 - 45, "P4 Hearth Lv3 Weakened Strike reduced wall damage"):
		return false
	if not _check(not night.enemy_active and night.enemy_hp <= 0, "P4 Hearth Lv3 burn DoT + thorn damage defeated the Raider"):
		return false

	# Isolated burn check: unbuilt wall -> no thorn/attack damage, so any HP loss is burn DoT only
	var night_burn: NightEncounterManager = NightEncounterManagerScript.new()
	var bm_burn: BuildingManager = BuildingManagerScript.new()
	night_burn.on_night_started(1)
	for _s: int in range(12):
		night_burn.tick(1.0, true, bm_burn, NightEncounterManager.get_hearth_radius(1), NightEncounterManager.get_hearth_burn_dps(1))
	if not _check(night_burn.enemy_hp < NightEncounterManager.ENEMY_MAX_HP and night_burn.enemy_hp > 0, "P4 burn DoT alone reduced enemy HP below 45 (no wall, hp=%d)" % night_burn.enemy_hp):
		return false
	if not _check(NightEncounterManager.get_night_forecast(3).contains("Brute"), "P4 Day 3 forecast telegraphs Brute"):
		return false
	print("PASS: P4 The Last Light (Hearth Lv3, Burn DoT, Weakened Strike, Brute & Forecast)")
	return true


func _test_p5_shipwreck_and_v2_save() -> bool:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 6, "wood": 8, "stone": 4})
	# Source stage costs from the production session constant instead of fabricating them
	var session_script: GDScript = load("res://scripts/world/ForgottenShoreSession.gd")
	var stage_costs: Array[Dictionary] = []
	for stage: int in range(3):
		stage_costs.append(session_script.SHIPWRECK_COSTS[stage])
	for cost: Dictionary in stage_costs:
		if not _check(ledger.try_spend(cost), "P5 shipwreck stage spend succeeds"):
			return false
	if not _check(ledger.get_amount(&"gold") == 0 and ledger.get_amount(&"wood") == 0 and ledger.get_amount(&"stone") == 0, "P5 shipwreck total cost == 6G 8W 4S"):
		return false

	var sm: SaveManager = SaveManagerScript.new()
	var p5_path: String = "user://test_unit_save_p5.json"
	var payload: Dictionary = {
		"schema_version": 2,
		"world_id": "aetherion",
		"island_id": "forgotten_shore",
		"day_count": 3,
		"world_time": 12.0,
		"world_phase": "daylight",
		"player": {"position_x": -1350.0, "facing_direction": -1},
		"resources": {"gold": 5, "wood": 4, "stone": 2},
		"buildings": [{"id": "wall_east_01", "type": "stone_wall", "level": 2, "state": "COMPLETED", "durability": 260, "max_durability": 260, "progress": 1.0}],
		"npcs": [{"id": "npc_01", "recruited": true, "role": "builder", "state": "IDLE", "position_x": 0.0}],
		"night_encounter": {"night_active": false, "night_elapsed": 0.0, "spawned_wave_count": 0, "enemy_active": false, "enemy_x": 820.0, "enemy_hp": 0, "enemy_max_hp": 160, "enemy_archetype": "brute", "current_day_number": 3, "settlement_breached": false, "first_night_survived": true},
		"progression_flags": {"first_night_survived": true, "hearth_level": 3, "shipwreck_stage": 3, "portal_relic_looted": true, "reign_state": 2},
	}
	if not _check(sm.save_state(payload, p5_path), "P5 v2 save with Brute/Hearth3/Shipwreck3 succeeds"):
		return false
	var res: Dictionary = sm.load_state(p5_path)
	if not _check(bool(res.get("ok", false)) and int(res["data"]["progression_flags"]["shipwreck_stage"]) == 3, "P5 v2 save round-trip preserves shipwreck_stage == 3"):
		return false
	print("PASS: P5/P7 Shipwreck Total Cost, v2 Save Round-Trip & Follower Hardening")
	return true


func _test_task1_modules_and_save_roundtrip() -> bool:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 12, "wood": 12, "stone": 12})
	var rnm: ResourceNodeManager = ResourceNodeManagerScript.new()
	var c1: Dictionary = rnm.try_collect("timber_pile_west", -110.0, ledger)
	if not _check(bool(c1.get("ok", false)) and rnm.is_collected("timber_pile_west"), "Task1 ResourceNodeManager collects timber_pile_west"):
		return false
	rnm.refresh_renewable_nodes()
	if not _check(not rnm.is_collected("timber_pile_west"), "Task1 renewable Wood node refreshes cleanly"):
		return false

	var hs: HearthSystem = HearthSystemScript.new()
	var h_res: Dictionary = hs.try_upgrade(0.0, ledger)
	if not _check(bool(h_res.get("ok", false)) and hs.hearth_level == 2 and is_equal_approx(hs.get_radius_px(), 320.0), "Task1 HearthSystem upgrades to Lv2 (320 px)"):
		return false

	# Stoke Fire [E]: 1W -> +30% radius & +2 burn DPS for 60s; not stackable; expires via tick_boost
	var broke_ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 5, "wood": 0, "stone": 5})
	if not _check(not bool(hs.try_stoke(0.0, broke_ledger).get("ok", false)), "Task1 Stoke Fire rejected without Wood"):
		return false
	if not _check(not bool(hs.try_stoke(200.0, ledger).get("ok", false)), "Task1 Stoke Fire rejected out of range"):
		return false
	var wood_before_stoke: int = ledger.get_amount(&"wood")
	if not _check(bool(hs.try_stoke(0.0, ledger).get("ok", false)) and ledger.get_amount(&"wood") == wood_before_stoke - 1, "Task1 Stoke Fire spends 1 Wood"):
		return false
	if not _check(hs.is_boost_active() and is_equal_approx(hs.get_effective_radius_px(), 320.0 * HearthSystem.BOOST_RADIUS_MULT) and is_equal_approx(hs.get_effective_burn_dps(), 2.0 + HearthSystem.BOOST_BURN_ADD), "Task1 Stoke Fire boosts radius 30% and burn +2 DPS"):
		return false
	if not _check(not bool(hs.try_stoke(0.0, ledger).get("ok", false)), "Task1 Stoke Fire rejected while boost active"):
		return false
	hs.tick_boost(HearthSystem.BOOST_DURATION_SEC)
	if not _check(not hs.is_boost_active() and is_equal_approx(hs.get_effective_radius_px(), 320.0) and is_equal_approx(hs.get_effective_burn_dps(), 2.0), "Task1 Stoke Fire boost expires after 60s"):
		return false

	# Hearth resolve: [E] = boost_hearth primary, [Q] = upgrade_hearth (E/Q split)
	var bm_hearth: BuildingManager = BuildingManagerScript.new()
	bm_hearth.register_forgotten_shore_expansion_plots()
	var hearth_tgt: Dictionary = InteractionResolverScript.resolve_nearest(0.0, rnm, bm_hearth, null, hs, 0, -1350.0, 1350.0, false)
	if not _check(String(hearth_tgt.get("target_id", "")) == "town_hearth" and (hearth_tgt.get("primary_command", null) as StringName) == &"boost_hearth" and (hearth_tgt.get("upgrade_command", null) as StringName) == &"upgrade_hearth", "Task1 Hearth resolve: [E] Stoke Fire primary + [Q] upgrade"):
		return false

	# Spatial overlap test: Watchtower (210) vs Wall (380) >= 140 px apart; InteractionResolver picks 1 nearest target
	var bm: BuildingManager = BuildingManagerScript.new()
	bm.register_forgotten_shore_expansion_plots()
	var tgt_tower: Dictionary = InteractionResolverScript.resolve_nearest(215.0, rnm, bm, null, hs, 0, -1350.0, 1350.0, false)
	var tgt_wall: Dictionary = InteractionResolverScript.resolve_nearest(360.0, rnm, bm, null, hs, 0, -1350.0, 1350.0, false)
	if not _check(String(tgt_tower.get("target_id", "")) == BuildingManager.WATCHTOWER_ID and String(tgt_wall.get("target_id", "")) == BuildingManager.WALL_ID, "Task1 InteractionResolver disambiguates Watchtower (210) vs Wall (380)"):
		return false

	# SaveManager round-trip with hearth_level, reign_state String, node_states Dictionary
	var sm: SaveManager = SaveManagerScript.new()
	var t1_path: String = "user://test_unit_task1_save.json"
	var payload: Dictionary = {
		"schema_version": 2,
		"world_id": "aetherion",
		"island_id": "forgotten_shore",
		"day_count": 2,
		"world_time": 10.0,
		"world_phase": "daylight",
		"player": {"position_x": 210.0, "facing_direction": 1},
		"resources": ledger.get_all_balances(),
		"buildings": bm.to_save_array(),
		"npcs": [{"id": "npc_01", "recruited": true, "role": "builder", "state": "IDLE", "position_x": 0.0}],
		"night_encounter": NightEncounterManagerScript.new().to_save_dict(),
		"progression_flags": {
			"first_night_survived": true,
			"hearth_level": 2,
			"reign_state": "ISLAND_CLEARED",
			"node_states": rnm.to_save_dict(),
		},
	}
	if not _check(sm.save_state(payload, t1_path), "Task1 SaveManager saves new fields"):
		return false
	var loaded: Dictionary = sm.load_state(t1_path)
	var pf: Dictionary = loaded["data"]["progression_flags"]
	if not _check(bool(loaded["ok"]) and int(pf["hearth_level"]) == 2 and String(pf["reign_state"]) == "ISLAND_CLEARED" and typeof(pf["node_states"]) == TYPE_DICTIONARY, "Task1 SaveManager round-trip preserves hearth_level, reign_state String, node_states"):
		return false
	print("PASS: Task 1 Modules (ResourceNodeManager, HearthSystem, InteractionResolver) & Save v2 Round-Trip")
	return true


func _test_task2_softlock_flare_west_lane() -> bool:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 0, "wood": 4, "stone": 2})
	# Shrine Offering (4W + 2S -> +2G)
	if not _check(ledger.try_spend({"wood": 4, "stone": 2}) and ledger.try_add(&"gold", 2), "Task2 Shrine Offering 4W+2S -> +2G"):
		return false

	# Enemy defeat emits +1G reward and Flare boosts burn/support by +50%
	var bm: BuildingManager = BuildingManagerScript.new()
	bm.register_forgotten_shore_expansion_plots()
	var wall_ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 4, "wood": 6, "stone": 4})
	bm.request_start_construction(BuildingManager.WALL_POSITION_X, wall_ledger)
	bm.advance_construction(4.0)
	if not _check(bm.has_plot(BuildingManager.WEST_WALL_ID), "Task2 West Wall plot registered at x=-400"):
		return false
	var night: NightEncounterManager = NightEncounterManagerScript.new()
	var kill_gold_box: Array[int] = [0]
	night.enemy_defeated.connect(func(_arch: String, rw: int, _px: float) -> void: kill_gold_box[0] += rw)
	night.on_night_started(2)
	night.apply_external_damage(200)
	for _s: int in range(30):
		night.tick(1.0, true, bm, NightEncounterManager.get_hearth_radius(3), NightEncounterManager.get_hearth_burn_dps(3), true)
	if not _check(night.west_spawned_count >= 1, "Task2 Day 2+ spawned West Scout lane"):
		return false
	if not _check(kill_gold_box[0] >= 1, "Task2 enemy defeat awards +1G"):
		return false
	print("PASS: Task 2 Anti-Softlock, Kindle Flare (+50%), West Wall & Day 2 West Scout")
	return true


func _test_p0_atomicity_and_bounds() -> bool:
	var cap_ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 10, "wood": 0, "stone": EconomyLedger.MAX_RESOURCE_CAP})
	if not _check(not cap_ledger.try_add_bundle({"gold": 3, "stone": 2}), "P0 atomic bundle fails when stone at cap"):
		return false
	if not _check(cap_ledger.get_balance(&"gold") == 10 and cap_ledger.get_balance(&"stone") == EconomyLedger.MAX_RESOURCE_CAP, "P0 atomic bundle keeps balances unchanged on failure"):
		return false
	var rep_ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 4, "wood": 10, "stone": 5})
	var bm: BuildingManager = BuildingManagerScript.new()
	bm.request_start_construction(BuildingManager.WALL_POSITION_X, rep_ledger)
	bm.advance_construction(4.0)
	bm.apply_damage(30)
	var wood_before: int = rep_ledger.get_balance(&"wood")
	if not _check(not bm.request_repair(0.0, rep_ledger, BuildingManager.WALL_ID, {"wood": 1}), "P0 repair fails when out of range"):
		return false
	if not _check(rep_ledger.get_balance(&"wood") == wood_before, "P0 out-of-range night repair does not deduct extra wood"):
		return false
	var pop: NPCPopulationManager = NPCPopulationManagerScript.new()
	if not _check(not pop.apply_save_array(["corrupt_entry"]), "P0 NPCPopulationManager rejects corrupt entry"):
		return false
	if not _check(pop.agents.size() == 1, "P0 NPCPopulationManager preserves active roster on failed load"):
		return false
	var net_script = load("res://scripts/networking/NetworkSessionManager.gd")
	var net = net_script.new()
	if not _check(is_equal_approx(net.MIN_WORLD_X, -1540.0) and is_equal_approx(net.MAX_WORLD_X, 1540.0), "P0 NetworkSessionManager bounds synced to +-1540"):
		return false
	print("PASS: P0 Atomicity, Night Repair, Strict NPC Load & Bounds Sync")
	return true


func _test_v141_forest_autochop_and_west_guard() -> bool:
	# 1. Forest 3-hit chop & sunrise regrow
	var forest_script = load("res://scripts/world/ForestTreeManager.gd")
	var fm = forest_script.new()
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 4, "wood": 0, "stone": 0})
	var r1: Dictionary = fm.try_chop("tree_west_01", -680.0, ledger)
	var r2: Dictionary = fm.try_chop("tree_west_01", -680.0, ledger)
	var r3: Dictionary = fm.try_chop("tree_west_01", -680.0, ledger)
	if not _check(bool(r1["ok"]) and bool(r2["ok"]) and bool(r3["ok"]) and bool(r3["felled"]) and ledger.get_amount(&"wood") == 4, "v1.4.1 Forest tree felled in 3 hits (+4 Wood)"):
		return false
	fm.regrow_all()
	if not _check(not fm.is_felled("tree_west_01") and fm.get_hp("tree_west_01") == 3, "v1.4.1 Forest regrows on Sunrise"):
		return false

	# 2. Idle Builder di x=0.0 bisa mendeteksi timber_pile_west (x=-110.0) dan jalan auto-chop
	var rnm: ResourceNodeManager = ResourceNodeManagerScript.new()
	var bm: BuildingManager = BuildingManagerScript.new()
	var night: NightEncounterManager = NightEncounterManagerScript.new()
	var builder: NPCBuilderAgent = NPCBuilderAgentScript.new()
	builder.request_recruit(NPCBuilderAgent.CAMP_POSITION_X, ledger)
	builder.position_x = 0.0
	for _s: int in range(3):
		builder.tick(1.0, bm, night, rnm, ledger)
	if not _check(rnm.is_collected("timber_pile_west") and ledger.get_amount(&"wood") == 9, "v1.4.1 Idle Builder at x=0 walks to x=-110 and auto-chops +5 Wood"):
		return false

	# 3. Archer tidak keluar melewati West Wall (x=-400) saat menjaga West Scout
	var w_ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 4, "wood": 6, "stone": 4})
	bm.register_forgotten_shore_expansion_plots()
	bm.request_start_construction(BuildingManager.WEST_WALL_POSITION_X, w_ledger, BuildingManager.WEST_WALL_ID)
	bm.advance_construction(4.0, BuildingManager.WEST_WALL_ID)
	night.on_night_started(2)
	night.enemy_active = false
	night.west_enemy_active = true
	night.west_enemy_x = -800.0
	var archer: NPCBuilderAgent = NPCBuilderAgentScript.new("npc_02")
	archer.recruited = true
	archer.role = "archer"
	archer.position_x = -350.0
	archer.tick(1.0, bm, night)
	if not _check(archer.position_x >= BuildingManager.WEST_WALL_POSITION_X + 36.0, "v1.4.1 Archer stays behind standing West Wall (x >= -364)"):
		return false

	# 4. Actionable plot selection: Farm East (x=120) COMPLETED tidak menghalangi Watchtower (x=210) PLACEHOLDER saat player di x=125
	var f_ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 10, "wood": 10, "stone": 10})
	bm.request_start_construction(BuildingManager.FARM_EAST_POSITION_X, f_ledger, BuildingManager.FARM_EAST_ID)
	bm.advance_construction(3.5, BuildingManager.FARM_EAST_ID)
	var hs_chk: HearthSystem = HearthSystemScript.new()
	# Node batu terdekat (stone_outcrop_east, x=190; jarak 65) lebih dekat daripada
	# Watchtower (x=210; jarak 85), dan resolver lintas-kategori memang memilih target
	# terdekat. Kumpulkan dulu agar pengujian benar-benar menguji seleksi plot.
	if not _check(bool(rnm.try_collect("stone_outcrop_east", 125.0, f_ledger)["ok"]), "v1.4.2 Stone outcrop (x=190) collected to isolate plot-selection test at x=125"):
		return false
	if not _check(bm.get_nearest_actionable_plot_id(125.0, BuildingManager.INTERACT_RANGE, "any") == BuildingManager.WATCHTOWER_ID, "v1.4.2 get_nearest_actionable_plot_id skips COMPLETED Farm East and returns Watchtower at x=125"):
		return false
	var overlap_tgt: Dictionary = InteractionResolverScript.resolve_nearest(125.0, rnm, bm, null, hs_chk, 0, -1350.0, 1350.0, false)
	if not _check(String(overlap_tgt.get("target_id", "")) == BuildingManager.WATCHTOWER_ID, "v1.4.2 Completed Farm East (x=120) does not block actionable Watchtower (x=210) at x=125"):
		return false

	# 5. Validasi ketat SaveManager: tolak tree_states invalid, plot type mismatch, & active enemy dengan 0 HP
	var sm_chk: SaveManager = SaveManagerScript.new()
	if not _check(not ForestTreeManager.is_valid_saved_tree_states({"unknown_tree": 2}) and not ForestTreeManager.is_valid_saved_tree_states({"tree_west_01": 99}), "v1.4.2 ForestTreeManager rejects unknown tree ID or out-of-range HP"):
		return false
	if not _check(not BuildingManager.is_valid_saved_building_dict({"id": "wall_east_01", "type": "wooden_wall", "state": "COMPLETED", "durability": 0, "max_durability": 150}), "v1.4.2 BuildingManager rejects COMPLETED building with 0 durability"):
		return false
	if not _check(not NightEncounterManager.is_valid_saved_encounter_dict({"night_active": true, "night_elapsed": 5.0, "spawned_wave_count": 1, "enemy_active": true, "enemy_x": 500.0, "enemy_hp": 0, "settlement_breached": false, "first_night_survived": false}), "v1.4.2 NightEncounterManager rejects enemy_active=true with enemy_hp=0"):
		return false
	var bad_type_payload: Dictionary = {
		"schema_version": 2, "world_id": "aetherion", "island_id": "forgotten_shore",
		"day_count": 1, "world_time": 0.0, "world_phase": "daylight",
		"resources": {"gold": 2, "wood": 2, "stone": 1},
		"buildings": [{"id": "watchtower_east_01", "type": "farm_plot", "state": "COMPLETED", "durability": 80, "max_durability": 80}],
		"npcs": [{"id": "npc_01", "recruited": true, "role": "builder", "state": "IDLE", "position_x": 0.0}],
		"night_encounter": NightEncounterManagerScript.new().to_save_dict(),
		"progression_flags": {"first_night_survived": false},
	}
	if not _check(not sm_chk.validate_payload(bad_type_payload), "v1.4.2 SaveManager rejects watchtower_east_01 disguised as farm_plot"):
		return false

	# 6. Session command execution test: Shrine Offering, Kindle Flare, Stoke Fire persistence & Shipwreck Stage 1-3 -> Set Sail
	var session_script: GDScript = load("res://scripts/world/ForgottenShoreSession.gd")
	var sess: ForgottenShoreSession = session_script.new()
	sess.building_mgr.register_forgotten_shore_expansion_plots()
	sess.economy.set_balances_from_dict({"gold": 10, "wood": 20, "stone": 15})
	sess.set_actor_position("local", -780.0)
	if not _check(bool(sess.execute_world_command("local", &"shrine_offering", "shrine_cache_far_west")["ok"]) and sess.shrine_offering_used_today, "v1.4.2 Session command shrine_offering succeeds"):
		return false
	sess.set_actor_position("local", 0.0)
	if not _check(bool(sess.execute_world_command("local", &"boost_hearth", "town_hearth")["ok"]) and sess.hearth_sys.is_boost_active() and is_equal_approx(sess.hearth_sys.get_effective_texture_scale(), 2.6 * 1.3), "v1.4.2 Session boost_hearth activates boost & effective texture scale"):
		return false
	var boost_save_path: String = "user://test_v142_boost_save.json"
	if not _check(sess.save_game_state(boost_save_path), "v1.4.2 Save session with active hearth boost"):
		return false
	sess.hearth_sys.apply_save_boost(0.0)
	if not _check(sess.load_game_state(boost_save_path) and is_equal_approx(sess.hearth_sys.boost_remaining, HearthSystem.BOOST_DURATION_SEC), "v1.4.2 Continue restores hearth_boost_remaining"):
		return false
	# Shipwreck command range check + 3-stage repair + Set Sail
	sess.set_actor_position("local", 0.0)
	if not _check(not bool(sess.execute_world_command("local", &"shipwreck", "shipwreck")["ok"]), "v1.4.2 Shipwreck command rejected out of range"):
		return false
	sess.set_actor_position("local", -1350.0)
	for _st: int in range(3):
		if not _check(bool(sess.execute_world_command("local", &"shipwreck", "shipwreck")["ok"]), "v1.4.2 Shipwreck repair stage command succeeds"):
			return false
	if not _check(sess.shipwreck_stage == 3 and bool(sess.execute_world_command("local", &"shipwreck", "shipwreck")["ok"]) and sess.reign_state == ForgottenShoreSession.ReignState.ISLAND_CLEARED, "v1.4.2 Shipwreck Stage 3 Set Sail sets ISLAND_CLEARED"):
		return false
	sess.free()

	print("PASS: v1.4.1/v1.4.2 Forest Chopping, Actionable Plot Selection, Strict Validation & Session Commands")
	return true
