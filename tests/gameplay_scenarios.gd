extends SceneTree

## Crownfall automated gameplay harness (10 executable scenarios).
##
## Run modes
##   Headless (CI-safe, logic only; screenshots are skipped):
##     godot --headless --script res://tests/gameplay_scenarios.gd
##   Windowed (real renderer; captures tests/artifacts/gp_*.png):
##     godot --script res://tests/gameplay_scenarios.gd
##
## Authenticity rules used below:
##   * Player-facing actions use REAL in-engine input:
##       - Input.action_press/release for held movement,
##       - Input.parse_input_event(InputEventKey) for discrete keys (E/Q/B/R).
##   * Direct session/manager calls are used ONLY as clearly labelled FIXTURE
##     setup (granting resources, positioning the player, recording a
##     prerequisite fact) or as labelled negative-path domain checks where the
##     player-facing resolver no longer offers the action (duplicate recruit /
##     duplicate activation).
##   * Every scenario loads a fresh ForgottenShore scene; no scenario shares
##     live state with another.
##   * Save tests use user://gp_test_*.json only. user://save_slot_0.json is
##     never read or written.
##
## Each scenario has isolated setup/cleanup, explicit preconditions, the real
## gameplay action, state assertions, negative cases, and cleanup.

const SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const ART: String = "res://tests/artifacts"
const SAVE_GAME: String = "user://gp_test_save_load.json"
const SAVE_LEGACY: String = "user://gp_test_legacy.json"
const SAVE_INVALID: String = "user://gp_test_invalid.json"

var _headless: bool = false
var _session: ForgottenShoreSession = null
var _checks: int = 0
var _current_scenario: String = ""
var _current_failures: int = 0
var _results: Array[Dictionary] = []
var _research_done_count: int = 0


func _initialize() -> void:
	_headless = DisplayServer.get_name() == "headless"
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ART))
	_run_all()


# ---------------------------------------------------------------- runner ----

func _run_all() -> void:
	await process_frame
	var scenarios: Array[Dictionary] = [
		{"name": "1_new_game", "fn": Callable(self, "_scenario_new_game")},
		{"name": "2_player_movement", "fn": Callable(self, "_scenario_player_movement")},
		{"name": "3_resource_collection", "fn": Callable(self, "_scenario_resource_collection")},
		{"name": "4_building", "fn": Callable(self, "_scenario_building")},
		{"name": "5_wall_upgrade", "fn": Callable(self, "_scenario_wall_upgrade")},
		{"name": "6_scientist", "fn": Callable(self, "_scenario_scientist")},
		{"name": "7_research", "fn": Callable(self, "_scenario_research")},
		{"name": "8_shrine_activation", "fn": Callable(self, "_scenario_shrine_activation")},
		{"name": "9_shrine_buff", "fn": Callable(self, "_scenario_shrine_buff")},
		{"name": "10_save_load", "fn": Callable(self, "_scenario_save_load")},
	]
	for entry: Dictionary in scenarios:
		_current_scenario = String(entry["name"])
		_current_failures = 0
		var before: int = _checks
		_release_all_actions()
		var fn: Callable = entry["fn"]
		var ok: bool = false
		var returned: Variant = await fn.call()
		ok = bool(returned) and _current_failures == 0
		var ran: int = _checks - before
		_results.append({"name": _current_scenario, "ok": ok, "checks": ran, "failures": _current_failures})
		if ok:
			print("SCENARIO PASS: %s (%d checks)" % [_current_scenario, ran])
		else:
			print("SCENARIO FAIL: %s (%d checks, %d failures)" % [_current_scenario, ran, _current_failures])
		await _cleanup_scenario()
	var failed: int = 0
	for r: Dictionary in _results:
		if not bool(r["ok"]):
			failed += 1
	print("Executed %d gameplay scenarios, %d passed, %d failed." % [_results.size(), _results.size() - failed, failed])
	if failed == 0 and _results.size() == 10:
		print("PASS: All 10 gameplay scenarios passed")
		quit(0)
	else:
		printerr("TEST FAILURE: gameplay scenarios had %d failing scenario(s)" % failed)
		quit(1)


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if cond:
		print("  ok   [%s] %s" % [_current_scenario, msg])
	else:
		_current_failures += 1
		printerr("  FAIL [%s] %s" % [_current_scenario, msg])
	return cond


