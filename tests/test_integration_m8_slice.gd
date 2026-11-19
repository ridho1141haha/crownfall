extends SceneTree

const TEST_SAVE_PATH: String = "user://test_m8_integration_save.json"
## N4.0: the entry gate now consults a PlayerProfile. The M8 slice runs as a
## returning player (pre-completed profile) so the gameplay scenario reaches
## ForgottenShore through the real Skip path (fresh session), unchanged.
const TEST_PROFILE_PATH: String = "user://test_m8_profile.json"
const MAX_WAIT_FRAMES: int = 120

## Round-2 save isolation (review P1): this suite drives the REAL game flow —
## including the sunrise Day-2 autosave and the ISLAND_CLEARED-style default
## path — so it previously wrote the developer's real user://save_slot_0.json
## when run against the normal user data dir. Following the 3A architecture:
## without the child env key the script is the PARENT (it only snapshots the
## real autosave slot byte-exact, spawns itself as a child whose
## HOME/XDG_DATA_HOME point at a fresh temp base, relays the child output,
## verifies the real slot stayed byte-exact and removes the temp base with a
## strictly guarded rm); with the key it is the CHILD and a fail-closed
## sandbox gate proves — before ANY scene load or save work — that user://
## really resolved inside the sandbox (Godot caches the user:// root at
## process startup, so the env must be set BEFORE the process launches; it is
## never trusted in-process). PLATFORM: Linux-only by design (guarded rm -rf
## cleanup); any other platform is an explicit counted SKIP (exit 2), never a
## fake PASS, and nothing runs there without a proven sandbox.
## Audit round 3: the parent verdict requires the child exit 0 AND every
## parent-level proof clean (quit() only flags the exit — it cannot stop or
## override a recorded failure); slot existence and content are proven
## separately; the temp base is created exclusively (never reused) and must
## canonicalize to itself (readlink -m), and the child gate also proves
## containment on canonicalized paths (symlink-proof).
const TEMP_BASE_PREFIX: String = "/tmp/m8_iso_"
const ENV_CHILD: String = "M8_ISOLATED_CHILD"
const ENV_TMP: String = "M8_ISOLATED_TMP"
const ENV_NORMAL: String = "M8_NORMAL_USER_DIR"

var _stage: int = 0
var _wait_frames: int = 0
var _checks: int = 0
var _failed: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failed += 1
		printerr("TEST FAILURE [test_integration_m8_slice]: " + msg)
		quit(1)
		return false
	return true


func _initialize() -> void:
	# Round-2 isolation entry point: parent/child split, platform SKIP, and a
	# fail-closed sandbox gate before any scene or save work (see the contract
	# above the consts).
	if OS.get_name() != "Linux":
		print("SKIP: test_integration_m8_slice is Linux-only by design (isolated sandbox + rm-based cleanup); not executing on %s" % OS.get_name())
		quit(2)
		return
	if OS.get_environment(ENV_CHILD) == "1":
		if not _sandbox_gate(OS.get_environment(ENV_TMP), OS.get_environment(ENV_NORMAL)):
			return
		_run_child_flow()
	else:
		_run_parent_wrapper()


func _run_child_flow() -> void:
	# N4.0 entry isolation: inject a pre-completed profile so the menu's
	# returning-player choice appears; Skip starts a fresh ForgottenShore
	# session, exactly the session the original gameplay checks expect.
	Engine.set_meta("crownfall_profile_path", TEST_PROFILE_PATH)
	var f: FileAccess = FileAccess.open(TEST_PROFILE_PATH, FileAccess.WRITE)
	if not _check(f != null, "M8 test profile file created"):
		return
	f.store_string(JSON.stringify({"schema_version": 1, "prologue_completed_once": true}, "\t"))
	f.flush()
	f.close()
	Engine.set_meta("crownfall_load_on_start", false)
	var err: Error = change_scene_to_file("res://scenes/main/Main.tscn")
	_check(err == OK, "Initial change_scene_to_file to Main.tscn")


