# CROWNFALL: THE LAST LIGHT

<p align="center">
  <strong>A 2D Medieval Fantasy Kingdom-Building & Survival Adventure</strong>
</p>

<p align="center">
  <em>Build a kingdom. Explore forgotten lands. Survive the darkness.</em>
</p>

---

## Project Status

**Document & Baseline Version:** 1.3  
**Current Stage:** Runnable Single-Player Vertical Slice Prototype (`M0–M8` Implemented on `main`)  
**Engine Target:** Godot `4.7.2.stable`

This repository contains a runnable Godot 4 project (`project.godot`), playable scenes (`scenes/main/Main.tscn`, `scenes/world/ForgottenShore.tscn`, `scenes/player/Player.tscn`), modular gameplay systems (`scripts/`), and automated unit and scene-integration test suites (`tests/`).

- **P0 Vertical Slice (`M0–M8`):** Implemented and integrated on **Forgotten Shore** (player movement, deterministic world clock, atomic Gold/Wood/Stone kingdom ledger, multi-plot Wooden Wall construction/repair, Villager recruitment and Builder priority/safety AI, 3-wave nighttime Greedling Raider survival encounter, and atomic local save/load with backup recovery).
- **P1 Experimental Skeletons (`M9–M10`):** `scripts/networking/NetworkSessionManager.gd` and `scripts/kingdom/ContentExpansionM10.gd` remains an experimental P1 skeleton for `Archer`/`Farmer` NPC roles and `Crawler`/`Brute` waves, while `Farm Plot`, `Watchtower` plot (once built, deals +10 damage to every raider that strikes the wall), `Stone Wall Tier 2`, `Hearth` Lv.1–3, `West Wall` (`x=-400`), `[Space]` *Kindle Flare*, and renewable Wood/Stone nodes are active in `ForgottenShoreSession.gd`.

---

## Running the Game & Automated Tests

### 1. Run Playable Prototype in Godot Editor
Open `project.godot` in **Godot `4.7.2.stable`** and press **F5**:
- **Controls on Forgotten Shore:**
  - `A` / `D` or `Left` / `Right`: Move Monarch horizontally
  - `E`: Collect nearby resource caches (`Gold`, `Wood`, `Stone`) or interact contextually
  - `R`: Recruit Villager as Builder at Vagrant Camp (`x = -220`, cost: `2 Gold`)
  - `B`: Fund Wooden Wall construction at Eastern Wall Plot (`x = 380`, cost: `2 Gold, 4 Wood, 2 Stone`)
  - `F`: Fund instant wall repair when damaged (`cost: 2 Wood, 1 Stone`)
  - `T`: Toggle `1x` / `20x` clock speed for testing phase transitions
  - `K`: Trigger manual local save (`user://save_slot_0.json`, disabled during active Night combat)

### 2. Run Automated Test Suites (Headless CLI)
 The repository separates unit tests, full scene integration tests (`Main.tscn` → `ForgottenShore.tscn`), and experimental P1 tests:

```bash
# 1. P0 Unit Tests (M2 World Clock through M7 SaveManager)
godot --headless --script res://tests/test_unit_m2_m7.gd

# 2. P0 Full Scene & Gameplay Loop Integration Test (M8: Main -> ForgottenShore -> Collect -> Recruit -> Build -> Night -> Sunrise -> Save/Reload)
godot --headless --script res://tests/test_integration_m8_slice.gd

# 3. Everything below plus the world-clock test, in sequence, with the same log traps as CI
bash tests/run_all.sh

# 4. Experimental P1 Skeleton Tests (M9 Networking Seams & M10 Content Expansion)
godot --headless --script res://tests/test_experimental_p1_m9_m10.gd

# 5. Repository Static & Scene-Graph Integrity Verifier (Python 3)
python3 tests/verify_repo_integrity.py
```

---

## Milestone Status (`M0–M10`)

| Milestone | Priority | Scope | Current Repository Status |
|---|---|---|---|
| **M0 — Godot Foundation** | `P0` | `project.godot`, `Main.tscn`, input map | **Implemented & Runtime Verified** (`Godot 4.7.2.stable`) |
| **M1 — Player Prototype** | `P0` | `Player.tscn`, `Player.gd`, bounds, `Camera2D` | **Implemented & Runtime Verified** (`Godot 4.7.2.stable`) |
| **M2 — World Clock** | `P0` | `TimeManager.gd`, `SkyAtmosphere.gd`, phase signals | **Implemented & Unit/Integration Tested** |
| **M3 — Economy** | `P0` | `EconomyLedger.gd` (`gold`, `wood`, `stone`), world caches | **Implemented & Unit/Integration Tested** |
| **M4 — Building** | `P0` | `BuildingManager.gd`, multi-plot Wooden Wall state machine | **Implemented & Unit/Integration Tested** |
| **M5 — NPC Builder** | `P0` | `NPCBuilderAgent.gd`, task validation & dusk safety override | **Implemented & Unit/Integration Tested** |
| **M6 — First Night** | `P0` | `NightEncounterManager.gd`, 3-wave raider approach & wall defense | **Implemented & Unit/Integration Tested** |
| **M7 — Save/Load** | `P0` | `SaveManager.gd`, safe replacement, `.bak` verification & rollback | **Implemented & Unit/Integration Tested** |
| **M8 — Slice Integration** | `P0` | `ForgottenShoreSession.gd`, `ClockHUD.gd`, end-to-end loop test | **Implemented & Scene-Integration Tested** |
| **M9 — Multiplayer** | `P1` | `NetworkSessionManager.gd` (ENet host-authority skeleton) | **Experimental Skeleton Only (Deferred)** |
| **M10 — Expansion** | `P1` | `ContentExpansionM10.gd` (Stone Wall, Watchtower, Archer, Farmer) | **Experimental Skeleton Only (Deferred)** |

---

## Documentation Index (Synchronized to v1.3)

- **[Revised Project Baseline (`docs/REVISED_PROJECT_BASELINE.md`)](docs/REVISED_PROJECT_BASELINE.md):** Cross-project authority for scope, priorities, and milestone gates.
- **[Approved Design & Technical Decisions (`docs/DECISIONS_M2_M8.md`)](docs/DECISIONS_M2_M8.md):** Official resolution record for `OD-01` through `OD-10`.
- **[Product Requirements Document (`docs/PRD.md`)](docs/PRD.md):** Product scope, requirement IDs, and acceptance criteria.
- **[Game Design Document (`docs/GDD.md`)](docs/GDD.md):** World premise, first-slice gameplay loop, and 3-wave night encounter balance.
- **[Game Systems Specification (`docs/SYSTEMS.md`)](docs/SYSTEMS.md):** System contracts, state transitions, invariants, and test gates.
- **[Technical Design Document (`docs/TDD.md`)](docs/TDD.md):** Architecture layers, command return contracts, safe save replacement, and test separation.
- **[Asset & Visual Guidelines (`docs/ASSET_GUIDELINES.md`)](docs/ASSET_GUIDELINES.md):** Pixel art specifications and placeholder conventions.
- **[Changelog (`docs/CHANGELOG.md`)](docs/CHANGELOG.md):** Factual record of repository commits and verification boundaries.
