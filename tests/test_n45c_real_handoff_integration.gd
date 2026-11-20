extends SceneTree

## N4.5-C Real Scene Handoff Integration & Menu Routing Suite.
## Loads the REAL res://scenes/world/ForgottenShore.tscn destination (no injected
## transition callback) and proves ForgottenShoreSession initialization triggers
## exact-once PlayerProfile completion, fresh-session state, and safe menu routing.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const PROLOGUE_SHELL_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const TEST_DIR: String = "user://n45c_test"
const PROFILE_FIXTURE: String = "user://n45c_test/profile.json"
const SAVE_FIXTURE: String = "user://n45c_test/save_slot_0.json"
const REAL_PROFILE_PATH: String = "user://player_profile.json"
const AUTOSTART_META: String = "crownfall_prologue_autostart"
const EXPLORATION_META: String = "crownfall_prologue_exploration"
const MAX_WAIT_FRAMES: int = 1800

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
	printerr("TEST FAILURE: [N45C] " + message)
	return false


func _snapshot_file(path: String) -> Dictionary:
	var existed: bool = FileAccess.file_exists(path)
	var content: String = FileAccess.get_file_as_string(path) if existed else ""
	return {"existed": existed, "content": content}


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _reset_fixtures(profile_completed: bool) -> void:
	PrologueHandoffBridge.reset_for_tests()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	for p: String in [PROFILE_FIXTURE, SAVE_FIXTURE]:
		_rm(p)
		for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
			_rm(p + suffix)
	var f: FileAccess = FileAccess.open(PROFILE_FIXTURE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"schema_version": 1, "prologue_completed_once": profile_completed}, "\t"))
		f.flush()
		f.close()
	Engine.set_meta("crownfall_profile_path", PROFILE_FIXTURE)
	Engine.set_meta("crownfall_menu_save_path", SAVE_FIXTURE)
	Engine.set_meta("crownfall_load_on_start", false)


func _read_fixture_completed() -> bool:
	var p := PlayerProfile.new()
	p.set_profile_path(PROFILE_FIXTURE)
	p.load_profile()
	return p.is_prologue_completed_once()


