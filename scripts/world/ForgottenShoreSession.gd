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
var tree_mgr: ForestTreeManager = ForestTreeManager.new()
var pause_menu: PauseMenu = null
var hearth_sys: HearthSystem = HearthSystem.new()
var pop_mgr: NPCPopulationManager = NPCPopulationManager.new()
var builder_npc: NPCBuilderAgent = null
var night_mgr: NightEncounterManager = NightEncounterManager.new()
var era_mgr: EraProgressionManager = EraProgressionManager.new()
var progression: ProgressionState = ProgressionState.new()
var specialists: SpecialistDomain = SpecialistDomain.new()
var research_mgr: ResearchManager = ResearchManager.new()
var structures: StructureDomain = StructureDomain.new()
var resource_access: ResourceAccessState = ResourceAccessState.new()
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
var _farm_timers: Dictionary = {}
var fx: ShoreFX = null
var view: ShoreView = null
var _stagger_cooldown: float = 0.0
var _last_rejection_reason: String = ""
var _last_rollback_failure_reason: String = ""
var _signals_wired: bool = false
var _last_saved_signature: int = 0
var _session_initialized: bool = false
var _loaded_from_save_on_start: bool = false

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
	var cam: Camera2D = (player.get_node_or_null("Camera2D") as Camera2D) if player != null else null
	fx = ShoreFX.new(self, sfx_player, cam)
	view = ShoreView.new(self)
	building_mgr.register_forgotten_shore_expansion_plots()
	_sync_resource_prompts_from_data()
	_setup_forest_visuals()
	_setup_specialist_visuals()
	_setup_structure_visuals()
	_setup_pause_menu()
	_wire_signals()
	_consume_pending_load_if_requested()
	_sync_all_presentations()
	_sync_plot_label_data()
	_last_saved_signature = _unsaved_signature()
	feedback_message.emit("Forgotten Shore: [A/D] Move | [E] Interact | [Q] Upgrade | [R] Recruit | [B] Build | [F] Repair | [T] 20x | [K] Save | [Esc] Pause")
	var core_ready: bool = player != null and time_manager != null and building_mgr != null and pop_mgr != null and fx != null and view != null and slice_hud != null
	_session_initialized = core_ready
	if PrologueHandoffBridge.has_pending_intent():
		PrologueHandoffBridge.acknowledge_destination_ready("res://scenes/world/ForgottenShore.tscn", _session_initialized, _loaded_from_save_on_start)


func is_session_initialized() -> bool:
	return _session_initialized


func was_loaded_from_save_on_start() -> bool:
	return _loaded_from_save_on_start


func _setup_pause_menu() -> void:
	if pause_menu != null:
		return
	pause_menu = PauseMenu.new()
	pause_menu.bind_session(self)
	add_child(pause_menu)


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false


func _sync_resource_prompts_from_data() -> void:
	if view != null:
		view.sync_resource_prompts_from_data()


func set_actor_position(actor_id: String, pos_x: float) -> void:
	_actor_positions[actor_id] = pos_x


func get_actor_position(actor_id: String) -> float:
	if actor_id == "player_1" and player != null:
		_actor_positions["player_1"] = player.global_position.x
	return float(_actor_positions.get(actor_id, 0.0))


func _process(delta: float) -> void:
	if player != null:
		_actor_positions["player_1"] = player.global_position.x
	var sim_delta: float = delta * (time_manager.time_scale if time_manager != null else 1.0)
	var is_night: bool = time_manager != null and time_manager.current_phase == TimeManager.Phase.NIGHT
	var is_daylight: bool = time_manager == null or time_manager.current_phase == TimeManager.Phase.DAYLIGHT
	pop_mgr.tick_all(sim_delta, building_mgr, night_mgr, resource_mgr, economy)
	research_mgr.advance_research(sim_delta)
	flare_active_timer = maxf(0.0, flare_active_timer - sim_delta)
	flare_cooldown_timer = maxf(0.0, flare_cooldown_timer - sim_delta)
	var was_boosted: bool = hearth_sys.is_boost_active()
	if not is_daylight:
		hearth_sys.tick_boost(sim_delta)
	if was_boosted != hearth_sys.is_boost_active():
		_sync_hearth_visuals()
	night_mgr.tick(sim_delta, is_night, building_mgr, hearth_sys.get_effective_radius_px(), hearth_sys.get_effective_burn_dps(), flare_active_timer > 0.0)
	_tick_monarch_light_risk(sim_delta, is_night)
	if view != null:
		view.advance_and_sync(delta)


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
	specialists.specialist_discovered.connect(_on_specialist_discovered)
	specialists.specialist_recruited.connect(_on_specialist_recruited)
	specialists.specialist_action_rejected.connect(_record_rejection)
	research_mgr.research_started.connect(_on_research_started)
	research_mgr.research_completed.connect(_on_research_completed)
	research_mgr.research_rejected.connect(_record_rejection)
	structures.structure_activated.connect(_on_structure_activated)
	structures.structure_action_rejected.connect(_record_rejection)
	building_mgr.building_action_rejected.connect(_record_rejection)
	building_mgr.wall_state_changed.connect(_on_wall_state_changed)
	night_mgr.building_attacked.connect(_on_building_attacked)
	builder_npc.recruitment_rejected.connect(_record_rejection)
	builder_npc.npc_state_changed.connect(_on_npc_state_changed)
	_wire_follower_signals(builder_npc)
	pop_mgr.population_action_rejected.connect(_record_rejection)
	pop_mgr.roster_changed.connect(_sync_follower_nodes)
	night_mgr.night_encounter_resolved.connect(_on_night_resolved)
	night_mgr.enemy_defeated.connect(_on_enemy_defeated)

	save_mgr.save_failed.connect(_on_save_failed)
	save_mgr.load_recovered_from_backup.connect(_on_load_recovered_from_backup)
	load_failed.connect(_record_rejection)

	if slice_hud != null and slice_hud.has_method("bind_session"):
		slice_hud.call("bind_session", self)


