class_name EldergroveForestArrival
extends Node2D

## N5.5: Minimal Eldergrove Forest arrival scene controller.

signal arrival_acknowledged(token: int)
signal arrival_rejected(reason: String)

const SCENE_PATH: String = "res://scenes/world/EldergroveForest.tscn"
const ARRIVAL_TITLE: String = "ELDERGROVE FOREST"
const ARRIVAL_SUBTITLE: String = "A new shore. We begin again."
const MIN_BOUND_X: float = -760.0
const MAX_BOUND_X: float = 760.0

var progression: ProgressionState = null
var era_mgr: EraProgressionManager = null
var _arrival_lock: PlayerControlLock = PlayerControlLock.new()
var _handoff_acknowledged: bool = false
var _init_valid: bool = false
var _last_status_reason: String = ""
var _persisted_on_arrival: bool = false
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

	_init_valid = validate_initialization()
	var token: int = EldergroveHandoffBridge.pending_token()
	var ack: Dictionary = EldergroveHandoffBridge.acknowledge_destination_ready(SCENE_PATH, _init_valid, token)
	if not bool(ack.get("ok", false)):
		_handoff_acknowledged = false
		_last_status_reason = String(ack.get("reason", "handoff_rejected"))
		_arrival_lock.unlock()
		arrival_rejected.emit(_last_status_reason)
		return

	var ctx: Dictionary = ack.get("source_context", {}) as Dictionary
	var prog_ref: Variant = ctx.get("progression", null)
	if prog_ref is ProgressionState:
		progression = prog_ref as ProgressionState
	var era_ref: Variant = ctx.get("era_mgr", null)
	if era_ref is EraProgressionManager:
		era_mgr = era_ref as EraProgressionManager

	if progression != null:
		progression.record_fact(ProgressionState.FACT_ELDERGROVE_REACHED)
	if era_mgr != null and progression != null:
		era_mgr.notify_eldergrove_milestone(progression)

	_persisted_on_arrival = _try_persist_arrival(ctx)

	_handoff_acknowledged = true
	_last_status_reason = ""
	_show_arrival_presentation()
	_arrival_lock.unlock()
	arrival_acknowledged.emit(int(ack.get("token", 0)))


func _exit_tree() -> void:
	_arrival_lock.unlock()


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


func is_initialization_valid() -> bool:
	return _init_valid


func get_last_status_reason() -> String:
	return _last_status_reason


func was_persisted_on_arrival() -> bool:
	return _persisted_on_arrival


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
		subtitle_label.text = ARRIVAL_SUBTITLE


func _try_persist_arrival(ctx: Dictionary) -> bool:
	if progression == null:
		return false
	var save_path: String = String(ctx.get("save_path", ""))
	var raw_payload: Variant = ctx.get("base_save_payload", null)
	if save_path.is_empty() or typeof(raw_payload) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = (raw_payload as Dictionary).duplicate(true)
	if not payload.has("progression_flags") or typeof(payload["progression_flags"]) != TYPE_DICTIONARY:
		return false
	var pf: Dictionary = payload["progression_flags"] as Dictionary
	pf["progression_facts"] = progression.to_save_array()
	if era_mgr != null:
		pf["era_id"] = era_mgr.to_save_id()
	var sm := SaveManager.new()
	return sm.save_state(payload, save_path)
