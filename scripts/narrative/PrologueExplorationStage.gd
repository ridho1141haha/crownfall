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
## INSPECTABLES CONTRACT (N4.3-B): the stage owns a PrologueMarkInspectables
## child built fail-closed during setup — the three placeholder mark objects
## render as pl_03 scenery and their shared prompt is driven per physics frame
## during pl_04. The component owns the range query and the per-run inspection
## state (D1: silent, idempotent per id); the stage owns the interact polling
## behind the full D5 gate, the recognition dialogue (D2, stage-owned lock +
## generation guard, approved text only), and the exactly-once completion
## request emission. PrologueShell stays the sole NarrativeState writer.
##
## RUINS CONTRACT (N4.4-A): the stage owns a PrologueRuinsEnvironment child
## built fail-closed during setup — the placeholder ruin zones, the hidden
## chamber reveal, and the altar area east of the road. The stage polls the
## component's zone state per physics frame during pl_05 and emits exactly
## ONE `ruins_altar_reached` request when the actor reaches the authored
## altar threshold (mirroring the pl_03 handoff contract: one-shot guard,
## active-beat + input-enabled gating, shell validates and records). pl_06 is
## DORMANT in N4.4-A: it is a valid active beat (movement stays enabled) with
## no interaction, no dialogue, and no completion path — N4.4-C/D own those.
##
## All environment art is labelled placeholder ColorRect geometry — no art
## assets ship in N4.3-A/N4.3-B/N4.4-A and nothing here implies lore (no road
## name, no ruins name, no kingdom/dynasty references, no royal-symbol
## design; the mark glyph is a labelled placeholder whose design stays an
## OPEN owner decision).

signal exploration_handoff_reached()
## The stage's ONE pl_04 completion request (N4.3-B): emitted exactly once,
## only after the recognition dialogue closed normally and the lifecycle
## checks passed. PrologueShell validates the active beat and records.
signal mark_inspection_completed()
## The stage's ONE pl_05 completion request (N4.4-A): emitted exactly once,
## only while pl_05 is active with movement enabled and the actor has reached
## the authored altar threshold. PrologueShell validates the active beat and
## records; reaching the altar is the pl_05 completion boundary (runtime beat
## table: exit condition "Reach altar"), NOT the N4.4-C crown interaction.
signal ruins_altar_reached()

## Authored stage layout (labelled placeholders; zoom 1.5 on a 1280x720
## viewport shows an 853x480 world band, so the band actually pans).
## N4.4-A: the authored band extends EAST through the ruins — the road path
## physically continues into the ruin interior as its floor (the ruins zone
## presentation draws above it), the camera limits extend with the band, and
## the containment guarantee (limits == band) is unchanged. The value is the
## east band end from the N4.4-A staging placeholders (OPEN decision O7).
const ROAD_MIN_X: float = -800.0
const ROAD_MAX_X: float = 2200.0
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
var _inspectables: PrologueMarkInspectables = null
## N4.4-A ruins component (zones + chamber reveal + altar area; east of the
## road). Null only before setup or after a failed build (fail-closed).
var _ruins: PrologueRuinsEnvironment = null
var _dialogue_lock: PlayerControlLock = null
var _active_beat: String = ""
var _built: bool = false
var _torn_down: bool = false
var _segment_ended: bool = false
## One completion request per exploration interval: the guard that keeps the
## stage from emitting duplicate handoff requests.
var _handoff_emitted: bool = false
## One N4.3-B completion request per run: the one-shot guard behind
## mark_inspection_completed — the request can never re-emit (§8 layer 1).
var _inspection_completed: bool = false
## One N4.4-A completion request per run: the one-shot guard behind
## ruins_altar_reached — the request can never re-emit.
var _altar_request_emitted: bool = false
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
	# N4.4-A (D6): the ruins environment is built fail-closed BEFORE the
	# inspectables and the actor — a failed build fails the whole setup, so
	# no partial ruins can ever be committed and the shell falls back to its
	# idle boundary (records nothing, acquires no lock).
	_ruins = PrologueRuinsEnvironment.new()
	if not _ruins.build(ROAD_MIN_X, ROAD_MAX_X, GROUND_Y, VIEW_TOP, VIEW_BOTTOM):
		_ruins.free()
		_ruins = null
		return false
	add_child(_ruins)
	# N4.3-B (D6): the inspectable set is built fail-closed BEFORE the actor —
	# a failed build fails the whole setup, so no partial inspection system is
	# ever committed and the shell falls back to its idle boundary.
	_inspectables = PrologueMarkInspectables.new()
	if not _inspectables.build(ROAD_MIN_X, ROAD_MAX_X, GROUND_Y):
		_inspectables.free()
		_inspectables = null
		return false
	add_child(_inspectables)
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
## N4.4-A: starting pl_05 enables movement directly — Beat 05 has NO approved
## dialogue (environmental storytelling only, Story Design Beat 05; adding an
## unapproved line would invent lore), so activation is silent.
func begin_beat(beat_id: String) -> void:
	if not _built or _torn_down or _segment_ended:
		return
	if beat_id != PrologueBeats.PL_03_WANDERER and beat_id != PrologueBeats.PL_05_FORGOTTEN_RUINS:
		return
	_active_beat = beat_id
	if beat_id == PrologueBeats.PL_05_FORGOTTEN_RUINS:
		_explorer.set_input_enabled(true)
		return
	_present_intro_dialogue(beat_id)