func _on_save_failed(reason: String) -> void:
	_record_rejection("Auto-save FAILED: %s" % reason)


func _on_load_recovered_from_backup(backup_path: String) -> void:
	feedback_message.emit("Save file was corrupted — recovered from backup (%s)" % backup_path)


func _play_sfx(sfx_name: String) -> void:
	if fx != null:
		fx.play_sfx(sfx_name)


func _spawn_floating_text(world_x: float, text: String, col: Color = Color(1.0, 0.92, 0.45, 1.0)) -> void:
	if fx != null:
		fx.spawn_floating_text(world_x, text, col)


func _spawn_payment_fly(cost: Dictionary, from_x: float, to_x: float) -> void:
	if fx != null:
		fx.spawn_payment_fly(cost, from_x, to_x)


func _trigger_camera_shake(intensity: float = 4.0, duration: float = 0.14) -> void:
	if fx != null:
		fx.trigger_camera_shake(intensity, duration)


func _flash_sprite(spr: CanvasItem, flash_col: Color = Color(2.0, 1.2, 1.2, 1.0), restore_col: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	if fx != null:
		fx.flash_sprite(spr, flash_col, restore_col)


func _record_rejection(reason: String) -> void:
	_last_rejection_reason = reason
	feedback_message.emit(reason)


func get_last_rejection_reason() -> String:
	return _last_rejection_reason


func get_last_rollback_failure_reason() -> String:
	# Dedicated diagnostic slot for a FAILED rollback after a failed load.
	# Kept separate from _last_rejection_reason so the original load-failure
	# reason can never be overwritten by follow-up recovery diagnostics.
	return _last_rollback_failure_reason


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
		shrine_offering_used_today,
		tree_mgr,
		specialists,
		progression,
		research_mgr,
		structures
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
			# Phase 5 resource access: acquisition requires explicit access
			# (derived from registered unlock conditions + durable facts, never
			# from the ledger balance). Base resources are always accessible,
			# so existing Forgotten Shore gameplay is unchanged; a future
			# locked resource fails closed here BEFORE any ledger mutation.
			var col_node: Dictionary = resource_mgr.get_node_def(resolved_target)
			var col_resource: String = String(col_node.get("resource", ""))
			if not col_node.is_empty() and not resource_access.is_accessible(col_resource, progression):
				_record_rejection("%s is not accessible yet" % col_resource.capitalize())
			elif not col_node.is_empty():
				var res: Dictionary = resource_mgr.try_collect(resolved_target, actor_x, economy)
				ok = bool(res.get("ok", false))
				if ok:
					var nd: Dictionary = res["node"] as Dictionary
					_update_resource_node_visuals()
					_play_sfx("sfx_coin")
					# Phase 5 structure blessing: additive wood-gathering bonus
					# derived on the fly from activation facts (no stored value
					# can double-apply; loading a save re-derives it).
					var gather_bonus: int = 0
					if String(nd["resource"]) == &"wood":
						gather_bonus = structures.get_effect_total(BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, progression)
					var blessing_applied: bool = false
					if gather_bonus > 0:
						blessing_applied = economy.try_add(&"wood", gather_bonus)
					if blessing_applied:
						_spawn_floating_text(float(nd["x"]), "+%d Wood" % (int(nd["amount"]) + gather_bonus))
						feedback_message.emit("Collected: %s (+%d blessing Wood)" % [String(nd["label"]), gather_bonus])
					else:
						_spawn_floating_text(float(nd["x"]), "+%d %s" % [int(nd["amount"]), String(nd["resource"]).capitalize()])
						feedback_message.emit("Collected: %s" % String(nd["label"]))
				else:
					_record_rejection(String(res.get("reason", "Collection failed")))
			else:
				# Unknown node ID: same rejection reason try_collect produces.
				_record_rejection("Unknown resource node: %s" % resolved_target)

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
				_spawn_payment_fly({"gold": 2}, actor_x, NPCBuilderAgent.CAMP_POSITION_X)
				_wire_follower_signals(agent)
				if agent.role == "villager":
					feedback_message.emit("Recruited Villager! Assign a role at the Hammer/Scythe/Bow Stand near Town Center. Total NPCs: %d" % pop_mgr.get_recruited_count())
				else:
					feedback_message.emit("Recruited %s (%s)! Total NPCs: %d" % [agent.npc_id, agent.role.capitalize(), pop_mgr.get_recruited_count()])

		&"build":
			if resolved_target.is_empty():
				resolved_target = building_mgr.get_nearest_actionable_plot_id(actor_x, BuildingManager.INTERACT_RANGE, "build_or_upgrade")
			if resolved_target.is_empty():
				resolved_target = building_mgr.get_nearest_plot_id(actor_x, BuildingManager.INTERACT_RANGE)
			if resolved_target.is_empty():
				resolved_target = BuildingManager.WALL_ID
			ok = building_mgr.request_start_construction(actor_x, economy, resolved_target)
			if ok:
				_play_sfx("sfx_build")
				var built_plot: Dictionary = building_mgr.get_plot(resolved_target)
				_spawn_payment_fly(built_plot.get("build_cost", {}) as Dictionary, actor_x, float(built_plot.get("position_x", actor_x)))
				feedback_message.emit("%s blueprint funded! Builder will construct it." % resolved_target)

		&"repair":
			if resolved_target.is_empty():
				resolved_target = building_mgr.get_nearest_actionable_plot_id(actor_x, BuildingManager.INTERACT_RANGE, "repair")
			if resolved_target.is_empty():
				resolved_target = building_mgr.get_nearest_plot_id(actor_x, BuildingManager.INTERACT_RANGE)
			if resolved_target.is_empty():
				resolved_target = BuildingManager.WALL_ID
			var extra_repair_cost: Dictionary = {"wood": 1} if (time_manager != null and time_manager.current_phase == TimeManager.Phase.NIGHT) else {}
			ok = building_mgr.request_repair(actor_x, economy, resolved_target, extra_repair_cost)
			if ok:
				_play_sfx("sfx_build")
				var rep_plot: Dictionary = building_mgr.get_plot(resolved_target)
				var rep_total: Dictionary = (rep_plot.get("repair_cost", {}) as Dictionary).duplicate()
				for r_key: String in extra_repair_cost.keys():
					rep_total[String(r_key)] = int(rep_total.get(String(r_key), 0)) + int(extra_repair_cost[r_key])
				_spawn_payment_fly(rep_total, actor_x, float(rep_plot.get("position_x", actor_x)))
				feedback_message.emit("Structure (%s) repaired to full durability!" % resolved_target)

		&"upgrade_building":
			if resolved_target.is_empty():
				resolved_target = building_mgr.get_nearest_actionable_plot_id(actor_x, BuildingManager.INTERACT_RANGE, "upgrade")
			if resolved_target.is_empty():
				resolved_target = building_mgr.get_nearest_plot_id(actor_x, BuildingManager.INTERACT_RANGE)
			if resolved_target.is_empty():
				resolved_target = BuildingManager.WALL_ID
			ok = building_mgr.request_upgrade_wall(actor_x, economy, resolved_target)
			if ok:
				_play_sfx("sfx_build")
				var upg_plot: Dictionary = building_mgr.get_plot(resolved_target)
				_spawn_payment_fly(building_mgr.get_plot_upgrade_cost(resolved_target), actor_x, float(upg_plot.get("position_x", actor_x)))
				var era_note: String = ""
				if era_mgr.notify_stone_wall_built():
					era_note = " The Stone Age has begun!"
				# Fondasi progresi Fase 1: milestone Stone Wall Tier 2 pertama
				# dicatat sebagai fakta durables HANYA setelah transaksi upgrade
				# berhasil (di atas). record_fact idempotent, jadi notifikasi
				# milestone yang berulang tidak pernah menduplikasi progresi.
				progression.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2)
				feedback_message.emit("Upgraded to %s (%d HP, %d thorn dmg)!%s" % [
					building_mgr.get_plot_title(resolved_target),
					int(upg_plot.get("max_durability", BuildingManager.STONE_WALL_MAX_DURABILITY)),
					building_mgr.get_thorn_damage(resolved_target),
					era_note,
				])

		&"upgrade_hearth":
			var hres: Dictionary = hearth_sys.try_upgrade(actor_x, economy)
			ok = bool(hres.get("ok", false))
			if ok:
				_sync_hearth_visuals()
				_play_sfx("sfx_build")
				_spawn_payment_fly(hearth_sys.get_next_upgrade_cost(), actor_x, HearthSystem.HEARTH_POSITION_X)
				_spawn_floating_text(0.0, "Hearth Lv.%d!" % hearth_sys.hearth_level, Color(1.0, 0.78, 0.35, 1.0))
				feedback_message.emit("Hearth upgraded to Lv.%d (Light radius: %.0f px)!" % [hearth_sys.hearth_level, hearth_sys.get_radius_px()])
			else:
				_record_rejection(String(hres.get("reason", "Hearth upgrade failed")))

		&"boost_hearth":
			var bres: Dictionary = hearth_sys.try_stoke(actor_x, economy)
			ok = bool(bres.get("ok", false))
			if ok:
				_sync_hearth_visuals()
				_play_sfx("sfx_sunset")
				_spawn_payment_fly(HearthSystem.BOOST_COST, actor_x, HearthSystem.HEARTH_POSITION_X)
				_spawn_floating_text(0.0, "STOKED!", Color(1.0, 0.85, 0.4, 1.0))
				feedback_message.emit("Fire stoked! Light radius +30%% and burn +2 DPS for %.0f seconds!" % HearthSystem.BOOST_DURATION_SEC)
			else:
				_record_rejection(String(bres.get("reason", "Stoke Fire failed")))

		&"shipwreck":
			ok = _on_player_interact_shipwreck(actor_x)

		&"loot_portal":
			if absf(actor_x - PORTAL_X) <= 96.0:
				ok = _on_player_loot_portal_relic()
			else:
				_record_rejection("Move closer to Greed Portal (x=1350)")

		&"shrine_offering":
			var offering_yield: int = 2 + research_mgr.get_effect_total(ResearchManager.EFFECT_SHRINE_OFFERING_GOLD_BONUS)
			if absf(actor_x - (-780.0)) > ResourceNodeManager.INTERACT_RANGE:
				_record_rejection("Move closer to Forgotten Shrine (x=-780)")
			elif shrine_offering_used_today:
				_record_rejection("Shrine Offering already used today")
			elif not economy.try_spend({"wood": 4, "stone": 2}):
				_record_rejection("Shrine Offering needs 4 Wood, 2 Stone")
			elif not economy.try_add(&"gold", offering_yield):
				economy.try_add_bundle({"wood": 4, "stone": 2})
				_record_rejection("Shrine Offering failed — ledger rejected the reward")
			else:
				shrine_offering_used_today = true
				ok = true
				_play_sfx("sfx_coin")
				_spawn_payment_fly({"wood": 4, "stone": 2}, actor_x, -780.0)
				_spawn_floating_text(-780.0, "+%dG Offering" % offering_yield)
				feedback_message.emit("Shrine Offering accepted: 4W + 2S -> +%d Gold!" % offering_yield)

		&"kindle_flare":
			if time_manager == null or time_manager.current_phase != TimeManager.Phase.NIGHT:
				_record_rejection("Kindle Flare [Space] can only be used at Night")
			elif flare_cooldown_timer > 0.0:
				_record_rejection("Kindle Flare on cooldown (%.0fs)" % flare_cooldown_timer)
			elif not economy.try_spend({"wood": 1}):
				_record_rejection("Kindle Flare needs 1 Wood")
			else:
				var flare_duration: float = 8.0 + float(research_mgr.get_effect_total(ResearchManager.EFFECT_FLARE_DURATION_BONUS_SEC))
				flare_active_timer = flare_duration
				flare_cooldown_timer = 25.0
				ok = true
				_play_sfx("sfx_sunset")
				_spawn_payment_fly({"wood": 1}, actor_x, HearthSystem.HEARTH_POSITION_X)
				_spawn_floating_text(actor_x, "KINDLE FLARE +50%!", Color(1.0, 0.82, 0.35, 1.0))
				feedback_message.emit("Kindle Flare active! Hearth burn & Watchtower dmg +50%% for %.0fs!" % flare_duration)

		&"chop_tree":
			if resolved_target.is_empty():
				var tr: Dictionary = tree_mgr.find_nearest_standing(actor_x)
				resolved_target = String(tr.get("id", ""))
			# Phase 5 resource access gate for the felling reward (see collect).
			if not resource_access.is_accessible("wood", progression):
				_record_rejection("Wood is not accessible yet")
			else:
				var cres: Dictionary = tree_mgr.try_chop(resolved_target, actor_x, economy)
				ok = bool(cres.get("ok", false))
				if ok:
					var td: Dictionary = cres["tree"] as Dictionary
					_update_forest_visuals()
					_play_sfx("sfx_build")
					if bool(cres.get("felled", false)):
						var fell_bonus: int = structures.get_effect_total(BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, progression)
						var fell_blessing_applied: bool = false
						if fell_bonus > 0:
							fell_blessing_applied = economy.try_add(&"wood", fell_bonus)
						if fell_blessing_applied:
							_spawn_floating_text(float(td["x"]), "+%d Wood" % (int(cres["wood_gained"]) + fell_bonus))
							feedback_message.emit("Tree felled! +%d Wood (+%d blessing Wood)" % [int(cres["wood_gained"]), fell_bonus])
						else:
							_spawn_floating_text(float(td["x"]), "+%d Wood" % int(cres["wood_gained"]))
							feedback_message.emit("Tree felled! +%d Wood" % int(cres["wood_gained"]))
					else:
						_spawn_floating_text(float(td["x"]), "Chop (%d/%d)" % [int(cres["hp_left"]), int(td["max_hp"])])
				else:
					_record_rejection(String(cres.get("reason", "Cannot chop tree")))

		&"discover_specialist":
			ok = _on_discover_specialist(actor_x, resolved_target)

		&"recruit_specialist":
			ok = _on_recruit_specialist(actor_x, resolved_target)

		&"start_research":
			ok = _on_start_research(actor_x, resolved_target)

		&"activate_structure":
			ok = _on_activate_structure(actor_x, resolved_target)

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
		target_id = building_mgr.get_nearest_actionable_plot_id(player_x, BuildingManager.INTERACT_RANGE, "build_or_upgrade")
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
		target_id = building_mgr.get_nearest_actionable_plot_id(player_x, BuildingManager.INTERACT_RANGE, "repair")
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
		night_mgr.stop_encounter()
		reign_state = ReignState.ISLAND_CLEARED
		if not save_game_state():
			_record_rejection("Island cleared, but auto-save FAILED — progress may be lost")
		_play_sfx("sfx_coin")
		if slice_hud != null and slice_hud.has_method("show_victory_banner"):
			slice_hud.call("show_victory_banner", "ISLAND CLEARED", "The vessel sets sail from Forgotten Shore toward Eldergrove Forest!")
		feedback_message.emit("Ship repaired! Setting sail from Forgotten Shore toward Eldergrove Forest!")
		return true
	var cost: Dictionary = SHIPWRECK_COSTS[shipwreck_stage]
	if not economy.try_spend(cost):
		_record_rejection("Shipwreck Stage %d/3 needs %dG %dW %dS" % [shipwreck_stage + 1, int(cost["gold"]), int(cost["wood"]), int(cost["stone"])])
		return false
	shipwreck_stage += 1
	_sync_landmark_visuals()
	_play_sfx("sfx_build")
	_spawn_payment_fly(cost, player_x, SHIPWRECK_X)
	_spawn_floating_text(SHIPWRECK_X, "Ship Stage %d/3" % shipwreck_stage)
	if shipwreck_stage >= 3:
		# Koreksi era Fase 2: menyelesaikan Shipwreck Stage 3 berarti kapal siap
		# berlayar. Fakta voyage readiness dicatat HANYA setelah transaksi repair
		# berhasil di atas; record_fact idempotent, jadi notifikasi berulang tidak
		# pernah menduplikasi progresi. Stage 3 TIDAK lagi membuka Iron Age —
		# Iron Age kini hanya bisa dibuka lewat milestone Eldergrove Forest
		# (fakta `eldergrove_reached`, fase multi-island mendatang).
		progression.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)
		feedback_message.emit("Shipwreck repaired to Stage 3/3! The vessel is ready to set sail from Forgotten Shore.")
	else:
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


