# N4.4 Step 3 — Final Review & Verification Report

**Tanggal:** 18 November 2026
**Objek review:** `N44_STEP3_WORKING_TREE.patch` pada base `0e4342df42d26fc43100e4365aa3eff88adee9c6`
**Batasan dihormati:** tidak commit/push, PR #23 tidak disentuh, Step 4 tidak dimulai, **nol perubahan kode produksi**, perilaku P0.1/P1.2/P0.2 tidak berubah, tanpa refactor di luar empat temuan review.

> **Catatan (putaran 19 November 2026):** §1–§7 di bawah menggambarkan putaran review-fix pertama dan dipertahankan apa adanya sebagai catatan historis. Remediasi temuan review lanjutan — P1 isolasi dua suite legacy penulis save asli, P2 diagnostik rollback + perilaku platform runner + cakupan E2E `world_time`, P3 file mode — terdokumentasi di **§8**; bagian baru itu tidak mengubah klaim historis di atas.

---

## 1. Perubahan yang dilakukan

| # | Temuan review | Perubahan (semua di test suite, nol produksi) |
| --- | --- | --- |
| P1 | `_run_isolated_flow()` melanjutkan eksekusi meski pemeriksaan sandbox gagal (`_check()` bukan fail-fast) | Gate fail-closed baru: `_sandbox_conditions()` mengevaluasi **seluruh** kondisi isolasi secara murni (tanpa `_check()`, tanpa efek samping) **sebelum** `change_scene_to_file()`. Satu saja yang gagal → cetak `TEST FAILURE: sandbox gate: <alasan spesifik>` per kondisi + `quit(1)` + `return`. Tidak ada scene loading, save read/write, atau gameplay di sandbox yang tidak terbukti. Setelah gate lulus, kondisi dicetak sebagai `CHECK OK` (bukti log) dan `STEP3A\|GATE\|ok` ditulis tepat sebelum scene dimuat |
| P1 | Bukti regression fail-closed | Parent kini menjalankan **negative probe** di setiap eksekusi: child di-spawn dengan klaim `ENV_TMP` **bogus** (jalur sibling yang tak pernah dibuat) — gate wajib menolaknya sebelum scene. Parent mengasersi: rc=1, ada baris penolakan spesifik, **tidak ada** marker `GATE\|ok`/`A-setup`/`PAYLOAD`, tidak ada file autosave di bawah sandbox yang ditolak, lalu sandbox probe dihapus. Jika probe gagal, parent **meng-abort tanpa menjalankan flow asli** (fail-closed di level meta). Output mentah probe TIDAK di-relay (mengandung `TEST FAILURE` yang diharapkan) — parent mencetak bukti tersanitasi `STEP3A\|PROBE\|evidence: …` agar log sukses tetap bersih |
| P2 | `begins_with(temp_base)` bukan containment sejati | Helper `_is_descendant_of()`: kedua jalur dinormalisasi leksikal dengan `String.simplify_path()` (Godot 4.7.2: melipat `//`, `./`, `../`), lalu base harus cocok sampai **batas komponen** (`child == base` atau `child.begins_with(base + "/")`). Base kosong dan `/` **ditolak** sehingga klaim blank/root tak pernah "memuat" apa pun. Prefix-string polos salahnya nyata: `/tmp/step3a_iso_X` akan menerima `/tmp/step3a_iso_XY/...`. Resolusi symlink sengaja di luar lingkup: kedua sisi jalur dibangun proses parent yang sama, normalisasi leksikal adalah containment test yang tepat untuk threat model ini. Diterapkan pada: user dir child, jalur autosave globalized, dan guard prefix temp base di gate |
| P2 | Ketergantungan `/tmp` + `rm -rf` | Keputusan: suite **sengaja Linux-only** (didokumentasikan di header). Alasan: Godot 4.7.2 tidak punya API hapus-rekursif, `list_dir_begin()` menyembunyikan dot-entry, dan child Godot menulis `$HOME/.cache` — `rm -rf` adalah satu-satunya cleanup yang deterministik; keamanan cleanup tidak dikorbankan demi portability. Platform guard fail-closed di `_initialize()`: `OS.get_name() != "Linux"` → `TEST FAILURE` + `quit(1)` **sebelum** direktori/proses/save apa pun — platform tak didukung tidak pernah melanjutkan tanpa isolasi. Cleanup dikonsolidasi ke `_rmrf_guarded()` (wajib absolute + prefix `/tmp/step3a_iso_` + `dir_exists` + separator `--`) |
| P2 | `_lf_texts[0]` bisa index-error bila `load_failed` tak terpancar | `test_n44_step3c_rollback_era.gd`: akses `[0]` kini dijaga `if _lf_texts.is_empty()` → `TEST FAILURE` bersih ("load_failed was never emitted") + exit nonzero; tanpa runtime index error. Akses lain sudah short-circuit aman (`size() > 0 and _lf_texts[0]`) |

**Temuan teknis di sepanjang jalan (terdokumentasi di komentar suite):** di Godot 4.7.2 `OS.execute` mengembalikan **seluruh output child sebagai SATU elemen** dengan newline tertanam — analisis probe awal mem-parsing per-elemen dan melewatkan baris gate; diperbaiki dengan flatten + `split("\n")` sebelum pencocokan baris.

