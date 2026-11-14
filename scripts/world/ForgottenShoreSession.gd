class_name ForgottenShoreSession
extends Node2D

signal feedback_message(text: String)

enum ReignState {
	ACTIVE,
	BREACH_PENALTY,
	ISLAND_CLEARED,
}

const FARM_HARVEST_INTERVAL: float = 60.0
const FARM_GOLD_YIELD: int = 2

const RESOURCE_NODES: Array[Dictionary] = [
	{"id": "cache_gold_west", "resource": &"gold", "amount": 4, "x": -480.0, "renewable": false, "label": "Ancient Coin Chest (+4 Gold)"},
	{"id": "timber_pile_west", "resource": &"wood", "amount": 5, "x": -110.0, "renewable": true, "label": "Fallen Timber (+5 Wood)"},
	{"id": "stone_outcrop_east", "resource": &"stone", "amount": 3, "x": 190.0, "renewable": true, "label": "Ruined Masonry (+3 Stone)"},
	{"id": "shrine_cache_far_west", "resource": &"gold", "amount": 3, "x": -780.0, "renewable": false, "label": "Forgotten Shrine (+3 Gold)"},
]

var economy: EconomyLedger = EconomyLedger.new({"gold": 2, "wood": 2, "stone": 1})
var building_mgr: BuildingManager = BuildingManager.new()
var builder_npc: NPCBuilderAgent = NPCBuilderAgent.new()
var night_mgr: NightEncounterManager = NightEncounterManager.new()
var save_mgr: SaveManager = SaveManager.new()
var collected_node_ids: Dictionary = {}
var reign_state: ReignState = ReignState.ACTIVE
var _farm_timers: Dictionary = {}
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


var _active_resource_nodes: Array[Dictionary] = []


func _load_resource_nodes_from_data() -> void:
	_active_resource_nodes.clear()
	if FileAccess.file_exists("res://data/resource_nodes.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/resource_nodes.json"))
		if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("nodes"):
			for item: Variant in (parsed as Dictionary)["nodes"]:
				if typeof(item) != TYPE_DICTIONARY:
					continue
				var d: Dictionary = item as Dictionary
				_active_resource_nodes.append({
					"id": String(d["id"]),
					"resource": StringName(String(d["resource"])),
					"amount": int(d["amount"]),
					"x": float(d["x"]),
					"renewable": bool(d.get("renewable", false)),
					"label": String(d.get("label", "")),
					"prompt": String(d.get("prompt", "")),
				})
				var lbl: Label = get_node_or_null("WorldObjects/ResourceNodes/%s/Label" % String(d["id"])) as Label
				if lbl != null and d.has("prompt"):
					lbl.text = String(d["prompt"])
	if _active_resource_nodes.is_empty():
		_active_resource_nodes = RESOURCE_NODES.duplicate()


func _ready() -> void:
	_load_resource_nodes_from_data()
	building_mgr.register_forgotten_shore_expansion_plots()
	_wire_signals()
	_consume_pending_load_if_requested()
	_sync_all_presentations()
	feedback_message.emit("Forgotten Shore: [A/D] Move | [E] Interact | [R] Recruit (2G) | [B] Build/Upgrade | [F] Repair | [T] 20x | [K] Save")


func _process(delta: float) -> void:
	_anim_clock += delta
	var sim_delta: float = delta * (time_manager.time_scale if time_manager != null else 1.0)
	var is_night: bool = time_manager != null and time_manager.current_phase == TimeManager.Phase.NIGHT
	var is_daylight: bool = time_manager == null or time_manager.current_phase == TimeManager.Phase.DAYLIGHT
	builder_npc.tick(sim_delta, building_mgr)
	night_mgr.tick(sim_delta, is_night, building_mgr)
	_tick_farm_plots(sim_delta, is_daylight)
	_sync_dynamic_actors()


func _tick_farm_plots(sim_delta: float, is_daylight: bool) -> void:
	if not is_daylight or sim_delta <= 0.0:
		return
	for farm_id: String in [BuildingManager.FARM_WEST_ID, BuildingManager.FARM_EAST_ID]:
		if not building_mgr.has_plot(farm_id):
			continue
		var plot: Dictionary = building_mgr.get_plot(farm_id)
		if int(plot["state"]) != BuildingManager.WallState.COMPLETED:
			continue
		var t: float = float(_farm_timers.get(farm_id, 0.0)) + sim_delta
		while t >= FARM_HARVEST_INTERVAL:
			t -= FARM_HARVEST_INTERVAL
			if economy.try_add(&"gold", FARM_GOLD_YIELD):
				feedback_message.emit("Farm Harvest (%s): +%d Gold" % [farm_id, FARM_GOLD_YIELD])
		_farm_timers[farm_id] = t


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
	for node_def: Dictionary in _active_resource_nodes:
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

	if not builder_npc.recruited and absf(player_x - NPCBuilderAgent.CAMP_POSITION_X) <= 90.0:
		return _on_player_recruit(player_x)

	var near_plot: String = building_mgr.get_nearest_plot_id(player_x, BuildingManager.INTERACT_RANGE)
	if not near_plot.is_empty():
		var plot: Dictionary = building_mgr.get_plot(near_plot)
		var st: int = int(plot["state"])
		if st == BuildingManager.WallState.DAMAGED:
			return _on_player_repair_wall(player_x, near_plot)
		elif st == BuildingManager.WallState.PLACEHOLDER or st == BuildingManager.WallState.DESTROYED:
			return _on_player_build_wall(player_x, near_plot)
		elif building_mgr.can_upgrade_wall(player_x, near_plot):
			return _on_player_upgrade_wall(player_x, near_plot)

	_record_rejection("Nothing to collect or interact with at x=%.0f." % player_x)
	return false


