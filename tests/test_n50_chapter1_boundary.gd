extends SceneTree

## N5.0 Chapter I Narrative Integration Boundary Test Suite.
## Verifies adapter ownership, idempotent setup/teardown, selective signal
## disconnection, restore-silent Continue/load behavior (D-N5-04 Option A),
## fresh-session event seam, lock release on unload, fail-closed partial setup,
## and SaveManager schema v2 invariance.

const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const TEST_DIR: String = "user://n50_test"
const TEST_SAVE_PATH: String = "user://n50_test/save_slot_0.json"
const REAL_PROFILE_PATH: String = "user://player_profile.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _real_profile_snap: Dictionary = {}
var _real_save_snap: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		print("PASS: " + message)
		return true
	_failures += 1
	printerr("TEST FAILURE: [N50] " + message)
	return false


func _snapshot_file(path: String) -> Dictionary:
	var existed: bool = FileAccess.file_exists(path)
	var content: String = FileAccess.get_file_as_string(path) if existed else ""
	return {"existed": existed, "content": content}


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup_fixtures() -> void:
	_rm(TEST_SAVE_PATH)
	for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
		_rm(TEST_SAVE_PATH + suffix)
	var abs_dir: String = ProjectSettings.globalize_path(TEST_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.remove_absolute(abs_dir)
	for key: String in ["crownfall_load_on_start", "crownfall_menu_save_path"]:
		if Engine.has_meta(key):
			Engine.remove_meta(key)


func _load_shore_scene(load_on_start: bool) -> Node:
	Engine.set_meta("crownfall_load_on_start", load_on_start)
	Engine.set_meta("crownfall_menu_save_path", TEST_SAVE_PATH)
	change_scene_to_file(MAIN_SCENE)
	for _i: int in range(120):
		if current_scene != null and current_scene.name == "Main":
			break
		await process_frame
	change_scene_to_file(FORGOTTEN_SHORE_SCENE)
	for _i: int in range(MAX_WAIT_FRAMES):
		if current_scene != null and current_scene.scene_file_path == FORGOTTEN_SHORE_SCENE:
			await process_frame
			return current_scene
		await process_frame
	return null


func _run() -> void:
	_real_profile_snap = _snapshot_file(REAL_PROFILE_PATH)
	_real_save_snap = _snapshot_file(SaveManager.DEFAULT_SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))

	_test_setup_failure_and_idempotency()
	await _test_fresh_session_lifecycle_and_lock_teardown()
	await _test_continue_restore_silent_and_schema_v2_invariance()

	_check(_snapshot_file(REAL_PROFILE_PATH) == _real_profile_snap, "Hygiene: real user://player_profile.json byte-exact untouched")
	_check(_snapshot_file(SaveManager.DEFAULT_SAVE_PATH) == _real_save_snap, "Hygiene: real user://save_slot_0.json byte-exact untouched")
	_cleanup_fixtures()

	if _failures == 0:
		print("PASS: All %d N50 Chapter I Boundary checks completed with 0 failures." % _checks)
		quit(0)
	else:
		printerr("FAIL: N50 Chapter I Boundary finished with %d failures out of %d checks." % [_failures, _checks])
		quit(1)


func _test_setup_failure_and_idempotency() -> void:
	# 10. Partial / missing dependencies fail closed with zero subscriptions or locks
	var bad := ChapterOneNarrativeAdapter.new()
	_check(not bad.setup({"player": null}, true), "10. Partial/missing dependencies fail closed")
	_check(not bad.is_initialized() and not bad.is_active() and bad.tracked_connection_count() == 0 and not bad.control_lock().is_locked(), "10. Failed setup leaves zero subscriptions and zero locks")


