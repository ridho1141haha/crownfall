class_name PrologueBeats
extends RefCounted

## N4.2 authored Prologue content: beats pl_01 and pl_02 ONLY.
##
## STORY CONTENT lives here — PrologueShell owns lifecycle only (runtime init,
## auto-start, chaining, exit guards). The sequences are plain
## NarrativeData-validated dictionaries in the same typed, allowlisted op
## format as the N3 runtime (dialogue, wait, lock_control, play_cue, finish).
## No change_scene step exists in these beats: the Forgotten Shore handoff is
## the N4.5 contract, and pl_03+ are future milestones, so the shell's chain
## stops after pl_02 at the N4.2 boundary.
##
## LORE DISCIPLINE (docs/narrative/PROLOGUE_STORY_DESIGN.md):
##  - pl_01 narration is the Story Design "Beat 01 — The Lost World" candidate
##    narration, verbatim. The cause of the Great Eclipse is NOT stated
##    anywhere in these beats.
##  - pl_02 shows exactly ONE small, uncontrolled childhood manifestation:
##    one resonance cue, one narration line describing it, then failed
##    attempts to repeat it. No spellcasting, no control, no power origin.
##    The stone location stays unnamed (OPEN decision, Story Design §10) and
##    the crown never appears in either beat.
##  - Every stage caption is labelled placeholder text: no art or audio assets
##    are shipped in N4.2 (assets stay PROPOSED in the story design), and no
##    caption converts an OPEN lore detail into canon.
##  - Dialogue is authored in English (DECIDED language, Story Design §10).
##
## N4.3-A: pl_03/pl_04 are EXPLORATION beats orchestrated by the shell and its
## dedicated stage/actor — they are deliberately NOT in BEAT_IDS and have no
## authored SequenceRunner sequence, so the runner chain still ends after
## pl_02 and can never auto-chain past the player-driven exploration interval.
## Only their narrative TEXT lives here (Story Design authority): pl_03's
## approved candidate internal line is presented through the existing
## DialoguePanel at the start of exploration; N4.3-B adds pl_04's approved
## candidate recognition line for the two-distinct-object trigger.

const BEAT_IDS: Array[String] = [
	"pl_01_lost_world",
	"pl_02_faint_resonance",
]

## N4.3 exploration beat ids (shell-orchestrated, never runner sequences).
## N4.4-A adds pl_05 (the Forgotten Ruins) and the dormant pl_06 id: the
## shell-orchestrated chain continues past pl_04 (runtime beat table: pl_05
## entry = "pl_04 finished", pl_06 entry = "pl_05 finished"). pl_06 is DORMANT
## in N4.4-A — its interaction/awakening is N4.4-C/D; activating it only
## moves the shell's active-beat bookkeeping, it stages no content.
const PL_03_WANDERER: String = "pl_03_wanderer"
const PL_04_REPEATED_MARK: String = "pl_04_repeated_mark"
const PL_05_FORGOTTEN_RUINS: String = "pl_05_forgotten_ruins"
const PL_06_CROWNS_CALL: String = "pl_06_crowns_call"
const PL_06_VISION_SEQUENCE_ID: String = "pl_06_vision"
const PL_07_UNFINISHED_JOURNEY: String = "pl_07_unfinished_journey"
const PL_08_SHIPWRECK: String = "pl_08_shipwreck"

## Presentation speaker for adult Monarch (exploration internal lines).
const MONARCH: String = "Monarch"

## Presentation speakers (schema requires a non-empty speaker; narration uses
## a presentation label, not a character).
const NARRATOR: String = "Narration"
const YOUNG_MONARCH: String = "Young Monarch"

## Placeholder stage states (PrologueShell maps cue ids to labelled captions).
const CUE_PL01_PROSPERITY: String = "stage_pl01_prosperity"
const CUE_PL01_ECLIPSE: String = "stage_pl01_eclipse"
const CUE_PL01_RUINS: String = "stage_pl01_ruins"
const CUE_PL02_CHILDHOOD: String = "stage_pl02_childhood"
const CUE_PL02_RESONANCE: String = "stage_pl02_resonance"

