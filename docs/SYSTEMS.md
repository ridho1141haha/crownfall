# CROWNFALL: THE LAST LIGHT
# GAME SYSTEMS SPECIFICATION

**Document Version:** 1.3
**Baseline:** Revised Project Baseline v1.3 & `docs/DECISIONS_M2_M8.md`
**Engine:** Godot 4
**Status:** M0–M8 Vertical Slice Prototype Implemented (`Godot 4.7.2.stable`)

---

## 1. Purpose and Priority Model

This document defines the responsibilities, behavior, state transitions, invariants, and test expectations of the gameplay systems in CROWNFALL.

The approved first playable target is a single-player vertical slice on Forgotten Shore. This document specifies the required system behavior and invariants; the P0 systems (`M0–M8`) are implemented in `scripts/` and verified by `tests/`, with `OD-01`..`OD-10` resolved in `docs/DECISIONS_M2_M8.md`.

| Priority | Meaning |
|---|---|
| P0 | Required for the single-player vertical slice, M0–M8 |
| P1 | Multiplayer prototype and selected content expansion, M9–M10, conditional on P0 validation |
| P2 | Long-term ideas and polish not committed to the current slice |

### 1.1 P0 System Set

- Player movement, collision, interaction requests, and local camera.
- Forgotten Shore environment and world boundaries.
- World clock with daylight, sunset, night, and sunrise phases.
- Kingdom ledger for Gold, Wood, and Stone.
- Town Center as the settlement anchor.
- Wooden Wall placement, construction, and the minimum damage/repair loop required for the first encounter.
- Villager recruitment and Builder behavior.
- One basic enemy archetype and one predictable route.
- Minimal HUD/feedback.
- Versioned local save/load with backup recovery.

No multiplayer runtime, full quest/dialogue framework, inactive-island simulation, or advanced production chain is required in P0.

---

## 2. System Dependency Overview

~~~text
LOCAL GAME SESSION
│
├── PLAYER SYSTEM [P0]
│   ├── Horizontal movement and collision
│   ├── Local Camera2D
│   └── Interaction requests
│
├── WORLD & TIME SYSTEM [P0]
│   ├── Forgotten Shore environment
│   ├── World boundaries
│   └── Day / Sunset / Night / Sunrise events
│
├── ECONOMY SYSTEM [P0]
│   └── Kingdom ledger: Gold, Wood, Stone
│
├── KINGDOM & BUILDING SYSTEM [P0]
│   ├── Town Center anchor
│   └── Wooden Wall placement and construction
│
├── NPC & BUILDER SYSTEM [P0]
│   ├── Villager recruitment
│   ├── Builder task selection and execution
│   └── Dusk safety override
│
├── SURVIVAL SYSTEM [P0]
│   ├── One enemy archetype
│   └── One predictable attack route
│
├── PRESENTATION / HUD [P0]
│   └── Reads confirmed state and presents feedback
│
└── SAVE & PERSISTENCE [P0]
    └── Versioned local save and backup recovery

MULTIPLAYER SYSTEM [P1 — M9+, NOT IMPLEMENTED IN P0]
└── ENet / host authority / replication
~~~

The dependency map is conceptual. It does not require each box to become a manager, singleton, or separate scene.

---

## 3. Player System [P0]

### Responsibilities

- Read local movement and interaction input.
- Move the Monarch horizontally.
- Respect floor collision and the playable island boundaries.
- Control a local Camera2D.
- Submit interaction requests to gameplay systems.

### Rules

- Player input is not the source of truth for economy, building, NPC, or enemy state.
- The camera is local presentation and is not serialized as authoritative world state.
- The initial movement model is intentionally simple; additional abilities and combat are deferred.

### Acceptance Checks

- The player moves left and right.
- The player cannot fall through the test floor.
- Movement respects world bounds.
- The local camera follows the player.
- Invalid interaction requests do not mutate gameplay state.

---

## 4. World and Time System [P0]

### Responsibilities

- Load and own the active Forgotten Shore world state.
- Define the playable bounds and required terrain collision.
- Advance the world clock.
- Emit phase-change events for gameplay and presentation systems.

### Provisional Time Tuning

| Phase | Duration | Intended Function |
|---|---:|---|
| Daylight | 8 minutes | Exploration, collection, recruitment, construction |
| Sunset | 1 minute | Warning and final preparation |
| Night | 3 minutes | First survival encounter |
| Full cycle | 12 minutes | Provisional target; tune through playtesting |

The timing values are configuration/balance data, not values that should be duplicated across unrelated scripts.

