# CROWNFALL — N4.4 Step 2: Runtime Reproduction & Failure Matrix

**Tanggal:** 18 November 2026
**Target HEAD:** `0e4342df42d26fc43100e4365aa3eff88adee9c6` (`0e4342d`), branch `feature/n44a-ruins-foundation`, PR #23 (OPEN/DRAFT, belum merge)
**Sifat tahap:** verifikasi saja — **tidak ada** perubahan kode produksi, test, dokumentasi, owner decision, atau commit. Fixture sementara dihapus setelah pengujian; HEAD dan working tree tidak berubah.

---

## 1. Environment dan commit

| Item | Nilai |
| --- | --- |
| Commit | `0e4342d` (`feature/n44a-ruins-foundation`) — diverifikasi tidak berubah sebelum/sesudah seluruh pengujian |
| Godot | `4.7.2.stable.official.ed1daf0bf` (biner lokal `godot-bin/Godot_v4.7.2-stable_linux.x86_64`, sama dengan pin CI 4.7.2) |
| Platform | Linux x86_64 (kernel 5.10.134), mode `--headless` |
| Isolasi save | `HOME=/tmp/step2home` + `XDG_DATA_HOME=/tmp/step2home/xdg` → `user://` = `/tmp/step2home/xdg/godot/app_userdata/CROWNFALL- THE LAST LIGHT/`; save asli pengguna **tidak tersentuh** (guard: tidak ada `save_slot_0.json` di lokasi asli sebelum & sesudah — `real_save_guard.txt`) |
| Fixture | Skrip sementara `tests/tmp_step2_fixtures/*.gd` (pola `extends SceneTree` + `change_scene_to_file` dari `tests/gameplay_scenarios.gd`), **dihapus setelah pengujian**; runner `scripts/step2_run.sh`; log bukti di `scripts/step2_logs/` |
| Penggerakan waktu | `auto_advance=false` + `set_process(false)`, fase di-set langsung (`TimeManager.Phase.NIGHT` — pola yang sama dengan `tests/test_research_foundation.gd:505`), transisi malam→pagi dipicu via `time_manager._transition_to_next_phase()` (jalur NIGHT→DAYLIGHT yang sama dengan rollover alami, `TimeManager.gd:146–151`; akumulasi `phase_elapsed` nyata tidak disimulasikan) |
| Exit code | Seluruh invokasi rerun `exit=0` (tercatat di `step2_logs/exit_codes.txt`) |
| Working tree akhir | `git status --porcelain` kosong; `git diff HEAD` = 0; HEAD tetap `0e4342d` |

---

## 2. Test A — P0.1 (Shrine Offering vs autosave sunrise)

**Hasil: BUG BERHASIL DIREPRODUKSI PADA RUNTIME** — `STEP2A|VERDICT_A|REPRODUCED=true`.

| Test ID | Setup | Expected | Actual | Evidence | Result |
| --- | --- | --- | --- | --- | --- |
| A1 | Sesi fresh hari 1; player di x=-780; `execute_world_command("player_1", &"shrine_offering")` | Offering diterima, `shrine_offering_used_today=true` | `ok=true`, flag=true, `{"ok":true,"reason":""}` | `STEP2A\|A1`, `A1R` | PASS |
| A-SIG | Fase di-set NIGHT, transisi nyata NIGHT→DAYLIGHT dipicu | `sunrise_reached` → autosave → `daylight_started` (urutan TimeManager.gd:150–151) | Persis: `sunrise_reached day_arg=1` → `save_completed` → "Kingdom state auto-saved!" → `daylight_started day_arg=2` | `STEP2A\|SIG`, `SM`, `FEEDBACK_A` | PASS |
| A2 | Sesi hidup setelah transisi (hari 2, tanpa keluar) | Flag di-reset oleh `daylight_started` | `live_flag_after_daylight_started=false` | `STEP2A\|A2` | PASS |
| A-PAY | Baca payload tepat setelah autosave sunrise | **Flag stale terbawa ke save hari 2** | `day_count=2.0, world_time=0.0, world_phase=daylight, shrine_flag_in_save=true` | `STEP2A\|PAYLOAD` | **BUG TERBUKTI** |
| A-RENEW | Pembanding renewable | Renewable di-refresh SEBELUM save (desain di FSS:945–951) | `trees_equal_pre=false` (regrow tercatat di payload), `nodes_equal_pre=true` (tak ada konsumsi di fixture) | `STEP2A\|PAYLOAD` | PASS (kontras sengaja dilakukan vs flag shrine yang tidak) |
| B1 | Keluar tanpa manual save (free scene) → Continue via seam `crownfall_load_on_start` (jalur produksi `ForgottenShoreSession.gd:1252–1267`) | Flag dimuat dari payload = **true pada hari 2** | `day=2, phase=0, shrine_flag=true, has_unsaved_progress=false` (load sukses) | `STEP2A\|B1` | **BUG TERBUKTI** |
| B2 | Coba Shrine Offering pada hari 2 setelah Continue (resource cukup, posisi tepat) | Ditolak karena flag stale | `ok=false`, `rejection="Shrine Offering already used today"` | `STEP2A\|B2`, `B2R` | **BUG TERBUKTI** |
| A3 (kontrol) | Sesi yang sama, hari 2, TANPA keluar/Continue | Offering diterima (flag sudah di-reset live) | `ok=true` | `STEP2A\|A3`, `A3R` | PASS |
| B3 | Konsistensi data setelah Continue | node states = payload | `continue_nodes_equal_saved=true` | `STEP2A\|B3` | PASS |

