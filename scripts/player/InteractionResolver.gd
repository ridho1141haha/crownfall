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
	portal_looted: bool
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

	# 4. Building Plots (Watchtower x=210, Wall x=380, Farms x=-310/120)
	if building_mgr != null:
		var pid: String = building_mgr.get_nearest_plot_id(actor_x, BuildingManager.INTERACT_RANGE)
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

	# 6. Town Center Hearth Upgrade ([Q])
	if hearth_sys != null and hearth_sys.can_upgrade():
		var d_hearth: float = absf(actor_x - HearthSystem.HEARTH_POSITION_X)
		if d_hearth <= HearthSystem.INTERACT_RANGE and d_hearth < float(best["distance"]):
			best = {
				"has_target": true,
				"kind": "hearth",
				"target_id": "town_hearth",
				"primary_command": &"upgrade_hearth",
				"upgrade_command": &"upgrade_hearth",
				"prompt_text": "Hearth [Q] Upgrade",
				"distance": d_hearth,
			}

	return best
