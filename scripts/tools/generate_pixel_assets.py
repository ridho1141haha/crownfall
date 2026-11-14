#!/usr/bin/env python3
"""
CROWNFALL: THE LAST LIGHT — Procedural 32x32 Pixel-Art Spritesheet Generator (P0)
Generates crisp, nearest-neighbor RGBA PNG spritesheets into:
    /content/drive/MyDrive/crownfall/assets/  (in Google Colab)
    or ./assets/                              (when run locally in repo root)

Follows ASSET_GUIDELINES.md v1.3 naming and directory conventions:
- assets/characters/player/player_monarch_sheet.png        (256x32, 8 frames: 0-3 idle, 4-7 walk)
- assets/characters/npc/npc_builder_sheet.png              (256x32, 8 frames: 0-3 walk, 4-7 work)
- assets/enemies/first_enemy/enemy_greedling_raider_sheet.png (128x32, 4 frames: walk/attack)
- assets/buildings/town_center/building_town_center_sheet.png (192x48, 4 frames: campfire flicker)
- assets/buildings/wooden_wall/building_wooden_wall_states.png (128x48, 4 states: placeholder, building, completed, damaged)
- assets/items/resources/items_resources_sheet.png         (128x32, 4 icons: gold, wood, stone, shrine)
- assets/environment/terrain/terrain_shore_tile.png        (32x32, seamless shore grass + earth tile)
"""
import os
from pathlib import Path
from PIL import Image


def resolve_repo_root() -> Path:
    colab_root = Path("/content/drive/MyDrive/crownfall")
    if colab_root.exists():
        return colab_root
    if "__file__" in globals():
        candidate = Path(__file__).resolve().parent
        if (candidate / "project.godot").exists():
            return candidate
    return Path(os.getcwd()).resolve()


ROOT = resolve_repo_root()
ASSETS_DIR = ROOT / "assets"

# Shared Muted Medieval-Fantasy Palette (avoiding pure #000000 and #FFFFFF per ASSET_GUIDELINES)
T = (0, 0, 0, 0)              # Transparent
OUT = (22, 20, 28, 255)       # Deep ink outline
SKIN = (228, 184, 148, 255)   # Skin tone
SKIN_D = (188, 140, 108, 255) # Skin shadow

# Monarch (Royal Blue + Crimson Cloak + Gold Crown)
GOLD_L = (250, 224, 110, 255)
GOLD = (232, 184, 58, 255)
GOLD_D = (176, 126, 32, 255)
ROYAL = (48, 92, 156, 255)
ROYAL_D = (32, 60, 112, 255)
CAPE = (164, 48, 58, 255)
CAPE_D = (116, 30, 42, 255)

# Builder (Earthy Tunic + Leather Apron + Steel Hammer)
HOOD = (68, 124, 84, 255)
HOOD_D = (46, 88, 58, 255)
TUNIC = (138, 106, 74, 255)
TUNIC_D = (98, 72, 48, 255)
STEEL = (176, 186, 198, 255)
STEEL_D = (118, 128, 142, 255)

# Greedling Raider (Shadow Body + Bone Mask + Crimson Eye)
SHADOW = (38, 32, 48, 255)
SHADOW_L = (62, 52, 76, 255)
MASK = (212, 204, 188, 255)
MASK_D = (158, 148, 134, 255)
CRIMSON = (232, 52, 68, 255)

# Wood, Stone, Foliage & Fire
WOOD_L = (168, 118, 72, 255)
WOOD = (132, 88, 50, 255)
WOOD_D = (88, 56, 32, 255)
STONE_L = (158, 164, 170, 255)
STONE = (118, 124, 132, 255)
STONE_D = (78, 84, 92, 255)
GRASS_L = (78, 136, 76, 255)
GRASS = (54, 104, 58, 255)
GRASS_D = (38, 74, 44, 255)
DIRT = (76, 56, 44, 255)
DIRT_D = (56, 40, 32, 255)
FIRE_L = (252, 232, 128, 255)
FIRE_M = (242, 148, 44, 255)
FIRE_D = (196, 68, 36, 255)
SHRINE_C = (92, 204, 224, 255)


