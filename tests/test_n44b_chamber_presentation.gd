extends SceneTree

## N4.4-B chamber presentation and data contract tests.

class FailingZonePolish extends PrologueRuinsEnvironment:
	func _create_zone_polish(_ground_y: float) -> Node2D:
		return null

class FailingRevealLayer extends PrologueRuinsEnvironment:
	func _create_chamber_reveal_layer() -> CanvasLayer:
		return null

const BUILD_ARGS: Array[float] = [-800.0, 2200.0, 200.0, -240.0, 240.0]
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + message)
	else:
		_failures += 1
		printerr("TEST FAILURE: [N44B] " + message)


func _run() -> void:
	_test_vision_data()
	await _test_ruins_lifecycle()
	await _test_stage_forwarding()
	if _failures == 0:
		print("PASS: All %d N44B Chamber Presentation checks completed with 0 failures." % _checks)
		quit(0)
	else:
		printerr("FAIL: N44B Chamber Presentation finished with %d failures out of %d checks." % [_failures, _checks])
		quit(1)


func _test_vision_data() -> void:
	var fragments: Array[Dictionary] = PrologueBeats.vision_fragments()
	_check(fragments.size() == 5, "R12 exposes exactly five canonical fragments")
	var validation: Dictionary = PrologueBeats.validate_vision_fragments(fragments)
	_check(bool(validation.get("ok", false)) and (validation.get("errors", []) as Array).is_empty(), "canonical R12 data passes fail-closed validation")
	_check(PrologueBeats.VISION_FRAGMENT_IDS.size() == 5 and not PrologueBeats.VISION_FRAGMENT_IDS.has(PrologueBeats.CUE_PL06_AWAKENING), "awakening cue is not a sixth vision fragment")
	_check(PrologueBeats.BEAT_IDS == ["pl_01_lost_world", "pl_02_faint_resonance"], "BEAT_IDS remains unchanged")
	_check(not PrologueBeats.is_beat("pl_06_crowns_call") and PrologueBeats.get_beat("pl_06_crowns_call").is_empty(), "pl_06 remains outside runner-authored beats")
	var copy: Array[Dictionary] = PrologueBeats.vision_fragments()
	copy[0]["subject"] = "mutated"
	_check(PrologueBeats.vision_fragments()[0]["subject"] == "ancient kingdom", "vision_fragments returns deep copies")
	var awakening: Dictionary = PrologueBeats.awakening_cue_entry()
	_check(awakening.get("cue_id") == PrologueBeats.CUE_PL06_AWAKENING and String(awakening.get("caption", "")).begins_with("[Placeholder art]"), "awakening cue is exposed separately with labelled placeholder caption")
	awakening["caption"] = "mutated"
	_check(PrologueBeats.awakening_cue_entry()["caption"] != "mutated", "awakening_cue_entry returns an isolated dictionary")
	_check(PrologueBeats.ALTAR_PROMPT_PROPOSAL_TEXT == "[E] Touch the crown", "O5 proposal remains a constant only")

	var unknown: Array[Dictionary] = PrologueBeats.vision_fragments()
	unknown[0]["id"] = "unknown_fragment"
	_check(not bool(PrologueBeats.validate_vision_fragments(unknown)["ok"]), "unknown fragment id is rejected")
	var six: Array[Dictionary] = PrologueBeats.vision_fragments()
	six.append(PrologueBeats.vision_fragments()[0])
	_check(not bool(PrologueBeats.validate_vision_fragments(six)["ok"]), "extra sixth fragment is rejected")
	var four: Array[Dictionary] = PrologueBeats.vision_fragments()
	four.pop_back()
	_check(not bool(PrologueBeats.validate_vision_fragments(four)["ok"]), "missing fifth fragment is rejected")
	_check(not bool(PrologueBeats.validate_vision_fragments([])["ok"]), "empty fragment array is rejected")
	var duplicate_id: Array[Dictionary] = PrologueBeats.vision_fragments()
	duplicate_id[1]["id"] = duplicate_id[0]["id"]
	_check(not bool(PrologueBeats.validate_vision_fragments(duplicate_id)["ok"]), "duplicate fragment id is rejected")
	var duplicate_cue: Array[Dictionary] = PrologueBeats.vision_fragments()
	duplicate_cue[1]["cue_id"] = duplicate_cue[0]["cue_id"]
	_check(not bool(PrologueBeats.validate_vision_fragments(duplicate_cue)["ok"]), "duplicate cue id is rejected")
	var mismatched: Array[Dictionary] = PrologueBeats.vision_fragments()
	mismatched[0]["cue_id"] = PrologueBeats.CUE_PL06_VISION_SYMBOL
	_check(not bool(PrologueBeats.validate_vision_fragments(mismatched)["ok"]), "mismatched id-to-cue pairing is rejected")
	var unknown_key: Array[Dictionary] = PrologueBeats.vision_fragments()
	unknown_key[0]["dialogue"] = "not allowed"
	_check(not bool(PrologueBeats.validate_vision_fragments(unknown_key)["ok"]), "unknown schema key is rejected")
	var bad_caption: Array[Dictionary] = PrologueBeats.vision_fragments()
	bad_caption[0]["caption"] = "unlabelled"
	_check(not bool(PrologueBeats.validate_vision_fragments(bad_caption)["ok"]), "unlabelled caption is rejected")
	var empty_subject: Array[Dictionary] = PrologueBeats.vision_fragments()
	empty_subject[0]["subject"] = "   "
	_check(not bool(PrologueBeats.validate_vision_fragments(empty_subject)["ok"]), "whitespace-only subject is rejected")
	var long_subject: Array[Dictionary] = PrologueBeats.vision_fragments()
	long_subject[0]["subject"] = "x".repeat(NarrativeData.MAX_TEXT_LENGTH + 1)
	_check(not bool(PrologueBeats.validate_vision_fragments(long_subject)["ok"]), "subject exceeding MAX_TEXT_LENGTH is rejected")

	for forbidden: String in ["king.", "king's", "dynasty", "caused the eclipse", "origin of the crown", "grants power", "source of power", "the ancient power source", "The Ancient Power Source", "THE ANCIENT POWER SOURCE"]:
		var rejected: Array[Dictionary] = PrologueBeats.vision_fragments()
		rejected[0]["subject"] = forbidden
		_check(not bool(PrologueBeats.validate_vision_fragments(rejected)["ok"]), "R13 rejects forbidden phrase: %s" % forbidden)
	var safe: Array[Dictionary] = PrologueBeats.vision_fragments()
	_check(bool(PrologueBeats.validate_vision_fragments(safe)["ok"]), "R13 word-boundary rules preserve approved kingdom and silhouette wording")


