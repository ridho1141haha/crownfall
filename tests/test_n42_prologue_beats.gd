extends SceneTree

## N4.2 Prologue beat tests: authored content pl_01 "The Lost World" and
## pl_02 "A Faint Resonance" playing through the existing N4.1 shell.
##
## Covered contract areas:
##   1. both authored sequences load and pass fail-closed NarrativeData
##      validation (and the whole payload validates with unique ids),
##   2. the shell auto-starts pl_01 on route load (production default) and
##      an explicit start_prologue() works on an idle shell,
##   3. dialogue progression and completion through the existing panel,
##   4. control lock during beats and deterministic restoration afterwards,
##   5. NarrativeState records both completions exactly once,
##   6. the chain advances pl_01 -> pl_02 in order and stops at the N4.2
##      boundary with NO scene transition (shore handoff stays N4.5),
##   7. invalid narrative data fails closed without side effects, and a
##      non-beat sequence completes without triggering chaining,
##   8. sequence cancellation cleans up without completion, the development
##      exit still cancels a running beat, and skip fast-forwards a beat
##      while completing it exactly once,
##   9. no PlayerProfile or world-save modification anywhere (byte-exact).
##
## ISOLATION CONTRACT (same style as test_n40/test_n41): every fixture lives
## under user://n42_test/ and is injected through the crownfall_profile_path /
## crownfall_menu_save_path Engine metas. The developer's real
## user://player_profile.json, user://save_slot_0.json and their sidecars are
## only READ once for byte-exact non-mutation proof at the end of the run.
## Fixture sidecars are cleaned before and after the run so re-runs stay
## idempotent.
##
## The shell's production auto-start (Engine meta
## crownfall_prologue_autostart, default true) is exercised in stages 9-10;
## earlier stages set it false to drive start_prologue() explicitly, exactly
## like the established crownfall_load_on_start injection convention.

const MAIN_SCRIPT: GDScript = preload("res://scripts/core/Main.gd")
const PROLOGUE_SHELL_SCRIPT: GDScript = preload("res://scripts/narrative/PrologueShell.gd")
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const PROLOGUE_SHELL_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const TEST_DIR: String = "user://n42_test"
const PROFILE_MISSING: String = "user://n42_test/profile_missing.json"
const PROFILE_FALSE: String = "user://n42_test/profile_false.json"
const PROFILE_TRUE: String = "user://n42_test/profile_true.json"
const SAVE_NONE: String = "user://n42_test/save_none.json"
const SAVE_PREV: String = "user://n42_test/save_prev.json"
const REAL_PROFILE_PATH: String = "user://player_profile.json"
const AUTOSTART_META: String = "crownfall_prologue_autostart"
const BEAT_01: String = "pl_01_lost_world"
const BEAT_02: String = "pl_02_faint_resonance"
const MAX_WAIT_FRAMES: int = 900

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _routes: Array[String] = []
var _shell_exits: Array[String] = []
## cue_id observations from the shell's injected cue observer.
var _cues: Array[String] = []
## sequence_completed observations for the current shell instance.
var _completions: Array[String] = []
## Guard so the stage-11 smoke sequence is started exactly once per run.
var _smoke_played: bool = false
## Completion count snapshot taken when the smoke sequence started.
var _smoke_base: int = 0
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
		printerr("TEST FAILURE: [test_n42_prologue_beats] " + msg)
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
	# missing (same convention as the N4.0/N4.1 suites).
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
	_cues.clear()
	_shell_exits.clear()
	shell.call("set_exit_transition", func(scene_path: String) -> void: _shell_exits.append(scene_path))
	shell.call("set_cue_player", func(cue_id: String) -> void: _cues.append(cue_id))
	var runner: SequenceRunner = shell.call("sequence_runner")
	runner.sequence_completed.connect(func(sequence_id: String) -> void: _completions.append(sequence_id))


func _advance_if_open(shell: Control) -> void:
	var panel: DialoguePanel = shell.call("dialogue_panel")
	if panel.is_open():
		panel.advance()