func _process(_delta: float) -> bool:
	_wait_frames += 1
	if _wait_frames > MAX_WAIT_FRAMES:
		_check(false, "Scene transition timed out at stage %d" % _stage)
		return true

	match _stage:
		0:
			if current_scene == null or current_scene.name != "Main":
				return false
			var play_btn: Button = current_scene.get_node_or_null("CenterContainer/VBoxContainer/PlayButton") as Button
			if not _check(play_btn != null, "PlayButton exists on Main.tscn"):
				return true
			play_btn.pressed.emit()
			_wait_frames = 0
			_stage = 1
			return false

		1:
			# N4.0: Start New Game may ask for the existing overwrite confirmation
			# when a valid save exists, then the returning-player Prologue choice
			# (pre-completed injected profile). Confirm/skip in order, then wait
			# for the fresh ForgottenShore transition via Skip. Visibility is
			# checked with is_visible_in_tree(): a hidden overlay keeps the
			# buttons' own .visible flag true, so pressing on .visible would
			# re-fire the handler every frame and never let the loop settle.
			var confirm_btn: Button = current_scene.find_child("ConfirmNewGameButton", true, false) as Button
			if confirm_btn != null and confirm_btn.is_visible_in_tree():
				confirm_btn.pressed.emit()
				_wait_frames = 0
				return false
			var skip_btn: Button = current_scene.find_child("SkipPrologueButton", true, false) as Button
			if skip_btn != null and skip_btn.is_visible_in_tree():
				skip_btn.pressed.emit()
				_wait_frames = 0
				return false
			if current_scene == null or current_scene.name != "ForgottenShore":
				return false
			var session: ForgottenShoreSession = current_scene as ForgottenShoreSession
			if not _check(session != null and session.time_manager != null, "ForgottenShoreSession and @onready time_manager ready"):
				return true
			session.time_manager.auto_advance = false

			if not _check(not session.execute_command(&"interact", 1500.0), "Empty interact returns false"):
				return true
			if not _check(session.execute_command(&"interact", -480.0), "Collect west gold chest"):
				return true
			if not _check(not session.execute_command(&"interact", -480.0), "Duplicate interact returns false"):
				return true
			if not _check(session.execute_command(&"interact", -110.0), "Collect timber pile"):
				return true
			if not _check(session.execute_command(&"interact", 190.0), "Collect stone outcrop"):
				return true
			if not _check(session.execute_command(&"interact", -780.0), "Collect shrine cache"):
				return true
			if not _check(session.economy.get_amount(&"gold") == 9 and session.economy.get_amount(&"wood") == 7 and session.economy.get_amount(&"stone") == 4, "Collected balances match 9G/7W/4S"):
				return true

			if not _check(not session.execute_command(&"recruit", 100.0), "Out-of-range recruit rejected"):
				return true
			if not _check(session.execute_command(&"recruit", -220.0), "Recruit Builder at Camp"):
				return true
			if not _check(session.execute_command(&"recruit", -220.0), "Recruit second Vagrant as Villager"):
				return true
			if not _check(not session.execute_command(&"recruit", -220.0), "Recruit rejected when no Vagrants remain"):
				return true
			if not _check(not session.execute_command(&"build_wall", 0.0), "Out-of-range build_wall rejected"):
				return true
			if not _check(session.execute_command(&"build_wall", 360.0), "Fund Wooden Wall at x=360"):
				return true
			if not _check(not session.execute_command(&"build_wall", 360.0), "Duplicate build_wall rejected"):
				return true
			if not _check(session.execute_command(&"assign_tool", 45.0), "Assign Villager as Archer via Bow Stand"):
				return true

			for _step: int in range(12):
				session._process(1.0)
			if not _check(session.building_mgr.state == BuildingManager.WallState.COMPLETED and session.building_mgr.durability == 150, "Builder completed wall to 150 HP"):
				return true

			session.time_manager.advance_time(480.0)
			if not _check(session.time_manager.current_phase == TimeManager.Phase.SUNSET and session.builder_npc.safety_override_active, "Sunset triggers Builder safety override"):
				return true
			for _step: int in range(5):
				session._process(1.0)
			if not _check(absf(session.builder_npc.position_x - NPCBuilderAgent.SAFE_ZONE_X) <= NPCBuilderAgent.WORK_RANGE, "Builder reached safe zone"):
				return true

			session.time_manager.advance_time(60.0)
			if not _check(session.time_manager.current_phase == TimeManager.Phase.NIGHT, "Night started"):
				return true
			for _step: int in range(6):
				session._process(1.0)
			var mid_night_x: float = session.night_mgr.enemy_x
			var mid_night_hp: int = session.night_mgr.enemy_hp
			if not _check(session.save_game_state(TEST_SAVE_PATH), "Mid-night save succeeded"):
				return true

			for _step: int in range(174):
				session._process(1.0)
			session.time_manager.advance_time(180.0)
			if not _check(session.time_manager.current_day == 2 and session.night_mgr.first_night_survived and session.building_mgr.durability == 150, "Archer-defended wall survives 3-wave Night 1 at full 150 HP"):
				return true

			if not _check(session.load_game_state(TEST_SAVE_PATH), "Mid-night state reload succeeded"):
				return true
			if not _check(is_equal_approx(session.night_mgr.enemy_x, mid_night_x) and session.night_mgr.enemy_hp == mid_night_hp, "Mid-night enemy position and HP preserved"):
				return true

			for _step: int in range(174):
				session._process(1.0)
			session.player.global_position.x = 340.0
			session.time_manager.advance_time(180.0)
			if not _check(SaveManager.new().has_valid_save(), "Sunrise Day 2 autosave exists and is valid"):
				return true

			var err_back: Error = change_scene_to_file("res://scenes/main/Main.tscn")
			if not _check(err_back == OK, "Transition back to Main.tscn"):
				return true
			_wait_frames = 0
			_stage = 2
			return false

		2:
			if current_scene == null or current_scene.name != "Main":
				return false
			var continue_btn: Button = current_scene.get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button
			if not _check(continue_btn != null and not continue_btn.disabled, "ContinueButton enabled on Main.tscn"):
				return true
			continue_btn.pressed.emit()
			_wait_frames = 0
			_stage = 3
			return false

		3:
			if current_scene == null or current_scene.name != "ForgottenShore":
				return false
			var loaded_session: ForgottenShoreSession = current_scene as ForgottenShoreSession
			if not _check(loaded_session != null and loaded_session.time_manager != null, "Continue transitioned to ForgottenShoreSession"):
				return true
			if not _check(loaded_session.time_manager.current_day == 2 and loaded_session.night_mgr.first_night_survived, "Continue loaded Day 2 survived state"):
				return true
			if not _check(is_equal_approx(loaded_session.player.global_position.x, 340.0), "Continue restored player position_x == 340.0"):
				return true
			if not _check(loaded_session.builder_npc.recruited and loaded_session.building_mgr.durability == 150, "Continue loaded Builder and 150 HP wall"):
				return true
			if not _check(loaded_session.pop_mgr.agents.size() == 2 and loaded_session.pop_mgr.agents[1].role == "archer", "Continue restores recruited Archer"):
				return true
			if not _check(not bool(loaded_session.collected_node_ids.get("timber_pile_west", false)) and not bool(loaded_session.collected_node_ids.get("stone_outcrop_east", false)), "Continue restores renewable Wood/Stone nodes as available on Day 2"):
				return true
			if not _check(bool(loaded_session.collected_node_ids.get("cache_gold_west", false)) and bool(loaded_session.collected_node_ids.get("shrine_cache_far_west", false)), "Continue keeps non-renewable Gold caches collected"):
				return true
			if not _check(loaded_session.building_mgr.apply_damage(30) == 30 and loaded_session.building_mgr.durability == 120, "Simulated raid damage sets wall to DAMAGED"):
				return true
			if not _check(loaded_session.execute_command(&"repair_wall", 360.0) and loaded_session.building_mgr.durability == 150, "Day 2 wall repair to 150 HP"):
				return true

			# N4.0 hygiene: remove the injected profile fixture before reporting.
			if FileAccess.file_exists(TEST_PROFILE_PATH):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE_PATH))
			print("PASS: All %d M8 Multi-Frame Scene Transition & Save/Continue Integration Checks succeeded!" % _checks)
			quit(0)
			return true

	return false


