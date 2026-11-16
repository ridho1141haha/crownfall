# Crownfall — Chapter I Narrative Gap Analysis

**Audit date:** 2026-11-16  
**Snapshot:** branch `feat/gameplay-testing-harness` @ `04eee57` (docs uncommitted)  
**Engine:** Godot `4.7.2.stable`  
**Companion docs:** [`NARRATIVE_IMPLEMENTATION_AUDIT.md`](NARRATIVE_IMPLEMENTATION_AUDIT.md), [`NARRATIVE_IMPLEMENTATION_ROADMAP.md`](NARRATIVE_IMPLEMENTATION_ROADMAP.md)  
**Rule:** This document does not invent or resolve lore. Open mysteries stay open.

---

## 1. Scope and definition of “established direction”

Chapter I is referred to as **“The Forgotten Shore”** in the GDD (`docs/GDD.md:58-66`). The only narrative direction currently in the repository is:

- Aetherion, the First Light, the Great Eclipse, the Monarch and an ancient crown (`docs/GDD.md:46-54`).
- Chapter table: I — The Forgotten Shore — “Establish the first settlement” — **“Vertical-slice location and gameplay proof only”** (`docs/GDD.md:58-66`).
- Explicit scope deferral: “the first vertical slice is not required to contain a complete Chapter I narrative, dialogue system, quest chain, or cinematic story sequence” (`docs/GDD.md:66`).
- Deferred narrative systems: full dialogue, quests, branching story, chapter framework (`docs/GDD.md:112`; `docs/PRD.md:505-521`; `docs/REVISED_PROJECT_BASELINE.md:85`).

**Critical finding:** there is **no Chapter I beat sheet, dialogue script, character bible, or cutscene specification in the repository.** The beat list in the audit task is therefore a *readiness checklist*, not an approved content spec. Every beat below is assessed against the implementation; content-level decisions are marked **BLOCKED — design approval required**, not invented.

The GDD’s “Implemented” status for Chapter I means only that the Forgotten Shore **location and settlement/first-night gameplay proof** exist. It does not mean Chapter I narrative is implemented.

---

## 2. Chapter I beat matrix

Status: **EXISTS** = implemented and reachable; **PARTIAL** = gameplay/system exists but narrative beat is absent/incomplete; **MISSING** = no implementation; **BLOCKED** = content cannot be implemented without approved lore/design.