## Phase 5 structure activation command. An empty target resolves the nearest
## activatable (AVAILABLE lifecycle) active-island structure in range
## (deterministic sorted-ID order); the authoritative transaction lives in
## StructureDomain: validate -> atomic EconomyLedger spend -> record the
## durable activation fact -> signal. A repeated activation is rejected
## BEFORE any spend, so it can never deduct resources twice.
func _on_activate_structure(actor_x: float, structure_id: String) -> bool:
	var st_id: String = structure_id
	if st_id.is_empty():
		var best_id: String = ""
		var best_d: float = StructureDomain.INTERACT_RANGE + 0.001
		for cand: String in structures.get_structure_ids():
			var cdef: Dictionary = structures.get_structure_definition(cand)
			if String(cdef.get("island_id", "")) != SpecialistDomain.ACTIVE_ISLAND_ID or not cdef.has("world_x"):
				continue
			var cd: float = absf(actor_x - float(cdef["world_x"]))
			if cd <= StructureDomain.INTERACT_RANGE and cd < best_d and structures.get_lifecycle_state(cand, progression) == StructureDomain.STATE_AVAILABLE:
				best_id = cand
				best_d = cd
		st_id = best_id
	if st_id.is_empty():
		_record_rejection("No shrine or structure to activate nearby")
		return false
	if not structures.try_activate(actor_x, st_id, progression, economy):
		return false
	var def: Dictionary = structures.get_structure_definition(st_id)
	_play_sfx("sfx_build")
	_spawn_payment_fly(structures.get_activation_cost(st_id), actor_x, float(def["world_x"]))
	_spawn_floating_text(float(def["world_x"]), "AWAKENED!", Color(0.55, 0.92, 0.85, 1.0))
	var blessings: Array[String] = structures.get_structure_buff_summaries(st_id)
	var blessing_txt: String = ""
	if not blessings.is_empty():
		blessing_txt = " Blessing: %s." % ", ".join(blessings)
	feedback_message.emit("%s activated!%s" % [structures.get_structure_display_name(st_id), blessing_txt])
	return true


