class_name EldergroveForestArrival
extends Node2D

## N5.5 / N5.6 / N6.0: Eldergrove Forest arrival & first playable slice controller.
##
## Lifecycle paths:
##   A) Fresh N5.5 Departure Handoff (crownfall_load_on_start == false)
##   B) N5.6 Island-Aware Continue Restoration (crownfall_load_on_start == true)
##
## N6.0 reuses existing PlayerController, EconomyLedger, ResourceNodeManager,
## InteractionResolver, PauseMenu, ProgressionState, EraProgressionManager, and
## SaveManager (schema v2 unchanged) to provide a bounded playable clearing with
## movement, collision, resource gathering, manual save, and Main Menu exit/re-entry.

signal arrival_acknowledged(token: int)
signal arrival_rejected(reason: String)
signal arrival_persistence_failed(reason: String)
signal continue_restored(save_path: String)
signal continue_restore_failed(reason: String)
signal interaction_completed(target_id: String, resource_id: StringName, amount: int)
signal camp_constructed(camp_id: String, cost: Dictionary)
signal sunrise_renewal_applied(completed_day: int, refreshed_ids: Array[String])
signal feedback_message(text: String)

const SCENE_PATH: String = "res://scenes/world/EldergroveForest.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/main/Main.tscn"
const ARRIVAL_TITLE: String = "ELDERGROVE FOREST"
const ARRIVAL_SUBTITLE: String = "A new shore. We begin again."
const RESTORED_SUBTITLE: String = "Eldergrove Forest — reign restored."
const PERSIST_FAIL_SUBTITLE: String = "A new shore. We begin again. (Warning: arrival progress was not saved)"
const MIN_BOUND_X: float = -760.0
const MAX_BOUND_X: float = 760.0
const PLAYER_SPAWN_X: float = -320.0
const PLAYER_SPAWN_Y: float = 0.0
const MAX_PERSIST_ATTEMPTS: int = 2
const OFF_ISLAND_X: float = -99999.0
const CAMP_SITE_ID: String = "eldergrove_first_camp"
const CAMP_BUILT_STATE_KEY: String = "eldergrove_first_camp_built"
const CAMP_SITE_X: float = 80.0
const CAMP_INTERACT_RANGE: float = 68.0
const CAMP_BUILD_COST: Dictionary = {
	"wood": 4,
	"stone": 2,
}
const SKY_COLOR_DAYLIGHT: Color = Color(0.18, 0.34, 0.36, 1.0)
const SKY_COLOR_SUNSET: Color = Color(0.42, 0.24, 0.18, 1.0)
const SKY_COLOR_NIGHT: Color = Color(0.06, 0.09, 0.16, 1.0)
const MODULATE_DAYLIGHT: Color = Color(1.0, 1.0, 1.0, 1.0)
const MODULATE_SUNSET: Color = Color(0.96, 0.82, 0.72, 1.0)
const MODULATE_NIGHT: Color = Color(0.62, 0.68, 0.84, 1.0)
const FAST_CLOCK_SCALE: float = 10.0

const ELDERGROVE_NODES: Array[Dictionary] = [
	{
		"id": "eldergrove_fallen_timber_01",
		"resource": &"wood",
		"amount": 4,
		"x": -60.0,
		"renewable": true,
		"label": "Fallen Clearing Timber (+4 Wood)",
		"prompt": "[E] Gather Timber (+4W)",
	},
	{
		"id": "eldergrove_mossy_stone_01",
		"resource": &"stone",
		"amount": 3,
		"x": 220.0,
		"renewable": true,
		"label": "Mossy Outcrop (+3 Stone)",
		"prompt": "[E] Gather Stone (+3S)",
	},
	{
		"id": "eldergrove_foraged_supply_01",
		"resource": &"gold",
		"amount": 3,
		"x": 500.0,
		"renewable": false,
		"label": "Weathered Supply Crate (+3 Gold)",
		"prompt": "[E] Salvage Crate (+3G)",
	},
]

var progression: ProgressionState = null
var era_mgr: EraProgressionManager = null
var ledger: EconomyLedger = EconomyLedger.new()
var resource_mgr: ResourceNodeManager = ResourceNodeManager.new()

