class_name ShoreView
extends RefCounted

## Presentation-only extraction of the Forgotten Shore visual layer: forest,
## specialist and structure landmarks, NPC follower sprites, and the proximity
## prompt resolver. Holds no gameplay state — it reads the session's managers
## and writes only to scene nodes/labels. Gameplay decisions stay in
## ForgottenShoreSession.

var _s
var _tree_sprites: Dictionary = {}
var _tree_labels: Dictionary = {}
var _structure_sprites: Dictionary = {}
var _structure_labels: Dictionary = {}
var _follower_sprites: Dictionary = {}
var _active_target: Dictionary = {}
var _anim_clock: float = 0.0
var _prev_builder_x: float = NPCBuilderAgent.CAMP_POSITION_X
var _prev_wall_hp: int = 0
var _prev_enemy_hp: int = 0


func _init(session) -> void:
	_s = session


func setup_forest_visuals() -> void:
	var world_objs: Node = _s.get_node_or_null("WorldObjects")
	if world_objs == null or world_objs.get_node_or_null("ForestTrees") != null:
		return
	var root_forest: Node2D = Node2D.new()
	root_forest.name = "ForestTrees"
	root_forest.z_index = -1
	world_objs.add_child(root_forest)
	var tex_path: String = "res://assets/environment/vegetation/env_pine_tree_states.png"
	var tree_tex: Texture2D = load(tex_path) as Texture2D if ResourceLoader.exists(tex_path) else null
	for dx: float in [-1220.0, -1150.0, -860.0, -720.0, -540.0, 460.0, 610.0, 770.0, 880.0, 1120.0]:
		var bg_spr: Sprite2D = Sprite2D.new()
		bg_spr.position = Vector2(dx, 0.0)
		bg_spr.centered = false
		bg_spr.offset = Vector2(-24, -64)
		bg_spr.hframes = 2
		bg_spr.frame = 0
		bg_spr.scale = Vector2(0.85, 0.85)
		bg_spr.modulate = Color(0.68, 0.78, 0.74, 0.72)
		if tree_tex != null:
			bg_spr.texture = tree_tex
		root_forest.add_child(bg_spr)
	for tr: Dictionary in _s.tree_mgr.trees:
		var tid: String = String(tr["id"])
		var spr: Sprite2D = Sprite2D.new()
		spr.name = tid
		spr.position = Vector2(float(tr["x"]), 0.0)
		spr.centered = false
		spr.offset = Vector2(-24, -64)
		spr.hframes = 2
		spr.z_index = 1
		if tree_tex != null:
			spr.texture = tree_tex
		root_forest.add_child(spr)
		_tree_sprites[tid] = spr
		var lbl: Label = Label.new()
		lbl.visible = false
		lbl.position = Vector2(-56, -86)
		lbl.size = Vector2(112, 24)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.text = "[E] Chop (3/3)"
		spr.add_child(lbl)
		_tree_labels[tid] = lbl
	update_forest_visuals()


func update_forest_visuals() -> void:
	for tr: Dictionary in _s.tree_mgr.trees:
		var tid: String = String(tr["id"])
		var spr: Sprite2D = _tree_sprites.get(tid, null) as Sprite2D
		if spr != null:
			spr.frame = 1 if _s.tree_mgr.is_felled(tid) else 0


