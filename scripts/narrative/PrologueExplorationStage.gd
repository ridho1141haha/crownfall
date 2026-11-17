class_name PrologueExplorationStage
extends Node2D

## N4.3-A Prologue exploration stage: the small bounded ancient-road
## environment, its bounds, the exploration handoff area, and the stage-owned
## presentation state for pl_03/pl_04 (technical spike).
##
## OWNERSHIP (N4.3 planning, DECIDED): this stage owns the road layout,
## bounds, handoff area, exploration conditions, and the narrow presentation
## path for the pl_03 intro line through the existing DialoguePanel. It does
## NOT own authoritative narrative completion records — it emits exactly ONE
## `exploration_handoff_reached` request per exploration interval, and
## PrologueShell validates the active beat and records the completion in
## NarrativeState exactly once.
##
## CONTROL-LOCK CONTRACT: the stage owns a dedicated PlayerControlLock for its
## dialogue (the runner keeps the shell as its control target for pl_01/pl_02,
## which have no actor). While the intro line is open, the lock disables the
## explorer's physics processing, so held movement keys cannot move the actor;
## DialoguePanel consuming input alone would not do that. The lock is released
## on every completion, skip, cancellation, exit, and teardown path, and
## unlock() is freed-safe, so a freed actor can never crash cleanup.
##
## All environment art is labelled placeholder ColorRect geometry — no art
## assets ship in N4.3-A and nothing here implies lore (no road name, no
## kingdom/dynasty references, no royal-symbol design; the mark props belong
## to N4.3-B).

signal exploration_handoff_reached()

## Authored stage layout (labelled placeholders; zoom 1.5 on a 1280x720
## viewport shows an 853x480 world band, so the 1600-wide road actually pans).
const ROAD_MIN_X: float = -800.0
const ROAD_MAX_X: float = 800.0
const VIEW_TOP: float = -240.0
const VIEW_BOTTOM: float = 240.0
const GROUND_Y: float = 200.0
## The exploration handoff area: the east end of the road. Reaching it is the
## sole normal pl_03 completion trigger (no timer, no quest marker).
const HANDOFF_X: float = 680.0
const EXPLORER_START_X: float = -700.0

const BACKDROP_COLOR: Color = Color(0.09, 0.085, 0.11, 1.0)
const ROAD_COLOR: Color = Color(0.32, 0.27, 0.22, 1.0)
const ROAD_EDGE_COLOR: Color = Color(0.22, 0.19, 0.16, 1.0)
const REMNANT_COLOR: Color = Color(0.42, 0.41, 0.44, 1.0)
const HANDOFF_MARKER_COLOR: Color = Color(0.85, 0.78, 0.45, 0.22)
const ROAD_THICKNESS: float = 44.0
const REMNANT_COUNT: int = 4
## How far the backdrop and road art extend past the camera-limit band on
## every side, so no viewport configuration can ever expose empty space
## beyond the authored band (see _build_environment coverage contract).
const BACKDROP_MARGIN: float = 4096.0

var _panel: DialoguePanel = null
var _explorer: PrologueExplorer = null
var _dialogue_lock: PlayerControlLock = null
var _active_beat: String = ""
var _built: bool = false
var _torn_down: bool = false
var _segment_ended: bool = false
## One completion request per exploration interval: the guard that keeps the
## stage from emitting duplicate handoff requests.
var _handoff_emitted: bool = false
## Generation guard for the intro-dialogue coroutine: skip/cancel/teardown
## invalidate the presentation so a resumed await can never re-enable input
## for a beat that already moved on.
var _dialogue_generation: int = 0


## Builds the environment and the dedicated explorer. Fail-closed and atomic:
## validation happens BEFORE anything is built, so a failed setup constructs
## no actor, acquires no lock, and leaves no stale state. Returns false when
## the panel is missing, the texture is invalid, or the stage was built once.
func setup(panel: DialoguePanel, explorer_texture: Texture2D) -> bool:
	if _built or _torn_down:
		return false
	if panel == null or explorer_texture == null:
		return false
	if not explorer_texture.get_width() > 0:
		return false
	_panel = panel
	_dialogue_lock = PlayerControlLock.new()
	_build_environment()
	# Movement bounds and camera limits are authored as SEPARATE seams (both
	# currently the road band): the camera limits define what may be visible,
	# the movement bounds where the actor can walk. The regression suite
	# measures the actual visible viewport rect at the extremes.
	_explorer = PrologueExplorer.new(
		explorer_texture,
		ROAD_MIN_X,
		ROAD_MAX_X,
		GROUND_Y,
		ROAD_MIN_X,
		ROAD_MAX_X,
		VIEW_TOP,
		VIEW_BOTTOM
	)
	_explorer.position = Vector2(EXPLORER_START_X, GROUND_Y)
	add_child(_explorer)
	_built = true
	return true


