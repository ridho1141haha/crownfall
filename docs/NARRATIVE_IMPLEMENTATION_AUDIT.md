# Crownfall — Narrative Implementation Readiness Audit

**Audit date:** 2026-11-16  
**Repository snapshot:** branch `feat/gameplay-testing-harness` @ `04eee57` (docs added uncommitted)  
**Engine:** Godot `4.7.2.stable`  
**Scope:** narrative implementation only. No gameplay code was modified, no features were added, no lore was invented.  
**Companion documents:** [`CHAPTER_01_NARRATIVE_GAP_ANALYSIS.md`](CHAPTER_01_NARRATIVE_GAP_ANALYSIS.md), [`NARRATIVE_IMPLEMENTATION_ROADMAP.md`](NARRATIVE_IMPLEMENTATION_ROADMAP.md)

---

## 0. Method and evidence standard

This audit treats the **Godot project as the source of truth for gameplay implementation**. Design documents were read as *intent*, not as proof of implementation. A feature is counted as implemented only when it exists in scenes/scripts/data and is reachable through the current runtime paths.

Inspected evidence classes:

- Scenes: `scenes/main/Main.tscn`, `scenes/world/ForgottenShore.tscn`, `scenes/player/Player.tscn`
- Runtime scripts: `scripts/world/ForgottenShoreSession.gd`, `scripts/player/Player.gd`, `scripts/player/InteractionResolver.gd`, `scripts/ui/ClockHUD.gd`, `scripts/ui/PauseMenu.gd`, `scripts/npc/*`, `scripts/kingdom/*`, `scripts/survival/*`, `scripts/progression/*`, `scripts/specialists/*`, `scripts/research/*`, `scripts/structures/*`, `scripts/buffs/*`, `scripts/save/*`
- Data: `data/*.json`
- Assets: `assets/**` (asset inventory and filename searches)
- Documentation: `readme.md`, `docs/GDD.md`, `docs/PRD.md`, `docs/REVISED_PROJECT_BASELINE.md`, `docs/SYSTEMS.md`, `docs/TDD.md`, `docs/DECISIONS_M2_M8.md`, `docs/PROGRESSION_FOUNDATION_DESIGN.md`, `docs/ASSET_GUIDELINES.md`, `docs/ROADMAP.md`, `docs/CHANGELOG.md`

Important boundary: **no standalone narrative design document, Chapter I beat sheet, dialogue script, or cutscene specification exists in the repository.** The only established narrative direction is the high-level GDD §2 (Aetherion / First Light / Great Eclipse / Monarch & ancient crown / five chapter titles) and the explicit statements that full dialogue, quests, branching story, and chapter framework are deferred. This audit therefore does not treat the task's beat list as already-approved content.

No narrative runtime exists to execute; this is a static readiness audit. Gameplay systems are independently covered by the repository's existing test suites and verifier.

---

## 1. Executive summary

| Dimension | Maturity | Summary |
|---|---|---|
| Gameplay loop | **Implemented / tested** | Movement, economy, building, NPC builder/farmer/archer, night defense, save/load, specialists, research, shrine/structure foundation, buffs, era progression. |
| Narrative content | **Near-zero** | No opening scene, no crown, no vision, no dialogue, no chapter progression. Only functional prompts/status text and a few lore-flavoured names/descriptions. |
| Narrative infrastructure | **Absent / minimal** | No dialogue system, quest/objective system, narrative event system, chapter state, cutscene/sequence runner, or narrative save fields. |
| Narrative data | **Fragments** | Narrative-flavoured `description` fields exist in data JSON but are validated only; no UI reads them. |
| Narrative assets | **Absent** | No crown, portrait, dialogue box, cutscene, or vision assets. Asset guidelines explicitly defer narrative asset sets. |

**Verdict:** the project is a runnable **gameplay vertical slice**, not a narrative implementation. The GDD explicitly limits Chapter I to “vertical-slice location and gameplay proof only” and excludes a complete Chapter I narrative, dialogue system, quest chain, and cinematic sequence. The project is **not narrative-ready for content implementation**; it is ready to begin a **narrative infrastructure foundation** once canon/beat-level design is approved.