func _new_ruins(component: PrologueRuinsEnvironment) -> PrologueRuinsEnvironment:
	get_root().add_child(component)
	return component


func _build_ruins(component: PrologueRuinsEnvironment) -> bool:
	return component.build(BUILD_ARGS[0], BUILD_ARGS[1], BUILD_ARGS[2], BUILD_ARGS[3], BUILD_ARGS[4])


func _test_ruins_lifecycle() -> void:
	var failed_zone := _new_ruins(FailingZonePolish.new())
	_check(not _build_ruins(failed_zone) and not failed_zone.is_valid() and failed_zone.get_child_count() == 0, "ZonePolish factory failure leaves ruins invalid and empty")
	_check(failed_zone.reveal_layer() == null and failed_zone.reveal_veil() == null, "failed ZonePolish build clears reveal references")
	failed_zone.queue_free()

	var failed_layer := _new_ruins(FailingRevealLayer.new())
	_check(not _build_ruins(failed_layer) and not failed_layer.is_valid() and failed_layer.get_child_count() == 0, "reveal-layer factory failure leaves ruins invalid and empty")
	_check(failed_layer.altar_group() == null and failed_layer.reveal_veil() == null, "failed reveal-layer build clears internal references")
	failed_layer.queue_free()

	var ruins := _new_ruins(PrologueRuinsEnvironment.new())
	await process_frame
	_check(not ruins.is_processing(), "ruins processing is disabled on ready")
	_check(_build_ruins(ruins) and ruins.get_child_count() == 1, "valid build commits exactly one RuinsEnvironment staging child")
	var layer := ruins.reveal_layer()
	var veil := ruins.reveal_veil()
	_check(layer != null and layer.layer == 0 and not layer.visible, "reveal CanvasLayer starts hidden on layer zero")
	var reveal_root := layer.get_node("RevealRoot") as Control
	_check(reveal_root != null and reveal_root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "reveal root ignores mouse input")
	_check(veil != null and veil.mouse_filter == Control.MOUSE_FILTER_IGNORE and veil.anchor_right == 1.0 and veil.anchor_bottom == 1.0, "veil is full-rect and ignores mouse input")
	var altar := ruins.altar_group()
	ruins.update_explorer_x(PrologueRuinsEnvironment.INTERIOR_END_X)
	_check(ruins.is_chamber_revealed() and altar.visible and ruins.is_reveal_overlay_visible(), "crossing chamber threshold reveals altar and presentation layer")
	_check(is_equal_approx(veil.color.a, PrologueRuinsEnvironment.REVEAL_VEIL_START_ALPHA) and ruins.is_reveal_active() and ruins.is_processing(), "reveal begins at configured alpha and enables processing")
	ruins.call("_process", 0.4)
	_check(is_equal_approx(veil.color.a, 0.19) and ruins.is_reveal_active(), "delta-driven reveal reaches the expected mid-fade alpha")
	ruins.call("_process", 0.5)
	_check(is_equal_approx(veil.color.a, 0.0) and not ruins.is_reveal_active() and not ruins.is_processing(), "reveal completes at alpha zero and stops processing")
	_check(ruins.is_reveal_overlay_visible(), "letterbox presentation remains visible after veil fade")
	ruins.update_explorer_x(1000.0)
	ruins.update_explorer_x(PrologueRuinsEnvironment.INTERIOR_END_X)
	_check(is_equal_approx(veil.color.a, 0.0), "backtracking never restarts the one-shot reveal")
	ruins.teardown()
	_check(ruins.is_torn_down() and not ruins.is_reveal_overlay_visible() and altar.visible, "teardown hides overlay but preserves static altar geometry")
	_check(not ruins.is_processing() and is_equal_approx(veil.color.a, 0.0), "teardown resets veil alpha and processing")
	_check(not _build_ruins(ruins), "build after teardown is rejected")
	ruins.teardown()
	ruins.teardown()
	_check(ruins.is_torn_down() and not ruins.is_reveal_overlay_visible(), "repeated teardown is idempotent")
	ruins.queue_free()


func _test_stage_forwarding() -> void:
	var panel := DialoguePanel.new()
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var stage := PrologueExplorationStage.new()
	get_root().add_child(stage)
	_check(stage.setup(panel, texture), "real exploration stage builds with an in-memory test texture")
	var ruins := stage.ruins()
	_check(ruins != null and ruins.is_valid(), "stage owns the committed ruins component")
	stage.end_segment()
	_check(ruins.is_torn_down() and not ruins.is_reveal_overlay_visible(), "end_segment forwards teardown to its real ruins child")
	stage.end_segment()
	_check(ruins.is_torn_down(), "repeated end_segment remains safe")
	stage.queue_free()

	var stage_before_reveal := PrologueExplorationStage.new()
	get_root().add_child(stage_before_reveal)
	_check(stage_before_reveal.setup(panel, texture), "second real exploration stage builds")
	var ruins_before_reveal := stage_before_reveal.ruins()
	stage_before_reveal.teardown()
	_check(ruins_before_reveal.is_torn_down(), "stage teardown forwards before any reveal")
	stage_before_reveal.teardown()
	_check(ruins_before_reveal.is_torn_down(), "repeated stage teardown remains idempotent")
	stage_before_reveal.queue_free()
	panel.free()
