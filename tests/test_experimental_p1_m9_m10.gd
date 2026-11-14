extends SceneTree

const EconomyLedgerScript = preload("res://scripts/economy/EconomyLedger.gd")
const BuildingManagerScript = preload("res://scripts/kingdom/BuildingManager.gd")
const NetworkSessionManagerScript = preload("res://scripts/networking/NetworkSessionManager.gd")
const ContentExpansionM10Script = preload("res://scripts/kingdom/ContentExpansionM10.gd")


func _init() -> void:
	_test_m9_networking_skeleton()
	_test_m10_content_expansion_skeleton()
	print("PASS: Experimental P1 Skeleton Tests (M9 & M10) completed.")
	quit(0)


func _test_m9_networking_skeleton() -> void:
	var net: NetworkSessionManager = NetworkSessionManagerScript.new()
	assert(net.register_test_peer(2, -100.0))
	assert(not net.register_test_peer(2, 0.0))
	assert(not net.submit_client_command(2, &"grant_infinite_gold", -100.0))
	assert(not net.submit_client_command(2, &"interact", 99999.0))
	assert(not net.submit_client_command(2, &"interact", 500.0))
	assert(net.update_peer_position(2, -120.0))
	assert(net.submit_client_command(2, &"interact", -110.0))
	assert(net.unregister_peer(2))
	net.free()
	print("PASS: M9 Experimental Networking Skeleton")


func _test_m10_content_expansion_skeleton() -> void:
	var ledger: EconomyLedger = EconomyLedgerScript.new({"gold": 12, "wood": 12, "stone": 12})
	var bm: BuildingManager = BuildingManagerScript.new()
	var m10: ContentExpansionM10 = ContentExpansionM10Script.new()

	m10.register_expansion_plots(bm)
	assert(bm.has_plot(ContentExpansionM10.WATCHTOWER_PLOT_ID))
	assert(bm.request_start_construction(BuildingManager.WALL_POSITION_X, ledger))
	bm.advance_construction(4.0)
	assert(m10.upgrade_wall_to_stone(bm, ledger))
	assert(bm.max_durability == ContentExpansionM10.STONE_WALL_MAX_DURABILITY)
	assert(m10.recruit_archer(ledger))
	assert(m10.recruit_farmer(ledger))
	var produced: int = m10.tick_daylight_production(10.0, true, ledger)
	assert(produced == 2)
	assert(m10.compute_archer_volley_damage(bm) == 20)
	print("PASS: M10 Experimental Content Expansion Skeleton")