func setup_specialist_visuals() -> void:
	var world_objs: Node = _s.get_node_or_null("WorldObjects")
	if world_objs == null or world_objs.get_node_or_null("SpecialistCamp") != null:
		return
	var camp: Node2D = Node2D.new()
	camp.name = "SpecialistCamp"
	world_objs.add_child(camp)
	var tex_path: String = "res://assets/characters/npc/npc_builder_sheet.png"
	var npc_tex: Texture2D = load(tex_path) as Texture2D if ResourceLoader.exists(tex_path) else null
	for sp_id: String in _s.specialists.get_specialist_ids():
		var sp_def: Dictionary = _s.specialists.get_specialist_definition(sp_id)
		if String(sp_def.get("island_id", "")) != SpecialistDomain.ACTIVE_ISLAND_ID or not sp_def.has("world_x"):
			continue
		var wx: float = float(sp_def["world_x"])
		var spr: Sprite2D = Sprite2D.new()
		spr.name = "SpSprite_%s" % sp_id
		spr.position = Vector2(wx, 0.0)
		spr.centered = false
		spr.offset = Vector2(-16, -32)
		spr.hframes = 8
		spr.frame = 0
		spr.modulate = Color(0.62, 0.9, 0.82, 1.0)
		if npc_tex != null:
			spr.texture = npc_tex
		camp.add_child(spr)
		var lbl: Label = Label.new()
		lbl.name = "SpLabel_%s" % sp_id
		lbl.visible = false
		lbl.position = Vector2(wx - 56.0, -86.0)
		lbl.size = Vector2(112, 24)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		camp.add_child(lbl)
	var housing_plot: String = get_active_specialist_housing_plot_id()
	if not housing_plot.is_empty() and _s.building_mgr.has_plot(housing_plot):
		var hut_lbl: Label = Label.new()
		hut_lbl.name = "HutLabel"
		hut_lbl.visible = false
		hut_lbl.position = Vector2(float(_s.building_mgr.get_plot(housing_plot).get("position_x", 0.0)) - 70.0, -86.0)
		hut_lbl.size = Vector2(140, 24)
		hut_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		camp.add_child(hut_lbl)


func setup_structure_visuals() -> void:
	var world_objs: Node = _s.get_node_or_null("WorldObjects")
	if world_objs == null or world_objs.get_node_or_null("StructureLandmarks") != null:
		return
	var landmarks: Node2D = Node2D.new()
	landmarks.name = "StructureLandmarks"
	world_objs.add_child(landmarks)
	var tex_path: String = "res://assets/environment/landmarks/env_shrine_structure.png"
	var structure_tex: Texture2D = load(tex_path) as Texture2D if ResourceLoader.exists(tex_path) else null
	for st_id: String in _s.structures.get_structure_ids():
		var st_def: Dictionary = _s.structures.get_structure_definition(st_id)
		if String(st_def.get("island_id", "")) != SpecialistDomain.ACTIVE_ISLAND_ID or not st_def.has("world_x"):
			continue
		var spr: Sprite2D = Sprite2D.new()
		spr.name = "StSprite_%s" % st_id
		spr.position = Vector2(float(st_def["world_x"]), 0.0)
		spr.centered = false
		spr.offset = Vector2(-24, -48)
		spr.hframes = 2
		spr.frame = 0
		spr.z_index = 1
		if structure_tex != null:
			spr.texture = structure_tex
		landmarks.add_child(spr)
		_structure_sprites[st_id] = spr
		var lbl: Label = Label.new()
		lbl.name = "StLabel_%s" % st_id
		lbl.visible = false
		lbl.position = Vector2(float(st_def["world_x"]) - 64.0, -70.0)
		lbl.size = Vector2(128, 24)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		landmarks.add_child(lbl)
		_structure_labels[st_id] = lbl
	update_structure_visuals()


func update_structure_visuals() -> void:
	for st_id: String in _s.structures.get_structure_ids():
		var spr: Sprite2D = _structure_sprites.get(st_id, null) as Sprite2D
		if spr != null:
			spr.frame = 1 if _s.structures.is_activated(st_id, _s.progression) else 0


func sync_follower_nodes() -> void:
	var container: Node = _s.get_node_or_null("WorldObjects/NPCFollowers")
	if container == null:
		return
	for i: int in range(1, _s.pop_mgr.agents.size()):
		var agent: NPCBuilderAgent = _s.pop_mgr.agents[i]
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


