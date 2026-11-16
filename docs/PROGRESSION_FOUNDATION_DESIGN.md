# Crownfall — Progression Foundation Design

**Status:** Phase 1 foundation implemented (fact service, unlock definition loader, deterministic evaluator, Stone Age milestone integration, save compatibility; merged via PR #3). Phase 2 era progression correction is implemented on `feat/progression-phase-2-era-correction` (Shipwreck Stage 3 = voyage readiness only; Iron Age gated behind the Eldergrove milestone; conservative legacy `iron_age` save migration; see section 12). Sections 4-10 remain the standing design reference; sections 11-12 record what actually shipped and what stays deferred. Later phases (specialists, research, resource access, islands, mounts) are still design-only.
**Scope:** Foundational progression architecture for the existing single-player Forgotten Shore build.
**Authority:** This document supplements `REVISED_PROJECT_BASELINE.md`; it does not silently replace approved vertical-slice requirements.

## 1. Purpose

Prepare a small, extensible foundation for gradual feature unlocking across future islands and eras. The foundation must support later specialist recruitment, research, resource discovery, structures, buffs, and mounts without implementing all of those systems now.

The first implementation target is the progression foundation only. It must preserve the current playable Forgotten Shore loop.

## 2. Core design rules

1. **Progression is gradual.** New systems, resources, specialists, upgrades, and mounts are not all available at the start.
2. **Unlocks have explicit requirements.** Requirements are stable IDs and validated data, not arbitrary script expressions.
3. **Gameplay state is authoritative.** UI displays unlock state; it never grants unlocks.
4. **One source of truth.** Store durable player accomplishments/milestones. Derive availability from those facts and definitions wherever practical; do not maintain multiple conflicting copies of the same state.
5. **Event-driven evaluation.** Re-evaluate relevant unlocks after committed gameplay events (construction completed, NPC recruited, research completed, shrine activated, island reached), not every frame.
6. **Backward-compatible saves.** Existing schema v2 saves must load without losing current progress.
7. **No premature abstraction.** Do not create empty managers, generic plugin frameworks, or every future content definition before a real consumer exists.
8. **No forced grinding.** Unlock requirements should be meaningful gameplay goals, not arbitrary repetition.

## 3. Current repository baseline and constraints

The current project is a single-player vertical slice on Forgotten Shore.

- `EconomyLedger` currently permits only `gold`, `wood`, and `stone`.
- `EraProgressionManager` supports Wood, Stone, and Iron Age. Stone Age unlocks through the first Stone Wall Tier 2. Since Phase 2, Shipwreck Stage 3 no longer unlocks Iron Age — it only records voyage readiness; Iron Age requires the Eldergrove Forest milestone and is unreachable while playing on Forgotten Shore.
- `SaveManager` currently writes schema version 2 and stores `progression_flags.era_id`.
- `NPCPopulationManager` currently models villagers and combat/work roles; it is not yet a specialist recruitment system.
- `ForgottenShoreSession` coordinates several systems and should not become the home for new progression rules.
- Multi-island simulation, specialist recruitment, research, generic statue/temple buffs, and mounts are not implemented.

The approved design direction is:
- Island 1 — Forgotten Shore: Wood Age to Stone Age; no Iron Age unlock here.
- Island 2 — Eldergrove Forest: Stone Age continues; Iron Age becomes available through a meaningful milestone on this island.
- Island 3 — Ancient Kingdom: develop Iron Age and discover advanced knowledge.
- Specialist distribution is staged: Scientist on Island 1, Blacksmith and Architect on Island 2, Scholar on Island 3.
- Shrines/statues/temples can unlock resource access and provide buffs.
- Mounts and other advanced features are discovered later, not given at the start.

These are long-term design targets, not claims about current playable content.

## 4. Progression model

Use three distinct concepts:

### 4.1 Definitions

Static data describing what can be unlocked and its requirements. Definitions are not copied wholesale into saves.

A future definition may contain:
- stable `id`
- category (era, resource, specialist, building, technology, feature, mount, buff)
- display name / description localization key
- requirement groups
- optional island/era availability boundary
- optional reward/unlock targets

Do not add unused fields until a real feature needs them.

### 4.2 Progression facts

Durable accomplishments made by the player, such as:
- `forgotten_shore_first_stone_wall_tier_2`
- `scientist_recruited`
- `eldergrove_reached`
- `iron_forge_research_completed`

Facts are recorded only after the corresponding gameplay transaction succeeds. They are stable IDs and should be validated against known definitions or a known fact registry.

For the first foundation milestone, preserve the existing Stone Wall Tier 2 progression behavior and represent its accomplishment through a stable milestone/fact without changing gameplay balance.

### 4.3 Availability

Availability is the result of evaluating definitions against progression facts and current authoritative state.

Suggested requirement operators:
- `all_of`: every listed prerequisite must be satisfied.
- `any_of`: at least one listed prerequisite must be satisfied.

Start with these simple operators. Avoid a general-purpose boolean expression language, arbitrary GDScript calls from JSON, or deeply nested condition trees.

Availability states should distinguish at least:
- locked (requirements not met)
- available (requirements met)
- unlocked/owned (the player has permanently acquired or activated it, where the feature requires a separate acquisition step)

Do not collapse “available to discover” and “already acquired” into one boolean when gameplay needs to distinguish them.

## 5. Ownership boundaries

| Responsibility | Owner |
|---|---|
| Static unlock definitions | Data files / validated definition loader |
| Durable milestone facts | Progression state/service |
| Requirement evaluation | Progression service |
| Era display/current era | Existing era progression owner, integrated without duplicating authority |
| Resource balances and transactions | EconomyLedger |
| Resource discovery/access | Progression + resource access policy, later phase |
| NPC roster and recruitment transactions | NPC domain system, later specialist extension |
| Research costs and completion | Research system, later phase |
| Building placement/construction | BuildingManager / building domain |
| Save/load validation and migration | SaveManager |
| HUD/prompts | Presentation only |

Avoid putting requirement logic in `ForgottenShoreSession`. The session may connect signals and issue commands, but it should not own the unlock rules.

## 6. Data and ID conventions

- Use stable lowercase snake_case IDs.
- Never use display names as persistent IDs.
- Unknown IDs in save data or definitions must be rejected or handled through an explicit migration; do not silently grant content.
- Data files must be parsed and validated before being used.
- Missing or malformed progression definitions must fail safely and must not grant unlocks.
- Keep content definitions separate from saved player state.

Candidate data layout (only create files when the foundation implementation requires them):
- `data/progression_facts.json`
- `data/unlocks.json`

Do not split into one JSON file per category until the catalog becomes large enough to justify it.

## 7. Save and migration policy

Current save schema is version 2. Any new durable progression fields require a deliberate schema migration.

Before implementation:
1. Inspect the exact current payload builder, validator, and apply path.
2. Define defaults for existing schema v1/v2 saves.
3. Add migration tests for fresh saves, existing saves, missing optional legacy fields, invalid IDs, and corrupted data.
4. Keep migration deterministic and idempotent.
5. Validate the complete migrated payload before mutating live game state.
6. Do not change schema version merely for a design document; bump it only in the implementation commit that adds the field.

Prefer persisting canonical facts and existing authoritative state, not a redundant cache of every derived availability flag. If an acquisition itself is not derivable (for example, a one-time statue activation), persist that acquisition explicitly.

## 8. First implementation boundary

The first coding milestone should:
- introduce a small progression state/service with stable fact IDs;
- validate definitions and prerequisite references;
- evaluate `all_of` and `any_of` requirements;
- integrate the current Stone Age milestone without changing the existing Stone Wall Tier 2 gameplay requirement;
- keep the current Iron Age trigger unchanged temporarily only if the branch is strictly an architecture foundation; immediately follow with the separately reviewed design correction before treating the milestone as progression-complete;
- add unit tests for validation, evaluation, duplicate facts, unknown IDs, and save round-tripping;
- preserve existing save compatibility and current vertical-slice behavior.

**Important design correction (implemented in Phase 2):** the Iron Age unlock was removed from Forgotten Shore / Shipwreck Stage 3 and moved to an Eldergrove Forest milestone. The correction shipped as one atomic change: era definition copy, unlock definitions, the fail-closed era gate, migration rules, session messages, and tests were updated together. Reaching Shipwreck Stage 3 now unlocks the voyage/next-island transition (fact `forgotten_shore_vessel_ready`), not Iron Age. See section 12 for the shipped behavior and the legacy save migration policy.

## 9. Explicitly out of scope for the foundation

- Implementing the Scientist, Blacksmith, Architect, or Scholar NPCs.
- Building specialist huts or recruitment quests.
- Research timers, research trees, or technology effects.
- Adding Iron as an active ledger resource.
- Implementing Shrine/Statue/Temple buff effects.
- Implementing multiple playable islands or inactive-island simulation.
- Implementing mounts, mount inventory, or mounted movement.
- Rebalancing enemy waves or adding new enemy archetypes.
- Replacing the current single-player session architecture wholesale.

## 10. Acceptance criteria

The foundation is ready when:
- existing vertical-slice tests remain green;
- progression definitions reject malformed data and duplicate IDs;
- unknown prerequisite references cannot become silently satisfied;
- requirement evaluation is deterministic and has no per-frame polling;
- milestone facts are only committed after successful gameplay actions;
- duplicate fact grants are idempotent;
- current Stone Age progression still works;
- existing v1/v2 save migration behavior is preserved;
- no specialist, research, mount, or multi-island feature appears prematurely in the playable build;
- docs accurately distinguish implemented behavior from future design.


## 11. Phase 1 implementation notes (shipped behavior, not future design)

Phase 1 implements the smallest testable foundation on the Forgotten Shore vertical slice:

- **Facts (`scripts/progression/ProgressionState.gd`).** Durable milestone facts
  with stable lowercase snake_case IDs. `KNOWN_FACT_IDS` is the code-level fact
  registry (Phase 1 ships exactly one fact: `forgotten_shore_first_stone_wall_tier_2`);
  a `data/progression_facts.json` file was deliberately NOT created because a
  registry of one fact does not justify a second data file. Recording is idempotent,
  rejects malformed and unknown IDs, emits `fact_recorded` only on the absent ->
  present transition, and never exposes the internal collection.
- **Definitions (`scripts/progression/ProgressionUnlockCatalog.gd`, `data/unlocks.json`).**
  Data-driven unlock definitions validated at load time: strict field set, stable
  IDs, unique definition IDs, `all_of` / `any_of` groups of known fact IDs, empty
  groups rejected, unknown requirement IDs rejected with a reported reason, and
  all-or-nothing loading (any error leaves the catalog empty so no unlock can be
  granted from malformed data). No script expressions, no eval.
- **Evaluation (`scripts/progression/ProgressionUnlockEvaluator.gd`).** Deterministic
  pure reads: every present group must pass; empty, missing, or unknown groups
  never unlock (fail-closed even for definitions that bypass the catalog);
  evaluation never mutates progression state. Only the locked -> available
  distinction exists in Phase 1; a separate "unlocked/owned" acquisition state is
  deferred until a real feature has an acquisition step.
- **Stone Age integration (`ForgottenShoreSession.gd`).** After a successful wall
  upgrade transaction, the session records the milestone fact; the fact is
  idempotent, so repeating the milestone (or upgrading the west wall later) never
  duplicates progression. Era advancement itself stays owned by
  `EraProgressionManager`; its behavior, save format, and player-facing messages
  are unchanged.
- **Save compatibility (`SaveManager.gd`).** Facts persist as the optional
  `progression_flags.progression_facts` array (sorted known fact ID strings).
  The schema stays version 2, matching how other optional `progression_flags`
  fields were introduced. Strict validation rejects unknown or malformed fact
  IDs in saves. Migration deterministically and idempotently backfills the
  stone-wall fact for saves whose `era_id` is `stone_age` (the era is only
  reachable through that milestone, so it proves the fact). Iron Age saves are
  never backfilled: the vessel-ready path can reach Iron Age without any stone
  wall, so no factual inference exists. Old saves without the field load with an
  empty fact set, and malformed fact arrays are rejected, never repaired
  mid-load.
- **Wiring boundary.** The session owns the fact service (milestone recording +
  save/restore). The catalog/evaluator are tested against the real data file but
  are not yet instantiated in gameplay, because no HUD or interaction consumer
  exists in Phase 1; the first availability UI will consume
  `ProgressionUnlockCatalog` + `ProgressionUnlockEvaluator` directly.

Acceptance evidence: `tests/test_progression_foundation.gd` (137 checks across 6
suites) covers fact recording/idempotency/ID validation, serialization round-trips
with transactional rejection, definition validation and fail-safe loading, the
`all_of`/`any_of` truth tables, the Stone Age milestone integration, and save
migration/round-trip behavior; the full headless suite
(`tests/run_all.sh`, static verifier + world clock + P0 unit + M8 integration +
experimental + progression) stays green.
## 12. Phase 2 implementation notes (era progression correction, shipped behavior)

Phase 2 aligns era unlocks with the island progression decision. Implemented
behavior on `feat/progression-phase-2-era-correction`:

- **Intended era progression.** Wood Age starts on Forgotten Shore. The first
  Stone Wall Tier 2 upgrade unlocks Stone Age (unchanged from Phase 1). Shipwreck
  Stage 3 records the voyage-readiness fact `forgotten_shore_vessel_ready` and
  does NOT unlock any era. Iron Age unlocks only through the Eldergrove Forest
  milestone fact `eldergrove_reached` — the defined Iron Age gate.
- **New facts (`ProgressionState.gd`).** The registry now ships exactly three
  facts: `forgotten_shore_first_stone_wall_tier_2`, `forgotten_shore_vessel_ready`
  (recorded by the session only after the successful Stage-3 repair transaction,
  idempotent), and `eldergrove_reached` (registered so the data-driven unlock
  definition can require it and future saves can carry it; no Forgotten Shore
  gameplay path records it, so Iron Age is unreachable on Forgotten Shore).
- **Fail-closed era gate (`EraProgressionManager.gd`).** `notify_vessel_ready()`
  was removed. `notify_eldergrove_milestone(progression)` advances to Iron Age
  only when the passed `ProgressionState` already contains `eldergrove_reached`;
  without the fact (or with a null state) it never advances. This is the
  documented integration boundary for the future Eldergrove Forest session: it
  will record the milestone fact first, then call this method. Stone Age
  advancement intentionally stays as Phase 1 shipped (`notify_stone_wall_built()`
  plus the deterministic save migration backfill).
- **Data definitions.** `data/unlocks.json` now ships three definitions:
  `stone_age_era` (all_of the stone-wall fact, unchanged),
  `forgotten_shore_voyage_ready` (all_of the vessel fact), and `iron_age_era`
  (all_of `eldergrove_reached`). `data/eras.json` iron_age description no longer
  claims the ship Stage 3 trigger. No gameplay consumer of the catalog exists
  yet (same boundary as Phase 1; the first availability UI will consume it).
- **Session behavior (`ForgottenShoreSession.gd`).** The Shipwreck Stage 3
  repair transaction still costs exactly 6G 8W 4S, still shows "Ship Stage 3/3",
  and the repeated interaction still takes the existing ISLAND_CLEARED / Set
  Sail path with the victory banner. The only changes: the Stage 3 message now
  announces voyage readiness (no Iron Age claim), and the vessel fact is
  recorded after the successful transaction. Wall upgrade gameplay, costs, and
  messages are untouched.
- **Save compatibility (`SaveManager.gd`).** Schema stays version 2; no new
  fields. `migrate_payload` gained a deterministic, idempotent, conservative
  legacy policy:
  1. A save whose `era_id` is `iron_age` but that carries a valid
     `progression_facts` array containing `eldergrove_reached` (new-format
     evidence, writable only by a build that truly recorded the milestone) keeps
     Iron Age and all facts untouched.
  2. Any other legacy `iron_age` save has Iron Age revoked: the era is
     recomputed from real evidence in the save (a `stone_wall` building ->
     `stone_age`, otherwise `wood_age`). Stone Age progress is preserved; the
     Phase 1 stone-fact backfill then applies to downgraded `stone_age` saves.
     An Eldergrove fact is never fabricated.
  3. `shipwreck_stage == 3` is genuine evidence of a completed vessel (the
     stage only advances through successful repair transactions), so the
     `forgotten_shore_vessel_ready` fact is backfilled from it for any era.
     Shipwreck/vessel progress is never lost.
  4. Backfilled fact arrays are canonicalized (sorted) to match the
     `to_save_array()` contract; invalid arrays are never repaired or sorted —
     they are rejected by `validate_payload`, never partially applied.
  Malformed progression data (unknown IDs, non-arrays, duplicates) keeps the
  Phase 1 behavior: the whole payload is rejected safely. An explicitly present
  `progression_facts: null` is malformed, not missing: it is never backfilled or
  repaired — only a genuinely absent field (a legacy save without the key)
  triggers the deterministic backfill, which the backfill helper distinguishes
  via an explicit `Dictionary.has()` presence check (a plain `get()` cannot tell
  an absent field from a stored null) — and the payload is rejected wholesale.
  An invalid fact array containing `eldergrove_reached` does NOT count as
  evidence; the era is still downgraded and the payload is rejected wholesale.

Acceptance evidence: `tests/test_progression_phase2_era_correction.gd` (133
checks across 7 suites) covers fresh-start era, the wall/shipwreck command paths
with exact balance regression, the fail-closed Iron Age gate, the intended
Eldergrove unlock path end-to-end (including an `iron_age` save round-trip),
all legacy migration branches with determinism/idempotency proof, malformed-data
rejection (including the absent-field vs explicitly-present-null distinction),
and data-contract regression guards. Phase 1's
`test_progression_foundation.gd` (139 checks) stays green with its legacy
iron-age migration assertions updated to the Phase 2 policy, and the full
headless suite (`tests/run_all.sh`) passes.
