class_name EldergroveForestArrival
extends Node2D

## N5.5: Minimal Eldergrove Forest arrival scene controller.
##
## Fail-closed acknowledgement & persistence sequence:
##   1. Validate required destination scene nodes.
##   2. Validate pending handoff intent, destination identity, and token.
##   3. Validate authoritative ProgressionState, EraProgressionManager, and
##      persistence context (safe save_path + valid SaveManager v2 base payload).
##   4. Acknowledge and consume the one-shot handoff ONLY after steps 1-3 pass.
##   5. Record FACT_ELDERGROVE_REACHED on the authoritative ProgressionState
##      and notify EraProgressionManager (runtime milestone recorded).
##   6. Persist updated facts & era through SaveManager with bounded retry and
##      explicit status reporting (preserving last known-good save on failure).
##   7. Restore player control safely on every exit path.

signal arrival_acknowledged(token: int)
signal arrival_rejected(reason: String)
signal arrival_persistence_failed(reason: String)

const SCENE_PATH: String = "res://scenes/world/EldergroveForest.tscn"
const ARRIVAL_TITLE: String = "ELDERGROVE FOREST"
const ARRIVAL_SUBTITLE: String = "A new shore. We begin again."
const PERSIST_FAIL_SUBTITLE: String = "A new shore. We begin again. (Warning: arrival progress was not saved)"
const MIN_BOUND_X: float = -760.0
const MAX_BOUND_X: float = 760.0
const MAX_PERSIST_ATTEMPTS: int = 2

var progression: ProgressionState = null
var era_mgr: EraProgressionManager = null
var _arrival_lock: PlayerControlLock = PlayerControlLock.new()
var _handoff_acknowledged: bool = false
var _runtime_milestone_recorded: bool = false
var _init_valid: bool = false
var _last_status_reason: String = ""
var _persisted_on_arrival: bool = false
var _persistence_attempts: int = 0
var _persistence_failure_reason: String = ""
var _force_invalid_init_for_test: bool = false

@onready var player: PlayerController = get_node_or_null("Player") as PlayerController
@onready var ground: StaticBody2D = get_node_or_null("Ground") as StaticBody2D
@onready var ground_collision: CollisionShape2D = get_node_or_null("Ground/CollisionShape2D") as CollisionShape2D
@onready var title_label: Label = get_node_or_null("ArrivalHUD/MarginContainer/VBoxContainer/TitleLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("ArrivalHUD/MarginContainer/VBoxContainer/SubtitleLabel") as Label


func _ready() -> void:
	_configure_player_bounds()
	if player != null:
		_arrival_lock.lock(player)

	# Step 1: Validate required destination scene nodes.
	_init_valid = validate_initialization()

	# Step 2: Validate pending handoff presence, destination, and token.
	if not EldergroveHandoffBridge.has_pending_intent():
		var no_ack: Dictionary = EldergroveHandoffBridge.acknowledge_destination_ready(SCENE_PATH, _init_valid, 0)
		_reject_arrival(String(no_ack.get("reason", "no_pending_intent")))
		return

	var token: int = EldergroveHandoffBridge.pending_token()
	if not _init_valid:
		var bad_init_ack: Dictionary = EldergroveHandoffBridge.acknowledge_destination_ready(SCENE_PATH, false, token)
		_reject_arrival(String(bad_init_ack.get("reason", "destination_invalid")))
		return

	if EldergroveHandoffBridge.peek_pending_destination() != SCENE_PATH:
		var wrong_dest_ack: Dictionary = EldergroveHandoffBridge.acknowledge_destination_ready(SCENE_PATH, _init_valid, token)
		_reject_arrival(String(wrong_dest_ack.get("reason", "wrong_destination")))
		return

	# Step 3: Fail-closed validation of authoritative source & persistence context
	# BEFORE acknowledging or consuming the one-shot handoff.
	var peek_ctx: Dictionary = EldergroveHandoffBridge.peek_pending_context()
	var ctx_err: String = _validate_source_context(peek_ctx)
	if not ctx_err.is_empty():
		EldergroveHandoffBridge.invalidate_pending(ctx_err)
		_reject_arrival(ctx_err)
		return

	# Step 4: Acknowledge and consume the one-shot handoff.
	var ack: Dictionary = EldergroveHandoffBridge.acknowledge_destination_ready(SCENE_PATH, _init_valid, token)
	if not bool(ack.get("ok", false)):
		_reject_arrival(String(ack.get("reason", "handoff_rejected")))
		return

	_handoff_acknowledged = true

	# Step 5: Record FACT_ELDERGROVE_REACHED on authoritative ProgressionState
	# and notify EraProgressionManager only after acknowledgement succeeds.
	var ctx: Dictionary = ack.get("source_context", {}) as Dictionary
	progression = ctx.get("progression", null) as ProgressionState
	era_mgr = ctx.get("era_mgr", null) as EraProgressionManager
	if progression.record_fact(ProgressionState.FACT_ELDERGROVE_REACHED):
		_runtime_milestone_recorded = progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED)
	era_mgr.notify_eldergrove_milestone(progression)

	# Step 6: Persist arrival milestone through SaveManager with explicit status.
	var persist_res: Dictionary = _try_persist_arrival(ctx)
	_persisted_on_arrival = bool(persist_res.get("ok", false))
	_persistence_attempts = int(persist_res.get("attempts", 0))
	_persistence_failure_reason = String(persist_res.get("reason", ""))
	if not _persisted_on_arrival:
		_last_status_reason = "arrival_persistence_failed"
		push_warning("[EldergroveForestArrival] Arrival fact recorded in runtime but persistence failed after %d attempt(s): %s" % [_persistence_attempts, _persistence_failure_reason])
		arrival_persistence_failed.emit(_persistence_failure_reason)
	else:
		_last_status_reason = ""

	# Step 7: Show arrival presentation and restore player control safely.
	_show_arrival_presentation()
	_arrival_lock.unlock()
	arrival_acknowledged.emit(int(ack.get("token", 0)))