func get_active_specialist_housing_plot_id() -> String:
	for sp_id: String in _s.specialists.get_specialist_ids():
		var sp_def: Dictionary = _s.specialists.get_specialist_definition(sp_id)
		if String(sp_def.get("island_id", "")) != SpecialistDomain.ACTIVE_ISLAND_ID:
			continue
		var housing: String = String(sp_def.get("housing_plot_id", ""))
		if not housing.is_empty():
			return housing
	return ""


func update_proximity_prompts() -> void:
	if _s.player == null:
		return
	var px: float = _s.player.global_position.x
	_active_target = _s._resolve_target_for_actor(px) as Dictionary
	var active_kind: String = String(_active_target.get("kind", ""))
	var active_id: String = String(_active_target.get("target_id", ""))
	var highlight_col: Color = Color(1.0, 0.95, 0.55, 1.0)
	var normal_col: Color = Color(1.0, 1.0, 1.0, 1.0)

	# Show ONLY the single active resolved prompt (plus live build/damage status)
	for n: Dictionary in _s.resource_mgr.nodes:
		var nid: String = String(n["id"])
		var lbl: Label = _s.get_node_or_null("WorldObjects/ResourceNodes/%s/Label" % nid) as Label
		if lbl != null:
			var is_active: bool = (active_kind == "resource" and active_id == nid)
			lbl.visible = is_active and not _s.resource_mgr.is_collected(nid)
			lbl.modulate = highlight_col if is_active else normal_col

	if _s.npc_label != null and not _s.builder_npc.recruited:
		var camp_active: bool = (active_kind == "camp")
		_s.npc_label.visible = camp_active
		_s.npc_label.modulate = highlight_col if camp_active else normal_col

	for plot_id: String in [BuildingManager.WALL_ID, BuildingManager.WEST_WALL_ID, BuildingManager.WATCHTOWER_ID, BuildingManager.FARM_WEST_ID, BuildingManager.FARM_EAST_ID]:
		var nodes: Dictionary = get_plot_nodes(plot_id)
		if nodes.is_empty():
			continue
		var lbl: Label = nodes["label"] as Label
		if lbl == null or not _s.building_mgr.has_plot(plot_id):
			continue
		var plot: Dictionary = _s.building_mgr.get_plot(plot_id)
		var st: int = int(plot["state"])
		var is_active_plot: bool = (active_kind == "building" and active_id == plot_id)
		lbl.visible = is_active_plot or st == BuildingManager.WallState.UNDER_CONSTRUCTION or st == BuildingManager.WallState.DAMAGED
		lbl.modulate = highlight_col if is_active_plot else normal_col

	var ship_lbl: Label = _s.get_node_or_null("WorldObjects/ShipwreckAnchor/ShipLabel") as Label
	if ship_lbl != null:
		ship_lbl.visible = (active_kind == "shipwreck")
		ship_lbl.modulate = highlight_col if ship_lbl.visible else normal_col

	var portal_lbl: Label = _s.get_node_or_null("WorldObjects/GreedPortalAnchor/PortalLabel") as Label
	if portal_lbl != null:
		portal_lbl.visible = (active_kind == "portal")
		portal_lbl.modulate = highlight_col if portal_lbl.visible else normal_col

	for tr: Dictionary in _s.tree_mgr.trees:
		var tid: String = String(tr["id"])
		var t_lbl: Label = _tree_labels.get(tid, null) as Label
		if t_lbl != null:
			var is_tree_active: bool = (active_kind == "tree" and active_id == tid)
			t_lbl.visible = is_tree_active and not _s.tree_mgr.is_felled(tid)
			t_lbl.text = "[E] Chop (%d/%d)" % [_s.tree_mgr.get_hp(tid), int(tr["max_hp"])]
			t_lbl.modulate = highlight_col if is_tree_active else normal_col

	var has_archer: bool = false
	for a: NPCBuilderAgent in _s.pop_mgr.agents:
		if a.recruited and a.role == "archer":
			has_archer = true
			break
	for sid: String in NPCPopulationManager.TOOL_STANDS.keys():
		var lbl: Label = _s.get_node_or_null("WorldObjects/ToolStands/%s/Label" % sid) as Label
		if lbl != null:
			if sid == "bow_stand":
				lbl.text = "[E] Archer (1G 1W)" if has_archer else "[E] Archer (Free 1st)"
			var is_stand: bool = (active_kind == "tool_stand" and active_id == sid)
			lbl.visible = is_stand
			lbl.modulate = highlight_col if is_stand else normal_col

	# Phase 3 specialist prompts: the resolved specialist prompt plus the
	# scientist housing plot status label (presentation only).
	var sp_camp: Node = _s.get_node_or_null("WorldObjects/SpecialistCamp")
	if sp_camp != null:
		for sp_id2: String in _s.specialists.get_specialist_ids():
			var sp_lbl: Label = sp_camp.get_node_or_null("SpLabel_%s" % sp_id2) as Label
			if sp_lbl != null:
				var is_sp: bool = (active_kind == "specialist" and active_id == sp_id2)
				sp_lbl.visible = is_sp
				sp_lbl.modulate = highlight_col if is_sp else normal_col
				sp_lbl.text = String(_active_target.get("prompt_text", "")) if is_sp else ""
		if active_kind == "research":
			var provider: String = String(_active_target.get("provider_id", ""))
			var prov_lbl: Label = sp_camp.get_node_or_null("SpLabel_%s" % provider) as Label
			if prov_lbl != null:
				prov_lbl.visible = true
				prov_lbl.modulate = highlight_col
				prov_lbl.text = String(_active_target.get("prompt_text", ""))
		var hut_id: String = get_active_specialist_housing_plot_id()
		var hut_lbl2: Label = sp_camp.get_node_or_null("HutLabel") as Label
		if hut_lbl2 != null and _s.building_mgr.has_plot(hut_id):
			var plot: Dictionary = _s.building_mgr.get_plot(hut_id)
			var st: int = int(plot["state"])
			var is_hut_active: bool = (active_kind == "building" and active_id == hut_id)
			hut_lbl2.visible = is_hut_active or st == BuildingManager.WallState.UNDER_CONSTRUCTION
			hut_lbl2.modulate = highlight_col if is_hut_active else normal_col
			var hut_title: String = _s.building_mgr.get_plot_title(hut_id)
			if st == BuildingManager.WallState.PLACEHOLDER or st == BuildingManager.WallState.DESTROYED:
				hut_lbl2.text = "%s [E/B]\n%s" % [hut_title, _s.building_mgr.get_plot_cost_label(hut_id)]
			elif st == BuildingManager.WallState.UNDER_CONSTRUCTION:
				hut_lbl2.text = "Building %s...\n%d%%" % [hut_title, int(roundf(float(plot["progress"]) * 100.0))]
			elif st == BuildingManager.WallState.DAMAGED:
				hut_lbl2.text = "Damaged %s [E/F]\nHP %d/%d" % [hut_title, int(plot["durability"]), int(plot["max_durability"])]
			else:
				hut_lbl2.text = hut_title

	# Phase 5 structure prompts: show only the resolved structure's prompt.
	for st_id2: String in _s.structures.get_structure_ids():
		var st_lbl: Label = _structure_labels.get(st_id2, null) as Label
		if st_lbl != null:
			var is_st: bool = (active_kind == "structure" and active_id == st_id2)
			st_lbl.visible = is_st
			st_lbl.modulate = highlight_col if is_st else normal_col
			st_lbl.text = String(_active_target.get("prompt_text", "")) if is_st else ""


