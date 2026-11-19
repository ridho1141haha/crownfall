extends Control

## N4.1: functional Prologue scene shell + lifecycle integration.
## N4.2: authored beat content (scripts/narrative/PrologueBeats.gd) plays
## through this shell — the shell stays LIFECYCLE-ONLY (auto-start, chaining,
## placeholder staging); it authors no story text itself.
##
## This is the real route target of the N4.0 entry gate
## (scripts/core/Main.gd PROLOGUE_ROUTE_SCENE): Main routes New Game here with
## crownfall_load_on_start = false, and the routing decision itself is
## unchanged. What N4.1 adds is the shell around the existing N1–N3 narrative
## runtime so N4.2–N4.5 can author the nine Prologue beats into it later:
##   - a per-run NarrativeState (in-memory, cleared with the scene — the
##     Prologue is linear and NON-RESUMABLE, decision D4 of the technical
##     design: exiting mid-Prologue discards per-run progress),
##   - a DialoguePanel (text-only presentation, N3 foundation, unmodified),
##   - a SequenceRunner configured with an ALLOWLISTED scene transition
##     (only res://scenes/world/ForgottenShore.tscn — the future N4.5 handoff —
##     plus the injected-exit contract below) and fail-closed sequence
##     validation via NarrativeData,
##   - a controlled exit/handoff path with a single-transition guard, so
##     duplicate exit or duplicate sequence change_scene requests are safely
##     ignored (at most one transition per shell instance).
##
## N4.2 INTEGRATION: on scene-ready the shell AUTO-STARTS the first
## uncompleted authored beat (PrologueBeats.BEAT_IDS) — the production
## default, matching the pl_01 entry condition "New Game start". Headless
## suites that exercise lifecycle semantics on an idle shell disable it with
## the Engine meta "crownfall_prologue_autostart" = false (same injection
## convention as crownfall_load_on_start). When an authored beat completes
## exactly once, the chain advances to the next authored beat and marks the
## N4.2 boundary ONLY when no next authored beat exists (pl_03+ are future
## milestones); when a next beat exists but cannot start (exit started, busy
## runner, already-completed beat, invalid data, play() rejection), the
## boundary stays FALSE and the refusal is reported explicitly. NO scene
## transition happens here (the shore handoff is N4.5), NO completion marker
## is set, and the development exit remains the only way out.
##
## N4.3-A INTEGRATION: the structural chain end after pl_02 is now the
## exploration handoff — the shell enters the Prologue-specific exploration
## segment (PrologueExplorationStage + PrologueExplorer on the ancient road)
## instead of idling at the N4.2 terminal boundary. The shell is the sole
## owner of authoritative NarrativeState.mark_completed() calls for the
## exploration beats pl_03/pl_04: the stage emits one validated completion
## request per interval (pl_03 = the actor reached the handoff area), the
## shell validates the ACTIVE beat, records it exactly once, and immediately
## activates the next beat. `skip_current_exploration_beat()` is the narrow
## per-beat Skip path (pl_03 skip starts pl_04 normally; pl_04 skip ends the
## N4.3 segment at a defined idle boundary). Cancellation, the development
## exit, scene unload, and failed setup are NOT skip: they record nothing,
## release the stage-owned actor lock, disable exploration input, and leave
## the Prologue non-resumable. The runner keeps the shell as its control
## target (pl_01/pl_02 have no actor); the exploration dialogue uses a
## dedicated stage-owned PlayerControlLock on the actor instead. Headless
## suites that must keep the N4.2 terminal-boundary behavior disable the
## segment with the Engine meta "crownfall_prologue_exploration" = false.
##
## N4.4-A INTEGRATION: the exploration chain continues past pl_04. Recording
## pl_04 now ACTIVATES pl_05 (the Forgotten Ruins); the stage's ONE
## `ruins_altar_reached` request completes pl_05 exactly once at the authored
## altar threshold and activates pl_06 DORMANT (no pl_06 content in slice A:
## the crown interaction is N4.4-C, the awakening/vision N4.4-D — the
## segment stays LIVE with pl_06 as the active beat and the development exit
## as the way out). The per-beat skip chain extends the same way (pl_04 skip
## -> pl_05, pl_05 skip -> pl_06 dormant; the O6-APPROVED default — see
## skip_current_exploration_beat). _n43_segment_ended is no longer reachable
## in the normal flow; it remains for the N4.4-D boundary machinery.
##
## COMPLETION SEMANTICS: this shell NEVER touches PlayerProfile. Entering,
## exiting, skipping, or closing the application must not mark
## prologue_completed_once; only the future N4.5 successful full-Prologue
## handoff (after pl_09) may call PlayerProfile.mark_prologue_completed().
## The button below is a DEVELOPMENT-ONLY exit so a build cannot dead-end
## before the remaining Prologue beats exist: it returns to the main menu
## and modifies no profile, no save, and no sidecar.

const MAIN_MENU_SCENE: String = "res://scenes/main/Main.tscn"
## The only world scene a Prologue sequence may transition into (N4.5 handoff).
## Menu return below is a shell exit, not a runner scene transition.
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const _ALLOWED_SEQUENCE_SCENES: Array[String] = [FORGOTTEN_SHORE_SCENE]
## Engine meta override for headless suites (repo injection convention, see
## header). Production never sets it, so the Prologue auto-plays on load.
const AUTOSTART_META: String = "crownfall_prologue_autostart"
## Engine meta override that keeps the N4.2 terminal-boundary behavior (no
## exploration segment after pl_02). Production never sets it, so exploration
## is the default. Same injection convention as AUTOSTART_META.
const EXPLORATION_META: String = "crownfall_prologue_exploration"
## Engine meta override for the explorer texture path — headless tests inject
## a nonexistent path to prove the failed-setup path leaves no stale state.
const STAGE_TEXTURE_META: String = "crownfall_prologue_stage_texture"
## The existing adult-Monarch sprite sheet (planning reuse policy): frames
## 0-3 idle / 4-7 walk, identical convention to the gameplay player scene.
const EXPLORER_TEXTURE_PATH: String = "res://assets/characters/player/player_monarch_sheet.png"
## Tree index the exploration stage is inserted at: above the backdrop layers.
## The shell UI (CenterContainer) lives on the "UICanvasLayer" CanvasLayer
## (N4.3-C fix: a plain Control on the default canvas is displaced OFF-SCREEN
## by the exploration Camera2D — the status labels and the development exit
## button disappeared during pl_03/pl_04; a CanvasLayer does not follow the
## viewport camera, matching the DialoguePanel's own camera immunity). The
## index still places the world stage after the backdrop siblings; canvas
## layers keep the UI above the world regardless of tree order.
const EXPLORATION_STAGE_UI_INDEX: int = 2

