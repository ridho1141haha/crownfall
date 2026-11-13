# CROWNFALL: THE LAST LIGHT
# Revised Project Baseline — v1.1

**Date:** 2026-11-13  
**Status:** Approved planning baseline for the first playable prototype  
**Engine:** Godot 4  
**Language:** GDScript  
**Target:** Windows PC  
**Development model:** Solo developer + AI assistance

> This document resolves scope and architecture conflicts across the original README, GDD, PRD, TDD, and SYSTEMS documents. Until those documents are fully split and synchronized, this is the source of truth for the decisions listed here.

---

## 1. Executive decisions

| Area | Revised decision |
|---|---|
| First playable target | Single-player vertical slice |
| Multiplayer | Deferred; architecture seams only during the first slice |
| Networking implementation | Later milestone, after the single-player loop is fun and stable |
| MVP economy | Gold, Wood, Stone |
| Later resources | Iron, Food, Crystal, Ancient Relics |
| Player inventory | No complex personal inventory in the first slice |
| Kingdom resources | One kingdom ledger; transactions go through one economy API |
| NPC roles in first slice | Villager and Builder behavior only |
| Farmer / Archer / Knight / Guard | Later milestones |
| First enemy | One basic enemy archetype for the first night |
| First map | Forgotten Shore only |
| Save | Versioned, validated, atomic local save |
| Island persistence | Data model designed for it; full multi-island simulation deferred |
| Immediate deliverable | Move, collect, recruit, build, assign Builder, survive one night, reach sunrise |

### Why multiplayer is deferred

Online multiplayer affects ownership, synchronization, persistence, UI, testing, and every world-changing interaction. Implementing all of that before the core loop is proven creates a large debugging multiplier for a solo project.

Do not delete the multiplayer vision. Preserve clean boundaries so it can be introduced later:

- Gameplay systems must not depend directly on UI nodes.
- World-changing actions must go through explicit commands or service methods.
- Economy and world state must not be stored inside presentation scripts.
- Player input must be separated from authoritative gameplay state changes.
- Avoid assumptions that the local player is the only player, but do not build networking infrastructure yet.

**Important:** “Multiplayer-ready architecture” does not mean prematurely implementing RPCs, peer synchronization, lobbies, or ENet.

---

## 2. Product definition and scope

CROWNFALL is a 2D side-scrolling medieval fantasy kingdom-building and survival game set in Aetherion. The player restores a settlement, gathers resources, recruits villagers, builds defenses, and survives creatures that emerge after sunset.

The design pillars remain:

1. **Build:** establish and improve a settlement.
2. **Explore:** discover resources and traces of the fallen world.
3. **Prepare and survive:** make meaningful decisions before nightfall.

### First vertical slice

The first playable slice is intentionally much smaller than the long-term game:

1. Start a new local game on Forgotten Shore.
2. Move the monarch left and right.
3. Collect a small amount of Gold, Wood, and Stone.
4. Recruit one villager.
5. Construct one basic wall.
6. Assign or allow one Builder NPC to construct/repair it.
7. Advance the day/night clock.
8. Survive one basic night encounter.
9. Reach sunrise and preserve the resulting kingdom state.

The slice is successful only if the loop is understandable and enjoyable without relying on multiplayer, multiple biomes, a large quest system, or extensive content.

### Explicitly out of scope for the first slice

- Online multiplayer, lobby, room codes, ENet, RPCs, relay services.
- More than one island.
- Independent island simulation.
- Host migration or dedicated servers.
- Knight, Guard, mounted combat, multiple player classes.
- Multiple enemy families and boss encounters.
- Complex crafting, trading, personal equipment, or large inventory UI.
- Full chapter narrative, branching dialogue, and multiple quest chains.
- Procedural world generation.
- Weather simulation and advanced environmental effects.

---

## 3. Economy and resource rules

### MVP resources

| Resource | MVP role | Example uses |
|---|---|---|
| Gold | Primary currency | Recruitment and selected construction costs |
| Wood | Basic material | Wooden wall and early structures |
| Stone | Durable material | Stone upgrades and later defensive structures |

Iron, Food, Crystal, and Ancient Relics are **not MVP resources**. They may exist in future design notes, but must not appear as required MVP HUD counters, costs, or acceptance criteria.

### Economy model

Use a single kingdom resource ledger for the first slice.

