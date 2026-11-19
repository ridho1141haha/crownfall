extends SceneTree

## N43C full-flow integration & regression (N4.3-C, planning §7 slice C).
##
## Central question: can the ENTIRE Prologue transition from pl_01 through the
## N4.3 exploration boundary without broken ownership, duplicate completion,
## stuck controls, or stale callbacks? This suite drives the complete
## experience as ONE continuous shell (pl_01 advance -> pl_02 advance -> pl_03
## intro -> genuine movement to the handoff -> pl_04 prompt/inspection ->
## recognition -> completion -> boundary) and then walks the skip, cancellation,
## teardown, and failed-setup matrices end to end.
##
## Covered integration contracts (see docs/narrative/N43C_IMPLEMENTATION_REPORT.md §2):
##   A. Normal full flow: cue ordering across pl_01/pl_02, cinematic control
##      lock on the shell, pl_02 -> exploration handoff, movement enabled ONLY
##      after the intro line closes, genuine handoff-area completion recorded
##      exactly once by the shell, prompt range + nearest-only targeting,
##      idempotent repeat inspection (D1), two-distinct recognition (D4/D5),
##      held-input recognition window (H14 contract inside the full flow),
##      exactly-once pl_04 completion, D3 terminal boundary, post-boundary
##      inertness, exit from the boundary.
##   B. Skip matrix: runner-level skips of pl_01/pl_02 stage no cues; pl_03
##      skip while the intro is open (records, activates pl_04, does NOT skip
##      it); pl_04 skip before any inspection / after exactly one inspection /
##      WHILE the recognition dialogue is open (the resumed coroutine must NOT
##      emit the completion request — the recording belongs to the skip);
##      duplicate skip after the segment ended is rejected.
##   C. Cancellation/teardown matrix: cancel during pl_01 (nothing recorded,
##      chain restartable per non-resumable per-run state), during the pl_03
##      intro, during pl_04 after one inspection, DURING the recognition
##      dialogue (the N4.3-B ordering contract: the stage is torn down before
##      the runner closes the shared panel, so a cancelled recognition can
##      never record), the development exit during recognition, and a DIRECT
##      scene unload during recognition (no cancel path).
##   D. Failed exploration-stage setup (fail-closed, atomic fallback).
##   E. Hygiene: no input-state leaks, real user profile/save files byte-exact
##      untouched, fixtures cleaned, Engine metas removed.
##
## OWNERSHIP ASSERTIONS WOVEN THROUGH: SequenceRunner never records
## exploration beats (runner completions stay [pl_01, pl_02]); PrologueShell
## is the sole NarrativeState writer for pl_03/pl_04; each beat records
## exactly once; cancel/exit/teardown/failed setup record nothing.
##
## ISOLATION CONTRACT (same style as test_n43a/test_n43b): fixtures live
## under user://n43c_test/ injected via the crownfall_profile_path /
## crownfall_menu_save_path Engine metas; the developer's real
## user://player_profile.json and user://save_slot_0.json plus sidecars are
## only READ once for byte-exact non-mutation proof at the end of the run.
## Interact presses follow the measured 4.7.2 input model (one press arms
## exactly one edge, observed by the first physics tick after the press; a
## press while already held does NOT re-arm — every normal retry releases
## before re-pressing, and the held-input recognition window never does).

const PROLOGUE_SHELL_SCRIPT: GDScript = preload("res://scripts/narrative/PrologueShell.gd")
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const PROLOGUE_SHELL_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const TEST_DIR: String = "user://n43c_test"
const PROFILE_MISSING: String = "user://n43c_test/profile_missing.json"
const PROFILE_FALSE: String = "user://n43c_test/profile_false.json"
const SAVE_NONE: String = "user://n43c_test/save_none.json"
const REAL_PROFILE_PATH: String = "user://player_profile.json"
const AUTOSTART_META: String = "crownfall_prologue_autostart"
const STAGE_TEXTURE_META: String = "crownfall_prologue_stage_texture"
const BEAT_01: String = "pl_01_lost_world"
const BEAT_02: String = "pl_02_faint_resonance"
const BEAT_03: String = "pl_03_wanderer"
const BEAT_04: String = "pl_04_repeated_mark"
const BEAT_05: String = "pl_05_forgotten_ruins"
const BEAT_06: String = "pl_06_crowns_call"
const MAIN_MENU_SCENE: String = "res://scenes/main/Main.tscn"
const MAX_WAIT_FRAMES: int = 1800
## How long an interact press may wait for its effect before the driver
## declares the attempt failed (N4.3-B measured model: physics ticks arrive
## every 2-5 process frames with gaps up to ~10; bounded window, not a sleep).
const INTERACT_RETRY_BUDGET_FRAMES: int = 30

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _routes: Array[String] = []
var _shell_exits: Array[String] = []
var _completions: Array[String] = []
var _cues: Array[String] = []
var _handoff_emissions: int = 0
var _inspection_emissions: int = 0
## N4.4-A: the stage's ONE pl_05 altar completion request (same observability
## contract as the pl_03/pl_04 request counters).
var _altar_emissions: int = 0
## A12 two-phase flag: phase 1 waits for the natural altar completion, phase 2
## measures the post-completion interact inertness after a settle window.
var _a12_pressed: bool = false
var _a12_press_frame: int = 0
var _recognition_seen: bool = false
var _real_profile_snapshot: String = ""
var _real_profile_existed: bool = false
var _real_save_snapshot: String = ""
var _real_save_existed: bool = false
var _real_save_sidecars: Dictionary = {}
var _real_profile_sidecars: Dictionary = {}
## NarrativeState captured before a direct scene unload (RefCounted outlives
## the freed shell, so the record contents stay observable).
var _unloaded_state: NarrativeState = null
## Shell captured before a direct scene unload (freed afterwards — the
## validity check proves the unload really happened).
var _captured_shell: Control = null
## The shell instance the observers were wired to (identity guard: looping
## stages wire and start a shell exactly once, never per frame).
var _wired_shell: Control = null
## Explorer captured before a cancel/unload (the shell drops the stage
## reference on abort, so post-abort explorer assertions need the capture).
var _captured_explorer: PrologueExplorer = null
## Stage/explorer references captured before a cancel/unload (the shell drops
## its own reference on abort; the captured objects stay valid for teardown
## assertions).
var _captured_stage: PrologueExplorationStage = null


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n43c_full_flow] " + msg)
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
	for path: String in [PROFILE_MISSING, PROFILE_FALSE, SAVE_NONE]:
		for suffix: String in [".tmp", ".old", ".bak", ".bak.tmp"]:
			_rm(path + suffix)


func _prepare_fixtures() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	for path: String in [PROFILE_MISSING, PROFILE_FALSE, SAVE_NONE]:
		_rm(path)
	_clean_fixture_sidecars()
	_write_json(PROFILE_FALSE, {"schema_version": 1, "prologue_completed_once": false})