## Test/handoff observability contract (same style as Main.set_route_transition):
## the injected callable receives the exit scene path instead of a real
## SceneTree.change_scene_to_file. Production leaves it unset.
var _exit_transition: Callable = Callable()
var _initialized: bool = false
var _exit_started: bool = false
## Runtime state is OWNED by this shell instance and dies with it (per-run,
## non-resumable). No autoload, no Engine state, no persistence.
var _state: NarrativeState = null
var _panel: DialoguePanel = null
var _runner: SequenceRunner = null
var _vision_runner: SequenceRunner = null
## N4.2 chain state (per-run, dies with the scene like all shell runtime).
var _current_beat_id: String = ""
var _prologue_reached_end: bool = false
## N4.3-A exploration segment state (per-run, dies with the scene).
## N4.4-A: _n43_segment_ended is no longer reachable in the NORMAL flow —
## the chain continues into dormant pl_06 and the segment stays live (the
## slice-A terminal state). The flag/API remain for the N4.4-D boundary
## machinery (record pl_06 -> end segment -> defined boundary) and for the
## existing regression suites; see n43_segment_complete().
var _exploration_stage: PrologueExplorationStage = null
var _exploration_beat: String = ""
var _n43_segment_ended: bool = false
## Labelled placeholder stage for beat cues (no art assets ship in N4.2).
var _stage_backdrop: ColorRect = null
var _stage_caption_label: Label = null
## Optional extra cue observer (headless tests now, audio later; same style
## as the _exit_transition hook).
var _cue_observer: Callable = Callable()
## N4.4-C shell-stage crown awakening handoff state (per-run, dies with shell).
## N4.4-D installs the vision starter via set_awakening_vision_starter(); while
## unset in N4.4-C, handoffs reject cleanly so the actor never locks permanently.
var _awakening_vision_starter: Callable = Callable()
var _awakening_handoff_active: bool = false
var _awakening_handoff_generation: int = 0
var _crown_awakening_requests_received: int = 0
var _crown_awakening_acceptances: int = 0
var _crown_awakening_rejections: int = 0
var _voyage_runner: SequenceRunner = null
var _voyage_generation: int = 0
var _voyage_beat_id: String = ""
var _voyage_active: bool = false
var _n45a_boundary_reached: bool = false
var _voyage_overlay_layer: CanvasLayer = null
var _voyage_backdrop: ColorRect = null
var _voyage_caption: Label = null
var _voyage_sequence_provider: Callable = Callable()


func _ready() -> void:
	_initialize_runtime()
	if bool(Engine.get_meta(AUTOSTART_META, true)):
		start_prologue()


## Builds the narrative runtime exactly once per scene instance. A repeated
## call (or a duplicate scene-ready) is an idempotent no-op, so scene
## transitions can never initialize the runtime twice.
func _initialize_runtime() -> bool:
	if _initialized:
		return false
	_initialized = true
	_state = NarrativeState.new()
	_panel = DialoguePanel.new()
	add_child(_panel)
	_runner = SequenceRunner.new()
	# control_target is the shell itself: the Prologue has no gameplay Monarch,
	# so lock/unlock ops have a real, harmless target while beats stage their
	# cinematics (pl_01/pl_02 are "no control" beats).
	_runner.configure(
		_state,
		_panel,
		self,
		Callable(self, "_on_sequence_cue"),
		Callable(self, "_on_sequence_scene_transition"),
		_ALLOWED_SEQUENCE_SCENES.duplicate()
	)
	_runner.sequence_completed.connect(_on_runner_sequence_completed)
	_runner.sequence_failed.connect(_on_runner_sequence_failed)
	add_child(_runner)
	_vision_runner = SequenceRunner.new()
	_vision_runner.configure(
		NarrativeState.new(),
		_panel,
		self,
		Callable(self, "_on_sequence_cue"),
		Callable(self, "_on_sequence_scene_transition"),
		[]
	)
	_vision_runner.sequence_completed.connect(_on_vision_runner_completed)
	_vision_runner.sequence_failed.connect(_on_vision_runner_failed)
	add_child(_vision_runner)
	_voyage_runner = SequenceRunner.new()
	_voyage_runner.configure(NarrativeState.new(), _panel, self, Callable(self, "_on_sequence_cue"), Callable(self, "_on_voyage_scene_transition_rejected"), [])
	_voyage_runner.sequence_completed.connect(_on_voyage_runner_completed)
	_voyage_runner.sequence_failed.connect(_on_voyage_runner_failed)
	add_child(_voyage_runner)
	_build_voyage_overlay()
	_stage_backdrop = get_node_or_null("StageBackdrop") as ColorRect
	_stage_caption_label = get_node_or_null("StageBackdrop/StageCaption") as Label
	return true


func is_initialized() -> bool:
	return _initialized


## True once an exit/handoff transition has been requested for this instance.
func is_exit_started() -> bool:
	return _exit_started


func narrative_state() -> NarrativeState:
	return _state


func dialogue_panel() -> DialoguePanel:
	return _panel


func sequence_runner() -> SequenceRunner:
	return _runner


func vision_runner() -> SequenceRunner:
	return _vision_runner


func is_sequence_running() -> bool:
	return (_runner != null and _runner.is_running()) or (_vision_runner != null and _vision_runner.is_running()) or (_voyage_runner != null and _voyage_runner.is_running())


func completed_sequence_count() -> int:
	return _state.completed_count() if _state != null else 0


## Overrides the scene-transition call used by the exit/handoff paths. Used by
## headless tests to observe exit decisions; production falls back to
## SceneTree.change_scene_to_file.
func set_exit_transition(transition: Callable) -> void:
	_exit_transition = transition


