# **CROWNFALL: THE LAST LIGHT**

# **TECHNICAL DESIGN DOCUMENT (TDD)**

**Document Version: 1.1 (Synced with Revised Project Baseline)**

**Engine: Godot 4 (Lock exact stable patch in project.godot on M0 init)**

**Language: GDScript (Static Typing enforced)**

**Architecture: Modular, Simulation/Presentation Decoupled (Multiplayer-Ready Seams)**

**Platform: Windows PC**

**Status: Pre-production (First Vertical Slice Baseline)**

# **1\. TECHNICAL OVERVIEW**

## **1.1 Objective**

**This document defines the technical architecture, project organization, data/save schemas, and testing standards for CROWNFALL: THE LAST LIGHT. In accordance with REVISED\_PROJECT\_BASELINE.md, the project delivers a Single-Player Vertical Slice (M0–M8) first while preserving clean architectural seams for ENet Multiplayer (M9).**

## **1.2 Technical Decisions**

| Component | Decision |
| :---- | :---- |
| **Engine** | **Godot 4 (Stable)** |
| **Language** | **GDScript** |
| **Rendering** | **Godot 2D** |
| **Physics** | **CharacterBody2D** |
| **Networking (M9)** | **ENetMultiplayerPeer (Host-Authoritative — deferred)** |
| **Camera** | **Local Camera2D** |
| **World** | **Separate island .tscn scenes (Forgotten Shore for MVP)** |
| **Data** | **Custom Resource (.tres) \+ static JSON/CSV in data/** |
| **Save** | **Versioned, atomic JSON serializer (user://)** |
| **Version Control** | **Git / GitHub** |
| **Target OS** | **Windows PC** |

# **2\. ARCHITECTURE OVERVIEW**

## **2.1 Core Rule: Simulation is Not Presentation**

**Authoritative gameplay state must never live inside presentation or UI scripts:**

* **Simulation / Gameplay Layer: Kingdom resource ledger, building states, NPC task scheduling, world clock, enemy state.**  
* **Presentation Layer: Sprites, animations, Camera2D, particles, shaders, HUD counters, menus, audio.**  
* **Input Layer: Translates player input into explicit gameplay commands/requests.**  
* **Persistence Layer: Serializes stable gameplay data (never transient visual nodes or animation frames).**

## **2.2 Authoritative Command & Event Flow**

```
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
  └── Save Dirty State

```

**This boundary allows a future host (M9) to validate the same commands without requiring networking code during the first vertical slice.**

# **3\. PROJECT DIRECTORY**

**Matches the repository root layout. Create subdirectories only when a real feature needs them:**

```
CROWNFALL/
├── project.godot
├── assets/                 # Art, audio, fonts (placeholder art acceptable in MVP)
├── data/                   # Static balance tables
├── docs/                   # Documentation & REVISED_PROJECT_BASELINE.md
├── resources/              # Custom Godot Resource (.tres) definitions
├── scenes/                 # Main, world/islands, player, npc, buildings, enemies, ui
├── scripts/                # Core, player, world, kingdom, economy, npc, survival, save, ui
├── shaders/                # Visual shaders (later polish)
└── tests/                  # Automated unit & runtime tests

```

## **3.1 Autoload Configuration**

**Keep global singletons minimal for the first slice:**

| Singleton | Script | Responsibility |
| :---- | :---- | :---- |
| **GameManager** | **game\_manager.gd** | **Session-level flow only** |
| **EventBus** | **event\_bus.gd** | **Cross-system signals when direct references are unwieldy** |
| **SaveManager** | **save\_manager.gd** | **Atomic local save/load** |
| **SceneManager** | **scene\_manager.gd** | **Scene transitions (if needed)** |

**Important: Do not register NetworkManager as an Autoload before the M9 multiplayer milestone begins.**

## **3.2 Coding Standards**

* **Enforce static typing (var speed: float \= 100.0, func try\_spend(costs: Dictionary) \-\> bool:).**  
* **Class/file names in PascalCase (or consistent snake\_case.gd for autoloads as listed above); variables and functions in snake\_case; signals in past tense (transaction\_committed, building\_completed, sunset\_started).**  
* **Use stable persistent IDs (building\_id, npc\_id, island\_id) rather than scene paths or display names.**

# **4\. SAVE SYSTEM & ATOMIC PERSISTENCE**

## **4.1 Minimum Save Payload (user://save\_slot\_0.json)**

```
{
  "schema_version": 1,
  "world_id": "aetherion",
  "island_id": "forgotten_shore",
  "day_count": 2,
  "world_time": 0.0,
  "resources": {
    "gold": 15,
    "wood": 20,
    "stone": 5
  },
  "buildings": [
    {
      "id": "wall_east_01",
      "type": "wooden_wall",
      "position_x": 420.0,
      "level": 1,
      "state": "COMPLETED",
      "durability": 100
    }
  ],
  "npcs": [
    {
      "id": "npc_01",
      "role": "builder",
      "state": "IDLE",
      "position_x": 120.0
    }
  ],
  "progression_flags": {
    "first_night_survived": true
  }
}

```

## **4.2 Atomic Write & Recovery Procedure**

1. **Serialize payload to a temporary file (user://save\_slot\_0.tmp).**  
2. **Validate that serialization completed without error.**  
3. **Preserve one previous valid backup (user://save\_slot\_0.bak) before replacing the active save.**  
4. **On load, validate schema\_version and required fields; if corrupted or invalid, recover from .bak and report the recovery result.**

# **5\. MULTIPLAYER SEAMS (M9 — DEFERRED)**

* **Do Not Implement Yet: No ENetMultiplayerPeer, RPCs, lobbies, or room codes in M0–M8.**  
* **Preparation Rules:**  
  * **Never couple gameplay simulation directly to UI nodes.**  
  * **Route state mutations through command/service methods.**  
  * **Avoid assuming the local player is the only possible actor in data models.**

# **6\. TESTING REQUIREMENTS**

**Every milestone requires verifiable acceptance checks in tests/:**

* **Economy: Reject negative/zero/unknown IDs; enforce atomic multi-resource try\_spend; failed spends leave balances untouched.**  
* **Building: Reject invalid placement/insufficient resources; deduct cost once; complete only through valid progress.**  
* **NPC: Stop work on missing/cancelled targets; enforce dusk safety override to safe area without silent teleportation.**  
* **Save: Round-trip state preservation; reject unsupported schema\_version; verify .bak backup recovery and non-destructive failed writes.**  
* &nbsp;

&nbsp;