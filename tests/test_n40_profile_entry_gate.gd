extends SceneTree

## N4.0 profile & entry gate tests: PlayerProfile fail-safe loading/atomic
## persistence, the New Game profile gate (no Skip on first playthrough;
## Play Again / Skip choice for returning players), Continue independence,
## fresh Forgotten Shore sessions, and the labelled Prologue route placeholder.
##
## ISOLATION CONTRACT (review fix): every fixture lives under user://n40_test/
## and is injected through the crownfall_profile_path / crownfall_menu_save_path
## Engine metas — including the ForgottenShoreSession pending-load consumption.
## The developer's real user://player_profile.json, user://save_slot_0.json and
## their sidecar files are NEVER written, deleted, or staged; they are only
## READ once for byte-exact non-mutation proof at the end of the run. Fixture
## sidecars (.tmp/.old/.bak/.bak.tmp) ARE cleaned before and after every run,
## so re-runs stay idempotent even after a previously killed run.

const MAIN_SCRIPT: GDScript = preload("res://scripts/core/Main.gd")
const PROLOGUE_SHELL_SCRIPT: GDScript = preload("res://scripts/narrative/PrologueShell.gd")
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const TEST_DIR: String = "user://n40_test"
const PROFILE_MISSING: String = "user://n40_test/profile_missing.json"
const PROFILE_FALSE: String = "user://n40_test/profile_false.json"
const PROFILE_TRUE: String = "user://n40_test/profile_true.json"
const PROFILE_MALFORMED: String = "user://n40_test/profile_malformed.json"
const PROFILE_NO_FIELD: String = "user://n40_test/profile_no_field.json"
const PROFILE_SCHEMA2: String = "user://n40_test/profile_schema2.json"
const PROFILE_UNREADABLE: String = "user://n40_test/profile_unreadable.json"
const PROFILE_WRITE_TARGET: String = "user://n40_test/profile_write_target.json"
const PROFILE_WRITE_BLOCKED: String = "user://n40_test/blocker_file/blocked.json"
const SAVE_NONE: String = "user://n40_test/save_none.json"
const SAVE_PREV: String = "user://n40_test/save_prev.json"
const SAVE_LEGACY: String = "user://n40_test/save_legacy.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _routes: Array[String] = []
var _real_profile_snapshot: String = ""
var _real_profile_existed: bool = false
var _real_save_snapshot: String = ""
var _real_save_existed: bool = false
## Sidecar snapshots (suffix -> {existed, content}): other suites and normal
## development may legitimately leave .tmp/.bak/.old beside the real save, so
## isolation is proven RELATIVELY — byte-identical before/after this suite —
## never by asserting global absence.
var _real_save_sidecars: Dictionary = {}
var _real_profile_sidecars: Dictionary = {}


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n40_profile_entry_gate] " + msg)
		quit(1)
		return false
	print("PASS: " + msg)
	return true


func _snapshot_sidecar(path: String) -> Dictionary:
	var existed: bool = FileAccess.file_exists(path)
	var content: String = FileAccess.get_file_as_string(path) if existed else ""
	return {"existed": existed, "content": content}


func _assert_sidecar_untouched(path: String, snap: Dictionary, label: String) -> void:
	var still_existed: bool = FileAccess.file_exists(path)
	var content_now: String = FileAccess.get_file_as_string(path) if still_existed else ""
	_check(bool((snap as Dictionary)["existed"]) == still_existed and content_now == String((snap as Dictionary)["content"]), "%s was never modified by this suite (existence and bytes unchanged)" % label)


func _write_json(path: String, payload: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "\t"))
		f.flush()
		f.close()