func _sandbox_gate(claimed_tmp: String, normal_dir: String) -> bool:
	# CHILD: fail-closed sandbox gate — EVERY isolation condition is proven
	# BEFORE any scene load or save work (same contract as the 3A suite).
	var user_dir: String = OS.get_user_data_dir().simplify_path()
	var claimed_base: String = claimed_tmp.simplify_path()
	var slot_global: String = ProjectSettings.globalize_path(SaveManager.DEFAULT_SAVE_PATH).simplify_path()
	var conditions: Array = [
		[claimed_base != "" and claimed_base.is_absolute_path() and claimed_base.begins_with(TEMP_BASE_PREFIX),
			"iso: claimed temp base is a self-generated absolute m8_iso path (%s)" % claimed_base],
		[normal_dir != "", "iso: normal user dir marker provided"],
		[normal_dir != "" and user_dir != normal_dir.simplify_path(),
			"iso: process user data dir differs from the normal user data dir"],
		[_is_descendant_of(user_dir, claimed_base),
			"iso: process user data dir is a TRUE descendant of the claimed temp base (%s)" % user_dir],
		[_is_descendant_of(slot_global, claimed_base),
			"iso: default autosave path is a TRUE descendant of the claimed temp base (%s)" % slot_global],
		[_is_descendant_of(_canonicalize(user_dir), _canonicalize(claimed_base)),
			"iso: canonicalized user data dir is a TRUE descendant of the canonicalized temp base (symlink-proof)"],
		[not FileAccess.file_exists(SaveManager.DEFAULT_SAVE_PATH),
			"iso: sandbox starts with NO pre-existing autosave slot"],
	]
	var problems: PackedStringArray = PackedStringArray()
	for cond: Array in conditions:
		if not bool(cond[0]):
			problems.append(String(cond[1]))
	if not problems.is_empty():
		for p: String in problems:
			print("TEST FAILURE: sandbox gate: %s" % p)
		print("TEST FAILURE: M8 sandbox gate refused the run — no scene load or save work attempted")
		quit(1)
		return false
	for cond: Array in conditions:
		print("M8|ISO|ok: %s" % String(cond[1]))
	print("M8|GATE|ok — sandbox proven valid; proceeding to scene load")
	return true