### Phase Contract

The clock should expose one clear phase state and emit each transition once per cycle. Suggested event names:

- daylight_started
- sunset_started
- night_started
- sunrise_reached

NPC safety, enemy spawning, lighting, and HUD react to the clock's events/state. They must not each maintain an independent world timer.

### Acceptance Checks

- Phase order is deterministic.
- Each transition is emitted once.
- Enemy spawning does not occur before the configured night phase.
- Builder safety reacts to the sunset threshold.
- HUD and lighting display the same world phase.

---

## 5. Economy and Kingdom Ledger [P0]

### Scope

The first slice uses one kingdom ledger with integer quantities for:

- gold
- wood
- stone

No complex personal pouch, personal inventory, trading, crafting chain, or additional resource type is required in P0.

### Conceptual API

~~~gdscript
try_add(resource_id: StringName, amount: int) -> bool
try_spend(costs: Dictionary) -> bool
get_amount(resource_id: StringName) -> int
~~~

The implementation may choose names that match the codebase, but the responsibilities should be equivalent.

### Invariants

1. Balances cannot become negative.
2. Zero or negative amounts are rejected.
3. Unknown resource IDs are rejected.
4. A multi-resource spend is atomic: either every cost is paid or none is.
5. Failed transactions leave all balances unchanged.
6. UI reads ledger state; it never owns or edits resource balances.
7. Persistent resource values are restored through the save system.

### Event Expectations

A successful mutation should provide a clear result/event so HUD feedback and tests can observe the committed transaction. Failure should return a clear rejection reason suitable for development diagnostics and player feedback.

### Approved Economy Parameters (`OD-01`, `OD-02`, `OD-03`)

Starting balances are `2 Gold, 2 Wood, 1 Stone`. Four single-use world caches provide `+4G`, `+5W`, `+3S`, and `+3G` when interacted with (`[E]` within `72 px`). Stone is required to construct (`2G, 4W, 2S`) and repair (`2W, 1S`) the `150 HP` Wooden Wall.

### Acceptance Checks

- Valid resource additions update the expected balance.
- Invalid IDs and non-positive amounts are rejected.
- Insufficient balance rejects spending.
- Multi-resource spending is atomic.
- Failed transactions do not change any balance.
- Save/load preserves all three balances.

---

## 6. Kingdom and Building System [P0]

### P0 Building Set

| Building / Object | Role |
|---|---|
| Town Center | Starting settlement anchor and safe-area reference; may be fixed rather than constructible |
| Wooden Wall | Main construction target and first-night defensive object |

A second constructible building is not required until the wall loop is reliable and a specific test need justifies it.

### Construction Flow

1. Player chooses a candidate location.
2. Placement service validates bounds and placement constraints.
3. Economy validates the full cost.
4. The cost is deducted once, only after validation succeeds.
5. A blueprint/construction state is created.
6. Builder behavior accepts a valid task.
7. Construction progress advances in gameplay simulation.
8. The structure becomes completed.

### Conceptual Building States

PLACEHOLDER → UNDER_CONSTRUCTION → COMPLETED → DAMAGED → DESTROYED

Only states used by the slice need implementation. Legal transitions must be explicit. A building must not jump to completion through a visual animation alone.

### Rules

- Validate placement before spending.
- Validate the entire cost before any deduction.
- Deduct exactly once on accepted placement.
- Construction progress belongs to gameplay state, not HUD or animation nodes.
- Interrupted work must not duplicate cost or progress.
- Repair and refund behavior must follow an explicit rule; no implicit refund is assumed.

### Acceptance Checks

- Invalid placement is rejected without spending resources.
- Insufficient resources reject placement.
- A valid placement creates one construction task/state.
- Cost is deducted once.
- Builder progress is reflected in persistent gameplay state.
- Damage and repair change the building state only through validated gameplay operations.

---

## 7. Villager and Builder System [P0]

### Scope

The first slice needs at least one recruited Villager and Builder behavior capable of constructing or repairing the Wooden Wall.

Approved Builder data model (`OD-05`): Represented as a persistent `NPCBuilderAgent` (`id="npc_01"`, `recruited: bool`, `role: "villager" -> "builder"`, state machine `UNRECRUITED -> IDLE -> MOVING_TO_TASK -> WORKING / RETURNING_TO_SAFETY`).

### Responsibilities

- Create or recruit a Villager after a valid recruitment request.
- Track stable NPC identity and relevant persistent gameplay state.
- Move an NPC toward an assigned task.
- Validate task target and working conditions.
- Perform the assigned construction/repair behavior.
- Override optional work at sunset and return toward safety.

