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

const BEAT_IDS: Array[String] = [
	"pl_01_lost_world",
	"pl_02_faint_resonance",
]

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


## Returns the authored sequence for a beat id, deep-copied so callers can
## never mutate the authored content. Unknown ids return {}.
static func get_beat(beat_id: String) -> Dictionary:
	var beat: Dictionary = _beats().get(beat_id, {})
	return beat.duplicate(true) if not beat.is_empty() else {}


## True when the id is one of the authored prologue beats.
static func is_beat(sequence_id: String) -> bool:
	return BEAT_IDS.has(sequence_id)


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
		_:
			return "[Placeholder stage] %s" % cue_id


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