- The ledger stores integer quantities by stable resource ID.
- UI reads the ledger; UI never owns or edits balances.
- All spending uses one transaction method.
- A transaction validates the resource ID, amount, and available balance before changing anything.
- Failed transactions leave every balance unchanged.
- Collection and spending emit clear gameplay events for HUD feedback and tests.
- Do not add a personal coin pouch or a 30-coin capacity until a tested gameplay need exists.

Suggested conceptual API:

```gdscript
try_add(resource_id: StringName, amount: int) -> bool
try_spend(costs: Dictionary) -> bool
get_amount(resource_id: StringName) -> int
```

These are design-level names, not a requirement to create these exact functions if the project already has a consistent API.

### Economy invariants

- Amounts cannot become negative.
- Zero or negative transaction amounts are rejected.
- Unknown resource IDs are rejected.
- A multi-resource purchase is all-or-nothing.
- UI updates only after the ledger confirms a transaction.
- Save/load restores the exact ledger values.

---

## 4. Building and construction

The first slice needs only the smallest building set that proves the loop:

- Town Center: starting kingdom anchor; may be a fixed scene rather than a constructible building.
- Wooden Wall: first defensive construction target.
- Optional second structure only after the wall loop works.

Each building definition should be data-driven and include:

- Stable building ID.
- Display name.
- Resource costs.
- Footprint or placement bounds.
- Construction duration.
- Current construction state.
- Health/durability if damage is implemented.
- Upgrade data only when an upgrade is actually in scope.

Recommended states:

`GHOST/PLACEHOLDER → UNDER_CONSTRUCTION → COMPLETED → DAMAGED → DESTROYED`

Do not implement every state if the first slice does not use it. Keep state transitions explicit and validated.

### Construction rules

1. Validate placement before spending resources.
2. Validate the full cost before deducting any resource.
3. Deduct the cost once when construction is accepted.
4. Construction progress is owned by the building/gameplay layer, not the HUD.
5. A Builder works only when assigned a valid task and within work range.
6. Interrupted work preserves valid progress unless a specific design rule says otherwise.
7. A destroyed or cancelled building must have an explicit refund policy; do not invent refunds implicitly.

---

## 5. NPC behavior and Builder task scheduling

NPC logic must be small, readable, and testable. Avoid one giant script that handles movement, job assignment, safety, animation, and every future profession.

Suggested responsibilities (they may be nodes, scripts, or plain data depending on implementation needs):

- **NPCController:** coordinates the NPC's current state.
- **NPCStateMachine:** owns legal state transitions.
- **NPCMovement:** moves toward a target and reports arrival/failure.
- **NPCTaskManager:** selects and tracks the current task.
- **NPCJob data:** describes a job's requirements and work behavior.
- **NPCSafety logic:** handles the dusk/night safety decision.

Do not create all of these as empty abstractions up front. Introduce a separate component only when it owns meaningful behavior or removes a real dependency.

### First-slice NPC states

`IDLE → MOVING_TO_TASK → WORKING`

Additional states when needed:

- `RETURNING_TO_SAFETY`
- `FLEEING`
- `DISABLED`

### Builder task selection

For the first slice, the Builder only needs to build or repair the first defensive structure. Define task priority explicitly so future tasks do not become arbitrary.

Recommended priority policy:

1. **Immediate safety** when the dusk/night safety condition is met.
2. Repair a critical defensive structure.
3. Finish an already-started critical construction task.
4. Start a new valid construction task.
5. Gather materials only if gathering is part of the current slice.
6. Idle at a safe location.

Safety is a time-sensitive override, not simply another ordinary task. As dusk approaches, the NPC must stop optional work and return to the designated safe area if the current design requires it.

### Task validation

Before starting or continuing work, verify:

- The target still exists.
- The target still needs work.
- The NPC is assigned to the task.
- The NPC is within work range.
- Required resources were already reserved/spent correctly.
- The task has not been cancelled or superseded.

If a task becomes invalid, release it cleanly and request another task. Avoid repeated path requests every frame; update movement targets only when necessary.

### Safety behavior

For the first slice, define one safe area near the Town Center or inside the defended settlement.

- Set a clear dusk warning threshold.
- At the threshold, safety overrides optional work.
- NPC returns to the safe area using normal navigation.
- If no safe path exists, fail safely and expose a debug signal/log rather than silently teleporting.
- Night behavior must be deterministic enough to test.

---

## 6. Day/night and first-night survival

Keep the original 12-minute day as a provisional tuning target, not a hard architectural constant:

- Daylight: 8 minutes.
- Sunset: 1 minute.
- Night: 3 minutes.

The clock must expose phase-change events. NPC safety, enemy spawning, audio, lighting, and HUD should react to those events rather than independently calculating time.