func _write_text(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.flush()
		f.close()


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Sidecar cleanup for fixture paths only (.tmp/.old = PlayerProfile staged
## write convention; .bak/.bak.tmp = SaveManager convention). A previously
## killed run can leave stale sidecars behind, which would make the leftover
## checks fail on re-run even though the implementation works — so they are
## cleaned before fixtures are (re)created and again after the run finishes.
## The real save/profile and THEIR sidecars are never touched here.
func _clean_fixture_sidecars() -> void:
	for path: String in [PROFILE_FALSE, PROFILE_TRUE, PROFILE_MALFORMED, PROFILE_NO_FIELD, PROFILE_SCHEMA2, PROFILE_WRITE_TARGET, SAVE_NONE, SAVE_PREV, SAVE_LEGACY]:
		for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
			_rm(path + suffix)


func _prepare_fixtures() -> void:
	# Fresh isolation dir on every run (idempotent, never touches real files).
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	for path: String in [PROFILE_FALSE, PROFILE_TRUE, PROFILE_MALFORMED, PROFILE_NO_FIELD, PROFILE_SCHEMA2, PROFILE_WRITE_TARGET, SAVE_NONE, SAVE_PREV, SAVE_LEGACY]:
		_rm(path)
	_clean_fixture_sidecars()
	_rm(PROFILE_UNREADABLE)
	_rm(PROFILE_WRITE_BLOCKED)
	if DirAccess.dir_exists_absolute(PROFILE_UNREADABLE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_UNREADABLE))
	if DirAccess.dir_exists_absolute(TEST_DIR + "/blocker_file"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR + "/blocker_file"))
	_write_json(PROFILE_FALSE, {"schema_version": 1, "prologue_completed_once": false})
	_write_json(PROFILE_TRUE, {"schema_version": 1, "prologue_completed_once": true})
	_write_text(PROFILE_MALFORMED, "{ this is not valid json !!")
	_write_json(PROFILE_NO_FIELD, {"schema_version": 1})
	_write_json(PROFILE_SCHEMA2, {"schema_version": 2, "prologue_completed_once": true})
	# Unreadable fixture: a DIRECTORY at the profile path (file reads fail).
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROFILE_UNREADABLE))
	# Write-failure fixture: a regular FILE where a parent directory is needed.
	_write_text(TEST_DIR + "/blocker_file", "not a directory")
	_write_json(SAVE_NONE, {})  # placeholder; removed again so the path stays missing
	_rm(SAVE_NONE)


func _valid_v2_save_payload() -> Dictionary:
	var payload: Dictionary = {
		"schema_version": 2, "world_id": "aetherion", "island_id": "forgotten_shore",
		"day_count": 2, "world_time": 10.0, "world_phase": "daylight",
		"resources": {"gold": 99, "wood": 99, "stone": 99},
		"buildings": [{"id": "wall_east_01", "type": "wooden_wall", "state": "COMPLETED", "durability": 150, "max_durability": 150}],
		"npcs": [{"id": "npc_01", "recruited": true, "role": "builder", "state": "IDLE", "position_x": 0.0}],
		"night_encounter": NightEncounterManager.new().to_save_dict(),
		"progression_flags": {"first_night_survived": true},
	}
	return payload


## SAFETY ASSERTION (review fix): every injection point is audited — the test
## must never resolve its save/profile target to the developer's real default
## paths. FAIL-CLOSED: if any assertion fails, the metas are NOT installed and
## the caller aborts without proceeding (the failed _check has already queued
## quit(1), so the run ends with exit code 1).
func _set_metas(profile_path: String, save_path: String) -> bool:
	if not _check(save_path != SaveManager.DEFAULT_SAVE_PATH and save_path.begins_with(TEST_DIR + "/"), "injected save path is isolated from the real player save (%s)" % save_path):
		return false
	if not _check(profile_path != PlayerProfile.DEFAULT_PROFILE_PATH and profile_path.begins_with(TEST_DIR + "/"), "injected profile path is isolated from the real player profile (%s)" % profile_path):
		return false
	Engine.set_meta("crownfall_profile_path", profile_path)
	Engine.set_meta("crownfall_menu_save_path", save_path)
	return true


