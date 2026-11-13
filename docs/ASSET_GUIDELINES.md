# CROWNFALL: THE LAST LIGHT
# ASSET GUIDELINES

**Document Version:** 1.0  
**Project:** CROWNFALL: THE LAST LIGHT  
**Engine:** Godot 4  
**Target Platform:** Windows PC  
**Art Direction:** Cinematic 2D Pixel Art  
**Base Resolution:** 1280 × 720  
**Target Frame Rate:** 60 FPS  
**Status:** Production Guidelines

---

# 1. PURPOSE

This document defines the visual, technical, and production standards for all assets used in CROWNFALL: THE LAST LIGHT.

Its purpose is to ensure that every asset maintains consistent visual quality, proportions, pixel density, technical compatibility, and artistic identity.

These guidelines apply to:

- Player characters
- NPCs and enemies
- Buildings and structures
- Environment and terrain
- Biome-specific assets
- Items and resources
- Mounts and animals
- Visual effects
- User interface
- Audio assets
- AI-generated assets
- Third-party or externally sourced assets

All assets must follow these guidelines before being integrated into the game.

# 2. ART DIRECTION

## 2.1 Visual Identity

CROWNFALL: THE LAST LIGHT uses a detailed cinematic 2D pixel-art style inspired by the visual presentation of Kingdom: New Lands and Kingdom Two Crowns.

The visual identity combines:

- Medieval fantasy architecture
- Atmospheric environmental storytelling
- Detailed pixel-art environments
- Layered side-scrolling landscapes
- Rich lighting and shadow
- Natural environmental colors
- Mysterious fantasy elements
- Strong silhouettes and readable compositions

The game should feel like a living medieval fantasy world rather than a collection of disconnected pixel-art objects.

## 2.2 Artistic Principles

Every asset must follow these principles:

**Consistency:** All assets must share the same visual language.

**Readability:** Important gameplay objects must remain recognizable at normal gameplay zoom.

**Atmosphere:** Environmental assets should contribute to the emotional tone of the world.

**Depth:** Backgrounds, foregrounds, and interactive objects must create a convincing sense of spatial depth.

**Detail:** Assets should contain meaningful details without becoming visually noisy.

**Gameplay Clarity:** Decorative details must never interfere with gameplay readability.

## 2.3 Color Direction

The overall palette should be natural, slightly muted, and atmospheric.

Recommended color families:

| Category | Color Direction |
|---|---|
| Forest | Deep green, moss green, earthy brown |
| Beach | Sand beige, muted blue, warm gray |
| Buildings | Dark wood, stone gray, aged brown |
| Night | Navy, charcoal, dark violet |
| Fire and Light | Warm yellow, orange, amber |
| Magic | Pale cyan, muted blue, controlled gold |
| Snow | Cold white, blue-gray, muted cyan |
| Volcanic Areas | Dark red, charcoal, burnt orange |

Avoid excessive saturation unless an object needs to stand out as a gameplay indicator.

# 3. TECHNICAL ART STANDARDS

## 3.1 Project Resolution

The game's reference resolution is:

- Width: 1280 pixels
- Height: 720 pixels
- Aspect ratio: 16:9
- Target frame rate: 60 FPS

Assets should be designed with the intended in-game display scale in mind.

The reference resolution does not mean every individual sprite must be 1280 × 720.

## 3.2 Pixel Density

Pixel density must remain consistent across all major asset categories.

The project must establish a visual benchmark scene before large-scale asset production.

The benchmark scene should contain:

- One player character
- One villager
- One tree
- One rock
- One wooden wall
- One watchtower
- One terrain section
- One background layer

This scene will serve as the reference for comparing sprite scale, pixel density, proportions, and readability.

Do not independently resize individual assets without checking them against the benchmark scene.

## 3.3 Texture Filtering

Recommended Godot texture settings:

- Texture Filter: Nearest
- Texture Repeat: Disabled unless required
- Mipmaps: Disabled for standard pixel-art sprites unless a tested use case requires them
- Compression: Lossless for important pixel-art assets
- Texture Import: Preserve pixel clarity

Avoid bilinear filtering and unintended anti-aliasing that create blurry edges.

## 3.4 Transparency

Assets intended to exist independently in the world should generally use transparent backgrounds.

Examples:

- Characters
- Trees
- Rocks
- Buildings
- Items
- Effects
- UI icons