| # | Chapter I beat | Status | One-line finding | Primary evidence |
|---:|---|---|---|---|
| 1 | Opening sequence / player introduction | **MISSING** | Title menu transitions directly into gameplay; no opening beat. | `Main.tscn`; `Main.gd:21-34`; `ForgottenShoreSession.gd:93-105` |
| 2 | Monarch identity and background | **MISSING (in-game)** | “Monarch” is a controller/sprite label only; no name, history, voice, or reveal. | `Player.gd:1-21`; `Player.tscn:4-13`; `GDD.md:24,54` |
| 3 | Ancient Crown discovery and interaction | **MISSING / BLOCKED** | No crown entity, asset, interaction, state, or canon details. | Repo-wide search; no crown asset; `GDD.md:54` intent only |
| 4 | Crown awakening and vision | **MISSING / BLOCKED** | No vision/cutscene system or content. | No cutscene scripts/scenes/assets; `ClockHUD.gd:61-88` is a banner only |
| 5 | Forgotten Shore arrival and settlement establishment | **PARTIAL** | Settlement loop is implemented; arrival/first-settlement narrative framing is absent. | `ForgottenShore.tscn:504`; Town Center `:140-161`; `ForgottenShoreSession.gd:93-105` |
| 6 | Existing NPCs and dialogue | **PARTIAL (NPCs) / MISSING (dialogue)** | NPC roles and specialist discovery/recruitment exist; no dialogue system, conversations, or portraits. | `NPCBuilderAgent.gd:21-100`; `NPCPopulationManager.gd:7-68`; `SpecialistDomain.gd`; `InteractionResolver.gd:146-198`; `ClockHUD.gd:11,123-125` |
| 7 | Greedling narrative context | **PARTIAL** | Threat names/forecasts exist; no explanation of Greed/Greedlings/First Light/Great Eclipse. | `data/enemies.json:3-17`; `NightEncounterManager.gd:25-29,107-133`; `ForgottenShoreSession.gd:1070-1091` |
| 8 | Forgotten Shrine | **PARTIAL + AMBIGUOUS** | A −780 “Forgotten Shrine” cache/offering and an 820 “Shrine of Growth” structure both exist; identity/canon unresolved. | `data/resource_nodes.json:40-46`; `ResourceNodeManager.gd:13`; `InteractionResolver.gd:50-61`; `ForgottenShoreSession.gd:512-529,751-779`; `data/structures.json:3-20` |
| 9 | Ancient Relic | **PARTIAL + AMBIGUOUS** | One-time Greed Portal loot labelled “Ancient Relic”; no artifact system/lore; GDD defers Ancient Relics as a resource. | `ForgottenShoreSession.gd:731-742,1186`; `data/resources.json`; `GDD.md:107,125` |
| 10 | Shipwreck | **PARTIAL** | Three-stage repair → vessel-ready → island-cleared banner; no voyage scene or Chapter II transition. | `ForgottenShoreSession.gd:15-21,694-728`; `ForgottenShore.tscn:427-443`; `GDD.md:132` |
| 11 | Chapter progression and story completion | **MISSING (as narrative)** | No chapter model/facts/flow; only era/`ReignState`/gameplay completion. | `ForgottenShoreSession.gd:7-11,694-707,1079-1084`; `ProgressionState.gd:25-95`; `EraProgressionManager.gd` |

**Count:** 0 fully implemented narrative beats. **6 partial beats** (5, 6, 7, 8, 9, 10) — with beat 6 splitting into “partial NPC systems / missing dialogue.” **5 missing/blocked beats** (1, 2, 3, 4, 11) — beats 3 and 4 are content-blocked on canon. No beat is a complete, authored Chapter I narrative scene.

---

## 3. Beat-by-beat analysis

### Beat 1 — Opening sequence / player introduction

**Intended function (documented):** Introduce the Monarch and the fallen world; establish tone. The GDD says the environment should communicate history without long cutscenes (`docs/GDD.md:39`) and that the vertical slice does not require a cinematic story sequence (`:66`). Exact opening content is **not documented**.

**Exists**
- `Main.tscn` title “CROWNFALL: THE LAST LIGHT”, subtitle “Forgotten Shore — Single-Player Vertical Slice”, Start/Continue/Exit buttons.
- Start/Continue call `change_scene_to_file("res://scenes/world/ForgottenShore.tscn")` (`Main.gd:21-34`).
- The first in-game feedback is a controls line (`ForgottenShoreSession.gd:105`).

**Missing**
- Any authored opening text, camera sequence, character introduction, or narrative framing.
- Any “new game vs continue” narrative distinction (Continue silently loads; `_consume_pending_load_if_requested`, `:1803`).
- Any skip/replay/save semantics for an opening.

**Dependencies / decisions**
- Opening content/voice (TBD, approval required).
- Whether opening is text-only, environmental, or a short scripted sequence.
- Whether it plays on New Game only, and whether it is skippable/replayable.

**Status:** **MISSING.** Infrastructure (sequence runner + dialogue UI) is also missing.

---

### Beat 2 — Monarch identity and background

**Intended function (documented):** Player controls a Monarch; the journey is tied to an ancient crown (`GDD.md:24,54`). Exact chronology, characters, and reveals remain future story design — explicitly unresolved.

**Exists**
- `PlayerController` (`Player.gd`), `player_monarch_sheet.png`, movement/interaction signals, camera.
- Docs/README call the character “Monarch”.