The biggest gaps are: (1) no dialogue runtime/UI, (2) no narrative state/chapter/cutscene infrastructure, (3) no opening/crown/vision content, (4) no beat-level Chapter I script or canon decisions in the repository, and (5) unresolved lore identity conflicts around the two “shrines” and the “Ancient Relic”.

---

## 2. Current narrative implementation

Status legend: **Implemented** = reachable in runtime; **Partial** = functional system exists but narrative framing is absent or incomplete; **Missing** = no implementation; **Ambiguous** = implementation exists but canon/identity is unresolved.

| Beat | Status | What actually exists | Evidence |
|---|---|---|---|
| Opening sequence / player introduction | **Missing** | Main menu only: title, subtitle, Start New Game / Continue / Exit. Play or Continue immediately calls `change_scene_to_file` to `ForgottenShore.tscn`. No intro scene, no text sequence, no camera/scripted opening. | `scenes/main/Main.tscn` (TitleLabel/SubtitleLabel/buttons), `scripts/core/Main.gd:21-34`, `scenes/world/ForgottenShore.tscn:58-60` |
| Monarch identity and background | **Partial (role label only)** | Player is a `PlayerController` using `player_monarch_sheet.png`; the word “Monarch” appears in docs/README. No in-game name, history, voice, or identity reveal. | `scripts/player/Player.gd:1-21`, `scenes/player/Player.tscn:4-13`, `docs/GDD.md:24`, `readme.md` controls |
| Ancient Crown discovery / interaction | **Missing** | No crown entity, scene node, data definition, asset, interaction target, or save flag. Searches for “crown” in scripts/data/scenes return only the project title and `crownfall_load_on_start`. | Repo-wide grep; `assets/**` has no crown asset; `docs/GDD.md:54` is intent only |
| Crown awakening / vision | **Missing** | No vision/cutscene/scripted-sequence system; no vision assets or state. | No cutscene scripts/scenes; `scripts/ui/ClockHUD.gd` has only a banner overlay |
| Forgotten Shore arrival / settlement establishment | **Partial** | The game loads directly onto Forgotten Shore with the Monarch at `x=0`, a pre-existing Town Center/Hearth anchor, and the full settlement loop. There is no arrival scene, narrative framing, or first-settlement beat. The first feedback line is controls-only. | `scenes/world/ForgottenShore.tscn:504` (Player), `:140-161` (Town Center), `scripts/world/ForgottenShoreSession.gd:93-105` |
| Existing NPCs and dialogue | **Partial (NPCs) / Missing (dialogue)** | NPCs exist as agents: Vagrant → Builder, Villager, Farmer, Archer; Scientist (discovery/recruitment). Interaction produces short prompts and one-line HUD feedback. No dialogue boxes, conversation trees, speaker portraits, choices, or NPC voice/text beyond data `display_name`/`description` (descriptions are not surfaced). | `scripts/npc/NPCBuilderAgent.gd:21-49`, `scripts/npc/NPCPopulationManager.gd:7-18,43-68`, `scripts/player/InteractionResolver.gd:165-198`, `scripts/ui/ClockHUD.gd:11,123-125` |
| Greedling narrative context | **Partial** | Enemies are named Greedling Raider / Shadow Crawler / Gloom Brute; HUD forecast and phase feedback announce incoming raiders, west scouts, and night waves. No explanation of the Greed, the Great Eclipse, or why they attack. | `data/enemies.json:3-17`, `scripts/survival/NightEncounterManager.gd:25-29,107-133`, `scripts/world/ForgottenShoreSession.gd:1070-1091` |
| Forgotten Shrine | **Partial + Ambiguous** | Two distinct “shrine” features exist: (a) a one-time gold node `shrine_cache_far_west` at `x=-780` labelled “Forgotten Shrine”, plus a daily offering interaction at the same location (4W+2S → +2G, +5G with research); (b) the Phase 5 structure `shrine_of_growth` at `x=820` (“Shrine of Growth”), activated for 4G+2W+3S after the Stone Wall Tier 2 milestone, granting +1 Wood per wood acquisition. | `data/resource_nodes.json:40-46`, `scripts/world/ResourceNodeManager.gd:13`, `scripts/player/InteractionResolver.gd:50-61`, `scripts/world/ForgottenShoreSession.gd:512-529`, `data/structures.json:3-20`, `scripts/world/ForgottenShoreSession.gd:751-779`, `docs/PROGRESSION_FOUNDATION_DESIGN.md:534-544` |
| Ancient Relic | **Partial + Ambiguous** | One-time “Ancient Relic” loot at the Greed Portal (`x=1350`) grants +3 Gold and +2 Stone and sets `portal_relic_looted`. There is no inventory item, relic system, or lore text. GDD lists Ancient Relics as a deferred resource. | `scripts/world/ForgottenShoreSession.gd:731-742,1186`, `data/resources.json` (only gold/wood/stone), `docs/GDD.md:107,125` |
| Shipwreck | **Partial** | Three-stage repair at `x=-1350` with escalating costs; Stage 3 records voyage readiness (`forgotten_shore_vessel_ready`) and changes the label to “Vessel Ready! [E] Set Sail”. Interacting after Stage 3 sets `ISLAND_CLEARED`, stops the night encounter, auto-saves, and shows a 7-second “ISLAND CLEARED” banner with a voyage line toward Eldergrove Forest. No voyage scene, island transition, or Chapter II. | `scripts/world/ForgottenShoreSession.gd:15-21,694-728,705`, `scenes/world/ForgottenShore.tscn:427-443`, `docs/GDD.md:132` |
| Chapter progression / story completion | **Missing as narrative** | No chapter model, chapter facts, quest log, story completion state, or chapter-end flow. The closest is gameplay state: `ReignState { ACTIVE, BREACH_PENALTY, ISLAND_CLEARED }`, era progression (Wood/Stone/Iron), and progression facts. “Completion” is the shipwreck/island-cleared gameplay outcome, not a narrative chapter. | `scripts/world/ForgottenShoreSession.gd:7-11,694-707,1079-1084`, `scripts/progression/ProgressionState.gd:25-95`, `scripts/world/EraProgressionManager.gd`, `docs/GDD.md:58-66` |

