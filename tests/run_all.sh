#!/usr/bin/env bash
# N4.4 Step 3 runner (round 2): platform-explicit, sandboxed, save-guarded.
#
#   - Linux (supported platform): the WHOLE run executes inside a fresh
#     temporary user data base — HOME/XDG_DATA_HOME/XDG_CACHE_HOME are
#     redirected BEFORE any Godot process starts — and a dedicated gate step
#     PROVES that user:// really resolves inside that sandbox before the
#     import step or any suite runs (an env override alone is never trusted).
#     The developer's real user data directory is never a write target; a
#     byte-level guard fingerprints it before and after the run and fails the
#     runner on any change.
#   - Non-Linux: explicit UNSUPPORTED exit before doing anything (fail-closed:
#     the run-wide sandbox, guarded rm -rf cleanup and save-guard paths are
#     validated on Linux only, and no suite may run without a proven
#     isolation sandbox). Suites needing the sandbox self-report an explicit
#     counted SKIP (exit 2 + a "^SKIP:" line) when invoked directly on other
#     platforms — never a fake PASS.
#   - The summary separates PASS / FAIL / SKIP and never claims
#     "ALL SUITES PASSED" while a suite was skipped.
#   - Audit round 3: the save guard targets the developer's REAL user data
#     location honoring a custom absolute XDG_DATA_HOME exactly like Godot
#     does (relative/absent XDG falls back to $HOME/.local/share), and the
#     sandbox base must canonicalize to itself (readlink -m, fail-closed).
#   - Final audit: the runner sandbox gate is an ABSOLUTE prerequisite. Its
#     verdict is re-derived from the same evidence the runner mechanism uses
#     (exit code + error markers + expected PASS line + no SKIP) — a printed
#     PASS alone is never sufficient — and any doubt aborts the runner BEFORE
#     the import step or any suite, still fingerprinting the real user data
#     afterwards and cleaning only the runner's own sandbox. Regression:
#     tests/test_runner_gate_failfast.sh (fake Godot, scenarios A/B/C).
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG_DIR="$(mktemp -d)"
failed=0
passed=0
skipped=0
skipped_names=""
LAST_STEP_RC=0
run_godot() {
  local name="$1" args="$2" pass="${3:-}" log="${LOG_DIR}/${1// /_}.log" rc=0
  echo "== ${name}"
  "${GODOT}" --headless ${args} 2>&1 | tee "${log}" || rc=$?
  LAST_STEP_RC="${rc}"
  if grep -E "(SCRIPT ERROR:|Parser Error:|TEST FAILURE:)" "${log}" > /dev/null; then
    echo "FAILED: ${name} (error marker found in log)"
    failed=$((failed + 1))
  elif [ "${rc}" -eq 2 ] && grep -q "^SKIP:" "${log}"; then
    echo "SKIPPED: ${name}"
    skipped=$((skipped + 1))
    skipped_names+=" ${name};"
  elif [ -n "${pass}" ] && ! grep -q "${pass}" "${log}"; then
    echo "FAILED: ${name} (missing PASS line: ${pass})"
    failed=$((failed + 1))
  elif [ "${rc}" -ne 0 ]; then
    echo "FAILED: ${name} (exit code ${rc})"
    failed=$((failed + 1))
  else
    passed=$((passed + 1))
  fi
}
PLATFORM="$(uname -s)"
if [ "${PLATFORM}" != "Linux" ]; then
  echo "PLATFORM UNSUPPORTED: ${PLATFORM}"
  echo "This runner is validated on Linux only: its run-wide sandbox (HOME/XDG"
  echo "redirection), guarded rm -rf cleanup and save-guard paths are Linux-"
  echo "specific, and no suite may run without a proven isolation sandbox."
  echo "Nothing was executed and no save was touched. Suites self-report SKIP"
  echo "when invoked directly on unsupported platforms."
  rm -rf -- "${LOG_DIR}"
  exit 3
