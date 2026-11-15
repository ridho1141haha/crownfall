class_name ForestTreeManager
extends RefCounted

signal tree_chopped(tree_id: String, hp_left: int, felled: bool, wood_gained: int)
signal forest_regrown(regrown_ids: Array[String])

const INTERACT_RANGE: float = 72.0
const DEFAULT_MAX_HP: int = 3
const DEFAULT_WOOD_YIELD: int = 4

const DEFAULT_TREES: Array[Dictionary] = [
	{"id": "tree_west_01", "x": -680.0, "max_hp": 3, "wood_yield": 4},
	{"id": "tree_west_02", "x": -940.0, "max_hp": 3, "wood_yield": 4},
	{"id": "tree_west_03", "x": -1080.0, "max_hp": 3, "wood_yield": 4},
	{"id": "tree_east_01", "x": 540.0, "max_hp": 3, "wood_yield": 4},
	{"id": "tree_east_02", "x": 690.0, "max_hp": 3, "wood_yield": 4},
	{"id": "tree_east_03", "x": 960.0, "max_hp": 3, "wood_yield": 4},
]

var trees: Array[Dictionary] = []
var tree_hp: Dictionary = {}


func _init() -> void:
	for t: Dictionary in DEFAULT_TREES:
		var copy_t: Dictionary = t.duplicate()
		trees.append(copy_t)
		tree_hp[String(copy_t["id"])] = int(copy_t["max_hp"])


func is_felled(tree_id: String) -> bool:
	return int(tree_hp.get(tree_id, 0)) <= 0


func get_hp(tree_id: String) -> int:
	return int(tree_hp.get(tree_id, 0))


func get_tree_def(tree_id: String) -> Dictionary:
	for t: Dictionary in trees:
		if String(t["id"]) == tree_id:
			return t
	return {}


func find_nearest_standing(actor_x: float, max_range: float = INTERACT_RANGE) -> Dictionary:
	var best: Dictionary = {}
	var best_dist: float = max_range + 0.001
	for t: Dictionary in trees:
		var tid: String = String(t["id"])
		if is_felled(tid):
			continue
		var dist: float = absf(actor_x - float(t["x"]))
		if dist < best_dist:
			best_dist = dist
			best = t
	return best


func try_chop(tree_id: String, actor_x: float, ledger: EconomyLedger) -> Dictionary:
	if ledger == null:
		return {"ok": false, "reason": "Economy ledger unavailable"}
	var t: Dictionary = get_tree_def(tree_id)
	if t.is_empty():
		return {"ok": false, "reason": "Unknown tree: %s" % tree_id}
	if is_felled(tree_id):
		return {"ok": false, "reason": "Tree already felled (regrows at Sunrise)"}
	if absf(actor_x - float(t["x"])) > INTERACT_RANGE:
		return {"ok": false, "reason": "Move closer to the tree to chop"}

	var next_hp: int = maxi(0, get_hp(tree_id) - 1)
	var felled: bool = (next_hp == 0)
	var wood_gain: int = 0
	if felled:
		var yld: int = int(t.get("wood_yield", DEFAULT_WOOD_YIELD))
		if not ledger.try_add(&"wood", yld):
			return {"ok": false, "reason": "Wood storage full!"}
		wood_gain = yld
	tree_hp[tree_id] = next_hp
	tree_chopped.emit(tree_id, next_hp, felled, wood_gain)
	return {"ok": true, "reason": "", "tree": t, "hp_left": next_hp, "felled": felled, "wood_gained": wood_gain}


func regrow_all() -> void:
	var regrown: Array[String] = []
	for t: Dictionary in trees:
		var tid: String = String(t["id"])
		var max_hp: int = int(t.get("max_hp", DEFAULT_MAX_HP))
		if int(tree_hp.get(tid, max_hp)) < max_hp:
			tree_hp[tid] = max_hp
			regrown.append(tid)
	forest_regrown.emit(regrown)


func to_save_dict() -> Dictionary:
	var out: Dictionary = {}
	for t: Dictionary in trees:
		var tid: String = String(t["id"])
		out[tid] = get_hp(tid)
	return out


static func is_valid_saved_tree_states(saved_states: Variant) -> bool:
	if typeof(saved_states) != TYPE_DICTIONARY:
		return false
	var known_max: Dictionary = {}
	for t: Dictionary in DEFAULT_TREES:
		known_max[String(t["id"])] = int(t.get("max_hp", DEFAULT_MAX_HP))
	var d: Dictionary = saved_states as Dictionary
	for raw_k: Variant in d.keys():
		var tid: String = String(raw_k)
		if not known_max.has(tid):
			return false
		if not EconomyLedger.is_exact_int_value(d[raw_k]):
			return false
		var hp_val: int = int(roundf(float(d[raw_k])))
		if hp_val < 0 or hp_val > int(known_max[tid]):
			return false
	return true


func apply_save_state(saved_states: Variant) -> void:
	for t: Dictionary in trees:
		tree_hp[String(t["id"])] = int(t.get("max_hp", DEFAULT_MAX_HP))
	if typeof(saved_states) != TYPE_DICTIONARY:
		return
	var d: Dictionary = saved_states as Dictionary
	for t: Dictionary in trees:
		var tid: String = String(t["id"])
		if d.has(tid):
			var max_hp: int = int(t.get("max_hp", DEFAULT_MAX_HP))
			tree_hp[tid] = clampi(int(roundf(float(d[tid]))), 0, max_hp)
