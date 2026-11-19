# CROWNFALL — N4.4 Step 3: Confirmed Bug Fixes & Regression Tests

**Tanggal:** 18 November 2026
**Baseline perilaku:** `docs/reviews/N44_STEP2_REPRODUCTION_REPORT.md` (ada di repo, dipakai sebagai acuan)
**Branch:** `feature/n44a-ruins-foundation` — PR #23 tetap OPEN/DRAFT, tidak di-merge, tidak dimulai Step 4.

---

## 1. Starting dan final commit SHA

| | SHA |
| --- | --- |
| Starting HEAD | `0e4342df42d26fc43100e4365aa3eff88adee9c6` (`0e4342d`) — diverifikasi sesuai spesifikasi sebelum implementasi |
| Final HEAD | `0e4342d` — **tidak ada commit dibuat** (tidak diminta; perubahan hidup di working tree untuk review) |

## 2. Status working tree

Sebelum implementasi: tracked files bersih (`git status --porcelain` hanya `?? docs/reviews/` berisi laporan Step 2). Setelah implementasi:

- **4 tracked file diubah** (lihat §4) — `git diff HEAD --stat`: 45 insertions, 7 deletions.
- **3 file test baru** (untracked): `tests/test_n44_step3a_shrine_autosave.gd`, `tests/test_n44_step3b_world_time_types.gd`, `tests/test_n44_step3c_rollback_era.gd`.
- **2 dokumen review** (untracked): laporan Step 2 (baseline) + laporan Step 3 ini.
- Tidak ada perubahan lain; bukti pre-fix diproduksi via `git stash push`/`pop` (HEAD tidak berubah; diff diverifikasi utuh setelah pop).

## 3. Ringkasan 3A / 3B / 3C

- **3A (P0.1):** titik reset `shrine_offering_used_today` dipindahkan (satu titik, tanpa duplikasi) dari `_on_daylight_started` — yang menyala SETELAH autosave sunrise — ke `_on_sunrise_reached` tepat sebelum `save_game_state()`, mengikuti konvensi blok refresh renewable yang sudah ada. Autosave sunrise kini mencatat hari baru dengan offering tersedia; jalur Continue memulihkan flag benar; perilaku sesi-langsung dan exactly-once tidak berubah.
- **3B (P1.2):** guard tipe eksplisit sebelum konversi numerik — di `SaveManager.validate_payload` (`TYPE_FLOAT`/`TYPE_INT` saja) dan defensif di `TimeManager.apply_save_dict` (tipe `world_time`, konvensi `is_exact_int_value` untuk `day_count`, guard `is_nan`/`is_inf` baru). String numerik/string sampah/boolean **ditolak eksplisit** (bukan koersi senyap); guard finite/range lama dipertahankan; schema_version TIDAK diubah (save legacy selalu menyerialisasi `world_time` sebagai angka JSON — tidak ada break kompatibilitas).
- **3C (P0.2):** hasil rollback-apply kini diperiksa — kegagalan rollback dilaporkan sebagai event terpisah dengan teks berbeda (alasan kegagalan load asli tidak tersentuh); hasil `apply_save_era()` kini diperiksa — `era_id` yang ada tapi gagal apply menggagalkan load; `era_id` kosong/absen tetap ditoleransi (kebijakan backfill migrasi owner di `SaveManager.gd:233–240` tidak diubah). Operasi restore yang `void` (resource/tree) tidak diberi cek return palsu.

## 4. File yang diubah dan alasannya