**Missing**
- Name, background, motivation, voice, portrait, or any in-game identity reveal.
- Any narrative state about the Monarch.

**Dependencies / decisions**
- Name/identity/background/voice (approval required).
- Whether the Monarch speaks, has internal monologue, or is a silent protagonist.
- How the Monarch relates to the crown (chronology/reveal timing).

**Status:** **MISSING in-game** (role label only).

---

### Beat 3 — Ancient Crown discovery and interaction

**Intended function (documented):** The Monarch’s journey is tied to an ancient crown (`GDD.md:54`). No discovery location, timing, mechanics, or scene is documented.

**Exists**
- Nothing. No crown node, data entry, interaction target, inventory item, asset, or save flag. Searches for “crown” in code/data/scenes find only the project title and `crownfall_load_on_start`.

**Missing**
- The crown as a world entity/interaction, its narrative context, and its gameplay hook.
- Any canon decisions about where/when/how it is found.

**Dependencies / decisions**
- Crown origin, discovery beat, interaction type, and consequences (BLOCKED — approval required).
- Whether the crown is an item, a structure, a cutscene object, or a persistent state.

**Status:** **MISSING / BLOCKED.**

---

### Beat 4 — Crown awakening and vision

**Intended function (documented):** Not specified beyond the crown premise. A “vision” beat is requested by the audit task but is not documented in the repository.

**Exists**
- Nothing. No vision/cutscene system, vision assets, camera/sequence control, or narrative state.

**Missing**
- The awakening/vision content and the runtime to present it.
- Rules for when it triggers, what it reveals, and whether it is skippable/persisted.

**Dependencies / decisions**
- Vision content and canon reveals (BLOCKED).
- Cutscene style/length, input gating, skip, pause/save behavior.

**Status:** **MISSING / BLOCKED.**

---

### Beat 5 — Forgotten Shore arrival and settlement establishment

**Intended function (documented):** “Establish the first settlement” (`GDD.md:60`); Forgotten Shore is the first location, with a ruined/abandoned settlement atmosphere and a clear settlement anchor (`:68-81`).

**Exists**
- The scene loads directly on Forgotten Shore; the Monarch starts at `x=0` next to a fixed Town Center/Hearth.
- Settlement establishment is fully playable: resource collection, villager recruitment, wall construction, watchtower/farm plots, hearth upgrades, day/night survival, shipwreck repair.
- Environment labels and resource nodes provide an “abandoned shore” surface (Ancient Coin Chest, Fallen Timber, Ruined Masonry, Stone Quarry, Forgotten Shrine).

**Missing**
- Any arrival beat (waking, shipwreck landing, first sight of the settlement, first words).
- Any narrative distinction between “arriving” and “already settled”.
- Any authored environmental storytelling beyond labels (no inscriptions, notes, ghosts, memories).

**Dependencies / decisions**
- Arrival framing/content (approval required).
- Whether the player begins with the Town Center or must establish it narratively.

**Status:** **PARTIAL** — gameplay exists; narrative beat missing.

---

### Beat 6 — Existing NPCs and dialogue

**Intended function (documented):** Recruit villagers and a Builder (`GDD.md:143-153`); specialist Scientist discovery/recruitment (`:138`). Full dialogue/quests are deferred (`:112`; `PRD.md:505-521`).

**Exists**
- NPC agents with IDs/roles/states: persistent `npc_01` (UNRECRUITED → builder), Villager, Farmer, Archer; `NPCPopulationManager` roster/tool stands.
- Scientist: data definition (`data/specialists.json:3-12`), discovery fact, housing plot `hut_scientist_01`, recruitment cost, research handoff.
- Interaction prompts and one-line feedback (`InteractionResolver.gd:146-198`; `ClockHUD.gd:11,123-125`).
- World labels (Vagrant/Builder, Scientist prompt “Speak to the Shipwrecked Stranger”).