func _attach_route_recorder() -> void:
	_routes.clear()
	var main_ctrl: Control = current_scene as Control
	main_ctrl.call("set_route_transition", func(scene_path: String) -> void: _routes.append(scene_path))


func _press(play_button: bool) -> void:
	var btn: String = "PlayButton" if play_button else "ContinueButton"
	var node: Button = current_scene.get_node_or_null("CenterContainer/VBoxContainer/" + btn) as Button
	if not _check(node != null, "%s exists on Main.tscn" % btn):
		return
	node.pressed.emit()


func _find_button(button_name: String) -> Button:
	return current_scene.find_child(button_name, true, false) as Button


func _on_main() -> bool:
	return current_scene != null and current_scene.name == "Main"


func _on_shore_ready() -> bool:
	if current_scene == null or current_scene.name != "ForgottenShore":
		return false
	var session: ForgottenShoreSession = current_scene as ForgottenShoreSession
	return session != null and session.time_manager != null


func _shore_session() -> ForgottenShoreSession:
	var session: ForgottenShoreSession = current_scene as ForgottenShoreSession
	session.time_manager.auto_advance = false
	return session


func _goto_main_next_stage(next_stage: int, profile_path: String, save_path: String) -> void:
	# Fail-closed: on a failed isolation assertion the metas are not installed
	# and the scene change never happens (quit(1) is already queued).
	if not _set_metas(profile_path, save_path):
		return
	_stage = next_stage
	_wait_frames = 0
	change_scene_to_file(MAIN_SCENE)


func _initialize() -> void:
	_prepare_fixtures()
	# Read-only byte snapshots of the developer's real files (if any) to prove
	# non-mutation at the end of the run. Nothing is ever written back.
	_real_profile_existed = FileAccess.file_exists("user://player_profile.json")
	if _real_profile_existed:
		_real_profile_snapshot = FileAccess.get_file_as_string("user://player_profile.json")
	_real_save_existed = FileAccess.file_exists(SaveManager.DEFAULT_SAVE_PATH)
	if _real_save_existed:
		_real_save_snapshot = FileAccess.get_file_as_string(SaveManager.DEFAULT_SAVE_PATH)
	for suffix: String in [".tmp", ".bak", ".old"]:
		_real_save_sidecars[suffix] = _snapshot_sidecar(SaveManager.DEFAULT_SAVE_PATH + suffix)
		_real_profile_sidecars[suffix] = _snapshot_sidecar("user://player_profile.json" + suffix)
	# Fail-closed: if the first isolation assertion fails, no metas are
	# installed, no scene loads, and the run ends with exit code 1.
	if not _set_metas(PROFILE_MISSING, SAVE_NONE):
		return
	_stage = 1
	change_scene_to_file(MAIN_SCENE)


