## N44 Step3 3A — P0.1 Shrine Offering autosave ordering regression tests.
##
## Step 2 baseline (docs/reviews/N44_STEP2_REPRODUCTION_REPORT.md): the sunrise
## autosave persisted shrine_offering_used_today=true into the day-2 payload
## because the flag was reset in _on_daylight_started (FSS:905), which fires
## AFTER the autosave inside _on_sunrise_reached. Continue then restored the
## stale flag and the Shrine rejected the day-2 offering.
##
## Regression contract:
##   A1  sunrise autosave payload records day N+1 with offering flag false
##   A2  Continue makes the offering available on day N+1
##   A3  same-session offering is available after the transition (no change)
##   A4  the offering stays used for the rest of day N (no premature reset)
##   A5  exactly-once: one sunrise signal, one daylight signal, one autosave
##
## Isolation contract (review follow-up — structural, not snapshot/restore):
##   The game flow ALWAYS runs inside a temporary Godot user data directory,
##   never in the developer's real one. PLATFORM: the suite is Linux-only by
##   design — the sandbox cleanup needs rm -rf because Godot 4.7.2 offers no
##   recursive-delete API and list_dir_begin() hides dot-entries — so on any
##   other platform the suite reports an explicit, counted SKIP (exit 2 with a
##   "^SKIP:" line, round 2) before doing anything; an unsupported platform
##   still never continues without isolation (fail-closed), and a skip is
##   never presented as a PASS.
##   Without the child env key the script is the PARENT: it snapshots the
##   real autosave slot byte-exact, FIRST spawns a NEGATIVE PROBE child whose
##   claimed temp base is a bogus sibling path — the gate must refuse it
##   before any scene/save work (fail-closed proof, asserted by the parent) —
##   then spawns itself as the real child with HOME/XDG_DATA_HOME pointed at
##   a fresh temp base, relays the child output, verifies the real slot
##   stayed byte-exact, removes both temp bases, and exits with the child's
##   verdict. With the env key it is the CHILD: a fail-closed sandbox gate
##   evaluates EVERY isolation condition before change_scene_to_file() —
##   _check() is only a log recorder, never the gate; any failed condition
##   prints specific TEST FAILURE reasons, quit(1)s and returns, so no scene
##   loading, save read/write or gameplay can happen in an unproven sandbox.
##   Containment uses TRUE path descendants (String.simplify_path()
##   normalization + separator boundary), never bare string prefixes.
##   This works when run directly and via tests/run_all.sh alike, and the
##   real save can never be written because the child's user:// root is a
##   fresh directory that dies with the run. _finish() cleanup is a
##   courtesy, not the protection.
extends SceneTree

const SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const REAL_SAVE: String = SaveManager.DEFAULT_SAVE_PATH
const TEMP_BASE_PREFIX: String = "/tmp/step3a_iso_"
const ENV_CHILD: String = "STEP3_ISOLATED_CHILD"
const ENV_TMP: String = "STEP3_ISOLATED_TMP"
const ENV_NORMAL: String = "STEP3_NORMAL_USER_DIR"

var _checks: int = 0
var _failed: int = 0
var _sunrise_count: int = 0
var _daylight_args: Array[int] = []
var _save_completed_count: int = 0
var _save_failed_count: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if cond:
		print("CHECK OK: %s" % msg)
	else:
		_failed += 1
		print("TEST FAILURE: %s" % msg)
	return cond


func _log(tag: String, msg: String) -> void:
	print("STEP3A|%s|%s" % [tag, msg])