Use PNG for standard transparent pixel-art images.

Do not include unwanted background pixels, halos, or opaque borders.

## 3.5 Pixel Alignment

All pixel-art assets must maintain clean pixel alignment.

Requirements:

- Avoid unintended subpixel positioning.
- Avoid fractional sprite scaling where possible.
- Use consistent sprite origins.
- Keep pixel edges sharp.
- Test movement and camera scrolling for visual jitter.
- Apply pixel snapping where appropriate.

# 4. CHARACTER ASSET GUIDELINES

## 4.1 Character Categories

The character asset system includes:

**Player Characters**
- Player Variant A
- Player Variant B

**NPCs**
- Villager
- Farmer
- Archer

**Enemies**
- Greedling
- Crawler
- Brute

**Mounts**
- Horse

Future characters must follow the same visual standards.

## 4.2 Character Perspective

All gameplay characters must use a consistent side-view perspective.

Requirements:

- Character faces left or right.
- Body proportions remain consistent between animations.
- Character silhouettes remain readable.
- Equipment must match the character's medieval fantasy setting.
- Character details must remain visible at gameplay scale.

Avoid mixing side-view, isometric, and front-facing character designs.

## 4.3 Character Proportions

Character dimensions must be established through the benchmark scene.

Each character must have:

- Defined visual height
- Defined ground contact point
- Consistent body proportions
- Consistent head-to-body ratio
- Appropriate collision dimensions
- Clearly defined animation origin

Visual sprite dimensions and collision dimensions do not need to be identical.

## 4.4 Player Character Requirements

Player sprites should communicate:

- Medieval fantasy identity
- Adventurous personality
- Practical clothing and equipment
- Clear silhouette
- Distinct visual identity between variants

Player characters should remain visually recognizable during movement, interaction, and combat.

## 4.5 NPC Requirements

NPCs must be distinguishable by their role.

Villager:
- Basic civilian clothing
- Neutral and friendly appearance
- Simple movement animations

Farmer:
- Farming-related clothing or equipment
- Readable agricultural identity
- Appropriate work animations

Archer:
- Bow and quiver
- Defensive combat identity
- Clear attack animation

## 4.6 Enemy Requirements

Enemies must communicate their threat level through silhouette, size, animation, and visual behavior.

Greedling:
- Small silhouette
- Fast movement
- Clearly readable coin-stealing behavior

Crawler:
- Low-profile body
- Fast and aggressive movement
- Distinct attack behavior

Brute:
- Large and heavy silhouette
- Slow movement
- Strong visual indication of structural damage potential

# 5. ANIMATION GUIDELINES

## 5.1 General Animation Rules

All animations must:

- Maintain consistent character proportions.
- Use consistent pivot points.
- Avoid unintended sprite shifting.
- Have readable movement timing.
- Avoid unnecessary frame variations.
- Maintain consistent lighting and color.

## 5.2 Initial Animation Targets

The following values are production starting points, not mandatory limits.

| Animation | Suggested Frames |
|---|---:|
| Idle | 4–8 |
| Walk | 6–8 |
| Run | 6–8 |
| Attack | 4–8 |
| Interact | 4–6 |
| Death | 6–10 |
| Work | 4–8 |
| Mount Movement | 6–8 |

Animation speed should be adjusted according to the intended movement and gameplay feel.

## 5.3 Animation Naming

Use consistent animation names:

- idle
- walk
- run
- attack
- interact
- work
- hurt
- death

For directional animations, use suffixes:

- walk_left
- walk_right
- attack_left
- attack_right

Where appropriate, use horizontal sprite flipping rather than duplicating identical animation frames.

## 5.4 Sprite Sheet Requirements

Sprite sheets must have:

- Consistent frame dimensions
- Consistent frame spacing
- Predictable frame order
- No accidental overlap
- Transparent backgrounds where applicable
- Clear animation separation

Every sprite sheet must include documentation describing frame dimensions, animation names, frame counts, and playback speed.

# 6. ENVIRONMENT & BIOME GUIDELINES

## 6.1 Environment Categories

Environment assets include:

- Terrain
- Grass
- Trees
- Rocks
- Water
- Bushes
- Plants
- Decorations
- Background scenery
- Foreground elements
- Environmental props

All environment assets must support the side-scrolling world structure.

## 6.2 Biome Visual Identity

### Forgotten Shore

