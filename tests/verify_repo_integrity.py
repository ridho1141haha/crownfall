#!/usr/bin/env python3
"""
Repository Static, Scene-Graph, CI Fail-Fast Lock & Documentation OD-01..OD-10 Consistency Verifier.
Works both in a Google Colab / Jupyter notebook cell and via CLI:
    python3 tests/verify_repo_integrity.py
"""
import json
import os
import re
import sys
from pathlib import Path


def _resolve_repo_root() -> Path:
    if "__file__" in globals():
        candidate = Path(__file__).resolve().parent.parent
        if (candidate / "project.godot").exists():
            return candidate
    colab_path = Path("/content/drive/MyDrive/crownfall")
    if colab_path.exists():
        return colab_path
    cwd = Path(os.getcwd()).resolve()
    if (cwd / "project.godot").exists():
        return cwd
    return cwd


ROOT = _resolve_repo_root()
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

# 2. Verify .gd scripts (pure tab indentation, zero raw assert() in tests, zero root.add_child in _init)
for gd in sorted(list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "tests").rglob("*.gd"))):
    rel = gd.relative_to(ROOT).as_posix()
    lines = gd.read_text(encoding="utf-8").splitlines()
    bad_lines = [
        i
        for i, l in enumerate(lines, 1)
        if l.strip() and not l.lstrip().startswith("#") and not all(c == "\t" for c in l[: len(l) - len(l.lstrip())])
    ]
    assert_check(len(bad_lines) == 0, f"{rel}: pure tab indentation", f"lines {bad_lines}")
    full = "\n".join(lines)
    if rel.startswith("tests/"):
        assert_check(
            "assert(" not in full and "func _check(" in full,
            f"{rel}: uses fail-fast _check() with quit(1) instead of raw assert()",
        )
        assert_check(
            "root.add_child(" not in full,
            f"{rel}: does not call root.add_child() before scene lifecycle readiness",
        )

# 3. Verify M5 test separates movement ticks from construction work ticks
unit_txt = (ROOT / "tests/test_unit_m2_m7.gd").read_text(encoding="utf-8")
assert_check(
    'for _step: int in range(5):\n\t\tnpc.tick(1.0, bm)' in unit_txt
    and 'is_equal_approx(bm.construction_progress, 0.5)' in unit_txt,
    "test_unit_m2_m7.gd: M5 separates 5s movement phase from 2s construction work phase",
)

# 4. Verify CI workflow explicit Godot 4.7.2 lock & fail-fast SCRIPT ERROR / TEST FAILURE log trap
ci_txt = (ROOT / ".github/workflows/godot-ci.yml").read_text(encoding="utf-8")
assert_check(
    "version: 4.7.2" in ci_txt and "4.3" not in ci_txt,
    ".github/workflows/godot-ci.yml: explicitly installs Godot 4.7.2 without 4.3 fallback",
)
assert_check(
    r'grep -E "^4\.7\.2\."' in ci_txt,
    ".github/workflows/godot-ci.yml: enforces runtime godot --version == 4.7.2.* check",
)
assert_check(
    '! grep -E "(SCRIPT ERROR:|Parser Error:|TEST FAILURE:)"' in ci_txt and "set -o pipefail" in ci_txt,
    ".github/workflows/godot-ci.yml: traps SCRIPT ERROR and TEST FAILURE with non-zero exit",
)

# 5. Verify canonical enemy balance consistency (45 HP, 15 damage, 15 thorn, 3 waves) across code & docs
nem_txt = (ROOT / "scripts/survival/NightEncounterManager.gd").read_text(encoding="utf-8")
assert_check("const ENEMY_MAX_HP: int = 45" in nem_txt, "NightEncounterManager.gd: ENEMY_MAX_HP == 45")
assert_check("const ATTACK_DAMAGE: int = 15" in nem_txt, "NightEncounterManager.gd: ATTACK_DAMAGE == 15")
assert_check("const WALL_THORN_DAMAGE: int = 15" in nem_txt, "NightEncounterManager.gd: WALL_THORN_DAMAGE == 15")

# 6. Verify zero residual "open / undecided / not locked" contradictions across ALL 7 docs (including ASSET_GUIDELINES.md)
FORBIDDEN_PHRASES = [
    "not yet locked",
    "not yet decided",
    "remain undecided",
    "are open design decisions",
    "remain open design decisions",
    "is still open",
    "are not finalized",
    "are not yet finalized",
    "it does not claim that the systems have been implemented",
    "The test framework and automation tooling are not yet selected",
    "Exact Builder data representation remains open",
]

ALL_DOCS = [
    "GDD.md",
    "PRD.md",
    "SYSTEMS.md",
    "TDD.md",
    "ASSET_GUIDELINES.md",
    "REVISED_PROJECT_BASELINE.md",
    "DECISIONS_M2_M8.md",
]

for doc_name in ALL_DOCS:
    doc_path = ROOT / "docs" / doc_name
    dtxt = doc_path.read_text(encoding="utf-8")
    assert_check("1.3" in dtxt[:400], f"docs/{doc_name}: header version is 1.3")
    for phrase in FORBIDDEN_PHRASES:
        assert_check(phrase not in dtxt, f"docs/{doc_name}: free of contradictory phrase '{phrase}'")
    assert_check(
        re.search(r"\b(50|60) HP\b", dtxt) is None,
        f"docs/{doc_name}: zero conflicting 50/60 HP enemy numbers",
    )

# 7. Verify TDD.md Section 5.1 JSON example matches SaveManager.REQUIRED_KEYS (including night_encounter)
tdd_txt = (ROOT / "docs/TDD.md").read_text(encoding="utf-8")
json_match = re.search(r"~~~json\s*(\{.*?\})\s*~~~", tdd_txt, flags=re.DOTALL)
assert_check(json_match is not None, "docs/TDD.md: Section 5.1 contains parseable JSON block")
if json_match:
    parsed_tdd_json = json.loads(json_match.group(1))
    required_save_keys = [
        "schema_version",
        "world_id",
        "island_id",
        "day_count",
        "world_time",
        "world_phase",
        "resources",
        "buildings",
        "npcs",
        "night_encounter",
        "progression_flags",
    ]
    for req_k in required_save_keys:
        assert_check(req_k in parsed_tdd_json, f"docs/TDD.md Section 5.1 JSON: includes required key '{req_k}'")

# 8. Verify readme.md locks Godot 4.7.2.stable without 4.3+ claim
readme_txt = (ROOT / "readme.md").read_text(encoding="utf-8")
assert_check("4.7.2.stable" in readme_txt and "4.3+" not in readme_txt, "readme.md: locked to Godot 4.7.2.stable")

if errors:
    for e in errors:
        print(e)
    if "__file__" in globals():
        sys.exit(1)
    else:
        raise AssertionError(f"{len(errors)} integrity checks failed")

print(f"PASS: All {checks} repository integrity, scene-graph, CI lock, and OD-01..OD-10 documentation checks succeeded!")
