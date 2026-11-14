# CROWNFALL: THE LAST LIGHT
# ASSET GUIDELINES

**Document Version:** 1.3
**Baseline:** Revised Project Baseline v1.3 (`docs/DECISIONS_M2_M8.md`)
**Engine:** Godot 4.7.2.stable
**Target Platform:** Windows PC
**Art Direction:** Atmospheric Medieval-Fantasy 2D Pixel Art
**Status:** M0–M8 Vertical Slice + Priority 1/2 Implemented (12 Procedural Pixel-Art PNGs Active)

---

## 1. Purpose and Production Status

This document defines the visual direction, technical preparation standards, naming conventions, validation process, and production priorities for CROWNFALL assets.

The first game target is a **single-player vertical slice on Forgotten Shore**. Art production must support that slice only. Do not create a large asset catalogue for future islands, professions, enemies, mounts, or multiplayer UI before the core gameplay loop is validated.

**Current repository status:** 12 procedural nearest-neighbor RGBA PNG spritesheets and tiles are generated via `scripts/tools/generate_pixel_assets.py` into `assets/` and wired into `Player.tscn` and `ForgottenShore.tscn` (Monarch, Builder, Greedling Raider, Town Center, Wooden/Stone Wall states, Farm Plot states, Watchtower states, Vagrant Tent, Resource nodes, Shore ground tile, and far-mountain/mid-forest parallax layers). Final hand-crafted production polish remains future work after core gameplay loops are balanced.

Placeholder art is acceptable during early mechanics validation. Use simple shapes, temporary sprites, or clearly identified placeholder assets when the final art would slow down gameplay testing.

---

## 2. Art Direction

### 2.1 Visual Identity

CROWNFALL aims for atmospheric medieval-fantasy pixel art with:
- Clear and readable silhouettes.
- Consistent pixel density and pixel clusters.
- Muted, natural colors.
- Controlled detail rather than visual noise.
- Strong environmental depth.
- Subtle lighting and atmospheric contrast.
- Side-view readability suitable for a 2D side-scrolling game.

Kingdom: New Lands and Kingdom Two Crowns may be used as high-level visual references for atmosphere, depth, and readability. Do not copy their sprites, layouts, designs, or distinctive assets.

### 2.2 Visual Priorities

The art must communicate gameplay before decorative detail:

1. The player and interactable objects must be easy to identify.
2. The ground plane and collision-relevant structures must be visually clear.
3. Resource objects must have recognizable silhouettes.
4. Construction states must be distinguishable.
5. Day/night lighting must preserve important gameplay readability.
6. Background art must not look like it is part of the collision layer.

### 2.3 Pixel Consistency

- Establish a consistent logical pixel scale for the first island.
- Avoid mixing crisp pixel art with smooth vector artwork or unfiltered 3D renders.
- Avoid arbitrary resizing that creates uneven pixel clusters.
- Use nearest-neighbor texture filtering where appropriate for pixel sprites.
- Keep outline, shading, lighting direction, and material treatment consistent.
- Do not force all assets to one exact dimension; scale should follow gameplay role and visual hierarchy.

### 2.4 Resolution and Animation Starting Points

These are provisional production starting points and must be checked in Godot at actual gameplay zoom.

| Parameter | Initial Direction |
|---|---|
| Base viewport | 1280 × 720 target |
| Render target | 60 FPS target; verify through profiling |
| Tile grid | 16×16 or 32×32 may be evaluated during blockout |
| Character height | Approximately 32–64 logical pixels as an initial comparison range |
| Idle animation | 4–8 frames as a starting range |
| Walk animation | 6–8 frames as a starting range |
| Work animation | Only if it improves task readability |
| Animation playback | Tune by actual character movement and feel |

These values are not hard limits. Do not distort a design merely to meet an arbitrary frame count or sprite size.

---

## 3. First Vertical Slice Asset Inventory (P0)

The following is the only asset scope required for the first playable slice. Placeholder assets are acceptable until the relevant milestone needs visual feedback.

### 3.1 Player

| Asset | Required Purpose | Notes |
|---|---|---|
| Monarch placeholder / player sprite | Identify the locally controlled character | One playable character in P0 |
| Idle animation | Readable resting state | Can begin as a static placeholder |
| Walk animation | Communicate horizontal movement | Add after movement is stable |
| Basic interaction feedback | Communicate interaction where needed | Can use a simple icon or text prompt |

No second character variant, class-specific costume, attack animation set, or multiplayer player indicator is required in P0.

### 3.2 NPC

| Asset | Required Purpose | Notes |
|---|---|---|
| Villager placeholder / sprite | Represent the recruited NPC | One NPC visual identity is enough initially |
| Basic idle/walk | Communicate movement and presence | Placeholder is acceptable |
| Builder work indication | Make construction behavior understandable | May use a simple pose, tool, icon, or effect |