**Interpretasi:** satu-satunya perbedaan antara jalur kontrol (A3, diterima) dan jalur Continue (B2, ditolak) adalah keluar-masuk sesi setelah autosave sunrise. Window bug: dari autosave sunrise sampai manual save berikutnya. Ini memenuhi definisi reproduksi P0.1 secara runtime (bukan hanya statis).

---

## 3. Test B — P1.2 (validasi tipe `world_time`)

**Hasil: sebagian terbukti runtime — lihat tabel.** Dua lapis: (1) `SaveManager.validate_payload` + `load_state` murni; (2) jalur penuh `load_game_state` pada sesi hidup.

### Layer 1 — `SaveManager.validate_payload` / `load_state` (satu invokasi Godot per kasus, log terpisah)

| Test ID | Setup (world_time) | Expected | Actual | Evidence | Result |
| --- | --- | --- | --- | --- | --- |
| b01 | `120` (int) | Diterima | validate=true; load ok=true | `step2_b_b01_int_120.log` | ACCEPTED (valid) |
| b02 | `90.5` (float) | Diterima | validate=true; load ok=true | `b02` log | ACCEPTED (valid) |
| b03 | `"120.5"` (string numerik) | Diterima senyap | validate=true; load ok=true | `b03` log | **ACCEPTED tanpa error** (float→120.5) |
| b04 | `"abc"` (string sampah) | ? (belum terbukti) | validate=true; load ok=true — **diterima sebagai 0.0** | `b04` log | **ACCEPTED senyap** |
| b05 | `true` (bool) | ? (belum terbukti) | validate=true; load ok=true — **diterima sebagai 1.0** | `b05` log | **ACCEPTED senyap** |
| b06 | `null` | Ditolak terkontrol | validate=false; load ok=false "Invalid schema or corrupt payload" | `b06` log | REJECTED — **tetapi dengan SCRIPT ERROR** |
| b07 | `[1,2]` (array) | ? | validate=false; load ok=false terkontrol | `b07` log | REJECTED — **dengan SCRIPT ERROR** |
| b08 | `{"a":1}` (object) | ? | validate=false; load ok=false terkontrol | `b08` log | REJECTED — **dengan SCRIPT ERROR** |
| b09 | `-1.5` | Ditolak | validate=false; load ok=false | `b09` log | REJECTED (guard `wt < 0.0`), tanpa error |
| b10 | token mentah `NaN` | Ditolak | **JSON parse gagal** (`typeof=NIL`) → ditolak di parse; guard `is_nan` tidak terjangkau lewat JSON | `b10` log | REJECTED (parse-level) |
| b11 | token mentah `1e999` | ? | Parse OK (menjadi inf) → guard `is_inf` menolak | `b11` log | REJECTED (guard `is_inf`), tanpa error |

**Bukti SCRIPT ERROR (b06–b08, backtrace identik):**

```
SCRIPT ERROR: Invalid call. Nonexistent 'float' constructor.
          at: SaveManager.validate_payload (res://scripts/save/SaveManager.gd:304)
```

### Layer 2 — `load_game_state` penuh pada sesi hidup (`step2_b_e2e.log`)

