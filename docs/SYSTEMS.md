# CROWNFALL: THE LAST LIGHT
# GAME SYSTEMS SPECIFICATION

**Document Version:** 1.0  
**Document:** SYSTEMS.md  
**Engine:** Godot 4  
**Status:** Pre-production

---

# 1. PURPOSE

This document defines the behavior, responsibilities, inputs, outputs, dependencies, and validation rules of every major game system.

It serves as the implementation reference for developers and AI coding agents.

The TDD describes how the project is architected.

This document describes how each gameplay system must behave.

## System Priority

| Priority | Meaning |
|---|---|
| P0 | Required for MVP |
| P1 | Required for initial content expansion |
| P2 | Future development |

---

# 2. SYSTEM DEPENDENCY MAP

```text
GAME SESSION
│
├── PLAYER SYSTEM [P0]
│   ├── Movement
│   ├── Camera
│   ├── Interaction
│   └── Player State
│
├── WORLD SYSTEM [P0]
│   ├── World Manager
│   ├── Island Manager
│   ├── Time Manager
│   └── Environment
│
├── KINGDOM SYSTEM [P0]
│   ├── Building Manager
│   ├── Population Manager
│   └── Kingdom Progression
│
├── ECONOMY SYSTEM [P0]
│   ├── Treasury
│   ├── Inventory
│   └── Transactions
│
├── NPC SYSTEM [P0]
│   ├── Villager
│   ├── Farmer
│   └── Archer
│
├── SURVIVAL SYSTEM [P0]
│   ├── Enemy Manager
│   ├── Wave Manager
│   └── Defense
│
├── MULTIPLAYER SYSTEM [P0]
│   ├── Session
│   ├── Player Sync
│   ├── World Sync
│   └── RPC Validation
│
├── NARRATIVE SYSTEM [P0]
│   ├── Quest
│   ├── Dialogue
│   └── Story Progress
│
└── SAVE SYSTEM [P0]
    ├── Serialization
    ├── Loading
    └── Recovery
```

---

# 3. PLAYER SYSTEM

**Priority:** P0

## 3.1 Purpose

Controls the player character and provides movement, interaction, and gameplay input.

## 3.2 Components

- PlayerController.
- PlayerStateMachine.
- PlayerInteraction.
- PlayerAnimation.
- PlayerCamera.
- PlayerStats.

## 3.3 Movement

Supported movement:
- Move left.
- Move right.
- Stop.
- Ride mount.

Initial movement values:

| Parameter | Value |
|---|---:|
| Walk Speed | 110 px/s |
| Run Speed | 160 px/s |
| Acceleration | 600 px/s² |
| Deceleration | 800 px/s² |

Movement must be horizontal for the initial side-scrolling implementation.

## 3.4 Player States

| State | Description |
|---|---|
| IDLE | No movement |
| WALKING | Horizontal movement |
| RUNNING | Faster movement |
| INTERACTING | Performing interaction |
| BUILDING | Performing construction interaction |
| RIDING | Mounted movement |
| DAMAGED | Receiving damage |
| DEAD | Player death state |

## 3.5 Interaction Rules

When the player presses Interact:

1. Detect valid interaction targets.
2. Prioritize the closest valid target.
3. Check interaction conditions.
4. Send request to host if world state changes.
5. Receive validation result.
6. Play the appropriate animation.
7. Update UI.

The client must not directly modify authoritative world state.

## 3.6 Acceptance Criteria

- Movement works in both directions.
- Movement stops correctly.
- Animation matches movement.
- Camera follows the local player.
- Remote players do not activate local cameras.
- Invalid interactions are rejected.

---

# 4. CAMERA SYSTEM

**Priority:** P0

## 4.1 Purpose

Provides an independent view for each player.

## 4.2 Rules

- One active gameplay camera per client.
- Camera follows the local player.
- Remote player cameras remain inactive.
- Camera respects island boundaries.
- Camera position is not authoritative.
- Camera smoothing must not introduce excessive input delay.

## 4.3 Independent Camera Behavior

Example:

Player A travels west.

Player B travels east.

Both players see different portions of the same shared world.

Both remain synchronized through the host.

## 4.4 Acceptance Criteria

- Two clients can view different areas.
- Camera follows the correct player.
- Camera does not switch to a remote player.
- Camera remains inside island limits.

---

# 5. WORLD SYSTEM

**Priority:** P0

## 5.1 Purpose

Controls island loading, environment state, world time, and exploration progression.

## 5.2 Components

- WorldManager.
- IslandManager.
- TravelManager.
- TimeManager.
- WorldStateManager.

## 5.3 Island Definition

Every island must contain:

- Island ID.
- Name.
- Biome.
- World seed.
- Unlock status.
- Resource definitions.
- Spawn locations.
- Building locations.
- Enemy spawn locations.
- Story flags.

## 5.4 Island States

```text
LOCKED
  |
  v
UNLOCKED
  |
  v
AVAILABLE
  |
  v
ACTIVE
  |
  v
INACTIVE
```

## 5.5 Island Travel

MVP:
- Players travel together.
- Host initiates travel.
- All connected players are transferred.
- Destination island state is loaded.
- Player spawn positions are restored.
- Previous island state is saved.

Future:
- Independent player island travel.
- Background island simulation.

## 5.6 Acceptance Criteria

- Forgotten Shore loads correctly.
- Island ID remains consistent.
- Island boundaries are enforced.
- Island state survives scene transitions.
- Invalid island travel is rejected.

---

# 6. DAY/NIGHT SYSTEM

**Priority:** P0

## 6.1 Purpose

Controls the world clock and schedules survival events.

## 6.2 Initial Timing

| Phase | Duration |
|---|---:|
| Morning/Day | 8 minutes |
| Sunset | 1 minute |
| Night | 3 minutes |

Total: 12 minutes.

## 6.3 State Flow

```text
MORNING
   |
   v
AFTERNOON
   |
   v
SUNSET
   |
   v
NIGHT
   |
   v
NEXT MORNING
```

## 6.4 Behavior

Morning:
- Villagers begin working.
- Daytime ambience plays.

Afternoon:
- Players explore.
- Buildings can be constructed.
- Resources are collected.

Sunset:
- Lighting changes.
- Warning notifications appear.
- Villagers return to safe areas.

Night:
- Enemy spawning is enabled.
- Defense systems become active.
- Night ambience and music change.

## 6.5 Multiplayer Rules

- Host owns world time.
- Clients receive time state.
- All clients display the same phase.
- Enemy spawning follows host time.

## 6.6 Acceptance Criteria

- Time progresses consistently.
- Phase transitions trigger once.
- No duplicate enemy waves.
- All clients display synchronized phases.

---

# 7. ECONOMY SYSTEM

**Priority:** P0

## 7.1 Purpose

Manages shared kingdom resources and transactions.

## 7.2 Resources

MVP resources:

| Resource | Description |
|---|---|
| Gold | Primary currency |
| Wood | Basic construction |
| Stone | Defensive upgrades |

Future resources:
- Iron.
- Food.
- Crystal.

## 7.3 Economy Components

- EconomyManager.
- Treasury.
- ResourceInventory.
- TransactionValidator.
- RewardProcessor.

## 7.4 Transaction Flow

```text
ACTION REQUEST
     |
     v
VALIDATE SENDER
     |
     v
VALIDATE RESOURCE
     |
     v
VALIDATE COST
     |
     v
EXECUTE TRANSACTION
     |
     v
UPDATE SHARED STATE
     |
     v
REPLICATE RESULT
```

## 7.5 Rules

- Shared treasury.
- No negative balances.
- Host validates every transaction.
- Transactions have unique IDs.
- Duplicate requests are rejected.
- Invalid requests do not change inventory.

## 7.6 Acceptance Criteria

- Resources can be collected.
- Resources can be spent.
- Invalid purchases are rejected.
- All clients see consistent balances.
- Duplicate requests cannot charge twice.

---

# 8. RESOURCE COLLECTION SYSTEM