### 2.1 What the player actually experiences narratively today

1. A title screen with the game name and the subtitle “Forgotten Shore — Single-Player Vertical Slice”.
2. A gameplay HUD with functional text: day/phase/era, resources, a one-line feedback message, night forecast, population, research, structures/blessings.
3. Short contextual interaction prompts (`[E] Collect`, `[E] Speak to the Shipwrecked Stranger`, `[E] Activate Shrine of Growth`, etc.).
4. Functional feedback sentences emitted by gameplay events (recruitment, collection, attacks, sunrise, etc.).
5. A 7-second victory banner on shipwreck escape.
6. World labels (Town Center, wall/watchtower/farm status, shipwreck, Greed Portal, resource nodes).

There is no authored opening, no character introduction, no crown, no vision, no dialogue, and no chapter framing.

---

## 3. Narrative infrastructure inventory

| Capability | Status | Evidence | Reuse potential |
|---|---|---|---|
| Dialogue system | **Absent** | No dialogue/quest scripts or scenes; no dialogue input action in `project.godot`; no dialogue/portrait assets; no NPC conversation data. Only one-line `ClockHUD.FeedbackLabel` and world prompts. | None as-is; build new. |
| Quest / objective system | **Absent** | `ClockHUD` exposes status/resources/feedback/forecast/population/research/structures only; no objective/quest tracker. PRD explicitly defers a quest tracker; REVISED baseline shows “Quest Progress (later)” as a future event consumer. | None as-is; build a minimal objective/beat tracker only if needed. |
| Narrative event system | **Absent (gameplay signals only)** | No EventBus/GameManager autoload/narrative trigger system. Gameplay emits signals: `feedback_message`, time phases (`daylight_started`, `sunset_started`, `night_started`, `sunrise_reached`), `night_encounter_resolved`, `enemy_defeated`, `building_attacked`, `specialist_discovered`, `specialist_recruited`, `research_started`, `research_completed`, `structure_activated`, `era_changed`, `fact_recorded`. | Signals are useful hooks, but they are gameplay events, not a narrative event/trigger system with conditions, once-only state, and skip/replay semantics. |
| Story progression state | **Partial** | `ProgressionState` stores durable, strictly validated facts (14 registered IDs). `EraProgressionManager` tracks era. Session stores `ReignState`, shipwreck stage, portal relic, shrine offering used. | Strong foundation for milestone gates. Facts are idempotent and persisted. |
| Narrative save/load | **Partial** | Schema v2 (`SaveManager.SCHEMA_VERSION = 2`). `build_save_payload` persists `progression_flags` including `progression_facts`, `era_id`, `reign_state`, `shipwreck_stage`, `portal_relic_looted`, `shrine_offering_used_today`, node/tree states, and optional `research`. Strict validation/migration exists. No dialogue/cutscene/quest/chapter fields. | Reuse validation/migration patterns. Narrative state needs either registered facts or a new optional validated save key (schema decision). |
| Cutscene / scripted sequence support | **Absent (one overlay only)** | `ClockHUD.show_victory_banner` creates a full-screen `ColorRect` overlay, fades in, waits 7s, fades out, frees itself. No input gating, skip, camera control, movement lock, or sequence state. No `AnimationPlayer`/cutscene scene. | The banner is a visual seed, not a cutscene system. |
| NPC interaction infrastructure | **Partial** | `InteractionResolver.resolve_nearest` returns `{kind, target_id, primary_command, upgrade_command, prompt_text, distance}`; `Player` emits input signals; session dispatches `execute_world_command`; specialist discovery/recruit, research start, structure activation, camps, shipwreck, portal, trees, buildings. No `talk` kind, no conversation state. | Extend, do not replace. Add a `talk` target/command or a dialogue trigger alongside existing prompts. |
| Narrative text authoring | **Fragments** | Narrative-flavoured `description` fields exist in `data/specialists.json`, `data/structures.json`, `data/technologies.json`, `data/eras.json`. Catalogs validate/normalize them; no UI/query reads `description` (only `display_name` is surfaced). | Authoring seeds only; needs a dialogue/text data format and a UI consumer. |
| Narrative assets | **Absent** | `assets/characters` has only `npc/` and `player/`; landmarks contain only `env_greed_portal.png` and `env_shrine_structure.png`; no crown, portrait, dialogue box, cutscene, or vision assets. Asset guidelines defer “selected narrative/environmental storytelling assets” and “full chapter/cutscene asset sets”. | New assets required. |
| Localization | **Absent** | No translation resources, no locale keys; all text is inline GDScript/data strings. | New foundation required before large dialogue volume. |
| Narrative test coverage | **Absent** | Existing suites cover gameplay systems; no dialogue/quest/cutscene/narrative-state tests. | Extend existing `SceneTree` + `_check` harness patterns. |