var _arrival_lock: PlayerControlLock = PlayerControlLock.new()
var _handoff_acknowledged: bool = false
var _restored_from_continue: bool = false
var _runtime_milestone_recorded: bool = false
var _init_valid: bool = false
var _last_status_reason: String = ""
var _last_rejection_reason: String = ""
var _persisted_on_arrival: bool = false
var _persistence_attempts: int = 0
var _persistence_failure_reason: String = ""
var _force_invalid_init_for_test: bool = false
var _base_save_payload: Dictionary = {}
var _has_unsaved_progress: bool = false
var _active_target: Dictionary = {}
var _node_markers: Dictionary = {}
var _signals_connected: bool = false
var _scene_transition: Callable = Callable()
var _first_camp_built: bool = false
var _last_sunrise_completed_day: int = 0
var _last_sunrise_refreshed_ids: Array[String] = []
var _sunrise_renewal_count: int = 0
var _clock_signals_connected: bool = false

@onready var player: PlayerController = get_node_or_null("Player") as PlayerController
@onready var ground: StaticBody2D = get_node_or_null("Ground") as StaticBody2D
@onready var ground_collision: CollisionShape2D = get_node_or_null("Ground/CollisionShape2D") as CollisionShape2D
@onready var world_objects: Node2D = get_node_or_null("WorldObjects") as Node2D
@onready var title_label: Label = get_node_or_null("ArrivalHUD/MarginContainer/VBoxContainer/TitleLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("ArrivalHUD/MarginContainer/VBoxContainer/SubtitleLabel") as Label
@onready var resources_label: Label = get_node_or_null("ArrivalHUD/MarginContainer/VBoxContainer/ResourcesLabel") as Label
@onready var prompt_label: Label = get_node_or_null("ArrivalHUD/BottomBar/PromptLabel") as Label
@onready var feedback_label: Label = get_node_or_null("ArrivalHUD/BottomBar/FeedbackLabel") as Label
@onready var pause_menu: PauseMenu = get_node_or_null("PauseMenu") as PauseMenu
@onready var camp_site_node: Node2D = get_node_or_null("WorldObjects/FirstCampSite") as Node2D
@onready var camp_site_marker: ColorRect = get_node_or_null("WorldObjects/FirstCampSite/SiteMarker") as ColorRect
@onready var camp_shelter_sprite: Sprite2D = get_node_or_null("WorldObjects/FirstCampSite/CampShelterSprite") as Sprite2D
@onready var camp_label: Label = get_node_or_null("WorldObjects/FirstCampSite/CampLabel") as Label
@onready var time_manager: TimeManager = get_node_or_null("TimeManager") as TimeManager
@onready var clock_label: Label = get_node_or_null("ArrivalHUD/MarginContainer/VBoxContainer/ClockLabel") as Label
@onready var sky_background: ColorRect = get_node_or_null("SkyLayer/SkyBackground") as ColorRect
@onready var day_night_modulate: CanvasModulate = get_node_or_null("DayNightModulate") as CanvasModulate


func _ready() -> void:
	resource_mgr.configure_nodes(ELDERGROVE_NODES)
	_configure_player_bounds()
	_place_player_at_spawn()
	_build_resource_markers()
	_refresh_camp_visuals()
	_wire_gameplay_connections()
	_wire_clock_connections()
	_apply_phase_visuals()
	_refresh_clock_hud()
	if pause_menu != null:
		pause_menu.bind_session(self)

	if player != null:
		_arrival_lock.lock(player)

	_init_valid = validate_initialization()

	# N5.6: Dedicated Continue restoration path (strictly separate from N5.5 departure handoff).
	if Engine.has_meta("crownfall_load_on_start") and bool(Engine.get_meta("crownfall_load_on_start")):
		Engine.set_meta("crownfall_load_on_start", false)
		EldergroveHandoffBridge.invalidate_pending("eldergrove_continue_restore")
		_restore_from_continue_save()
		return

	# N5.5: Fresh departure handoff path.
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

	var peek_ctx: Dictionary = EldergroveHandoffBridge.peek_pending_context()
	var ctx_err: String = _validate_source_context(peek_ctx)
	if not ctx_err.is_empty():
		EldergroveHandoffBridge.invalidate_pending(ctx_err)
		_reject_arrival(ctx_err)
		return

	var ack: Dictionary = EldergroveHandoffBridge.acknowledge_destination_ready(SCENE_PATH, _init_valid, token)
	if not bool(ack.get("ok", false)):
		_reject_arrival(String(ack.get("reason", "handoff_rejected")))
		return

	_handoff_acknowledged = true

	var ctx: Dictionary = ack.get("source_context", {}) as Dictionary
	progression = ctx.get("progression", null) as ProgressionState
	era_mgr = ctx.get("era_mgr", null) as EraProgressionManager
	_hydrate_gameplay_from_payload(ctx.get("base_save_payload", {}) as Dictionary, false)
	if progression.record_fact(ProgressionState.FACT_ELDERGROVE_REACHED):
		_runtime_milestone_recorded = progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED)
	era_mgr.notify_eldergrove_milestone(progression)

	var persist_res: Dictionary = _try_persist_arrival(ctx)
	_persisted_on_arrival = bool(persist_res.get("ok", false))
	_persistence_attempts = int(persist_res.get("attempts", 0))
	_persistence_failure_reason = String(persist_res.get("reason", ""))
	if not _persisted_on_arrival:
		_last_status_reason = "arrival_persistence_failed"
		_has_unsaved_progress = true
		push_warning("[EldergroveForestArrival] Arrival fact recorded in runtime but persistence failed after %d attempt(s): %s" % [_persistence_attempts, _persistence_failure_reason])
		arrival_persistence_failed.emit(_persistence_failure_reason)
	else:
		_last_status_reason = ""
		_has_unsaved_progress = false

	_show_arrival_presentation()
	_refresh_gameplay_hud()
	_refresh_clock_hud()
	_apply_phase_visuals()
	_refresh_resource_markers()
	_refresh_camp_visuals()
	_arrival_lock.unlock()
	arrival_acknowledged.emit(int(ack.get("token", 0)))