func _on_structure_activated(structure_id: String) -> void:
	_update_structure_visuals()


## Phase 3 specialist discovery command. An empty target resolves the nearest
## active-island specialist in range (deterministic sorted-ID order); the
## authoritative transaction lives in SpecialistDomain.
func _on_discover_specialist(actor_x: float, specialist_id: String) -> bool:
	var sp_id: String = specialist_id
	if sp_id.is_empty():
		sp_id = _find_nearby_specialist_id(actor_x)
	if sp_id.is_empty():
		_record_rejection("No specialist nearby to discover")
		return false
	return specialists.try_discover(actor_x, sp_id, progression)


## Phase 3 specialist recruitment command. An empty target resolves the nearest
## active-island specialist in range. Requirements, housing, costs and
## duplicate-recruitment guards are enforced by SpecialistDomain.try_recruit.
func _on_recruit_specialist(actor_x: float, specialist_id: String) -> bool:
	var sp_id: String = specialist_id
	if sp_id.is_empty():
		sp_id = _find_nearby_specialist_id(actor_x)
	if sp_id.is_empty():
		_record_rejection("No specialist nearby to recruit")
		return false
	return specialists.try_recruit(actor_x, sp_id, progression, building_mgr, economy)


## Phase 4 research start command. An empty target resolves the first
## available technology in stable ID order; proximity to a recruited
## specialist is the world-side gate and try_start enforces the rest.
func _on_start_research(actor_x: float, tech_id: String) -> bool:
	var resolved: String = tech_id
	if resolved.is_empty():
		resolved = research_mgr.get_first_available_technology_id(progression)
	if resolved.is_empty():
		_record_rejection("No research is available right now")
		return false
	if not specialists.is_any_recruited_specialist_near(actor_x, progression):
		_record_rejection("Stand near a recruited specialist to conduct research")
		return false
	return research_mgr.try_start(resolved, progression, economy)