func sync_resource_prompts_from_data() -> void:
	for n: Dictionary in _s.resource_mgr.nodes:
		var lbl: Label = _s.get_node_or_null("WorldObjects/ResourceNodes/%s/Label" % String(n["id"])) as Label
		if lbl != null and n.has("prompt"):
			lbl.text = String(n["prompt"])


func sync_hearth_visuals() -> void:
	var light: PointLight2D = _s.get_node_or_null("WorldObjects/TownCenterAnchor/CampfireLight") as PointLight2D
	if light != null:
		light.texture_scale = _s.hearth_sys.get_effective_texture_scale()
	var t_lbl: Label = _s.get_node_or_null("WorldObjects/TownCenterAnchor/TownLabel") as Label
	if t_lbl != null:
		if _s.hearth_sys.hearth_level == 1:
			t_lbl.text = "Town Center (Hearth Lv.1)\n[E] Stoke (1W) | [Q] Beacon Lv2: 4G 4W 2S"
		elif _s.hearth_sys.hearth_level == 2:
			t_lbl.text = "Town Center (Hearth Lv.2)\n[E] Stoke (1W) | [Q] Solar Lv3: 6G 5W 4S"
		else:
			t_lbl.text = "Town Center (Solar Brazier Lv.3)\n[E] Stoke (1W)"


