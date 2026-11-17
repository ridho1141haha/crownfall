extends Control

## N4.1: functional Prologue scene shell + lifecycle integration. NOT the story.
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
## COMPLETION SEMANTICS: this shell NEVER touches PlayerProfile. Entering,
## exiting, skipping, or closing the application must not mark
## prologue_completed_once; only the future N4.5 successful full-Prologue
## handoff (after pl_09) may call PlayerProfile.mark_prologue_completed().
## The button below is a DEVELOPMENT-ONLY exit so a build cannot dead-end
## before N4.2+ provides real Prologue content: it returns to the main menu
## and modifies no profile, no save, and no sidecar.

const MAIN_MENU_SCENE: String = "res://scenes/main/Main.tscn"
## The only world scene a Prologue sequence may transition into (N4.5 handoff).
## Menu return below is a shell exit, not a runner scene transition.
const FORGOTTEN_SHORE_SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const _ALLOWED_SEQUENCE_SCENES: Array[String] = [FORGOTTEN_SHORE_SCENE]

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


func _ready() -> void:
	_initialize_runtime()


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
	# so lock/unlock ops have a real, harmless target until N4.2+ stages actors.
	_runner.configure(
		_state,
		_panel,
		self,
		Callable(),
		Callable(self, "_on_sequence_scene_transition"),
		_ALLOWED_SEQUENCE_SCENES.duplicate()
	)
	add_child(_runner)
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
## validation; exactly-once completion; allowlisted ops). This is the
## presentation contract N4.2–N4.5 beat scripts will use — the shell authors
## NO Prologue content itself.
func play_sequence(sequence: Dictionary) -> bool:
	_initialize_runtime()
	return _runner.play(sequence)


## Fast-forwards the current sequence (runtime-level skip, N3 semantics).
func skip_sequence() -> void:
	if _runner != null:
		_runner.skip()


## Aborts the current sequence without completion (N3 semantics; cleanup only).
func cancel_sequence() -> void:
	if _runner != null:
		_runner.cancel()


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
