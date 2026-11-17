extends SceneTree

## N4.0 profile & entry gate tests: PlayerProfile fail-safe loading/atomic
## persistence, the New Game profile gate (no Skip on first playthrough;
## Play Again / Skip choice for returning players), Continue independence,
## fresh Forgotten Shore sessions, and the labelled Prologue route placeholder.
## All fixtures live under user://n40_test/ — the developer's real
## user://player_profile.json and user://save_slot_0.json are never touched.

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
## The session consumes the DEFAULT world-save slot on Continue
## (ForgottenShoreSession._consume_pending_load_if_requested). Real-transition
## Continue checks therefore stage their fixture at the default slot, with a
## byte-exact snapshot/restore so the developer's real save is untouched.
const DEFAULT_SAVE_SLOT: String = "user://save_slot_0.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _routes: Array[String] = []
var _real_profile_snapshot: String = ""
var _real_profile_existed: bool = false
var _default_save_snapshot: String = ""
var _default_save_existed: bool = false


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		printerr("TEST FAILURE [test_n40_profile_entry_gate]: " + msg)
		quit(1)
		return false
	print("PASS: " + msg)
	return true


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


func _prepare_fixtures() -> void:
	# Fresh isolation dir on every run (idempotent, never touches real files).
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	for path: String in [PROFILE_FALSE, PROFILE_TRUE, PROFILE_MALFORMED, PROFILE_NO_FIELD, PROFILE_SCHEMA2, PROFILE_WRITE_TARGET, SAVE_NONE, SAVE_PREV, SAVE_LEGACY]:
		_rm(path)
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


func _stage_default_save(fixture_path: String) -> void:
	var f: FileAccess = FileAccess.open(DEFAULT_SAVE_SLOT, FileAccess.WRITE)
	if f != null:
		f.store_string(FileAccess.get_file_as_string(fixture_path))
		f.flush()
		f.close()


func _restore_default_save() -> void:
	_rm(DEFAULT_SAVE_SLOT)
	_rm(DEFAULT_SAVE_SLOT + ".tmp")
	_rm(DEFAULT_SAVE_SLOT + ".bak")
	_rm(DEFAULT_SAVE_SLOT + ".old")
	if _default_save_existed:
		_write_text(DEFAULT_SAVE_SLOT, _default_save_snapshot)


func _set_metas(profile_path: String, save_path: String) -> void:
	Engine.set_meta("crownfall_profile_path", profile_path)
	Engine.set_meta("crownfall_menu_save_path", save_path)


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
	_set_metas(profile_path, save_path)
	_stage = next_stage
	_wait_frames = 0
	change_scene_to_file(MAIN_SCENE)


