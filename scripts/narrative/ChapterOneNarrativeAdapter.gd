class_name ChapterOneNarrativeAdapter
extends RefCounted

## N5.0 / N5.1: Narrow, session-owned integration boundary for Chapter I
## narrative events on Forgotten Shore (D-N5-04 Option A: restore-silent, zero
## per-beat persistence flags, zero SaveManager schema v2 changes).
##
## Implemented beats:
##   - N5.1: ch1_02_foothold ("A Place to Survive") — fires once when
##     BuildingManager.WALL_ID ("wall_east_01") transitions into
##     BuildingManager.WallState.COMPLETED ("COMPLETED") during a live session
##     (D-N5-01 Option A, D-N5-03 Option A).
## N5.2+ beats remain unimplemented.

const BEAT_CH1_02_FOOTHOLD: String = "ch1_02_foothold"
const FOOTHOLD_SPEAKER: String = "Monarch"
const FOOTHOLD_LINE_TEXT: String = "The eastern wall is up. It won't hold forever, but it gives us a fighting chance tonight."
const WALL_STATE_COMPLETED_NAME: String = "COMPLETED"

var _player: Node = null
var _time_manager: TimeManager = null
var _building_mgr: BuildingManager = null
var _night_mgr: NightEncounterManager = null
var _progression: ProgressionState = null
var _dialogue_panel: DialoguePanel = null

var _state: NarrativeState = NarrativeState.new()
var _control_lock: PlayerControlLock = PlayerControlLock.new()
var _connections: Array[Dictionary] = []

var _initialized: bool = false
var _allow_live_dispatch: bool = false
var _active: bool = false
var _restoring_save: bool = false
var _torn_down: bool = false

var _last_east_wall_state: String = ""
var _foothold_historical_passed: bool = false
var _foothold_active: bool = false
var _active_beat_id: String = ""
var _beat_generation: int = 0

var _observed_event_count: int = 0
var _last_observed_event: Dictionary = {}


## Initializes the adapter with explicit session dependencies.
## Fail-closed: if any required dependency is missing, leaves zero subscriptions
## and zero locks behind. Repeated calls after a successful setup are idempotent.
func setup(deps: Dictionary, allow_live_dispatch: bool = true) -> bool:
	if _torn_down:
		return false
	if _initialized:
		return true

	var p: Node = deps.get("player", null) as Node
	var tm: TimeManager = deps.get("time_manager", null) as TimeManager
	var bm: BuildingManager = deps.get("building_mgr", null) as BuildingManager
	var nm: NightEncounterManager = deps.get("night_mgr", null) as NightEncounterManager
	var prog: ProgressionState = deps.get("progression", null) as ProgressionState
	var panel: DialoguePanel = deps.get("dialogue_panel", null) as DialoguePanel

	if p == null or tm == null or bm == null or nm == null or prog == null or panel == null:
		return false
	if not is_instance_valid(p) or not is_instance_valid(tm) or not is_instance_valid(panel):
		return false

	_player = p
	_time_manager = tm
	_building_mgr = bm
	_night_mgr = nm
	_progression = prog
	_dialogue_panel = panel
	_allow_live_dispatch = allow_live_dispatch

	_last_east_wall_state = _building_mgr.get_state_name(BuildingManager.WALL_ID)
	if _building_mgr.is_standing(BuildingManager.WALL_ID):
		_foothold_historical_passed = true

	_track_connect(_building_mgr, &"wall_state_changed", Callable(self, "_on_wall_state_changed"))
	_track_connect(_progression, &"fact_recorded", Callable(self, "_on_progression_fact_recorded"))
	_track_connect(_night_mgr, &"night_encounter_resolved", Callable(self, "_on_night_encounter_resolved"))
	_track_connect(_dialogue_panel, &"dialogue_finished", Callable(self, "_on_dialogue_finished"))
	_initialized = true
	return true


## Activates live observation only after the session has passed its restore
## boundary. Continue / restore-silent sessions remain inactive for historical
## state and never synthesize past beats.
func activate() -> bool:
	if not _initialized or _torn_down or _restoring_save:
		return false
	if not _allow_live_dispatch:
		return false
	_active = true
	return true


## Explicit save-restoration boundary (D-N5-04 Option A).
## While restoring a save, all side-effect signals are ignored; no dialogue may
## open, no lock may be acquired, and no NarrativeState mutation may occur.
func begin_save_restore() -> void:
	_restoring_save = true
	_active = false
	if _foothold_active:
		_cancel_active_beat()


func end_save_restore(restored_ok: bool) -> void:
	_restoring_save = false
	if _building_mgr != null:
		_last_east_wall_state = _building_mgr.get_state_name(BuildingManager.WALL_ID)
		if restored_ok and _building_mgr.is_standing(BuildingManager.WALL_ID):
			_foothold_historical_passed = true
	if restored_ok:
		# Continue / load restoration stays silent for historical beats.
		_allow_live_dispatch = false
		_active = false


## Skips the currently active short Chapter I beat (D-N5-04 Option A:
## skip_allowed = true). Finishes the beat cleanly, records it once in
## NarrativeState, and releases any adapter-owned control lock.
func skip_active_beat() -> bool:
	if _torn_down or not _foothold_active or _active_beat_id.is_empty():
		return false
	if _dialogue_panel != null and is_instance_valid(_dialogue_panel):
		_dialogue_panel.set_process_unhandled_input(true)
		if _dialogue_panel.is_open():
			_dialogue_panel.close()
		return true
	_finish_active_beat()
	return true


