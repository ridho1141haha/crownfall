extends SceneTree

## N43B mark-inspection tests — slices B1 + B2.
##
## B1 scope under test (N4.3-B design, section 10 slice 1):
##   1. D6 fail-closed table validation: empty table, fewer than two objects,
##      empty id, duplicate ids, positions outside the authored road bounds —
##      every case leaves the component invalid and EMPTY (atomic cleanup),
##   2. atomic construction: prop/glyph/prompt factory failures free every
##      partial and commit nothing (H9/H9a/H9b),
##   3. a valid build commits exactly the authored props + the shared prompt,
##      with ONE identical mark glyph shape on every prop (placeholder),
##   4. the interaction-range query returns the nearest eligible object only
##      inside the authored range,
##   5. per-run inspection state is idempotent per id (D1) and counts
##      DISTINCT ids only,
##   6. the shared prompt is shown above the requested target and hidden for
##      none/unknown targets,
##   7. stage integration: the props render as pl_03 scenery, the prompt is
##      INACTIVE during pl_03 even when the actor stands in range, and the
##      prompt becomes active in pl_04 following the nearest eligible object,
##   8. the N4.3-A pl_03 flow (chain, intro dialogue, handoff, pl_04
##      activation) is unchanged by the new component,
##   9. cancellation still records nothing and hides the prompt,
##  10. real profile/save files remain byte-exact untouched.
##
## B2 scope under test (section 10 slice 2 — interaction, recognition,
## completion):
##  11. H1: a press within range records the nearest object silently (no
##      dialogue, no completion),
##  12. H3: approach past every object WITHOUT interact never completes,
##  13. H4: same-object repeats never increase the distinct count; two
##      DISTINCT objects open the approved recognition line exactly once,
##  14. H5: interact presses during the recognition dialogue are inert,
##  15. H6: the FINAL state after normal completion is the D3 ended/frozen
##      boundary (panel closed, lock released, input disabled, actor frozen,
##      prompt hidden, boundary status),
##  16. H7a/H7b: cancellation before/during the recognition dialogue records
##      nothing and cleans up deterministically,
##  17. H8: a DIRECT scene unload while the recognition dialogue is open
##      releases the lock (observed on the SURVIVING PlayerControlLock
##      reference), records nothing, and never dereferences a freed node,
##  18. H10: completion exactly-once separated into E (stage emission), A
##      (shell acceptance via its two externally visible effects), and R
##      (NarrativeState recording) — scenarios A-D, never one conflated count,
##  19. H11: any two DISTINCT pairs complete; the third object is optional
##      and inert after completion,
##  20. H14: a held interact key across dialogue closure never re-inspects
##      and never duplicates the completion,
##  21. real profile/save files remain byte-exact untouched.
##
## This file is NOT yet registered in tests/run_all.sh — registration is
## slice B3 (per the design).
##
## ISOLATION CONTRACT (same style as test_n43a): fixtures live under
## user://n43b_test/ injected via the crownfall_profile_path /
## crownfall_menu_save_path Engine metas; the developer's real files are only
## READ once for byte-exact non-mutation proof at the end of the run.
## Interact presses use single Input.action_press/release calls. Measured on
## 4.7.2 (two dedicated probes): one action_press from _process produces
## exactly ONE is_action_just_pressed edge, observed by the FIRST physics
## tick after the press no matter how many process frames later that tick
## runs; a held key produces no further edges; and an action_press while the
## action is ALREADY held does NOT arm a new edge — so every retry in the
## normal driver releases the action before re-pressing (see
## _await_interact_effect), while the H14 held-input window never does (see
## _await_held_interact_effect).

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const PROLOGUE_SHELL_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const PROLOGUE_SHELL_SCRIPT: GDScript = preload("res://scripts/narrative/PrologueShell.gd")
const TEST_DIR: String = "user://n43b_test"
const PROFILE_FALSE: String = "user://n43b_test/profile_false.json"
const SAVE_NONE: String = "user://n43b_test/save_none.json"
const REAL_PROFILE_PATH: String = "user://player_profile.json"
const AUTOSTART_META: String = "crownfall_prologue_autostart"
const BEAT_01: String = "pl_01_lost_world"
const BEAT_02: String = "pl_02_faint_resonance"
const BEAT_03: String = "pl_03_wanderer"
const BEAT_04: String = "pl_04_repeated_mark"
const MAX_WAIT_FRAMES: int = 1800
## How long an interact press may wait for its effect before the driver
## declares the attempt failed. Headless/windowed pacing runs process frames
## faster than the 60 Hz physics clock, so physics ticks arrive every 2-5
## process frames with occasional gaps up to ~10 (measured on this binary);
## the budget is sized well above that ceiling. It is a bounded retry window,
## not a sleep — the effect lands at the first tick after the press.
const INTERACT_RETRY_BUDGET_FRAMES: int = 30

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _shell_exits: Array[String] = []
var _completions: Array[String] = []
## H10 observables (rev 2.1): E = raw stage emissions in arrival order,
## A = the two externally visible acceptance effects (asserted per scenario),
## R = the pre-captured NarrativeState reference.
var _emissions: Array[int] = []
var _emission_panel_states: Array[bool] = []
var _emission_panel: DialoguePanel = null
var _real_profile_snapshot: String = ""
var _real_profile_existed: bool = false
var _real_save_snapshot: String = ""
var _real_save_existed: bool = false
var _real_save_sidecars: Dictionary = {}
var _real_profile_sidecars: Dictionary = {}
## H8 survivor captures (taken BEFORE the unload; only survivors are touched).
var _unloaded_shell: Control = null
var _unloaded_explorer: PrologueExplorer = null
var _unlocked_lock_ref: PlayerControlLock = null
var _unloaded_state: NarrativeState = null


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n43b_mark_inspection] " + msg)
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


func _wire_shell_observers(shell: Control) -> void:
	_completions.clear()
	_shell_exits.clear()
	shell.call("set_exit_transition", func(scene_path: String) -> void: _shell_exits.append(scene_path))
	shell.call("set_cue_player", func(cue_id: String) -> void: pass)
	var runner: SequenceRunner = shell.call("sequence_runner")
	runner.sequence_completed.connect(func(sequence_id: String) -> void: _completions.append(sequence_id))


func _stage_node(shell: Control) -> PrologueExplorationStage:
	return shell.call("exploration_stage") as PrologueExplorationStage


func _inspectables_of(shell: Control) -> PrologueMarkInspectables:
	var stage := _stage_node(shell)
	return stage.inspectables() if stage != null else null


func _explorer_of(shell: Control) -> PrologueExplorer:
	var stage := _stage_node(shell)
	return stage.explorer() if stage != null else null


