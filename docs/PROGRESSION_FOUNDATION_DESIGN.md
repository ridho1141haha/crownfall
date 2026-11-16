# Crownfall — Progression Foundation Design

**Status:** Proposed implementation design; not yet implemented.
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
- `EraProgressionManager` currently supports Wood, Stone, and Iron Age. Stone Age unlocks through the first Stone Wall Tier 2; Iron Age currently unlocks through Shipwreck Stage 3.
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

**Important design correction:** the desired final design removes the Iron Age unlock from Forgotten Shore / Shipwreck Stage 3 and moves it to an Eldergrove Forest milestone. This correction is a separate gameplay decision and should not be hidden inside the generic foundation refactor. Before the first content-facing implementation, update the era definition, migration/inference rules, UI copy, and tests together. Reaching Shipwreck Stage 3 should unlock the voyage/next-island transition, not Iron Age.

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