## Starts a sequence through the N3 runner (fail-closed NarrativeData
## validation; exactly-once completion; allowlisted ops). Generic entry point
## for any validated sequence — authored beats normally enter through
## start_prologue()/the chain, non-beat sequences never trigger chaining.
func play_sequence(sequence: Dictionary) -> bool:
	_initialize_runtime()
	return _runner.play(sequence)


## Fast-forwards the current sequence (runtime-level skip, N3 semantics).
## Skipping an authored beat still completes it exactly once (skip_allowed),
## and the chain handler advances to the next beat on that completion.
func skip_sequence() -> void:
	if _voyage_active and _voyage_runner != null and _voyage_runner.is_running():
		_voyage_runner.skip()
		return
	if _exploration_beat == PrologueBeats.PL_06_CROWNS_CALL and _vision_runner != null and _vision_runner.is_running():
		skip_current_exploration_beat()
		return
	if _runner != null:
		_runner.skip()


## Aborts the current sequence without completion (N3 semantics; cleanup only).
## The chain does NOT advance on a cancellation, and the placeholder stage is
## hidden so the shell returns to its idle screen. An active exploration
## segment is torn down the same way: cancellation is NOT a skip, so nothing
## is recorded, and the stage-owned actor lock is released deterministically.
##
## N4.3-B ORDERING CONTRACT: the exploration segment is aborted BEFORE the
## runner cleanup. SequenceRunner._cleanup() closes the SHARED DialoguePanel
## unconditionally as part of its own bookkeeping — if that close ran first,
## a waiting exploration coroutine (the N4.3-B recognition line) would resume
## while every stage guard is still disarmed, take its NORMAL-completion path,
## emit the completion request, and record a beat the user just CANCELLED
## (planning: cancel is never a skip). teardown() bumps the dialogue
## generation and arms the torn-down flag FIRST, so the resumed await always
## observes stale state and returns without emitting. The N4.3-A intro line
## had the same exposure with no consequence (its normal path only restores
## input); the recognition path records, so the shell must arm the guard
## before any shared-panel close.
func cancel_sequence() -> void:
	_abort_exploration_segment(true)
	_abort_voyage_segment(true)
	if _runner != null:
		_runner.cancel()
	if _vision_runner != null and _vision_runner.is_running():
		_vision_runner.cancel()
	_current_beat_id = ""
	_hide_stage()


## Starts the Prologue content chain: plays the first uncompleted authored
## beat (production auto-start calls this from _ready; pl_01 entry condition
## is "New Game start"). Returns false when an exit already started, the
## runner is busy, every authored beat is already completed this run, or the
## discovered beat cannot start. This call NEVER marks the N4.2 boundary —
## boundary decisions belong to the chain completion handler, which can
## distinguish a structural chain end from a playback refusal.
func start_prologue() -> bool:
	return _play_next_beat("")


## Id of the authored beat currently staged by the chain (empty when idle).
func current_beat_id() -> String:
	return _current_beat_id


## True only when the authored chain structurally ended: the completed beat
## was the last authored runner beat (pl_02 — exploration beats pl_03/pl_04
## are shell-orchestrated and never runner sequences). Every other chain stop
## (exit started, busy runner, already-completed next beat, invalid beat data,
## play() rejection) keeps this FALSE, so a playback failure is never reported
## as a successful milestone boundary. Note: with exploration enabled this
## structural end ALSO enters the N4.3-A exploration segment.
func prologue_reached_end() -> bool:
	return _prologue_reached_end


## Injects an extra cue observer (headless tests now; audio later). Same
## observability convention as set_exit_transition; the shell's own labelled
## placeholder stage always updates regardless of this hook.
func set_cue_player(observer: Callable) -> void:
	_cue_observer = observer


## Next-beat DISCOVERY (pure, no side effects, no playback): the authored
## beat that should play after completed_id in BEAT_IDS order.
##   - completed_id "" (chain start): the first UNCOMPLETED authored beat, or
##     "" when every authored beat is already completed this run.
##   - completed_id = an authored beat (chain advance): the structurally NEXT
##     authored beat, or "" only when completed_id is the LAST authored beat.
## The "" result after a completed beat is the ONLY N4.2 boundary condition;
## every other outcome (including an unknown id) is not a boundary.
func _next_beat_id(completed_id: String) -> String:
	var beat_ids: Array[String] = PrologueBeats.BEAT_IDS
	if completed_id.is_empty():
		for beat_id: String in beat_ids:
			if not _state.is_completed(beat_id):
				return beat_id
		return ""
	for i: int in range(beat_ids.size()):
		if beat_ids[i] == completed_id:
			return beat_ids[i + 1] if i + 1 < beat_ids.size() else ""
	return ""


## Next-beat PLAYBACK (lifecycle, fail-safe): starts the beat discovered by
## _next_beat_id(). Returns true only when the next beat actually started.
## Every refusal returns false WITHOUT touching the N4.2 boundary:
##   - an exit already started (the shell is leaving; no chain advance),
##   - the runner is busy (a sequence is still running),
##   - the discovered beat is already completed this run (never replayed),
##   - its authored data is missing or fails NarrativeData validation,
##   - SequenceRunner.play() rejects the start for any other reason.
func _play_next_beat(completed_id: String) -> bool:
	if _exit_started:
		return false
	if _runner.is_running():
		return false
	var next_id: String = _next_beat_id(completed_id)
	if next_id.is_empty():
		return false
	if _state.is_completed(next_id):
		push_warning("[PrologueShell] beat '%s' is already completed this run; the chain will not replay it" % next_id)
		return false
	var sequence: Dictionary = PrologueBeats.get_beat(next_id)
	if sequence.is_empty() or not NarrativeData.validate_sequence(sequence):
		push_warning("[PrologueShell] authored beat '%s' is missing or invalid; the chain refused to start it" % next_id)
		return false
	if not _runner.play(sequence):
		push_warning("[PrologueShell] SequenceRunner.play rejected beat '%s'" % next_id)
		return false
	_current_beat_id = next_id
	return true