### 3.1 Key save/runtime facts for narrative integration

- Save schema: `scripts/save/SaveManager.gd:8-24` (`MIN_SCHEMA_VERSION=1`, `SCHEMA_VERSION=2`, required keys including `progression_flags`). Validation is strict and all-or-nothing; migration exists for v1 → v2.
- Narrative-adjacent persisted state: `scripts/world/ForgottenShoreSession.gd:1650` (`build_save_payload`) and `:1732` (`_apply_loaded_payload`).
- Progression facts: `scripts/progression/ProgressionState.gd:25-95` (14 known IDs), `record_fact` at `:158`, transactional `apply_save_state` at `:196`.
- Runtime signals available to narrative: `scripts/world/TimeManager.gd` phase signals; `ForgottenShoreSession.gd` wiring at `:159-219`; specialist/research/structure signals in their domains.
- Loading behavior: `Engine.set_meta("crownfall_load_on_start", true)` is the Continue path (`scripts/core/Main.gd:30-34`); `_consume_pending_load_if_requested` at `scripts/world/ForgottenShoreSession.gd:1803` silently loads. Any narrative intro must not replay on Continue.

---

## 4. Chapter I — comparison summary

Full beat-by-beat analysis is in [`CHAPTER_01_NARRATIVE_GAP_ANALYSIS.md`](CHAPTER_01_NARRATIVE_GAP_ANALYSIS.md).