func _initialize() -> void:
	# Platform guard (fail-closed): the sandbox lifecycle depends on rm -rf
	# (see the isolation contract above), so any non-Linux platform must
	# refuse to run instead of continuing without isolation.
	if OS.get_name() != "Linux":
		# Round 2: an unsupported platform is an explicit, counted SKIP — not a
		# fake PASS and no longer a hard TEST FAILURE. Fail-closed is kept:
		# nothing below this guard runs without a proven sandbox, so no
		# directory, process or save operation is attempted on other platforms.
		# Exit code 2 + a "^SKIP:" line is the runner's skip contract.
		print("SKIP: N44 Step3 3A is Linux-only by design (isolated sandbox + rm-based cleanup); not executing on %s" % OS.get_name())
		quit(2)
		return
	if OS.get_environment(ENV_CHILD) == "1":
		await _run_isolated_flow(OS.get_environment(ENV_TMP), OS.get_environment(ENV_NORMAL))
	else:
		_run_parent_wrapper()


func _run_parent_wrapper() -> void:
	# PARENT: runs in whatever user data dir Godot resolved at startup, but
	# never performs game/save work here. Structural isolation comes from
	# re-executing this script as a child with a throwaway user data dir.
	# Capture the parent's real (startup) user data dir BEFORE touching the
	# environment: OS.get_user_data_dir() re-derives from HOME/XDG_DATA_HOME
	# on this build, so reading it after the set below would leak the temp
	# path into the "normal dir" marker and defeat the child's gate.
	var normal_user_dir: String = OS.get_user_data_dir()
	_log("PARENT", "normal user data dir (startup): %s" % normal_user_dir)
	var had_real_save: bool = FileAccess.file_exists(REAL_SAVE)
	var real_bytes: PackedByteArray = FileAccess.get_file_as_bytes(REAL_SAVE) if had_real_save else PackedByteArray()

	# --- Negative probe (fail-closed proof): a child that CLAIMS a bogus
	# temp base (a sibling-shaped path that was never created) must be
	# refused by the gate before any scene/save work. Its raw output is NOT
	# relayed — it contains the expected TEST FAILURE lines — so the parent
	# asserts the verdict and prints sanitized evidence instead.
	var probe_base: String = "%s%d_%d_probe" % [TEMP_BASE_PREFIX, OS.get_process_id(), Time.get_ticks_usec()]
	var bogus_claim: String = "%sbogus_%d_%d" % [TEMP_BASE_PREFIX, OS.get_process_id(), Time.get_ticks_usec()]
	# F2 (final audit) + F5 (audit round 3): the probe sandbox must be created
	# exclusively and canonicalize to itself. This is a fail-fast GATE, not a
	# merely recorded check: quit() does not stop this function in Godot 4, so
	# a recorded failure would still reach the spawn below and let the child
	# write startup artifacts into an unproven (possibly pre-existing or
	# symlinked) probe location. If the base is refused, NOTHING below runs:
	# no child, no probe, no real flow — and nothing this process did not
	# create is ever removed.
	if not _make_exclusive_base(probe_base):
		print("TEST FAILURE: N44 Step3 3A parent wrapper — probe base refused (non-exclusive or non-canonical: %s); no child spawned, no probe or real flow runs, refused location left untouched" % probe_base)
		quit(1)
		return
	_check(true, "probe: probe base created exclusively + canonically (readlink -m)")
	var probe_out: Array = []
	var probe_rc: int = _run_child_process(probe_base, bogus_claim, normal_user_dir, probe_out)
	# OS.execute (4.7.2) returns the WHOLE child output as a single element
	# with embedded newlines, so flatten and split before line matching.
	var probe_text: String = ""
	for raw in probe_out:
		probe_text += str(raw)
	var gate_fail_count: int = 0
	var leak_markers: int = 0
	var first_gate_msg: String = ""
	for probe_line_v in probe_text.split("\n"):
		var probe_line: String = String(probe_line_v)
		if probe_line.begins_with("TEST FAILURE: sandbox gate: "):
			gate_fail_count += 1
			if first_gate_msg == "":
				first_gate_msg = probe_line.trim_prefix("TEST FAILURE: ")
		if probe_line.contains("STEP3A|GATE|ok") or probe_line.contains("A-setup") or probe_line.contains("STEP3A|PAYLOAD"):
			leak_markers += 1
	_check(probe_rc == 1, "probe: bogus-sandbox child was refused with exit code 1 (rc=%d)" % probe_rc)
	_check(gate_fail_count >= 1 and leak_markers == 0,
		"probe: gate printed specific refusal(s) and NO gate-ok/scene/payload markers — execution stopped before change_scene_to_file")
	var probe_slot: String = probe_base.path_join("xdg/godot/app_userdata").path_join(String(normal_user_dir).get_file()).path_join("save_slot_0.json")
	_check(not FileAccess.file_exists(probe_slot), "probe: no autosave file exists anywhere under the refused sandbox (%s)" % probe_slot)
	if first_gate_msg != "":
		print("STEP3A|PROBE|evidence: %s" % first_gate_msg)
	_check(_rmrf_guarded(probe_base), "probe: probe sandbox removed")

	if _failed > 0:
		print("TEST FAILURE: N44 Step3 3A parent wrapper — sandbox gate is not fail-closed; aborting without the real flow")
		quit(1)
		return

	# --- Real isolated run: the child gets the SAME fresh base it claims,
	# so the gate must accept it and only then may the scene load. ---
	var temp_base: String = "%s%d_%d" % [TEMP_BASE_PREFIX, OS.get_process_id(), Time.get_ticks_usec()]
	# F5 (audit round 3): exclusive creation + canonical validation — a
	# pre-existing or planted entry is never reused, and a symlink anywhere
	# on the base path aborts the parent before the real child is spawned.
	if not _make_exclusive_base(temp_base):
		print("TEST FAILURE: N44 Step3 3A parent wrapper — real base refused (non-exclusive or non-canonical: %s)" % temp_base)
		quit(1)
		return
	_log("PARENT", "isolated child user-data base: %s" % temp_base)
	var child_out: Array = []
	var exit_code: int = _run_child_process(temp_base, temp_base, normal_user_dir, child_out)
	for line in child_out:
		print(str(line))
	if exit_code < 0:
		_check(false, "parent: isolated child could not be launched (rc=%d) — refusing to run the flow unsandboxed" % exit_code)
	else:
		_check(true, "parent: isolated child completed with exit code %d" % exit_code)

	# Parent-level proof that the developer's real autosave slot was never
	# touched: existence and byte content are checked SEPARATELY (audit round
	# 3, F4) — an absent slot must never be conflated with an empty one.
	var had_after_save: bool = FileAccess.file_exists(REAL_SAVE)
	var after_bytes: PackedByteArray = FileAccess.get_file_as_bytes(REAL_SAVE) if had_after_save else PackedByteArray()
	_check(had_real_save == had_after_save, "parent: real autosave slot EXISTENCE unchanged across the probe + isolated run")
	_check(real_bytes == after_bytes, "parent: real autosave slot byte-exact unchanged across the probe + isolated run (%s)" % ProjectSettings.globalize_path(REAL_SAVE))

	# Guarded cleanup: only the exact temp bases this run created. A plain
	# DirAccess walk is NOT enough here — Godot writes a $HOME/.cache
	# dot-directory for the child and list_dir_begin() hides dot-entries in
	# 4.7 — so the removal goes through rm -rf with a strict path guard
	# (self-generated absolute path under /tmp/step3a_iso_, "--" separator).
	_check(_rmrf_guarded(temp_base), "parent: temporary isolated user data removed")
	if DirAccess.dir_exists_absolute(temp_base):
		_log("LEFTOVERS", "temp base not fully removed; remaining entries:")
		_list_leftovers(temp_base, "  ")

	if _failed == 0 and exit_code == 0:
		quit(0)
	else:
		print("TEST FAILURE: N44 Step3 3A parent wrapper (child_exit=%d, parent_failures=%d)" % [exit_code, _failed])
		quit(1)