## N4.4-B: canonical R12 vision data only. These are data accessors;
## they do not activate pl_06 or execute a vision sequence.
const CUE_PL06_VISION_KINGDOM: String = "stage_pl06_vision_kingdom"
const CUE_PL06_VISION_SILHOUETTE: String = "stage_pl06_vision_silhouette"
const CUE_PL06_VISION_SYMBOL: String = "stage_pl06_vision_symbol"
const CUE_PL06_VISION_FADING_LIGHT: String = "stage_pl06_vision_fading_light"
const CUE_PL06_VISION_DESTRUCTION: String = "stage_pl06_vision_destruction"
const CUE_PL06_AWAKENING: String = "stage_pl06_awakening"
const CUE_PL07_DEPARTURE: String = "stage_pl07_departure"
const CUE_PL07_OPEN_SEA: String = "stage_pl07_open_sea"
const CUE_PL08_STORM_GATHERS: String = "stage_pl08_storm_gathers"
const CUE_PL08_SHIPWRECK: String = "stage_pl08_shipwreck"
const CUE_PL08_FADE_OUT: String = "stage_pl08_fade_out"

const VISION_FRAGMENT_IDS: Array[String] = [
	"vision_ancient_kingdom",
	"vision_ruler_silhouette",
	"vision_recurring_symbol",
	"vision_fading_light",
	"vision_interrupted_destruction",
]

## Provisional only: OPEN owner decision O5. Never wired to UI/input in N4.4-B.
const ALTAR_PROMPT_PROPOSAL_TEXT: String = "[E] Touch the crown"

const _VISION_FRAGMENTS: Array[Dictionary] = [
	{"id": "vision_ancient_kingdom", "cue_id": CUE_PL06_VISION_KINGDOM, "subject": "ancient kingdom", "caption": "[Placeholder art] Fragmented vision — an unnamed ancient kingdom in brief flashes"},
	{"id": "vision_ruler_silhouette", "cue_id": CUE_PL06_VISION_SILHOUETTE, "subject": "ruler's silhouette", "caption": "[Placeholder art] Fragmented vision — an unidentifiable ruler's silhouette"},
	{"id": "vision_recurring_symbol", "cue_id": CUE_PL06_VISION_SYMBOL, "subject": "recurring symbol", "caption": "[Placeholder art] Fragmented vision — the recurring symbol"},
	{"id": "vision_fading_light", "cue_id": CUE_PL06_VISION_FADING_LIGHT, "subject": "fading light", "caption": "[Placeholder art] Fragmented vision — a fading golden light"},
	{"id": "vision_interrupted_destruction", "cue_id": CUE_PL06_VISION_DESTRUCTION, "subject": "interrupted destruction", "caption": "[Placeholder art] Fragmented vision — interrupted images of collapse, cut short"},
]

const _R13_PATTERNS: Array[String] = [
	"(?i)\\bking\\b",
	"(?i)\\bqueen\\b",
	"(?i)\\bemperor\\b",
	"(?i)\\bdynasty\\b",
	"(?i)\\bbloodline\\b",
	"(?i)\\bheir\\b",
	"(?i)\\beclipse\\b.*\\bcaus(e|ed|ing)\\b",
	"(?i)\\bcaus(e|ed|ing)\\b.*\\beclipse\\b",
	"(?i)\\bforged\\b.*\\bcrown\\b",
	"(?i)\\borigin\\b.*\\bcrown\\b",
	"(?i)\\bcrown\\b.*\\borigin\\b",
	"(?i)\\bgrant(s|ed|ing)?\\b.*\\bpower\\b",
	"(?i)\\bsource\\b.*\\bpower\\b",
	"(?i)\\bpower\\s+source\\b",
	"(?i)\\bpower\\b.*\\bsource\\b",
]


## Returns the authored sequence for a beat id, deep-copied so callers can
## never mutate the authored content. Unknown ids return {}.
static func get_beat(beat_id: String) -> Dictionary:
	var beat: Dictionary = _beats().get(beat_id, {})
	return beat.duplicate(true) if not beat.is_empty() else {}


## True when the id is one of the authored prologue beats.
static func is_beat(sequence_id: String) -> bool:
	return BEAT_IDS.has(sequence_id)


## True when the id is one of the shell-orchestrated exploration beats
## (pl_03..pl_06). These never enter BEAT_IDS: SequenceRunner must not chain
## or validate them as sequences. pl_06 is dormant in N4.4-A (N4.4-C/D own
## its interaction and completion); the id exists so the shell can activate
## it as the post-pl_05 chain state.
static func is_exploration_beat(sequence_id: String) -> bool:
	return sequence_id == PL_03_WANDERER or sequence_id == PL_04_REPEATED_MARK \
		or sequence_id == PL_05_FORGOTTEN_RUINS or sequence_id == PL_06_CROWNS_CALL