### Suggested State Model

IDLE → MOVING_TO_TASK → WORKING

Additional states when needed:

- RETURNING_TO_SAFETY
- FLEEING
- DISABLED

Do not add states without a behavior that uses them.

### Builder Task Priority

1. **Safety override:** when the dusk threshold is reached, stop optional work and return toward the designated safe area.
2. **Repair critical defense:** repair a damaged defensive structure if the task is valid and affordable.
3. **Finish started construction:** resume an existing critical construction task.
4. **Start new construction:** accept a valid funded task.
5. **Gather materials:** only if gathering is explicitly included in the slice.
6. **Idle:** wait at a safe location.

### Task Validation

Before starting or continuing a task, validate:

- Target still exists.
- Target still needs work.
- Task remains assigned and active.
- NPC can reach the target and is within work range.
- Required resources have been handled correctly.
- Task has not been cancelled or superseded.

Release an invalid task cleanly. Do not repeatedly request paths every frame.

### Safety Behavior

- Define one safe area near the Town Center or behind the defended wall.
- Sunset safety overrides optional construction.
- NPC navigates normally toward safety when a valid path exists.
- If no path exists, report a failure through a debug signal/log; do not silently teleport the NPC.

### Acceptance Checks

- Recruitment charges only after successful validation.
- NPC receives a stable identity.
- Builder accepts only a valid task.
- Completed/cancelled/missing targets release the task.
- Sunset safety overrides optional work.
- NPC does not silently teleport when pathfinding fails.

---

## 8. Survival and First-Night System [P0]

### Scope

- One basic enemy archetype.
- One predictable spawn/approach route.
- Wooden Wall as the first intended defensive target.
- One encounter that can resolve at sunrise.

Approved P0 encounter (`OD-06`): **Greedling Raider** spawns in **3 waves** (`t = 0.0s, 55.0s, 110.0s`) at `x=820.0` during `Night` (`180s`), marching west at `95 px/s` with `45 HP`, `15 damage/hit` (`1.0s` interval), and taking `15 thorn damage/hit` (`45 wall damage/wave`, `135 total wall damage` across 3 waves).

### Behavioral Contract

- Enemy appears only when the configured night condition is met.
- Its route and target selection are deterministic enough to test.
- It can interact with and damage the Wooden Wall through validated gameplay state changes.
- Wall defense must make a meaningful difference to the encounter.
- The encounter resolves at sunrise.

### Failure and Recovery

Approved breach & recovery rule (`OD-07`): If the wall is unbuilt or destroyed (`0 HP`), the raider marches to `TownCenter` (`x=0.0`) and sets `settlement_breached = true` without permanent game-over, allowing recovery on the next day. Partially built walls (`>=25%` progress) act as a makeshift barricade with `int(round(progress * 80.0)) HP` (`OD-04`).

### Acceptance Checks

- No premature spawn.
- Spawn and route are repeatable in tests.
- Wall damage is applied through authoritative simulation.
- Sunrise resolves the encounter.
- The outcome is represented consistently in the state that can be saved.

---

## 9. Presentation and HUD [P0]

The first HUD should remain minimal and present only information needed to understand the slice:

- Gold, Wood, and Stone balances.
- Current day and time phase.
- Contextual interaction/construction feedback.
- Clear sunset/night feedback.

Presentation reads gameplay state. It does not own authoritative resource, construction, NPC, time, or enemy state.

Detailed inventory, quest tracker, multiplayer indicators, minimap, and advanced kingdom management panels are deferred.

### Acceptance Checks

- HUD balances match the ledger.
- Phase indicator matches the world clock.
- Feedback is shown only after a valid committed change or a clearly reported rejection.
- UI cannot independently mutate gameplay state.

---

## 10. Save and Persistence [P0]

### Required Persistent Data

The minimum save should preserve:

- schema_version
- world_id and island_id
- Current day and world time/phase
- Kingdom resource balances
- Stable building IDs, types, positions, levels if used, and construction/durability state
- Stable NPC IDs and only the roles/assignments/states required by the approved design
- Required vertical-slice progression flags

Do not serialize transient scene nodes, animation frames, particles, camera state, or other visual-only state as authoritative game data.

### Save Triggers

- Sunrise after the first-night outcome is resolved.
- Major kingdom milestone.
- Before leaving the active session.
- Manual save only if the UX includes it.
- Periodic autosave only after the basic save path is stable.

### Atomic Write and Recovery