| File | Perubahan | Alasan |
| --- | --- | --- |
| `scripts/world/ForgottenShoreSession.gd` | (a) reset flag dipindah ke `_on_sunrise_reached` pra-autosave + komentar; (b) `_on_daylight_started` tidak lagi me-reset flag (komentar penunjuk); (c) `load_game_state`: cek hasil `_apply_loaded_payload(snapshot)` + emit terpisah "Rollback failed — …" saat rollback gagal; (d) `_apply_loaded_payload`: cek `apply_save_era` (toleran kosong/absen) | 3A: bukti Step 2 Test A; 3C: hasil rollback/era sebelumnya tidak diperiksa |
| `scripts/save/SaveManager.gd` | Guard `typeof(dict["world_time"]) not in [TYPE_FLOAT, TYPE_INT] → return false` sebelum `float()` | 3B: SCRIPT ERROR tak terkontrol di :304 + koersi senyap (Step 2 Test B) |
| `scripts/world/TimeManager.gd` | Guard tipe `world_time`, `is_exact_int_value` untuk `day_count`, guard `is_nan/is_inf` baru, konversi `day_val` via `roundf` | 3B: `apply_save_dict` tidak boleh percaya data malformed dari jalur internal |
| `tests/run_all.sh` | 3 baris `run_godot` registrasi suite regression baru | Konvensi runner + pemenuhan §6 (grep `SCRIPT ERROR:`/`TEST FAILURE:` + PASS line) |

Tidak ada refactor arsitektur, tidak ada framework transaksi, tidak ada perubahan gameplay/keputusan owner.

## 5. Regression test yang ditambahkan

| Suite | Cakupan |
| --- | --- |
| `tests/test_n44_step3a_shrine_autosave.gd` | 23 checks: A1 payload autosave (day N+1, flag false), A2 Continue → offering tersedia, A3 sesi-langsung tetap benar, A4 tidak ada reset prematur (flag bertahan melewati SUNSET/NIGHT + rejection kedua), A5 exactly-once (1× sunrise, 1× daylight day-2, 1× autosave, 0 gagal). Jalur transisi & persistensi NYATA; slot autosave asli di-snapshot dan dipulihkan byte-exact di akhir run. |
| `tests/test_n44_step3b_world_time_types.gd` | 52 checks: matriks 11 kasus tipe (`validate_payload` + `load_state`), 2 probe token mentah (NaN, 1e999), kompatibilitas legacy (int & float), 6 probe langsung `TimeManager.apply_save_dict` (string/bool/array/NaN/Inf ditolak; valid int/float diterapkan), 3 kasus end-to-end `load_game_state` (array & string ditolak tanpa mutasi state; float legacy tetap dimuat dengan elapsed benar). |
| `tests/test_n44_step3c_rollback_era.gd` | 12 checks: C1 probe kegagalan apply-layer Step 2 (research elapsed>durasi) → `load_failed` tepat 1× dengan teks asli verbatim, 22/22 komponen state dipulihkan, signature pulih; C2 era (valid era_id diterapkan; era_id absen → backfill migrasi terdokumentasi; fail-closed langsung); C3 tidak ada emit palsu pada rollback sukses. Keterbatasan injeksi dicetak eksplisit di log. |

## 6. Command dan exit code (eksekusi nyata)