func _set_metas(profile_path: String, save_path: String) -> bool:
	if not _check(save_path != SaveManager.DEFAULT_SAVE_PATH and save_path.begins_with(TEST_DIR + "/"), "injected save path is isolated from the real player save (%s)" % save_path):
		return false
	if not _check(profile_path != PlayerProfile.DEFAULT_PROFILE_PATH and profile_path.begins_with(TEST_DIR + "/"), "injected profile path is isolated from the real player profile (%s)" % profile_path):
		return false
	Engine.set_meta("crownfall_profile_path", profile_path)
	Engine.set_meta("crownfall_menu_save_path", save_path)
	return true


func _on_main() -> bool:
	return current_scene != null and current_scene.name == "Main"


func _on_shell() -> bool:
	if current_scene == null or current_scene.name != "PrologueShell":
		return false
	return current_scene.get_script() == PROLOGUE_SHELL_SCRIPT


func _shell() -> Control:
	return current_scene as Control


## Wires the per-shell observability contract and resets the per-shell
## recorders. Same injection convention as N4.3-A/N4.3-B: exit transitions and
## cue staging are observed via the shell's existing test seams, runner
## completions via the runner signal, and the stage's one-shot completion
## requests via its own signals.
func _wire_shell_observers(shell: Control) -> void:
	_completions.clear()
	_shell_exits.clear()
	_cues.clear()
	_handoff_emissions = 0
	_inspection_emissions = 0
	_altar_emissions = 0
	_a12_pressed = false
	_a12_press_frame = 0
	_recognition_seen = false
	shell.call("set_exit_transition", func(scene_path: String) -> void: _shell_exits.append(scene_path))
	shell.call("set_cue_player", func(cue_id: String) -> void: _cues.append(cue_id))
	var runner: SequenceRunner = shell.call("sequence_runner")
	runner.sequence_completed.connect(func(sequence_id: String) -> void: _completions.append(sequence_id))


func _wire_stage_observers(stage: PrologueExplorationStage) -> void:
	stage.exploration_handoff_reached.connect(func() -> void: _handoff_emissions += 1)
	stage.mark_inspection_completed.connect(func() -> void: _inspection_emissions += 1)
	stage.ruins_altar_reached.connect(func() -> void: _altar_emissions += 1)


func _stage_node(shell: Control) -> PrologueExplorationStage:
	return shell.call("exploration_stage") as PrologueExplorationStage


func _explorer_of(shell: Control) -> PrologueExplorer:
	var stage := _stage_node(shell)
	return stage.explorer() if stage != null else null


func _inspectables_of(shell: Control) -> PrologueMarkInspectables:
	var stage := _stage_node(shell)
	return stage.inspectables() if stage != null else null


func _panel_of(shell: Control) -> DialoguePanel:
	return shell.call("dialogue_panel") as DialoguePanel


func _advance_if_open(shell: Control) -> void:
	var panel := _panel_of(shell)
	if panel.is_open():
		panel.advance()


func _skip_runner_beat(shell: Control) -> void:
	if bool(shell.call("is_sequence_running")):
		shell.call("skip_sequence")


func _drive_right(_shell: Control) -> void:
	Input.action_press("move_right")


func _drive_left(_shell: Control) -> void:
	Input.action_press("move_left")


func _stop_driving() -> void:
	Input.action_release("move_right")
	Input.action_release("move_left")


func _teleport(explorer: PrologueExplorer, x: float) -> void:
	explorer.position = Vector2(x, PrologueExplorationStage.GROUND_Y)


## Marks the recognition window when the approved line first appears (one-shot
## per shell, used as the await effect and for the exactly-once proof).
func _mark_recognition_seen() -> void:
	if not _recognition_seen:
		_recognition_seen = true


func _recognition_open() -> bool:
	if current_scene == null or current_scene.name != "PrologueShell":
		return false
	var panel := _panel_of(current_scene as Control)
	return panel.is_open() and panel.get_speaker_text() == "Monarch" and panel.get_body_text().contains("I've seen this mark before...")


## The TRUE screen-space rect of a UI control. Items under a CanvasLayer are
## camera-immune (their global transform is layer-relative and the layer does
## not follow the viewport camera); items on the default canvas go through the
## viewport's canvas transform, which the exploration Camera2D drives.
## Regression proof for the N4.3-C UI-layer fix: the shell UI (status labels
## + the development exit button) must stay ON-SCREEN while the world pans —
## on the old default-canvas UI the exploration camera displaced it outside
## the viewport (demonstrated by the Phase 5 screenshots).
func _button_screen_rect(button: Control) -> Rect2:
	var node: Node = button
	while node != null:
		if node is CanvasLayer:
			return Rect2(button.get_global_position(), button.get_size())
		node = node.get_parent()
	var xform: Transform2D = root.get_canvas_transform()
	return Rect2(xform * button.get_global_position(), button.get_size())


func _ui_button_on_screen(shell: Control, label: String) -> void:
	var button: Button = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/DevExitButton") as Button
	if button == null:
		_check(false, "%s: the DevExitButton node is missing" % label)
		return
	var view: Rect2 = Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var rect := _button_screen_rect(button)
	_check(view.encloses(rect.grow(-2.0)), "%s: the development exit button stays ON-SCREEN during exploration (UI is camera-immune on its CanvasLayer; measured %s)" % [label, rect])


## Press-and-confirm driver for NORMAL interactions (the N4.3-B measured input
## model): the press stage presses once; every retry releases before
## re-pressing so each attempt arms a FRESH just-pressed edge; every exit
## path leaves the action released.
func _await_interact_effect(has_effect: Callable, next_stage: int) -> bool:
	if has_effect.call():
		Input.action_release("interact")
		_stage = next_stage
		_wait_frames = 0
		return true
	if _wait_frames > INTERACT_RETRY_BUDGET_FRAMES:
		Input.action_release("interact")
		_check(false, "the interact press produced no effect within the retry budget (stage %d)" % _stage)
		return true
	Input.action_release("interact")
	Input.action_press("interact")
	return false


