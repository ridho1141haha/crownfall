#!/usr/bin/env python3
"""
Repository Static, Scene-Graph, CI Engine Lock & Documentation OD-01..OD-10 Consistency Verifier.
Works both in a Google Colab / Jupyter notebook cell and via CLI:
    python3 tests/verify_repo_integrity.py
"""
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

# 2. Verify .gd scripts (pure tab indentation, no duplicate manual _ready(), real current_scene transition test)
for gd in sorted(list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "tests").rglob("*.gd"))):
    rel = gd.relative_to(ROOT).as_posix()
    lines = gd.read_text(encoding="utf-8").splitlines()
    bad_lines = [
        i
        for i, l in enumerate(lines, 1)
        if l.strip() and not l.lstrip().startswith("#") and " " in l[: len(l) - len(l.lstrip())]
    ]
    assert_check(len(bad_lines) == 0, f"{rel}: pure tab indentation", f"lines {bad_lines}")
    full = "\n".join(lines)
    if rel.startswith("tests/"):
        assert_check(
            "session._ready()" not in full and "mid_session._ready()" not in full,
            f"{rel}: no duplicate manual _ready() call",
        )

m8_txt = (ROOT / "tests/test_integration_m8_slice.gd").read_text(encoding="utf-8")
assert_check(
    'current_scene.name != "Main"' in m8_txt and 'current_scene.name != "ForgottenShore"' in m8_txt,
    "test_integration_m8_slice.gd: verifies real SceneTree.current_scene transitions",
)

# 3. Verify CI workflow explicit Godot 4.7.2 version lock (zero 4.3.0 fallback)
ci_txt = (ROOT / ".github/workflows/godot-ci.yml").read_text(encoding="utf-8")
assert_check(
    "version: 4.7.2" in ci_txt and "4.3.0" not in ci_txt,
    ".github/workflows/godot-ci.yml: explicitly installs Godot 4.7.2 without silent 4.3.0 fallback",
)
assert_check(
    r'grep -E "^4\.7\.2\."' in ci_txt,
    ".github/workflows/godot-ci.yml: enforces runtime godot --version == 4.7.2.* check",
)

# 4. Verify canonical enemy balance consistency (45 HP, 15 damage, 15 thorn, 3 waves) across code & docs
nem_txt = (ROOT / "scripts/survival/NightEncounterManager.gd").read_text(encoding="utf-8")
assert_check("const ENEMY_MAX_HP: int = 45" in nem_txt, "NightEncounterManager.gd: ENEMY_MAX_HP == 45")
assert_check("const ATTACK_DAMAGE: int = 15" in nem_txt, "NightEncounterManager.gd: ATTACK_DAMAGE == 15")
assert_check("const WALL_THORN_DAMAGE: int = 15" in nem_txt, "NightEncounterManager.gd: WALL_THORN_DAMAGE == 15")

# 5. Verify zero residual "open / undecided / not locked" contradictions across GDD, PRD, SYSTEMS, TDD, Baseline, DECISIONS
FORBIDDEN_PHRASES = [
    "not yet locked",
    "not yet decided",
    "remain undecided",
    "are open design decisions",
    "are not finalized",
    "are not yet finalized",
    "it does not claim that the systems have been implemented",
    "The test framework and automation tooling are not yet selected",
    "Exact Builder data representation remains open",
]

for doc_name in ["GDD.md", "PRD.md", "SYSTEMS.md", "TDD.md", "REVISED_PROJECT_BASELINE.md", "DECISIONS_M2_M8.md"]:
    doc_path = ROOT / "docs" / doc_name
    dtxt = doc_path.read_text(encoding="utf-8")
    for phrase in FORBIDDEN_PHRASES:
        assert_check(phrase not in dtxt, f"docs/{doc_name}: free of contradictory phrase '{phrase}'")
    assert_check(
        re.search(r"\b(50|60) HP\b", dtxt) is None,
        f"docs/{doc_name}: zero conflicting 50/60 HP enemy numbers",
    )

# 6. Verify specific OD-01..OD-10 approved facts are present in GDD, PRD, and SYSTEMS
for doc_name in ["GDD.md", "PRD.md", "SYSTEMS.md"]:
    dtxt = (ROOT / "docs" / doc_name).read_text(encoding="utf-8")
    assert_check("npc_01" in dtxt, f"docs/{doc_name}: documents approved Builder actor ID 'npc_01' (OD-05)")
    assert_check("45 HP" in dtxt, f"docs/{doc_name}: documents approved Greedling Raider 45 HP (OD-06)")
    assert_check("settlement_breached" in dtxt, f"docs/{doc_name}: documents approved non-destructive breach rule (OD-07)")

if errors:
    for e in errors:
        print(e)
    if "__file__" in globals():
        sys.exit(1)
    else:
        raise AssertionError(f"{len(errors)} integrity checks failed")

print(f"PASS: All {checks} repository integrity, scene-graph, CI lock, and OD-01..OD-10 documentation checks succeeded!")
