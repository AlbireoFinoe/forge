# FORGE — Phase 5C HTTP Integration Harness Safety Fix

**Tanggal:** 19 November 2026
**Lingkup:** Perbaikan pada `backend/tests/test_workout_http_integration.py` berdasarkan audit kode asli dan laporan `REVIEW-WORKOUT-HTTP-INTEGRATION-SAFETY-PHASE5C-20261119.md`.

## 1. Ringkasan keputusan

**Status: perbaikan kode disiapkan; belum dinyatakan READY untuk menjalankan pengujian yang menulis data.** File Python telah diperiksa sintaksnya. Tidak ada akses ke PostgreSQL FORGE milik pengguna, migrasi, operasi HTTP FORGE, atau eksekusi pytest yang menulis data dalam sesi pembuatan patch ini.

File produksi `backend/app/core/database.py` **tidak diubah**. File `backend/requirements-dev.txt` juga **tidak diubah**; deklarasi `httpx==0.28.1` sudah ada di berkas pengguna.

## 2. Tinjauan kode sumber

- Test harness: `backend/tests/test_workout_http_integration.py` (sumber asli 770 baris).
- Engine produksi: `backend/app/core/database.py`; engine dibuat dari `settings.database_url` tanpa `connect_args` khusus.
- Dependency: `backend/requirements-dev.txt` berisi `-r requirements.txt`, `pytest==9.1.1`, `httpx==0.28.1`.
- Safety review: `audits/REVIEW-WORKOUT-HTTP-INTEGRATION-SAFETY-PHASE5C-20261119.md`.

## 3. Perbaikan implementasi

| Temuan | Perubahan di file test | Status implementasi |
|---|---|---|
| HIGH — libpq `PGHOSTADDR`/service env dapat mengubah tujuan koneksi | Buang seluruh variabel berawalan `PG` dari environment proses test **sebelum** koneksi pertama; set `PGOPTIONS` hanya untuk `public`. Parent dan bootstrap child mem-pin `hostaddr=127.0.0.1` dalam `connect_args`. Environment child menggunakan allowlist. | Diimplementasikan; perlu validasi Windows dan PostgreSQL nyata |
| HIGH — HTTPX belum dipasang | Tidak mengubah dependency file; perintah instalasi `httpx==0.28.1` disediakan untuk virtualenv backend. | Langkah lokal pengguna belum dijalankan |
| MEDIUM — search path runtime tidak dipastikan | Preflight dan *engine aplikasi sungguhan* pada parent **dan** child memverifikasi database, `current_schema()` = `public`, dan satu revisi Alembic yang tepat. `PGOPTIONS` khusus test dipertahankan untuk engine produksi yang digunakan oleh pengujian. | Diimplementasikan; perlu validasi nyata |
| MEDIUM — port race | Port ditentukan **oleh child** pada socket loopback yang tetap terbuka sampai Uvicorn menggunakannya; child mengirim nonce + port ke parent melalui pipe. Parent tidak mencoba HTTP sebelum handshake yang diverifikasi dan berjangka waktu. | Diimplementasikan; pola socket telah diuji dengan stub FastAPI lokal, bukan FORGE |
| LOW — sisa data setelah crash | Cleanup ID/email spesifik yang sudah ada tetap dipertahankan. Berkas ini tidak menambahkan auto-delete luas. | Risiko residu masih ada pada kill paksa |
| LOW — diagnostik startup | Handshake memiliki pesan gagal yang tidak memaparkan secret; stderr anak tetap disembunyikan. | Peningkatan parsial; diagnostik mendalam ditunda |

**Pertahanan tambahan:** Semua client HTTPX dalam harness memakai `trust_env=False`, sehingga variabel proxy shell tidak mengalihkan HTTP loopback ke proxy.

## 4. Isolasi dan perilaku yang dipertahankan

