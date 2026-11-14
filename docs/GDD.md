# CROWNFALL: THE LAST LIGHT
# GAME DESIGN DOCUMENT (GDD)

**Document Version:** 1.3
**Baseline:** Revised Project Baseline v1.3 & `docs/DECISIONS_M2_M8.md`
**Genre:** 2D Side-Scrolling Kingdom Building, Exploration & Survival
**Engine:** Godot 4
**Language:** GDScript
**Platform Target:** Windows PC
**Status:** Pre-production — Single-Player Vertical Slice

---

## 1. Purpose and Design Scope

This document defines the intended player experience, game pillars, world concept, and first-slice gameplay design for CROWNFALL: THE LAST LIGHT.

The first playable target is a **single-player vertical slice on Forgotten Shore**. It is a focused proof of the core loop, not a complete version of the long-term game and not a complete first story chapter.

Online co-op for up to four players remains a long-term goal and is deferred until M9, after the single-player loop has been validated.

### 1.1 High-Level Description

CROWNFALL is set in Aetherion, a fallen medieval fantasy world. The player controls a Monarch who restores a settlement, gathers resources, recruits villagers, constructs defenses, explores the remains of the world, and prepares for hostile creatures that emerge after sunset.

### 1.2 Design Pillars

1. **Build** — establish and improve a settlement through meaningful resource and construction decisions.
2. **Explore** — traverse forgotten places, discover useful resources, and uncover traces of Aetherion's past.
3. **Prepare and Survive** — use daylight wisely, prepare the settlement, and survive threats after sunset.

Every P0 feature should support at least one pillar. The first slice should demonstrate all three at a small scale without requiring a full quest or narrative framework.

### 1.3 Design Principles

- Simple controls; meaningful decisions.
- Preparation and kingdom development matter more than action-heavy combat.
- Exploration should reward curiosity, but its exact reward loop must be defined before content implementation.
- The environment should communicate history without relying on long cutscenes.
- Gameplay state must remain independent from HUD and visual presentation.
- Every P0 resource and feature must have a clear purpose.
- The first slice should prefer a small number of understandable interactions over a large feature catalogue.

---

## 2. World and Narrative

### 2.1 Aetherion

Aetherion was once protected by **The First Light**, a force that maintained balance between the human world and the realm of darkness.

An event known as **The Great Eclipse** caused the First Light to vanish. Kingdoms collapsed, civilizations were lost, and hostile creatures began spreading across the islands.

The Monarch's journey is tied to an ancient crown and the gradual restoration of settlements. The exact chronology, characters, and narrative reveals remain subject to future story design.

### 2.2 Planned Story Direction

| Chapter | Working Title | Long-Term Direction | Current Status |
|---|---|---|---|
| I | The Forgotten Shore | Establish the first settlement | Vertical-slice location and gameplay proof only |
| II | The Lost Kingdom | Discover the remains of an ancient kingdom | Future |
| III | Beyond the Forest | Explore other regions and civilizations | Future |
| IV | The Hollow Crown | Uncover the crown's origin | Future |
| V | The Last Light | Determine Aetherion's future | Future |

**Scope clarification:** the first vertical slice is not required to contain a complete Chapter I narrative, dialogue system, quest chain, or cinematic story sequence. Its purpose is to prove the settlement and first-night loop.

### 2.3 First Location — Forgotten Shore

Forgotten Shore is the only island required for the first slice.

Its visual and gameplay identity should support:
- A coastal or shoreline setting.
- A traversable side-scrolling environment.
- A ruined or abandoned settlement atmosphere.
- Resource locations that encourage movement through the playable area.
- A clear settlement anchor and a defensible route for the first night.

The exact terrain layout, resource-node placement, and points of interest are content decisions to be finalized during blockout and playtesting.

Other island concepts are long-term worldbuilding, not P0 production requirements.

---

## 3. First Vertical Slice

### 3.1 Intended Player Loop

1. Start a new local game on Forgotten Shore.
2. Move the Monarch left and right through the side-scrolling world.
3. Discover and collect Gold, Wood, and Stone.
4. Recruit at least one Villager.
5. Select a valid location and fund a Wooden Wall construction.
6. Have Builder behavior complete or repair the wall.
7. Prepare as daylight moves into sunset.
8. Survive one basic enemy encounter along one predictable route.
9. Reach sunrise and preserve the resulting kingdom state through local save/load.

The loop should make the relationship between daytime decisions and nighttime consequences understandable.

### 3.2 First-Slice Boundaries

| Area | First-Slice Scope | Deferred |
|---|---|---|
| Players | One local Monarch | Online co-op and multiple player variants |
| Island | Forgotten Shore | Other islands and inactive-island simulation |
| Resources | Gold, Wood, Stone | Iron, Food, Crystal, Ancient Relics |
| NPC | Villager recruitment and Builder behavior | Farmer, Archer, Knight, Guard, mount systems |
| Buildings | Town Center anchor and Wooden Wall | Full building catalogue and upgrade tree |
| Enemies | One basic enemy archetype | Multiple enemy families and bosses |
| Survival | One night encounter and sunrise | Blood Moon and advanced world events |
| Narrative | Environmental atmosphere and world premise | Full dialogue, quests, branching story, chapter framework |
| Persistence | Local versioned save | Cloud saves and multiplayer session persistence |

### 3.3 Resources

The vertical slice uses one kingdom resource ledger.

