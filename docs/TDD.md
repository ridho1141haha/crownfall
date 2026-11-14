# CROWNFALL: THE LAST LIGHT
# TECHNICAL DESIGN DOCUMENT (TDD)

**Document Version:** 1.3
**Baseline:** Revised Project Baseline v1.3 (`docs/DECISIONS_M2_M8.md`)
**Engine:** Godot 4.7.2.stable (verified at M0/M1)
**Language:** GDScript
**Platform Target:** Windows PC
**Architecture Direction:** Simulation / Presentation Separation
**Status:** M0–M8 Vertical Slice Prototype Implemented (`Godot 4.7.2.stable`)

---

## 1. Purpose and Technical Scope

This document defines the technical direction for the first single-player vertical slice and the boundaries that will make later expansion manageable.

The repository contains a runnable Godot `4.7.2.stable` project (`project.godot`), playable vertical-slice scenes (`Main.tscn`, `ForgottenShore.tscn`, `Player.tscn`), modular simulation scripts (`scripts/`, including `ResourceNodeManager`, `HearthSystem`, `InteractionResolver`, `Watchtower`, `Farm Plot`, `Stone Wall Lv.2`, `West Wall`), `data/*.json`, and `shaders/*.gdshader`, and separated automated unit, scene-integration, and experimental P1 test suites (`tests/`).

### 1.1 Technical Goals

1. Keep the first implementation small and runnable.
2. Separate authoritative gameplay state from UI, animations, and other presentation.
3. Make core state changes explicit and validated.
4. Persist stable game data through a versioned local save format.
5. Keep future multiplayer seams possible without building networking infrastructure in P0.
6. Avoid speculative abstractions and empty manager layers.

### 1.2 Confirmed Direction

| Area | Direction |
|---|---|
| Engine | Godot 4.7.2.stable (verified at M0) |
| Language | GDScript |
| Rendering | Godot 2D |
| Player physics | CharacterBody2D is the intended starting point |
| Camera | Local Camera2D |
| World | Forgotten Shore first; further islands later |
| Resource data | Gold, Wood, Stone in one kingdom ledger |
| Static definitions | Godot Resources and/or static data files where useful |
| Save | Versioned local JSON with temp write and backup recovery |
| Version control | Git / GitHub |
| Multiplayer | ENet host-authoritative concept, deferred until M9 |

These are architectural directions. Specific classes, APIs, and directory names should be introduced only when justified by an actual feature.

---

## 2. Architecture Principles

### 2.1 Simulation Is Not Presentation

Gameplay state must not be owned by UI or visual nodes.

| Layer | Responsibilities |
|---|---|
| Input | Read controls and submit gameplay requests |
| Simulation / Gameplay | Economy, construction, NPC task state, world time, enemy state |
| Presentation | Sprites, animations, camera, particles, lighting, HUD, menus, audio |
| Persistence | Serialize and restore stable gameplay data |
| Session / Scene Flow | Start a local session and transition between scenes |

A presentation node may display state or request an action. It must not become the source of truth for balances, construction progress, NPC task completion, or enemy damage.

### 2.2 Command and Event Flow

~~~text
Player Input / UI Request
          |
          v
Gameplay Service / Command
          |
          v
Validation
          |
          v
Authoritative Gameplay State
          |
          v
Committed Result / Gameplay Event
       /       |       \
      v        v        v
    HUD     Audio   Animation/FX
          |
          v
    Save Dirty State
~~~

Use direct references when they keep dependencies simple. An EventBus is optional and should only be introduced when cross-system signal wiring becomes unwieldy.

### 2.3 Do Not Over-Abstract

- Do not create a manager for every system by default.
- Do not create empty class hierarchies for future professions/enemies.
- Do not add interfaces solely to claim multiplayer readiness.
- Do not create many empty folders before a real feature requires them.
- Prefer a small, testable implementation that can be evolved after runtime evidence.

---

## 3. Conceptual Project Organization