The starting island and MVP environment.

Visual characteristics:
- Coastal forest
- Sandy beaches
- Abandoned settlement
- Weathered wooden structures
- Natural vegetation
- Ruined medieval objects

Primary palette:
- Muted green
- Sand beige
- Weathered brown
- Ocean blue
- Stone gray

### Eldergrove Forest

Visual characteristics:
- Dense ancient forest
- Large trees
- Overgrown ruins
- Moss and vegetation
- Mysterious atmosphere

Primary palette:
- Deep green
- Moss green
- Dark brown
- Muted cyan

### Frostveil Highlands

Visual characteristics:
- Snow-covered terrain
- Frozen trees
- Mountain formations
- Ice structures
- Cold atmosphere

Primary palette:
- Snow white
- Blue-gray
- Muted cyan
- Cold dark blue

### Ashen Wastes

Visual characteristics:
- Volcanic terrain
- Burnt vegetation
- Ruined settlements
- Lava and ash effects
- Ancient structures

Primary palette:
- Charcoal
- Dark red
- Burnt orange
- Ash gray

### The Hollow Depths

Visual characteristics:
- Underground caves
- Crystalline formations
- Dark stone
- Ancient ruins
- Subterranean atmosphere

Primary palette:
- Dark gray
- Muted violet
- Deep blue
- Crystal cyan

### Crownlands

Visual characteristics:
- Former royal capital
- Large medieval structures
- Royal ruins
- Ancient architecture
- Legendary materials

Primary palette:
- Weathered gold
- Stone gray
- Dark brown
- Muted royal blue

## 6.3 Layering and Parallax

The world should use multiple visual layers.

Recommended structure:

1. Distant sky and atmospheric background
2. Far background scenery
3. Mid-background vegetation and structures
4. Main gameplay terrain
5. Interactive objects
6. Foreground decorations
7. Atmospheric effects

Parallax movement must create depth without making gameplay objects appear disconnected from the world.

Gameplay collision objects must remain independent of decorative background layers.

# 7. BUILDING & STRUCTURE GUIDELINES

## 7.1 Building Categories

MVP buildings:

- Town Center
- Wooden Wall
- Watchtower
- Farm
- Workshop
- Storage

## 7.2 Building Requirements

Each building should include:

- Base visual asset
- Ground anchor
- Defined footprint
- Collision shape where needed
- Construction state
- Completed state
- Upgrade state where applicable
- Damaged state where applicable
- Destruction state where applicable

## 7.3 Construction Stages

Buildings that require construction should support visually distinct stages.

Recommended stages:

1. Empty construction location
2. Initial foundation
3. Partial construction
4. Completed structure

The number of stages may vary depending on the building.

## 7.4 Building Scale

Building scale must be evaluated against:

- Player character height
- NPC character height
- Terrain dimensions
- Nearby environmental objects

Buildings must not look disproportionately large or small unless intentionally designed that way.

# 8. ITEMS & RESOURCE GUIDELINES

## 8.1 Resource Categories

MVP resources:

- Gold
- Wood
- Stone

Future resources:

- Iron
- Food
- Crystal
- Ancient Relics

## 8.2 Item Requirements

Every item asset must have:

- Unique visual identity
- Consistent pixel density
- Transparent background when appropriate
- Recognizable silhouette
- Appropriate in-world display size
- UI icon version where needed

## 8.3 Item Naming

Examples:

- item_gold_coin
- item_wood_log
- item_stone
- item_iron_ore
- item_crystal

Gameplay IDs must remain independent from asset filenames.

# 9. MOUNT & ANIMAL GUIDELINES

MVP mount:

- Horse

Animal assets should include:

- Idle
- Walk
- Run
- Movement transitions
- Appropriate ground contact
- Consistent side-view perspective

Mount animations must be visually synchronized with the rider where necessary.

# 10. LIGHTING, EFFECTS & ATMOSPHERE

## 10.1 Lighting

Lighting is a major part of CROWNFALL's visual identity.

The game should support:

- Daylight
- Sunset
- Night
- Torchlight
- Campfires
- Building lights
- Magical illumination

Lighting must enhance atmosphere without reducing gameplay readability.

## 10.2 Visual Effects

Potential effects include:

- Dust
- Smoke
- Fire
- Sparks
- Rain
- Snow
- Fog
- Water splashes
- Magic particles
- Enemy impact effects
- Construction effects

