class_name ForgottenShoreSession
extends Node2D

signal feedback_message(text: String)

const RESOURCE_NODES: Array[Dictionary] = [
	{"id": "cache_gold_west", "resource": &"gold", "amount": 4, "x": -480.0, "label": "Ancient Coin Chest (+4 Gold)"},
	{"id": "timber_pile_west", "resource": &"wood", "amount": 5, "x": -110.0, "label": "Fallen Timber (+5 Wood)"},
	{"id": "stone_outcrop_east", "resource": &"stone", "amount": 3, "x": 190.0, "label": "Ruined Masonry (+3 Stone)"},
	{"id": "shrine_cache_far_west", "resource": &"gold", "amount": 3, "x": -780.0, "label": "Forgotten Shrine (+3 Gold)"},
]

var economy: EconomyLedger = EconomyLedger.new({"gold": 2, "wood": 2, "stone": 1})
var building_mgr: BuildingManager = BuildingManager.new()
var builder_npc: NPCBuilderAgent = NPCBuilderAgent.new()
var night_mgr: NightEncounterManager = NightEncounterManager.new()
var save_mgr: SaveManager = SaveManager.new()
var collected_node_ids: Dictionary = {}
var _last_rejection_reason: String = ""
var _signals_wired: bool = false

@onready var time_manager: TimeManager = $TimeManager as TimeManager
@onready var player: PlayerController = $Player as PlayerController
@onready var wall_visual: Sprite2D = $WorldObjects/WoodenWallPlot/WallVisual as Sprite2D
@onready var town_center_sprite: Sprite2D = get_node_or_null("WorldObjects/TownCenterAnchor/TownCenterSprite") as Sprite2D
@onready var builder_sprite: Sprite2D = get_node_or_null("WorldObjects/BuilderActor/BuilderSprite") as Sprite2D
@onready var enemy_sprite: Sprite2D = get_node_or_null("WorldObjects/NightEnemyActor/EnemySprite") as Sprite2D
var _anim_clock: float = 0.0
var _prev_builder_x: float = NPCBuilderAgent.CAMP_POSITION_X
@onready var wall_label: Label = $WorldObjects/WoodenWallPlot/WallLabel as Label
@onready var npc_visual: Node2D = $WorldObjects/BuilderActor as Node2D
@onready var npc_label: Label = $WorldObjects/BuilderActor/NPCLabel as Label
@onready var enemy_visual: Node2D = $WorldObjects/NightEnemyActor as Node2D
@onready var slice_hud: CanvasLayer = $ClockHUD as CanvasLayer


func _ready() -> void:
	_wire_signals()
	_consume_pending_load_if_requested()
	_sync_all_presentations()
	feedback_message.emit("Forgotten Shore: [A/D] Move | [E] Collect/Interact | [R] Recruit (2G) | [B] Build Wall (2G,4W,2S) | [F] Repair | [T] 20x Clock | [K] Save")


func _process(delta: float) -> void:
	_anim_clock += delta
	var sim_delta: float = delta * (time_manager.time_scale if time_manager != null else 1.0)
	var is_night: bool = time_manager != null and time_manager.current_phase == TimeManager.Phase.NIGHT
	builder_npc.tick(sim_delta, building_mgr)
	night_mgr.tick(sim_delta, is_night, building_mgr)
	_sync_dynamic_actors()


func _wire_signals() -> void:
	if _signals_wired:
		return
	_signals_wired = true
	if time_manager != null:
		time_manager.daylight_started.connect(_on_daylight_started)
		time_manager.sunset_started.connect(_on_sunset_started)
		time_manager.night_started.connect(_on_night_started)
		time_manager.sunrise_reached.connect(_on_sunrise_reached)

	if player != null:
		player.interaction_requested.connect(func(px: float) -> void: _on_player_interact(px))
		player.recruit_requested.connect(func(px: float) -> void: _on_player_recruit(px))
		player.build_wall_requested.connect(func(px: float) -> void: _on_player_build_wall(px))
		player.repair_wall_requested.connect(func(px: float) -> void: _on_player_repair_wall(px))
		player.manual_save_requested.connect(func() -> void: _on_manual_save())
		player.fast_clock_toggled.connect(_on_toggle_fast_clock)

	economy.transaction_rejected.connect(_record_rejection)
	building_mgr.building_action_rejected.connect(_record_rejection)
	building_mgr.wall_state_changed.connect(_on_wall_state_changed)
	builder_npc.recruitment_rejected.connect(_record_rejection)
	builder_npc.npc_state_changed.connect(_on_npc_state_changed)
	night_mgr.night_encounter_resolved.connect(_on_night_resolved)

	if slice_hud != null and slice_hud.has_method("bind_session"):
		slice_hud.call("bind_session", self)