## Chain lifecycle handler: advances exactly once per authored-beat
## completion. The runner is idle here by construction (sequence_completed is
## emitted after its cleanup), so starting the next beat from inside this
## handler is safe; generation guards make the finished run stale.
func _on_runner_sequence_completed(sequence_id: String) -> void:
	if not PrologueBeats.is_beat(sequence_id):
		return
	_current_beat_id = ""
	_hide_stage()
	var next_id: String = _next_beat_id(sequence_id)
	if next_id.is_empty():
		# N4.2 boundary: the completed beat was the last authored beat. This
		# is the ONLY boundary trigger. With exploration enabled (production
		# default), this structural chain end is ALSO the N4.3-A exploration
		# handoff: the shell enters pl_03 instead of idling here.
		_prologue_reached_end = true
		if _exploration_enabled() and not _exit_started:
			_begin_exploration_segment()
		else:
			_set_boundary_status()
		return
	if not _play_next_beat(sequence_id):
		# A next authored beat EXISTS but could not start (exit started, busy
		# runner, already-completed beat, invalid data, play() rejection).
		# This is NOT the N4.2 boundary: the shell returns to a defined idle
		# state (no staged beat, stage hidden, control restored by the
		# runner's cleanup) with the development exit available and
		# start_prologue() able to retry the chain.
		push_warning("[PrologueShell] chain did not advance past '%s': next beat '%s' exists but could not start" % [sequence_id, next_id])


## Any runner failure (fail-closed validation errors reject before playback;
## mid-run failures emit here) resets the chain bookkeeping deterministically.
func _on_runner_sequence_failed(_sequence_id: String, _reason: String) -> void:
	_current_beat_id = ""
	_hide_stage()


## --- N4.3-A exploration segment (shell-owned beat routing and completion) ---

## True while an exploration beat (pl_03/pl_04) is the active segment state.
func in_exploration() -> bool:
	return _exploration_beat != ""


## The active exploration beat id ("" when not in exploration).
func active_exploration_beat() -> String:
	return _exploration_beat


## True once the exploration segment ended at its defined boundary. N4.4-A:
## never true in the NORMAL flow (the chain continues into dormant pl_06 and
## the segment stays live — the slice-A terminal state); the flag/API remain
## for the N4.4-D boundary machinery (record pl_06 -> end segment). The
## existing name is kept for the regression suites until D renames it.
func n43_segment_complete() -> bool:
	return _n43_segment_ended


## The exploration stage instance (null outside the exploration segment).
func exploration_stage() -> PrologueExplorationStage:
	return _exploration_stage


func set_awakening_vision_starter(starter: Callable) -> void:
	_awakening_vision_starter = starter


func is_awakening_handoff_active() -> bool:
	return _awakening_handoff_active


func awakening_handoff_generation() -> int:
	return _awakening_handoff_generation


func crown_awakening_requests_received() -> int:
	return _crown_awakening_requests_received


func crown_awakening_acceptances() -> int:
	return _crown_awakening_acceptances


func crown_awakening_rejections() -> int:
	return _crown_awakening_rejections


## Exploration is the production default; headless suites may restore the N4.2
## terminal-boundary behavior via the Engine meta injection convention.
func _exploration_enabled() -> bool:
	return bool(Engine.get_meta(EXPLORATION_META, true))


## Enters the exploration segment (pl_03) after the authored chain structurally
## ends. Build order is fail-closed: a texture load failure or a failed
## stage.setup() frees the stage, records NOTHING, acquires NO lock, and falls
## back to the defined N4.2-style idle boundary (dev exit available).
func _begin_exploration_segment() -> void:
	var texture_path: String = String(Engine.get_meta(STAGE_TEXTURE_META, EXPLORER_TEXTURE_PATH))
	var texture: Texture2D = load(texture_path) as Texture2D
	var stage := PrologueExplorationStage.new()
	_exploration_stage = stage
	add_child(stage)
	move_child(stage, EXPLORATION_STAGE_UI_INDEX)
	if texture == null or not stage.setup(_panel, texture):
		# Failed setup is not a skip: no beat recorded, no lock left behind,
		# defined idle state instead of a half-built exploration segment.
		push_warning("[PrologueShell] exploration stage setup failed; falling back to the idle boundary")
		_exploration_stage = null
		stage.free()
		_set_boundary_status()
		return
	stage.exploration_handoff_reached.connect(_on_exploration_handoff_reached)
	stage.mark_inspection_completed.connect(_on_mark_inspection_completed)
	stage.ruins_altar_reached.connect(_on_ruins_altar_reached)
	stage.crown_awakening_requested.connect(_on_crown_awakening_requested)
	stage.set_awakening_handoff_handler(Callable(self, "_handle_crown_awakening_handoff"))
	stage.crown_awakening_completed.connect(_on_crown_awakening_completed)
	_exploration_beat = PrologueBeats.PL_03_WANDERER
	_set_exploration_status(PrologueBeats.PL_03_WANDERER)
	stage.begin_beat(PrologueBeats.PL_03_WANDERER)


## The stage's ONE pl_03 completion request (actor reached the handoff area).
## The shell validates the request against the ACTIVE beat and records the
## completion exactly once; duplicate or inactive-beat requests are ignored.
func _on_exploration_handoff_reached() -> void:
	if _exit_started or _exploration_stage == null:
		return
	if _exploration_beat != PrologueBeats.PL_03_WANDERER:
		# A request for an inactive beat is never accepted (late duplicate,
		# torn-down stage, or a beat that already moved on).
		return
	if not _record_exploration_beat(PrologueBeats.PL_03_WANDERER):
		return
	_activate_exploration_beat(PrologueBeats.PL_04_REPEATED_MARK)


## The shell is the SOLE writer of exploration completions in NarrativeState
## (the stage never records; the runner never sees exploration beats).
## mark_completed is idempotent, so a duplicate request is a rejected no-op.
func _record_exploration_beat(beat_id: String) -> bool:
	if _state == null:
		return false
	var recorded: bool = _state.mark_completed(beat_id)
	if not recorded:
		push_warning("[PrologueShell] duplicate exploration completion request for '%s' ignored" % beat_id)
	return recorded


## Activates the next exploration beat on the validated stage.
func _activate_exploration_beat(beat_id: String) -> void:
	_exploration_beat = beat_id
	if _exploration_stage != null:
		_exploration_stage.set_active_beat(beat_id)
	_set_exploration_status(beat_id)


