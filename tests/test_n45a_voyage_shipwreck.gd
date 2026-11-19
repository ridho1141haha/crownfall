extends SceneTree

## N4.5-A Voyage & Shipwreck integration and contract suite.
##
## Covers:
##   1. Invalid transition rejection before N4.4 boundary (pl_07 cannot start early).
##   2. Normal pl_07_unfinished_journey -> pl_08_shipwreck -> N4.5-A terminal boundary:
##      - exact cue order & labelled [Placeholder art] captions,
##      - PrologueShell sole-writer ownership (pl_07 & pl_08 recorded once each),
##      - duplicate start_voyage_sequence() rejection during run and at boundary,
##      - MOUSE_FILTER_IGNORE overlay input isolation & control lock lifecycle,
##      - no Forgotten Shore transition, PlayerProfile.prologue_completed_once == false.
##   3. Skip path during pl_07 and pl_08 (each recorded once, reaches N4.5-A boundary).
##   4. Cancellation during pl_07 (nothing recorded, locks/overlay cleaned, generation guard).
##   5. Cancellation during pl_08 storm (pl_07 kept, pl_08 NOT recorded, locks/overlay cleaned).
##   6. Development exit during pl_08 storm (single Main exit, pl_08 NOT recorded).
##   7. Direct scene unload during pl_08 storm (shell freed, pl_08 NOT recorded after settle).
##   8. Failed setup / rejected sequence playback (invalid pl_07 rejected fail-closed;
##      invalid pl_08 after valid pl_07 fails closed without reaching N4.5-A boundary).
##   9. Real user profile/save non-mutation and fixture cleanup.

const PROLOGUE_SHELL_SCRIPT: GDScript = preload("res://scripts/narrative/PrologueShell.gd")
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const PROLOGUE_SHELL_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const TEST_DIR: String = "user://n45a_test"
const PROFILE_FALSE: String = "user://n45a_test/profile_false.json"
const SAVE_NONE: String = "user://n45a_test/save_none.json"
const REAL_PROFILE_PATH: String = "user://player_profile.json"
const AUTOSTART_META: String = "crownfall_prologue_autostart"
const BEAT_01: String = "pl_01_lost_world"
const BEAT_02: String = "pl_02_faint_resonance"
const BEAT_06: String = "pl_06_crowns_call"
const BEAT_07: String = "pl_07_unfinished_journey"
const BEAT_08: String = "pl_08_shipwreck"
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const MAX_WAIT_FRAMES: int = 2400

const EXPECTED_VOYAGE_CUES: Array[String] = [
	PrologueBeats.CUE_PL07_DEPARTURE,
	PrologueBeats.CUE_PL07_OPEN_SEA,
	PrologueBeats.CUE_PL08_STORM_GATHERS,
	PrologueBeats.CUE_PL08_SHIPWRECK,
	PrologueBeats.CUE_PL08_FADE_OUT,
]

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _wired_shell: Control = null
var _completions: Array[String] = []
var _shell_exits: Array[String] = []
var _cues: Array[String] = []
var _captured_shell: Control = null
var _unloaded_state: NarrativeState = null
var _real_profile_snapshot: String = ""
var _real_profile_existed: bool = false
var _real_save_snapshot: String = ""
var _real_save_existed: bool = false


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n45a_voyage_shipwreck] " + msg)
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


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _prepare_fixtures() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	for path: String in [PROFILE_FALSE, SAVE_NONE]:
		_rm(path)
		for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
			_rm(path + suffix)
	_write_json(PROFILE_FALSE, {"schema_version": 1, "prologue_completed_once": false})


func _profile_flag_is_false() -> bool:
	if not FileAccess.file_exists(PROFILE_FALSE):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_FALSE))
	return parsed is Dictionary and not bool((parsed as Dictionary).get("prologue_completed_once", true))


func _on_main() -> bool:
	return current_scene != null and current_scene.name == "Main"


func _on_shell() -> bool:
	return current_scene != null and current_scene.name == "PrologueShell" and current_scene.get_script() == PROLOGUE_SHELL_SCRIPT


func _shell() -> Control:
	return current_scene as Control


func _wire_shell(shell: Control) -> void:
	_completions.clear()
	_shell_exits.clear()
	_cues.clear()
	shell.call("set_exit_transition", func(scene_path: String) -> void: _shell_exits.append(scene_path))
	shell.call("set_cue_player", func(cue_id: String) -> void: _cues.append(cue_id))
	var runner: SequenceRunner = shell.call("sequence_runner")
	runner.sequence_completed.connect(func(sequence_id: String) -> void: _completions.append(sequence_id))