**Missing**
- Any dialogue box, conversation tree, speaker name/portrait, choices, voice, or NPC personality text.
- NPC names beyond role/display name; specialist `description` is never displayed.
- Any “talk” interaction that is not also a recruit/research action.

**Dependencies / decisions**
- Which NPCs speak, what they say, tone/voice, and whether conversations are optional/required.
- Whether dialogue is text-only or portrait-based; whether choices/branching are in scope.
- How NPC dialogue interacts with recruitment/housing/research gating.

**Status:** **PARTIAL NPC systems / MISSING dialogue.**

---

### Beat 7 — Greedling narrative context

**Intended function (documented):** Hostile creatures emerge after sunset (`GDD.md:24`); the first enemy is the Greedling Raider (`:167`; `DECISIONS_M2_M8.md:22`). The Greed/First Light connection is not documented beyond the world premise.

**Exists**
- Enemy archetypes: Greedling Raider, Shadow Crawler, Gloom Brute (`data/enemies.json`).
- Night forecast text, sunset/night warnings, west-scout warnings, breach feedback, enemy labels.
- A “Greed Portal” landmark at `x=1350` with a one-time relic reward.

**Missing**
- Any explanation of what Greedlings are, why they attack, or how they relate to the Greed/First Light/Great Eclipse.
- Any authored encounter dialogue, warning from an NPC, or lore discovery.
- A coherent narrative identity for the Greed Portal.

**Dependencies / decisions**
- Greedling/Greed/portal canon and exposition timing (approval required).
- Whether context is delivered environmentally, via dialogue, or via discovery text.

**Status:** **PARTIAL** — threat pressure exists; narrative context missing.

---

### Beat 8 — Forgotten Shrine

**Intended function (documented):** Far-western Forgotten Shrine at `x=-780` grants `+3 Gold` as an exploration reward (`GDD.md:38`; `DECISIONS_M2_M8.md:24`; `PRD.md:341`). Separately, Phase 5 adds a “Shrine of Growth” structure at `x=820` (`PROGRESSION_FOUNDATION_DESIGN.md:534-544`).

**Exists**
- `shrine_cache_far_west` at `x=-780`: one-time +3 Gold; after collection, a daily offering interaction (4W+2S → +2G; +5G with `Inscription Studies`).
- `shrine_of_growth` at `x=820`: structure activation (4G+2W+3S) after Stone Wall Tier 2; grants +1 Wood per wood acquisition; dormant/awakened landmark sprite; HUD blessing line.
- Narrative-flavoured descriptions in `data/structures.json` and `data/technologies.json` are validated but **not displayed**.

**Missing / ambiguous**
- Whether these are the same sacred tradition/site or two different shrines.
- Which shrine is the Chapter I “Forgotten Shrine” for narrative purposes.
- Any authored lore for either shrine, its inscriptions, or its spirits.
- Any dialogue/vision at the shrine; interaction is purely transactional.

**Dependencies / decisions**
- Canon identity/relationship of the two shrines (approval required).
- Which shrine receives Chapter I narrative content, and what the offering/activation means.
- Whether the Scientist’s “Forgotten Shrine inscriptions” research refers to the −780 site, the 820 structure, or both.

**Status:** **PARTIAL + AMBIGUOUS.**

---

### Beat 9 — Ancient Relic

**Intended function (documented):** Ancient Relics are listed as a deferred resource category (`GDD.md:107,125`; `REVISED_PROJECT_BASELINE.md:23,101`). No relic narrative/system is documented.

**Exists**
- One-time “Ancient Relic” loot at the Greed Portal (`x=1350`): +3 Gold, +2 Stone, sets `portal_relic_looted`, changes label to “Greed Portal (Scavenged)”.
- Floating text “+3G +2S Relic”.

**Missing / ambiguous**
- No relic item/inventory/collection UI, no relic identity, no lore, no consequence beyond the one-time resources.
- Terminology conflicts with the deferred “Ancient Relics” resource category; it is a reward cache, not a resource.