For the first slice:

- One basic enemy type is enough.
- One predictable spawn route is enough.
- One wall interaction is enough.
- The objective is to test whether preparation and construction matter.
- Do not add multiple enemy classes before the first night is fun and balanced.

---

## 7. Technical architecture

### Core rule: simulation is not presentation

Separate the authoritative game state from how it is displayed.

- **Simulation/gameplay:** resources, buildings, NPC tasks, world time, enemy state.
- **Presentation:** sprites, animations, camera, particles, HUD, menus, audio.
- **Input:** translates player input into gameplay requests.
- **Persistence:** serializes stable game state; it must not serialize transient visual nodes blindly.

A UI button or HUD counter must never be the source of truth for game state.

### Suggested high-level flow

```text
Input
  ↓
Gameplay Command / Service
  ↓
Validation
  ↓
Authoritative Game State
  ↓
Gameplay Events
  ├── HUD
  ├── Animation / Effects
  ├── Audio
  ├── Quest Progress (later)
  └── Save Dirty State
```

This structure supports later multiplayer because a future host can validate the same commands. It does not require networking code in the first slice.

### Autoloads

Keep global singletons minimal. For the first slice, likely candidates are:

- GameManager: session-level flow only.
- EventBus: cross-system signals only, if direct references become unwieldy.
- SaveManager: local persistence.
- SceneManager: scene transitions, if needed.

Do **not** register a fully implemented NetworkManager as an Autoload before networking exists. Add it when the multiplayer milestone begins.

### Project directory

Use the folders already present in the repository. The corrected conceptual structure is:

```text
CROWNFALL/
├── project.godot
├── assets/
├── data/
├── docs/
├── resources/
├── scenes/
├── scripts/
├── shaders/
└── tests/
```

The current repository has placeholder directories for several of these folders. That does not mean a Godot project or gameplay implementation already exists.

Create subdirectories only when a real feature needs them. Avoid generating dozens of empty folders or placeholder managers just to match a large future architecture.

---

## 8. Save/load design

The first slice needs a reliable local save. Use a versioned save schema and serialize stable gameplay data, not raw scene-tree state.

### Minimum save payload

- `schema_version`
- `world_id` / `island_id`
- `world_time` and current day
- Kingdom resource balances
- Placed building IDs, positions, levels, construction/durability states
- NPC IDs, roles, and relevant persistent states
- Progression flags required by the slice

Player cosmetics, transient particles, current animation frame, and other presentation-only details are not required.

### Save triggers

Use explicit save requests at meaningful points:

- Manual save, if exposed.
- Sunrise/day transition after the first-night result is settled.
- Major kingdom milestone.
- Before leaving the current game session.
- Optional periodic autosave only after the basic save path is stable.

Do not autosave every frame or on every tiny state mutation.

### Atomic write and recovery

1. Serialize to a temporary file.
2. Validate that serialization completed.
3. Replace the active save only after the temporary file is ready.
4. Keep one previous valid backup.
5. Validate schema version and required fields before loading.
6. Reject or migrate unsupported versions explicitly.
7. If the primary save is invalid, attempt the backup and report the recovery result.

Use stable IDs for persistent objects. Scene paths and display names are not reliable persistent identifiers.

### Island persistence

Design saved world data around an island ID so multiple islands can be added later. For the first slice, only Forgotten Shore needs to be loaded and saved. Do not build background simulation for inactive islands yet.

---

## 9. Multiplayer path — later, not now

When the single-player vertical slice is stable, multiplayer can begin as a separate milestone.

Proposed later stages:

1. Two local/test peers connect over ENet.
2. Host-authoritative session and player spawning.
3. Player movement replication.
4. Validated economy/building commands.
5. NPC and enemy simulation authority.
6. Disconnect and save recovery.
7. External network testing and connection UX.
8. Expand from two to four players.

The host should own authoritative world simulation and shared kingdom state. Each client owns its local camera and local presentation. Never trust a client-provided resource balance, building completion, enemy damage, or quest reward.

Do not promise easy public connectivity until the chosen distribution and networking approach are tested. Direct ENet connections may require network configuration; a relay or platform networking integration is a separate product/technical decision.

---

## 10. Testing requirements

Every feature must have a testable acceptance criterion.

### Minimum automated or repeatable tests

**Economy**
- Cannot spend more than available.
- Multi-resource transaction is atomic.
- Invalid IDs and non-positive amounts are rejected.
- Failed transactions do not change balances.