func _on_research_started(tech_id: String) -> void:
	_play_sfx("sfx_build")
	feedback_message.emit("Research started: %s" % research_mgr.get_technology_display_name(tech_id))


func _on_research_completed(tech_id: String) -> void:
	_play_sfx("sfx_coin")
	feedback_message.emit("Research completed: %s! The kingdom benefits immediately." % research_mgr.get_technology_display_name(tech_id))


## Presentation helper delegated to ShoreView.
func _get_active_specialist_housing_plot_id() -> String:
	return view.get_active_specialist_housing_plot_id() if view != null else ""


func _find_nearby_specialist_id(actor_x: float) -> String:
	for sp_id: String in specialists.get_specialist_ids():
		var sp_def: Dictionary = specialists.get_specialist_definition(sp_id)
		if String(sp_def.get("island_id", "")) != SpecialistDomain.ACTIVE_ISLAND_ID:
			continue
		if not sp_def.has("world_x"):
			continue
		if absf(actor_x - float(sp_def["world_x"])) <= SpecialistDomain.INTERACT_RANGE:
			return sp_id
	return ""


func _on_specialist_discovered(specialist_id: String) -> void:
	var name_txt: String = specialists.get_display_name(specialist_id)
	if name_txt.is_empty():
		name_txt = specialist_id
	_play_sfx("sfx_coin")
	_spawn_floating_text(specialists.get_world_x(specialist_id), "%s found!" % name_txt, Color(0.6, 0.95, 0.85, 1.0))
	feedback_message.emit("You found %s! Build their hut here with [B] so they can join the kingdom." % name_txt)


func _on_specialist_recruited(specialist_id: String) -> void:
	var name_txt: String = specialists.get_display_name(specialist_id)
	if name_txt.is_empty():
		name_txt = specialist_id
	_play_sfx("sfx_coin")
	_spawn_floating_text(specialists.get_world_x(specialist_id), "%s joined!" % name_txt, Color(0.6, 0.95, 0.85, 1.0))
	feedback_message.emit("%s joined the kingdom!" % name_txt)


## Programmatic specialist-camp visuals delegated to ShoreView.
func _setup_specialist_visuals() -> void:
	if view != null:
		view.setup_specialist_visuals()


## Programmatic structure-landmark visuals delegated to ShoreView.
func _setup_structure_visuals() -> void:
	if view != null:
		view.setup_structure_visuals()


## Presentation-only structure marker refresh delegated to ShoreView.
func _update_structure_visuals() -> void:
	if view != null:
		view.update_structure_visuals()


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
	if not agent.auto_chop_collected.is_connected(_on_auto_chop_collected):
		agent.auto_chop_collected.connect(_on_auto_chop_collected)
	if not agent.tool_confiscated.is_connected(_on_tool_confiscated):
		agent.tool_confiscated.connect(_on_tool_confiscated)


func _get_agent_position(npc_id: String) -> float:
	for a: NPCBuilderAgent in pop_mgr.agents:
		if a.npc_id == npc_id:
			return a.position_x
	return 0.0


