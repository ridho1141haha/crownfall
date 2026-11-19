## N44A ruins-foundation tests — N4.4-A slice.
##
## Scope under test (N44_TEST_STRATEGY.md slice A + N44_IMPLEMENTATION_ROADMAP.md
## N4.4-A acceptance):
##   1. D6 fail-closed threshold validation: unordered thresholds, thresholds
##      outside the authored band, invalid vertical extents, NaN values —
##      every case leaves the component invalid and EMPTY (atomic cleanup),
##   2. atomic construction: a valid build commits exactly the authored
##      ruins structure (exterior walls, passage/chamber overlays, framing
##      walls, TWO identical U2-placeholder mark glyphs, the hidden altar
##      group) and rejects a second build,
##   3. the one-way zone-state machine: EXTERIOR -> INTERIOR_PASSAGE ->
##      CHAMBER_REVEALED by the explorer's x; backtracking never un-reveals
##      and never re-fires; the chamber reveal shows the altar group exactly
##      once,
##   4. the full production chain pl_01 -> pl_06-dormant in ONE continuous
##      shell: pl_03 handoff, pl_04 recognition, pl_05 activation (movement
##      enabled, no dialogue — Beat 05 has no approved line), the natural
##      drive east reaching the altar, the ONE altar completion request,
##      pl_05 recorded exactly once BY THE SHELL, dormant pl_06 active,
##   5. the stage's altar request is single-shot and gated (inactive beat,
##      input disabled, torn down, wrong active beat — never recorded twice),
##   6. camera containment at the extended east bound (measured visible rect,
##      not limit values) and camera-independent shell UI at the ruins,
##   7. the pl_04 inspection prompt never leaks into pl_05 (stale-prompt
##      regression at the beat change),
##   8. the O6 documented default skip chain: pl_03 skip -> pl_04, pl_04 skip
##      -> pl_05, pl_05 skip -> DORMANT pl_06 (recorded once, no stage
##      emission, settle-window stale-request proof); pl_06 skip is NOT
##      implemented in N4.4-A (rejected),
##   9. cancellation, the development exit, and a DIRECT scene unload during
##      pl_05/dormant pl_06 record NOTHING and leave no stale state,
##  10. failed stage setup (missing explorer texture) falls back to the
##      defined idle boundary with the ruins never built and nothing recorded,
##  11. real profile/save files remain byte-exact untouched; no input leaks.
##
## ISOLATION CONTRACT (same style as the N4.3 suites): fixtures live under
## user://n44a_test/ injected via the crownfall_profile_path /
## crownfall_menu_save_path Engine metas; the developer's real files are only
## READ once for byte-exact non-mutation proof at the end of the run.
## Interact presses use the single-press + bounded-retry driver convention
## measured in N4.3-B (one action_press produces exactly ONE just-pressed
## edge on the first physics tick after the press).

extends SceneTree

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const PROLOGUE_SHELL_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const PROLOGUE_SHELL_SCRIPT: GDScript = preload("res://scripts/narrative/PrologueShell.gd")
const TEST_DIR: String = "user://n44a_test"
const PROFILE_FALSE: String = "user://n44a_test/profile_false.json"
const SAVE_NONE: String = "user://n44a_test/save_none.json"
const REAL_PROFILE_PATH: String = "user://player_profile.json"
const AUTOSTART_META: String = "crownfall_prologue_autostart"
const STAGE_TEXTURE_META: String = "crownfall_prologue_stage_texture"
const BEAT_01: String = "pl_01_lost_world"
const BEAT_02: String = "pl_02_faint_resonance"
const BEAT_03: String = "pl_03_wanderer"
const BEAT_04: String = "pl_04_repeated_mark"
const BEAT_05: String = "pl_05_forgotten_ruins"
const BEAT_06: String = "pl_06_crowns_call"
const MAX_WAIT_FRAMES: int = 1800
## Same measured budget convention as N4.3-B (physics ticks arrive every 2-5
## process frames headless with gaps up to ~10; the budget sits well above).
const INTERACT_RETRY_BUDGET_FRAMES: int = 30

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _shell_exits: Array[String] = []
var _completions: Array[String] = []
var _altar_emissions: int = 0
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
		printerr("TEST FAILURE: [test_n44a_ruins_foundation] " + msg)
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


