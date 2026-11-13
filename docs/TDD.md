# CROWNFALL: THE LAST LIGHT
# TECHNICAL DESIGN DOCUMENT (TDD)

**Document Version:** 1.0  
**Engine:** Godot 4  
**Language:** GDScript  
**Architecture:** Modular, Host-Authoritative  
**Platform:** Windows PC  
**Status:** Pre-production

---

# 1. TECHNICAL OVERVIEW

## 1.1 Objective

This document defines the technical architecture, project organization, game systems implementation, multiplayer communication, data management, and development standards for CROWNFALL: THE LAST LIGHT.

The project must remain modular, maintainable, testable, and suitable for solo development with AI assistance.

## 1.2 Technical Decisions

| Component | Decision |
|---|---|
| Engine | Godot 4 |
| Language | GDScript |
| Rendering | Godot 2D |
| Physics | CharacterBody2D |
| Networking | ENet |
| Multiplayer Model | Host-authoritative |
| Camera | Local Camera2D |
| World | Separate island scenes |
| Data | Custom Resource + JSON |
| Save | Versioned save serializer |
| Version Control | Git |
| Target OS | Windows |

Use the latest stable Godot 4 release available at project initialization. Record the exact engine version in project documentation and avoid mixing incompatible versions.

---

# 2. ARCHITECTURE OVERVIEW

## 2.1 Architecture Layers

### Presentation Layer
Responsible for:
- Camera.
- Animation.
- HUD.
- Menus.
- Effects.
- Audio presentation.

### Gameplay Layer
Responsible for:
- Player movement.
- Interactions.
- Building.
- Resource collection.
- NPC behavior.
- Enemy behavior.

### World Layer
Responsible for:
- Island management.
- Terrain.
- Environment.
- Day/night cycle.
- World progression.

### Economy Layer
Responsible for:
- Treasury.
- Resource inventory.
- Transactions.
- Trading.
- Rewards.

### Networking Layer
Responsible for:
- Session creation.
- Peer connections.
- Player identification.
- RPC communication.
- World state replication.

### Persistence Layer
Responsible for:
- Serialization.
- Save files.
- Loading.
- Save version migration.

### Narrative Layer
Responsible for:
- Quest progression.
- Dialogue.
- Story events.
- Story flags.

---

# 3. PROJECT DIRECTORY

```text
CROWNFALL/
│
├── project.godot
│
├── assets/
│   ├── characters/
│   ├── enemies/
│   ├── environment/
│   ├── buildings/
│   ├── items/
│   ├── mounts/
│   ├── effects/
│   ├── ui/
│   └── audio/
│
├── scenes/
│   ├── main/
│   ├── world/
│   │   ├── islands/
│   │   └── environment/
│   ├── player/
│   ├── npc/
│   ├── enemies/
│   ├── buildings/
│   ├── multiplayer/
│   └── ui/
│
├── scripts/
│   ├── core/
│   ├── player/
│   ├── world/
│   ├── kingdom/
│   ├── economy/
│   ├── npc/
│   ├── survival/
│   ├── networking/
│   ├── narrative/
│   ├── save/
│   └── ui/
│
├── resources/
│   ├── buildings/
│   ├── items/
│   ├── enemies/
│   ├── islands/
│   └── quests/
│
├── data/
│   ├── balance/
│   ├── localization/
│   └── world/
│
├── shaders/
│
├── tests/
│
└── docs/
    ├── README.md
    ├── GDD.md
    ├── TDD.md
    ├── SYSTEMS.md
    ├── PRD.md
    ├── ASSET_GUIDELINES.md
    └── CHANGELOG.md
```

All production scripts must be stored in their appropriate directories.

Do not create duplicate manager scripts or alternate implementations without architectural approval.

---

# 4. AUTOLOAD CONFIGURATION

The following Autoloads are approved.

| Singleton | Script | Responsibility |
|---|---|---|
| GameManager | game_manager.gd | Global game state |
| NetworkManager | network_manager.gd | Network sessions |
| EventBus | event_bus.gd | Global signals |
| SaveManager | save_manager.gd | Save/load |
| SceneManager | scene_manager.gd | Scene transitions |
| AudioManager | audio_manager.gd | Audio control |