The repository implements the following directory layout for the P0 vertical slice (with `scripts/networking/` and `ContentExpansionM10.gd` kept as experimental P1 skeletons):

~~~text
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
~~~

Create subdirectories only when a feature requires them. A possible future grouping is:

- scenes/player/
- scenes/world/
- scenes/npc/
- scenes/buildings/
- scenes/enemies/
- scenes/ui/
- scripts/core/
- scripts/economy/
- scripts/kingdom/
- scripts/npc/
- scripts/survival/
- scripts/save/

Do not create all of these in M0 if the task does not need them.

### 3.1 Minimal Autoload Policy

Autoloads are global lifetime objects. Keep their number small.

| Candidate | P0 Policy |
|---|---|
| GameManager | Add only if session-level flow needs a persistent owner |
| SaveManager | Add when local save/load is implemented |
| EventBus | Optional; add only if direct references become difficult |
| SceneManager | Optional; add only if scene transitions justify it |
| NetworkManager | **Do not implement or register before M9** |
| AudioManager | Defer until there is a real audio lifecycle requirement |

An Autoload is not automatically justified by a system name.

### 3.2 Coding Standards

- Use static typing where it improves clarity and catches errors.
- Use consistent snake_case for GDScript files, functions, variables, and signals.
- Use clear, stable IDs for persistent entities (for example, building IDs and NPC IDs).
- Keep data definitions separate from behavior where that separation is useful.
- Avoid hard-coded duplicated balance values; centralize tunable values.
- Prefer small functions with explicit inputs and results.
- Handle invalid input and failed file operations explicitly.
- Follow the conventions already present in the project once M0 initializes it.

Do not enforce contradictory naming styles. Consistency within the actual Godot project takes precedence over speculative naming rules.

---

## 4. First-Slice Technical Boundaries

### 4.1 Player

- Start with one local Monarch.
- Use horizontal movement and collision.
- Use one local Camera2D.
- Keep input handling separate from kingdom/economy mutations.
- No player synchronization, multiple player ownership, or multiplayer camera system in P0.

### 4.2 World and Clock

- Load Forgotten Shore as the only active world.
- Keep world bounds and collision separate from decorative background layers.
- Use one source of truth for current phase/time.
- Publish phase changes for Builder safety, enemy spawning, lighting, and HUD.
- Do not simulate inactive islands.

### 4.3 Economy

- Keep Gold, Wood, and Stone in one kingdom ledger.
- Validate resource IDs, positive amounts, and available balances before committing.
- Make multi-resource spending atomic.
- Return an explicit success/failure result.
- Keep HUD values derived from committed ledger state.

### 4.4 Building

- Validate placement before spending.
- Validate the full cost before mutation.
- Deduct exactly once when construction is accepted.
- Store construction progress and durability in gameplay state.
- Do not use animation completion as proof of gameplay construction completion.

### 4.5 NPC and Builder

- Give each persistent NPC a stable ID.
- Keep movement, task state, and animation responsibilities distinguishable.
- Validate task target and assignment before work.
- Avoid per-frame repeated path requests.
- At sunset, safety overrides optional work.
- Builder is represented as `NPCBuilderAgent` (`id="npc_01"`, `recruited: bool`, `role: "villager" -> "builder"`, `OD-05`).

### 4.6 First Enemy

- Implement one enemy archetype only.
- Use one predictable spawn route.
- Apply damage through gameplay state/services.
- Gate spawning on the authoritative world clock.
- Defer additional enemy families and complex combat.

---

## 5. Persistence and Save Schema

### 5.1 Save Design

The first slice uses a versioned local save in Godot's user data location (for example, user://save_slot_0.json).

The save contains stable gameplay state, not raw scene-tree state.

Minimum conceptual payload:

~~~json
{
  "schema_version": 1,
  "world_id": "aetherion",
  "island_id": "forgotten_shore",
  "day_count": 1,
  "world_time": 0.0,
  "world_phase": "daylight",
  "resources": {
    "gold": 2,
    "wood": 2,
    "stone": 1
  },
  "buildings": [
    {
      "id": "wall_east_01",
      "type": "wooden_wall",
      "position_x": 360.0,
      "level": 1,
      "state": "PLACEHOLDER",
      "progress": 0.0,
      "durability": 0,
      "max_durability": 150
    }
  ],
  "npcs": [
    {
      "id": "npc_01",
      "recruited": false,
      "role": "villager",
      "state": "UNRECRUITED",
      "position_x": -220.0
    }
  ],
  "night_encounter": {
    "night_active": false,
    "night_elapsed": 0.0,
    "spawned_wave_count": 0,
    "enemy_active": false,
    "enemy_x": 820.0,
    "enemy_hp": 0,
    "settlement_breached": false,
    "first_night_survived": false
  },
  "progression_flags": {
    "first_night_survived": false,
    "collected_nodes": []
  }
}
~~~

This is a structural example, not final balance data. Starting resource quantities, persistent NPC fields, building properties, and progression flags must follow approved design decisions.

### 5.2 Required Save Rules

- Include an explicit schema version.
- Validate required fields and field types before applying loaded state.
- Reject unsupported or malformed data safely.
- Preserve stable IDs for persistent buildings and NPCs.
- Do not serialize transient particles, animation frames, camera offsets, or temporary visual nodes.
- Keep migration logic explicit if the schema changes in the future.

### 5.3 Atomic Write and Recovery

Intended flow:

1. Build the save payload from authoritative state.
2. Serialize and write to a temporary file.
3. Check file open/write/flush/close outcomes as supported by the chosen Godot APIs.
4. Preserve the last known valid save as a backup.
5. Replace the active save only after the new temporary file is validated.
6. On load, validate the primary file.
7. If invalid, attempt the backup and report the recovery result.
8. Never overwrite a valid backup with malformed data.

Implemented in `SaveManager._safe_replace_file()`: writes and validates `.tmp`, stages and validates `.bak` via `.bak.tmp`, attempts direct atomic POSIX rename first, and falls back to Windows-safe staged `.old` swap with automatic rollback from `.old`/`.bak` if replacement fails.

### 5.4 Save Test Cases

- Valid save/load round trip.
- Missing file behavior for a new game.
- Malformed JSON rejection.
- Missing required fields.
- Unsupported schema version.
- Backup recovery when primary is corrupt.
- Failed write preserves previous valid data.
- Save restores the exact required economy/building/NPC/progression state.

---

## 6. Test Strategy

Testing should grow with the project rather than requiring a complex framework before M0.

### 6.1 Test Levels

| Level | Purpose |
|---|---|
| Static review | Inspect code/configuration for obvious issues; not runtime proof |
| Unit or script-level tests | Verify isolated deterministic rules |
| Headless project checks | Verify import/parser/startup behavior where supported |
| Manual runtime tests | Verify movement, collisions, visuals, controls, and gameplay feel |
| Regression checks | Re-run critical prior tests after changes |

Automated testing uses Godot 4 headless SceneTree scripts (`tests/test_unit_m2_m7.gd`, `tests/test_integration_m8_slice.gd`, `tests/test_experimental_p1_m9_m10.gd`), `tests/verify_repo_integrity.py`, and `.github/workflows/godot-ci.yml`.

### 6.2 Required Feature Tests

**Economy**
- Reject invalid IDs and non-positive amounts.
- Verify insufficient balance is rejected.
- Verify atomic multi-resource spending.
- Verify failed operations do not mutate balances.

**Building**
- Reject invalid placement and insufficient funds.
- Verify one-time cost deduction.
- Verify legal state transitions and construction progress.

**NPC**
- Reject invalid task targets.
- Release completed/cancelled tasks.
- Verify dusk safety priority.
- Verify safe-path failure is reported, not hidden by teleportation.

