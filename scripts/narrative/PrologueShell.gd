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
## exactly once, the chain advances to the next authored beat and stops at
## the N4.2 boundary (pl_03+ are future milestones): NO scene transition
## happens here (the shore handoff is N4.5), NO completion marker is set,
## and the development exit remains the only way out.
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
## N4.2 chain state (per-run, dies with the scene like all shell runtime).
var _current_beat_id: String = ""
var _prologue_reached_end: bool = false
## Labelled placeholder stage for beat cues (no art assets ship in N4.2).
var _stage_backdrop: ColorRect = null
var _stage_caption_label: Label = null
## Optional extra cue observer (headless tests now, audio later; same style
## as the _exit_transition hook).
var _cue_observer: Callable = Callable()


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


func is_sequence_running() -> bool:
	return _runner != null and _runner.is_running()


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
	if _runner != null:
		_runner.skip()


## Aborts the current sequence without completion (N3 semantics; cleanup only).
## The chain does NOT advance on a cancellation, and the placeholder stage is
## hidden so the shell returns to its idle screen.
func cancel_sequence() -> void:
	if _runner != null:
		_runner.cancel()
	_current_beat_id = ""
	_hide_stage()


## Starts the Prologue content chain: plays the first uncompleted authored
## beat (production auto-start calls this from _ready; pl_01 entry condition
## is "New Game start"). Returns false when an exit already started, the
## runner is busy, or every authored beat is already completed (boundary).
func start_prologue() -> bool:
	return _play_beat_after("")


## Id of the authored beat currently staged by the chain (empty when idle).
func current_beat_id() -> String:
	return _current_beat_id


## True once the chain reached the N4.2 boundary: every authored beat is
## completed and no next beat exists (pl_03+ are future milestones).
func prologue_reached_end() -> bool:
	return _prologue_reached_end


## Injects an extra cue observer (headless tests now; audio later). Same
## observability convention as set_exit_transition; the shell's own labelled
## placeholder stage always updates regardless of this hook.
func set_cue_player(observer: Callable) -> void:
	_cue_observer = observer


## Plays the authored beat that follows completed_id ("" = start of chain).
## Fail-closed: no beat, an already-completed next beat, a busy runner, or a
## started exit all resolve to false without side effects.
func _play_beat_after(completed_id: String) -> bool:
	if _exit_started:
		return false
	var next_id: String = ""
	var beat_ids: Array[String] = PrologueBeats.BEAT_IDS
	for i: int in range(beat_ids.size()):
		if completed_id.is_empty():
			if not _state.is_completed(beat_ids[i]):
				next_id = beat_ids[i]
				break
		elif beat_ids[i] == completed_id and i + 1 < beat_ids.size():
			next_id = beat_ids[i + 1]
			break
	if next_id.is_empty() or _state.is_completed(next_id):
		return false
	var sequence: Dictionary = PrologueBeats.get_beat(next_id)
	if sequence.is_empty() or not _runner.play(sequence):
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
	if not _play_beat_after(sequence_id):
		# N4.2 boundary: no next authored beat (pl_03+ not implemented).
		_prologue_reached_end = true
		_set_boundary_status()


## Any runner failure (fail-closed validation errors reject before playback;
## mid-run failures emit here) resets the chain bookkeeping deterministically.
func _on_runner_sequence_failed(_sequence_id: String, _reason: String) -> void:
	_current_beat_id = ""
	_hide_stage()


## SequenceRunner cue callable (configured at init): updates the labelled
## placeholder stage and forwards to the injected observer if any. Cues are
## the beat staging channel — no new runner ops were added for N4.2.
func _on_sequence_cue(cue_id: String) -> void:
	if _cue_observer.is_valid():
		_cue_observer.call(cue_id)
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
## shell screen states exactly where the Prologue milestone ends.
func _set_boundary_status() -> void:
	var status: Label = get_node_or_null("CenterContainer/VBoxContainer/StatusLabel") as Label
	if status != null:
		status.text = "N4.2 Prologue opening complete (pl_01 + pl_02). Later beats (N4.3+) are not implemented yet."
	var detail: Label = get_node_or_null("CenterContainer/VBoxContainer/DetailLabel") as Label
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
	if _exit_transition.is_valid():
		_exit_transition.call(scene_path)
		return true
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(scene_path)
	return true