func _run_child_process(home_base: String, claimed_tmp: String, normal_dir: String, out: Array) -> int:
	# Spawns this script as a child whose HOME/XDG roots point at home_base
	# while the child is TOLD the sandbox is claimed_tmp. On the real run
	# both are the same freshly created base; the negative probe deliberately
	# claims a bogus sibling so the gate must refuse. Godot 4.7.2 has no
	# OS.execute_with_env, so the env is set on THIS process and restored
	# afterwards — the parent's own user:// resolution is cached at startup
	# and stays unaffected.
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
		"--script", "res://tests/test_n44_step3a_shrine_autosave.gd",
	], out, true)
	OS.set_environment("HOME", orig_home)
	OS.set_environment("XDG_DATA_HOME", orig_xdg)
	OS.set_environment("XDG_CACHE_HOME", orig_xdg_cache)
	OS.set_environment(ENV_CHILD, "")
	OS.set_environment(ENV_TMP, "")
	OS.set_environment(ENV_NORMAL, "")
	return exit_code


func _rmrf_guarded(target: String) -> bool:
	# Linux-only, strictly guarded removal of a self-generated temp base:
	# only absolute paths under this suite's own prefix are ever touched.
	if not target.is_absolute_path() or not target.begins_with(TEMP_BASE_PREFIX) or not DirAccess.dir_exists_absolute(target):
		return false
	var rm_out: Array = []
	var rm_rc: int = OS.execute("rm", ["-rf", "--", target], rm_out, false)
	return rm_rc == 0 and not DirAccess.dir_exists_absolute(target)