**Priority:** P0

## 8.1 Purpose

Allows players and NPCs to gather resources.

## 8.2 Resource Sources

MVP:
- Tree.
- Rock.
- Treasure chest.

Future:
- Farm.
- Fishing.
- Hunting.
- Trading.

## 8.3 Collection Flow

1. Detect resource node.
2. Validate distance.
3. Validate resource availability.
4. Start gathering interaction.
5. Apply gathering duration.
6. Host updates resource count.
7. Notify all clients.
8. Update node visual state.

## 8.4 Resource Node States

```text
AVAILABLE
   |
   v
BEING_COLLECTED
   |
   v
DEPLETED
   |
   v
REGENERATING
```

Resource regeneration is optional and must be configured per resource type.

---

# 9. BUILDING SYSTEM

**Priority:** P0

## 9.1 Purpose

Allows players to establish and upgrade kingdom structures.

## 9.2 MVP Buildings

| Building | Main Function |
|---|---|
| Town Center | Kingdom progression |
| Wooden Wall | Basic defense |
| Watchtower | Defensive support |
| Farm | Food production placeholder / future |
| Workshop | Construction support |
| Storage | Resource management |

## 9.3 Building States

```text
UNBUILT
   |
   v
AVAILABLE
   |
   v
CONSTRUCTION
   |
   v
COMPLETED
   |
   v
UPGRADED
   |
   v
DAMAGED
   |
   v
DESTROYED
```

## 9.4 Construction Rules

- Building locations must be valid.
- Costs must be checked.
- Host approves placement.
- Resource deduction occurs once.
- Construction duration is host-controlled.
- Construction state is synchronized.
- Building ID is unique and persistent.

## 9.5 Building Upgrade

Upgrade conditions:
- Existing building is completed.
- Required resources are available.
- Maximum level has not been reached.
- Host approves the transaction.

## 9.6 Acceptance Criteria

- Valid construction succeeds.
- Invalid construction fails.
- Costs are deducted once.
- All clients see identical structures.
- Construction progress survives save/load.

---

# 10. NPC SYSTEM

**Priority:** P0

## 10.1 Purpose

Provides the population required for economy and defense.

## 10.2 NPC Types

### Villager
- Basic population.
- Can receive jobs.
- Returns to safe locations at night.

### Farmer
- Assigned to farms.
- Produces food in future content.

### Archer
- Provides ranged defense.
- Participates in hunting and night protection.

## 10.3 NPC State Machine

```text
IDLE
  |
  v
ASSIGNED
  |
  v
MOVING
  |
  v
WORKING
  |
  +---- RETURNING
  +---- FLEEING
  +---- DAMAGED
  +---- DEAD
```

## 10.4 Rules

- Host controls NPC AI.
- NPCs require valid job assignments.
- NPCs cannot execute incompatible states simultaneously.
- NPCs must respond to night events.
- NPC population must be tracked.
- NPC state must be saved.

## 10.5 Acceptance Criteria

- NPCs spawn correctly.
- NPCs can receive assignments.
- NPCs move toward work locations.
- NPCs react to night events.
- NPC state is synchronized.

---

# 11. ENEMY SYSTEM

**Priority:** P0

## 11.1 Purpose

Creates survival threats that challenge kingdom development.

## 11.2 Enemy Types

| Enemy | Role | Priority |
|---|---|---|
| Greedling | Basic attacker and coin thief | P0 |
| Crawler | Fast attacker | P0 |
| Brute | Heavy attacker | P0 |
| Night Herald | Special event enemy | P2 |

## 11.3 Enemy State Machine

```text
IDLE
  |
  v
SPAWNED
  |
  v
APPROACHING
  |
  v
ATTACKING
  |
  +---- DAMAGED
  |
  +---- STUNNED
  |
  +---- DEAD
```

## 11.4 Enemy Rules

- Host controls spawning.
- Host controls target selection.
- Host calculates damage.
- Clients receive enemy state.
- Enemy count is limited.
- Enemy cleanup must prevent node accumulation.

## 11.5 Difficulty Scaling