## 2. Bukti fail-closed

Dari log suite (runner terisolasi, direct-run, dan di dalam `run_all.sh` penuh — konsisten):

```
CHECK OK: probe: bogus-sandbox child was refused with exit code 1 (rc=1)
CHECK OK: probe: gate printed specific refusal(s) and NO gate-ok/scene/payload markers —
          execution stopped before change_scene_to_file
CHECK OK: probe: no autosave file exists anywhere under the refused sandbox
          (/tmp/step3a_iso_…_probe/xdg/godot/app_userdata/CROWNFALL- THE LAST LIGHT/save_slot_0.json)
STEP3A|PROBE|evidence: sandbox gate: iso: process user data dir is a TRUE descendant of the
          claimed temp base (/tmp/step3a_iso_…_probe/xdg/godot/app_userdata/CROWNFALL- THE LAST LIGHT)
```

Reproduksi manual probe child (bogus klaim) juga menunjukkan penolakan dengan **dua alasan spesifik** + `rc=1` + tanpa output scene. Urutan kode: gate → `STEP3A|GATE|ok` → `change_scene_to_file()`; karena `GATE|ok` absen pada child yang ditolak dan tak ada marker `A-setup`/`PAYLOAD`, **eksekusi terbukti berhenti sebelum scene dimuat**.

## 3. Bukti path containment