| Resource | Design Role | First-Slice Use |
|---|---|---|
| Gold | Primary currency | Recruitment and selected construction costs |
| Wood | Basic material | Wooden Wall and early construction |
| Stone | Durable material | Reserved for a defined first-slice use only if the design requires it |

Iron, Food, Crystal, and Ancient Relics are deferred. No personal coin-pouch capacity or complex personal inventory is required in P0.

The exact source, collection interaction, starting quantity, and spending costs for each resource are open design decisions. They must be settled before the relevant economy/building implementation milestone.

### 3.4 Settlement and Construction

- **Town Center:** the starting kingdom anchor and reference point for the settlement's safe area. It may be a fixed starting scene rather than a constructible building.
- **Wooden Wall:** the primary construction target for the first-slice loop.
- **Construction flow:** choose a location, validate placement, validate and deduct cost once, create a blueprint/construction state, let Builder behavior progress it, then mark it completed.
- **Damage and repair:** include only the minimum rules needed to make the first-night defense meaningful.

Additional buildings, building upgrades, and economic infrastructure are deferred until the wall loop is stable.

### 3.5 Villager and Builder Behavior

The first slice requires:
- Recruitment of at least one Villager.
- Basic NPC movement.
- Builder behavior capable of accepting and completing a valid wall construction or repair task.
- A safety response when sunset begins.

The design requirement is **Villager plus Builder behavior**. Whether Builder is represented internally as a profession/assignment, a role, or a separate actor type is not yet locked. Documentation must not imply that this implementation choice has been finalized.

Farmer, Archer, Knight, Guard, and mounted roles are deferred.

### 3.6 Day/Night and First Enemy

The current tuning target is a 12-minute in-game day:

| Phase | Provisional Duration | Intended Function |
|---|---:|---|
| Daylight | 8 minutes | Movement, resource collection, recruitment, construction |
| Sunset | 1 minute | Warning and final preparation |
| Night | 3 minutes | First survival encounter |

These timings are provisional and must be tested.

The first slice uses one basic enemy archetype following one predictable route and attacking the Wooden Wall. Its final appearance, name, health, movement speed, damage, spawn timing, and failure consequences are open design decisions.

### 3.7 Outcome and Persistence

The first-slice goal is to reach sunrise and preserve the resulting kingdom state. The exact consequences of a destroyed wall, an enemy reaching the settlement, NPC loss, or player failure are not yet finalized.

Do not invent a permanent-death or game-over rule in implementation before the failure/recovery design is approved.

---

## 4. Long-Term Multiplayer Vision (M9+)

The long-term target is online co-op for 1–4 players in a shared kingdom.

Design intent:
- Players share kingdom progress and world state.
- Each player has a local camera.
- The host owns authoritative world simulation.
- Clients submit validated actions rather than reporting authoritative balances or outcomes.

Multiplayer implementation is deferred. P0 must not include ENet peers, RPCs, lobbies, room codes, session synchronization, or NetworkManager infrastructure.

The first multiplayer validation target is two peers in an external test. Four-player capacity is a later target, not a proven capability.

---

## 5. Open Design Decisions

The following decisions must be resolved in the relevant design document before implementation depends on them.

| ID | Decision Needed | Needed Before |
|---|---|---|
| GDD-OD-01 | How Gold, Wood, and Stone are found and collected | M3 — Economy |
| GDD-OD-02 | Starting resource quantities, recruitment cost, and recruitment interaction | M3/M5 |
| GDD-OD-03 | Wooden Wall placement rules, cost, duration, footprint, and repair cost | M4 — Building |
| GDD-OD-04 | Whether Builder is an assignment, profession, role, or separate actor type | M5 — NPC |
| GDD-OD-05 | First enemy identity, behavior, tuning, and spawn conditions | M6 — First Night |
| GDD-OD-06 | Consequences of wall destruction, settlement breach, and first-night failure | M6 — First Night |
| GDD-OD-07 | Exact exploration reward or point-of-interest interaction for the slice | Before M8 scope sign-off |
| GDD-OD-08 | Which persistent NPC attributes and states are necessary | M7 — Save/Load |

An open decision is not an implementation requirement. Record the decision and rationale when it is approved; do not silently fill gaps with assumptions.

---

## 6. Design Validation

Playtesting should answer:
- Can a new player understand the movement and interaction loop?
- Are resource sources and resource purposes obvious?
- Does the player understand why and when to build the wall?
- Is Builder behavior predictable and useful?
- Does sunset create meaningful preparation pressure?
- Does the first enemy make the wall and preparation matter?
- Does exploration give a reason to move across Forgotten Shore?
- Can the player understand the outcome at sunrise?

Balance values remain provisional until tested in the actual game.

---

## 7. Scope Change Rules

A proposed change that affects the first slice must state:
1. The player benefit.
2. Which design pillar it supports.
3. Its P0/P1/P2 priority.
4. Dependencies and production impact.
5. How it will be tested.
6. Which documents must be updated.

The Revised Project Baseline defines approved cross-project scope. This GDD owns player-facing design and narrative intent; SYSTEMS owns concrete gameplay rules and state transitions.

---

**END OF GDD**

Project: CROWNFALL: THE LAST LIGHT  
Document: GDD.md  
Version: 1.2


---

> **v1.3 Synchronization Note:** All P0 vertical-slice open decisions (`OD-01` through `OD-10`) referenced in this document have been formally resolved and approved in [`docs/DECISIONS_M2_M8.md`](DECISIONS_M2_M8.md).