Approved representation (`OD-05`): Builder is represented as the persistent `NPCBuilderAgent` (`id="npc_01"`, `role: "villager" -> "builder"`). Reusing the Villager silhouette with a work indicator or tool cue is sufficient for P0.

Farmer, Archer, Knight, Guard, and other professions are deferred.

### 3.3 Settlement and Buildings

| Asset | Required Purpose | Notes |
|---|---|---|
| Town Center / starting settlement anchor | Establish the safe-area and settlement focal point | Could begin as a simple scene/placeholder |
| Wooden Wall | First defensive construction target | Must read clearly at gameplay zoom |
| Wall construction placeholder | Communicate incomplete work | Can use simple stages or a progress indicator |
| Damaged wall appearance | Communicate damage when damage is implemented | Required only if the first encounter uses wall damage |

Watchtower, Farm, Workshop, Storage, Stone Wall, Barracks, and full upgrade visual sets are not P0 asset requirements.

### 3.4 Forgotten Shore Environment

Only the environment needed to make the first slice traversable and readable is required:

- Ground and terrain tiles.
- Simple shoreline/beach transition if used by the blockout.
- Basic background/sky.
- A small set of trees and rocks.
- A limited set of vegetation or environmental props.
- Clear world-boundary treatment where needed.
- One or more points of interest only if the approved exploration loop needs them.

The final terrain composition and resource-node layout will follow the level blockout. Do not create a full island environment pack before the route and gameplay space are validated.

### 3.5 Resources and UI

| Asset | Required Purpose |
|---|---|
| Gold visual / icon | Represent Gold in world or HUD |
| Wood visual / icon | Represent Wood in world or HUD |
| Stone visual / icon | Represent Stone in world or HUD |
| Minimal HUD frame/icons | Display resource counts and time phase |
| Interaction prompt | Explain the currently available interaction |
| Day/sunset/night indicator | Communicate world phase |

A detailed inventory screen, minimap, quest tracker, multiplayer lobby, player list, or kingdom-management dashboard is deferred.

### 3.6 First Enemy

One generic enemy placeholder is sufficient until the enemy design is approved.

Required visual scope:
- One readable side-view silhouette.
- Basic movement/approach indication.
- Wall-attack indication if the behavior is implemented.
- Optional damage feedback needed to test the encounter.

Approved P0 enemy (`OD-06`): **Greedling Raider** (`45 HP`, `15 dmg/hit`, `15 thorn dmg/hit`, `95 px/s`, 3 waves per night). Only the single Greedling Raider visual/placeholder is required in P0; Crawler, Brute, and boss asset sets remain deferred to P1/P2.

### 3.7 First-Slice Effects

Only effects that clarify the core loop should be considered:
- Basic sunset/night transition.
- Subtle ambient lighting changes.
- Construction feedback.
- Wall impact/damage feedback.
- Minimal dust or movement feedback when useful.

Weather, snow, rain, advanced magic, large particle systems, and elaborate combat effects are future content.

### 3.8 Audio Scope

Audio production is not a separate P0 dependency. Temporary audio or silence is acceptable during early mechanics validation.

When audio is introduced, prioritize:
- Basic ambience for Forgotten Shore.
- Simple movement or interaction feedback.
- Resource collection feedback.
- Construction feedback.
- Sunset/night transition cue.
- First enemy/wall impact feedback.

A full soundtrack, extensive NPC voice work, and biome-specific music are deferred.

---

## 4. Forgotten Shore Palette and Environment Identity

The starting island should feel like a once-inhabited coastal settlement reclaimed by nature.

Suggested visual materials:
- Muted forest greens.
- Sand beige and weathered earth.
- Weathered wood browns.
- Ocean blue and subdued cyan.
- Stone gray.
- Warm sunset light and restrained night cool tones.

Use a limited palette first. Expand it only when the level design requires a distinct material or gameplay cue.

### 4.1 World Layers

A potential parallax/environment stack:

1. Sky and atmosphere.
2. Distant silhouettes or mountains.
3. Far background trees and ruins.
4. Midground scenery.
5. Gameplay terrain and buildings.
6. Foreground decoration.
7. Lighting and atmospheric effects.

Collision and interactable objects must remain independent from decorative background layers. A background silhouette must not accidentally imply a traversable platform or interactable object.

---

## 5. Character and Animation Standards

### 5.1 Character Readability

- Use a consistent side-view perspective.
- Keep the character's ground contact and pivot consistent.
- Maintain recognizable silhouettes at normal gameplay zoom.
- Avoid excessive detail that disappears at the target resolution.
- Keep tools and carried objects readable without obscuring the body.

### 5.2 Animation Requirements

For the first slice, prioritize:
- Idle.
- Walk.
- Optional interaction or work pose when it improves feedback.