## pl_04 activation (shell-validated). N4.3-A presents no pl_04 dialogue:
## its recognition interaction is N4.3-B. Movement stays enabled — pl_04 is
## an interactive beat on the same stage.
## N4.4-A: pl_05 activates with movement enabled (interactive exploration);
## pl_06 activates DORMANT — movement stays enabled (the player may wander
## the chamber) but the stage polls nothing for pl_06 in N4.4-A: no prompt,
## no dialogue, no completion path (N4.4-C/D own the crown interaction and
## the awakening/vision; staging them here would implement a future slice).
func set_active_beat(beat_id: String) -> void:
	if not _built or _torn_down or _segment_ended:
		return
	if beat_id != PrologueBeats.PL_03_WANDERER and beat_id != PrologueBeats.PL_04_REPEATED_MARK \
			and beat_id != PrologueBeats.PL_05_FORGOTTEN_RUINS and beat_id != PrologueBeats.PL_06_CROWNS_CALL:
		return
	_active_beat = beat_id
	if beat_id != PrologueBeats.PL_04_REPEATED_MARK and _inspectables != null and is_instance_valid(_inspectables):
		# Only pl_04 polls the shared inspection prompt; every other beat
		# hides it so a stale prompt can never leak across the beat change
		# (e.g. a skip that lands between the recognition opening and the next
		# gated poll would otherwise carry a visible "[E] Inspect" into pl_05).
		_inspectables.set_prompt_target("")
	if beat_id != PrologueBeats.PL_03_WANDERER:
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


## Ends the exploration segment at its defined boundary: closes any active
## dialogue, releases the stage-owned actor lock, disables exploration
## input, and freezes the actor. No beat is recorded here — the shell records
## completions. Idempotent.
## N4.4-A NOTE: the NORMAL flow no longer ends the segment anywhere — the
## chain continues into dormant pl_06 (the terminal state of slice A). This
## path stays for the N4.4-D boundary machinery (record pl_06 -> end segment
## -> defined boundary); until then it is reachable only by tests.
func end_segment() -> void:
	if _segment_ended:
		return
	_segment_ended = true
	close_active_dialogue()
	if _inspectables != null and is_instance_valid(_inspectables):
		_inspectables.set_prompt_target("")
	if _explorer != null and is_instance_valid(_explorer):
		_explorer.set_input_enabled(false)
		_explorer.freeze()
	if _ruins != null and is_instance_valid(_ruins):
		_ruins.teardown()


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
	if _inspectables != null and is_instance_valid(_inspectables):
		_inspectables.set_prompt_target("")
	if _explorer != null and is_instance_valid(_explorer):
		_explorer.set_input_enabled(false)
		_explorer.freeze()
	if _ruins != null and is_instance_valid(_ruins):
		_ruins.teardown()


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


func inspectables() -> PrologueMarkInspectables:
	return _inspectables


func inspection_completed() -> bool:
	return _inspection_completed


## The ruins environment component (null before setup or after a failed
## build; test observability + the shell's B-slice extension point).
func ruins() -> PrologueRuinsEnvironment:
	return _ruins


## Whether the ONE pl_05 altar completion request has been emitted (test
## observability, mirroring handoff_emitted()).
func altar_request_emitted() -> bool:
	return _altar_request_emitted


func is_segment_ended() -> bool:
	return _segment_ended


func is_torn_down() -> bool:
	return _torn_down


## Per-beat exploration conditions, dispatched on the active beat. Both
## branches are gated on the torn-down/segment-ended flags first, so a
## finished or cancelled segment can never process anything (the pl_04
## prompt/inspection logic needs its own branch — the old single-purpose
## early return on _handoff_emitted belonged to pl_03 only). N4.4-A: pl_05
## gets its own branch (zone polling + the altar trigger); pl_06 is DORMANT
## and deliberately has NO branch — no polling, no triggers in N4.4-A.
func _physics_process(_delta: float) -> void:
	if _torn_down or _segment_ended:
		return
	if _active_beat == PrologueBeats.PL_03_WANDERER:
		_process_pl_03()
	elif _active_beat == PrologueBeats.PL_04_REPEATED_MARK:
		_process_pl_04()
	elif _active_beat == PrologueBeats.PL_05_FORGOTTEN_RUINS:
		_process_pl_05()