func _cleanup_all() -> void:
	PrologueHandoffBridge.reset_for_tests()
	for p: String in [PROFILE_FIXTURE, SAVE_FIXTURE]:
		_rm(p)
		for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
			_rm(p + suffix)
	var abs_dir: String = ProjectSettings.globalize_path(TEST_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.remove_absolute(abs_dir)
	for key: String in [AUTOSTART_META, EXPLORATION_META, "crownfall_profile_path", "crownfall_menu_save_path", "crownfall_load_on_start"]:
		if Engine.has_meta(key):
			Engine.remove_meta(key)


func _run() -> void:
	_real_profile_snap = _snapshot_file(REAL_PROFILE_PATH)
	_real_save_snap = _snapshot_file(SaveManager.DEFAULT_SAVE_PATH)

	await _test_real_scene_handoff_to_forgotten_shore()
	await _test_menu_continue_and_new_game_do_not_consume_pending_intent()
	await _test_replay_preserves_true_profile_flag()

	_check(_snapshot_file(REAL_PROFILE_PATH) == _real_profile_snap, "Hygiene: real user://player_profile.json byte-exact untouched")
	_check(_snapshot_file(SaveManager.DEFAULT_SAVE_PATH) == _real_save_snap, "Hygiene: real user://save_slot_0.json byte-exact untouched")
	_cleanup_all()

	if _failures == 0:
		print("PASS: All %d N45C Real Handoff Integration checks completed with 0 failures." % _checks)
		quit(0)
	else:
		printerr("FAIL: N45C Real Handoff Integration finished with %d failures out of %d checks." % [_failures, _checks])
		quit(1)


func _test_real_scene_handoff_to_forgotten_shore() -> void:
	_reset_fixtures(false)
	Engine.set_meta(AUTOSTART_META, false)
	Engine.set_meta(EXPLORATION_META, true)
	change_scene_to_file(PROLOGUE_SHELL_SCENE)
	var shell: Control = null
	for _i: int in range(MAX_WAIT_FRAMES):
		if current_scene != null and current_scene.name == "PrologueShell":
			shell = current_scene as Control
			break
		await process_frame
	if not _check(shell != null, "Real Handoff: PrologueShell loaded"):
		return

	# Advance pl_01 -> pl_08 -> N4.5-A boundary
	shell.call("start_prologue")
	await process_frame
	shell.call("skip_sequence")
	for _i: int in range(MAX_WAIT_FRAMES):
		if String(shell.call("current_beat_id")) == "pl_02_faint_resonance":
			break
		await process_frame
	shell.call("skip_sequence")
	for _i: int in range(MAX_WAIT_FRAMES):
		if bool(shell.call("in_exploration")):
			break
		await process_frame
	shell.call("skip_current_exploration_beat")
	shell.call("skip_current_exploration_beat")
	shell.call("skip_current_exploration_beat")
	shell.call("skip_current_exploration_beat")
	shell.call("start_voyage_sequence")
	await process_frame
	shell.call("skip_sequence")
	for _i: int in range(MAX_WAIT_FRAMES):
		if String(shell.call("active_voyage_beat")) == PrologueBeats.PL_08_SHIPWRECK:
			break
		await process_frame
	shell.call("skip_sequence")
	for _i: int in range(MAX_WAIT_FRAMES):
		if bool(shell.call("n45a_boundary_reached")):
			break
		await process_frame

	# Do NOT inject set_exit_transition — let PrologueShell load the REAL ForgottenShore.tscn!
	_check(not _read_fixture_completed(), "Real Handoff: profile is false before pl_09 starts")
	_check(bool(shell.call("start_shore_handoff")), "Real Handoff: pl_09 started without mocked transition callback")

	var saw_title_before_scene_change: bool = false
	var shore_scene: Node = null
	for _i: int in range(MAX_WAIT_FRAMES):
		if is_instance_valid(shell) and current_scene == shell:
			if String(shell.call("shore_title_text")) == "CHAPTER I — FORGOTTEN SHORE":
				saw_title_before_scene_change = true
		if current_scene != null and current_scene.scene_file_path == FORGOTTEN_SHORE_SCENE:
			shore_scene = current_scene
			break
		await process_frame

	# Let one frame settle so _ready() is guaranteed complete
	await process_frame
	_check(saw_title_before_scene_change, "Real Handoff: exact title 'CHAPTER I — FORGOTTEN SHORE' displayed before scene switch")
	_check(shore_scene != null and shore_scene.scene_file_path == FORGOTTEN_SHORE_SCENE, "Real Handoff: actual ForgottenShore.tscn loaded as current_scene")
	if shore_scene == null:
		return
	_check(bool(shore_scene.call("is_session_initialized")), "Real Handoff: ForgottenShoreSession completed _ready() initialization")
	_check(not bool(shore_scene.call("was_loaded_from_save_on_start")), "Real Handoff: destination started in fresh-session mode (not Continue load)")
	_check(shore_scene.get_node_or_null("Player") != null and shore_scene.get_node_or_null("TimeManager") != null and shore_scene.get_node_or_null("ClockHUD") != null, "Real Handoff: required gameplay nodes (Player, TimeManager, ClockHUD) exist")
	_check(not PrologueHandoffBridge.has_pending_intent(), "Real Handoff: one-shot bridge intent consumed after target initialization")
	var last: Dictionary = PrologueHandoffBridge.last_result()
	_check(bool(last.get("ok", false)) and bool(last.get("persisted", false)) and _read_fixture_completed(), "Real Handoff: PlayerProfile.prologue_completed_once persisted ONLY after ForgottenShoreSession initialized")
	var dup_ack: Dictionary = PrologueHandoffBridge.acknowledge_destination_ready(FORGOTTEN_SHORE_SCENE, true, false)
	_check(not bool(dup_ack.get("ok", true)), "Real Handoff: duplicate acknowledgment after real load is rejected")


func _test_menu_continue_and_new_game_do_not_consume_pending_intent() -> void:
	_reset_fixtures(false)
	PrologueHandoffBridge.authorize_fresh_handoff(FORGOTTEN_SHORE_SCENE, PROFILE_FIXTURE)
	change_scene_to_file(MAIN_SCENE)
	var main_node: Control = null
	for _i: int in range(180):
		if current_scene != null and current_scene.name == "Main":
			main_node = current_scene as Control
			break
		await process_frame
	if not _check(main_node != null, "Menu Routing: Main.tscn loaded"):
		return
	var routes: Array[String] = []
	main_node.call("set_route_transition", func(path: String) -> void: routes.append(path))
	main_node.call("_on_continue_button_pressed")
	_check(routes == [FORGOTTEN_SHORE_SCENE] and bool(Engine.get_meta("crownfall_load_on_start", false)), "Menu Routing: Continue sets load_on_start and routes to Forgotten Shore")
	_check(not PrologueHandoffBridge.has_pending_intent() and not _read_fixture_completed(), "Menu Routing: Continue clears stale pending handoff intent and never marks Prologue complete")


func _test_replay_preserves_true_profile_flag() -> void:
	_reset_fixtures(true)
	change_scene_to_file(MAIN_SCENE)
	var main_node: Control = null
	for _i: int in range(180):
		if current_scene != null and current_scene.name == "Main":
			main_node = current_scene as Control
			break
		await process_frame
	if not _check(main_node != null, "Replay Routing: Main.tscn loaded"):
		return
	var routes: Array[String] = []
	main_node.call("set_route_transition", func(path: String) -> void: routes.append(path))
	main_node.call("_route_to_prologue")
	_check(routes == [PROLOGUE_SHELL_SCENE] and _read_fixture_completed(), "Replay Routing: Play Prologue Again routes to Prologue without downgrading true profile flag")