**Building**
- Invalid placement is rejected.
- Insufficient resources prevent construction.
- Cost is deducted exactly once.
- Construction reaches completion only through valid progress.

**NPC**
- Builder cannot work on a missing target.
- Builder stops when task is completed/cancelled.
- Dusk safety overrides optional work.
- NPC returns to the safe area when a valid path exists.

**Save**
- Save/load round-trip preserves all required state.
- Invalid or unsupported save is rejected safely.
- Backup recovery works.
- A failed write does not destroy the previous valid save.

**Vertical slice runtime**
- Player can move and interact.
- Resources can be collected.
- Recruitment works.
- Wall construction works.
- Builder performs the expected task.
- Day/night advances.
- The first night can be survived.
- Sunrise is reached and state can be saved/reloaded.

Do not claim a test passed unless it was actually executed. Distinguish static inspection, unit tests, headless tests, and manual runtime tests.

---

## 11. Revised milestones

| Milestone | Scope | Exit condition |
|---|---|---|
| M0 — Godot foundation | Create/open project, main scene, input, basic world | Project runs without errors |
| M1 — Player prototype | Movement, collision, animation placeholder, camera | Movement feels correct in a test island |
| M2 — World clock | Forgotten Shore blockout, boundaries, day/night | Phase changes are deterministic |
| M3 — Economy | Gold/Wood/Stone ledger, collection, spending | Economy tests pass |
| M4 — Building | Wooden Wall placement and construction | Valid construction loop works |
| M5 — NPC | Recruit villager, Builder task, safety | Builder behaves predictably |
| M6 — First night | One enemy, wall defense, sunrise | Complete first-night loop is playable |
| M7 — Save/load | Versioned atomic local save | Round-trip and recovery tests pass |
| M8 — Vertical slice polish | Feedback, tuning, bug fixing | A fresh player can complete the slice |
| M9 — Multiplayer prototype | ENet, host authority, replication | Two-player external test works |
| M10 — Content expansion | More buildings, NPC roles, enemies, quests | Added content does not destabilize core loop |

Milestones are sequential gates, not a promise of calendar dates. Do not start M9 merely because the architecture mentions multiplayer.

---

## 12. Definition of Done

A feature is done only when:

- Its behavior matches the agreed scope.
- It has explicit acceptance criteria.
- It has been integrated into the actual Godot project.
- Relevant tests were run.
- Runtime behavior was checked when appropriate.
- No known critical regression remains.
- Documentation reflects the implementation.
- The change is committed with a focused commit message.

A generated script or a successful static review is not proof that a feature works in-game.

---

## 13. Immediate next task

### TASK 001 — Create the smallest runnable Godot project

Do not implement the whole game in one prompt.

Deliver:

1. `project.godot` configured for Godot 4.
2. One main scene.
3. One simple Forgotten Shore test scene with floor and collision.
4. One player scene with horizontal movement.
5. One local camera that follows the player.
6. Main menu → game scene transition, if it can be done without distracting from movement.
7. Clear run instructions.

Acceptance:

- Project opens in the selected Godot 4 version.
- No parser errors.
- Game launches.
- Player moves left and right.
- Player cannot fall through the floor.
- Camera follows the player.
- No multiplayer, economy, NPC, enemy, quest, or save system is added in this task.

After TASK 001 passes in the actual editor/runtime, commit it and move to the next milestone.

---

## 14. Documentation synchronization rules

When updating the original documents:

- **README:** describe the current status honestly; label multiplayer and future islands as planned, not MVP commitments.
- **GDD:** preserve the world, pillars, and long-term vision; update first-slice gameplay and resource scope.
- **PRD:** set multiplayer, full chapter, mount, multiple NPC roles, and extra enemy types to later priorities.
- **TDD:** describe simulation/presentation boundaries, save format, and future multiplayer seams without implementing a premature network layer.
- **SYSTEMS:** align resource, building, NPC, save, and multiplayer priorities with this baseline.
- **ASSET_GUIDELINES:** prioritize only the art assets needed by the current vertical slice. Placeholder art is acceptable during early mechanics validation.
- **CHANGELOG:** record actual implemented changes; do not use it as a wishlist.

If two documents conflict, this baseline wins until the documents are synchronized and this file is retired.

---

## 15. Final direction

The project does not need more speculative systems before it has a playable loop.

The next meaningful proof of CROWNFALL is not a lobby, six islands, a full story chapter, or a large NPC framework. It is a small kingdom that the player can build, protect through one night, and return to after sunrise.

**Build the first kingdom loop. Prove it is fun. Then expand.**