func _process(_delta: float) -> void:
	_refresh_clock_hud()
	if player == null or not is_instance_valid(player):
		return
	_active_target = resolve_nearest_interaction(player.global_position.x)
	if prompt_label != null:
		if bool(_active_target.get("has_target", false)):
			prompt_label.text = String(_active_target.get("prompt_text", ""))
		else:
			prompt_label.text = "Explore the clearing — [A/D] Move | [E] Interact | [K] Save | [Esc] Menu"


func _exit_tree() -> void:
	_arrival_lock.unlock()
	if get_tree() != null:
		get_tree().paused = false


func set_scene_transition(transition: Callable) -> void:
	_scene_transition = transition


func is_first_camp_built() -> bool:
	return _first_camp_built


func get_camp_build_cost() -> Dictionary:
	return CAMP_BUILD_COST.duplicate()


func _get_camp_prompt_text() -> String:
	if _first_camp_built:
		return "First Camp (Built)"
	var cost_txt: String = BuildingManager.format_cost_text(CAMP_BUILD_COST)
	if ledger.can_afford(CAMP_BUILD_COST):
		return "[E] Build First Camp (%s)" % cost_txt
	return "[E] Build First Camp (Need %s)" % cost_txt


func _build_custom_interaction_targets() -> Array[Dictionary]:
	return [
		{
			"id": CAMP_SITE_ID,
			"kind": "camp_site",
			"x": CAMP_SITE_X,
			"range": CAMP_INTERACT_RANGE,
			"primary_command": &"inspect_camp" if _first_camp_built else &"build_camp",
			"prompt_text": _get_camp_prompt_text(),
		},
	]


func resolve_nearest_interaction(actor_x: float) -> Dictionary:
	return InteractionResolver.resolve_nearest(
		actor_x,
		resource_mgr,
		null,
		null,
		null,
		0,
		OFF_ISLAND_X,
		-OFF_ISLAND_X,
		true,
		false,
		null,
		null,
		null,
		null,
		null,
		_build_custom_interaction_targets()
	)


func get_active_interaction_target() -> Dictionary:
	return _active_target.duplicate(true)


