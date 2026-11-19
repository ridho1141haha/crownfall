extends SceneTree

## N4.4-E Full-Flow Integration & Regression (pl_01 -> pl_06 -> N4.4 boundary).
##
## Drives the real Main.tscn -> PrologueShell.tscn -> SequenceRunner ->
## DialoguePanel -> PrologueExplorationStage -> PrologueRuinsEnvironment ->
## PrologueExplorer runtime integration with five scenario shells:
##   Shell A: Normal complete flow (pl_01..pl_06 -> N4.4 boundary -> dev exit)
##   Shell B: Skip matrix (pl_04 O6, pl_05, pl_06 before/after contact, during
##            vision via skip_current_exploration_beat & skip_sequence, during
##            post-vision dialogue, duplicate skips, profile non-mutation)
##   Shell C: Cancellation & teardown (pl_05, awakening, vision, post-vision
##            dialogue, dev exit during vision, direct scene unload during vision)
##   Shell D: Failed exploration-stage setup (fail-closed fallback boundary)
##   Shell E: Control lifecycle (unavailable -> enabled -> blocked -> restored ->
##            frozen), held interact through vision, overlay input non-consumption,
##            and real user file / input hygiene.

const PROLOGUE_SHELL_SCRIPT: GDScript = preload("res://scripts/narrative/PrologueShell.gd")
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const PROLOGUE_SHELL_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const TEST_DIR: String = "user://n44_full_flow_test"
const PROFILE_MISSING: String = "user://n44_full_flow_test/profile_missing.json"
const PROFILE_FALSE: String = "user://n44_full_flow_test/profile_false.json"
const SAVE_NONE: String = "user://n44_full_flow_test/save_none.json"
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
const MAX_WAIT_FRAMES: int = 2400
const INTERACT_RETRY_BUDGET_FRAMES: int = 40

const EXPECTED_VISION_CUES: Array[String] = [
	PrologueBeats.CUE_PL06_AWAKENING,
	PrologueBeats.CUE_PL06_VISION_KINGDOM,
	PrologueBeats.CUE_PL06_VISION_SILHOUETTE,
	PrologueBeats.CUE_PL06_VISION_SYMBOL,
	PrologueBeats.CUE_PL06_VISION_FADING_LIGHT,
	PrologueBeats.CUE_PL06_VISION_DESTRUCTION,
]
const R15_LINE_1: String = "What... was that?"
const R15_LINE_2: String = "I've never seen those places before."

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _shell_exits: Array[String] = []
var _completions: Array[String] = []
var _cues: Array[String] = []
var _handoff_emissions: int = 0
var _inspection_emissions: int = 0
var _altar_emissions: int = 0
var _chamber_revealed_count: int = 0
var _crown_completed_emissions: int = 0
var _wired_shell: Control = null
var _captured_shell: Control = null
var _captured_stage: PrologueExplorationStage = null
var _captured_explorer: PrologueExplorer = null
var _captured_ruins: PrologueRuinsEnvironment = null
var _unloaded_state: NarrativeState = null
var _custom_awakening_gen: int = 0
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
		printerr("TEST FAILURE: [test_n44_full_flow] " + msg)
		_release_all_inputs()
		quit(1)
		return false
	print("PASS: " + msg)
	return true


func _release_all_inputs() -> void:
	Input.action_release("interact")
	Input.action_release("move_left")
	Input.action_release("move_right")


func _snapshot_sidecar(path: String) -> Dictionary:
	var existed: bool = FileAccess.file_exists(path)
	var content: String = FileAccess.get_file_as_string(path) if existed else ""
	return {"existed": existed, "content": content}


func _assert_sidecar_untouched(path: String, snap: Dictionary, label: String) -> void:
	var still_existed: bool = FileAccess.file_exists(path)
	var content_now: String = FileAccess.get_file_as_string(path) if still_existed else ""
	_check(
		bool(snap["existed"]) == still_existed and content_now == String(snap["content"]),
		"%s was never modified by this suite" % label
	)


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
	if not _check(save_path != SaveManager.DEFAULT_SAVE_PATH and save_path.begins_with(TEST_DIR + "/"), "injected save path is isolated (%s)" % save_path):
		return false
	if not _check(profile_path != PlayerProfile.DEFAULT_PROFILE_PATH and profile_path.begins_with(TEST_DIR + "/"), "injected profile path is isolated (%s)" % profile_path):
		return false
	Engine.set_meta("crownfall_profile_path", profile_path)
	Engine.set_meta("crownfall_menu_save_path", save_path)
	return true


func _profile_flag_is_false() -> bool:
	if not FileAccess.file_exists(PROFILE_FALSE):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_FALSE))
	return parsed is Dictionary and not bool((parsed as Dictionary).get("prologue_completed_once", true))


func _on_main() -> bool:
	return current_scene != null and current_scene.name == "Main"


func _on_shell() -> bool:
	if current_scene == null or current_scene.name != "PrologueShell":
		return false
	return current_scene.get_script() == PROLOGUE_SHELL_SCRIPT


func _shell() -> Control:
	return current_scene as Control


func _stage_node(shell: Control) -> PrologueExplorationStage:
	return shell.call("exploration_stage") as PrologueExplorationStage


func _explorer_of(shell: Control) -> PrologueExplorer:
	var st := _stage_node(shell)
	return st.explorer() if st != null else null


func _inspectables_of(shell: Control) -> PrologueMarkInspectables:
	var st := _stage_node(shell)
	return st.inspectables() if st != null else null


func _ruins_of(shell: Control) -> PrologueRuinsEnvironment:
	var st := _stage_node(shell)
	return st.ruins() if st != null else null


func _panel_of(shell: Control) -> DialoguePanel:
	return shell.call("dialogue_panel") as DialoguePanel