Run, attack, mount, complex directional combat, death, and profession-specific animation sets are deferred unless the first-slice design explicitly requires them.

### 5.3 Sprite Sheet Requirements

A sprite sheet should provide:
- Consistent frame dimensions.
- Consistent pivot/ground alignment.
- Predictable frame order.
- No accidental overlap.
- Transparent background where appropriate.
- Documented frame count and playback rate.

Do not assume an AI-generated sprite sheet has consistent pivots or frame dimensions; validate each frame before integration.

---

## 6. Building and Construction Visual Standards

The Wooden Wall is the only required constructible structure for the first slice.

The wall should support clear visual recognition of:
1. Valid placement/blueprint, if shown.
2. Under construction.
3. Completed.
4. Damaged, if wall damage is part of the first-night loop.

Not every state needs a unique full-resolution sprite. A tint, overlay, partial sprite, or simple effect may be sufficient if it communicates state clearly.

The Town Center is the visual settlement anchor. It may be a static starting structure; do not assume it requires construction stages or upgrades.

Building visuals must:
- Have clear ground contact.
- Match the player's scale.
- Use collision shapes that match gameplay intent.
- Keep decorative elements separate from collision where practical.
- Avoid hiding the player or enemy silhouette.

---

## 7. Naming and Asset Identity

Use:
- Lowercase filenames.
- Underscores instead of spaces.
- Descriptive names.
- Consistent category prefixes.
- Version suffixes only when needed.

Examples:

~~~text
player_monarch_idle.png
player_monarch_walk.png
npc_villager_idle.png
npc_villager_walk.png
npc_builder_work.png
building_town_center.png
building_wooden_wall.png
building_wooden_wall_damaged.png
environment_tree_oak.png
environment_rock_small.png
item_gold.png
item_wood.png
item_stone.png
ui_icon_gold.png
ui_icon_wood.png
ui_icon_stone.png
enemy_placeholder_idle.png
~~~

Avoid names such as New Image.png, Final Version 2.png, Sprite Latest.png, or Untitled.png.

Gameplay IDs must remain independent from filenames. Replacing a sprite must not break save data or gameplay references.

---

## 8. Suggested Asset Folder Organization

This is a future organization guide. Create only the directories needed by real assets; do not create empty folders for deferred content.

~~~text
assets/
├── characters/
│   ├── player/
│   └── npc/
├── enemies/
│   └── first_enemy/
├── environment/
│   ├── terrain/
│   ├── vegetation/
│   ├── props/
│   └── backgrounds/
├── buildings/
│   ├── town_center/
│   └── wooden_wall/
├── items/
│   └── resources/
├── effects/
├── ui/
└── audio/
~~~

Future expansions may add categories for other NPC roles, enemies, mounts, islands, and advanced effects when those features enter an approved milestone.

---

## 9. AI-Assisted Asset Creation

AI generation may be used as a concepting or asset-production aid. Generated outputs are not automatically production-ready.

### 9.1 Prompt Information

A useful asset prompt should specify:
- Asset category and gameplay purpose.
- Subject and silhouette.
- Side-view perspective where relevant.
- CROWNFALL pixel-art direction.
- Relative scale or logical dimensions when known.
- Lighting direction and palette.
- Transparency/background requirements.
- Whether the output is a single sprite, tile, background layer, or sprite sheet.
- Explicit exclusions such as text, watermark, extra characters, or unwanted props.

### 9.2 Shared Style Description

Use this as a style reference, then add asset-specific instructions:

> Atmospheric medieval-fantasy 2D pixel art for a side-scrolling kingdom-building survival game. Crisp intentional pixel clusters, readable silhouettes, consistent pixel density, restrained natural colors, handcrafted weathered materials, subtle cinematic lighting, environmental depth, and clear gameplay readability. No photorealism, no vector illustration, no smooth 3D render, no unwanted anti-aliasing, no text, and no watermark.

This is a visual direction, not a guarantee of consistency across generated outputs.

### 9.3 Example Character Prompt Structure

~~~text
Create one side-view 2D pixel-art character sprite for
CROWNFALL: THE LAST LIGHT.

Subject: [CHARACTER DESCRIPTION]
Gameplay role: [PURPOSE]
Scale: [KNOWN LOGICAL SCALE OR REFERENCE]
Pose/animation: [IDLE / WALK / WORK]
Facing direction: [LEFT / RIGHT]

Maintain:
- readable silhouette
- consistent pixel density
- clear ground contact
- restrained medieval-fantasy palette
- intentional pixel clusters
- transparent background if requested

Do not include additional characters, text, watermark,
or unrelated environment objects.
~~~

### 9.4 AI Output Review