func get_plot_nodes(plot_id: String) -> Dictionary:
	var node_refs: Dictionary = {}
	match plot_id:
		BuildingManager.WALL_ID:
			node_refs = {"sprite": _s.wall_visual, "label": _s.wall_label}
		BuildingManager.WEST_WALL_ID:
			node_refs = {"sprite": _s.get_node_or_null("WorldObjects/WestWallPlot/WallVisual") as Sprite2D, "label": _s.get_node_or_null("WorldObjects/WestWallPlot/WallLabel") as Label}
		BuildingManager.WATCHTOWER_ID:
			node_refs = {
				"sprite": _s.get_node_or_null("WorldObjects/WatchtowerPlot/WatchtowerVisual") as Sprite2D,
				"label": _s.get_node_or_null("WorldObjects/WatchtowerPlot/WatchtowerLabel") as Label,
			}
		BuildingManager.FARM_WEST_ID:
			node_refs = {
				"sprite": _s.get_node_or_null("WorldObjects/FarmWestPlot/FarmVisual") as Sprite2D,
				"label": _s.get_node_or_null("WorldObjects/FarmWestPlot/FarmLabel") as Label,
			}
		BuildingManager.FARM_EAST_ID:
			node_refs = {
				"sprite": _s.get_node_or_null("WorldObjects/FarmEastPlot/FarmVisual") as Sprite2D,
				"label": _s.get_node_or_null("WorldObjects/FarmEastPlot/FarmLabel") as Label,
			}
		_:
			return {}
	node_refs["title"] = _s.building_mgr.get_plot_title(plot_id)
	node_refs["cost"] = _s.building_mgr.get_plot_cost_label(plot_id)
	return node_refs


func sync_plot_label_data() -> void:
	for plot_id: String in _s.building_mgr.get_all_plot_ids():
		var nodes: Dictionary = get_plot_nodes(plot_id)
		if nodes.is_empty():
			continue
		var lbl: Label = nodes["label"] as Label
		if lbl == null:
			continue
		var plot: Dictionary = _s.building_mgr.get_plot(plot_id)
		if int(plot.get("state", 0)) == BuildingManager.WallState.PLACEHOLDER:
			lbl.text = "%s [E/B]\n%s" % [String(nodes["title"]), String(nodes["cost"])]


func on_wall_state_changed(wall_id: String, new_state: String, progress: float, durability: int, max_dur: int) -> void:
	var nodes: Dictionary = get_plot_nodes(wall_id)
	if nodes.is_empty():
		return
	var spr: Sprite2D = nodes["sprite"] as Sprite2D
	var lbl: Label = nodes["label"] as Label
	if spr == null or lbl == null:
		return
	var plot: Dictionary = _s.building_mgr.get_plot(wall_id)
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
				lbl.text = "Wooden Wall [Q: Stone Lv2]\nHP %d/%d (%s)" % [durability, max_dur, _s.building_mgr.get_plot_upgrade_cost_label(wall_id)]
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