| Beat | Status |
|---|---|
| Opening / player introduction | **Missing** |
| Monarch identity / background | **Missing in-game** (role label only) |
| Ancient Crown discovery / interaction | **Missing** (blocked on canon) |
| Crown awakening / vision | **Missing** (blocked on canon) |
| Forgotten Shore arrival / settlement establishment | **Partial** (settlement loop exists; arrival framing missing) |
| Existing NPCs / dialogue | **Partial NPCs; dialogue missing** |
| Greedling narrative context | **Partial** (threat pressure; no lore context) |
| Forgotten Shrine | **Partial + ambiguous identity** |
| Ancient Relic | **Partial + ambiguous definition** |
| Shipwreck | **Partial** (repair/voyage readiness; no voyage/chapter transition) |
| Chapter progression / completion | **Missing as narrative** (gameplay era/island-cleared only) |

The GDD itself states: “the first vertical slice is not required to contain a complete Chapter I narrative, dialogue system, quest chain, or cinematic story sequence” (`docs/GDD.md:66`). The implementation matches that deferral; it does not match a *complete* Chapter I.

---

## 5. Lore consistency findings

These are **consistency observations**, not resolutions. Intentional mysteries/open questions are left open.

### 5.1 Narrative-direction vs implementation (gaps, not contradictions)

- **Ancient Crown.** GDD says the Monarch’s journey is tied to an ancient crown (`docs/GDD.md:54`). No crown exists in implementation. This is an unimplemented premise, not a contradiction.
- **First Light / Great Eclipse / Aetherion.** These exist only in GDD §2.1. No in-game exposition, code, or assets. Missing context, not contradiction.
- **Chapter titles I–V.** GDD §2.2 lists them; only Chapter I’s location exists as gameplay. No chapter state/framework.
- **Narrative scope.** PRD/GDD/REVISED explicitly defer full dialogue, quests, branching story, and chapter framework (`docs/PRD.md:418,505-521`; `docs/GDD.md:66,112`; `docs/REVISED_PROJECT_BASELINE.md:85,286`). Implementation is consistent with the deferral.

### 5.2 Lore-identity ambiguities requiring a decision

1. **Two different “shrines.”**
   - `Forgotten Shrine` at `x=-780`: one-time `shrine_cache_far_west` (+3 Gold) and a daily offering interaction (4W+2S → +2G; +5G with `Inscription Studies`). (`data/resource_nodes.json:40-46`; `InteractionResolver.gd:50-61`; `ForgottenShoreSession.gd:512-529`; `data/technologies.json:6`.)
   - `Shrine of Growth` at `x=820`: a structure activated for 4G+2W+3S after Stone Wall Tier 2, granting a +1 Wood blessing. (`data/structures.json:3-20`; `ForgottenShoreSession.gd:751-779`; `docs/PROGRESSION_FOUNDATION_DESIGN.md:534-544`.)
   - Documentation uses “Forgotten Shrine” for the −780 site (`DECISIONS_M2_M8.md:24`; `GDD.md:38`; `PRD.md:341`) and “Shrine of Growth” for the structure. A technology description explicitly says the Scientist deciphers “the Forgotten Shrine inscriptions” (`data/technologies.json:6`), which currently points to the −780 site, not the Shrine of Growth. Whether these are the same sacred site, two distinct sites, or one is a cache/anchor is **unresolved**.
2. **“Ancient Relic.”** The Greed Portal loot is labelled “Ancient Relic” and grants Gold/Stone (`ForgottenShoreSession.gd:731-742,1186`), while GDD/REVISED defer “Ancient Relics” as a resource category (`GDD.md:107,125`; `REVISED_PROJECT_BASELINE.md:23,101`). If it is a narrative artifact, it has no item/inventory/lore; if it is a reward cache, the wording needs a decision.
3. **Greed Portal / Greedlings / Greed.** Names exist (`Greed Portal`, `Greedling Raider`, etc.) but no explanation of the Greed, the portal’s role, or the relationship to the First Light/Great Eclipse. This is an open lore dependency, not a contradiction.