func _advance_if_open(shell: Control) -> void:
	var panel: DialoguePanel = shell.call("dialogue_panel")
	if panel.is_open():
		panel.advance()


func _skip_runner_beat(shell: Control) -> void:
	if bool(shell.call("is_sequence_running")):
		shell.call("skip_sequence")


func _stop_driving() -> void:
	Input.action_release("move_right")
	Input.action_release("move_left")


func _teleport(explorer: PrologueExplorer, x: float) -> void:
	explorer.position.x = x


## H10 E listener (rev 2.1): counts raw stage emissions AND captures the
## panel state AT emission time (record-after-dialogue ordering proof).
func _connect_emission_listener(shell: Control) -> void:
	_emissions.clear()
	_emission_panel_states.clear()
	_emission_panel = shell.call("dialogue_panel")
	var stage := _stage_node(shell)
	if stage != null:
		stage.mark_inspection_completed.connect(_on_stage_emission)


func _on_stage_emission() -> void:
	_emissions.append(1)
	_emission_panel_states.append(_emission_panel != null and _emission_panel.is_open())


## The D3 ended/frozen terminal list (design section 8) after the boundary is
## reached — asserted as a whole everywhere it applies. stage_emitted selects
## the per-scenario E expectation: true after a NORMAL recognition completion
## (H6/H10-A/H14), false after a SKIP (H10-B: the skip records through the
## shell, the stage never emits — asserting `false` here IS the E=0 proof).
func _check_terminal_state(shell: Control, label: String, stage_emitted: bool) -> void:
	var stage := _stage_node(shell)
	var explorer := _explorer_of(shell)
	var panel: DialoguePanel = shell.call("dialogue_panel")
	var inspectables := _inspectables_of(shell)
	_check(not panel.is_open(), "%s: the dialogue panel is closed" % label)
	_check(stage != null and not stage.is_dialogue_locked(), "%s: the stage-owned actor lock is released" % label)
	_check(stage != null and stage.is_segment_ended() and stage.inspection_completed() == stage_emitted, "%s: the stage segment ended with the scenario-correct emission flag (emitted=%s)" % [label, stage_emitted])
	_check(String(shell.call("active_exploration_beat")) == "" and bool(shell.call("n43_segment_complete")), "%s: the shell ended the segment at the N4.3 boundary" % label)
	_check(explorer != null and not explorer.is_input_enabled() and not explorer.is_physics_processing(), "%s: the explorer is input-disabled and frozen" % label)
	_check(inspectables != null and not inspectables.prompt().visible, "%s: the inspection prompt is hidden" % label)
	var status: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
	_check(status != null and status.text.contains("N4.3"), "%s: the boundary status is shown" % label)


## Press-and-confirm driver for NORMAL interactions. The press stage presses
## once; this await then guarantees a FRESH just-pressed edge per attempt:
## an Input.action_press while the action is already held does NOT arm a new
## edge on 4.7.2 (measured), so every retry releases before re-pressing —
## the previous retry (press without release) could never recover a missed
## press. Every exit path leaves the action RELEASED (known state): on
## success, and on the failure path before the suite aborts. The extra edges
## are always safe because a repeated mark is an idempotent no-op (D1) and
## edges while a dialogue is open are D5-gated.
func _await_interact_effect(has_effect: Callable, next_stage: int) -> bool:
	if has_effect.call():
		Input.action_release("interact")
		_stage = next_stage
		_wait_frames = 0
		return true
	if _wait_frames > INTERACT_RETRY_BUDGET_FRAMES:
		Input.action_release("interact")
		_check(false, "the interact press produced no effect within the retry budget")
		return true
	# Re-arm deterministically: cancel any not-yet-observed pending edge and
	# press again, so the first physics tick after THIS frame observes a
	# fresh edge (measured: same-call release+press always re-arms).
	Input.action_release("interact")
	Input.action_press("interact")
	return false


## Held-input await (H14 ONLY): the accepting press must stay DOWN for the
## whole window — a single continuous hold, with NO release/press cycles
## here (those would convert the held-input scenario into repeated presses
## and defeat the contract). The held press's edge is observed by the first
## physics tick after the press regardless of the frame gap (measured), so
## this only waits for the effect. On the failure path the key is released
## before the suite aborts; on success the hold intentionally continues and
## the test releases it explicitly after the assertion window.
func _await_held_interact_effect(has_effect: Callable, next_stage: int) -> bool:
	if has_effect.call():
		_stage = next_stage
		_wait_frames = 0
		return true
	if _wait_frames > INTERACT_RETRY_BUDGET_FRAMES:
		Input.action_release("interact")
		_check(false, "the held interact press produced no effect within the retry budget")
		return true
	return false


# --- D6 test-only table variants (no production test seam: subclasses only) ---

class EmptyTableInspectables extends PrologueMarkInspectables:
	func _authored_table() -> Array[Dictionary]:
		return []


class SingleInspectables extends PrologueMarkInspectables:
	func _authored_table() -> Array[Dictionary]:
		return [{"id": "mark_stone_a", "name": "MarkStoneA", "x": 430.0, "condition": "stone"}]


class EmptyIdInspectables extends PrologueMarkInspectables:
	func _authored_table() -> Array[Dictionary]:
		return [
			{"id": "", "name": "MarkA", "x": 430.0, "condition": "stone"},
			{"id": "mark_fragment_b", "name": "MarkFragmentB", "x": 630.0, "condition": "fragment"},
		]


class DuplicateIdInspectables extends PrologueMarkInspectables:
	func _authored_table() -> Array[Dictionary]:
		return [
			{"id": "mark_stone_a", "name": "MarkStoneA", "x": 430.0, "condition": "stone"},
			{"id": "mark_stone_a", "name": "MarkStoneB", "x": 630.0, "condition": "stone"},
		]


class OutOfBoundsInspectables extends PrologueMarkInspectables:
	func _authored_table() -> Array[Dictionary]:
		return [
			{"id": "mark_stone_a", "name": "MarkStoneA", "x": 430.0, "condition": "stone"},
			{"id": "mark_fragment_b", "name": "MarkFragmentB", "x": 900.0, "condition": "fragment"},
		]


class BelowBoundsInspectables extends PrologueMarkInspectables:
	func _authored_table() -> Array[Dictionary]:
		return [
			{"id": "mark_stone_a", "name": "MarkStoneA", "x": -900.0, "condition": "stone"},
			{"id": "mark_fragment_b", "name": "MarkFragmentB", "x": 630.0, "condition": "fragment"},
		]


# --- H9a/H9b test-only factory-failure subclasses ---