fi
echo "== Repository static verifier"
python3 tests/verify_repo_integrity.py || failed=$((failed + 1))
# --- Save guard: fingerprint the developer's REAL user data dir up front ---
REAL_HOME="${HOME}"
REAL_XDG_DATA="${XDG_DATA_HOME:-}"
# F3 (audit round 3): mirror Godot's own resolution — XDG_DATA_HOME is used
# ONLY when it is an absolute path; otherwise Godot falls back to
# $HOME/.local/share (see the engine warning "XDG_DATA_HOME is a relative
# path. Ignoring its value and falling back to $HOME/.local/share"). The
# fingerprint must target the location the developer's Godot REALLY uses.
case "${REAL_XDG_DATA}" in
  /*) REAL_DATA_BASE="${REAL_XDG_DATA}" ;;
  *) REAL_DATA_BASE="${REAL_HOME}/.local/share" ;;
esac
REAL_USER_DATA="${REAL_DATA_BASE}/godot/app_userdata/CROWNFALL- THE LAST LIGHT"
real_dir_fingerprint() {
  if [ ! -d "${REAL_USER_DATA}" ]; then
    printf "absent"
    return
  fi
  find "${REAL_USER_DATA}" -type f -print0 2>/dev/null | sort -z | xargs -0 -r md5sum 2>/dev/null | md5sum | awk '{print $1}'
}
FP_BEFORE="$(real_dir_fingerprint)"
echo "== Save guard (before): real user data fingerprint = ${FP_BEFORE}"
# --- Run-wide temporary user data sandbox (created BEFORE any Godot call) ---
RUNNER_SANDBOX_BASE="$(mktemp -d /tmp/step3_runner_iso_XXXXXXXX)"
case "${RUNNER_SANDBOX_BASE}" in
  /tmp/step3_runner_iso_*) ;;
  *) echo "INTERNAL ERROR: unexpected sandbox path ${RUNNER_SANDBOX_BASE}"; rm -rf -- "${LOG_DIR}"; exit 1 ;;
esac
# F5 (audit round 3): the sandbox base must canonicalize to itself (no
# symlink component anywhere on the path) — fail-closed otherwise.
SANDBOX_CANON="$(readlink -m -- "${RUNNER_SANDBOX_BASE}")"
if [ "${SANDBOX_CANON}" != "${RUNNER_SANDBOX_BASE}" ]; then
  echo "INTERNAL ERROR: sandbox base does not canonicalize to itself (${RUNNER_SANDBOX_BASE} -> ${SANDBOX_CANON}); refusing to run (fail-closed)"
  rm -rf -- "${RUNNER_SANDBOX_BASE}"
  rm -rf -- "${LOG_DIR}"
  exit 1
fi
HOME="${RUNNER_SANDBOX_BASE}/home"
XDG_DATA_HOME="${RUNNER_SANDBOX_BASE}/xdg-data"
XDG_CACHE_HOME="${RUNNER_SANDBOX_BASE}/xdg-cache"
mkdir -p "${HOME}" "${XDG_DATA_HOME}" "${XDG_CACHE_HOME}"
export HOME XDG_DATA_HOME XDG_CACHE_HOME RUNNER_SANDBOX_BASE
echo "== Run sandbox: ${RUNNER_SANDBOX_BASE} (all Godot processes inherit the HOME/XDG overrides)"
run_godot "Runner sandbox gate" "--script res://tests/test_runner_sandbox_gate.gd" "PASS: runner sandbox gate"
# --- Final audit (F1): the sandbox gate is an ABSOLUTE prerequisite. ---
# The verdict is NOT taken from a printed PASS alone: it is re-derived from
# the same evidence the runner mechanism itself uses (exit code, error
# markers, expected PASS line, no SKIP). Any doubt stops the runner here —
# before the import step or any suite can execute (fail-closed) — while the
# final save-guard fingerprint still runs (did the gate itself touch the
# real data?), only the runner's own sandbox is cleaned, and the diagnostic
# gate log is kept.
GATE_LOG="${LOG_DIR}/Runner_sandbox_gate.log"
GATE_FAIL_REASON=""
if [ ! -f "${GATE_LOG}" ]; then
  GATE_FAIL_REASON="gate log missing (gate step did not run)"
elif grep -E "(SCRIPT ERROR:|Parser Error:|TEST FAILURE:)" "${GATE_LOG}" > /dev/null; then
  GATE_FAIL_REASON="error marker found in gate log"
elif grep -q "^SKIP:" "${GATE_LOG}"; then
  GATE_FAIL_REASON="gate reported SKIP — sandbox not proven on this platform"
elif ! grep -q "PASS: runner sandbox gate" "${GATE_LOG}"; then
  GATE_FAIL_REASON="missing gate PASS line"
elif [ "${LAST_STEP_RC}" -ne 0 ]; then
  GATE_FAIL_REASON="gate exit code ${LAST_STEP_RC}"
fi
if [ -n "${GATE_FAIL_REASON}" ]; then
  echo "RUNNER ABORTED BEFORE ANY SUITE: sandbox gate not proven (${GATE_FAIL_REASON})"
  echo "Fail-closed: no project import and no suite was or will be executed."
  FP_AFTER="$(real_dir_fingerprint)"
  echo "== Save guard (after abort): real user data fingerprint = ${FP_AFTER}"
  if [ "${FP_AFTER}" != "${FP_BEFORE}" ]; then
    echo "SAVE GUARD FAILURE: the real user data directory changed during the aborted run (before=${FP_BEFORE} after=${FP_AFTER})"
    failed=$((failed + 1))
  else
    echo "SAVE GUARD OK: real user data directory unchanged across the aborted run"
  fi
  rm -rf -- "${RUNNER_SANDBOX_BASE}"
  echo "SUMMARY (aborted at gate): passed=${passed} failed=${failed} skipped=${skipped} — diagnostics kept in ${LOG_DIR}"
  exit 1
fi
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
run_godot "N43C full flow" "--script res://tests/test_n43c_full_flow.gd" "PASS: All .* N43C Full Flow"
run_godot "N44A ruins foundation" "--script res://tests/test_n44a_ruins_foundation.gd" "PASS: All .* N44A Ruins Foundation"
run_godot "N44B chamber presentation" "--script res://tests/test_n44b_chamber_presentation.gd" "PASS: All .* N44B Chamber Presentation"
run_godot "N44C crown interaction" "--script res://tests/test_n44c_crown_interaction.gd" "PASS: All .* N44C Crown Interaction"
run_godot "N44D vision sequence" "--script res://tests/test_n44d_vision_sequence.gd" "PASS: All .* N44D Vision Sequence"
run_godot "N44 full flow" "--script res://tests/test_n44_full_flow.gd" "PASS: All .* N44 Full Flow"
run_godot "N45A voyage shipwreck" "--script res://tests/test_n45a_voyage_shipwreck.gd" "PASS: All .* N45A Voyage Shipwreck"
run_godot "N45B forgotten shore handoff" "--script res://tests/test_n45b_forgotten_shore_handoff.gd" "PASS: All .* N45B Forgotten Shore Handoff"
run_godot "N45C real handoff integration" "--script res://tests/test_n45c_real_handoff_integration.gd" "PASS: All .* N45C Real Handoff Integration"
run_godot "N50 chapter1 boundary" "--script res://tests/test_n50_chapter1_boundary.gd" "PASS: All .* N50 Chapter I Boundary"
run_godot "N51 first foothold" "--script res://tests/test_n51_foothold_beat.gd" "PASS: All .* N51 First Foothold"
run_godot "N52 first night narrative" "--script res://tests/test_n52_first_night_narrative.gd" "PASS: All .* N52 First Night Narrative"
run_godot "N53 scientist research narrative" "--script res://tests/test_n53_scientist_research_narrative.gd" "PASS: All .* N53 Scientist Research Narrative"
run_godot "N54 vessel readiness narrative" "--script res://tests/test_n54_vessel_readiness_narrative.gd" "PASS: All .* N54 Vessel Readiness Narrative"
run_godot "N44 Step3 shrine autosave" "--script res://tests/test_n44_step3a_shrine_autosave.gd" "PASS: All .* N44 Step3 3A"
run_godot "N44 Step3 world_time types" "--script res://tests/test_n44_step3b_world_time_types.gd" "PASS: All .* N44 Step3 3B"
run_godot "N44 Step3 rollback era" "--script res://tests/test_n44_step3c_rollback_era.gd" "PASS: All .* N44 Step3 3C"
run_godot "N55 Eldergrove handoff" "--script res://tests/test_n55_eldergrove_handoff.gd" "PASS: All .* N55 Eldergrove Handoff"
run_godot "N56 Island continue" "--script res://tests/test_n56_island_continue.gd" "PASS: All .* N56 Island Continue"
# --- Save guard (after): the real user data dir must be unchanged ---
FP_AFTER="$(real_dir_fingerprint)"
echo "== Save guard (after): real user data fingerprint = ${FP_AFTER}"
if [ "${FP_AFTER}" != "${FP_BEFORE}" ]; then
  echo "SAVE GUARD FAILURE: the real user data directory changed during the run (before=${FP_BEFORE} after=${FP_AFTER})"
  failed=$((failed + 1))
else
  echo "SAVE GUARD OK: real user data directory unchanged across the full run"
fi
# --- Guarded cleanup: only our own mktemp bases are ever removed ---
rm -rf -- "${RUNNER_SANDBOX_BASE}"
if [ "${skipped}" -gt 0 ]; then
  echo "SUMMARY: passed=${passed} failed=${failed} skipped=${skipped} [${skipped_names}]"
else
  echo "SUMMARY: passed=${passed} failed=${failed} skipped=${skipped}"
fi
if [ "${failed}" -ne 0 ]; then
  echo "SOME SUITES FAILED (logs in ${LOG_DIR})"
  exit 1
fi
if [ "${skipped}" -ne 0 ]; then
  echo "ALL SUPPORTED SUITES PASSED — ${skipped} suite(s) SKIPPED (see SKIPPED lines above); not claimed as ALL SUITES PASSED"
  exit 0
fi
echo "ALL SUITES PASSED"