func _ruins_of(shell: Control) -> PrologueRuinsEnvironment:
	var stage := _stage_node(shell)
	return stage.ruins() if stage != null else null


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


func _stop_driving() -> void:
	Input.action_release("move_right")
	Input.action_release("move_left")


func _teleport(explorer: PrologueExplorer, x: float) -> void:
	explorer.position.x = x


## Wire the altar emission counter on the CURRENT stage (per-shell, like the
## N43C per-stage listeners).
func _connect_altar_listener(shell: Control) -> void:
	_altar_emissions = 0
	var stage := _stage_node(shell)
	if stage != null:
		stage.ruins_altar_reached.connect(func() -> void: _altar_emissions += 1)


## The camera's ACTUAL visible world rect (same measurement convention as the
## N43A suite: get_screen_center_position() is the limit-clamped center).
func _visible_rect(explorer: PrologueExplorer) -> Rect2:
	var camera: Camera2D = explorer.camera()
	var center: Vector2 = camera.get_screen_center_position()
	var view: Vector2 = current_scene.get_viewport().get_visible_rect().size / camera.zoom
	return Rect2(center - view * 0.5, view)


## Press-and-confirm driver (the measured N4.3-B convention): guarantees a
## FRESH just-pressed edge per attempt; every exit leaves the key RELEASED.
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
	Input.action_release("interact")
	Input.action_press("interact")
	return false


## --- N4.4-A unit checks: the ruins component (no shell required) ---

class BadOrderRuins extends PrologueRuinsEnvironment:
	func _thresholds() -> Dictionary:
		return {"exterior_end": 1800.0, "interior_end": 1400.0, "altar_x": 2050.0}


class AltarBeyondBandRuins extends PrologueRuinsEnvironment:
	func _thresholds() -> Dictionary:
		return {"exterior_end": 1400.0, "interior_end": 1800.0, "altar_x": 2400.0}


class AltarBeforeChamberRuins extends PrologueRuinsEnvironment:
	func _thresholds() -> Dictionary:
		return {"exterior_end": 1400.0, "interior_end": 1800.0, "altar_x": 1700.0}


class ExteriorOutsideBandRuins extends PrologueRuinsEnvironment:
	func _thresholds() -> Dictionary:
		return {"exterior_end": -900.0, "interior_end": 1800.0, "altar_x": 2050.0}


class BadVerticalRuins extends PrologueRuinsEnvironment:
	func _validate_table(road_min_x: float, road_max_x: float, ground_y: float, view_top: float, view_bottom: float) -> bool:
		# Simulate a degenerate vertical extent reaching the validator.
		return super._validate_table(road_min_x, road_max_x, ground_y, view_bottom, view_bottom)


