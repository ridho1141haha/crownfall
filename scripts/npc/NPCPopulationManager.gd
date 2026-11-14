class_name NPCPopulationManager
extends RefCounted

signal roster_changed()
signal population_action_rejected(reason: String)

const MAX_POPULATION: int = 6
const MAX_CAMP_VAGRANTS: int = 2
const STAND_RANGE: float = 64.0

const TOOL_STANDS: Dictionary = {
	"hammer_stand": {"x": -45.0, "role": "builder", "cost": {}},
	"scythe_stand": {"x": -90.0, "role": "farmer", "cost": {"gold": 1, "stone": 1}},
	"bow_stand": {"x": 45.0, "role": "archer", "cost": {"gold": 1, "wood": 1}},
}

var agents: Array[NPCBuilderAgent] = []
var camp_vagrants_available: int = 1


func _init() -> void:
	var primary: NPCBuilderAgent = NPCBuilderAgent.new(NPCBuilderAgent.NPC_ID)
	agents.append(primary)


func get_primary_agent() -> NPCBuilderAgent:
	return agents[0]


func get_recruited_count() -> int:
	var count: int = 0
	for a: NPCBuilderAgent in agents:
		if a.recruited:
			count += 1
	return count


func on_sunrise_refill() -> void:
	if get_recruited_count() + camp_vagrants_available < MAX_POPULATION:
		camp_vagrants_available = mini(MAX_CAMP_VAGRANTS, camp_vagrants_available + 1)


func recruit_next_vagrant(player_x: float, ledger: EconomyLedger) -> NPCBuilderAgent:
	# Preserve M8 single-player slice behavior: first recruit npc_01 directly as builder
	var primary: NPCBuilderAgent = agents[0]
	if not primary.recruited:
		if primary.request_recruit(player_x, ledger, "builder"):
			camp_vagrants_available = maxi(0, camp_vagrants_available - 1)
			roster_changed.emit()
			return primary
		return null

	if get_recruited_count() >= MAX_POPULATION:
		population_action_rejected.emit("Kingdom population cap (%d) reached" % MAX_POPULATION)
		return null
	if camp_vagrants_available <= 0:
		population_action_rejected.emit("No Vagrants at Camp right now (refills at Sunrise)")
		return null

	var next_id: String = "npc_%02d" % (agents.size() + 1)
	var newcomer: NPCBuilderAgent = NPCBuilderAgent.new(next_id)
	if newcomer.request_recruit(player_x, ledger, "villager"):
		agents.append(newcomer)
		camp_vagrants_available = maxi(0, camp_vagrants_available - 1)
		roster_changed.emit()
		return newcomer
	return null


func get_nearest_tool_stand(player_x: float) -> String:
	var best_id: String = ""
	var best_dist: float = STAND_RANGE + 0.001
	for sid: String in TOOL_STANDS.keys():
		var sx: float = float((TOOL_STANDS[sid] as Dictionary)["x"])
		var dist: float = absf(player_x - sx)
		if dist < best_dist:
			best_dist = dist
			best_id = sid
	return best_id


func assign_tool_stand(stand_id: String, ledger: EconomyLedger, building_mgr: BuildingManager) -> NPCBuilderAgent:
	if not TOOL_STANDS.has(stand_id) or ledger == null:
		return null
	var idle_villager: NPCBuilderAgent = null
	for a: NPCBuilderAgent in agents:
		if a.recruited and a.role == "villager":
			idle_villager = a
			break
	if idle_villager == null:
		population_action_rejected.emit("Recruit a Villager at Vagrant Camp [R: 2G] first!")
		return null

	var stand: Dictionary = TOOL_STANDS[stand_id] as Dictionary
	var cost: Dictionary = stand["cost"] as Dictionary
	if not cost.is_empty() and not ledger.try_spend(cost):
		population_action_rejected.emit("Insufficient resources for %s" % stand_id)
		return null

	idle_villager.set_role(String(stand["role"]), building_mgr)
	roster_changed.emit()
	return idle_villager


func set_dusk_or_night_safety(is_unsafe: bool, building_mgr: BuildingManager) -> void:
	for a: NPCBuilderAgent in agents:
		a.set_dusk_or_night_safety(is_unsafe, building_mgr)


func tick_all(delta: float, building_mgr: BuildingManager, night_mgr: NightEncounterManager) -> void:
	for a: NPCBuilderAgent in agents:
		a.tick(delta, building_mgr, night_mgr)


func to_save_array() -> Array[Dictionary]:
	var arr: Array[Dictionary] = []
	for a: NPCBuilderAgent in agents:
		arr.append(a.to_save_dict())
	return arr


func apply_save_array(npcs_arr: Array) -> bool:
	if npcs_arr.is_empty() or agents.is_empty():
		return false
	var staged_agents: Array[NPCBuilderAgent] = []
	for i: int in range(npcs_arr.size()):
		var raw: Variant = npcs_arr[i]
		if typeof(raw) != TYPE_DICTIONARY:
			return false
		var d: Dictionary = raw as Dictionary
		var probe: NPCBuilderAgent = NPCBuilderAgent.new(String(d.get("id", "npc_%02d" % (i + 1))))
		if not probe.apply_save_dict(d):
			return false
		staged_agents.append(probe)
	var primary: NPCBuilderAgent = agents[0]
	if not primary.apply_save_dict(npcs_arr[0] as Dictionary):
		return false
	agents.clear()
	agents.append(primary)
	for i: int in range(1, staged_agents.size()):
		agents.append(staged_agents[i])
	roster_changed.emit()
	return true