## Exploration condition: the handoff area completes pl_03 when the actor
## reaches the east end of the road. The request fires exactly once and only
## while pl_03 is active with movement enabled (so a placed-but-not-yet-
## controllable actor can never complete the beat early).
func _process_pl_03() -> void:
	if _handoff_emitted:
		return
	if not is_input_enabled():
		return
	if _explorer.position.x >= HANDOFF_X:
		_handoff_emitted = true
		exploration_handoff_reached.emit()


## pl_05 per-frame logic (N4.4-A): the ruins component tracks the explorer's
## x for the one-way zone-state machine (exterior -> interior passage ->
## chamber reveal), and the altar threshold fires the stage's ONE pl_05
## completion request — the same one-shot discipline as the pl_03 handoff:
## exactly once, only while pl_05 is active with movement enabled (a placed-
## but-not-controllable actor can never complete the beat). The component
## itself never emits completion requests; the stage is the sole emitter and
## PrologueShell the sole recorder.
func _process_pl_05() -> void:
	if _ruins == null or not _ruins.is_valid():
		return
	if _explorer == null or not is_instance_valid(_explorer):
		return
	_ruins.update_explorer_x(_explorer.position.x)
	if _altar_request_emitted:
		return
	if not is_input_enabled():
		return
	if _explorer.position.x >= _ruins.altar_x():
		_altar_request_emitted = true
		ruins_altar_reached.emit()


## pl_04 per-frame logic (N4.3-B): prompt visibility follows the nearest
## eligible inspectable while the beat is interactive, and the inspect
## interaction is polled behind the FULL D5 gate list — active beat pl_04 and
## not torn down / segment not ended (the dispatcher above), movement input
## enabled, dialogue panel not open, stage lock not held, an eligible object
## within the authored range, and `interact` just pressed. The panel's input
## consumption is NEVER relied upon to suppress this raw polling (D5): the
## explicit panel/lock/input gates do that. A held key cannot retrigger:
## is_action_just_pressed fires only on the press edge, and every accepting
## press flips the gate list to a rejecting state before the next poll.
func _process_pl_04() -> void:
	if _inspectables == null or not _inspectables.is_valid():
		return
	if _explorer == null or not is_instance_valid(_explorer):
		return
	if not is_input_enabled() or is_dialogue_locked() or (_panel != null and is_instance_valid(_panel) and _panel.is_open()):
		_inspectables.set_prompt_target("")
		return
	_inspectables.set_prompt_target(_inspectables.nearest_eligible_id(_explorer.position.x))
	if _inspection_completed:
		return
	if not Input.is_action_just_pressed("interact"):
		return
	var id := _inspectables.nearest_eligible_id(_explorer.position.x)
	if id.is_empty():
		return
	# D1: silent inspection — the first press records the id, a repeat is an
	# idempotent no-op, and NOTHING opens until two DISTINCT ids exist (D4:
	# the third object is optional and never required).
	if not _inspectables.mark_inspected(id):
		return
	if _inspectables.distinct_inspected_count() < 2:
		return
	_begin_recognition_dialogue()


## Begins the N4.3-B recognition presentation (D2 steps 1-5): two DISTINCT
## objects have been inspected, so movement input is disabled, the stage-owned
## lock holds the actor, and the approved Beat 04 line opens through the
## existing DialoguePanel. Structurally identical to _present_intro_dialogue —
## one code shape to review, same generation-guard discipline.
func _begin_recognition_dialogue() -> void:
	var lines: Array[Dictionary] = PrologueBeats.exploration_recognition_lines()
	if lines.is_empty():
		return
	_dialogue_generation += 1
	var gen: int = _dialogue_generation
	_dialogue_lock.lock(_explorer)
	_explorer.set_input_enabled(false)
	_panel.open_lines(lines)
	await _panel.dialogue_finished
	# Stale-coroutine guard: skip/cancel/teardown invalidate the generation,
	# so a resumed await never re-enables input and never emits a completion
	# request for a beat that already moved on or was torn down.
	if gen != _dialogue_generation or _active_beat != PrologueBeats.PL_04_REPEATED_MARK or _torn_down or _segment_ended:
		return
	if not is_instance_valid(_explorer):
		return
	# D2 steps 6-7: release the lock and restore input, then emit the ONE
	# completion request. The restore is TRANSIENT: the shell handler runs
	# synchronously inside this emission and immediately ends the segment
	# (input disabled + actor frozen) — the ended/frozen boundary is the
	# acceptance state (D3), never this brief restore.
	_dialogue_lock.unlock()
	_explorer.set_input_enabled(true)
	if _inspection_completed:
		return
	_inspection_completed = true
	mark_inspection_completed.emit()


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