| Test ID | Setup | Expected | Actual | Evidence | Result |
| --- | --- | --- | --- | --- | --- |
| V1 | `world_time=[1,2]` via jalur penuh | ? | 1 SCRIPT ERROR (:304) → abort-default `false` → `load_state` ok=false → `load_game_state` **kembali false**; signature/gold/day/phase **tidak berubah** | backtrace: `validate_payload:304 → _read_and_validate_file:528 → load_state:108 → load_game_state:1161`; `STEP2B2\|V1_*` | REJECTED terkontrol, **tanpa crash, tanpa mutasi state** |
| V2 | `world_time="abc"` via jalur penuh | ? | **load_game_state kembali true** — diterima; `TimeManager.apply_save_dict` terpanggil (`elapsed=0.0` via float("abc")→0.0); `has_unsaved_progress=false` | `STEP2B2\|V2_*` | **ACCEPTED senyap end-to-end** |

**Interpretasi P1.2:**
- Kriteria "save korup tidak menyebabkan SCRIPT ERROR" **dilanggar** untuk `null`/Array/Dictionary (SCRIPT ERROR tercetak di `SaveManager.gd:304`) — tetapi propagasinya aman: GDScript abort-default membuat `validate_payload` kembali `false`, load ditolak, **tidak ada crash dan tidak ada mutasi state**.
- String/bool **diterima senyap** (`"abc"`→0.0, `true`→1.0) — nilai sampah dianggap valid; berakhir sebagai `phase_elapsed=0.0` (awal fase).
- NaN/Inf/negatif sudah terjaga (`is_nan`/`is_inf`/`wt<0` di :305–306); token `NaN` bahkan ditolak di lapisan parse JSON.
- `TimeManager.apply_save_dict` hanya terjangkau setelah `validate_payload` lolos (dibuktikan V2 yang diterima; V1 yang gagal tidak pernah sampai ke sana).

---

## 4. Test C — P0.2 (rollback & propagasi kegagalan restorasi)

**Hasil: jalur rollback terbukti BENAR pada runtime untuk satu-satunya titik kegagalan apply-layer yang dapat disuntikkan lewat payload; gap yang tersisa bersifat statis.**

Catatan metodologi penting: versi awal Test C (v1) menyuntikkan kegagalan melalui `progression_facts` korup dan `durability` non-int — ternyata **keduanya ditolak di lapisan skema** (`validate_payload` memeriksa `ProgressionState.is_valid_fact_array` di `SaveManager.gd:432–434` dan `is_valid_saved_building_dict` di :337), sehingga jalur rollback tidak pernah terjangkau dan hasil "restored" v1 bersifat trivial. Tanda petunjuknya: sinyal `load_failed` tidak pernah terpancar di v1. v2 menambahkan probe lapisan apply yang memanfaatkan satu-satunya asimetri skema→apply yang ditemukan: **skema riset memeriksa `elapsed_sec >= 0` tetapi tidak `elapsed <= duration`** (`SaveManager.gd:436–441` vs `ResearchManager.apply_save_dict:316–319`; komentar `SaveManager.gd:439` dan `ResearchManager.gd:249–250` memang menyatakan kepemilikan/durasi divalidasi saat apply).

| Test ID | Setup | Expected | Actual | Evidence | Result |
| --- | --- | --- | --- | --- | --- |
| V1 | `progression_facts="CORRUPT_NOT_AN_ARRAY"` | Ditolak sebelum mutasi | `load_game_state` false **tanpa** sinyal `load_failed`; 22 komponen state unchanged; signature unchanged | `STEP2C\|V1_*` (tanpa LOADFAILED) | SCHEMA-REJECTED (bukti gating skema, bukan rollback) |
| V2 | `buildings[0].durability="NOT_AN_INT"` | Ditolak sebelum mutasi | `false` tanpa sinyal; state unchanged | `STEP2C\|V2_*` | SCHEMA-REJECTED |
| V3 | Payload lolos skema; `research.active_research={technology_id:"inscription_studies", elapsed_sec:999999.0}` + mutasi pra-gagal: `px=-500`, `first_night_survived=true`, `reign=BREACH_PENALTY`, `hearth=3`, `shipwreck=2`, `portal=true`, `shrine=true`, `era_id="stone_age"` | Gagal di apply (FSS:1208) → `load_failed` terpancar → rollback memulihkan SEMUA mutasi | **Persis**: `load_failed.emit("Failed to restore saved kingdom state — rolling back")` terpancar (FSS:1171); `load_game_state` false; **22/22 komponen UNCHANGED_OR_RESTORED** — termasuk era kembali `wood_age` (mutasi `stone_age` yang sah sempat diterapkan `apply_save_era` sebelum titik gagal) — dan `_unsaved_signature` pulih | `STEP2C\|LOADFAILED`, `V3_RETURN`, blok `V3_CMP` (22 baris), `V3_SIG` | **ROLLBACK TERBUKTI RUNTIME** |
| ERA | `apply_save_era("")` / `("nonexistent_era_xyz")` langsung + panggilan gaya produksi tanpa cek return (FSS:1201) | Fail-closed: ret=false, tanpa mutasi | `ret=false`, era tetap `wood_age` pada ketiga pemanggilan | `STEP2C\|ERA`, `ERA_UNCHECKED` | PASS (bool yang tak diperiksa terbukti benign untuk fungsi ini) |