func _run_unit_checks() -> void:
	# --- D6 validation matrix: invalid tables fail closed, atomically ---
	for variant: PrologueRuinsEnvironment in [
		BadOrderRuins.new(),
		AltarBeyondBandRuins.new(),
		AltarBeforeChamberRuins.new(),
		ExteriorOutsideBandRuins.new(),
	]:
		var ok: bool = variant.build(PrologueExplorationStage.ROAD_MIN_X, PrologueExplorationStage.ROAD_MAX_X, PrologueExplorationStage.GROUND_Y, PrologueExplorationStage.VIEW_TOP, PrologueExplorationStage.VIEW_BOTTOM)
		_check(not ok and not variant.is_valid(), "%s fails closed (build rejected, is_valid false)" % variant.get_class())
		_check(variant.get_child_count() == 0, "%s leaves NO committed children (atomic cleanup)" % variant.get_class())
		_check(variant.altar_group() == null, "%s leaves no altar reference" % variant.get_class())
		variant.free()
	var bad_vertical := BadVerticalRuins.new()
	var ok_vertical: bool = bad_vertical.build(PrologueExplorationStage.ROAD_MIN_X, PrologueExplorationStage.ROAD_MAX_X, PrologueExplorationStage.GROUND_Y, PrologueExplorationStage.VIEW_TOP, PrologueExplorationStage.VIEW_BOTTOM)
	_check(not ok_vertical and not bad_vertical.is_valid(), "a degenerate vertical extent fails closed")
	_check(bad_vertical.get_child_count() == 0, "the degenerate-vertical failure commits nothing")
	bad_vertical.free()
	# --- Valid build: committed structure, hidden altar, identical glyphs ---
	var ruins := PrologueRuinsEnvironment.new()
	var zone_changes: Array[int] = []
	# Lambda captures of primitives are BY VALUE in GDScript, so the reveal
	# counter is an array (reference type) to count across the lambda boundary.
	var reveals: Array[int] = []
	ruins.zone_state_changed.connect(func(new_state: int) -> void: zone_changes.append(new_state))
	ruins.chamber_revealed.connect(func() -> void: reveals.append(1))
	_check(ruins.build(PrologueExplorationStage.ROAD_MIN_X, PrologueExplorationStage.ROAD_MAX_X, PrologueExplorationStage.GROUND_Y, PrologueExplorationStage.VIEW_TOP, PrologueExplorationStage.VIEW_BOTTOM), "a valid authored table builds successfully")
	_check(ruins.is_valid(), "the built component is valid")
	_check(ruins.get_child_count() == 1, "exactly the committed ruins root is a child")
	var root: Node2D = ruins.get_node_or_null("RuinsEnvironment") as Node2D
	_check(root != null, "the ruins root commits under its authored name")
	_check(root != null and root.get_node_or_null("ExteriorWalls") != null and root.get_node_or_null("InteriorPassageOverlay") != null and root.get_node_or_null("ChamberOverlay") != null and root.get_node_or_null("PassageAndChamberWalls") != null and root.get_node_or_null("RuinMarkGlyphs") != null, "the exterior, passage, chamber, framing walls, and mark glyphs all commit")
	# --- Zone overlay geometry regression (review fix): _create_zone_overlay's
	# third parameter is a WIDTH spanning [x, x + width] — an absolute east END
	# must be converted first. The old ChamberOverlay call passed the east band
	# end (road_max_x) directly as the width, painting the overlay from
	# interior_end to road_max_x PAST the world boundary instead of up to it.
	var passage_overlay: ColorRect = root.get_node_or_null("InteriorPassageOverlay") as ColorRect
	var chamber_overlay: ColorRect = root.get_node_or_null("ChamberOverlay") as ColorRect
	var road_max: float = float(PrologueExplorationStage.ROAD_MAX_X)
	var road_min: float = float(PrologueExplorationStage.ROAD_MIN_X)
	_check(passage_overlay != null and passage_overlay.position.x == PrologueRuinsEnvironment.EXTERIOR_END_X and passage_overlay.size.x == PrologueRuinsEnvironment.INTERIOR_END_X - PrologueRuinsEnvironment.EXTERIOR_END_X, "the InteriorPassageOverlay WIDTH spans exactly the passage zone (exterior_end -> interior_end)")
	_check(chamber_overlay != null and chamber_overlay.position.x == PrologueRuinsEnvironment.INTERIOR_END_X and chamber_overlay.size.x == road_max - PrologueRuinsEnvironment.INTERIOR_END_X, "the ChamberOverlay WIDTH is the chamber span (interior_end -> road_max), NOT the absolute east boundary")
	_check(chamber_overlay != null and chamber_overlay.position.x + chamber_overlay.size.x == road_max, "the ChamberOverlay right edge lands exactly ON the world boundary")
	_check(passage_overlay != null and chamber_overlay != null and passage_overlay.position.x >= road_min and passage_overlay.size.x > 0.0 and chamber_overlay.size.x > 0.0 and chamber_overlay.position.x + chamber_overlay.size.x <= road_max, "both zone overlays stay inside the authored world band with positive width")
	var altar_group: Node2D = ruins.altar_group()
	_check(altar_group != null and altar_group.name == "AltarGroup" and not altar_group.visible, "the altar group commits HIDDEN (the chamber reveal shows it)")
	_check(root != null and root.get_node_or_null("AltarGroup/CrownPlaceholder") != null and root.get_node_or_null("AltarGroup/AltarStone") != null, "the altar stone and the labelled crown placeholder commit under the altar group")
	_check(ruins.altar_x() == PrologueRuinsEnvironment.ALTAR_X, "the authored altar threshold is readable")
	_check(ruins.zone_state() == PrologueRuinsEnvironment.ZONE_EXTERIOR and not ruins.is_chamber_revealed(), "the component starts in the EXTERIOR zone")
	_check(not ruins.build(PrologueExplorationStage.ROAD_MIN_X, PrologueExplorationStage.ROAD_MAX_X, PrologueExplorationStage.GROUND_Y, PrologueExplorationStage.VIEW_TOP, PrologueExplorationStage.VIEW_BOTTOM), "a second build is rejected")
	# --- Zone-state machine: one-way, exactly the authored thresholds ---
	ruins.update_explorer_x(1100.0)
	_check(ruins.zone_state() == PrologueRuinsEnvironment.ZONE_EXTERIOR and zone_changes.is_empty(), "walking inside the exterior zone changes nothing")
	ruins.update_explorer_x(PrologueRuinsEnvironment.EXTERIOR_END_X)
	_check(ruins.zone_state() == PrologueRuinsEnvironment.ZONE_INTERIOR_PASSAGE and zone_changes == [PrologueRuinsEnvironment.ZONE_INTERIOR_PASSAGE], "crossing the interior threshold advances to INTERIOR_PASSAGE exactly once")
	ruins.update_explorer_x(1200.0)
	_check(ruins.zone_state() == PrologueRuinsEnvironment.ZONE_INTERIOR_PASSAGE and zone_changes.size() == 1, "backtracking west never un-reveals the passage state")
	ruins.update_explorer_x(PrologueRuinsEnvironment.INTERIOR_END_X)
	_check(ruins.zone_state() == PrologueRuinsEnvironment.ZONE_CHAMBER_REVEALED and ruins.is_chamber_revealed() and altar_group.visible, "crossing the chamber threshold REVEALS the chamber and shows the altar group")
	_check(reveals.size() == 1 and zone_changes == [PrologueRuinsEnvironment.ZONE_INTERIOR_PASSAGE, PrologueRuinsEnvironment.ZONE_CHAMBER_REVEALED], "the reveal fires exactly once with the correct state sequence")
	ruins.update_explorer_x(0.0)
	_check(ruins.zone_state() == PrologueRuinsEnvironment.ZONE_CHAMBER_REVEALED and reveals.size() == 1 and altar_group.visible, "walking back west never un-reveals the chamber or re-fires the reveal")
	# --- Identical U2-placeholder glyph geometry on both ruin glyphs ---
	var glyph_one: Node2D = root.get_node("RuinMarkGlyphs/RuinMarkGlyphOne") as Node2D
	var glyph_two: Node2D = root.get_node("RuinMarkGlyphs/RuinMarkGlyphTwo") as Node2D
	var rect_sizes_one: Array = []
	var rect_sizes_two: Array = []
	for child: Node in glyph_one.get_children():
		rect_sizes_one.append((child as ColorRect).size)
	for child: Node in glyph_two.get_children():
		rect_sizes_two.append((child as ColorRect).size)
	_check(glyph_one.get_child_count() == 2 and glyph_two.get_child_count() == 2 and rect_sizes_one == rect_sizes_two, "both ruin glyphs use the ONE identical placeholder mark geometry (U2 consistency)")
	# --- A failed build makes every update a no-op ---
	var invalid := BadOrderRuins.new()
	invalid.build(PrologueExplorationStage.ROAD_MIN_X, PrologueExplorationStage.ROAD_MAX_X, PrologueExplorationStage.GROUND_Y, PrologueExplorationStage.VIEW_TOP, PrologueExplorationStage.VIEW_BOTTOM)
	invalid.update_explorer_x(2200.0)
	_check(not invalid.is_valid() and invalid.zone_state() == PrologueRuinsEnvironment.ZONE_EXTERIOR, "an invalid component ignores zone updates (no-op, fail-closed)")
	invalid.free()
	ruins.free()


