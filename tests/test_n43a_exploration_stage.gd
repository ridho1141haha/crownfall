extends SceneTree

## N43A Prologue exploration stage tests (N4.3-A technical spike only).
##
## Covered contract areas (N4_3_PLANNING.md slice A):
##   1. the existing pl_01 -> pl_02 chain still plays in order,
##   2. pl_02 completion enters the pl_03 exploration segment (no runner
##      auto-chaining past the player-driven interval),
##   3. the dedicated explorer is presented and movement becomes available
##      exactly when the pl_03 intro line closes,
##   4. movement cannot escape the authored road bounds (both clamps),
##   5. camera/stage setup is valid (limits == bounds, road wider than the
##      viewport, handoff area inside bounds, actor on the authored ground),
##   5b. the camera's ACTUAL visible viewport rect (get_screen_center_position
##      +/- viewport/zoom) stays inside the authored band at the road start,
##      the west bound, and the east bound — limit values alone prove nothing
##      (review fix: Camera2D.offset is applied AFTER limit clamping, so an
##      offset view escaped the band; the camera now uses no offset and the
##      backdrop art extends 4096 px past the band on every side),
##   6. the handoff area completes pl_03 via ONE stage completion request,
##   7. pl_03 is recorded exactly once in NarrativeState (by the shell — the
##      stage and the runner never record exploration beats),
##   8. duplicate pl_03 completion requests are ignored,
##   9. pl_03 completion activates pl_04 (movement stays interactive),
##  10. pl_03 Skip records pl_03 and activates pl_04 (also while the intro
##      dialogue is open; pl_04 is NOT skipped),
##  11. pl_04 Skip records pl_04 and ends at the defined N4.3 boundary
##      (dialogue closed, actor lock released, input disabled, no pl_05),
##  12. Skip never touches PlayerProfile or world saves (no completion flag),
##  13. cancellation does not complete the active beat and releases locks,
##  14. the development exit does not complete the active beat,
##  15. teardown (cancel/exit/unload) releases the stage-owned control lock,
##  16. failed stage setup leaves no stale state, locks, or completions,
##  17. dialogue locks actor movement (the panel alone would not),
##  18. normal dialogue completion restores actor movement,
##  19. a freed actor never crashes cleanup (freed-safe lock release),
##  19b. a DIRECT scene unload while the exploration dialogue is open (no
##      cancel/dev-exit path) releases the lock, records nothing, and produces
##      no coroutine or invalid-access errors (review-fix coverage),
##  20. real user profile/save files remain byte-exact untouched.
##
## ISOLATION CONTRACT (same style as test_n40/test_n41/test_n42): fixtures
## live under user://n43a_test/ injected via the crownfall_profile_path /
## crownfall_menu_save_path Engine metas. The developer's real
## user://player_profile.json, user://save_slot_0.json and their sidecars are
## only READ once for byte-exact non-mutation proof at the end of the run.
## Exploration beats are shell-orchestrated (never runner sequences), so the
## suite never needs the exploration-disable meta; it exercises the
## production default everywhere.

const PROLOGUE_SHELL_SCRIPT: GDScript = preload("res://scripts/narrative/PrologueShell.gd")
const MAIN_SCENE: String = "res://scenes/main/Main.tscn"
const PROLOGUE_SHELL_SCENE: String = "res://scenes/narrative/PrologueShell.tscn"
const TEST_DIR: String = "user://n43a_test"
const PROFILE_MISSING: String = "user://n43a_test/profile_missing.json"
const PROFILE_FALSE: String = "user://n43a_test/profile_false.json"
const SAVE_NONE: String = "user://n43a_test/save_none.json"
const REAL_PROFILE_PATH: String = "user://player_profile.json"
const AUTOSTART_META: String = "crownfall_prologue_autostart"
const EXPLORATION_META: String = "crownfall_prologue_exploration"
const STAGE_TEXTURE_META: String = "crownfall_prologue_stage_texture"
const BEAT_01: String = "pl_01_lost_world"
const BEAT_02: String = "pl_02_faint_resonance"
const BEAT_03: String = "pl_03_wanderer"
const BEAT_04: String = "pl_04_repeated_mark"
const MAX_WAIT_FRAMES: int = 1800