## Held-input await (the recognition accepting press ONLY): the key stays
## DOWN for the whole window — no release/press cycles (they would convert
## the held-input scenario into repeated presses). The held press's edge is
## observed by the first physics tick after the press regardless of the frame
## gap (measured), so this only waits for the effect. On failure the key is
## released before the suite aborts.
func _await_held_interact_effect(has_effect: Callable, next_stage: int) -> bool:
	if has_effect.call():
		_stage = next_stage
		_wait_frames = 0
		return true
	if _wait_frames > INTERACT_RETRY_BUDGET_FRAMES:
		Input.action_release("interact")
		_check(false, "the held interact press produced no effect within the retry budget (stage %d)" % _stage)
		return true
	return false


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
	# --- Shell A: the complete normal flow with production defaults ---
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
			var main_ctrl: Control = current_scene as Control
			main_ctrl.call("set_route_transition", func(scene_path: String) -> void: _routes.append(scene_path))
			# Autostart is disabled ONLY so the cue/exit observers can be wired
			# before the chain starts; start_prologue() below IS the production
			# entry call (the _ready auto-start path itself is covered by the
			# N4.3-A suite). Exploration stays on the production default.
			Engine.set_meta(AUTOSTART_META, false)
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 2
			_wait_frames = 0
			return false
		2:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if not _check(shell.call("start_prologue"), "A1: the production entry call starts the chain (Shell A)"):
				return true
			# --- A1: pl_01 plays under production exploration defaults ---
			var panel := _panel_of(shell)
			var runner: SequenceRunner = shell.call("sequence_runner")
			_check(panel.is_open() and panel.get_body_text().contains("Long ago"), "A1: the chain plays pl_01 (existing flow intact)")
			_check(String(shell.call("current_beat_id")) == BEAT_01, "A1: the chain stages pl_01")
			_check(runner.is_control_locked(), "A1: the cinematic control lock holds the shell during pl_01 (pl_01/pl_02 stay no-control)")
			_check(shell.call("exploration_stage") == null and not bool(shell.call("in_exploration")), "A1: no exploration actor/state exists during the cinematics")
			_check(_cues == ["stage_pl01_prosperity"], "A2: the pl_01 opening cue is staged first")
			_stage = 3
			_wait_frames = 0
			return false
		3:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not _completions.has(BEAT_01):
				_advance_if_open(shell)
				return false
			# --- A3: pl_01 completed exactly once; pl_02 chained ---
			_check(_completions == [BEAT_01], "A3: pl_01 records exactly once through the runner")
			var panel := _panel_of(shell)
			_check(panel.is_open() and panel.get_body_text().contains("Years ago"), "A3: pl_01 completion chains pl_02 (existing flow intact)")
			_check(_cues == ["stage_pl01_prosperity", "stage_pl01_eclipse", "stage_pl01_ruins", "stage_pl02_childhood"], "A2: the pl_01/pl_02 cue order is authored and sequential")
			_stage = 4
			_wait_frames = 0
			return false
		4:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not _completions.has(BEAT_02):
				_advance_if_open(shell)
				return false
			if not bool(shell.call("in_exploration")):
				return false
			# --- A4: pl_02 completion enters the exploration segment ---
			_check(_completions == [BEAT_01, BEAT_02], "A4: pl_02 records exactly once (runner chain untouched by exploration)")
			_check(String(shell.call("active_exploration_beat")) == BEAT_03 and bool(shell.call("in_exploration")), "A4: pl_02 completion enters the pl_03 exploration segment")
			_check(bool(shell.call("prologue_reached_end")) and not bool(shell.call("is_sequence_running")), "A4: the authored chain structurally ended and the runner is idle (no auto-chaining past exploration)")
			_check(_cues == ["stage_pl01_prosperity", "stage_pl01_eclipse", "stage_pl01_ruins", "stage_pl02_childhood", "stage_pl02_resonance"], "A4: the full authored cue order played across the chain")
			var stage := _stage_node(shell)
			_check(stage != null and stage.is_built() and String(stage.active_beat()) == BEAT_03, "A4: the exploration stage is built with pl_03 active")
			var explorer := _explorer_of(shell)
			_check(explorer != null and explorer.position == Vector2(PrologueExplorationStage.EXPLORER_START_X, PrologueExplorationStage.GROUND_Y), "A4: the dedicated explorer stands at the authored road start")
			_wire_stage_observers(stage)
			var panel := _panel_of(shell)
			_check(panel.is_open() and panel.get_speaker_text() == "Monarch" and panel.get_body_text().contains("difficult to forget"), "A4: the approved pl_03 internal line opens through the existing DialoguePanel")
			_check(stage.is_dialogue_locked() and not explorer.is_input_enabled() and not explorer.is_physics_processing(), "A4: the stage-owned actor lock disables movement during the intro line")
			_check(_inspectables_of(shell) != null and not _inspectables_of(shell).prompt().visible, "A4: no inspection prompt exists during pl_03")
			var runner: SequenceRunner = shell.call("sequence_runner")
			_check(not runner.is_control_locked(), "A4: the runner lock was released with the cinematics (control moved to the stage-owned lock)")
			# --- A5: held movement during the intro must not move the actor ---
			_drive_right(shell)
			_stage = 5
			_wait_frames = 0
			return false
		5:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if explorer == null:
				return false
			if _wait_frames < 20:
				return false
			_stop_driving()
			_check(explorer.position.x == PrologueExplorationStage.EXPLORER_START_X, "A5: held movement keys do NOT move the actor while the intro lock is held")
			# --- A6: control arrives exactly when the intro line closes ---
			_stage = 6
			_wait_frames = 0
			return false
		6:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel := _panel_of(shell)
			if panel.is_open():
				panel.advance()
				return false
			var stage := _stage_node(shell)
			var explorer := _explorer_of(shell)
			_check(stage != null and not stage.is_dialogue_locked(), "A6: normal intro completion releases the stage-owned actor lock")
			_check(explorer != null and explorer.is_input_enabled() and explorer.is_physics_processing(), "A6: movement becomes enabled exactly after the line closes (the intended point)")
			var status: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
			_check(status != null and status.text.contains("The Wanderer"), "A6: the exploration status names the active pl_03 beat")
			_check(_cues.size() == 5, "A6: the pl_03 intro stages no cinematic cue (panel-direct presentation)")
			# --- A7: genuine movement to the handoff area ---
			_drive_right(shell)
			_stage = 7
			_wait_frames = 0
			return false
		7:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(state.is_completed(BEAT_03)):
				return false
			_stop_driving()
			var explorer := _explorer_of(shell)
			var stage := _stage_node(shell)
			# --- A7: the handoff completes pl_03 exactly once, shell-validated ---
			_check(bool(state.is_completed(BEAT_03)) and state.completed_count() == 3, "A7: reaching the handoff area records pl_03 exactly once (state: pl_01..pl_03)")
			_check(stage != null and stage.handoff_emitted() and _handoff_emissions == 1, "A7: the stage emitted exactly its one handoff completion request")
			_check(String(shell.call("active_exploration_beat")) == BEAT_04, "A7: pl_03 completion activates pl_04 immediately")
			_check(_completions == [BEAT_01, BEAT_02], "A7: the runner never recorded an exploration beat (shell sole writer)")
			_check(explorer != null and explorer.position.x >= PrologueExplorationStage.HANDOFF_X, "A7: the completion fired because the actor reached the authored handoff area")
			_check(explorer != null and explorer.is_input_enabled(), "A7: pl_04 stays interactive (movement still enabled)")
			_check(not _panel_of(shell).is_open(), "A7: pl_04 activation opens no dialogue (recognition comes from inspection only)")
			# --- A8: prompt range + target identity. The authored ranges are
			# A [366, 494] and B [566, 694] (range 64): they never overlap, so
			# each in-range position proves exactly-one eligible targeting,
			# and x=520 sits in the out-of-range gap. ---
			_teleport(explorer, 480.0)
			_stage = 8
			_wait_frames = 0
			return false
		8:
			if not _on_shell():
				return false
			if _wait_frames < 12:
				return false
			var shell: Control = _shell()
			var prompt: Label = _inspectables_of(shell).prompt()
			_check(prompt.visible and absf(prompt.position.x - 430.0 + prompt.custom_minimum_size.x * 0.5) < 1.0, "A8: in A's range the prompt appears and identifies ONLY object A")
			_ui_button_on_screen(shell, "A8")
			var ui_explorer := _explorer_of(shell)
			_check(ui_explorer != null and absf((root.get_canvas_transform() * ui_explorer.global_position).x - ui_explorer.global_position.x) > 1.0, "A8: the world actor IS camera-displaced while the UI is not (the exploration camera is active — contrast proof)")
			var explorer := _explorer_of(shell)
			_teleport(explorer, 580.0)
			_stage = 9
			_wait_frames = 0
			return false
		9:
			if not _on_shell():
				return false
			if _wait_frames < 12:
				return false
			var shell: Control = _shell()
			var prompt: Label = _inspectables_of(shell).prompt()
			_check(prompt.visible and absf(prompt.position.x - 630.0 + prompt.custom_minimum_size.x * 0.5) < 1.0, "A8: in B's range the prompt flips to B (exactly one eligible target)")
			var explorer := _explorer_of(shell)
			_teleport(explorer, 520.0)
			_stage = 10
			_wait_frames = 0
			return false
		10:
			if not _on_shell():
				return false
			if _wait_frames < 12:
				return false
			var shell: Control = _shell()
			var prompt: Label = _inspectables_of(shell).prompt()
			_check(not prompt.visible, "A8: in the gap between A and B no prompt appears (out of range)")
			_teleport(_explorer_of(shell), -280.0)
			_stage = 11
			_wait_frames = 0
			return false
		11:
			if not _on_shell():
				return false
			if _wait_frames < 12:
				return false
			var shell: Control = _shell()
			var prompt: Label = _inspectables_of(shell).prompt()
			_check(prompt.visible, "A8: the optional third object (C) is reachable and prompted in range")
			var explorer := _explorer_of(shell)
			# --- A9: first + repeated inspection of the SAME object (D1) ---
			_teleport(explorer, 430.0)
			Input.action_press("interact")
			_stage = 13
			_wait_frames = 0
			return false
		13:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 14):
				return false
			_stage = 14
			_wait_frames = 0
			return false
		14:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			_check(inspectables.distinct_inspected_count() == 1 and not _panel_of(shell).is_open(), "A9: the first inspection records the id silently (no recognition yet)")
			# Repeat the same object: the effect (count == 1) is already true,
			# so this await releases immediately — the D1 idempotence proof.
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 15):
				return false
			_stage = 15
			_wait_frames = 0
			return false
		15:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			_check(inspectables.distinct_inspected_count() == 1 and inspectables.is_inspected("mark_stone_a"), "A9: repeating the SAME object never increases progress (D1 idempotent)")
			_check(not _panel_of(shell).is_open() and _inspection_emissions == 0, "A9: one distinct object never triggers the recognition or a completion request")
			var explorer := _explorer_of(shell)
			# --- A10: the second DISTINCT object opens the recognition (held
			# interact input for the whole window — the H14 contract inside
			# the uninterrupted full flow) ---
			_teleport(explorer, 630.0)
			Input.action_press("interact")
			_stage = 16
			_wait_frames = 0
			return false
		16:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var stage := _stage_node(shell)
			if not _await_held_interact_effect(func() -> bool: return _recognition_open(), 17):
				return false
			_mark_recognition_seen()
			# The recognition is open with the key still held. Assert the
			# whole D2/D5 window state before advancing.
			var state: NarrativeState = shell.call("narrative_state")
			var inspectables := _inspectables_of(shell)
			var panel := _panel_of(shell)
			var explorer := _explorer_of(shell)
			_check(_recognition_seen and panel.is_open() and panel.get_body_text().contains("I've seen this mark before..."), "A10: inspecting two DISTINCT objects opens the approved recognition line exactly once")
			_check(panel.get_body_text().contains("Why does it keep appearing?") or panel.get_body_text().contains("I've seen this mark before..."), "A10: the recognition presentation carries the approved Beat 04 candidate text")
			_check(inspectables.distinct_inspected_count() == 2 and inspectables.is_inspected("mark_fragment_b"), "A10: the second distinct id was recorded (2 distinct ids)")
			_check(stage.is_dialogue_locked() and not explorer.is_input_enabled() and not explorer.is_physics_processing(), "A10: the recognition locks the actor (movement blocked during the dialogue)")
			_check(not bool(state.is_completed(BEAT_04)) and _inspection_emissions == 0, "A10: the completion request fires only AFTER the dialogue closes (not at open)")
			# Hold movement during the recognition for the stillness proof.
			_drive_right(shell)
			_stage = 17
			_wait_frames = 0
			return false
		17:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if explorer == null:
				return false
			if _wait_frames < 15:
				return false
			_check(explorer.position.x == 630.0, "A10: the actor stays still during the recognition (held movement keys do not move it)")
			_stop_driving()
			# --- A11: dialogue closure -> exactly-once pl_04 completion ---
			_stage = 18
			_wait_frames = 0
			return false
		18:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel := _panel_of(shell)
			if panel.is_open():
				panel.advance()
				return false
			var stage := _stage_node(shell)
			var state: NarrativeState = shell.call("narrative_state")
			var explorer := _explorer_of(shell)
			_check(state.completed_count() == 4 and bool(state.is_completed(BEAT_04)), "A11: normal recognition closure completes pl_04 exactly once (state: pl_01..pl_04)")
			_check(stage.inspection_completed() and _inspection_emissions == 1, "A11: the stage emitted exactly its one pl_04 completion request, after the dialogue lifecycle")
			# N4.4-A: recording pl_04 ACTIVATES pl_05 (the O6 documented
			# default) — the segment stays live and the chain continues into
			# the ruins; the old defined boundary moved to the N4.4-D state.
			_check(String(shell.call("active_exploration_beat")) == BEAT_05 and not bool(shell.call("n43_segment_complete")), "A11: pl_04 completion activates pl_05 (the chain continues)")
			_check(explorer != null and explorer.is_input_enabled(), "A11: the ruins beat enables exploration input")
			_check(stage != null and not stage.is_dialogue_locked() and not stage.is_segment_ended(), "A11: the stage-owned actor lock is released and the segment stays live")
			_check(not _inspectables_of(shell).prompt().visible, "A11: no stale prompt leaks into pl_05")
			var runner: SequenceRunner = shell.call("sequence_runner")
			_check(not runner.is_control_locked() and not bool(shell.call("is_sequence_running")) and _completions == [BEAT_01, BEAT_02], "A11: the runner stayed out of exploration and the runner lock is released")
			var status: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
			_check(status != null and status.text.contains("Forgotten Ruins"), "A11: the status presents the ruins beat")
			_ui_button_on_screen(shell, "A11")
			_check(_inspectables_of(shell).distinct_inspected_count() == 2, "A11: the held interact key added NO second inspection across the recognition window (H14 inside the full flow)")
			# The held-input window is over: release the key explicitly.
			Input.action_release("interact")
			# --- A11b: drive east through the ruins to the altar ---
			_drive_right(shell)
			_stage = 19
			_wait_frames = 0
			return false
		19:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var stage := _stage_node(shell)
			var state: NarrativeState = shell.call("narrative_state")
			# Phase 1: drive east until the ONE natural altar completion lands.
			if not _a12_pressed:
				if _altar_emissions == 0 and _wait_frames < MAX_WAIT_FRAMES - 60:
					return false
				_stop_driving()
				_check(_altar_emissions == 1, "A11b: the stage emitted exactly its one pl_05 altar completion request (driving east reaches the altar)")
				_check(stage != null and stage.altar_request_emitted(), "A11b: the altar request stays single-shot (no re-emission)")
				_check(state.completed_count() == 5 and bool(state.is_completed(BEAT_05)), "A11b: reaching the altar completes pl_05 exactly once (state: pl_01..pl_05)")
				_check(String(shell.call("active_exploration_beat")) == BEAT_06 and not bool(shell.call("n43_segment_complete")), "A11b: pl_05 completion activates DORMANT pl_06 (segment stays live, no pl_06 content)")
				var explorer := _explorer_of(shell)
				_check(explorer != null and explorer.is_input_enabled(), "A11b: dormant pl_06 keeps exploration input enabled")
				var status: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
				_check(status != null and status.text.contains("Crown's Call"), "A11b: the status presents the dormant pl_06 beat")
				# --- A12: wrong-beat completion requests are ignored ---
				stage.exploration_handoff_reached.emit()
				stage.mark_inspection_completed.emit()
				stage.ruins_altar_reached.emit()
				_check(state.completed_count() == 5 and String(shell.call("active_exploration_beat")) == BEAT_06 and not bool(shell.call("n43_segment_complete")), "A12: late re-emitted completion requests are ignored by the shell (wrong active beat)")
				_check(_handoff_emissions + _inspection_emissions + _altar_emissions == 6, "A12: exactly the 3 natural + 3 forced completion requests were emitted (no unexpected extras)")
				Input.action_press("interact")
				_a12_pressed = true
				_a12_press_frame = _wait_frames
				return false
			# Phase 2: after a settle window, the dormant-pl_06 press is inert.
			if _wait_frames < _a12_press_frame + 5:
				return false
			Input.action_release("interact")
			_check(state.completed_count() == 5 and not _panel_of(shell).is_open() and not _inspectables_of(shell).prompt().visible, "A12: a post-completion interact press is structurally inert (dormant pl_06 polls nothing)")
			# --- A13: exit from the dormant pl_06 state ---
			_check(shell.call("request_main_menu_return"), "A13: the development exit works from the dormant pl_06 state")
			_check(_shell_exits.size() == 1 and String(_shell_exits[0]) == MAIN_MENU_SCENE, "A13: the exit transitions to the main menu exactly once")
			change_scene_to_file(MAIN_SCENE)
			_stage = 20
			_wait_frames = 0
			return false
		20:
			if not _on_main():
				return false
			# --- Shell B: the skip matrix (autostart off, explicit starts) ---
			Engine.set_meta(AUTOSTART_META, false)
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 21
			_wait_frames = 0
			return false
		21:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if not _check(shell.call("start_prologue"), "B1: the chain starts explicitly (idle shell)"):
				return true
			var panel := _panel_of(shell)
			var runner: SequenceRunner = shell.call("sequence_runner")
			_check(panel.is_open() and panel.get_body_text().contains("Long ago") and runner.is_control_locked(), "B1: pl_01 plays normally before the skip")
			shell.call("skip_sequence")
			_stage = 22
			_wait_frames = 0
			return false
		22:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not _completions.has(BEAT_01):
				return false
			_check(_completions == [BEAT_01], "B1: skipping pl_01 still completes it exactly once")
			var panel := _panel_of(shell)
			_check(panel.is_open() and panel.get_body_text().contains("Years ago"), "B1: the skipped pl_01 chains into pl_02")
			shell.call("skip_sequence")
			_stage = 23
			_wait_frames = 0
			return false
		23:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not bool(shell.call("in_exploration")):
				return false
			# --- B2/B3: skip semantics across the chain and the intro Skip ---
			_check(_completions == [BEAT_01, BEAT_02] and int(shell.call("completed_sequence_count")) == 2, "B2: skipping pl_02 completes it once and enters the exploration segment")
			_check(_cues == ["stage_pl01_prosperity", "stage_pl02_childhood"], "B2: a skip stages no cues AFTER the skip point (pl_01's eclipse/ruins and pl_02's resonance never played; already-played steps remain history)")
			var profile_fixture: String = FileAccess.get_file_as_string(PROFILE_FALSE)
			_check(profile_fixture == JSON.stringify({"schema_version": 1, "prologue_completed_once": false}, "\t"), "B2: Skip never touches the player profile fixture (no completion flag)")
			var state: NarrativeState = shell.call("narrative_state")
			var stage := _stage_node(shell)
			var panel := _panel_of(shell)
			_check(panel.is_open() and stage != null and stage.is_dialogue_locked(), "B3: the pl_03 intro dialogue is open and the actor locked before the Skip")
			_check(shell.call("skip_current_exploration_beat"), "B3: pl_03 Skip is accepted while the intro dialogue is open")
			_check(bool(state.is_completed(BEAT_03)) and state.completed_count() == 3, "B3: pl_03 Skip records pl_03 exactly once")
			_check(not panel.is_open() and not stage.is_dialogue_locked() and stage.is_input_enabled(), "B3: pl_03 Skip closes the dialogue and releases the actor lock with movement")
			_check(String(shell.call("active_exploration_beat")) == BEAT_04 and not bool(state.is_completed(BEAT_04)) and not bool(shell.call("n43_segment_complete")), "B3: pl_03 Skip activates pl_04 WITHOUT skipping it")
			_check(shell.call("skip_current_exploration_beat"), "B4: pl_04 Skip before any inspection is accepted")
			_stage = 24
			_wait_frames = 0
			return false
		24:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			var stage := _stage_node(shell)
			var explorer := _explorer_of(shell)
			_check(bool(state.is_completed(BEAT_04)) and state.completed_count() == 4, "B4: pl_04 Skip records pl_04 exactly once")
			# N4.4-A (O6 documented default): the pl_04 skip CONTINUES the chain
			# into pl_05 instead of ending the segment; the next skip is the
			# pl_05 skip, which records pl_05 once and activates DORMANT pl_06.
			_check(String(shell.call("active_exploration_beat")) == BEAT_05 and not bool(shell.call("n43_segment_complete")), "B4: pl_04 Skip activates pl_05 WITHOUT skipping it")
			_check(stage != null and not stage.is_segment_ended() and not stage.is_dialogue_locked() and not stage.inspection_completed(), "B4: no recognition ever staged and the segment stays live")
			_check(explorer == null or explorer.is_input_enabled(), "B4: the ruins beat enables exploration input")
			_check(_inspectables_of(shell).distinct_inspected_count() == 0 and not _recognition_seen and _inspection_emissions == 0, "B4: no inspection happened and no recognition/completion path ran")
			var status: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
			_check(status != null and status.text.contains("Forgotten Ruins"), "B4: the status presents the ruins beat")
			_check(shell.call("skip_current_exploration_beat"), "B4: the follow-up pl_05 Skip is accepted (the per-beat chain)")
			_check(bool(state.is_completed(BEAT_05)) and state.completed_count() == 5, "B4: pl_05 Skip records pl_05 exactly once")
			_check(String(shell.call("active_exploration_beat")) == BEAT_06 and not bool(shell.call("n43_segment_complete")), "B4: pl_05 Skip activates DORMANT pl_06 (segment stays live)")
			_check(stage != null and not stage.altar_request_emitted(), "B4: the skips record through the shell — the stage never emitted the altar request")
			_check(shell.call("skip_current_exploration_beat") and state.completed_count() == 6 and bool(state.is_completed(BEAT_06)) and bool(shell.call("n43_segment_complete")), "B4: pl_06 Skip records pl_06 once and ends at N4.4 boundary (O4 Option A)")
			_check(not shell.call("skip_current_exploration_beat") and state.completed_count() == 6, "B4: duplicate pl_06 Skip is rejected (never starts pl_07)")
			_check(shell.call("request_main_menu_return") and _shell_exits.size() == 1 and String(_shell_exits[0]) == MAIN_MENU_SCENE, "B4: the development exit transitions exactly once from the dormant pl_06 state")
			change_scene_to_file(MAIN_SCENE)
			_stage = 25
			_wait_frames = 0
			return false
		25:
			if not _on_main():
				return false
			# --- Shell B2: pl_04 Skip AFTER exactly one inspection ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 26
			_wait_frames = 0
			return false
		26:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "B5: the chain starts explicitly (Shell B2)"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			_check(shell.call("skip_current_exploration_beat") and String(shell.call("active_exploration_beat")) == BEAT_04, "B5: the shell reaches pl_04 via the pl_03 Skip (pl_04 not skipped)")
			_teleport(_explorer_of(shell), 430.0)
			Input.action_press("interact")
			_stage = 27
			_wait_frames = 0
			return false
		27:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 28):
				return false
			_stage = 28
			_wait_frames = 0
			return false
		28:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			var state: NarrativeState = shell.call("narrative_state")
			_check(inspectables.distinct_inspected_count() == 1 and not _recognition_seen, "B5: exactly one inspection is recorded (no recognition at 1 distinct)")
			_check(shell.call("skip_current_exploration_beat"), "B5: pl_04 Skip AFTER one inspection is accepted")
			_check(bool(state.is_completed(BEAT_04)) and state.completed_count() == 4 and String(shell.call("active_exploration_beat")) == BEAT_05, "B5: the Skip records pl_04 exactly once and activates pl_05 (O6 documented default)")
			_check(inspectables.distinct_inspected_count() == 1 and not _recognition_seen and _inspection_emissions == 0, "B5: the partial inspection never opened the recognition and emitted no completion request")
			_check(shell.call("skip_current_exploration_beat") and String(shell.call("active_exploration_beat")) == BEAT_06 and state.completed_count() == 5, "B5: the follow-up pl_05 Skip records pl_05 once and activates DORMANT pl_06")
			_check(shell.call("skip_current_exploration_beat") and state.completed_count() == 6 and bool(state.is_completed(BEAT_06)) and bool(shell.call("n43_segment_complete")), "B5: pl_06 Skip records pl_06 once and ends at N4.4 boundary (O4 Option A)")
			_check(not shell.call("skip_current_exploration_beat") and state.completed_count() == 6, "B5: duplicate pl_06 Skip is rejected (never starts pl_07)")
			_check(shell.call("request_main_menu_return") and _shell_exits.size() == 1 and String(_shell_exits[0]) == MAIN_MENU_SCENE, "B5: the development exit transitions exactly once")
			change_scene_to_file(MAIN_SCENE)
			_stage = 29
			_wait_frames = 0
			return false
		29:
			if not _on_main():
				return false
			# --- Shell B3: pl_04 Skip WHILE the recognition dialogue is open ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 30
			_wait_frames = 0
			return false
		30:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "B6: the chain starts explicitly (Shell B3)"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			var state: NarrativeState = shell.call("narrative_state")
			_check(shell.call("skip_current_exploration_beat") and String(shell.call("active_exploration_beat")) == BEAT_04 and state.completed_count() == 3, "B6: the shell reaches pl_04 (pl_03 skipped, pl_04 active)")
			_teleport(_explorer_of(shell), 430.0)
			Input.action_press("interact")
			_stage = 31
			_wait_frames = 0
			return false
		31:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 32):
				return false
			_stage = 32
			_wait_frames = 0
			return false
		32:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			_teleport(explorer, 630.0)
			Input.action_press("interact")
			_stage = 33
			_wait_frames = 0
			return false
		33:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var stage := _stage_node(shell)
			if not _await_held_interact_effect(func() -> bool: return _recognition_open(), 34):
				return false
			_mark_recognition_seen()
			var state: NarrativeState = shell.call("narrative_state")
			var panel := _panel_of(shell)
			var explorer := _explorer_of(shell)
			_check(_recognition_seen and panel.is_open() and panel.get_body_text().contains("I've seen this mark before...") and inspectables_of_count(shell) == 2, "B6: the recognition is open from two distinct inspections (key still held)")
			_check(stage.is_dialogue_locked() and not explorer.is_input_enabled(), "B6: the recognition holds the actor lock before the Skip")
			_check(shell.call("skip_current_exploration_beat"), "B6: pl_04 Skip is accepted WHILE the recognition dialogue is open")
			_check(not panel.is_open() and not stage.is_dialogue_locked(), "B6: the Skip closes the panel and releases the stage-owned actor lock")
			_check(bool(state.is_completed(BEAT_04)) and state.completed_count() == 4 and String(shell.call("active_exploration_beat")) == BEAT_05, "B6: the Skip itself records pl_04 exactly once and activates pl_05 (O6 documented default)")
			_check(explorer == null or explorer.is_input_enabled(), "B6: the ruins beat re-enables exploration input after the skip")
			_stage = 34
			_wait_frames = 0
			return false
		34:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			var stage := _stage_node(shell)
			if _wait_frames < 10:
				return false
			# The critical ordering proof: the recognition coroutine resumed
			# against a bumped generation and must NOT have emitted the
			# completion request — the recording belongs to the Skip alone.
			_check(_inspection_emissions == 0 and not stage.inspection_completed(), "B6: the resumed recognition coroutine emitted NO completion request after the Skip (stale generation)")
			_check(state.completed_count() == 4 and String(shell.call("active_exploration_beat")) == BEAT_05, "B6: no duplicate pl_04 recording lands after the settle window")
			Input.action_release("interact")
			_check(shell.call("request_main_menu_return") and _shell_exits.size() == 1 and String(_shell_exits[0]) == MAIN_MENU_SCENE, "B6: the development exit transitions exactly once")
			change_scene_to_file(MAIN_SCENE)
			_stage = 35
			_wait_frames = 0
			return false
		35:
			if not _on_main():
				return false
			# --- Shell C1: cancellation during pl_01 ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 36
			_wait_frames = 0
			return false
		36:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if not _check(shell.call("start_prologue"), "C1: the chain starts explicitly"):
				return true
			_stage = 37
			_wait_frames = 0
			return false
		37:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not bool(shell.call("is_sequence_running")):
				return false
			var panel := _panel_of(shell)
			_check(panel.is_open() and panel.get_body_text().contains("Long ago"), "C1: pl_01 is playing when the cancellation lands")
			shell.call("cancel_sequence")
			var state: NarrativeState = shell.call("narrative_state")
			var runner: SequenceRunner = shell.call("sequence_runner")
			_check(state.completed_count() == 0 and _completions.is_empty(), "C1: cancelling pl_01 records NOTHING (cancel is not a skip)")
			_check(not panel.is_open() and not runner.is_control_locked() and not bool(shell.call("is_sequence_running")), "C1: the cancellation closes the panel, releases the runner lock, and idles the runner")
			_check(shell.call("start_prologue"), "C1: the chain restarts after cancellation (non-resumable per-run state)")
			_stage = 38
			_wait_frames = 0
			return false
		38:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel := _panel_of(shell)
			if not panel.is_open():
				return false
			var state: NarrativeState = shell.call("narrative_state")
			_check(panel.get_body_text().contains("Long ago") and state.completed_count() == 0, "C1: the replay starts pl_01 from the beginning (nothing was recorded)")
			shell.call("skip_sequence")
			_stage = 39
			_wait_frames = 0
			return false
		39:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			# --- C2: cancellation during the pl_03 intro dialogue ---
			_captured_stage = _stage_node(shell)
			var explorer := _explorer_of(shell)
			var state: NarrativeState = shell.call("narrative_state")
			var panel := _panel_of(shell)
			_check(panel.is_open() and _captured_stage != null and _captured_stage.is_dialogue_locked(), "C2: the intro dialogue is open and locked before the cancellation")
			shell.call("cancel_sequence")
			_check(state.completed_count() == 2 and not bool(state.is_completed(BEAT_03)), "C2: cancelling the pl_03 intro records NOTHING (pl_03 stays uncompleted)")
			_check(_captured_stage.is_torn_down() and not _captured_stage.is_dialogue_locked(), "C2: the cancellation tears the stage down and releases the stage-owned actor lock")
			_check(explorer != null and not explorer.is_input_enabled() and not explorer.is_physics_processing(), "C2: exploration input is disabled and the actor frozen by the teardown")
			_check(shell.call("exploration_stage") == null and not bool(shell.call("in_exploration")), "C2: the shell dropped the exploration segment state")
			var status: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
			_check(status != null and status.text.contains("cancelled"), "C2: the cancelled state shows the defined idle status")
			_check(shell.call("request_main_menu_return") and _shell_exits.size() == 1 and String(_shell_exits[0]) == MAIN_MENU_SCENE, "C2: the development exit transitions exactly once after the cancellation")
			change_scene_to_file(MAIN_SCENE)
			_stage = 40
			_wait_frames = 0
			return false
		40:
			if not _on_main():
				return false
			# --- Shell C2: cancellation during pl_04 after one inspection ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 41
			_wait_frames = 0
			return false
		41:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "C3: the chain starts explicitly (Shell C2)"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), 430.0)
			Input.action_press("interact")
			_stage = 42
			_wait_frames = 0
			return false
		42:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 43):
				return false
			_stage = 43
			_wait_frames = 0
			return false
		43:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_captured_stage = _stage_node(shell)
			var explorer := _explorer_of(shell)
			var state: NarrativeState = shell.call("narrative_state")
			var inspectables := _inspectables_of(shell)
			_check(inspectables.distinct_inspected_count() == 1 and not _recognition_seen, "C3: one inspection is recorded before the cancellation (no recognition path)")
			shell.call("cancel_sequence")
			_check(state.completed_count() == 3 and not bool(state.is_completed(BEAT_04)), "C3: cancelling pl_04 after one inspection records NOTHING (pl_04 stays uncompleted)")
			_check(_captured_stage.is_torn_down() and not _captured_stage.is_dialogue_locked(), "C3: the cancellation tears the stage down and releases the lock")
			_check(explorer != null and not explorer.is_input_enabled() and not explorer.is_physics_processing(), "C3: the actor is frozen with input disabled")
			_check(not _panel_of(shell).is_open() and not _recognition_seen, "C3: the recognition never opened and the panel is closed")
			_check(shell.call("request_main_menu_return") and _shell_exits.size() == 1 and String(_shell_exits[0]) == MAIN_MENU_SCENE, "C3: the development exit transitions exactly once")
			change_scene_to_file(MAIN_SCENE)
			_stage = 44
			_wait_frames = 0
			return false
		44:
			if not _on_main():
				return false
			# --- Shell C3: cancellation DURING the recognition dialogue ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 45
			_wait_frames = 0
			return false
		45:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "C4: the chain starts explicitly (Shell C3)"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), 430.0)
			Input.action_press("interact")
			_stage = 46
			_wait_frames = 0
			return false
		46:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 47):
				return false
			_stage = 47
			_wait_frames = 0
			return false
		47:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_teleport(_explorer_of(shell), 630.0)
			Input.action_press("interact")
			_stage = 48
			_wait_frames = 0
			return false
		48:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not _await_held_interact_effect(func() -> bool: return _recognition_open(), 49):
				return false
			_mark_recognition_seen()
			_captured_stage = _stage_node(shell)
			_captured_explorer = _explorer_of(shell)
			var explorer := _explorer_of(shell)
			var state: NarrativeState = shell.call("narrative_state")
			# --- C4: the N4.3-B ordering contract inside the full flow: the
			# stage is torn down BEFORE the runner closes the shared panel ---
			shell.call("cancel_sequence")
			_check(not _panel_of(shell).is_open() and _captured_stage.is_torn_down(), "C4: the cancellation tears the stage down first and closes the recognition dialogue")
			_check(state.completed_count() == 3 and not bool(state.is_completed(BEAT_04)), "C4: cancelling DURING the recognition records NOTHING (pl_04 stays uncompleted)")
			_stage = 49
			_wait_frames = 0
			return false
		49:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			var stage: PrologueExplorationStage = _captured_stage
			var explorer: PrologueExplorer = _captured_explorer
			if _wait_frames < 10:
				return false
			_check(_inspection_emissions == 0 and not stage.inspection_completed(), "C4: the resumed recognition coroutine emitted NO completion request after the cancellation (stale generation guard)")
			_check(state.completed_count() == 3, "C4: no late pl_04 recording lands after the settle window")
			_check(not stage.is_dialogue_locked() and explorer != null and not explorer.is_input_enabled() and not explorer.is_physics_processing(), "C4: the lock is released and the actor frozen after the cancellation")
			_check(_completions == [BEAT_01, BEAT_02] and not bool(shell.call("is_sequence_running")), "C4: the runner recorded nothing and stays idle")
			Input.action_release("interact")
			_check(shell.call("request_main_menu_return") and _shell_exits.size() == 1 and String(_shell_exits[0]) == MAIN_MENU_SCENE, "C4: the development exit transitions exactly once")
			change_scene_to_file(MAIN_SCENE)
			_stage = 50
			_wait_frames = 0
			return false
		50:
			if not _on_main():
				return false
			# --- Shell C4: the development exit DURING the recognition dialogue ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 51
			_wait_frames = 0
			return false
		51:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "C5: the chain starts explicitly (Shell C4)"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), 430.0)
			Input.action_press("interact")
			_stage = 52
			_wait_frames = 0
			return false
		52:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 53):
				return false
			_stage = 53
			_wait_frames = 0
			return false
		53:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_teleport(_explorer_of(shell), 630.0)
			Input.action_press("interact")
			_stage = 54
			_wait_frames = 0
			return false
		54:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not _await_held_interact_effect(func() -> bool: return _recognition_open(), 55):
				return false
			_mark_recognition_seen()
			_captured_stage = _stage_node(shell)
			var state: NarrativeState = shell.call("narrative_state")
			# --- C5: the exit path runs the same ordering contract ---
			_check(shell.call("request_main_menu_return"), "C5: the development exit is accepted DURING the recognition dialogue")
			_check(_shell_exits.size() == 1 and String(_shell_exits[0]) == MAIN_MENU_SCENE, "C5: the exit transitions to the main menu exactly once")
			_check(state.completed_count() == 3 and not bool(state.is_completed(BEAT_04)), "C5: the exit records NOTHING (exit is not a skip)")
			_check(not _panel_of(shell).is_open() and _captured_stage.is_torn_down(), "C5: the exit tears the stage down first and closes the dialogue")
			_stage = 55
			_wait_frames = 0
			return false
		55:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			var stage: PrologueExplorationStage = _captured_stage
			if _wait_frames < 10:
				return false
			_check(_inspection_emissions == 0 and not stage.inspection_completed() and state.completed_count() == 3, "C5: no completion request lands after the exit's settle window (stale generation guard)")
			Input.action_release("interact")
			change_scene_to_file(MAIN_SCENE)
			_stage = 56
			_wait_frames = 0
			return false
		56:
			if not _on_main():
				return false
			# --- Shell C5: DIRECT scene unload during the recognition dialogue
			# (no cancel path, no exit call — pure unload coverage) ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 57
			_wait_frames = 0
			return false
		57:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "C6: the chain starts explicitly (Shell C5)"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), 430.0)
			Input.action_press("interact")
			_stage = 58
			_wait_frames = 0
			return false
		58:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 59):
				return false
			_stage = 59
			_wait_frames = 0
			return false
		59:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_teleport(_explorer_of(shell), 630.0)
			Input.action_press("interact")
			_stage = 60
			_wait_frames = 0
			return false
		60:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not _await_held_interact_effect(func() -> bool: return _recognition_open(), 61):
				return false
			_mark_recognition_seen()
			_captured_shell = _shell()
			_unloaded_state = shell.call("narrative_state")
			# --- C6: direct unload mid-recognition: the stage's _exit_tree
			# teardown must release everything and record nothing; the
			# suspended coroutine dies with the freed panel ---
			Input.action_release("interact")
			change_scene_to_file(MAIN_SCENE)
			_stage = 61
			_wait_frames = 0
			return false
		61:
			if not _on_main():
				return false
			_check(_unloaded_state != null and _unloaded_state.completed_count() == 3 and not bool(_unloaded_state.is_completed(BEAT_04)), "C6: the direct unload during recognition records NOTHING (unload is not a skip)")
			_check(not is_instance_valid(_captured_shell), "C6: the PrologueShell was freed by the direct unload")
			if _wait_frames < 10:
				return false
			_check(_unloaded_state.completed_count() == 3, "C6: no late completion lands after the unload's settle window (the coroutine died with the panel)")
			_unloaded_state = null
			# --- Shell D: failed exploration-stage setup (fail-closed) ---
			Engine.set_meta(STAGE_TEXTURE_META, "res://n43c_missing_texture.png")
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 62
			_wait_frames = 0
			return false
		62:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "D: the chain starts explicitly (Shell D)"):
					return true
			# The texture load fails, so the chain-end fallback runs instead of
			# the exploration segment: wait for pl_02's completion (the skip
			# path) — in_exploration NEVER becomes true in this shell.
			if not _completions.has(BEAT_02):
				_skip_runner_beat(shell)
				return false
			_stage = 63
			_wait_frames = 0
			return false
		63:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			var runner: SequenceRunner = shell.call("sequence_runner")
			_check(not bool(shell.call("in_exploration")) and shell.call("exploration_stage") == null, "D: failed stage setup enters NO exploration state")
			_check(state.completed_count() == 2 and not bool(state.is_completed(BEAT_03)) and not bool(state.is_completed(BEAT_04)), "D: failed setup records NO exploration completion (not a skip)")
			_check(bool(shell.call("prologue_reached_end")), "D: the structural chain end stays true after the fallback")
			_check(not runner.is_control_locked() and not bool(shell.call("is_sequence_running")), "D: failed setup leaves no control lock and an idle runner")
			var status: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
			_check(status != null and status.text.contains("No exploration segment is active"), "D: the fallback shows the defined idle boundary status")
			Engine.remove_meta(STAGE_TEXTURE_META)
			_check(shell.call("request_main_menu_return") and _shell_exits.size() == 1 and String(_shell_exits[0]) == MAIN_MENU_SCENE, "D: the development exit works from the failed-setup fallback")
			change_scene_to_file(MAIN_SCENE)
			_stage = 64
			_wait_frames = 0
			return false
		64:
			if not _on_main():
				return false
			# --- Hygiene: real files untouched, fixtures cleaned, metas
			# removed, no leaked input state ---
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
			_rm(PROFILE_FALSE)
			_rm(SAVE_NONE)
			_clean_fixture_sidecars()
			if DirAccess.dir_exists_absolute(TEST_DIR):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
			Engine.remove_meta(AUTOSTART_META)
			Engine.remove_meta(STAGE_TEXTURE_META)
			Engine.remove_meta("crownfall_profile_path")
			Engine.remove_meta("crownfall_menu_save_path")
			_check(not Input.is_action_pressed("interact"), "no interact input state leaks past the suite")
			_check(not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "no movement input state leaks past the suite")
			if _failures == 0:
				print("PASS: All %d N43C Full Flow checks completed with 0 failures." % _checks)
				quit(0)
			else:
				printerr("FAIL: N43C Full Flow finished with %d failures out of %d checks." % [_failures, _checks])
				quit(1)
			return true
	return false


## Typed accessor used inside stage lambdas (keeps them one-line).
func inspectables_of_count(shell: Control) -> int:
	return _inspectables_of(shell).distinct_inspected_count()