func on_npc_state_changed(_npc_id: String, _role: String, state_name: String, pos_x: float) -> void:
	if _s.npc_visual != null:
		_s.npc_visual.position.x = pos_x
	if _s.npc_label != null:
		if not _s.builder_npc.recruited:
			_s.npc_label.text = "Vagrant [E/R: 2G]"
		else:
			match state_name:
				"WORKING":
					_s.npc_label.text = "Builder: Working"
				"RETURNING_TO_SAFETY":
					_s.npc_label.text = "Retreating!"
				_:
					_s.npc_label.text = ""
			_s.npc_label.visible = not _s.npc_label.text.is_empty()


func build_population_summary() -> String:
	var role_counts: Dictionary = {}
	var idle: int = 0
	var recruited: int = 0
	for a: NPCBuilderAgent in _s.pop_mgr.agents:
		if not a.recruited:
			continue
		recruited += 1
		role_counts[a.role] = int(role_counts.get(a.role, 0)) + 1
		if a.state == NPCBuilderAgent.State.IDLE:
			idle += 1
	var parts: Array[String] = []
	for role_name: String in ["builder", "farmer", "archer", "villager"]:
		if role_counts.has(role_name):
			parts.append("%d %s" % [int(role_counts[role_name]), role_name.capitalize()])
	var detail: String = ", ".join(parts) if not parts.is_empty() else "none"
	return "NPCs: %d (%s) | Idle: %d | Vagrants: %d" % [recruited, detail, idle, _s.pop_mgr.camp_vagrants_available]


func update_resource_node_visuals() -> void:
	var nodes_root: Node = _s.get_node_or_null("WorldObjects/ResourceNodes")
	if nodes_root == null:
		return
	for n: Dictionary in _s.resource_mgr.nodes:
		var node_id: String = String(n["id"])
		var marker: CanvasItem = nodes_root.get_node_or_null(node_id) as CanvasItem
		if marker != null:
			marker.modulate.a = 0.25 if _s.resource_mgr.is_collected(node_id) else 1.0


func advance_and_sync(delta: float) -> void:
	_anim_clock += delta
	_sync_dynamic_actors()