var _checks: int = 0
var _failures: int = 0
var _stage: int = 0
var _wait_frames: int = 0
var _routes: Array[String] = []
var _shell_exits: Array[String] = []
var _completions: Array[String] = []
var _real_profile_snapshot: String = ""
var _real_profile_existed: bool = false
var _real_save_snapshot: String = ""
var _real_save_existed: bool = false
var _real_save_sidecars: Dictionary = {}
var _real_profile_sidecars: Dictionary = {}
## Position snapshot for the release-input drift check (stage 8/9).
var _settle_x: float = 0.0
## One-shot guard for the east-bound hold check inside stage 15.
var _east_hold_checked: bool = false
## One-shot guard for the in-motion viewport containment check (stage 7).
var _motion_view_checked: bool = false
## Shell/state captured before the direct scene-unload test (stage 34):
## the NarrativeState RefCounted outlives the freed shell, so its record
## contents remain observable after unload.
var _unloaded_shell: Control = null
var _unloaded_state: NarrativeState = null


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("TEST FAILURE: [test_n43a_exploration_stage] " + msg)
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


func _wire_shell_observers(shell: Control) -> void:
	_completions.clear()
	_shell_exits.clear()
	shell.call("set_exit_transition", func(scene_path: String) -> void: _shell_exits.append(scene_path))
	shell.call("set_cue_player", func(cue_id: String) -> void: pass)
	var runner: SequenceRunner = shell.call("sequence_runner")
	runner.sequence_completed.connect(func(sequence_id: String) -> void: _completions.append(sequence_id))


func _stage_node(shell: Control) -> PrologueExplorationStage:
	return shell.call("exploration_stage") as PrologueExplorationStage


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


func _drive_right(shell: Control) -> void:
	Input.action_press("move_right")


func _drive_left(shell: Control) -> void:
	Input.action_press("move_left")


func _stop_driving() -> void:
	Input.action_release("move_right")
	Input.action_release("move_left")


