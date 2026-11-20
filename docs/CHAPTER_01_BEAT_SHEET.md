# Crownfall — Chapter I Beat Sheet (Draft Proposal)

**Status (updated 2026-11-20):** **CANDIDATE BEATS REMAIN DRAFT / NON-CANON** — no dialogue in this document is approved for implementation. Owner-approved progression constraints (Chapter I ends on Eldergrove arrival; mandatory first night with defense + breach recovery valid; Scientist & research optional and never block departure; SaveManager schema v2 unchanged) are locked and mapped to small PRs in [`docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`](narrative/N5_IMPLEMENTATION_ROADMAP.md); open implementation triggers are tracked in [`docs/narrative/N5_OWNER_DECISIONS.md`](narrative/N5_OWNER_DECISIONS.md).
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
4. Give the player a concrete reason to repair the vessel, depart, and discover Eldergrove Forest.
5. End Chapter I on arrival at Eldergrove, giving the next chapter a natural launch point while preserving the Monarch's unanswered questions.

The Monarch is not seeking a throne at the start. Leadership should emerge from practical decisions and the community's reliance on those decisions. The chapter should not instantly turn the Monarch into a confident ruler or trained mage.

## 2. Player-facing narrative principles

- **Survival before destiny:** the first objective is to understand the shore and stay alive.
- **Gameplay carries the story:** resource collection, building, recruitment, night defense, research, and ship repair remain playable activities, not long cutscenes.
- **Short, purposeful dialogue:** use dialogue only when it adds character, context, or a clear objective. Avoid explaining systems the HUD already explains.
- **No forced exposition:** Greedling origins, the Greed Portal, Ancient Relic identity, and shrine identities remain unresolved.
- **Earned leadership:** the Monarch helps establish a settlement through actions; no self-coronation or instant claim of authority.
- **Mandatory first-night milestone, recoverable outcome:** the first night must occur to complete Chapter I's opening survival arc. Both a successful defense and a breach-recovery outcome remain valid; narrative must never soft-lock the player.
- **No new framework by default:** use the N1–N3 runtime and existing gameplay state. A quest journal, branching dialogue, chapter manager, or new save schema requires separate justification and approval.

## 3. Candidate beat sequence

The sequence below is a proposed narrative spine, not a locked linear quest chain. Some beats can be optional or triggered by gameplay milestones. Exact trigger policy and dialogue are still OPEN.

| ID | Candidate beat | Narrative purpose | Existing gameplay anchor | Candidate completion condition |
|---|---|---|---|---|
| ch1_01_arrival | The Stranded | Establish that the Monarch has regained control on an unfamiliar shore and must orient himself. | Prologue beat 09 handoff; current Forgotten Shore spawn/session entry. | Player control is returned and the first objective is visible. |
| ch1_02_foothold | A Place to Survive | Turn immediate survival into the first practical settlement decisions. | Existing resource nodes, Town Center/Hearth, Vagrant Camp, recruitment, wall/building loop. | Player completes a small set of existing early-game milestones; exact set TBD. |
| ch1_03_first_night | The First Night | Make the day/night loop feel consequential without explaining enemy origins. | Existing sunset warnings, Greedling encounter, wall/support defense, sunrise outcome. | First night resolves; both survived and breach-recovery paths remain valid. |
| ch1_04_after_dawn | After the Night | Acknowledge the settlement's condition and let the player recover/continue. | Existing first_night_survived, settlement_breached, sunrise/autosave behavior. | Player regains normal control after sunrise; no narrative soft lock on breach. |
| ch1_05_scientist | A Different Kind of Knowledge | Introduce the Scientist as an optional specialist whose expertise enables settlement upgrades and research. | Scientist discovery at x=-1010, Scientist's Hut at x=-980, recruitment and research. | Scientist can be discovered and recruited, but recruitment is not a Chapter I completion requirement. |
| ch1_06_research | Signs of the Past | Show the practical value of specialist knowledge without resolving shrine, crown, or relic lore. | Existing Inscription Studies / Improved Flares research and world-clock progress; Scientist recruitment gate. | Research remains optional for chapter completion. Research and any upgrade that requires specialist knowledge stay unavailable until the Scientist is recruited. |
| ch1_07_prepare_vessel | The Way Forward | Shift from settling in place to preparing to leave the island. | Existing three-stage Shipwreck repair and voyage-readiness state. | Vessel reaches Stage 3 / ready-to-sail; this is a departure prerequisite, not the chapter ending. |
| ch1_08_departure | Beyond the Shore | Carry the player from Forgotten Shore to the first arrival in Eldergrove Forest, ending Chapter I on discovery rather than on a menu/state flag. | Existing set-sail / island-cleared presentation; future voyage and Eldergrove transition are not implemented. | Chapter I ends when the player arrives in Eldergrove and control is handed over there. The exact arrival scene and Chapter II opening remain to be designed. |

