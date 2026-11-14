class_name EconomyLedger
extends RefCounted

signal balance_changed(resource_id: StringName, new_balance: int)
signal transaction_committed(kind: String, details: Dictionary)
signal transaction_rejected(reason: String)

const VALID_RESOURCES: Array[StringName] = [&"gold", &"wood", &"stone"]
const MAX_RESOURCE_CAP: int = 999999

var _balances: Dictionary = {
	&"gold": 0,
	&"wood": 0,
	&"stone": 0,
}


func _init(initial_balances: Dictionary = {}) -> void:
	for res_id: StringName in VALID_RESOURCES:
		_balances[res_id] = 0
	if not initial_balances.is_empty():
		set_balances_from_dict(initial_balances)


static func is_exact_int_value(val: Variant) -> bool:
	if typeof(val) == TYPE_INT:
		return true
	if typeof(val) == TYPE_FLOAT:
		var f: float = float(val)
		if is_nan(f) or is_inf(f):
			return false
		return is_equal_approx(f, roundf(f))
	return false


func is_valid_resource(resource_id: StringName) -> bool:
	return VALID_RESOURCES.has(resource_id)


func get_amount(resource_id: StringName) -> int:
	if not is_valid_resource(resource_id):
		return 0
	return int(_balances[resource_id])


func get_all_balances() -> Dictionary:
	return {
		"gold": int(_balances[&"gold"]),
		"wood": int(_balances[&"wood"]),
		"stone": int(_balances[&"stone"]),
	}


func try_add(resource_id: StringName, amount: Variant) -> bool:
	if not is_valid_resource(resource_id):
		transaction_rejected.emit("Unknown resource ID: %s" % String(resource_id))
		return false
	if not is_exact_int_value(amount):
		transaction_rejected.emit("Resource amount must be an exact integer")
		return false
	var int_amount: int = int(roundf(float(amount)))
	if int_amount <= 0:
		transaction_rejected.emit("Add amount must be positive")
		return false
	var current: int = int(_balances[resource_id])
	if current + int_amount > MAX_RESOURCE_CAP:
		transaction_rejected.emit("Resource cap exceeded for %s" % String(resource_id))
		return false

	_balances[resource_id] = current + int_amount
	balance_changed.emit(resource_id, int(_balances[resource_id]))
	transaction_committed.emit("add", {"resource_id": String(resource_id), "amount": int_amount})
	return true


func can_afford(costs: Dictionary) -> bool:
	if costs.is_empty():
		return false
	for raw_key: Variant in costs.keys():
		var res_id: StringName = StringName(String(raw_key))
		if not is_valid_resource(res_id):
			return false
		var raw_val: Variant = costs[raw_key]
		if not is_exact_int_value(raw_val):
			return false
		var amount: int = int(roundf(float(raw_val)))
		if amount <= 0:
			return false
		if int(_balances[res_id]) < amount:
			return false
	return true


func try_spend(costs: Dictionary) -> bool:
	if costs.is_empty():
		transaction_rejected.emit("Empty cost dictionary")
		return false

	# Phase 1: Validate all entries before mutating any balance (atomic invariant)
	var normalized_costs: Dictionary = {}
	for raw_key: Variant in costs.keys():
		var res_id: StringName = StringName(String(raw_key))
		if not is_valid_resource(res_id):
			transaction_rejected.emit("Unknown resource ID in spend: %s" % String(res_id))
			return false
		var raw_val: Variant = costs[raw_key]
		if not is_exact_int_value(raw_val):
			transaction_rejected.emit("Invalid non-integer cost for %s" % String(res_id))
			return false
		var amount: int = int(roundf(float(raw_val)))
		if amount <= 0:
			transaction_rejected.emit("Spend amount must be positive for %s" % String(res_id))
			return false
		var total_for_res: int = int(normalized_costs.get(res_id, 0)) + amount
		if int(_balances[res_id]) < total_for_res:
			transaction_rejected.emit("Insufficient %s (need %d, have %d)" % [String(res_id), total_for_res, int(_balances[res_id])])
			return false
		normalized_costs[res_id] = total_for_res

	# Phase 2: Commit deductions atomically
	for res_id: StringName in normalized_costs.keys():
		var amount: int = int(normalized_costs[res_id])
		_balances[res_id] = int(_balances[res_id]) - amount
		balance_changed.emit(res_id, int(_balances[res_id]))

	transaction_committed.emit("spend", costs.duplicate())
	return true


func set_balances_from_dict(data: Dictionary) -> bool:
	var next_balances: Dictionary = {}
	for res_id: StringName in VALID_RESOURCES:
		var key_str: String = String(res_id)
		if not data.has(key_str) and not data.has(res_id):
			return false
		var raw_val: Variant = data.get(key_str, data.get(res_id))
		if not is_exact_int_value(raw_val):
			return false
		var val: int = int(roundf(float(raw_val)))
		if val < 0 or val > MAX_RESOURCE_CAP:
			return false
		next_balances[res_id] = val

	for res_id: StringName in VALID_RESOURCES:
		_balances[res_id] = int(next_balances[res_id])
		balance_changed.emit(resource_id_or_self(res_id), int(_balances[res_id]))
	return true


func resource_id_or_self(res_id: StringName) -> StringName:
	return res_id