func _process(_delta: float) -> bool:
	_wait_frames += 1
	if _wait_frames > MAX_WAIT_FRAMES:
		_check(false, "timed out at stage %d" % _stage)
		return true
	match _stage:
		1:
			if not _on_main():
				return false
			_attach_route_recorder()
			# --- Profile unit behavior (task tests 1-11) on injected paths ---
			var p: PlayerProfile = PlayerProfile.new()
			_check(p.set_profile_path(PROFILE_MISSING), "profile path injection accepted")
			p.load_profile(PROFILE_MISSING)
			_check(not p.is_prologue_completed_once(), "missing profile defaults to not completed")
			_check(bool(p.load_profile(PROFILE_MISSING).get("ok", false)), "missing profile is a normal first-run state, not a failure")
			var pf: PlayerProfile = PlayerProfile.new()
			pf.load_profile(PROFILE_FALSE)
			_check(not pf.is_prologue_completed_once(), "valid false profile loads as not completed")
			var pt: PlayerProfile = PlayerProfile.new()
			pt.load_profile(PROFILE_TRUE)
			_check(pt.is_prologue_completed_once(), "valid true profile loads as completed")
			var pm: PlayerProfile = PlayerProfile.new()
			pm.load_profile(PROFILE_MALFORMED)
			_check(not pm.is_prologue_completed_once() and not bool(pm.load_profile(PROFILE_MALFORMED).get("ok", false)), "malformed JSON defaults to not completed")
			var pn: PlayerProfile = PlayerProfile.new()
			pn.load_profile(PROFILE_NO_FIELD)
			_check(not pn.is_prologue_completed_once(), "missing required field defaults to not completed")
			var ps: PlayerProfile = PlayerProfile.new()
			ps.load_profile(PROFILE_SCHEMA2)
			_check(not ps.is_prologue_completed_once(), "unsupported schema version defaults to not completed")
			var pu: PlayerProfile = PlayerProfile.new()
			pu.load_profile(PROFILE_UNREADABLE)
			_check(not pu.is_prologue_completed_once(), "unreadable profile (directory at path) defaults to not completed")
			_check(PlayerProfile.new().load_profile("res://outside.json").get("ok", false) == false, "unsafe profile path rejected")
			var pc: PlayerProfile = PlayerProfile.new()
			pc.load_profile(PROFILE_MISSING)
			_check(pc.mark_prologue_completed(PROFILE_WRITE_TARGET), "successful completion writes the flag (atomic write reports success)")
			_check(pc.is_prologue_completed_once(), "successful write commits the in-memory completion state")
			var pc_check: PlayerProfile = PlayerProfile.new()
			pc_check.load_profile(PROFILE_WRITE_TARGET)
			_check(pc_check.is_prologue_completed_once(), "reloading after successful write preserves true")
			_check(not FileAccess.file_exists(PROFILE_WRITE_TARGET + ".tmp") and not FileAccess.file_exists(PROFILE_WRITE_TARGET + ".old"), "atomic write leaves no tmp/old leftovers")
			var pw: PlayerProfile = PlayerProfile.new()
			pw.load_profile(PROFILE_MISSING)
			_check(not pw.mark_prologue_completed(PROFILE_WRITE_BLOCKED), "failed atomic write reports failure (parent is a file)")
			_check(not pw.is_prologue_completed_once(), "failed write leaves the previous in-memory state untouched (false)")
			_check(not FileAccess.file_exists(PROFILE_WRITE_BLOCKED), "failed write does not report successful persistence: no file was written")
			var pw_check: PlayerProfile = PlayerProfile.new()
			pw_check.load_profile(PROFILE_WRITE_BLOCKED)
			_check(not pw_check.is_prologue_completed_once(), "failed write is treated as not persisted on reload")
			# --- Review fix: in-memory state commits only after persistence succeeds ---
			var pt_block: PlayerProfile = PlayerProfile.new()
			pt_block.load_profile(PROFILE_TRUE)
			_check(not pt_block.mark_prologue_completed(PROFILE_WRITE_BLOCKED), "failed write from a completed in-memory state returns false")
			_check(pt_block.is_prologue_completed_once(), "failed write preserves the previous in-memory state (true stays true)")
			var pf_block: PlayerProfile = PlayerProfile.new()
			_check(not pf_block.mark_prologue_completed(PROFILE_WRITE_BLOCKED), "failed write from a fresh instance returns false")
			_check(not pf_block.is_prologue_completed_once(), "failed write preserves the previous in-memory state (fresh instance stays false)")
			var pr_true: PlayerProfile = PlayerProfile.new()
			pr_true.load_profile(PROFILE_TRUE)
			_check(pr_true.is_prologue_completed_once(), "reload after failed writes still reflects the persisted state (true file)")
			var pr_false: PlayerProfile = PlayerProfile.new()
			pr_false.load_profile(PROFILE_FALSE)
			_check(not pr_false.is_prologue_completed_once(), "reload after failed writes still reflects the persisted state (false file)")
			_check(not pw_check.is_prologue_completed_once(), "invalid profile data is never silently converted to completed")
			_stage = 2
			_wait_frames = 0
			return false
		2:
			if _wait_frames < 2:
				return false
			# --- First-ever New Game (profile missing): no Skip, Prologue route ---
			_press(true)
			_stage = 3
			_wait_frames = 0
			return false
		3:
			if _wait_frames < 2:
				return false
			_check(_routes.size() == 1 and String(_routes[0]) == String(MAIN_SCRIPT.PROLOGUE_ROUTE_SCENE), "first-ever New Game routes to the Prologue entry contract")
			_check(_find_button("SkipPrologueButton") == null, "first-ever New Game does not offer Skip")
			_check(_find_button("ConfirmNewGameButton") == null, "first-ever New Game without a save shows no overwrite confirmation")
			_check(not Engine.has_meta("crownfall_load_on_start") or not bool(Engine.get_meta("crownfall_load_on_start")), "Prologue route clears the load-on-start flag")
			_press(true)  # repeated press: must not start a second transition
			_stage = 4
			_wait_frames = 0
			return false
		4:
			if _wait_frames < 2:
				return false
			_check(_routes.size() == 1, "repeated New Game presses trigger exactly one transition")
			# --- Corrupted profile must not block New Game (fail-safe route) ---
			_goto_main_next_stage(5, PROFILE_MALFORMED, SAVE_NONE)
			return false
		5:
			if not _on_main():
				return false
			_attach_route_recorder()
			_press(true)
			_stage = 6
			_wait_frames = 0
			return false
		6:
			if _wait_frames < 2:
				return false
			_check(_routes.size() == 1 and String(_routes[0]) == String(MAIN_SCRIPT.PROLOGUE_ROUTE_SCENE), "corrupted profile does not block New Game (fail-safe Prologue route)")
			# --- Returning player choice (profile completed) ---
			_goto_main_next_stage(7, PROFILE_TRUE, SAVE_NONE)
			return false
		7:
			if not _on_main():
				return false
			_attach_route_recorder()
			_press(true)
			_stage = 8
			_wait_frames = 0
			return false
		8:
			if _wait_frames < 2:
				return false
			var play_again: Button = _find_button("PlayPrologueAgainButton")
			var skip: Button = _find_button("SkipPrologueButton")
			_check(play_again != null and play_again.visible and skip != null and skip.visible, "returning player sees Play Prologue Again and Skip")
			var cancel_btn: Button = _find_button("CancelPrologueChoiceButton")
			if not _check(cancel_btn != null, "returning-player choice offers Cancel"):
				return true
			cancel_btn.pressed.emit()
			_stage = 9
			_wait_frames = 0
			return false
		9:
			if _wait_frames < 2:
				return false
			_check(_routes.is_empty(), "canceling the returning-player choice stays in the main menu")
			_press(true)
			_stage = 10
			_wait_frames = 0
			return false
		10:
			if _wait_frames < 2:
				return false
			var play_again2: Button = _find_button("PlayPrologueAgainButton")
			_check(play_again2 != null and play_again2.visible, "reopening the choice after cancel works")
			# Choose Play Prologue Again...
			play_again2.pressed.emit()
			_stage = 11
			_wait_frames = 0
			return false
		11:
			if _wait_frames < 2:
				return false
			_check(_routes.size() == 1 and String(_routes[0]) == String(MAIN_SCRIPT.PROLOGUE_ROUTE_SCENE), "Play Prologue Again routes to the Prologue entry contract")
			# ...then try Skip: the single-transition guard must reject it.
			var skip2: Button = _find_button("SkipPrologueButton")
			if not _check(skip2 != null, "choice buttons remain reachable for the double-transition check"):
				return true
			skip2.pressed.emit()
			_stage = 12
			_wait_frames = 0
			return false
		12:
			if _wait_frames < 2:
				return false
			_check(_routes.size() == 1, "switching Skip/Play Again after a route started never double-transitions")
			_check(not bool(Engine.get_meta("crownfall_load_on_start")), "Play Again route does not load the world save")
			# --- Overwrite confirmation compatibility + choice-cancel regression ---
			_goto_main_next_stage(13, PROFILE_TRUE, SAVE_PREV)
			return false
		13:
			if not _on_main():
				return false
			# Fresh Main instance (no injected recorder): real transitions happen.
			var save_mgr: SaveManager = SaveManager.new()
			_check(not save_mgr.has_valid_save(SAVE_PREV), "previous-world fixture not yet written (pre-check)")
			if not _check(save_mgr.save_state(_valid_v2_save_payload(), SAVE_PREV), "previous-world v2 save fixture written (day 2, gold 99)"):
				return true
			_press(true)
			_stage = 14
			_wait_frames = 0
			return false
		14:
			if _wait_frames < 2:
				return false
			var confirm_btn: Button = _find_button("ConfirmNewGameButton")
			_check(confirm_btn != null and confirm_btn.visible, "existing valid save still triggers the overwrite confirmation")
			var cancel_confirm: Button = _find_button("CancelNewGameButton")
			if not _check(cancel_confirm != null, "overwrite confirmation offers Cancel"):
				return true
			cancel_confirm.pressed.emit()
			_stage = 15
			_wait_frames = 0
			return false
		15:
			if _wait_frames < 2:
				return false
			_check(_on_main(), "canceling overwrite confirmation does not start a new game")
			_press(true)
			_stage = 16
			_wait_frames = 0
			return false
		16:
			if _wait_frames < 2:
				return false
			var confirm_btn2: Button = _find_button("ConfirmNewGameButton")
			if not _check(confirm_btn2 != null and confirm_btn2.visible, "confirmation reappears after cancel"):
				return true
			confirm_btn2.pressed.emit()
			_stage = 17
			_wait_frames = 0
			return false
		17:
			if _wait_frames < 2:
				return false
			var skip_btn0: Button = _find_button("SkipPrologueButton")
			var cancel_choice: Button = _find_button("CancelPrologueChoiceButton")
			if not _check(skip_btn0 != null and skip_btn0.visible and cancel_choice != null, "returning player with a valid save reaches the choice after confirmation"):
				return true
			# Review fix regression: cancel the CHOICE while a New Game was
			# already confirmed — the pending confirmation must be revoked.
			cancel_choice.pressed.emit()
			_stage = 18
			_wait_frames = 0
			return false
		18:
			if _wait_frames < 2:
				return false
			_check(_on_main(), "canceling the Prologue choice stays in the main menu")
			_check(SaveManager.new().has_valid_save(SAVE_PREV), "choice-cancel leaves the existing world save valid (never cleared)")
			_press(true)
			_stage = 19
			_wait_frames = 0
			return false
		19:
			if _wait_frames < 2:
				return false
			var confirm_btn3: Button = _find_button("ConfirmNewGameButton")
			if not _check(confirm_btn3 != null and confirm_btn3.visible, "review regression: overwrite confirmation runs again after choice-cancel (pending confirmation revoked)"):
				return true
			confirm_btn3.pressed.emit()
			_stage = 20
			_wait_frames = 0
			return false
		20:
			if _wait_frames < 2:
				return false
			var skip_btn2: Button = _find_button("SkipPrologueButton")
			if not _check(skip_btn2 != null and skip_btn2.visible, "choice reappears after the repeated confirmation"):
				return true
			skip_btn2.pressed.emit()
			_stage = 21
			_wait_frames = 0
			return false
		21:
			if not _on_shore_ready():
				return false
			var session: ForgottenShoreSession = _shore_session()
			_check(session.time_manager.current_day == 1, "Skip starts a fresh Forgotten Shore session (day 1, not the saved day 2)")
			_check(session.economy.get_amount(&"gold") == 2 and session.economy.get_amount(&"wood") == 2 and session.economy.get_amount(&"stone") == 1, "fresh session uses default ledger (previous gold 99 not consumed)")
			_check(not bool(Engine.get_meta("crownfall_load_on_start")), "Skip clears the load-on-start flag")
			var reloaded: Dictionary = SaveManager.new().load_state(SAVE_PREV)
			var data_ok: bool = bool(reloaded.get("ok", false)) and int((reloaded.get("data", {}) as Dictionary).get("day_count", 0)) == 2 and int(((reloaded.get("data", {}) as Dictionary).get("resources", {}) as Dictionary).get("gold", 0)) == 99
			_check(data_ok, "previous world save is intact after Skip (never loaded, deleted, or corrupted)")
			var prof_after: PlayerProfile = PlayerProfile.new()
			prof_after.load_profile(PROFILE_TRUE)
			_check(prof_after.is_prologue_completed_once(), "Skip does not modify the completion flag")
			# --- Continue independence (tests 21-23) ---
			_goto_main_next_stage(22, PROFILE_TRUE, SAVE_PREV)
			return false
		22:
			if not _on_main():
				return false
			var cont: Button = current_scene.get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button
			_check(cont != null and not cont.disabled, "Continue enabled with completed profile and valid save")
			_press(false)
			_stage = 23
			_wait_frames = 0
			return false
		23:
			if not _on_shore_ready():
				return false
			var session2: ForgottenShoreSession = _shore_session()
			_check(session2.time_manager.current_day == 2 and session2.economy.get_amount(&"gold") == 99, "Continue bypasses the Prologue and loads the injected world save (day 2, gold 99)")
			# --- Legacy v1 save via Continue (test 22) ---
			var legacy: Dictionary = (_valid_v2_save_payload()).duplicate(true)
			legacy["schema_version"] = 1
			legacy.erase("player")
			var pf_legacy: Dictionary = legacy["progression_flags"] as Dictionary
			pf_legacy.erase("first_night_survived")
			_write_json(SAVE_LEGACY, legacy)
			_goto_main_next_stage(24, PROFILE_TRUE, SAVE_LEGACY)
			return false
		24:
			if not _on_main():
				return false
			var cont2: Button = current_scene.get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button
			_check(cont2 != null and not cont2.disabled, "Continue enabled for a legacy v1 world save")
			_press(false)
			_stage = 25
			_wait_frames = 0
			return false
		25:
			if not _on_shore_ready():
				return false
			var session3: ForgottenShoreSession = _shore_session()
			_check(session3.time_manager.current_day == 2 and session3.economy.get_amount(&"gold") == 99, "Continue loads a valid legacy world save (schema v1 via migration)")
			# --- Corrupted profile must not disable Continue (test 23) ---
			_goto_main_next_stage(26, PROFILE_MALFORMED, SAVE_PREV)
			return false
		26:
			if not _on_main():
				return false
			var cont3: Button = current_scene.get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button
			_check(cont3 != null and not cont3.disabled, "corrupted profile does not disable Continue")
			_press(false)
			_stage = 27
			_wait_frames = 0
			return false
		27:
			if not _on_shore_ready():
				return false
			var session4: ForgottenShoreSession = _shore_session()
			_check(session4.time_manager.current_day == 2, "Continue works despite corrupted profile (loads day 2)")
			# --- Prologue route placeholder sanity (entry contract target) ---
			# Fail-closed: stop processing entirely if the assertion fails.
			if not _set_metas(PROFILE_FALSE, SAVE_NONE):
				return true
			_stage = 28
			_wait_frames = 0
			change_scene_to_file(String(MAIN_SCRIPT.PROLOGUE_ROUTE_SCENE))
			return false
		28:
			if current_scene == null or current_scene.name != "PrologueShell":
				return false
			_check(current_scene.name == "PrologueShell" and current_scene.get_script() == PROLOGUE_SHELL_SCRIPT, "Prologue route target is the labelled N4.0 placeholder shell")
			var ret_btn: Button = current_scene.find_child("ReturnToMenuButton", true, false) as Button
			_check(ret_btn != null, "placeholder shell cannot dead-end (Return to Main Menu exists)")
			var shell_prof: PlayerProfile = PlayerProfile.new()
			shell_prof.load_profile(PROFILE_FALSE)
			_check(not shell_prof.is_prologue_completed_once(), "placeholder shell does not mark Prologue completion")
			var false_text: String = FileAccess.get_file_as_string(PROFILE_FALSE)
			_check(false_text.contains("false"), "placeholder shell leaves the profile file untouched")
			if not _check(ret_btn != null, "return button available before press"):
				return true
			ret_btn.pressed.emit()
			_stage = 29
			_wait_frames = 0
			return false
		29:
			if not _on_main():
				return false
			_check(_on_main(), "placeholder shell returns to the main menu")
			# --- Hygiene: remove fixtures + their sidecars, then prove the real files untouched ---
			for path: String in [PROFILE_FALSE, PROFILE_TRUE, PROFILE_MALFORMED, PROFILE_NO_FIELD, PROFILE_SCHEMA2, PROFILE_WRITE_TARGET, SAVE_NONE, SAVE_PREV, SAVE_LEGACY]:
				_rm(path)
			_clean_fixture_sidecars()
			if DirAccess.dir_exists_absolute(PROFILE_UNREADABLE):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_UNREADABLE))
			_rm(TEST_DIR + "/blocker_file")
			if DirAccess.dir_exists_absolute(TEST_DIR + "/blocker_file"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR + "/blocker_file"))
			if DirAccess.dir_exists_absolute(TEST_DIR):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
			# Real player profile: byte-exact non-mutation proof (read-only).
			if _real_profile_existed:
				_check(FileAccess.get_file_as_string("user://player_profile.json") == _real_profile_snapshot, "developer's real user://player_profile.json was never mutated")
			else:
				_check(not FileAccess.file_exists("user://player_profile.json"), "suite never created the developer's real user://player_profile.json")
			_check(not FileAccess.file_exists("user://player_profile.json.tmp") and not FileAccess.file_exists("user://player_profile.json.old"), "no profile sidecar was created next to the real profile")
			# Real world save + sidecars: the suite never stages, writes, or
			# deletes them (review fix: Continue consumes the injected path).
			# Sidecars are proven byte-identical to their pre-run snapshots —
			# pre-existing sidecars from other suites or development are out
			# of this suite's control and are only proven unmodified.
			if _real_save_existed:
				_check(FileAccess.get_file_as_string(SaveManager.DEFAULT_SAVE_PATH) == _real_save_snapshot, "developer's real user://save_slot_0.json was never mutated")
			else:
				_check(not FileAccess.file_exists(SaveManager.DEFAULT_SAVE_PATH), "suite never created the developer's real user://save_slot_0.json")
			for suffix: String in [".tmp", ".bak", ".old"]:
				_assert_sidecar_untouched(SaveManager.DEFAULT_SAVE_PATH + suffix, _real_save_sidecars[suffix], "real save sidecar %s" % suffix)
			for suffix: String in [".tmp", ".old"]:
				_assert_sidecar_untouched("user://player_profile.json" + suffix, _real_profile_sidecars[suffix], "real profile sidecar %s" % suffix)
			if _failures == 0:
				print("PASS: All %d N4.0 Profile & Entry Gate checks completed with 0 failures." % _checks)
				quit(0)
			else:
				printerr("FAIL: N4.0 Profile & Entry Gate finished with %d failures out of %d checks." % [_failures, _checks])
				quit(1)
			return true
	return false