func _record_rejection(reason: String) -> void:
	_last_rejection_reason = reason
	feedback_message.emit(reason)


func _on_player_interact(player_x: float) -> bool:
	_last_rejection_reason = ""
	for node_def: Dictionary in RESOURCE_NODES:
		var node_id: String = String(node_def["id"])
		if collected_node_ids.get(node_id, false):
			continue
		var node_x: float = float(node_def["x"])
		if absf(player_x - node_x) <= 72.0:
			var res_id: StringName = node_def["resource"] as StringName
			var amount: int = int(node_def["amount"])
			if economy.try_add(res_id, amount):
				collected_node_ids[node_id] = true
				_update_resource_node_visuals()
				feedback_message.emit("Collected: %s" % String(node_def["label"]))
				return true
			return false

	# Contextual interaction fallback near Camp or Wall returns actual operation result
	if not builder_npc.recruited and absf(player_x - NPCBuilderAgent.CAMP_POSITION_X) <= 90.0:
		return _on_player_recruit(player_x)
	if absf(player_x - building_mgr.position_x) <= 90.0:
		if building_mgr.state == BuildingManager.WallState.DAMAGED:
			return _on_player_repair_wall(player_x)
		elif building_mgr.state == BuildingManager.WallState.PLACEHOLDER or building_mgr.state == BuildingManager.WallState.DESTROYED:
			return _on_player_build_wall(player_x)

	_record_rejection("Nothing to collect or interact with at x=%.0f." % player_x)
	return false


func _on_player_recruit(player_x: float) -> bool:
	_last_rejection_reason = ""
	if builder_npc.request_recruit(player_x, economy):
		feedback_message.emit("Villager recruited as Builder! Will construct/repair walls and retreat at Sunset.")
		return true
	return false


func _on_player_build_wall(player_x: float, plot_id: String = BuildingManager.WALL_ID) -> bool:
	_last_rejection_reason = ""
	if building_mgr.request_start_construction(player_x, economy, plot_id):
		feedback_message.emit("Wooden Wall blueprint funded! Builder will construct it.")
		return true
	return false


func _on_player_repair_wall(player_x: float, plot_id: String = BuildingManager.WALL_ID) -> bool:
	_last_rejection_reason = ""
	if building_mgr.request_repair(player_x, economy, plot_id):
		feedback_message.emit("Wooden Wall repaired to full durability!")
		return true
	return false


func _on_manual_save() -> bool:
	_last_rejection_reason = ""
	if save_game_state():
		feedback_message.emit("Kingdom state saved to user://save_slot_0.json")
		return true
	_record_rejection("Manual save failed")
	return false


func execute_command(command_id: StringName, actor_x: float, params: Dictionary = {}) -> bool:
	var plot_id: String = String(params.get("plot_id", BuildingManager.WALL_ID))
	match command_id:
		&"interact":
			return _on_player_interact(actor_x)
		&"recruit":
			return _on_player_recruit(actor_x)
		&"build_wall":
			return _on_player_build_wall(actor_x, plot_id)
		&"repair_wall":
			return _on_player_repair_wall(actor_x, plot_id)
		&"save_game":
			return _on_manual_save()
	_record_rejection("Unknown command: %s" % String(command_id))
	return false


func execute_command_detailed(command_id: StringName, actor_x: float, params: Dictionary = {}) -> Dictionary:
	var ok: bool = execute_command(command_id, actor_x, params)
	return {
		"ok": ok,
		"command": String(command_id),
		"reason": "" if ok else _last_rejection_reason,
	}