func _on_farmer_gold_earned(npc_id: String, amount: int) -> void:
	if economy.try_add(&"gold", amount):
		_play_sfx("sfx_coin")
		_spawn_floating_text(_get_agent_position(npc_id), "+%d Gold" % amount)
		feedback_message.emit("Farmer %s harvested +%d Gold!" % [npc_id, amount])


func _on_auto_chop_collected(npc_id: String, amount: int) -> void:
	# Phase 5: idle villagers chopping timber count as island wood gathering,
	# so the derived blessing bonus applies to their deliveries too.
	var chop_bonus: int = structures.get_effect_total(BuffCatalog.EFFECT_WOOD_GATHERING_BONUS, progression)
	var bonus_applied: bool = false
	if chop_bonus > 0:
		bonus_applied = economy.try_add(&"wood", chop_bonus)
	var delivered: int = amount + (chop_bonus if bonus_applied else 0)
	_play_sfx("sfx_coin")
	_spawn_floating_text(_get_agent_position(npc_id), "+%d Wood" % delivered)
	feedback_message.emit("Builder %s chopped +%d Wood while idle!" % [npc_id, delivered])


func _on_tool_confiscated(npc_id: String, former_role: String) -> void:
	_play_sfx("sfx_hit")
	_spawn_floating_text(_get_agent_position(npc_id), "-%s!" % former_role.capitalize(), Color(1.0, 0.5, 0.4, 1.0))
	feedback_message.emit("Greedlings caught %s outside the walls — %s tools lost! Re-assign at the Tool Stands tomorrow." % [npc_id, former_role.capitalize()])


func _on_archer_volley_fired(_npc_id: String, damage: int, from_tower: bool, target_x: float = 0.0) -> void:
	_play_sfx("sfx_bow")
	_spawn_floating_text(target_x, "-%d" % damage, Color(1.0, 0.45, 0.45, 1.0))
	feedback_message.emit("Archer volley (%d dmg%s)!" % [damage, " from Watchtower" if from_tower else ""])


func _on_building_attacked(plot_id: String, damage: int, enemy_x: float) -> void:
	_play_sfx("sfx_hit")
	var nodes: Dictionary = _get_plot_nodes(plot_id)
	var label: String = String(nodes.get("title", plot_id)) if not nodes.is_empty() else plot_id
	_spawn_floating_text(enemy_x, "-%d %s!" % [damage, label], Color(1.0, 0.35, 0.3, 1.0))
	if plot_id == BuildingManager.WEST_WALL_ID:
		feedback_message.emit("West Wall is under attack by a West Scout!")
	elif label.contains("Farm"):
		feedback_message.emit("Greedlings trampled one of our Farms! Repair it at dawn.")
	elif label.contains("Watchtower"):
		feedback_message.emit("Our Watchtower is under attack!")
	else:
		feedback_message.emit("Our East Wall is under attack!")


func _on_toggle_fast_clock() -> void:
	if time_manager == null:
		return
	time_manager.time_scale = 20.0 if is_equal_approx(time_manager.time_scale, 1.0) else 1.0
	feedback_message.emit("Clock speed set to %.0fx" % time_manager.time_scale)


func _on_daylight_started(day_number: int) -> void:
	pop_mgr.set_dusk_or_night_safety(false, building_mgr)
	# NOTE: the day-N+1 Shrine Offering reset lives in _on_sunrise_reached (just
	# before the autosave, P0.1) alongside the renewable refresh/regrow, so the
	# sunrise autosave captures the refreshed node, tree and offering state.
	feedback_message.emit("Day %d Daylight — Wood & Stone nodes refreshed! Expand Farms, Watchtower & Stone Wall." % day_number)


func _on_sunset_started(day_number: int) -> void:
	pop_mgr.set_dusk_or_night_safety(true, building_mgr)
	_play_sfx("sfx_sunset")
	if day_number >= 2:
		feedback_message.emit("Sunset Warning — Greedlings approach from BOTH shores tonight! Keep villagers inside the walls.")
	else:
		feedback_message.emit("Sunset Warning — Builder is retreating to the Town Center safe zone!")


func _on_night_started(day_number: int) -> void:
	pop_mgr.set_dusk_or_night_safety(true, building_mgr)
	if reign_state == ReignState.ISLAND_CLEARED:
		_play_sfx("sfx_sunset")
		feedback_message.emit("The island is at peace — no Greedlings remain after your victory.")
		return
	if not night_mgr.night_active:
		night_mgr.on_night_started(time_manager.current_day if time_manager != null else 1)
	_play_sfx("sfx_night")
	if day_number >= 2:
		feedback_message.emit("Night %d! Raiders hit the East Wall — West Scouts prowl the far flank!" % day_number)
	else:
		feedback_message.emit("Night has fallen! Greedling Raiders approach from the East Shore!")


func _on_sunrise_reached(completed_day: int) -> void:
	night_mgr.on_sunrise_reached(building_mgr)
	if night_mgr.settlement_breached and reign_state != ReignState.ISLAND_CLEARED:
		reign_state = ReignState.BREACH_PENALTY
		var cur_gold: int = economy.get_amount(&"gold")
		var penalty: int = cur_gold / 2
		if penalty > 0:
			economy.try_spend({"gold": penalty})
	elif reign_state != ReignState.ISLAND_CLEARED:
		reign_state = ReignState.ACTIVE
	# Refresh renewables BEFORE the autosave so the save records nodes as available
	# (daylight_started fires after this signal, too late for the payload).
	resource_mgr.refresh_renewable_nodes()
	tree_mgr.regrow_all()
	# P0.1: same convention as the renewables — the new day's Shrine Offering
	# availability is reset HERE so the sunrise autosave records it. The old
	# reset lived in _on_daylight_started, which fires after save_game_state
	# below and let yesterday's flag persist through Continue (N44_STEP2
	# reproduction report, Test A).
	shrine_offering_used_today = false
	_update_resource_node_visuals()
	_update_forest_visuals()
	pop_mgr.on_sunrise_refill()
	if save_game_state():
		feedback_message.emit("Kingdom state auto-saved!")
	else:
		feedback_message.emit("WARNING: Auto-save FAILED — progress may be lost!")