### 5.3 Documentation drift that affects narrative/environment consistency

The project is the source of truth; several docs are stale relative to the code/data. These should be reconciled before narrative text is authored from them.

| Topic | Documentation | Implementation | Impact |
|---|---|---|---|
| Resource nodes | `DECISIONS_M2_M8.md:17` and `PRD.md:335` say “four single-use caches”; GDD `:127` says five nodes, two single-use + three renewable | `data/resource_nodes.json` has 5 nodes: 2 non-renewable, 3 renewable; `ResourceNodeManager.gd:8-14` matches data | Exploration/narrative pacing claims differ; “caches” vs “renewable nodes” wording. |
| East wall position | `DECISIONS_M2_M8.md:20` and `PRD.md:337` say `x=360`; GDD `:133` says `x=380` | `BuildingManager.WALL_POSITION_X = 380.0`; `data/buildings.json` `position_x: 380.0`; `ForgottenShore.tscn` plot at 380 | Doc drift; environment/lore descriptions derived from docs may cite wrong location. |
| Watchtower position | GDD `:134` says `x=290` | `data/buildings.json` `position_x: 210.0`; `BuildingManager.WATCHTOWER_POSITION_X = 210.0` | Doc drift. |
| Save schema | `DECISIONS_M2_M8.md:25` and `PRD.md:342` say `schema_version: 1` | `SaveManager.SCHEMA_VERSION = 2` (v1 migration supported) | Narrative save planning must target v2 semantics, not the doc claim. |
| First-slice NPC/enemy scope | GDD `:107-111` defers Farmer/Archer and “one basic enemy archetype” | Farmer/Archer and Crawler/Brute/West Scouts are implemented (CHANGELOG `:208,212`; data/code) | GDD scope table is stale; dialogue/content scope must use shipped systems. |
| Monarch and chopping | ROADMAP `:29-31` plans “The Monarch does not chop” (explicitly unimplemented ideas) | Player can chop trees via `[E]` (`InteractionResolver.gd:224-239`; session `chop_tree`) | Not a contradiction (ROADMAP is planned-only), but a narrative/role tension to decide. |

No intentional mystery is resolved here; the audit only flags where decisions are required.

---

## 6. Implementation risks and readiness

### 6.1 Existing systems that can support narrative

| System | Why it is useful | Caveat |
|---|---|---|
| `InteractionResolver` + `Player` input + session command dispatch | Ready-made contextual target resolution and command routing; can add a `talk` target/command. | Do not replace; extend without breaking existing kinds. |
| `ProgressionState` facts | Durable, idempotent, strictly validated milestone state; ideal for “beat seen/condition met”. | Registry is code-owned; new IDs require code + tests + save validation. |
| `SaveManager` schema/validation/migration | Proven atomic save/load, strict validation, v1→v2 migration, rollback. | Schema is strict; narrative state needs an explicit design (facts vs new optional key). |
| Gameplay signals | Phase, night resolution, specialist, research, structure, era, feedback events. | Signals are not a narrative event system; no conditions/once-only/skip state. |
| `ClockHUD` feedback/forecast + label APIs | Minimal presentation channels for short text. | `FeedbackLabel` is a single overwritten line; cannot host dialogue. |
| `ClockHUD.show_victory_banner` | A full-screen text overlay with fade in/out. | 7s timer, no input gating/skip/state; only a seed. |
| Data-driven catalogs (specialists/structures/technologies) | Established validated-data pattern with stable IDs and fail-closed loading. | Reusable pattern for dialogue/beat definitions, not the dialogue runtime. |
| `PauseMenu` + scene transitions | Existing pause/return-to-menu flow. | Narrative must integrate pause/input and avoid autosave mid-sequence. |
| Tests + repo verifier | `SceneTree` harness patterns, headless suites, integrity checks. | Narrative tests must follow tab indentation, `_check`, no raw `assert`, no `root.add_child`. |

### 6.2 Systems needing small extensions