Difficulty can depend on:
- Current day.
- Kingdom progression.
- Player count.
- Story progression.
- Active island.

Avoid aggressive scaling during early gameplay.

---

# 12. DEFENSE SYSTEM

**Priority:** P0

## 12.1 Purpose

Allows kingdoms to survive nighttime attacks.

## 12.2 Defensive Components

- Walls.
- Gates.
- Watchtowers.
- Archers.
- Defensive positions.

## 12.3 Defense Rules

- Walls block or delay enemies.
- Damaged structures can be repaired.
- Enemies can attack defensive structures.
- NPC defenders must have valid positions.
- Destruction events are synchronized.

## 12.4 Acceptance Criteria

- Enemies can approach defenses.
- Walls receive damage.
- Defenders can attack valid enemies.
- Destroyed defenses update on all clients.

---

# 13. POPULATION SYSTEM

**Priority:** P0

## 13.1 Purpose

Tracks kingdom population and available workforce.

## 13.2 Population Data

- Total villagers.
- Available villagers.
- Assigned workers.
- Farmers.
- Archers.
- Dead villagers.

## 13.3 Rules

- A villager can have one primary job.
- Assignment must be validated.
- Dead villagers are removed from active population.
- Population updates are host-authoritative.
- Population is stored in save data.

---

# 14. INVENTORY SYSTEM

**Priority:** P0

## 14.1 Purpose

Manages shared kingdom materials and player-specific carried items.

## 14.2 Inventory Types

**Kingdom Inventory**
- Gold.
- Wood.
- Stone.
- Other shared materials.

**Player Inventory**
- Quest items.
- Special artifacts.
- Personal equipment, if introduced.

## 14.3 Rules

- Shared and personal inventory must remain separate.
- All authoritative inventory changes are host-validated.
- Item IDs must remain stable.
- Inventory changes must be saved.

---

# 15. QUEST SYSTEM

**Priority:** P0

## 15.1 Purpose

Tracks story and optional objectives.

## 15.2 Quest Categories

- Main Quest.
- Side Quest.
- Exploration Quest.
- Collection Quest.
- Construction Quest.

## 15.3 Quest States

```text
LOCKED
  |
  v
AVAILABLE
  |
  v
ACTIVE
  |
  v
COMPLETED
  |
  v
REWARDED
```

## 15.4 MVP Quests

1. The First Settlement.
2. Gather the Wood.
3. Raise the Walls.
4. The First Night.
5. Beyond the Shore.

## 15.5 Rules

- Shared campaign quest progression.
- Host validates objectives.
- Rewards are distributed once.
- Quest state is saved.
- Completed quests cannot be rewarded repeatedly.

---

# 16. DIALOGUE SYSTEM

**Priority:** P0

## 16.1 Purpose

Provides NPC interactions and narrative delivery.

## 16.2 Features

- Dialogue text.
- Speaker name.
- Dialogue choices.
- Story conditions.
- Quest triggers.
- Dialogue completion flags.

## 16.3 Rules

- Dialogue content is data-driven.
- Dialogue progression is client-side presentation.
- Story-changing choices are host-validated.
- Shared story decisions are synchronized.

---

# 17. SAVE SYSTEM

**Priority:** P0

## 17.1 Purpose

Preserves player and kingdom progression.

## 17.2 Data to Save

- Session ID.
- Player state.
- World time.
- Island state.
- Kingdom resources.
- Building states.
- NPC states.
- Quest progress.
- Unlocks.

## 17.3 Save Triggers

- Periodic autosave.
- Island transitions.
- Quest completion.
- Important kingdom milestones.
- Manual save where supported.

## 17.4 Rules

- Host owns multiplayer save.
- Save version is required.
- Validate data before loading.
- Maintain backup recovery.
- Avoid saving transient visual effects.

---

# 18. MULTIPLAYER SYSTEM

**Priority:** P0

## 18.1 Purpose

Connects players into a shared cooperative game session.

## 18.2 Components

- NetworkManager.
- SessionManager.
- PlayerSpawner.
- StateReplicator.
- RPCValidator.

