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
	"night_encounter",
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


func save_state(
	payload: Dictionary,
	save_path: String = DEFAULT_SAVE_PATH,
	simulate_write_failure: bool = false,
	simulate_replace_failure: bool = false
) -> bool:
	if not is_safe_save_path(save_path):
		save_failed.emit("Unsafe save path rejected: %s" % save_path)
		return false
	if not validate_payload(payload):
		save_failed.emit("Payload failed schema validation before write")
		return false

	var tmp_path: String = save_path + ".tmp"
	var bak_path: String = save_path + ".bak"
	var bak_tmp_path: String = save_path + ".bak.tmp"
	var old_path: String = save_path + ".old"
	var json_text: String = JSON.stringify(payload, "\t")
	if json_text.is_empty():
		save_failed.emit("Failed to serialize JSON")
		return false

	# Step 1: Write and verify temporary save file (.tmp)
	if not _write_and_verify_file(tmp_path, json_text, simulate_write_failure):
		_remove_if_exists(tmp_path)
		save_failed.emit("Failed writing or verifying temporary save file")
		return false

	# Step 2: If an active valid save exists, stage and verify .bak BEFORE touching active save
	var had_valid_active: bool = false
	if FileAccess.file_exists(save_path):
		var existing_check: Dictionary = _read_and_validate_file(save_path)
		if bool(existing_check.get("ok", false)):
			had_valid_active = true
			var prev_text: String = FileAccess.get_file_as_string(save_path)
			if not _write_and_verify_file(bak_tmp_path, prev_text, false):
				_remove_if_exists(bak_tmp_path)
				_remove_if_exists(tmp_path)
				save_failed.emit("Backup staging verification failed; active save left untouched")
				return false
			if not _safe_replace_file(bak_tmp_path, bak_path, bak_path + ".old", false):
				_remove_if_exists(bak_tmp_path)
				_remove_if_exists(tmp_path)
				save_failed.emit("Backup commit failed; active save left untouched")
				return false

	# Step 3: Windows/POSIX safe replacement of active save with automatic rollback from .old/.bak
	if not _safe_replace_file(tmp_path, save_path, old_path, simulate_replace_failure):
		_remove_if_exists(tmp_path)
		if had_valid_active and not bool(_read_and_validate_file(save_path).get("ok", false)):
			_restore_from_backup_file(bak_path, save_path)
		save_failed.emit("Failed replacing active save; previous valid save preserved/restored")
		return false

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
		# Self-heal corrupt primary from verified backup
		_restore_from_backup_file(bak_path, save_path)
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
	var b_arr: Array = dict["buildings"]
	if b_arr.is_empty():
		return false
	for b_item: Variant in b_arr:
		if not BuildingManager.is_valid_saved_building_dict(b_item):
			return false

	var n_arr: Array = dict["npcs"]
	if n_arr.is_empty():
		return false
	for n_item: Variant in n_arr:
		if not NPCBuilderAgent.is_valid_saved_npc_dict(n_item):
			return false

	if not NightEncounterManager.is_valid_saved_encounter_dict(dict["night_encounter"]):
		return false

	if typeof(dict["progression_flags"]) != TYPE_DICTIONARY:
		return false

	return true


func _write_and_verify_file(path: String, text: String, simulate_failure: bool) -> bool:
	if simulate_failure:
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	return bool(_read_and_validate_file(path).get("ok", false))


func _safe_replace_file(src_tmp_path: String, dst_path: String, staged_old_path: String, simulate_failure: bool) -> bool:
	var abs_src: String = ProjectSettings.globalize_path(src_tmp_path)
	var abs_dst: String = ProjectSettings.globalize_path(dst_path)
	var abs_old: String = ProjectSettings.globalize_path(staged_old_path)

	# Extreme rollback test path: move active -> .old first, then simulate crash/failure before .tmp -> active
	if simulate_failure:
		_remove_if_exists(staged_old_path)
		if FileAccess.file_exists(dst_path):
			if DirAccess.rename_absolute(abs_dst, abs_old) == OK:
				# Simulate mid-swap failure right after active was moved to .old, then verify rollback!
				DirAccess.rename_absolute(abs_old, abs_dst)
		return false

	# 1. Try direct atomic POSIX rename first (replaces target atomically on Linux/macOS)
	if DirAccess.rename_absolute(abs_src, abs_dst) == OK:
		if bool(_read_and_validate_file(dst_path).get("ok", false)):
			return true

	# 2. Windows-safe staged swap: move existing target to .old (never delete before replacement succeeds)
	_remove_if_exists(staged_old_path)
	var moved_existing: bool = false
	if FileAccess.file_exists(dst_path):
		if DirAccess.rename_absolute(abs_dst, abs_old) != OK:
			return false
		moved_existing = true

	if DirAccess.rename_absolute(abs_src, abs_dst) != OK or not bool(_read_and_validate_file(dst_path).get("ok", false)):
		# Rollback from staged .old immediately so dst_path is never lost
		if moved_existing and FileAccess.file_exists(staged_old_path):
			DirAccess.rename_absolute(abs_old, abs_dst)
		return false

	# Only clean up .old after the new dst_path is verified valid
	if moved_existing:
		_remove_if_exists(staged_old_path)
	return true


func _restore_from_backup_file(bak_path: String, active_path: String) -> bool:
	if not bool(_read_and_validate_file(bak_path).get("ok", false)):
		return false
	var bak_text: String = FileAccess.get_file_as_string(bak_path)
	var restore_tmp: String = active_path + ".restore.tmp"
	if not _write_and_verify_file(restore_tmp, bak_text, false):
		_remove_if_exists(restore_tmp)
		return false
	return _safe_replace_file(restore_tmp, active_path, active_path + ".old", false)


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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