- **InteractionResolver**: add a `talk`/`converse` target kind and prompt; keep existing priorities. Session needs a dispatch path that starts dialogue without consuming gameplay resources.
- **ClockHUD or a new CanvasLayer**: add a dialogue panel (speaker, body, advance/skip, choices) rather than overloading `FeedbackLabel`.
- **Input map**: add `dialogue_advance` / `dialogue_skip` actions (currently absent from `project.godot`).
- **Save payload**: add a validated narrative-state section (or register narrative facts) with migration and strict rejection; decide schema version strategy.
- **Trigger evaluation**: reuse `ProgressionUnlockEvaluator` semantics (all_of/any_of over registered facts) but do not pretend it is a narrative event system; add once-only/seen state.

### 6.3 Missing foundations

- Dialogue data format, validation, and runtime (nodes, lines, conditions, choices, localization keys).
- Narrative state model (seen beats/lines, chapter progress, dialogue completion) with save/load and transactional rejection.
- Narrative event/trigger system with idempotence, load-silence, skip/replay semantics, and conditions beyond facts.
- Cutscene/sequence runner (movement/input lock, camera control, fades, waits, skip, pause integration).
- Narrative UI (dialogue box, speaker/portrait, advance indicator, log, accessibility).
- Narrative asset pipeline (crown, portraits, cutscene art, audio, fonts).
- Localization pipeline.
- Narrative test harness and acceptance criteria.

### 6.4 Architectural conflicts / risks

1. **Session coupling.** `ForgottenShoreSession.gd` is the central orchestrator (input wiring, command dispatch, simulation, UI updates, save/load). Adding narrative triggers directly into `_process`/command handlers will deepen the monolith. A separate presentation-layer refactor exists on another branch (`refactor/shore-presentation-layer`) but is **not merged**; narrative work must not silently depend on it.
2. **Feedback channel contention.** Every gameplay event writes to `ClockHUD.FeedbackLabel` (`ClockHUD.gd:123-125`). Dialogue must not reuse that label; gameplay feedback will overwrite it immediately.
3. **Save timing.** Autosave occurs at sunrise (`ForgottenShoreSession.gd:1094-1114`) and manual save is disabled at night; dialogue/cutscenes need explicit save semantics (e.g., save only at safe boundaries, never mid-line; restore narrative state silently).
4. **Load/Continue behavior.** `_consume_pending_load_if_requested` loads silently (`:1803`); narrative intros/one-shots must not replay on Continue. Facts and seen-state need deterministic restoration.
5. **Time/night signals during sequences.** Narrative sequences can overlap sunset/night transitions and enemy spawns. Need input/time policy (pause simulation? lock movement? defer triggers?).
6. **Strict save schema.** New top-level keys require `validate_payload` updates, migration decisions, and tests. Adding many fact IDs to `KNOWN_FACT_IDS` is code-owned and can bloat the registry; a narrative-state object may be cleaner, but then schema/version migration must be designed.
7. **Repo verifier/CI.** The verifier checks scene `load_steps`, tab indentation, test conventions, CI lock strings, and documentation consistency; new narrative scenes/scripts/docs must keep it green. Headless CI must not require a desktop.
8. **Data descriptions are not UI.** Specialist/structure/technology/era `description` fields are validated but never displayed; authors may assume they are live text. Do not treat them as implemented dialogue.
9. **Multiplayer seam.** REVISED baseline keeps host-authoritative simulation for future multiplayer; narrative triggers/state should eventually be host-authoritative and must not trust client narrative state.
10. **Early-content risk.** Implementing crown/vision/Chapter I before canon approval risks hardcoding lore, save IDs, and scene structure that later conflict with approved stories. The GDD explicitly defers these decisions.

### 6.5 Readiness conclusion

- **Ready now:** narrative *infrastructure* design/implementation groundwork, using existing interaction/save/fact/signal systems.
- **Not ready:** implementing Chapter I narrative content, dialogue script, crown/vision beats, quest/chapter framework, or cutscenes, because the beat-level content and several canon identities are not approved/documented in the repository.
- **Recommended gate:** approve the Chapter I beat sheet and canon decisions, then build the runtime foundation, then content.

---