func _vision_runner_of(shell: Control) -> SequenceRunner:
	return shell.call("vision_runner") as SequenceRunner


func _wire_shell_observers(shell: Control) -> void:
	_completions.clear()
	_shell_exits.clear()
	_cues.clear()
	_handoff_emissions = 0
	_inspection_emissions = 0
	_altar_emissions = 0
	_chamber_revealed_count = 0
	_crown_completed_emissions = 0
	_custom_awakening_gen = 0
	shell.call("set_exit_transition", func(scene_path: String) -> void: _shell_exits.append(scene_path))
	shell.call("set_cue_player", func(cue_id: String) -> void: _cues.append(cue_id))
	var runner: SequenceRunner = shell.call("sequence_runner")
	runner.sequence_completed.connect(func(sequence_id: String) -> void: _completions.append(sequence_id))


func _wire_stage_observers(st: PrologueExplorationStage) -> void:
	st.exploration_handoff_reached.connect(func() -> void: _handoff_emissions += 1)
	st.mark_inspection_completed.connect(func() -> void: _inspection_emissions += 1)
	st.ruins_altar_reached.connect(func() -> void: _altar_emissions += 1)
	st.crown_awakening_completed.connect(func() -> void: _crown_completed_emissions += 1)
	var ruins := st.ruins()
	if ruins != null:
		ruins.chamber_revealed.connect(func() -> void: _chamber_revealed_count += 1)


func _advance_if_open(shell: Control) -> void:
	var panel := _panel_of(shell)
	if panel.is_open():
		panel.advance()


func _skip_runner_beat(shell: Control) -> void:
	if bool(shell.call("is_sequence_running")):
		shell.call("skip_sequence")


func _teleport(explorer: PrologueExplorer, x: float) -> void:
	explorer.position = Vector2(x, PrologueExplorationStage.GROUND_Y)


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
		_check(false, "%s: DevExitButton node is missing" % label)
		return
	var view: Rect2 = Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var rect := _button_screen_rect(button)
	_check(view.encloses(rect.grow(-2.0)), "%s: DevExitButton stays on-screen (camera-immune; measured %s)" % [label, rect])


func _await_interact_effect(has_effect: Callable, next_stage: int) -> bool:
	if has_effect.call():
		Input.action_release("interact")
		_stage = next_stage
		_wait_frames = 0
		return true
	if _wait_frames > INTERACT_RETRY_BUDGET_FRAMES:
		Input.action_release("interact")
		_check(false, "interact press produced no effect within retry budget (stage %d)" % _stage)
		return true
	Input.action_release("interact")
	Input.action_press("interact")
	return false


func _await_held_interact_effect(has_effect: Callable, next_stage: int) -> bool:
	if has_effect.call():
		_stage = next_stage
		_wait_frames = 0
		return true
	if _wait_frames > INTERACT_RETRY_BUDGET_FRAMES:
		Input.action_release("interact")
		_check(false, "held interact press produced no effect within retry budget (stage %d)" % _stage)
		return true
	return false


func _cues_contain_subsequence(recorded: Array[String], expected: Array[String]) -> bool:
	var idx: int = 0
	for cue_id: String in recorded:
		if idx < expected.size() and cue_id == expected[idx]:
			idx += 1
	return idx == expected.size()


func _next_stage(n: int) -> void:
	_stage = n
	_wait_frames = 0


func _go_main(next_s: int) -> void:
	_release_all_inputs()
	_wired_shell = null
	change_scene_to_file(MAIN_SCENE)
	_next_stage(next_s)


func _go_shell(next_s: int) -> void:
	_wired_shell = null
	change_scene_to_file(PROLOGUE_SHELL_SCENE)
	_next_stage(next_s)


func _initialize() -> void:
	_prepare_fixtures()
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
	if not _set_metas(PROFILE_FALSE, SAVE_NONE):
		return
	Engine.set_meta(AUTOSTART_META, false)
	_stage = 1
	change_scene_to_file(MAIN_SCENE)


