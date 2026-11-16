extends SceneTree

## N1 narrative foundation tests: NarrativeState idempotence and
## NarrativeData fail-closed validation (valid/invalid payloads).

var _checks: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		printerr("TEST FAILURE [test_narrative_foundation]: " + msg)
		quit(1)
		return false
	print("PASS: " + msg)
	return true


func _initialize() -> void:
	# --- NarrativeState: in-memory, idempotent completion ---
	var state: NarrativeState = NarrativeState.new()
	_check(state.mark_completed("probe_sequence"), "first completion recorded")
	_check(not state.mark_completed("probe_sequence"), "duplicate completion rejected")
	_check(state.is_completed("probe_sequence"), "completion query returns true")
	_check(not state.is_completed("other_sequence"), "unknown id not completed")
	_check(state.completed_count() == 1, "completed count is 1")
	state.clear()
	_check(state.completed_count() == 0, "clear resets in-memory state")

	# --- NarrativeData: valid fixture round-trip ---
	var loaded: Dictionary = NarrativeData.load_sequences("res://tests/fixtures/narrative_sequences.json")
	_check(bool(loaded.get("ok", false)), "valid fixture loads")
	var sequences: Array = loaded.get("sequences", []) as Array
	_check(sequences.size() == 2, "fixture contains 2 sequences")
	if sequences.size() >= 1:
		var first: Dictionary = sequences[0] as Dictionary
		_check(String(first.get("id", "")) == "test_probe_greeting", "sequence id round-trips")
		_check(bool(first.get("skip_allowed", false)), "skip_allowed flag round-trips")
		_check((first.get("steps", []) as Array).size() == 6, "step count round-trips")

	# --- NarrativeData: fail-closed payloads ---
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": "nope"}).get("ok", false)), "sequences must be an array")
	_check(not bool(NarrativeData.validate_sequences_payload({}).get("ok", false)), "missing sequences rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": []}).get("ok", false)), "empty sequences rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"steps": [{"op": "finish"}]}], "extra": 1}).get("ok", false)), "unknown top-level field rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"steps": [{"op": "finish"}]}]}).get("ok", false)), "missing id rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "Bad-ID", "steps": [{"op": "finish"}]}]}).get("ok", false)), "invalid stable id rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "dup_seq", "steps": [{"op": "finish"}]}, {"id": "dup_seq", "steps": [{"op": "finish"}]}]}).get("ok", false)), "duplicate ids rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "extra_field_seq", "steps": [{"op": "finish"}], "colour": "red"}]}).get("ok", false)), "unknown sequence field rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "no_steps_seq"}]}).get("ok", false)), "missing steps rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "empty_steps_seq", "steps": []}]}).get("ok", false)), "empty steps rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "bad_op_seq", "steps": [{"op": "explode"}]}]}).get("ok", false)), "unknown op rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "bad_dialogue_seq", "steps": [{"op": "dialogue"}]}]}).get("ok", false)), "dialogue without lines rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "empty_lines_seq", "steps": [{"op": "dialogue", "lines": []}]}]}).get("ok", false)), "empty dialogue lines rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "bad_line_seq", "steps": [{"op": "dialogue", "lines": [{"text": "missing speaker"}]}]}]}).get("ok", false)), "line without speaker rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "bad_line_seq", "steps": [{"op": "dialogue", "lines": [{"speaker": "S", "text": ""}]}]}]}).get("ok", false)), "empty line text rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "bad_line_seq", "steps": [{"op": "dialogue", "lines": [{"speaker": "S", "text": "t", "tone": "angry"}]}]}]}).get("ok", false)), "unknown line field rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "neg_wait_seq", "steps": [{"op": "wait", "seconds": -1.0}]}]}).get("ok", false)), "negative wait rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "nan_wait_seq", "steps": [{"op": "wait", "seconds": NAN}]}]}).get("ok", false)), "NaN wait rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "inf_wait_seq", "steps": [{"op": "wait", "seconds": INF}]}]}).get("ok", false)), "infinite wait rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "long_wait_seq", "steps": [{"op": "wait", "seconds": 61.0}]}]}).get("ok", false)), "wait above bound rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "bad_cue_seq", "steps": [{"op": "play_cue", "cue_id": ""}]}]}).get("ok", false)), "empty cue id rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "bad_scene_seq", "steps": [{"op": "change_scene", "scene_path": "user://bad.tscn"}]}]}).get("ok", false)), "non-res scene path rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "bad_scene_seq", "steps": [{"op": "change_scene", "scene_path": "res://scenes/x"}]}]}).get("ok", false)), "scene path without .tscn rejected")
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "extra_op_field_seq", "steps": [{"op": "finish", "seconds": 1.0}]}]}).get("ok", false)), "finish with extra field rejected")
	_check(bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "minimal_seq", "steps": [{"op": "finish"}]}]}).get("ok", false)), "minimal valid sequence accepted")
	_check(bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "minimal_seq", "steps": [{"op": "wait", "seconds": 0.0}]}]}).get("ok", false)), "zero wait accepted")

	# --- Bounds: step/line limits ---
	var too_many_steps: Array = []
	for i: int in range(NarrativeData.MAX_STEPS + 1):
		too_many_steps.append({"op": "finish"})
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "step_bomb_seq", "steps": too_many_steps}]}).get("ok", false)), "too many steps rejected")
	var too_many_lines: Array = []
	for i: int in range(NarrativeData.MAX_LINES + 1):
		too_many_lines.append({"speaker": "S", "text": "t"})
	_check(not bool(NarrativeData.validate_sequences_payload({"sequences": [{"id": "line_bomb_seq", "steps": [{"op": "dialogue", "lines": too_many_lines}]}]}).get("ok", false)), "too many dialogue lines rejected")

	print("PASS: All %d Narrative Foundation checks completed with 0 failures." % _checks)
	quit(0)