func try_interact_at(actor_x: float) -> Dictionary:
	if progression == null or not progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED):
		_record_rejection("Eldergrove session is not active")
		return {"ok": false, "reason": _last_rejection_reason}
	var target: Dictionary = resolve_nearest_interaction(actor_x)
	if not bool(target.get("has_target", false)):
		_record_rejection("Nothing within interaction range")
		return {"ok": false, "reason": _last_rejection_reason}
	var cmd: StringName = target.get("primary_command", &"") as StringName
	var target_id: String = String(target.get("target_id", ""))
	if cmd == &"collect":
		var res: Dictionary = resource_mgr.try_collect(target_id, actor_x, ledger)
		if not bool(res.get("ok", false)):
			_record_rejection(String(res.get("reason", "Collection failed")))
			return res
		var node_def: Dictionary = res.get("node", {}) as Dictionary
		var res_id: StringName = node_def.get("resource", &"wood") as StringName
		var amount: int = int(node_def.get("amount", 0))
		_has_unsaved_progress = true
		_last_rejection_reason = ""
		_refresh_resource_markers()
		_refresh_gameplay_hud()
		var msg: String = "Gathered %s" % String(node_def.get("label", target_id))
		_set_feedback(msg)
		interaction_completed.emit(target_id, res_id, amount)
		return res
	if cmd == &"build_camp":
		return try_build_first_camp(actor_x)
	if cmd == &"inspect_camp":
		_set_feedback("First Camp is already built.")
		return {"ok": false, "already_built": true, "reason": "First Camp already constructed"}
	_record_rejection("Unsupported interaction command")
	return {"ok": false, "reason": _last_rejection_reason}


func try_build_first_camp(actor_x: float) -> Dictionary:
	if progression == null or not progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED):
		_record_rejection("Eldergrove session is not active")
		return {"ok": false, "reason": _last_rejection_reason}
	if _first_camp_built:
		_set_feedback("First Camp is already built.")
		return {"ok": false, "already_built": true, "reason": "First Camp already constructed"}
	if absf(actor_x - CAMP_SITE_X) > CAMP_INTERACT_RANGE:
		_record_rejection("Move closer to the Camp Site")
		return {"ok": false, "reason": _last_rejection_reason}
	if not ledger.can_afford(CAMP_BUILD_COST):
		var cost_txt: String = BuildingManager.format_cost_text(CAMP_BUILD_COST)
		_record_rejection("Insufficient resources to build First Camp (Need %s)" % cost_txt)
		return {"ok": false, "reason": _last_rejection_reason}
	if not ledger.try_spend(CAMP_BUILD_COST):
		_record_rejection("Failed to deduct resources for First Camp")
		return {"ok": false, "reason": _last_rejection_reason}
	_first_camp_built = true
	_has_unsaved_progress = true
	_last_rejection_reason = ""
	_refresh_camp_visuals()
	_refresh_gameplay_hud()
	_set_feedback("First Camp constructed!")
	camp_constructed.emit(CAMP_SITE_ID, CAMP_BUILD_COST.duplicate())
	return {"ok": true, "camp_id": CAMP_SITE_ID, "cost": CAMP_BUILD_COST.duplicate()}


func build_save_payload() -> Dictionary:
	if _base_save_payload.is_empty() or progression == null or era_mgr == null:
		return {}
	var payload: Dictionary = _base_save_payload.duplicate(true)
	if not payload.has("progression_flags") or typeof(payload["progression_flags"]) != TYPE_DICTIONARY:
		return {}
	if time_manager != null and is_instance_valid(time_manager):
		var clock_dict: Dictionary = time_manager.to_save_dict()
		payload["day_count"] = int(clock_dict["day_count"])
		payload["world_time"] = float(clock_dict["world_time"])
		payload["world_phase"] = String(clock_dict["world_phase"])
	payload["resources"] = ledger.get_all_balances()
	if player != null and is_instance_valid(player):
		payload["player"] = {
			"position_x": clampf(player.global_position.x, MIN_BOUND_X, MAX_BOUND_X),
			"facing_direction": 1 if player.facing_direction >= 0 else -1,
		}
	var pf: Dictionary = payload["progression_flags"] as Dictionary
	pf["progression_facts"] = progression.to_save_array()
	pf["era_id"] = era_mgr.to_save_id()
	var merged_nodes: Dictionary = {}
	if pf.has("node_states") and typeof(pf["node_states"]) == TYPE_DICTIONARY:
		merged_nodes = (pf["node_states"] as Dictionary).duplicate(true)
	var eg_nodes: Dictionary = resource_mgr.to_save_dict()
	for nid: String in eg_nodes.keys():
		merged_nodes[nid] = bool(eg_nodes[nid])
	merged_nodes[CAMP_BUILT_STATE_KEY] = _first_camp_built
	pf["node_states"] = merged_nodes
	return payload


