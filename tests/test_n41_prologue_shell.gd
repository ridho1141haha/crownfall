extends SceneTree

## N4.1 Prologue shell tests: scene lifecycle, runtime ownership, allowlisted
## sequence plumbing, controlled exit/handoff guards, and the N4.0 entry-gate
## routing contract the shell must preserve.
##
## ISOLATION CONTRACT (same style as test_n40_profile_entry_gate): every
## fixture lives under user://n41_test/ and is injected through the
## crownfall_profile_path / crownfall_menu_save_path Engine metas. The
## developer's real user://player_profile.json, user://save_slot_0.json and
## their sidecars are only READ once for byte-exact non-mutation proof at the
## end of the run; fixture sidecars (.tmp/.old/.bak/.bak.tmp) are cleaned
## before and after the run so re-runs stay idempotent.
##
## The test sequences below (n41_shell_smoke / n41_shell_cancel_check /
## n41_shell_handoff / n41_shell_dev_exit_check) are explicit non-canon
## plumbing fixtures — they are NOT Prologue story content.

const MAIN_SCRIPT: GDScript = preload("res://scripts/core/Main.gd")
const PROLOGUE_SHELL_SCRIPT: GDScript = preload("res://scripts/narrative/PrologueShell.gd")
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const PROLOGUE_SHELL_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const TEST_DIR: String = "user://n41_test"
const PROFILE_MISSING: String = "user://n41_test/profile_missing.json"
const PROFILE_FALSE: String = "user://n41_test/profile_false.json"
const PROFILE_TRUE: String = "user://n41_test/profile_true.json"
const SAVE_NONE: String = "user://n41_test/save_none.json"
const SAVE_PREV: String = "user://n41_test/save_prev.json"
const REAL_PROFILE_PATH: String = "user://player_profile.json"
const MAX_WAIT_FRAMES: int = 600

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _routes: Array[String] = []
var _shell_exits: Array[String] = []
## sequence_completed observations for the handoff regression (P1 proof).
var _handoff_completions: Array[String] = []
var _real_profile_snapshot: String = ""
var _real_profile_existed: bool = false
var _real_save_snapshot: String = ""
var _real_save_existed: bool = false
var _real_save_sidecars: Dictionary = {}
var _real_profile_sidecars: Dictionary = {}


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n41_prologue_shell] " + msg)
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


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _clean_fixture_sidecars() -> void:
	for path: String in [PROFILE_FALSE, PROFILE_TRUE, SAVE_NONE, SAVE_PREV]:
		for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
			_rm(path + suffix)


func _prepare_fixtures() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	for path: String in [PROFILE_FALSE, PROFILE_TRUE, SAVE_NONE, SAVE_PREV]:
		_rm(path)
	_clean_fixture_sidecars()
	_write_json(PROFILE_FALSE, {"schema_version": 1, "prologue_completed_once": false})
	_write_json(PROFILE_TRUE, {"schema_version": 1, "prologue_completed_once": true})
	_write_json(SAVE_PREV, _valid_v2_save_payload())
	# SAVE_NONE is written as a placeholder and removed again so the path stays
	# missing (same convention as the N4.0 suite).
	_write_json(SAVE_NONE, {})
	_rm(SAVE_NONE)


func _valid_v2_save_payload() -> Dictionary:
	return {
		"schema_version": 2, "world_id": "aetherion", "island_id": "forgotten_shore",
		"day_count": 2, "world_time": 10.0, "world_phase": "daylight",
		"resources": {"gold": 99, "wood": 99, "stone": 99},
		"buildings": [{"id": "wall_east_01", "type": "wooden_wall", "state": "COMPLETED", "durability": 150, "max_durability": 150}],
		"npcs": [{"id": "npc_01", "recruited": true, "role": "builder", "state": "IDLE", "position_x": 0.0}],
		"night_encounter": NightEncounterManager.new().to_save_dict(),
		"progression_flags": {"first_night_survived": true},
	}


func _set_metas(profile_path: String, save_path: String) -> bool:
	# FAIL-CLOSED isolation assertion: never install metas for unsafe paths.
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