class PropFailInspectables extends PrologueMarkInspectables:
	func _create_prop(_node_name: String, _condition: String, _x: float, _ground_y: float) -> Node2D:
		return null


class GlyphFailInspectables extends PrologueMarkInspectables:
	func _create_mark_glyph(_condition: String) -> Node2D:
		return null


class PromptFailInspectables extends PrologueMarkInspectables:
	func _create_prompt() -> Label:
		return null


func _run_unit_checks() -> void:
	# --- D6 validation matrix: invalid, empty, atomic ---
	for variant: PrologueMarkInspectables in [
		EmptyTableInspectables.new(),
		SingleInspectables.new(),
		EmptyIdInspectables.new(),
		DuplicateIdInspectables.new(),
		OutOfBoundsInspectables.new(),
		BelowBoundsInspectables.new(),
	]:
		var ok: bool = variant.build(PrologueExplorationStage.ROAD_MIN_X, PrologueExplorationStage.ROAD_MAX_X, PrologueExplorationStage.GROUND_Y)
		_check(not ok and not variant.is_valid(), "%s fails closed (build rejected, is_valid false)" % variant.get_class())
		_check(variant.get_child_count() == 0, "%s leaves NO committed children (atomic cleanup)" % variant.get_class())
		_check(variant.prompt() == null, "%s leaves no prompt reference" % variant.get_class())
		variant.free()
	# --- H9a/H9b: factory failures fail closed with zero partials ---
	for variant: PrologueMarkInspectables in [
		PropFailInspectables.new(),
		GlyphFailInspectables.new(),
		PromptFailInspectables.new(),
	]:
		var ok: bool = variant.build(PrologueExplorationStage.ROAD_MIN_X, PrologueExplorationStage.ROAD_MAX_X, PrologueExplorationStage.GROUND_Y)
		_check(not ok and not variant.is_valid(), "%s construction failure fails closed" % variant.get_class())
		_check(variant.get_child_count() == 0, "%s construction failure commits nothing (partials freed)" % variant.get_class())
		variant.free()
	# --- Valid build: committed structure, identical glyph geometry ---
	var set_valid: PrologueMarkInspectables = PrologueMarkInspectables.new()
	_check(set_valid.build(PrologueExplorationStage.ROAD_MIN_X, PrologueExplorationStage.ROAD_MAX_X, PrologueExplorationStage.GROUND_Y), "a valid authored table builds successfully")
	_check(set_valid.is_valid(), "the built component is valid")
	_check(set_valid.get_child_count() == 2, "exactly the props container + the shared prompt are committed")
	var props_root: Node2D = set_valid.get_node("MarkProps") as Node2D
	_check(props_root != null and props_root.get_child_count() == 3, "exactly three placeholder props are committed")
	_check(set_valid.get_node_or_null("MarkProps/MarkStoneA") != null and set_valid.get_node_or_null("MarkProps/MarkFragmentB") != null and set_valid.get_node_or_null("MarkProps/MarkArtifactC") != null, "the three authored props exist under their authored names")
	var prompt: Label = set_valid.prompt()
	_check(prompt != null and prompt.name == "InspectPrompt" and not prompt.visible, "the shared prompt is committed hidden")
	_check(prompt != null and prompt.text == PrologueMarkInspectables.PROMPT_TEXT and prompt.text == "[E] Inspect", "the prompt wording is the explicitly provisional placeholder")
	var glyph_a: Node2D = set_valid.get_node("MarkProps/MarkStoneA/MarkGlyph") as Node2D
	var glyph_b: Node2D = set_valid.get_node("MarkProps/MarkFragmentB/MarkGlyph") as Node2D
	var glyph_c: Node2D = set_valid.get_node("MarkProps/MarkArtifactC/MarkGlyph") as Node2D
	var bar_a: ColorRect = glyph_a.get_node("MarkGlyphVertical") as ColorRect
	var bar_b: ColorRect = glyph_b.get_node("MarkGlyphVertical") as ColorRect
	var bar_c: ColorRect = glyph_c.get_node("MarkGlyphVertical") as ColorRect
	var cross_a: ColorRect = glyph_a.get_node("MarkGlyphHorizontal") as ColorRect
	var cross_b: ColorRect = glyph_b.get_node("MarkGlyphHorizontal") as ColorRect
	var cross_c: ColorRect = glyph_c.get_node("MarkGlyphHorizontal") as ColorRect
	_check(bar_a != null and bar_b != null and bar_c != null and cross_a != null and cross_b != null and cross_c != null, "every prop carries the two-rect placeholder mark glyph")
	_check(bar_a.size == bar_b.size and bar_b.size == bar_c.size and cross_a.size == cross_b.size and cross_b.size == cross_c.size and bar_a.position == bar_b.position and cross_a.position == cross_b.position, "the mark glyph GEOMETRY is identical on all three props")
	_check(bar_a.color != bar_b.color or cross_a.color != cross_b.color, "only the glyph TINT varies with the surface condition (planning section 2)")
	# --- Range query: nearest eligible object only ---
	_check(set_valid.nearest_eligible_id(430.0) == "mark_stone_a", "the range query finds object A at its authored position")
	_check(set_valid.nearest_eligible_id(680.0) == "mark_fragment_b", "the range query finds the NEAREST object (B from the handoff area, not A)")
	_check(set_valid.nearest_eligible_id(-280.0) == "mark_artifact_c", "the range query finds object C at its authored position")
	_check(set_valid.nearest_eligible_id(620.0) == "mark_fragment_b", "inside the range the nearest object wins")
	_check(set_valid.nearest_eligible_id(520.0) == "", "the gap between objects is out of range for every object")
	_check(set_valid.nearest_eligible_id(430.0 + PrologueMarkInspectables.INSPECT_RANGE_X) == "mark_stone_a", "the range boundary itself is inclusive (|dx| <= range)")
	_check(set_valid.nearest_eligible_id(430.0 + PrologueMarkInspectables.INSPECT_RANGE_X + 0.5) == "", "beyond the range boundary nothing is eligible")
	_check(set_valid.nearest_eligible_id(0.0) == "", "mid-road is out of range for every object")
	# --- D1 marking state: idempotent per id, distinct count ---
	_check(set_valid.mark_inspected("mark_stone_a"), "the first inspection of an object is recorded")
	_check(not set_valid.mark_inspected("mark_stone_a"), "re-inspecting the SAME object is an idempotent no-op (D1)")
	_check(set_valid.distinct_inspected_count() == 1, "a repeated inspection never increases the distinct count")
	_check(not set_valid.mark_inspected("mark_unknown_x"), "an unknown id is never recorded")
	_check(set_valid.mark_inspected("mark_fragment_b"), "a second DISTINCT object is recorded")
	_check(set_valid.distinct_inspected_count() == 2, "the distinct count tracks distinct ids only (D1/D4)")
	_check(set_valid.is_inspected("mark_stone_a") and set_valid.is_inspected("mark_fragment_b") and not set_valid.is_inspected("mark_artifact_c"), "per-id inspection state is queryable")
	# --- Prompt target: show above the target, hide for none/unknown ---
	set_valid.set_prompt_target("mark_stone_a")
	_check(prompt.visible and absf(prompt.position.x - (430.0 - prompt.custom_minimum_size.x * 0.5)) < 0.01 and absf(prompt.position.y - (PrologueExplorationStage.GROUND_Y - PrologueMarkInspectables.PROMPT_HEIGHT_ABOVE_GROUND)) < 0.01, "the prompt appears above the targeted object")
	set_valid.set_prompt_target("")
	_check(not prompt.visible, "an empty target hides the prompt")
	set_valid.set_prompt_target("mark_unknown_x")
	_check(not prompt.visible, "an unknown target hides the prompt (never points at nothing)")
	set_valid.set_prompt_target("mark_artifact_c")
	_check(prompt.visible and absf(prompt.position.x - (-280.0 - prompt.custom_minimum_size.x * 0.5)) < 0.01, "the prompt follows the requested target")
	set_valid.free()
	# --- H4 (data): the approved recognition line is authored data only ---
	var recognition: Array[Dictionary] = PrologueBeats.exploration_recognition_lines()
	_check(recognition.size() == 2, "the recognition line is authored with exactly two lines")
	_check(String(recognition[0].get("speaker", "")) == PrologueBeats.MONARCH and String(recognition[1].get("speaker", "")) == PrologueBeats.MONARCH, "the recognition line uses the exploration MONARCH speaker convention")
	_check(String(recognition[0].get("text", "")) == "I've seen this mark before..." and String(recognition[1].get("text", "")) == "Why does it keep appearing?", "the recognition text is the approved Story Design Beat 04 candidate, verbatim")


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
		_real_profile_sidecars[suffix] = _snapshot_sidecar(REAL_PROFILE_PATH + suffix)
	if not _set_metas(PROFILE_FALSE, SAVE_NONE):
		return
	_stage = 1


