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
if [ "${failed}" -ne 0 ]; then
  echo "SOME SUITES FAILED (logs in ${LOG_DIR})"
  exit 1
fi
echo "ALL SUITES PASSED"