## The stage's ONE pl_04 completion request (N4.3-B: two distinct marks
## inspected, the recognition line completed normally). The shell validates
## the request against the ACTIVE beat and records the completion exactly
## once; duplicate, inactive-beat, or post-exit requests are ignored — and a
## duplicate record is already a rejected no-op in _record_exploration_beat.
## N4.4-A: recording pl_04 now ACTIVATES pl_05 (the runtime beat table's
## pl_05 entry condition is "pl_04 finished") — the exploration segment no
## longer ends here; the defined boundary moved to the post-pl_06 N4.4
## boundary (N4.4-D).
func _on_mark_inspection_completed() -> void:
	if _exit_started or _exploration_stage == null:
		return
	if _exploration_beat != PrologueBeats.PL_04_REPEATED_MARK:
		# A request for an inactive beat is never accepted (late duplicate,
		# torn-down stage, or a beat that already moved on).
		return
	if not _record_exploration_beat(PrologueBeats.PL_04_REPEATED_MARK):
		return
	_activate_exploration_beat(PrologueBeats.PL_05_FORGOTTEN_RUINS)


## The stage's ONE pl_05 completion request (N4.4-A: the actor reached the
## authored altar threshold — the runtime beat table's pl_05 exit condition
## "Reach altar"). The shell validates the request against the ACTIVE beat
## and records the completion exactly once; duplicate, inactive-beat, or
## post-exit requests are ignored. Recording pl_05 activates pl_06 DORMANT:
## the beat id becomes the active chain state, but N4.4-A stages no pl_06
## content (the crown interaction is N4.4-C, the awakening/vision N4.4-D) —
## the segment stays LIVE and the development exit remains the way out.
func _on_ruins_altar_reached() -> void:
	if _exit_started or _exploration_stage == null:
		return
	if _exploration_beat != PrologueBeats.PL_05_FORGOTTEN_RUINS:
		# A request for an inactive beat is never accepted (late duplicate,
		# torn-down stage, or a beat that already moved on).
		return
	if not _record_exploration_beat(PrologueBeats.PL_05_FORGOTTEN_RUINS):
		return
	_activate_exploration_beat(PrologueBeats.PL_06_CROWNS_CALL)


func _on_crown_awakening_requested(generation: int) -> void:
	_crown_awakening_requests_received += 1
	if _exit_started or _n43_segment_ended or _exploration_stage == null or not is_instance_valid(_exploration_stage):
		return
	if _exploration_beat != PrologueBeats.PL_06_CROWNS_CALL:
		_exploration_stage.reject_crown_awakening(generation, false)
		return
	if not _exploration_stage.is_awakening_generation_current(generation):
		return


func _handle_crown_awakening_handoff(generation: int) -> bool:
	if _exit_started or _n43_segment_ended or _exploration_stage == null or not is_instance_valid(_exploration_stage):
		_crown_awakening_rejections += 1
		return false
	if _exploration_beat != PrologueBeats.PL_06_CROWNS_CALL:
		_crown_awakening_rejections += 1
		return false
	if _awakening_handoff_active:
		_crown_awakening_rejections += 1
		return false
	if _state != null and _state.is_completed(PrologueBeats.PL_06_CROWNS_CALL):
		_crown_awakening_rejections += 1
		return false
	if not _exploration_stage.is_awakening_generation_current(generation):
		_crown_awakening_rejections += 1
		return false
	if _awakening_vision_starter.is_valid():
		if not bool(_awakening_vision_starter.call(generation)):
			_crown_awakening_rejections += 1
			return false
		_awakening_handoff_active = true
		_awakening_handoff_generation = generation
		_crown_awakening_acceptances += 1
		return true
	if not _start_pl06_vision_sequence(generation):
		_crown_awakening_rejections += 1
		return false
	_crown_awakening_acceptances += 1
	return true


func _start_pl06_vision_sequence(generation: int) -> bool:
	if _vision_runner == null or _vision_runner.is_running():
		return false
	var seq: Dictionary = PrologueBeats.vision_sequence()
	if seq.is_empty() or not NarrativeData.validate_sequence(seq):
		return false
	_awakening_handoff_active = true
	_awakening_handoff_generation = generation
	if not _vision_runner.play(seq):
		_awakening_handoff_active = false
		_awakening_handoff_generation = 0
		return false
	return true


func _on_vision_runner_completed(sequence_id: String) -> void:
	if sequence_id != PrologueBeats.PL_06_VISION_SEQUENCE_ID:
		return
	if _exit_started or _n43_segment_ended or not _awakening_handoff_active:
		return
	if _exploration_stage == null or not is_instance_valid(_exploration_stage):
		return
	if _exploration_beat != PrologueBeats.PL_06_CROWNS_CALL:
		return
	if not _exploration_stage.is_awakening_generation_current(_awakening_handoff_generation):
		return
	_exploration_stage.present_post_vision_dialogue(_awakening_handoff_generation)


func _on_vision_runner_failed(_sequence_id: String, _reason: String) -> void:
	var failed_gen: int = _awakening_handoff_generation
	_awakening_handoff_active = false
	_awakening_handoff_generation = 0
	if _exploration_stage != null and is_instance_valid(_exploration_stage):
		_exploration_stage.reject_crown_awakening(failed_gen, true)


func _on_crown_awakening_completed() -> void:
	if _exit_started or _n43_segment_ended or _exploration_stage == null:
		return
	if _exploration_beat != PrologueBeats.PL_06_CROWNS_CALL:
		return
	if not _record_exploration_beat(PrologueBeats.PL_06_CROWNS_CALL):
		return
	_finish_n44_boundary()


func _finish_n44_boundary() -> void:
	_awakening_handoff_active = false
	_awakening_handoff_generation = 0
	_n43_segment_ended = true
	_exploration_beat = ""
	if _exploration_stage != null and is_instance_valid(_exploration_stage):
		_exploration_stage.end_segment()
	if _vision_runner != null and _vision_runner.is_running():
		_vision_runner.cancel()
	_set_n44_boundary_status()


func _set_n44_boundary_status() -> void:
	var status: Label = get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
	if status != null:
		status.text = "N4.4 Prologue exploration complete (pl_01-pl_06). Later beats (pl_07+) are not implemented yet."
	var detail: Label = get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/DetailLabel") as Label
	if detail != null:
		detail.text = "No scene transition happens here and nothing records Prologue completion. Use the development exit to return to the menu."


