# CROWNFALL: THE LAST LIGHT

<p align="center">
  <strong>A 2D Medieval Fantasy Kingdom-Building & Survival Adventure</strong>
</p>

<p align="center">
  <em>Build a kingdom. Explore forgotten lands. Survive the darkness.</em>
</p>

---

## Project Status

**Status: Pre-production**

CROWNFALL is currently in the **planning and documentation stage**. The approved first development target is a small **single-player vertical slice** on Forgotten Shore.

**Important repository status:** this repository does not yet contain a runnable Godot project. The current folders are placeholders, and no \`project.godot\`, playable scenes, gameplay scripts, or production game assets have been committed. The next implementation gate is M0 — Godot Foundation.

Online co-op remains part of the long-term vision, but it is deliberately deferred until the single-player gameplay loop is proven.

---

## About the Game

**CROWNFALL: THE LAST LIGHT** is a 2D side-scrolling medieval fantasy game set in the fallen world of **Aetherion**. The player takes the role of a Monarch who restores a settlement, gathers resources, recruits villagers, builds defenses, explores the remains of a lost world, and prepares for creatures that emerge after sunset.

The game is built around three design pillars:

- **Build:** establish and improve a settlement through meaningful resource and construction decisions.
- **Explore:** traverse forgotten places, discover useful resources, and uncover traces of Aetherion's past.
- **Prepare and Survive:** use daylight wisely, protect the settlement, and survive threats after sunset.

The long-term vision includes multiple islands, deeper kingdom systems, environmental storytelling, and online cooperative play for up to four players. Those features are not commitments for the first playable slice.

---

## Project Information

| Category | Current Direction |
|---|---|
| Project | CROWNFALL: THE LAST LIGHT |
| Genre | Kingdom Building, Exploration, Survival, Adventure |
| Engine | Godot 4 |
| Language | GDScript |
| Rendering | 2D |
| Art Direction | Atmospheric medieval-fantasy pixel art |
| Platform Target | Windows PC |
| Base Resolution Target | 1280 × 720 (to be configured and verified in M0) |
| First Playable Target | Single-player vertical slice |
| First Island | Forgotten Shore |
| MVP Resources | Gold, Wood, Stone |
| First Construction Target | Wooden Wall |
| First NPC Scope | Villager with Builder behavior |
| First Survival Encounter | One basic enemy archetype |
| Long-Term Multiplayer | Online co-op, target 1–4 players, planned for M9+ |
| Development Model | Solo developer with AI assistance |

---

## First Vertical Slice

The first playable target is intentionally small. It must prove that the central kingdom loop is understandable and enjoyable before the project expands.

### Intended gameplay loop

1. Start a local game on Forgotten Shore.
2. Move the Monarch through the side-scrolling environment.
3. Collect Gold, Wood, and Stone.
4. Recruit a Villager.
5. Place and fund a Wooden Wall construction.
6. Have Builder behavior complete or repair the wall.
7. Advance through daylight, sunset, and night.
8. Face one basic enemy encounter along one predictable route.
9. Reach sunrise and preserve the resulting kingdom state through local save/load.

The 12-minute day/night cycle (8 minutes daylight, 1 minute sunset, 3 minutes night) is a **provisional tuning target**, not a final balance decision.

### Scope by priority

| Priority | Scope |
|---|---|
| P0 — M0 to M8 | Single-player vertical slice on Forgotten Shore |
| P1 — M9 to M10 | Multiplayer prototype and selected content expansion, conditional on slice validation |
| P2 — Future | Additional islands, larger story content, advanced systems, and other expansion ideas |

### P0 includes

- One local playable Monarch.
- Horizontal movement, collision, and local camera.
- One Forgotten Shore environment.
- Day/night phase progression.
- One kingdom ledger containing Gold, Wood, and Stone.
- Villager recruitment and Builder task behavior.
- Town Center as the starting settlement anchor.
- Wooden Wall placement, construction, damage/repair as required by the first encounter.
- One basic enemy archetype.
- Versioned local save/load with backup recovery.
- Minimal HUD and interaction feedback.

### Explicitly deferred

- Online multiplayer, lobbies, room codes, ENet, RPCs, and synchronization.
- More than one playable island or inactive-island simulation.
- Farmer, Archer, Knight, Guard, and mounted roles.
- Additional enemy families and bosses.
- A large building catalogue, complex crafting, trading, and personal inventory.
- Full dialogue, quest, branching-story, or chapter framework.
- Procedural world generation and advanced weather simulation.

Deferred does not mean cancelled. It means these features must not expand the first slice without a deliberate scope change.

---

## World and Story

Aetherion was once protected by **The First Light**, which maintained a balance between the human world and the realm of darkness. The **Great Eclipse** caused the First Light to vanish, leading to the collapse of kingdoms and the spread of hostile creatures.

The long-term story follows the restoration of settlements and the discovery of what happened to the First Light. The names and broad chapter direction are part of the current world concept; a complete playable story chapter is not part of the first vertical slice.

The first playable location is **Forgotten Shore**. Other island concepts are future content and do not require production assets during P0.

---

## Development Milestones

Milestones are sequential gates, not calendar promises.

| Milestone | Deliverable | Exit Condition |
|---|---|---|
| M0 — Godot Foundation | Project configuration, main scene, input, basic world | Project launches without errors |
| M1 — Player Prototype | Movement, collision, placeholder animation, camera | Movement works reliably in a test area |
| M2 — World Clock | Forgotten Shore blockout, boundaries, day/night | Phase changes are deterministic |
| M3 — Economy | Gold/Wood/Stone ledger, collection, spending | Economy acceptance tests pass |
| M4 — Building | Wooden Wall placement and construction | Valid construction loop works |
| M5 — NPC | Recruit Villager, Builder task behavior, safety | Builder behavior is predictable |
| M6 — First Night | One enemy, wall defense, sunrise | First-night loop is playable |
| M7 — Save/Load | Versioned atomic local save | Round-trip and recovery tests pass |
| M8 — Vertical Slice Polish | Feedback, tuning, bug fixing | A fresh tester can complete the slice |
| M9 — Multiplayer Prototype | ENet, host authority, replication | Two-peer external test works |
| M10 — Content Expansion | Selected new buildings, roles, enemies, exploration/story content | New content does not destabilize the core loop |

---

## Technology and Architecture Direction

- Godot 4 with GDScript.
- 2D side-scrolling presentation.
- Gameplay simulation kept separate from input, UI, and visual presentation.
- Kingdom resources managed through one validated ledger.
- Versioned local save data with temporary writes and backup recovery.
- Stable IDs for persistent world objects.
- Future multiplayer should use host-authoritative state, but no networking infrastructure is to be implemented during P0.

The exact Godot stable patch and project settings will be recorded when M0 initializes the project.

---

## Repository Structure

### Current repository

The repository currently contains documentation and placeholder directories:

~~~text
Crownfall/
├── assets/                 # Placeholder (.gitkeep)
├── data/                   # Placeholder (.gitkeep)
├── docs/
│   ├── ASSET_GUIDELINES.md
│   ├── CHANGELOG.md
│   ├── GDD.md
│   ├── PRD.md
│   ├── REVISED_PROJECT_BASELINE.md
│   ├── SYSTEMS.md
│   └── TDD.md
├── resources/              # Placeholder (.gitkeep)
├── scenes/                 # Placeholder (.gitkeep)
├── scripts/                # Placeholder (.gitkeep)
├── shaders/                # Placeholder (.gitkeep)
└── tests/                  # Placeholder (.gitkeep)
~~~

This is not yet the final runtime project structure. Directories and subdirectories should be created only when a real feature requires them.

---

## Documentation Guide

| Document | Responsibility |
|---|---|
| [Revised Project Baseline](docs/REVISED_PROJECT_BASELINE.md) | Approved scope, architecture constraints, milestone order, and current source of truth |
| [PRD](docs/PRD.md) | Product requirements, priorities, acceptance criteria, and success conditions |
| [GDD](docs/GDD.md) | Player experience, design pillars, world, lore, and vertical-slice gameplay |
| [SYSTEMS](docs/SYSTEMS.md) | Gameplay-system behavior, rules, invariants, and dependencies |
| [TDD](docs/TDD.md) | Godot project architecture, data flow, persistence, coding, and testing standards |
| [Asset Guidelines](docs/ASSET_GUIDELINES.md) | Art direction, asset standards, production priorities, and validation |
| [Changelog](docs/CHANGELOG.md) | Historical record of documentation and implementation changes |

When documents overlap, the Revised Project Baseline governs approved scope and cross-system constraints. Each specialized document owns its subject matter. Unresolved design questions must remain visibly marked as open decisions rather than being silently treated as approved requirements.

---

## Development Workflow

Each milestone should follow this sequence:

1. Confirm scope and acceptance criteria.
2. Review dependencies and relevant documentation.
3. Implement only the approved milestone.
4. Run relevant automated or repeatable tests.
5. Perform runtime testing in Godot where applicable.
6. Review regressions and update documentation.
7. Commit the verified change.

AI-generated code or assets are production aids, not proof of correctness. A feature is not complete until its behavior has been tested in the actual project.

---

## Next Development Gate

### M0 — Godot Foundation

- Initialize the Godot 4 project and record the exact stable patch.
- Configure project settings and the main scene.
- Verify that the project launches without parser or startup errors.
- Document run instructions.

**M0 acceptance:** the project opens and runs with the expected main scene. Do not add gameplay systems merely to inflate this milestone.

### M1 — Player Prototype

- Add the player scene and horizontal movement.
- Add floor collision and a bounded test area.
- Add a local Camera2D that follows the player.
- Add placeholder idle/walk feedback when movement is stable.

**M1 acceptance:** the player moves left and right, cannot fall through the floor, respects test bounds, and the camera follows correctly. Verify this in the actual Godot runtime.

Do not add multiplayer, economy, NPC, enemy, quest, or save systems during M0/M1.

---

## Project Principle

CROWNFALL should grow from a small, reliable kingdom loop into the larger Aetherion experience. Prove the foundations first; expand only when the current milestone is stable.

<p align="center">
  <strong>CROWNFALL: THE LAST LIGHT</strong><br/>
  <em>Build. Explore. Survive.</em>
</p>

---

**Documentation Version:** 1.2  
**Project:** CROWNFALL: THE LAST LIGHT  
**Status:** Pre-production — Documentation Baseline Synchronized