func _run_isolated_flow(temp_base: String, normal_user_dir: String) -> void:
	# CHILD: fail-closed sandbox gate. EVERY isolation condition is evaluated
	# here, before ANY scene, save or gameplay work. _check() is only a log
	# recorder and is never the gate: if any condition fails, the process
	# prints the specific reasons, quits with exit code 1 and returns —
	# change_scene_to_file() is never reached.
	var conditions: Array = _sandbox_conditions(temp_base, normal_user_dir)
	var problems: PackedStringArray = PackedStringArray()
	for cond in conditions:
		if not bool(cond[0]):
			problems.append(String(cond[1]))
	if not problems.is_empty():
		for p in problems:
			print("TEST FAILURE: sandbox gate: %s" % p)
		print("TEST FAILURE: N44 Step3 3A sandbox gate refused the run — no scene load, save read/write or gameplay work attempted")
		quit(1)
		return
	for cond in conditions:
		_check(true, String(cond[1]))
	print("STEP3A|GATE|ok — sandbox proven valid; proceeding to scene load")

	Engine.set_meta("crownfall_load_on_start", false)
	change_scene_to_file(SCENE)
	var s: ForgottenShoreSession = await _wait_session()
	if not _check(s != null, "A-setup: session A loads with a player"):
		_finish()
		return
	s.time_manager.auto_advance = false
	s.set_process(false)
	# Let the deferred initial-phase emission finish before counters attach.
	await process_frame
	await process_frame
	await process_frame
	s.time_manager.sunrise_reached.connect(func(_d: int) -> void: _sunrise_count += 1)
	s.time_manager.daylight_started.connect(func(d: int) -> void: _daylight_args.append(d))
	s.save_mgr.save_completed.connect(func(_p: String) -> void: _save_completed_count += 1)
	s.save_mgr.save_failed.connect(func(_r: String) -> void: _save_failed_count += 1)

	_check(s.time_manager.current_day == 1, "A-setup: fresh session is Day 1 (N-1)")

	# --- A4: no premature reset during the remainder of day N ---
	_teleport_shrine(s)
	s.economy.try_add(&"wood", 16)
	s.economy.try_add(&"stone", 8)
	var r1: Dictionary = s.execute_world_command("player_1", &"shrine_offering", "")
	_check(bool(r1.get("ok", false)), "A4: offering accepted on day 1")
	_check(s.shrine_offering_used_today, "A4: flag recorded as used on day 1")
	s.time_manager.current_phase = TimeManager.Phase.SUNSET
	_check(s.shrine_offering_used_today, "A4: flag survives the unrelated SUNSET transition")
	s.time_manager.current_phase = TimeManager.Phase.NIGHT
	_check(s.shrine_offering_used_today, "A4: flag survives the unrelated NIGHT transition")
	var r2: Dictionary = s.execute_world_command("player_1", &"shrine_offering", "")
	_check(not bool(r2.get("ok", false)) and s._last_rejection_reason.find("already used today") != -1,
		"A4: second offering on day N still rejected (flag not reset early)")
	_check(s.shrine_offering_used_today, "A4: flag still used immediately before sunrise")

	# --- A1 + A5: the real NIGHT -> DAYLIGHT transition and its autosave ---
	s.time_manager._transition_to_next_phase()
	await process_frame
	await process_frame

	var pay: Variant = JSON.parse_string(FileAccess.get_file_as_string(REAL_SAVE))
	var pay_dict: Dictionary = (pay as Dictionary) if typeof(pay) == TYPE_DICTIONARY else {}
	var pf: Dictionary = pay_dict.get("progression_flags", {}) as Dictionary
	_log("PAYLOAD", "day_count=%s world_phase=%s shrine_flag=%s" % [
		str(pay_dict.get("day_count")), str(pay_dict.get("world_phase")), str(pf.get("shrine_offering_used_today"))])
	_check(int(roundf(float(pay_dict.get("day_count", 0)))) == 2, "A1: autosave payload records day N+1 (2)")
	_check(String(pay_dict.get("world_phase", "")) == "daylight", "A1: autosave payload records the new-day daylight phase")
	_check(not bool(pf.get("shrine_offering_used_today", true)), "A1: autosave payload records offering flag FALSE (P0.1 fix)")

	# --- A5: exactly-once transition effects ---
	_check(_sunrise_count == 1, "A5: sunrise_reached emitted exactly once")
	_check(_daylight_args.size() == 1 and _daylight_args[0] == 2, "A5: daylight_started emitted exactly once with day 2")
	_check(_save_completed_count == 1, "A5: autosave completed exactly once")
	_check(_save_failed_count == 0, "A5: no autosave failures introduced")

	# --- A3: same-session day 2 behavior (must stay correct) ---
	_check(not s.shrine_offering_used_today, "A3: live session flag reset for day 2")
	s.economy.try_add(&"wood", 16)
	s.economy.try_add(&"stone", 8)
	var r3: Dictionary = s.execute_world_command("player_1", &"shrine_offering", "")
	_check(bool(r3.get("ok", false)), "A3: offering accepted on day 2 without quit/Continue")

	# --- A2: Continue path on the autosaved payload ---
	current_scene.queue_free()
	await process_frame
	await process_frame
	Engine.set_meta("crownfall_load_on_start", true)
	change_scene_to_file(SCENE)
	var s2: ForgottenShoreSession = await _wait_session()
	if _check(s2 != null, "A2: session B loads via Continue"):
		s2.time_manager.auto_advance = false
		s2.set_process(false)
		await process_frame
		await process_frame
		_check(s2.time_manager.current_day == 2, "A2: Continue restores day N+1 (2)")
		_check(not s2.shrine_offering_used_today, "A2: Continue restores offering flag FALSE (P0.1 fix)")
		_check(not s2.has_unsaved_progress(), "A2: Continue completed with no unsaved-progress drift")
		_teleport_shrine(s2)
		s2.economy.try_add(&"wood", 16)
		s2.economy.try_add(&"stone", 8)
		var r4: Dictionary = s2.execute_world_command("player_1", &"shrine_offering", "")
		_log("A2R", "ok=%s rejection=%s" % [str(r4.get("ok", false)), s2._last_rejection_reason])
		_check(bool(r4.get("ok", false)), "A2: offering available on day N+1 through the real Continue path")

	_finish()