## Narrow Prologue-specific per-beat Skip path (N4.3 planning, DECIDED): not a
## global shortcut, not SequenceRunner.skip (exploration beats are not runner
## runs), and never a full-Prologue skip. The skip chain follows the
## per-beat precedent (skipping a beat records it once and activates the
## NEXT beat, which is NOT skipped):
##   - skipping pl_03 records it once and starts pl_04 normally;
##   - skipping pl_04 records it once and activates pl_05 — the O6-APPROVED
##     default (owner ruling 2026-11-18, Option A, recorded in
##     N44_OWNER_DECISIONS.md: "skip chain continues"; the N4.3 epoch
##     sentence "pl_04 skip ends the segment" was explicitly epoch-scoped to
##     a time when pl_05 did not exist and is superseded by that ruling);
##   - skipping pl_05 records it once and activates pl_06 dormant.
## pl_06 is deliberately NOT skippable in N4.4-A: its skip semantics (the
## vision-moment granularity, decision O4) belong to N4.4-D.
## Returns false when no eligible exploration beat is active, the segment
## already ended, an exit started, or the beat was already completed
## (duplicate skip).
func skip_current_exploration_beat() -> bool:
	if _exit_started or _n43_segment_ended:
		return false
	var beat: String = _exploration_beat
	if beat != PrologueBeats.PL_03_WANDERER and beat != PrologueBeats.PL_04_REPEATED_MARK \
			and beat != PrologueBeats.PL_05_FORGOTTEN_RUINS and beat != PrologueBeats.PL_06_CROWNS_CALL:
		return false
	if not _record_exploration_beat(beat):
		return false
	if beat == PrologueBeats.PL_06_CROWNS_CALL:
		# O4 Option A (APPROVED): invalidate stage generation BEFORE closing panel so
		# skip never passes through the normal crown_awakening_completed emission edge.
		_finish_n44_boundary()
		return true
	if _exploration_stage != null:
		_exploration_stage.close_active_dialogue()
	if beat == PrologueBeats.PL_03_WANDERER:
		_activate_exploration_beat(PrologueBeats.PL_04_REPEATED_MARK)
		return true
	if beat == PrologueBeats.PL_04_REPEATED_MARK:
		# O6-APPROVED default (owner ruling 2026-11-18, Option A): the skip
		# chain continues into the ruins.
		_activate_exploration_beat(PrologueBeats.PL_05_FORGOTTEN_RUINS)
		return true
	_activate_exploration_beat(PrologueBeats.PL_06_CROWNS_CALL)
	return true


## Cancellation/exit cleanup for the exploration segment — explicitly NOT a
## skip: nothing is recorded, the stage-owned lock is released, exploration
## input is disabled, and the segment state returns to "" so a later
## handoff/skip request can never complete a torn-down beat. Idempotent;
## safe even when the actor or stage was already freed (stage.teardown() is
## freed-safe). update_status refreshes the idle status text on cancellation.
func _abort_exploration_segment(update_status: bool) -> void:
	_awakening_handoff_active = false
	_awakening_handoff_generation = 0
	if _exploration_stage == null:
		return
	_exploration_stage.teardown()
	_exploration_stage = null
	_exploration_beat = ""
	if update_status and not _exit_started:
		_set_cancelled_exploration_status()


## Exploration status text (beat-aware, labelled placeholder presentation).
## N4.4-A: pl_05/pl_06 present the ruins and the dormant chamber honestly —
## no ruins name (Story Design §10: OPEN, may remain unnamed), no lore, and
## the dormant pl_06 text says exactly what is and is not implemented.
func _set_exploration_status(beat_id: String) -> void:
	var status: Label = get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
	if status != null:
		if beat_id == PrologueBeats.PL_05_FORGOTTEN_RUINS:
			status.text = "[Placeholder art] N4.4 exploration — %s: a forgotten ruin of weathered stone." % PrologueBeats.exploration_beat_title(beat_id)
		elif beat_id == PrologueBeats.PL_06_CROWNS_CALL:
			status.text = "[Placeholder art] N4.4 exploration — %s: the hidden chamber." % PrologueBeats.exploration_beat_title(beat_id)
		else:
			status.text = "[Placeholder art] N4.3 exploration — %s: a quiet, weathered ancient road." % PrologueBeats.exploration_beat_title(beat_id)
	var detail: Label = get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/DetailLabel") as Label
	if detail != null:
		if beat_id == PrologueBeats.PL_03_WANDERER:
			detail.text = "Walk the road (A/D or arrow keys) and reach the far end to continue. Nothing records Prologue completion."
		elif beat_id == PrologueBeats.PL_04_REPEATED_MARK:
			# N4.3-B: pl_04 IS interactive now — inspection polls the existing
			# interact action behind the stage's prompt/range gates, and two
			# distinct marks trigger the recognition. The per-beat skip stays
			# a scripted/API path only (no button or input binding here), so
			# the UI names only what the player actually has.
			detail.text = "Inspect the marked objects (press E when the prompt appears): two distinct marks reveal the recognition. The development exit remains available."
		elif beat_id == PrologueBeats.PL_05_FORGOTTEN_RUINS:
			detail.text = "Follow the ruin path east into the hidden chamber and reach the altar. Environmental clues only — nothing records Prologue completion."
		else:
			# Dormant pl_06 (N4.4-A boundary state): honest about the slice.
			# Kept short enough for the unwrapped placeholder label layout.
			detail.text = "pl_05 is recorded. The awakening is not implemented yet (N4.4-C/D)."


## Defined N4.3 boundary presentation (pl_04 skip): mirrors the N4.2 boundary.
func _set_n43_boundary_status() -> void:
	var status: Label = get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
	if status != null:
		status.text = "N4.3 Prologue exploration complete (pl_03 + pl_04). Later beats (N4.4+) are not implemented yet."
	var detail: Label = get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/DetailLabel") as Label
	if detail != null:
		detail.text = "No scene transition happens here (the shore handoff is N4.5) and nothing records Prologue completion. Use the development exit to return to the menu."