**Dependencies / decisions**
- Is this a narrative artifact or merely a POI reward? (approval required)
- If an artifact: what it is, how it is stored, and how it matters to Chapter I/crown.
- If a cache: rename/describe it consistently with canon.

**Status:** **PARTIAL + AMBIGUOUS.**

---

### Beat 10 — Shipwreck

**Intended function (documented):** Shipwreck Stage 3 means the vessel is ready to sail; it does not unlock an era (`GDD.md:132`; `PROGRESSION_FOUNDATION_DESIGN.md:240-259`). The shipped feedback points toward Eldergrove Forest (the future Island 2); the GDD’s Chapter II is titled “The Lost Kingdom.” Both are future work; no voyage/island transition exists today.

**Exists**
- Three-stage repair at `x=-1350` with escalating costs; label/prompt progression; Stage 3 records `forgotten_shore_vessel_ready`.
- Interacting after Stage 3 sets `ISLAND_CLEARED`, stops the night encounter, auto-saves, and shows “ISLAND CLEARED” + voyage subtitle; feedback says the vessel sets sail toward Eldergrove Forest.
- Post-victory nights are peaceful (`_on_night_started` returns for `ISLAND_CLEARED`).

**Missing**
- Any departure sequence, sea voyage, arrival at Island 2, or Chapter II transition.
- Any narrative framing of who built the ship, where it goes, or what the Monarch expects.
- A chapter-completion model separate from `ISLAND_CLEARED`.

**Dependencies / decisions**
- Chapter I end condition (ship repair? set sail? island cleared?) and Chapter II handoff (approval required).
- Whether the “set sail” action ends the chapter, ends the current build, or continues in-place.
- Voyage/Island 2 scope (currently future).

**Status:** **PARTIAL** — preparation and a banner exist; the journey/chapter transition does not.

---

### Beat 11 — Chapter progression and story completion

**Intended function (documented):** Chapters I–V are a long-term direction (`GDD.md:58-66`). Chapter I is explicitly “vertical-slice location and gameplay proof only”. No chapter framework is approved or implemented.

**Exists**
- Era progression: Wood → Stone → Iron (`EraProgressionManager`), with Iron Age unreachable on Forgotten Shore by design.
- `ReignState { ACTIVE, BREACH_PENALTY, ISLAND_CLEARED }`.
- Durable progression facts (14 IDs) and strict save/load.
- `ISLAND_CLEARED` victory banner and peaceful post-victory state.

**Missing**
- Chapter model/facts/state, chapter start/end flow, chapter UI, chapter replay/continue semantics.
- A narrative completion condition distinct from gameplay victory.
- Any Chapter II setup beyond a feedback line.

**Dependencies / decisions**
- Chapter definitions and completion criteria (approval required).
- Relationship between era progression, progression facts, `ISLAND_CLEARED`, and chapters.
- Whether chapters are linear, per-save, replayable, or skippable.

**Status:** **MISSING as narrative** (gameplay completion only).

---

## 4. Dependencies and unresolved decisions

Each item below blocks content implementation until approved. None is resolved by this audit.

### 4.1 Canon / narrative decisions

1. **Ancient Crown:** origin, discovery location/timing, interaction type, awakening, vision content, and consequences.
2. **Monarch:** name, background, motivation, voice/silence, relationship to the crown.
3. **Crownfall / First Light / Great Eclipse:** what the player learns in Chapter I and when.
4. **Greedlings / Greed / Greed Portal:** nature, motivation, relationship to the world premise, and exposition timing.
5. **Forgotten Shrine vs Shrine of Growth:** are they the same tradition/site, two sites, or a site plus a structure? Which is canonically “the Forgotten Shrine”?
6. **Ancient Relic:** artifact vs reward cache; identity, storage, and relevance (if any) to the crown.
7. **Shipwreck / voyage:** who/what/where; Chapter I end and Chapter II handoff.
8. **Chapter I completion:** what counts as completing Chapter I, and how it relates to `ISLAND_CLEARED`/era.