- Opt-in tetap wajib: `FORGE_WORKOUT_HTTP_INTEGRATION=1`.
- URL test wajib eksplisit: `FORGE_WORKOUT_TEST_DATABASE_URL`.
- Database harus **persis** `forge_workout_integration_test`, host `127.0.0.1`, port `5432`, driver `postgresql+psycopg`, user `forge`, tanpa query parameter URL.
- Revisi Alembic di `public.alembic_version` harus satu baris `a4f6c91d2e7b`.
- HTTP sungguhan melalui child Uvicorn + HTTPX tetap digunakan.
- Test tetap menggunakan identitas fixture unik dan cleanup sesuai ID/email yang dibuat saat test. Tidak ada DROP/TRUNCATE atau penghapusan global.
- Backend user yang sudah berjalan di port 8000 tidak disetop maupun digunakan oleh harness.

## 5. Validasi yang dilakukan pada artefak patch

- `ast.parse` dan `py_compile`: **lulus**.
- Pengecekan struktur source: URL, opt-in, path check, penggunaan `hostaddr`, sanitasi `PG*`, `PGOPTIONS`, child-owned port/nonce, dan HTTPX `trust_env=False` **diperiksa secara statis**.
- Uji terpisah *dummy* loopback FastAPI/Uvicorn dengan socket bound oleh child: **lulus** di lingkungan pembuatan patch; tidak membuktikan runtime Windows pengguna.
- **Belum dilakukan:** `pytest` FORGE, koneksi ke Docker PostgreSQL pengguna, uji child Uvicorn pada Python 3.13/Windows, migrasi, dan tes regresi backend/Flutter.

## 6. Langkah implementasi pada Windows

1. Pastikan branch `test/workout-integration-phase5`.
2. Simpan salinan file test lama di luar repository jika diperlukan.
3. Ganti **hanya** `backend/tests/test_workout_http_integration.py` dengan file patch ini.
4. Buat laporan ini di `audits/FIX-WORKOUT-HTTP-INTEGRATION-SAFETY-PHASE5C-20261119.md`.
5. Periksa perubahan sebelum eksekusi:

```powershell
cd C:\Projects\forge

git status -sb

# Jika file test masih untracked, `git diff --` tidak akan menampilkan isinya.
# Bandingkan dengan salinan awal di folder TEMP menggunakan `git diff --no-index`.
# Exit code 1 pada `--no-index` berarti ada perubahan, bukan kegagalan syntax.

git diff --check

& .\backend\.venv\Scripts\python.exe -m py_compile .\backend\tests\test_workout_http_integration.py
```

6. Setelah pemeriksaan patch dan kesesuaian target database, HTTPX yang belum ada dapat dipasang secara spesifik, tanpa mengubah kode aplikasi:

```powershell
& .\backend\.venv\Scripts\python.exe -m pip install httpx==0.28.1
```

7. Eksekusi tes integrasi **belum dilakukan**. Sebelum test menulis data, lakukan pemeriksaan ulang URL environment, server PostgreSQL lokal, dan jalankan hanya modul HTTP integration secara opt-in. Jangan menampilkan URL, password atau JWT.

## 7. Risiko / follow-up

- Pengujian masih dapat meninggalkan akun/fixture unik ketika interpreter dimatikan paksa. Operator dapat melakukan **SELECT read-only** pada database khusus test untuk mengidentifikasi email dengan pola `workout-http-%@example.test` setelah crash. Jangan menghapus otomatis sebelum diverifikasi kepemilikannya.
- Pemakaian `PGOPTIONS` pada engine aplikasi perlu dipastikan pada Windows/libpq yang terpasang. Jika tidak menghasilkan `current_schema() = 'public'`, harness harus **gagal sebelum** membuat fixture.
- Proses lain yang memodifikasi database test secara bersamaan tidak dikendalikan oleh harness; jangan gunakan database ini untuk pengguna/pekerjaan lain.
- PostgreSQL Docker host masih terikat ke seluruh interface menurut audit lama; ini belum diperbaiki oleh patch harness dan tetap perlu dikunci sebelum pengujian perangkat LAN.

## 8. Putusan

**PATCH READY FOR LOCAL STATIC REVIEW**, bukan pernyataan bahwa integrasi HTTP sudah lulus. Setelah kode dipasang, validasi sintaks dan pemeriksaan konfigurasi test, lanjutkan first-run terkontrol secara terpisah dengan opt-in eksplisit, lalu catat hasil aktual dan cleanup pada laporan validasi baru.
