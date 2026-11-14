extends SceneTree

const EconomyLedgerScript = preload("res://scripts/economy/EconomyLedger.gd")
const BuildingManagerScript = preload("res://scripts/kingdom/BuildingManager.gd")
const NetworkSessionManagerScript = preload("res://scripts/networking/NetworkSessionManager.gd")
const ContentExpansionM10Script = preload("res://scripts/kingdom/ContentExpansionM10.gd")

var _checks: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		printerr("TEST FAILURE [test_experimental_p1_m9_m10]: " + msg)
		quit(1)
		return false
	return true


func _init() -> void:
	if not _test_m9_networking_skeleton():
		return
	if not _test_m10_content_expansion_skeleton():
		return
	print("PASS: All %d Experimental P1 Skeleton Checks (M9 & M10) completed." % _checks)
	quit(0)


func _test_m9_networking_skeleton() -> bool:
	var net: NetworkSessionManager = NetworkSessionManagerScript.new()
	if not _check(net.register_test_peer(2, -100.0), "M9 register peer 2"):
		return false
	if not _check(not net.register_test_peer(2, 0.0), "M9 reject duplicate peer 2"):
		return false
	if not _check(not net.submit_client_command(2, &"grant_infinite_gold", -100.0), "M9 reject unwhitelisted command"):
		return false
	if not _check(not net.submit_client_command(2, &"interact", 99999.0), "M9 reject out-of-bounds coord"):
		return false

	# Anti-teleport check: without advancing server_clock_sec, moving >24 px in 0.0s is rejected!
	if not _check(not net.submit_client_command(2, &"interact", -40.0), "M9 reject zero-delta speed-hack jump"):
		return false
	if not _check(is_equal_approx(float(net.peer_positions[2]), -100.0), "M9 rejected command does not mutate peer_positions"):
		return false

	# Advance server clock by 0.5s (allows up to 24 + 130 = 154 px movement)
	net.advance_server_clock(0.5)
	if not _check(net.update_peer_position(2, -120.0), "M9 valid time-bounded position update"):
		return false
	net.advance_server_clock(0.2)
	if not _check(net.submit_client_command(2, &"interact", -110.0), "M9 valid peer command"):
		return false
	if not _check(net.unregister_peer(2), "M9 unregister peer 2"):
		return false
	net.free()
	print("PASS: M9 Experimental Networking Skeleton")
	return true


func _test_m10_content_expansion_skeleton() -> bool:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 12, "wood": 12, "stone": 12})
	var bm: BuildingManager = BuildingManagerScript.new()
	var m10: ContentExpansionM10 = ContentExpansionM10Script.new()

	m10.register_expansion_plots(bm)
	if not _check(bm.has_plot(ContentExpansionM10.WATCHTOWER_PLOT_ID), "M10 watchtower plot registered"):
		return false
	if not _check(bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger), "M10 build base wall"):
		return false
	bm.advance_construction(4.0)
	if not _check(m10.upgrade_wall_to_stone(bm, ledger) and bm.max_durability == ContentExpansionM10.STONE_WALL_MAX_DURABILITY, "M10 Stone Wall Tier 2 upgrade"):
		return false
	if not _check(m10.recruit_archer(ledger) and m10.recruit_farmer(ledger), "M10 recruit Archer & Farmer"):
		return false
	var produced: int = m10.tick_daylight_production(10.0, true, ledger)
	if not _check(produced == 2 and m10.compute_archer_volley_damage(bm) == 20, "M10 farm production & archer volley"):
		return false
	print("PASS: M10 Experimental Content Expansion Skeleton")
	return true