func _on_shell() -> bool:
	if current_scene == null or current_scene.name != "PrologueShell":
		return false
	return current_scene.get_script() == PROLOGUE_SHELL_SCRIPT


func _on_shore_ready() -> bool:
	if current_scene == null or current_scene.name != "ForgottenShore":
		return false
	var session: ForgottenShoreSession = current_scene as ForgottenShoreSession
	return session != null and session.time_manager != null


func _shell() -> Control:
	return current_scene as Control


func _shell_smoke_sequence() -> Dictionary:
	# Non-canon plumbing fixture (NOT a Prologue beat).
	return {
		"id": "n41_shell_smoke",
		"steps": [
			{"op": "dialogue", "lines": [{"speaker": "Development Shell", "text": "N4.1 shell sequence plumbing check."}]},
			{"op": "finish"},
		],
	}


func _shell_cancel_sequence() -> Dictionary:
	# Non-canon plumbing fixture (NOT a Prologue beat).
	return {
		"id": "n41_shell_cancel_check",
		"steps": [
			{"op": "dialogue", "lines": [{"speaker": "Development Shell", "text": "N4.1 shell cancel-path plumbing check."}]},
			{"op": "finish"},
		],
	}


func _shell_handoff_sequence() -> Dictionary:
	# Non-canon plumbing fixture (NOT a Prologue beat): mimics the future N4.5
	# handoff — a sequence whose change_scene op transitions through the
	# shell's own scene-transition callback into the allowlisted shore scene.
	return {
		"id": "n41_shell_handoff",
		"steps": [
			{"op": "change_scene", "scene_path": FORGOTTEN_SHORE_SCENE},
			{"op": "finish"},
		],
	}


func _shell_dev_exit_sequence() -> Dictionary:
	# Non-canon plumbing fixture (NOT a Prologue beat): left un-advanced so the
	# development exit fires while a sequence is still running.
	return {
		"id": "n41_shell_dev_exit_check",
		"steps": [
			{"op": "dialogue", "lines": [{"speaker": "Development Shell", "text": "N4.1 shell development-exit plumbing check."}]},
			{"op": "finish"},
		],
	}


func _fixture_completions_untouched() -> void:
	# Entering/exiting/running the shell must never create or change a profile
	# file: the missing fixture stays missing, and PROFILE_FALSE stays false
	# byte-exactly (test 8 + test 9 of the task contract).
	_check(not FileAccess.file_exists(PROFILE_MISSING), "missing profile fixture stays missing after shell lifecycle use")
	_check(FileAccess.get_file_as_string(PROFILE_FALSE) == JSON.stringify({"schema_version": 1, "prologue_completed_once": false}, "\t"), "PROFILE_FALSE fixture is byte-exact unchanged after shell lifecycle use")