func is_built() -> bool:
	return _built


## Starts pl_03: the beat becomes active, the explorer is presented at the
## authored start point, and the approved internal line plays through the
## DialoguePanel while the stage-owned lock holds the actor. Movement is
## enabled only after the line closes (the intended point).
func begin_beat(beat_id: String) -> void:
	if not _built or _torn_down or _segment_ended:
		return
	if beat_id != PrologueBeats.PL_03_WANDERER:
		return
	_active_beat = beat_id
	_present_intro_dialogue(beat_id)


## pl_04 activation (shell-validated). N4.3-A presents no pl_04 dialogue:
## its recognition interaction is N4.3-B. Movement stays enabled — pl_04 is
## an interactive beat on the same stage.
func set_active_beat(beat_id: String) -> void:
	if not _built or _torn_down or _segment_ended:
		return
	if beat_id != PrologueBeats.PL_03_WANDERER and beat_id != PrologueBeats.PL_04_REPEATED_MARK:
		return
	_active_beat = beat_id
	if beat_id == PrologueBeats.PL_04_REPEATED_MARK:
		_explorer.set_input_enabled(true)


## Ends the pl_03 intro presentation WITHOUT completing anything: used by the
## shell's skip path (skip is not cancellation — the shell records the beat)
## and by teardown. Invalidates the dialogue coroutine, closes the panel, and
## releases the stage-owned actor lock. Idempotent and freed-safe.
func close_active_dialogue() -> void:
	_dialogue_generation += 1
	if _panel != null and is_instance_valid(_panel) and _panel.is_open():
		_panel.close()
	if _dialogue_lock != null:
		_dialogue_lock.unlock()


## Ends the N4.3 segment at its defined boundary (pl_04 skip): closes any
## active dialogue, releases the stage-owned actor lock, disables exploration
## input, and freezes the actor. No beat is recorded here — the shell records
## completions. Idempotent.
func end_segment() -> void:
	if _segment_ended:
		return
	_segment_ended = true
	close_active_dialogue()
	if _explorer != null and is_instance_valid(_explorer):
		_explorer.set_input_enabled(false)
		_explorer.freeze()


## Cancellation/exit/scene-unload cleanup — explicitly NOT a skip: nothing is
## recorded, no completion request is emitted, the owned lock is released, and
## input is disabled so no stale movement state survives. Idempotent and
## safe to call while the intro dialogue is open or after the actor was freed.
func teardown() -> void:
	if _torn_down:
		return
	_torn_down = true
	# Invalidate the dialogue coroutine first so a resumed await observes the
	# torn-down state and never re-enables input for a dead segment.
	close_active_dialogue()
	if _explorer != null and is_instance_valid(_explorer):
		_explorer.set_input_enabled(false)
		_explorer.freeze()


func _exit_tree() -> void:
	# Scene-unload cleanup: release owned locks and input state. teardown() is
	# freed-safe (PlayerControlLock.unlock checks is_instance_valid).
	teardown()


func explorer() -> PrologueExplorer:
	return _explorer


func active_beat() -> String:
	return _active_beat


func is_dialogue_locked() -> bool:
	return _dialogue_lock != null and _dialogue_lock.is_locked()


func is_input_enabled() -> bool:
	return _explorer != null and is_instance_valid(_explorer) and _explorer.is_input_enabled()


func handoff_emitted() -> bool:
	return _handoff_emitted


func is_segment_ended() -> bool:
	return _segment_ended


func is_torn_down() -> bool:
	return _torn_down


## Exploration condition: the handoff area completes pl_03 when the actor
## reaches the east end of the road. The request fires exactly once and only
## while pl_03 is active with movement enabled (so a placed-but-not-yet-
## controllable actor can never complete the beat early).
func _physics_process(_delta: float) -> void:
	if _torn_down or _segment_ended or _handoff_emitted:
		return
	if _active_beat != PrologueBeats.PL_03_WANDERER:
		return
	if not is_input_enabled():
		return
	if _explorer.position.x >= HANDOFF_X:
		_handoff_emitted = true
		exploration_handoff_reached.emit()


