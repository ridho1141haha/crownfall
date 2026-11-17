# Crownfall — Narrative Implementation Readiness Audit

**Audit date:** 2026-11-17 (refreshed after PR #11)  
**Repository snapshot:** `main` @ `eb82ae4d63a33a5c0fb9bb3f17f4bf832860c79a` (PR #11 merged; N1–N3 runtime foundation is now on main).  
**N4.0 update (2026-11-17):** after this snapshot, N4.0 — the global `PlayerProfile` (`user://player_profile.json`), the New Game/Continue entry gate with the returning-player Skip choice, and the labelled `PrologueShell` placeholder route target — was implemented and verified (101-check suite plus the adapted M8 integration slice; see [`NARRATIVE_IMPLEMENTATION_ROADMAP.md`](NARRATIVE_IMPLEMENTATION_ROADMAP.md) §5 and [`narrative/PROLOGUE_PRODUCTION_BREAKDOWN.md`](narrative/PROLOGUE_PRODUCTION_BREAKDOWN.md) §5). **N4.1 update (2026-11-17):** the placeholder then became the functional Prologue shell at the same path (per-run `NarrativeState` + `DialoguePanel` + `SequenceRunner`, allowlisted sequence transitions, single-transition exit guard, labelled development-only menu exit; 74-check suite) — still no story beats, no completion marking, and the Prologue remains not playable as a story experience. **N4.2 update (2026-11-17):** the first two beats are now authored (`scripts/narrative/PrologueBeats.gd`, `pl_01_lost_world` + `pl_02_faint_resonance`, NarrativeData-validated data only; Story Design candidate narration; no Eclipse cause, no power origin, no crown) and playable on New Game — the shell auto-plays and chains them exactly-once and stops at the N4.2 boundary with no scene transition and no completion marking (89-check suite; see roadmap §5). The inventory below otherwise still describes the `eb82ae4` state.  
**Engine:** Godot `4.7.2.stable`  
**Scope:** narrative implementation only. No gameplay code was modified, no features were added, no lore was invented.  
**Companion documents:** [`CHAPTER_01_NARRATIVE_GAP_ANALYSIS.md`](CHAPTER_01_NARRATIVE_GAP_ANALYSIS.md), the official [`NARRATIVE_IMPLEMENTATION_ROADMAP.md`](NARRATIVE_IMPLEMENTATION_ROADMAP.md) (phases N0–N5), and [`narrative/PROLOGUE_STORY_DESIGN.md`](narrative/PROLOGUE_STORY_DESIGN.md)

---

## 0. Method and evidence standard

This audit treats the **Godot project as the source of truth for gameplay implementation**. Design documents were read as *intent*, not as proof of implementation. A feature is counted as implemented only when it exists in scenes/scripts/data and is reachable through the current runtime paths.

Inspected evidence classes:

- Scenes: `scenes/main/Main.tscn`, `scenes/world/ForgottenShore.tscn`, `scenes/player/Player.tscn`
- Runtime scripts: `scripts/world/ForgottenShoreSession.gd`, `scripts/world/ShoreView.gd`, `scripts/world/ShoreFX.gd`, `scripts/world/TimeManager.gd`, `scripts/player/Player.gd`, `scripts/player/InteractionResolver.gd`, `scripts/ui/ClockHUD.gd`, `scripts/ui/PauseMenu.gd`, `scripts/npc/*`, `scripts/kingdom/*`, `scripts/survival/*`, `scripts/progression/*`, `scripts/specialists/*`, `scripts/research/*`, `scripts/structures/*`, `scripts/buffs/*`, `scripts/save/*`
- Data: `data/*.json`
- Assets: `assets/**` (asset inventory and filename searches)
- Documentation: `readme.md`, `docs/GDD.md`, `docs/PRD.md`, `docs/REVISED_PROJECT_BASELINE.md`, `docs/SYSTEMS.md`, `docs/TDD.md`, `docs/DECISIONS_M2_M8.md`, `docs/PROGRESSION_FOUNDATION_DESIGN.md`, `docs/ASSET_GUIDELINES.md`, `docs/ROADMAP.md`, `docs/CHANGELOG.md`, `docs/NARRATIVE_IMPLEMENTATION_ROADMAP.md`, `docs/narrative/PROLOGUE_STORY_DESIGN.md`

Boundary note: the repository now contains the Prologue story design, the N0–N5 roadmap, and the N1–N3 runtime foundation merged by PR #11. The runtime is implemented and tested but is not wired to canon content. The Chapter I beat sheet is being introduced in `docs/CHAPTER_01_BEAT_SHEET.md` as a **draft, non-canon proposal** pending owner approval; it does not authorize implementation.

---

## 1. Executive summary

| Dimension | Maturity | Summary |
|---|---|---|
| Gameplay loop | **Implemented / tested** | Movement, economy, building, NPC builder/farmer/archer, night defense, save/load, specialists, research, shrine/structure foundation, buffs, era progression. The presentation refactor (`ShoreView`/`ShoreFX`, PR #8) is merged. |
| Narrative design | **Prologue designed, Chapter I not yet** | “The Crown's Call” defines 9 Prologue beats, Monarch direction, vision content, and an OPEN-decision list. Chapter I has no approved beat sheet yet (roadmap N5). |
| Narrative content (runtime) | **Near-zero** | No playable opening, crown, vision, dialogue, or chapter progression. Only functional prompts/status text and a few lore-flavoured names/descriptions. |
| Narrative infrastructure | **Implemented foundation (N1–N3)** | Dialogue panel, control lock, sequence runner, validator, and in-memory state are merged and tested. They are not yet connected to authored content. No quest/objective system, chapter progression, cutscene content, or narrative save fields. |
| Narrative data | **Fragments** | Narrative-flavoured `description` fields exist in data JSON but are validated only; no UI reads them. |
| Narrative assets | **Absent** | No crown, portrait, dialogue box, cutscene, or vision assets. Asset guidelines defer narrative asset sets; the Prologue design lists the needed assets. |

**Verdict:** the project remains a runnable **gameplay vertical slice with a merged narrative runtime foundation**, not a playable narrative implementation. N1–N3 are implemented and tested, but no canon Prologue or Chapter I content is wired into them. The Prologue remains designed, not playable. Chapter I now has a draft beat sheet proposal (`CHAPTER_01_BEAT_SHEET.md`) pending owner approval; N4 Prologue content remains the next narrative implementation milestone.

The biggest gaps are: (1) no Prologue scenes/content, (2) no integration of the runtime with NPCs or gameplay beats, (3) no chapter progression/quest system (and no evidence yet that one is needed), (4) no approved Chapter I beat sheet or dialogue script, and (5) unresolved lore identities: the two shrines, the Ancient Relic, and Greedling/Greed Portal origins.

---

## 2. Current narrative implementation

Status legend: **Implemented** = reachable in runtime; **Partial** = functional system exists but narrative framing is absent/incomplete; **Designed** = approved/planned in a design document but not implemented; **Missing** = no implementation; **Ambiguous** = implementation exists but canon/identity is unresolved.

| Beat | Status | What actually exists | Evidence |
|---|---|---|---|
| Opening sequence / player introduction | **Designed (Prologue), not implemented** | Prologue “The Crown's Call” defines beats 01–09 (Lost World → Shipwreck → wake on Forgotten Shore). The shipped build has no Prologue scene: the title menu routes Start/Continue directly to `ForgottenShore.tscn`; the first in-game feedback is a controls line. | `docs/narrative/PROLOGUE_STORY_DESIGN.md:49-162`; `scripts/core/Main.gd:18-27`; `scripts/world/ForgottenShoreSession.gd:84,99` |
| Monarch identity and background | **Designed (Prologue §2/§5), not implemented in-game** | Agreed direction: human Monarch, dormant inherited power, one small uncontrolled childhood manifestation, adult search, “curious and observant, not a trained mage or experienced king”. In-game, the Monarch is only a `PlayerController` sprite with no name/history/voice. | `PROLOGUE_STORY_DESIGN.md:24-38,165-178`; `scripts/player/Player.gd:1-21`; `scenes/player/Player.tscn:4-13` |
| Ancient Crown discovery / interaction | **Designed (Prologue beats 05–06), not implemented** | Design: clues lead to a forgotten royal ruin, a hidden chamber, a crown on an altar; the crown is a **trigger/key, not the source of Monarch's power**. No crown entity, data definition, interaction target, asset, or save flag exists in code. | `PROLOGUE_STORY_DESIGN.md:31,49-162` (beats 05–06); no crown asset under `assets/**`; repo-wide search finds only the project title and `crownfall_load_on_start` |
| Crown awakening / vision | **Designed (Prologue beat 06), not implemented** | Design: touching the crown awakens inherited power and triggers a fragmented vision (ancient kingdom, ruler silhouette, recurring symbol, fading light, interrupted destruction); the vision must not reveal protected mysteries. No cutscene/sequence runtime exists; the only overlay is `ClockHUD.show_victory_banner`. | `PROLOGUE_STORY_DESIGN.md:33,44,beat 06`; `scripts/ui/ClockHUD.gd:61` |
| Forgotten Shore arrival / settlement establishment | **Partial** | Prologue beat 09 designs the landing (wake on the beach, wreckage, crown continuity, prompt control handoff). The shipped build loads directly onto Forgotten Shore with the Monarch at `x=0`, a fixed Town Center/Hearth anchor, and the full settlement loop; no arrival scene exists. | `PROLOGUE_STORY_DESIGN.md:218-231`; `scenes/world/ForgottenShore.tscn` (Player at default position, Town Center anchor); `ForgottenShoreSession.gd:84-99` |
| Existing NPCs and dialogue | **Partial (NPCs + runtime) / Missing (content integration)** | NPCs exist as agents: Vagrant → Builder, Villager, Farmer, Archer; Scientist (discovery/recruitment). Interaction produces short prompts and one-line HUD feedback. The dialogue panel exists but is not connected to NPCs; no canon conversations, portraits, choices, or voice are authored. | `scripts/npc/NPCBuilderAgent.gd:21-49`, `scripts/npc/NPCPopulationManager.gd:7-18,43-68`, `scripts/player/InteractionResolver.gd:146-198`, `scripts/ui/ClockHUD.gd:11,125` |
| Greedling narrative context | **Partial (lore explicitly out of scope)** | Enemies are named Greedling Raider / Shadow Crawler / Gloom Brute; HUD forecast and phase feedback announce incoming raiders, west scouts, and night waves. The roadmap explicitly leaves “defining the origins or purpose of Greedlings, Greed Portal…” out of scope. | `data/enemies.json:3-17`, `scripts/survival/NightEncounterManager.gd:25-29,107-133`, `ForgottenShoreSession.gd:920-966`, `docs/NARRATIVE_IMPLEMENTATION_ROADMAP.md` §4 |
| Forgotten Shrine | **Partial + Ambiguous** | Two distinct “shrine” features: (a) one-time `shrine_cache_far_west` at `x=-780` labelled “Forgotten Shrine” plus a daily offering (4W+2S → +2G, +5G with research); (b) the Phase 5 structure `shrine_of_growth` at `x=820` (“Shrine of Growth”), activated for 4G+2W+3S after the Stone Wall Tier 2 milestone, granting +1 Wood per wood acquisition. Roadmap N5 says not to conflate them until an explicit lore decision. | `data/resource_nodes.json:40-46`, `scripts/world/ResourceNodeManager.gd:13`, `InteractionResolver.gd:50-61`, `ForgottenShoreSession.gd:676-707`, `data/structures.json:3-20`, `docs/PROGRESSION_FOUNDATION_DESIGN.md:534-544`, roadmap N5 |
| Ancient Relic | **Partial + Ambiguous** | One-time “Ancient Relic” loot at the Greed Portal (`x=1350`) grants +3 Gold and +2 Stone and sets `portal_relic_looted`. No inventory item, relic system, or lore text. GDD lists Ancient Relics as a deferred resource; the roadmap leaves defining the Ancient Relic out of scope. | `ForgottenShoreSession.gd:656-675,997-1001` (label), `data/resources.json`, `docs/GDD.md:107,125`, roadmap §4 |
| Shipwreck | **Partial** | Two different things share the word: the **Prologue beat 08** designs the arrival-wreck cinematic (not implemented), and the **in-game Shipwreck structure** at `x=-1350` is a three-stage repairable vessel. Stage 3 records voyage readiness and enables “ISLAND CLEARED” + a voyage banner; no voyage scene or island transition exists. | `PROLOGUE_STORY_DESIGN.md` beat 08; `ForgottenShoreSession.gd:15-17,619-655`; `scenes/world/ForgottenShore.tscn` ShipwreckAnchor |
| Chapter progression / story completion | **Missing as narrative** | No chapter model, chapter facts, quest log, story completion state, or chapter-end flow. Closest is gameplay state: `ReignState { ACTIVE, BREACH_PENALTY, ISLAND_CLEARED }`, era progression (Wood/Stone/Iron), and progression facts. Roadmap N5 requires a Chapter I beat sheet first. | `ForgottenShoreSession.gd:7-11,619-655,920-966`, `scripts/progression/ProgressionState.gd:25-95`, `scripts/world/EraProgressionManager.gd`, roadmap N5 |

### 2.1 What the player actually experiences narratively today

1. A title screen with the game name and the subtitle “Forgotten Shore — Single-Player Vertical Slice”.
2. A gameplay HUD with functional text: day/phase/era, resources, a one-line feedback message, night forecast, population, research, structures/blessings.
3. Short contextual interaction prompts (`[E] Collect`, `[E] Speak to the Shipwrecked Stranger`, `[E] Activate Shrine of Growth`, `[E] Shrine Offering`, etc.).
4. Functional feedback sentences emitted by gameplay events (recruitment, collection, attacks, sunrise, etc.).
5. A 7-second victory banner on shipwreck escape.
6. World labels (Town Center, wall/watchtower/farm status, shipwreck, Greed Portal, resource nodes).

There is still no authored opening, no character introduction, no crown, no vision, no canon dialogue, and no chapter framing at runtime. The merged dialogue panel + sequence runner foundation (N1–N3) is not wired into any gameplay content; the Prologue that would provide the opening is designed but not built.

---

## 3. Narrative infrastructure inventory

| Capability | Status | Evidence | Reuse potential |
|---|---|---|---|
| Dialogue system | **Foundation only** | `DialoguePanel` (speaker/body/advance, consumes input while open) exists with a 19-check suite; no canon content, portraits, choices, voice, or history. Roadmap N2. | None beyond the foundation; content authoring still needed. |
| Quest / objective system | **Absent** | `ClockHUD` exposes status/resources/feedback/forecast/population/research/structures only; no objective/quest tracker. PRD defers a quest tracker; REVISED baseline shows “Quest Progress (later)”. | None as-is; only if a later approved milestone needs it. |
| Narrative event system | **Partial foundation** | In-memory `NarrativeState` (per-run completed IDs) + `SequenceRunner` exactly-once completion. Gameplay signals remain the only world events; no persisted trigger/condition system. | Hooks exist; conditions/once-only/seen state beyond the runner are future work (N4/N5). |
| Story progression state | **Partial** | `ProgressionState` stores durable, strictly validated facts (14 registered IDs). `EraProgressionManager` tracks era. Session stores `ReignState`, shipwreck stage, portal relic, shrine offering used. No narrative chapter/beat/seen state. | Strong foundation for milestone gates. Facts are idempotent and persisted. |
| Narrative save/load | **Partial** | Schema v2 (`SaveManager.SCHEMA_VERSION = 2`). `build_save_payload` persists `progression_flags` including `progression_facts`, `era_id`, `reign_state`, `shipwreck_stage`, `portal_relic_looted`, `shrine_offering_used_today`, node/tree states, and optional `research`. No dialogue/cutscene/quest/chapter fields. | Reuse validation/migration patterns. NarrativeState is intentionally in-memory under the approved N1 decision; no narrative save fields are currently required. Revisit only if resumable/cross-session story requirements are approved. |
| Cutscene / scripted sequence support | **Foundation only** | `SequenceRunner` executes typed allowlisted steps (dialogue/wait/lock_control/unlock_control/play_cue/change_scene/finish) with skip/cancel cleanup and a 31-check suite; no cinematic content or camera scripting yet. `ClockHUD.show_victory_banner` remains the only shipped in-game overlay. | The runner is the foundation; Prologue staging/camera work is N4. |
| NPC interaction infrastructure | **Partial** | `InteractionResolver.resolve_nearest` returns `{kind, target_id, primary_command, upgrade_command, prompt_text, distance}`; `Player` emits input signals; session dispatches `execute_world_command`; specialist discovery/recruit, research start, structure activation, camps, shipwreck, portal, trees, buildings. No `talk` kind, no conversation state. | Extend, do not replace. Add a `talk` target/command or a dialogue trigger alongside existing prompts. |
| Presentation layer (merged PR #8) | **Present, not narrative** | `ShoreView` (world visual setup/sync) and `ShoreFX` (transient feedback) are merged and wired from the session (`fx = ShoreFX.new(...)` `:86`, `view = ShoreView.new(...)` `:87`, `view.advance_and_sync(delta)` `:148`). They are world presentation helpers, not a dialogue, cutscene, or narrative runtime. | Keeps presentation separated; narrative UI should follow the same separation (own surface, no gameplay authority). |
| Narrative text authoring | **Fragments** | Narrative-flavoured `description` fields exist in `data/specialists.json`, `data/structures.json`, `data/technologies.json`, `data/eras.json`. Catalogs validate/normalize them; no UI/query reads `description` (only `display_name` is surfaced). | Authoring seeds only; needs a dialogue/text data format and a UI consumer. |
| Narrative assets | **Absent** | `assets/characters` has only `npc/` and `player/`; landmarks contain only `env_greed_portal.png` and `env_shrine_structure.png`; no crown, portrait, dialogue box, cutscene, or vision assets. Asset guidelines defer narrative sets; the Prologue design §7 lists the needed visuals/audio. | New assets required for Prologue. |
| Localization | **Absent** | No translation resources, no locale keys; all text is inline GDScript/data strings. Prologue dialogue language/voice is marked OPEN. | New foundation required before large dialogue volume. |
| Narrative test coverage | **Foundation suites** | `tests/test_narrative_foundation.gd` (39 checks), `tests/test_dialogue_panel.gd` (19), `tests/test_sequence_runner.gd` (31); fixtures under `tests/fixtures/` are explicitly non-canon. No content-level narrative tests yet. | Extend the same `SceneTree` + `_check` harness patterns for N4 content. |

### 3.1 Key save/runtime facts for narrative integration

- Save schema: `scripts/save/SaveManager.gd:8-24` (`MIN_SCHEMA_VERSION=1`, `SCHEMA_VERSION=2`, required keys including `progression_flags`). Validation is strict and all-or-nothing; migration exists for v1 → v2.
- Narrative-adjacent persisted state: `scripts/world/ForgottenShoreSession.gd:1099` (`build_save_payload`) and `:1181` (`_apply_loaded_payload`). Loading is silent: `_apply_loaded_payload` restores the clock with `apply_save_dict(data, true)`.
- Continue path: `Engine.set_meta("crownfall_load_on_start", true)` (`scripts/core/Main.gd:24-27`); `_consume_pending_load_if_requested` at `scripts/world/ForgottenShoreSession.gd:1252` loads silently. Any Prologue/opening must not replay on Continue.
- Progression facts: `scripts/progression/ProgressionState.gd:25-95` (14 known IDs), `record_fact` at `:158`, transactional `apply_save_state` at `:196`.
- Runtime signals available to narrative: `scripts/world/TimeManager.gd:4-7`; session wiring at `scripts/world/ForgottenShoreSession.gd:151` (`_wire_signals`).

**TimeManager signal semantics (corrected):** the phase signals `daylight_started`, `sunset_started`, `night_started`, and `sunrise_reached` are **transition-time events, not per-frame ticks**. `_transition_to_next_phase` (`TimeManager.gd:137`) emits exactly one signal per phase change; `_emit_initial_phase_if_needed` (`:130`) emits the initial daylight once; `apply_save_dict` (`:99`) re-emits the current phase only when `restore_silent = false`, and the session load path restores silently. The real duplicate/trigger risks for narrative listeners are therefore: (a) connecting the same handler more than once (use `is_connected` guards, as `ClockHUD` now does), and (b) a trigger reacting to a transition emitted while a restored scene is still settling. Narrative triggers must stay idempotent and load-silent — not because signals “fire every frame” (they do not), but to survive save-restore and re-entry safely.

---

## 4. Chapter I — comparison summary

Prologue and Chapter I are now separate scopes: the crown discovery, awakening, and vision belong to the Prologue (“The Crown's Call”), and Chapter I begins when the player regains control on Forgotten Shore (`PROLOGUE_STORY_DESIGN.md:218-231`). The full beat-by-beat analysis is in [`CHAPTER_01_NARRATIVE_GAP_ANALYSIS.md`](CHAPTER_01_NARRATIVE_GAP_ANALYSIS.md).

| Chapter I beat | Status |
|---|---|
| Opening / arrival handoff (Prologue beat 09) | **Designed, not implemented** |
| Monarch identity / background establishment | **Designed (Prologue), not implemented in-game** |
| Settlement establishment | **Partial** (gameplay exists; narrative framing missing) |
| Existing NPCs / dialogue | **Partial NPCs + runtime; content integration missing** |
| Greedling narrative context | **Partial** (threat pressure; lore out of scope) |
| Forgotten Shrine | **Partial + ambiguous identity** |
| Ancient Relic | **Partial + ambiguous definition** |
| Shipwreck (departure vessel) | **Partial** (repair/voyage readiness; no voyage/chapter transition) |
| Chapter progression / completion | **Missing as narrative** (roadmap N5 pending beat sheet) |

Prologue beats 01–09 are **designed, not implemented**; see the gap analysis §2.

---

## 5. Lore consistency findings

These are **consistency observations**, not resolutions. Intentional mysteries/open questions are left open.

### 5.1 Narrative-direction vs implementation

- **Ancient Crown / awakening / vision.** Now designed in the Prologue (“The Crown's Call”, beats 05–06; crown is a trigger/key, power already exists in Monarch). Nothing is implemented yet — a planned-but-unshipped feature, not a contradiction.
- **First Light / Great Eclipse / Aetherion.** Designed as Prologue beat 01 with candidate narration; the cause of the Great Eclipse must remain unexplained. Not implemented in-game.
- **Chapter titles I–V.** GDD §2.2 lists them; only Chapter I’s location exists as gameplay. No chapter state/framework. The GDD scope clarification now distinguishes the implemented N1–N3 runtime foundation from the still-unimplemented Prologue and Chapter I story content (`docs/GDD.md:66,112`).
- **Narrative scope deferrals.** PRD/GDD/REVISED still defer full dialogue, quests, branching story, and chapter framework (`docs/PRD.md:418,505-521`; `docs/REVISED_PROJECT_BASELINE.md:85,286`). Implementation is consistent; the roadmap narrows the first delivery to the Prologue plus a minimal foundation (N0–N4).

### 5.2 Lore-identity ambiguities requiring a decision (still open)

1. **Two different “shrines.”**
   - `Forgotten Shrine` at `x=-780`: one-time `shrine_cache_far_west` (+3 Gold) and a daily offering interaction (4W+2S → +2G; +5G with `Inscription Studies`). (`data/resource_nodes.json:40-46`; `InteractionResolver.gd:50-61`; `ForgottenShoreSession.gd:437-449`; `data/technologies.json:6`.)
   - `Shrine of Growth` at `x=820`: a structure activated for 4G+2W+3S after Stone Wall Tier 2, granting a +1 Wood blessing. (`data/structures.json:3-20`; `ForgottenShoreSession.gd:676-707`; `docs/PROGRESSION_FOUNDATION_DESIGN.md:534-544`.)
   - Roadmap N5 explicitly says: “Do not conflate the existing Forgotten Shrine with the Shrine of Growth; preserve their separate identities until an explicit lore decision is made.” Whether they are one tradition, two sites, or a cache/anchor pair remains **OPEN**.
2. **“Ancient Relic.”** The Greed Portal loot is labelled “Ancient Relic” and grants Gold/Stone (`ForgottenShoreSession.gd:656-675,997-1001`), while GDD/REVISED defer “Ancient Relics” as a resource category (`GDD.md:107,125`; `REVISED_PROJECT_BASELINE.md:23,101`) and the roadmap leaves defining the Ancient Relic out of scope. Artifact vs reward cache remains **OPEN**.
3. **Greed Portal / Greedlings / Greed.** Names exist (`Greed Portal`, `Greedling Raider`, etc.) but the origins/purpose are explicitly out of scope (roadmap §4). This is an open lore dependency, not a contradiction.

### 5.3 Prologue OPEN items and protected mysteries

The Prologue design resolves the earlier “crown details undecided” claim, but it still marks these **OPEN** (`docs/narrative/PROLOGUE_STORY_DESIGN.md:248-265`): the royal symbol's exact design, the ruins' name, the exact childhood location, Monarch's prior travel notes/artifacts, the ship's origin, the voyage destination, the cause of the storm, the crown's post-wreck appearance (draft), dialogue language/voice, and Prologue skip behavior.

**Protected mysteries** that must NOT be revealed by implementation (`PROLOGUE_STORY_DESIGN.md` §1/§2/beat 06; roadmap §4): the crown's origin, the source of Monarch's inherited power, the dynasty/ancestor, the ancient kingdom's name, and the cause of the Great Eclipse.

### 5.4 Documentation drift that affects narrative/environment consistency

The project is the source of truth; several docs are stale relative to the code/data. These should be reconciled before narrative text is authored from them.

| Topic | Documentation | Implementation | Impact |
|---|---|---|---|
| Resource nodes | `DECISIONS_M2_M8.md:17` and `PRD.md:335` say “four single-use caches”; GDD `:127` says five nodes, two single-use + three renewable | `data/resource_nodes.json` has 5 nodes: 2 non-renewable, 3 renewable; `ResourceNodeManager.gd:8-14` matches data | Exploration/narrative pacing claims differ; “caches” vs “renewable nodes” wording. |
| East wall position | `DECISIONS_M2_M8.md:20` and `PRD.md:337` say `x=360`; GDD `:133` says `x=380` | `BuildingManager.WALL_POSITION_X = 380.0`; `data/buildings.json` `position_x: 380.0`; `ForgottenShore.tscn` plot at 380 | Doc drift; environment/lore descriptions derived from docs may cite the wrong location. |
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
| `ProgressionState` facts | Durable, idempotent, strictly validated milestone state; ideal for “beat seen/condition met”. | Registry is code-owned; new IDs require code + tests + save validation. Roadmap N1: keep narrative facts distinct from gameplay facts. |
| `SaveManager` schema/validation/migration | Proven atomic save/load, strict validation, v1→v2 migration, rollback. | Schema is strict; N1 intentionally keeps NarrativeState in-memory. Any future resumable story state needs a separate approved schema/migration design. |
| Gameplay signals | Phase transitions, night resolution, specialist, research, structure, era, feedback events. | Transition-time events (§3.1); need once-only/seen state and load-silence, not raw signal use. |
| `ClockHUD` feedback/forecast + label APIs | Minimal presentation channels for short text. | `FeedbackLabel` is a single overwritten line; cannot host dialogue. |
| `ClockHUD.show_victory_banner` | A full-screen text overlay with fade in/out. | 7s timer, no input gating/skip/state; only a visual seed. |
| `ShoreView` / `ShoreFX` (merged) | World presentation helpers with clean delegation from the session (`:86-87,148`). | They are not narrative controllers; a dialogue/sequence presenter should be a separate surface with the same ownership discipline (roadmap §7). |
| Data-driven catalogs (specialists/structures/technologies) | Established validated-data pattern with stable IDs and fail-closed loading. | Reusable pattern for dialogue/beat definitions, not the dialogue runtime. |
| `PauseMenu` + scene transitions | Existing pause/return-to-menu flow. | Narrative must integrate pause/input and avoid autosave mid-sequence. |
| Tests + repo verifier | `SceneTree` harness patterns, headless suites, integrity checks. | Narrative tests must follow tab indentation, `_check`, no raw `assert`, no `root.add_child`. |

### 6.2 Systems needing content integration

- **SequenceRunner / DialoguePanel:** author validated sequence data and connect it through a narrow scene/session entry point. Do not move narrative ownership into `ForgottenShoreSession`.
- **NPC conversations:** if the approved beat sheet requires NPC dialogue, add a narrow talk interaction path to `InteractionResolver` and dispatch it to the narrative presenter. Preserve existing recruit/research interaction priorities.
- **Gameplay beat triggers:** bind only to existing authoritative milestones/signals (first-night outcome, Scientist discovery/recruitment, research completion, ship readiness) and make triggers idempotent and load-silent.
- **Camera/fade/world-pause support:** add an operation only when an approved beat requires it; these are not part of the current runner contract.
- **Persistence:** keep `NarrativeState` in-memory unless a resumable/cross-session story requirement is approved. SaveManager schema v2 is unchanged.

### 6.3 Missing content and optional systems

- Prologue scenes, art/audio, and New Game routing (N4).
- Chapter I canon dialogue and beat triggers remain unimplemented; core progression decisions are approved (mandatory recoverable first night, optional Scientist with specialist gates, chapter end on Eldergrove arrival). Chapter-end presentation and voyage/arrival content remain future work after N4 handoff.
- A chapter/quest framework is absent, but should not be built by default. First prove that a small number of authored sequences and existing progression facts can deliver the approved beats.
- Portraits, choices, voice, localization, and a full journal are optional future scope, not current requirements.

### 6.4 Architectural conflicts / risks

1. **Session coupling.** `ForgottenShoreSession.gd` remains the central orchestrator (input wiring `:151`, command dispatch, simulation `:130`, save/load `:1099/:1181/:1252`), with presentation already extracted into `ShoreView`/`ShoreFX`. Narrative triggers should NOT be added directly into `_process`/command handlers; keep a separate narrative domain/presenter and a narrow handoff contract (roadmap §7).
2. **Feedback channel contention.** Every gameplay event writes to `ClockHUD.FeedbackLabel` (`ClockHUD.gd:11,125`). Dialogue must not reuse that label; gameplay feedback will overwrite it immediately.
3. **Save timing.** Autosave occurs at sunrise (`_on_sunrise_reached`, `ForgottenShoreSession.gd:935`) and manual save is disabled during active night; dialogue/cutscenes need explicit save semantics (save only at safe boundaries, never mid-line; restore narrative state silently).
4. **Load/Continue behavior.** `_consume_pending_load_if_requested` loads silently (`:1252`); the Prologue/opening must not replay on Continue. The recommended entry-flow policy (Start New Game → Prologue; Continue → direct load) is still approval-required (roadmap §6).
5. **Time/night signals during sequences.** Phase signals are transition-time events (§3.1). Narrative sequences can still overlap a sunset/night transition or an enemy spawn, so the sequence runner needs an explicit input/time policy (pause simulation? lock movement? defer triggers?) and duplicate-listener guards.
6. **Strict save schema.** New top-level keys require `validate_payload` updates, migration decisions, and tests. Adding many fact IDs to `KNOWN_FACT_IDS` is code-owned and can bloat the registry; a narrative-state object may be cleaner, but then schema/version migration must be designed (N1 decision).
7. **Repo verifier/CI.** The verifier checks scene `load_steps`, tab indentation, test conventions, CI lock strings, and documentation consistency; new narrative scenes/scripts/docs must keep it green. Headless CI must not require a desktop.
8. **Data descriptions are not UI.** Specialist/structure/technology/era `description` fields are validated but never displayed; authors may assume they are live text. Do not treat them as implemented dialogue.
9. **Multiplayer seam.** REVISED baseline keeps host-authoritative simulation for future multiplayer; narrative triggers/state should eventually be host-authoritative and must not trust client narrative state.
10. **Early-content risk.** The Prologue design resolves the crown/vision direction, but N0 approvals (symbol design, entry-flow policy, skip behavior, staging details) and the OPEN list still gate content implementation. Chapter I content stays blocked until the N5 beat sheet exists.

### 6.5 Readiness conclusion

- **Implemented:** N1–N3 narrative runtime foundation merged on `main` by PR #11: `NarrativeState`, `NarrativeData` validation, `DialoguePanel`, `PlayerControlLock`, and `SequenceRunner`. Automated narrative suites and the merge-commit CI check passed.
- **Not implemented:** playable Prologue scenes/content, NPC conversation integration, Chapter I canon dialogue/beats, chapter progression, and narrative save fields.
- **Planning state:** Chapter I beat sheet exists as a non-canon draft proposal. Owner approval is required before proposed story details become canon or code tasks.
- **Recommended sequence:** resolve N0/entry-flow approvals, prepare and implement N4 Prologue in a separate PR, then implement only the approved Chapter I beats in small N5 PRs.

---

## 7. Evidence appendix (primary references)

**Scenes**
- `scenes/main/Main.tscn` — title/subtitle/buttons (no intro; no narrative nodes).
- `scenes/world/ForgottenShore.tscn` — gameplay scene; Player at default position, Town Center anchor, wall/watchtower/farm plots, resource nodes, ToolStands, Shipwreck, Greed Portal, enemy actors, `ClockHUD` labels (“Explore Forgotten Shore”, forecast, population).
- `scenes/player/Player.tscn` — `player_monarch_sheet.png`; no identity/dialogue components.

**Runtime**
- `scripts/core/Main.gd:18-27` — Start/Continue both route directly to Forgotten Shore; no narrative state.
- `scripts/world/ForgottenShoreSession.gd:84,99` — `_ready` setup and controls-only first feedback.
- `scripts/world/ForgottenShoreSession.gd:86-87,148` — `ShoreFX`/`ShoreView` wiring and `view.advance_and_sync`.
- `scripts/world/ForgottenShoreSession.gd:7-11,619-655` — `ReignState`, shipwreck stages, `ISLAND_CLEARED`, victory banner.
- `scripts/world/ForgottenShoreSession.gd:656-675,997-1001` — Greed Portal relic loot + label.
- `scripts/world/ForgottenShoreSession.gd:676-707,714-779` — structure activation, specialist discovery/recruit, research start.
- `scripts/world/ForgottenShoreSession.gd:920-966` — phase/sunrise/night feedback and outcomes.
- `scripts/world/ForgottenShoreSession.gd:1099,1181,1252` — `build_save_payload`, `_apply_loaded_payload`, `_consume_pending_load_if_requested`.
- `scripts/world/ShoreView.gd:1,479` — world presentation helper, `advance_and_sync`.
- `scripts/world/ShoreFX.gd:1` — transient feedback helper.
- `scripts/world/TimeManager.gd:4-7,99,130,137` — phase signals, silent restore path, initial-phase emit, phase-transition emit.
- `scripts/player/InteractionResolver.gd:32-260` — prompt/target model (resources, shrine offering `:50-61`, camp, shipwreck, portal, specialists `:146-198`, research `:195`, structures `:216-222`, trees `:224-239`, hearth).
- `scripts/npc/NPCBuilderAgent.gd:21-49,80-100` — NPC identity/roles/recruitment; no dialogue.
- `scripts/survival/NightEncounterManager.gd:25-29,107-133` — enemy names/forecast.
- `scripts/ui/ClockHUD.gd:11,61-88,125` — feedback label, victory banner, feedback handler.
- `scripts/save/SaveManager.gd:8-24,286-450` — schema/validation.
- `scripts/progression/ProgressionState.gd:25-95,151-205` — facts.
- `scripts/world/EraProgressionManager.gd` — era state/names.

**Data**
- `data/specialists.json:6-50` — Scientist + future-island descriptions.
- `data/structures.json:3-46` — Shrine of Growth / Statue of the First Sailor / Temple of the Dawn descriptions.
- `data/technologies.json:5-25` — research descriptions.
- `data/eras.json:5-20` — era descriptions.
- `data/resource_nodes.json:3-46` — resource labels including “Forgotten Shrine”.
- `data/enemies.json:3-17` — enemy archetype names.
- `data/resources.json` — only gold/wood/stone.

**Documentation**
- `docs/CHAPTER_01_BEAT_SHEET.md` — draft, non-canon Chapter I proposal; owner approval pending.
- `docs/narrative/PROLOGUE_STORY_DESIGN.md:24-38` (agreed direction), `:49-162` (beats 01–09), `:218-231` (Prologue/Chapter I boundary), `:233-246` (acceptance), `:248-265` (open decisions).
- `docs/NARRATIVE_IMPLEMENTATION_ROADMAP.md` — official N0–N5 phases, §4 out-of-scope lore, §6 entry-flow policy, §7 ownership, §8 quality gates.
- `docs/GDD.md:66,112` — updated narrative scope (Prologue planned, not shipped).
- `docs/PRD.md:296-325,400-449,500-521` — narrative exclusions, tutorial, HUD, out-of-scope.
- `docs/REVISED_PROJECT_BASELINE.md:23,101,250-301,440-451` — scope and future “Quest Progress”.
- `docs/DECISIONS_M2_M8.md:17-25` — approved P0 decisions (including stale values noted in §5.4).
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
