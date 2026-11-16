class_name InteractionResolver
extends RefCounted


static func resolve_nearest(
	actor_x: float,
	resource_mgr: ResourceNodeManager,
	building_mgr: BuildingManager,
	pop_mgr: NPCPopulationManager,
	hearth_sys: HearthSystem,
	shipwreck_stage: int,
	shipwreck_x: float,
	portal_x: float,
	portal_looted: bool,
	shrine_offering_used: bool = false,
	tree_mgr: ForestTreeManager = null,
	specialist_domain: SpecialistDomain = null,
	progression: ProgressionState = null,
	research_mgr: ResearchManager = null
) -> Dictionary:
	var best: Dictionary = {
		"has_target": false,
		"kind": "",
		"target_id": "",
		"primary_command": &"",
		"upgrade_command": &"",
		"prompt_text": "",
		"distance": INF,
	}

	# 1. Resource nodes
	if resource_mgr != null:
		var n: Dictionary = resource_mgr.find_nearest_available(actor_x, ResourceNodeManager.INTERACT_RANGE)
		if not n.is_empty():
			var d: float = absf(actor_x - float(n["x"]))
			if d < float(best["distance"]):
				best = {
					"has_target": true,
					"kind": "resource",
					"target_id": String(n["id"]),
					"primary_command": &"collect",
					"upgrade_command": &"",
					"prompt_text": String(n.get("prompt", "[E] Collect")),
					"distance": d,
				}


	# 1b. Shrine Offering (4W + 2S -> +2G, 1x/day after shrine_cache_far_west is collected)
	if resource_mgr != null and resource_mgr.is_collected("shrine_cache_far_west") and not shrine_offering_used:
		var d_shrine: float = absf(actor_x - (-780.0))
		if d_shrine <= ResourceNodeManager.INTERACT_RANGE and d_shrine < float(best["distance"]):
			best = {
				"has_target": true,
				"kind": "shrine_offering",
				"target_id": "shrine_cache_far_west",
				"primary_command": &"shrine_offering",
				"upgrade_command": &"",
				"prompt_text": "[E] Shrine Offering (4W 2S -> +2G)",
				"distance": d_shrine,
			}

	# 2. Tool Stands
	if pop_mgr != null:
		var sid: String = pop_mgr.get_nearest_tool_stand(actor_x)
		if not sid.is_empty():
			var sx: float = float((NPCPopulationManager.TOOL_STANDS[sid] as Dictionary)["x"])
			var d_stand: float = absf(actor_x - sx)
			if d_stand < float(best["distance"]):
				best = {
					"has_target": true,
					"kind": "tool_stand",
					"target_id": sid,
					"primary_command": &"assign_tool",
					"upgrade_command": &"",
					"prompt_text": "[E] Assign %s" % String((NPCPopulationManager.TOOL_STANDS[sid] as Dictionary)["role"]).capitalize(),
					"distance": d_stand,
				}

	# 3. Vagrant Camp
	if pop_mgr != null and pop_mgr.camp_vagrants_available > 0:
		var d_camp: float = absf(actor_x - NPCBuilderAgent.CAMP_POSITION_X)
		if d_camp <= 90.0 and d_camp < float(best["distance"]):
			best = {
				"has_target": true,
				"kind": "camp",
				"target_id": "vagrant_camp",
				"primary_command": &"recruit",
				"upgrade_command": &"",
				"prompt_text": "Vagrant [E/R: 2G]",
				"distance": d_camp,
			}

	# 4. Building Plots (pilih plot terdekat yang benar-benar punya aksi aktif)
	if building_mgr != null:
		var pid: String = building_mgr.get_nearest_actionable_plot_id(actor_x, BuildingManager.INTERACT_RANGE, "any")
		if not pid.is_empty():
			var plot: Dictionary = building_mgr.get_plot(pid)
			var d_plot: float = absf(actor_x - float(plot["position_x"]))
			var st: int = int(plot["state"])
			var p_cmd: StringName = &""
			var u_cmd: StringName = &""
			if st == BuildingManager.WallState.PLACEHOLDER or st == BuildingManager.WallState.DESTROYED:
				p_cmd = &"build"
			elif st == BuildingManager.WallState.DAMAGED:
				p_cmd = &"repair"
			if building_mgr.can_upgrade_wall(actor_x, pid):
				u_cmd = &"upgrade_building"
			if (not String(p_cmd).is_empty() or not String(u_cmd).is_empty()) and d_plot < float(best["distance"]):
				best = {
					"has_target": true,
					"kind": "building",
					"target_id": pid,
					"primary_command": p_cmd,
					"upgrade_command": u_cmd,
					"prompt_text": pid,
					"distance": d_plot,
				}

	# 5. Shipwreck & Greed Portal
	var d_ship: float = absf(actor_x - shipwreck_x)
	if d_ship <= 96.0 and d_ship < float(best["distance"]):
		best = {
			"has_target": true,
			"kind": "shipwreck",
			"target_id": "shipwreck",
			"primary_command": &"shipwreck",
			"upgrade_command": &"",
			"prompt_text": "Vessel Ready! [E] Set Sail" if shipwreck_stage >= 3 else "Shipwreck [E] Stage %d/3" % (shipwreck_stage + 1),
			"distance": d_ship,
		}

	if not portal_looted:
		var d_port: float = absf(actor_x - portal_x)
		if d_port <= 96.0 and d_port < float(best["distance"]):
			best = {
				"has_target": true,
				"kind": "portal",
				"target_id": "greed_portal",
				"primary_command": &"loot_portal",
				"upgrade_command": &"",
				"prompt_text": "Greed Portal [E]",
				"distance": d_port,
			}

	# 5a. Specialists (Phase 3): discover / recruit the active-island roster.
	# Recruited specialists do not offer a primary interaction here; the
	# Scientist's research interaction belongs to the research phase and the
	# hut build/repair prompt comes from the building block above.
	if specialist_domain != null and progression != null and building_mgr != null:
		for sp_id: String in specialist_domain.get_specialist_ids():
			var sp_def: Dictionary = specialist_domain.get_specialist_definition(sp_id)
			if String(sp_def.get("island_id", "")) != SpecialistDomain.ACTIVE_ISLAND_ID:
				continue
			if not sp_def.has("world_x"):
				continue
			var d_sp: float = absf(actor_x - float(sp_def["world_x"]))
			if d_sp > SpecialistDomain.INTERACT_RANGE or d_sp >= float(best["distance"]):
				continue
			var sp_name: String = String(sp_def.get("display_name", sp_id))
			var lifecycle: String = specialist_domain.get_lifecycle_state(sp_id, progression, building_mgr)
			if lifecycle == SpecialistDomain.STATE_UNDISCOVERED:
				best = {
					"has_target": true,
					"kind": "specialist",
					"target_id": sp_id,
					"primary_command": &"discover_specialist",
					"upgrade_command": &"",
					"prompt_text": "[E] Speak to the Shipwrecked Stranger",
					"distance": d_sp,
				}
			elif lifecycle == SpecialistDomain.STATE_RECRUITABLE:
				best = {
					"has_target": true,
					"kind": "specialist",
					"target_id": sp_id,
					"primary_command": &"recruit_specialist",
					"upgrade_command": &"",
					"prompt_text": "[E] Recruit %s (%s)" % [sp_name, BuildingManager.format_cost_text(specialist_domain.get_recruitment_cost(sp_id))],
					"distance": d_sp,
				}
			elif lifecycle == SpecialistDomain.STATE_RECRUITED and research_mgr != null and research_mgr.has_active_research() == false:
				# Phase 4: a recruited specialist provides research. Offer the
				# first available technology in stable ID order; the tech ID is
				# the interaction target and the specialist stays the provider.
				var next_tech: String = research_mgr.get_first_available_technology_id(progression)
				if not next_tech.is_empty():
					var tech_def: Dictionary = research_mgr.get_technology_definition(next_tech)
					best = {
						"has_target": true,
						"kind": "research",
						"target_id": next_tech,
						"primary_command": &"start_research",
						"upgrade_command": &"",
						"prompt_text": "[E] Research %s (%s)" % [String(tech_def.get("display_name", next_tech)), BuildingManager.format_cost_text(tech_def.get("cost", {}) as Dictionary)],
						"distance": d_sp,
						"provider_id": sp_id,
					}

	# 5b. Forest Trees ([E] Chop)
	if tree_mgr != null:
		var tr: Dictionary = tree_mgr.find_nearest_standing(actor_x, ForestTreeManager.INTERACT_RANGE)
		if not tr.is_empty():
			var tid: String = String(tr["id"])
			var d_tree: float = absf(actor_x - float(tr["x"]))
			if d_tree < float(best["distance"]):
				best = {
					"has_target": true,
					"kind": "tree",
					"target_id": tid,
					"primary_command": &"chop_tree",
					"upgrade_command": &"",
					"prompt_text": "[E] Chop Tree (%d/%d)" % [tree_mgr.get_hp(tid), int(tr["max_hp"])],
					"distance": d_tree,
				}

	# 6. Town Center Hearth ([E] Stoke Fire, [Q] Upgrade)
	if hearth_sys != null:
		var d_hearth: float = absf(actor_x - HearthSystem.HEARTH_POSITION_X)
		if d_hearth <= HearthSystem.INTERACT_RANGE:
			var u_cmd: StringName = &"upgrade_hearth" if hearth_sys.can_upgrade() else &""
			if d_hearth < float(best["distance"]):
				var prompt: String = "Hearth [E] Stoke Fire (1W)"
				if hearth_sys.can_upgrade():
					prompt += " | [Q] Upgrade"
				best = {
					"has_target": true,
					"kind": "hearth",
					"target_id": "town_hearth",
					"primary_command": &"boost_hearth",
					"upgrade_command": u_cmd,
					"prompt_text": prompt,
					"distance": d_hearth,
				}

	return best
