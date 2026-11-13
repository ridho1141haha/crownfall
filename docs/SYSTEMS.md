# **CROWNFALL: THE LAST LIGHT**

# **GAME SYSTEMS SPECIFICATION**

**Document Version:** 1.1 (Synced with Revised Project Baseline)

**Document:** SYSTEMS.md

**Engine:** Godot 4

**Status:** Pre-production (First Vertical Slice Baseline)

# **1\. PURPOSE**

This document defines the behavior, responsibilities, invariants, and priorities of every major game system in **CROWNFALL: THE LAST LIGHT**, aligned with REVISED\_PROJECT\_BASELINE.md.

## **System Priority**

| Priority | Meaning |
| :---- | :---- |
| P0 | Required for Single-Player Vertical Slice (M0–M8) |
| P1 | Multiplayer & Initial Content Expansion (M9–M10) |
| P2 | Future Development & Polish |

# **2\. SYSTEM DEPENDENCY MAP**

```
GAME SESSION
│
├── PLAYER SYSTEM [P0]
│   ├── Horizontal Movement & Collision
│   ├── Local Camera2D
│   └── Interaction Requests
│
├── WORLD & TIME SYSTEM [P0]
│   ├── Forgotten Shore Scene & Boundaries
│   ├── Day/Night Clock (Phase Events)
│   └── Multi-Island Framework (Data-ready only)
│
├── ECONOMY SYSTEM [P0]
│   └── Kingdom Resource Ledger (Gold, Wood, Stone)
│
├── KINGDOM & BUILDING SYSTEM [P0]
│   ├── Town Center (Anchor)
│   └── Wooden Wall (Construction & Durability)
│
├── NPC & BUILDER AI SYSTEM [P0]
│   ├── Villager Recruitment
│   ├── Builder Task Scheduler & Priority Policy
│   └── Dusk/Night Safety Override
│
├── COMBAT & SURVIVAL SYSTEM [P0]
│   ├── Night Spawner (Single Route)
│   └── Basic Enemy Archetype (Wall Attack)
│
├── SAVE & PERSISTENCE SYSTEM [P0]
│   ├── Versioned Local Save Serializer
│   └── Atomic Write & Backup Recovery
│
└── MULTIPLAYER SYSTEM [P1 — Deferred until M9]
    ├── ENet Session Manager
    ├── Host-Authoritative Command Validation
    └── State Replication

```

# **3\. GAME SYSTEMS SPECIFICATION**

## **3.1 Player System \[P0\]**

* **Responsibilities:** Read local movement (left/right) and interaction inputs, emit gameplay commands/requests, and update local Camera2D without storing authoritative world or economy state.  
* **Scope:** Horizontal movement and basic interaction on Forgotten Shore. Mounted combat and multiple player classes are deferred.

## **3.2 Time & Day/Night System \[P0\]**

* **Provisional Tuning Target:** 12-minute full day cycle:  
  * **Daylight:** 8 minutes  
  * **Sunset (Dusk Warning):** 1 minute  
  * **Night:** 3 minutes  
* **Event-Driven Design:** Emits phase-change signals (day\_started, sunset\_started, night\_started, sunrise\_reached). NPC safety, enemy spawning, lighting, and HUD react to these signals rather than polling raw timers.

## **3.3 Economy & Kingdom Ledger System \[P0\]**

* **MVP Resources:** gold, wood, stone stored as integers in a single kingdom resource ledger. (Iron, Food, Crystal, and Ancient Relics are excluded from MVP).  
* **Conceptual API:**  
  * try\_add(resource\_id: StringName, amount: int) \-\> bool  
  * try\_spend(costs: Dictionary) \-\> bool  
  * get\_amount(resource\_id: StringName) \-\> int  
* **Invariants:**  
  * Balances can never become negative.  
  * Zero, negative, or unknown resource\_id requests are rejected.  
  * Multi-resource purchases (try\_spend) are **all-or-nothing** (atomic).  
  * UI reads the ledger and updates only after confirmed transaction events.

## **3.4 Building & Construction System \[P0\]**

* **First Slice Buildings:**  
  * **Town Center:** Starting kingdom anchor and designated safe zone.  
  * **Wooden Wall:** First defensive construction target (plus optional second structure only after the wall loop works).  
* **Building States:** GHOST/PLACEHOLDER \-\> UNDER\_CONSTRUCTION \-\> COMPLETED \-\> DAMAGED \-\> DESTROYED.  
* **Construction Rules:**  
  * Validate placement bounds before spending resources.  
  * Validate full cost before deducting any resource; deduct once on acceptance.  
  * Construction progress is owned by the simulation layer, not the HUD.  
  * Interrupted work preserves valid progress unless explicitly cancelled.

## **3.5 NPC & Builder Task System \[P0\]**

* **First Slice Roles:** **Villager** and **Builder** only (Farmer, Archer, Knight/Guard are P1).  
* **First Slice States:** IDLE \-\> MOVING\_TO\_TASK \-\> WORKING, plus RETURNING\_TO\_SAFETY, FLEEING, and DISABLED.  
* **Builder Task Priority Policy:**  
  * **Immediate Safety Override:** When the sunset/dusk warning threshold is met, abort optional work and return to the safe area near the Town Center or behind defended walls.  
  * **Repair Critical Defense:** Repair damaged defensive structures.  
  * **Finish Started Construction:** Resume an already-started critical construction task.  
  * **Start New Construction:** Begin a newly funded valid construction task.  
  * **Gather Materials:** Only if gathering tasks are active in the current slice.  
  * **Idle:** Wait at a safe location.  
* **Task Validation:** Before starting or continuing work, verify target existence, work remaining, assignment, work range, reserved resources, and non-cancellation. If invalid, release cleanly and avoid re-pathing every frame.  
* **Safety Failure Handling:** If no safe path exists at dusk, fail safely and emit a debug log/signal rather than silently teleporting.

## **3.6 Combat & First-Night Survival \[P0\]**

* **First Slice Scope:** One basic enemy archetype spawning along one predictable route at night, attacking the Wooden Wall.  
* **Goal:** Verify that preparation and wall construction meaningfully affect survival until sunrise.

## **3.7 Save & Persistence System \[P0\]**

* **Minimum Save Payload:** schema\_version, world\_id/island\_id, world\_time, day\_count, kingdom resource balances, placed building IDs/positions/levels/durability states, NPC IDs/roles/states, and slice progression flags. (Never serialize transient visual nodes or animation frames).  
* **Save Triggers:** Sunrise/day transition after night resolution, major kingdom milestone, manual save, and before exiting session.  
* **Atomic Write & Recovery:**  
  * Serialize to a temporary file and validate completion.  
  * Keep one previous valid backup before swapping the active save.  
  * Validate schema\_version and required fields on load; fall back to backup if primary is corrupted.

## **3.8 Multiplayer System \[P1 — M9\]**

* **Deferred Implementation:** Do not implement ENet, RPCs, lobbies, or room codes in P0.  
* **Target Model:** Host-authoritative simulation where clients send input/command requests and receive replicated state, never trusting client-reported balances, damage, or construction completion.  
* &nbsp;

&nbsp;