func _fixture_completions_untouched() -> void:
	# Beats, chaining, cancellation, skipping, and exits must never create or
	# change a profile file (N4.2 adds no completion marking anywhere).
	_check(not FileAccess.file_exists(PROFILE_MISSING), "missing profile fixture stays missing after beat playback")
	_check(FileAccess.get_file_as_string(PROFILE_FALSE) == JSON.stringify({"schema_version": 1, "prologue_completed_once": false}, "\t"), "PROFILE_FALSE fixture is byte-exact unchanged after beat playback")


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
	# Explicit-flow first (stages 2-7); the auto-start default is exercised in
	# stages 9-10 (same Engine-meta injection convention as the suites above).
	Engine.set_meta(AUTOSTART_META, false)
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
			# --- Real entry flow: first-ever New Game routes to the shell ---
			_press(true)
			_check(_routes.size() == 1 and String(_routes[0]) == String(MAIN_SCRIPT.PROLOGUE_ROUTE_SCENE), "first-ever New Game routes to the Prologue shell (N4.0 contract preserved)")
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 2
			_wait_frames = 0
			return false
		2:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			# --- Autostart disabled: the shell stays idle until started ---
			_check(shell.call("is_initialized"), "shell runtime initializes on scene-ready")
			_check(not shell.call("is_sequence_running") and shell.call("completed_sequence_count") == 0 and shell.call("current_beat_id") == "" and not shell.call("prologue_reached_end"), "with autostart disabled the shell starts idle (no beat staged)")
			# --- Area 1: both authored beats load and validate fail-closed ---
			var beat_01: Dictionary = PrologueBeats.get_beat(BEAT_01)
			var beat_02: Dictionary = PrologueBeats.get_beat(BEAT_02)
			_check(NarrativeData.validate_sequence(beat_01), "pl_01_lost_world sequence passes NarrativeData validation")
			_check(NarrativeData.validate_sequence(beat_02), "pl_02_faint_resonance sequence passes NarrativeData validation")
			var payload: Dictionary = {"sequences": [beat_01, beat_02]}
			var payload_result: Dictionary = NarrativeData.validate_sequences_payload(payload)
			_check(bool(payload_result.get("ok", false)) and (payload_result.get("sequences", []) as Array).size() == 2, "the N4.2 beat payload validates as a whole with unique sequence ids")
			_check(PrologueBeats.is_beat(BEAT_01) and PrologueBeats.is_beat(BEAT_02) and not PrologueBeats.is_beat("n41_shell_smoke"), "is_beat recognizes exactly the authored beat ids")
			_check(PrologueBeats.get_beat("nonexistent_beat").is_empty(), "get_beat returns empty for unknown ids (no invented content)")
			_check(PrologueBeats.stage_caption("unknown_cue").begins_with("[Placeholder stage]"), "unknown cue captions stay labelled placeholders")
			# --- Area 2: explicit chain start plays pl_01 ---
			_wire_shell_observers(shell)
			_check(shell.call("start_prologue"), "start_prologue plays the first uncompleted authored beat")
			_check(shell.call("is_sequence_running") and shell.call("current_beat_id") == BEAT_01, "pl_01_lost_world is staged as the current beat")
			var panel: DialoguePanel = shell.call("dialogue_panel")
			_check(panel.is_open(), "pl_01 opens the dialogue panel for its narration (input isolation surface active)")
			_check(panel.get_speaker_text() == "Narration" and panel.get_body_text().contains("Long ago"), "pl_01 presents the Story Design candidate narration verbatim")
			var runner: SequenceRunner = shell.call("sequence_runner")
			_check(runner.is_control_locked(), "lock_control engages the player control lock for the cinematic beat")
			_check(_cues == [PrologueBeats.CUE_PL01_PROSPERITY], "the prosperity cue fired before the first dialogue step")
			var backdrop: ColorRect = shell.get_node_or_null("StageBackdrop") as ColorRect
			var caption: Label = shell.get_node_or_null("StageBackdrop/StageCaption") as Label
			_check(backdrop != null and backdrop.visible and caption != null and caption.text.contains("[Placeholder art] Aetherion beneath the First Light"), "the labelled placeholder stage shows the prosperity state")
			_check(shell.call("start_prologue") == false, "start_prologue is rejected while a beat is already running (busy guard)")
			_stage = 3
			_wait_frames = 0
			return false
		3:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			# --- Area 3 + 6: advance through pl_01; chain advances to pl_02 ---
			if shell.call("is_sequence_running") and not _completions.has(BEAT_01):
				_advance_if_open(shell)
				return false
			_check(_completions == [BEAT_01], "sequence_completed fired exactly once for pl_01")
			_check(shell.call("completed_sequence_count") == 1 and bool((shell.call("narrative_state") as NarrativeState).is_completed(BEAT_01)), "NarrativeState records the pl_01 completion")
			_check(shell.call("is_sequence_running") and shell.call("current_beat_id") == BEAT_02, "the chain advanced automatically to pl_02_faint_resonance after pl_01")
			_check(_cues.size() >= 3 and String(_cues[0]) == PrologueBeats.CUE_PL01_PROSPERITY and String(_cues[1]) == PrologueBeats.CUE_PL01_ECLIPSE and String(_cues[2]) == PrologueBeats.CUE_PL01_RUINS, "pl_01 stage cues fired in story order (prosperity, eclipse, ruins)")
			var panel2: DialoguePanel = shell.call("dialogue_panel")
			_check(panel2.is_open() and panel2.get_speaker_text() == "Narration" and panel2.get_body_text().contains("old stone wall"), "pl_02 opens with the childhood flashback framing")
			var runner2: SequenceRunner = shell.call("sequence_runner")
			_check(runner2.is_control_locked(), "pl_02 re-locks control for its flashback")
			_stage = 4
			_wait_frames = 0
			return false
		4:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			# --- Area 5 + 6: complete pl_02; the chain stops at the boundary ---
			if shell.call("is_sequence_running") or not shell.call("prologue_reached_end"):
				_advance_if_open(shell)
				return false
			_check(_completions == [BEAT_01, BEAT_02], "sequence_completed fired exactly once per beat, in chain order")
			_check(shell.call("completed_sequence_count") == 2, "NarrativeState records exactly two completions for the N4.2 opening")
			_check(bool((shell.call("narrative_state") as NarrativeState).is_completed(BEAT_02)), "NarrativeState records the pl_02 completion")
			_check(shell.call("prologue_reached_end"), "the chain stops at the N4.2 boundary (no pl_03+ content exists)")
			_check(not shell.call("is_sequence_running") and shell.call("current_beat_id") == "", "the runner is idle after the boundary")
			_check(not (shell.call("dialogue_panel") as DialoguePanel).is_open(), "the dialogue panel is closed after the boundary")
			var runner3: SequenceRunner = shell.call("sequence_runner")
			_check(not runner3.is_control_locked(), "control is restored after the last beat (unlock via runner cleanup)")
			var backdrop2: ColorRect = shell.get_node_or_null("StageBackdrop") as ColorRect
			_check(backdrop2 != null and not backdrop2.visible, "the placeholder stage is hidden after the boundary")
			_check(_cues == [PrologueBeats.CUE_PL01_PROSPERITY, PrologueBeats.CUE_PL01_ECLIPSE, PrologueBeats.CUE_PL01_RUINS, PrologueBeats.CUE_PL02_CHILDHOOD, PrologueBeats.CUE_PL02_RESONANCE], "all five stage cues fired in story order across both beats (exactly one manifestation)")
			_check(not shell.call("is_exit_started") and _shell_exits.is_empty(), "the N4.2 boundary performs NO scene transition (shore handoff stays N4.5)")
			var status: Label = shell.get_node_or_null("CenterContainer/VBoxContainer/StatusLabel") as Label
			var detail: Label = shell.get_node_or_null("CenterContainer/VBoxContainer/DetailLabel") as Label
			_check(status != null and status.text.contains("Later beats (N4.3+)"), "the boundary status text names the next unimplemented milestone")
			_check(detail != null and detail.text.contains("N4.5"), "the boundary detail text keeps the shore handoff contract visible")
			_fixture_completions_untouched()
			# Fresh instance for the cancellation path.
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 6
			_wait_frames = 0
			return false
		6:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_check(not shell.call("is_sequence_running") and shell.call("completed_sequence_count") == 0 and not shell.call("prologue_reached_end"), "a fresh shell instance starts with clean per-run state (non-resumable Prologue)")
			_wire_shell_observers(shell)
			_check(shell.call("start_prologue"), "restart via start_prologue plays pl_01 again on a fresh instance")
			_check(shell.call("current_beat_id") == BEAT_01, "the fresh chain stages pl_01")
			# --- Area 8: cancellation cleans up without completion ---
			shell.call("cancel_sequence")
			_check(not shell.call("is_sequence_running") and shell.call("current_beat_id") == "", "cancel stops the running beat and clears chain staging")
			_check(_completions.is_empty() and shell.call("completed_sequence_count") == 0, "cancel completes nothing (no sequence_completed, no NarrativeState record)")
			_check(not (shell.call("dialogue_panel") as DialoguePanel) .is_open(), "cancel closes the dialogue panel")
			var runner4: SequenceRunner = shell.call("sequence_runner")
			_check(not runner4.is_control_locked(), "cancel restores control (lock cleanup)")
			_check(not shell.call("prologue_reached_end"), "the chain does NOT advance on cancellation (no completion, no boundary)")
			var backdrop3: ColorRect = shell.get_node_or_null("StageBackdrop") as ColorRect
			_check(backdrop3 != null and not backdrop3.visible, "cancel hides the placeholder stage")
			_check(not shell.call("is_exit_started") and _shell_exits.is_empty(), "cancellation triggers no exit or transition")
			_stage = 7
			_wait_frames = 0
			return false
		7:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			# --- Area 8: the development exit still cancels a running beat ---
			_check(shell.call("start_prologue"), "start_prologue works again after cancellation (per-run restart)")
			_check(shell.call("is_sequence_running") and shell.call("current_beat_id") == BEAT_01, "pl_01 is running before the development exit")
			_check(shell.call("request_main_menu_return"), "the development exit is accepted while a beat runs")
			_check(not shell.call("is_sequence_running"), "the development exit stops the running beat")
			_check(_completions.is_empty() and shell.call("completed_sequence_count") == 0, "the development exit completes nothing")
			_check(_shell_exits.size() == 1 and String(_shell_exits[0]) == "res://scenes/main/Main.tscn", "the development exit transitions to the main menu exactly once")
			_fixture_completions_untouched()
			change_scene_to_file(MAIN_SCENE)
			_stage = 8
			_wait_frames = 0
			return false
		8:
			if not _on_main():
				return false
			# --- Areas 2 + 8: production auto-start default ON ---
			Engine.set_meta(AUTOSTART_META, true)
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 9
			_wait_frames = 0
			return false
		9:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			# --- Auto-start: pl_01 begins without any explicit call ---
			_check(shell.call("is_sequence_running") and shell.call("current_beat_id") == BEAT_01 and shell.call("completed_sequence_count") == 0, "the shell auto-starts pl_01 on route load (production default, pl_01 entry condition)")
			var panel3: DialoguePanel = shell.call("dialogue_panel")
			_check(panel3.is_open() and panel3.get_body_text().contains("Long ago"), "the auto-started beat opens with its first narration line")
			var runner5: SequenceRunner = shell.call("sequence_runner")
			_check(runner5.is_control_locked(), "the auto-started beat locks control")
			var caption2: Label = shell.get_node_or_null("StageBackdrop/StageCaption") as Label
			_check(caption2 != null and caption2.text.contains("Aetherion beneath the First Light"), "the auto-start flow shows the prosperity stage state (cue before wiring is still observed by the built-in stage)")
			_wire_shell_observers(shell)
			# --- Area 8: skip fast-forwards and still completes exactly once ---
			shell.call("skip_sequence")
			_check(_completions == [BEAT_01], "skip completes the running beat exactly once (skip_allowed)")
			_check(shell.call("completed_sequence_count") == 1, "NarrativeState records the skipped beat's completion")
			_check(shell.call("is_sequence_running") and shell.call("current_beat_id") == BEAT_02, "the chain advances to pl_02 after the skipped pl_01")
			_check(_cues == [PrologueBeats.CUE_PL02_CHILDHOOD], "skip fast-forwards pl_01's remaining steps (later pl_01 cues never fire; pl_02 stages normally)")
			_stage = 10
			_wait_frames = 0
			return false
		10:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			# --- Drive the chained pl_02 to the boundary ---
			if shell.call("is_sequence_running") or not shell.call("prologue_reached_end"):
				_advance_if_open(shell)
				return false
			# Boundary reached once: everything below is synchronous.
			_check(_completions == [BEAT_01, BEAT_02], "auto-start + skip + chain produce exactly one completion per beat")
			_check(_cues == [PrologueBeats.CUE_PL02_CHILDHOOD, PrologueBeats.CUE_PL02_RESONANCE], "pl_02 stages both of its cues after the skip point")
			# --- Area 7: invalid narrative data fails closed ---
			var before: int = shell.call("completed_sequence_count")
			_check(shell.call("play_sequence", {}) == false, "an empty payload fails closed")
			_check(shell.call("play_sequence", {"id": "n42_bad_op", "steps": [{"op": "explode"}]}) == false, "an unknown op fails closed")
			_check(shell.call("play_sequence", {"id": "n42_bad_speaker", "steps": [{"op": "dialogue", "lines": [{"speaker": "", "text": "no"}]}]}) == false, "an empty speaker fails closed")
			_check(shell.call("play_sequence", {"id": "n42_bad_text", "steps": [{"op": "dialogue", "lines": [{"speaker": "Narration", "text": "x".repeat(600)}]}]}) == false, "oversized dialogue text fails closed")
			_check(shell.call("play_sequence", {"id": "n42_bad_scene", "steps": [{"op": "change_scene", "scene_path": "user://not_allowed.tscn"}]}) == false, "a non-res:// scene path fails closed")
			_check(shell.call("play_sequence", {"id": "n42_bad_steps", "id2": "x", "steps": "nope"}) == false, "unknown fields and non-array steps fail closed")
			_check(not shell.call("is_sequence_running") and shell.call("completed_sequence_count") == before and shell.call("current_beat_id") == "", "invalid payloads leave the runner idle with unchanged completion state")
			_stage = 11
			_wait_frames = 0
			return false
		11:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			# --- Area 7: a valid non-beat sequence never triggers chaining ---
			if not _smoke_played:
				_smoke_base = shell.call("completed_sequence_count")
				var smoke: Dictionary = {"id": "n42_non_beat_smoke", "steps": [{"op": "dialogue", "lines": [{"speaker": "Development Check", "text": "N4.2 non-beat sequence plumbing check."}]}, {"op": "finish"}]}
				_check(shell.call("play_sequence", smoke), "a valid non-beat sequence still plays through the shell API")
				_smoke_played = true
				return false
			if shell.call("is_sequence_running"):
				_advance_if_open(shell)
				return false
			_check(shell.call("completed_sequence_count") == _smoke_base + 1 and (shell.call("narrative_state") as NarrativeState).is_completed("n42_non_beat_smoke"), "the non-beat sequence completes and is recorded")
			_check(shell.call("current_beat_id") == "" and shell.call("prologue_reached_end"), "a non-beat completion does NOT advance or reset the beat chain")
			# --- Development exit is still the only way out after the boundary ---
			var dev_btn: Button = shell.find_child("DevExitButton", true, false) as Button
			_check(dev_btn != null and dev_btn.text.contains("Development"), "the development-only exit button survives the boundary")
			dev_btn.pressed.emit()
			_check(_shell_exits.size() == 1 and String(_shell_exits[0]) == "res://scenes/main/Main.tscn", "the development exit after the boundary returns to the main menu exactly once")
			_fixture_completions_untouched()
			change_scene_to_file(MAIN_SCENE)
			_stage = 12
			_wait_frames = 0
			return false
		12:
			# --- Area 9 + hygiene: real files untouched, fixtures cleaned ---
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
			Engine.remove_meta(AUTOSTART_META)
			if _failures == 0:
				print("PASS: All %d N4.2 Prologue Beats checks completed with 0 failures." % _checks)
				quit(0)
			else:
				printerr("FAIL: N4.2 Prologue Beats finished with %d failures out of %d checks." % [_failures, _checks])
				quit(1)
			return true
	return false