def new_canvas(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), T)


def put(img: Image.Image, x: int, y: int, col: tuple[int, int, int, int]) -> None:
    if 0 <= x < img.width and 0 <= y < img.height and col[3] > 0:
        img.putpixel((x, y), col)


def rect(img: Image.Image, x0: int, y0: int, w: int, h: int, col: tuple[int, int, int, int]) -> None:
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            put(img, x, y, col)


def add_outline(frame: Image.Image) -> Image.Image:
    w, h = frame.size
    out = frame.copy()
    px = frame.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                has_neighbor = False
                for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0:
                        has_neighbor = True
                        break
                if has_neighbor:
                    out.putpixel((x, y), OUT)
    return out


def build_monarch_sheet() -> Image.Image:
    sheet = new_canvas(32 * 8, 32)
    for i in range(8):
        f = new_canvas(32, 32)
        is_walk = i >= 4
        bob = 1 if (i % 2 == 1) else 0
        stride = [-2, 0, 2, 0][i % 4] if is_walk else 0
        cape_sway = -1 if (is_walk and i % 2 == 1) else 0

        # Crown (3-point gold crown)
        cy = 6 + bob
        put(f, 13, cy - 2, GOLD_L)
        put(f, 16, cy - 3, GOLD_L)
        put(f, 19, cy - 2, GOLD_L)
        rect(f, 13, cy - 1, 7, 2, GOLD)
        rect(f, 13, cy + 1, 7, 1, GOLD_D)

        # Head
        rect(f, 13, cy + 2, 6, 5, SKIN)
        rect(f, 13, cy + 5, 2, 2, SKIN_D)
        put(f, 17, cy + 4, OUT)  # Eye

        # Flowing Crimson Cape
        rect(f, 10 + cape_sway, cy + 7, 4, 11, CAPE)
        rect(f, 9 + cape_sway, cy + 13, 3, 6, CAPE_D)

        # Royal Tunic & Gold Belt
        rect(f, 13, cy + 7, 6, 9, ROYAL)
        rect(f, 13, cy + 11, 6, 2, GOLD)
        rect(f, 13, cy + 13, 2, 3, ROYAL_D)

        # Legs
        rect(f, 14 + stride, 24, 2, 6, ROYAL_D)
        rect(f, 17 - stride, 24, 2, 6, ROYAL_D)
        rect(f, 14 + stride, 29, 3, 2, WOOD_D)
        rect(f, 17 - stride, 29, 3, 2, WOOD_D)

        sheet.paste(add_outline(f), (i * 32, 0))
    return sheet


def build_builder_sheet() -> Image.Image:
    sheet = new_canvas(32 * 8, 32)
    for i in range(8):
        f = new_canvas(32, 32)
        is_work = i >= 4
        bob = 1 if (i % 2 == 1) else 0
        stride = [-2, 0, 2, 0][i % 4] if not is_work else 0
        hammer_lift = [0, -3, -5, 2][i % 4] if is_work else 0

        # Hooded Head
        hy = 8 + bob
        rect(f, 12, hy, 7, 6, HOOD)
        rect(f, 11, hy + 2, 2, 4, HOOD_D)
        rect(f, 15, hy + 2, 4, 4, SKIN)
        put(f, 18, hy + 3, OUT)

        # Tunic & Apron
        rect(f, 13, hy + 6, 6, 8, TUNIC)
        rect(f, 14, hy + 8, 4, 6, TUNIC_D)

        # Legs
        rect(f, 14 + stride, 23, 2, 6, TUNIC_D)
        rect(f, 17 - stride, 23, 2, 6, TUNIC_D)
        rect(f, 14 + stride, 29, 3, 2, WOOD_D)
        rect(f, 17 - stride, 29, 3, 2, WOOD_D)

        # Hammer (carried or swinging)
        hx = 20
        hy_tool = 15 + bob + hammer_lift
        rect(f, hx, hy_tool, 2, 7, WOOD_L)
        rect(f, hx - 2, hy_tool - 2, 6, 3, STEEL)
        rect(f, hx - 2, hy_tool, 6, 1, STEEL_D)

        sheet.paste(add_outline(f), (i * 32, 0))
    return sheet