### 4.2 Presentation / scope decisions

1. Dialogue style: text-only vs portraits; linear vs choices; branching scope.
2. Cutscene style/length: in-engine scripted, text overlay, environmental, or hybrid; skip/replay rules.
3. Chapter structure: beat sheet, scene boundaries, required vs optional conversations.
4. Localization scope and text volume.
5. Audio/voice scope for Chapter I.

### 4.3 Technical decisions

1. Narrative state model: registered facts vs a new optional save object; schema version strategy; migration.
2. Trigger/event model: conditions, once-only/seen state, load-silence, save timing, replay.
3. UI ownership: new CanvasLayer dialogue system vs extending `ClockHUD`; pause/input integration.
4. Interaction extension: add `talk` kind/command without breaking existing resolver priorities.
5. Whether to build on the current session or wait for/ignore the unmerged presentation refactor (`refactor/shore-presentation-layer`).

---

## 5. What can be implemented without new lore

Only **infrastructure** can proceed safely without inventing content:

- Dialogue/sequence data format + validation.
- Narrative state + save/load integration (with migration and transactional rejection).
- Narrative event/trigger system with once-only/seen semantics.
- Minimal dialogue UI and input actions (`advance`, `skip`), pause integration.
- `talk` interaction extension.
- Tests and documentation.

Content beats (opening text, Monarch identity, crown, vision, NPC lines, shrine/relic lore, chapter end) are **blocked on approval**. Placeholder text should not be committed as canon.

---

## 6. Conditional acceptance criteria (for the first narrative implementation)

These are infrastructure-focused and do not require new lore. They should be approved/refined before coding.

1. A New Game plays the approved opening beat exactly once; Continue does not replay it.
2. Dialogue/sequence data is data-driven, schema-validated, and fail-closed on malformed content.
3. Narrative triggers are idempotent and silent during load; seen-state round-trips through save/load and is rejected transactionally if invalid.
4. A `talk` interaction works alongside existing gather/build/recruit/research/structure prompts without changing their behavior.
5. Dialogue UI does not reuse/overwrite `ClockHUD.FeedbackLabel`; gameplay feedback continues to work.
6. Skip/advance work; pause/menu interactions do not corrupt narrative state.
7. Autosave/manual-save rules are explicit for sequences; no save occurs mid-sequence unless specified.
8. Existing headless suites, repo verifier, and gameplay harness remain green; new narrative tests cover success/failure/save/migration.
9. No lore is hardcoded beyond approved content; no open mystery is resolved silently.
10. Runtime logs show no narrative-related `SCRIPT ERROR`/`Parser Error`/`TEST FAILURE`.

---

## 7. Early-implementation risks for Chapter I

- **Lore lock-in:** building scenes/IDs/text before canon approval makes later rewriting expensive.
- **Overbuilding:** a quest/branching framework is not justified by the GDD’s Chapter I proof scope; start with linear, data-driven beats.
- **Save churn:** narrative state added without a migration strategy can break existing saves/tests.
- **Session coupling:** narrative triggers in `ForgottenShoreSession._process`/command handlers deepen the orchestrator; keep narrative in a separate domain/presenter.
- **Signal storms:** phase/night signals fire continuously; triggers must be once-only and deterministic.
- **UI contention:** the single feedback label is overwritten by gameplay; dialogue needs its own surface.
- **Autosave/night overlap:** sequences can cross sunset/night; define pause/defer/save policy.
- **Spoilers:** vision/crown reveals must not leak via HUD/labels or data descriptions before the beat.
- **Doc drift:** stale positions/scope/schema in docs can produce incorrect narrative text (e.g., wall at 360 vs 380, shrine identity).
- **Testability:** narrative UI needs headless-safe logic tests plus GUI screenshot evidence, like the gameplay harness.