func _on_toggle_fast_clock() -> void:
	if time_manager == null:
		return
	time_manager.time_scale = 20.0 if is_equal_approx(time_manager.time_scale, 1.0) else 1.0
	feedback_message.emit("Clock speed set to %.0fx" % time_manager.time_scale)


func _on_daylight_started(day_number: int) -> void:
	builder_npc.set_dusk_or_night_safety(false)
	feedback_message.emit("Day %d Daylight — Explore, gather resources, recruit Builder, and prepare the East Wall." % day_number)


func _on_sunset_started(_day_number: int) -> void:
	builder_npc.set_dusk_or_night_safety(true)
	feedback_message.emit("Sunset Warning — Builder is retreating to the Town Center safe zone!")


func _on_night_started(_day_number: int) -> void:
	builder_npc.set_dusk_or_night_safety(true)
	if not night_mgr.night_active:
		night_mgr.on_night_started()
	feedback_message.emit("Night has fallen! Greedling Raiders approach from the East Shore!")


func _on_sunrise_reached(_completed_day: int) -> void:
	night_mgr.on_sunrise_reached(building_mgr)
	save_game_state()


func _on_night_resolved(survived: bool, wall_held: bool) -> void:
	if survived and wall_held:
		feedback_message.emit("Sunrise reached! Your Wooden Wall held the line. Kingdom state auto-saved!")
	elif survived:
		feedback_message.emit("Sunrise reached! The wall fell, but dawn broke in time. Auto-saved!")
	else:
		feedback_message.emit("Raiders breached the Town Center during the night! Rebuild and reinforce before next dusk.")


func _on_wall_state_changed(wall_id: String, new_state: String, progress: float, durability: int, max_dur: int) -> void:
	if wall_id != BuildingManager.WALL_ID or wall_visual == null or wall_label == null:
		return
	match new_state:
		"PLACEHOLDER":
			wall_visual.frame = 0
			wall_visual.modulate = Color(1.0, 1.0, 1.0, 0.75)
			wall_label.text = "Wall Plot [B]\n2G 4W 2S"
		"UNDER_CONSTRUCTION":
			wall_visual.frame = 1
			wall_visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
			wall_label.text = "Building Wall...\n%d%%" % int(roundf(progress * 100.0))
		"COMPLETED":
			wall_visual.frame = 2
			wall_visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
			wall_label.text = "Wooden Wall\nHP %d/%d" % [durability, max_dur]
		"DAMAGED":
			wall_visual.frame = 3
			wall_visual.modulate = Color(1.0, 0.85, 0.85, 1.0)
			wall_label.text = "Damaged Wall [F]\nHP %d/%d" % [durability, max_dur]
		"DESTROYED":
			wall_visual.frame = 0
			wall_visual.modulate = Color(0.75, 0.4, 0.4, 0.65)
			wall_label.text = "Destroyed Wall [B]\nRebuild: 2G 4W 2S"


func _on_npc_state_changed(_npc_id: String, _role: String, state_name: String, pos_x: float) -> void:
	if npc_visual != null:
		npc_visual.position.x = pos_x
	if npc_label != null:
		npc_label.text = "Vagrant [R: 2G]" if not builder_npc.recruited else "Builder (%s)" % state_name


func _sync_dynamic_actors() -> void:
	if town_center_sprite != null:
		town_center_sprite.frame = int(floorf(_anim_clock * 6.0)) % 4

	if npc_visual != null:
		npc_visual.position.x = builder_npc.position_x
		if builder_sprite != null:
			var dx: float = builder_npc.position_x - _prev_builder_x
			if absf(dx) > 0.05:
				builder_sprite.flip_h = dx < 0.0
			_prev_builder_x = builder_npc.position_x
			if builder_npc.state == NPCBuilderAgent.State.WORKING:
				builder_sprite.frame = 4 + (int(floorf(_anim_clock * 8.0)) % 4)
			elif builder_npc.state == NPCBuilderAgent.State.MOVING_TO_TASK or builder_npc.state == NPCBuilderAgent.State.RETURNING_TO_SAFETY:
				builder_sprite.frame = int(floorf(_anim_clock * 8.0)) % 4
			else:
				builder_sprite.frame = 0

	if enemy_visual != null:
		enemy_visual.visible = night_mgr.enemy_active
		enemy_visual.position.x = night_mgr.enemy_x
		if enemy_sprite != null and night_mgr.enemy_active:
			enemy_sprite.frame = int(floorf(_anim_clock * 8.0)) % 4