## Human-readable exploration beat title (status presentation only).
static func exploration_beat_title(beat_id: String) -> String:
	match beat_id:
		PL_03_WANDERER:
			return "The Wanderer"
		PL_04_REPEATED_MARK:
			return "The Repeated Mark"
		PL_05_FORGOTTEN_RUINS:
			return "The Forgotten Ruins"
		PL_06_CROWNS_CALL:
			return "The Crown's Call"
		_:
			return "Prologue exploration"


## The approved Story Design candidate internal line for an exploration beat,
## presented through the existing DialoguePanel (not a SequenceRunner
## sequence). pl_03 uses the Beat 03 candidate text verbatim. pl_04's
## recognition line lives in exploration_recognition_lines() (N4.3-B).
static func exploration_intro_lines(beat_id: String) -> Array[Dictionary]:
	if beat_id == PL_03_WANDERER:
		return [
			{"speaker": MONARCH, "text": "Some things are difficult to forget."},
			{"speaker": MONARCH, "text": "Especially the things you cannot explain."},
		]
	return []


## The approved Story Design Beat 04 candidate recognition line, verbatim
## ("I've seen this mark before..." / "Why does it keep appearing?"), played
## through the existing DialoguePanel when two DISTINCT inspectables have
## been inspected (N4.3-B). Speaker presentation follows the exploration
## convention (MONARCH). Data only — the shell-orchestrated presentation and
## the completion handshake live in the exploration stage; this is never a
## SequenceRunner sequence, and no lore beyond this approved text exists.
static func exploration_recognition_lines() -> Array[Dictionary]:
	return [
		{"speaker": MONARCH, "text": "I've seen this mark before..."},
		{"speaker": MONARCH, "text": "Why does it keep appearing?"},
	]


## Approved R15 post-vision dialogue lines (verbatim, in order).
static func exploration_post_vision_lines() -> Array[Dictionary]:
	return [
		{"speaker": MONARCH, "text": "What... was that?"},
		{"speaker": MONARCH, "text": "I've never seen those places before."},
	]


## N4.4-D presentation-only vision sequence (existing allowlisted ops only).
static func vision_sequence() -> Dictionary:
	var steps: Array[Dictionary] = [
		{"op": "lock_control"},
		{"op": "play_cue", "cue_id": CUE_PL06_AWAKENING},
		{"op": "wait", "seconds": 0.15},
	]
	for fragment: Dictionary in _VISION_FRAGMENTS:
		steps.append({"op": "play_cue", "cue_id": String(fragment["cue_id"])})
		steps.append({"op": "wait", "seconds": 0.12})
	steps.append({"op": "finish"})
	return {
		"id": PL_06_VISION_SEQUENCE_ID,
		"skip_allowed": true,
		"steps": steps,
	}


## N4.5-A pl_07 Unfinished Journey sequence (existing allowlisted ops only).
static func voyage_sequence() -> Dictionary:
	return {
		"id": PL_07_UNFINISHED_JOURNEY,
		"skip_allowed": true,
		"steps": [
			{"op": "lock_control"},
			{"op": "play_cue", "cue_id": CUE_PL07_DEPARTURE},
			{"op": "wait", "seconds": 0.25},
			{"op": "play_cue", "cue_id": CUE_PL07_OPEN_SEA},
			{"op": "wait", "seconds": 0.3},
			{"op": "finish"},
		],
	}


## N4.5-A pl_08 Shipwreck sequence (existing allowlisted ops only).
static func shipwreck_sequence() -> Dictionary:
	return {
		"id": PL_08_SHIPWRECK,
		"skip_allowed": true,
		"steps": [
			{"op": "lock_control"},
			{"op": "play_cue", "cue_id": CUE_PL08_STORM_GATHERS},
			{"op": "wait", "seconds": 0.25},
			{"op": "play_cue", "cue_id": CUE_PL08_SHIPWRECK},
			{"op": "wait", "seconds": 0.3},
			{"op": "play_cue", "cue_id": CUE_PL08_FADE_OUT},
			{"op": "wait", "seconds": 0.2},
			{"op": "finish"},
		],
	}


