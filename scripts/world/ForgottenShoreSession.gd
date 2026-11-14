class_name ForgottenShoreSession
extends Node2D

signal feedback_message(text: String)
signal load_failed(reason: String)

enum ReignState {
	ACTIVE,
	BREACH_PENALTY,
	ISLAND_CLEARED,
}

const FARM_HARVEST_INTERVAL: float = 60.0
const FARM_GOLD_YIELD: int = 2
const SHIPWRECK_X: float = -1350.0
const PORTAL_X: float = 1350.0
const SHIPWRECK_COSTS: Array[Dictionary] = [
	{"gold": 2, "wood": 3, "stone": 1},
	{"gold": 2, "wood": 3, "stone": 2},
	{"gold": 2, "wood": 2, "stone": 1},
]

var economy: EconomyLedger = EconomyLedger.new({"gold": 2, "wood": 2, "stone": 1})
var building_mgr: BuildingManager = BuildingManager.new()
var resource_mgr: ResourceNodeManager = ResourceNodeManager.new()
var hearth_sys: HearthSystem = HearthSystem.new()
var pop_mgr: NPCPopulationManager = NPCPopulationManager.new()
var builder_npc: NPCBuilderAgent = null
var night_mgr: NightEncounterManager = NightEncounterManager.new()
var save_mgr: SaveManager = SaveManager.new()

# Backward-compatible mirror for tests inspecting collected_node_ids directly
var collected_node_ids: Dictionary:
	get:
		return resource_mgr.node_states

var hearth_level: int:
	get:
		return hearth_sys.hearth_level
	set(val):
		hearth_sys.apply_save_level(val)

var reign_state: ReignState = ReignState.ACTIVE
var shipwreck_stage: int = 0
var portal_relic_looted: bool = false
var shrine_offering_used_today: bool = false
var flare_active_timer: float = 0.0
var flare_cooldown_timer: float = 0.0
var _actor_positions: Dictionary = {"player_1": 0.0}
var _follower_sprites: Dictionary = {}
var _farm_timers: Dictionary = {}
var _sfx_cache: Dictionary = {}
var _prev_wall_hp: int = 0
var _prev_enemy_hp: int = 0
var _stagger_cooldown: float = 0.0
var _last_rejection_reason: String = ""
var _signals_wired: bool = false
var _anim_clock: float = 0.0
var _prev_builder_x: float = NPCBuilderAgent.CAMP_POSITION_X
var _active_target: Dictionary = {}

@onready var time_manager: TimeManager = $TimeManager as TimeManager
@onready var player: PlayerController = $Player as PlayerController
@onready var wall_visual: Sprite2D = $WorldObjects/WoodenWallPlot/WallVisual as Sprite2D
@onready var town_center_sprite: Sprite2D = get_node_or_null("WorldObjects/TownCenterAnchor/TownCenterSprite") as Sprite2D
@onready var builder_sprite: Sprite2D = get_node_or_null("WorldObjects/BuilderActor/BuilderSprite") as Sprite2D
@onready var enemy_sprite: Sprite2D = get_node_or_null("WorldObjects/NightEnemyActor/EnemySprite") as Sprite2D
@onready var wall_label: Label = $WorldObjects/WoodenWallPlot/WallLabel as Label
@onready var npc_visual: Node2D = $WorldObjects/BuilderActor as Node2D
@onready var npc_label: Label = $WorldObjects/BuilderActor/NPCLabel as Label
@onready var enemy_visual: Node2D = $WorldObjects/NightEnemyActor as Node2D
@onready var slice_hud: CanvasLayer = $ClockHUD as CanvasLayer
@onready var sfx_player: AudioStreamPlayer = get_node_or_null("SFXPlayer") as AudioStreamPlayer


func _init() -> void:
	builder_npc = pop_mgr.get_primary_agent()


func _ready() -> void:
	building_mgr.register_forgotten_shore_expansion_plots()
	_sync_resource_prompts_from_data()
	_wire_signals()
	_consume_pending_load_if_requested()
	_sync_all_presentations()
	feedback_message.emit("Forgotten Shore: [A/D] Move | [E] Interact | [Q] Upgrade | [R] Recruit | [B] Build | [F] Repair | [T] 20x | [K] Save")


func _sync_resource_prompts_from_data() -> void:
	for n: Dictionary in resource_mgr.nodes:
		var lbl: Label = get_node_or_null("WorldObjects/ResourceNodes/%s/Label" % String(n["id"])) as Label
		if lbl != null and n.has("prompt"):
			lbl.text = String(n["prompt"])


func set_actor_position(actor_id: String, pos_x: float) -> void:
	_actor_positions[actor_id] = pos_x


func get_actor_position(actor_id: String) -> float:
	if actor_id == "player_1" and player != null:
		_actor_positions["player_1"] = player.global_position.x
	return float(_actor_positions.get(actor_id, 0.0))


