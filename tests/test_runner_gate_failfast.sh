#!/usr/bin/env bash
# Final audit regression (F1): the runner sandbox gate in tests/run_all.sh is
# an ABSOLUTE prerequisite. Uses a FAKE Godot executable — no engine, no real
# suite and no real user data are involved; every fake invocation is recorded
# to a call log so the assertions prove the CALL GRAPH, not just exit codes.
#
#   A  fake gate refuses (TEST FAILURE marker + exit 1)
#        -> runner stops BEFORE --import and before any suite; exit nonzero;
#           the aborted-run save guard still runs; only the runner's own
#           sandbox is cleaned; diagnostics are kept.
#   B  fake gate proves (PASS line + exit 0)
#        -> runner continues (the --import invocation MUST appear); exit 0.
#   C  fake gate prints the PASS line but exits nonzero
#        -> runner STILL stops: a printed PASS alone is never sufficient.
#
# PLATFORM: Linux (the runner itself is Linux-only by design).
set -u
cd "$(dirname "$0")/.."

fails=0
assert() { # assert <description> <0|1>
  if [ "$2" -eq 0 ]; then
    echo "CHECK OK: $1"
  else
    echo "TEST FAILURE: $1"
    fails=$((fails + 1))
  fi
}

WORK="$(mktemp -d /tmp/step3_gate_regr_XXXXXXXX)"
FAKE_BIN="${WORK}/fakebin"
CALLLOG="${WORK}/calls.log"
mkdir -p "${FAKE_BIN}"
: > "${CALLLOG}"
export FAKE_GODOT_CALLLOG="${CALLLOG}"

cat > "${FAKE_BIN}/fake-godot" <<'EOF'
#!/usr/bin/env bash
# Fake Godot under regression: records argv, then behaves per scenario.
printf 'ARGS: %s\n' "$*" >> "${FAKE_GODOT_CALLLOG}"
case "$*" in
  *test_runner_sandbox_gate.gd*)
    case "${FAKE_GODOT_SCENARIO}" in
      A) echo "TEST FAILURE: sandbox gate: fake refusal — no sandbox proof"; exit 1 ;;
      B) echo "CHECK OK: fake gate proof"; echo "PASS: runner sandbox gate — fake proof (5 checks)"; exit 0 ;;
      C) echo "CHECK OK: fake gate proof"; echo "PASS: runner sandbox gate — fake proof (5 checks)"; exit 7 ;;
    esac ;;
esac
# Any non-gate invocation (import or a suite): report an explicit counted
# SKIP so scenario B's continuation reaches the summary without executing
# anything real.
echo "SKIP: fake step (regression fake, nothing real runs)"
exit 2
EOF
chmod 755 "${FAKE_BIN}/fake-godot"

RUN_RC=0
run_scenario() { # run_scenario <A|B|C>
  : > "${CALLLOG}"
  HOME="${WORK}/home" XDG_DATA_HOME="${WORK}/xdg" TMPDIR="${WORK}" \
    GODOT="${FAKE_BIN}/fake-godot" FAKE_GODOT_SCENARIO="$1" \
    bash tests/run_all.sh > "${WORK}/out_$1.txt" 2>&1
  RUN_RC=$?
}

suite_calls() { grep -c -- '--script' "${CALLLOG}" || true; }

# --- Skenario A: gate menolak -> runner harus berhenti SEBELUM --import ---
run_scenario A
assert "A: runner exit nonzero ketika gate menolak" $([ "${RUN_RC}" -ne 0 ] && echo 0 || echo 1)
assert "A: tepat satu invokasi Godot — hanya gate, tanpa langkah lain" \
  $([ "$(suite_calls)" -eq 1 ] && grep -q "test_runner_sandbox_gate.gd" "${CALLLOG}" && echo 0 || echo 1)
assert "A: TIDAK ada --import setelah gate ditolak" $(grep -q -- '--import' "${CALLLOG}" && echo 1 || echo 0)
assert "A: runner mencetak RUNNER ABORTED" $(grep -q "RUNNER ABORTED" "${WORK}/out_A.txt" && echo 0 || echo 1)
assert "A: save guard tetap dijalankan pada jalur abort" $(grep -q "Save guard (after abort)" "${WORK}/out_A.txt" && echo 0 || echo 1)
assert "A: sandbox dibersihkan + log diagnostik dipertahankan" \
  $(grep -q "SUMMARY (aborted at gate)" "${WORK}/out_A.txt" && grep -q "diagnostics kept in" "${WORK}/out_A.txt" && echo 0 || echo 1)

# --- Skenario B: gate terbukti (PASS + exit 0) -> runner BOLEH melanjutkan ---
run_scenario B
assert "B: runner exit 0 ketika gate terbukti" $([ "${RUN_RC}" -eq 0 ] && echo 0 || echo 1)
assert "B: --import dijalankan setelah gate terbukti" $(grep -q -- '--import' "${CALLLOG}" && echo 0 || echo 1)
assert "B: run berlanjut sampai save guard + summary" \
  $(grep -q "SAVE GUARD OK" "${WORK}/out_B.txt" && grep -q "SUMMARY:" "${WORK}/out_B.txt" && echo 0 || echo 1)

# --- Skenario C: PASS tercetak tapi exit nonzero -> runner tetap berhenti ---
run_scenario C
assert "C: runner exit nonzero meski PASS tercetak (exit 7)" $([ "${RUN_RC}" -ne 0 ] && echo 0 || echo 1)
assert "C: TIDAK ada --import setelah PASS-but-nonzero" $(grep -q -- '--import' "${CALLLOG}" && echo 1 || echo 0)
assert "C: tepat satu invokasi Godot — hanya gate" $([ "$(suite_calls)" -eq 1 ] && echo 0 || echo 1)
assert "C: alasan abort menyebut exit code gate" $(grep -q "gate exit code 7" "${WORK}/out_C.txt" && echo 0 || echo 1)

echo "--- ringkasan ---"
if [ "${fails}" -eq 0 ]; then
  echo "PASS: runner gate fail-fast regression (A/B/C) — kegagalan gate terbukti menghentikan runner sebelum suite berikutnya"
  rm -rf -- "${WORK}"
  exit 0
fi
echo "TEST FAILURE: runner gate fail-fast regression: ${fails} check gagal — bukti disimpan di ${WORK}"
exit 1