func _sandbox_conditions(claimed_tmp: String, normal_dir: String) -> Array:
	# Pure evaluation of the sandbox gate — no _check() calls and no side
	# effects beyond the existence read of the autosave path (part of the
	# gate itself). Returns an Array of [ok: bool, msg: String]; the caller
	# turns any failure into a hard refusal before the scene load.
	var user_dir: String = OS.get_user_data_dir().simplify_path()
	var claimed_base: String = claimed_tmp.simplify_path()
	var slot_global: String = ProjectSettings.globalize_path(REAL_SAVE).simplify_path()
	var conditions: Array = []
	conditions.append([claimed_base != "" and claimed_base.is_absolute_path() and claimed_base.begins_with(TEMP_BASE_PREFIX),
		"iso: claimed temp base is a self-generated absolute step3a path (%s)" % claimed_base])
	conditions.append([normal_dir != "", "iso: normal user dir marker provided"])
	conditions.append([normal_dir != "" and user_dir != normal_dir.simplify_path(),
		"iso: process user data dir differs from the normal user data dir"])
	conditions.append([_is_descendant_of(user_dir, claimed_base),
		"iso: process user data dir is a TRUE descendant of the claimed temp base (%s)" % user_dir])
	conditions.append([_is_descendant_of(slot_global, claimed_base),
		"iso: autosave path is a TRUE descendant of the claimed temp base (%s)" % slot_global])
	conditions.append([_is_descendant_of(_canonicalize(user_dir), _canonicalize(claimed_base)),
		"iso: canonicalized user data dir is a TRUE descendant of the canonicalized temp base (symlink-proof)"])
	conditions.append([not FileAccess.file_exists(REAL_SAVE),
		"iso: sandbox starts with NO pre-existing autosave slot"])
	return conditions