func _cleanup_scenario() -> void:
	_release_all_actions()
	Engine.set_meta("crownfall_load_on_start", false)
	_remove_save(SAVE_GAME)
	_remove_save(SAVE_LEGACY)
	_remove_save(SAVE_INVALID)
	await process_frame


func _release_all_actions() -> void:
	for action: StringName in [&"move_left", &"move_right"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


# --------------------------------------------------------------- helpers ----

func _fresh_session() -> ForgottenShoreSession:
	Engine.set_meta("crownfall_load_on_start", false)
	change_scene_to_file(SCENE)
	for _i: int in range(600):
		await process_frame
		if current_scene != null and String(current_scene.name) == "ForgottenShore":
			var s: ForgottenShoreSession = current_scene as ForgottenShoreSession
			if s != null and s.player != null:
				s.time_manager.auto_advance = false
				s.set_process(false)
				_session = s
				await process_frame
				return s
	return null


func _teleport(x: float) -> void:
	# FIXTURE: deterministic player placement for a precise interaction target.
	_session.player.global_position.x = clampf(x, _session.player.min_bound_x, _session.player.max_bound_x)
	_session.set_actor_position("player_1", _session.player.global_position.x)
	await process_frame


func _grant(resources: Dictionary) -> void:
	# FIXTURE: grant starting resources so a scenario can focus on its action.
	for key: Variant in resources.keys():
		_session.economy.try_add(StringName(String(key)), int(resources[key]))


func _tap(keycode: Key) -> void:
	# REAL INPUT: discrete key through the engine input pipeline.
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	await process_frame
	var release: InputEventKey = InputEventKey.new()
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _hold_action(action: StringName, seconds: float) -> void:
	# REAL INPUT: held action state, exactly what a keyboard hold produces.
	Input.action_press(action)
	await create_timer(seconds).timeout
	Input.action_release(action)
	await process_frame


func _sim(seconds: float, step: float = 0.25) -> void:
	# ADVANCE authoritative world simulation deterministically (no wall clock).
	var remaining: float = seconds
	while remaining > 0.0:
		var dt: float = minf(step, remaining)
		_session._process(dt)
		remaining -= dt


func _sim_until(predicate: Callable, max_seconds: float, step: float = 0.1) -> bool:
	var elapsed: float = 0.0
	while elapsed < max_seconds:
		if bool(predicate.call()):
			return true
		_session._process(step)
		elapsed += step
	return bool(predicate.call())


func _bal() -> Dictionary:
	return _session.economy.get_all_balances()


func _capture(file_name: String) -> void:
	await process_frame
	await process_frame
	if _headless:
		print("  skip screenshot (headless): %s" % file_name)
		return
	var tex: ViewportTexture = get_root().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if not _check(img != null and img.get_width() > 0, "screenshot image available: " + file_name):
		return
	if img == null:
		return
	var path: String = ART + "/" + file_name
	var err: Error = img.save_png(path)
	_check(err == OK, "screenshot saved: " + path)


func _on_research_completed(_tech_id: String) -> void:
	_research_done_count += 1


func _remove_save(path: String) -> void:
	for suffix: String in ["", ".tmp", ".bak", ".bak.tmp", ".old", ".restore.tmp"]:
		var p: String = path + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _write_json(path: String, data: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		f.flush()
		f.close()


func _write_raw(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.flush()
		f.close()


# ------------------------------------------------------------- scenarios ----

func _scenario_new_game() -> bool:
	_session = await _fresh_session()
	if _session == null:
		_check(false, "fresh session created")
		return false
	var s: ForgottenShoreSession = _session
	_check(s.time_manager.current_day == 1, "starts on day 1")
	_check(s.time_manager.current_phase == TimeManager.Phase.DAYLIGHT, "starts in DAYLIGHT")
	_check(s.era_mgr.get_era_id() == "wood_age", "initial era is wood_age (got %s)" % s.era_mgr.get_era_id())
	var b: Dictionary = _bal()
	_check(int(b["gold"]) == 2 and int(b["wood"]) == 2 and int(b["stone"]) == 1, "initial ledger is 2G/2W/1S (got %s)" % str(b))
	_check(is_zero_approx(s.player.global_position.x), "player starts at x=0 (got %.2f)" % s.player.global_position.x)
	_check(s.progression.fact_count() == 0, "no progression facts initially")
	_check(s.research_mgr.get_completed_tech_ids().is_empty() and not s.research_mgr.has_active_research(), "research starts empty")
	_check(not s.specialists.is_discovered("scientist", s.progression), "scientist is undiscovered")
	_check(not s.specialists.is_recruited("scientist", s.progression), "scientist is not recruited")
	_check(not s.structures.is_activated("shrine_of_growth", s.progression), "shrine is dormant")
	_check(not s.builder_npc.recruited, "no recruited NPC")
	_check(s.building_mgr.get_state_name(BuildingManager.WALL_ID) == "PLACEHOLDER", "east wall plot is a PLACEHOLDER")
	await _capture("gp_new_game.png")
	return _current_failures == 0


func _scenario_player_movement() -> bool:
	_session = await _fresh_session()
	if _session == null:
		_check(false, "fresh session created")
		return false
	var s: ForgottenShoreSession = _session
	var x0: float = s.player.global_position.x
	await _capture("gp_movement_before.png")
	await _hold_action(&"move_right", 0.5)
	var x1: float = s.player.global_position.x
	_check(x1 > x0 + 40.0, "held RIGHT moved player right (%.1f -> %.1f)" % [x0, x1])
	await _hold_action(&"move_left", 0.5)
	var x2: float = s.player.global_position.x
	_check(x2 < x1 - 40.0, "held LEFT moved player left (%.1f -> %.1f)" % [x1, x2])
	_check(x2 >= s.player.min_bound_x - 0.01 and x2 <= s.player.max_bound_x + 0.01, "player stayed inside playable bounds")
	await _capture("gp_movement.png")
	return _current_failures == 0


func _scenario_resource_collection() -> bool:
	_session = await _fresh_session()
	if _session == null:
		_check(false, "fresh session created")
		return false
	var s: ForgottenShoreSession = _session
	await _teleport(-110.0)
	var w0: int = s.economy.get_amount(&"wood")
	await _tap(KEY_E)
	var w1: int = s.economy.get_amount(&"wood")
	_check(w1 == w0 + 5, "timber node granted +5 wood (%d -> %d)" % [w0, w1])
	_check(s.resource_mgr.is_collected("timber_pile_west"), "timber node marked collected")
	await _tap(KEY_E)
	_check(s.economy.get_amount(&"wood") == w1, "second interaction did not grant wood again")
	await _teleport(190.0)
	var s0: int = s.economy.get_amount(&"stone")
	await _tap(KEY_E)
	_check(s.economy.get_amount(&"stone") == s0 + 3, "stone outcrop granted +3 stone")
	_check(s.resource_mgr.is_collected("stone_outcrop_east"), "stone outcrop marked collected")
	await _teleport(-480.0)
	var g0: int = s.economy.get_amount(&"gold")
	await _tap(KEY_E)
	_check(s.economy.get_amount(&"gold") == g0 + 4, "gold chest granted +4 gold")
	_check(s.resource_mgr.is_collected("cache_gold_west"), "gold chest marked collected")
	await _capture("gp_resource_collection.png")
	return _current_failures == 0


func _scenario_building() -> bool:
	_session = await _fresh_session()
	if _session == null:
		_check(false, "fresh session created")
		return false
	var s: ForgottenShoreSession = _session
	_grant({"gold": 20, "wood": 20, "stone": 20})  # FIXTURE
	await _teleport(NPCBuilderAgent.CAMP_POSITION_X)
	var g_before: int = s.economy.get_amount(&"gold")
	await _tap(KEY_R)
	_check(s.builder_npc.recruited and s.builder_npc.role == "builder", "recruited Builder with R at the camp")
	_check(g_before - s.economy.get_amount(&"gold") == 2, "builder recruitment charged exactly 2 gold")
	await _teleport(BuildingManager.WALL_POSITION_X)
	var before: Dictionary = _bal()
	await _tap(KEY_B)
	var after: Dictionary = _bal()
	_check(int(before["gold"]) - int(after["gold"]) == 2 and int(before["wood"]) - int(after["wood"]) == 4 and int(before["stone"]) - int(after["stone"]) == 2, "wall build charged exactly once (2G/4W/2S)")
	_check(s.building_mgr.get_state_name(BuildingManager.WALL_ID) == "UNDER_CONSTRUCTION", "wall is UNDER_CONSTRUCTION after funding")
	var dup: Dictionary = _bal()
	await _tap(KEY_B)
	_check(_bal() == dup, "duplicate funding press charged nothing")
	var built: bool = _sim_until(func() -> bool: return s.building_mgr.is_fully_operational(BuildingManager.WALL_ID), 20.0)
	_check(built, "builder completed the wall construction")
	_check(s.building_mgr.get_state_name(BuildingManager.WALL_ID) == "COMPLETED", "wall state is COMPLETED")
	_check(s.building_mgr.durability == s.building_mgr.max_durability, "completed wall at full durability (%d/%d)" % [s.building_mgr.durability, s.building_mgr.max_durability])
	await _capture("gp_building.png")
	return _current_failures == 0


func _scenario_wall_upgrade() -> bool:
	_session = await _fresh_session()
	if _session == null:
		_check(false, "fresh session created")
		return false
	var s: ForgottenShoreSession = _session
	_grant({"gold": 4, "wood": 4, "stone": 2})  # FIXTURE
	await _teleport(NPCBuilderAgent.CAMP_POSITION_X)
	await _tap(KEY_R)
	_check(s.builder_npc.recruited, "builder recruited (fixture prerequisite)")
	await _teleport(BuildingManager.WALL_POSITION_X)
	await _tap(KEY_B)
	var built: bool = _sim_until(func() -> bool: return s.building_mgr.is_fully_operational(BuildingManager.WALL_ID), 20.0)
	_check(built, "wooden wall completed as upgrade prerequisite")
	_check(not s.progression.has_fact(ProgressionState.FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2), "Stone Age fact absent before upgrade")
	_check(s.era_mgr.get_era_id() == "wood_age", "era is wood_age before upgrade")
	var bal0: Dictionary = _bal()
	await _tap(KEY_Q)
	var bal1: Dictionary = _bal()
	_check(bal1 == bal0, "failed upgrade charged no resources (%s -> %s)" % [str(bal0), str(bal1)])
	_check(not s.progression.has_fact(ProgressionState.FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2), "failed upgrade granted no Stone Age fact")
	_check(s.era_mgr.get_era_id() == "wood_age", "failed upgrade kept wood_age")
	_check(int((s.building_mgr.get_plot(BuildingManager.WALL_ID) as Dictionary)["level"]) == 1, "failed upgrade kept wall level 1")
	_grant({"gold": 3, "wood": 2, "stone": 5})  # FIXTURE
	var pre: Dictionary = _bal()
	await _tap(KEY_Q)
	var post: Dictionary = _bal()
	_check(int(pre["gold"]) - int(post["gold"]) == 3 and int(pre["wood"]) - int(post["wood"]) == 2 and int(pre["stone"]) - int(post["stone"]) == 5, "successful upgrade charged exact 3G/2W/5S")
	var plot: Dictionary = s.building_mgr.get_plot(BuildingManager.WALL_ID)
	_check(int(plot["level"]) == 2, "wall level advanced to 2")
	_check(String(plot["type"]) == "stone_wall", "wall type is stone_wall")
	_check(s.building_mgr.max_durability == 260 and s.building_mgr.durability == 260, "stone wall has 260/260 HP")
	_check(s.progression.has_fact(ProgressionState.FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2), "Stone Age fact recorded after successful upgrade")
	_check(s.era_mgr.get_era_id() == "stone_age", "era advanced to stone_age")
	var bal2: Dictionary = _bal()
	await _tap(KEY_Q)
	_check(_bal() == bal2, "repeat upgrade press charged nothing")
	_check(int((s.building_mgr.get_plot(BuildingManager.WALL_ID) as Dictionary)["level"]) == 2, "repeat upgrade kept wall level 2")
	await _capture("gp_wall_upgrade.png")
	return _current_failures == 0


func _scenario_scientist() -> bool:
	_session = await _fresh_session()
	if _session == null:
		_check(false, "fresh session created")
		return false
	var s: ForgottenShoreSession = _session
	_grant({"gold": 7, "wood": 7, "stone": 1})  # FIXTURE
	await _teleport(NPCBuilderAgent.CAMP_POSITION_X)
	await _tap(KEY_R)
	_check(s.builder_npc.recruited, "builder recruited (needed to construct the hut)")
	await _teleport(-1010.0)
	await _tap(KEY_E)
	_check(s.progression.has_fact(ProgressionState.FACT_SCIENTIST_DISCOVERED), "scientist discovered via E interaction")
	_check(s.specialists.get_lifecycle_state("scientist", s.progression, s.building_mgr) == SpecialistDomain.STATE_DISCOVERED, "lifecycle is discovered before housing")
	await _teleport(-980.0)
	var pre_hut: Dictionary = _bal()
	await _tap(KEY_B)
	var post_hut: Dictionary = _bal()
	_check(int(pre_hut["gold"]) - int(post_hut["gold"]) == 2 and int(pre_hut["wood"]) - int(post_hut["wood"]) == 5 and int(pre_hut["stone"]) - int(post_hut["stone"]) == 1, "hut build charged exact 2G/5W/1S")
	var built: bool = _sim_until(func() -> bool: return s.building_mgr.is_fully_operational(SpecialistDomain.SCIENTIST_HUT_PLOT_ID), 30.0)
	_check(built, "scientist hut completed")
	_check(s.specialists.get_lifecycle_state("scientist", s.progression, s.building_mgr) == SpecialistDomain.STATE_RECRUITABLE, "lifecycle is recruitable after housing")
	await _teleport(-1010.0)
	var pre_rec: Dictionary = _bal()
	await _tap(KEY_E)
	var post_rec: Dictionary = _bal()
	_check(s.progression.has_fact(ProgressionState.FACT_SCIENTIST_RECRUITED), "scientist recruited via E interaction")
	_check(int(pre_rec["gold"]) - int(post_rec["gold"]) == 3 and int(pre_rec["wood"]) - int(post_rec["wood"]) == 2, "recruitment charged exact 3G/2W")
	_check(s.specialists.get_lifecycle_state("scientist", s.progression, s.building_mgr) == SpecialistDomain.STATE_RECRUITED, "lifecycle is recruited")
	var dup_bal: Dictionary = _bal()
	var dup_ok: bool = s.specialists.try_recruit(-1010.0, "scientist", s.progression, s.building_mgr, s.economy)
	_check(not dup_ok, "duplicate recruitment rejected (direct domain negative check)")
	_check(_bal() == dup_bal, "rejected duplicate recruitment charged nothing")
	await _capture("gp_scientist.png")
	return _current_failures == 0


func _scenario_research() -> bool:
	_session = await _fresh_session()
	if _session == null:
		_check(false, "fresh session created")
		return false
	var s: ForgottenShoreSession = _session
	s.progression.record_fact(ProgressionState.FACT_SCIENTIST_DISCOVERED)  # FIXTURE
	s.progression.record_fact(ProgressionState.FACT_SCIENTIST_RECRUITED)  # FIXTURE
	_grant({"gold": 10, "wood": 10, "stone": 10})  # FIXTURE
	await _teleport(-1010.0)
	var bal0: Dictionary = _bal()
	_check(not s.research_mgr.try_start("improved_flares", s.progression, s.economy), "improved_flares rejected without Stone Age fact/prerequisite (negative)")
	_check(_bal() == bal0, "rejected invalid research charged nothing")
	var pre: Dictionary = _bal()
	await _tap(KEY_E)
	var post: Dictionary = _bal()
	_check(s.research_mgr.get_active_tech_id() == "inscription_studies", "inscription_studies started via E (got '%s')" % s.research_mgr.get_active_tech_id())
	_check(int(pre["gold"]) - int(post["gold"]) == 3 and int(pre["wood"]) - int(post["wood"]) == 2, "research charged exact 3G/2W")
	_check(is_zero_approx(s.research_mgr.get_active_elapsed()), "research elapsed starts at 0")
	var active_bal: Dictionary = _bal()
	_check(not s.research_mgr.try_start("inscription_studies", s.progression, s.economy), "second start rejected while a project is active (negative)")
	_check(_bal() == active_bal, "rejected concurrent research charged nothing")
	_research_done_count = 0
	if not s.research_mgr.research_completed.is_connected(_on_research_completed):
		s.research_mgr.research_completed.connect(_on_research_completed)
	var completed: bool = _sim_until(func() -> bool: return s.research_mgr.is_completed("inscription_studies"), 100.0, 0.25)
	_check(completed, "inscription_studies completed after authoritative sim time")
	_check(not s.research_mgr.has_active_research(), "active research cleared on completion")
	_check(_research_done_count == 1, "completion signal fired exactly once (got %d)" % _research_done_count)
	_check(s.research_mgr.get_effect_total(ResearchManager.EFFECT_SHRINE_OFFERING_GOLD_BONUS) == 3, "completion effect applied (shrine offering +3)")
	_sim(10.0)
	_check(_research_done_count == 1, "further sim did not re-complete research (got %d)" % _research_done_count)
	s.progression.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2)  # FIXTURE prerequisite
	s.economy.set_balances_from_dict({"gold": 0, "wood": 0, "stone": 0})  # FIXTURE insufficient
	var broke: Dictionary = _bal()
	_check(not s.research_mgr.try_start("improved_flares", s.progression, s.economy), "improved_flares rejected with insufficient resources (negative)")
	_check(_bal() == broke and not s.research_mgr.has_active_research(), "rejected insufficient research charged nothing and started nothing")
	await _capture("gp_research.png")
	return _current_failures == 0


func _scenario_shrine_activation() -> bool:
	_session = await _fresh_session()
	if _session == null:
		_check(false, "fresh session created")
		return false
	var s: ForgottenShoreSession = _session
	s.progression.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2)  # FIXTURE
	_grant({"gold": 4, "wood": 2, "stone": 3})  # FIXTURE
	var spr: Sprite2D = s.get_node_or_null("WorldObjects/StructureLandmarks/StSprite_shrine_of_growth") as Sprite2D
	_check(spr != null, "shrine landmark sprite exists")
	if spr != null:
		_check(spr.frame == 0, "shrine starts dormant (frame 0)")
	await _teleport(820.0)
	var pre: Dictionary = _bal()
	await _tap(KEY_E)
	var post: Dictionary = _bal()
	_check(s.progression.has_fact(ProgressionState.FACT_SHRINE_OF_GROWTH_ACTIVATED), "shrine activated via E interaction")
	_check(int(pre["gold"]) - int(post["gold"]) == 4 and int(pre["wood"]) - int(post["wood"]) == 2 and int(pre["stone"]) - int(post["stone"]) == 3, "activation charged exact 4G/2W/3S")
	_check(s.structures.get_lifecycle_state("shrine_of_growth", s.progression) == StructureDomain.STATE_ACTIVATED, "shrine lifecycle is activated")
	if spr != null:
		_check(spr.frame == 1, "shrine presentation awakened (frame 1)")
	var dup_bal: Dictionary = _bal()
	_check(not s.structures.try_activate(820.0, "shrine_of_growth", s.progression, s.economy), "duplicate activation rejected (direct domain negative check)")
	_check(_bal() == dup_bal, "rejected duplicate activation charged nothing")
	await _capture("gp_shrine_activation.png")
	return _current_failures == 0


func _scenario_shrine_buff() -> bool:
	# Path A: resource-node collection.
	_session = await _fresh_session()
	if _session == null:
		_check(false, "fresh session created")
		return false
	var s: ForgottenShoreSession = _session
	s.progression.record_fact(ProgressionState.FACT_SHRINE_OF_GROWTH_ACTIVATED)  # FIXTURE
	_check(s.structures.get_effect_total(BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, s.progression) == 1, "shrine blessing total is +1")
	await _teleport(-110.0)
	var w0: int = s.economy.get_amount(&"wood")
	await _tap(KEY_E)
	var w1: int = s.economy.get_amount(&"wood")
	_check(w1 - w0 == 6, "node collection granted 5 base + 1 blessing = 6 (got %d)" % (w1 - w0))
	await _capture("gp_shrine_buff.png")
	# Path B: tree felling.
	_session = await _fresh_session()
	s = _session
	s.progression.record_fact(ProgressionState.FACT_SHRINE_OF_GROWTH_ACTIVATED)  # FIXTURE
	await _teleport(540.0)
	var t0: int = s.economy.get_amount(&"wood")
	await _tap(KEY_E)
	await _tap(KEY_E)
	_check(s.economy.get_amount(&"wood") == t0, "non-felling chops granted no wood")
	await _tap(KEY_E)
	_check(s.tree_mgr.is_felled("tree_east_01"), "tree felled after 3 chops")
	var t1: int = s.economy.get_amount(&"wood")
	_check(t1 - t0 == 5, "tree felling granted 4 base + 1 blessing = 5 (got %d)" % (t1 - t0))
	# Path C: idle villager auto-chop.
	_session = await _fresh_session()
	s = _session
	s.progression.record_fact(ProgressionState.FACT_SHRINE_OF_GROWTH_ACTIVATED)  # FIXTURE
	_grant({"gold": 10})  # FIXTURE
	await _teleport(NPCBuilderAgent.CAMP_POSITION_X)
	await _tap(KEY_R)
	_check(s.builder_npc.recruited, "builder recruited for auto-chop (fixture prerequisite)")
	var a0: int = s.economy.get_amount(&"wood")
	var chopped: bool = _sim_until(func() -> bool: return s.resource_mgr.is_collected("timber_pile_west"), 10.0)
	_check(chopped, "idle builder auto-chopped renewable timber")
	var a1: int = s.economy.get_amount(&"wood")
	_check(a1 - a0 == 6, "auto-chop delivered 5 base + 1 blessing = 6 (got %d)" % (a1 - a0))
	# Path D: ledger cap / failed transaction.
	_session = await _fresh_session()
	s = _session
	s.progression.record_fact(ProgressionState.FACT_SHRINE_OF_GROWTH_ACTIVATED)  # FIXTURE
	s.economy.set_balances_from_dict({"gold": 0, "wood": EconomyLedger.MAX_RESOURCE_CAP, "stone": 0})  # FIXTURE
	await _teleport(-110.0)
	var cap0: int = s.economy.get_amount(&"wood")
	await _tap(KEY_E)
	_check(s.economy.get_amount(&"wood") == cap0, "capped ledger rejected collection and applied no blessing")
	_check(not s.resource_mgr.is_collected("timber_pile_west"), "failed capped collection did not mark the node collected")
	return _current_failures == 0


func _scenario_save_load() -> bool:
	_remove_save(SAVE_GAME)
	_remove_save(SAVE_LEGACY)
	_remove_save(SAVE_INVALID)
	# Session A: rich state via fixtures + a real research start.
	_session = await _fresh_session()
	if _session == null:
		_check(false, "fresh session created")
		return false
	var a: ForgottenShoreSession = _session
	a.progression.record_fact(ProgressionState.FACT_SCIENTIST_DISCOVERED)  # FIXTURE
	a.progression.record_fact(ProgressionState.FACT_SCIENTIST_RECRUITED)  # FIXTURE
	a.progression.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2)  # FIXTURE
	a.progression.record_fact(ProgressionState.FACT_SHRINE_OF_GROWTH_ACTIVATED)  # FIXTURE
	a.era_mgr.apply_save_era("stone_age")  # FIXTURE
	_grant({"gold": 10, "wood": 10, "stone": 10})  # FIXTURE
	await _teleport(-1010.0)
	await _tap(KEY_E)
	_check(a.research_mgr.get_active_tech_id() == "inscription_studies", "research started for the save payload")
	_sim(30.0)
	_check(a.research_mgr.get_active_tech_id() == "inscription_studies", "research still active at ~30s")
	var expected_bal: Dictionary = _bal()
	var expected_facts: Array[String] = a.progression.get_fact_ids()
	_check(a.save_game_state(SAVE_GAME), "save_game_state wrote the test save")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_GAME))
	_check(typeof(saved) == TYPE_DICTIONARY, "saved payload parses as a dictionary")
	if typeof(saved) != TYPE_DICTIONARY:
		return false
	var saved_dict: Dictionary = saved as Dictionary
	# Session B: clean state, load, verify exact restoration.
	_session = await _fresh_session()
	if _session == null:
		_check(false, "clean session B created")
		return false
	var b: ForgottenShoreSession = _session
	_check(_bal() == {"gold": 2, "wood": 2, "stone": 1}, "clean session B starts at the default ledger")
	_check(b.progression.fact_count() == 0, "clean session B has no facts")
	_check(b.load_game_state(SAVE_GAME), "load_game_state restored the test save")
	_check(_bal() == expected_bal, "loaded ledger matches saved (%s)" % str(_bal()))
	_check(b.progression.get_fact_ids() == expected_facts, "loaded facts match saved (%s)" % str(b.progression.get_fact_ids()))
	_check(b.era_mgr.get_era_id() == "stone_age", "loaded era is stone_age")
	_check(b.specialists.is_recruited("scientist", b.progression), "loaded scientist recruitment fact")
	_check(b.structures.is_activated("shrine_of_growth", b.progression), "loaded shrine activation fact")
	_check(b.research_mgr.get_active_tech_id() == "inscription_studies", "loaded active research id")
	var active_saved: Variant = (saved_dict["research"] as Dictionary).get("active_research", null)
	var elapsed_saved: float = 0.0
	if typeof(active_saved) == TYPE_DICTIONARY:
		elapsed_saved = float((active_saved as Dictionary).get("elapsed_sec", 0.0))
	_check(is_equal_approx(b.research_mgr.get_active_elapsed(), elapsed_saved), "loaded research elapsed preserved (%.3f)" % b.research_mgr.get_active_elapsed())
	_check(_bal() == expected_bal, "load did not re-charge research or build costs")
	await _capture("gp_save_load.png")
	# Legacy v1 compatibility through the real load path.
	var legacy: Dictionary = saved_dict.duplicate(true)
	legacy["schema_version"] = 1
	legacy.erase("player")
	legacy.erase("research")
	legacy.erase("camp_vagrants_available")
	for bd: Variant in (legacy["buildings"] as Array):
		if typeof(bd) == TYPE_DICTIONARY:
			(bd as Dictionary).erase("level")
	var pf: Dictionary = legacy["progression_flags"] as Dictionary
	pf.erase("hearth_level")
	pf.erase("shipwreck_stage")
	pf.erase("portal_relic_looted")
	pf.erase("node_states")
	pf.erase("era_id")
	pf.erase("progression_facts")
	_write_json(SAVE_LEGACY, legacy)
	_session = await _fresh_session()
	if _session == null:
		_check(false, "clean session C created")
		return false
	var c: ForgottenShoreSession = _session
	_check(c.load_game_state(SAVE_LEGACY), "legacy schema v1 save loads through migration")
	_check(c.era_mgr.get_era_id() == "wood_age", "legacy save inferred wood_age (no stone-wall evidence)")
	_check(not c.research_mgr.has_active_research(), "legacy save without research key resets research")
	_check(_bal() == expected_bal, "legacy load restored ledger balances")
	# Invalid data rollback.
	var live_bal: Dictionary = _bal()
	var live_facts: Array[String] = c.progression.get_fact_ids()
	_write_json(SAVE_INVALID, {"schema_version": 2, "not_a_real_save": true})
	_check(not c.load_game_state(SAVE_INVALID), "structurally invalid save rejected")
	_check(_bal() == live_bal and c.progression.get_fact_ids() == live_facts, "rejected invalid load left live state unchanged")
	_remove_save(SAVE_GAME)
	_remove_save(SAVE_LEGACY)
	_remove_save(SAVE_INVALID)
	return _current_failures == 0