## Deterministic cleanup: disconnects ONLY this adapter's own tracked signals,
## closes an open dialogue panel if owned, and releases any held control lock.
## Idempotent and safe to call repeatedly or after scene unload.
func teardown() -> void:
	if _torn_down:
		return
	_torn_down = true
	_active = false
	_restoring_save = false
	_beat_generation += 1
	_foothold_active = false
	_active_beat_id = ""
	_disconnect_tracked()
	if _dialogue_panel != null and is_instance_valid(_dialogue_panel) and _dialogue_panel.is_open():
		_dialogue_panel.close()
	_control_lock.unlock()
	_player = null
	_time_manager = null
	_building_mgr = null
	_night_mgr = null
	_progression = null
	_dialogue_panel = null


func is_initialized() -> bool:
	return _initialized


func is_active() -> bool:
	return _active


func is_restoring_save() -> bool:
	return _restoring_save


func is_torn_down() -> bool:
	return _torn_down


func is_beat_active() -> bool:
	return _foothold_active


func active_beat_id() -> String:
	return _active_beat_id


func narrative_state() -> NarrativeState:
	return _state


func control_lock() -> PlayerControlLock:
	return _control_lock


func dialogue_panel() -> DialoguePanel:
	return _dialogue_panel


func tracked_connection_count() -> int:
	return _connections.size()


func observed_event_count() -> int:
	return _observed_event_count


func last_observed_event() -> Dictionary:
	return _last_observed_event.duplicate(true)


func _track_connect(obj: Object, sig: StringName, cb: Callable) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	if obj.is_connected(sig, cb):
		return
	var err: Error = obj.connect(sig, cb)
	if err == OK:
		_connections.append({"object": obj, "signal": sig, "callable": cb})


func _disconnect_tracked() -> void:
	for entry: Dictionary in _connections:
		var obj: Object = entry.get("object", null) as Object
		var sig: StringName = entry.get("signal", &"") as StringName
		var cb: Callable = entry.get("callable", Callable()) as Callable
		if obj != null and is_instance_valid(obj) and obj.is_connected(sig, cb):
			obj.disconnect(sig, cb)
	_connections.clear()


func _can_dispatch_live() -> bool:
	return _initialized and _active and not _torn_down and not _restoring_save


func _on_wall_state_changed(wall_id: String, new_state: String, _progress: float, _durability: int, _max_durability: int) -> void:
	if wall_id != BuildingManager.WALL_ID:
		return
	var prev_state: String = _last_east_wall_state
	_last_east_wall_state = new_state
	if not _can_dispatch_live():
		return
	if _foothold_historical_passed or _foothold_active or _state.is_completed(BEAT_CH1_02_FOOTHOLD):
		return
	if new_state != WALL_STATE_COMPLETED_NAME or prev_state == WALL_STATE_COMPLETED_NAME:
		return
	_start_foothold_beat()


func _start_foothold_beat() -> void:
	if _dialogue_panel == null or not is_instance_valid(_dialogue_panel) or _dialogue_panel.is_open():
		return
	_beat_generation += 1
	_foothold_active = true
	_active_beat_id = BEAT_CH1_02_FOOTHOLD
	# Non-gating acknowledgement (N5.1 §3): never lock player or swallow gameplay keys (e.g., Q upgrade / movement).
	_dialogue_panel.set_process_unhandled_input(false)
	var lines: Array[Dictionary] = [
		{"speaker": FOOTHOLD_SPEAKER, "text": FOOTHOLD_LINE_TEXT},
	]
	_dialogue_panel.open_lines(lines)


func _on_dialogue_finished() -> void:
	if _torn_down or not _foothold_active or _active_beat_id != BEAT_CH1_02_FOOTHOLD:
		return
	_finish_active_beat()


func _finish_active_beat() -> void:
	var completed_id: String = _active_beat_id
	_beat_generation += 1
	_foothold_active = false
	_active_beat_id = ""
	if _dialogue_panel != null and is_instance_valid(_dialogue_panel):
		_dialogue_panel.set_process_unhandled_input(true)
	_control_lock.unlock()
	if not completed_id.is_empty():
		_state.mark_completed(completed_id)


func _cancel_active_beat() -> void:
	_beat_generation += 1
	_foothold_active = false
	_active_beat_id = ""
	if _dialogue_panel != null and is_instance_valid(_dialogue_panel):
		_dialogue_panel.set_process_unhandled_input(true)
		if _dialogue_panel.is_open():
			_dialogue_panel.close()
	_control_lock.unlock()


func _on_progression_fact_recorded(fact_id: String) -> void:
	if not _can_dispatch_live():
		return
	_observed_event_count += 1
	_last_observed_event = {"source": "progression", "fact_id": fact_id}


func _on_night_encounter_resolved(survived: bool, wall_held: bool) -> void:
	if not _can_dispatch_live():
		return
	_observed_event_count += 1
	_last_observed_event = {"source": "night_encounter", "survived": survived, "wall_held": wall_held}