1. Serialize to a temporary file.
2. Validate the serialized result and write status.
3. Preserve the previous valid save.
4. Replace the active save only after the temporary save is valid.
5. Validate schema version and required fields on load.
6. Reject or explicitly migrate unsupported versions.
7. If primary data is invalid, try the previous valid backup and report recovery.

### Acceptance Checks

- Round-trip save/load preserves all required fields.
- Unsupported schema is rejected safely.
- Corrupt primary can recover from a valid backup.
- Failed writes do not destroy the last valid save.
- Save content contains stable gameplay data rather than transient visuals.

---

## 11. Multiplayer System [P1 — M9+, Deferred]

The long-term target is online co-op for 1–4 players. It is not part of P0.

Potential later responsibilities:
- ENet session setup.
- Host-authoritative world simulation.
- Player spawning and movement replication.
- Validated economy/building commands.
- NPC and enemy authority.
- Disconnect handling and external connectivity testing.

The first validation should use two peers. Do not implement ENet, RPCs, lobbies, room codes, a NetworkManager Autoload, or replication during M0–M8.

---

## 12. Approved System Decisions (`OD-01` to `OD-10`)

All system-level P0 decisions are resolved in [`docs/DECISIONS_M2_M8.md`](DECISIONS_M2_M8.md):

| Decision | Owner Document | Approved Resolution |
|---|---|---|
| Gold/Wood/Stone sources & collection (`OD-01`) | GDD + SYSTEMS | 4 single-use caches (`-480`, `-110`, `190`, `-780`) via `[E]` (`72 px`) |
| Starting balances & recruitment (`OD-02`) | GDD + PRD | `2G, 2W, 1S` start; `2G` recruitment at Vagrant Camp (`x=-220`) |
| Stone's first-slice purpose (`OD-03`) | GDD + PRD | Required for Wooden Wall build (`2G, 4W, 2S`) and repair (`2W, 1S`) |
| Wall placement, costs, duration, repair (`OD-04`) | GDD + SYSTEMS | East plot `x=360`, `4.0s` build, `150 HP`, partial barricade `progress * 80 HP` |
| Builder representation (`OD-05`) | GDD + TDD | `NPCBuilderAgent` (`id="npc_01"`, `role: "villager" -> "builder"`) |
| First enemy tuning (`OD-06`) | GDD + SYSTEMS | 3 waves (`0s, 55s, 110s`), `45 HP`, `15 dmg/hit`, `15 thorn dmg/hit` |
| Wall breach consequences (`OD-07`) | GDD + PRD | Non-destructive `settlement_breached = true` at Town Center (`x=0.0`) |
| Exploration reward (`OD-08`) | GDD | Far-west Forgotten Shrine (`x=-780.0`, `+3 Gold`) |
| Save payload schema (`OD-09`) | TDD + SYSTEMS | `schema_version: 1` including multi-plot `buildings[]`, `npcs[]`, and `night_encounter` |

---

## 13. Testing and Definition of Done

System acceptance must be verified in the actual project.

### Required repeatable tests

**Economy**
- Reject negative/zero amounts and unknown IDs.
- Verify atomic multi-resource spending.
- Verify failed spending leaves all balances unchanged.

**Building**
- Reject invalid placement.
- Reject insufficient resources.
- Verify cost is deducted once.
- Verify legal construction-state transitions.
- Verify interrupted work cannot duplicate spending or progress.

**NPC**
- Reject missing or cancelled task targets.
- Stop work when a task is completed.
- Verify dusk safety override.
- Verify no silent teleport on path failure.

**Survival**
- Verify enemy phase gating and repeatable route.
- Verify wall damage.
- Verify sunrise resolution.

**Save**
- Verify round-trip.
- Reject malformed/unsupported versions.
- Verify backup recovery.
- Verify failed writes preserve valid data.

**Runtime vertical slice**
- Move and interact.
- Collect resources.
- Recruit a Villager.
- Place and construct the wall.
- Observe Builder behavior.
- Advance all time phases.
- Resolve the first-night encounter.
- Reach sunrise and reload the saved state.

Never report a test as passed unless it has actually run. Distinguish static review, unit tests, headless execution, and manual runtime validation.

---

**END OF SYSTEMS**

Project: CROWNFALL: THE LAST LIGHT  
Document: SYSTEMS.md  
Version: 1.3


---

> **v1.3 Synchronization Note:** All P0 vertical-slice open decisions (`OD-01` through `OD-10`) referenced in this document have been formally resolved and approved in [`docs/DECISIONS_M2_M8.md`](DECISIONS_M2_M8.md).
