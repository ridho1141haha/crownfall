extends SceneTree

const TimeManagerScript = preload("res://scripts/world/TimeManager.gd")
const EconomyLedgerScript = preload("res://scripts/economy/EconomyLedger.gd")
const BuildingManagerScript = preload("res://scripts/kingdom/BuildingManager.gd")
const NPCBuilderAgentScript = preload("res://scripts/npc/NPCBuilderAgent.gd")
const NightEncounterManagerScript = preload("res://scripts/survival/NightEncounterManager.gd")
const SaveManagerScript = preload("res://scripts/save/SaveManager.gd")
const NetworkSessionManagerScript = preload("res://scripts/networking/NetworkSessionManager.gd")
const ContentExpansionM10Script = preload("res://scripts/kingdom/ContentExpansionM10.gd")


func _init() -> void:
	_test_m2_world_clock()
	_test_m3_economy_invariants()
	_test_m4_building_validation()
	_test_m5_npc_builder_and_safety()
	_test_m6_first_night_encounter()
	_test_m7_save_load_and_backup_recovery()
	_test_m9_host_authoritative_multiplayer_seams()
	_test_m10_content_expansion()
	print("ALL M2-M8 VERTICAL SLICE TESTS PASSED!")
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
	print("PASS: M2 World Clock")


func _test_m3_economy_invariants() -> void:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 2, "wood": 2, "stone": 1})
	assert(not ledger.try_add(&"iron", 5))
	assert(not ledger.try_add(&"gold", 0))
	assert(not ledger.try_add(&"gold", -3))
	assert(ledger.get_amount(&"gold") == 2)
	# Reject fractional floats, NaN, INF, and overflow
	assert(not ledger.try_add(&"gold", 1.5))
	assert(not ledger.try_spend({"gold": 1.25}))
	assert(not ledger.try_add(&"gold", 2000000))

	# Multi-resource atomic spend: fails if stone is short, leaving gold & wood untouched
	assert(not ledger.try_spend({"gold": 1, "wood": 1, "stone": 5}))
	assert(ledger.get_amount(&"gold") == 2 and ledger.get_amount(&"wood") == 2 and ledger.get_amount(&"stone") == 1)

	assert(ledger.try_add(&"gold", 4))
	assert(ledger.try_add(&"wood", 5))
	assert(ledger.try_add(&"stone", 3))
	assert(ledger.try_spend({"gold": 2, "wood": 4, "stone": 2}))
	assert(ledger.get_amount(&"gold") == 4 and ledger.get_amount(&"wood") == 3 and ledger.get_amount(&"stone") == 2)
	print("PASS: M3 Economy Ledger")


func _test_m4_building_validation() -> void:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 2, "wood": 4, "stone": 2})
	var bm: BuildingManager = BuildingManagerScript.new()

	# Out of placement range must reject without deducting resources
	assert(not bm.request_start_construction(0.0, ledger))
	assert(ledger.get_amount(&"gold") == 2)
	# Reject fractional floats, NaN, INF, and overflow
	assert(not ledger.try_add(&"gold", 1.5))
	assert(not ledger.try_spend({"gold": 1.25}))
	assert(not ledger.try_add(&"gold", 2000000))

	# Valid placement deducts once and enters UNDER_CONSTRUCTION
	assert(bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger))
	assert(ledger.get_amount(&"gold") == 0 and ledger.get_amount(&"wood") == 0 and ledger.get_amount(&"stone") == 0)
	assert(bm.state == BuildingManager.WallState.UNDER_CONSTRUCTION)

	# Duplicate construction request is rejected
	assert(not bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger))

	bm.advance_construction(2.0)
	assert(bm.state == BuildingManager.WallState.UNDER_CONSTRUCTION and is_equal_approx(bm.construction_progress, 0.5))
	bm.advance_construction(2.0)
	assert(bm.state == BuildingManager.WallState.COMPLETED and bm.durability == BuildingManager.REINFORCED_MAX_DURABILITY)
	print("PASS: M4 Building Manager")


func _test_m5_npc_builder_and_safety() -> void:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 4, "wood": 4, "stone": 2})
	var bm: BuildingManager = BuildingManagerScript.new()
	var npc: NPCBuilderAgent = NPCBuilderAgentScript.new()

	assert(not npc.request_recruit(300.0, ledger))
	assert(npc.request_recruit(NPCBuilderAgent.CAMP_POSITION_X, ledger))
	assert(bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger))

	# Builder walks to wall and works
	npc.tick(5.0, bm)
	assert(bm.construction_progress > 0.0)

	# Dusk safety override interrupts optional work and walks back toward Town Center
	npc.set_dusk_or_night_safety(true)
	var prev_x: float = npc.position_x
	npc.tick(1.0, bm)
	assert(npc.state == NPCBuilderAgent.State.RETURNING_TO_SAFETY or npc.state == NPCBuilderAgent.State.IDLE)
	assert(npc.position_x < prev_x)

	# Blocked path emits failure signal without silent teleportation
	npc.navigation_blocked = true
	var failed_reasons: Array[String] = []
	npc.safety_path_failed.connect(func(_id: String, reason: String) -> void: failed_reasons.append(reason))
	var stuck_x: float = npc.position_x
	npc.tick(1.0, bm)
	assert(is_equal_approx(npc.position_x, stuck_x) and failed_reasons.size() == 1)
	print("PASS: M5 NPC Builder & Safety")


