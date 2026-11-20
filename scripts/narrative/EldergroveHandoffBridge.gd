class_name EldergroveHandoffBridge
extends RefCounted

## N5.5: Narrow one-shot handoff bridge carrying the Forgotten Shore ->
## Eldergrove Forest departure intent across SceneTree.change_scene_to_file().

const INTENT_META: String = "crownfall_eldergrove_handoff_intent"
const TOKEN_SEQ_META: String = "crownfall_eldergrove_handoff_seq"
const LAST_RESULT_META: String = "crownfall_eldergrove_handoff_last_result"


static func authorize_departure(destination_scene: String, source_context: Dictionary = {}) -> int:
	if destination_scene.strip_edges().is_empty():
		return 0
	var next_token: int = int(Engine.get_meta(TOKEN_SEQ_META, 0)) + 1
	Engine.set_meta(TOKEN_SEQ_META, next_token)
	var intent: Dictionary = {
		"token": next_token,
		"destination": destination_scene,
		"source_context": source_context.duplicate(false),
		"consumed": false,
	}
	Engine.set_meta(INTENT_META, intent)
	return next_token


static func invalidate_pending(reason: String = "") -> void:
	if Engine.has_meta(INTENT_META):
		Engine.remove_meta(INTENT_META)
	if not reason.is_empty():
		Engine.set_meta(LAST_RESULT_META, {
			"ok": false,
			"token": 0,
			"destination": "",
			"reason": reason,
		})


static func has_pending_intent() -> bool:
	if not Engine.has_meta(INTENT_META):
		return false
	var raw: Variant = Engine.get_meta(INTENT_META)
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = raw as Dictionary
	if bool(d.get("consumed", true)):
		return false
	if int(d.get("token", 0)) <= 0:
		return false
	if String(d.get("destination", "")).strip_edges().is_empty():
		return false
	return true


static func pending_token() -> int:
	if not has_pending_intent():
		return 0
	return int((Engine.get_meta(INTENT_META) as Dictionary).get("token", 0))


static func peek_pending_destination() -> String:
	if not has_pending_intent():
		return ""
	return String((Engine.get_meta(INTENT_META) as Dictionary).get("destination", ""))


static func peek_pending_context() -> Dictionary:
	if not has_pending_intent():
		return {}
	var raw_ctx: Variant = (Engine.get_meta(INTENT_META) as Dictionary).get("source_context", {})
	if typeof(raw_ctx) != TYPE_DICTIONARY:
		return {}
	return (raw_ctx as Dictionary).duplicate(false)


static func last_result() -> Dictionary:
	if Engine.has_meta(LAST_RESULT_META) and typeof(Engine.get_meta(LAST_RESULT_META)) == TYPE_DICTIONARY:
		return (Engine.get_meta(LAST_RESULT_META) as Dictionary).duplicate(true)
	return {}


static func reset_for_tests() -> void:
	for key: String in [INTENT_META, LAST_RESULT_META]:
		if Engine.has_meta(key):
			Engine.remove_meta(key)


static func acknowledge_destination_ready(destination_scene: String, destination_valid: bool, expected_token: int = 0) -> Dictionary:
	if not has_pending_intent():
		var res_none: Dictionary = {
			"ok": false,
			"token": 0,
			"destination": "",
			"reason": "no_pending_intent",
		}
		Engine.set_meta(LAST_RESULT_META, res_none)
		return res_none

	var intent: Dictionary = Engine.get_meta(INTENT_META) as Dictionary
	var token: int = int(intent.get("token", 0))
	var expected_dest: String = String(intent.get("destination", ""))
	var raw_ctx: Variant = intent.get("source_context", {})
	var source_context: Dictionary = (raw_ctx as Dictionary).duplicate(false) if typeof(raw_ctx) == TYPE_DICTIONARY else {}

	if expected_token != 0 and expected_token != token:
		var res_stale: Dictionary = {
			"ok": false,
			"token": token,
			"destination": expected_dest,
			"reason": "stale_token",
		}
		Engine.set_meta(LAST_RESULT_META, res_stale)
		return res_stale

	if destination_scene != expected_dest:
		var res_dest: Dictionary = {
			"ok": false,
			"token": token,
			"destination": expected_dest,
			"reason": "wrong_destination",
		}
		Engine.set_meta(LAST_RESULT_META, res_dest)
		return res_dest

	if not destination_valid:
		Engine.remove_meta(INTENT_META)
		var res_invalid: Dictionary = {
			"ok": false,
			"token": token,
			"destination": expected_dest,
			"reason": "destination_invalid",
		}
		Engine.set_meta(LAST_RESULT_META, res_invalid)
		return res_invalid

	Engine.remove_meta(INTENT_META)

	var recorded_result: Dictionary = {
		"ok": true,
		"token": token,
		"destination": expected_dest,
		"reason": "",
	}
	Engine.set_meta(LAST_RESULT_META, recorded_result)

	return {
		"ok": true,
		"token": token,
		"destination": expected_dest,
		"source_context": source_context,
		"reason": "",
	}