func _skip_to_n44_boundary(shell: Control) -> bool:
	if not bool(shell.call("in_exploration")):
		if bool(shell.call("is_sequence_running")):
			shell.call("skip_sequence")
		return false
	while not bool(shell.call("n43_segment_complete")):
		if not bool(shell.call("skip_current_exploration_beat")):
			return false
	return true


func _go_main(next_s: int) -> void:
	_wired_shell = null
	change_scene_to_file(MAIN_SCENE)
	_stage = next_s
	_wait_frames = 0


func _go_shell(next_s: int) -> void:
	_wired_shell = null
	change_scene_to_file(PROLOGUE_SHELL_SCENE)
	_stage = next_s
	_wait_frames = 0


func _initialize() -> void:
	_prepare_fixtures()
	_real_profile_existed = FileAccess.file_exists(REAL_PROFILE_PATH)
	if _real_profile_existed:
		_real_profile_snapshot = FileAccess.get_file_as_string(REAL_PROFILE_PATH)
	_real_save_existed = FileAccess.file_exists(SaveManager.DEFAULT_SAVE_PATH)
	if _real_save_existed:
		_real_save_snapshot = FileAccess.get_file_as_string(SaveManager.DEFAULT_SAVE_PATH)
	Engine.set_meta("crownfall_profile_path", PROFILE_FALSE)
	Engine.set_meta("crownfall_menu_save_path", SAVE_NONE)
	Engine.set_meta(AUTOSTART_META, false)

	# Authored sequence data checks (no runtime side effects)
	var seq7: Dictionary = PrologueBeats.voyage_sequence()
	var seq8: Dictionary = PrologueBeats.shipwreck_sequence()
	_check(NarrativeData.validate_sequence(seq7) and String(seq7.get("id", "")) == BEAT_07, "Data: pl_07_unfinished_journey validates under NarrativeData")
	_check(NarrativeData.validate_sequence(seq8) and String(seq8.get("id", "")) == BEAT_08, "Data: pl_08_shipwreck validates under NarrativeData")
	for cue_id: String in EXPECTED_VOYAGE_CUES:
		var cap: String = PrologueBeats.stage_caption(cue_id)
		_check(cap.begins_with("[Placeholder art]"), "Data: cue %s uses labelled [Placeholder art] caption" % cue_id)
		_check(not cap.to_lower().contains("forgotten shore") and not cap.to_lower().contains("crown"), "Data: cue %s preserves OPEN lore boundaries" % cue_id)

	_stage = 1
	change_scene_to_file(MAIN_SCENE)