func save_game_state(save_path: String = "", simulate_failure: bool = false) -> bool:
	if progression == null or era_mgr == null or not progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED):
		_record_rejection("Cannot save without active Eldergrove progression")
		return false
	var target_path: String = save_path if not save_path.is_empty() else _resolve_continue_save_path()
	if target_path.is_empty() or not SaveManager.is_safe_save_path(target_path):
		_record_rejection("Invalid save path")
		return false
	var payload: Dictionary = build_save_payload()
	if payload.is_empty():
		_record_rejection("No valid base save payload available")
		return false
	var sm := SaveManager.new()
	if not sm.validate_payload(payload):
		_record_rejection("Save payload failed schema v2 validation")
		return false
	if not sm.save_state(payload, target_path, simulate_failure):
		_record_rejection("Failed to save Eldergrove progress")
		return false
	_base_save_payload = payload.duplicate(true)
	_has_unsaved_progress = false
	_last_rejection_reason = ""
	_set_feedback("Eldergrove progress saved.")
	return true


func _on_manual_save() -> bool:
	return save_game_state()


func has_unsaved_progress() -> bool:
	return _has_unsaved_progress


func get_last_rejection_reason() -> String:
	return _last_rejection_reason


func return_to_main_menu() -> bool:
	EldergroveHandoffBridge.invalidate_pending("eldergrove_return_to_menu")
	_arrival_lock.unlock()
	if get_tree() != null:
		get_tree().paused = false
	if _scene_transition.is_valid():
		_scene_transition.call(MAIN_MENU_SCENE)
		return true
	if is_inside_tree() and get_tree() != null:
		return get_tree().change_scene_to_file(MAIN_MENU_SCENE) == OK
	return false


func _on_player_interaction_requested(player_x: float) -> void:
	try_interact_at(player_x)


func _wire_gameplay_connections() -> void:
	if _signals_connected or player == null or not is_instance_valid(player):
		return
	if not player.interaction_requested.is_connected(_on_player_interaction_requested):
		player.interaction_requested.connect(_on_player_interaction_requested)
	if not player.manual_save_requested.is_connected(_on_manual_save):
		player.manual_save_requested.connect(_on_manual_save)
	if not player.fast_clock_toggled.is_connected(_on_toggle_fast_clock):
		player.fast_clock_toggled.connect(_on_toggle_fast_clock)
	_signals_connected = true


func _resolve_continue_save_path() -> String:
	if Engine.has_meta("crownfall_menu_save_path"):
		return String(Engine.get_meta("crownfall_menu_save_path"))
	return SaveManager.DEFAULT_SAVE_PATH


func _hydrate_gameplay_from_payload(payload: Dictionary, restore_player_position: bool) -> void:
	if payload.is_empty():
		return
	_base_save_payload = payload.duplicate(true)
	if time_manager != null and is_instance_valid(time_manager):
		if time_manager.apply_save_dict(payload, true):
			_last_sunrise_completed_day = maxi(0, time_manager.current_day - 1)
	if payload.has("resources") and typeof(payload["resources"]) == TYPE_DICTIONARY:
		ledger.set_balances_from_dict(payload["resources"] as Dictionary)
	if payload.has("progression_flags") and typeof(payload["progression_flags"]) == TYPE_DICTIONARY:
		var pf: Dictionary = payload["progression_flags"] as Dictionary
		if pf.has("node_states") and typeof(pf["node_states"]) == TYPE_DICTIONARY:
			var ns: Dictionary = pf["node_states"] as Dictionary
			resource_mgr.apply_save_state(ns)
			_first_camp_built = bool(ns.get(CAMP_BUILT_STATE_KEY, false))
		else:
			_first_camp_built = false
	if restore_player_position and player != null and is_instance_valid(player):
		var placed: bool = false
		if payload.has("player") and typeof(payload["player"]) == TYPE_DICTIONARY:
			var p_dict: Dictionary = payload["player"] as Dictionary
			if typeof(p_dict.get("position_x", null)) in [TYPE_FLOAT, TYPE_INT]:
				var px: float = float(p_dict["position_x"])
				if not is_nan(px) and not is_inf(px) and px >= MIN_BOUND_X and px <= MAX_BOUND_X:
					player.global_position = Vector2(px, PLAYER_SPAWN_Y)
					var fd: int = int(roundf(float(p_dict.get("facing_direction", 1))))
					player.facing_direction = -1 if fd < 0 else 1
					placed = true
		if not placed:
			_place_player_at_spawn()


