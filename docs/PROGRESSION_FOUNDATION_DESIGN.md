# Crownfall — Progression Foundation Design

**Status:** Phase 1 foundation implemented (fact service, unlock definition loader, deterministic evaluator, Stone Age milestone integration, save compatibility; merged via PR #3). Phase 2 era progression correction implemented and merged via PR #4 (Shipwreck Stage 3 = voyage readiness only; Iron Age gated behind the Eldergrove milestone; conservative legacy `iron_age` save migration; see section 12). Phase 3 specialist domain foundation and Phase 4 research system foundation are implemented on `feat/specialist-research-phase-3-4` (see sections 13-14). Phase 5 shrine/statue/temple, resource-access, and buff foundation is implemented on `feat/shrine-resource-buff-phase-5` (see section 15). Sections 4-10 remain the standing design reference; sections 11-15 record what actually shipped and what stays deferred. Later phases (multi-island progression, mounts) are still design-only.
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
  Phase 2.2 hardening: `migrate_payload` gates the whole progression migration
  section (era inference, Iron Age correction, vessel/Stone Age backfills,
  canonicalization) on an explicit `Dictionary.has("progression_facts")`
  presence check — a plain `get()` cannot tell an absent field from a stored
  null — so exactly three cases exist:
  1. Missing `progression_facts` (a legacy save without the key): the valid
     legacy migration path — era inference, conservative Iron Age correction,
     and the deterministic backfills run exactly as before.
  2. Present and a valid fact array: normal migration — Eldergrove evidence
     retains Iron Age, backfills are idempotent, and the array is
     canonically sorted.
  3. Present but malformed (`null`, string, number, dictionary, unknown IDs,
     duplicates): the whole progression migration is skipped. `era_id` is
     neither inferred nor corrected, no vessel or Stone Age fact is backfilled,
     and the malformed value is left untouched (never canonicalized, replaced,
     or deleted); `validate_payload` rejects the payload wholesale. Migration
     never partially mutates progression-related fields before rejection, the
     caller's input dictionary is never modified, and no live gameplay state
     changes.
  An invalid fact array containing `eldergrove_reached` therefore does NOT
  count as evidence and, since Phase 2.2, no longer triggers the era downgrade
  either: the payload is simply rejected untouched (Phase 2 rejected it after
  the downgrade mutation; Phase 2.2 rejects it without any mutation).

Acceptance evidence: `tests/test_progression_phase2_era_correction.gd` (162
checks across 8 suites) covers fresh-start era, the wall/shipwreck command paths
with exact balance regression, the fail-closed Iron Age gate, the intended
Eldergrove unlock path end-to-end (including an `iron_age` save round-trip),
all legacy migration branches with determinism/idempotency proof, malformed-data
rejection (including the absent-field vs explicitly-present-null distinction),
and data-contract regression guards. The Phase 2.2 suite additionally proves
the three-case gate: explicit null, malformed strings/dictionaries, and unknown
or duplicate fact IDs skip the whole progression migration (era and facts
untouched, no backfills) and are rejected wholesale with the caller's input
dictionary unchanged, while absent-field legacy migration and valid-array
migration with deterministic sorting keep their existing idempotent behavior.
Phase 1's `test_progression_foundation.gd` (139 checks) stays green, and the
full headless suite (`tests/run_all.sh`) passes.

## 13. Phase 3 implementation notes (specialist domain foundation, shipped behavior)

Phase 3 implements the smallest reliable specialist domain on the Forgotten
Shore vertical slice, on `feat/specialist-research-phase-3-4`:

- **Definitions (`scripts/specialists/SpecialistCatalog.gd`, `data/specialists.json`).**
  Data-driven roster of the four established specialists (`scientist`,
  `blacksmith`, `architect`, `scholar`) with stable unique IDs, role whitelist
  (`research`/`crafting`/`construction`/`knowledge`), island whitelist
  (`forgotten_shore`/`eldergrove_forest`/`ancient_kingdom`), fact bindings pinned
  to the registered `<id>_discovered` / `<id>_recruited` pattern, validated
  positive `EconomyLedger` costs, and optional housing-plot/world-position/
  requirement-fact fields. Loading is all-or-nothing (any error leaves the
  catalog empty; nothing can become discoverable from malformed data). The three
  future-island specialists intentionally omit `world_x`/`housing_plot_id`, so
  their discovery and recruitment fail closed until their islands exist.
- **Lifecycle (`scripts/specialists/SpecialistDomain.gd`).** The four states
  `undiscovered -> discovered -> recruitable -> recruited` are logically
  distinguishable and DERIVED, never stored: discovery and recruitment are
  durable `ProgressionState` facts, housing is live `BuildingManager` state, and
  `get_lifecycle_state()` evaluates the definition against them. The domain
  keeps no save fields of its own.
- **Discovery and recruitment are separate transactions.** Discovery records
  the discovery fact after a real world interaction at the specialist's
  position (idempotent repeat: success without a second signal). Recruitment
  runs validate -> atomic `EconomyLedger` spend -> record recruitment fact ->
  signal, and is rejected for unknown IDs, undiscovered specialists, unsatisfied
  requirement facts, missing housing, insufficient funds, and duplicate
  recruitment; failed recruitment never deducts resources or mutates facts.
- **Housing.** Minimal, well-defined, and integrated with the existing
  data-driven building system: the Scientist's housing is the new
  `hut_scientist_01` plot (`specialist_hut` type in `data/buildings.json`); the
  requirement is satisfied only when that plot exists and is COMPLETED in the
  authoritative `BuildingManager` (a destroyed hut stops satisfying it). No
  residential simulation, population, or happiness mechanics were added.
- **Scientist playable path (Forgotten Shore only).** The shipwrecked Scientist
  stands at `x=-1010` (data-defined): `[E]` discovers them, `[B]` builds their
  hut at `x=-980`, `[E]` recruits them for the data-defined `3G 2W`. All of it
  flows through the existing interaction resolver, world-command and building
  transaction paths; specialist progress never enters the villager population
  roster or cap.
- **Facts.** All eight specialist fact IDs are registered in
  `ProgressionState.KNOWN_FACT_IDS` (same rationale as `eldergrove_reached`:
  stable references for definitions and future saves). Only the Scientist has a
  gameplay recording path; registering an ID never records the fact, and no
  fact exists without real gameplay evidence.
- **Save compatibility.** Schema stays version 2 with NO new specialist fields:
  discovery/recruitment persist through the existing strictly-validated
  `progression_facts` array and housing persists through the buildings array
  (`hut_scientist_01` added to the strict save plot whitelist). Legacy v2 saves
  without specialist data load untouched (scientist undiscovered, hut a fresh
  placeholder); malformed fact arrays are rejected exactly as before.

Acceptance evidence: `tests/test_specialist_domain.gd` (108 checks across 5
suites) covers definition validation and fail-safe loading, the four lifecycle
states, discovery idempotency and rejection reasons, housing/recruitment
atomicity (insufficient funds, destroyed housing, duplicate recruitment), the
real session command and resolver paths, villager-population separation, and
save round-trip/legacy/malformed compatibility.

## 14. Phase 4 implementation notes (research system foundation, shipped behavior)

Phase 4 makes the recruited Scientist provide a real gameplay function, on the
same branch:

- **Definitions (`scripts/research/TechnologyCatalog.gd`, `data/technologies.json`).**
  Validated data-driven technology catalog: strict field sets, stable unique
  IDs, non-empty positive `EconomyLedger` costs, positive finite durations, a
  completion-effect registry that rejects unimplemented effect IDs (no fake
  technologies), requirement fact groups evaluated with the existing
  progression evaluator semantics, and prerequisite references resolved inside
  the set with depth-first cycle detection. All-or-nothing loading. Exactly two
  technologies ship: `inscription_studies` (requires `scientist_recruited`;
  effect `shrine_offering_gold_bonus: +3`) and `improved_flares` (requires
  `scientist_recruited` + `forgotten_shore_first_stone_wall_tier_2` as the
  era/Stone-Age gate, prerequisite `inscription_studies`; effect
  `flare_duration_bonus_sec: +4`). No Iron Age technology exists on Forgotten
  Shore.
- **Runtime (`scripts/research/ResearchManager.gd`).** One active project at a
  time; the four states unavailable/available/in_progress/completed are
  deterministic queries. `try_start` runs validate -> atomic spend -> set
  active project -> signal; failures never deduct resources. Progress advances
  only through `advance_research(delta)` fed with the session's scaled
  world-simulation delta (the same authoritative time every other system uses;
  no UI timers, frame counters, or offline progression). Completion happens
  exactly once (the active project is cleared synchronously) and completion
  rewards are DERIVED from the completed set (`get_effect_total`), so neither
  repeated advances nor repeated loads can re-apply them.
- **Effects consumed.** The session's shrine offering yields `2 + bonus` gold
  and the Kindle Flare lasts `8 + bonus` seconds, both read from
  `get_effect_total` (data-driven; fresh-session behavior unchanged with bonus
  0). The HUD gains a research status line (`ClockHUD.set_research_text`) and
  the recruited Scientist offers `[E] Research <tech> (<cost>)` at their camp.
- **Save compatibility.** The research state persists as the optional
  top-level `research` key (`{"completed_techs": [...sorted], "active_research":
  {"technology_id", "elapsed_sec"} | null}`); schema stays version 2 and
  `migrate_payload` is untouched (absent key = empty research state, so old
  saves load with nothing to backfill). Strict validation rejects malformed
  structures, unknown/duplicate technology IDs (against a file-derived
  fail-closed static registry), negative elapsed time, and active-vs-completed
  collisions; an explicit `"research": null` is malformed and rejected, like
  the progression-facts policy. Loading an active project restores its exact
  elapsed time and never re-deducts the cost; loading completed technologies
  never re-applies rewards; failed loads never partially mutate live state.
  (Phase 4.1 corrected the enforcement of the absent-key case: the session
  apply path now resets research to the empty state via the transactional
  `ResearchManager.reset_to_empty_state()` when the key is absent, instead of
  silently keeping the live session's research; all other load semantics are
  unchanged.)
- **Ownership boundaries.** Definitions live in the catalog, durable research
  state in `ResearchManager`, requirement facts stay in `ProgressionState`,
  costs flow through `EconomyLedger`, and UI only renders. Completed research
  is deliberately NOT duplicated into progression facts (one source of truth);
  a future unlock definition that needs to require a technology can add that
  bridge explicitly in a later phase.

Acceptance evidence: `tests/test_research_foundation.gd` (188 checks across 7
suites) covers definition validation including prerequisite cycles, the
availability truth table, transactional starts (insufficient resources,
unknown technology, duplicate project), authoritative timing with exactly-once
completion, save round-trips (active project resumes without re-deduction,
completed effects never re-applied, legacy saves, explicit-null and unknown-ID
rejection with no partial mutation), the Phase 4.1 legacy-save reset
regression (missing key = empty research state after completed or active
research; modern saves still restore exactly; explicit null rejected; session
rollback preserves the previous research state), session effect integration
through the real command paths, and era-safety regression (no Iron Age, no
fabricated Eldergrove fact, fail-closed era gate).
## 15. Phase 5 implementation notes (structures, resource access, buffs, shipped behavior)

Phase 5 implements the smallest reliable Shrine / Statue / Temple domain, the
explicit resource-access foundation, and a deliberately scoped buff system on
the Forgotten Shore vertical slice, on `feat/shrine-resource-buff-phase-5`:

- **Structure definitions (`scripts/structures/StructureCatalog.gd`,
  `data/structures.json`).** Validated data-driven definitions for the three
  distinguishable categories (`shrine`/`statue`/`temple`): stable unique IDs,
  island whitelist shared with the specialist catalog, activation facts pinned
  to the registered `<id>_activated` pattern, positive EconomyLedger costs,
  optional world position (bounded by `WorldConstants`) and optional
  requirement groups evaluated with the shared all_of/any_of validator. Empty
  requirement groups are rejected (a structure with no requirements would
  unlock unconditionally). All-or-nothing loading: any error leaves the
  catalog empty, so malformed data can never grant a partial or ghost
  structure. Three structures ship: the playable `shrine_of_growth`
  (Forgotten Shore, `x=820`), plus `statue_of_the_first_sailor` and
  `temple_of_the_dawn` which deliberately omit `world_x` and therefore fail
  closed until a future phase places them in a world (same rationale as the
  future-island specialist roster); their derived lifecycle reports
  `not_present`, never `available`.
- **Runtime (`scripts/structures/StructureDomain.gd`).** The lifecycle states
  `activated > not_present > available > locked` are DERIVED queries over the
  definitions plus durable ProgressionState facts, never stored. `not_present`
  covers structures that are not a placeable part of the active world (they
  belong to another island or have no `world_x` yet): requirement eligibility
  is irrelevant until a structure exists in this world, so the lifecycle never
  describes an unplaced or inactive-island structure as ready for player
  activation (it mirrors `try_activate`'s island/world-presence rejections;
  both world resolvers pre-filter by island and world position, so resolver
  behavior is unchanged). `try_activate` runs validate -> duplicate guard
  (before any spend) -> island and world presence -> finite actor position ->
  proximity -> requirement facts -> atomic `EconomyLedger` spend -> record the
  activation fact -> signal. Non-finite actor coordinates (NaN/±inf) are
  rejected before any proximity math — every comparison against NaN is false,
  so without the guard they would bypass the range check entirely — and a
  rejected non-finite position mutates no balance and records no fact. A
  failure at any step leaves balances, facts and lifecycle untouched; a
  repeated activation is rejected before the spend, so it can never deduct
  resources twice; the defensive refund after a failed fact recording keeps
  even the unreachable failure path free of partial activations. The domain
  keeps no save fields of its own.
- **Resource access (`scripts/resources/ResourceCatalog.gd`,
  `scripts/resources/ResourceAccessState.gd`, `data/resources.json`).** The
  mandatory distinction between resource ACCESS and resource QUANTITY:
  definitions carry exactly one access source — explicit `base_accessible:
  true` (shipped for gold/wood/stone so the entire existing Forgotten Shore
  loop is preserved) or `unlock_requires` fact groups (multiple unlock
  sources expressible with `any_of`; future sources such as shrine
  activation, milestones, island events, or research are all expressible as
  registered facts, so the foundation supports them without new machinery).
  Access evaluation is deterministic and fail-closed (unknown resource IDs are
  never accessible) and NEVER consults the ledger: a zero-balance resource can
  be accessible and a nonzero balance can never unlock anything. Enforcement
  lives at player-initiated acquisition (the session `collect` path, before
  any ledger mutation) and is a behavioral no-op for the base resources.
  No save fields: access is re-derived from the restored fact set after every
  load, so old saves never fabricate access.
- **Buffs (`scripts/buffs/BuffCatalog.gd`, `scripts/buffs/BuffDomain.gd`,
  `data/buffs.json`).** Validated buff definitions with stable IDs, an effect
  type registry that only contains types with real gameplay consumers
  (unimplemented effect types are rejected — no placeholder effects), positive
  exact magnitudes, an additive stacking whitelist (unique and multiplicative
  modes have no Phase 5 consumer and are rejected fail-closed), permanent-only
  durations (timed definitions are rejected until an authoritative timed
  consumer exists), and a validated `source_structure` reference into the
  structure catalog (single directional link, so catalog validation never
  needs a cycle). The authoritative calculation path is
  `BuffDomain.get_effect_total(effect_type, activated_structure_ids)`:
  additive totals are DERIVED per query from activation evidence, with
  duplicate structure IDs collapsed, so re-activation or repeated loads can
  never duplicate or accumulate an effect. Nothing is stored, pushed, or
  re-applied.
- **Facts.** Three activation facts are registered in
  `ProgressionState.KNOWN_FACT_IDS` (`shrine_of_growth_activated`,
  `statue_of_the_first_sailor_activated`, `temple_of_the_dawn_activated`).
  Only the Shrine has a gameplay recording path; registering an ID never
  records the fact.
- **First playable structure.** The Shrine of Growth exists in the world
  (`x=820`, generated 2-frame dormant/awakened landmark sprite), is
  discovered/interacted with through the existing interaction resolver (kind
  `structure`, command `activate_structure`), requires the Stone Wall Tier 2
  milestone plus 4G 2W 3S, and its `grove_timber_blessing` grants +1 Wood to
  every island wood acquisition (player node collection, tree felling, and
  idle-villager auto-chop deliveries). When the ledger rejects the blessing
  top-up (resource cap), the feedback falls back to the base amounts, so UI
  never claims wood the economy did not grant. The HUD gains a passive
  structures/blessings line (`ClockHUD.set_structures_text`) fed from
  `StructureDomain.get_hud_text` (presentation only).
- **Save compatibility.** Schema stays version 2 with ZERO new save keys:
  activation persists through the strictly validated
  `progression_flags.progression_facts` array. Legacy schema-v2 saves without
  the activation fact load with the structure locked and no effects (nothing
  fabricated); loading any save REPLACES the fact set, so stale runtime
  activations/effects disappear and derived blessings are recalculated from
  the restored facts; unknown or duplicate fact IDs are rejected wholesale
  exactly as before; a failed restore rolls the whole session back through
  the existing snapshot mechanism (fact restore participates in the
  transactional apply path); no activation cost is ever deducted during
  restoration (costs are not stored). Loading a legacy save into a session
  that already has non-empty Phase 5 state is explicitly tested (replace, not
  merge).

Acceptance evidence: `tests/test_structure_buff_phase5.gd` (209 checks across
8 suites) covers definition validation and fail-safe loading for all three
catalogs, the derived lifecycle (including `not_present` for unplaced and
inactive-island structures), activation transactions (success, unknown IDs,
non-finite actor positions, out-of-range, insufficient funds, future-island
and unplaced structures failing closed, duplicate activation without double
spending), buff
aggregation (additive totals, collapsed duplicates, unknown effect types,
idempotent facts never accumulating), resource access (zero balance while
unlocked, nonzero balance while locked, unknown IDs, multiple `any_of` unlock
sources, legacy saves), the real session command/resolver/blessing paths
(exact balance math for activation, node collection, tree felling, villager
auto-chop, and the cap-exceeded fallback), save round-trips, legacy saves
loaded into Phase-5-active sessions, transactional rollback with a failing
later subsystem, malformed-fact rejection, and regression guards for
specialists, research, shrine offerings, wall construction, economy and era
safety. The full headless suite (`tests/run_all.sh`) passes.

Deliberately deferred (documented, not silently missing): timed buff runtime
(no Phase 5 consumer; definitions fail closed), resource-unlock-by-structure
gameplay (the access foundation supports it via fact-based definitions; no
live locked resource ships yet to avoid breaking the vertical slice),
Statue/Temple world placement, and future-island structures.