Check for:
- Inconsistent proportions or anatomy.
- Pixel density drift.
- Unwanted anti-aliasing or blur.
- Incorrect transparency.
- Broken or inconsistent animation frames.
- Changing pivots or ground alignment.
- Unintended background objects.
- Visual mismatch with accepted CROWNFALL references.

Do not integrate generated spritesheets without frame-by-frame inspection and in-engine testing.

---

## 10. Godot Integration Standards

All production assets must be checked in the selected Godot 4 version.

Validate:
- Import settings and texture filtering.
- Transparency and sprite bounds.
- Scaling and pixel alignment.
- Pivot and ground contact.
- Animation frame order and playback.
- Collision alignment where applicable.
- Camera scrolling and parallax behavior.
- Visibility against daylight and nighttime backgrounds.
- Runtime performance.

Keep visuals separate from balance values and gameplay logic. Asset replacement should not require rewriting unrelated gameplay systems.

---

## 11. Asset Quality Control

### 11.1 Visual Checklist

- [ ] Matches the accepted visual direction.
- [ ] Correct perspective for its intended layer.
- [ ] Consistent pixel density.
- [ ] Readable silhouette at gameplay zoom.
- [ ] Appropriate scale relative to player and world.
- [ ] Palette fits Forgotten Shore.
- [ ] No unwanted blur, artifacts, or background elements.
- [ ] Consistent ground alignment and lighting.

### 11.2 Technical Checklist

- [ ] Correct file format and dimensions.
- [ ] Correct transparency.
- [ ] Descriptive filename.
- [ ] Gameplay ID remains separate from filename.
- [ ] Correct pivot/origin.
- [ ] Sprite sheet frames are consistent, if applicable.
- [ ] Import settings are verified in Godot.
- [ ] Asset tested in the relevant scene.

### 11.3 Gameplay Checklist

- [ ] Readable at normal gameplay zoom.
- [ ] Does not hide important gameplay information.
- [ ] Collision dimensions match intended behavior.
- [ ] Construction/damage states are distinguishable if required.
- [ ] Works with the intended camera and parallax.
- [ ] Does not create noticeable performance problems.

An asset is not approved merely because it looks good in an isolated image.

---

## 12. Asset Production Workflow

1. **Define need:** identify the milestone, gameplay purpose, and asset priority.
2. **Set reference:** compare against accepted CROWNFALL style references.
3. **Create:** produce a placeholder, hand-made asset, or AI-assisted concept.
4. **Clean up:** correct palette, pixel clusters, frame consistency, and artifacts.
5. **Validate technically:** check dimensions, transparency, naming, and pivots.
6. **Integrate:** test the asset in the intended Godot scene.
7. **Review:** confirm visual readability and gameplay clarity.
8. **Document:** record accepted asset/version and important constraints when an asset inventory exists.

---

## 13. Production Priorities

### P0 — First Vertical Slice

1. Player/Monarch placeholder and basic idle/walk representation.
2. Villager placeholder and basic movement representation.
3. Builder work feedback (may reuse Villager art).
4. Forgotten Shore terrain, floor, and essential background.
5. Small set of resource visuals for Gold, Wood, and Stone.
6. Town Center / settlement anchor.
7. Wooden Wall and the minimum construction/damage states needed.
8. One generic first-enemy placeholder.
9. Minimal resource/time HUD and interaction prompts.
10. Only the lighting/effects needed to communicate day, sunset, and night.

### P1 — Conditional Later Content

Only after the vertical slice has been validated:
- Additional building sets and upgrade visuals.
- Farmer and Archer visuals if those roles are approved.
- Additional enemy variants.
- Larger Forgotten Shore exploration content.
- Selected narrative/environmental storytelling assets.
- Improved animation and effects.

### P2 — Long-Term World Expansion

Not current production tasks:
- Eldergrove Forest, Frostveil Highlands, Ashen Wastes, The Hollow Depths, and Crownlands asset sets.
- Knight/Guard and mounted characters.
- Multiple mounts.
- Additional bosses and enemy families.
- Advanced weather, magic, and large-scale environmental effects.
- Multiplayer lobby and player UI assets.
- Full chapter/cutscene asset sets.

Do not create P1/P2 production assets while P0 gameplay requirements are still unproven, unless the asset is a low-cost concept reference that does not delay the slice.

---

## 14. Change Control

Any asset scope change should identify:
- The gameplay feature it supports.
- Its P0/P1/P2 priority.
- Whether it is a placeholder, concept, or production asset.
- Dependencies on unresolved gameplay decisions.
- Technical and review requirements.
- Which document or asset reference must be updated.

Art direction changes that affect multiple asset classes should be recorded and communicated in the GDD/asset guidelines. Do not treat a one-off generated image as an approved project-wide style benchmark without review.

---

**END OF ASSET GUIDELINES**

Project: CROWNFALL: THE LAST LIGHT  
Document: ASSET_GUIDELINES.md  
Version: 1.3