func _exit_tree() -> void:
	_arrival_lock.unlock()


func _reject_arrival(reason: String) -> void:
	_handoff_acknowledged = false
	_runtime_milestone_recorded = false
	_persisted_on_arrival = false
	_persistence_attempts = 0
	_persistence_failure_reason = ""
	_last_status_reason = reason
	_arrival_lock.unlock()
	arrival_rejected.emit(reason)


func _validate_source_context(ctx: Dictionary) -> String:
	var prog_ref: Variant = ctx.get("progression", null)
	if not (prog_ref is ProgressionState):
		return "missing_or_invalid_progression"
	var era_ref: Variant = ctx.get("era_mgr", null)
	if not (era_ref is EraProgressionManager):
		return "missing_or_invalid_era_manager"
	var raw_path: Variant = ctx.get("save_path", null)
	if typeof(raw_path) != TYPE_STRING:
		return "invalid_persistence_context"
	var save_path: String = String(raw_path)
	if save_path.is_empty() or not SaveManager.is_safe_save_path(save_path):
		return "invalid_persistence_context"
	var raw_payload: Variant = ctx.get("base_save_payload", null)
	if typeof(raw_payload) != TYPE_DICTIONARY:
		return "invalid_persistence_context"
	var payload: Dictionary = raw_payload as Dictionary
	if not payload.has("progression_flags") or typeof(payload["progression_flags"]) != TYPE_DICTIONARY:
		return "invalid_persistence_context"
	var sm := SaveManager.new()
	if not sm.validate_payload(payload):
		return "invalid_persistence_context"
	return ""


func validate_initialization() -> bool:
	if _force_invalid_init_for_test:
		return false
	if player == null or not is_instance_valid(player):
		return false
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if cam == null or not is_instance_valid(cam):
		return false
	if ground == null or not is_instance_valid(ground):
		return false
	if ground_collision == null or not is_instance_valid(ground_collision):
		return false
	if title_label == null or not is_instance_valid(title_label):
		return false
	return true


func is_handoff_acknowledged() -> bool:
	return _handoff_acknowledged


func is_runtime_milestone_recorded() -> bool:
	return _runtime_milestone_recorded


func is_initialization_valid() -> bool:
	return _init_valid


func get_last_status_reason() -> String:
	return _last_status_reason


func was_persisted_on_arrival() -> bool:
	return _persisted_on_arrival


func get_persistence_failure_reason() -> String:
	return _persistence_failure_reason


func get_persistence_attempts() -> int:
	return _persistence_attempts


func get_arrival_status() -> Dictionary:
	return {
		"handoff_acknowledged": _handoff_acknowledged,
		"runtime_milestone_recorded": _runtime_milestone_recorded,
		"persisted": _persisted_on_arrival,
		"persistence_attempts": _persistence_attempts,
		"persistence_failure_reason": _persistence_failure_reason,
		"status_reason": _last_status_reason,
	}


func is_player_control_restored() -> bool:
	if _arrival_lock.is_locked():
		return false
	if player == null or not is_instance_valid(player):
		return false
	return player.is_physics_processing() and player.is_processing_unhandled_input()


func _configure_player_bounds() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.min_bound_x = MIN_BOUND_X
	player.max_bound_x = MAX_BOUND_X
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.limit_left = -800
		cam.limit_right = 800


func _show_arrival_presentation() -> void:
	if title_label != null:
		title_label.text = ARRIVAL_TITLE
	if subtitle_label != null:
		subtitle_label.text = ARRIVAL_SUBTITLE if _persisted_on_arrival else PERSIST_FAIL_SUBTITLE


func _try_persist_arrival(ctx: Dictionary) -> Dictionary:
	if progression == null or era_mgr == null:
		return {"ok": false, "attempts": 0, "reason": "missing_progression_state"}
	var save_path: String = String(ctx.get("save_path", ""))
	var raw_payload: Variant = ctx.get("base_save_payload", null)
	if save_path.is_empty() or not SaveManager.is_safe_save_path(save_path) or typeof(raw_payload) != TYPE_DICTIONARY:
		return {"ok": false, "attempts": 0, "reason": "invalid_persistence_context"}
	var payload: Dictionary = (raw_payload as Dictionary).duplicate(true)
	if not payload.has("progression_flags") or typeof(payload["progression_flags"]) != TYPE_DICTIONARY:
		return {"ok": false, "attempts": 0, "reason": "invalid_persistence_context"}
	var pf: Dictionary = payload["progression_flags"] as Dictionary
	pf["progression_facts"] = progression.to_save_array()
	pf["era_id"] = era_mgr.to_save_id()

	var simulate_fail: bool = bool(ctx.get("_test_simulate_save_failure", false))
	var sm := SaveManager.new()
	var last_error: Array[String] = [""]
	sm.save_failed.connect(func(msg: String) -> void: last_error[0] = msg)

	var attempts: int = 0
	for _i: int in range(MAX_PERSIST_ATTEMPTS):
		attempts += 1
		if sm.save_state(payload, save_path, simulate_fail):
			return {"ok": true, "attempts": attempts, "reason": ""}

	var reason: String = last_error[0] if not last_error[0].is_empty() else "save_write_failed"
	return {"ok": false, "attempts": attempts, "reason": reason}