func _on_player_recruit(player_x: float) -> bool:
	_last_rejection_reason = ""
	if builder_npc.request_recruit(player_x, economy):
		feedback_message.emit("Villager recruited as Builder! Will construct/repair structures and retreat at Sunset.")
		return true
	return false


func _on_player_build_wall(player_x: float, plot_id: String = "") -> bool:
	_last_rejection_reason = ""
	var target_id: String = plot_id
	if target_id.is_empty():
		target_id = building_mgr.get_nearest_plot_id(player_x, BuildingManager.INTERACT_RANGE)
	if target_id.is_empty():
		target_id = BuildingManager.WALL_ID
	if building_mgr.can_upgrade_wall(player_x, target_id):
		return _on_player_upgrade_wall(player_x, target_id)
	if building_mgr.request_start_construction(player_x, economy, target_id):
		feedback_message.emit("%s blueprint funded! Builder will construct it." % target_id)
		return true
	return false


func _on_player_upgrade_wall(player_x: float, plot_id: String = BuildingManager.WALL_ID) -> bool:
	_last_rejection_reason = ""
	if building_mgr.request_upgrade_wall(player_x, economy, plot_id):
		feedback_message.emit("Upgraded to Stone Wall Tier 2 (260 HP, 20 thorn dmg)!")
		return true
	return false


func _on_player_repair_wall(player_x: float, plot_id: String = "") -> bool:
	_last_rejection_reason = ""
	var target_id: String = plot_id
	if target_id.is_empty():
		target_id = building_mgr.get_nearest_plot_id(player_x, BuildingManager.INTERACT_RANGE)
	if target_id.is_empty():
		target_id = BuildingManager.WALL_ID
	if building_mgr.request_repair(player_x, economy, target_id):
		feedback_message.emit("Structure (%s) repaired to full durability!" % target_id)
		return true
	return false


func _on_manual_save() -> bool:
	_last_rejection_reason = ""
	if time_manager != null and time_manager.current_phase == TimeManager.Phase.NIGHT:
		_record_rejection("Manual save [K] is disabled during active Night combat")
		return false
	if save_game_state():
		feedback_message.emit("Kingdom state saved to user://save_slot_0.json")
		return true
	_record_rejection("Manual save failed")
	return false


func execute_command(command_id: StringName, actor_x: float, params: Dictionary = {}) -> bool:
	var plot_id: String = String(params.get("plot_id", ""))
	match command_id:
		&"interact":
			return _on_player_interact(actor_x)
		&"recruit":
			return _on_player_recruit(actor_x)
		&"build_wall":
			return _on_player_build_wall(actor_x, plot_id)
		&"upgrade_wall":
			return _on_player_upgrade_wall(actor_x, BuildingManager.WALL_ID if plot_id.is_empty() else plot_id)
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
	# Regenerate renewable Wood & Stone nodes on Day 2+
	if day_number > 1:
		_refresh_renewable_nodes()
	feedback_message.emit("Day %d Daylight — Wood & Stone nodes refreshed! Expand Farms, Watchtower & Stone Wall." % day_number)



func _refresh_renewable_nodes() -> void:
	for node_def: Dictionary in _active_resource_nodes:
		if bool(node_def.get("renewable", false)):
			collected_node_ids.erase(String(node_def["id"]))
	_update_resource_node_visuals()


func _on_sunset_started(_day_number: int) -> void:
	builder_npc.set_dusk_or_night_safety(true)
	feedback_message.emit("Sunset Warning — Builder is retreating to the Town Center safe zone!")


func _on_night_started(_day_number: int) -> void:
	builder_npc.set_dusk_or_night_safety(true)
	if not night_mgr.night_active:
		night_mgr.on_night_started()
	feedback_message.emit("Night has fallen! Greedling Raiders approach from the East Shore!")