Other systems should be owned by GameSession or WorldRoot.

Avoid excessive global state.

---

# 5. SCENE ARCHITECTURE

## 5.1 Main Scene

```text
MainMenu
├── Background
├── Title
├── MenuButtons
├── Settings
└── VersionLabel
```

## 5.2 Game Session

```text
GameSession
├── WorldRoot
│   ├── ActiveIslands
│   ├── WorldEnvironment
│   └── WorldManagers
│
├── Players
│
├── UI
│   ├── HUD
│   ├── Notifications
│   └── Menus
│
└── MultiplayerSpawner
```

## 5.3 Player Scene

```text
Player
├── Sprite
├── AnimationPlayer
├── CollisionShape2D
├── InteractionArea
├── Camera2D
└── PlayerAudio
```

Player movement logic and camera logic must remain separate.

---

# 6. PLAYER ARCHITECTURE

## 6.1 Player Controller

Base class:

`CharacterBody2D`

Responsibilities:
- Read local input.
- Send movement intent.
- Apply authorized movement.
- Handle interactions.
- Trigger animation states.

## 6.2 Movement Parameters

Initial tuning values:

| Parameter | Value |
|---|---:|
| Walk Speed | 110 px/s |
| Run Speed | 160 px/s |
| Acceleration | 600 px/s² |
| Deceleration | 800 px/s² |
| Jump | Disabled |

All values should be configurable through centralized balance resources.

## 6.3 Player State Machine

States:

```text
IDLE
WALKING
RUNNING
INTERACTING
BUILDING
RIDING
DAMAGED
DEAD
```

Use a finite state machine or equivalent explicit state architecture.

Do not allow incompatible actions to execute simultaneously.

---

# 7. CAMERA ARCHITECTURE

## 7.1 Design

Each client has one local camera following its locally controlled player.

Remote players must not activate additional cameras.

## 7.2 Rules

- Camera is client-side.
- Camera does not control gameplay authority.
- Camera follows the local player.
- Camera respects island boundaries.
- Camera supports smooth horizontal movement.
- Camera position is not replicated as authoritative game state.

## 7.3 Implementation Concept

```gdscript
extends Camera2D

@export var follow_target: Node2D
@export var follow_speed: float = 6.0

func _process(delta: float) -> void:
    if follow_target == null:
        return

    global_position = global_position.lerp(
        follow_target.global_position,
        1.0 - exp(-follow_speed * delta)
    )
```

Only enable the camera belonging to the local player.

---

# 8. WORLD ARCHITECTURE

## 8.1 World Manager

Responsibilities:
- Load active island.
- Maintain island identity.
- Track world state.
- Handle island transitions.
- Coordinate world managers.

## 8.2 Island Manager

Responsibilities:
- Island loading.
- Island unloading.
- Island metadata.
- Island unlock status.
- Island state persistence.

## 8.3 Island Data

Use a custom Resource.

```gdscript
class_name IslandData
extends Resource

@export var island_id: String
@export var island_name: String
@export var biome: String
@export var is_unlocked: bool = false
@export var world_seed: int = 0
@export var day_number: int = 1
@export var resources: Dictionary = {}
```

Island runtime state must be separated from immutable island definitions.

## 8.4 World Simulation

MVP:
- One active island.
- Shared world time.
- Shared NPC simulation.
- Shared enemy simulation.

Future:
- Multiple independently simulated islands.
- Background island progression.
- Independent island events.

Do not implement background simulation in the MVP.

---

# 9. MULTIPLAYER ARCHITECTURE

## 9.1 Network Model

Use host-authoritative networking.

The host is responsible for authoritative world state.

Clients send requests and receive validated results.

## 9.2 Network Components

- ENetMultiplayerPeer.
- MultiplayerAPI.
- MultiplayerSpawner.
- MultiplayerSynchronizer.
- RPC methods.

## 9.3 Session Flow

```text
CREATE SESSION
      |
      v
HOST STARTS ENET
      |
      v
CLIENT CONNECTS
      |
      v
HOST VALIDATES CONNECTION
      |
      v
PLAYER ID ASSIGNED
      |
      v
PLAYER SPAWNED
      |
      v
WORLD STATE SYNCHRONIZED
```

## 9.4 Network Authority