## 18.3 Required Features

- Host session creation.
- Client connection.
- Player ID assignment.
- Player spawning.
- Player synchronization.
- Shared economy.
- Shared building.
- NPC synchronization.
- Enemy synchronization.
- Disconnect handling.

## 18.4 Connection States

```text
DISCONNECTED
    |
    v
CONNECTING
    |
    v
CONNECTED
    |
    v
IN_SESSION
    |
    v
DISCONNECTED
```

## 18.5 Rules

- Host is authoritative.
- Clients cannot create arbitrary world state.
- Critical requests use reliable delivery.
- Movement updates can use optimized delivery.
- Disconnections must not corrupt the world.
- Invalid peers must be rejected.

---

# 19. UI SYSTEM

**Priority:** P0

## 19.1 HUD

Displays:
- Gold.
- Resources.
- Day.
- Time phase.
- Quest notification.
- Player indicators.

## 19.2 Main Menu

- New Game.
- Continue.
- Multiplayer.
- Settings.
- Credits.

## 19.3 Multiplayer Lobby

- Create Room.
- Join Room.
- Room Code.
- Player List.
- Ready State.
- Start Game.

## 19.4 UI Rules

- UI is client-side.
- Gameplay validation remains on host.
- UI must reflect confirmed state.
- UI must not directly modify authoritative economy.

---

# 20. AUDIO SYSTEM

**Priority:** P1

Responsibilities:
- Background music.
- Ambient audio.
- Sound effects.
- Dynamic music states.
- Volume settings.

Audio state can respond to:
- Time phase.
- Biome.
- Combat events.
- Story events.

---

# 21. MOUNT SYSTEM

**Priority:** P1

MVP:
- One horse.

Features:
- Mount.
- Dismount.
- Riding animation.
- Movement speed adjustment.
- Stamina placeholder.

Future:
- Multiple mount types.
- Special mount abilities.
- Biome-specific mounts.

---

# 22. SYSTEM COMMUNICATION RULES

Systems should communicate through explicit interfaces, signals, or validated manager methods.

Examples:

| Event | Publisher | Subscriber |
|---|---|---|
| PlayerMoved | Player | Animation, Camera |
| ResourceCollected | Economy | HUD, Quest |
| BuildingCompleted | Building | Kingdom, Quest |
| NightStarted | Time | Survival, Audio, NPC |
| EnemyDefeated | Enemy | Economy, Quest |
| QuestCompleted | Quest | Story, UI |
| IslandChanged | World | Camera, Save, UI |

Do not create circular dependencies.

Do not let UI scripts own gameplay logic.

---

# 23. SYSTEM DEVELOPMENT RULES

Every new system must include:

1. System purpose.
2. Required scenes.
3. Required scripts.
4. Data dependencies.
5. Authority rules.
6. State definitions.
7. Signals or RPC methods.
8. Acceptance criteria.
9. Testing procedure.
10. Documentation updates.

A system is not complete merely because its scripts have been created.

It must be integrated and runtime-tested.

---

# 24. IMPLEMENTATION STATUS

| System | Priority | Status |
|---|---|---|
| Player | P0 | Planned |
| Camera | P0 | Planned |
| World | P0 | Planned |
| Economy | P0 | Planned |
| Resources | P0 | Planned |
| Building | P0 | Planned |
| NPC | P0 | Planned |
| Survival | P0 | Planned |
| Enemy | P0 | Planned |
| Defense | P0 | Planned |
| Population | P0 | Planned |
| Inventory | P0 | Planned |
| Quest | P0 | Planned |
| Dialogue | P0 | Planned |
| Save | P0 | Planned |
| Multiplayer | P0 | Planned |
| UI | P0 | Planned |
| Audio | P1 | Planned |
| Mount | P1 | Planned |
| Advanced Island Simulation | P2 | Planned |

---

**END OF SYSTEMS SPECIFICATION**

Project: CROWNFALL: THE LAST LIGHT  
Document: SYSTEMS.md  
Version: 1.0