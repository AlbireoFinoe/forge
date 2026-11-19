# PostgreSQL Disposable Integration Validation — FORGE Phase 5D

**19 November 2026 · `test/workout-mobile-api-phase5d` · HEAD `15bea21`**

## Executive summary

**PASS pada PostgreSQL 16 disposable.** Alembic berhasil membangun skema dari kosong, upgrade P1, downgrade untuk data kompatibel, dan menolak downgrade yang akan membuat estimasi pendek tidak valid. Transaction rollback mempertahankan revision, CHECK, dan data pada downgrade yang ditolak. API menyimpan dan membaca estimasi **12, 14, dan 15 menit**. Respons **422** untuk failure fitting dan **500** generik untuk failure CHECK mempertahankan program aktif. Workout dari resep yang disimpan lulus dari start hingga retry finish dan pembacaan ulang.

Rujukan skenario adalah [validasi H1–H3](./VALIDATION-EXERCISE-GENERATOR-H1-H3-PHASE5D-20261119.md), [perbaikan P1](./FIX-PROGRAM-DURATION-PERSISTENCE-P1-PHASE5D-20261119.md), dan [source migration P1](../backend/alembic/versions/7c92e4f1b6a8_allow_short_program_day_estimates.py).

## Preflight dan isolasi

- **Analisis statis.** Branch dan HEAD sesuai, staged diff kosong, dan `git diff --check` lulus. Source aplikasi dan env Alembic memakai `settings.database_url`. Harness memberi config in-memory dan memasok engine terverifikasi untuk Alembic. Kredensial FORGE dan file environment tidak dibaca untuk menjalankan validasi. [Wiring aplikasi](../backend/app/core/database.py#L1), [wiring Alembic](../backend/alembic/env.py#L38)
- **Dieksekusi setelah persetujuan manual.** Docker Linux lokal 29.7.2 sudah memiliki image `postgres:16`. Container baru `forge-phase5d-pg-20261119-67c2` (ID `c8ec9dde12f6`) hanya memublikasikan `127.0.0.1:55432 → 5432/tcp` dan memakai tmpfs untuk data. Image dijalankan dengan `--pull never`. FORGE memakai port 5432. [Container dan guard](../backend/tests/disposable/phase5d_postgres_validation.py#L52)
- **Dieksekusi.** Role baru `phase5d_runner_67c2`, password acak per run, dan dua database baru `phase5d_main_67c2` dan `phase5d_downgrade_67c2`. Runner mematok host dan hostaddr ke loopback serta membersihkan variabel libpq `PG*` dalam prosesnya. Password dan URL berkredensial tidak dicetak.
- **Dieksekusi.** Runner mencocokkan ID, label unik `a264da361be44c7eb296216e55969f3a`, publikasi port dan tmpfs sebelum migrasi atau operasi fixture/API yang menulis. Awal setiap transaksi memeriksa database, role, schema `public`, port server 5432 dan fingerprint server `7709810065690017838` yang diperoleh langsung dari container. Pembuatan database kedua melakukan pemeriksaan yang sama pada koneksi admin disposable. [Guard PostgreSQL](../backend/tests/disposable/phase5d_postgres_validation.py#L127)
- **Cleanup terverifikasi.** Hanya container dengan ID dan label milik run yang dihapus. Pemeriksaan setelah cleanup menunjukkan container disposable sudah hilang dan port 55432 tidak memiliki listener. `forge_postgres` tetap berjalan pada port 5432. Database `forge`, `forge_workout_test`, dan `forge_workout_integration_test` tidak dikoneksikan.

## A. Alembic dan CHECK PostgreSQL

| Skenario | Hasil eksekusi |
| --- | --- |
| Graph dan bootstrap | 15 revision, satu head `7c92e4f1b6a8`, parent `a4f6c91d2e7b`. Database utama mulai tanpa revision dan berhasil mencapai parent. |
| CHECK pada parent | PostgreSQL melaporkan CHECK tervalidasi 15–240. Insert 15 diterima dan dipertahankan, 12 ditolak. |
| Upgrade parent → head | Revision menjadi `7c92e4f1b6a8`, CHECK tervalidasi 1–240, baris existing 15 tetap tersimpan. |
| Boundary pada head | **1, 12, 14, 15, 240** diterima. **−1, 0, 241** ditolak oleh `ck_program_day_duration`. Percobaan boundary diisolasi dengan savepoint. |
| Downgrade, seluruh data ≥15 | Berhasil kembali ke `a4f6c91d2e7b` dan CHECK 15–240. Baris 15 tetap ada. Insert 15 serta 240 diterima, 12 serta 14 ditolak. Database utama di-upgrade kembali ke head untuk tes API. |
| Downgrade, ada estimasi pendek | Database terpisah pada head berisi 12 dan 14. Downgrade gagal dengan SQLSTATE `23514` pada `ck_program_day_duration`. Pembacaan ulang membuktikan revision masih `7c92e4f1b6a8`, CHECK tervalidasi 1–240, dan kedua estimasi tetap `[12, 14]`. |

[Tes migrasi dan pembacaan katalog PostgreSQL](../backend/tests/disposable/phase5d_postgres_validation.py#L205)

## B. Generator, HTTP dan rollback

Router FastAPI asli menggunakan override autentikasi dan session PostgreSQL terverifikasi. Context, katalog, generator, ORM dan transaksi memakai implementasi aplikasi. Resep hasil API dibandingkan dengan fitted plan dan pembacaan ulang.

| Fixture | POST generate | GET current |
| --- | --- | --- |
| Nominal 30, boxing high, satu set per otot | 201 | 200, estimasi **12**, total 2 set fisik, CHEST/BACK masing-masing 1 efektif, rep 8–12, rest 60 detik |
| Nominal 90, boxing high, dua set per otot, rest 30 | 201 | 200, estimasi **14**, total 4 set fisik, CHEST/BACK masing-masing 2 efektif, rep 8–12 |
| Nominal 90, boxing high, dua set per otot, rest 60 | 201 | 200, estimasi **15**, total 4 set fisik, CHEST/BACK masing-masing 2 efektif, rep 8–12 |
| Nominal 15, boxing high | 422, fitting tidak bisa mempertahankan coverage dalam 10 menit | Payload aktif dan daftar versi tetap sama |
| Estimasi 0 disuntikkan tepat sebelum insert | 500 generik, `Internal Server Error` | Payload aktif dan daftar versi tetap sama |

Pada skenario 500, query dalam transaksi yang sama melihat versi ketiga sudah `archived`. PostgreSQL kemudian menolak insert melalui `ck_program_day_duration`. Setelah rollback, session baru menemukan versi ketiga kembali `active`, dua versi historis tetap `archived`, dan tidak ada versi tambahan. GET current cocok dengan snapshot termasuk ID dan resep. [Tes HTTP](../backend/tests/disposable/phase5d_postgres_validation.py#L355), [pembuktian rollback](../backend/tests/disposable/phase5d_postgres_validation.py#L429)

## C. Workout lifecycle

Workout dari versi aktif 15 menit mengembalikan start **201**, empat PATCH log set **200**, finish **200**, dan retry finish **200**. ID program exercise, target set, rentang rep dan rest cocok dengan resep. Payload kedua finish cocok dengan finish pertama dan GET workout. Session PostgreSQL baru membaca empat set yang sama, masing-masing 10 repetisi dan RPE 8. [Tes workout](../backend/tests/disposable/phase5d_postgres_validation.py#L458)

## D. Perhitungan dan performa

| Profil | Target efektif | Set fisik | Efektif aktual | Skor recovery |
| --- | ---: | ---: | ---: | ---: |
| 4 hari, advanced hybrid, Full Gym, nominal 120 | 71 | 67 | 69,25 | 5,64 |
| 7 hari, advanced hybrid, Full Gym, nominal 120 | 71 | 68 | 69,25 | 22,69 |

Kedua build lolos validator dan menghasilkan HTTP 201. Verifikasi independen mencocokkan alokasi per otot, jumlah exposure, equipment, difficulty, rep/rest, set fisik, kredit primer/sekunder, estimasi durasi, serta skor recovery dari pasangan melingkar dengan hasil aplikasi. Profil tiga hari, 15 menit, beginner strength dengan alat terbatas memberi masing-masing satu set dan satu exposure untuk ketujuh otot. Profil pendek ini memverifikasi H1 pada volume/distribusi. Kegagalan fitting diverifikasi melalui kasus HTTP tersendiri. [Asersi invariant](../backend/tests/generator/test_program_integration_validation.py#L128), [profil PostgreSQL](../backend/tests/disposable/phase5d_postgres_validation.py#L493)

Dua warm-up dan enam request terukur per profil. HTTP berjalan dengan ASGI `TestClient` dan DB melalui TCP loopback. Angka **median / maksimum (ms)**. Build mencakup akses katalog. SQL adalah jumlah durasi eksekusi cursor terinstrumen, termasuk query yang juga dihitung dalam build. Verifikasi container berada di luar timer HTTP. Guard transaksi termasuk dalam waktu request.

| Profil | HTTP end-to-end | Build generator | SQL cursor selama request |
| --- | ---: | ---: | ---: |
| 4 hari | 36,89 / 37,89 | 6,14 / 7,74 | 18,71 / 19,41 |
| 7 hari | 147,29 / 193,41 | 102,80 / 129,30 | 27,43 / 43,95 |

[Instrumentasi benchmark](../backend/tests/disposable/phase5d_postgres_validation.py#L524)

## Temuan, keterbatasan, dan selective commit

- **Dieksekusi.** Tidak ditemukan bug produk baru pada skenario ini. Warning deprecation muncul untuk `TestClient` dan alias HTTP 422. Downgrade dengan estimasi pendek ditolak sesuai ekspektasi dan membutuhkan penanganan data yang eksplisit jika deployment harus di-rollback.
- **Keterbatasan.** Run memakai katalog dan akun sintetis, autentikasi dioverride, dan HTTP in-process. Perangkat Flutter, katalog produksi, trafik serentak, serta lock migration pada tabel besar belum diuji. Benchmark merupakan baseline lokal.
- **Analisis statis.** Perubahan H1–H3/P1 tetap tersedia di working tree. Run ini tidak mengedit migration historis, source produksi, test existing, Android Manifest, ataupun konfigurasi environment.
- **Rekomendasi.** Phase 5D **siap selective commit** untuk perbaikan H1–H3/P1, migration baru, dan tes terkait. Harness serta laporan dapat disertakan sebagai artefak validasi. Perubahan manifest lokal, credentials, backup, dan artefak tak terkait dikecualikan. Deployment tetap memerlukan penerapan migration pada target yang diotorisasi. Staged diff kosong dan tidak ada commit.

## File yang dibuat

- [backend/tests/disposable/phase5d_postgres_validation.py](../backend/tests/disposable/phase5d_postgres_validation.py) — harness validasi PostgreSQL disposable.
- `audits/VALIDATION-POSTGRESQL-EXERCISE-GENERATOR-PHASE5D-20261119.md` — laporan ini.

## Final safety review — hardening guard Python

**PASS untuk perbaikan guard di working tree.** Review sebelumnya terhadap blob staged `672ff10b6f32e3fbdbb4b3aef8711d7e24513553` menemukan blocker High. Python menghapus instruksi `assert` saat memakai `-O` atau `PYTHONOPTIMIZE`. Beberapa pemeriksaan container, allowlist dan identitas PostgreSQL semula dapat dilewati sebelum operasi tulis. Pada baseline offline `-O`, mock migrasi dan pembuatan database tercapai pada beberapa mismatch, sehingga regression suite lama gagal. Seluruh operasi tersebut berupa mock.

Guard kini menggunakan kondisi eksplisit yang melempar `RuntimeError`. Berikut cakupan pemeriksaan setelah perbaikan.

| Guard | Perilaku saat verifikasi gagal |
| --- | --- |
| Engine Docker dan nama disposable sebelum create | Engine non-Linux atau nama yang sudah dipakai menghentikan atau mencegah `docker run`. Image tetap lokal dan port harus bisa di-bind sebelum create. [Preflight](../backend/tests/disposable/phase5d_postgres_validation.py#L102) |
| Identitas container, port dan penyimpanan | ID yang belum tercatat atau mismatch ID/nama/label menghentikan verifikasi. Container harus running dengan tmpfs untuk PGDATA, port loopback yang tepat, dan tanpa mount non-tmpfs sebelum operasi DB. [Verifikasi identitas dan konfigurasi](../backend/tests/disposable/phase5d_postgres_validation.py#L72) |
| Allowlist dan identitas PostgreSQL | URL dan koneksi hanya menerima dua nama database disposable. Fingerprint harus terbaca dari container terverifikasi. Koneksi awal dan hook sebelum transaksi menolak hasil identitas atau alamat TCP yang kosong, serta mismatch database, role, schema, fingerprint, atau port. [Allowlist](../backend/tests/disposable/phase5d_postgres_validation.py#L52), [bootstrap fingerprint dan guard transaksi](../backend/tests/disposable/phase5d_postgres_validation.py#L131) |
| Migrasi, fixture dan transaksi | Migrasi memakai engine terdaftar untuk URL target yang tepat. Graph dan revision yang tidak sesuai menghentikan rangkaian. Hasil CHECK yang meleset menghentikan fixture sebelum commit. [Guard migrasi dan fixture](../backend/tests/disposable/phase5d_postgres_validation.py#L218) |
| Cleanup Docker | Pemeriksaan ID penuh, nama dan label run tetap wajib sebelum `rm -f` terhadap ID tunggal. Jika identitas tidak cocok, tidak ada panggilan `rm`. [Cleanup](../backend/tests/disposable/phase5d_postgres_validation.py#L184) |

Regression test menggunakan `unittest` dan mock checks yang tetap aktif pada mode optimasi. Bukti mock menunjukkan tidak ada panggilan engine untuk database terlarang, tidak ada migrasi untuk container/port/mount atau engine yang salah, tidak ada `CREATE DATABASE` atau SQL tulis setelah identitas server gagal, serta tidak ada `rm` saat label cleanup salah. Kontrol positif memeriksa identitas yang sah, engine migrasi terdaftar, dan cleanup dengan ID persis. Import ulang tidak memulai subprocess, engine, koneksi, atau migrasi. [Tes offline](../backend/tests/disposable/test_phase5d_postgres_safety.py)

| Eksekusi offline | Level optimasi terukur | Hasil |
| --- | ---: | --- |
| Python normal | 0 | 13 lulus |
| Python `-O` | 1 | 13 lulus |
| `PYTHONOPTIMIZE=1` tanpa flag `-O` | 1 | 13 lulus |

Blocker High terselesaikan pada versi working tree berdasarkan bukti offline. Bukti PostgreSQL di atas berasal dari run sebelumnya. Docker, PostgreSQL, migration dan fixture sungguhan tidak dijalankan ulang untuk hardening ini. Asersi hasil fungsional pada skenario live HTTP/workout tetap merupakan pengecekan hasil tes, sementara guard yang mengotorisasi akses tetap aktif dalam mode optimasi. Git index dipertahankan, sehingga blob staged yang pernah direview masih memerlukan staging perbaikan pada tahap terpisah sebelum commit.