func _initialize() -> void:
	_prepare_fixtures()
	# Read-only byte snapshots of the developer's real files (if any) to prove
	# non-mutation at the end of the run. Nothing is ever written back.
	_real_profile_existed = FileAccess.file_exists(REAL_PROFILE_PATH)
	if _real_profile_existed:
		_real_profile_snapshot = FileAccess.get_file_as_string(REAL_PROFILE_PATH)
	_real_save_existed = FileAccess.file_exists(SaveManager.DEFAULT_SAVE_PATH)
	if _real_save_existed:
		_real_save_snapshot = FileAccess.get_file_as_string(SaveManager.DEFAULT_SAVE_PATH)
	for suffix: String in [".tmp", ".bak", ".old"]:
		_real_save_sidecars[suffix] = _snapshot_sidecar(SaveManager.DEFAULT_SAVE_PATH + suffix)
	for suffix: String in [".tmp", ".old"]:
		_real_profile_sidecars[suffix] = _snapshot_sidecar(REAL_PROFILE_PATH + suffix)
	if not _set_metas(PROFILE_MISSING, SAVE_NONE):
		return
	# N4.2: the shell now auto-plays the authored opening beat by default;
	# this suite exercises the shell's lifecycle semantics on an idle
	# instance (the auto-start flow is covered by test_n42_prologue_beats.gd).
	Engine.set_meta("crownfall_prologue_autostart", false)
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
			# --- Test 3: first-ever New Game routes to the Prologue shell ---
			_press(true)
			_check(_routes.size() == 1 and String(_routes[0]) == String(MAIN_SCRIPT.PROLOGUE_ROUTE_SCENE), "first-ever New Game routes to the Prologue shell")
			_check(bool(Engine.get_meta("crownfall_load_on_start", true)) == false, "Prologue route clears the load-on-start flag (never consumes a world save)")
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 2
			_wait_frames = 0
			return false
		2:
			if not _on_shell():
				return false
			# --- Test 1: scene loads and instantiates as the shell ---
			var shell: Control = _shell()
			_check(shell.get_script() == PROLOGUE_SHELL_SCRIPT, "PrologueShell scene instantiates with the N4.1 shell script")
			_check(shell.name == "PrologueShell", "shell root node is named PrologueShell")
			# --- Test 2: required runtime components initialize correctly ---
			_check(shell.call("is_initialized"), "shell runtime is initialized on scene-ready")
			var state: NarrativeState = shell.call("narrative_state")
			var panel: DialoguePanel = shell.call("dialogue_panel")
			var runner: SequenceRunner = shell.call("sequence_runner")
			_check(state != null and panel != null and runner != null, "shell owns its NarrativeState, DialoguePanel, and SequenceRunner")
			_check(shell.is_ancestor_of(panel) and shell.is_ancestor_of(runner), "panel and runner are children of the shell (single owner)")
			_check(not shell.call("is_sequence_running") and shell.call("completed_sequence_count") == 0 and not panel.is_open(), "fresh shell starts idle: no running sequence, no completions, closed panel")
			# Duplicate initialization is an idempotent no-op.
			var first_panel: DialoguePanel = panel
			_check(shell.call("_initialize_runtime") == false, "duplicate runtime initialization is rejected as a no-op")
			_check(shell.call("dialogue_panel") == first_panel, "duplicate initialization keeps the same panel instance (no double build)")
			# Non-canon sequence payloads pass fail-closed validation via the shell API.
			_check(NarrativeData.validate_sequence(_shell_smoke_sequence()), "shell smoke sequence passes NarrativeData validation")
			_stage = 3
			_wait_frames = 0
			return false
		3:
			if not _on_shell():
				return false
			# --- Reusable text-only sequence presentation (N4.1 deliverable) ---
			var shell: Control = _shell()
			_check(shell.call("play_sequence", _shell_smoke_sequence()), "shell starts a validated text-only sequence through the N3 runner")
			_check(shell.call("is_sequence_running"), "sequence is running inside the shell")
			var panel: DialoguePanel = shell.call("dialogue_panel")
			_check(panel.is_open(), "dialogue panel opens for the dialogue step (input isolation surface active)")
			_check(panel.get_speaker_text() == "Development Shell" and panel.get_body_text().contains("plumbing check"), "panel presents the speaker and body text")
			panel.advance()
			_check(not panel.is_open() and not shell.call("is_sequence_running"), "advancing past the last line closes the panel and completes the run")
			_check(shell.call("completed_sequence_count") == 1 and bool((shell.call("narrative_state") as NarrativeState).is_completed("n41_shell_smoke")), "per-run NarrativeState records exactly one completion")
			_stage = 4
			_wait_frames = 0
			return false
		4:
			if not _on_shell():
				return false
			# --- Cancel path: aborts without completion (cleanup only) ---
			var shell: Control = _shell()
			_check(shell.call("play_sequence", _shell_cancel_sequence()), "shell starts the second sequence for the cancel-path check")
			shell.call("cancel_sequence")
			_check(not shell.call("is_sequence_running"), "cancel stops the running sequence")
			_check(shell.call("completed_sequence_count") == 1, "cancel completes nothing (completion count unchanged)")
			_check(not (shell.call("dialogue_panel") as DialoguePanel).is_open(), "cancel closes the dialogue panel")
			_stage = 5
			_wait_frames = 0
			return false
		5:
			if not _on_shell():
				return false
			# --- P1 regression: sequence-driven handoff must complete exactly once ---
			# A sequence whose change_scene op transitions through the shell's own
			# callback (PrologueShell._on_sequence_scene_transition) must NOT be
			# cancelled: the runner is inside its change_scene step and must still
			# run _finalize_completion (sequence_completed + NarrativeState).
			var shell: Control = _shell()
			_shell_exits.clear()
			_handoff_completions.clear()
			shell.call("set_exit_transition", func(scene_path: String) -> void: _shell_exits.append(scene_path))
			var runner: SequenceRunner = shell.call("sequence_runner")
			runner.sequence_completed.connect(func(sequence_id: String) -> void: _handoff_completions.append(sequence_id))
			_check(shell.call("play_sequence", _shell_handoff_sequence()), "shell accepts a sequence whose change_scene targets the allowlisted Forgotten Shore")
			_check(_shell_exits.size() == 1 and String(_shell_exits[0]) == FORGOTTEN_SHORE_SCENE, "sequence change_scene invokes the shell handoff exactly once with the allowlisted scene")
			_check(_handoff_completions.size() == 1 and String(_handoff_completions[0]) == "n41_shell_handoff", "sequence_completed is emitted exactly once for the handoff sequence")
			_check(bool((shell.call("narrative_state") as NarrativeState).is_completed("n41_shell_handoff")) and shell.call("completed_sequence_count") == 2, "NarrativeState records the handoff sequence completion (smoke + handoff; cancel and dev exit never add)")
			_check(not shell.call("is_sequence_running") and not (shell.call("dialogue_panel") as DialoguePanel).is_open(), "after handoff: runner idle, panel closed, control restored")
			# --- Duplicate handoff must not produce a second transition ---
			shell.call("_on_sequence_scene_transition", FORGOTTEN_SHORE_SCENE)
			_check(_shell_exits.size() == 1, "duplicate sequence handoff request is ignored (no second transition)")
			_fixture_completions_untouched()
			# The handoff armed this instance's exit guard, so the dev-exit-while-
			# running scenario runs on a FRESH shell instance (next stage).
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 6
			_wait_frames = 0
			return false
		6:
			if not _on_shell():
				return false
			# --- Development exit while a sequence runs: cancel WITHOUT completion ---
			var shell: Control = _shell()
			_shell_exits.clear()
			_handoff_completions.clear()
			# A fresh instance starts with no injected transition — install the
			# exit recorder on THIS shell so the dev exit stays observable.
			shell.call("set_exit_transition", func(scene_path: String) -> void: _shell_exits.append(scene_path))
			var runner2: SequenceRunner = shell.call("sequence_runner")
			runner2.sequence_completed.connect(func(sequence_id: String) -> void: _handoff_completions.append(sequence_id))
			_check(shell.call("play_sequence", _shell_dev_exit_sequence()), "shell starts a dialogue sequence before the development exit")
			_check(shell.call("is_sequence_running"), "sequence is still running when the development exit fires")
			_check(shell.call("request_main_menu_return"), "development exit is accepted while a sequence runs")
			_check(not shell.call("is_sequence_running"), "development exit stops the running sequence")
			_check(_handoff_completions.is_empty(), "development exit completes nothing (sequence_completed never emitted)")
			_check(_shell_exits.size() == 1 and String(_shell_exits[0]) == "res://scenes/main/Main.tscn", "development exit transitions to the main menu exactly once")
			_check(not (shell.call("dialogue_panel") as DialoguePanel).is_open(), "development exit closes the dialogue panel")
			_fixture_completions_untouched()
			_stage = 7
			_wait_frames = 0
			return false
		7:
			if not _on_shell():
				return false
			# --- Duplicate exit guard + no stale runtime state + fresh instance ---
			var shell: Control = _shell()
			_check(shell.call("is_exit_started"), "shell records that its exit has started")
			_check(shell.call("request_main_menu_return") == false and _shell_exits.size() == 1, "duplicate exit request is ignored (no second transition)")
			# The development-only button routes through the same guarded path.
			var dev_btn: Button = shell.find_child("DevExitButton", true, false) as Button
			_check(dev_btn != null and dev_btn.text.contains("Development"), "development-only exit button exists and is labelled as such")
			dev_btn.pressed.emit()
			_check(_shell_exits.size() == 1, "development exit after a started exit is also ignored")
			_check(not shell.call("is_sequence_running") and not (shell.call("dialogue_panel") as DialoguePanel).is_open(), "after exit: no running sequence and closed panel")
			var runner: SequenceRunner = shell.call("sequence_runner")
			_check(runner != null and not runner.is_running(), "sequence runner is idle after exit")
			# A fresh instance starts clean (runtime state dies with the scene).
			var second: Control = (load(PROLOGUE_SHELL_SCENE) as PackedScene).instantiate() as Control
			get_root().add_child(second)
			_check(second.call("is_initialized") and second.call("completed_sequence_count") == 0 and not second.call("is_exit_started"), "a fresh shell instance starts with clean runtime state")
			get_root().remove_child(second)
			second.free()
			change_scene_to_file(MAIN_SCENE)
			_stage = 8
			_wait_frames = 0
			return false
		8:
			if not _on_main():
				return false
			# --- Returning-player routing (N4.0 contract preserved) ---
			if not _set_metas(PROFILE_TRUE, SAVE_PREV):
				return true
			_attach_route_recorder()
			_press(true)
			var confirm: Button = _find_button("ConfirmNewGameButton")
			_check(confirm != null and confirm.is_visible_in_tree(), "overwrite confirmation is still shown for a valid world save")
			if confirm == null:
				return true
			confirm.pressed.emit()
			var play_again: Button = _find_button("PlayPrologueAgainButton")
			_check(play_again != null and play_again.is_visible_in_tree(), "completed profile offers the Play Prologue Again choice")
			if play_again == null:
				return true
			play_again.pressed.emit()
			_check(_routes.size() == 1 and String(_routes[0]) == String(MAIN_SCRIPT.PROLOGUE_ROUTE_SCENE), "Play Prologue Again routes to the Prologue shell")
			_set_metas(PROFILE_TRUE, SAVE_PREV)
			change_scene_to_file(MAIN_SCENE)
			_stage = 9
			_wait_frames = 0
			return false
		9:
			if not _on_main():
				return false
			_attach_route_recorder()
			_press(true)
			var confirm2: Button = _find_button("ConfirmNewGameButton")
			if not _check(confirm2 != null, "overwrite confirmation appears again for the Skip scenario"):
				return true
			confirm2.pressed.emit()
			var skip: Button = _find_button("SkipPrologueButton")
			_check(skip != null and skip.is_visible_in_tree(), "Skip Prologue is offered to a returning player")
			if skip == null:
				return true
			skip.pressed.emit()
			_check(_routes.size() == 1 and String(_routes[0]) == FORGOTTEN_SHORE_SCENE, "Skip Prologue routes to a fresh Forgotten Shore session")
			_check(bool(Engine.get_meta("crownfall_load_on_start", true)) == false, "Skip clears the load-on-start flag (fresh session, no save consumed)")
			# --- Skip must never mark or revoke the completion flag ---
			var after: PlayerProfile = PlayerProfile.new()
			after.load_profile(PROFILE_TRUE)
			_check(after.is_prologue_completed_once(), "Skip does not revoke the recorded completion")
			_check(FileAccess.get_file_as_string(PROFILE_TRUE) == JSON.stringify({"schema_version": 1, "prologue_completed_once": true}, "\t"), "profile fixture is byte-exact unchanged after Skip")
			_set_metas(PROFILE_TRUE, SAVE_PREV)
			change_scene_to_file(MAIN_SCENE)
			_stage = 10
			_wait_frames = 0
			return false
		10:
			if not _on_main():
				return false
			_attach_route_recorder()
			# --- Test 6: Cancel preserves the existing menu flow (N4.0 contract) ---
			_press(true)
			var confirm3: Button = _find_button("ConfirmNewGameButton")
			if not _check(confirm3 != null, "overwrite confirmation appears for the Cancel scenario"):
				return true
			confirm3.pressed.emit()
			var cancel: Button = _find_button("CancelPrologueChoiceButton")
			_check(cancel != null and cancel.is_visible_in_tree(), "Cancel is offered on the returning-player choice")
			if cancel == null:
				return true
			cancel.pressed.emit()
			_check(_routes.is_empty() and _on_main(), "Cancel stays in the main menu (no route, no scene change)")
			_check(not (cancel.get_parent() as Control).get_parent().is_visible_in_tree(), "choice overlay is hidden after Cancel")
			_press(true)
			var confirm_again: Button = _find_button("ConfirmNewGameButton")
			_check(confirm_again != null and confirm_again.is_visible_in_tree(), "next Play press re-runs the overwrite confirmation (Cancel revokes the pending confirmation)")
			_set_metas(PROFILE_TRUE, SAVE_PREV)
			change_scene_to_file(MAIN_SCENE)
			_stage = 11
			_wait_frames = 0
			return false
		11:
			if not _on_main():
				return false
			_attach_route_recorder()
			# --- Test 7: Continue bypasses the Prologue and loads the save ---
			_press(false)
			_check(_routes.size() == 1 and String(_routes[0]) == FORGOTTEN_SHORE_SCENE, "Continue routes straight to Forgotten Shore (never to the Prologue)")
			_check(bool(Engine.get_meta("crownfall_load_on_start", false)), "Continue sets the load-on-start flag")
			change_scene_to_file(FORGOTTEN_SHORE_SCENE)
			_stage = 12
			_wait_frames = 0
			return false
		12:
			if not _on_shore_ready():
				return false
			var session: ForgottenShoreSession = current_scene as ForgottenShoreSession
			session.time_manager.auto_advance = false
			_check(session.time_manager.current_day == 2 and session.economy.get_amount(&"gold") == 99, "Continue consumed the injected save (day 2, gold 99) without any Prologue detour")
			# Continue never reads or writes the profile: the true fixture stays
			# byte-exact and the missing fixture stays missing.
			_check(FileAccess.get_file_as_string(PROFILE_TRUE) == JSON.stringify({"schema_version": 1, "prologue_completed_once": true}, "\t"), "profile fixture is byte-exact unchanged after Continue")
			_check(not FileAccess.file_exists(PROFILE_MISSING), "missing profile fixture stays missing after Continue")
			_stage = 13
			_wait_frames = 0
			return false
		13:
			# --- Hygiene: prove the real files untouched, then clean fixtures ---
			if _real_profile_existed:
				_check(FileAccess.get_file_as_string(REAL_PROFILE_PATH) == _real_profile_snapshot, "developer's real user://player_profile.json was never mutated")
			else:
				_check(not FileAccess.file_exists(REAL_PROFILE_PATH), "suite never created the developer's real user://player_profile.json")
			if _real_save_existed:
				_check(FileAccess.get_file_as_string(SaveManager.DEFAULT_SAVE_PATH) == _real_save_snapshot, "developer's real user://save_slot_0.json was never mutated")
			else:
				_check(not FileAccess.file_exists(SaveManager.DEFAULT_SAVE_PATH), "suite never created the developer's real user://save_slot_0.json")
			for suffix: String in [".tmp", ".bak", ".old"]:
				_assert_sidecar_untouched(SaveManager.DEFAULT_SAVE_PATH + suffix, _real_save_sidecars[suffix], "real save sidecar %s" % suffix)
			for suffix: String in [".tmp", ".old"]:
				_assert_sidecar_untouched(REAL_PROFILE_PATH + suffix, _real_profile_sidecars[suffix], "real profile sidecar %s" % suffix)
			for path: String in [PROFILE_FALSE, PROFILE_TRUE, SAVE_NONE, SAVE_PREV]:
				_rm(path)
			_clean_fixture_sidecars()
			if DirAccess.dir_exists_absolute(TEST_DIR):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
			if _failures == 0:
				print("PASS: All %d N4.1 Prologue Shell checks completed with 0 failures." % _checks)
				quit(0)
			else:
				printerr("FAIL: N4.1 Prologue Shell finished with %d failures out of %d checks." % [_failures, _checks])
				quit(1)
			return true
	return false
