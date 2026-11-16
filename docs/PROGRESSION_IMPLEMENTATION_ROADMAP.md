# Crownfall — Progression Foundation Implementation Roadmap

**Status:** Planning only. No gameplay code is implemented by this document.
**Scope:** Foundational architecture first; future content remains staged.

## Guiding approach

Design the long-term progression model now, but implement only the smallest reusable foundation that can be tested against the current Forgotten Shore vertical slice. Do not build all future features in one pass.

## Phase 0 — Repository and design alignment

**Deliverable:** approved design and implementation boundary.

- [ ] Confirm current Godot `main` baseline and existing open work.
- [ ] Keep `REVISED_PROJECT_BASELINE.md` as scope authority; update it only after an explicit scope decision.
- [ ] Align `GDD.md`, `SYSTEMS.md`, `TDD.md`, `PRD.md`, and `ROADMAP.md` without presenting planned features as implemented.
- [ ] Resolve the Iron Age trigger conflict: Shipwreck Stage 3 means voyage readiness; Iron Age unlock moves to an Eldergrove Forest milestone.
- [ ] Define stable IDs and initial milestone list.

**Exit criteria:** no contradictory description of era unlock behavior; no unapproved multi-island implementation scope.

## Phase 1 — Progression foundation

**Status:** Implemented on `feat/progression-foundation-phase-1` (fact service, definition
loader/validator, deterministic evaluator, Stone Age milestone integration, optional
`progression_flags.progression_facts` save field with schema v2 kept, deterministic
era-based fact backfill). See `PROGRESSION_FOUNDATION_DESIGN.md` section 11 for the
shipped boundary. Phases 2+ below remain planning only.

**Goal:** create a small, data-driven, testable unlock evaluator.

Implementation tasks:
1. Inspect current `EraProgressionManager`, save payload construction/application, and test conventions.
2. Define validated progression fact and unlock definition schemas.
3. Implement fact recording with idempotent behavior.
4. Implement `all_of` and `any_of` prerequisite evaluation.
5. Validate unique IDs, valid categories, and all prerequisite references.
6. Integrate current Stone Age milestone while preserving its gameplay trigger.
7. Keep presentation out of the progression service; expose query results for HUD/interaction layers.
8. Avoid frame polling; react to committed gameplay events or explicit reevaluation requests.

**Tests:**
- valid and malformed definition sets;
- duplicate IDs and unknown prerequisite IDs;
- all/any prerequisite truth tables;
- duplicate fact grant;
- unknown fact rejection;
- progression state serialization and restore;
- current Stone Wall Tier 2 -> Stone Age behavior;
- existing save v1/v2 migration and full regression suite.

**Exit criteria:** foundation is deterministic, tested, and does not change the existing vertical-slice loop.

## Phase 2 — Era progression correction

**Goal:** align era unlocks with the island progression decision.

- Wood Age starts on Forgotten Shore.
- Stone Age begins when the first Stone Wall Tier 2 milestone is completed.
- Shipwreck Stage 3 unlocks voyage readiness / travel to Eldergrove Forest, not Iron Age.
- Iron Age unlocks only after a defined Eldergrove Forest milestone.
- Existing saves with `iron_age` from the old trigger require an explicit compatibility policy; do not silently downgrade or silently preserve an unlock that violates the new progression design.
- Update era definitions, HUD messages, migration rules, docs, and tests atomically.

**Exit criteria:** no path unlocks Iron Age while still on Forgotten Shore; old saves have a documented and tested migration outcome.

## Phase 3 — Specialist domain foundation

**Goal:** extend recruitment without coupling specialists to ordinary villagers.

- Define specialist IDs and role metadata.
- Model discovery, recruitment, residence, and availability as separate states where needed.
- Start with Scientist only after the specialist domain design is approved.
- Later stages add Blacksmith and Architect on Eldergrove Forest, then Scholar on Ancient Kingdom.
- Do not make every specialist a subclass of the current Builder actor without evidence that behavior is shared.

**Exit criteria:** specialist state is testable, saved, and separate from the current villager population cap / Builder state unless an explicit design decision merges them.

## Phase 4 — Research and technology

- Add research definitions only when at least one real technology is scoped.
- Research requirements can depend on specialist recruitment, era, resource access, and prior research.
- Costs use EconomyLedger transactions; research completion must be atomic and idempotent.
- Time-based research must use the authoritative world clock, not UI timers.
- UI cannot mark research completed.

**Exit criteria:** one end-to-end research item is discoverable, affordable, completable, saveable, and unlocks a real gameplay feature.

## Phase 5 — Shrines, statues, temples, and resource access

- Separate resource discovery/access from resource quantity in the ledger.
- A resource being unavailable is not the same as an available resource with a balance of zero.
- Define each shrine/statue/temple by stable ID, activation requirements, costs, unlock effects, and buff effects.
- Buffs must define scope, magnitude, stacking policy, duration/permanence, and persistence.
- Avoid global multiplier stacks without explicit balance rules.

**Exit criteria:** one structure unlocks one previously unavailable resource or grants one clearly testable buff.

## Phase 6 — Multi-island world progression

- Introduce explicit island definitions and transition requirements.
- Preserve the single active island model initially; do not simulate inactive islands.
- Define what carries between islands: kingdom ledger, roster, research, buildings, discovered resources, and world state.
- Define travel and return rules before implementing maps.
- Build Eldergrove Forest as the first expansion only after the transition/save model is tested.

**Exit criteria:** travel, arrival, persistence, and return/re-entry behavior are deterministic.

## Phase 7 — Mounts and advanced unlocks

- Mounts are discovered in the world and are not granted at the start.
- Define discovery, taming/recruitment, ownership, active mount, and movement behavior separately.
- Mounts are late content; no mount implementation is required for the progression foundation.

## Non-goals for Phase 1

- Specialist NPCs or their huts.
- Research UI or research timers.
- New resource types in the live economy.
- Shrine/statue/temple buffs.
- New islands or travel.
- Mounts.
- Replacing the existing session manager architecture.
- Multiplayer implementation.

## Implementation workflow and quality gates

For each coding phase:
1. Work on a dedicated feature branch from the current verified `main`.
2. Inspect the actual code and tests before editing; do not assume this document's proposed architecture maps one-to-one to existing classes.
3. Make the smallest coherent change.
4. Add regression tests before claiming completion.
5. Run the full Godot headless test suite and relevant scene/integration tests.
6. Verify the project launches and the relevant gameplay flow manually.
7. Review save migration, old-save compatibility, and rollback behavior.
8. Update docs only to reflect tested implementation.
9. Open a PR; do not merge without review/approval.

## Risk register

| Risk | Mitigation |
|---|---|
| Overengineering a generic quest/unlock framework | Keep only stable facts and two prerequisite operators initially |
| Save incompatibility | Explicit schema migration and old-save fixtures |
| Conflicting era state | One authoritative era owner; milestone is the source fact |
| Unlocking Iron Age too early | Separate voyage readiness from era unlock |
| Specialist roles entangled with villagers | Separate specialist domain from population roles |
| Resource availability confused with balance | Track access separately from ledger quantity |
| Session script grows further | Keep rules in domain services; session only orchestrates |
| UI grants progression | UI only sends requests and renders committed results |