func _is_descendant_of(child_path: String, base_path: String) -> bool:
	# True descendant containment, NOT a bare string prefix: both paths are
	# lexically normalized with String.simplify_path() (collapses "//",
	# "./" and "../" — Godot 4.7.2 API), then the base must match up to a
	# path-component boundary: child == base, or child starts with
	# base + "/". A bare begins_with(base) would wrongly accept
	# /tmp/step3a_iso_XY... as "inside" a base named /tmp/step3a_iso_X.
	# Empty and root bases are refused so a blank or oversized claim can
	# never contain anything. Audit round 3: the lexical test is now paired
	# with a canonicalized-path condition (_canonicalize via readlink -m), so
	# containment is also proven on the physical path, not only lexically.
	var child: String = child_path.simplify_path()
	var base: String = base_path.simplify_path()
	if base == "" or base == "/":
		return false
	if child == base:
		return true
	return child.begins_with(base + "/")


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


func _finish() -> void:
	# Courtesy cleanup inside the sandbox: the slot this flow created is
	# removed so the temp base is trivially removable; the parent also removes
	# the whole base afterwards. This is NOT the isolation mechanism.
	var now_exists: bool = FileAccess.file_exists(REAL_SAVE)
	if now_exists:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REAL_SAVE))
		_check(not FileAccess.file_exists(REAL_SAVE), "isolation: suite-created autosave slot removed")
	else:
		_check(true, "isolation: no autosave slot left behind")
	if _failed == 0:
		print("PASS: All %d checks — N44 Step3 3A Shrine Autosave Ordering" % _checks)
		quit(0)
	else:
		print("TEST FAILURE: N44 Step3 3A (%d of %d checks failed)" % [_failed, _checks])
		quit(1)


func _wait_session() -> ForgottenShoreSession:
	for _i: int in range(600):
		await process_frame
		if current_scene != null and String(current_scene.name) == "ForgottenShore":
			var s: ForgottenShoreSession = current_scene as ForgottenShoreSession
			if s != null and s.player != null:
				return s
	return null


func _teleport_shrine(s: ForgottenShoreSession) -> void:
	s.player.global_position.x = clampf(-780.0, s.player.min_bound_x, s.player.max_bound_x)
	s.set_actor_position("player_1", s.player.global_position.x)


func _list_leftovers(path: String, indent: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		print("%s<unreadable: %s>" % [indent, path])
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path.path_join(entry)
		if dir.current_is_dir():
			print("%s[DIR] %s" % [indent, full])
			_list_leftovers(full, indent + "  ")
		else:
			print("%s[FIL] %s" % [indent, full])
		entry = dir.get_next()
	dir.list_dir_end()