**Perbandingan state wajib (V3, sebelum load vs setelah rollback):** era, reign, hearth, boost, shipwreck, portal, shrine, first_night_survived, gold/wood/stone, day/phase/elapsed, player x, resource nodes, forest trees, buildings, npcs, research, night encounter, camp vagrants — **semua 22 pulih**; save metadata (`_unsaved_signature`) pulih. Komponen di luar snapshot: `_last_saved_signature` (tidak di-update karena load gagal — benar), sinkronisasi presentasi (`_sync_all_presentations` dijalankan di kedua jalur), `set_dusk_or_night_safety` (dihitung ulang di akhir apply, FSS:1245–1247) — tidak ada yang tertinggal stale pada pengujian ini.

---

## 5. Evidence log dan hasil aktual

- Log lengkap: `/home/z/my-project/scripts/step2_logs/`
  - `step2_a_p01_shrine.log` — Test A (rerun final, exit=0, 0 SCRIPT ERROR)
  - `step2_b_b00..b11_*.log` — 12 invokasi layer 1 (exit=0; b06/b07/b08 memuat SCRIPT ERROR :304 sebagai bukti)
  - `step2_b_e2e.log` — layer 2 (exit=0, 1 SCRIPT ERROR :304 dengan backtrace penuh)
  - `step2_c_rollback.log` — Test C v2 (exit=0)
  - `exit_codes.txt`, `real_save_guard.txt` (BEFORE/AFTER: tidak ada save asli yang tersentuh)
- Runner: `scripts/step2_run.sh` (timeout per invokasi 120–180 s); rerun manual untuk A dan layer-1 B setelah dua perbaikan fixture (lihat §8).
- Semua fixture dihapus: `tests/tmp_step2_fixtures/` tidak ada lagi; `/tmp/step2home` dihapus.

## 6. Temuan yang berhasil direproduksi

1. **P0.1 — CONFIRMED pada runtime.** Payload autosave sunrise menyimpan `shrine_offering_used_today=true` untuk hari 2 (`day_count=2.0`, `world_phase=daylight`); Continue memuat flag stale dan interaksi Shrine ditolak ("Shrine Offering already used today"); kontrol tanpa keluar/Continue menerima offering pada hari yang sama. Sinyal urutan + save sebelum `daylight_started` tercatat di log.
2. **P1.2 — dibuktikan runtime dengan penyempitan:** `null`/Array/Dictionary pada `world_time` → **SCRIPT ERROR di `SaveManager.gd:304`** ("Nonexistent 'float' constructor") — pelanggaran kriteria "tanpa SCRIPT ERROR" — namun tanpa crash dan tanpa mutasi state (abort-default → reject terkontrol). `"abc"`/`true` **diterima senyap** (→0.0/1.0) end-to-end. Negatif/NaN/Inf terjaga; token `NaN` ditolak di parse.
3. **P0.2 — bagian "era bool tak diperiksa" berdampak nyata namun benign:** mutasi era `stone_age` yang sah terjadi sebelum titik gagal dan **berhasil di-roll back**; `apply_save_era` fail-closed untuk id kosong/tak dikenal.

## 7. Temuan yang tidak berhasil direproduksi

1. **State campuran akibat rollback (int P0.2):** tidak terbukti. Untuk satu-satunya titik kegagalan apply-layer yang dapat disuntikkan lewat payload (riset elapsed>durasi), rollback memulihkan 22/22 komponen + signature. Kegagalan di lapisan skema (V1/V2) sama sekali tidak menyentuh state. **Klaim "rollback hasil tak diperiksa" (FSS:1172) tetap sebagai gap statis** — tidak ada skenario payload yang membuktikannya berbahaya pada HEAD.
2. **Crash/mutasi state dari tipe komposit `world_time`:** tidak terjadi — hanya SCRIPT ERROR terkontrol + reject.
3. **Titik kegagalan apply-layer pasca-ekonomi:** tidak ada pada HEAD — economy (`EconomyLedger.gd:172–189` hanya iterasi `VALID_RESOURCES`), npcs (`NPCBuilderAgent.apply_save_dict:362` menjalankan validator yang sama dengan skema), buildings (`BuildingManager.apply_save_dict:783` idem; plot tak dikenal ditolak whitelist skema) semuanya simetris dengan skema. Asimetri research (elapsed/durasi) adalah satu-satunya yang ditemukan — dan justru dialah yang membuat rollback terjangkau.

