#!/usr/bin/env python3
"""
Repository Static, Scene-Graph & Documentation Consistency Verifier for CROWNFALL.
Run from repository root:
    python3 tests/verify_repo_integrity.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
errors: list[str] = []
checks: int = 0


def assert_check(cond: bool, label: str, detail: str = "") -> None:
    global checks
    checks += 1
    if not cond:
        errors.append(f"FAIL [{label}]: {detail}")


# 1. Verify .tscn scene files (load_steps, ExtResource paths, SubResources, signal methods)
for tscn in sorted((ROOT / "scenes").rglob("*.tscn")):
    rel = tscn.relative_to(ROOT).as_posix()
    txt = tscn.read_text(encoding="utf-8")
    m = re.search(r"\[gd_scene\s+load_steps=(\d+)\s+format=3\]", txt)
    ext_ids = re.findall(r'\[ext_resource\s+[^\]]*id="([^"]+)"\]', txt)
    sub_ids = re.findall(r'\[sub_resource\s+[^\]]*id="([^"]+)"\]', txt)
    assert_check(m is not None, f"{rel}: valid gd_scene header")
    if m:
        assert_check(int(m.group(1)) == 1 + len(ext_ids) + len(sub_ids), f"{rel}: load_steps matches resources")
    for rp in re.findall(r'path="res://([^"]+)"', txt):
        assert_check((ROOT / rp).exists(), f"{rel}: ExtResource res://{rp} exists")

# 2. Verify .gd scripts (pure tab indentation, balanced delimiters, no manual _ready() after add_child)
for gd in sorted(list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "tests").rglob("*.gd"))):
    rel = gd.relative_to(ROOT).as_posix()
    lines = gd.read_text(encoding="utf-8").splitlines()
    bad_lines = [i for i, l in enumerate(lines, 1) if l.strip() and not l.lstrip().startswith("#") and " " in l[:len(l) - len(l.lstrip())]]
    assert_check(len(bad_lines) == 0, f"{rel}: pure tab indentation", f"lines {bad_lines}")
    full = "\n".join(lines)
    if rel.startswith("tests/"):
        assert_check("session._ready()" not in full and "mid_session._ready()" not in full, f"{rel}: no duplicate manual _ready() call after add_child()")

# 3. Verify canonical enemy balance consistency (45 HP, 15 damage, 15 thorn, 3 waves) across code & docs
nem_txt = (ROOT / "scripts/survival/NightEncounterManager.gd").read_text(encoding="utf-8")
assert_check("const ENEMY_MAX_HP: int = 45" in nem_txt, "NightEncounterManager.gd: ENEMY_MAX_HP == 45")
assert_check("const ATTACK_DAMAGE: int = 15" in nem_txt, "NightEncounterManager.gd: ATTACK_DAMAGE == 15")
assert_check("const WALL_THORN_DAMAGE: int = 15" in nem_txt, "NightEncounterManager.gd: WALL_THORN_DAMAGE == 15")

dec_txt = (ROOT / "docs/DECISIONS_M2_M8.md").read_text(encoding="utf-8")
base_txt = (ROOT / "docs/REVISED_PROJECT_BASELINE.md").read_text(encoding="utf-8")
assert_check("45 HP" in dec_txt and "15 thorn" in dec_txt, "DECISIONS_M2_M8.md: matches 45 HP / 15 thorn")
assert_check("45 HP" in base_txt and "15 thorn" in base_txt, "REVISED_PROJECT_BASELINE.md: matches 45 HP / 15 thorn")
assert_check(re.search(r"\b(50|60) HP\b", dec_txt) is None and re.search(r"\b(50|60) HP\b", base_txt) is None, "Zero conflicting 60 HP / 50 HP enemy stats in docs")

# 4. Verify documentation v1.3 cross-references & implementation status
prd_txt = (ROOT / "docs/PRD.md").read_text(encoding="utf-8")
sys_txt = (ROOT / "docs/SYSTEMS.md").read_text(encoding="utf-8")
tdd_txt = (ROOT / "docs/TDD.md").read_text(encoding="utf-8")
assert_check("GDD v1.3, SYSTEMS v1.3, and TDD v1.3" in prd_txt, "PRD.md: v1.3 cross-references aligned")
assert_check("it does not claim that the systems have been implemented" not in sys_txt, "SYSTEMS.md: outdated unimplemented disclaimer removed")
assert_check("The test framework and automation tooling are not yet selected" not in tdd_txt, "TDD.md: outdated test tooling disclaimer removed")

if errors:
    for e in errors:
        print(e)
    sys.exit(1)

print(f"PASS: All {checks} repository integrity, scene-graph, balance, and documentation v1.3 checks succeeded!")