## Presents the approved intro line through the existing DialoguePanel with
## the stage-owned actor lock. On panel close (normal completion) the lock is
## released and movement is enabled; when skip/cancel/teardown closed the
## panel, the stale-coroutine guard leaves all state handling to that path.
func _present_intro_dialogue(beat_id: String) -> void:
	var lines: Array[Dictionary] = PrologueBeats.exploration_intro_lines(beat_id)
	if lines.is_empty():
		_explorer.set_input_enabled(true)
		return
	_dialogue_generation += 1
	var gen: int = _dialogue_generation
	_dialogue_lock.lock(_explorer)
	_explorer.set_input_enabled(false)
	_panel.open_lines(lines)
	await _panel.dialogue_finished
	# Stale-coroutine guard: skip/cancel/teardown invalidate the generation.
	# A runner-side panel cleanup (e.g. cancel_sequence during an exit) can
	# also close the shared panel while the shell is tearing down, so a freed
	# or about-to-be-torn-down explorer must never be touched after resume.
	if gen != _dialogue_generation or _active_beat != beat_id or _torn_down or _segment_ended:
		return
	if not is_instance_valid(_explorer):
		return
	_dialogue_lock.unlock()
	_explorer.set_input_enabled(true)


## Labelled placeholder environment: dark backdrop, packed-earth road band,
## a few weathered remnant stones (environmental storytelling placeholders —
## no lore), and a translucent marker for the handoff area.
##
## COVERAGE CONTRACT (review fix): the backdrop and the road band extend far
## BEYOND the camera-limit band (BACKDROP_MARGIN on every side) so no viewport
## configuration can ever expose empty space past the authored band —
## Camera2D clamps the viewport edges inside the limits only while the limit
## band is larger than the view, and larger windows (the canvas_items stretch
## keeps logical size fixed, but the camera centers within smaller limit
## spans) would otherwise show past it. Everything the camera can possibly
## see is authored art, and the road reads as continuing past the walkable
## bounds (it leads east toward the handoff/ruins).
func _build_environment() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "RoadBackdrop"
	backdrop.color = BACKDROP_COLOR
	backdrop.position = Vector2(ROAD_MIN_X - BACKDROP_MARGIN, VIEW_TOP - BACKDROP_MARGIN)
	backdrop.size = Vector2((ROAD_MAX_X - ROAD_MIN_X) + BACKDROP_MARGIN * 2.0, (VIEW_BOTTOM - VIEW_TOP) + BACKDROP_MARGIN * 2.0)
	add_child(backdrop)

	var road: ColorRect = ColorRect.new()
	road.name = "RoadBand"
	road.color = ROAD_COLOR
	road.position = Vector2(ROAD_MIN_X - BACKDROP_MARGIN, GROUND_Y)
	road.size = Vector2((ROAD_MAX_X - ROAD_MIN_X) + BACKDROP_MARGIN * 2.0, ROAD_THICKNESS)
	add_child(road)

	var road_edge: ColorRect = ColorRect.new()
	road_edge.name = "RoadEdge"
	road_edge.color = ROAD_EDGE_COLOR
	road_edge.position = Vector2(ROAD_MIN_X - BACKDROP_MARGIN, GROUND_Y + ROAD_THICKNESS)
	road_edge.size = Vector2((ROAD_MAX_X - ROAD_MIN_X) + BACKDROP_MARGIN * 2.0, 6.0)
	add_child(road_edge)

	for i: int in range(REMNANT_COUNT):
		var remnant: ColorRect = ColorRect.new()
		remnant.name = "Remnant%d" % (i + 1)
		remnant.color = REMNANT_COLOR
		remnant.position = Vector2(ROAD_MIN_X + 150.0 + float(i) * 340.0, GROUND_Y - 18.0 - float(i % 2) * 8.0)
		remnant.size = Vector2(22.0 + float(i % 3) * 8.0, 18.0 + float(i % 2) * 8.0)
		add_child(remnant)

	var handoff_marker: ColorRect = ColorRect.new()
	handoff_marker.name = "HandoffAreaMarker"
	handoff_marker.color = HANDOFF_MARKER_COLOR
	handoff_marker.position = Vector2(HANDOFF_X, GROUND_Y - 96.0)
	handoff_marker.size = Vector2(ROAD_MAX_X - HANDOFF_X, 96.0 + ROAD_THICKNESS)
	add_child(handoff_marker)