## 7. Evidence appendix (primary references)

**Scenes**
- `scenes/main/Main.tscn` — title/subtitle/buttons (no intro; no narrative nodes).
- `scenes/world/ForgottenShore.tscn` — gameplay scene; Player at default position, Town Center anchor, wall/watchtower/farm plots, resource nodes, ToolStands, Shipwreck, Greed Portal, enemy actors, `ClockHUD` labels (“Explore Forgotten Shore”, forecast, population).
- `scenes/player/Player.tscn` — `player_monarch_sheet.png`; no identity/dialogue components.

**Runtime**
- `scripts/core/Main.gd:3,7,21-34` — direct scene transition; no narrative state.
- `scripts/world/ForgottenShoreSession.gd:93-105` — `_ready` setup and controls-only feedback.
- `scripts/world/ForgottenShoreSession.gd:7-11,694-728` — `ReignState`, shipwreck stages, `ISLAND_CLEARED`, victory banner.
- `scripts/world/ForgottenShoreSession.gd:731-742` — Greed Portal relic loot.
- `scripts/world/ForgottenShoreSession.gd:751-779,789-835,863-878` — structure activation, specialist discovery/recruit, research start/completion feedback.
- `scripts/world/ForgottenShoreSession.gd:1061-1134` — phase/sunrise/night feedback and outcomes.
- `scripts/world/ForgottenShoreSession.gd:1650,1732,1803` — save payload/apply/continue-load.
- `scripts/player/InteractionResolver.gd:32-260` — prompt/target model (resources, shrine offering, camp, shipwreck, portal, specialists, research, structures, trees, hearth).
- `scripts/npc/NPCBuilderAgent.gd:21-49,80-100` — NPC identity/roles/recruitment; no dialogue.
- `scripts/survival/NightEncounterManager.gd:25-29,107-133` — enemy names/forecast.
- `scripts/ui/ClockHUD.gd:11,61-88,123-125` — feedback label and victory banner.
- `scripts/save/SaveManager.gd:8-24,286-450` — schema/validation.
- `scripts/progression/ProgressionState.gd:25-95,151-205` — facts.
- `scripts/world/EraProgressionManager.gd` — era state/names/descriptions handling.

**Data**
- `data/specialists.json:6-50` — Scientist + future-island descriptions.
- `data/structures.json:3-46` — Shrine of Growth / Statue of the First Sailor / Temple of the Dawn descriptions.
- `data/technologies.json:5-25` — research descriptions.
- `data/eras.json:5-20` — era descriptions.
- `data/resource_nodes.json:3-46` — resource labels including “Forgotten Shrine”.
- `data/enemies.json:3-17` — enemy archetype names.
- `data/resources.json` — only gold/wood/stone.

**Documentation**
- `docs/GDD.md:18,24,46-66,68-81,101-113,115-139,155-171,191-205,224-234` — narrative premise, chapter table, scope deferral, first-slice systems.
- `docs/PRD.md:296-325,400-449,500-521` — narrative exclusions, tutorial, HUD, out-of-scope.
- `docs/REVISED_PROJECT_BASELINE.md:23,101,250-301,440-451` — scope and future “Quest Progress”.
- `docs/DECISIONS_M2_M8.md:17-25` — approved P0 decisions (including stale values noted above).
- `docs/PROGRESSION_FOUNDATION_DESIGN.md:455-549` — structure/buff facts and Shrine of Growth.
- `docs/ASSET_GUIDELINES.md:480-506` — narrative/cutscene assets deferred.
- `docs/ROADMAP.md:3-9,24-56` — explicitly planned/unimplemented ideas.
- `docs/CHANGELOG.md:12-40,208-213` — shipped gameplay expansions (no narrative system).

**Assets**
- `assets/characters/player/player_monarch_sheet.png`
- `assets/characters/npc/` (builder/farmer/archer sheets)
- `assets/enemies/first_enemy/enemy_greedling_raider_sheet.png`
- `assets/environment/landmarks/env_greed_portal.png`, `env_shrine_structure.png`
- No crown/dialogue/portrait/cutscene/vision assets (filename search returned none).
