class_name NarrativeData
extends RefCounted

## Schema validation for narrative sequences (typed, allowlisted steps).
##
## DECIDED (technical design, section E): sequences are data-driven JSON with
## a fixed allowlist of operations. Validation is fail-closed and all-or-
## nothing: one malformed entry rejects the whole payload with reasons, so a
## broken file can never run a partial sequence. No script expressions or
## arbitrary execution exist anywhere in this format.

const VALID_OPS: Array[String] = [
	"dialogue",
	"wait",
	"lock_control",
	"unlock_control",
	"play_cue",
	"change_scene",
	"finish",
]

const MAX_SEQUENCES: int = 128
const MAX_STEPS: int = 128
const MAX_LINES: int = 256
const MAX_TEXT_LENGTH: int = 512
const MAX_SPEAKER_LENGTH: int = 64
const MAX_ID_LENGTH: int = 64
const MAX_WAIT_SECONDS: float = 60.0


## Loads and validates a narrative sequences file. Returns
## {"ok": bool, "errors": Array[String], "sequences": Array[Dictionary]}.
static func load_sequences(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "errors": ["Narrative data file not found: %s" % path], "sequences": []}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		return {"ok": false, "errors": ["Narrative data is not valid JSON: %s" % path], "sequences": []}
	return validate_sequences_payload(parsed)


## Pure, file-less validator so malformed payloads can be tested without
## fixtures on disk. Unknown fields, unknown ops, and out-of-bounds values
## fail closed with human-readable reasons.
static func validate_sequences_payload(data: Variant) -> Dictionary:
	var errors: Array[String] = []
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("Narrative payload must be a JSON object")
		return {"ok": false, "errors": errors, "sequences": []}
	var root: Dictionary = data as Dictionary
	for key: Variant in root.keys():
		if String(key) != "sequences":
			errors.append("Payload has unknown top-level field '%s'" % String(key))
			return {"ok": false, "errors": errors, "sequences": []}
	if not root.has("sequences") or typeof(root["sequences"]) != TYPE_ARRAY:
		errors.append("Payload must contain a 'sequences' array")
		return {"ok": false, "errors": errors, "sequences": []}
	var raw_sequences: Array = root["sequences"] as Array
	if raw_sequences.is_empty():
		errors.append("Payload must contain at least one sequence")
		return {"ok": false, "errors": errors, "sequences": []}
	if raw_sequences.size() > MAX_SEQUENCES:
		errors.append("Too many sequences (%d, max %d)" % [raw_sequences.size(), MAX_SEQUENCES])
		return {"ok": false, "errors": errors, "sequences": []}

	var sequences: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	for i: int in range(raw_sequences.size()):
		var where: String = "sequences[%d]" % i
		if typeof(raw_sequences[i]) != TYPE_DICTIONARY:
			errors.append("%s must be an object" % where)
			return {"ok": false, "errors": errors, "sequences": []}
		var seq: Dictionary = (raw_sequences[i] as Dictionary).duplicate(true)
		if not _validate_sequence(seq, where, errors):
			return {"ok": false, "errors": errors, "sequences": []}
		var seq_id: String = String(seq["id"])
		if seen_ids.has(seq_id):
			errors.append("%s duplicates sequence id '%s'" % [where, seq_id])
			return {"ok": false, "errors": errors, "sequences": []}
		seen_ids[seq_id] = true
		sequences.append(seq)
	return {"ok": true, "errors": errors, "sequences": sequences}


static func _validate_sequence(seq: Dictionary, where: String, errors: Array[String]) -> bool:
	for key: Variant in seq.keys():
		if String(key) not in ["id", "skip_allowed", "steps"]:
			errors.append("%s has unknown field '%s'" % [where, String(key)])
			return false
	if not seq.has("id") or not ProgressionState.is_valid_stable_id(seq["id"]):
		errors.append("%s has an invalid sequence id (lowercase snake_case, a-z0-9_ required)" % where)
		return false
	var id_str: String = String(seq["id"])
	if id_str.length() > MAX_ID_LENGTH:
		errors.append("%s id exceeds %d characters" % [where, MAX_ID_LENGTH])
		return false
	if seq.has("skip_allowed") and typeof(seq["skip_allowed"]) != TYPE_BOOL:
		errors.append("%s skip_allowed must be a boolean" % where)
		return false
	if not seq.has("steps") or typeof(seq["steps"]) != TYPE_ARRAY:
		errors.append("%s must contain a 'steps' array" % where)
		return false
	var steps: Array = seq["steps"] as Array
	if steps.is_empty():
		errors.append("%s must contain at least one step" % where)
		return false
	if steps.size() > MAX_STEPS:
		errors.append("%s has too many steps (%d, max %d)" % [where, steps.size(), MAX_STEPS])
		return false
	for j: int in range(steps.size()):
		if typeof(steps[j]) != TYPE_DICTIONARY:
			errors.append("%s.steps[%d] must be an object" % [where, j])
			return false
		if not _validate_step(steps[j] as Dictionary, "%s.steps[%d]" % [where, j], errors):
			return false
	return true


