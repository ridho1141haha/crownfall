# Crownfall — Chapter I Beat Sheet (Draft Proposal)

**Status:** DRAFT / NON-CANON — owner review required. No dialogue in this document is approved for implementation.
**Baseline:** main @ eb82ae4d63a33a5c0fb9bb3f17f4bf832860c79a (PR #11 merged), Godot 4.7.2.stable.
**Scope:** N5 design planning only. This document does not authorize gameplay changes, narrative code, new lore, or a chapter/quest framework.
**Story boundary:** Chapter I begins when the Monarch regains player control on Forgotten Shore after Prologue beat pl_09_forgotten_shore. Crown discovery, awakening, and the fragmented vision belong to the Prologue.

> Every beat below is a candidate structure mapped to existing gameplay. It is not canon until explicitly approved. If an existing gameplay mechanic and this proposal disagree, shipped code and approved design decisions remain authoritative.

---

## 1. Chapter purpose

Chapter I should turn the Monarch's immediate situation into a small, believable settlement-building journey:

1. Establish the immediate need to survive on an unfamiliar shore.
2. Let the player build a foothold through the existing collection, recruitment, construction, and first-night loop.
3. Introduce the Scientist and research as a way to deepen exploration and preparation, not as a lore exposition dump.
4. Give the player a concrete reason to repair the vessel and leave Forgotten Shore.
5. Preserve the Monarch's unanswered questions from the Prologue without revealing protected mysteries.

The Monarch is not seeking a throne at the start. Leadership should emerge from practical decisions and the community's reliance on those decisions. The chapter should not instantly turn the Monarch into a confident ruler or trained mage.

## 2. Player-facing narrative principles

- **Survival before destiny:** the first objective is to understand the shore and stay alive.
- **Gameplay carries the story:** resource collection, building, recruitment, night defense, research, and ship repair remain playable activities, not long cutscenes.
- **Short, purposeful dialogue:** use dialogue only when it adds character, context, or a clear objective. Avoid explaining systems the HUD already explains.
- **No forced exposition:** Greedling origins, the Greed Portal, Ancient Relic identity, and shrine identities remain unresolved.
- **Earned leadership:** the Monarch helps establish a settlement through actions; no self-coronation or instant claim of authority.
- **Preserve the existing loop:** first-night breach remains recoverable; narrative must not punish or soft-lock a player for a failed defense.
- **No new framework by default:** use the N1–N3 runtime and existing gameplay state. A quest journal, branching dialogue, chapter manager, or new save schema requires separate justification and approval.

## 3. Candidate beat sequence

The sequence below is a proposed narrative spine, not a locked linear quest chain. Some beats can be optional or triggered by gameplay milestones. Exact trigger policy and dialogue are still OPEN.

| ID | Candidate beat | Narrative purpose | Existing gameplay anchor | Candidate completion condition |
|---|---|---|---|---|
| ch1_01_arrival | The Stranded | Establish that the Monarch has regained control on an unfamiliar shore and must orient himself. | Prologue beat 09 handoff; current Forgotten Shore spawn/session entry. | Player control is returned and the first objective is visible. |
| ch1_02_foothold | A Place to Survive | Turn immediate survival into the first practical settlement decisions. | Existing resource nodes, Town Center/Hearth, Vagrant Camp, recruitment, wall/building loop. | Player completes a small set of existing early-game milestones; exact set TBD. |
| ch1_03_first_night | The First Night | Make the day/night loop feel consequential without explaining enemy origins. | Existing sunset warnings, Greedling encounter, wall/support defense, sunrise outcome. | First night resolves; both survived and breach-recovery paths remain valid. |
| ch1_04_after_dawn | After the Night | Acknowledge the settlement's condition and let the player recover/continue. | Existing first_night_survived, settlement_breached, sunrise/autosave behavior. | Player regains normal control after sunrise; no narrative soft lock on breach. |
| ch1_05_scientist | A Different Kind of Knowledge | Introduce the Scientist as a practical specialist who can support the settlement. | Scientist discovery at x=-1010, Scientist's Hut at x=-980, recruitment and research. | Scientist recruitment becomes available/completes through existing gameplay. |
| ch1_06_research | Signs of the Past | Give research a restrained narrative frame without resolving shrine, crown, or relic lore. | Existing Inscription Studies / Improved Flares research and world-clock progress. | One existing research milestone completes; exact technology TBD. |
| ch1_07_prepare_vessel | The Way Forward | Shift from settling in place to preparing to leave the island. | Existing three-stage Shipwreck repair and voyage-readiness state. | Vessel reaches the existing Stage 3 / ready-to-sail state. |
| ch1_08_departure | Beyond the Shore | Provide a clean chapter-end handoff toward the next island without revealing what awaits there. | Existing set-sail / island-cleared presentation; future Eldergrove transition is not implemented. | Owner-approved chapter end and transition condition; currently OPEN. |

### Beat ordering notes

- ch1_01_arrival is a boundary/handoff from Prologue beat 09, not a second shipwreck or a replacement landing sequence.
- ch1_02_foothold and ch1_03_first_night should be driven by existing gameplay milestones. Do not add arbitrary mandatory tasks just to force dialogue.
- ch1_04_after_dawn must support both first-night outcomes. A breach is a recoverable gameplay state, not a failed story branch.
- ch1_05_scientist and ch1_06_research can be paced by player choice; do not require the player to recruit or research at a specific time unless approved.
- ch1_07_prepare_vessel and ch1_08_departure must distinguish “vessel ready” from “actual voyage/next-island scene”. The latter is not currently implemented.
- The order of Scientist/research and ship repair is a proposal; do not block ship progression on optional research without an explicit design decision.

## 4. Dialogue and character scope (proposal)

No final dialogue lines are authored here. Candidate speaker roles:

- **Monarch:** sparse internal observations, focused on immediate needs and unanswered questions. Do not give the Monarch a confirmed name, dynasty, or royal self-identification.
- **Vagrant / first recruit:** may communicate immediate settlement needs if the existing NPC interaction is extended. Do not invent a personal backstory or assume a full survivor community beyond shipped NPCs.
- **Scientist:** may explain the practical purpose of research and observations. Do not use the Scientist to explain the crown, Great Eclipse, Greedling origins, Ancient Relic, or shrine identities.
- **Environmental text:** optional and limited. Do not place definitive lore in inscriptions, item descriptions, HUD strings, or data descriptions without owner approval.

Dialogue language, voice, speaker names, portrait style, and whether dialogue is skippable remain OPEN.

## 5. Gameplay integration contract

- The world simulation continues during gameplay-embedded dialogue under the current technical design. If a beat needs a pause, that requirement must be explicitly reviewed; do not silently pause TimeManager or enemies.
- The N1–N3 runtime is implemented, but no NPC conversation or Chapter I content integration exists yet.
- Prefer existing authoritative state/events for first-night outcome, Scientist discovery/recruitment, research completion, and vessel readiness.
- Narrative triggers must be idempotent and must not fire during silent save restoration.
- Do not write narrative ownership into ForgottenShoreSession._process; keep the session as world orchestrator and use a narrow narrative entry point.
- Keep ClockHUD.FeedbackLabel for gameplay feedback. Dialogue must use DialoguePanel.
- Keep NarrativeState in-memory unless a resumable/cross-session requirement is approved. Do not change SaveManager schema v2 in this planning scope.
- Do not add a quest journal, branching dialogue, generic event bus, camera scripting, or pause-world operation unless an approved beat demonstrates the need.

## 6. Explicitly unresolved owner decisions

1. Is Chapter I's final beat “vessel ready”, the player explicitly choosing to set sail, or arrival at Eldergrove? These are different milestones and must not be conflated.
2. Does Chapter I require a fixed first-night milestone, or should a player who delays/advances differently still progress naturally?
3. Should the Scientist be a required Chapter I character, or an optional specialist whose research can be discovered at the player's pace?
4. Which existing NPCs, if any, should have authored dialogue? Are Vagrant and Scientist sufficient?
5. What is the intended Chapter I dialogue language and presentation style?
6. Should the crown be visible during Chapter I gameplay, and if so, how is its visual continuity represented without adding an inventory system?
7. Does any Chapter I beat mention the royal symbol or Monarch's unanswered questions, or should those remain subtle until later?
8. What is the canonical relationship, if any, between Forgotten Shrine and Shrine of Growth? Keep separate until decided.
9. What is the Ancient Relic at the Greed Portal: an artifact, a gameplay reward label, or something else? Keep undefined.
10. What are the Greedlings and Greed Portal, and why do they attack? Keep undefined.
11. What is the exact transition from Forgotten Shore to Eldergrove, and what is the Chapter II opening?
12. Which beats are skippable, optional, or replayable? The current runtime supports sequence skip/cancel, but content policy is not yet approved.

## 7. Proposed acceptance criteria

A Chapter I design is ready for implementation only when:

- The owner approves the chapter purpose, beat order, and chapter-end condition.
- Every beat has an explicit trigger, gameplay anchor, player-control policy, expected outcome, and failure/recovery behavior.
- Both first-night success and breach recovery remain valid.
- No beat requires a gameplay feature that does not exist unless that feature is separately approved and scoped.
- Dialogue has a defined purpose and speaker; no filler/tutorial duplication.
- All OPEN lore stays OPEN; protected Prologue mysteries remain protected.
- The design distinguishes vessel readiness, departure, and next-island arrival.
- Existing save/load, progression, and first-night gameplay contracts are preserved.
- The implementation can be split into small PRs with automated tests and windowed verification.

## 8. Recommended implementation order (after design approval)

1. Complete N0/entry-flow decisions and prepare the N4 Prologue implementation plan.
2. Implement the Prologue and verify its handoff to a fresh Forgotten Shore session.
3. Implement Chapter I beats in small slices, starting with one gameplay-triggered beat and one short dialogue sequence.
4. Add NPC talk interaction only if the approved beats require it.
5. Add camera/fade/pause operations only if visual staging and playtesting prove they are needed.

---

**END OF DRAFT — NOT APPROVED CANON**