Runner: `scripts/step3_check_suite.sh` (isolasi `HOME=/tmp/step3home`; meniru `run_godot`: exit code + grep `SCRIPT ERROR:`/`Parser Error:`/`TEST FAILURE:` + PASS line). Suite existing dijalankan langsung seperti `run_all.sh` (user:// sandbox kosong). Semua log: `/home/z/my-project/scripts/step3_logs/`.

| Tahap | Command inti | Exit | Marker log | PASS line |
| --- | --- | --- | --- | --- |
| 3A pre-fix | `godot --headless --script res://tests/test_n44_step3a_shrine_autosave.gd` | **1** | MARKER-FOUND (3× TEST FAILURE) | missing |
| 3A post-fix | idem | 0 | clean | `PASS: All 23 checks — N44 Step3 3A` |
| 3B pre-fix | `godot … test_n44_step3b_world_time_types.gd` | **1** | MARKER-FOUND (11× TEST FAILURE + **8× SCRIPT ERROR**) | missing |
| 3B post-fix | idem | 0 | clean (0 SCRIPT ERROR) | `PASS: All 52 checks — N44 Step3 3B` |
| 3C pre-fix (setelah koreksi ekspektasi C2) | `godot … test_n44_step3c_rollback_era.gd` | 0 | clean | `PASS: All 12 checks — N44 Step3 3C` |
| 3C post-fix | idem | 0 | clean | `PASS: All 12 checks — N44 Step3 3C` |
| existing | `test_time_manager` | 0 | 0 | PASS |
| existing | `test_unit_m2_m7` | 0 | 0 | 18 PASS |
| existing | `test_research_foundation` | 0 | 0 | 8 PASS |
| existing | `test_progression_foundation` | 0 | 0 | 7 PASS |
| existing | `test_progression_phase2_era_correction` | 0 | 0 | 9 PASS |
| existing | `test_n44a_ruins_foundation` | 0 | 0 | 100/100 PASS |

Bukti pre-fix 3A/3B diproduksi ulang secara konsolidasi dengan `git stash push` (produksi kembali ke HEAD, test baru tetap ada) → log `*.prefix.log` → `git stash pop` (diff utuh, HEAD tetap `0e4342d`).

## 7. Inspeksi log runtime

Semua eksekusi post-fix: **0** kemunculan `SCRIPT ERROR:`, `Parser Error:`, `TEST FAILURE:` di log (bukan hanya exit code). Pre-fix 3B sengaja memuat 8× `SCRIPT ERROR: Invalid call. Nonexistent 'float' constructor.` (7× `SaveManager.validate_payload:304`, 1× `TimeManager.apply_save_dict:103`) sebagai bukti. Catatan noise non-gagal: baris `ObjectDB instances leaked at exit` / `resources still in use` muncul saat teardown suite scene-based (pola harness yang sama seperti suite existing) — bukan error runtime skrip dan tidak masuk marker.

## 8. Bukti before/after P0.1

| Aspek | Pre-fix | Post-fix |
| --- | --- | --- |
| Payload autosave sunrise | `day_count=2.0, world_phase=daylight, shrine_flag=true` (stale) | `day_count=2.0, world_phase=daylight, shrine_flag=false` |
| Continue → shrine day 2 | `ok=false, rejection="Shrine Offering already used today"` | `ok=true, rejection=""` |
| Sesi langsung day 2 (A3) | ok=true (tidak berubah) | ok=true |
| A4 reset prematur | tidak ada (pass pre & post) | tidak ada (pass) |
| A5 exactly-once | 1/1/1/0 (pass pre & post) | 1/1/1/0 |
| Hasil suite | exit=1, 3/23 gagal | exit=0, 23/23 PASS |

## 9. Matriks validasi tipe P1.2 (before → after)

| Kasus (`world_time`) | Pre-fix | Post-fix |
| --- | --- | --- |
| `120` (int) | ACCEPT | **ACCEPT** (kompatibel) |
| `90.5` (float) | ACCEPT | **ACCEPT** (kompatibel) |
| `"120.5"` (string numerik) | ACCEPT senyap (120.5) | **REJECT** terkontrol, tanpa error |
| `"abc"` | ACCEPT senyap (0.0) — end-to-end load sukses | **REJECT** (validate + TimeManager + e2e), tanpa mutasi state |
| `true` (bool) | ACCEPT senyap (1.0) | **REJECT** |
| `null` | SCRIPT ERROR :304 → reject | **REJECT** tanpa SCRIPT ERROR |
| `[1,2]` | SCRIPT ERROR :304 → reject | **REJECT** tanpa SCRIPT ERROR |
| `{"a":1}` | SCRIPT ERROR :304 → reject | **REJECT** tanpa SCRIPT ERROR |
| `NaN` (token mentah) | Reject di parse JSON (typeof NIL) | **REJECT** (unchanged) |
| `1e999` (token mentah → inf) | Reject via guard `is_inf` | **REJECT** (unchanged) |
| `-1.5` | Reject via guard `wt<0` | **REJECT** (unchanged) |

Keputusan eksplisit: **string numerik DITOLAK** (bukan dikonversi) — `world_time` pada save nyata selalu angka JSON (hasil `JSON.stringify(float)`), sehingga tidak ada save legacy berformat string; schema_version tidak berubah.

## 10. Rollback P0.2 — perilaku dan keterbatasan

- **C1 (runtime, pre & post):** probe apply-layer Step 2 → `load_failed` tepat 1× dengan teks asli verbatim, 22/22 komponen (era, reign, hearth, boost, shipwreck, portal, shrine, first_night, gold/wood/stone, day/phase/elapsed, player x, nodes, trees, buildings, npcs, research, night, camp) + signature dipulihkan. Perilaku rollback sukses tidak berubah.
- **C3:** rollback sukses tetap senyap (tepat 1 emit) — tidak salah dilaporkan sebagai kegagalan.
- **Temuan penting selama penulisan test:** `era_id` yang absen pada save lama di-backfill oleh `migrate_payload` dengan era terinferensi (wood_age / stone_age bila ada stone wall — `SaveManager.gd:233–240`). Ini **kebijakan owner yang terdokumentasi dan tidak diubah**; test C2b memin perilaku tersebut, bukan mengubahnya.
- **Keterbatasan (dinyatakan, tidak diklaim terverifikasi):** (1) jalur "Rollback failed" TIDAK dapat diinjeksi runtime (snapshot valid by construction; tidak ada seam load-path) → diverifikasi code review + C1 membuktikan jalur sukses tetap senyap; (2) permukaan gagal cek era TIDAK dapat diinjeksi via payload (skema men-gate `KNOWN_ERA_IDS` sebelum apply) → diverifikasi code review; audit fail-closed langsung (`apply_save_era("")/unknown`) diuji runtime dan tetap lolos.

## 11. Deviasi dari rencana dan justifikasi

1. **Ekspektasi C2b/C2c awal salah** (versi v1 suite menganggap era absen mempertahankan era hidup) — dieksekusi, GAGAL 2/12, dan dari situ ditemukan kebijakan backfill migrasi owner. Suite dikoreksi untuk memin perilaku terdokumentasi; log v1 disimpan (`test_n44_step3c_rollback_era.prefix-v1-migration-discovery.log`). Tidak ada perubahan produksi akibat temuan ini.
2. **3C suite lolos pre-fix by design** — perbaikan 3C murni menambah reporting pada jalur yang tidak terinjeksi; suite berfungsi sebagai guard no-regression + pin perilaku (sesuai §5: "If pre-fix failure cannot be demonstrated safely, state why" — dinyatakan di log C2_LIMIT/C3_LIMIT).
3. **Tidak ada commit dibuat** — tidak diminta di instruksi tahap ini; perubahan disajikan di working tree untuk review (starting = final SHA).
4. **run_all.sh penuh tidak dijalankan ulang end-to-end** — dijalankan subset yang menyentuh area diff (6 suite di §6, termasuk headline N44A). Suite lain tidak menyentuh jalur yang berubah; eksekusi penuh dibiarkan untuk tahap berikutnya sesuai batas "do not start Step 4".

## 12. Risiko tersisa dan langkah berikutnya

- Dua permukaan laporan baru (rollback-failure emit, era-check failure) terverifikasi code review saja — risiko rendah (jalur sukses dibuktikan runtime tetap senyap/berperilaku sama), tapi belum ada probe runtime-nya; jika diinginkan, butuh keputusan owner untuk seam test baru (tidak ditambahkan di tahap ini).
- Cek era kini bisa menggagalkan load bila payload mengandung `era_id` valid-skema yang gagal apply — dengan skema saat ini tidak terjangkau; bila validator era berubah di masa depan, C2/C1 akan menangkapnya.
- P1.5 Windows tetap NEEDS REPRODUCTION (host Linux) — di luar cakupan tahap ini.
- Langkah berikutnya yang disarankan: full `tests/run_all.sh` (11 suite lainnya) sekali sebelum PR #23 ready-for-review, lalu tahap 4 sesuai roadmap.

## Checklist Definition of Done

Semua item terpenuhi kecuali yang dinyatakan eksplisit: HEAD diverifikasi ✓; tree bersih sebelum implementasi ✓; A1–A5 terbukti pre/post ✓; P1.2 reject tanpa SCRIPT ERROR + kompatibilitas legacy ✓ + tanpa mutasi state ✓; P0.2 rollback sukses tak berubah ✓ + hasil meaningful diperiksa ✓; tidak ada klaim tak-teruji (dinyatakan sebagai keterbatasan) ✓; targeted tests pass ✓; log dicek bukan hanya exit code ✓; tidak ada perubahan keputusan owner ✓; diff hanya berisi perubahan yang dimaksud ✓; laporan ini ✓.