func _process(delta: float) -> void:
	_anim_clock += delta
	if player != null:
		_actor_positions["player_1"] = player.global_position.x
	var sim_delta: float = delta * (time_manager.time_scale if time_manager != null else 1.0)
	var is_night: bool = time_manager != null and time_manager.current_phase == TimeManager.Phase.NIGHT
	var is_daylight: bool = time_manager == null or time_manager.current_phase == TimeManager.Phase.DAYLIGHT
	pop_mgr.tick_all(sim_delta, building_mgr, night_mgr)
	flare_active_timer = maxf(0.0, flare_active_timer - sim_delta)
	flare_cooldown_timer = maxf(0.0, flare_cooldown_timer - sim_delta)
	night_mgr.tick(sim_delta, is_night, building_mgr, hearth_sys.hearth_level, flare_active_timer > 0.0)
	_tick_monarch_light_risk(sim_delta, is_night)
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
		player.interaction_requested.connect(func(px: float) -> void:
			set_actor_position("player_1", px)
			_on_player_interact(px)
		)
		player.upgrade_tier_requested.connect(func(px: float) -> void:
			set_actor_position("player_1", px)
			_on_player_upgrade_tier(px)
		)
		player.recruit_requested.connect(func(px: float) -> void:
			set_actor_position("player_1", px)
			execute_world_command("player_1", &"recruit", "vagrant_camp")
		)
		player.build_wall_requested.connect(func(px: float) -> void:
			set_actor_position("player_1", px)
			_on_player_build_wall(px)
		)
		player.repair_wall_requested.connect(func(px: float) -> void:
			set_actor_position("player_1", px)
			_on_player_repair_wall(px)
		)
		player.manual_save_requested.connect(func() -> void: execute_world_command("player_1", &"save_game", ""))
		player.fast_clock_toggled.connect(_on_toggle_fast_clock)
		player.kindle_flare_requested.connect(func() -> void: execute_world_command("player_1", &"kindle_flare", ""))

	economy.transaction_rejected.connect(_record_rejection)
	building_mgr.building_action_rejected.connect(_record_rejection)
	building_mgr.wall_state_changed.connect(_on_wall_state_changed)
	builder_npc.recruitment_rejected.connect(_record_rejection)
	builder_npc.npc_state_changed.connect(_on_npc_state_changed)
	pop_mgr.population_action_rejected.connect(_record_rejection)
	pop_mgr.roster_changed.connect(_sync_follower_nodes)
	night_mgr.night_encounter_resolved.connect(_on_night_resolved)
	night_mgr.enemy_defeated.connect(_on_enemy_defeated)

	if slice_hud != null and slice_hud.has_method("bind_session"):
		slice_hud.call("bind_session", self)


func _play_sfx(sfx_name: String) -> void:
	if sfx_player == null:
		return
	if not _sfx_cache.has(sfx_name):
		var path: String = "res://assets/audio/%s.wav" % sfx_name
		_sfx_cache[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _sfx_cache.get(sfx_name, null) as AudioStream
	if stream != null:
		sfx_player.pitch_scale = randf_range(0.92, 1.08)
		sfx_player.stream = stream
		sfx_player.play()


func _spawn_floating_text(world_x: float, text: String, col: Color = Color(1.0, 0.92, 0.45, 1.0)) -> void:
	if not is_inside_tree():
		return
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.modulate = col
	lbl.position = Vector2(world_x - 32.0, -48.0)
	add_child(lbl)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", -78.0, 0.85)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.85)
	tw.chain().tween_callback(lbl.queue_free)



func _trigger_camera_shake(intensity: float = 4.0, duration: float = 0.14) -> void:
	if player == null or not is_inside_tree():
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(cam, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), duration * 0.5)
	tw.tween_property(cam, "offset", Vector2.ZERO, duration * 0.5)