func _test_m6_first_night_encounter() -> void:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 2, "wood": 4, "stone": 2})
	var bm: BuildingManager = BuildingManagerScript.new()
	var night: NightEncounterManager = NightEncounterManagerScript.new()

	bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger)
	bm.advance_construction(4.0)
	assert(bm.is_standing())

	# No enemy movement before night starts
	night.tick(5.0, false, bm)
	assert(not night.enemy_active)

	night.on_night_started()
	assert(night.enemy_active)
	for _i: int in range(20):
		night.tick(1.0, true, bm)
	assert(bm.durability < bm.max_durability and bm.is_standing())

	night.on_sunrise_reached(bm)
	assert(night.first_night_survived and not night.settlement_breached)
	print("PASS: M6 First-Night Survival")


func _test_m7_save_load_and_backup_recovery() -> void:
	var sm: SaveManager = SaveManagerScript.new()
	var test_path: String = "user://test_crownfall_save.json"
	var payload: Dictionary = {
		"schema_version": 1,
		"world_id": "aetherion",
		"island_id": "forgotten_shore",
		"day_count": 2,
		"world_time": 12.5,
		"world_phase": "daylight",
		"resources": {"gold": 5, "wood": 3, "stone": 1},
		"buildings": [{"id": "wall_east_01", "state": "COMPLETED", "durability": 120, "max_durability": 150, "progress": 1.0}],
		"npcs": [{"id": "npc_01", "recruited": true, "role": "builder", "state": "IDLE", "position_x": 0.0}],
		"progression_flags": {"first_night_survived": true},
	}

	# Reject unsafe path traversal and corrupt nested building state
	assert(not sm.save_state(payload, "res://hack.json"))
	assert(not sm.save_state(payload, "user://../hack.json"))
	var bad_building_payload: Dictionary = payload.duplicate(true)
	bad_building_payload["buildings"] = [{"id": "wall_east_01", "state": "HACKED_STATE", "durability": 9999}]
	assert(not sm.validate_payload(bad_building_payload))
	assert(sm.save_state(payload, test_path))
	var loaded: Dictionary = sm.load_state(test_path)
	assert(bool(loaded["ok"]) and not bool(loaded["recovered_from_backup"]))
	assert(int(loaded["data"]["resources"]["gold"]) == 5)

	# Second valid save creates .bak of first save; simulated failed write preserves existing valid save
	payload["day_count"] = 3
	assert(sm.save_state(payload, test_path))
	assert(not sm.save_state(payload, test_path, true))
	var after_fail: Dictionary = sm.load_state(test_path)
	assert(bool(after_fail["ok"]) and int(after_fail["data"]["day_count"]) == 3)

	# Corrupt primary save -> automatically recovers from .bak
	var corrupt_file: FileAccess = FileAccess.open(test_path, FileAccess.WRITE)
	corrupt_file.store_string("{corrupt_json}")
	corrupt_file.close()
	var recovered: Dictionary = sm.load_state(test_path)
	assert(bool(recovered["ok"]) and bool(recovered["recovered_from_backup"]))
	print("PASS: M7 Save/Load & Backup Recovery")


func _test_m9_host_authoritative_multiplayer_seams() -> void:
	var net: NetworkSessionManager = NetworkSessionManagerScript.new()
	assert(net.register_test_peer(2, -100.0))
	assert(not net.register_test_peer(2, 0.0))

	# Reject unpermitted command injection & out-of-bounds / teleport coordinates
	assert(not net.submit_client_command(2, &"grant_infinite_gold", -100.0))
	assert(not net.submit_client_command(2, &"interact", 99999.0))
	assert(not net.submit_client_command(2, &"interact", 500.0))

	# Valid peer movement + command passes host authority check
	assert(net.update_peer_position(2, -120.0))
	assert(net.submit_client_command(2, &"interact", -110.0))
	assert(net.unregister_peer(2))
	net.free()
	print("PASS: M9 Host-Authoritative Multiplayer Seams")


func _test_m10_content_expansion() -> void:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 12, "wood": 12, "stone": 12})
	var bm: BuildingManager = BuildingManagerScript.new()
	var m10: ContentExpansionM10 = ContentExpansionM10Script.new()

	m10.register_expansion_plots(bm)
	assert(bm.has_plot(ContentExpansionM10.WATCHTOWER_PLOT_ID))

	# Build & complete primary wall, then upgrade to Stone Wall Tier 2 (260 HP)
	assert(bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger))
	bm.advance_construction(4.0)
	assert(m10.upgrade_wall_to_stone(bm, ledger))
	assert(bm.max_durability == ContentExpansionM10.STONE_WALL_MAX_DURABILITY)

	# Recruit Archer & Farmer and verify daylight farm production + watchtower volley
	assert(m10.recruit_archer(ledger))
	assert(m10.recruit_farmer(ledger))
	var gold_before: int = ledger.get_amount(&"gold")
	var produced: int = m10.tick_daylight_production(10.0, true, ledger)
	assert(produced == 2 and ledger.get_amount(&"gold") == gold_before + 2)
	assert(m10.compute_archer_volley_damage(bm) == 20)

	var brute_stats: Dictionary = ContentExpansionM10.get_enemy_archetype_stats("brute")
	assert(int(brute_stats["hp"]) == 160)
	print("PASS: M10 Content Expansion (Stone Wall, Watchtower, Archer, Farmer, Brute)")
