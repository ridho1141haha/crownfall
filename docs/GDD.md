# **CROWNFALL: THE LAST LIGHT**

# **GAME DESIGN DOCUMENT (GDD)**

**Document Version:** 1.1 (Synced with Revised Project Baseline)

**Project Type:** 2D Pixel-Art Kingdom Building & Survival Adventure

**Engine:** Godot 4

**Language:** GDScript

**Platform:** Windows PC

**Status:** Pre-production (First Vertical Slice Baseline)

# **1\. GAME OVERVIEW**

## **1.1 Game Description**

**CROWNFALL: THE LAST LIGHT** is a 2D side-scrolling medieval fantasy game combining kingdom building, exploration, survival, and narrative adventure.

Set in the fallen world of **Aetherion**, players control a Monarch who restores settlements, gathers resources, recruits villagers, constructs defensive structures, and survives creatures that emerge after sunset.

**Scope Note (v1.1):** The first playable milestone is a **Single-Player Vertical Slice** on **Forgotten Shore**. Online cooperative multiplayer (1–4 players, independent cameras) remains part of the long-term vision and is scheduled for **M9** after the core single-player loop is proven fun and stable.

## **1.2 Core Pillars**

1. **Build:** Establish and improve a settlement, manage kingdom resources, and construct defenses.  
2. **Explore:** Discover resources, hidden treasures, and traces of the fallen world across islands.  
3. **Prepare and Survive:** Make meaningful preparation decisions before nightfall and defend against enemy waves.

## **1.3 Design Principles**

1. Simple controls, meaningful decisions.  
2. Minimal direct combat; preparation matters more than reaction.  
3. Exploration must reward curiosity.  
4. The environment communicates the story (avoid excessive cutscenes).  
5. UI should remain minimal and driven by authoritative state.  
6. Every resource in the current slice must have a clear purpose.

# **2\. STORY AND LORE (LONG-TERM VISION)**

## **2.1 World: Aetherion**

Aetherion was once protected by **The First Light**, maintaining balance between the human world and the realm of darkness. An event called **The Great Eclipse** caused The First Light to vanish, collapsing kingdoms and unleashing darkness creatures across the islands. Centuries later, the last descendants discover an ancient crown capable of restoring settlements and reconnecting Aetherion to The First Light.

## **2.2 Story Chapters**

| Chapter | Title | Main Objective | Scope |
| :---- | :---- | :---- | :---- |
| I | The Forgotten Shore | Establish the first settlement | **First Vertical Slice** |
| II | The Lost Kingdom | Discover the ancient kingdom | Post-MVP |
| III | Beyond the Forest | Explore new civilizations | Post-MVP |
| IV | The Hollow Crown | Uncover the crown's origin | Post-MVP |
| V | The Last Light | Determine Aetherion's future | Post-MVP |

# **3\. FIRST VERTICAL SLICE GAMEPLAY**

## **3.1 Playable Loop (Forgotten Shore)**

1. Start a new local game on **Forgotten Shore**.  
2. Move the Monarch left and right across the 2D side-scrolling terrain.  
3. Collect **Gold**, **Wood**, and **Stone**.  
4. Recruit a **Villager** and assign/allow **Builder** behavior.  
5. Construct a **Wooden Wall** before sunset.  
6. Survive one night encounter against the basic enemy archetype.  
7. Reach sunrise and preserve the resulting kingdom state.

## **3.2 Economy & Resources**

The first vertical slice uses a **single kingdom resource ledger** with three core resources:

| Resource | MVP Role | Example Uses |
| :---- | :---- | :---- |
| **Gold** | Primary currency | Recruiting villagers and selected construction costs |
| **Wood** | Basic material | Wooden Wall and early structures |
| **Stone** | Durable material | Stone upgrades and later defensive structures |

* **Deferred Resources:** Iron, Food, Crystal, and Ancient Relics are **out of scope** for the first vertical slice.  
* **No Personal Coin Pouch:** Do not implement a 30-coin personal pouch limit or physical coin-drop inventory for the first slice; all transactions go through the unified kingdom ledger.

## **3.3 NPCs & Roles**

* **First Slice (MVP):** Only **Villager** and **Builder** behaviors are active. Builders construct and repair defensive structures and prioritize returning to safety at dusk.  
* **Later Milestones (Post-MVP):** **Farmer**, **Archer**, and **Knight / Guard** will be added once the Builder loop is stable.

## **3.4 World, Day/Night & Enemies**

* **Day/Night Tuning Target:** Provisional 12-minute cycle (**Daylight:** 8 min, **Sunset:** 1 min, **Night:** 3 min) driving phase-change events.  
* **First-Night Enemy:** One basic enemy archetype spawning from a predictable route to test wall defense and preparation.  
* **Win/Loss & Progression:** Surviving until sunrise preserves kingdom state via local save. Multi-island sailing, Blood Moon events, weather simulation, and procedural world generation are deferred to later milestones.

# **4\. DEFERRED MULTIPLAYER CO-OP VISION (M9+)**

* **Capacity:** 1–4 Players online via Host-Authoritative ENet.  
* **Architecture Readiness:** Gameplay state is decoupled from UI and input so a future host can validate commands without rewriting core systems.  
* **Out of Scope for First Slice:** Lobbies, room codes, RPCs, ENet peers, relay services, and host migration.  
* &nbsp;

&nbsp;