func _on_sunrise_reached(completed_day: int) -> void:
	night_mgr.on_sunrise_reached(building_mgr)
	if night_mgr.settlement_breached:
		reign_state = ReignState.BREACH_PENALTY
		var cur_gold: int = economy.get_amount(&"gold")
		var penalty: int = cur_gold / 2
		if penalty > 0:
			economy.try_spend({"gold": penalty})
	elif completed_day >= 2:
		reign_state = ReignState.ISLAND_CLEARED
	else:
		reign_state = ReignState.ACTIVE
	_refresh_renewable_nodes()
	save_game_state()


func _on_night_resolved(survived: bool, wall_held: bool) -> void:
	if reign_state == ReignState.ISLAND_CLEARED:
		feedback_message.emit("Dawn of Day 3+! Forgotten Shore secured. State auto-saved!")
	elif survived and wall_held:
		feedback_message.emit("Sunrise reached! Your defenses held the line. Kingdom state auto-saved!")
	elif survived:
		feedback_message.emit("Sunrise reached! The wall fell, but dawn broke in time. Auto-saved!")
	else:
		feedback_message.emit("Raiders breached Town Center! Half your Gold was lost; rebuild before next dusk.")


func _get_plot_nodes(plot_id: String) -> Dictionary:
	match plot_id:
		BuildingManager.WALL_ID:
			return {"sprite": wall_visual, "label": wall_label, "title": "Wall Plot", "cost": "2G 4W 2S"}
		BuildingManager.WATCHTOWER_ID:
			return {
				"sprite": get_node_or_null("WorldObjects/WatchtowerPlot/WatchtowerVisual") as Sprite2D,
				"label": get_node_or_null("WorldObjects/WatchtowerPlot/WatchtowerLabel") as Label,
				"title": "Watchtower",
				"cost": "3G 3W 3S",
			}
		BuildingManager.FARM_WEST_ID:
			return {
				"sprite": get_node_or_null("WorldObjects/FarmWestPlot/FarmVisual") as Sprite2D,
				"label": get_node_or_null("WorldObjects/FarmWestPlot/FarmLabel") as Label,
				"title": "Farm Plot",
				"cost": "3G 4W",
			}
		BuildingManager.FARM_EAST_ID:
			return {
				"sprite": get_node_or_null("WorldObjects/FarmEastPlot/FarmVisual") as Sprite2D,
				"label": get_node_or_null("WorldObjects/FarmEastPlot/FarmLabel") as Label,
				"title": "Farm Plot",
				"cost": "3G 4W",
				}
	return {}


func _on_wall_state_changed(wall_id: String, new_state: String, progress: float, durability: int, max_dur: int) -> void:
	var nodes: Dictionary = _get_plot_nodes(wall_id)
	if nodes.is_empty():
		return
	var spr: Sprite2D = nodes["sprite"] as Sprite2D
	var lbl: Label = nodes["label"] as Label
	if spr == null or lbl == null:
		return
	var plot: Dictionary = building_mgr.get_plot(wall_id)
	var lvl: int = int(plot.get("level", 1))
	var title: String = String(nodes["title"])
	var cost_txt: String = String(nodes["cost"])
	match new_state:
		"PLACEHOLDER":
			spr.frame = 0
			spr.modulate = Color(1.0, 1.0, 1.0, 0.75)
			lbl.text = "%s [B]\n%s" % [title, cost_txt]
		"UNDER_CONSTRUCTION":
			spr.frame = 1
			spr.modulate = Color(1.0, 1.0, 1.0, 1.0)
			lbl.text = "Building %s...\n%d%%" % [title, int(roundf(progress * 100.0))]
		"COMPLETED":
			spr.frame = 2
			if wall_id == BuildingManager.WALL_ID and lvl >= 2:
				spr.modulate = Color(0.78, 0.86, 1.0, 1.0)
				lbl.text = "Stone Wall Lv.2\nHP %d/%d" % [durability, max_dur]
			elif wall_id == BuildingManager.WALL_ID:
				spr.modulate = Color(1.0, 1.0, 1.0, 1.0)
				lbl.text = "Wooden Wall [B: Stone Lv2]\nHP %d/%d (3G 2W 5S)" % [durability, max_dur]
			else:
				spr.modulate = Color(1.0, 1.0, 1.0, 1.0)
				lbl.text = "%s\nHP %d/%d" % [title, durability, max_dur]
		"DAMAGED":
			spr.frame = 3
			spr.modulate = Color(1.0, 0.85, 0.85, 1.0)
			lbl.text = "Damaged %s [F]\nHP %d/%d" % [title, durability, max_dur]
		"DESTROYED":
			spr.frame = 0
			spr.modulate = Color(0.75, 0.4, 0.4, 0.65)
			lbl.text = "Destroyed %s [B]\nRebuild: %s" % [title, cost_txt]