Effects must use a consistent pixel-art style.

Avoid overly smooth, vector-like particles that visually conflict with the game's pixel-art environment.

## 10.3 Performance

Avoid excessive real-time lighting and particle effects.

Use reusable effects, sensible particle counts, and optimized rendering.

# 11. UI & ICON GUIDELINES

## 11.1 UI Visual Direction

The UI should feel like part of a medieval fantasy world.

Recommended characteristics:

- Minimalist
- Clear
- Atmospheric
- Readable
- Consistent with the environment
- Limited decorative complexity

## 11.2 UI Elements

Required UI categories:

- Gold counter
- Wood counter
- Stone counter
- Inventory
- Interaction prompts
- Quest interface
- Map
- Multiplayer player indicators
- Pause menu
- Kingdom management interface

## 11.3 Icon Requirements

Icons must:

- Be instantly recognizable.
- Use consistent visual scale.
- Maintain clear silhouettes.
- Remain readable at small sizes.
- Use consistent visual treatment.

# 12. AUDIO ASSET GUIDELINES

## 12.1 Audio Categories

Audio assets include:

- Background music
- Environmental ambience
- Player footsteps
- Resource collection
- Construction
- Building upgrades
- NPC sounds
- Enemy sounds
- Combat effects
- UI interactions
- Day/night transitions

## 12.2 Audio Direction

The audio identity should support the game's medieval fantasy atmosphere.

Recommended qualities:

- Atmospheric
- Cinematic
- Subtle
- Immersive
- Environmentally appropriate

Audio must not overwhelm important gameplay sounds.

## 12.3 Audio File Standards

Preferred formats:

- WAV for source and high-quality sound effects
- OGG Vorbis for compressed music and suitable runtime audio

Use descriptive filenames.

Examples:

- sfx_player_footstep_grass.wav
- sfx_building_construct.wav
- sfx_enemy_greedling_attack.wav
- ambience_forest_day.ogg
- music_forgotten_shore.ogg

# 13. FILE NAMING CONVENTIONS

All asset filenames must use:

- Lowercase letters
- Underscores instead of spaces
- Descriptive names
- Consistent category prefixes
- Version suffixes only when needed

Examples:

```text
player_idle_01.png
player_walk_01.png
villager_idle_01.png
farmer_work_01.png
enemy_greedling_walk_01.png
enemy_brute_attack_01.png
building_wooden_wall_lv1.png
environment_tree_oak_01.png
environment_rock_large_01.png
item_gold_coin.png
ui_icon_gold.png
```

Avoid:

```text
New Image.png
Final Version 2.png
Sprite Latest.png
Untitled.png
```

## 13.1 Stable Asset IDs

Asset filenames must not be treated as gameplay identifiers.

Use stable IDs for game data.

Examples:

- PLAYER_VARIANT_A
- NPC_VILLAGER
- ENEMY_GREEDLING
- BUILD_WOODEN_WALL
- ITEM_GOLD_COIN
- ISLAND_FORGOTTEN_SHORE

This separation allows assets to be replaced without breaking gameplay systems or saved data.

# 14. ASSET DIRECTORY STRUCTURE

Recommended asset directory:

```text
assets/
├── characters/
│   ├── players/
│   ├── villagers/
│   ├── farmers/
│   ├── archers/
│   └── animals/
│
├── enemies/
│   ├── greedling/
│   ├── crawler/
│   └── brute/
│
├── environment/
│   ├── terrain/
│   ├── trees/
│   ├── rocks/
│   ├── water/
│   ├── vegetation/
│   ├── props/
│   └── backgrounds/
│
├── buildings/
│   ├── town_center/
│   ├── wooden_wall/
│   ├── watchtower/
│   ├── farm/
│   ├── workshop/
│   └── storage/
│
├── items/
│   ├── resources/
│   ├── equipment/
│   └── collectibles/
│
├── mounts/
│   └── horse/
│
├── effects/
│   ├── lighting/
│   ├── particles/
│   ├── weather/
│   └── combat/
│
├── ui/
│   ├── icons/
│   ├── menus/
│   ├── hud/
│   └── fonts/
│
└── audio/
    ├── music/
    ├── ambience/
    ├── sfx/
    └── ui/
```

# 15. AI ASSET GENERATION GUIDELINES

AI-generated assets must follow the same artistic and technical standards as manually created assets.

