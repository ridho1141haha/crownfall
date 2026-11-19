# CROWNFALL — N4.4 Step 3 Review Fix Report

**Tanggal:** 18 November 2026
**Objek review:** `N44_STEP3_WORKING_TREE.patch` (perbaikan P0.1 / P1.2 / P0.2 di atas `0e4342df42d26fc43100e4365aa3eff88adee9c6`)
**Batasan dihormati:** tidak ada commit/push, PR #23 tidak disentuh, Step 4 tidak dimulai, seluruh perbaikan P0.1/P1.2/P0.2 dipertahankan, **nol perubahan kode produksi** pada putaran ini.

---

## 1. Temuan review yang ditindaklanjuti

| # | Temuan | Tindak lanjut | Status |
| --- | --- | --- | --- |
| F1 | Test isolation P0.1: suite 3A memakai `user://save_slot_0.json` dan hanya mengandalkan snapshot/restore di akhir run | Isolasi struktural test-only: suite meng-eksekusi ulang dirinya sebagai child proses dengan user data dir sementara; save asli tidak pernah menjadi target tulisan mana pun | ✅ Selesai |
| F2 | Kompatibilitas `day_count` perlu divalidasi terhadap format historis | Kontrak ditelusuri ke sumber (`EconomyLedger.is_exact_int_value`); representasi valid per kontrak dipin oleh test baru; validasi TIDAK dilonggarkan | ✅ Selesai |
| F3 | Subscriber `load_failed` — risiko emisi ganda saat rollback gagal | Audit semua koneksi: tepat SATU subscriber diagnostik; tidak ada risiko state/UI; desain sinyal TIDAK diubah (dengan justifikasi); kontrak dipin oleh test | ✅ Selesai |
| F4 | Fixture 3B/3C tidak dibersihkan | Cleanup terpandu (hanya direktori milik test sendiri) + check hasilnya | ✅ Selesai |
| F5 | Verifikasi akhir belum mencakup `run_all.sh` penuh | Dieksekusi penuh: **ALL SUITES PASSED** (exit 0) | ✅ Selesai |

## 2. Perubahan file dan alasannya

| File | Perubahan | Alasan |
| --- | --- | --- |
| `tests/test_n44_step3a_shrine_autosave.gd` | Ditulis ulang dengan kontrak isolasi struktural: mode PARENT (snapshot byte-exact slot asli → spawn child via `OS.execute` dengan `HOME`/`XDG_DATA_HOME`/`XDG_CACHE_HOME` menunjuk direktori sementara baru → relay output → verifikasi slot asli byte-exact → cleanup terpandu) dan mode CHILD (verifikasi sandbox SEBELUM scene/save apa pun: user dir ≠ dir normal, di dalam base temp, jalur autosave di dalam base, tanpa slot pra-ada). Check naik 23→28 | F1: perlindungan kini struktural — alur game tidak pernah berjalan di user data normal; `_finish()` bukan lagi satu-satunya perlindungan; bekerja saat langsung maupun via `run_all.sh` tanpa kerja sama launcher |
| `tests/test_n44_step3b_world_time_types.gd` | Blok "Layer 1b: day_count contract" (4 check), 4 probe baru `TimeManager.apply_save_dict` (2.5 ditolak, NaN ditolak, 2.0 diterima & diterapkan), 1 kasus end-to-end integral-float, cleanup fixture `user://step3b` + helper `_rmtree`. Check naik 52→63 | F2 + F4 |
| `tests/test_n44_step3c_rollback_era.gd` | Check baru C3: satu-satunya subscriber (`_record_rejection`) mempertahankan teks kegagalan load ASLI setelah rollback sukses; cleanup fixture `user://step3c` + helper `_rmtree`. Check naik 12→14 | F3 + F4 |
| **Produksi: tidak ada** | — | Ketiga perbaikan (FSS reset pra-autosave, guard SaveManager/TimeManager, cek rollback/era) tetap utuh; review ini tidak menuntut perubahan produksi |