func _on_enemy_defeated(_archetype: String, reward_gold: int, pos_x: float) -> void:
	if economy.try_add(&"gold", reward_gold):
		_play_sfx("sfx_coin")
		_spawn_floating_text(pos_x, "+%dG" % reward_gold)
		feedback_message.emit("Raider defeated! +%d Gold" % reward_gold)


func _on_night_resolved(survived: bool, wall_held: bool) -> void:
	if reign_state == ReignState.ISLAND_CLEARED:
		var dawn_day: int = time_manager.current_day if time_manager != null else 1
		feedback_message.emit("Dawn of Day %d! Forgotten Shore secured." % dawn_day)
	elif survived and wall_held:
		feedback_message.emit("Sunrise reached! Your defenses held the line.")
	elif survived:
		feedback_message.emit("Sunrise reached! The wall fell, but dawn broke in time.")
	else:
		feedback_message.emit("Raiders breached Town Center! Half your Gold was lost; rebuild before next dusk.")




func _sync_hearth_visuals() -> void:
	if view != null:
		view.sync_hearth_visuals()


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
	if not is_night or player == null or _stagger_cooldown > 0.0:
		return
	if not (night_mgr.enemy_active or night_mgr.west_enemy_active):
		return
	var px: float = player.global_position.x
	var nearest: Dictionary = night_mgr.get_nearest_active_enemy(px)
	if nearest.is_empty() or hearth_sys.is_in_light(px):
		return
	if absf(px - float(nearest["x"])) > 44.0:
		return
	_stagger_cooldown = 2.0
	var enemy_x: float = float(nearest["x"])
	var away_dir: float = signf(px - enemy_x)
	if is_zero_approx(away_dir):
		away_dir = -1.0
	player.global_position.x = clampf(px + away_dir * 48.0, player.min_bound_x, player.max_bound_x)
	if economy.get_amount(&"gold") > 0:
		economy.try_spend({"gold": 1})
	feedback_message.emit("Shadow Stagger! Stay inside the Light at Night (-1 Gold)!")


func _get_plot_nodes(plot_id: String) -> Dictionary:
	return view.get_plot_nodes(plot_id) if view != null else {}


func _sync_plot_label_data() -> void:
	if view != null:
		view.sync_plot_label_data()


func _on_wall_state_changed(wall_id: String, new_state: String, progress: float, durability: int, max_dur: int) -> void:
	if view != null:
		view.on_wall_state_changed(wall_id, new_state, progress, durability, max_dur)


func _on_npc_state_changed(_npc_id: String, _role: String, state_name: String, pos_x: float) -> void:
	if view != null:
		view.on_npc_state_changed(_npc_id, _role, state_name, pos_x)


func _sync_follower_nodes() -> void:
	if view != null:
		view.sync_follower_nodes()


func _update_proximity_prompts() -> void:
	if view != null:
		view.update_proximity_prompts()




func _setup_forest_visuals() -> void:
	if view != null:
		view.setup_forest_visuals()


func _update_forest_visuals() -> void:
	if view != null:
		view.update_forest_visuals()


func _update_resource_node_visuals() -> void:
	if view != null:
		view.update_resource_node_visuals()


func _sync_all_presentations() -> void:
	if view != null:
		view.sync_all_presentations()


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
		"island_id": SpecialistDomain.ACTIVE_ISLAND_ID,
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
		"camp_vagrants_available": pop_mgr.camp_vagrants_available,
		"night_encounter": night_mgr.to_save_dict(),
		"research": research_mgr.to_save_dict(),
		"progression_flags": {
			"first_night_survived": night_mgr.first_night_survived,
			"collected_nodes": resource_mgr.get_collected_ids_array(),
			"node_states": resource_mgr.to_save_dict(),
			"tree_states": tree_mgr.to_save_dict(),
			"reign_state": _reign_state_to_string(reign_state),
			"hearth_level": hearth_sys.hearth_level,
			"hearth_boost_remaining": snappedf(hearth_sys.boost_remaining, 0.01),
			"shipwreck_stage": shipwreck_stage,
			"portal_relic_looted": portal_relic_looted,
			"shrine_offering_used_today": shrine_offering_used_today,
			"era_id": era_mgr.to_save_id(),
			"progression_facts": progression.to_save_array(),
		},
	}


func save_game_state(save_path: String = SaveManager.DEFAULT_SAVE_PATH) -> bool:
	var ok: bool = save_mgr.save_state(build_save_payload(), save_path)
	if ok:
		_last_saved_signature = _unsaved_signature()
	return ok


func _unsaved_signature() -> int:
	# Signature progres signifikan untuk deteksi "belum tersimpan". world_time
	# dikecualikan karena berubah setiap frame dan bukan progres yang hilang.
	var payload: Dictionary = build_save_payload()
	payload.erase("world_time")
	return payload.hash()


func has_unsaved_progress() -> bool:
	return _unsaved_signature() != _last_saved_signature


func load_game_state(save_path: String = SaveManager.DEFAULT_SAVE_PATH) -> bool:
	# The rollback verdict describes the CURRENT attempt only.
	_last_rollback_failure_reason = ""
	var res: Dictionary = save_mgr.load_state(save_path)
	if not bool(res.get("ok", false)):
		return false
	var data: Dictionary = res["data"]

	# Transaksional: snapshot state hidup saat ini SEBELUM ada mutasi. Jika
	# langkah apply mana pun gagal, seluruh snapshot dipulihkan sehingga sesi
	# tidak pernah berada di kondisi setengah-terpakai ("fresh reign" palsu).
	var snapshot: Dictionary = build_save_payload()
	if not _apply_loaded_payload(data):
		load_failed.emit("Failed to restore saved kingdom state — rolling back")
		# P0.2 + review round: a failing rollback used to be reported with a
		# SECOND load_failed emission, but the sole subscriber
		# (_record_rejection, FSS:208) is last-writer-wins — that second
		# emission silently OVERWROTE the original failure reason the message
		# above promises to keep standing. The repeated emission is therefore
		# gone: the rollback verdict is recorded in its own dedicated slot
		# (get_last_rollback_failure_reason()) while _last_rejection_reason
		# keeps the ORIGINAL load failure verbatim, and a successful rollback
		# stays silent (C1, 3C). The rollback-failure path itself IS
		# deterministically injectable at runtime — not via payload content
		# (the snapshot is valid by construction) but by placing an
		# apply-invalid value into the live session state before the snapshot
		# is taken; C4 (3C) covers it without any production test hook.
		if not _apply_loaded_payload(snapshot):
			_last_rollback_failure_reason = "Rollback failed — session state may be incomplete; the load failure reported above still stands"
		_sync_all_presentations()
		return false

	_sync_all_presentations()
	_last_saved_signature = _unsaved_signature()
	return true