func _sync_dynamic_actors() -> void:
	if _s.town_center_sprite != null:
		_s.town_center_sprite.frame = int(floorf(_anim_clock * 6.0)) % 4

	if _s.npc_visual != null:
		_s.npc_visual.position.x = _s.builder_npc.position_x
		if _s.builder_sprite != null:
			var dx: float = _s.builder_npc.position_x - _prev_builder_x
			if absf(dx) > 0.05:
				_s.builder_sprite.flip_h = dx < 0.0
			_prev_builder_x = _s.builder_npc.position_x
			if _s.builder_npc.state == NPCBuilderAgent.State.WORKING:
				_s.builder_sprite.frame = 4 + (int(floorf(_anim_clock * 8.0)) % 4)
			elif _s.builder_npc.state == NPCBuilderAgent.State.MOVING_TO_TASK or _s.builder_npc.state == NPCBuilderAgent.State.RETURNING_TO_SAFETY:
				_s.builder_sprite.frame = int(floorf(_anim_clock * 8.0)) % 4
			else:
				_s.builder_sprite.frame = 0

	if _s.enemy_visual != null:
		_s.enemy_visual.visible = _s.night_mgr.enemy_active
		_s.enemy_visual.position.x = _s.night_mgr.enemy_x
		if _s.enemy_sprite != null and _s.night_mgr.enemy_active:
			_s.enemy_sprite.frame = int(floorf(_anim_clock * 8.0)) % 4
			if _s.night_mgr.enemy_archetype == "brute":
				_s.enemy_sprite.scale = Vector2(1.45, 1.45)
				_s.enemy_sprite.modulate = Color(0.85, 0.65, 1.0, 1.0)
			elif _s.night_mgr.enemy_archetype == "crawler":
				_s.enemy_sprite.scale = Vector2(0.9, 0.85)
				_s.enemy_sprite.modulate = Color(1.0, 0.75, 0.75, 1.0)
			else:
				_s.enemy_sprite.scale = Vector2(1.0, 1.0)
				_s.enemy_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if _s.slice_hud != null and _s.slice_hud.has_method("set_forecast_text"):
		var day_n: int = _s.time_manager.current_day if _s.time_manager != null else 1
		if _s.night_mgr.enemy_active or _s.night_mgr.west_enemy_active:
			var alert: String = "ALERT: %s (%d/%d HP) at x=%.0f" % [_s.night_mgr.get_enemy_display_name(), _s.night_mgr.enemy_hp, _s.night_mgr.enemy_max_hp, _s.night_mgr.enemy_x] if _s.night_mgr.enemy_active else "ALERT: Greedling raiders inbound!"
			if _s.night_mgr.west_enemy_active:
				alert += " | West Scout (%d/%d HP) at x=%.0f" % [_s.night_mgr.west_enemy_hp, _s.night_mgr.west_enemy_max_hp, _s.night_mgr.west_enemy_x]
			_s.slice_hud.call("set_forecast_text", alert)
		else:
			_s.slice_hud.call("set_forecast_text", NightEncounterManager.get_night_forecast(day_n))

	if _s.slice_hud != null and _s.slice_hud.has_method("set_population_text"):
		_s.slice_hud.call("set_population_text", build_population_summary())

	if _s.slice_hud != null and _s.slice_hud.has_method("set_research_text"):
		_s.slice_hud.call("set_research_text", _s.research_mgr.get_hud_text(_s.progression))

	if _s.slice_hud != null and _s.slice_hud.has_method("set_structures_text"):
		_s.slice_hud.call("set_structures_text", _s.structures.get_hud_text(_s.progression))

	if _s.building_mgr.durability < _prev_wall_hp and _prev_wall_hp > 0:
		_s._play_sfx("sfx_hit")
		var restore_wall: Color = Color(1.0, 0.85, 0.85, 1.0) if _s.building_mgr.state == BuildingManager.WallState.DAMAGED else Color(1.0, 1.0, 1.0, 1.0)
		_s._flash_sprite(_s.wall_visual, Color(2.0, 1.2, 1.2, 1.0), restore_wall)
		_s._trigger_camera_shake(4.0, 0.14)
	_prev_wall_hp = _s.building_mgr.durability

	if _s.night_mgr.enemy_active and _s.night_mgr.enemy_hp < _prev_enemy_hp and _prev_enemy_hp > 0:
		_s._flash_sprite(_s.enemy_sprite)
	_prev_enemy_hp = _s.night_mgr.enemy_hp if _s.night_mgr.enemy_active else 0

	var west_actor: Node2D = _s.get_node_or_null("WorldObjects/WestEnemyActor") as Node2D
	if west_actor != null:
		west_actor.visible = _s.night_mgr.west_enemy_active
		west_actor.position.x = _s.night_mgr.west_enemy_x

	sync_follower_nodes()
	update_proximity_prompts()


func sync_all_presentations() -> void:
	for plot_id: String in _s.building_mgr.get_all_plot_ids():
		var p: Dictionary = _s.building_mgr.get_plot(plot_id)
		on_wall_state_changed(
			plot_id,
			_s.building_mgr.get_state_name(plot_id),
			float(p["progress"]),
			int(p["durability"]),
			int(p["max_durability"])
		)
	on_npc_state_changed(
		NPCBuilderAgent.NPC_ID,
		_s.builder_npc.role,
		_s.builder_npc.get_state_name(),
		_s.builder_npc.position_x
	)
	sync_hearth_visuals()
	_s._sync_landmark_visuals()
	update_resource_node_visuals()
	update_forest_visuals()
	update_structure_visuals()
	_sync_dynamic_actors()
	if _s.slice_hud != null and _s.slice_hud.has_method("_refresh_clock"):
		_s.slice_hud.call("_refresh_clock")