func _restore_from_continue_save() -> void:
	if not _init_valid:
		_reject_continue_restore("destination_invalid")
		return
	var save_path: String = _resolve_continue_save_path()
	if save_path.is_empty() or not SaveManager.is_safe_save_path(save_path):
		_reject_continue_restore("unsafe_save_path")
		return
	var sm := SaveManager.new()
	var loaded: Dictionary = sm.load_state(save_path)
	if not bool(loaded.get("ok", false)):
		_reject_continue_restore("save_load_failed")
		return
	var data: Dictionary = loaded.get("data", {}) as Dictionary
	if not data.has("progression_flags") or typeof(data["progression_flags"]) != TYPE_DICTIONARY:
		_reject_continue_restore("missing_progression_flags")
		return
	var pf: Dictionary = data["progression_flags"] as Dictionary
	var raw_facts: Variant = pf.get("progression_facts", null)
	if typeof(raw_facts) != TYPE_ARRAY or not ProgressionState.is_valid_fact_array(raw_facts):
		_reject_continue_restore("missing_eldergrove_fact")
		return
	if not (raw_facts as Array).has(ProgressionState.FACT_ELDERGROVE_REACHED):
		_reject_continue_restore("missing_eldergrove_fact")
		return

	var restored_prog := ProgressionState.new()
	if not restored_prog.apply_save_state(raw_facts):
		_reject_continue_restore("progression_apply_failed")
		return
	var restored_era := EraProgressionManager.new()
	var saved_era_id: String = String(pf.get("era_id", ""))
	if not saved_era_id.is_empty() and not restored_era.apply_save_era(saved_era_id):
		_reject_continue_restore("era_apply_failed")
		return

	progression = restored_prog
	era_mgr = restored_era
	_hydrate_gameplay_from_payload(data, true)
	_handoff_acknowledged = false
	_restored_from_continue = true
	_runtime_milestone_recorded = progression.has_fact(ProgressionState.FACT_ELDERGROVE_REACHED)
	_persisted_on_arrival = false
	_persistence_attempts = 0
	_persistence_failure_reason = ""
	_last_status_reason = ""
	_has_unsaved_progress = false
	_show_restored_presentation()
	_refresh_gameplay_hud()
	_refresh_clock_hud()
	_apply_phase_visuals()
	_refresh_resource_markers()
	_refresh_camp_visuals()
	_arrival_lock.unlock()
	continue_restored.emit(save_path)


func _reject_continue_restore(reason: String) -> void:
	progression = null
	era_mgr = null
	_base_save_payload = {}
	_handoff_acknowledged = false
	_restored_from_continue = false
	_runtime_milestone_recorded = false
	_persisted_on_arrival = false
	_persistence_attempts = 0
	_persistence_failure_reason = ""
	_last_status_reason = reason
	_has_unsaved_progress = false
	_arrival_lock.unlock()
	continue_restore_failed.emit(reason)


func _reject_arrival(reason: String) -> void:
	_base_save_payload = {}
	_handoff_acknowledged = false
	_restored_from_continue = false
	_runtime_milestone_recorded = false
	_persisted_on_arrival = false
	_persistence_attempts = 0
	_persistence_failure_reason = ""
	_last_status_reason = reason
	_has_unsaved_progress = false
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
	if time_manager == null or not is_instance_valid(time_manager):
		return false
	return true


func is_handoff_acknowledged() -> bool:
	return _handoff_acknowledged


