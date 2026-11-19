# Final Integration & Regression Validation — Exercise Generator H1–H3

**19 November 2026 · FORGE · `test/workout-mobile-api-phase5d` · HEAD `15bea21` · perbaikan H1–H3 di working tree**

## Executive summary

**H1–H3 siap masuk pengujian integrasi PostgreSQL terisolasi. Persetujuan rilis masih tertahan oleh temuan persistensi P1.** Sebanyak **161 tes lulus**, termasuk 103 tes generator yang sudah ada, 25 kasus validasi baru, dan 33 regresi backend yang aman. Pipeline penuh dengan katalog sintetis lolos untuk 15 kombinasi goal/experience. Jalur HTTP dengan SQLite in-memory berhasil membuat dan membaca program, menyalin resep ke workout, mencatat set, dan menyelesaikan workout secara idempoten.

Reproduksi baru menemukan bahwa program yang lolos validator dengan estimasi 12 menit bisa ditolak oleh constraint penyimpanan minimum 15 menit. SQLite menghasilkan HTTP 500 generik dan transaksi mempertahankan program aktif sebelumnya. Pembanding calculation pipeline pada source Git `15bea21` juga menghasilkan estimasi 12 menit dan lolos validator, sehingga ketidaksesuaian ini sudah ada sebelum perbaikan H1–H3. Database PostgreSQL yang disebutkan dalam permintaan tidak disentuh.

Rujukan cakupan dan baseline adalah [audit awal](./AUDIT-EXERCISE-PROGRAM-CALCULATIONS-PHASE5D-20261119.md), [perbaikan H1](./FIX-VOLUME-DISTRIBUTION-H1-PHASE5D-20261119.md), [perbaikan H2](./FIX-DURATION-FITTING-H2-PHASE5D-20261119.md), dan [perbaikan H3](./FIX-RECOVERY-SCHEDULING-H3-PHASE5D-20261119.md).

## Metode dan status bukti