static func _validate_step(step: Dictionary, where: String, errors: Array[String]) -> bool:
	if not step.has("op") or typeof(step["op"]) != TYPE_STRING:
		errors.append("%s must contain a string 'op'" % where)
		return false
	var op: String = String(step["op"])
	if not VALID_OPS.has(op):
		errors.append("%s has unknown op '%s' (allowed: %s)" % [where, op, ", ".join(VALID_OPS)])
		return false
	match op:
		"dialogue":
			for key: Variant in step.keys():
				if String(key) != "op" and String(key) != "lines":
					errors.append("%s has unknown field '%s'" % [where, String(key)])
					return false
			if not step.has("lines") or typeof(step["lines"]) != TYPE_ARRAY or (step["lines"] as Array).is_empty():
				errors.append("%s dialogue op must contain a non-empty 'lines' array" % where)
				return false
			var lines: Array = step["lines"] as Array
			if lines.size() > MAX_LINES:
				errors.append("%s has too many lines (%d, max %d)" % [where, lines.size(), MAX_LINES])
				return false
			for k: int in range(lines.size()):
				var line_where: String = "%s.lines[%d]" % [where, k]
				if typeof(lines[k]) != TYPE_DICTIONARY:
					errors.append("%s must be an object" % line_where)
					return false
				var line: Dictionary = lines[k] as Dictionary
				for key2: Variant in line.keys():
					if String(key2) != "speaker" and String(key2) != "text":
						errors.append("%s has unknown field '%s'" % [line_where, String(key2)])
						return false
				if not line.has("speaker") or typeof(line["speaker"]) != TYPE_STRING:
					errors.append("%s must contain a string 'speaker'" % line_where)
					return false
				if String(line["speaker"]).strip_edges().is_empty() or String(line["speaker"]).length() > MAX_SPEAKER_LENGTH:
					errors.append("%s speaker must be 1-%d characters" % [line_where, MAX_SPEAKER_LENGTH])
					return false
				if not line.has("text") or typeof(line["text"]) != TYPE_STRING:
					errors.append("%s must contain a string 'text'" % line_where)
					return false
				if String(line["text"]).strip_edges().is_empty() or String(line["text"]).length() > MAX_TEXT_LENGTH:
					errors.append("%s text must be 1-%d characters" % [line_where, MAX_TEXT_LENGTH])
					return false
		"wait":
			for key: Variant in step.keys():
				if String(key) != "op" and String(key) != "seconds":
					errors.append("%s has unknown field '%s'" % [where, String(key)])
					return false
			if not step.has("seconds") or typeof(step["seconds"]) not in [TYPE_FLOAT, TYPE_INT]:
				errors.append("%s wait op must contain a numeric 'seconds'" % where)
				return false
			var seconds: float = float(step["seconds"])
			if is_nan(seconds) or is_inf(seconds) or seconds < 0.0 or seconds > MAX_WAIT_SECONDS:
				errors.append("%s wait seconds must be finite and within [0, %.0f]" % [where, MAX_WAIT_SECONDS])
				return false
		"play_cue":
			for key: Variant in step.keys():
				if String(key) != "op" and String(key) != "cue_id":
					errors.append("%s has unknown field '%s'" % [where, String(key)])
					return false
			if not step.has("cue_id") or typeof(step["cue_id"]) != TYPE_STRING:
				errors.append("%s play_cue op must contain a string 'cue_id'" % where)
				return false
			if String(step["cue_id"]).strip_edges().is_empty() or String(step["cue_id"]).length() > MAX_ID_LENGTH:
				errors.append("%s cue_id must be 1-%d characters" % [where, MAX_ID_LENGTH])
				return false
		"change_scene":
			for key: Variant in step.keys():
				if String(key) != "op" and String(key) != "scene_path":
					errors.append("%s has unknown field '%s'" % [where, String(key)])
					return false
			if not step.has("scene_path") or typeof(step["scene_path"]) != TYPE_STRING:
				errors.append("%s change_scene op must contain a string 'scene_path'" % where)
				return false
			var scene_path: String = String(step["scene_path"])
			if not scene_path.begins_with("res://") or not scene_path.ends_with(".tscn"):
				errors.append("%s scene_path must be a res:// .tscn path" % where)
				return false
		"lock_control", "unlock_control", "finish":
			for key: Variant in step.keys():
				if String(key) != "op":
					errors.append("%s has unknown field '%s'" % [where, String(key)])
					return false
	return true