func _process(_delta: float) -> bool:
	_wait_frames += 1
	if _wait_frames > MAX_WAIT_FRAMES:
		_check(false, "timed out at stage %d" % _stage)
		return true
	match _stage:
		# =====================================================================
		# SHELL A: Normal complete flow (pl_01 -> pl_06 -> N4.4 boundary)
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
			_wired_shell = shell
			_wire_shell_observers(shell)
			if not _check(shell.call("start_prologue"), "Shell A: start_prologue starts pl_01"):
				return true
			var panel := _panel_of(shell)
			var runner: SequenceRunner = shell.call("sequence_runner")
			_check(panel.is_open() and panel.get_body_text().contains("Long ago"), "Shell A: pl_01 opens first dialogue line")
			_check(runner.is_control_locked(), "Shell A: runner locks control during pl_01")
			_check(shell.call("exploration_stage") == null and not bool(shell.call("in_exploration")), "Shell A: no exploration stage during pl_01")
			_check(_cues == [PrologueBeats.CUE_PL01_PROSPERITY], "Shell A: pl_01 opening cue staged first")
			_next_stage(3)
			return false
		3:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _completions.has(BEAT_01):
				_advance_if_open(shell)
				return false
			_check(_completions == [BEAT_01], "Shell A: pl_01 completed exactly once")
			_check(_panel_of(shell).is_open() and _panel_of(shell).get_body_text().contains("Years ago"), "Shell A: pl_02 chained after pl_01")
			_check(_cues == [
				PrologueBeats.CUE_PL01_PROSPERITY,
				PrologueBeats.CUE_PL01_ECLIPSE,
				PrologueBeats.CUE_PL01_RUINS,
				PrologueBeats.CUE_PL02_CHILDHOOD,
			], "Shell A: pl_01/pl_02 cue ordering is exact")
			_next_stage(4)
			return false
		4:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _completions.has(BEAT_02):
				_advance_if_open(shell)
				return false
			var st := _stage_node(shell)
			var explorer := _explorer_of(shell)
			_check(_completions == [BEAT_01, BEAT_02], "Shell A: pl_02 completed exactly once")
			_check(_cues.has(PrologueBeats.CUE_PL02_RESONANCE), "Shell A: pl_02 resonance cue staged")
			_check(bool(shell.call("in_exploration")) and String(shell.call("active_exploration_beat")) == BEAT_03, "Shell A: exploration enters pl_03 after pl_02")
			_check(st != null and explorer != null, "Shell A: exploration stage and explorer built")
			_check(_panel_of(shell).is_open() and st.is_dialogue_locked() and not explorer.is_input_enabled(), "Shell A: pl_03 intro locks actor and disables input")
			_wire_stage_observers(st)
			_next_stage(5)
			return false
		5:
			if not _on_shell():
				return false
			var shell := _shell()
			if _panel_of(shell).is_open():
				_advance_if_open(shell)
				return false
			var st := _stage_node(shell)
			var explorer := _explorer_of(shell)
			var state: NarrativeState = shell.call("narrative_state")
			_check(explorer.is_input_enabled() and not st.is_dialogue_locked(), "Shell A: control hands off after pl_03 intro closes")
			_check(not bool(state.is_completed(BEAT_03)), "Shell A: pl_03 not recorded before reaching handoff")
			Input.action_press("move_right")
			_next_stage(6)
			return false
		6:
			if not _on_shell():
				return false
			var shell := _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(state.is_completed(BEAT_03)):
				return false
			Input.action_release("move_right")
			_check(_handoff_emissions == 1, "Shell A: pl_03 handoff emitted once")
			_check(state.completed_count() == 3 and String(shell.call("active_exploration_beat")) == BEAT_04, "Shell A: pl_03 recorded once and pl_04 activated")
			_teleport(_explorer_of(shell), 430.0)
			Input.action_press("interact")
			_next_stage(7)
			return false
		7:
			if not _on_shell():
				return false
			var inspectables := _inspectables_of(_shell())
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 8):
				return false
			return false
		8:
			if not _on_shell():
				return false
			_teleport(_explorer_of(_shell()), 630.0)
			Input.action_press("interact")
			_next_stage(9)
			return false
		9:
			if not _on_shell():
				return false
			var panel := _panel_of(_shell())
			if not _await_interact_effect(func() -> bool: return panel.is_open(), 10):
				return false
			return false
		10:
			if not _on_shell():
				return false
			var shell := _shell()
			if _panel_of(shell).is_open():
				_advance_if_open(shell)
				return false
			var state: NarrativeState = shell.call("narrative_state")
			var ruins := _ruins_of(shell)
			_check(_inspection_emissions == 1 and bool(state.is_completed(BEAT_04)) and state.completed_count() == 4, "Shell A: pl_04 recorded once after recognition closes")
			_check(String(shell.call("active_exploration_beat")) == BEAT_05 and _explorer_of(shell).is_input_enabled(), "Shell A: pl_05 activated with control restored")
			_check(ruins != null and ruins.zone_state() == PrologueRuinsEnvironment.ZONE_EXTERIOR, "Shell A: ruins start in exterior zone")
			_teleport(_explorer_of(shell), 1500.0)
			_next_stage(11)
			return false
		11:
			if not _on_shell():
				return false
			var shell := _shell()
			var ruins := _ruins_of(shell)
			if ruins.zone_state() != PrologueRuinsEnvironment.ZONE_INTERIOR_PASSAGE:
				return false
			_check(ruins.zone_state() == PrologueRuinsEnvironment.ZONE_INTERIOR_PASSAGE, "Shell A: ruins transition to interior passage")
			_teleport(_explorer_of(shell), 1830.0)
			_next_stage(12)
			return false
		12:
			if not _on_shell():
				return false
			var shell := _shell()
			var ruins := _ruins_of(shell)
			if not ruins.is_chamber_revealed():
				return false
			_check(ruins.zone_state() == PrologueRuinsEnvironment.ZONE_CHAMBER_REVEALED and _chamber_revealed_count == 1, "Shell A: hidden chamber reveals once")
			_teleport(_explorer_of(shell), 1980.0)
			Input.action_press("move_right")
			_next_stage(13)
			return false
		13:
			if not _on_shell():
				return false
			var shell := _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(state.is_completed(BEAT_05)):
				return false
			Input.action_release("move_right")
			_check(_altar_emissions == 1 and state.completed_count() == 5, "Shell A: pl_05 recorded exactly once at altar threshold")
			_check(String(shell.call("active_exploration_beat")) == BEAT_06, "Shell A: pl_06 activated after pl_05")
			_ui_button_on_screen(shell, "Shell A")
			_teleport(_explorer_of(shell), _ruins_of(shell).altar_x())
			_next_stage(14)
			return false
		14:
			if not _on_shell():
				return false
			var shell := _shell()
			var ruins := _ruins_of(shell)
			if not ruins.is_crown_prompt_visible():
				return false
			_check(ruins.crown_prompt().text == PrologueBeats.ALTAR_PROMPT_PROPOSAL_TEXT, "Shell A: crown prompt uses O5 provisional text")
			Input.action_press("interact")
			_next_stage(15)
			return false
		15:
			if not _on_shell():
				return false
			var shell := _shell()
			var ruins := _ruins_of(shell)
			if not _await_interact_effect(func() -> bool: return ruins.is_crown_consumed() and bool(shell.call("is_awakening_handoff_active")), 16):
				return false
			var st := _stage_node(shell)
			_check(st.is_awakening_locked() and not _explorer_of(shell).is_input_enabled(), "Shell A: crown contact locks actor and disables input")
			_check(not ruins.is_crown_prompt_visible(), "Shell A: crown prompt hidden during awakening/vision")
			_check(_vision_runner_of(shell).is_running(), "Shell A: vision runner is active")
			return false
		16:
			if not _on_shell():
				return false
			var shell := _shell()
			var panel := _panel_of(shell)
			if not panel.is_open():
				return false
			var ruins := _ruins_of(shell)
			var state: NarrativeState = shell.call("narrative_state")
			_check(not ruins.is_vision_overlay_visible(), "Shell A: vision ends abruptly before post-vision dialogue (R14)")
			_check(_cues_contain_subsequence(_cues, EXPECTED_VISION_CUES), "Shell A: awakening + 5 canonical R12 vision fragments played in exact order")
			_check(not bool(state.is_completed(BEAT_06)), "Shell A: pl_06 not recorded while post-vision dialogue is open")
			_check(panel.get_body_text() == R15_LINE_1, "Shell A: post-vision line 1 matches approved R15 verbatim")
			panel.advance()
			_check(panel.is_open() and panel.get_body_text() == R15_LINE_2, "Shell A: post-vision line 2 matches approved R15 verbatim")
			_check(not bool(state.is_completed(BEAT_06)), "Shell A: pl_06 still unrecorded before final line closes")
			panel.advance()
			_next_stage(17)
			return false
		17:
			if not _on_shell():
				return false
			var shell := _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(state.is_completed(BEAT_06)):
				return false
			var st := _stage_node(shell)
			var ruins := _ruins_of(shell)
			var explorer := _explorer_of(shell)
			var status: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
			_check(_crown_completed_emissions == 1, "Shell A: crown_awakening_completed emitted exactly once")
			_check(state.completed_count() == 6 and bool(state.is_completed(BEAT_06)), "Shell A: pl_06 recorded exactly once (total 6 beats)")
			_check(_completions == [BEAT_01, BEAT_02], "Shell A: SequenceRunner completions remain [pl_01, pl_02] (PrologueShell sole writer)")
			_check(String(shell.call("active_exploration_beat")) == "" and bool(shell.call("n43_segment_complete")) and st.is_segment_ended(), "Shell A: N4.4 boundary reached cleanly")
			_check(not explorer.is_input_enabled() and not st.is_actor_locked() and not _panel_of(shell).is_open(), "Shell A: boundary leaves input disabled, locks released, dialogue closed")
			_check(not ruins.is_crown_prompt_visible() and not ruins.is_vision_overlay_visible() and not _vision_runner_of(shell).is_running(), "Shell A: boundary hides prompt/overlay and vision runner idle")
			_check(status != null and status.text.contains("pl_01-pl_06") and status.text.contains("pl_07+"), "Shell A: N4.4 boundary status updated and pl_07 never started")
			_check(bool(shell.call("request_main_menu_return")) and not bool(shell.call("request_main_menu_return")) and _shell_exits == [MAIN_MENU_SCENE], "Shell A: development exit transitions exactly once")
			_go_main(20)
			return false

		# =====================================================================
		# SHELL B: Skip matrix (B1..B4)
		# =====================================================================
		20:
			if not _on_main():
				return false
			_go_shell(21)
			return false
		21:
			# B1: pl_04 O6 skip, pl_05 skip, pl_06 skip before crown contact, duplicate skip
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "Shell B1: start_prologue starts chain"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			var state: NarrativeState = shell.call("narrative_state")
			var st := _stage_node(shell)
			var ruins := _ruins_of(shell)
			_check(bool(shell.call("skip_current_exploration_beat")) and String(shell.call("active_exploration_beat")) == BEAT_04, "Shell B1: pl_03 skip activates pl_04")
			_check(bool(shell.call("skip_current_exploration_beat")) and bool(state.is_completed(BEAT_04)) and String(shell.call("active_exploration_beat")) == BEAT_05 and not bool(shell.call("n43_segment_complete")), "Shell B1: pl_04 skip follows approved O6 (activates pl_05)")
			_check(bool(shell.call("skip_current_exploration_beat")) and bool(state.is_completed(BEAT_05)) and String(shell.call("active_exploration_beat")) == BEAT_06 and not bool(shell.call("n43_segment_complete")), "Shell B1: pl_05 skip records once and activates pl_06")
			_check(bool(shell.call("skip_current_exploration_beat")) and bool(state.is_completed(BEAT_06)) and state.completed_count() == 6 and bool(shell.call("n43_segment_complete")), "Shell B1: pl_06 skip before crown contact records once and reaches N4.4 boundary")
			_check(not st.is_actor_locked() and not _explorer_of(shell).is_input_enabled() and not ruins.is_crown_prompt_visible(), "Shell B1: boundary state clean after pre-contact skip")
			_check(not bool(shell.call("skip_current_exploration_beat")) and state.completed_count() == 6, "Shell B1: duplicate pl_06 skip rejected without mutation")
			_check(_profile_flag_is_false(), "Shell B1: skip never mutates player profile completion flag")
			_go_main(22)
			return false
		22:
			if not _on_main():
				return false
			_go_shell(23)
			return false
		23:
			# B2: pl_06 skip AFTER crown contact / during vision (via skip_current_exploration_beat)
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "Shell B2: start_prologue starts chain"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			_wire_stage_observers(_stage_node(shell))
			shell.call("skip_current_exploration_beat")
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), 1830.0)
			_next_stage(24)
			return false
		24:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _ruins_of(shell).is_chamber_revealed():
				return false
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), _ruins_of(shell).altar_x())
			Input.action_press("interact")
			_next_stage(25)
			return false
		25:
			if not _on_shell():
				return false
			var shell := _shell()
			var ruins := _ruins_of(shell)
			if not _await_interact_effect(func() -> bool: return ruins.is_crown_consumed() and _vision_runner_of(shell).is_running(), 26):
				return false
			return false
		26:
			if not _on_shell():
				return false
			var shell := _shell()
			var state: NarrativeState = shell.call("narrative_state")
			var st := _stage_node(shell)
			var ruins := _ruins_of(shell)
			_check(bool(shell.call("skip_current_exploration_beat")), "Shell B2: pl_06 skip accepted during vision playback")
			_check(bool(state.is_completed(BEAT_06)) and state.completed_count() == 6 and bool(shell.call("n43_segment_complete")), "Shell B2: pl_06 recorded once and boundary reached on vision skip")
			_check(not _vision_runner_of(shell).is_running() and not ruins.is_vision_overlay_visible() and not st.is_actor_locked(), "Shell B2: vision stopped, overlay hidden, locks released")
			_check(not bool(shell.call("skip_current_exploration_beat")) and state.completed_count() == 6, "Shell B2: duplicate skip after vision skip rejected")
			_next_stage(27)
			return false
		27:
			if not _on_shell():
				return false
			if _wait_frames < 12:
				return false
			var shell := _shell()
			_check(_crown_completed_emissions == 0 and not _panel_of(shell).is_open(), "Shell B2: no stale callback or dialogue after vision skip")
			_go_main(28)
			return false
		28:
			if not _on_main():
				return false
			_go_shell(29)
			return false
		29:
			# B3: pl_06 skip during vision via shell.skip_sequence()
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "Shell B3: start_prologue starts chain"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			shell.call("skip_current_exploration_beat")
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), 1830.0)
			_next_stage(30)
			return false
		30:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _ruins_of(shell).is_chamber_revealed():
				return false
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), _ruins_of(shell).altar_x())
			Input.action_press("interact")
			_next_stage(31)
			return false
		31:
			if not _on_shell():
				return false
			var shell := _shell()
			var ruins := _ruins_of(shell)
			if not _await_interact_effect(func() -> bool: return ruins.is_crown_consumed() and _vision_runner_of(shell).is_running(), 32):
				return false
			return false
		32:
			if not _on_shell():
				return false
			var shell := _shell()
			var state: NarrativeState = shell.call("narrative_state")
			shell.call("skip_sequence")
			_check(bool(state.is_completed(BEAT_06)) and state.completed_count() == 6 and bool(shell.call("n43_segment_complete")), "Shell B3: skip_sequence() during vision completes pl_06 once and reaches boundary")
			_check(not _vision_runner_of(shell).is_running() and not _ruins_of(shell).is_vision_overlay_visible(), "Shell B3: vision stopped and overlay hidden via skip_sequence()")
			_go_main(33)
			return false
		33:
			if not _on_main():
				return false
			_go_shell(34)
			return false
		34:
			# B4: pl_06 skip DURING post-vision dialogue
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "Shell B4: start_prologue starts chain"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			_wire_stage_observers(_stage_node(shell))
			shell.call("skip_current_exploration_beat")
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), 1830.0)
			_next_stage(35)
			return false
		35:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _ruins_of(shell).is_chamber_revealed():
				return false
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), _ruins_of(shell).altar_x())
			Input.action_press("interact")
			_next_stage(36)
			return false
		36:
			if not _on_shell():
				return false
			var shell := _shell()
			var ruins := _ruins_of(shell)
			if not _await_interact_effect(func() -> bool: return ruins.is_crown_consumed() and _vision_runner_of(shell).is_running(), 37):
				return false
			return false
		37:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _panel_of(shell).is_open():
				return false
			var state: NarrativeState = shell.call("narrative_state")
			var st := _stage_node(shell)
			_check(not bool(state.is_completed(BEAT_06)), "Shell B4: pl_06 unrecorded while post-vision dialogue open")
			_check(bool(shell.call("skip_current_exploration_beat")), "Shell B4: pl_06 skip accepted during post-vision dialogue")
			_check(bool(state.is_completed(BEAT_06)) and state.completed_count() == 6 and not _panel_of(shell).is_open() and not st.is_actor_locked(), "Shell B4: post-vision dialogue skip records once, closes UI, releases locks")
			_check(not bool(shell.call("skip_current_exploration_beat")) and state.completed_count() == 6, "Shell B4: duplicate skip rejected")
			_next_stage(38)
			return false
		38:
			if not _on_shell():
				return false
			if _wait_frames < 10:
				return false
			_check(_crown_completed_emissions == 0, "Shell B4: resumed dialogue coroutine does not emit after skip")
			_check(_profile_flag_is_false(), "Shell B4: profile completion flag remains false across all skips")
			_go_main(40)
			return false

		# =====================================================================
		# SHELL C: Cancellation & teardown (C1..C6)
		# =====================================================================
		40:
			if not _on_main():
				return false
			_go_shell(41)
			return false
		41:
			# C1: Cancellation during pl_05
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "Shell C1: start_prologue starts chain"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			shell.call("skip_current_exploration_beat")
			shell.call("skip_current_exploration_beat")
			var state: NarrativeState = shell.call("narrative_state")
			_captured_stage = _stage_node(shell)
			_captured_explorer = _explorer_of(shell)
			shell.call("cancel_sequence")
			_check(state.completed_count() == 4 and not bool(state.is_completed(BEAT_05)), "Shell C1: cancel during pl_05 records nothing")
			_check(not _captured_stage.is_actor_locked() and not _captured_explorer.is_input_enabled() and not bool(shell.call("in_exploration")), "Shell C1: cancel during pl_05 releases locks and tears down stage")
			_go_main(42)
			return false
		42:
			if not _on_main():
				return false
			_go_shell(43)
			return false
		43:
			# C2: Cancellation during awakening window (before vision finishes)
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "Shell C2: start_prologue starts chain"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			shell.call("set_awakening_vision_starter", func(gen: int) -> bool:
				_custom_awakening_gen = gen
				return true
			)
			shell.call("skip_current_exploration_beat")
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), 1830.0)
			_next_stage(44)
			return false
		44:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _ruins_of(shell).is_chamber_revealed():
				return false
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), _ruins_of(shell).altar_x())
			Input.action_press("interact")
			_next_stage(45)
			return false
		45:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _await_interact_effect(func() -> bool: return _custom_awakening_gen > 0 and bool(shell.call("is_awakening_handoff_active")), 46):
				return false
			return false
		46:
			if not _on_shell():
				return false
			var shell := _shell()
			var state: NarrativeState = shell.call("narrative_state")
			_captured_stage = _stage_node(shell)
			_captured_ruins = _ruins_of(shell)
			shell.call("cancel_sequence")
			_check(state.completed_count() == 5 and not bool(state.is_completed(BEAT_06)), "Shell C2: cancel during awakening records nothing")
			_check(not _captured_stage.is_actor_locked() and not _captured_stage.is_awakening_generation_current(_custom_awakening_gen), "Shell C2: awakening lock released and generation invalidated")
			_check(not _captured_ruins.is_crown_prompt_visible() and not _captured_ruins.is_vision_overlay_visible(), "Shell C2: prompt and overlay hidden on awakening cancel")
			_captured_stage.present_post_vision_dialogue(_custom_awakening_gen)
			_check(not _panel_of(shell).is_open() and state.completed_count() == 5, "Shell C2: stale awakening generation rejected by guard")
			_go_main(47)
			return false
		47:
			if not _on_main():
				return false
			_go_shell(48)
			return false
		48:
			# C3: Cancellation during vision playback
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "Shell C3: start_prologue starts chain"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			_wire_stage_observers(_stage_node(shell))
			shell.call("skip_current_exploration_beat")
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), 1830.0)
			_next_stage(49)
			return false
		49:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _ruins_of(shell).is_chamber_revealed():
				return false
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), _ruins_of(shell).altar_x())
			Input.action_press("interact")
			_next_stage(50)
			return false
		50:
			if not _on_shell():
				return false
			var shell := _shell()
			var ruins := _ruins_of(shell)
			if not _await_interact_effect(func() -> bool: return ruins.is_crown_consumed() and _vision_runner_of(shell).is_running(), 51):
				return false
			return false
		51:
			if not _on_shell():
				return false
			var shell := _shell()
			var state: NarrativeState = shell.call("narrative_state")
			_captured_stage = _stage_node(shell)
			_captured_ruins = _ruins_of(shell)
			shell.call("cancel_sequence")
			_check(state.completed_count() == 5 and not bool(state.is_completed(BEAT_06)), "Shell C3: cancel during vision records nothing")
			_check(not _vision_runner_of(shell).is_running() and not _captured_stage.is_actor_locked(), "Shell C3: vision runner stopped and locks released")
			_check(not _captured_ruins.is_vision_overlay_visible() and not _captured_ruins.is_crown_prompt_visible(), "Shell C3: overlay and prompt hidden on vision cancel")
			_next_stage(52)
			return false
		52:
			if not _on_shell():
				return false
			if _wait_frames < 15:
				return false
			var shell := _shell()
			var state: NarrativeState = shell.call("narrative_state")
			_check(state.completed_count() == 5 and not _panel_of(shell).is_open() and _crown_completed_emissions == 0, "Shell C3: no stale callback or dialogue after vision cancel")
			_go_main(53)
			return false
		53:
			if not _on_main():
				return false
			_go_shell(54)
			return false
		54:
			# C4: Cancellation during post-vision dialogue
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "Shell C4: start_prologue starts chain"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			_wire_stage_observers(_stage_node(shell))
			shell.call("skip_current_exploration_beat")
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), 1830.0)
			_next_stage(55)
			return false
		55:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _ruins_of(shell).is_chamber_revealed():
				return false
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), _ruins_of(shell).altar_x())
			Input.action_press("interact")
			_next_stage(56)
			return false
		56:
			if not _on_shell():
				return false
			var shell := _shell()
			var ruins := _ruins_of(shell)
			if not _await_interact_effect(func() -> bool: return ruins.is_crown_consumed() and _vision_runner_of(shell).is_running(), 57):
				return false
			return false
		57:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _panel_of(shell).is_open():
				return false
			var state: NarrativeState = shell.call("narrative_state")
			_captured_stage = _stage_node(shell)
			shell.call("cancel_sequence")
			_check(state.completed_count() == 5 and not bool(state.is_completed(BEAT_06)), "Shell C4: cancel during post-vision dialogue records nothing")
			_check(not _panel_of(shell).is_open() and not _captured_stage.is_actor_locked(), "Shell C4: dialogue closed and locks released on cancel")
			_next_stage(58)
			return false
		58:
			if not _on_shell():
				return false
			if _wait_frames < 10:
				return false
			var state: NarrativeState = _shell().call("narrative_state")
			_check(state.completed_count() == 5 and _crown_completed_emissions == 0, "Shell C4: resumed dialogue coroutine emits nothing after cancel")
			_go_main(59)
			return false
		59:
			if not _on_main():
				return false
			_go_shell(60)
			return false
		60:
			# C5: Development exit during vision
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "Shell C5: start_prologue starts chain"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			shell.call("skip_current_exploration_beat")
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), 1830.0)
			_next_stage(61)
			return false
		61:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _ruins_of(shell).is_chamber_revealed():
				return false
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), _ruins_of(shell).altar_x())
			Input.action_press("interact")
			_next_stage(62)
			return false
		62:
			if not _on_shell():
				return false
			var shell := _shell()
			var ruins := _ruins_of(shell)
			if not _await_interact_effect(func() -> bool: return ruins.is_crown_consumed() and _vision_runner_of(shell).is_running(), 63):
				return false
			return false
		63:
			if not _on_shell():
				return false
			var shell := _shell()
			var state: NarrativeState = shell.call("narrative_state")
			_captured_stage = _stage_node(shell)
			_captured_ruins = _ruins_of(shell)
			_check(bool(shell.call("request_main_menu_return")) and not bool(shell.call("request_main_menu_return")), "Shell C5: dev exit during vision transitions once")
			_check(_shell_exits == [MAIN_MENU_SCENE], "Shell C5: dev exit targets Main menu only")
			_check(state.completed_count() == 5 and not bool(state.is_completed(BEAT_06)), "Shell C5: dev exit during vision records nothing")
			_check(not _vision_runner_of(shell).is_running() and not _captured_stage.is_actor_locked() and not _captured_ruins.is_vision_overlay_visible(), "Shell C5: dev exit cleans runner, locks, and overlay")
			_go_main(64)
			return false
		64:
			if not _on_main():
				return false
			_go_shell(65)
			return false
		65:
			# C6: Direct scene unload during vision
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "Shell C6: start_prologue starts chain"):
					return true
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			shell.call("skip_current_exploration_beat")
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), 1830.0)
			_next_stage(66)
			return false
		66:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _ruins_of(shell).is_chamber_revealed():
				return false
			shell.call("skip_current_exploration_beat")
			_teleport(_explorer_of(shell), _ruins_of(shell).altar_x())
			Input.action_press("interact")
			_next_stage(67)
			return false
		67:
			if not _on_shell():
				return false
			var shell := _shell()
			var ruins := _ruins_of(shell)
			if not _await_interact_effect(func() -> bool: return ruins.is_crown_consumed() and _vision_runner_of(shell).is_running(), 68):
				return false
			return false
		68:
			if not _on_shell():
				return false
			var shell := _shell()
			_captured_shell = shell
			_unloaded_state = shell.call("narrative_state")
			_go_main(69)
			return false
		69:
			if not _on_main():
				return false
			if _wait_frames < 15:
				return false
			_check(not is_instance_valid(_captured_shell), "Shell C6: PrologueShell freed by direct scene unload")
			_check(_unloaded_state != null and _unloaded_state.completed_count() == 5 and not bool(_unloaded_state.is_completed(BEAT_06)), "Shell C6: direct unload during vision records nothing and survives settle window")
			_unloaded_state = null
			_captured_shell = null
			# =====================================================================
			# SHELL D: Failed setup (component-build failure -> fallback boundary)
			# =====================================================================
			Engine.set_meta(STAGE_TEXTURE_META, "res://n44e_missing_texture.png")
			_go_shell(70)
			return false
		70:
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "Shell D: start_prologue starts chain under induced failure"):
					return true
			if not _completions.has(BEAT_02):
				_skip_runner_beat(shell)
				return false
			_next_stage(71)
			return false
		71:
			if not _on_shell():
				return false
			var shell := _shell()
			var state: NarrativeState = shell.call("narrative_state")
			var runner: SequenceRunner = shell.call("sequence_runner")
			var status: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
			_check(not bool(shell.call("in_exploration")) and shell.call("exploration_stage") == null, "Shell D: failed stage setup enters no exploration state")
			_check(state.completed_count() == 2 and not bool(state.is_completed(BEAT_03)) and not bool(state.is_completed(BEAT_05)) and not bool(state.is_completed(BEAT_06)), "Shell D: failed setup records no exploration beats")
			_check(bool(shell.call("prologue_reached_end")) and not runner.is_control_locked() and not bool(shell.call("is_sequence_running")), "Shell D: fallback leaves runner idle and unlocked")
			_check(status != null and status.text.contains("No exploration segment is active"), "Shell D: fallback status reflects safe boundary")
			Engine.remove_meta(STAGE_TEXTURE_META)
			_check(bool(shell.call("request_main_menu_return")) and _shell_exits == [MAIN_MENU_SCENE], "Shell D: dev exit works from failed-setup fallback")
			_go_main(75)
			return false

		# =====================================================================
		# SHELL E: Control lifecycle (unavailable -> enabled -> blocked ->
		#          restored -> frozen) + held interact through vision +
		#          overlay input non-consumption + hygiene
		# =====================================================================
		75:
			if not _on_main():
				return false
			_go_shell(76)
			return false
		76:
			if not _on_shell():
				return false
			var shell := _shell()
			if _wired_shell != shell:
				_wired_shell = shell
				_wire_shell_observers(shell)
				if not _check(shell.call("start_prologue"), "Shell E: start_prologue starts lifecycle verification"):
					return true
				_check(shell.call("exploration_stage") == null and (shell.call("sequence_runner") as SequenceRunner).is_control_locked(), "Shell E: input unavailable during pl_01/pl_02 cinematics")
			if not bool(shell.call("in_exploration")):
				_skip_runner_beat(shell)
				return false
			var st := _stage_node(shell)
			var explorer := _explorer_of(shell)
			_check(st.is_dialogue_locked() and not explorer.is_input_enabled(), "Shell E: input unavailable during pl_03 intro dialogue")
			_next_stage(77)
			return false
		77:
			if not _on_shell():
				return false
			var shell := _shell()
			if _panel_of(shell).is_open():
				_advance_if_open(shell)
				return false
			var st := _stage_node(shell)
			var explorer := _explorer_of(shell)
			_check(explorer.is_input_enabled() and not st.is_actor_locked(), "Shell E: input enabled after pl_03 intro closes")
			shell.call("skip_current_exploration_beat")
			_teleport(explorer, 430.0)
			Input.action_press("interact")
			_next_stage(78)
			return false
		78:
			if not _on_shell():
				return false
			var inspectables := _inspectables_of(_shell())
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 79):
				return false
			return false
		79:
			if not _on_shell():
				return false
			_teleport(_explorer_of(_shell()), 630.0)
			Input.action_press("interact")
			_next_stage(80)
			return false
		80:
			if not _on_shell():
				return false
			var panel := _panel_of(_shell())
			if not _await_interact_effect(func() -> bool: return panel.is_open(), 81):
				return false
			var st := _stage_node(_shell())
			_check(st.is_dialogue_locked() and not _explorer_of(_shell()).is_input_enabled(), "Shell E: input blocked during pl_04 recognition dialogue")
			return false
		81:
			if not _on_shell():
				return false
			var shell := _shell()
			if _panel_of(shell).is_open():
				_advance_if_open(shell)
				return false
			var st := _stage_node(shell)
			var explorer := _explorer_of(shell)
			_check(explorer.is_input_enabled() and not st.is_actor_locked(), "Shell E: input restored after pl_04 dialogue closes")
			_teleport(explorer, 1830.0)
			_next_stage(82)
			return false
		82:
			if not _on_shell():
				return false
			var shell := _shell()
			if not _ruins_of(shell).is_chamber_revealed():
				return false
			shell.call("skip_current_exploration_beat")
			var explorer := _explorer_of(shell)
			_check(explorer.is_input_enabled() and String(shell.call("active_exploration_beat")) == BEAT_06, "Shell E: input enabled for pl_06 crown approach")
			_teleport(explorer, _ruins_of(shell).altar_x())
			# Hold interact DOWN continuously across awakening and vision playback
			Input.action_press("interact")
			_next_stage(83)
			return false
		83:
			if not _on_shell():
				return false
			var shell := _shell()
			var ruins := _ruins_of(shell)
			if not _await_held_interact_effect(func() -> bool: return ruins.is_crown_consumed() and _vision_runner_of(shell).is_running(), 84):
				return false
			var st := _stage_node(shell)
			_check(st.is_awakening_locked() and not _explorer_of(shell).is_input_enabled(), "Shell E: input blocked during awakening and vision")
			var reveal_layer := ruins.reveal_layer()
			var reveal_root: Control = reveal_layer.get_node_or_null("RevealRoot") as Control
			var vision_bg: Control = reveal_root.get_node_or_null("VisionBackdrop") as Control if reveal_root != null else null
			var vision_lbl: Control = vision_bg.get_node_or_null("VisionCaption") as Control if vision_bg != null else null
			_check(
				reveal_root != null and reveal_root.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and vision_bg != null and vision_bg.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and vision_lbl != null and vision_lbl.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"Shell E: presentation overlays use MOUSE_FILTER_IGNORE (no gameplay input consumption)"
			)
			return false
		84:
			if not _on_shell():
				return false
			var shell := _shell()
			# Keep interact held until post-vision dialogue opens
			if not _panel_of(shell).is_open():
				return false
			Input.action_release("interact")
			var st := _stage_node(shell)
			_check(int(shell.call("crown_awakening_requests_received")) == 1 and int(shell.call("crown_awakening_acceptances")) == 1, "Shell E: held interact through vision triggers zero extra crown interactions")
			_check(st.is_awakening_locked() and not _explorer_of(shell).is_input_enabled(), "Shell E: input stays blocked during post-vision dialogue")
			_next_stage(85)
			return false
		85:
			if not _on_shell():
				return false
			var shell := _shell()
			if _panel_of(shell).is_open():
				_advance_if_open(shell)
				return false
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(state.is_completed(BEAT_06)):
				return false
			var st := _stage_node(shell)
			var explorer := _explorer_of(shell)
			_check(not explorer.is_input_enabled() and not st.is_actor_locked() and not explorer.is_physics_processing() and st.is_segment_ended(), "Shell E: actor frozen and locks released at N4.4 boundary")
			_go_main(86)
			return false
		86:
			if not _on_main():
				return false
			# Hygiene: real user files & sidecars byte-exact untouched, fixtures cleaned
			if _real_profile_existed:
				_check(FileAccess.get_file_as_string(REAL_PROFILE_PATH) == _real_profile_snapshot, "Shell E: real user://player_profile.json untouched")
			else:
				_check(not FileAccess.file_exists(REAL_PROFILE_PATH), "Shell E: real user://player_profile.json not created")
			if _real_save_existed:
				_check(FileAccess.get_file_as_string(SaveManager.DEFAULT_SAVE_PATH) == _real_save_snapshot, "Shell E: real user://save_slot_0.json untouched")
			else:
				_check(not FileAccess.file_exists(SaveManager.DEFAULT_SAVE_PATH), "Shell E: real user://save_slot_0.json not created")
			for suffix: String in [".tmp", ".bak", ".old"]:
				_assert_sidecar_untouched(SaveManager.DEFAULT_SAVE_PATH + suffix, _real_save_sidecars[suffix], "Shell E: real save sidecar %s" % suffix)
			for suffix: String in [".tmp", ".old"]:
				_assert_sidecar_untouched(REAL_PROFILE_PATH + suffix, _real_profile_sidecars[suffix], "Shell E: real profile sidecar %s" % suffix)
			_rm(PROFILE_FALSE)
			_rm(SAVE_NONE)
			_clean_fixture_sidecars()
			if DirAccess.dir_exists_absolute(TEST_DIR):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
			Engine.remove_meta(AUTOSTART_META)
			Engine.remove_meta(STAGE_TEXTURE_META)
			Engine.remove_meta("crownfall_profile_path")
			Engine.remove_meta("crownfall_menu_save_path")
			_check(not Input.is_action_pressed("interact") and not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "Shell E: no leaked input actions after suite")
			if _failures == 0:
				print("PASS: All %d N44 Full Flow checks completed with 0 failures." % _checks)
				quit(0)
			else:
				printerr("FAIL: N44 Full Flow finished with %d failures out of %d checks." % [_failures, _checks])
				quit(1)
			return true
	return false
