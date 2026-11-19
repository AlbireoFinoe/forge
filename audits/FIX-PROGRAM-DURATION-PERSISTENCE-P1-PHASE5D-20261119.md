# Perbaikan P1 — Generated Program Duration vs Database Constraint

**19 November 2026 · FORGE · `test/workout-mobile-api-phase5d` · HEAD `15bea21`**

Estimasi sesi valid 12, 14, dan 15 menit sekarang kembali apa adanya dari API setelah tersimpan melalui SQLite in-memory. Batas durasi nominal tetap 15–240 menit. Validator menegakkan estimasi yang positif dan tidak melebihi budget efektif. Model ORM, schema respons dan migration baru menggunakan rentang estimasi 1–240 menit. Deployment PostgreSQL memerlukan penerapan migration pada tahap yang diotorisasi terpisah. [Laporan validasi yang menemukan bug](./VALIDATION-EXERCISE-GENERATOR-H1-H3-PHASE5D-20261119.md#temuan-baru-dan-potensi-regresi)

## Root cause dan audit penggunaan

| Lapisan | Perilaku dan bukti |
| --- | --- |
| Setup | `session_duration_minutes` adalah budget pilihan pengguna. Schema input, constraint preferensi, dan slider Flutter menerima 15–240 menit. Field dan batas ini tetap berlaku. [Schema onboarding](../backend/app/schemas/onboarding.py#L57), [model preferensi](../backend/app/models/training_preference.py#L22), [slider Flutter](../mobile/lib/features/onboarding/presentation/training_preferences_screen.dart#L313) |
| Generator dan fitter | Builder meneruskan context ke fitter. Fitter membulatkan budget dari durasi nominal × faktor kapasitas olahraga. Fitting membandingkan resep dengan budget dalam detik. Estimasi akhir dibulatkan dari detik resep aktual. Resep yang selesai jauh sebelum budget dapat memiliki estimasi kurang dari 15 menit. [Builder](../backend/app/generator/builder.py#L233), [durasi fitter](../backend/app/generator/fitter.py#L81), [budget fitting](../backend/app/generator/fitter.py#L761), [estimasi akhir](../backend/app/generator/fitter.py#L920) |
| Validator | Sebelum perubahan, validator hanya menolak estimasi di atas budget dan menilai jumlah working set secara terpisah. Estimasi 12 menit dengan working set dan coverage sah lolos. Setelah perubahan, validator juga menolak estimasi nol atau negatif dengan `SESSION_DURATION_INVALID`. Estimasi di atas budget tetap `SESSION_DURATION_EXCEEDED`. [Validator](../backend/app/generator/validator.py#L299) |
| Persistence | Service menyalin estimasi dari fitted plan ke `ProgramDay` tanpa transformasi. Sebelum perubahan, constraint `ck_program_day_duration` menolak angka di bawah 15 meski telah lolos validator. Kegagalan flush di-rollback dan menjadi HTTP 500. ORM dan migration baru memperbolehkan angka 1–240. [Service](../backend/app/services/program_service.py#L136), [model](../backend/app/models/program_day.py#L38), [migration historis](../backend/alembic/versions/c2d069a4198d_add_training_program_schema.py#L44) |
| API | Route detail meneruskan angka yang disimpan. `ProgramDayResponse` sebelumnya bertipe int tanpa rentang. Sekarang field JSON yang sama mendeklarasikan 1–240. Endpoint generate tetap mengembalikan ringkasan, sedangkan angka estimasi diverifikasi melalui GET current. [Route programs](../backend/app/api/v1/programs.py#L120), [schema respons](../backend/app/schemas/program.py#L56) |
| Flutter | Model membaca `estimated_duration_minutes` sebagai int. Home, Train, dan Program Detail menampilkan angka dengan satuan menit tanpa batas minimum tampilan. Kompatibilitas payload dinilai dari source; tes perangkat Flutter belum dijalankan. [Model Flutter](../mobile/lib/features/program/data/program_models.dart#L117), [Home](../mobile/lib/features/home/presentation/home_screen.dart#L619), [Home next session](../mobile/lib/features/home/presentation/home_screen.dart#L866), [Train](../mobile/lib/features/train/presentation/train_screen.dart#L531), [Program Detail](../mobile/lib/features/program/presentation/program_detail_screen.dart#L385) |

## Kontrak sebelum dan sesudah

| Nilai | Sebelum | Sesudah |
| --- | --- | --- |
| Durasi nominal | Integer 15–240 menit | Integer 15–240 menit |
| Budget efektif | `round(nominal × kapasitas)` | Formula yang sama |
| Estimasi di generator | `round(detik resep / 60)`; validator mewajibkan ≤ budget efektif | Formula yang sama; validator mewajibkan estimasi >0 dan ≤ budget efektif |
| Estimasi yang disimpan | Integer non-null 15–240 | Integer non-null 1–240 pada ORM dan skema setelah migration |
| Estimasi di JSON detail | Integer | Field dan tipe yang sama dengan batas 1–240 |

Budget efektif bergantung pada context olahraga saat program dibangun. Kolom `program_days` menyimpan estimasi, sehingga aturan relatif terhadap budget dijaga di fitter dan validator. Batas absolut 240 pada ORM/JSON mengikuti batas nominal dan faktor kapasitas yang paling tinggi 1. Estimasi dipertahankan sesuai hasil resep tanpa penyesuaian angka ke 15. [Faktor kapasitas](../backend/app/generator/fatigue.py#L20)

## Test-first dan rollback

| Pemeriksaan | Sebelum | Sesudah |
| --- | --- | --- |
| Nominal 30, boxing high, dua exercise × satu set, estimasi 12 | POST 500 | POST 201, GET current 12 |
| Nominal 90, boxing high, dua exercise × dua set dengan rest 30 detik, estimasi 14 | POST 500 | POST 201, GET current 14 |
| Nominal 90, boxing high, dua exercise × dua set dengan rest 60 detik, estimasi 15 | POST 201 | POST 201, GET current 15 |
| Estimasi 0 dalam fitted plan dengan working set | Validator menerima | Error `SESSION_DURATION_INVALID` |
| Estimasi 0 dalam schema respons | Schema menerima | Schema menolak. Estimasi 12 diterima dan input nominal 14 ditolak. |
| Budget efektif 15, estimasi 15 atau 16 | 15 valid, 16 ditolak | 15 valid, 16 ditolak dengan `SESSION_DURATION_EXCEEDED` |
| Nominal 15 dengan boxing high dan dua target satu set | 422 pada jalur regresi H2 | 422 dengan alasan budget 10 menit, versi aktif tetap tersedia |
| Kegagalan insert setelah arsip program aktif | Tes kondisi 15 menit mempertahankan program sebelumnya | Untuk ketiga resep valid, tes menyuntikkan estimasi 0 tepat sebelum SQL INSERT. Query dari transaksi yang sama melihat versi lama sudah `archived`. CHECK menolak insert, HTTP 500 tetap generik, dan GET current serta pembacaan tabel kemudian membuktikan hanya versi lama yang `active`. |

Perhitungan manual fixture memakai pemanasan 480 detik dan 75 detik transisi per exercise. Estimasi 12 berasal dari 710 detik, 14 dari 850 detik, dan 15 dari 910 detik. Setelah memeriksa rollback, setiap round-trip memakai program yang masih aktif untuk start workout, mencatat set, dan melakukan finish dua kali dengan hasil identik. [Tes validator dan schema](../backend/tests/generator/test_program_integration_validation.py#L288), [tes HTTP/persistensi/workout](../backend/tests/generator/test_program_integration_validation.py#L335), [bukti status di transaksi yang gagal](../backend/tests/generator/test_program_integration_validation.py#L424)

**Sebelum perubahan source:** 4 gagal, 3 lulus pada tujuh kasus P1. Dua 500 menunjukkan mismatch penyimpanan dan dua kegagalan menunjukkan nol lolos validator/schema. **Setelah perubahan:** 167 lulus, terdiri dari 134 tes generator termasuk regresi H1–H3 dan 33 tes backend aman (11 adaptation, 6 load preference, 5 progress, 11 workout lifecycle SQLite). Delapan warning deprecation berasal dari dependensi HTTP dan alias konstanta HTTP 422 yang sudah digunakan sebelumnya. Runner membatasi engine ke SQLite in-memory, memakai config stub tanpa `.env`, dan tidak mengoleksi tes PostgreSQL. Source migration hanya diperiksa lewat AST. Graph berisi 15 revision dengan head tunggal `7c92e4f1b6a8` dan parent `a4f6c91d2e7b`.

## File yang diubah

- [backend/app/generator/validator.py](../backend/app/generator/validator.py#L308) — cek estimasi positif sebelum cek budget.
- [backend/app/models/program_day.py](../backend/app/models/program_day.py#L38) — rentang CHECK estimasi menjadi 1–240.
- [backend/app/schemas/program.py](../backend/app/schemas/program.py#L65) — rentang estimasi di kontrak respons.
- [backend/alembic/versions/7c92e4f1b6a8_allow_short_program_day_estimates.py](../backend/alembic/versions/7c92e4f1b6a8_allow_short_program_day_estimates.py) — penggantian CHECK dan downgrade ke rentang lama.
- [backend/tests/generator/test_program_integration_validation.py](../backend/tests/generator/test_program_integration_validation.py) — parameterisasi boundary, cek schema/validator dan kegagalan insert yang independen dari bug lama.
- `audits/FIX-PROGRAM-DURATION-PERSISTENCE-P1-PHASE5D-20261119.md` — laporan ini.

Formula volume, recovery, seleksi exercise, fitting, serta pemetaan error H2 tetap mengikuti implementasi H1–H3. Migration historis tetap menjadi bagian dari graph dan tidak diedit.

## Kompatibilitas migration dan validasi PostgreSQL berikutnya

- **Upgrade.** CHECK lama diganti dengan CHECK bernama sama dan rentang lebih longgar. Seluruh baris yang memenuhi 15–240 tetap valid. Migration berisi DDL constraint tanpa update, backfill, atau penghapusan data. Terapkan migration sebelum mengandalkan penyimpanan estimasi singkat pada PostgreSQL target.
- **Downgrade.** CHECK 15–240 dipulihkan. Secara rancangan, bila masih ada baris 1–14, PostgreSQL akan menolak penambahan CHECK yang lebih ketat. Dengan DDL transaksional, kegagalan seharusnya membatalkan penggantian constraint dan mempertahankan data. Downgrade tidak menyunting estimasi. Hasil rollback DDL, lock dan durasi validasi tabel belum diukur secara langsung. [Migration baru](../backend/alembic/versions/7c92e4f1b6a8_allow_short_program_day_estimates.py#L22), [transaksi Alembic](../backend/alembic/env.py#L38)
- **Tahap disposable setelah diotorisasi.** Gunakan instance dan role sementara dengan nama DB unik. Verifikasi identitas koneksi, schema dan revision awal serta tolak `forge`, `forge_workout_test`, dan `forge_workout_integration_test`. Terapkan upgrade dari revision induk pada instance disposable, konfirmasi baris existing pada rentang lama, lalu uji respons 201 dengan 12/14/15, 422 untuk constraint program, 500 generik saat insert gagal, dan status versi aktif. Verifikasi downgrade saat seluruh baris ≥15 dan percobaan downgrade dengan baris pendek pada skenario terpisah. Ukur lock/waktu DDL pada ukuran data representatif sebelum memilih jendela deployment.

Migration tidak dieksekusi pada sesi ini. Keberhasilan tahap database PostgreSQL belum diverifikasi.