| System | Authority |
|---|---|
| Input | Local Client |
| Player Simulation | Host |
| Economy | Host |
| Building | Host |
| NPC AI | Host |
| Enemy AI | Host |
| Damage | Host |
| World Clock | Host |
| Quest Progress | Host |
| Island State | Host |
| Camera | Local Client |
| UI | Local Client |

## 9.5 RPC Rules

All gameplay-changing RPC requests must:

1. Verify the sender.
2. Verify the request format.
3. Validate resource availability.
4. Validate the target.
5. Validate ownership and permissions.
6. Prevent duplicate requests.
7. Return a success or rejection result.

Use reliable RPC for critical transactions and events.

Use unreliable or unreliable-ordered delivery only for suitable high-frequency state updates.

## 9.6 Player Movement Synchronization

For MVP:
- Local client reads movement input.
- Input is transmitted to the host.
- Host validates and simulates movement.
- Host replicates position and movement state.
- Remote clients interpolate received state.

Avoid trusting arbitrary client-supplied positions.

## 9.7 Network Security

- Validate all client requests.
- Limit request frequency.
- Reject invalid resource transactions.
- Prevent duplicate transaction IDs.
- Validate object identifiers.
- Never trust client-side enemy damage.
- Never trust client-side economy state.

## 9.8 Multiplayer MVP Limitations

- Host-based sessions.
- One active island.
- No host migration.
- No public matchmaking.
- No dedicated servers.
- No persistent cloud saves.

---

# 10. ECONOMY ARCHITECTURE

## 10.1 Economy Manager

Responsibilities:
- Treasury.
- Resource inventory.
- Transactions.
- Rewards.
- Trading.

## 10.2 Transaction Rules

Every transaction must:
- Have a unique transaction ID.
- Be validated by host.
- Be atomic.
- Prevent negative balances.
- Return a transaction result.

## 10.3 Resource Definition

Use Resource-based definitions.

```gdscript
class_name ItemData
extends Resource

@export var item_id: String
@export var display_name: String
@export var max_stack: int = 999
@export var icon: Texture2D
```

Avoid using display names as identifiers.

---

# 11. BUILDING ARCHITECTURE

## 11.1 Building Data

```gdscript
class_name BuildingData
extends Resource

@export var building_id: String
@export var display_name: String

@export var gold_cost: int
@export var wood_cost: int
@export var stone_cost: int

@export var build_duration: float
@export var max_level: int = 3

@export var scene: PackedScene
```

## 11.2 Construction Pipeline

```text
PLAYER INTERACTION
       |
       v
BUILD REQUEST
       |
       v
HOST VALIDATION
       |
       v
RESOURCE CHECK
       |
       v
TRANSACTION
       |
       v
BUILDING SPAWN
       |
       v
CONSTRUCTION PROGRESS
       |
       v
BUILDING COMPLETE
```

## 11.3 Building Identity

Every placed building must have a persistent unique ID.

Do not use scene node names as permanent identifiers.

---

# 12. NPC ARCHITECTURE

## 12.1 NPC Controller

Base class:

`CharacterBody2D`

Responsibilities:
- Movement.
- Job state.
- Interaction.
- Animation.
- Health.
- Survival behavior.

## 12.2 NPC State Machine

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

## 12.3 NPC Authority

NPC simulation runs on the host.

Clients receive synchronized visual state.

## 12.4 Performance

- Use behavior update intervals.
- Avoid expensive per-frame searches.
- Use simple movement targets.
- Use object pooling where beneficial.
- Profile AI before increasing NPC counts.

---

# 13. SURVIVAL ARCHITECTURE

## 13.1 Time Manager

The host controls the world clock.

Initial values:

| Phase | Duration |
|---|---:|
| Morning/Day | 8 minutes |
| Sunset | 1 minute |
| Night | 3 minutes |

Total: 12 minutes.

## 13.2 Time State

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

## 13.3 Enemy Manager

Responsibilities:
- Spawn conditions.
- Spawn locations.
- Difficulty scaling.
- Enemy limits.
- Wave events.
- Enemy cleanup.

Host controls all enemy simulation.

---

# 14. SAVE SYSTEM

## 14.1 Save Structure