AI generation is a production aid, not a replacement for asset validation.

## 15.1 General AI Prompt Requirements

Every prompt should specify:

- Asset category
- Subject description
- Side-view perspective where applicable
- Pixel-art style
- Desired visual detail
- Lighting direction
- Color palette
- Intended gameplay purpose
- Background transparency requirements
- Technical output requirements

## 15.2 Master Art Style Prompt

Use the following style description as a shared reference:

"Detailed cinematic 2D pixel art for a medieval fantasy side-scrolling kingdom survival game. Rich atmospheric environmental storytelling, carefully controlled pixel density, crisp pixel clusters, clean silhouettes, natural muted color palette, sophisticated lighting and shadows, layered environmental depth, handcrafted medieval fantasy aesthetic, consistent proportions, no vector graphics, no 3D rendering, no photorealism, no smooth anti-aliased edges."

This is a style reference, not a guarantee that every generated image will be production-ready.

## 15.3 Character Prompt Template

```text
Create a 2D pixel-art game character for
CROWNFALL: THE LAST LIGHT.

Subject: [CHARACTER DESCRIPTION]

Perspective: Side view, facing right.

Art style: Detailed cinematic medieval fantasy
pixel art, consistent with the established
CROWNFALL visual identity.

Requirements:
- Clear readable silhouette.
- Consistent character proportions.
- Crisp pixel edges.
- Controlled pixel density.
- Natural muted color palette.
- Detailed medieval clothing and equipment.
- Transparent background.
- No environment.
- No text.
- No watermark.
- No additional characters.

The result must be suitable for a 2D
side-scrolling Godot 4 game.
```

## 15.4 Environment Prompt Template

```text
Create a 2D pixel-art environment asset
for CROWNFALL: THE LAST LIGHT.

Subject: [ENVIRONMENT DESCRIPTION]

Biome: [BIOME NAME]

Perspective: Side-scrolling 2D game perspective.

Art style: Detailed cinematic medieval fantasy
pixel art.

Requirements:
- Consistent pixel density.
- Natural atmospheric colors.
- Clean pixel clusters.
- Detailed but readable shapes.
- Consistent lighting direction.
- Appropriate environmental scale.
- No characters unless requested.
- No text.
- No watermark.

The asset must visually match the
CROWNFALL environment benchmark.
```

## 15.5 Building Prompt Template

```text
Create a medieval fantasy building sprite
for CROWNFALL: THE LAST LIGHT.

Building: [BUILDING NAME]

Level: [BUILDING LEVEL]

Perspective: Side view, suitable for
a 2D side-scrolling game.

Art direction:
Detailed cinematic pixel art with
weathered medieval materials, natural
muted colors, clean pixel edges,
consistent pixel density, and
atmospheric lighting.

Requirements:
- Clearly defined ground contact.
- Readable building silhouette.
- Consistent scale with player characters.
- Transparent background.
- No perspective distortion.
- No text or watermark.
```

## 15.6 Sprite Sheet Prompt Template

```text
Create a sprite sheet for
CROWNFALL: THE LAST LIGHT.

Character: [CHARACTER NAME]

Animation: [ANIMATION NAME]

Requirements:
- Consistent frame dimensions.
- Consistent character proportions.
- Fixed ground alignment.
- Consistent pivot position.
- Clearly separated frames.
- Transparent background.
- No frame overlap.
- No text.
- No watermark.

Frame count: [FRAME COUNT]

Animation direction: [LEFT / RIGHT]

The sprite sheet must be suitable for
frame-based animation in Godot 4.
```

## 15.7 AI Generation Limitations

AI-generated assets must be checked for:

- Inconsistent anatomy
- Different character proportions between frames
- Broken animation continuity
- Unwanted anti-aliasing
- Incorrect transparency
- Inconsistent perspective
- Unintended background objects
- Duplicate or malformed sprite frames

Do not import AI-generated sprite sheets directly into production without validation.

# 16. GODOT 4 INTEGRATION STANDARDS

## 16.1 Import Rules

All assets must be tested inside Godot 4.

Check:

- Import settings
- Texture filtering
- Transparency
- Sprite scaling
- Animation playback
- Collision alignment
- Camera scrolling
- Runtime performance

## 16.2 Scene Integration

Recommended scene structure:

```text
Player
├── Sprite2D
├── AnimationPlayer
├── CollisionShape2D
├── InteractionArea
├── Camera2D
└── Audio
```

