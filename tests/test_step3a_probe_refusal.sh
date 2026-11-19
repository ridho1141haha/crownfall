#!/usr/bin/env bash
# Final audit regression (F2): when the 3A parent cannot create the PROBE
# sandbox base exclusively + canonically, it must fail FAST — print a TEST
# FAILURE, quit(1) and return — and NEVER call _run_child_process(). If a
# child had been spawned, its startup artifacts and its own gate's readlink
# queries would be observable.
#
# The refusal is forced deterministically with a fake `readlink` on PATH that
# reports a non-canonical resolution for any probe-shaped base (which makes
# _make_exclusive_base refuse), passes every other query through to the real
# readlink, and LOGS every query.
#
# Evidence asserted:
#   - the suite exits 1 with the explicit refusal message;
#   - NO child-flow marker ever appears (no gate-ok, no A-setup, no payload,
#     no child sandbox-gate output, no post-gate CHECK OK);
#   - the readlink query log contains the probe-base query and NEVER contains
#     a child-gate-shaped query (app_userdata path or bogus claim) — a
#     spawned child would have produced both;
#   - structural audit: the refusal branch sits between the probe-base gate
#     and the child spawn, contains quit(1) + return, never removes the
#     refused location, and the old recorded-check form is gone; the real
#     base keeps its own explicit gate;
#   - cleanup is LEFTOVER-SAFE (round-6 audit P2): the refusal message only
#     proves a path was REFUSED by this run — NOT that this run created it.
#     _make_exclusive_base() checks dir existence, then creates, then
#     validates canonicalization; that sequence is not atomic, so the
#     refused path may pre-exist or may have been created by another process
#     between check and make_dir. This test therefore NEVER removes the
#     refused probe base: the path is extracted from the refusal message
#     (strictly pattern-validated, for reporting only) and reported as
#     LEFTOVER KEPT FOR SAFETY. The only directory this test ever removes
#     is its own mktemp WORK dir.
#
# PLATFORM: Linux (the suite itself is Linux-only by design).
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

WORK="$(mktemp -d /tmp/step3a_refusal_regr_XXXXXXXX)"
FAKE_BIN="${WORK}/fakebin"
RL_LOG="${WORK}/readlink_calls.log"
mkdir -p "${FAKE_BIN}"
: > "${RL_LOG}"
export FAKE_READLINK_LOG="${RL_LOG}"

REAL_READLINK="$(command -v readlink)"
cat > "${FAKE_BIN}/readlink" <<EOF
#!/usr/bin/env bash
# Fake readlink under regression: log the queried path; report a
# non-canonical resolution for probe-shaped bases (forcing the refusal);
# pass everything else through to the real readlink.
printf 'QUERY: %s\n' "\$*" >> "\${FAKE_READLINK_LOG}"
for a in "\$@"; do
  case "\$a" in
    /tmp/step3a_iso_*_probe)
      echo "/noncanonical-by-regression-fake"
      exit 0 ;;
  esac
done
exec "${REAL_READLINK}" "\$@"
EOF
chmod 755 "${FAKE_BIN}/readlink"

GODOT="${GODOT:-godot}"
OUT="${WORK}/out.txt"
PATH="${FAKE_BIN}:${PATH}" "${GODOT}" --headless --path . \
  --script res://tests/test_n44_step3a_shrine_autosave.gd > "${OUT}" 2>&1
RC=$?

assert "suite exit 1 ketika pembuatan probe base ditolak" $([ "${RC}" -eq 1 ] && echo 0 || echo 1)
assert "pesan penolakan eksplisit tercetak (TEST FAILURE)" $(grep -q "probe base refused" "${OUT}" && echo 0 || echo 1)
assert "TIDAK ada marker alur child (gate-ok / A-setup / PAYLOAD)" \
  $(grep -qE "STEP3A\|GATE\|ok|A-setup|STEP3A\|PAYLOAD" "${OUT}" && echo 1 || echo 0)
assert "TIDAK ada output sandbox-gate child (child tidak pernah di-spawn)" \
  $(grep -q "sandbox gate:" "${OUT}" && echo 1 || echo 0)
assert "TIDAK ada CHECK OK: probe (verdict tidak berjalan setelah gate gagal)" \
  $(grep -q "CHECK OK: probe:" "${OUT}" && echo 1 || echo 0)
assert "log readlink memuat query probe base (jalur penolakan benar)" \
  $(grep -q "QUERY: .*step3a_iso_.*_probe" "${RL_LOG}" && echo 0 || echo 1)
assert "log readlink TIDAK memuat query berbentuk child gate (app_userdata)" \
  $(grep -q "app_userdata" "${RL_LOG}" && echo 1 || echo 0)