### Beat ordering notes

- ch1_01_arrival is a boundary/handoff from Prologue beat 09, not a second shipwreck or a replacement landing sequence.
- ch1_02_foothold leads into a mandatory first-night milestone. The game may pace the approach through existing gameplay, but Chapter I cannot bypass the first night entirely.
- ch1_04_after_dawn must support both first-night outcomes. A breach is a recoverable gameplay state, not a failed story branch.
- Scientist discovery/recruitment is optional for Chapter I completion. However, research and specialist-dependent upgrades must remain gated until the Scientist is recruited; do not silently grant those capabilities without the specialist.
- Research itself is optional and must not block ship repair or departure. The player may leave without recruiting the Scientist or completing research.
- ch1_07_prepare_vessel marks readiness only. ch1_08_departure includes the actual voyage and arrival at Eldergrove; Chapter I ends on arrival, not at the departure prompt.
- The Eldergrove voyage/arrival transition does not exist yet and must be separately scoped and implemented.

## 4. Dialogue and character scope (proposal)

No final dialogue lines are authored here. Candidate speaker roles:

- **Monarch:** sparse internal observations, focused on immediate needs and unanswered questions. Do not give the Monarch a confirmed name, dynasty, or royal self-identification.
- **Vagrant / first recruit:** may communicate immediate settlement needs if the existing NPC interaction is extended. Do not invent a personal backstory or assume a full survivor community beyond shipped NPCs.
- **Scientist:** may explain the practical purpose of research and observations. Do not use the Scientist to explain the crown, Great Eclipse, Greedling origins, Ancient Relic, or shrine identities.
- **Environmental text:** optional and limited. Do not place definitive lore in inscriptions, item descriptions, HUD strings, or data descriptions without owner approval.

**Language decision:** English is the default/source language for all authored in-game dialogue, including the Prologue and Chapter I. Additional language localization is future scope; do not build a localization framework for this milestone. Voice acting, speaker names, portrait style, and whether dialogue is skippable remain OPEN.

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

1. Which existing NPCs, if any, should have authored dialogue? Are Vagrant and Scientist sufficient?
2. What dialogue presentation style best fits Chapter I (text-only, speaker label, portrait, or another minimal treatment)? English is the approved default language.
3. Should the crown be visible during Chapter I gameplay, and if so, how is its visual continuity represented without adding an inventory system?
4. Does any Chapter I beat mention the royal symbol or Monarch's unanswered questions, or should those remain subtle until later?
5. What is the canonical relationship, if any, between Forgotten Shrine and Shrine of Growth? Keep separate until decided.
6. What is the Ancient Relic at the Greed Portal: an artifact, a gameplay reward label, or something else? Keep undefined.
7. What are the Greedlings and Greed Portal, and why do they attack? Keep undefined.
8. What is the exact voyage/arrival presentation from Forgotten Shore to Eldergrove, and what is the Chapter II opening? Chapter I's endpoint is fixed as arrival at Eldergrove, but the transition details remain open.
9. Which beats are skippable, optional, or replayable? The current runtime supports sequence skip/cancel, but content policy is not yet approved.

## 7. Proposed acceptance criteria

A Chapter I design is ready for implementation only when:

- The owner-approved chapter boundary is arrival at Eldergrove; vessel readiness, departure, and arrival are distinct milestones.
- The first night is mandatory, with both success and breach-recovery outcomes supported.
- Scientist recruitment is optional for Chapter I completion; research and specialist-dependent upgrades remain gated until recruitment.
- Every beat has an explicit trigger, gameplay anchor, player-control policy, expected outcome, and failure/recovery behavior.
- Both first-night success and breach recovery remain valid.
- No beat requires a gameplay feature that does not exist unless that feature is separately approved and scoped.
- Dialogue has a defined purpose and speaker; no filler/tutorial duplication.
- All OPEN lore stays OPEN; protected Prologue mysteries remain protected.
- The design distinguishes vessel readiness, departure, and Eldergrove arrival, with Chapter I ending on arrival.
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