def build_raider_sheet() -> Image.Image:
    sheet = new_canvas(32 * 4, 32)
    for i in range(4):
        f = new_canvas(32, 32)
        bob = 1 if i % 2 == 1 else 0
        lunge = -1 if i == 2 else 0
        stride = [-2, 0, 2, 0][i]

        # Shadowy crouched body
        by = 13 + bob
        rect(f, 11 + lunge, by, 10, 10, SHADOW)
        rect(f, 13 + lunge, by - 2, 6, 3, SHADOW_L)

        # Bone Mask facing West (left)
        rect(f, 9 + lunge, by + 1, 5, 6, MASK)
        rect(f, 12 + lunge, by + 2, 2, 5, MASK_D)
        put(f, 10 + lunge, by + 3, CRIMSON)  # Glowing eye
        put(f, 11 + lunge, by - 1, MASK)     # Horn

        # Claws & legs
        rect(f, 7 + lunge, by + 6, 3, 2, SHADOW_L)
        rect(f, 12 + stride, 24, 2, 5, SHADOW)
        rect(f, 17 - stride, 24, 2, 5, SHADOW)

        sheet.paste(add_outline(f), (i * 32, 0))
    return sheet


def build_town_center_sheet() -> Image.Image:
    sheet = new_canvas(48 * 4, 48)
    for i in range(4):
        f = new_canvas(48, 48)
        # Ruined Stone Hearth / Pillar Base
        rect(f, 8, 22, 6, 22, STONE)
        rect(f, 6, 20, 10, 3, STONE_L)
        rect(f, 34, 24, 6, 20, STONE_D)
        rect(f, 32, 22, 9, 3, STONE)
        rect(f, 14, 38, 20, 6, STONE_D)
        rect(f, 16, 40, 16, 4, DIRT_D)

        # Crossed Campfire Logs
        rect(f, 18, 39, 12, 3, WOOD)
        rect(f, 20, 37, 8, 3, WOOD_D)

        # Flickering Campfire Flames (4-frame variation)
        fh = [10, 12, 9, 11][i]
        fx = [0, 1, -1, 0][i]
        rect(f, 20, 38 - fh, 8, fh, FIRE_D)
        rect(f, 21 + fx, 39 - (fh - 2), 6, fh - 2, FIRE_M)
        rect(f, 22 + fx, 40 - (fh - 5), 4, fh - 5, FIRE_L)
        put(f, 23 - fx, 26 - (i % 2) * 2, FIRE_L)  # Spark

        sheet.paste(add_outline(f), (i * 48, 0))
    return sheet


def build_wooden_wall_states() -> Image.Image:
    sheet = new_canvas(32 * 4, 48)

    # State 0: PLACEHOLDER (Wooden stakes + rope marker)
    f0 = new_canvas(32, 48)
    rect(f0, 8, 36, 3, 10, WOOD_D)
    rect(f0, 21, 36, 3, 10, WOOD_D)
    rect(f0, 10, 40, 12, 2, GOLD_D)
    sheet.paste(add_outline(f0), (0, 0))

    # State 1: UNDER_CONSTRUCTION (Half-height palisade + scaffold)
    f1 = new_canvas(32, 48)
    rect(f1, 6, 40, 20, 6, STONE_D)
    for x in [7, 12, 17, 22]:
        rect(f1, x, 26, 4, 15, WOOD)
        rect(f1, x + 1, 26, 2, 15, WOOD_L)
    rect(f1, 6, 33, 20, 3, WOOD_D)
    sheet.paste(add_outline(f1), (32, 0))

    # State 2: COMPLETED (Reinforced Stone-Base Wooden Palisade)
    f2 = new_canvas(32, 48)
    rect(f2, 5, 38, 22, 8, STONE)
    rect(f2, 5, 38, 22, 2, STONE_L)
    for x in [6, 11, 16, 21]:
        rect(f2, x, 12, 5, 27, WOOD)
        rect(f2, x + 1, 13, 2, 25, WOOD_L)
        put(f2, x + 2, 10, WOOD_L)
        rect(f2, x + 1, 11, 3, 2, WOOD)
    rect(f2, 5, 22, 22, 3, WOOD_D)
    rect(f2, 5, 31, 22, 3, WOOD_D)
    sheet.paste(add_outline(f2), (64, 0))

    # State 3: DAMAGED (Splintered beams + cracked stone base)
    f3 = new_canvas(32, 48)
    rect(f3, 5, 39, 22, 7, STONE_D)
    rect(f3, 6, 18, 4, 21, WOOD_D)
    rect(f3, 12, 24, 4, 15, WOOD)
    rect(f3, 18, 16, 4, 23, WOOD_D)
    rect(f3, 23, 28, 3, 11, WOOD)
    rect(f3, 5, 30, 18, 3, WOOD_D)
    sheet.paste(add_outline(f3), (96, 0))

    return sheet