func _update_resource_node_visuals() -> void:
	var nodes_root: Node = get_node_or_null("WorldObjects/ResourceNodes")
	if nodes_root == null:
		return
	for node_def: Dictionary in RESOURCE_NODES:
		var node_id: String = String(node_def["id"])
		var marker: CanvasItem = nodes_root.get_node_or_null(node_id) as CanvasItem
		if marker != null:
			marker.modulate.a = 0.25 if collected_node_ids.get(node_id, false) else 1.0


func _sync_all_presentations() -> void:
	_on_wall_state_changed(
		BuildingManager.WALL_ID,
		building_mgr.get_state_name(),
		building_mgr.construction_progress,
		building_mgr.durability,
		building_mgr.max_durability
	)
	_on_npc_state_changed(
		NPCBuilderAgent.NPC_ID,
		builder_npc.role,
		builder_npc.get_state_name(),
		builder_npc.position_x
	)
	_update_resource_node_visuals()
	_sync_dynamic_actors()


func build_save_payload() -> Dictionary:
	var clock_dict: Dictionary = time_manager.to_save_dict() if time_manager != null else {
		"day_count": 1,
		"world_time": 0.0,
		"world_phase": "daylight",
	}
	return {
		"schema_version": SaveManager.SCHEMA_VERSION,
		"world_id": "aetherion",
		"island_id": "forgotten_shore",
		"day_count": int(clock_dict["day_count"]),
		"world_time": float(clock_dict["world_time"]),
		"world_phase": String(clock_dict["world_phase"]),
		"resources": economy.get_all_balances(),
		"buildings": building_mgr.to_save_array(),
		"npcs": [builder_npc.to_save_dict()],
		"night_encounter": night_mgr.to_save_dict(),
		"progression_flags": {
			"first_night_survived": night_mgr.first_night_survived,
			"collected_nodes": collected_node_ids.keys(),
		},
	}


func save_game_state(save_path: String = SaveManager.DEFAULT_SAVE_PATH) -> bool:
	return save_mgr.save_state(build_save_payload(), save_path)


func load_game_state(save_path: String = SaveManager.DEFAULT_SAVE_PATH) -> bool:
	var res: Dictionary = save_mgr.load_state(save_path)
	if not bool(res.get("ok", false)):
		return false
	var data: Dictionary = res["data"]

	# Restore NightEncounterManager BEFORE TimeManager emits night_started so mid-night state is not overwritten
	if data.has("night_encounter") and typeof(data["night_encounter"]) == TYPE_DICTIONARY:
		night_mgr.apply_save_dict(data["night_encounter"])

	if time_manager != null:
		time_manager.apply_save_dict(data)
	economy.set_balances_from_dict(data["resources"])

	var b_arr: Array = data["buildings"]
	building_mgr.apply_save_array(b_arr)

	var n_arr: Array = data["npcs"]
	if not n_arr.is_empty() and typeof(n_arr[0]) == TYPE_DICTIONARY:
		builder_npc.apply_save_dict(n_arr[0])

	var flags: Dictionary = data["progression_flags"]
	night_mgr.first_night_survived = bool(flags.get("first_night_survived", night_mgr.first_night_survived))
	collected_node_ids.clear()
	var saved_nodes: Variant = flags.get("collected_nodes", [])
	if typeof(saved_nodes) == TYPE_ARRAY:
		for item: Variant in saved_nodes:
			collected_node_ids[String(item)] = true

	if time_manager != null:
		var is_unsafe: bool = time_manager.current_phase != TimeManager.Phase.DAYLIGHT
		builder_npc.set_dusk_or_night_safety(is_unsafe)

	_sync_all_presentations()
	return true


func _consume_pending_load_if_requested() -> void:
	if Engine.has_meta("crownfall_load_on_start") and bool(Engine.get_meta("crownfall_load_on_start")):
		Engine.set_meta("crownfall_load_on_start", false)
		if load_game_state():
			feedback_message.emit("Loaded saved kingdom state from user://save_slot_0.json")