func is_restored_from_continue() -> bool:
	return _restored_from_continue


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
		"restored_from_continue": _restored_from_continue,
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


func _place_player_at_spawn() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.global_position = Vector2(PLAYER_SPAWN_X, PLAYER_SPAWN_Y)
	player.facing_direction = 1


func _build_resource_markers() -> void:
	if world_objects == null or not is_instance_valid(world_objects):
		return
	var container: Node2D = world_objects.get_node_or_null("ResourceMarkers") as Node2D
	if container == null:
		container = Node2D.new()
		container.name = "ResourceMarkers"
		world_objects.add_child(container)
	_node_markers.clear()
	for n: Dictionary in resource_mgr.nodes:
		var nid: String = String(n["id"])
		var marker := Node2D.new()
		marker.name = nid
		marker.position = Vector2(float(n["x"]), 0.0)
		var box := ColorRect.new()
		box.name = "Visual"
		box.offset_left = -14.0
		box.offset_top = -24.0
		box.offset_right = 14.0
		box.offset_bottom = 0.0
		var res_id: StringName = n["resource"] as StringName
		if res_id == &"wood":
			box.color = Color(0.55, 0.36, 0.2, 1.0)
		elif res_id == &"stone":
			box.color = Color(0.58, 0.62, 0.66, 1.0)
		else:
			box.color = Color(0.84, 0.68, 0.24, 1.0)
		marker.add_child(box)
		var lbl := Label.new()
		lbl.name = "Tag"
		lbl.text = String(n.get("prompt", "[E]"))
		lbl.position = Vector2(-64.0, -48.0)
		marker.add_child(lbl)
		container.add_child(marker)
		_node_markers[nid] = marker


func _refresh_camp_visuals() -> void:
	if camp_site_marker != null and is_instance_valid(camp_site_marker):
		camp_site_marker.visible = not _first_camp_built
	if camp_shelter_sprite != null and is_instance_valid(camp_shelter_sprite):
		camp_shelter_sprite.visible = _first_camp_built
	if camp_label != null and is_instance_valid(camp_label):
		if _first_camp_built:
			camp_label.text = "First Camp (Built)"
		else:
			camp_label.text = "Camp Site (%s)" % BuildingManager.format_cost_text(CAMP_BUILD_COST)


func _refresh_resource_markers() -> void:
	for nid: String in _node_markers.keys():
		var marker: Node2D = _node_markers[nid] as Node2D
		if marker != null and is_instance_valid(marker):
			marker.visible = not resource_mgr.is_collected(nid)


func _wire_clock_connections() -> void:
	if _clock_signals_connected or time_manager == null or not is_instance_valid(time_manager):
		return
	if not time_manager.daylight_started.is_connected(_on_daylight_started):
		time_manager.daylight_started.connect(_on_daylight_started)
	if not time_manager.sunset_started.is_connected(_on_sunset_started):
		time_manager.sunset_started.connect(_on_sunset_started)
	if not time_manager.night_started.is_connected(_on_night_started):
		time_manager.night_started.connect(_on_night_started)
	if not time_manager.sunrise_reached.is_connected(_on_sunrise_reached):
		time_manager.sunrise_reached.connect(_on_sunrise_reached)
	if not resource_mgr.renewable_nodes_refreshed.is_connected(_on_renewable_nodes_refreshed):
		resource_mgr.renewable_nodes_refreshed.connect(_on_renewable_nodes_refreshed)
	_clock_signals_connected = true


func _on_toggle_fast_clock() -> void:
	if time_manager == null or not is_instance_valid(time_manager):
		return
	time_manager.time_scale = FAST_CLOCK_SCALE if is_equal_approx(time_manager.time_scale, 1.0) else 1.0
	_set_feedback("Clock speed: %.0fx" % time_manager.time_scale)


func _on_daylight_started(_day_number: int) -> void:
	_apply_phase_visuals()
	_refresh_clock_hud()


func _on_sunset_started(_day_number: int) -> void:
	_apply_phase_visuals()
	_refresh_clock_hud()


func _on_night_started(_day_number: int) -> void:
	_apply_phase_visuals()
	_refresh_clock_hud()


func _on_renewable_nodes_refreshed(refreshed_ids: Array[String]) -> void:
	_last_sunrise_refreshed_ids = refreshed_ids.duplicate()


