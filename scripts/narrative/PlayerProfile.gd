class_name PlayerProfile
extends RefCounted

## N4.0: minimal global player profile for first-playthrough narrative metadata.
##
## Stores exactly one durable fact — `prologue_completed_once` — separately from
## world saves (technical design D1/D2/D8: Skip eligibility must survive New
## Game replacing the world save). This is NOT a general profile/settings
## framework: no resources, buildings, NPCs, gameplay progression, settings, or
## world-save data ever live here, and SaveManager/schema v2 stay untouched.
##
## Fail-safe policy (DECIDED): a missing, malformed, unsupported-version, or
## unreadable profile is treated as "Prologue not completed" (Skip stays
## locked). A profile failure never blocks New Game or Continue and never
## invalidates a world save. Invalid data is never silently converted into a
## completed profile.
##
## Schema (user://player_profile.json):
##   {"schema_version": 1, "prologue_completed_once": false}

const SCHEMA_VERSION: int = 1
const DEFAULT_PROFILE_PATH: String = "user://player_profile.json"

const KEY_SCHEMA_VERSION: String = "schema_version"
const KEY_PROLOGUE_COMPLETED_ONCE: String = "prologue_completed_once"

var _profile_path: String = DEFAULT_PROFILE_PATH
var _prologue_completed_once: bool = false


static func is_safe_profile_path(profile_path: String) -> bool:
	# Same containment rules as SaveManager.is_safe_save_path: user:// only,
	# no traversal/backslashes, JSON extension.
	if not profile_path.begins_with("user://"):
		return false
	if profile_path.find("..") != -1 or profile_path.find("\\") != -1:
		return false
	if not profile_path.ends_with(".json"):
		return false
	return true


## Strict, fail-closed payload validation. Only the exact two-key shape at the
## known schema version is valid; anything else (missing field, wrong type,
## extra field, unknown version) is rejected so callers default to
## "not completed" instead of guessing.
static func validate_payload(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = data as Dictionary
	if dict.size() != 2:
		return false
	if not dict.has(KEY_SCHEMA_VERSION) or not dict.has(KEY_PROLOGUE_COMPLETED_ONCE):
		return false
	if not EconomyLedger.is_exact_int_value(dict[KEY_SCHEMA_VERSION]):
		return false
	if int(roundf(float(dict[KEY_SCHEMA_VERSION]))) != SCHEMA_VERSION:
		return false
	if typeof(dict[KEY_PROLOGUE_COMPLETED_ONCE]) != TYPE_BOOL:
		return false
	return true


func get_profile_path() -> String:
	return _profile_path


## Points the profile at an alternative path (test/fixture injection). Refuses
## unsafe paths so injected callers cannot escape user:// containment.
func set_profile_path(profile_path: String) -> bool:
	if not is_safe_profile_path(profile_path):
		return false
	_profile_path = profile_path
	return true


## Whether the Prologue was completed at least once on this installation.
## Only meaningful after load_profile(); a fresh instance defaults to false
## (fail-safe: missing data behaves as first playthrough).
func is_prologue_completed_once() -> bool:
	return _prologue_completed_once


## Loads/refreshes the cached completion state from disk. Returns a result
## dictionary ({ok, error}); on any failure the cached state falls back to
## false ("not completed") and ok is false. Never throws, never blocks.
func load_profile(profile_path: String = _profile_path) -> Dictionary:
	if not is_safe_profile_path(profile_path):
		_prologue_completed_once = false
		return {"ok": false, "error": "Unsafe profile path rejected: %s" % profile_path}
	if not FileAccess.file_exists(profile_path):
		# Missing profile: first-playthrough behavior, not an error condition
		# for callers (New Game/Continue must proceed).
		_prologue_completed_once = false
		return {"ok": true, "error": "Profile file does not exist yet"}
	var raw_text: String = FileAccess.get_file_as_string(profile_path)
	if FileAccess.get_open_error() != OK or raw_text.strip_edges().is_empty():
		_prologue_completed_once = false
		return {"ok": false, "error": "Unreadable or empty profile file: %s" % profile_path}
	var parsed: Variant = JSON.parse_string(raw_text)
	if not validate_payload(parsed):
		_prologue_completed_once = false
		return {"ok": false, "error": "Invalid or unsupported profile payload in %s" % profile_path}
	_prologue_completed_once = bool((parsed as Dictionary)[KEY_PROLOGUE_COMPLETED_ONCE])
	return {"ok": true, "error": ""}


## Records one successful full Prologue completion (called only after the full
## Prologue reaches its successful handoff path — never by Skip). Sets the
## in-run flag and persists it atomically. Returns whether the flag was
## actually persisted; a failed write must not be reported as persisted, and
## the next launch will correctly read the flag as still unset.
func mark_prologue_completed(profile_path: String = _profile_path) -> bool:
	_prologue_completed_once = true
	return _write_and_verify_profile(profile_path)


func _write_and_verify_profile(profile_path: String) -> bool:
	if not is_safe_profile_path(profile_path):
		return false
	var payload: Dictionary = {
		KEY_SCHEMA_VERSION: SCHEMA_VERSION,
		KEY_PROLOGUE_COMPLETED_ONCE: _prologue_completed_once,
	}
	var json_text: String = JSON.stringify(payload, "\t")
	if json_text.is_empty():
		return false
	var tmp_path: String = profile_path + ".tmp"
	var old_path: String = profile_path + ".old"
	# Step 1: write and verify the temporary file (SaveManager convention:
	# a write is only successful if the file re-reads as valid JSON).
	if not _write_and_verify_file(tmp_path, json_text):
		_remove_if_exists(tmp_path)
		return false
	# Step 2: staged atomic replacement with rollback (never delete before
	# the replacement is verified on disk).
	if not _safe_replace_file(tmp_path, profile_path, old_path):
		_remove_if_exists(tmp_path)
		return false
	return true


func _write_and_verify_file(path: String, text: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	var verify: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return validate_payload(verify)


func _safe_replace_file(src_tmp_path: String, dst_path: String, staged_old_path: String) -> bool:
	var abs_src: String = ProjectSettings.globalize_path(src_tmp_path)
	var abs_dst: String = ProjectSettings.globalize_path(dst_path)
	var abs_old: String = ProjectSettings.globalize_path(staged_old_path)
	# 1. Direct atomic POSIX rename first (replaces target atomically on Linux/macOS).
	if DirAccess.rename_absolute(abs_src, abs_dst) == OK:
		if bool(load_profile(dst_path).get("ok", false)):
			return true
	# 2. Windows-safe staged swap: move existing target to .old (never delete
	#    before replacement succeeds), then roll back on any failure.
	_remove_if_exists(staged_old_path)
	var moved_existing: bool = false
	if FileAccess.file_exists(dst_path):
		if DirAccess.rename_absolute(abs_dst, abs_old) != OK:
			return false
		moved_existing = true
	if DirAccess.rename_absolute(abs_src, abs_dst) != OK or not bool(load_profile(dst_path).get("ok", false)):
		if moved_existing and FileAccess.file_exists(staged_old_path):
			DirAccess.rename_absolute(abs_old, abs_dst)
		return false
	if moved_existing:
		_remove_if_exists(staged_old_path)
	return true


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