func _prepare_fixtures() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	_rm(PROFILE_FALSE)
	_rm(SAVE_NONE)
	_write_json(PROFILE_FALSE, {"schema_version": 1, "prologue_completed_once": false})


func _process(_delta: float) -> bool:
	_wait_frames += 1
	if _wait_frames > MAX_WAIT_FRAMES:
		_check(false, "timed out at stage %d" % _stage)
		return true
	match _stage:
		1:
			_run_unit_checks()
			# Production defaults: autostart ON and exploration ON (metas stay
			# unset — same convention as the N4.3-A suite's shell A).
			change_scene_to_file(MAIN_SCENE)
			_stage = 2
			_wait_frames = 0
			return false
		2:
			if not _on_main():
				return false
			# --- Shell A: production flow (autostart ON) — pl_03 unchanged ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 3
			_wait_frames = 0
			return false
		3:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not bool(shell.call("is_sequence_running")):
				return false
			_wire_shell_observers(shell)
			var panel: DialoguePanel = shell.call("dialogue_panel")
			_check(panel.is_open() and panel.get_body_text().contains("Long ago"), "auto-start plays pl_01 (existing flow intact)")
			_stage = 4
			_wait_frames = 0
			return false
		4:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not _completions.has(BEAT_01):
				_advance_if_open(shell)
				return false
			var panel2: DialoguePanel = shell.call("dialogue_panel")
			_check(panel2.is_open() and panel2.get_body_text().contains("Years ago"), "pl_01 completion chains pl_02 exactly as in N4.2")
			_stage = 5
			_wait_frames = 0
			return false
		5:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not _completions.has(BEAT_02):
				_advance_if_open(shell)
				return false
			# --- pl_02 completion enters exploration; inspectables are scenery ---
			_check(String(shell.call("active_exploration_beat")) == BEAT_03, "pl_02 completion enters the pl_03 exploration segment (unchanged)")
			var stage := _stage_node(shell)
			var inspectables := _inspectables_of(shell)
			_check(stage != null and inspectables != null and inspectables.is_valid(), "the exploration stage builds the inspectable set during setup")
			var props_root: Node2D = inspectables.get_node("MarkProps") as Node2D
			_check(props_root != null and props_root.get_child_count() == 3, "all three mark props render during pl_03 (scenery)")
			_check(not inspectables.prompt().visible, "the inspection prompt is INACTIVE during pl_03")
			var panel3: DialoguePanel = shell.call("dialogue_panel")
			_check(panel3.is_open() and panel3.get_speaker_text() == "Monarch", "the approved pl_03 internal line still opens through the DialoguePanel")
			_check(stage.is_dialogue_locked() and not stage.is_input_enabled(), "the intro dialogue still locks the actor (N4.3-A contract intact)")
			_stage = 6
			_wait_frames = 0
			return false
		6:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var stage := _stage_node(shell)
			var panel: DialoguePanel = shell.call("dialogue_panel")
			if panel.is_open():
				panel.advance()
				return false
			_check(not stage.is_dialogue_locked() and stage.is_input_enabled(), "normal intro completion still releases the lock and enables movement")
			Input.action_press("move_right")
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
			_check(state.completed_count() == 3 and String(shell.call("active_exploration_beat")) == BEAT_04, "the handoff still records pl_03 exactly once and activates pl_04 (N4.3-A intact)")
			var explorer := _explorer_of(shell)
			_check(explorer != null and explorer.is_input_enabled(), "pl_04 stays interactive")
			# --- pl_04 prompt follows the nearest eligible object ---
			_teleport(explorer, 620.0)
			_stage = 8
			_wait_frames = 0
			return false
		8:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if _wait_frames < 3:
				return false
			var prompt: Label = inspectables.prompt()
			_check(prompt.visible and absf(prompt.position.x - (630.0 - prompt.custom_minimum_size.x * 0.5)) < 0.01, "in pl_04 the prompt appears above the nearest eligible object (B)")
			var explorer := _explorer_of(shell)
			_teleport(explorer, 450.0)
			_stage = 9
			_wait_frames = 0
			return false
		9:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if _wait_frames < 3:
				return false
			var prompt: Label = inspectables.prompt()
			_check(prompt.visible and absf(prompt.position.x - (430.0 - prompt.custom_minimum_size.x * 0.5)) < 0.01, "the prompt follows the nearest object as the actor moves (A)")
			var explorer := _explorer_of(shell)
			_teleport(explorer, 0.0)
			_stage = 10
			_wait_frames = 0
			return false
		10:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if _wait_frames < 3:
				return false
			_check(not inspectables.prompt().visible, "out of range of every object the prompt disappears")
			var explorer := _explorer_of(shell)
			_teleport(explorer, -280.0)
			_stage = 11
			_wait_frames = 0
			return false
		11:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if _wait_frames < 3:
				return false
			var prompt: Label = inspectables.prompt()
			_check(prompt.visible and absf(prompt.position.x - (-280.0 - prompt.custom_minimum_size.x * 0.5)) < 0.01, "the optional third object gets the prompt as well (D4: never required, but inspectable)")
			# --- Cancellation during pl_04 records nothing and hides the prompt ---
			shell.call("cancel_sequence")
			var state: NarrativeState = shell.call("narrative_state")
			_check(not inspectables.prompt().visible, "cancellation hides the inspection prompt")
			_check(state.completed_count() == 3 and not bool(state.is_completed(BEAT_04)), "cancellation during pl_04 still records nothing (not a skip)")
			_check(String(shell.call("active_exploration_beat")) == "" and not bool(shell.call("in_exploration")), "cancellation ends the segment presentation")
			change_scene_to_file(MAIN_SCENE)
			_stage = 12
			_wait_frames = 0
			return false
		12:
			if not _on_main():
				return false
			# --- Shell B: pl_03 prompt gate vs pl_04 prompt gate ---
			Engine.set_meta(AUTOSTART_META, false)
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 13
			_wait_frames = 0
			return false
		13:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if not _check(shell.call("start_prologue"), "shell B starts the chain explicitly (idle shell)"):
				return true
			_stage = 14
			_wait_frames = 0
			return false
		14:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if bool(shell.call("in_exploration")):
				var stage := _stage_node(shell)
				var panel: DialoguePanel = shell.call("dialogue_panel")
				_check(panel.is_open() and stage.is_dialogue_locked(), "shell B reaches the exploration intro dialogue")
				# The actor is teleported INTO object C's range during pl_03:
				# the prompt must stay hidden — it is a pl_04-only affordance.
				var explorer := _explorer_of(shell)
				_teleport(explorer, -290.0)
				_stage = 15
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		15:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if _wait_frames < 3:
				return false
			_check(not inspectables.prompt().visible, "the prompt STAYS hidden during pl_03 even with the actor in range (pl_04-only affordance)")
			# --- pl_03 Skip activates pl_04 (records pl_03 once) ---
			_check(shell.call("skip_current_exploration_beat"), "pl_03 Skip is accepted while the intro dialogue is open")
			var state: NarrativeState = shell.call("narrative_state")
			_check(bool(state.is_completed(BEAT_03)) and String(shell.call("active_exploration_beat")) == BEAT_04, "pl_03 Skip records pl_03 once and activates pl_04 without skipping it")
			var explorer := _explorer_of(shell)
			_check(explorer != null and explorer.is_input_enabled(), "pl_04 is interactive after the Skip")
			_teleport(explorer, -290.0)
			_stage = 16
			_wait_frames = 0
			return false
		16:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if _wait_frames < 3:
				return false
			var prompt: Label = inspectables.prompt()
			_check(prompt.visible and absf(prompt.position.x - (-280.0 - prompt.custom_minimum_size.x * 0.5)) < 0.01, "the SAME position in pl_04 now shows the prompt (gate follows the active beat)")
			# --- Cancellation after a skip still records nothing new ---
			shell.call("cancel_sequence")
			var state: NarrativeState = shell.call("narrative_state")
			_check(state.completed_count() == 3 and not bool(state.is_completed(BEAT_04)), "cancellation after the pl_03 Skip records nothing for pl_04")
			_check(not inspectables.prompt().visible, "cancellation hides the prompt")
			_check(shell.call("request_main_menu_return"), "the development exit works from the cancelled state")
			_check(_shell_exits.size() == 1 and String(_shell_exits[0]) == "res://scenes/main/Main.tscn", "the exit transitions to the main menu exactly once")
			change_scene_to_file(MAIN_SCENE)
			_stage = 17
			_wait_frames = 0
			return false
		17:
			if not _on_main():
				return false
			# --- Shell C: normal recognition completion (H1/H3/H4/H5/H6/H10-A) ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 18
			_wait_frames = 0
			return false
		18:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if not _check(shell.call("start_prologue"), "shell C starts the chain explicitly"):
				return true
			_stage = 19
			_wait_frames = 0
			return false
		19:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if bool(shell.call("in_exploration")):
				_check(shell.call("skip_current_exploration_beat"), "shell C skips pl_03 to reach pl_04 (skips are the fast path)")
				_connect_emission_listener(shell)
				var stage := _stage_node(shell)
				_check(String(shell.call("active_exploration_beat")) == BEAT_04 and stage != null and stage.is_input_enabled(), "shell C reaches interactive pl_04 with the E listener connected")
				_stage = 20
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		20:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if _wait_frames < 2:
				return false
			# H3: move PAST every object without pressing interact.
			_teleport(explorer, 450.0)
			_stage = 21
			_wait_frames = 0
			return false
		21:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if _wait_frames < 2:
				return false
			_teleport(explorer, 620.0)
			_stage = 22
			_wait_frames = 0
			return false
		22:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if _wait_frames < 2:
				return false
			_teleport(explorer, -280.0)
			_stage = 23
			_wait_frames = 0
			return false
		23:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if _wait_frames < 2:
				return false
			_check(String(shell.call("active_exploration_beat")) == BEAT_04 and not bool(state.is_completed(BEAT_04)) and state.completed_count() == 3 and _emissions.is_empty(), "H3: approach past every object without interact never completes (no emission, no record)")
			# H1: press within range of A.
			var explorer := _explorer_of(shell)
			_teleport(explorer, 450.0)
			_stage = 24
			_wait_frames = 0
			return false
		24:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if _wait_frames < 2:
				return false
			Input.action_press("interact")
			_stage = 25
			_wait_frames = 0
			return false
		25:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 26):
				return false
			_stage = 26
			_wait_frames = 0
			return false
		26:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			var panel: DialoguePanel = shell.call("dialogue_panel")
			_check(inspectables.is_inspected("mark_stone_a"), "H1: the press within range recorded the nearest object (A)")
			_check(not panel.is_open(), "H1: the individual inspection opens NO dialogue (D1: silent)")
			var state: NarrativeState = shell.call("narrative_state")
			_check(not bool(state.is_completed(BEAT_04)) and _emissions.is_empty(), "H1: no completion request and no recording from a single inspection")
			# H4a: repeat the SAME object (no armor needed: the effect IS the no-op).
			Input.action_press("interact")
			_stage = 27
			_wait_frames = 0
			return false
		27:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			Input.action_release("interact")
			_check(inspectables.distinct_inspected_count() == 1, "H4a: re-inspecting the SAME object never increases the distinct count")
			var panel: DialoguePanel = shell.call("dialogue_panel")
			_check(not panel.is_open() and _emissions.is_empty(), "H4a: the repeated inspection still opens nothing and emits nothing")
			# H4b: inspect the second DISTINCT object -> recognition opens.
			var explorer := _explorer_of(shell)
			_teleport(explorer, 620.0)
			_stage = 28
			_wait_frames = 0
			return false
		28:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if _wait_frames < 2:
				return false
			Input.action_press("interact")
			_stage = 29
			_wait_frames = 0
			return false
		29:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not _await_interact_effect(func() -> bool: return _emission_panel != null and _emission_panel.is_open(), 30):
				return false
			_stage = 30
			_wait_frames = 0
			return false
		30:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			var stage := _stage_node(shell)
			var panel: DialoguePanel = shell.call("dialogue_panel")
			_check(inspectables.distinct_inspected_count() == 2, "H4b: two DISTINCT objects are recorded (A + B; D4)")
			_check(panel.is_open() and panel.get_speaker_text() == "Monarch" and panel.get_body_text() == "I've seen this mark before...", "H4b: the recognition dialogue opened exactly once with the approved line through the existing panel")
			_check(stage.is_dialogue_locked() and not stage.is_input_enabled(), "H4b: the actor is locked and input-disabled during the recognition (D2 steps 1-3)")
			# H5: press interact DURING the recognition dialogue.
			Input.action_press("interact")
			_stage = 31
			_wait_frames = 0
			return false
		31:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			var panel: DialoguePanel = shell.call("dialogue_panel")
			Input.action_release("interact")
			_check(panel.is_open() and panel.get_body_text() == "I've seen this mark before..." and inspectables.distinct_inspected_count() == 2 and _emissions.is_empty(), "H5: interact presses during the recognition are inert (D5: panel open + lock held)")
			panel.advance()
			_check(panel.is_open() and panel.get_body_text() == "Why does it keep appearing?", "the recognition advances to its second approved line")
			_stage = 32
			_wait_frames = 0
			return false
		32:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel: DialoguePanel = shell.call("dialogue_panel")
			# Last advance closes the panel: the recognition coroutine resumes
			# synchronously inside close(), releases the lock, emits the ONE
			# completion request, and the shell records + ends the segment.
			panel.advance()
			var state: NarrativeState = shell.call("narrative_state")
			_check(_emissions == [1], "H10-A: exactly ONE natural stage emission (E_stage = 1)")
			_check(_emission_panel_states == [false], "H10-A: the emission happened only AFTER the panel closed (record-after-dialogue ordering)")
			_check(bool(state.is_completed(BEAT_04)) and state.completed_count() == 4, "H10-A: the recording R = 1 (pl_04 recorded exactly once; state: pl_01+pl_02+pl_03+pl_04)")
			_check(String(shell.call("active_exploration_beat")) == "" and bool(shell.call("n43_segment_complete")), "H10-A: shell acceptance A = 1 (one transition to the ended boundary)")
			_check(_completions == [BEAT_01, BEAT_02], "exploration completion adds NO SequenceRunner completion (runner stays out of exploration)")
			_check_terminal_state(shell, "H6/D3", true)
			_stage = 33
			_wait_frames = 0
			return false
		33:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var stage := _stage_node(shell)
			var state: NarrativeState = shell.call("narrative_state")
			# H10-C: force-deliver duplicate/late requests at the shell boundary.
			stage.mark_inspection_completed.emit()
			stage.mark_inspection_completed.emit()
			_check(_emissions.size() == 3 and _emissions[0] == 1, "H10-C: injected raw emissions counted SEPARATELY (E_stage stays 1, E_injected = 2)")
			_check(state.completed_count() == 4 and bool(state.is_completed(BEAT_04)), "H10-C: no additional NarrativeState recording")
			_check(String(shell.call("active_exploration_beat")) == "" and bool(shell.call("n43_segment_complete")), "H10-C: no additional shell acceptance or state transition")
			# H11-post: the third object after completion changes nothing.
			var explorer := _explorer_of(shell)
			_teleport(explorer, -280.0)
			Input.action_press("interact")
			_stage = 34
			_wait_frames = 0
			return false
		34:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			var state: NarrativeState = shell.call("narrative_state")
			Input.action_release("interact")
			_check(inspectables.distinct_inspected_count() == 2, "H11-post: the third object is inert after completion (post-boundary physics gate)")
			_check(state.completed_count() == 4 and _emissions.size() == 3, "H11-post: no new recording and no new emission of any kind")
			change_scene_to_file(MAIN_SCENE)
			_stage = 35
			_wait_frames = 0
			return false
		35:
			if not _on_main():
				return false
			# --- Shell D: H10-B skip during the recognition dialogue ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 36
			_wait_frames = 0
			return false
		36:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if not _check(shell.call("start_prologue"), "shell D starts the chain explicitly"):
				return true
			_stage = 37
			_wait_frames = 0
			return false
		37:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if bool(shell.call("in_exploration")):
				_check(shell.call("skip_current_exploration_beat"), "shell D skips pl_03 to reach pl_04")
				_connect_emission_listener(shell)
				_stage = 38
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		38:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if _wait_frames < 2:
				return false
			_teleport(explorer, 450.0)
			Input.action_press("interact")
			_stage = 39
			_wait_frames = 0
			return false
		39:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 40):
				return false
			_stage = 40
			_wait_frames = 0
			return false
		40:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			_check(inspectables.distinct_inspected_count() == 1, "shell D: first inspection recorded")
			var explorer := _explorer_of(shell)
			_teleport(explorer, 620.0)
			Input.action_press("interact")
			_stage = 41
			_wait_frames = 0
			return false
		41:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not _await_interact_effect(func() -> bool: return _emission_panel != null and _emission_panel.is_open(), 42):
				return false
			_stage = 42
			_wait_frames = 0
			return false
		42:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel: DialoguePanel = shell.call("dialogue_panel")
			_check(panel.is_open() and panel.get_body_text() == "I've seen this mark before...", "shell D: the recognition dialogue is open")
			# H10-B: SKIP while the recognition dialogue is open.
			_check(shell.call("skip_current_exploration_beat"), "H10-B: the skip is accepted while the recognition dialogue is open")
			var state: NarrativeState = shell.call("narrative_state")
			_check(bool(state.is_completed(BEAT_04)) and state.completed_count() == 4, "H10-B: the skip records pl_04 exactly once through the existing skip path")
			_check(not panel.is_open(), "H10-B: the skip closed the recognition dialogue")
			_check(String(shell.call("active_exploration_beat")) == "" and bool(shell.call("n43_segment_complete")), "H10-B: shell acceptance via the SKIP path (A = 1)")
			_check(_emissions.is_empty() and not bool(shell.call("skip_current_exploration_beat")), "H10-B: no stage emission occurred and a duplicate skip is rejected")
			_check_terminal_state(shell, "H10-B final", false)
			_stage = 43
			_wait_frames = 0
			return false
		43:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if _wait_frames < 15:
				return false
			_check(_emissions.is_empty() and state.completed_count() == 4, "H10-B: the stale recognition coroutine never emits a later request (15 frames after the skip)")
			change_scene_to_file(MAIN_SCENE)
			_stage = 44
			_wait_frames = 0
			return false
		44:
			if not _on_main():
				return false
			# --- Shell E: H7a cancel BEFORE any recognition dialogue ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 45
			_wait_frames = 0
			return false
		45:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if not _check(shell.call("start_prologue"), "shell E starts the chain explicitly"):
				return true
			_stage = 46
			_wait_frames = 0
			return false
		46:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if bool(shell.call("in_exploration")):
				_check(shell.call("skip_current_exploration_beat"), "shell E skips pl_03 to reach pl_04")
				_connect_emission_listener(shell)
				_stage = 47
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		47:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if _wait_frames < 2:
				return false
			_teleport(explorer, 450.0)
			Input.action_press("interact")
			_stage = 48
			_wait_frames = 0
			return false
		48:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 49):
				return false
			_stage = 49
			_wait_frames = 0
			return false
		49:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			var stage := _stage_node(shell)
			_check(inspectables.distinct_inspected_count() == 1 and _emissions.is_empty(), "H7a: one silent inspection before the cancel (no recognition ever opened)")
			shell.call("cancel_sequence")
			var state: NarrativeState = shell.call("narrative_state")
			_check(state.completed_count() == 3 and not bool(state.is_completed(BEAT_04)), "H7a: cancellation records nothing (not a skip)")
			_check(String(shell.call("active_exploration_beat")) == "" and not bool(shell.call("in_exploration")) and shell.call("exploration_stage") == null, "H7a: the segment presentation is torn down")
			_check(not inspectables.prompt().visible and inspectables.is_valid(), "H7a: the prompt is hidden and the component survived teardown intact")
			_check(stage.is_torn_down(), "H7a: the stage is torn down")
			change_scene_to_file(MAIN_SCENE)
			_stage = 50
			_wait_frames = 0
			return false
		50:
			if not _on_main():
				return false
			# --- Shell F: H7b cancel DURING the recognition dialogue ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 51
			_wait_frames = 0
			return false
		51:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if not _check(shell.call("start_prologue"), "shell F starts the chain explicitly"):
				return true
			_stage = 52
			_wait_frames = 0
			return false
		52:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if bool(shell.call("in_exploration")):
				_check(shell.call("skip_current_exploration_beat"), "shell F skips pl_03 to reach pl_04")
				_connect_emission_listener(shell)
				_stage = 53
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		53:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if _wait_frames < 2:
				return false
			_teleport(explorer, 450.0)
			Input.action_press("interact")
			_stage = 54
			_wait_frames = 0
			return false
		54:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 55):
				return false
			_stage = 55
			_wait_frames = 0
			return false
		55:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			_check(inspectables.distinct_inspected_count() == 1, "shell F: first inspection recorded")
			var explorer := _explorer_of(shell)
			_teleport(explorer, 620.0)
			Input.action_press("interact")
			_stage = 56
			_wait_frames = 0
			return false
		56:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not _await_interact_effect(func() -> bool: return _emission_panel != null and _emission_panel.is_open(), 57):
				return false
			_stage = 57
			_wait_frames = 0
			return false
		57:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel: DialoguePanel = shell.call("dialogue_panel")
			var stage := _stage_node(shell)
			_check(panel.is_open() and stage.is_dialogue_locked(), "shell F: the recognition dialogue is open with the actor locked")
			shell.call("cancel_sequence")
			var state: NarrativeState = shell.call("narrative_state")
			_check(not panel.is_open(), "H7b: cancellation closed the recognition dialogue")
			_check(state.completed_count() == 3 and not bool(state.is_completed(BEAT_04)), "H7b: cancellation records NOTHING for pl_04 (not a skip)")
			_check(stage.is_torn_down() and not stage.is_dialogue_locked() and not stage.is_input_enabled(), "H7b: the stage is torn down, the lock released, exploration input disabled")
			var explorer := _explorer_of(shell)
			_check(explorer == null or not explorer.is_physics_processing(), "H7b: the actor is frozen")
			_check(String(shell.call("active_exploration_beat")) == "" and not bool(shell.call("in_exploration")), "H7b: the segment presentation ended")
			_check(_emissions.is_empty(), "H7b: no completion emission was produced by the cancelled recognition")
			# The dev exit routes through the same cancel_sequence: it must also
			# stay record-free for the cancelled recognition beat.
			_check(shell.call("request_main_menu_return"), "H7b: the development exit works from the cancelled-recognition state")
			_check(_shell_exits.size() == 1 and String(_shell_exits[0]) == "res://scenes/main/Main.tscn", "H7b: the exit transitions exactly once")
			_check(state.completed_count() == 3 and not bool(state.is_completed(BEAT_04)), "H7b: the exit after the cancelled recognition still records nothing")
			change_scene_to_file(MAIN_SCENE)
			_stage = 58
			_wait_frames = 0
			return false
		58:
			if not _on_main():
				return false
			# --- Shell G: H8 direct scene unload during the recognition ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 59
			_wait_frames = 0
			return false
		59:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if not _check(shell.call("start_prologue"), "shell G starts the chain explicitly"):
				return true
			_stage = 60
			_wait_frames = 0
			return false
		60:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if bool(shell.call("in_exploration")):
				_check(shell.call("skip_current_exploration_beat"), "shell G skips pl_03 to reach pl_04")
				_connect_emission_listener(shell)
				_stage = 61
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		61:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if _wait_frames < 2:
				return false
			_teleport(explorer, 450.0)
			Input.action_press("interact")
			_stage = 62
			_wait_frames = 0
			return false
		62:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 63):
				return false
			_stage = 63
			_wait_frames = 0
			return false
		63:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			_check(inspectables.distinct_inspected_count() == 1, "shell G: first inspection recorded")
			var explorer := _explorer_of(shell)
			_teleport(explorer, 620.0)
			Input.action_press("interact")
			_stage = 64
			_wait_frames = 0
			return false
		64:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not _await_interact_effect(func() -> bool: return _emission_panel != null and _emission_panel.is_open(), 65):
				return false
			_stage = 65
			_wait_frames = 0
			return false
		65:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel: DialoguePanel = shell.call("dialogue_panel")
			var stage := _stage_node(shell)
			_check(panel.is_open() and stage.is_dialogue_locked(), "shell G: the recognition dialogue is open with the actor locked")
			# H8 capture phase (design, H8 contract detail step 1): capture the
			# survivors BEFORE the unload. lock_ref via the documented test-side
			# private-member access; state via the public getter; shell and
			# explorer refs only for negative validity checks.
			_unlocked_lock_ref = stage.get("_dialogue_lock") as PlayerControlLock
			_unloaded_state = shell.call("narrative_state")
			_unloaded_shell = shell
			_unloaded_explorer = stage.explorer()
			_check(_unlocked_lock_ref != null and _unlocked_lock_ref.is_locked() and stage.is_dialogue_locked(), "H8: the captured lock reference is alive and LOCKED at unload time")
			_check(_unloaded_state != null and _unloaded_state.completed_count() == 3, "H8: the pre-captured NarrativeState holds exactly pl_01+pl_02+pl_03")
			# Unload exactly as the N4.3-A stage-34 precedent does.
			change_scene_to_file(MAIN_SCENE)
			_stage = 66
			_wait_frames = 0
			return false
		66:
			if not _on_main():
				return false
			if _wait_frames < 8:
				return false
			# H8 step 3: assert on SURVIVORS only — the freed shell/stage/
			# explorer are only touched through is_instance_valid (negative
			# checks, never dereferenced).
			_check(not is_instance_valid(_unloaded_shell), "H8: the PrologueShell is freed after the direct scene unload")
			_check(not is_instance_valid(_unloaded_explorer), "H8: the explorer is freed after the direct scene unload")
			_check(_unlocked_lock_ref.is_locked() == false, "H8: the surviving PlayerControlLock reports RELEASED (unlock ran during the unload's synchronous teardown)")
			_check(_unloaded_state.completed_count() == 3 and not bool(_unloaded_state.is_completed(BEAT_04)), "H8: nothing was recorded by the unload (pl_04 not completed)")
			_check(_emissions.is_empty(), "H8: no delayed completion emission occurred across the unload frames")
			_unloaded_shell = null
			_unloaded_explorer = null
			_unlocked_lock_ref = null
			_unloaded_state = null
			_stage = 67
			_wait_frames = 0
			return false
		67:
			if not _on_main():
				return false
			# --- Shell H: H14 held interact across closure + A+C pair (H11) ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 68
			_wait_frames = 0
			return false
		68:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if not _check(shell.call("start_prologue"), "shell H starts the chain explicitly"):
				return true
			_stage = 69
			_wait_frames = 0
			return false
		69:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if bool(shell.call("in_exploration")):
				_check(shell.call("skip_current_exploration_beat"), "shell H skips pl_03 to reach pl_04")
				_connect_emission_listener(shell)
				_stage = 70
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		70:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if _wait_frames < 2:
				return false
			_teleport(explorer, 450.0)
			Input.action_press("interact")
			_stage = 71
			_wait_frames = 0
			return false
		71:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 72):
				return false
			_stage = 72
			_wait_frames = 0
			return false
		72:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			_check(inspectables.distinct_inspected_count() == 1, "shell H: object A recorded")
			# H14: HOLD interact from the accepting press onward (single press,
			# never released until after the segment ends).
			var explorer := _explorer_of(shell)
			_teleport(explorer, -280.0)
			Input.action_press("interact")
			_stage = 73
			_wait_frames = 0
			return false
		73:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			var panel: DialoguePanel = shell.call("dialogue_panel")
			if not _await_held_interact_effect(func() -> bool: return _emission_panel != null and _emission_panel.is_open(), 74):
				return false
			_stage = 74
			_wait_frames = 0
			return false
		74:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			var panel: DialoguePanel = shell.call("dialogue_panel")
			_check(inspectables.distinct_inspected_count() == 2, "H14/H11: the A+C pair is recorded (any two DISTINCT objects complete; D4)")
			_check(panel.is_open() and panel.get_body_text() == "I've seen this mark before...", "H14: the recognition opened from the accepting press while the key is HELD")
			panel.advance()
			_check(panel.get_body_text() == "Why does it keep appearing?", "the recognition advances while the key stays held")
			_stage = 75
			_wait_frames = 0
			return false
		75:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel: DialoguePanel = shell.call("dialogue_panel")
			panel.advance()
			var state: NarrativeState = shell.call("narrative_state")
			var inspectables := _inspectables_of(shell)
			_check(bool(state.is_completed(BEAT_04)) and state.completed_count() == 4, "H14/H11: the A+C pair completed pl_04 exactly once (R = 1)")
			_check(_emissions == [1], "H14: exactly one natural emission")
			_check(inspectables.distinct_inspected_count() == 2, "H14: the held key added NO second inspection")
			_check_terminal_state(shell, "H14/D3", true)
			_stage = 76
			_wait_frames = 0
			return false
		76:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			var inspectables := _inspectables_of(shell)
			if _wait_frames < 10:
				return false
			_check(_emissions == [1] and inspectables.distinct_inspected_count() == 2 and state.completed_count() == 4, "H14: the held interact across closure and segment end never re-inspects and never duplicates the completion (10 frames)")
			Input.action_release("interact")
			change_scene_to_file(MAIN_SCENE)
			_stage = 77
			_wait_frames = 0
			return false
		77:
			if not _on_main():
				return false
			# --- Hygiene: real files untouched, fixtures cleaned, metas removed ---
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
				_assert_sidecar_untouched(REAL_PROFILE_PATH + suffix, _real_profile_sidecars[suffix], "real profile sidecar %s" % suffix)
			_rm(PROFILE_FALSE)
			_rm(SAVE_NONE)
			if DirAccess.dir_exists_absolute(TEST_DIR):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
			Engine.remove_meta(AUTOSTART_META)
			Engine.remove_meta("crownfall_profile_path")
			Engine.remove_meta("crownfall_menu_save_path")
			_check(not Input.is_action_pressed("interact"), "no interact input state leaks past the suite")
			_check(not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "no movement input state leaks past the suite")
			if _failures == 0:
				print("PASS: All %d N43B Mark Inspection checks completed with 0 failures." % _checks)
				quit(0)
			else:
				printerr("FAIL: N43B Mark Inspection finished with %d failures out of %d checks." % [_failures, _checks])
				quit(1)
			return true
	return false