Catatan teknis implementasi (terdokumentasi di komentar suite 3A):
- Godot 4.7.2 **tidak punya `OS.execute_with_env`** (diverifikasi via `ClassDB.class_get_method_list`); isolasi memakai `OS.set_environment` pada proses parent sebelum `OS.execute` — child mewarisi seluruh env; env dipulihkan setelahnya. `OS.get_user_data_dir()` di build ini re-derive dari env, sehingga dir "normal" diklaim **sebelum** env diubah (bug awal ditemukan & diperbaiki).
- `list_dir_begin()` 4.7.2 menyembunyikan dot-entry: walk GDScript tidak bisa menghapus `$HOME/.cache` yang ditulis Godot untuk child (ditemukan via `ls -la` pada sisa run gagal). Karena itu cleanup direktori sementara memakai `rm -rf` **terpandu ketat**: hanya jalur yang dibuat proses sendiri (`/tmp/step3a_iso_<pid>_<usec>`), guard prefix + `dir_exists_absolute`, separator `--`. 3B/3C tetap memakai walk GDScript karena direktori fixture mereka hanya berisi file visible yang ditulis suite sendiri.

## 3. Bukti isolasi save

1. **Struktural (child, sebelum alur apa pun):** `CHECK OK: iso: process user data dir differs from the normal user data dir` / `inside the temporary isolated base` / `autosave path resolves inside the temporary user data dir (/tmp/step3a_iso_…/xdg/godot/app_userdata/CROWNFALL- THE LAST LIGHT/save_slot_0.json)` / `sandbox starts with NO pre-existing autosave slot`.
2. **Parent-level (byte-exact):** `CHECK OK: parent: real autosave slot byte-exact unchanged across the isolated run` — slot asli dibaca sebelum & sesudah child berjalan.
3. **Direct-run tanpa isolasi launcher** (persis cara developer / `run_all.sh`; "dir normal" = user data asli):
   - `normal user data dir (startup): /home/z/.local/share/godot/app_userdata/CROWNFALL- THE LAST LIGHT`
   - md5 `save_slot_0.json` asli: `fe3690fca516c74bf0a213c7b2f697f4` **sebelum = sesudah** seluruh 3 suite direct-run **dan** setelah `run_all.sh` penuh.
   - Fixture `user://step3b` / `user://step3c` tidak tertinggal di user data asli.
4. **Via runner terisolasi:** juga hijau (28/63/14), tanpa sisa `/tmp/step3a_iso_*`.
5. **Via `run_all.sh` penuh:** suite 3A lulus di dalam runner CI standar.

## 4. Hasil kompatibilitas day_count

- **Kontrak aktual** (`scripts/economy/EconomyLedger.gd:25-33`): `is_exact_int_value` menerima `TYPE_INT`, menerima `TYPE_FLOAT` **integral** (`is_equal_approx(f, roundf(f))`), menolak NaN/Inf dan non-integral. Pola konversi skema `int(roundf(float(dict["day_count"])))` (SaveManager) dan migrasi night-event (`SaveManager.gd:213`) memang mengantisipasi float integral — kontrak sengaja menoleransinya.
- **Format historis:** fixture test existing (n40/n41/n42) selalu menulis `day_count` int, dan `TimeManager.to_save_dict` menulis `current_day` (int) — penulis internal proyek tidak pernah menghasilkan `2.0`; toleransi float integral bersifat defensif untuk writer eksternal/lama.
- **Keputusan:** representasi **`2.0` (float integral) VALID per kontrak** → dipin oleh test (diterima di `validate_payload`, `load_state`, `TimeManager.apply_save_dict`, dan end-to-end `load_game_state`); representasi **`2.5` (non-integral) ditolak** di kedua lapis; `NaN` day_count ditolak TimeManager. **Validasi tidak dilonggarkan** — guard TimeManager memakai fungsi kontrak yang sama dengan SaveManager (konsisten).

## 5. Hasil pemeriksaan subscriber load_failed

- Seluruh repo: `load_failed` **hanya** ter-connect di `ForgottenShoreSession.gd:208` → `_record_rejection`, yang hanya menyimpan teks rejection terakhir ke `_last_rejection_reason` (`FSS:62`) — sink bersama 8 sinyal rejection (economy/specialists/research/structures/buildings/recruitment/population/load/save). **Tidak ada** transisi UI, navigasi, atau mutasi state pada subscriber ini.
- Emisi kedua (rollback gagal — jalur yang tidak terinjeksi via payload) hanya akan **menimpa string diagnostik**; tidak ada pemrosesan ganda bermakna, tidak ada perubahan state/transisi UI. Sinyal terpisah (`rollback_failed`) **tidak diperlukan** — perubahan desain sinyal tidak dilakukan sesuai prinsip "usulkan sebelum mengubah" dan justifikasi ini tercatat di sini + komentar test C3.
- Kontrak dipin runtime: `C3: sole subscriber (_record_rejection) retains the original load failure text`.