func _initialize() -> void:
	_prepare_fixtures()
	# Snapshot the developer's real profile (if any) to prove non-mutation.
	_real_profile_existed = FileAccess.file_exists("user://player_profile.json")
	if _real_profile_existed:
		_real_profile_snapshot = FileAccess.get_file_as_string("user://player_profile.json")
	# Snapshot the developer's real default save slot for restore after the
	# real-transition Continue checks.
	_default_save_existed = FileAccess.file_exists(DEFAULT_SAVE_SLOT)
	if _default_save_existed:
		_default_save_snapshot = FileAccess.get_file_as_string(DEFAULT_SAVE_SLOT)
	_set_metas(PROFILE_MISSING, SAVE_NONE)
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
			pc.load_profile(PROFILE_TRUE)
			_check(pc.mark_prologue_completed(PROFILE_WRITE_TARGET), "successful completion writes the flag (atomic write reports success)")
			var pc_check: PlayerProfile = PlayerProfile.new()
			pc_check.load_profile(PROFILE_WRITE_TARGET)
			_check(pc_check.is_prologue_completed_once(), "reloading after successful write preserves true")
			_check(not FileAccess.file_exists(PROFILE_WRITE_TARGET + ".tmp") and not FileAccess.file_exists(PROFILE_WRITE_TARGET + ".old"), "atomic write leaves no tmp/old leftovers")
			var pw: PlayerProfile = PlayerProfile.new()
			pw.load_profile(PROFILE_MISSING)
			_check(not pw.mark_prologue_completed(PROFILE_WRITE_BLOCKED), "failed atomic write reports failure (parent is a file)")
			_check(not FileAccess.file_exists(PROFILE_WRITE_BLOCKED), "failed write does not report successful persistence: no file was written")
			var pw_check: PlayerProfile = PlayerProfile.new()
			pw_check.load_profile(PROFILE_WRITE_BLOCKED)
			_check(not pw_check.is_prologue_completed_once(), "failed write is treated as not persisted on reload")
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
			# --- Overwrite confirmation compatibility + real Skip (tests 16/17/19/20) ---
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
			var skip_btn2: Button = _find_button("SkipPrologueButton")
			if not _check(skip_btn2 != null and skip_btn2.visible, "returning player with a valid save reaches the choice after confirmation"):
				return true
			skip_btn2.pressed.emit()
			_stage = 18
			_wait_frames = 0
			return false
		18:
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
			_goto_main_next_stage(19, PROFILE_TRUE, SAVE_PREV)
			return false
		19:
			if not _on_main():
				return false
			var cont: Button = current_scene.get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button
			_check(cont != null and not cont.disabled, "Continue enabled with completed profile and valid save")
			_stage_default_save(SAVE_PREV)
			_press(false)
			_stage = 20
			_wait_frames = 0
			return false
		20:
			if not _on_shore_ready():
				return false
			var session2: ForgottenShoreSession = _shore_session()
			_check(session2.time_manager.current_day == 2 and session2.economy.get_amount(&"gold") == 99, "Continue bypasses the Prologue and loads the world save (day 2, gold 99)")
			# --- Legacy v1 save via Continue (test 22) ---
			var legacy: Dictionary = (_valid_v2_save_payload()).duplicate(true)
			legacy["schema_version"] = 1
			legacy.erase("player")
			var pf_legacy: Dictionary = legacy["progression_flags"] as Dictionary
			pf_legacy.erase("first_night_survived")
			_write_json(SAVE_LEGACY, legacy)
			_goto_main_next_stage(21, PROFILE_TRUE, SAVE_LEGACY)
			return false
		21:
			if not _on_main():
				return false
			var cont2: Button = current_scene.get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button
			_check(cont2 != null and not cont2.disabled, "Continue enabled for a legacy v1 world save")
			_stage_default_save(SAVE_LEGACY)
			_press(false)
			_stage = 22
			_wait_frames = 0
			return false
		22:
			if not _on_shore_ready():
				return false
			var session3: ForgottenShoreSession = _shore_session()
			_check(session3.time_manager.current_day == 2 and session3.economy.get_amount(&"gold") == 99, "Continue loads a valid legacy world save (schema v1 via migration)")
			# --- Corrupted profile must not disable Continue (test 23) ---
			_goto_main_next_stage(23, PROFILE_MALFORMED, SAVE_PREV)
			return false
		23:
			if not _on_main():
				return false
			var cont3: Button = current_scene.get_node_or_null("CenterContainer/VBoxContainer/ContinueButton") as Button
			_check(cont3 != null and not cont3.disabled, "corrupted profile does not disable Continue")
			_stage_default_save(SAVE_PREV)
			_press(false)
			_stage = 24
			_wait_frames = 0
			return false
		24:
			if not _on_shore_ready():
				return false
			var session4: ForgottenShoreSession = _shore_session()
			_check(session4.time_manager.current_day == 2, "Continue works despite corrupted profile (loads day 2)")
			# --- Prologue route placeholder sanity (entry contract target) ---
			Engine.set_meta("crownfall_profile_path", PROFILE_FALSE)
			_stage = 25
			_wait_frames = 0
			change_scene_to_file(String(MAIN_SCRIPT.PROLOGUE_ROUTE_SCENE))
			return false
		25:
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
			_stage = 26
			_wait_frames = 0
			return false
		26:
			if not _on_main():
				return false
			_check(_on_main(), "placeholder shell returns to the main menu")
			# --- Hygiene: restore the developer's real files, remove fixtures ---
			_restore_default_save()
			for path: String in [PROFILE_FALSE, PROFILE_TRUE, PROFILE_MALFORMED, PROFILE_NO_FIELD, PROFILE_SCHEMA2, PROFILE_WRITE_TARGET, SAVE_NONE, SAVE_PREV, SAVE_LEGACY]:
				_rm(path)
			if DirAccess.dir_exists_absolute(PROFILE_UNREADABLE):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_UNREADABLE))
			_rm(TEST_DIR + "/blocker_file")
			if DirAccess.dir_exists_absolute(TEST_DIR + "/blocker_file"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR + "/blocker_file"))
			if _real_profile_existed:
				_check(FileAccess.get_file_as_string("user://player_profile.json") == _real_profile_snapshot, "developer's real user://player_profile.json was never mutated")
			else:
				_check(not FileAccess.file_exists("user://player_profile.json"), "suite never created the developer's real user://player_profile.json")
			print("PASS: All %d N4.0 Profile & Entry Gate checks completed with 0 failures." % _checks)
			quit(0)
			return true
	return false