## Placeholder caption for a stage cue id (labelled placeholder; unknown ids
## fall back to a generic labelled caption so nothing unlabelled can show).
static func stage_caption(cue_id: String) -> String:
	match cue_id:
		CUE_PL01_PROSPERITY:
			return "[Placeholder art] Aetherion beneath the First Light — kingdoms at their height"
		CUE_PL01_ECLIPSE:
			return "[Placeholder art] The Great Eclipse — the light vanishes"
		CUE_PL01_RUINS:
			return "[Placeholder art] Abandoned kingdoms and ruined landscapes"
		CUE_PL02_CHILDHOOD:
			return "[Placeholder art] Childhood memory — an old stone wall"
		CUE_PL02_RESONANCE:
			return "[Placeholder art] Thin golden light in the stone cracks — brief, uncontrolled"
		CUE_PL06_VISION_KINGDOM:
			return "[Placeholder art] Fragmented vision — an unnamed ancient kingdom in brief flashes"
		CUE_PL06_VISION_SILHOUETTE:
			return "[Placeholder art] Fragmented vision — an unidentifiable ruler's silhouette"
		CUE_PL06_VISION_SYMBOL:
			return "[Placeholder art] Fragmented vision — the recurring symbol"
		CUE_PL06_VISION_FADING_LIGHT:
			return "[Placeholder art] Fragmented vision — a fading golden light"
		CUE_PL06_VISION_DESTRUCTION:
			return "[Placeholder art] Fragmented vision — interrupted images of collapse, cut short"
		CUE_PL07_DEPARTURE:
			return "[Placeholder art] Leaving the forgotten ruins behind — the search continues"
		CUE_PL07_OPEN_SEA:
			return "[Placeholder art] At sea — an uncharted course into open waters"
		CUE_PL08_STORM_GATHERS:
			return "[Placeholder art] Dark clouds gather — a sudden storm overtakes the ship"
		CUE_PL08_SHIPWRECK:
			return "[Placeholder art] Waves break across the deck — the vessel loses control"
		CUE_PL08_FADE_OUT:
			return "[Placeholder art] The wreck vanishes into darkness"
		CUE_PL06_AWAKENING:
			return "[Placeholder art] Faint golden resonance — recalling the childhood light, brief and uncontrolled"
		_:
			return "[Placeholder stage] %s" % cue_id


## Returns a deep copy of the canonical five R12 fragments.
static func vision_fragments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fragment: Dictionary in _VISION_FRAGMENTS:
		result.append(fragment.duplicate(true))
	return result


## Awakening is a separate cue, never a sixth R12 vision fragment.
static func awakening_cue_entry() -> Dictionary:
	return {
		"cue_id": CUE_PL06_AWAKENING,
		"caption": stage_caption(CUE_PL06_AWAKENING),
	}


## Fail-closed R12 schema and R13 lore fence. Regex is a regression guard;
## semantic lore approval remains a human owner-review responsibility.
static func validate_vision_fragments(fragments: Variant) -> Dictionary:
	var errors: Array[String] = []
	if typeof(fragments) != TYPE_ARRAY:
		errors.append("Vision fragments must be an Array")
		return {"ok": false, "errors": errors}
	var raw: Array = fragments as Array
	if raw.size() != VISION_FRAGMENT_IDS.size():
		errors.append("Vision fragments must contain exactly five entries")
		return {"ok": false, "errors": errors}

	var expected_cues: Dictionary = {
		"vision_ancient_kingdom": CUE_PL06_VISION_KINGDOM,
		"vision_ruler_silhouette": CUE_PL06_VISION_SILHOUETTE,
		"vision_recurring_symbol": CUE_PL06_VISION_SYMBOL,
		"vision_fading_light": CUE_PL06_VISION_FADING_LIGHT,
		"vision_interrupted_destruction": CUE_PL06_VISION_DESTRUCTION,
	}
	var allowed_keys: Array[String] = ["id", "cue_id", "subject", "caption"]
	var seen_ids: Dictionary = {}
	var seen_cues: Dictionary = {}
	for index: int in range(raw.size()):
		if typeof(raw[index]) != TYPE_DICTIONARY:
			errors.append("vision_fragments[%d] must be a Dictionary" % index)
			continue
		var item: Dictionary = raw[index] as Dictionary
		var valid_keys: bool = true
		for key: Variant in item.keys():
			if String(key) not in allowed_keys:
				errors.append("vision_fragments[%d] has unknown key '%s'" % [index, String(key)])
				valid_keys = false
		if not valid_keys:
			continue
		for key: String in allowed_keys:
			if not item.has(key):
				errors.append("vision_fragments[%d] is missing '%s'" % [index, key])
		if not item.has_all(allowed_keys):
			continue
		if typeof(item["id"]) != TYPE_STRING or typeof(item["cue_id"]) != TYPE_STRING \
				or typeof(item["subject"]) != TYPE_STRING or typeof(item["caption"]) != TYPE_STRING:
			errors.append("vision_fragments[%d] fields must all be Strings" % index)
			continue
		var fragment_id: String = String(item["id"])
		var cue_id: String = String(item["cue_id"])
		var subject: String = String(item["subject"])
		var caption: String = String(item["caption"])
		if fragment_id.strip_edges().is_empty() or fragment_id.length() > NarrativeData.MAX_ID_LENGTH:
			errors.append("vision_fragments[%d] id must be 1-%d characters" % [index, NarrativeData.MAX_ID_LENGTH])
		if not VISION_FRAGMENT_IDS.has(fragment_id):
			errors.append("vision_fragments[%d] has unknown id '%s'" % [index, fragment_id])
		if seen_ids.has(fragment_id):
			errors.append("vision_fragments[%d] duplicates id '%s'" % [index, fragment_id])
		seen_ids[fragment_id] = true
		if cue_id.strip_edges().is_empty() or cue_id.length() > NarrativeData.MAX_ID_LENGTH:
			errors.append("vision_fragments[%d] cue_id must be 1-%d characters" % [index, NarrativeData.MAX_ID_LENGTH])
		if seen_cues.has(cue_id):
			errors.append("vision_fragments[%d] duplicates cue_id '%s'" % [index, cue_id])
		seen_cues[cue_id] = true
		if expected_cues.has(fragment_id) and cue_id != String(expected_cues[fragment_id]):
			errors.append("vision_fragments[%d] cue_id does not match id '%s'" % [index, fragment_id])
		if subject.strip_edges().is_empty() or subject.length() > NarrativeData.MAX_TEXT_LENGTH:
			errors.append("vision_fragments[%d] subject must be 1-%d characters" % [index, NarrativeData.MAX_TEXT_LENGTH])
		if caption.strip_edges().is_empty() or not caption.begins_with("[Placeholder art]") or caption.length() > NarrativeData.MAX_TEXT_LENGTH:
			errors.append("vision_fragments[%d] caption must be labelled placeholder text of at most %d characters" % [index, NarrativeData.MAX_TEXT_LENGTH])
		var content: String = subject + " " + caption
		for pattern: String in _R13_PATTERNS:
			var regex := RegEx.new()
			if regex.compile(pattern) != OK:
				errors.append("R13 validator pattern failed to compile: %s" % pattern)
				break
			if regex.search(content) != null:
				errors.append("vision_fragments[%d] violates R13 content fence" % index)
				break
	return {"ok": errors.is_empty(), "errors": errors}