func _test_fresh_session_lifecycle_and_lock_teardown() -> void:
	var session: Node = await _load_shore_scene(false)
	if not _check(session != null and bool(session.call("is_session_initialized")), "1. Fresh ForgottenShoreSession initialized"):
		return
	var adapter: ChapterOneNarrativeAdapter = session.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	if not _check(adapter != null and adapter.is_initialized() and adapter.is_active(), "1. Session-owned adapter initialized and active on fresh session"):
		return

	# 2. Repeated setup does not duplicate signal connections
	var conn_before: int = adapter.tracked_connection_count()
	var deps: Dictionary = {
		"player": session.get("player"),
		"time_manager": session.get("time_manager"),
		"building_mgr": session.get("building_mgr"),
		"night_mgr": session.get("night_mgr"),
		"progression": session.get("progression"),
		"dialogue_panel": adapter.dialogue_panel(),
	}
	_check(adapter.setup(deps, true) and adapter.tracked_connection_count() == conn_before, "2. Repeated setup is idempotent and does not duplicate connections")

	# 4 & 8. External listener preserved + fresh-session post-init event reaches adapter once
	var prog: ProgressionState = session.get("progression") as ProgressionState
	var ext_hits: Array[String] = []
	var ext_cb: Callable = func(fid: String) -> void: ext_hits.append(fid)
	prog.fact_recorded.connect(ext_cb)

	prog.record_fact(ProgressionState.FACT_SCIENTIST_DISCOVERED)
	prog.record_fact(ProgressionState.FACT_SCIENTIST_DISCOVERED)
	_check(adapter.observed_event_count() == 1 and String(adapter.last_observed_event().get("fact_id", "")) == ProgressionState.FACT_SCIENTIST_DISCOVERED, "8. Fresh-session gameplay event reaches adapter seam once without duplicates")
	_check(adapter.narrative_state().completed_count() == 0 and not adapter.dialogue_panel().is_open(), "N5.0 infrastructure opens no dialogue and records no beats")

	# 6. Restore-silent boundary suppresses signals during save restore
	adapter.begin_save_restore()
	_check(adapter.is_restoring_save() and not adapter.is_active(), "6. begin_save_restore disables live dispatch")
	prog.record_fact(ProgressionState.FACT_SCIENTIST_RECRUITED)
	_check(adapter.observed_event_count() == 1 and adapter.narrative_state().completed_count() == 0 and not adapter.dialogue_panel().is_open(), "6. Signals during save restore do not dispatch, open dialogue, or mutate NarrativeState")
	adapter.end_save_restore(false)

	# 3, 4 & 9. Teardown/unload disconnects ONLY adapter's signals and releases adapter-owned lock
	var player_node: Node = session.get("player") as Node
	adapter.control_lock().lock(player_node)
	_check(adapter.control_lock().is_locked() and not player_node.is_physics_processing(), "9. Lock seam acquired for teardown verification")

	# Save a fixture with FACT_FORGOTTEN_SHORE_VESSEL_READY for the Continue test next
	prog.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)
	_check(bool(session.call("save_game_state", TEST_SAVE_PATH)), "Fixture save written to isolated user://n50_test/")

	# Unload scene to verify _exit_tree() teardown + selective disconnect
	change_scene_to_file(MAIN_SCENE)
	for _i: int in range(60):
		if current_scene != null and current_scene.name == "Main":
			break
		await process_frame
	_check(adapter.is_torn_down() and adapter.tracked_connection_count() == 0 and not adapter.control_lock().is_locked(), "3 & 9. Scene unload runs teardown, clears connections, and releases player lock")
	adapter.teardown()
	_check(adapter.is_torn_down() and adapter.tracked_connection_count() == 0, "3. Repeated teardown is safe and idempotent")
	_check(prog.is_connected(&"fact_recorded", ext_cb), "4. Adapter teardown disconnected only its own listeners (external listener preserved)")


func _test_continue_restore_silent_and_schema_v2_invariance() -> void:
	# 5, 7, 11, 12. Continue load stays silent, does not synthesize historical beats, schema v2 unchanged
	var session: Node = await _load_shore_scene(true)
	if not _check(session != null and bool(session.call("was_loaded_from_save_on_start")), "5. Continue session loaded from isolated fixture save"):
		return
	var adapter: ChapterOneNarrativeAdapter = session.get("chapter1_narrative") as ChapterOneNarrativeAdapter
	var prog: ProgressionState = session.get("progression") as ProgressionState
	_check(prog.has_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY), "7. Historical progression fact restored from save")
	_check(adapter != null and adapter.is_initialized() and not adapter.is_active(), "5. Continue restoration does not activate narrative dispatch")
	_check(adapter.observed_event_count() == 0 and adapter.narrative_state().completed_count() == 0 and not adapter.dialogue_panel().is_open(), "7. Already-satisfied gameplay state at Continue synthesizes zero historical beats")

	# 11. SaveManager schema v2 & payload keys invariant (no per-beat narrative flags)
	var payload: Dictionary = session.call("build_save_payload")
	_check(SaveManager.SCHEMA_VERSION == 2 and int(payload.get("schema_version", 0)) == 2, "11. SaveManager schema version remains v2")
	_check(not payload.has("chapter1_narrative") and not payload.has("narrative_beats") and not payload.has("ch1_beats"), "11. Serialized payload adds zero per-beat narrative persistence keys")
	var save_mgr := SaveManager.new()
	_check(save_mgr.validate_payload(payload), "11. Serialized payload passes SaveManager v2 validation unchanged")