```text
SaveData
├── Version
├── SessionID
├── WorldSeed
├── PlayerData
├── KingdomData
├── EconomyData
├── WorldTime
├── IslandStates
├── BuildingStates
├── NPCStates
├── QuestProgress
└── UnlockedContent
```

## 14.2 Persistence Rules

- Host saves the session.
- Save at important progression events.
- Support periodic autosave.
- Store stable unique identifiers.
- Include save version.
- Validate data during loading.
- Maintain backup recovery.

## 14.3 Save Security

Client-side save data must not override authoritative multiplayer state.

Cloud synchronization is future scope.

---

# 15. NARRATIVE ARCHITECTURE

Systems:

- QuestManager.
- DialogueManager.
- StoryManager.

Quest definitions must be data-driven.

Example:

```json
{
  "quest_id": "FS_001",
  "title": "The Forgotten Shore",
  "objectives": [
    {
      "type": "collect",
      "target": "wood",
      "amount": 20
    },
    {
      "type": "build",
      "target": "town_center",
      "amount": 1
    }
  ],
  "reward": {
    "gold": 50
  }
}
```

Host validates shared quest progression and distributes rewards.

---

# 16. RENDERING & PERFORMANCE

## 16.1 Rendering Configuration

- 2D renderer.
- Nearest texture filtering.
- Consistent pixel density.
- Pixel snapping where appropriate.
- Controlled lighting.
- Parallax backgrounds.
- Modular TileMapLayer scenes.

## 16.2 Performance Targets

| Metric | Target |
|---|---:|
| FPS | 60 |
| Players | 4 |
| NPCs | 50–100 |
| Enemies | 20–40 |
| Network Tick | 20–30 Hz |

Targets require profiling on actual hardware.

## 16.3 Optimization Rules

- Avoid excessive scene instantiation.
- Avoid unnecessary node processing.
- Avoid per-frame resource searches.
- Use signals appropriately.
- Use object pooling selectively.
- Avoid excessive dynamic lighting.
- Avoid synchronizing static data.
- Use event-based replication.

---

# 17. TESTING ARCHITECTURE

Test categories:

**Unit Tests**
- Economy.
- Resource transactions.
- Building costs.
- Quest conditions.

**Integration Tests**
- Building and economy.
- NPC and survival.
- World and island loading.
- Save and load.

**Multiplayer Tests**
- Host creation.
- Client connection.
- Player synchronization.
- Shared economy.
- Building synchronization.
- Enemy synchronization.
- Disconnect handling.

**Performance Tests**
- NPC load.
- Enemy load.
- Scene transitions.
- Network traffic.
- Memory usage.

---

# 18. IMPLEMENTATION ORDER

1. Project Foundation.
2. Player Controller.
3. Independent Camera.
4. WorldRoot.
5. Forgotten Shore.
6. Economy.
7. Building.
8. NPC.
9. Day/Night.
10. Enemy AI.
11. Multiplayer.
12. Island Travel.
13. Narrative.
14. Save/Load.
15. Polish.

Multiplayer architecture must be prepared early, even though full online gameplay is implemented after the core single-player mechanics.

---

# 19. ENGINEERING RULES

1. Use explicit dependencies.
2. Keep systems modular.
3. Avoid circular dependencies.
4. Use typed GDScript where practical.
5. Use custom Resources for definitions.
6. Use signals for decoupled communication.
7. Use stable IDs for persistent entities.
8. Separate local presentation from authoritative simulation.
9. Do not mix UI logic with gameplay rules.
10. Test every system before integration.
11. Maintain CHANGELOG.md.
12. Document architecture changes.
13. Do not use APIs from incompatible Godot versions.
14. Never claim a feature is complete without runtime verification.

---

# 20. DEFINITION OF TECHNICAL COMPLETION

The technical MVP is complete when:

- Project runs without critical errors.
- All core gameplay systems function.
- Two to four clients can join a session.
- Independent cameras work correctly.
- Shared world state is consistent.
- Economy cannot be manipulated through invalid client requests.
- Building and NPC state synchronize correctly.
- World time is consistent.
- Save/load restores progression.
- Windows build runs successfully.

---

**END OF TDD**

Project: CROWNFALL: THE LAST LIGHT  
Document: TDD.md  
Version: 1.0