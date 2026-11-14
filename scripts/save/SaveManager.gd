class_name SaveManager
extends RefCounted

signal save_completed(path: String)
signal save_failed(reason: String)
signal load_recovered_from_backup(path: String)

const SCHEMA_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://save_slot_0.json"

const REQUIRED_KEYS: Array[String] = [
	"schema_version",
	"world_id",
	"island_id",
	"day_count",
	"world_time",
	"world_phase",
	"resources",
	"buildings",
	"npcs",
	"progression_flags",
]


static func is_safe_save_path(save_path: String) -> bool:
	if not save_path.begins_with("user://"):
		return false
	if save_path.find("..") != -1 or save_path.find("\\") != -1:
		return false
	if not save_path.ends_with(".json"):
		return false
	return true


func has_valid_save(save_path: String = DEFAULT_SAVE_PATH) -> bool:
	var result: Dictionary = load_state(save_path)
	return bool(result.get("ok", false))


func save_state(payload: Dictionary, save_path: String = DEFAULT_SAVE_PATH, simulate_write_failure: bool = false) -> bool:
	if not is_safe_save_path(save_path):
		save_failed.emit("Unsafe save path rejected: %s" % save_path)
		return false
	if not validate_payload(payload):
		save_failed.emit("Payload failed schema validation before write")
		return false

	var tmp_path: String = save_path + ".tmp"
	var bak_path: String = save_path + ".bak"
	var json_text: String = JSON.stringify(payload, "\t")
	if json_text.is_empty():
		save_failed.emit("Failed to serialize JSON")
		return false

	var tmp_file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null or simulate_write_failure:
		if tmp_file != null:
			tmp_file.close()
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		save_failed.emit("Failed writing temporary save file")
		return false

	tmp_file.store_string(json_text)
	tmp_file.flush()
	tmp_file.close()

	# Verify temporary file parses and deep-validates before touching active or backup files
	var verify_tmp: Dictionary = _read_and_validate_file(tmp_path)
	if not bool(verify_tmp.get("ok", false)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		save_failed.emit("Temporary save verification failed")
		return false

	# Preserve previous valid primary save as .bak (never overwrite .bak with corrupt primary)
	if FileAccess.file_exists(save_path):
		var existing_check: Dictionary = _read_and_validate_file(save_path)
		if bool(existing_check.get("ok", false)):
			var prev_text: String = FileAccess.get_file_as_string(save_path)
			var bak_file: FileAccess = FileAccess.open(bak_path, FileAccess.WRITE)
			if bak_file != null:
				bak_file.store_string(prev_text)
				bak_file.flush()
				bak_file.close()

	# Atomic replacement from verified .tmp to active save_path
	var abs_tmp: String = ProjectSettings.globalize_path(tmp_path)
	var abs_active: String = ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(abs_active)
	var rename_err: Error = DirAccess.rename_absolute(abs_tmp, abs_active)
	if rename_err != OK:
		var active_file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
		if active_file == null:
			save_failed.emit("Could not replace active save file")
			return false
		active_file.store_string(json_text)
		active_file.flush()
		active_file.close()
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(abs_tmp)

	save_completed.emit(save_path)
	return true


func load_state(save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if not is_safe_save_path(save_path):
		return {
			"ok": false,
			"recovered_from_backup": false,
			"error": "Unsafe save path rejected: %s" % save_path,
		}

	var primary: Dictionary = _read_and_validate_file(save_path)
	if bool(primary.get("ok", false)):
		return {
			"ok": true,
			"recovered_from_backup": false,
			"data": primary["data"],
		}

	var bak_path: String = save_path + ".bak"
	var backup: Dictionary = _read_and_validate_file(bak_path)
	if bool(backup.get("ok", false)):
		load_recovered_from_backup.emit(bak_path)
		return {
			"ok": true,
			"recovered_from_backup": true,
			"data": backup["data"],
		}

	return {
		"ok": false,
		"recovered_from_backup": false,
		"error": String(primary.get("error", "No valid save or backup found")),
	}


func validate_payload(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = data as Dictionary
	for key: String in REQUIRED_KEYS:
		if not dict.has(key):
			return false

	if not EconomyLedger.is_exact_int_value(dict["schema_version"]):
		return false
	if int(roundf(float(dict["schema_version"]))) != SCHEMA_VERSION:
		return false
	if String(dict["world_id"]).strip_edges().is_empty() or String(dict["island_id"]).strip_edges().is_empty():
		return false
	if not EconomyLedger.is_exact_int_value(dict["day_count"]) or int(roundf(float(dict["day_count"]))) < 1:
		return false

	var wt: float = float(dict["world_time"])
	if is_nan(wt) or is_inf(wt) or wt < 0.0:
		return false

	var phase: String = String(dict["world_phase"])
	if phase != "daylight" and phase != "sunset" and phase != "night":
		return false

	if typeof(dict["resources"]) != TYPE_DICTIONARY:
		return false
	var res: Dictionary = dict["resources"]
	for r_key: String in ["gold", "wood", "stone"]:
		if not res.has(r_key) or not EconomyLedger.is_exact_int_value(res[r_key]):
			return false
		var r_val: int = int(roundf(float(res[r_key])))
		if r_val < 0 or r_val > EconomyLedger.MAX_RESOURCE_CAP:
			return false

	if typeof(dict["buildings"]) != TYPE_ARRAY or typeof(dict["npcs"]) != TYPE_ARRAY:
		return false
	for b_item: Variant in dict["buildings"]:
		if not BuildingManager.is_valid_saved_building_dict(b_item):
			return false
	for n_item: Variant in dict["npcs"]:
		if not NPCBuilderAgent.is_valid_saved_npc_dict(n_item):
			return false

	if typeof(dict["progression_flags"]) != TYPE_DICTIONARY:
		return false

	return true


func _read_and_validate_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "File does not exist: %s" % path}
	var raw_text: String = FileAccess.get_file_as_string(path)
	if raw_text.strip_edges().is_empty():
		return {"ok": false, "error": "Empty save file: %s" % path}

	var parsed: Variant = JSON.parse_string(raw_text)
	if not validate_payload(parsed):
		return {"ok": false, "error": "Invalid schema or corrupt payload in %s" % path}
	return {"ok": true, "data": parsed}