## Defined idle presentation after a cancelled exploration segment.
func _set_cancelled_exploration_status() -> void:
	var status: Label = get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
	if status != null:
		status.text = "Prologue exploration cancelled — nothing was recorded."
	var detail: Label = get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/DetailLabel") as Label
	if detail != null:
		detail.text = "The Prologue is non-resumable: the next New Game restarts it from the beginning. Use the development exit to return to the menu."


## SequenceRunner cue callable (configured at init): updates the labelled
## placeholder stage and forwards to the injected observer if any. Cues are
## the beat staging channel — no new runner ops were added for N4.2.
func _on_sequence_cue(cue_id: String) -> void:
	if _cue_observer.is_valid():
		_cue_observer.call(cue_id)
	if _voyage_active and (cue_id.begins_with("stage_pl07_") or cue_id.begins_with("stage_pl08_")):
		_show_voyage_cue(cue_id)
		return
	if _awakening_handoff_active and _exploration_stage != null and is_instance_valid(_exploration_stage):
		var ruins := _exploration_stage.ruins()
		if ruins != null and is_instance_valid(ruins):
			ruins.show_vision_cue(cue_id)
		return
	if _stage_backdrop != null and _stage_caption_label != null:
		_stage_caption_label.text = PrologueBeats.stage_caption(cue_id)
		_stage_backdrop.visible = true
		_stage_caption_label.visible = true


## Hides the placeholder stage (completion, cancellation, failure, boundary).
func _hide_stage() -> void:
	if _stage_backdrop != null:
		_stage_backdrop.visible = false
	if _stage_caption_label != null:
		_stage_caption_label.visible = false


## Boundary presentation: replaces the placeholder status text so the idle
## shell screen states exactly where the Prologue milestone ends. N4.4-A:
## the text stops claiming "later beats are not implemented" (pl_05 IS
## implemented now); the fallback state itself is unchanged — it covers both
## the exploration-disabled mode and a failed exploration setup, recording
## nothing either way.
func _set_boundary_status() -> void:
	var status: Label = get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
	if status != null:
		status.text = "N4.2 Prologue opening complete (pl_01 + pl_02). No exploration segment is active (disabled or setup failed) — nothing was recorded."
	var detail: Label = get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/DetailLabel") as Label
	if detail != null:
		detail.text = "No scene transition happens here (the shore handoff is N4.5) and nothing records Prologue completion. Use the development exit to return to the menu."


## DEVELOPMENT-ONLY exit (button in PrologueShell.tscn): returns to the main
## menu so the build cannot dead-end before real Prologue content exists.
## It must never be promoted into a story exit: it does NOT mark the Prologue
## completed, does NOT touch the player profile or any world save, and the
## per-run NarrativeState is discarded with the scene (non-resumable, D4).
func _on_dev_exit_button_pressed() -> void:
	request_main_menu_return()


## Controlled exit/handoff path. Returns false when an exit already started —
## duplicate exit/handoff requests are safely ignored and a second transition
## can never fire (single-transition guard, same convention as the menu
## _route_started guard).
func request_main_menu_return() -> bool:
	# Development exit: a running sequence is cancelled with deterministic
	# cleanup and completes nothing (N3 cancel semantics).
	return _begin_exit(MAIN_MENU_SCENE, true)


## SequenceRunner scene_transition callable (allowlisted by configure()). This
## is the future N4.5 completion handoff channel into a fresh Forgotten Shore
## session; the shell adds no completion marking here.
func _on_sequence_scene_transition(scene_path: String) -> void:
	# Sequence-driven handoff: the runner is INSIDE its change_scene op right
	# now, so the sequence must NOT be cancelled — cancelling here would make
	# _execute() bail out before _finalize_completion(), losing the
	# exactly-once sequence_completed signal and the NarrativeState record.
	# The runner finishes its own step, restores control, and closes the panel
	# via its normal cleanup; this path only arms the transition guard and
	# performs the scene change.
	_begin_exit(scene_path, false)


## Single-transition exit/handoff core. cancel_running_sequence is true only
## for the development exit (stop + clean up any running sequence, completing
## nothing); false for sequence-driven handoffs, which leave the finishing
## sequence untouched.
func _begin_exit(scene_path: String, cancel_running_sequence: bool) -> bool:
	if _exit_started:
		return false
	_exit_started = true
	if cancel_running_sequence:
		# Deterministic cleanup of any running sequence (restores control,
		# closes the panel, completes nothing). cancel() is a safe no-op when
		# idle; a finishing handoff sequence is never routed through here.
		cancel_sequence()
	# An active exploration segment is torn down on EVERY exit path (this is
	# not a skip: nothing is recorded). Idempotent — the dev exit already
	# aborted the segment through cancel_sequence above.
	_abort_exploration_segment(false)
	_abort_voyage_segment(false)
	if _exit_transition.is_valid():
		_exit_transition.call(scene_path)
		return true
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(scene_path)
	return true

# --- N4.5-A: Voyage (pl_07) & Shipwreck (pl_08) ---

func voyage_runner() -> SequenceRunner:
	return _voyage_runner


func is_voyage_active() -> bool:
	return _voyage_active


func active_voyage_beat() -> String:
	return _voyage_beat_id


func voyage_generation() -> int:
	return _voyage_generation


func n45a_boundary_reached() -> bool:
	return _n45a_boundary_reached


func is_voyage_overlay_visible() -> bool:
	return _voyage_overlay_layer != null and is_instance_valid(_voyage_overlay_layer) and _voyage_overlay_layer.visible


func voyage_caption_text() -> String:
	return _voyage_caption.text if _voyage_caption != null and is_instance_valid(_voyage_caption) else ""


func voyage_overlay_layer() -> CanvasLayer:
	return _voyage_overlay_layer


func set_voyage_sequence_provider(provider: Callable) -> void:
	_voyage_sequence_provider = provider


func _build_voyage_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "VoyageOverlayLayer"
	layer.layer = 0
	layer.follow_viewport_enabled = false
	layer.visible = false
	var root_ctrl := Control.new()
	root_ctrl.name = "VoyageRoot"
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.name = "VoyageBackdrop"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = Color(0.03, 0.06, 0.11, 0.96)
	var lbl := Label.new()
	lbl.name = "VoyageCaption"
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_top = -120.0
	lbl.offset_bottom = -64.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(lbl)
	root_ctrl.add_child(bg)
	layer.add_child(root_ctrl)
	add_child(layer)
	_voyage_overlay_layer = layer
	_voyage_backdrop = bg
	_voyage_caption = lbl