func _on_sunrise_reached(completed_day: int) -> void:
	if completed_day <= 0 or completed_day <= _last_sunrise_completed_day:
		return
	_last_sunrise_completed_day = completed_day
	_last_sunrise_refreshed_ids.clear()
	resource_mgr.refresh_renewable_nodes()
	_sunrise_renewal_count += 1
	_has_unsaved_progress = true
	_refresh_resource_markers()
	_apply_phase_visuals()
	_refresh_clock_hud()
	if not _last_sunrise_refreshed_ids.is_empty():
		_set_feedback("Day %d — Sunrise: clearing timber and stone replenished." % (completed_day + 1))
	sunrise_renewal_applied.emit(completed_day, _last_sunrise_refreshed_ids.duplicate())


func get_sunrise_renewal_count() -> int:
	return _sunrise_renewal_count


func get_last_sunrise_completed_day() -> int:
	return _last_sunrise_completed_day


func get_clock_status_text() -> String:
	if time_manager == null or not is_instance_valid(time_manager):
		return ""
	var secs: int = int(floorf(maxf(time_manager.phase_elapsed, 0.0)))
	var mins: int = secs / 60
	var rem: int = secs % 60
	return "Day %d — %s (%02d:%02d)" % [time_manager.current_day, time_manager.get_phase_name(), mins, rem]


func _refresh_clock_hud() -> void:
	if clock_label == null or not is_instance_valid(clock_label):
		return
	var txt: String = get_clock_status_text()
	if not txt.is_empty():
		clock_label.text = txt


func _apply_phase_visuals() -> void:
	if time_manager == null or not is_instance_valid(time_manager):
		return
	var sky_col: Color = SKY_COLOR_DAYLIGHT
	var mod_col: Color = MODULATE_DAYLIGHT
	match time_manager.current_phase:
		TimeManager.Phase.SUNSET:
			sky_col = SKY_COLOR_SUNSET
			mod_col = MODULATE_SUNSET
		TimeManager.Phase.NIGHT:
			sky_col = SKY_COLOR_NIGHT
			mod_col = MODULATE_NIGHT
	if sky_background != null and is_instance_valid(sky_background):
		sky_background.color = sky_col
	if day_night_modulate != null and is_instance_valid(day_night_modulate):
		day_night_modulate.color = mod_col


func _refresh_gameplay_hud() -> void:
	if resources_label != null:
		var b: Dictionary = ledger.get_all_balances()
		resources_label.text = "Gold: %d | Wood: %d | Stone: %d" % [int(b["gold"]), int(b["wood"]), int(b["stone"])]


func _set_feedback(text: String) -> void:
	if feedback_label != null:
		feedback_label.text = text
	feedback_message.emit(text)


func _record_rejection(reason: String) -> void:
	_last_rejection_reason = reason
	_set_feedback(reason)


func _show_arrival_presentation() -> void:
	if title_label != null:
		title_label.text = ARRIVAL_TITLE
	if subtitle_label != null:
		subtitle_label.text = ARRIVAL_SUBTITLE if _persisted_on_arrival else PERSIST_FAIL_SUBTITLE


func _show_restored_presentation() -> void:
	if title_label != null:
		title_label.text = ARRIVAL_TITLE
	if subtitle_label != null:
		subtitle_label.text = RESTORED_SUBTITLE


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
	payload["player"] = {
		"position_x": PLAYER_SPAWN_X,
		"facing_direction": 1,
	}

	var simulate_fail: bool = bool(ctx.get("_test_simulate_save_failure", false))
	var sm := SaveManager.new()
	var last_error: Array[String] = [""]
	sm.save_failed.connect(func(msg: String) -> void: last_error[0] = msg)

	var attempts: int = 0
	for _i: int in range(MAX_PERSIST_ATTEMPTS):
		attempts += 1
		if sm.save_state(payload, save_path, simulate_fail):
			_base_save_payload = payload.duplicate(true)
			return {"ok": true, "attempts": attempts, "reason": ""}

	var reason: String = last_error[0] if not last_error[0].is_empty() else "save_write_failed"
	return {"ok": false, "attempts": attempts, "reason": reason}