func _apply_loaded_payload(data: Dictionary) -> bool:
	# Restore order: player -> progression flags -> encounter -> clock (silently,
	# no phase signals) -> economy -> buildings -> NPCs. Restoring the clock
	# before reign_state used to re-trigger night_started with a default
	# reign_state and spawn a phantom encounter.
	if player != null and data.has("player") and typeof(data["player"]) == TYPE_DICTIONARY:
		var p_dict: Dictionary = data["player"]
		var saved_px: float = float(p_dict.get("position_x", 0.0))
		player.global_position.x = clampf(saved_px, player.min_bound_x, player.max_bound_x)
		player.facing_direction = 1 if int(p_dict.get("facing_direction", 1)) >= 0 else -1
		set_actor_position("player_1", player.global_position.x)

	var flags: Dictionary = data["progression_flags"]
	night_mgr.first_night_survived = bool(flags.get("first_night_survived", night_mgr.first_night_survived))
	reign_state = _string_to_reign_state(flags.get("reign_state", "ACTIVE"))
	hearth_sys.apply_save_level(int(flags.get("hearth_level", 1)))
	hearth_sys.apply_save_boost(float(flags.get("hearth_boost_remaining", 0.0)))
	shipwreck_stage = clampi(int(flags.get("shipwreck_stage", 0)), 0, 3)
	portal_relic_looted = bool(flags.get("portal_relic_looted", false))
	shrine_offering_used_today = bool(flags.get("shrine_offering_used_today", false))
	# P0.2: the era restore bool is now inspected (it was ignored even though
	# apply_save_era is fail-closed). Missing/empty era_id stays tolerated —
	# migrate_payload backfills an inferred era for old saves before this point
	# (SaveManager.gd:233-240, owner policy) — but a present era_id that fails
	# to apply must fail the load instead of being silently dropped.
	var era_id: String = String(flags.get("era_id", ""))
	if era_id != "" and not era_mgr.apply_save_era(era_id):
		return false
	# Fakta progresi dipulihkan secara transaksional: payload invalid gagal
	# di sini tanpa mutasi parsial, sehingga rollback snapshot di pemanggil
	# tetap menjamin sesi tidak pernah berada di kondisi setengah-terpakai.
	if not progression.apply_save_state(flags.get("progression_facts", null)):
		return false
	if data.has("research"):
		if not research_mgr.apply_save_dict(data["research"]):
			return false
	else:
		# The optional "research" key is absent (legacy schema-v2 save): the
		# payload is the authority, so research resets to the empty state
		# instead of silently keeping the live session's research. An
		# explicitly present "research": null still fails the has() branch
		# above and is rejected by apply_save_dict.
		if not research_mgr.reset_to_empty_state():
			return false
	resource_mgr.apply_save_state(flags.get("node_states", null), flags.get("collected_nodes", []))
	tree_mgr.apply_save_state(flags.get("tree_states", null))

	if data.has("night_encounter") and typeof(data["night_encounter"]) == TYPE_DICTIONARY:
		if not night_mgr.apply_save_dict(data["night_encounter"]):
			return false

	if time_manager != null:
		if not time_manager.apply_save_dict(data, true):
			return false

	if not economy.set_balances_from_dict(data["resources"]):
		return false

	var b_arr: Array = data["buildings"]
	if not building_mgr.apply_save_array(b_arr):
		return false

	var n_arr: Array = data["npcs"]
	if not pop_mgr.apply_save_array(n_arr):
		return false
	if data.has("camp_vagrants_available"):
		pop_mgr.camp_vagrants_available = clampi(int(roundf(float(data["camp_vagrants_available"]))), 0, NPCPopulationManager.MAX_CAMP_VAGRANTS)
	for a: NPCBuilderAgent in pop_mgr.agents:
		_wire_follower_signals(a)
	_sync_follower_nodes()

	if time_manager != null:
		var is_unsafe: bool = time_manager.current_phase != TimeManager.Phase.DAYLIGHT
		pop_mgr.set_dusk_or_night_safety(is_unsafe, building_mgr)

	return true


func _consume_pending_load_if_requested() -> void:
	if Engine.has_meta("crownfall_load_on_start") and bool(Engine.get_meta("crownfall_load_on_start")):
		_loaded_from_save_on_start = true
		Engine.set_meta("crownfall_load_on_start", false)
		# N4.0 test isolation: when the menu's injected save path meta is set
		# (crownfall_menu_save_path, see Main.MENU_SAVE_PATH_META), Continue
		# loads from that same path instead of the default slot — the menu's
		# has_valid_save() check already validated it. In production the meta
		# is unset and the default player save slot applies (behavior
		# unchanged).
		var load_path: String = SaveManager.DEFAULT_SAVE_PATH
		if Engine.has_meta("crownfall_menu_save_path"):
			load_path = String(Engine.get_meta("crownfall_menu_save_path"))
		if load_game_state(load_path):
			feedback_message.emit("Loaded saved kingdom state from %s" % load_path)
		else:
			feedback_message.emit("Failed to load saved kingdom state — starting a fresh reign")