**Survival**
- Verify phase-gated enemy spawn.
- Verify predictable target/route.
- Verify wall damage and sunrise resolution.

**Save**
- Verify round-trip and schema validation.
- Verify backup recovery.
- Verify failed write does not destroy valid data.

---

## 7. Multiplayer Readiness — M9+, Not P0

The long-term model is host-authoritative online co-op using Godot multiplayer/ENet, subject to later connectivity design and testing.

P0 preparation is limited to:
- Simulation not coupled to UI.
- World-changing actions passing through validated service/command boundaries.
- Stable persistent IDs.
- No assumption that every data record must embed the local camera or input device.

Do not implement:
- ENetMultiplayerPeer
- RPC methods
- Lobbies or room codes
- NetworkManager Autoload
- State replication
- Host migration
- Relay services

The first multiplayer validation target is two peers. Four-player support remains a target to validate, not a demonstrated result.

---

## 8. Milestone Technical Gates

| Milestone | Technical Deliverable | Verification Gate |
|---|---|---|
| M0 — Godot Foundation | Godot project, main scene, input, basic world | Project opens and runs without errors |
| M1 — Player Prototype | Player movement, floor collision, local camera | Manual runtime movement and collision test |
| M2 — World Clock | Forgotten Shore blockout and phase clock | Deterministic phase transitions |
| M3 — Economy | Kingdom ledger and collection/spending | Economy invariants pass |
| M4 — Building | Placement validation and wall construction | Cost and state-transition tests pass |
| M5 — NPC | Recruitment, Builder tasks, dusk safety | Task and safety tests pass |
| M6 — First Night | One enemy, wall interaction, sunrise | Complete encounter is playable |
| M7 — Save/Load | Versioned local persistence and recovery | Round-trip and backup tests pass |
| M8 — Vertical Slice Polish | Integration, feedback, balance and regression fixes | Fresh tester completes the slice |
| M9 — Multiplayer Prototype | ENet host authority and replication | Two-peer external test |
| M10 — Content Expansion | Selected additional gameplay content | Existing slice remains stable |

Milestones are gates, not calendar estimates. A later milestone must not begin solely because its architecture is mentioned in this document.

---

## 9. Definition of Done

A technical feature is done only when:

- Its scope and acceptance criteria are clear.
- It is implemented in the actual Godot project.
- Relevant tests have been run.
- Runtime behavior has been checked where applicable.
- No known critical regression remains.
- Documentation reflects the actual behavior.
- The change is committed with a focused message.

A generated file, static code review, or successful parser check alone does not prove that a gameplay feature works.

---

## 10. Open Technical Decisions

| Decision | Status | Resolution Reference (`docs/DECISIONS_M2_M8.md`) |
|---|---|---|
| Exact Godot stable patch and project settings | **Resolved (M0)** | Verified on **Godot `4.7.2.stable`** (`1280x720`, `gl_compatibility`) |
| Input map and movement tuning | **Resolved (M1)** | `A/D`, `E`, `R`, `B`, `F`, `T`, `K` (`move_speed = 240.0`) |
| Test framework/tooling | **Resolved (M3/M8)** | Headless `SceneTree` suites + `tests/verify_repo_integrity.py` + GitHub Actions CI |
| Resource collection representation | **Resolved (M3)** | 4 single-use Forgotten Shore caches (`OD-01`) |
| Builder data representation | **Resolved (M5)** | Persistent `NPCBuilderAgent` (`id="npc_01"`, `OD-05`) |
| Final save schema and required NPC fields | **Resolved (M7)** | `schema_version: 1` with multi-plot `buildings[]`, `npcs[]`, and `night_encounter` (`OD-09`) |
| ENet connectivity/relay strategy | **Open (Deferred to M9)** | Requires two-peer external network testing before M9 sign-off |

---

**END OF TDD**

Project: CROWNFALL: THE LAST LIGHT  
Document: TDD.md  
Version: 1.3
