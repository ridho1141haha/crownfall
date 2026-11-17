#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG_DIR="$(mktemp -d)"
failed=0
run_godot() {
  local name="$1" args="$2" pass="${3:-}" log="${LOG_DIR}/${1// /_}.log"
  echo "== ${name}"
  "${GODOT}" --headless ${args} 2>&1 | tee "${log}"
  if grep -E "(SCRIPT ERROR:|Parser Error:|TEST FAILURE:)" "${log}" > /dev/null; then
    echo "FAILED: ${name} (error marker found in log)"
    failed=1
  elif [ -n "${pass}" ] && ! grep -q "${pass}" "${log}"; then
    echo "FAILED: ${name} (missing PASS line: ${pass})"
    failed=1
  fi
}
echo "== Repository static verifier"
python3 tests/verify_repo_integrity.py || failed=1
run_godot "Project import" "--import"
run_godot "World clock" "--script res://tests/test_time_manager.gd" "PASS: test_time_manager"
run_godot "P0 unit" "--script res://tests/test_unit_m2_m7.gd" "PASS: All .* P0 Unit Checks"
run_godot "P0 scene integration" "--script res://tests/test_integration_m8_slice.gd" "PASS: All .* M8 Multi-Frame Scene Transition"
run_godot "P1 experimental" "--script res://tests/test_experimental_p1_m9_m10.gd" "PASS: All .* Experimental P1 Skeleton Checks"
run_godot "Progression foundation" "--script res://tests/test_progression_foundation.gd" "PASS: All .* Progression Foundation"
run_godot "Phase 2 era correction" "--script res://tests/test_progression_phase2_era_correction.gd" "PASS: All .* Phase 2 Era Correction"
run_godot "Specialist domain" "--script res://tests/test_specialist_domain.gd" "PASS: All .* Specialist Domain Foundation"
run_godot "Research foundation" "--script res://tests/test_research_foundation.gd" "PASS: All .* Research System Foundation"
run_godot "Phase 5 structures & buffs" "--script res://tests/test_structure_buff_phase5.gd" "PASS: All .* Phase 5 Structure & Buff Foundation"
run_godot "Gameplay scenarios (headless)" "--script res://tests/gameplay_scenarios.gd" "PASS: All 10 gameplay scenarios"
run_godot "Narrative foundation" "--script res://tests/test_narrative_foundation.gd" "PASS: All .* Narrative Foundation"
run_godot "Dialogue panel" "--script res://tests/test_dialogue_panel.gd" "PASS: All .* Dialogue Panel"
run_godot "Sequence runner" "--script res://tests/test_sequence_runner.gd" "PASS: All .* Sequence Runner"
run_godot "N4.0 profile & entry gate" "--script res://tests/test_n40_profile_entry_gate.gd" "PASS: All .* N4.0 Profile & Entry Gate"
run_godot "N4.1 prologue shell" "--script res://tests/test_n41_prologue_shell.gd" "PASS: All .* N4.1 Prologue Shell"
run_godot "N4.2 prologue beats" "--script res://tests/test_n42_prologue_beats.gd" "PASS: All .* N4.2 Prologue Beats"
run_godot "N43A exploration stage" "--script res://tests/test_n43a_exploration_stage.gd" "PASS: All .* N43A Exploration Stage"
run_godot "N43B mark inspection" "--script res://tests/test_n43b_mark_inspection.gd" "PASS: All .* N43B Mark Inspection"
if [ "${failed}" -ne 0 ]; then
  echo "SOME SUITES FAILED (logs in ${LOG_DIR})"
  exit 1
fi
echo "ALL SUITES PASSED"