## 6. Hasil seluruh test

| Eksekusi | Exit | Marker (`SCRIPT ERROR`/`Parser Error`/`TEST FAILURE`) | Hasil |
| --- | --- | --- | --- |
| `step3_check_suite.sh` 3A (HOME terisolasi) | 0 | 0 | `PASS: All 28 checks — N44 Step3 3A` |
| `step3_check_suite.sh` 3B | 0 | 0 | `PASS: All 63 checks — N44 Step3 3B` |
| `step3_check_suite.sh` 3C | 0 | 0 | `PASS: All 14 checks — N44 Step3 3C` |
| Direct-run ketiga suite **tanpa** isolasi launcher | 0 / 0 / 0 | 0 / 0 / 0 | PASS 1× per suite, 0 TEST FAILURE |
| `GODOT=… bash tests/run_all.sh` **PENUH** | **0** — `ALL SUITES PASSED` | **0** di seluruh log | 25 langkah (verifier + import + 23 suite), 1110 baris PASS; Step3: 28/63/14 |
| `git diff --check` | 0 | — | bersih |

Log lengkap: `scripts/step3_logs/` (`run_all_full.log`, `direct_*.log`, `*.log` per suite).

## 7. Risiko yang belum bisa diverifikasi

1. **Cleanup `rm -rf` berbasis `rm` POSIX** — asumsi Linux/CI (konsisten dengan headless test proyek yang Linux-only). Arah kegagalannya aman: di platform tanpa `rm`, check cleanup GAGAL keras (tidak pernah menghapus jalur yang salah — guard prefix + jalur absolut yang dibuat proses sendiri).
2. **`_rmtree` 3B/3C buta terhadap dot-entry** (limitasi `list_dir_begin()` 4.7.2). Saat ini aman karena direktori fixture hanya berisi file visible tulisan suite; jika kelak Godot menulis dotfile di sana, check cleanup akan GAGAL keras (arah aman), bukan diam-diam meninggalkan sampah.
3. **Dua permukaan laporan P0.2** (emit "Rollback failed", cek era) tetap terverifikasi code review saja — tetap tidak terinjeksi via payload tanpa seam produksi baru; tidak diubah putaran ini.
4. Slot `save_slot_0.json` asli di user data developer ada selama verifikasi (dibuat oleh aktivitas proyek sebelumnya, bukan oleh suite ini) — integritasnya diverifikasi byte-exact (md5), tetapi keberadaannya bergantung lingkungan.

## 8. Status Git dan working tree

- **HEAD: `0e4342df42d26fc43100e4365aa3eff88adee9c6`** — tidak berubah; **tidak ada commit/push**; PR #23 tetap OPEN/DRAFT; Step 4 tidak dimulai.
- Working tree: 4 tracked file diubah (dari Step 3: FSS, SaveManager, TimeManager, run_all.sh — **tidak tersentuh lagi** putaran ini) + 3 test suite direvisi putaran ini + 3 sidecar `.uid` baru untuk test tersebut (dibuat otomatis oleh langkah `--import` saat `run_all.sh` penuh; konvensi repo melacak `.uid` — 72 file existing) + 3 dokumen review (Step 2, Step 3, laporan ini).
- `N44_STEP3_WORKING_TREE.patch` **diregenerasi** untuk mencerminkan working tree terkini — kini 13 blok diff (4 modifikasi + 3 suite + 3 `.uid` + 3 dokumen) — diverifikasi ulang `git apply` pada clone bersih + cmp byte-per-byte 13/13 file identik (sha256 baru tercatat di file; patch lama usang dan diganti).

> **Catatan (klarifikasi jumlah, ditambahkan belakangan):** Angka **13 blok diff** dan **13/13 file identik** di atas menggambarkan versi paket **saat laporan ini ditulis** dan akurat untuk versi tersebut (saat itu 3 dokumen review). Paket final kemudian menambahkan **satu dokumen review tambahan** (`N44_STEP3_FINAL_REVIEW_FIX_REPORT.md`), sehingga jumlah otoritatif paket final adalah **14 blok diff/file** dan **14/14 file identik** pada clone bersih — sebagaimana terdokumentasi di §6 `N44_STEP3_FINAL_REVIEW_FIX_REPORT.md`. Angka historis di atas sengaja tidak diubah.