## 8. Keterbatasan test harness

1. **Kegagalan DI DALAM apply-rollback (langkah 5 matriks): tidak dapat diinjeksi** tanpa menambah seam produksi — snapshot dibangun `build_save_payload()` (valid by construction); seam `simulate_*` hanya menarget jalur write. Tercatat sebagai keterbatasan; klaim FSS:1172 tetap statis.
2. **Transisi malam→pagi dipicu langsung** (`_transition_to_next_phase`, jalur kode identik dengan rollover alami) — akumulasi `phase_elapsed` nyata tidak disimulasikan; tidak memengaruhi klaim P0.1 karena klaimnya menyangkut urutan sinyal, bukan timing.
3. **Iterasi fixture (bukan kode produksi):** (a) run pertama Test A menggantung karena baris verdict fixture mengakses objek yang sudah di-free — diperbaiki dengan capture sebelum free, rerun bersih exit=0; (b) layer-1 B gagal parse (`_log` dua argumen) — diperbaiki, 12 kasus rerun bersih; (c) Test C v1 menyuntik kegagalan di lapisan yang salah (skema, bukan apply) — dideteksi lewat absennya sinyal `load_failed`, diperbaiki di v2 dengan probe research elapsed/durasi. Semua iterasi terdokumentasi di `exit_codes.txt`.
4. **P1.5 Windows di luar cakupan** lingkungan ini (host Linux) — tetap NEEDS REPRODUCTION menunggu mesin Windows.
5. **Guard save asli:** tidak ada `save_slot_0.json` pada lokasi asli sebelum/sesudah pengujian; seluruh `user://` dialihkan ke `/tmp/step2home`.

## 9. Rekomendasi langkah 3 (didukung bukti)

1. **P0.1 — perbaiki + regression test (wajib, satu-satunya bug perilaku terbukti).** Opsi perbaikan mengikuti pola yang sudah ada untuk renewable (FSS:945–951 memindahkan refresh ke sebelum autosave): reset `shrine_offering_used_today` sebelum payload dibangun pada `_on_sunrise_reached`, atau reset pada jalur restore. Regression test: skenario A (pakai offering → sunrise autosave → Continue) harus menghasilkan offering tersedia hari 2; test harus gagal pada implementasi lama (bukti B2: rejection "already used today").
2. **P1.2 — tambahkan guard tipe di `SaveManager.gd:304`** (terima hanya `TYPE_FLOAT`/`TYPE_INT` sebelum `float()`, sisanya reject terkontrol) + guard defensif di `TimeManager.gd:103`. Prioritas kecil: tidak ada bahaya state, tapi menghilangkan SCRIPT ERROR dari log (yang juga dicari marker `SCRIPT ERROR:` oleh CI/run_all) dan menutup penerimaan senyap `"abc"`/bool.
3. **P0.2 — perbaikan minimal, bukan darurat:** periksa hasil `_apply_loaded_payload(snapshot)` di FSS:1172 (minimal: emit kegagalan keras jika rollback gagal) dan cek return `apply_save_era` di FSS:1201. Runtime terbukti aman untuk semua jalur yang dapat disuntikkan, jadi ini pengerasan defensif. **Tambahkan regression test dua varian (schema-gating dan apply-layer research elapsed/durasi) untuk mengunci perilaku rollback yang sudah benar** — sekaligus menjaga asimetri research tetap ter-deteksi jika validator berubah.
4. **Catatan untuk P0.3 (dari pembacaan kode, bukan bug runtime):** `BuildingManager.apply_save_dict` mendaftarkan plot baru untuk id tak dikenal (`BuildingManager.gd:780–783`) — saat whitelist P0.3 dinormalisasi ke katalog, jalur ini perlu ditinjau agar plot tidak dikenal tetap ditolak konsisten di skema maupun apply.

**Prinsip terjaga:** tidak ada perbaikan yang diimplementasikan pada tahap ini; tidak ada commit; HEAD `0e4342d` dan working tree tidak berubah.