func _flash_sprite(spr: CanvasItem, flash_col: Color = Color(2.0, 1.2, 1.2, 1.0), restore_col: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	if spr == null or not is_inside_tree():
		return
	if spr.material is ShaderMaterial:
		var smat: ShaderMaterial = spr.material as ShaderMaterial
		smat.set_shader_parameter("flash_amount", 1.0)
		var tw_s: Tween = create_tween()
		tw_s.tween_method(func(v: float) -> void: smat.set_shader_parameter("flash_amount", v), 1.0, 0.0, 0.14)
		return
	spr.modulate = flash_col
	var tw: Tween = create_tween()
	tw.tween_property(spr, "modulate", restore_col, 0.12)


func _record_rejection(reason: String) -> void:
	_last_rejection_reason = reason
	feedback_message.emit(reason)


func _resolve_target_for_actor(actor_x: float) -> Dictionary:
	return InteractionResolver.resolve_nearest(
		actor_x,
		resource_mgr,
		building_mgr,
		pop_mgr,
		hearth_sys,
		shipwreck_stage,
		SHIPWRECK_X,
		PORTAL_X,
		portal_relic_looted,
		shrine_offering_used_today
	)


func execute_world_command(actor_id: String, command: StringName, target_id: String = "") -> Dictionary:
	_last_rejection_reason = ""
	var actor_x: float = get_actor_position(actor_id)
	var ok: bool = false
	var resolved_target: String = target_id

	match command:
		&"collect":
			if resolved_target.is_empty():
				var n: Dictionary = resource_mgr.find_nearest_available(actor_x)
				resolved_target = String(n.get("id", ""))
			var res: Dictionary = resource_mgr.try_collect(resolved_target, actor_x, economy)
			ok = bool(res.get("ok", false))
			if ok:
				var nd: Dictionary = res["node"] as Dictionary
				_update_resource_node_visuals()
				_play_sfx("sfx_coin")
				_spawn_floating_text(float(nd["x"]), "+%d %s" % [int(nd["amount"]), String(nd["resource"]).capitalize()])
				feedback_message.emit("Collected: %s" % String(nd["label"]))
			else:
				_record_rejection(String(res.get("reason", "Collection failed")))

		&"assign_tool":
			if resolved_target.is_empty():
				resolved_target = pop_mgr.get_nearest_tool_stand(actor_x)
			var assigned: NPCBuilderAgent = pop_mgr.assign_tool_stand(resolved_target, economy, building_mgr)
			ok = (assigned != null)
			if ok:
				_wire_follower_signals(assigned)
				feedback_message.emit("%s assigned as %s!" % [assigned.npc_id, assigned.role.capitalize()])

		&"recruit":
			var agent: NPCBuilderAgent = pop_mgr.recruit_next_vagrant(actor_x, economy)
			ok = (agent != null)
			if ok:
				resolved_target = agent.npc_id
				_wire_follower_signals(agent)
				feedback_message.emit("Recruited %s (%s)! Total NPCs: %d" % [agent.npc_id, agent.role.capitalize(), pop_mgr.get_recruited_count()])

		&"build":
			if resolved_target.is_empty():
				resolved_target = building_mgr.get_nearest_plot_id(actor_x, BuildingManager.INTERACT_RANGE)
			if resolved_target.is_empty():
				resolved_target = BuildingManager.WALL_ID
			ok = building_mgr.request_start_construction(actor_x, economy, resolved_target)
			if ok:
				_play_sfx("sfx_build")
				feedback_message.emit("%s blueprint funded! Builder will construct it." % resolved_target)

		&"repair":
			if resolved_target.is_empty():
				resolved_target = building_mgr.get_nearest_plot_id(actor_x, BuildingManager.INTERACT_RANGE)
			if resolved_target.is_empty():
				resolved_target = BuildingManager.WALL_ID
			var extra_repair_cost: Dictionary = {"wood": 1} if (time_manager != null and time_manager.current_phase == TimeManager.Phase.NIGHT) else {}
			ok = building_mgr.request_repair(actor_x, economy, resolved_target, extra_repair_cost)
			if ok:
				_play_sfx("sfx_build")
				feedback_message.emit("Structure (%s) repaired to full durability!" % resolved_target)

		&"upgrade_building":
			if resolved_target.is_empty():
				resolved_target = building_mgr.get_nearest_plot_id(actor_x, BuildingManager.INTERACT_RANGE)
			if resolved_target.is_empty():
				resolved_target = BuildingManager.WALL_ID
			ok = building_mgr.request_upgrade_wall(actor_x, economy, resolved_target)
			if ok:
				_play_sfx("sfx_build")
				feedback_message.emit("Upgraded to Stone Wall Tier 2 (260 HP, 20 thorn dmg)!")

		&"upgrade_hearth":
			var hres: Dictionary = hearth_sys.try_upgrade(actor_x, economy)
			ok = bool(hres.get("ok", false))
			if ok:
				_sync_hearth_visuals()
				_play_sfx("sfx_build")
				_spawn_floating_text(0.0, "Hearth Lv.%d!" % hearth_sys.hearth_level, Color(1.0, 0.78, 0.35, 1.0))
				feedback_message.emit("Hearth upgraded to Lv.%d (Light radius: %.0f px)!" % [hearth_sys.hearth_level, hearth_sys.get_radius_px()])
			else:
				_record_rejection(String(hres.get("reason", "Hearth upgrade failed")))

		&"shipwreck":
			ok = _on_player_interact_shipwreck(actor_x)

		&"loot_portal":
			if absf(actor_x - PORTAL_X) <= 96.0:
				ok = _on_player_loot_portal_relic()
			else:
				_record_rejection("Move closer to Greed Portal (x=1350)")

		&"shrine_offering":
			if absf(actor_x - (-780.0)) > ResourceNodeManager.INTERACT_RANGE:
				_record_rejection("Move closer to Forgotten Shrine (x=-780)")
			elif shrine_offering_used_today:
				_record_rejection("Shrine Offering already used today")
			elif not economy.try_spend({"wood": 4, "stone": 2}):
				_record_rejection("Shrine Offering needs 4 Wood, 2 Stone")
			else:
				economy.try_add(&"gold", 2)
				shrine_offering_used_today = true
				ok = true
				_play_sfx("sfx_coin")
				_spawn_floating_text(-780.0, "+2G Offering")
				feedback_message.emit("Shrine Offering accepted: 4W + 2S -> +2 Gold!")

		&"kindle_flare":
			if time_manager == null or time_manager.current_phase != TimeManager.Phase.NIGHT:
				_record_rejection("Kindle Flare [Space] can only be used at Night")
			elif flare_cooldown_timer > 0.0:
				_record_rejection("Kindle Flare on cooldown (%.0fs)" % flare_cooldown_timer)
			elif not economy.try_spend({"wood": 1}):
				_record_rejection("Kindle Flare needs 1 Wood")
			else:
				flare_active_timer = 8.0
				flare_cooldown_timer = 25.0
				ok = true
				_play_sfx("sfx_sunset")
				_spawn_floating_text(actor_x, "KINDLE FLARE +50%!", Color(1.0, 0.82, 0.35, 1.0))
				feedback_message.emit("Kindle Flare active! Hearth burn & Watchtower dmg +50% for 8s!")

		&"save_game":
			ok = _on_manual_save()

		_:
			_record_rejection("Unknown world command: %s" % String(command))

	return {
		"ok": ok,
		"actor_id": actor_id,
		"command": String(command),
		"target_id": resolved_target,
		"reason": "" if ok else _last_rejection_reason,
	}


func _on_player_interact(player_x: float) -> bool:
	var tgt: Dictionary = _resolve_target_for_actor(player_x)
	if not bool(tgt.get("has_target", false)):
		_record_rejection("Nothing to collect or interact with at x=%.0f." % player_x)
		return false
	var p_cmd: StringName = tgt["primary_command"] as StringName
	if String(p_cmd).is_empty():
		if not String(tgt["upgrade_command"]).is_empty():
			_record_rejection("Press [Q] to upgrade %s" % String(tgt["target_id"]))
		else:
			_record_rejection("No action available for %s" % String(tgt["target_id"]))
		return false
	var res: Dictionary = execute_world_command("player_1", p_cmd, String(tgt["target_id"]))
	return bool(res.get("ok", false))


func _on_player_upgrade_tier(player_x: float) -> bool:
	var tgt: Dictionary = _resolve_target_for_actor(player_x)
	if bool(tgt.get("has_target", false)) and not String(tgt["upgrade_command"]).is_empty():
		var res: Dictionary = execute_world_command("player_1", tgt["upgrade_command"] as StringName, String(tgt["target_id"]))
		return bool(res.get("ok", false))
	if absf(player_x) <= HearthSystem.INTERACT_RANGE and hearth_sys.can_upgrade():
		var hres: Dictionary = execute_world_command("player_1", &"upgrade_hearth", "town_hearth")
		return bool(hres.get("ok", false))
	_record_rejection("Nothing to upgrade near x=%.0f." % player_x)
	return false


func _on_player_build_wall(player_x: float, plot_id: String = "") -> bool:
	var target_id: String = plot_id
	if target_id.is_empty():
		target_id = building_mgr.get_nearest_plot_id(player_x, BuildingManager.INTERACT_RANGE)
	if target_id.is_empty():
		target_id = BuildingManager.WALL_ID
	if building_mgr.can_upgrade_wall(player_x, target_id):
		return bool(execute_world_command("player_1", &"upgrade_building", target_id).get("ok", false))
	return bool(execute_world_command("player_1", &"build", target_id).get("ok", false))


func _on_player_repair_wall(player_x: float, plot_id: String = "") -> bool:
	var target_id: String = plot_id
	if target_id.is_empty():
		target_id = building_mgr.get_nearest_plot_id(player_x, BuildingManager.INTERACT_RANGE)
	if target_id.is_empty():
		target_id = BuildingManager.WALL_ID
	return bool(execute_world_command("player_1", &"repair", target_id).get("ok", false))


func execute_command(command_id: StringName, actor_x: float, params: Dictionary = {}) -> bool:
	set_actor_position("local", actor_x)
	var plot_id: String = String(params.get("plot_id", ""))
	match command_id:
		&"interact":
			var tgt: Dictionary = _resolve_target_for_actor(actor_x)
			if not bool(tgt.get("has_target", false)):
				_record_rejection("Nothing to collect or interact with at x=%.0f." % actor_x)
				return false
			var p_cmd: StringName = tgt["primary_command"] as StringName
			if String(p_cmd).is_empty():
				return false
			return bool(execute_world_command("local", p_cmd, String(tgt["target_id"])).get("ok", false))
		&"recruit":
			return bool(execute_world_command("local", &"recruit", "vagrant_camp").get("ok", false))
		&"build_wall":
			var pid_b: String = BuildingManager.WALL_ID if plot_id.is_empty() else plot_id
			return bool(execute_world_command("local", &"build", pid_b).get("ok", false))
		&"upgrade_wall":
			var pid_u: String = BuildingManager.WALL_ID if plot_id.is_empty() else plot_id
			return bool(execute_world_command("local", &"upgrade_building", pid_u).get("ok", false))
		&"repair_wall":
			var pid_r: String = BuildingManager.WALL_ID if plot_id.is_empty() else plot_id
			return bool(execute_world_command("local", &"repair", pid_r).get("ok", false))
		_:
			return bool(execute_world_command("local", command_id, plot_id).get("ok", false))


func execute_command_detailed(command_id: StringName, actor_x: float, params: Dictionary = {}) -> Dictionary:
	var ok: bool = execute_command(command_id, actor_x, params)
	return {
		"ok": ok,
		"command": String(command_id),
		"reason": "" if ok else _last_rejection_reason,
	}


func _on_player_interact_shipwreck(player_x: float) -> bool:
	if absf(player_x - SHIPWRECK_X) > 96.0:
		_record_rejection("Move closer to the Shipwreck (x=-1350)")
		return false
	if shipwreck_stage >= 3:
		reign_state = ReignState.ISLAND_CLEARED
		save_game_state()
		_play_sfx("sfx_coin")
		feedback_message.emit("Ship repaired! Setting sail from Forgotten Shore toward Eldergrove Forest!")
		return true
	var cost: Dictionary = SHIPWRECK_COSTS[shipwreck_stage]
	if not economy.try_spend(cost):
		_record_rejection("Shipwreck Stage %d/3 needs %dG %dW %dS" % [shipwreck_stage + 1, int(cost["gold"]), int(cost["wood"]), int(cost["stone"])])
		return false
	shipwreck_stage += 1
	_sync_landmark_visuals()
	_play_sfx("sfx_build")
	_spawn_floating_text(SHIPWRECK_X, "Ship Stage %d/3" % shipwreck_stage)
	feedback_message.emit("Shipwreck repaired to Stage %d/3!" % shipwreck_stage)
	return true


func _on_player_loot_portal_relic() -> bool:
	if portal_relic_looted:
		_record_rejection("Portal Relic already scavenged")
		return false
	if economy.try_add_bundle({"gold": 3, "stone": 2}):
		portal_relic_looted = true
		_sync_landmark_visuals()
		_play_sfx("sfx_coin")
		_spawn_floating_text(PORTAL_X, "+3G +2S Relic")
		feedback_message.emit("Scavenged Ancient Relic near Greed Portal (+3 Gold, +2 Stone)!")
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


func _wire_follower_signals(agent: NPCBuilderAgent) -> void:
	if agent == null:
		return
	if not agent.farm_gold_earned.is_connected(_on_farmer_gold_earned):
		agent.farm_gold_earned.connect(_on_farmer_gold_earned)
	if not agent.archer_volley_fired.is_connected(_on_archer_volley_fired):
		agent.archer_volley_fired.connect(_on_archer_volley_fired)


func _on_farmer_gold_earned(npc_id: String, amount: int) -> void:
	if economy.try_add(&"gold", amount):
		_play_sfx("sfx_coin")
		_spawn_floating_text(player.global_position.x if player != null else 0.0, "+%d Gold" % amount)
		feedback_message.emit("Farmer %s harvested +%d Gold!" % [npc_id, amount])


func _on_archer_volley_fired(_npc_id: String, damage: int, from_tower: bool) -> void:
	_play_sfx("sfx_bow")
	_spawn_floating_text(night_mgr.enemy_x, "-%d" % damage, Color(1.0, 0.45, 0.45, 1.0))
	feedback_message.emit("Archer volley (%d dmg%s)!" % [damage, " from Watchtower" if from_tower else ""])


func _on_toggle_fast_clock() -> void:
	if time_manager == null:
		return
	time_manager.time_scale = 20.0 if is_equal_approx(time_manager.time_scale, 1.0) else 1.0
	feedback_message.emit("Clock speed set to %.0fx" % time_manager.time_scale)


func _on_daylight_started(day_number: int) -> void:
	pop_mgr.set_dusk_or_night_safety(false, building_mgr)
	if day_number > 1:
		shrine_offering_used_today = false
		shrine_offering_used_today = false
	resource_mgr.refresh_renewable_nodes()
	_update_resource_node_visuals()
	feedback_message.emit("Day %d Daylight — Wood & Stone nodes refreshed! Expand Farms, Watchtower & Stone Wall." % day_number)


func _on_sunset_started(_day_number: int) -> void:
	pop_mgr.set_dusk_or_night_safety(true, building_mgr)
	_play_sfx("sfx_sunset")
	feedback_message.emit("Sunset Warning — Builder is retreating to the Town Center safe zone!")


func _on_night_started(_day_number: int) -> void:
	pop_mgr.set_dusk_or_night_safety(true, building_mgr)
	if not night_mgr.night_active:
		night_mgr.on_night_started(time_manager.current_day if time_manager != null else 1)
	_play_sfx("sfx_night")
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
	resource_mgr.refresh_renewable_nodes()
	_update_resource_node_visuals()
	pop_mgr.on_sunrise_refill()
	save_game_state()



func _on_enemy_defeated(_archetype: String, reward_gold: int, pos_x: float) -> void:
	if economy.try_add(&"gold", reward_gold):
		_play_sfx("sfx_coin")
		_spawn_floating_text(pos_x, "+%dG" % reward_gold)
		feedback_message.emit("Raider defeated! +%d Gold" % reward_gold)


func _on_night_resolved(survived: bool, wall_held: bool) -> void:
	if reign_state == ReignState.ISLAND_CLEARED:
		feedback_message.emit("Dawn of Day 3+! Forgotten Shore secured. State auto-saved!")
	elif survived and wall_held:
		feedback_message.emit("Sunrise reached! Your defenses held the line. Kingdom state auto-saved!")
	elif survived:
		feedback_message.emit("Sunrise reached! The wall fell, but dawn broke in time. Auto-saved!")
	else:
		feedback_message.emit("Raiders breached Town Center! Half your Gold was lost; rebuild before next dusk.")


func _sync_hearth_visuals() -> void:
	var light: PointLight2D = get_node_or_null("WorldObjects/TownCenterAnchor/CampfireLight") as PointLight2D
	if light != null:
		light.texture_scale = hearth_sys.get_texture_scale()
	var t_lbl: Label = get_node_or_null("WorldObjects/TownCenterAnchor/TownLabel") as Label
	if t_lbl != null:
		if hearth_sys.hearth_level == 1:
			t_lbl.text = "Town Center (Hearth Lv.1)\n[Q] Beacon Lv2: 4G 4W 2S"
		elif hearth_sys.hearth_level == 2:
			t_lbl.text = "Town Center (Hearth Lv.2)\n[Q] Solar Lv3: 6G 5W 4S"
		else:
			t_lbl.text = "Town Center (Solar Brazier Lv.3)"


func _sync_landmark_visuals() -> void:
	var ship_spr: Sprite2D = get_node_or_null("WorldObjects/ShipwreckAnchor/ShipSprite") as Sprite2D
	var ship_lbl: Label = get_node_or_null("WorldObjects/ShipwreckAnchor/ShipLabel") as Label
	if ship_spr != null:
		ship_spr.frame = clampi(shipwreck_stage, 0, 3)
	if ship_lbl != null:
		if shipwreck_stage >= 3:
			ship_lbl.text = "Vessel Ready! [E] Set Sail"
		else:
			var c: Dictionary = SHIPWRECK_COSTS[shipwreck_stage]
			ship_lbl.text = "Shipwreck [E] Stage %d/3\n%dG %dW %dS" % [shipwreck_stage + 1, int(c["gold"]), int(c["wood"]), int(c["stone"])]
	var portal_spr: Sprite2D = get_node_or_null("WorldObjects/GreedPortalAnchor/PortalSprite") as Sprite2D
	var portal_lbl: Label = get_node_or_null("WorldObjects/GreedPortalAnchor/PortalLabel") as Label
	if portal_spr != null:
		portal_spr.frame = 1 if reign_state == ReignState.ISLAND_CLEARED else 0
	if portal_lbl != null:
		portal_lbl.text = "Greed Portal (Scavenged)" if portal_relic_looted else "Greed Portal [E]\nScavenge Relic (+3G +2S)"


func _tick_monarch_light_risk(sim_delta: float, is_night: bool) -> void:
	_stagger_cooldown = maxf(0.0, _stagger_cooldown - sim_delta)
	if not is_night or not night_mgr.enemy_active or player == null or _stagger_cooldown > 0.0:
		return
	var px: float = player.global_position.x
	if not hearth_sys.is_in_light(px) and absf(px - night_mgr.enemy_x) <= 44.0:
		_stagger_cooldown = 2.0
		player.global_position.x = clampf(px - 48.0, player.min_bound_x, player.max_bound_x)
		if economy.get_amount(&"gold") > 0:
			economy.try_spend({"gold": 1})
		feedback_message.emit("Shadow Stagger! Stay inside the Light at Night (-1 Gold)!")


func _get_plot_nodes(plot_id: String) -> Dictionary:
	match plot_id:
		BuildingManager.WALL_ID:
			return {"sprite": wall_visual, "label": wall_label, "title": "Wall Plot", "cost": "2G 4W 2S"}
		BuildingManager.WEST_WALL_ID:
			return {"sprite": get_node_or_null("WorldObjects/WestWallPlot/WallVisual") as Sprite2D, "label": get_node_or_null("WorldObjects/WestWallPlot/WallLabel") as Label, "title": "West Wall", "cost": "2G 4W 2S"}
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
			lbl.text = "%s [E/B]\n%s" % [title, cost_txt]
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
				lbl.text = "Wooden Wall [Q: Stone Lv2]\nHP %d/%d (3G 2W 5S)" % [durability, max_dur]
			else:
				spr.modulate = Color(1.0, 1.0, 1.0, 1.0)
				lbl.text = "%s\nHP %d/%d" % [title, durability, max_dur]
		"DAMAGED":
			spr.frame = 3
			spr.modulate = Color(1.0, 0.85, 0.85, 1.0)
			lbl.text = "Damaged %s [E/F]\nHP %d/%d" % [title, durability, max_dur]
		"DESTROYED":
			spr.frame = 0
			spr.modulate = Color(0.75, 0.4, 0.4, 0.65)
			lbl.text = "Destroyed %s [E/B]\nRebuild: %s" % [title, cost_txt]


func _on_npc_state_changed(_npc_id: String, _role: String, state_name: String, pos_x: float) -> void:
	if npc_visual != null:
		npc_visual.position.x = pos_x
	if npc_label != null:
		if not builder_npc.recruited:
			npc_label.text = "Vagrant [E/R: 2G]"
		else:
			match state_name:
				"WORKING":
					npc_label.text = "Builder: Working"
				"RETURNING_TO_SAFETY":
					npc_label.text = "Retreating!"
				_:
					npc_label.text = ""
			npc_label.visible = not npc_label.text.is_empty()


func _sync_follower_nodes() -> void:
	var container: Node = get_node_or_null("WorldObjects/NPCFollowers")
	if container == null:
		return
	for i: int in range(1, pop_mgr.agents.size()):
		var agent: NPCBuilderAgent = pop_mgr.agents[i]
		if not _follower_sprites.has(agent.npc_id):
			var spr: Sprite2D = Sprite2D.new()
			spr.centered = false
			spr.offset = Vector2(-16, -32)
			spr.hframes = 8
			container.add_child(spr)
			_follower_sprites[agent.npc_id] = spr
		var s: Sprite2D = _follower_sprites[agent.npc_id] as Sprite2D
		var tex_path: String = "res://assets/characters/npc/npc_builder_sheet.png"
		if agent.role == "farmer":
			tex_path = "res://assets/characters/npc/npc_farmer_sheet.png"
		elif agent.role == "archer":
			tex_path = "res://assets/characters/npc/npc_archer_sheet.png"
		if ResourceLoader.exists(tex_path):
			s.texture = load(tex_path)
		var dx: float = agent.position_x - s.position.x
		if absf(dx) > 0.05:
			s.flip_h = dx < 0.0
		s.position.x = agent.position_x
		if agent.state == NPCBuilderAgent.State.WORKING:
			s.frame = 4 + (int(floorf(_anim_clock * 8.0)) % 4)
		elif agent.state == NPCBuilderAgent.State.MOVING_TO_TASK or agent.state == NPCBuilderAgent.State.RETURNING_TO_SAFETY:
			s.frame = int(floorf(_anim_clock * 8.0)) % 4
		else:
			s.frame = 0


func _update_proximity_prompts() -> void:
	if player == null:
		return
	var px: float = player.global_position.x
	_active_target = _resolve_target_for_actor(px)
	var active_kind: String = String(_active_target.get("kind", ""))
	var active_id: String = String(_active_target.get("target_id", ""))
	var highlight_col: Color = Color(1.0, 0.95, 0.55, 1.0)
	var normal_col: Color = Color(1.0, 1.0, 1.0, 1.0)

	# Show ONLY the single active resolved prompt (plus live build/damage status)
	for n: Dictionary in resource_mgr.nodes:
		var nid: String = String(n["id"])
		var lbl: Label = get_node_or_null("WorldObjects/ResourceNodes/%s/Label" % nid) as Label
		if lbl != null:
			var is_active: bool = (active_kind == "resource" and active_id == nid)
			lbl.visible = is_active and not resource_mgr.is_collected(nid)
			lbl.modulate = highlight_col if is_active else normal_col

	if npc_label != null and not builder_npc.recruited:
		var camp_active: bool = (active_kind == "camp")
		npc_label.visible = camp_active
		npc_label.modulate = highlight_col if camp_active else normal_col

	for plot_id: String in [BuildingManager.WALL_ID, BuildingManager.WEST_WALL_ID, BuildingManager.WATCHTOWER_ID, BuildingManager.FARM_WEST_ID, BuildingManager.FARM_EAST_ID]:
		var nodes: Dictionary = _get_plot_nodes(plot_id)
		if nodes.is_empty():
			continue
		var lbl: Label = nodes["label"] as Label
		if lbl == null or not building_mgr.has_plot(plot_id):
			continue
		var plot: Dictionary = building_mgr.get_plot(plot_id)
		var st: int = int(plot["state"])
		var is_active_plot: bool = (active_kind == "building" and active_id == plot_id)
		lbl.visible = is_active_plot or st == BuildingManager.WallState.UNDER_CONSTRUCTION or st == BuildingManager.WallState.DAMAGED
		lbl.modulate = highlight_col if is_active_plot else normal_col

	var ship_lbl: Label = get_node_or_null("WorldObjects/ShipwreckAnchor/ShipLabel") as Label
	if ship_lbl != null:
		ship_lbl.visible = (active_kind == "shipwreck")
		ship_lbl.modulate = highlight_col if ship_lbl.visible else normal_col

	var portal_lbl: Label = get_node_or_null("WorldObjects/GreedPortalAnchor/PortalLabel") as Label
	if portal_lbl != null:
		portal_lbl.visible = (active_kind == "portal")
		portal_lbl.modulate = highlight_col if portal_lbl.visible else normal_col

	for sid: String in NPCPopulationManager.TOOL_STANDS.keys():
		var lbl: Label = get_node_or_null("WorldObjects/ToolStands/%s/Label" % sid) as Label
		if lbl != null:
			var is_stand: bool = (active_kind == "tool_stand" and active_id == sid)
			lbl.visible = is_stand
			lbl.modulate = highlight_col if is_stand else normal_col


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
			if night_mgr.enemy_archetype == "brute":
				enemy_sprite.scale = Vector2(1.45, 1.45)
				enemy_sprite.modulate = Color(0.85, 0.65, 1.0, 1.0)
			elif night_mgr.enemy_archetype == "crawler":
				enemy_sprite.scale = Vector2(0.9, 0.85)
				enemy_sprite.modulate = Color(1.0, 0.75, 0.75, 1.0)
			else:
				enemy_sprite.scale = Vector2(1.0, 1.0)
				enemy_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if slice_hud != null and slice_hud.has_method("set_forecast_text"):
		var day_n: int = time_manager.current_day if time_manager != null else 1
		if night_mgr.enemy_active:
			slice_hud.call("set_forecast_text", "ALERT: %s (%d/%d HP) at x=%.0f" % [night_mgr.get_enemy_display_name(), night_mgr.enemy_hp, night_mgr.enemy_max_hp, night_mgr.enemy_x])
		else:
			slice_hud.call("set_forecast_text", NightEncounterManager.get_night_forecast(day_n))

	if building_mgr.durability < _prev_wall_hp and _prev_wall_hp > 0:
		_play_sfx("sfx_hit")
		var restore_wall: Color = Color(1.0, 0.85, 0.85, 1.0) if building_mgr.state == BuildingManager.WallState.DAMAGED else Color(1.0, 1.0, 1.0, 1.0)
		_flash_sprite(wall_visual, Color(2.0, 1.2, 1.2, 1.0), restore_wall)
		_trigger_camera_shake(4.0, 0.14)
	_prev_wall_hp = building_mgr.durability

	if night_mgr.enemy_active and night_mgr.enemy_hp < _prev_enemy_hp and _prev_enemy_hp > 0:
		_flash_sprite(enemy_sprite)
	_prev_enemy_hp = night_mgr.enemy_hp if night_mgr.enemy_active else 0


	var west_actor: Node2D = get_node_or_null("WorldObjects/WestEnemyActor") as Node2D
	if west_actor != null:
		west_actor.visible = night_mgr.west_enemy_active
		west_actor.position.x = night_mgr.west_enemy_x

	_sync_follower_nodes()
	_update_proximity_prompts()


func _update_resource_node_visuals() -> void:
	var nodes_root: Node = get_node_or_null("WorldObjects/ResourceNodes")
	if nodes_root == null:
		return
	for n: Dictionary in resource_mgr.nodes:
		var node_id: String = String(n["id"])
		var marker: CanvasItem = nodes_root.get_node_or_null(node_id) as CanvasItem
		if marker != null:
			marker.modulate.a = 0.25 if resource_mgr.is_collected(node_id) else 1.0


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
	_sync_hearth_visuals()
	_sync_landmark_visuals()
	_update_resource_node_visuals()
	_sync_dynamic_actors()


func _reign_state_to_string(rs: ReignState) -> String:
	match rs:
		ReignState.BREACH_PENALTY:
			return "BREACH_PENALTY"
		ReignState.ISLAND_CLEARED:
			return "ISLAND_CLEARED"
		_:
			return "ACTIVE"


func _string_to_reign_state(raw_val: Variant) -> ReignState:
	var norm: String = SaveManager._normalize_reign_state(raw_val)
	match norm:
		"BREACH_PENALTY":
			return ReignState.BREACH_PENALTY
		"ISLAND_CLEARED":
			return ReignState.ISLAND_CLEARED
		_:
			return ReignState.ACTIVE


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
		"npcs": pop_mgr.to_save_array(),
		"night_encounter": night_mgr.to_save_dict(),
		"progression_flags": {
			"first_night_survived": night_mgr.first_night_survived,
			"collected_nodes": resource_mgr.get_collected_ids_array(),
			"node_states": resource_mgr.to_save_dict(),
			"reign_state": _reign_state_to_string(reign_state),
			"hearth_level": hearth_sys.hearth_level,
			"shipwreck_stage": shipwreck_stage,
			"portal_relic_looted": portal_relic_looted,
			"shrine_offering_used_today": shrine_offering_used_today,
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
		set_actor_position("player_1", player.global_position.x)

	if data.has("night_encounter") and typeof(data["night_encounter"]) == TYPE_DICTIONARY:
		if not night_mgr.apply_save_dict(data["night_encounter"]):
			load_failed.emit("Failed to restore night_encounter state")
			return false

	if time_manager != null:
		if not time_manager.apply_save_dict(data):
			load_failed.emit("Failed to restore time_manager state")
			return false
	if not economy.set_balances_from_dict(data["resources"]):
		load_failed.emit("Failed to restore economy balances")
		return false

	var b_arr: Array = data["buildings"]
	if not building_mgr.apply_save_array(b_arr):
		load_failed.emit("Failed to restore buildings state")
		return false

	var n_arr: Array = data["npcs"]
	if not pop_mgr.apply_save_array(n_arr):
		load_failed.emit("Failed to restore NPC population state")
		return false
	for a: NPCBuilderAgent in pop_mgr.agents:
		_wire_follower_signals(a)
	_sync_follower_nodes()

	var flags: Dictionary = data["progression_flags"]
	night_mgr.first_night_survived = bool(flags.get("first_night_survived", night_mgr.first_night_survived))
	reign_state = _string_to_reign_state(flags.get("reign_state", "ACTIVE"))
	hearth_sys.apply_save_level(int(flags.get("hearth_level", 1)))
	shipwreck_stage = clampi(int(flags.get("shipwreck_stage", 0)), 0, 3)
	portal_relic_looted = bool(flags.get("portal_relic_looted", false))
	shrine_offering_used_today = bool(flags.get("shrine_offering_used_today", false))
	resource_mgr.apply_save_state(flags.get("node_states", null), flags.get("collected_nodes", []))

	if time_manager != null:
		var is_unsafe: bool = time_manager.current_phase != TimeManager.Phase.DAYLIGHT
		pop_mgr.set_dusk_or_night_safety(is_unsafe, building_mgr)

	_sync_all_presentations()
	return true


func _consume_pending_load_if_requested() -> void:
	if Engine.has_meta("crownfall_load_on_start") and bool(Engine.get_meta("crownfall_load_on_start")):
		Engine.set_meta("crownfall_load_on_start", false)
		if load_game_state():
			feedback_message.emit("Loaded saved kingdom state from user://save_slot_0.json")