def build_resources_sheet() -> Image.Image:
    sheet = new_canvas(32 * 4, 32)

    # 0: Gold Coin Chest
    f0 = new_canvas(32, 32)
    rect(f0, 7, 14, 18, 13, WOOD)
    rect(f0, 7, 12, 18, 4, WOOD_L)
    rect(f0, 7, 17, 18, 2, GOLD_D)
    rect(f0, 14, 16, 4, 4, GOLD_L)
    sheet.paste(add_outline(f0), (0, 0))

    # 1: Wood Timber Pile
    f1 = new_canvas(32, 32)
    rect(f1, 6, 20, 20, 6, WOOD)
    rect(f1, 8, 14, 16, 6, WOOD_L)
    rect(f1, 6, 20, 4, 6, WOOD_D)
    rect(f1, 22, 20, 4, 6, WOOD_D)
    sheet.paste(add_outline(f1), (32, 0))

    # 2: Stone Outcrop
    f2 = new_canvas(32, 32)
    rect(f2, 7, 16, 18, 11, STONE)
    rect(f2, 10, 11, 11, 6, STONE_L)
    rect(f2, 7, 22, 18, 5, STONE_D)
    sheet.paste(add_outline(f2), (64, 0))

    # 3: Forgotten Shrine (Glowing Cyan Rune)
    f3 = new_canvas(32, 32)
    rect(f3, 10, 8, 12, 19, STONE)
    rect(f3, 8, 24, 16, 4, STONE_D)
    rect(f3, 14, 13, 4, 6, SHRINE_C)
    sheet.paste(add_outline(f3), (96, 0))

    return sheet


def build_shore_tile() -> Image.Image:
    tile = new_canvas(32, 32)
    rect(tile, 0, 0, 32, 4, GRASS_L)
    rect(tile, 0, 4, 32, 4, GRASS)
    rect(tile, 0, 8, 32, 3, GRASS_D)
    rect(tile, 0, 11, 32, 21, DIRT)
    for px, py in [(4, 15), (14, 21), (24, 14), (9, 26), (20, 27), (28, 22)]:
        rect(tile, px, py, 3, 2, DIRT_D)
    for gx in [2, 9, 17, 25]:
        put(tile, gx, 0, GRASS)
        put(tile, gx + 2, 3, GRASS_D)
    return tile


def main() -> None:
    outputs = {
        "characters/player/player_monarch_sheet.png": build_monarch_sheet(),
        "characters/npc/npc_builder_sheet.png": build_builder_sheet(),
        "enemies/first_enemy/enemy_greedling_raider_sheet.png": build_raider_sheet(),
        "buildings/town_center/building_town_center_sheet.png": build_town_center_sheet(),
        "buildings/wooden_wall/building_wooden_wall_states.png": build_wooden_wall_states(),
        "items/resources/items_resources_sheet.png": build_resources_sheet(),
        "environment/terrain/terrain_shore_tile.png": build_shore_tile(),
    }

    for rel_path, img in outputs.items():
        dst = ASSETS_DIR / rel_path
        dst.parent.mkdir(parents=True, exist_ok=True)
        img.save(dst, format="PNG")
        print(f"Generated: assets/{rel_path} ({img.width}x{img.height})")


if __name__ == "__main__":
    main()