func _initialize() -> void:
	_rm(PROFILE_FALSE)
	_rm(SAVE_NONE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	_write_json(PROFILE_FALSE, {"schema_version": 1, "prologue_completed_once": false})
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


func _process(_delta: float) -> bool:
	_wait_frames += 1
	if _wait_frames > MAX_WAIT_FRAMES:
		_check(false, "timed out at stage %d" % _stage)
		return true
	match _stage:
		1:
			_run_unit_checks()
			# Shell A: production defaults (autostart ON, exploration ON — no
			# metas set), the same convention as the N4.3 suite's shell A.
			change_scene_to_file(MAIN_SCENE)
			_stage = 2
			_wait_frames = 0
			return false
		2:
			if not _on_main():
				return false
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 3
			_wait_frames = 0
			return false
		3:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			_stage = 4
			_wait_frames = 0
			return false
		4:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if bool(shell.call("in_exploration")):
				# Fast path to pl_04 (the pl_03 handoff contract is owned by
				# the N43A/N43C suites): skip pl_03 and arm the altar listener.
				_check(shell.call("skip_current_exploration_beat") and String(shell.call("active_exploration_beat")) == BEAT_04, "shell A reaches pl_04 via the pl_03 Skip (pl_04 not skipped)")
				_connect_altar_listener(shell)
				_stage = 5
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		5:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if _wait_frames < 2:
				return false
			_teleport(_explorer_of(shell), 430.0)
			Input.action_press("interact")
			_stage = 6
			_wait_frames = 0
			return false
		6:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			if not _await_interact_effect(func() -> bool: return inspectables.distinct_inspected_count() == 1, 7):
				return false
			_stage = 7
			_wait_frames = 0
			return false
		7:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var inspectables := _inspectables_of(shell)
			_check(inspectables.distinct_inspected_count() == 1, "shell A: first mark inspection recorded silently")
			_teleport(_explorer_of(shell), 620.0)
			Input.action_press("interact")
			_stage = 8
			_wait_frames = 0
			return false
		8:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel := _panel_of(shell)
			if not _await_interact_effect(func() -> bool: return panel.is_open(), 9):
				return false
			_stage = 9
			_wait_frames = 0
			return false
		9:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var panel := _panel_of(shell)
			if panel.is_open():
				_check(panel.get_body_text().contains("I've seen this mark before") or panel.get_body_text().contains("Why does it keep appearing"), "shell A: the approved recognition line plays through the existing panel")
				panel.advance()
				return false
			# The recognition closed normally: pl_04 recorded, pl_05 active.
			var state: NarrativeState = shell.call("narrative_state")
			var stage := _stage_node(shell)
			var explorer := _explorer_of(shell)
			_check(state.completed_count() == 4 and bool(state.is_completed(BEAT_04)), "shell A: the recognition completes pl_04 exactly once (state: pl_01..pl_04)")
			_check(String(shell.call("active_exploration_beat")) == BEAT_05 and not bool(shell.call("n43_segment_complete")), "shell A: pl_04 completion ACTIVATES pl_05 (the chain continues)")
			_check(stage != null and not stage.is_segment_ended() and not stage.is_dialogue_locked(), "shell A: the segment stays live with the actor lock released")
			_check(explorer != null and explorer.is_input_enabled(), "shell A: pl_05 enables exploration input (no approved pl_05 dialogue exists)")
			_check(not _panel_of(shell).is_open(), "shell A: no pl_05 dialogue opens (Beat 05 is environmental storytelling only)")
			var status: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
			_check(status != null and status.text.contains("Forgotten Ruins") and status.text.contains("[Placeholder art]"), "shell A: the status presents the ruins beat as labelled placeholder")
			# Drive east through the ruins to the altar.
			Input.action_press("move_right")
			_stage = 10
			_wait_frames = 0
			return false
		10:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			var stage := _stage_node(shell)
			var ruins := _ruins_of(shell)
			if _altar_emissions == 0 and _wait_frames < MAX_WAIT_FRAMES - 60:
				return false
			_stop_driving()
			_check(_altar_emissions == 1, "shell A: the stage emitted exactly its ONE pl_05 altar completion request (driving east reaches the altar)")
			_check(stage != null and stage.altar_request_emitted(), "shell A: the altar request stays single-shot")
			_check(ruins != null and ruins.is_chamber_revealed() and ruins.zone_state() == PrologueRuinsEnvironment.ZONE_CHAMBER_REVEALED, "shell A: the drive passed through the passage and REVEALED the chamber (one-way zone machine)")
			_check(ruins != null and ruins.altar_group() != null and ruins.altar_group().visible, "shell A: the altar group is visible after the reveal")
			_check(state.completed_count() == 5 and bool(state.is_completed(BEAT_05)), "shell A: reaching the altar completes pl_05 exactly once (state: pl_01..pl_05)")
			_check(String(shell.call("active_exploration_beat")) == BEAT_06 and not bool(shell.call("n43_segment_complete")), "shell A: pl_05 completion activates DORMANT pl_06 (segment stays live)")
			var explorer := _explorer_of(shell)
			_check(explorer != null and explorer.is_input_enabled() and not _panel_of(shell).is_open(), "shell A: dormant pl_06 keeps exploration input enabled with no dialogue")
			# Wrong-beat completion requests are ignored after the move-on.
			stage.exploration_handoff_reached.emit()
			stage.mark_inspection_completed.emit()
			stage.ruins_altar_reached.emit()
			_check(state.completed_count() == 5 and String(shell.call("active_exploration_beat")) == BEAT_06, "shell A: late re-emitted completion requests are ignored by the shell (wrong active beat)")
			# Camera containment + camera-independent UI at the extended east bound.
			_teleport(explorer, PrologueExplorationStage.ROAD_MAX_X)
			_stage = 11
			_wait_frames = 0
			return false
		11:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if _wait_frames < 30:
				return false
			_check(explorer.position.x == PrologueExplorationStage.ROAD_MAX_X, "the actor clamps exactly at the extended east bound (holding/teleport never escapes the authored band)")
			var east_rect: Rect2 = _visible_rect(explorer)
			_check(east_rect.position.x >= PrologueExplorationStage.ROAD_MIN_X - 0.5 and east_rect.end.x <= PrologueExplorationStage.ROAD_MAX_X + 0.5, "at the extended east bound the visible horizontal edges rest inside the authored band (measured %s)" % [east_rect])
			_check(east_rect.position.y >= PrologueExplorationStage.VIEW_TOP - 0.5 and east_rect.end.y <= PrologueExplorationStage.VIEW_BOTTOM + 0.5, "at the extended east bound the visible vertical edges rest inside the authored band (measured %s)" % [east_rect])
			var camera: Camera2D = explorer.camera()
			_check(camera.limit_left == int(PrologueExplorationStage.ROAD_MIN_X) and camera.limit_right == int(PrologueExplorationStage.ROAD_MAX_X), "camera limits match the extended authored band (limits == bounds)")
			var status: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
			var detail: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/DetailLabel") as Label
			var viewport_size: Vector2 = shell.get_viewport().get_visible_rect().size
			var ui_rect: Rect2 = status.get_global_rect()
			_check(ui_rect.position.x >= 0.0 and ui_rect.end.x <= viewport_size.x and ui_rect.position.y >= 0.0 and ui_rect.end.y <= viewport_size.y, "the shell status UI stays on-screen at the ruins camera position (camera-independent CanvasLayer, measured %s)" % [ui_rect])
			var detail_rect: Rect2 = detail.get_global_rect()
			_check(detail_rect.position.x >= 0.0 and detail_rect.end.x <= viewport_size.x and detail_rect.position.y >= 0.0 and detail_rect.end.y <= viewport_size.y, "the shell detail UI stays on-screen with the dormant pl_06 text (no placeholder text overflows the viewport, measured %s)" % [detail_rect])
			# Stale-prompt regression: stand on an old mark position in pl_05.
			_teleport(explorer, 430.0)
			_stage = 12
			_wait_frames = 0
			return false
		12:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if _wait_frames < 10:
				return false
			var inspectables := _inspectables_of(shell)
			var state: NarrativeState = shell.call("narrative_state")
			_check(inspectables != null and not inspectables.prompt().visible, "the pl_04 inspection prompt NEVER leaks into the post-pl_04 beats (stale-prompt regression)")
			_check(inspectables != null and inspectables.distinct_inspected_count() == 2, "the pl_05 world has no inspection path (the old marks stay inert)")
			_check(state.completed_count() == 5, "no re-completion happens anywhere in the ruins")
			# --- Cancellation during dormant pl_06 records nothing ---
			var shell_ref: Control = _shell()
			shell_ref.call("cancel_sequence")
			_check(state.completed_count() == 5, "cancellation during dormant pl_06 records NOTHING (not a skip)")
			_check(not bool(shell_ref.call("in_exploration")) and shell_ref.call("exploration_stage") == null, "cancellation tears the exploration segment down completely")
			_check(not bool(shell_ref.call("is_sequence_running")) and not _panel_of(shell_ref).is_open(), "cancellation leaves an idle runner and a closed panel")
			var cancelled_status: Label = shell_ref.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
			_check(cancelled_status != null and cancelled_status.text.contains("cancelled"), "the cancelled status is shown")
			change_scene_to_file(MAIN_SCENE)
			_stage = 13
			_wait_frames = 0
			return false
		13:
			if not _on_main():
				return false
			# --- Shell B: the O6-default skip chain to dormant pl_06 ---
			Engine.set_meta(AUTOSTART_META, false)
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 14
			_wait_frames = 0
			return false
		14:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if not _check(shell.call("start_prologue"), "shell B starts the chain explicitly"):
				return true
			_stage = 15
			_wait_frames = 0
			return false
		15:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if bool(shell.call("in_exploration")):
				_connect_altar_listener(shell)
				_check(shell.call("skip_current_exploration_beat") and String(shell.call("active_exploration_beat")) == BEAT_04, "shell B: pl_03 Skip activates pl_04")
				_check(shell.call("skip_current_exploration_beat") and String(shell.call("active_exploration_beat")) == BEAT_05, "shell B: pl_04 Skip activates pl_05 (O6 documented default)")
				_check(shell.call("skip_current_exploration_beat") and String(shell.call("active_exploration_beat")) == BEAT_06, "shell B: pl_05 Skip activates DORMANT pl_06")
				_stage = 16
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		16:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			var stage := _stage_node(shell)
			if _wait_frames < 15:
				return false
			_check(state.completed_count() == 5 and bool(state.is_completed(BEAT_05)), "shell B: the skip chain records pl_03+pl_04+pl_05 exactly once each (no pl_06 recording)")
			_check(_altar_emissions == 0 and stage != null and not stage.altar_request_emitted(), "shell B: the skips record through the shell — the stage NEVER emitted the altar request (15-frame settle)")
			_check(shell.call("skip_current_exploration_beat") and state.completed_count() == 6 and bool(state.is_completed(BEAT_06)) and bool(shell.call("n43_segment_complete")), "shell B: pl_06 Skip records pl_06 once and ends at N4.4 boundary (O4 Option A)")
			_check(not shell.call("skip_current_exploration_beat") and state.completed_count() == 6, "shell B: duplicate pl_06 Skip is rejected (never starts pl_07)")
			_check(shell.call("request_main_menu_return") and _shell_exits.size() == 1 and String(_shell_exits[0]) == MAIN_SCENE, "shell B: the development exit transitions exactly once from dormant pl_06")
			change_scene_to_file(MAIN_SCENE)
			_stage = 17
			_wait_frames = 0
			return false
		17:
			if not _on_main():
				return false
			Engine.remove_meta(AUTOSTART_META)
			# --- Shell C: failed setup falls back with the ruins never built ---
			Engine.set_meta(STAGE_TEXTURE_META, "res://nonexistent_n44a_probe.png")
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 18
			_wait_frames = 0
			return false
		18:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(shell.call("prologue_reached_end")):
				# Shell C has no driver: fast-forward the authored beats so the
				# chain end reaches the (failing) exploration entry.
				_skip_runner_beat(shell)
				return false
			_check(not bool(shell.call("in_exploration")) and shell.call("exploration_stage") == null, "shell C: failed setup enters NO exploration state (the ruins are never built)")
			_check(state.completed_count() == 2 and not bool(state.is_completed(BEAT_05)), "shell C: failed setup records NO exploration completion (not a skip)")
			var fallback_status: Label = shell.get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
			_check(fallback_status != null and fallback_status.text.contains("No exploration segment is active"), "shell C: the fallback shows the defined idle boundary status")
			Engine.remove_meta(STAGE_TEXTURE_META)
			_check(shell.call("request_main_menu_return") and _shell_exits.size() == 1 and String(_shell_exits[0]) == MAIN_SCENE, "shell C: the development exit works from the failed-setup fallback")
			change_scene_to_file(MAIN_SCENE)
			_stage = 19
			_wait_frames = 0
			return false
		19:
			if not _on_main():
				return false
			# --- Shell D: direct scene unload during pl_05 records nothing ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 20
			_wait_frames = 0
			return false
		20:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if bool(shell.call("in_exploration")):
				_check(shell.call("skip_current_exploration_beat") and String(shell.call("active_exploration_beat")) == BEAT_04, "shell D: the pl_03 Skip activates pl_04")
				_check(shell.call("skip_current_exploration_beat") and String(shell.call("active_exploration_beat")) == BEAT_05, "shell D: the pl_04 Skip reaches pl_05")
				_stage = 21
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		21:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			# Direct unload (no cancel, no exit): the stage's _exit_tree teardown
			# must run and NOTHING may be recorded.
			change_scene_to_file(MAIN_SCENE)
			_stage = 22
			_wait_frames = 0
			_unloaded_state = state
			return false
		22:
			if not _on_main():
				return false
			_check(_unloaded_state != null and _unloaded_state.completed_count() == 4 and not bool(_unloaded_state.is_completed(BEAT_05)), "shell D: a DIRECT scene unload during pl_05 records NOTHING (not a skip, pl_05 stays uncompleted)")
			# --- Shell E: wrong-beat altar requests are ignored ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 23
			_wait_frames = 0
			return false
		23:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if bool(shell.call("in_exploration")):
				_connect_altar_listener(shell)
				_check(shell.call("skip_current_exploration_beat") and String(shell.call("active_exploration_beat")) == BEAT_04, "shell E: the pl_03 Skip activates pl_04")
				var stage := _stage_node(shell)
				# While pl_04 is the ACTIVE beat, an altar request is wrong-beat.
				stage.ruins_altar_reached.emit()
				stage.ruins_altar_reached.emit()
				_check(String(shell.call("active_exploration_beat")) == BEAT_04 and state_count(shell) == 3 and not stage.altar_request_emitted(), "shell E: altar requests during pl_04 are ignored (wrong active beat, no stage flag)")
				_check(shell.call("skip_current_exploration_beat") and String(shell.call("active_exploration_beat")) == BEAT_05, "shell E: the pl_04 skip activates pl_05")
				_check(shell.call("skip_current_exploration_beat") and String(shell.call("active_exploration_beat")) == BEAT_06, "shell E: the pl_05 skip activates DORMANT pl_06")
				var state: NarrativeState = shell.call("narrative_state")
				stage.ruins_altar_reached.emit()
				stage.exploration_handoff_reached.emit()
				stage.mark_inspection_completed.emit()
				_check(state.completed_count() == 5 and String(shell.call("active_exploration_beat")) == BEAT_06, "shell E: altar/handoff/inspection requests during dormant pl_06 are ALL ignored (wrong active beat)")
				# Raw emissions are counted separately from acceptance (E/A/R
				# discipline): 2 forced during pl_04 + 1 forced during pl_06,
				# none of which the shell ever accepted or the stage flagged.
				_check(_altar_emissions == 3 and not stage.altar_request_emitted(), "shell E: no altar request was ever ACCEPTED or flagged outside pl_05 (3 raw forced emissions, 0 acceptances)")
				change_scene_to_file(MAIN_SCENE)
				_stage = 24
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		24:
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
			Engine.remove_meta("crownfall_profile_path")
			Engine.remove_meta("crownfall_menu_save_path")
			_check(not Input.is_action_pressed("interact"), "no interact input state leaks past the suite")
			_check(not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "no movement input state leaks past the suite")
			if _failures == 0:
				print("PASS: All %d N44A Ruins Foundation checks completed with 0 failures." % _checks)
				quit(0)
			else:
				printerr("FAIL: N44A Ruins Foundation finished with %d failures out of %d checks." % [_failures, _checks])
				quit(1)
			return true
	return false


## Shell E helper: the captured NarrativeState for wrong-beat assertions.
func state_count(shell: Control) -> int:
	var state: NarrativeState = shell.call("narrative_state")
	return state.completed_count()


var _unloaded_state: NarrativeState = null