assert "log readlink TIDAK memuat query bogus claim" \
  $(grep -q "bogus_" "${RL_LOG}" && echo 1 || echo 0)

# --- structural audit of the parent wrapper (belt and suspenders) ---
if python3 - tests/test_n44_step3a_shrine_autosave.gd <<'PYEOF'
import sys
src = open(sys.argv[1]).read()
fn = src.split("func _run_parent_wrapper", 1)[1].split("\nfunc ", 1)[0]
ok = True
if "if not _make_exclusive_base(probe_base):" not in fn:
    print("STRUKTUR: gate probe-base tidak ditemukan"); ok = False
if "_check(_make_exclusive_base(probe_base)" in fn:
    print("STRUKTUR: bentuk lama _check(_make_exclusive_base(probe_base)) masih ada"); ok = False
gate = fn.index("if not _make_exclusive_base(probe_base):")
spawn = fn.index("_run_child_process(probe_base")
between = fn[gate:spawn]
if "quit(1)" not in between or "\treturn" not in between:
    print("STRUKTUR: cabang penolakan tidak memuat quit(1) + return sebelum spawn"); ok = False
if "_rmrf_guarded" in between:
    print("STRUKTUR: cabang penolakan tidak boleh menghapus lokasi yang ditolak"); ok = False
if "if not _make_exclusive_base(temp_base):" not in fn:
    print("STRUKTUR: gate eksklusif base real hilang"); ok = False
sys.exit(0 if ok else 1)
PYEOF
then
  assert "audit struktur: gate fail-fast tepat sebelum spawn, tanpa rm lokasi ditolak" 0
else
  assert "audit struktur: gate fail-fast tepat sebelum spawn, tanpa rm lokasi ditolak" 1
fi

# Cleanup (round-6 audit P2, final): LEFTOVER-SAFE. The refusal message
# proves the path was REFUSED by this run, not that this run created it —
# _make_exclusive_base() checks existence, then creates, then validates, and
# that sequence is not atomic (TOCTOU): the refused path may pre-exist or
# have been created by another process in between. So the refused probe base
# is NEVER removed by this test, no matter what the message says: the path
# is extracted (strictly validated) for REPORTING ONLY and left in place.
# No /tmp scan, no snapshot diff, no rm based on suite output — the only
# directory this test ever removes is its own mktemp WORK dir.
PROBE_BASE_OWNED="$(sed -n 's/.*probe base refused (non-exclusive or non-canonical: \([^)]*\));.*/\1/p' "${OUT}" 2>/dev/null | head -n1)"
OWN_OK=0
if [ -n "${PROBE_BASE_OWNED}" ] && printf '%s' "${PROBE_BASE_OWNED}" | grep -Eq '^/tmp/step3a_iso_[0-9]+_[0-9]+_probe$'; then
  OWN_OK=1
fi
assert "path base probe ter-identifikasi dari pesan penolakan run ini + tervalidasi ketat (untuk PELAPORAN, bukan untuk rm)" \
  $([ "${OWN_OK}" -eq 1 ] && echo 0 || echo 1)
if [ "${OWN_OK}" -eq 1 ]; then
  echo "LEFTOVER KEPT FOR SAFETY: base probe yang ditolak DIBIARKAN tetap ada — path terbukti ditolak run ini tetapi TIDAK terbukti dibuat olehnya (urutan cek->buat tidak atomik; rm di sini berisiko menghapus direktori milik proses lain): ${PROBE_BASE_OWNED}"
  assert "artefak DIBIARKAN tetap ada — test tidak pernah menjalankan rm atas path dari pesan penolakan (kebijakan leftover-safe)" \
    $([ -e "${PROBE_BASE_OWNED}" ] && echo 0 || echo 1)
else
  assert "artefak DIBIARKAN tetap ada — test tidak pernah menjalankan rm atas path dari pesan penolakan (kebijakan leftover-safe)" 1
  echo "LEFTOVER KEPT FOR SAFETY: path base probe tidak ter-identifikasi dari output suite — tidak ada yang dihapus"
fi

echo "--- ringkasan ---"
if [ "${fails}" -eq 0 ]; then
  echo "PASS: 3A probe-base refusal regression — pembuatan probe base yang gagal terbukti TIDAK memulai child (kebijakan leftover-safe: base yang ditolak dibiarkan + dilaporkan, tanpa rm)"
  rm -rf -- "${WORK}"
  exit 0
fi
echo "TEST FAILURE: 3A probe-base refusal regression: ${fails} check gagal — bukti disimpan di ${WORK}"
exit 1