The exact scene structure may change as the implementation evolves.

## 16.3 Resource Management

Use Godot Resource files for reusable asset definitions where appropriate.

Keep visual assets separate from gameplay balance and logic.

Asset replacement should not require rewriting unrelated gameplay systems.

# 17. ASSET QUALITY CONTROL

Every asset must pass a quality-control review before production integration.

## 17.1 Visual Checklist

- [ ] Matches the CROWNFALL art direction.
- [ ] Correct side-view perspective where applicable.
- [ ] Consistent pixel density.
- [ ] Correct proportions.
- [ ] Readable silhouette.
- [ ] Appropriate color palette.
- [ ] No unwanted blur.
- [ ] No unwanted background artifacts.
- [ ] No unintended visual inconsistencies.

## 17.2 Technical Checklist

- [ ] Correct file format.
- [ ] Correct dimensions.
- [ ] Correct transparency.
- [ ] Correct naming convention.
- [ ] Correct directory location.
- [ ] Correct pivot or origin.
- [ ] Correct animation frame structure.
- [ ] Correct Godot import settings.
- [ ] Tested inside the game.

## 17.3 Gameplay Checklist

- [ ] Readable at normal gameplay zoom.
- [ ] Does not obstruct important gameplay information.
- [ ] Collision dimensions are appropriate.
- [ ] Animation timing is appropriate.
- [ ] Works with the intended camera.
- [ ] Does not cause noticeable performance problems.

# 18. ASSET PRODUCTION WORKFLOW

All new assets should follow this workflow:

**Step 1 — Asset Planning**

Define the asset category, gameplay purpose, visual reference, and technical requirements.

**Step 2 — Visual Reference**

Establish the intended design and compare it against the existing benchmark assets.

**Step 3 — Asset Creation**

Create the asset manually or using an AI generation workflow.

**Step 4 — Cleanup**

Correct visual inconsistencies, remove artifacts, and prepare the final file.

**Step 5 — Technical Validation**

Check dimensions, transparency, naming, pixel alignment, and animation structure.

**Step 6 — Godot Integration**

Import the asset and test it inside the relevant scene.

**Step 7 — Approval**

Accept the asset only after visual, technical, and gameplay validation.

**Step 8 — Documentation**

Update the asset inventory and record any important production changes.

# 19. MVP ASSET PRIORITIES

Asset production must prioritize the playable MVP.

## Priority 1 — Required for Core Gameplay

- Player Variant A
- Player Variant B
- Villager
- Farmer
- Archer
- Greedling
- Crawler
- Brute
- Horse
- Forgotten Shore terrain
- Trees and rocks
- Town Center
- Wooden Wall
- Watchtower
- Farm
- Workshop
- Storage
- Gold, wood, and stone assets
- Basic HUD
- Day/night visual effects

## Priority 2 — Gameplay Polish

- Additional character animations
- Construction stages
- Building upgrade visuals
- Environmental particles
- Weather effects
- Additional props
- Improved lighting
- Additional UI animations

## Priority 3 — Future Expansion

- Eldergrove Forest assets
- Frostveil Highlands assets
- Ashen Wastes assets
- The Hollow Depths assets
- Crownlands assets
- Additional enemies
- Additional mounts
- Ancient relics and magical effects

Do not prioritize expansion assets before the core MVP asset set is functional.

# 20. FINAL PRODUCTION RULES

The following rules are mandatory:

1. Every asset must follow the established CROWNFALL art direction.
2. No asset should be integrated without technical validation.
3. AI-generated assets must be reviewed and corrected before production use.
4. Maintain consistent pixel density across all asset categories.
5. Do not change established character designs without updating their references.
6. Keep asset filenames and gameplay IDs separate.
7. Avoid unnecessary duplicate assets.
8. Optimize assets for Godot 4.
9. Prioritize MVP requirements over future expansion.
10. Every approved asset must be tested in the actual game environment.

---

# DOCUMENT CONTROL

**Document:** ASSET_GUIDELINES.md  
**Version:** 1.0  
**Project:** CROWNFALL: THE LAST LIGHT  
**Engine:** Godot 4  
**Status:** Initial Production Standard

This document may be updated as the game's visual benchmark, technical requirements, and production pipeline evolve.

Any significant changes to art direction or asset standards must be documented in a new version.
