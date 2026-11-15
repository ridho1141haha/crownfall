class_name EraProgressionManager
extends RefCounted

## Progresi zaman bertahap (Wood Age -> Stone Age -> Iron Age).
## Zaman tidak muncul sekaligus di pulau pertama: Wood Age aktif sejak awal,
## Stone Age terbuka saat tembok pertama menjadi Stone Wall Tier 2, dan Iron Age
## terbuka saat kapal hasil perbaikan Shipwreck mencapai Stage 3.

signal era_changed(era_id: String, era_name: String)

const DATA_PATH: String = "res://data/eras.json"
const KNOWN_ERA_IDS: Array[String] = ["wood_age", "stone_age", "iron_age"]

const DEFAULT_ERAS: Array[Dictionary] = [
	{"id": "wood_age", "name": "Wood Age", "order": 1},
	{"id": "stone_age", "name": "Stone Age", "order": 2},
	{"id": "iron_age", "name": "Iron Age", "order": 3},
]

var eras: Array[Dictionary] = []
var current_index: int = 0


func _init() -> void:
	load_from_data()


static func is_valid_era_dict(d: Dictionary, expected_order: int) -> bool:
	if String(d.get("id", "")) not in KNOWN_ERA_IDS:
		return false
	if String(d.get("name", "")).strip_edges().is_empty():
		return false
	if not EconomyLedger.is_exact_int_value(d.get("order", null)):
		return false
	return int(d["order"]) == expected_order


func load_from_data(path: String = DATA_PATH) -> void:
	eras.clear()
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("eras") and typeof((parsed as Dictionary)["eras"]) == TYPE_ARRAY:
			var raw_arr: Array = (parsed as Dictionary)["eras"]
			if raw_arr.size() >= DEFAULT_ERAS.size():
				var valid_all: bool = true
				for i: int in range(DEFAULT_ERAS.size()):
					if typeof(raw_arr[i]) != TYPE_DICTIONARY or not is_valid_era_dict(raw_arr[i] as Dictionary, i + 1):
						valid_all = false
						break
				if valid_all:
					for i: int in range(DEFAULT_ERAS.size()):
						eras.append(raw_arr[i] as Dictionary)
	if eras.size() < DEFAULT_ERAS.size():
		eras = DEFAULT_ERAS.duplicate(true)
	current_index = clampi(current_index, 0, eras.size() - 1)


func get_era_id() -> String:
	return String(eras[clampi(current_index, 0, eras.size() - 1)].get("id", "wood_age"))


func get_era_name() -> String:
	return String(eras[clampi(current_index, 0, eras.size() - 1)].get("name", "Wood Age"))


func get_era_index_by_id(era_id: String) -> int:
	for i: int in range(eras.size()):
		if String(eras[i].get("id", "")) == era_id:
			return i
	return -1


func _advance_to_index(target: int) -> bool:
	if target <= current_index:
		return false
	current_index = clampi(target, 0, eras.size() - 1)
	era_changed.emit(get_era_id(), get_era_name())
	return true


func notify_stone_wall_built() -> bool:
	var target: int = get_era_index_by_id("stone_age")
	if target < 0:
		return false
	return _advance_to_index(target)


func notify_vessel_ready() -> bool:
	var target: int = get_era_index_by_id("iron_age")
	if target < 0:
		return false
	return _advance_to_index(target)


func to_save_id() -> String:
	return get_era_id()


func apply_save_era(era_id: String) -> bool:
	if era_id.is_empty():
		return false
	var idx: int = get_era_index_by_id(era_id)
	if idx < 0:
		return false
	current_index = idx
	return true