## The camera's ACTUAL visible world rect: get_screen_center_position()
## returns the limit-clamped, offset-adjusted center, and the viewport's
## logical size divided by the zoom gives the world-space view size. Tests
## assert this rect (not the raw limit values) stays inside the authored band.
func _visible_rect(explorer: PrologueExplorer) -> Rect2:
	var camera: Camera2D = explorer.camera()
	var center: Vector2 = camera.get_screen_center_position()
	var view: Vector2 = current_scene.get_viewport().get_visible_rect().size / camera.zoom
	return Rect2(center - view / 2.0, view)


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
	# Production defaults: autostart ON and exploration ON (metas stay unset).
	# Shell A (stages 2-12) exercises the full production flow end to end.
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
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 2
			_wait_frames = 0
			return false
		2:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if not bool(shell.call("is_sequence_running")):
				return false
			# --- Shell A: production flow (autostart + exploration defaults) ---
			_wire_shell_observers(shell)
			var panel: DialoguePanel = shell.call("dialogue_panel")
			_check(panel.is_open() and panel.get_body_text().contains("Long ago"), "auto-start plays pl_01 (existing flow intact)")
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
			var panel2: DialoguePanel = shell.call("dialogue_panel")
			_check(panel2.is_open() and panel2.get_body_text().contains("Years ago"), "pl_01 completion chains pl_02 exactly as in N4.2 (existing flow intact)")
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
			# --- pl_02 completion enters the exploration segment ---
			_check(bool(shell.call("in_exploration")) and String(shell.call("active_exploration_beat")) == BEAT_03, "pl_02 completion enters the pl_03 exploration segment")
			_check(bool(shell.call("prologue_reached_end")) and not bool(shell.call("is_sequence_running")), "the authored chain structurally ended and the runner is idle (no auto-chaining past exploration)")
			var stage := _stage_node(shell)
			_check(stage != null and stage.is_built() and String(stage.active_beat()) == BEAT_03, "the exploration stage is built with pl_03 active")
			var explorer := _explorer_of(shell)
			_check(explorer != null and is_instance_valid(explorer), "the dedicated explorer actor is presented")
			_check(explorer != null and explorer.position.x == PrologueExplorationStage.EXPLORER_START_X and explorer.position.y == PrologueExplorationStage.GROUND_Y, "the explorer stands at the authored road start point")
			var panel3: DialoguePanel = shell.call("dialogue_panel")
			_check(panel3.is_open() and panel3.get_speaker_text() == "Monarch" and panel3.get_body_text().contains("difficult to forget"), "the approved pl_03 internal line opens through the existing DialoguePanel")
			_check(stage.is_dialogue_locked() and not explorer.is_input_enabled() and not explorer.is_physics_processing(), "movement is disabled during the intro dialogue (lock + input gate)")
			# --- Dialogue locks actor movement (req: lock beats the actor) ---
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
			_check(explorer.position.x == PrologueExplorationStage.EXPLORER_START_X, "held movement keys do NOT move the actor while the dialogue lock is held")
			_stage = 6
			_wait_frames = 0
			return false
		6:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var stage := _stage_node(shell)
			var panel: DialoguePanel = shell.call("dialogue_panel")
			# Advance through the two-line internal line; the last advance
			# closes the panel and completes the dialogue normally.
			if panel.is_open():
				panel.advance()
				return false
			_check(stage != null and not stage.is_dialogue_locked(), "normal dialogue completion releases the stage-owned actor lock")
			var explorer := _explorer_of(shell)
			_check(explorer != null and explorer.is_input_enabled() and explorer.is_physics_processing(), "movement becomes enabled at the intended point (after the line closes)")
			_drive_right(shell)
			_stage = 7
			_wait_frames = 0
			return false
		7:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if explorer == null:
				return false
			if not _motion_view_checked:
				# One-shot containment check at the reviewer's worst-case
				# scenario: the actor stands at the road start while the
				# camera converges — the visible rect must already be inside
				# the authored band (not showing empty space past it).
				_motion_view_checked = true
				var start_rect: Rect2 = _visible_rect(explorer)
				_check(start_rect.position.x >= PrologueExplorationStage.ROAD_MIN_X and start_rect.end.x <= PrologueExplorationStage.ROAD_MAX_X, "at the road start the camera's visible horizontal edges stay inside the road band (measured %s)" % [start_rect])
				_check(start_rect.position.y >= PrologueExplorationStage.VIEW_TOP and start_rect.end.y <= PrologueExplorationStage.VIEW_BOTTOM, "at the road start the camera's visible vertical edges stay inside the authored band (measured %s)" % [start_rect])
			# Position-based wait (idle/physics ratios are not 1:1 headless).
			if explorer.position.x <= PrologueExplorationStage.EXPLORER_START_X and _wait_frames < MAX_WAIT_FRAMES - 60:
				return false
			_stop_driving()
			_check(explorer.position.x > PrologueExplorationStage.EXPLORER_START_X, "the actor actually moves with input after dialogue completes")
			_drive_right(shell)
			_stage = 8
			_wait_frames = 0
			return false
		8:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if explorer == null:
				return false
			if _wait_frames < 12:
				return false
			_stop_driving()
			var x_after_release: float = explorer.position.x
			_check(x_after_release > PrologueExplorationStage.EXPLORER_START_X, "movement is responsive while input is held")
			_stage = 9
			_wait_frames = 0
			_settle_x = x_after_release
			return false
		9:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if explorer == null:
				return false
			if _wait_frames < 10:
				return false
			_check(explorer.position.x == _settle_x, "the actor stops when input is released (no drift)")
			# --- Left bound clamp ---
			_drive_left(shell)
			_stage = 10
			_wait_frames = 0
			return false
		10:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if explorer == null:
				return false
			if explorer.position.x > PrologueExplorationStage.ROAD_MIN_X and _wait_frames < MAX_WAIT_FRAMES - 60:
				return false
			_stop_driving()
			_check(explorer.position.x == PrologueExplorationStage.ROAD_MIN_X, "movement clamps exactly at the west road bound")
			_drive_left(shell)
			_stage = 11
			_wait_frames = 0
			return false
		11:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if explorer == null:
				return false
			if _wait_frames < 15:
				return false
			_stop_driving()
			_check(explorer.position.x == PrologueExplorationStage.ROAD_MIN_X, "holding the key at the bound never escapes the authored bounds")
			_stage = 12
			_wait_frames = 0
			return false
		12:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var stage := _stage_node(shell)
			var explorer := _explorer_of(shell)
			# --- Camera / stage setup validity ---
			var camera: Camera2D = explorer.camera()
			_check(camera != null and camera.limit_left == int(PrologueExplorationStage.ROAD_MIN_X) and camera.limit_right == int(PrologueExplorationStage.ROAD_MAX_X), "camera limits match the authored road bounds (no out-of-bounds exposure)")
			_check(camera != null and camera.limit_top == int(PrologueExplorationStage.VIEW_TOP) and camera.limit_bottom == int(PrologueExplorationStage.VIEW_BOTTOM), "camera vertical limits match the authored view band")
			_check(camera != null and camera.zoom == Vector2(1.5, 1.5) and camera.position_smoothing_enabled, "the camera reuses the gameplay zoom/smoothing pattern")
			var view_width: float = float(current_scene.get_viewport().get_visible_rect().size.x) / camera.zoom.x
			_check(PrologueExplorationStage.ROAD_MAX_X - PrologueExplorationStage.ROAD_MIN_X > view_width, "the road is wider than the visible world width so the camera actually follows")
			# Measured viewport containment at the west extreme: limit VALUES
			# alone prove nothing — get_screen_center_position() returns the
			# camera's actual (limit-clamped, offset-adjusted) center, so the
			# visible rect edges must rest inside the authored band.
			var west_rect: Rect2 = _visible_rect(explorer)
			_check(west_rect.position.x >= PrologueExplorationStage.ROAD_MIN_X - 0.5 and west_rect.end.x <= PrologueExplorationStage.ROAD_MAX_X + 0.5, "at the west bound the visible horizontal edges rest inside the road band (measured %s)" % [west_rect])
			_check(west_rect.position.y >= PrologueExplorationStage.VIEW_TOP - 0.5 and west_rect.end.y <= PrologueExplorationStage.VIEW_BOTTOM + 0.5, "at the west bound the visible vertical edges rest inside the authored band (measured %s)" % [west_rect])
			_check(PrologueExplorationStage.HANDOFF_X > PrologueExplorationStage.ROAD_MIN_X and PrologueExplorationStage.HANDOFF_X < PrologueExplorationStage.ROAD_MAX_X, "the handoff area sits inside the authored bounds")
			var sprite: Sprite2D = explorer.sprite()
			_check(sprite != null and sprite.hframes == 8, "the existing Monarch sheet is used with its 8-frame layout")
			_check(explorer.position.y == PrologueExplorationStage.GROUND_Y, "the actor walks on the authored road line")
			_check(stage != null and not stage.handoff_emitted(), "no completion request fired before the handoff area")
			_drive_right(shell)
			_stage = 13
			_wait_frames = 0
			return false
		13:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if not bool(state.is_completed(BEAT_03)):
				return false
			_stop_driving()
			# --- Handoff-area completion: exactly once, shell-validated ---
			_check(bool(state.is_completed(BEAT_03)) and state.completed_count() == 3, "reaching the handoff area records pl_03 exactly once (state: pl_01+pl_02+pl_03)")
			var stage := _stage_node(shell)
			_check(stage != null and stage.handoff_emitted(), "the stage emitted exactly its one handoff-area completion request")
			_check(String(shell.call("active_exploration_beat")) == BEAT_04, "pl_03 completion activates pl_04")
			_check(_completions == [BEAT_01, BEAT_02], "exploration beats never emit SequenceRunner completions (runner stays out of exploration)")
			var explorer := _explorer_of(shell)
			_check(explorer != null and explorer.is_input_enabled(), "pl_04 stays interactive (movement still enabled)")
			var panel: DialoguePanel = shell.call("dialogue_panel")
			_check(not panel.is_open(), "pl_04 activation opens no dialogue in N4.3-A (recognition line is N4.3-B)")
			_drive_right(shell)
			_stage = 14
			_wait_frames = 0
			return false
		14:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if explorer == null:
				return false
			# Position-based wait: keep driving right until the east clamp
			# (idle/physics frame ratios are not 1:1 in headless runs).
			if explorer.position.x < PrologueExplorationStage.ROAD_MAX_X and _wait_frames < MAX_WAIT_FRAMES - 60:
				return false
			_stop_driving()
			_check(explorer.position.x == PrologueExplorationStage.ROAD_MAX_X, "the actor clamps exactly at the east road bound during pl_04 (bounds hold)")
			_drive_right(shell)
			_stage = 15
			_wait_frames = 0
			return false
		15:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var explorer := _explorer_of(shell)
			if explorer == null:
				return false
			if not _east_hold_checked:
				if _wait_frames < 15:
					return false
				_stop_driving()
				_check(explorer.position.x == PrologueExplorationStage.ROAD_MAX_X, "holding the key at the east bound never escapes the authored bounds")
				# Measured viewport containment at the east extreme.
				var east_rect: Rect2 = _visible_rect(explorer)
				_check(east_rect.position.x >= PrologueExplorationStage.ROAD_MIN_X - 0.5 and east_rect.end.x <= PrologueExplorationStage.ROAD_MAX_X + 0.5, "at the east bound the visible horizontal edges rest inside the road band (measured %s)" % [east_rect])
				_check(east_rect.position.y >= PrologueExplorationStage.VIEW_TOP - 0.5 and east_rect.end.y <= PrologueExplorationStage.VIEW_BOTTOM + 0.5, "at the east bound the visible vertical edges rest inside the authored band (measured %s)" % [east_rect])
				_east_hold_checked = true
			var state: NarrativeState = shell.call("narrative_state")
			# --- Duplicate completion requests are ignored ---
			var stage := _stage_node(shell)
			var before: int = state.completed_count()
			stage.exploration_handoff_reached.emit()
			stage.exploration_handoff_reached.emit()
			_check(state.completed_count() == before and String(shell.call("active_exploration_beat")) == BEAT_04, "duplicate pl_03 completion requests are ignored by the shell")
			_check(stage.handoff_emitted(), "the handoff request stays single-shot (no new request on repeated entry)")
			# --- pl_04 Skip ends the N4.3 segment at its defined boundary ---
			_check(shell.call("skip_current_exploration_beat"), "pl_04 Skip is accepted")
			_check(bool(state.is_completed(BEAT_04)) and state.completed_count() == 4, "pl_04 Skip records pl_04 exactly once")
			_check(String(shell.call("active_exploration_beat")) == "" and bool(shell.call("n43_segment_complete")), "the N4.3 segment ends at its defined idle boundary")
			_check(explorer == null or (not explorer.is_input_enabled() and not explorer.is_physics_processing()), "the boundary disables exploration input and freezes the actor")
			_check(stage != null and not stage.is_dialogue_locked(), "the boundary releases the stage-owned actor lock")
			_check(not shell.call("is_sequence_running") and _completions == [BEAT_01, BEAT_02], "no pl_05 content is fabricated (runner untouched, no new completions)")
			var status: Label = shell.get_node_or_null("CenterContainer/VBoxContainer/StatusLabel") as Label
			_check(status != null and status.text.contains("N4.3") and status.text.contains("N4.4+"), "the boundary status names the N4.3 segment end and the next unimplemented milestone")
			_check(not shell.call("skip_current_exploration_beat"), "a duplicate pl_04 Skip is rejected (already recorded)")
			_check(state.completed_count() == 4, "the duplicate Skip records nothing")
			var profile_fixture: String = FileAccess.get_file_as_string(PROFILE_FALSE)
			_check(profile_fixture == JSON.stringify({"schema_version": 1, "prologue_completed_once": false}, "\t"), "Skip never touches the player profile fixture (no completion flag)")
			_stage = 16
			_wait_frames = 0
			return false
		16:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_check(shell.call("request_main_menu_return"), "the development exit works from the N4.3 boundary")
			_check(_shell_exits.size() == 1 and String(_shell_exits[0]) == "res://scenes/main/Main.tscn", "the boundary exit transitions to the main menu exactly once")
			change_scene_to_file(MAIN_SCENE)
			_stage = 17
			_wait_frames = 0
			return false
		17:
			if not _on_main():
				return false
			# --- Shell B: pl_03 Skip while the intro dialogue is open ---
			Engine.set_meta(AUTOSTART_META, false)
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 18
			_wait_frames = 0
			return false
		18:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			if not _check(shell.call("start_prologue"), "shell B starts the chain explicitly (idle shell)"):
				return true
			_stage = 19
			_wait_frames = 0
			return false
		19:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if bool(shell.call("in_exploration")):
				_stop_driving()
				var panel: DialoguePanel = shell.call("dialogue_panel")
				_check(panel.is_open() and panel.get_speaker_text() == "Monarch", "shell B reaches the exploration intro dialogue (skipped pl_01, drove pl_02)")
				var stage := _stage_node(shell)
				_check(stage != null and stage.is_dialogue_locked() and not stage.is_input_enabled(), "the intro dialogue locks the actor before the Skip")
				_check(shell.call("skip_current_exploration_beat"), "pl_03 Skip is accepted while the intro dialogue is open")
				_check(bool(state.is_completed(BEAT_03)) and state.completed_count() == 3, "pl_03 Skip records pl_03 exactly once")
				_check(not panel.is_open(), "pl_03 Skip closes the active intro dialogue")
				_check(not stage.is_dialogue_locked() and stage.is_input_enabled(), "pl_03 Skip releases the actor lock and enables movement")
				_check(String(shell.call("active_exploration_beat")) == BEAT_04 and not bool(state.is_completed(BEAT_04)) and not bool(shell.call("n43_segment_complete")), "pl_03 Skip activates pl_04 WITHOUT skipping it")
				_drive_right(shell)
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
			if explorer == null:
				return false
			# Position-based wait (idle/physics ratios are not 1:1 headless).
			if explorer.position.x <= PrologueExplorationStage.EXPLORER_START_X and _wait_frames < MAX_WAIT_FRAMES - 60:
				return false
			_stop_driving()
			_check(explorer.position.x > PrologueExplorationStage.EXPLORER_START_X, "movement is available in pl_04 after the pl_03 Skip (not skipped)")
			# --- Development exit during ACTIVE exploration (no skip) ---
			_drive_right(shell)
			_check(shell.call("request_main_menu_return"), "the development exit is accepted during active exploration")
			_stop_driving()
			_check(_shell_exits.size() == 1 and String(_shell_exits[0]) == "res://scenes/main/Main.tscn", "the exploration exit transitions to the main menu exactly once")
			_check(String(shell.call("active_exploration_beat")) == "" and not bool(shell.call("in_exploration")), "the exit tears down the exploration segment")
			var state: NarrativeState = shell.call("narrative_state")
			_check(state.completed_count() == 3 and not bool(state.is_completed(BEAT_04)), "the development exit does NOT complete the active pl_04 beat")
			var stage := _stage_node(shell)
			_check(stage == null or (not stage.is_dialogue_locked() and not stage.is_input_enabled()), "the exit releases locks and disables exploration input")
			change_scene_to_file(MAIN_SCENE)
			_stage = 21
			_wait_frames = 0
			return false
		21:
			if not _on_main():
				return false
			# --- Shell C: cancellation during exploration (stays idle) ---
			Engine.set_meta(AUTOSTART_META, false)
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 22
			_wait_frames = 0
			return false
		22:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			_check(shell.call("start_prologue"), "shell C starts the chain explicitly")
			_stage = 23
			_wait_frames = 0
			return false
		23:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if bool(shell.call("in_exploration")):
				var panel: DialoguePanel = shell.call("dialogue_panel")
				_check(panel.is_open(), "shell C reaches the intro dialogue (autostart-driven flow)")
				shell.call("cancel_sequence")
				_check(not panel.is_open(), "cancellation closes the exploration dialogue")
				var stage := _stage_node(shell)
				_check(stage == null or (not stage.is_dialogue_locked() and not stage.is_input_enabled()), "cancellation releases the actor lock and disables exploration input")
				_check(String(shell.call("active_exploration_beat")) == "" and not bool(shell.call("in_exploration")), "cancellation ends the segment presentation")
				_check(state.completed_count() == 2 and not bool(state.is_completed(BEAT_03)), "cancellation does NOT complete the active pl_03 beat")
				_check(not shell.call("is_sequence_running") and _completions == [BEAT_01, BEAT_02], "cancellation emits no duplicate completion signals")
				var status: Label = shell.get_node_or_null("CenterContainer/VBoxContainer/StatusLabel") as Label
				_check(status != null and status.text.contains("cancelled"), "the cancelled state has a defined idle status text")
				_stage = 24
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		24:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			_check(shell.call("request_main_menu_return"), "the development exit works after cancellation")
			_check(_shell_exits.size() == 1 and String(_shell_exits[0]) == "res://scenes/main/Main.tscn", "the post-cancellation exit transitions exactly once")
			_check(state.completed_count() == 2, "the exit after cancellation still records nothing new")
			change_scene_to_file(MAIN_SCENE)
			_stage = 25
			_wait_frames = 0
			return false
		25:
			if not _on_main():
				return false
			# --- Shell D: failed stage setup leaves no stale state ---
			Engine.set_meta(STAGE_TEXTURE_META, "res://n43a_missing_texture.png")
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 26
			_wait_frames = 0
			return false
		26:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			_check(shell.call("start_prologue"), "shell D starts the chain explicitly (bad texture meta injected)")
			_stage = 27
			_wait_frames = 0
			return false
		27:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			var state: NarrativeState = shell.call("narrative_state")
			if not _completions.has(BEAT_02):
				_skip_runner_beat(shell)
				return false
			# --- Failed setup fallback: defined idle, no locks, no records ---
			_check(not bool(shell.call("in_exploration")) and shell.call("exploration_stage") == null, "failed stage setup enters no exploration state")
			_check(bool(state.is_completed(BEAT_02)) and state.completed_count() == 2 and not bool(state.is_completed(BEAT_03)), "failed setup records NO exploration completion (not a skip)")
			_check(bool(shell.call("prologue_reached_end")), "the structural chain end stays true after the fallback")
			var runner: SequenceRunner = shell.call("sequence_runner")
			_check(not runner.is_control_locked() and not bool(shell.call("is_sequence_running")), "failed setup leaves no control lock and an idle runner")
			var stage := _stage_node(shell)
			_check(stage == null, "the failed stage instance is fully released")
			var status: Label = shell.get_node_or_null("CenterContainer/VBoxContainer/StatusLabel") as Label
			_check(status != null and status.text.contains("Later beats (N4.3+)"), "the fallback shows the defined idle boundary status")
			Engine.remove_meta(STAGE_TEXTURE_META)
			_stage = 28
			_wait_frames = 0
			return false
		28:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_check(shell.call("request_main_menu_return"), "the development exit works after failed setup")
			_check(_shell_exits.size() == 1, "the fallback exit transitions exactly once")
			change_scene_to_file(MAIN_SCENE)
			_stage = 29
			_wait_frames = 0
			return false
		29:
			if not _on_main():
				return false
			# --- Shell E: freed-actor teardown safety ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 30
			_wait_frames = 0
			return false
		30:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			_check(shell.call("start_prologue"), "shell E starts the chain explicitly")
			_stage = 31
			_wait_frames = 0
			return false
		31:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if bool(shell.call("in_exploration")):
				var stage := _stage_node(shell)
				var explorer := _explorer_of(shell)
				_check(stage != null and explorer != null and stage.is_dialogue_locked(), "the intro dialogue holds the actor lock before the freed-actor test")
				if explorer != null and is_instance_valid(explorer):
					explorer.free()
				# Teardown with a freed actor must not crash or record anything.
				_check(shell.call("request_main_menu_return"), "the exit tears down cleanly after the actor was freed")
				_check(_shell_exits.size() == 1 and String(_shell_exits[0]) == "res://scenes/main/Main.tscn", "the freed-actor teardown still exits exactly once")
				var state: NarrativeState = shell.call("narrative_state")
				_check(state.completed_count() == 2 and not bool(state.is_completed(BEAT_03)), "the freed-actor teardown records nothing (not a skip)")
				change_scene_to_file(MAIN_SCENE)
				_stage = 32
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		32:
			if not _on_main():
				return false
			# --- Shell F: DIRECT scene unload while the exploration dialogue
			# is open — no cancel_sequence, no dev-exit path (unload coverage) ---
			change_scene_to_file(PROLOGUE_SHELL_SCENE)
			_stage = 33
			_wait_frames = 0
			return false
		33:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			_wire_shell_observers(shell)
			_check(shell.call("start_prologue"), "shell F starts the chain explicitly")
			_stage = 34
			_wait_frames = 0
			return false
		34:
			if not _on_shell():
				return false
			var shell: Control = _shell()
			if bool(shell.call("in_exploration")):
				var panel: DialoguePanel = shell.call("dialogue_panel")
				var stage := _stage_node(shell)
				_check(panel.is_open(), "shell F reaches the exploration intro dialogue with the panel open")
				_check(stage != null and stage.is_dialogue_locked(), "the actor is held by the stage-owned lock at unload time")
				_unloaded_shell = shell
				_unloaded_state = shell.call("narrative_state")
				# Unload the shell directly: the stage's _exit_tree teardown
				# must release the lock and close the presentation without
				# coroutine errors or invalid access, and without recording.
				change_scene_to_file(MAIN_SCENE)
				_stage = 35
				_wait_frames = 0
				return false
			_skip_runner_beat(shell)
			return false
		35:
			if not _on_main():
				return false
			_check(not is_instance_valid(_unloaded_shell), "the PrologueShell is freed after the direct scene unload")
			_check(_unloaded_state.completed_count() == 2 and not bool(_unloaded_state.is_completed(BEAT_03)), "the direct unload records nothing (unload is not a skip; no stale completion)")
			_unloaded_shell = null
			_unloaded_state = null
			_stage = 36
			_wait_frames = 0
			return false
		36:
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
			for suffix: String in [".tmp", ".old"]:
				_assert_sidecar_untouched(REAL_PROFILE_PATH + suffix, _real_profile_sidecars[suffix], "real profile sidecar %s" % suffix)
			for path: String in [PROFILE_MISSING, PROFILE_FALSE, SAVE_NONE]:
				_rm(path)
			_clean_fixture_sidecars()
			if DirAccess.dir_exists_absolute(TEST_DIR):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
			Engine.remove_meta(AUTOSTART_META)
			Engine.remove_meta(EXPLORATION_META)
			Engine.remove_meta(STAGE_TEXTURE_META)
			if _failures == 0:
				print("PASS: All %d N43A Exploration Stage checks completed with 0 failures." % _checks)
				quit(0)
			else:
				printerr("FAIL: N43A Exploration Stage finished with %d failures out of %d checks." % [_failures, _checks])
				quit(1)
			return true
	return false