- **Dieksekusi.** Python lokal dari `backend/.venv`, pytest dengan plugin autoload, cache, dan bytecode dinonaktifkan. Runner menyediakan `DeclarativeBase` dan config stub tanpa membaca `.env`. `get_db` default akan gagal jika override terlewat. Runner menolak semua URL engine selain `sqlite+pysqlite:///:memory:`. Matriks generator menggunakan respons query mock untuk katalog sehingga loader, filter equipment, selection, fitting, dan validator berjalan tanpa engine. [Fixture dan verifikasi pipeline](../backend/tests/generator/test_program_integration_validation.py#L42)
- **Dieksekusi.** Smoke test SQLite membuat tabel sementara dari SQLAlchemy metadata dan mengisi fixture lewat ORM. Router program dan workout dipasang pada aplikasi FastAPI tes dengan override autentikasi dan session. Tes memakai service, query, constraint, serta commit dan rollback SQLite sungguhan. [Tes round-trip](../backend/tests/generator/test_program_integration_validation.py#L298)
- **Analisis statis.** Diff working tree, referensi weekday, fixture backend berisiko, model dan source migration diperiksa. Pembanding runtime mengambil source split/distribution dari `git show 15bea21:...` ke memori, memakai katalog dan builder yang sama. Pembanding ini hanya mengukur perhitungan lama, bukan menjalankan API atau database dari commit lama.
- **Asumsi dan batas data.** Katalog sintetis berisi tujuh otot dengan 14 exercise, dua level kandidat dan dua jenis kebutuhan alat. Kandidat BACK memberi kontribusi BICEPS 0,25. Kasus yang lulus dengan katalog ini tidak mewakili semua kombinasi katalog produksi, histori pengguna, atau perangkat.

## Hasil per area

| Area | Hasil eksekusi |
| --- | --- |
| H1 | 70 kasus lulus. Termasuk 63 kombinasi target 1–3 × 1–7 hari × tiga prioritas dan lima pembagian volume 8–18 set. Contoh audit CHEST/BACK masing-masing teralokasi satu set. |
| H2 | Delapan kasus lulus. HTTP 201 untuk konfigurasi feasible, 422 untuk duration fitter atau kandidat kosong, dan 500 generik untuk bug, driver, serta invariant internal. |
| H3 | 17 kasus lulus. Ranking memilih exposure Rabu/Minggu pada fixture yang sebelumnya memilih Senin/Minggu. Skor dihitung tanpa duplikasi dan stabil terhadap urutan weekday pada fixture. |
| Unit generator lain | Delapan kasus lulus untuk identitas sesi, primary coverage rescue, dan fragment merge. |
| Integrasi generator sintetis | 24 kasus. Seluruh 15 kombinasi goal/experience dan delapan profil jadwal diverifikasi sesuai outcome di matriks, ditambah reproduksi fitter 15 menit dengan boxing high. Invariant dan resep dicek untuk setiap program yang selesai dibangun, termasuk yang ditolak validator. |
| Integrasi HTTP dan persistensi | Satu tes round-trip SQLite lulus. POST generate 201 dan GET current 200 mengembalikan versi serta resep yang konsisten. Attempt yang memberi 422 atau 500 mempertahankan daftar versi dan program aktif. Workout start 201 menyalin ID, set, rep range dan rest. Log set 200, finish 200, dan finish ulang mengembalikan payload yang sama. |
| Regresi backend lain | 11 adaptation, 6 load preference, 5 progress, dan 11 workout lifecycle SQLite lulus. |

**Total akhir 161 lulus.** Satu eksekusi eksplorasi sebelumnya gagal pada `ck_program_day_duration`, dengan 152 kasus lain lulus. Tes akhir menggunakan resep yang memenuhi constraint untuk jalur sukses dan tetap menguji fixture 12 menit sebagai reproduksi 500 serta rollback. Warning deprecation dari dependensi Starlette/AnyIO dan alias HTTP 422 tidak mengubah hasil. [Tes H1](../backend/tests/generator/test_volume_distribution.py), [tes H2](../backend/tests/generator/test_program_generation_errors.py), [tes H3](../backend/tests/generator/test_weekly_recovery.py), [tes integrasi](../backend/tests/generator/test_program_integration_validation.py)

## Matriks input dan output

### Jadwal, durasi, alat, dan olahraga

Angka volume ditulis sebagai **target efektif / set fisik / set efektif aktual**. Estimasi merupakan menit per hari dalam urutan jadwal yang dihasilkan. Status valid adalah keputusan validator generator.

| Hari | Menit nominal | Goal / experience | Equipment dan variasi | Hasil | Volume | Estimasi |
| ---: | ---: | --- | --- | --- | --- | --- |
| 1 | 15 | strength / beginner | Full Gym, CHEST dan BACK saja | Valid, estimasi di bawah constraint DB | 2 / 2 / 2 | 12 |
| 1 | 15 | strength / beginner | Bodyweight, boxing high hari yang sama, CHEST dan BACK | `DurationFitterError` pada 10 menit efektif. Jalur HTTP terpisah menghasilkan 422 | — | — |
| 2 | 45 | fat loss / beginner | Dumbbell tanpa bench, Senin/Minggu | Invalid, `WEEKLY_VOLUME_TOO_HIGH` | 8 / 11 / 11,25 | 17, 19 |
| 3 | 75 | muscle gain / intermediate | Full Gym, Senin/Rabu/Minggu | Valid | 42 / 41 / 42,50 | 37, 30, 31 |
| 4 | 90 | general fitness / beginner | Full Gym, tanpa dedicated leg day | Valid | 41 / 40 / 41,50 | 31, 18, 25, 27 |
| 5 | 90 | hybrid / intermediate | Full Gym, running moderate Minggu | Valid, budget Minggu 76 | 57 / 56 / 58 | 29, 30, 34, 27, 20 |
| 6 | 120 | strength / advanced | Bodyweight, cycling low pada hari tanpa gym | Valid dengan warning target sesi | 76 / 70 / 72,50 | 34, 25, 24, 34, 29, 24 |
| 7 | 240 | hybrid / advanced | Full Gym | Valid dengan warning volume rendah/target sesi | 71 / 68 / 70,25 | 17, 23, 22, 34, 26, 24, 34 |
| 7 | 15 | strength / advanced | Full Gym | `DurationFitterError` pada sesi 1 | — | — |

Fixture tujuh otot memakai CHEST high, TRICEPS maintenance, dan otot lain normal. Arm specialization aktif, tetapi fixture ini tidak menetapkan lengan sebagai prioritas high, sehingga tambahan +2 untuk lengan bukan skenario yang diklaim tercakup. Pada fixture dumbbell tanpa bench, kandidat yang memerlukan kedua alat tidak dapat dipilih. Pada fixture cycling low, semua budget gym tetap 120 menit karena weekday sport berbeda. [Definisi profil dan assertions](../backend/tests/generator/test_program_integration_validation.py#L242)

### Semua goal × experience

Empat hari pada Senin/Rabu/Jumat/Minggu, 75 menit, Full Gym, tujuh otot. Semua 15 valid. Setiap sel memakai urutan **target efektif / set fisik / set efektif aktual**.

| Experience | Muscle gain | Strength | Fat loss | General fitness | Hybrid |
| --- | --- | --- | --- | --- | --- |
| Beginner | 41 / 40 / 41,50 | 40 / 39 / 40,50 | 33 / 33 / 34,25 | 33 / 33 / 34,25 | 38 / 37 / 38,50 |
| Intermediate | 56 / 54 / 56 | 49 / 48 / 49,75 | 43 / 42 / 43,50 | 43 / 42 / 43,50 | 44 / 43 / 44,50 |
| Advanced | 69 / 63 / 65,25 | 62 / 59 / 61,25 | 55 / 53 / 55 | 55 / 53 / 55 | 57 / 56 / 58 |

Nilai di atas berasal dari eksekusi dengan katalog sintetis tetap. Total mingguan hanya ringkasan. Assertions dan validator membandingkan volume per otot. [Matriks pytest dan verifikasi per otot](../backend/tests/generator/test_program_integration_validation.py#L128)

## Invariant dan contoh expected vs actual

| Pemeriksaan | Expected | Actual |
| --- | --- | --- |
| H1, target integer 1 dan 3 hari | Total alokasi 1 dan exposure positif ≤1 | `[1]` untuk CHEST high dan BACK normal pada fixture audit |
| H1, target normal/tinggi | Contoh normal 13 dengan batas 6 membutuhkan ≥3 exposure. High 18 dengan tiga hari membutuhkan tepat 6 per exposure | `[5,4,4]` dan `[6,6,6]` |
| Effective vs physical sets | Set fisik = jumlah set fitted. Kredit per otot = set primer ditambah set sekunder × bobot. Contoh dua set BACK memberi 2 BACK dan 0,50 BICEPS. | Kalkulasi terpisah dari definisi katalog cocok dengan `achieved_effective_sets`, sisa target sesi, `planning_actual_effective_sets`, dan volume per otot validator untuk setiap build yang selesai. |
| Durasi dan resep 1×15 | 480 + 2 × (40 + 75) = 710 detik, estimasi 12 menit. Satu set 8–12 rep per exercise, rest resep 60 detik. | 2 set fisik, 2 efektif, estimasi 12. Rest antar-set tidak menambah durasi karena hanya satu set per exercise. |
| Durasi dan resep SQLite 1×90 + boxing high | 480 + 2 × (80 + 60 + 75) = 910 detik, estimasi 15 menit. Target 2 per otot dari `round(round(8 × 0,9) × 90/375)`. | HTTP 201, `estimated_duration_minutes=15`, 2 exercise dengan 2 set, rep 8–12 dan rest 60. Semua target disalin ke workout. |
| H3 CHEST high pada Senin/Rabu/Minggu | 6,48 pada Minggu–Senin + 1,62 pada Senin–Rabu + 0 pada Rabu–Minggu = 8,10 | 8,10. Jarak melingkar dan total split juga direkonstruksi dari focus muscles untuk setiap build yang selesai. |

Semua alokasi pada build yang selesai memenuhi jumlah per otot tepat sama dengan target, 1–6 set per exposure, satu exposure per otot per weekday, dan jumlah exposure positif ≤ target. Resep fitted memakai metadata rep/rest katalog dan memenuhi equipment serta batas level experience fixture. Jumlah set dan durasi dihitung ulang dari item fitted. Pencarian static terhadap kode aplikasi, scripts, tests, dokumentasi terkait, dan mobile menemukan satu definisi `weekday_distance` dan tiga pemanggil aktif, dua di split dan satu di distribusi. Nama lama `_weekday_distance` tidak muncul sebagai referensi aktif. [Assertions](../backend/tests/generator/test_program_integration_validation.py#L128), [jarak split](../backend/app/generator/split.py#L820), [jarak distribusi](../backend/app/generator/distribution.py#L261)

## Benchmark latensi lokal

Python lokal, advanced hybrid, Full Gym, 120 menit/sesi, katalog sintetis tujuh otot, tanpa sport, weekday berurutan 1 hingga N. Tiga pemanasan dan 15 pengukuran per kombinasi dengan `perf_counter_ns`. Kolom merupakan **median / maksimum dalam ms**. Baseline split dimuat dari Git tanpa checkout. Build mencakup setup mock query, seluruh kalkulasi, dan validator, di luar HTTP dan persistensi.

| Hari | Split baseline `15bea21` | Split H3 | Build + validate H1–H3 |
| ---: | ---: | ---: | ---: |
| 1 | 0,008 / 0,010 | 0,008 / 0,009 | 1,947 / 4,341 |
| 2 | 0,017 / 0,025 | 0,017 / 0,018 | 3,351 / 6,419 |
| 3 | 0,035 / 0,037 | 0,043 / 0,059 | 3,868 / 4,446 |
| 4 | 0,128 / 0,149 | 0,196 / 0,223 | 3,501 / 4,244 |
| 5 | 0,736 / 0,933 | 1,204 / 1,403 | 3,837 / 5,724 |
| 6 | 4,744 / 6,116 | 9,495 / 9,612 | 12,119 / 13,973 |
| 7 | 42,318 / 43,705 | 91,064 / 103,302 | 107,602 / 165,077 |

Pada tujuh hari, median split meningkat sekitar **2,15× (+48,75 ms)**. Ini adalah biaya yang terukur dari evaluasi pasangan, bukan estimasi latensi HTTP produksi. Fixture ranking H3 dan rekalkulasi skor mendukung koreksi fungsional pada kombinasi yang diuji. Latensi dengan katalog produksi, konflik sport, banyak pengguna serentak, dan PostgreSQL belum diukur. [Loop ranking](../backend/app/generator/split.py#L1018), [agregasi pasangan](../backend/app/generator/split.py#L974)

## Temuan baru dan potensi regresi

### P1 High — Durasi estimasi 12 menit lolos validator dan gagal saat insert

**Bug terbukti di SQLite, dengan dukungan statis untuk skema PostgreSQL.** Fixture beginner strength, satu hari, 30 menit nominal, boxing high, bodyweight, serta CHEST/BACK masing-masing satu set menghasilkan anggaran 21 menit dan estimasi 12 menit. Validator menerima karena ada working set, coverage terpenuhi, dan estimasi ≤ budget. Service menyalin 12 ke `program_days.estimated_duration_minutes`, sedangkan model dan migration membatasi 15–240. Insert memicu `ck_program_day_duration` dan respons 500. Pada tes ulang setelah versi aktif dibuat, 500 generik mempertahankan versi 1 serta semua resepnya. Fixture generator tanpa sport 1×15 juga menghasilkan 12 dan lolos validator. Pembanding baseline menghasilkan build valid dengan 12 menit untuk kedua profil tersebut. [Fitter](../backend/app/generator/fitter.py#L920), [validator](../backend/app/generator/validator.py#L299), [penyimpanan](../backend/app/services/program_service.py#L136), [constraint model](../backend/app/models/program_day.py#L38), [migration](../backend/alembic/versions/c2d069a4198d_add_training_program_schema.py#L44), [tes rollback](../backend/tests/generator/test_program_integration_validation.py#L373)

**Expected.** Jika sesi singkat adalah resep yang sah, storage menerima estimasi aktualnya. Jika ada minimum durasi sebagai aturan produk, validator menolak dengan error domain sebelum persistensi. **Rekomendasi.** Sepakati semantik minimum untuk durasi nominal dan estimasi resep, selaraskan validator serta skema, lalu tambahkan tes boundary 14/15 menit di PostgreSQL terisolasi. Tes karakterisasi 500 perlu diperbarui menjadi perilaku final ketika bug diperbaiki.

### P2 Medium — Profil target kecil masih bisa ditolak karena actual volume berlebih

**Pembatasan terukur dengan katalog sintetis, sudah muncul pada baseline.** Profil 2×45 fat loss beginner pada Senin/Minggu, prioritas campuran dan dumbbell tanpa bench, memiliki target total 8. Alokasi tepat 8, tetapi fitted actual ABS 2,00/1,00, BICEPS 2,25/1,00 dan TRICEPS 2,00/1,00. Validator menerima maksimal 160% dan menolak ketiganya. Baseline juga menolak otot yang sama dengan rasio yang sama walaupun hari/estimasi berbeda. **Rekomendasi.** Telusuri bagaimana seleksi dan fitting menangani target integer kecil serta kredit sekunder, dan ukur frekuensi pada katalog aktual. Temuan ini tidak menunjukkan pelanggaran invariant alokasi H1. [Batas validator](../backend/app/generator/validator.py#L23), [tes jadwal](../backend/tests/generator/test_program_integration_validation.py#L262)

### P2 Medium — Biaya ranking bertambah untuk jadwal padat

**Perubahan performa terukur, dampak layanan belum diverifikasi.** Split tujuh hari mencoba 5.040 assignment, dengan hingga 21 pasangan per assignment. Fixture benchmark menunjukkan kenaikan yang lebih besar pada enam dan tujuh hari. **Rekomendasi.** Bandingkan terhadap budget latensi layanan pada pengujian terisolasi dan ukur concurrency sebelum menentukan kebutuhan optimasi. [Benchmark dan metodologi](#benchmark-latensi-lokal)

## Pemeriksaan Git dan tes yang dikecualikan

- Diff produksi yang sudah ada mencakup `distribution.py`, `split.py`, dan `program_service.py`. Dua Android Manifest juga memiliki perubahan lokal yang sudah terlihat saat sesi dimulai. Empat file test generator untracked telah ditinjau dan dijalankan, termasuk satu file validasi yang ditambahkan pada sesi ini. Inventaris untracked lain ditinjau dari status Git, tanpa membuka isi credentials atau backup. `git diff --check` bersih dan staged diff kosong.
- `test_workout_lifecycle.py` dijalankan dengan 11 node yang memakai fixture `db_session` SQLite in-memory. Fixture PostgreSQL, tes konkurensi, dan tes migration ditinggalkan. `test_workout_http_integration.py` dikecualikan karena fixture menyiapkan server/engine PostgreSQL serta melakukan commit dan cleanup. Route registration load preference hanya membaca OpenAPI. [Fixture SQLite](../backend/tests/test_workout_lifecycle.py#L57), [fixture PostgreSQL](../backend/tests/test_workout_lifecycle.py#L70), [HTTP PostgreSQL](../backend/tests/test_workout_http_integration.py#L440), [tes OpenAPI](../backend/tests/test_load_preferences.py#L106)
- Sesi ini menambah [test_program_integration_validation.py](../backend/tests/generator/test_program_integration_validation.py) dan laporan ini. Source produksi, test H1–H3 lama, manifest, environment, dan dependency tetap seperti saat validasi dimulai.

## Keterbatasan PostgreSQL dan rencana tahap berikut

SQLite memverifikasi alur ORM, serialisasi HTTP, dan rollback untuk fixture, tetapi belum memverifikasi driver PostgreSQL, constraint yang benar-benar terpasang, concurrency, locking, proses migrasi, maupun katalog dari lingkungan PostgreSQL. Pengujian perangkat Flutter juga belum dijalankan. Temuan P1 untuk PostgreSQL didukung oleh mekanisme dan definisi migration yang sama, sementara observasi runtime hanya dari SQLite.

Rencana integrasi berikut menggunakan instance PostgreSQL disposable dengan DB dan role khusus run, tidak mengambil konfigurasi lokal. Role test dibatasi ke instance tersebut dan proses harus memverifikasi host, nama DB unik, role, schema, serta revision sebelum menjalankan fixture. Tolak target `forge`, `forge_workout_test`, dan `forge_workout_integration_test`. Setelah otorisasi tahap terpisah, bootstrap hanya instance disposable dan jalankan generate→current→workout, reproduksi 12 menit dengan rollback, uji constraint dan lifecycle PostgreSQL, serta ukur latency real. Setelah selesai, buang instance disposable milik run itu. Rencana ini belum dieksekusi.
