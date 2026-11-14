class_name ResourceNodeManager
extends RefCounted

signal node_collected(node_id: String, resource_id: StringName, amount: int)
signal renewable_nodes_refreshed(refreshed_ids: Array[String])

const INTERACT_RANGE: float = 72.0
const DEFAULT_NODES: Array[Dictionary] = [
	{"id": "cache_gold_west", "resource": &"gold", "amount": 4, "x": -480.0, "renewable": false, "label": "Ancient Coin Chest (+4 Gold)", "prompt": "[E] Chest +4G"},
	{"id": "timber_pile_west", "resource": &"wood", "amount": 5, "x": -110.0, "renewable": true, "label": "Fallen Timber (+5 Wood)", "prompt": "[E] Timber +5W"},
	{"id": "stone_outcrop_east", "resource": &"stone", "amount": 3, "x": 190.0, "renewable": true, "label": "Ruined Masonry (+3 Stone)", "prompt": "[E] Masonry +3S"},
	{"id": "shrine_cache_far_west", "resource": &"gold", "amount": 3, "x": -780.0, "renewable": false, "label": "Forgotten Shrine (+3 Gold)", "prompt": "[E] Shrine +3G"},
]

var nodes: Array[Dictionary] = []
var node_states: Dictionary = {}


func _init() -> void:
	load_from_data()


func load_from_data(path: String = "res://data/resource_nodes.json") -> void:
	nodes.clear()
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("nodes"):
			for item: Variant in (parsed as Dictionary)["nodes"]:
				if typeof(item) != TYPE_DICTIONARY:
					continue
				var d: Dictionary = item as Dictionary
				var nid: String = String(d.get("id", ""))
				if nid.is_empty():
					continue
				nodes.append({
					"id": nid,
					"resource": StringName(String(d.get("resource", "gold"))),
					"amount": int(roundf(float(d.get("amount", 1)))),
					"x": float(d.get("x", 0.0)),
					"renewable": bool(d.get("renewable", false)),
					"label": String(d.get("label", nid)),
					"prompt": String(d.get("prompt", "[E] Collect")),
				})
	if nodes.is_empty():
		nodes.assign(DEFAULT_NODES)
	for n: Dictionary in nodes:
		var nid: String = String(n["id"])
		if not node_states.has(nid):
			node_states[nid] = false


func is_collected(node_id: String) -> bool:
	return bool(node_states.get(node_id, false))


func get_node_def(node_id: String) -> Dictionary:
	for n: Dictionary in nodes:
		if String(n["id"]) == node_id:
			return n
	return {}


func find_nearest_available(actor_x: float, max_range: float = INTERACT_RANGE) -> Dictionary:
	var best: Dictionary = {}
	var best_dist: float = max_range + 0.001
	for n: Dictionary in nodes:
		var nid: String = String(n["id"])
		if is_collected(nid):
			continue
		var dist: float = absf(actor_x - float(n["x"]))
		if dist < best_dist:
			best_dist = dist
			best = n
	return best


func try_collect(node_id: String, actor_x: float, ledger: EconomyLedger) -> Dictionary:
	if ledger == null:
		return {"ok": false, "reason": "Economy ledger unavailable"}
	var n: Dictionary = get_node_def(node_id)
	if n.is_empty():
		return {"ok": false, "reason": "Unknown resource node: %s" % node_id}
	if is_collected(node_id):
		return {"ok": false, "reason": "Resource node already collected"}
	if absf(actor_x - float(n["x"])) > INTERACT_RANGE:
		return {"ok": false, "reason": "Move closer to %s" % String(n["label"])}
	var res_id: StringName = n["resource"] as StringName
	var amount: int = int(n["amount"])
	if not ledger.try_add(res_id, amount):
		return {"ok": false, "reason": "Failed adding resource to ledger"}
	node_states[node_id] = true
	node_collected.emit(node_id, res_id, amount)
	return {"ok": true, "reason": "", "node": n}


func refresh_renewable_nodes() -> void:
	var refreshed: Array[String] = []
	for n: Dictionary in nodes:
		var nid: String = String(n["id"])
		if bool(n.get("renewable", false)) and is_collected(nid):
			node_states[nid] = false
			refreshed.append(nid)
	renewable_nodes_refreshed.emit(refreshed)


func to_save_dict() -> Dictionary:
	var out: Dictionary = {}
	for n: Dictionary in nodes:
		var nid: String = String(n["id"])
		out[nid] = is_collected(nid)
	return out


func get_collected_ids_array() -> Array[String]:
	var arr: Array[String] = []
	for nid: String in node_states.keys():
		if bool(node_states[nid]):
			arr.append(nid)
	return arr


func apply_save_state(saved_node_states: Variant, legacy_collected_arr: Variant = []) -> void:
	for n: Dictionary in nodes:
		node_states[String(n["id"])] = false
	if typeof(saved_node_states) == TYPE_DICTIONARY and not (saved_node_states as Dictionary).is_empty():
		var d: Dictionary = saved_node_states as Dictionary
		for k: Variant in d.keys():
			var nid: String = String(k)
			if node_states.has(nid):
				node_states[nid] = bool(d[k])
		return
	if typeof(legacy_collected_arr) == TYPE_ARRAY:
		for item: Variant in (legacy_collected_arr as Array):
			var nid: String = String(item)
			if node_states.has(nid):
				node_states[nid] = true