func _is_descendant_of(child_path: String, base_path: String) -> bool:
	# TRUE-descendant containment (lexical normalize + component boundary),
	# never a bare string prefix; empty/root bases contain nothing.
	var child: String = child_path.simplify_path()
	var base: String = base_path.simplify_path()
	if base == "" or base == "/":
		return false
	if child == base:
		return true
	return child.begins_with(base + "/")


func _run_parent_wrapper() -> void:
	# PARENT: never performs game/save work. Structural isolation comes from
	# re-executing this script as a child with a throwaway user data dir; the
	# real autosave slot's EXISTENCE and CONTENT are proven unchanged before
	# vs. after the child runs (audit round 3, F4: separately).
	var normal_user_dir: String = OS.get_user_data_dir()
	print("M8|PARENT|normal user data dir (startup): %s" % normal_user_dir)
	var real_save: String = SaveManager.DEFAULT_SAVE_PATH
	var had_real_save: bool = FileAccess.file_exists(real_save)
	var real_bytes: PackedByteArray = FileAccess.get_file_as_bytes(real_save) if had_real_save else PackedByteArray()
	var temp_base: String = "%s%d_%d" % [TEMP_BASE_PREFIX, OS.get_process_id(), Time.get_ticks_usec()]
	# F5 (audit round 3): exclusive creation + canonical validation — a
	# pre-existing or planted entry is never reused, and a symlink anywhere
	# on the base path aborts the parent before the child is spawned.
	if not _make_exclusive_base(temp_base):
		printerr("TEST FAILURE [test_integration_m8_slice]: parent refused a non-exclusive or non-canonical temp base (%s)" % temp_base)
		quit(1)
		return
	var child_out: Array = []
	var exit_code: int = _run_child_process(temp_base, temp_base, normal_user_dir, child_out)
	for line: Variant in child_out:
		print(str(line))
	var had_after_save: bool = FileAccess.file_exists(real_save)
	var after_bytes: PackedByteArray = FileAccess.get_file_as_bytes(real_save) if had_after_save else PackedByteArray()
	_check(had_real_save == had_after_save, "parent: real autosave slot EXISTENCE unchanged before vs after the isolated run")
	_check(real_bytes == after_bytes, "parent: real autosave slot byte-exact unchanged across the isolated run (%s)" % ProjectSettings.globalize_path(real_save))
	_check(_rmrf_guarded(temp_base), "parent: temporary isolated user data removed")
	# F1 (audit round 3): the parent verdict requires BOTH the child verdict
	# AND every parent-level proof. quit() does not stop the current function
	# in Godot 4 — it only flags the exit — so a failing _check() above can
	# never be silently overridden by the success branch.
	if exit_code == 0 and _failed == 0:
		print("PASS: M8 parent wrapper — isolated child exit 0, all parent checks clean (%d checks)" % _checks)
		quit(0)
	else:
		printerr("TEST FAILURE [test_integration_m8_slice]: parent wrapper (child_exit=%d, parent_failures=%d)" % [exit_code, _failed])
		quit(1)


