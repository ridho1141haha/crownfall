# Crownfall — Chapter I Narrative Gap Analysis

**Audit date:** 2026-11-17 (refreshed after PR #11)  
**Snapshot:** `main` @ `eb82ae4d63a33a5c0fb9bb3f17f4bf832860c79a` (PR #11 merged)  
**Engine:** Godot `4.7.2.stable`  
**Companion docs:** [`NARRATIVE_IMPLEMENTATION_AUDIT.md`](NARRATIVE_IMPLEMENTATION_AUDIT.md), the official [`NARRATIVE_IMPLEMENTATION_ROADMAP.md`](NARRATIVE_IMPLEMENTATION_ROADMAP.md) (phases N0–N5), and [`narrative/PROLOGUE_STORY_DESIGN.md`](narrative/PROLOGUE_STORY_DESIGN.md)  
**Rule:** This document does not invent or resolve lore. Open mysteries stay open.

---

## 1. Scope and the Prologue / Chapter I boundary

The repository now separates two narrative scopes:

- **Prologue — “The Crown's Call”** (`docs/narrative/PROLOGUE_STORY_DESIGN.md`): happens **before** the sea voyage, the shipwreck, and the arrival on Forgotten Shore. **Crown Discovery (beats 05–06), Crown Awakening, and the Vision are Prologue content, not Chapter I beats.**
- **Chapter I — Forgotten Shore** (`docs/GDD.md:58-66`): begins when the player regains control on Forgotten Shore and continues with survival, exploration, and the gradual establishment of a settlement (`PROLOGUE_STORY_DESIGN.md:218-231`).

The GDD distinguishes the implemented N1–N3 runtime foundation from the still-unimplemented Prologue and Chapter I story content (`docs/GDD.md:66,112`). The official roadmap adds the N0–N5 phases, with N4 = Prologue content integration and N5 = the separate Chapter I content milestone.

**Current planning state:** a first Chapter I beat sheet proposal now exists in [`CHAPTER_01_BEAT_SHEET.md`](CHAPTER_01_BEAT_SHEET.md). It is a **draft, non-canon proposal** pending owner approval; no dialogue script is approved and no Chapter I content is implemented.

---

## 2. Prologue status (designed, not implemented)

The Prologue is designed but has **no playable content implementation** (no Prologue scenes or authored sequences). The N1–N3 dialogue/sequence runtime foundation exists on main but is not yet connected to Prologue content. It is tracked by roadmap phases N0–N4 rather than as Chapter I work.

| # | Prologue beat (designed) | Runtime status | Source |
|---|---|---|---|
| 01 | The Lost World — Aetherion, The First Light, the Great Eclipse | **Designed only** | `PROLOGUE_STORY_DESIGN.md:49-162` |
| 02 | A Faint Resonance — one small uncontrolled childhood manifestation | **Designed only** | same |
| 03 | The Wanderer — adult Monarch searches for an explanation | **Designed only** | same |
| 04 | The Repeated Mark — the same unresolved royal symbol on ancient remains | **Designed only** | same |
| 05 | The Forgotten Ruins — clues lead to a hidden chamber and altar | **Designed only** | same |
| 06 | The Crown's Call — crown discovery, awakening, fragmented vision | **Designed only** | same |
| 07 | The Unfinished Journey — continues the search by sea | **Designed only** | same |
| 08 | The Shipwreck — storm wrecks the ship (connection to the crown unknown) | **Designed only** | same |
| 09 | Forgotten Shore — wakes on the island with the crown; handoff to Chapter I | **Designed only** | `:218-231` |

**Key designed decisions (no longer “undecided”):**
- Monarch is human with dormant inherited power; childhood resonance; adult search (`PROLOGUE_STORY_DESIGN.md:24-38`).
- The crown is a **trigger/key, not the source of Monarch's power** (`:31`); “the crown awakens, it does not grant” (`:44`).
- Touching the crown triggers a fragmented vision (ancient kingdom, ruler silhouette, recurring symbol, fading light, interrupted destruction) that raises more questions than it answers (`:33`, beat 06).
- Balanced storytelling: cinematic moments, short dialogue, gameplay, environmental storytelling, audio (`:36`).
- Leadership must be earned; bloodline and power do not make a worthy ruler (`:38`, `:44`).
- Do not reveal the ruler's identity, dynasty/kingdom name, power source, crown origin, or Great Eclipse cause (beat 06; roadmap §4).

**Remaining OPEN for the Prologue** (`PROLOGUE_STORY_DESIGN.md:248-265`): the royal symbol's exact design, the ruins' name, the exact childhood location, prior travel notes/artifacts, the ship's origin, the voyage destination, the cause of the storm, the crown's post-wreck appearance (draft), dialogue language/voice, and Prologue skip behavior.

**Verdict:** crown discovery, awakening, and vision are **designed Prologue beats awaiting the N0 design-lock approvals and N4 content**, not missing Chapter I beats. They are not implemented today.

**Runtime foundation note:** N1–N3 are implemented and merged on `main` through PR #11: `DialoguePanel`, `PlayerControlLock`, `dialogue_advance`, `SequenceRunner`, in-memory `NarrativeState`, and `NarrativeData` validation. Tests include non-canon fixtures. No Prologue or Chapter I content is wired to the runtime yet, and SaveManager schema v2 is unchanged.

---

## 3. Chapter I beat matrix

Status: **EXISTS** = implemented and reachable; **PARTIAL** = gameplay/system exists but the narrative beat is absent/incomplete; **MISSING** = no implementation; **DESIGNED** = planned in an approved design doc but not implemented; **AMBIGUOUS** = implementation exists but canon/identity is unresolved.

| # | Chapter I beat | Status | One-line finding | Primary evidence |
|---:|---|---|---|---|
| 1 | Opening / arrival handoff (Prologue beat 09) | **DESIGNED, not implemented** | Landing beat (wake, wreckage, crown continuity, title card, prompt control return) is designed; the build loads directly into Forgotten Shore with no arrival scene. | `PROLOGUE_STORY_DESIGN.md:218-231`; `Main.gd:18-27`; `ForgottenShoreSession.gd:84,99` |
| 2 | Monarch identity / background establishment | **DESIGNED (Prologue), not implemented in-game** | Monarch direction is designed (curious, observant, not a trained mage/experienced king; survival-first after landing). No in-game identity, name, history, or voice exists. | `PROLOGUE_STORY_DESIGN.md:24-38,165-178`; `Player.gd:1-21`; `Player.tscn:4-13` |
| 3 | Settlement establishment | **PARTIAL** | The full settlement loop exists (resources, recruitment, walls, hearth, night survival); no narrative framing for the establishment beat. | `ForgottenShore.tscn`; `ForgottenShoreSession.gd:84-99,130-148`; `BuildingManager.gd` |
| 4 | Existing NPCs and dialogue | **PARTIAL (NPCs + runtime) / MISSING (content integration)** | NPC agents and the Scientist exist; the dialogue panel/runtime is implemented but is not connected to NPC conversations. No canon Chapter I script, portraits, choices, or voice. | `NPCBuilderAgent.gd:21-100`; `NPCPopulationManager.gd:7-68`; `InteractionResolver.gd:146-198`; `ClockHUD.gd:11,125` |
| 5 | Greedling narrative context | **PARTIAL (lore out of scope)** | Threat names/forecasts/warnings exist; the origins and purpose of Greedlings and the Greed Portal are explicitly out of scope until approved. | `data/enemies.json:3-17`; `NightEncounterManager.gd:25-29,107-133`; `ForgottenShoreSession.gd:920-966`; roadmap §4 |
| 6 | Forgotten Shrine | **PARTIAL + AMBIGUOUS** | A −780 “Forgotten Shrine” cache/offering and an 820 “Shrine of Growth” structure both exist; roadmap N5 requires preserving their separate identities until an explicit lore decision. | `data/resource_nodes.json:40-46`; `ResourceNodeManager.gd:13`; `InteractionResolver.gd:50-61`; `ForgottenShoreSession.gd:437-449,676-707`; `data/structures.json:3-20`; roadmap N5 |
| 7 | Ancient Relic | **PARTIAL + AMBIGUOUS** | One-time Greed Portal loot labelled “Ancient Relic”; no artifact system/lore; defining the Ancient Relic is out of scope. | `ForgottenShoreSession.gd:656-675,997-1001`; `data/resources.json`; `GDD.md:107,125`; roadmap §4 |
| 8 | Shipwreck (departure vessel) | **PARTIAL** | Three-stage repair → vessel-ready → island-cleared banner; no voyage scene or chapter transition. Distinct from the designed Prologue beat 08 (arrival wreck). | `ForgottenShoreSession.gd:15-17,619-655`; `ForgottenShore.tscn` ShipwreckAnchor; `PROLOGUE_STORY_DESIGN.md` beat 08 |
| 9 | Chapter progression and story completion | **MISSING as narrative** | No chapter model/facts/flow; only era/`ReignState`/gameplay completion. Chapter I beat sheet is the N5 gate. | `ForgottenShoreSession.gd:7-11,619-655,920-966`; `ProgressionState.gd:25-95`; roadmap N5 |

**Count:** 0 Chapter I narrative beats implemented. Existing gameplay covers parts of beats 3–8, but no authored Chapter I story sequence is playable. The dialogue/sequence runtime exists but has no Chapter I content integration. **Prologue: 9 beats designed, 0 implemented.**

---

## 4. Beat-by-beat analysis (Chapter I)

### Beat 1 — Opening / arrival handoff

**Intended function (documented):** Prologue beat 09 — Monarch wakes on Forgotten Shore, the wreckage and unfamiliar island are shown, the crown stays with him (no dialogue explaining its survival), control returns promptly (`PROLOGUE_STORY_DESIGN.md:218-231`). A title card “CHAPTER I — FORGOTTEN SHORE” is drafted; the optional “A new kingdom begins” tagline is explicitly flagged for review because Monarch initially seeks survival, not kingship.

**Exists**
- `Main.tscn` Start/Continue/Exit; both Start and Continue route straight to `ForgottenShore.tscn` (`Main.gd:18-27`).
- The first in-game feedback is a controls line (`ForgottenShoreSession.gd:99`).

**Missing**
- The landing scene/sequence, wreckage presentation, crown continuity detail, title card, and control-handoff policy.
- The approved New Game / Continue routing (roadmap §6: New Game → Prologue → fresh shore; Continue → direct load; policy still approval-required).

**Dependencies / decisions**
- Entry-flow policy sign-off (roadmap §6); skip behavior (OPEN); landing staging details (N0).

**Status:** **DESIGNED, not implemented.**

---

### Beat 2 — Monarch identity / background establishment

**Intended function (documented):** Monarch's identity direction is fixed by the Prologue design (`:24-38,165-178`): human, dormant inherited power, childhood resonance, adult search, “surprised and confused, not instantly convinced he is royal” after the vision, and “focuses on immediate survival” after the shipwreck.

**Exists**
- `PlayerController` (`Player.gd`), `player_monarch_sheet.png`, movement/interaction signals, camera.
- Docs call the character “Monarch”.

**Missing**
- Any in-game name, portrait, voice, or identity presentation; any narrative state about the Monarch.
- Chapter I dialogue that expresses the survival-first mindset (candidate lines only; no script).

**Dependencies / decisions**
- Dialogue language/voice (OPEN); which Chapter I beats carry the identity line (N5 beat sheet).

**Status:** **DESIGNED (Prologue), not implemented in-game.**

---

### Beat 3 — Settlement establishment

**Intended function (documented):** “Establish the first settlement” (`GDD.md:60`); the settlement should grow from survival into leadership through gameplay (`PROLOGUE_STORY_DESIGN.md:226-231`).

**Exists**
- The scene loads on Forgotten Shore with the Monarch at `x=0` next to a fixed Town Center/Hearth.
- The establishment loop is fully playable: resource collection, villager recruitment, wall construction, watchtower/farm plots, hearth upgrades, day/night survival, shipwreck repair, specialists, research, structures.
- Environment labels and resource nodes provide an “abandoned shore” surface.

**Missing**
- Narrative framing for the establishment (why the Monarch settles, first decisions, first night context).
- Any authored environmental storytelling beyond labels (no inscriptions, notes, memories).

**Dependencies / decisions**
- Chapter I beat sheet (N5) decides how settlement progress is narrated.

**Status:** **PARTIAL** — gameplay exists; the narrative beat is missing.

---

### Beat 4 — Existing NPCs and dialogue

**Intended function (documented):** Recruit villagers and a Builder (`GDD.md:143-153`); Scientist discovery/recruitment (`:138`). Prologue dialogue rules set the tone (short, natural lines; no self-coronation; no world-explaining exposition) (`PROLOGUE_STORY_DESIGN.md:165-178`).

**Exists**
- NPC agents with IDs/roles/states; tool stands; Scientist discovery/housing/recruitment/research handoff.
- Interaction prompts and one-line feedback (`InteractionResolver.gd:146-198`; `ClockHUD.gd:11,125`).
- The N2 dialogue runtime foundation (`DialoguePanel`, `dialogue_advance` input, `PlayerControlLock`) exists on main but is not wired to any NPC.

**Missing**
- Canon conversation data and NPC integration (the panel exists; no Chapter I script/speaker content exists), speaker names/portraits, choices, voice.
- NPC names beyond role/display name; `description` fields are never displayed.
- Any `talk` interaction that is not also a recruit/research action.

**Dependencies / decisions**
- Which NPCs speak and what they say (Chapter I script, N5); presentation style (N0/N2); whether conversations gate recruitment/housing/research.

**Status:** **PARTIAL NPC systems / MISSING dialogue.**

---

### Beat 5 — Greedling narrative context

**Intended function (documented):** Hostile creatures emerge after sunset (`GDD.md:24`); the first enemy is the Greedling Raider (`:167`; `DECISIONS_M2_M8.md:22`). The roadmap explicitly leaves **defining the origins or purpose of Greedlings and the Greed Portal** out of scope (roadmap §4).

**Exists**
- Enemy archetypes and names; night forecast, sunset/night warnings, west-scout warnings, breach feedback, enemy labels; a “Greed Portal” landmark with a one-time relic reward.

**Missing**
- Any explanation of what Greedlings are or why they attack — intentionally unresolved, not to be invented.

**Dependencies / decisions**
- Whether Chapter I exposition touches the Greed at all, and in what form (N5; approval required).

**Status:** **PARTIAL** — threat pressure exists; context intentionally absent.

---

### Beat 6 — Forgotten Shrine

**Intended function (documented):** Far-western Forgotten Shrine at `x=-780` grants `+3 Gold` (`GDD.md:38`; `DECISIONS_M2_M8.md:24`; `PRD.md:341`). Phase 5 separately adds the `Shrine of Growth` structure at `x=820` (`PROGRESSION_FOUNDATION_DESIGN.md:534-544`). Roadmap N5: do not conflate them until an explicit lore decision.

**Exists**
- `shrine_cache_far_west` (−780): one-time +3 Gold; daily offering (4W+2S → +2G; +5G with research).
- `shrine_of_growth` (820): structure activation (4G+2W+3S) after Stone Wall Tier 2; +1 Wood per wood acquisition; dormant/awakened sprite; HUD blessing line.
- Descriptions exist in data but are not displayed.

**Missing / ambiguous**
- Canon identity/relationship of the two shrines.
- Which shrine carries Chapter I narrative content, and what the offering/activation mean.
- Whether the Scientist's “Forgotten Shrine inscriptions” research refers to the −780 site, the 820 structure, or both.

**Dependencies / decisions**
- Explicit lore decision (roadmap N5); narrative content per the N5 beat sheet.

**Status:** **PARTIAL + AMBIGUOUS.**

---

### Beat 7 — Ancient Relic

**Intended function (documented):** Ancient Relics are a deferred resource category (`GDD.md:107,125`; `REVISED_PROJECT_BASELINE.md:23,101`); the roadmap leaves defining the Ancient Relic out of scope (roadmap §4).

**Exists**
- One-time “Ancient Relic” loot at the Greed Portal (x=1350): +3 Gold, +2 Stone, `portal_relic_looted`, label change to “Greed Portal (Scavenged)”.

**Missing / ambiguous**
- No relic item/inventory/lore/consequence beyond the one-time resources.
- Terminology conflict with the deferred “Ancient Relics” resource category.

**Dependencies / decisions**
- Artifact vs reward cache (approval required); if it ever relates to the crown, that decision belongs to the owner, not this audit.

**Status:** **PARTIAL + AMBIGUOUS.**

---

### Beat 8 — Shipwreck (departure vessel)

**Intended function (documented):** Shipwreck Stage 3 means the vessel is ready to sail; it does not unlock an era (`GDD.md:132`; `PROGRESSION_FOUNDATION_DESIGN.md:240-259`). The shipped feedback points toward Eldergrove Forest (the future Island 2); the GDD's Chapter II is titled “The Lost Kingdom.” The Prologue beat 08 is a different, designed arrival-wreck cinematic.

**Exists**
- Three-stage repair at `x=-1350`; Stage 3 records `forgotten_shore_vessel_ready`; “ISLAND CLEARED” + voyage banner on set-sail; peaceful post-victory nights.

**Missing**
- Any departure/voyage sequence or island transition.
- Narrative framing of who built the ship, where it goes, and what the Monarch expects.
- A chapter-completion model separate from `ISLAND_CLEARED`.

**Dependencies / decisions**
- Chapter I end condition and Chapter II handoff (N5; approval required).

**Status:** **PARTIAL** — preparation and a banner exist; the journey/chapter transition does not.

---

### Beat 9 — Chapter progression and story completion

**Intended function (documented):** Chapters I–V are a long-term direction (`GDD.md:58-66`). Chapter I is a separate content milestone in the roadmap (N5); no chapter framework is approved or implemented.

**Exists**
- Era progression (Wood → Stone → Iron, Iron unreachable on Forgotten Shore by design).
- `ReignState { ACTIVE, BREACH_PENALTY, ISLAND_CLEARED }`.
- Durable progression facts (14 IDs) and strict save/load.
- `ISLAND_CLEARED` victory banner and peaceful post-victory state.

**Missing**
- Chapter model/facts/state, chapter start/end flow, chapter UI, replay/continue semantics.
- A narrative completion condition distinct from gameplay victory.
- The Chapter I beat sheet (N5 exit gate).

**Dependencies / decisions**
- Chapter definitions and completion criteria; relationship between era progression, facts, `ISLAND_CLEARED`, and chapters.

**Status:** **MISSING as narrative** (gameplay completion only).

---

## 5. Dependencies and unresolved decisions

### 5.1 Resolved by the Prologue design (no longer blockers)

- Crown discovery location/staging (hidden chamber, altar), crown = trigger/key, awakening + fragmented vision content, Monarch progression, Prologue beat sequence, storytelling style.

### 5.2 Still OPEN

**Prologue** (`PROLOGUE_STORY_DESIGN.md:248-265`): royal symbol design, ruins name, childhood location, travel notes/artifacts, ship origin, voyage destination, storm cause, crown post-wreck appearance (draft), dialogue language/voice, skip behavior.

**Protected mysteries (must not be revealed):** crown origin, power source, dynasty/ancestor, ancient kingdom name, Great Eclipse cause.

**Chapter I / world lore:** Forgotten Shrine vs Shrine of Growth identity (roadmap N5); Ancient Relic definition; Greedlings/Greed Portal origins and purpose (roadmap §4); Chapter I end condition and Chapter II handoff.

### 5.3 Process / technical decisions

- New Game / Continue entry-flow policy and legacy-save behavior (roadmap §6 — policy is documented, but remaining PROPOSED/OPEN items still require owner approval before N4 wiring).
- N0 production details: repeated-symbol visual design, childhood staging, vision visual language, ship-to-island transition.
- N4 Prologue production/implementation and the fresh Forgotten Shore handoff.
- N5 Chapter I beat sheet approval, dialogue language/voice, proposed first-night and Scientist beats, and chapter-end condition.
- Whether any gameplay-embedded sequence needs explicit world pause; current technical design says world simulation continues during gameplay dialogue unless a future approved operation changes that policy.
- Whether a narrow `talk` interaction is needed for approved NPC beats; do not add it pre-emptively.

The runtime foundation (N1–N3) is no longer a pending process decision. Its technical contract is documented in `narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` and implemented on main by PR #11.

---

## 6. What can be implemented without new lore

The following work can proceed as **documentation/design** without resolving OPEN lore:

- Review the draft Chapter I beat sheet and map beats to already-shipped gameplay milestones.
- Define dialogue purpose and speaker roles without inventing personal histories, origins, or protected mysteries.
- Prepare N4 scene/asset/test tasks from the Prologue design.
- Specify idempotent trigger and control-handoff tests using the existing N1–N3 runtime.

The runtime foundation is already implemented. Content implementation remains gated by owner approval of the relevant beat sheet and N0/entry-flow decisions. Do not turn an OPEN lore item into dialogue or quest content.

## 7. Acceptance criteria (aligned with the official roadmap and Prologue design)

1. New Game starts the Prologue per the approved entry-flow policy; Continue bypasses the Prologue and loads existing/legacy saves (roadmap §6, §8).
2. The Prologue completes or skips exactly once and hands off to a fresh Forgotten Shore session; control returns promptly (`PROLOGUE_STORY_DESIGN.md` §8–9).
3. Dialogue/sequence data is data-driven, schema-validated, and fails closed on malformed content (implemented N1 foundation).
4. Narrative triggers are idempotent and silent during load; one-time events do not replay after restore, skip, or scene re-entry (N1, §8).
5. Dialogue input cannot trigger movement, construction, recruitment, or world commands (implemented N2 foundation; content-level integration must retain this guarantee).
6. The dialogue surface does not reuse/overwrite `ClockHUD.FeedbackLabel`; gameplay feedback keeps working.
7. Sequence cleanup restores control; pause/exit/skip/scene changes cannot leave input locked or duplicate events (implemented N3 foundation; each authored sequence must test its path).
8. Existing v1/v2 save compatibility remains intact; any approved narrative persistence has migration tests.
9. Existing headless suites, repo verifier, and gameplay harness remain green; new narrative tests cover success/failure/save/migration.
10. No protected mystery (crown origin, power source, dynasty, kingdom name, Great Eclipse cause) is revealed; OPEN items stay OPEN.
11. Runtime logs show no narrative-related `SCRIPT ERROR`/`Parser Error`/`TEST FAILURE`.

---

## 8. Early-implementation risks for Chapter I

- **Lore lock-in:** implementing Chapter I text before the N5 beat sheet and the shrine/relic/Greedling lore decisions risks rework.
- **Overbuilding:** a quest/branching framework is not justified; the roadmap deliberately limits N1–N3 to what the Prologue needs.
- **Save churn:** adding persistent narrative state despite the approved in-memory N1 design could break existing saves/tests; any change requires a separate schema and migration review.
- **Session coupling:** narrative triggers in `ForgottenShoreSession._process`/command handlers would deepen the orchestrator; keep a separate narrative domain/presenter with a narrow handoff contract.
- **Transition-time signals:** phase signals fire once per transition (`TimeManager.gd:137`), once for the initial phase (`:130`), and are re-emitted only by a non-silent `apply_save_dict` (`:99`) — the session restores silently. The real risks are duplicate handler connections (guard with `is_connected`) and triggers reacting during save-restore; keep triggers idempotent and load-silent. They do **not** fire every frame.
- **UI contention:** the single feedback label is overwritten by gameplay; dialogue needs its own surface.
- **Autosave/night overlap:** sequences can cross a sunset/night transition; define pause/defer/save policy.
- **Entry-flow risk:** Start/Continue routing changes can break legacy saves or replay the Prologue; test New Game vs Continue explicitly.
- **Spoilers:** vision/crown reveals must not leak via HUD/labels or data descriptions before the beat.
- **Doc drift:** stale positions/scope/schema in docs can produce incorrect narrative text (e.g., wall at 360 vs 380, shrine identity).
- **Testability:** narrative UI needs headless-safe logic tests plus GUI screenshot evidence, like the gameplay harness.


## 9. Chapter I beat sheet status

The candidate Chapter I sequence and per-beat gameplay mapping are documented in [`CHAPTER_01_BEAT_SHEET.md`](CHAPTER_01_BEAT_SHEET.md). That document is a **proposal only**. It does not settle the Chapter I ending, shrine/relic/Greedling lore, NPC personalities, or dialogue language. Owner approval is required before implementation.