- Jalur sukses (child asli): `CHECK OK: iso: process user data dir is a TRUE descendant of the claimed temp base (/tmp/step3a_iso_<pid>_<usec>/xdg/godot/app_userdata/CROWNFALL- THE LAST LIGHT)` dan padanannya untuk jalur autosave — keduanya lolos uji batas komponen, bukan sekadar prefix.
- Jalur negatif (probe): klaim sibling-shaped `/tmp/step3a_iso_bogus_…` DITOLAK padahal lolos prefix-string polos — ini persis celah yang diperbaiki.
- Guard pencegahan: klaim base wajib absolute + ber-prefix `/tmp/step3a_iso_` (kondisi gate #1); base kosong/`/` ditolak di `_is_descendant_of`.

## 4. Batas platform

- Suite 3A **Linux-only by design**: sandbox cleanup memerlukan `rm -rf` (tak ada API rekursif di Godot 4.7.2; dot-entry tersembunyi dari `list_dir_begin()`). Platform guard menolak eksekusi pada platform lain **sebelum** membuat direktori, men-spawn proses, atau menyentuh save. Suite 3B/3C platform-netral (jalur `user://` + walk GDScript) dan tidak diubah.
- Tidak ada jalur "lanjut tanpa isolasi" pada platform tak didukung — satu-satunya perilaku adalah refusal keras (exit 1).

## 5. Hasil ketiga suite dan full run

| Eksekusi | Exit | `SCRIPT ERROR`/`Parser Error`/`TEST FAILURE` | Hasil |
| --- | --- | --- | --- |
| Runner: 3A | 0 | 0 | `PASS: All 29 checks — N44 Step3 3A Shrine Autosave Ordering` |
| Runner: 3B | 0 | 0 | `PASS: All 63 checks — N44 Step3 3B World Time Type Validation` |
| Runner: 3C | 0 | 0 | `PASS: All 14 checks — N44 Step3 3C Rollback Era Reporting` |
| Direct-run ketiga suite (HOME asli developer, tanpa kerja sama launcher) | 0 / 0 / 0 | 0 / 0 / 0 | PASS 1× per suite; probe + gate bukti identik |
| `GODOT=… bash tests/run_all.sh` **PENUH** | **0** — `ALL SUITES PASSED` | **0** di seluruh log | 25 langkah, 1110 baris PASS; Step3 29/63/14 |
| `git diff --check` (repo crownfall) | 0 | — | bersih |

**Save asli:** selama verifikasi ini `$HOME/.local/share/godot/app_userdata/CROWNFALL- THE LAST LIGHT/` awalnya **tanpa** `save_slot_0.json` (sandbox agent didaur ulang). Setelah direct-run ketiga suite Step 3: **slot tetap absen** (byte-exact untuk file absen = tidak diciptakan), fixture `user://step3b`/`step3c` tidak tertinggal. Di dalam suite 3A sendiri, parent memverifikasi byte-exact snapshot-sebelum vs sesudah (berlaku untuk slot ada maupun absen) di setiap eksekusi.

**Temuan penting di luar patch (atribusi presis, tidak diubah):** dua suite **legacy di luar lingkup patch** — `tests/test_integration_m8_slice.gd` (memicu `advance_time` melewati NIGHT→DAYLIGHT dengan sesi hidup → autosave FSS ke jalur default, `test_integration_m8_slice.gd:120-152`) dan `tests/test_progression_phase2_era_correction.gd` (day-roll sesi hidup; save eksplisitnya sendiri sudah ber-jalur khusus) — **menulis `user://save_slot_0.json` ketika dijalankan pada user data dir normal**. Ini perilaku pra-eksisting (slot yang sama pernah ada di sandbox sebelumnya), teridentifikasi lewat eksperimen per-suite terisolasi; keduanya BUKAN bagian dari patch yang direview dan tidak diubah sesuai batasan "perbaikan terbatas / tanpa refactor tak perlu". Rekomendasi tindak lanjut: terapkan pola sandbox 3A ke kedua suite tersebut di putaran review berikutnya. Artefak slot yang tercipta selama diagnostik (payload fresh day-1 schema v2) telah dihapus; fixture bernama `test_*.json` milik suite legacy dibiarkan (perilaku baku mereka).

## 6. Status Git

- **HEAD: `0e4342df42d26fc43100e4365aa3eff88adee9c6`** — tidak berubah; **tanpa commit/push**; PR #23 tetap OPEN/DRAFT; Step 4 tidak dimulai.
- Working tree: **4 modified tracked files** (FSS, SaveManager, TimeManager, `tests/run_all.sh` — dari Step 3, tak tersentuh lagi putaran ini) + **3 test suite files** (direvisi putaran ini) + **3 `.uid` sidecar files** + **4 review documents** (STEP2 reproduction, STEP3 implementation, STEP3 review-fix, STEP3 final review-fix) — 10 file untracked baru, total **14 diff blocks/files**.
- `N44_STEP3_WORKING_TREE.patch` diregenerasi (14 blok diff) dan diverifikasi ulang `git apply` pada clone bersih + cmp byte-per-byte 14/14 file identik.

## 7. Risiko yang masih tersisa

1. **Dua suite legacy menulis slot asli saat run_all dijalankan pada user data dir normal** (m8_slice, phase2 era correction) — di luar patch ini; belum diperbaiki (batasan lingkup), terdokumentasi + rekomendasi di §5. *(Status round 2: DIPERBAIKI — sandbox parent/child di kedua suite + sandbox run-wide + save-guard di runner; lihat §8. Klaim historis di atas tetap benar untuk putaran ini.)*
2. **Platform guard bersifat refusal, bukan adaptasi** — di Windows/macOS suite 3A akan selalu gagal-keras; inilah perilaku yang diminta review, tetapi berarti CI non-Linux butuh pengecualian eksplisit di run_all jika kelak ada. *(Status round 2: refusal suite kini berupa SKIP eksplisit yang dihitung (exit 2 + baris `SKIP:`), dan runner memisahkan PASS/FAIL/SKIP serta keluar UNSUPPORTED eksplisit di non-Linux; lihat §8.)*
3. **`_rmtree` 3B/3C tetap buta dot-entry** (limitasi engine) — aman saat ini karena direktori fixture hanya berisi file visible tulisan suite; jika kelak Godot menulis dotfile di sana, check cleanup gagal keras (arah aman).
4. **Dua permukaan laporan P0.2** (emit "Rollback failed", cek era) tetap terverifikasi code review saja — tetap tidak terinjeksi via payload tanpa seam produksi. *(Status round 2: permukaan "Rollback failed" kini teruji runtime tanpa seam produksi — C4 menginjeksi kegagalan rollback lewat nilai apply-invalid pada state hidup; lihat §8. Permukaan cek era tetap code-review-only.)*
5. **Negative probe mengasumsikan penolakan menghasilkan exit code 1** — jika engine berubah perilaku exit-code untuk `quit(1)`, probe check akan gagal keras (arah aman: suite berhenti, tidak melanjutkan tanpa bukti).

## 8. Putaran remediasi P1–P3 (19 November 2026)

Semua perubahan tetap **revisi lokal pada scope Step 3** — tanpa commit/push, PR #23 tidak disentuh, Step 4 tidak dimulai, scope gameplay N4.4-A tidak berubah, tanpa refactor besar atau framework baru, dan tanpa melemahkan test yang ada.

### 8.1 Temuan yang diperbaiki

| Prioritas | Temuan | Perbaikan |
| --- | --- | --- |
| P1 | `test_integration_m8_slice.gd` dan `test_progression_phase2_era_correction.gd` dapat menulis `user://save_slot_0.json` asli (autosave sesi hidup: sunrise day-2 / jalur ISLAND_CLEARED) | Pola sandbox 3A diterapkan ke keduanya: tanpa env key → **PARENT** (snapshot slot asli byte-exact → spawn dirinya sebagai child dengan `HOME`/`XDG_DATA_HOME`/`XDG_CACHE_HOME` baru SEBELUM proses diluncurkan → relay output → verifikasi slot asli byte-exact → `rm -rf` terpandu prefix); dengan env key → **CHILD** dengan **gate fail-closed** murni (user:// ≠ dir normal, TRUE descendant dari temp base lewat `simplify_path` + batas komponen, jalur autosave di dalam base, tanpa slot pra-ada) **sebelum** scene/session/save mana pun. Env tidak pernah dipercaya in-process: root `user://` di-cache Godot saat startup (bukti 3A), jadi env wajib diset sebelum launch |
| P1 | Runner dapat menyentuh save asli | `tests/run_all.sh` kini menjalankan **seluruh run di dalam sandbox user-data sementara** (env dialihkan sebelum proses Godot pertama), dibuktikan oleh langkah **runner sandbox gate** baru (`tests/test_runner_sandbox_gate.gd` — 4 kondisi, fail-closed, exit 1 menolak seluruh run), plus **save-guard** bash: fingerprint `find -type f | md5sum` atas dir user data asli sebelum & sesudah run |
| P2 | Emisi `load_failed` kedua saat rollback gagal menimpa alasan asli di `_last_rejection_reason` (komentar FSS menjanjikan "stays verbatim" tapi state tidak menjamin) | `ForgottenShoreSession.gd`: emisi ganda **dihapus**; verdict rollback masuk slot diagnostik khusus baru `_last_rollback_failure_reason` + getter `get_last_rollback_failure_reason()` (di-reset di awal tiap `load_game_state`); alasan asli tetap verbatim di subscriber satu-satunya (`_record_rejection`, audit: tanpa UI/state). Kontrak sinyal publik tidak berubah; jalur rollback sukses & load failure lama tidak berubah |
| P2 | Suite 3A fail-hard di platform non-Linux tanpa hasil informatif; runner tidak memisahkan SKIP | Guard 3A non-Linux kini **`SKIP:` + exit 2** (tetap fail-closed: tidak ada operasi apa pun); runner menghormati kontrak skip (exit 2 + baris `^SKIP:`), ringkasan memisahkan **passed/failed/skipped**, dan `ALL SUITES PASSED` tidak pernah diklaim saat ada skip; runner non-Linux keluar **UNSUPPORTED (exit 3)** sebelum menjalankan apa pun |
| P2 | `world_time` invalid belum semua teruji lewat jalur pemuatan sesi | 3B diperluas parametrik penuh: Layer 1 (validate/load_state: +negative int, −Infinity), Layer 2 (TimeManager: null, bool×2, Array, Dictionary, numeric string, alpha string, negative×2, NaN, ±Inf — semuanya + cek state tak berubah), **Layer 3b E2E** lewat `ForgottenShoreSession.load_game_state()` untuk SEMUA varian invalid (null, bool, numeric string, Dictionary, negative, NaN, ±Inf via raw token) + asersi signature/state utuh + **tanpa emisi `load_failed`** (penolakan terjadi sebelum apply/rollback) |
| P3 | File baru dalam patch memakai mode `100755` (`.gd`/`.uid`/`.md`) | Seluruh 12 file baru (source/test/uid/gate/dokumen) kini `100644` di patch; tidak ada isi file yang diubah untuk urusan permission dan tidak ada perubahan mode git pada file tracked (baris `old/new mode` absen dari patch) — `tests/run_all.sh` tetap `100644` sesuai catatan repo (dipanggil via `bash`, bukan dieksekusi langsung; mode filesystem lokal sandbox tidak terlihat git karena `core.fileMode=false`) |

### 8.2 File yang berubah (inventaris)

- **Tracked (6):** `scripts/world/ForgottenShoreSession.gd` (diagnostik rollback — satu-satunya delta produksi), `tests/run_all.sh` (sandbox + gate + save-guard + ringkasan), `tests/test_integration_m8_slice.gd`, `tests/test_progression_phase2_era_correction.gd` (isolasi), plus `scripts/save/SaveManager.gd` & `scripts/world/TimeManager.gd` (dari Step 3 sebelumnya, tak tersentuh putaran ini).
- **Untracked (12):** 3 suite Step 3 (direvisi), 3 `.uid` sidecar, `tests/test_runner_sandbox_gate.gd` + `.uid` (baru), 4 dokumen review. Log verifikasi di `scripts/step3_logs/r2_*.log` adalah artefak untracked di luar patch.

### 8.3 Hasil verifikasi (semua dijalankan, tidak ada yang dikarang)

*(Angka di bawah adalah hasil putaran 2. Angka final setelah putaran audit 3 ada di §8.6.)*

| Verifikasi | Hasil |
| --- | --- |
| Suite per-suite (GODOT 4.7.2 headless, direct) | gate rc=0 (4 checks); 3A rc=0 (29); 3B rc=0 (**111**, +48); 3C rc=0 (**21**, +7, termasuk C4); M8 rc=0 (39 + 2 parent checks, gate + byte-exact); era rc=0 (162, 8/8 sub-suite + 2 parent checks) |
| `GODOT=… bash tests/run_all.sh` penuh | **exit 0 — `ALL SUITES PASSED`**; `SUMMARY: passed=25 failed=0 skipped=0`; `SAVE GUARD OK` (fingerprint `84f825c6…` sebelum = sesudah); tanpa `SCRIPT ERROR`/`Parser Error`/`TEST FAILURE` |
| Hash save asli | `save_slot_0.json` **ABSENT sebelum & sesudah** seluruh eksekusi (tidak pernah diciptakan); fingerprint dir user data asli identik sebelum/sesudah full runner |
| `git diff --check` | bersih (0) |
| File mode | 12 blok new-file `100644`, 0 blok `100755`; baris `old/new mode` tidak ada di patch (`git diff --summary` kosong); `tests/run_all.sh` tetap `100644` level git sesuai konvensi repo |
| Bukti isolasi aktif | gate runner 4 CHECK OK (user:// TRUE descendant sandbox, autosave path descendant, tanpa slot pra-ada); gate M8/era `…GATE\|ok` per eksekusi; parent M8/era/3A: slot asli byte-exact; save-guard runner |

### 8.4 Platform dan keterbatasan

- **Linux** = platform yang didukung dan terverifikasi penuh (seluruh angka di atas).
- **Non-Linux: NOT RUN** (tidak dapat diuji di sandbox Linux ini). Perilaku yang diimplementasikan: runner keluar `UNSUPPORTED (exit 3)` fail-closed sebelum langkah apa pun; suite bersandbox melaporkan `SKIP` (exit 2) saat dipanggil langsung. Keduanya diimplementasikan tapi hanya sisi Linux yang dieksekusi.
- Sandbox runner & suite bergantung semantik XDG + `rm -rf` terpandu — divalidasi di Linux saja; gate membuat klaim env **wajib dibuktikan** (user:// benar-benar di dalam sandbox) sehingga platform yang mengabaikan env akan ditolak, bukan diam-diam lanjut.
- Cleanup `/tmp` bersifat courtesy: crash keras di tengah run bisa meninggalkan base temp berprefix ketat (`/tmp/step3a_iso_`, `/tmp/m8_iso_`, `/tmp/phase2_iso_`, `/tmp/step3_runner_iso_`); perlindungan save bersifat struktural, bukan bergantung cleanup.
- Permukaan cek era (`apply_save_era` gagal via payload) tetap code-review-only (KNOWLEDGE_ERA gate schema) — tidak diubah.

### 8.5 Patch final

Patch final putaran ini diberi nama baru **`N44_STEP3_REMEDIATION_WORKING_TREE.patch`** (18 blok diff: 6 tracked + 12 untracked; patch `N44_STEP3_WORKING_TREE.patch` putaran sebelumnya dipertahankan utuh). Verifikasi lengkapnya (apply pada base + cmp byte-per-byte 18/18 + SHA-256) dicatat pada laporan chat putaran ini; SHA-256 sengaja tidak ditulis di dalam dokumen ini (patch memuat dokumen ini — SHA-nya berubah bila dokumen berubah).

### 8.6 Putaran audit 3 (19 November 2026) — lima temuan audit patch remediasi

Audit eksternal atas patch remediasi menemukan lima celah; semuanya diperbaiki dan diverifikasi ulang. Tetap tanpa commit/push, tanpa perubahan scope, tanpa melemahkan test.

| # | Temuan audit | Perbaikan |
| --- | --- | --- |
| F1 (P1) | Parent wrapper M8/Era hanya memeriksa `exit_code == 0` — kegagalan pemeriksaan parent bisa menyembunyikan PASS. Analisis tambahan: di Godot 4 `quit()` hanya menandai exit — `quit(1)` dari `_check()` bisa **tertimpa `quit(0)`** pada cabang sukses, jadi false PASS benar-benar mungkin | Verdict parent M8/Era kini `exit_code == 0 and _failed == 0` (M8 mendapat counter `_failed` baru; era memakai `_failures` yang sudah ada); cabang gagal mencetak `TEST FAILURE` + `quit(1)`. 3A sudah gate `_failed == 0 and exit_code == 0` sejak putaran 2 (dicek ulang, tidak diubah) |
| F2 (P1) | 3B/3C bisa menghapus direktori `user://step3b`/`step3c` milik pengguna saat direct run (fixture dir tetap + `_rmtree` membabi buta) | Direktori fixture kini **unik per run** (`user://step3b_<pid>_<usec>`, `user://step3c_<pid>_<usec>`) dengan **precondition fail-closed** (entri pra-ada apa pun → `TEST FAILURE` + quit(1), tidak pernah disentuh) dan cleanup `_rmtree` ter-scoped ke tepat direktori yang dibuat run ini. Keputusan desain: parent/child penuh ala 3A sengaja TIDAK ditambahkan ke 3B/3C — kedua suite ini **tidak pernah menulis slot default** (dibuktikan save-guard runner), jadi risiko nyatanya hanya clobber direktori fixture, yang lenyap by-construction dengan nama unik + precondition; postur platform-neutral 3B/3C tetap terjaga |
| F3 (P2) | Fingerprint save-guard runner selalu memakai `$HOME/.local/share/...` — salah untuk `XDG_DATA_HOME` khusus | Runner menyimpan `XDG_DATA_HOME` asli SEBELUM dialihkan dan menurunkan base data asli persis seperti Godot: dipakai hanya bila **absolute**; relative/kosong → fallback `$HOME/.local/share` (mirip warning engine "XDG_DATA_HOME is a relative path. Ignoring its value..."). Logika case bash diuji untuk 3 kasus (kosong/absolute/relative) |
| F4 (P2) | Cek byte-exact parent menggabungkan "file tidak ada" dengan "file kosong" (`PackedByteArray()` untuk keduanya); di 3A `had_real_save` dibuat tapi tak dipakai | M8/Era/3A kini memeriksa **KEBERADAAN dan ISI secara terpisah**: `_check(had_real_save == had_after_save, ... existence unchanged)` + `_check(real_bytes == after_bytes, ... byte-exact)` |
| F5 (P3) | Containment hanya leksikal — symlink tidak terselesaikan; base dibuat tanpa jaminan eksklusif | (a) `_make_exclusive_base()` di M8/Era/3A: base yang sudah ada (tabrakan atau symlink tanam) **tidak pernah dipakai ulang**, dibuat eksklusif, lalu wajib `readlink -m` menyelesaikan dirinya sendiri — kegagalan apa pun meng-abort parent sebelum child spawn (fail-closed); (b) kondisi gate baru di M8/Era/3A + gate runner: **containment pada path ter-kanonikalisasi** (user_dir & base di-resolve `readlink -m` dulu); (c) runner bash: `readlink -m` atas `RUNNER_SANDBOX_BASE` wajib identik — beda → `INTERNAL ERROR` + exit 1. Dokumen 3A yang lama menyatakan symlink "out of scope" — klaim itu kini diperkuat, bukan dihapus |

**Hasil verifikasi putaran 3 (semua dijalankan):**

| Verifikasi | Hasil |
| --- | --- |
| Suite per-suite (direct) | gate rc=0 (kini **5 checks**, termasuk canonical); 3A rc=0 (**30** — +1 cek base eksklusif); 3B rc=0 (**111**); 3C rc=0 (**21**); M8 rc=0 (39 + **3 parent checks**: existence + byte-exact + cleanup); era rc=0 (162 + **3 parent checks**) |
| Full runner `GODOT=… bash tests/run_all.sh` | **exit 0 — `ALL SUITES PASSED`**; `SUMMARY: passed=25 failed=0 skipped=0`; `SAVE GUARD OK` (fingerprint sebelum = sesudah); **0** baris `SCRIPT ERROR`/`Parser Error`/`TEST FAILURE` |
| Hash save asli | `save_slot_0.json` **ABSENT sebelum & sesudah** seluruh eksekusi; tidak ada fixture `step3*` tertinggal di user data asli; tidak ada sandbox `/tmp` tersisa |
| `git diff --check` | bersih; `git diff --summary` kosong (tanpa perubahan mode tracked) |
| Uji logika XDG guard | kasus kosong/relative → fallback `$HOME/.local/share`; absolute → dipakai (sesuai resolusi Godot) |

Angka patch: tetap **18 blok** (6 tracked + 12 untracked, konten diperbarui), `git apply` bersih pada base, cmp 18/18 identik; SHA-256 final dicatat di laporan chat (di dalam dokumen sengaja tidak ditulis — lihat §8.5).

### 8.7 Putaran audit final (19 November 2026) — dua temuan P1 fail-closed

Audit independen atas `N44_STEP3_REMEDIATION_WORKING_TREE.patch` menemukan dua celah fail-closed; keduanya diperbaiki, masing-masing dengan regression test yang membuktikan call graph-nya. Tetap tanpa commit/push/merge, tanpa perubahan scope gameplay, tanpa menghapus atau melemahkan test.

| # | Temuan | Penyebab | Perbaikan |
| --- | --- | --- | --- |
| F1 (P1) | `run_all.sh` tidak berhenti ketika runner sandbox gate gagal: `run_godot()` hanya menambah penghitung `failed`, sehingga setelah gate gagal runner tetap menjalankan `--import` dan seluruh suite — suite bisa melakukan operasi file sebelum save guard akhir bereaksi | Verdict gate tidak pernah dijadikan prasyarat; keluaran `run_godot` hanya bersifat akuntansi | Blok prasyarat mutlak setelah langkah gate: verdict di-re-derive dari **bukti yang sama dengan mekanisme runner** (log gate: error marker / baris `^SKIP:` / baris PASS yang diharapkan + exit code via `LAST_STEP_RC` baru) — tulisan PASS saja tidak pernah cukup. Keraguan apa pun → `RUNNER ABORTED BEFORE ANY SUITE` + exit **1** SEBELUM `--import` dan suite mana pun, dengan: fingerprint save akhir tetap dijalankan (apakah proses gate sendiri mengubah data asli), hanya `RUNNER_SANDBOX_BASE` milik runner yang dibersihkan, dan log diagnostik dipertahankan. Regression: `tests/test_runner_gate_failfast.sh` (fake Godot + call log): **A** gate menolak → tepat satu invokasi Godot (hanya gate), tanpa `--import`, exit nonzero, save-guard abort jalan; **B** gate terbukti → `--import` dijalankan, runner exit 0; **C** PASS tercetak tapi exit 7 → runner tetap berhenti. Hasil: **13/13 CHECK OK** |
| F2 (P1) | 3A `_run_parent_wrapper()` mencatat kegagalan `_make_exclusive_base(probe_base)` lewat `_check()` (yang hanya menjadwalkan `quit(1)`) lalu **tetap meluncurkan `_run_child_process()`** — di Godot 4 `quit()` tidak menghentikan fungsi, sehingga child bisa menulis artefak startup ke lokasi probe yang belum terbukti (mungkin pra-ada atau symlink) | Pola "prasyarat dicatat, bukan gate" — serupa akar masalah dengan temuan parent-wrapper putaran 3 | `_check()` pada prasyarat probe base diganti **gate fail-fast eksplisit**: gagal → cetak `TEST FAILURE` (probe base refused… no child spawned) → `quit(1)` → `return` langsung; `_run_child_process()` tidak pernah dipanggil; probe dan real flow tidak berjalan; lokasi yang ditolak **tidak dihapus** (bukan dibuat oleh proses ini). Audit seluruh fungsi parent: prasyarat base real sudah fail-fast sejak putaran 3; tidak ada pola serupa lain. Regression: `tests/test_step3a_probe_refusal.sh` — penolakan dipicu deterministik via fake `readlink` di PATH (mengembalikan resolusi non-kanonik untuk base berbentuk probe, query lain pass-through, semua query dicatat): suite exit 1, pesan penolakan eksplisit, **tanpa** marker alur child (gate-ok/A-setup/PAYLOAD/output gate child/CHECK OK probe), log readlink memuat query probe base dan **tidak** memuat query berbentuk gate child (`app_userdata` / bogus claim) — bukti child tidak pernah spawn; plus audit struktur (cabang penolakan berisi `quit(1)`+`return` sebelum spawn, tanpa `_rmrf_guarded`, bentuk `_check(_make_exclusive_base(...))` lama hilang). Hasil: **9/9 CHECK OK** |

**Hasil verifikasi putaran final (semua dijalankan):**

| Verifikasi | Hasil |
| --- | --- |
| `bash -n` | `tests/run_all.sh`, `tests/test_runner_gate_failfast.sh`, `tests/test_step3a_probe_refusal.sh` — semua OK |
| Parse `--check-only` | 7/7 file GDScript OK |
| Regression F1 (fake Godot, A/B/C) | **13/13 CHECK OK** — kegagalan gate terbukti menghentikan runner sebelum suite berikutnya |
| Regression F2 (fake readlink + audit struktur) | **9/9 CHECK OK** — kegagalan pembuatan probe base terbukti tidak memulai child |
| Full runner `GODOT=… bash tests/run_all.sh` | **exit 0 — `ALL SUITES PASSED`**; `SUMMARY: passed=25 failed=0 skipped=0` (tanpa FAIL/SKIP di Linux); `SAVE GUARD OK` (fingerprint sebelum = sesudah); **0** baris `SCRIPT ERROR`/`Parser Error`/`TEST FAILURE` |
| Hash save asli | `save_slot_0.json` **ABSENT sebelum & sesudah** seluruh eksekusi |
| `git diff --check` / mode | bersih; `git diff --summary` kosong; dua shell test baru `100644` sesuai konvensi repo (dijalankan via `bash`) |
| Scope | 6 tracked M + untracked yang sama **+ 2 shell test baru yang diwajibkan mandat** (`tests/test_runner_gate_failfast.sh`, `tests/test_step3a_probe_refusal.sh`); tidak ada file lain di luar inventaris yang berubah |

Patch putaran final: **`N44_STEP3_FINAL_FAILCLOSED.patch`** — **20 blok** (6 tracked + 14 untracked: 12 sebelumnya + 2 shell regression test); patch-patch terdahulu tidak ditimpa. Verifikasi apply-pada-base + cmp byte-per-byte dicatat di laporan chat; SHA-256 di laporan chat (bukan di dokumen ini — lihat §8.5).

### 8.8 Putaran audit 4 (19 November 2026) — P2 ownership cleanup pada regression F2

Audit terakhir menemukan P2 pada `tests/test_step3a_probe_refusal.sh`: cleanup menggunakan snapshot global `/tmp/step3a_iso_*_probe` sebelum/sesudah test, lalu menghapus seluruh direktori yang baru muncul. Direktori baru tersebut belum tentu milik test ini — bisa berasal dari proses Godot lain yang berjalan bersamaan (misalnya run runner paralel yang juga membuat base berpola sama). Perbaikan menyasar **hanya** script regression; implementasi produksi F1 (gate prasyarat runner) dan F2 (fail-fast probe base 3A) tidak disentuh, begitu pula simulasi fake `readlink` dan seluruh assertion F2 yang tetap utuh.

| Aspek | Sebelum | Sesudah |
| --- | --- | --- |
| Basis cleanup | diff snapshot global (`ls /tmp/step3a_iso_*_probe` before/after + `comm -13`) → menghapus semua yang baru muncul | Ownership terbukti: path base diambil dari **pesan penolakan run ini sendiri** (`… probe base refused (non-exclusive or non-canonical: <path>) …`), divalidasi ketat terhadap pola `^/tmp/step3a_iso_[0-9]+_[0-9]+_probe$`, dan **hanya** path tunggal tervalidasi itu yang dihapus |
| Direktori milik proses lain | bisa terhapus (P2) | tidak pernah disentuh — test tidak melakukan scan glob `/tmp` sama sekali |
| Ownership tak terbukti | tidak ada jalur ini | artefak **dibiarkan** dan path-nya dilaporkan eksplisit (`LEFTOVER KEPT FOR SAFETY: …`); test gagal dengan bukti tersimpan di `WORK` |
| Assertion | 9/9 CHECK OK | 9 assertion F2 tetap utuh + 2 assertion cleanup baru → **11/11 CHECK OK** |
| Artefak lain | — | `WORK` milik test sendiri (mktemp) tetap dihapus saat sukses; pada kegagalan dipertahankan sebagai bukti dan path-nya dilaporkan |

Verifikasi putaran ini: `bash -n` 3/3; regression F2 **11/11 CHECK OK** (artefak tunggal terbukti ter-identifikasi dari pesan penolakan dan terhapus, tidak ada yang tertinggal); regression F1 fake-Godot **13/13** tetap lulus; parse `--check-only` 7/7; full runner **exit 0 — `ALL SUITES PASSED`**, `SUMMARY: passed=25 failed=0 skipped=0`, `SAVE GUARD OK` (fingerprint sebelum = sesudah), 0 baris `SCRIPT ERROR`/`Parser Error`/`TEST FAILURE`; `save_slot_0.json` ABSENT sebelum & sesudah; `git diff --check` bersih. Patch diterbitkan sebagai **`N44_STEP3_FINAL_FAILCLOSED_R2.patch`** (tetap 20 blok: 6 tracked + 14 untracked — dibanding putaran 3 hanya isi `tests/test_step3a_probe_refusal.sh` dan dokumen ini yang berubah); patch-patch sebelumnya tidak ditimpa; SHA-256 di laporan chat.

### 8.9 Putaran audit 5 (19 November 2026) — P2 final: klaim ownership dari pesan penolakan lemah (TOCTOU)

Audit menunjukkan bahwa klaim putaran 8.7 ("path dari pesan penolakan membuktikan ownership") belum sepenuhnya benar. Di produksi, `_make_exclusive_base()` memeriksa keberadaan direktori, **lalu** membuat dengan `make_dir_recursive_absolute()`, **lalu** memvalidasi canonical path — urutan cek→buat **bukan operasi atomik**. Ada dua kondisi ketika fungsi menolak path yang **bukan** dibuat oleh run ini: (1) direktori sudah ada saat pemeriksaan pertama, atau (2) proses lain membuat direktori itu di antara pemeriksaan dan pembuatan (TOCTOU). Dalam kedua kasus pesan penolakan tetap mencetak path — jadi pesan penolakan hanya membuktikan path **ditolak** oleh run ini, **bukan** bahwa direktori itu dibuat dan dimiliki run ini. Script R2 yang mengambil path dari pesan itu lalu menjalankan `rm -rf` berarti tetap berisiko menghapus direktori milik proses lain.

**Perbaikan (kebijakan leftover-safe; hanya script regression — produksi F1/F2 tetap tidak disentuh, simulasi fake `readlink` dan seluruh 9 assertion F2 tetap utuh):**

| Aspek | R2 (dibatalkan) | R3 (final) |
| --- | --- | --- |
| `rm` atas path dari pesan penolakan | dijalankan atas satu path tervalidasi | **tidak pernah** — `rm` berbasis pesan penolakan dihapus total; tidak ada scan/snapshot `/tmp` |
| Base probe yang ditolak | dihapus | **dibiarkan tetap ada** dan path-nya dilaporkan eksplisit (`LEFTOVER KEPT FOR SAFETY: …` — termasuk alasan kenapa dibiarkan) |
| Assertion cleanup | "ter-identifikasi & terhapus" | "ter-identifikasi + tervalidasi (untuk PELAPORAN, bukan untuk rm)" + "artefak DIBIARKAN tetap ada — tanpa rm" → tetap **11/11 CHECK OK** |
| Direktori yang boleh dihapus test | WORK mktemp milik sendiri | tetap hanya **WORK mktemp milik sendiri** (dihapus saat sukses, dipertahankan sebagai bukti saat gagal) |
| Trade-off | — | ada kemungkinan artefak sementara tertinggal di `/tmp` (satu direktori per run penolakan) — sengaja diterima demi keamanan: lebih baik daripada menghapus direktori yang ownership-nya tidak terbukti |

Verifikasi putaran ini: `bash -n` OK; regression F2 **11/11 CHECK OK** dengan bukti `LEFTOVER KEPT FOR SAFETY: /tmp/step3a_iso_…_probe` (artefak dibiarkan, terlaporkan) dan tanpa pemanggilan `rm` apa pun atas path dari pesan penolakan; regression F1 fake-Godot **13/13** tetap lulus; parse `--check-only` 7/7; full runner **exit 0 — `ALL SUITES PASSED`**, `passed=25 failed=0 skipped=0`, `SAVE GUARD OK`, 0 error marker; `save_slot_0.json` ABSENT sebelum & sesudah; `git diff --check` bersih; produksi F1/F2 byte-identik dengan putaran sebelumnya. Patch diterbitkan sebagai **`N44_STEP3_FINAL_FAILCLOSED_R3.patch`** (tetap 20 blok — dibanding R2 hanya isi `tests/test_step3a_probe_refusal.sh` dan dokumen ini yang berubah); patch-patch sebelumnya tidak ditimpa; SHA-256 di laporan chat.