func _run_child_process(home_base: String, claimed_tmp: String, normal_dir: String, out: Array) -> int:
	# Godot 4.7.2 has no OS.execute_with_env, so the env is set on THIS
	# process before the launch and restored afterwards; the child's user://
	# root is derived from that env at ITS startup (cached — see 3A evidence).
	var orig_home: String = OS.get_environment("HOME")
	var orig_xdg: String = OS.get_environment("XDG_DATA_HOME")
	var orig_xdg_cache: String = OS.get_environment("XDG_CACHE_HOME")
	DirAccess.make_dir_recursive_absolute(home_base.path_join("xdg"))
	OS.set_environment("HOME", home_base)
	OS.set_environment("XDG_DATA_HOME", home_base.path_join("xdg"))
	OS.set_environment("XDG_CACHE_HOME", home_base.path_join("xdg-cache"))
	OS.set_environment(ENV_CHILD, "1")
	OS.set_environment(ENV_TMP, claimed_tmp)
	OS.set_environment(ENV_NORMAL, normal_dir)
	var exit_code: int = OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/test_integration_m8_slice.gd",
	], out, true)
	OS.set_environment("HOME", orig_home)
	OS.set_environment("XDG_DATA_HOME", orig_xdg)
	OS.set_environment("XDG_CACHE_HOME", orig_xdg_cache)
	OS.set_environment(ENV_CHILD, "")
	OS.set_environment(ENV_TMP, "")
	OS.set_environment(ENV_NORMAL, "")
	return exit_code


func _canonicalize(path: String) -> String:
	# F5 (audit round 3): resolve symlinks for EVERY path component via GNU
	# readlink -m (also works for not-yet-existing tails). An empty string
	# means resolution failed — callers must treat that as fail-closed.
	var out: Array = []
	var rc: int = OS.execute("readlink", ["-m", "--", path], out, true)
	if rc != 0 or out.is_empty():
		return ""
	var resolved: String = String(out[0]).strip_edges()
	if resolved.contains("\n"):
		resolved = resolved.split("\n")[0]
	return resolved if resolved.is_absolute_path() else ""


func _make_exclusive_base(base: String) -> bool:
	# F5 (audit round 3): exclusive creation plus canonical validation. A
	# pre-existing directory/file at the self-generated path (collision or a
	# planted symlink) is NEVER reused; after creation the path must resolve
	# to itself (no symlink component anywhere). Any failure returns false
	# and the parent aborts before spawning the child.
	if base.is_empty() or not base.is_absolute_path() or not base.begins_with(TEMP_BASE_PREFIX):
		return false
	if DirAccess.dir_exists_absolute(base) or FileAccess.file_exists(base):
		return false
	if DirAccess.make_dir_recursive_absolute(base) != OK or not DirAccess.dir_exists_absolute(base):
		return false
	var resolved: String = _canonicalize(base)
	return resolved != "" and resolved == base


func _rmrf_guarded(target: String) -> bool:
	# Linux-only, strictly guarded removal of a self-generated temp base:
	# only absolute paths under this suite's own prefix are ever touched.
	if not target.is_absolute_path() or not target.begins_with(TEMP_BASE_PREFIX) or not DirAccess.dir_exists_absolute(target):
		return false
	var rm_out: Array = []
	var rm_rc: int = OS.execute("rm", ["-rf", "--", target], rm_out, false)
	return rm_rc == 0 and not DirAccess.dir_exists_absolute(target)
