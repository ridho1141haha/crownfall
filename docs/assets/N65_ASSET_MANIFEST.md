# N6.5 Asset Manifest & Replacement Contract — Eldergrove Threat Encounters

**Milestone:** N6.5 (Eldergrove Threat Encounters & Pixel-Art Presentation)
**Visual Direction:** 2D side-scrolling pixel art (Kingdom: New Lands / Kingdom Two Crowns reference), nearest-neighbor filtering (`default_texture_filter = 0`), ground baseline `y = 0.0`.

---

## 1. Verified Asset Inventory

| Asset ID | Role | Existing Asset Path | Verified Dimensions & Frame Layout | Needed Animation States | World Scale & Ground Alignment | Status | Source / License |
|---|---|---|---|---|---|---|---|
| `eldergrove_threat_raider` | Ordinary night threat (`ThreatClass.ORDINARY` / `"raider"`) | `res://assets/enemies/first_enemy/enemy_greedling_raider_sheet.png` | `128x32` PNG; `hframes = 4` (`32x32` per frame). Native West-facing (left). F0: stride `-2`; F1: mid-stride/bob; F2: stride `+2` lunge; F3: recovery. | `approaching` (F0–F3 walk loop), `blocked` (F1–F2 hold/pulse) | `scale = Vector2(1, 1)`, `centered = false`, `offset = Vector2(-16, -32)`, feet at `y = 0.0` | Reused existing asset | Project-authored via `scripts/tools/generate_pixel_assets.py` (`build_raider_sheet()`) |
| `eldergrove_threat_brute` | Breach-capable night threat (`ThreatClass.BREACH_CAPABLE` / `"brute"`) | `res://assets/enemies/first_enemy/enemy_greedling_raider_sheet.png` *(temporary placeholder)* | Reuses verified `128x32` (`hframes = 4`, `32x32`) pixel-art sheet with crimson-shadow tint (`Color(0.72, 0.42, 0.56, 1.0)`). | `approaching` (F0–F3), `breached` (F0–F3 crimson alert) | `scale = Vector2(2, 2)` (exact 2x integer pixel scale), `centered = false`, `offset = Vector2(-16, -32)`, feet at `y = 0.0` | **Placeholder** | Project-authored placeholder (`generate_pixel_assets.py`); no external third-party asset |
| `eldergrove_first_camp` | First Camp shelter | `res://assets/buildings/camp/building_vagrant_tent.png` | `48x32` PNG; single static frame. | Built / unbuilt visibility | `scale = Vector2(1, 1)`, `position = Vector2(-24, -32)` under `FirstCampSite (x=80, y=0)` | Reused existing asset | Project-authored via `scripts/tools/generate_pixel_assets.py` |
| `eldergrove_camp_ward_posts` | First Camp protection perimeter markers (`x = -4`, `x = 164`) | Procedural pixel-aligned `ColorRect` (`4x22` px) inside `EldergroveThreatPresenter` | `4x22` px integer-aligned stakes at `CAMP_CENTER_X +/- CAMP_PROTECTION_RADIUS`. | `idle` (amber), `blocked` (bright ward glow), `breached` (crimson alert) | `1:1` world pixels, base at `y = 0.0` | **Placeholder** (minimal pixel stake) | Procedural in-engine node |

---

## 2. Asset Decoupling & Future Replacement Contract

- **Authoritative Simulation Independence:** `scripts/survival/EldergroveNightSurvival.gd` contains zero texture paths, frame indexes, colors, or scene node references.
- **Swappable Visual Profiles:** `scripts/survival/EldergroveThreatPresenter.gd` resolves visuals exclusively through `set_visual_profile(archetype, profile)`.
- **Future Gloom Brute Replacement Steps:**
  1. Add a dedicated side-view pixel-art sprite sheet (e.g., `res://assets/enemies/gloom_brute/enemy_gloom_brute_sheet.png`) authored with nearest-neighbor pixel art, integer frame size (e.g., `48x48` or `64x64` horizontal strip), and bottom-center feet aligned to the bottom row of each frame.
  2. Update the `"brute"` profile in `EldergroveThreatPresenter._init_default_profiles()` (or override via `set_visual_profile("brute", {...})`) with `texture_path`, `hframes`, `frame_offset = Vector2(-frame_w / 2.0, -frame_h)`, `sprite_scale = Vector2(1.0, 1.0)`, `modulate = Color.WHITE`, `native_faces_left`, and `is_placeholder = false`.
  3. Zero changes to `EldergroveNightSurvival.gd`, `EldergroveForestArrival.gd`, `SaveManager`, or N6.4/N6.5 gameplay tests are required.