## The authored beats. Data only — nothing here executes anything.
static func _beats() -> Dictionary:
	return {
		"pl_01_lost_world": {
			"id": "pl_01_lost_world",
			"skip_allowed": true,
			"steps": [
				{"op": "lock_control"},
				{"op": "play_cue", "cue_id": CUE_PL01_PROSPERITY},
				{"op": "dialogue", "lines": [
					{"speaker": NARRATOR, "text": "Long ago, Aetherion flourished beneath the light of an ancient power."},
					{"speaker": NARRATOR, "text": "Kingdoms rose. Civilizations prospered. And the world endured beneath the First Light."},
				]},
				{"op": "play_cue", "cue_id": CUE_PL01_ECLIPSE},
				{"op": "wait", "seconds": 1.2},
				{"op": "dialogue", "lines": [
					{"speaker": NARRATOR, "text": "Then came the Great Eclipse."},
				]},
				{"op": "play_cue", "cue_id": CUE_PL01_RUINS},
				{"op": "wait", "seconds": 1.0},
				{"op": "dialogue", "lines": [
					{"speaker": NARRATOR, "text": "The light vanished. Kingdoms fell. And the world was left to the ages."},
				]},
				{"op": "finish"},
			],
		},
		"pl_02_faint_resonance": {
			"id": "pl_02_faint_resonance",
			"skip_allowed": true,
			"steps": [
				{"op": "lock_control"},
				{"op": "play_cue", "cue_id": CUE_PL02_CHILDHOOD},
				{"op": "dialogue", "lines": [
					{"speaker": NARRATOR, "text": "Years ago, a child paused beside an old stone wall."},
					{"speaker": YOUNG_MONARCH, "text": "...Warm. Why would a plain stone be warm?"},
				]},
				{"op": "play_cue", "cue_id": CUE_PL02_RESONANCE},
				{"op": "wait", "seconds": 1.0},
				{"op": "dialogue", "lines": [
					{"speaker": NARRATOR, "text": "When his fingers brushed the stone, thin golden light ran through the cracks — there for a breath, then gone."},
					{"speaker": YOUNG_MONARCH, "text": "What was that? Did I do that?"},
					{"speaker": NARRATOR, "text": "He tried again, and kept trying. The stone never answered him."},
					{"speaker": YOUNG_MONARCH, "text": "It never came back. But I never forgot it."},
				]},
				{"op": "finish"},
			],
		},
	}
