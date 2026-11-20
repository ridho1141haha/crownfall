class_name PrologueHandoffBridge
extends RefCounted

## Narrow persistent bridge carrying a one-shot Prologue -> Forgotten Shore
## handoff intent across SceneTree.change_scene_to_file().
## Ensures PlayerProfile.mark_prologue_completed() runs ONLY after
## ForgottenShoreSession._ready() confirms a valid fresh gameplay session.

const INTENT_META: String = "crownfall_prologue_handoff_intent"
const TOKEN_SEQ_META: String = "crownfall_prologue_handoff_seq"
const LAST_RESULT_META: String = "crownfall_prologue_handoff_last_result"
const MAX_PERSIST_ATTEMPTS: int = 2


static func authorize_fresh_handoff(destination_scene: String, profile_path: String) -> int:
	var next_token: int = int(Engine.get_meta(TOKEN_SEQ_META, 0)) + 1
	Engine.set_meta(TOKEN_SEQ_META, next_token)
	var intent: Dictionary = {
		"token": next_token,
		"destination": destination_scene,
		"profile_path": profile_path,
		"fresh_session": true,
		"consumed": false,
	}
	Engine.set_meta(INTENT_META, intent)
	Engine.set_meta("crownfall_load_on_start", false)
	return next_token


static func invalidate_pending(reason: String = "") -> void:
	if Engine.has_meta(INTENT_META):
		Engine.remove_meta(INTENT_META)
	if not reason.is_empty():
		Engine.set_meta(LAST_RESULT_META, {
			"ok": false,
			"persisted": false,
			"token": 0,
			"attempts": 0,
			"reason": reason,
		})


static func has_pending_intent() -> bool:
	if not Engine.has_meta(INTENT_META):
		return false
	var raw: Variant = Engine.get_meta(INTENT_META)
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	return not bool((raw as Dictionary).get("consumed", true))


static func pending_token() -> int:
	if not has_pending_intent():
		return 0
	return int((Engine.get_meta(INTENT_META) as Dictionary).get("token", 0))


static func last_result() -> Dictionary:
	if Engine.has_meta(LAST_RESULT_META) and typeof(Engine.get_meta(LAST_RESULT_META)) == TYPE_DICTIONARY:
		return (Engine.get_meta(LAST_RESULT_META) as Dictionary).duplicate(true)
	return {}


static func reset_for_tests() -> void:
	for key: String in [INTENT_META, LAST_RESULT_META]:
		if Engine.has_meta(key):
			Engine.remove_meta(key)


static func acknowledge_destination_ready(destination_scene: String, session_valid: bool, loaded_from_save: bool, expected_token: int = 0) -> Dictionary:
	if not has_pending_intent():
		var res_none: Dictionary = {"ok": false, "persisted": false, "token": 0, "attempts": 0, "reason": "no_pending_intent"}
		Engine.set_meta(LAST_RESULT_META, res_none)
		return res_none
	var intent: Dictionary = Engine.get_meta(INTENT_META) as Dictionary
	var token: int = int(intent.get("token", 0))
	var expected_dest: String = String(intent.get("destination", ""))
	var profile_path: String = String(intent.get("profile_path", PlayerProfile.DEFAULT_PROFILE_PATH))

	if expected_token > 0 and expected_token != token:
		var res_stale: Dictionary = {"ok": false, "persisted": false, "token": token, "attempts": 0, "reason": "stale_token"}
		Engine.set_meta(LAST_RESULT_META, res_stale)
		return res_stale
	if destination_scene != expected_dest:
		var res_dest: Dictionary = {"ok": false, "persisted": false, "token": token, "attempts": 0, "reason": "wrong_destination"}
		Engine.set_meta(LAST_RESULT_META, res_dest)
		return res_dest
	if loaded_from_save:
		Engine.remove_meta(INTENT_META)
		var res_load: Dictionary = {"ok": false, "persisted": false, "token": token, "attempts": 0, "reason": "loaded_from_save"}
		Engine.set_meta(LAST_RESULT_META, res_load)
		return res_load
	if not session_valid:
		Engine.remove_meta(INTENT_META)
		var res_invalid: Dictionary = {"ok": false, "persisted": false, "token": token, "attempts": 0, "reason": "session_invalid"}
		Engine.set_meta(LAST_RESULT_META, res_invalid)
		return res_invalid

	# Consume one-shot intent before persistence so duplicate acks can never write twice.
	Engine.remove_meta(INTENT_META)

	var persisted: bool = false
	var attempts: int = 0
	var profile := PlayerProfile.new()
	if profile.set_profile_path(profile_path):
		for _try: int in range(MAX_PERSIST_ATTEMPTS):
			attempts += 1
			if profile.mark_prologue_completed(profile_path):
				persisted = true
				break
	if not persisted:
		push_warning("[PrologueHandoffBridge] PlayerProfile persistence failed after %d attempt(s) for '%s'; keeping player in playable Forgotten Shore" % [attempts, profile_path])

	var result: Dictionary = {
		"ok": true,
		"persisted": persisted,
		"token": token,
		"attempts": attempts,
		"reason": "" if persisted else "profile_write_failed",
	}
	Engine.set_meta(LAST_RESULT_META, result)
	return result