func _process(_delta: float) -> bool:
	_wait_frames += 1
	if _wait_frames > MAX_WAIT_FRAMES:
		_check(false, "timed out at stage %d" % _stage)
		return true
	match _stage:
		# =====================================================================
		# Case 1: Invalid transition before N4.4 boundary + Normal pl_07 -> pl_08 -> N4.5-A boundary
		# =====================================================================
		1:
			if not _on_main():
				return false
			_go_shell(2)
			return false
		2:
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell(shell)
				_check(not bool(shell.call("start_voyage_sequence")), "Case 1: start_voyage_sequence rejected before Prologue starts")
				if not _check(shell.call("start_prologue"), "Case 1: start_prologue starts chain"):
					return true
			if not _skip_to_n44_boundary(shell):
				if bool(shell.call("in_exploration")) and not bool(shell.call("n43_segment_complete")):
					_check(not bool(shell.call("start_voyage_sequence")), "Case 1: start_voyage_sequence rejected before N4.4 boundary")
				return false
			var state: NarrativeState = shell.call("narrative_state")
			_check(state.completed_count() == 6 and bool(state.is_completed(BEAT_06)), "Case 1: N4.4 boundary reached cleanly with 6 beats")
			_cues.clear()
			var gen_before: int = int(shell.call("voyage_generation"))
			_check(bool(shell.call("start_voyage_sequence")), "Case 1: start_voyage_sequence accepted at N4.4 boundary")
			_check(int(shell.call("voyage_generation")) > gen_before, "Case 1: voyage generation incremented on start")
			_check(bool(shell.call("is_voyage_active")) and String(shell.call("active_voyage_beat")) == BEAT_07, "Case 1: pl_07 activated")
			_check(not bool(shell.call("start_voyage_sequence")), "Case 1: duplicate start_voyage_sequence rejected while pl_07 running")
			var vrunner: SequenceRunner = shell.call("voyage_runner")
			_check(vrunner != null and vrunner.is_running() and vrunner.is_control_locked(), "Case 1: voyage runner active and control locked")
			var vlayer: CanvasLayer = shell.call("voyage_overlay_layer")
			var vroot: Control = vlayer.get_node_or_null("VoyageRoot") as Control if vlayer != null else null
			var vbg: Control = vroot.get_node_or_null("VoyageBackdrop") as Control if vroot != null else null
			var vlbl: Control = vbg.get_node_or_null("VoyageCaption") as Control if vbg != null else null
			_check(
				vroot != null and vroot.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and vbg != null and vbg.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and vlbl != null and vlbl.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"Case 1: voyage overlay controls use MOUSE_FILTER_IGNORE"
			)
			_stage = 3
			_wait_frames = 0
			return false
		3:
			if not _on_shell():
				return false
			var shell := _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(state.is_completed(BEAT_07)):
				return false
			_check(state.completed_count() == 7 and String(shell.call("active_voyage_beat")) == BEAT_08, "Case 1: pl_07 completed once and pl_08 activated")
			_check(not bool(shell.call("start_voyage_sequence")), "Case 1: duplicate start_voyage_sequence rejected during pl_08")
			_stage = 4
			_wait_frames = 0
			return false
		4:
			if not _on_shell():
				return false
			var shell := _shell()
			if not bool(shell.call("n45a_boundary_reached")):
				return false
			var state: NarrativeState = shell.call("narrative_state")
			var vrunner: SequenceRunner = shell.call("voyage_runner")
			var status: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
			_check(state.completed_count() == 8 and bool(state.is_completed(BEAT_07)) and bool(state.is_completed(BEAT_08)), "Case 1: pl_07 and pl_08 each recorded exactly once (total 8)")
			_check(_completions == [BEAT_01, BEAT_02], "Case 1: primary runner completions stay [pl_01, pl_02] (PrologueShell sole writer)")
			_check(_cues == EXPECTED_VOYAGE_CUES, "Case 1: exact pl_07/pl_08 cue order played")
			_check(not bool(shell.call("is_voyage_active")) and String(shell.call("active_voyage_beat")) == "", "Case 1: voyage inactive at N4.5-A terminal boundary")
			_check(not vrunner.is_running() and not vrunner.is_control_locked() and not bool(shell.call("is_voyage_overlay_visible")), "Case 1: voyage runner idle, locks released, overlay hidden at boundary")
			_check(not bool(shell.call("start_voyage_sequence")), "Case 1: duplicate start_voyage_sequence rejected at N4.5-A boundary")
			_check(status != null and status.text.contains("pl_01-pl_08") and status.text.contains("pl_09"), "Case 1: N4.5-A boundary status explicitly awaits N4.5-B (pl_09)")
			_check(_shell_exits.is_empty() and not _shell_exits.has(FORGOTTEN_SHORE_SCENE), "Case 1: no scene transition to Forgotten Shore")
			_check(_profile_flag_is_false(), "Case 1: PlayerProfile.prologue_completed_once remains false")
			_go_main(10)
			return false

		# =====================================================================
		# Case 2: Skip during pl_07 and pl_08 reaches N4.5-A boundary cleanly
		# =====================================================================
		10:
			if not _on_main():
				return false
			_go_shell(11)
			return false
		11:
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell(shell)
				shell.call("start_prologue")
			if not _skip_to_n44_boundary(shell):
				return false
			_check(bool(shell.call("start_voyage_sequence")), "Case 2: voyage started for skip test")
			shell.call("skip_sequence")
			_stage = 12
			_wait_frames = 0
			return false
		12:
			if not _on_shell():
				return false
			var shell := _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(state.is_completed(BEAT_07)):
				return false
			if String(shell.call("active_voyage_beat")) == BEAT_08:
				shell.call("skip_sequence")
			_stage = 13
			_wait_frames = 0
			return false
		13:
			if not _on_shell():
				return false
			var shell := _shell()
			if not bool(shell.call("n45a_boundary_reached")):
				return false
			var state: NarrativeState = shell.call("narrative_state")
			_check(state.completed_count() == 8 and bool(state.is_completed(BEAT_07)) and bool(state.is_completed(BEAT_08)), "Case 2: skipping pl_07 and pl_08 records each once and reaches N4.5-A boundary")
			_check(_profile_flag_is_false() and _shell_exits.is_empty(), "Case 2: skip never marks profile or transitions scene")
			_go_main(20)
			return false

		# =====================================================================
		# Case 3: Cancellation during pl_07
		# =====================================================================
		20:
			if not _on_main():
				return false
			_go_shell(21)
			return false
		21:
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell(shell)
				shell.call("start_prologue")
			if not _skip_to_n44_boundary(shell):
				return false
			_check(bool(shell.call("start_voyage_sequence")), "Case 3: pl_07 started")
			var gen_active: int = int(shell.call("voyage_generation"))
			shell.call("cancel_sequence")
			var state: NarrativeState = shell.call("narrative_state")
			var vrunner: SequenceRunner = shell.call("voyage_runner")
			_check(state.completed_count() == 6 and not bool(state.is_completed(BEAT_07)), "Case 3: cancel during pl_07 records nothing")
			_check(not bool(shell.call("is_voyage_active")) and not vrunner.is_running() and not vrunner.is_control_locked() and not bool(shell.call("is_voyage_overlay_visible")), "Case 3: cancel during pl_07 releases locks and hides overlay")
			_check(int(shell.call("voyage_generation")) > gen_active, "Case 3: cancel invalidates voyage generation")
			_stage = 22
			_wait_frames = 0
			return false
		22:
			if not _on_shell():
				return false
			if _wait_frames < 12:
				return false
			var state: NarrativeState = _shell().call("narrative_state")
			_check(state.completed_count() == 6 and not bool(_shell().call("n45a_boundary_reached")), "Case 3: no stale callback mutates state after pl_07 cancel")
			_go_main(30)
			return false

		# =====================================================================
		# Case 4: Cancellation during pl_08 storm
		# =====================================================================
		30:
			if not _on_main():
				return false
			_go_shell(31)
			return false
		31:
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell(shell)
				shell.call("start_prologue")
			if not _skip_to_n44_boundary(shell):
				return false
			shell.call("start_voyage_sequence")
			shell.call("skip_sequence")
			_stage = 32
			_wait_frames = 0
			return false
		32:
			if not _on_shell():
				return false
			var shell := _shell()
			if String(shell.call("active_voyage_beat")) != BEAT_08:
				return false
			shell.call("cancel_sequence")
			var state: NarrativeState = shell.call("narrative_state")
			var vrunner: SequenceRunner = shell.call("voyage_runner")
			_check(state.completed_count() == 7 and bool(state.is_completed(BEAT_07)) and not bool(state.is_completed(BEAT_08)), "Case 4: cancel during pl_08 keeps pl_07 and records nothing for pl_08")
			_check(not vrunner.is_running() and not vrunner.is_control_locked() and not bool(shell.call("is_voyage_overlay_visible")), "Case 4: cancel during pl_08 cleans runner, locks, and overlay")
			_stage = 33
			_wait_frames = 0
			return false
		33:
			if not _on_shell():
				return false
			if _wait_frames < 12:
				return false
			var state: NarrativeState = _shell().call("narrative_state")
			_check(state.completed_count() == 7 and not bool(_shell().call("n45a_boundary_reached")), "Case 4: no stale callback mutates state after pl_08 cancel")
			_go_main(40)
			return false

		# =====================================================================
		# Case 5: Development exit during pl_08 storm
		# =====================================================================
		40:
			if not _on_main():
				return false
			_go_shell(41)
			return false
		41:
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell(shell)
				shell.call("start_prologue")
			if not _skip_to_n44_boundary(shell):
				return false
			shell.call("start_voyage_sequence")
			shell.call("skip_sequence")
			_stage = 42
			_wait_frames = 0
			return false
		42:
			if not _on_shell():
				return false
			var shell := _shell()
			if String(shell.call("active_voyage_beat")) != BEAT_08:
				return false
			_check(bool(shell.call("request_main_menu_return")) and not bool(shell.call("request_main_menu_return")), "Case 5: dev exit during pl_08 transitions once")
			_check(_shell_exits == [MAIN_SCENE], "Case 5: dev exit targets Main menu only")
			var state: NarrativeState = shell.call("narrative_state")
			var vrunner: SequenceRunner = shell.call("voyage_runner")
			_check(state.completed_count() == 7 and not bool(state.is_completed(BEAT_08)), "Case 5: dev exit during pl_08 does not record pl_08")
			_check(not vrunner.is_running() and not vrunner.is_control_locked() and not bool(shell.call("is_voyage_overlay_visible")), "Case 5: dev exit cleans runner, locks, and overlay")
			_go_main(50)
			return false

		# =====================================================================
		# Case 6: Direct scene unload during pl_08 storm
		# =====================================================================
		50:
			if not _on_main():
				return false
			_go_shell(51)
			return false
		51:
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell(shell)
				shell.call("start_prologue")
			if not _skip_to_n44_boundary(shell):
				return false
			shell.call("start_voyage_sequence")
			shell.call("skip_sequence")
			_stage = 52
			_wait_frames = 0
			return false
		52:
			if not _on_shell():
				return false
			var shell := _shell()
			if String(shell.call("active_voyage_beat")) != BEAT_08:
				return false
			_captured_shell = shell
			_unloaded_state = shell.call("narrative_state")
			_go_main(53)
			return false
		53:
			if not _on_main():
				return false
			if _wait_frames < 15:
				return false
			_check(not is_instance_valid(_captured_shell), "Case 6: PrologueShell freed on direct scene unload during storm")
			_check(_unloaded_state != null and _unloaded_state.completed_count() == 7 and not bool(_unloaded_state.is_completed(BEAT_08)), "Case 6: direct unload during storm records nothing for pl_08 after settle window")
			_captured_shell = null
			_unloaded_state = null
			_go_shell(60)
			return false

		# =====================================================================
		# Case 7: Failed setup / rejected sequence playback (pl_07 invalid, then pl_08 invalid)
		# =====================================================================
		60:
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell(shell)
				shell.call("start_prologue")
			if not _skip_to_n44_boundary(shell):
				return false
			# 7a: invalid pl_07 payload rejected fail-closed
			shell.call("set_voyage_sequence_provider", func(_beat_id: String) -> Dictionary:
				return {"id": BEAT_07, "steps": [{"op": "invalid_op_n45a"}]}
			)
			var state: NarrativeState = shell.call("narrative_state")
			var vrunner: SequenceRunner = shell.call("voyage_runner")
			_check(not bool(shell.call("start_voyage_sequence")), "Case 7a: invalid pl_07 sequence rejected fail-closed")
			_check(state.completed_count() == 6 and not bool(shell.call("is_voyage_active")) and not vrunner.is_control_locked(), "Case 7a: rejected pl_07 mutates no state and leaves no lock")
			# 7b: valid pl_07 followed by invalid pl_08 fails closed without reaching boundary
			shell.call("set_voyage_sequence_provider", func(beat_id: String) -> Dictionary:
				if beat_id == BEAT_07:
					return PrologueBeats.voyage_sequence()
				return {"id": BEAT_08, "steps": [{"op": "invalid_op_n45a"}]}
			)
			_check(bool(shell.call("start_voyage_sequence")), "Case 7b: valid pl_07 starts cleanly")
			shell.call("skip_sequence")
			_stage = 61
			_wait_frames = 0
			return false
		61:
			if not _on_shell():
				return false
			if _wait_frames < 10:
				return false
			var shell := _shell()
			var state: NarrativeState = shell.call("narrative_state")
			var vrunner: SequenceRunner = shell.call("voyage_runner")
			_check(state.completed_count() == 7 and bool(state.is_completed(BEAT_07)) and not bool(state.is_completed(BEAT_08)), "Case 7b: rejected pl_08 keeps pl_07 and records nothing for pl_08")
			_check(not bool(shell.call("n45a_boundary_reached")) and not bool(shell.call("is_voyage_active")) and not vrunner.is_control_locked() and not bool(shell.call("is_voyage_overlay_visible")), "Case 7b: rejected pl_08 does not reach boundary and leaves no locks or overlay")
			_go_main(70)
			return false

		# =====================================================================
		# Hygiene & Cleanup
		# =====================================================================
		70:
			if not _on_main():
				return false
			if _real_profile_existed:
				_check(FileAccess.get_file_as_string(REAL_PROFILE_PATH) == _real_profile_snapshot, "Hygiene: real user://player_profile.json untouched")
			else:
				_check(not FileAccess.file_exists(REAL_PROFILE_PATH), "Hygiene: real user://player_profile.json not created")
			if _real_save_existed:
				_check(FileAccess.get_file_as_string(SaveManager.DEFAULT_SAVE_PATH) == _real_save_snapshot, "Hygiene: real user://save_slot_0.json untouched")
			else:
				_check(not FileAccess.file_exists(SaveManager.DEFAULT_SAVE_PATH), "Hygiene: real user://save_slot_0.json not created")
			_rm(PROFILE_FALSE)
			_rm(SAVE_NONE)
			if DirAccess.dir_exists_absolute(TEST_DIR):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
			Engine.remove_meta(AUTOSTART_META)
			Engine.remove_meta("crownfall_profile_path")
			Engine.remove_meta("crownfall_menu_save_path")
			if _failures == 0:
				print("PASS: All %d N45A Voyage Shipwreck checks completed with 0 failures." % _checks)
				quit(0)
			else:
				printerr("FAIL: N45A Voyage Shipwreck finished with %d failures out of %d checks." % [_failures, _checks])
				quit(1)
			return true
	return false