func _show_voyage_cue(cue_id: String) -> void:
	if _voyage_overlay_layer == null or not is_instance_valid(_voyage_overlay_layer):
		return
	_voyage_overlay_layer.visible = true
	if _voyage_backdrop != null and is_instance_valid(_voyage_backdrop):
		match cue_id:
			PrologueBeats.CUE_PL07_DEPARTURE:
				_voyage_backdrop.color = Color(0.05, 0.07, 0.11, 0.96)
			PrologueBeats.CUE_PL07_OPEN_SEA:
				_voyage_backdrop.color = Color(0.04, 0.09, 0.16, 0.96)
			PrologueBeats.CUE_PL08_STORM_GATHERS:
				_voyage_backdrop.color = Color(0.06, 0.06, 0.09, 0.97)
			PrologueBeats.CUE_PL08_SHIPWRECK:
				_voyage_backdrop.color = Color(0.08, 0.05, 0.07, 0.98)
			PrologueBeats.CUE_PL08_FADE_OUT:
				_voyage_backdrop.color = Color(0.01, 0.01, 0.015, 1.0)
	if _voyage_caption != null and is_instance_valid(_voyage_caption):
		_voyage_caption.text = PrologueBeats.stage_caption(cue_id)


func _hide_voyage_overlay() -> void:
	if _voyage_overlay_layer != null and is_instance_valid(_voyage_overlay_layer):
		_voyage_overlay_layer.visible = false
	if _voyage_caption != null and is_instance_valid(_voyage_caption):
		_voyage_caption.text = ""


func _resolve_voyage_sequence(beat_id: String) -> Dictionary:
	if _voyage_sequence_provider.is_valid():
		var provided: Variant = _voyage_sequence_provider.call(beat_id)
		return provided as Dictionary if provided is Dictionary else {}
	if beat_id == PrologueBeats.PL_07_UNFINISHED_JOURNEY:
		return PrologueBeats.voyage_sequence()
	if beat_id == PrologueBeats.PL_08_SHIPWRECK:
		return PrologueBeats.shipwreck_sequence()
	return {}


## Starts N4.5-A (pl_07 Unfinished Journey -> pl_08 Shipwreck -> N4.5-A boundary).
## Valid only after the N4.4 boundary is reached with pl_06 completed.
func start_voyage_sequence() -> bool:
	if _exit_started or _voyage_active or _n45a_boundary_reached:
		return false
	if not _n43_segment_ended or _state == null:
		return false
	if not _state.is_completed(PrologueBeats.PL_06_CROWNS_CALL):
		return false
	if _state.is_completed(PrologueBeats.PL_07_UNFINISHED_JOURNEY):
		return false
	return _start_voyage_beat(PrologueBeats.PL_07_UNFINISHED_JOURNEY)


func _start_voyage_beat(beat_id: String) -> bool:
	if _voyage_runner == null or _voyage_runner.is_running():
		return false
	var seq: Dictionary = _resolve_voyage_sequence(beat_id)
	if seq.is_empty() or not NarrativeData.validate_sequence(seq) or String(seq.get("id", "")) != beat_id:
		return false
	_voyage_generation += 1
	_voyage_active = true
	_voyage_beat_id = beat_id
	if not _voyage_runner.play(seq):
		_voyage_active = false
		_voyage_beat_id = ""
		_hide_voyage_overlay()
		return false
	return true


func _record_voyage_beat(beat_id: String) -> bool:
	if _state == null or _state.is_completed(beat_id):
		return false
	_state.mark_completed(beat_id)
	return true


func _on_voyage_runner_completed(sequence_id: String) -> void:
	if _exit_started or not _voyage_active or _n45a_boundary_reached:
		return
	if sequence_id != _voyage_beat_id:
		return
	if sequence_id == PrologueBeats.PL_07_UNFINISHED_JOURNEY:
		if not _record_voyage_beat(PrologueBeats.PL_07_UNFINISHED_JOURNEY):
			return
		if not _start_voyage_beat(PrologueBeats.PL_08_SHIPWRECK):
			_abort_voyage_segment(false)
		return
	if sequence_id == PrologueBeats.PL_08_SHIPWRECK:
		if not _record_voyage_beat(PrologueBeats.PL_08_SHIPWRECK):
			return
		_finish_n45a_boundary()


func _on_voyage_runner_failed(_sequence_id: String, _reason: String) -> void:
	_abort_voyage_segment(false)


func _on_voyage_scene_transition_rejected(_scene_path: String) -> void:
	# N4.5-A never transitions to Forgotten Shore (belongs to N4.5-B).
	pass


func _finish_n45a_boundary() -> void:
	_voyage_generation += 1
	_voyage_active = false
	_voyage_beat_id = ""
	_n45a_boundary_reached = true
	_hide_voyage_overlay()
	_set_n45a_boundary_status()


func _set_n45a_boundary_status() -> void:
	var status: Label = get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/StatusLabel") as Label
	if status != null:
		status.text = "N4.5-A Prologue voyage complete (pl_01-pl_08). Forgotten Shore landing (pl_09) is not implemented yet."
	var detail: Label = get_node_or_null("UICanvasLayer/CenterContainer/VBoxContainer/DetailLabel") as Label
	if detail != null:
		detail.text = "No scene transition happens here and nothing records Prologue completion. Use the development exit to return to the menu."


func _abort_voyage_segment(update_status: bool) -> void:
	var was_active: bool = _voyage_active
	_voyage_generation += 1
	_voyage_active = false
	_voyage_beat_id = ""
	_hide_voyage_overlay()
	if _voyage_runner != null and _voyage_runner.is_running():
		_voyage_runner.cancel()
	if was_active and update_status and not _exit_started:
		_set_cancelled_exploration_status()


func _exit_tree() -> void:
	_voyage_generation += 1
	_voyage_active = false
	_voyage_beat_id = ""
	_hide_voyage_overlay()