func _on_npc_state_changed(_npc_id: String, _role: String, state_name: String, pos_x: float) -> void:
	if npc_visual != null:
		npc_visual.position.x = pos_x
	if npc_label != null:
		if not builder_npc.recruited:
			npc_label.text = "Vagrant [R: 2G]"
		else:
			match state_name:
				"WORKING":
					npc_label.text = "Builder: Working"
				"RETURNING_TO_SAFETY":
					npc_label.text = "Retreating!"
				_:
					npc_label.text = ""
			npc_label.visible = not npc_label.text.is_empty()


func _update_proximity_prompts() -> void:
	if player == null:
		return
	var px: float = player.global_position.x

	var nodes_root: Node = get_node_or_null("WorldObjects/ResourceNodes")
	if nodes_root != null:
		for node_def: Dictionary in _active_resource_nodes:
			var node_id: String = String(node_def["id"])
			var lbl: Label = nodes_root.get_node_or_null(node_id + "/Label") as Label
			if lbl != null:
				var collected: bool = bool(collected_node_ids.get(node_id, false))
				lbl.visible = (not collected) and (absf(px - float(node_def["x"])) <= 80.0)

	if npc_label != null and not builder_npc.recruited:
		npc_label.visible = absf(px - builder_npc.position_x) <= 105.0

	for plot_id: String in [BuildingManager.WALL_ID, BuildingManager.WATCHTOWER_ID, BuildingManager.FARM_WEST_ID, BuildingManager.FARM_EAST_ID]:
		var nodes: Dictionary = _get_plot_nodes(plot_id)
		if nodes.is_empty():
			continue
		var lbl: Label = nodes["label"] as Label
		if lbl == null or not building_mgr.has_plot(plot_id):
			continue
		var plot: Dictionary = building_mgr.get_plot(plot_id)
		var st: int = int(plot["state"])
		var near: bool = absf(px - float(plot["position_x"])) <= 120.0
		lbl.visible = near or st == BuildingManager.WallState.UNDER_CONSTRUCTION or st == BuildingManager.WallState.DAMAGED


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

	_update_proximity_prompts()


func _update_resource_node_visuals() -> void:
	var nodes_root: Node = get_node_or_null("WorldObjects/ResourceNodes")
	if nodes_root == null:
		return
	for node_def: Dictionary in _active_resource_nodes:
		var node_id: String = String(node_def["id"])
		var marker: CanvasItem = nodes_root.get_node_or_null(node_id) as CanvasItem
		if marker != null:
			marker.modulate.a = 0.25 if collected_node_ids.get(node_id, false) else 1.0


func _sync_all_presentations() -> void:
	for plot_id: String in building_mgr.get_all_plot_ids():
		var p: Dictionary = building_mgr.get_plot(plot_id)
		_on_wall_state_changed(
			plot_id,
			building_mgr.get_state_name(plot_id),
			float(p["progress"]),
			int(p["durability"]),
			int(p["max_durability"])
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
	var player_x: float = snappedf(player.global_position.x, 0.1) if player != null else 0.0
	var player_facing: int = player.facing_direction if player != null else 1
	return {
		"schema_version": SaveManager.SCHEMA_VERSION,
		"world_id": "aetherion",
		"island_id": "forgotten_shore",
		"day_count": int(clock_dict["day_count"]),
		"world_time": float(clock_dict["world_time"]),
		"world_phase": String(clock_dict["world_phase"]),
		"player": {
			"position_x": player_x,
			"facing_direction": player_facing,
		},
		"resources": economy.get_all_balances(),
		"buildings": building_mgr.to_save_array(),
		"npcs": [builder_npc.to_save_dict()],
		"night_encounter": night_mgr.to_save_dict(),
		"progression_flags": {
			"first_night_survived": night_mgr.first_night_survived,
			"collected_nodes": collected_node_ids.keys(),
			"reign_state": int(reign_state),
		},
	}


func save_game_state(save_path: String = SaveManager.DEFAULT_SAVE_PATH) -> bool:
	return save_mgr.save_state(build_save_payload(), save_path)


func load_game_state(save_path: String = SaveManager.DEFAULT_SAVE_PATH) -> bool:
	var res: Dictionary = save_mgr.load_state(save_path)
	if not bool(res.get("ok", false)):
		return false
	var data: Dictionary = res["data"]

	if player != null and data.has("player") and typeof(data["player"]) == TYPE_DICTIONARY:
		var p_dict: Dictionary = data["player"]
		var saved_px: float = float(p_dict.get("position_x", 0.0))
		player.global_position.x = clampf(saved_px, player.min_bound_x, player.max_bound_x)
		player.facing_direction = 1 if int(p_dict.get("facing_direction", 1)) >= 0 else -1

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
	reign_state = int(flags.get("reign_state", ReignState.ACTIVE)) as ReignState
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
