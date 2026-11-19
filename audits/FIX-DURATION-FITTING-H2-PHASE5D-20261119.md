# Perbaikan H2 — Duration Fitting Error Handling

**19 November 2026 · FORGE · `test/workout-mobile-api-phase5d` · basis `15bea21`**

POST `/api/v1/programs/generate` kini mengembalikan HTTP 422 ketika fitter tidak bisa mempertahankan coverage dalam durasi yang tersedia atau selector tidak punya exercise yang memenuhi syarat. Error internal tetap diteruskan untuk penanganan HTTP 500. Tes FastAPI terisolasi menunjukkan bahwa kedua kegagalan konfigurasi memanggil rollback sebelum ada perubahan ke program aktif.

## Root cause dan reproduksi

Builder menghitung target mingguan dan split, mendistribusikan target, memuat katalog, lalu memilih dan melakukan fitting exercise per sesi. Selector dapat melempar `ExerciseSelectorError` untuk sesi dengan target tetapi tanpa kandidat yang lolos. Fitter melempar `DurationFitterError` bila sesi masih melebihi anggaran detik dan tidak ada pemangkasan yang menjaga minimum coverage. Kedua exception dapat muncul pada input sah. [builder.py, susunan pipeline](../backend/app/generator/builder.py#L161), [builder.py, seleksi dan fitting](../backend/app/generator/builder.py#L233), [selector.py, kelayakan kandidat](../backend/app/generator/selector.py#L868), [fitter.py, proteksi coverage](../backend/app/generator/fitter.py#L305), [fitter.py, budget dan exception](../backend/app/generator/fitter.py#L761)

Sebelum perbaikan, service melakukan rollback dan melempar exception asli. Route hanya memetakan `GeneratorContextError` dan `ProgramGenerationError` ke 422. `DurationFitterError` dan `ExerciseSelectorError` keluar dari route sebagai exception yang tidak ditangani, sehingga klien menerima 500. [program_service.py, rollback](../backend/app/services/program_service.py#L306), [programs.py, pemetaan 422](../backend/app/api/v1/programs.py#L175)

Reproduksi menggunakan beginner strength, satu hari gym selama 15 menit, boxing high pada hari yang sama, target CHEST high dan BACK normal, serta dua exercise bodyweight sintetis dengan otot primer berbeda tanpa kontribusi silang. Target masing-masing satu set. Boxing high memberi faktor 0,70 dan anggaran sesi dibulatkan menjadi 10 menit (600 detik). Pemanasan 480 detik dan dua exercise satu set, masing-masing 40 detik kerja + 75 detik transisi, menghasilkan 710 detik. Menghapus salah satu exercise menurunkan coverage otot terkait di bawah satu set. Request nyata melalui `TestClient` menghasilkan 500 sebelum perbaikan, dibandingkan 422 dan respons berikut sesudahnya. [fatigue.py, faktor olahraga](../backend/app/generator/fatigue.py#L4), [fitter.py, estimasi durasi](../backend/app/generator/fitter.py#L81), [test_program_generation_errors.py, fixture dan reproduksi](../backend/tests/generator/test_program_generation_errors.py#L25)

```json
{
  "detail": "Unable to fit session 1 within 10 minutes without removing minimum muscle coverage"
}
```

## Exception dan pemetaan HTTP

| Exception atau hasil | Sebelum | Sesudah | Alasan |
| --- | --- | --- | --- |
| `DurationFitterError` selama build | 500 | **422** | Durasi efektif tidak cukup untuk mempertahankan minimum coverage. Pesan menyebut urutan sesi, menit efektif dan coverage. [fitter.py](../backend/app/generator/fitter.py#L812) |
| `ExerciseSelectorError` selama build | 500 | **422** | Katalog yang lolos filter alat/level dan relevansi tidak menyediakan kandidat untuk target sesi. Pesan menyebut sesi tanpa exercise yang eligible. Helper seleksi program lengkap juga memakai tipe ini untuk pool kosong, tetapi builder aktif memakai seleksi per sesi. [selector.py](../backend/app/generator/selector.py#L868), [selector.py, helper program](../backend/app/generator/selector.py#L1220) |
| `GeneratorContextError` | 422 | 422 | Setup wajib hilang atau jumlah hari tidak cocok. [context.py](../backend/app/generator/context.py#L53), [programs.py](../backend/app/api/v1/programs.py#L191) |
| `ProgramGenerationError` dari validator | 422 | 422 | Jalur validasi yang sudah ada, termasuk durasi di atas anggaran atau sesi kosong. [validator.py](../backend/app/generator/validator.py#L299), [program_service.py](../backend/app/services/program_service.py#L235) |
| `VolumeEngineError`, `SplitEngineError`, `VolumeDistributionError` | 500 | 500 | Pada jalur normal, setup sudah membatasi nilai input, context memeriksa jumlah hari dan volume engine membatasi target menurut kapasitas jadwal. Exception yang lolos di tahap ini dapat menunjukkan state tersimpan yang tidak konsisten atau invariant internal yang rusak. [volume.py](../backend/app/generator/volume.py#L79), [split.py](../backend/app/generator/split.py#L794), [distribution.py](../backend/app/generator/distribution.py#L426), [onboarding.py, skema input](../backend/app/schemas/onboarding.py#L57) |
| Bug pemrograman atau kegagalan infrastruktur, seperti `RuntimeError` atau SQLAlchemy `OperationalError` | 500 | 500 | Service melakukan rollback dan membiarkan error ditangani sebagai 500 oleh framework. Tes memverifikasi body generik `Internal Server Error`, termasuk saat exception memuat teks diagnostik. [program_service.py](../backend/app/services/program_service.py#L306), [test_program_generation_errors.py](../backend/tests/generator/test_program_generation_errors.py#L119) |

## Perubahan dan rollback

Service menangkap dua tipe exception terpilih hanya di sekitar `build_program_plan` dan menerjemahkannya menjadi `ProgramGenerationError`. Cause dipertahankan untuk diagnosis internal. Pesan yang dikirim berasal dari kalimat yang dikonstruksi di fitter/selector dan berisi informasi terkait sesi, durasi atau kandidat. Route memakai kontrak JSON `detail` yang sudah ada. Scope catch yang sempit mempertahankan perilaku error dari validasi, persistensi, dan infrastruktur. [program_service.py, perubahan H2](../backend/app/services/program_service.py#L229), [programs.py, respons domain](../backend/app/api/v1/programs.py#L199)

Pada kedua failure build, dan pada lima failure internal yang disuntikkan sebelum persistensi, mock session mencatat tepat satu call `rollback()`. Status program sebelumnya tetap `active`. Perhitungan nomor versi, pengarsipan program, insert, flush, dan commit terjadi setelah build serta validasi berhasil. Tes sukses memakai kandidat yang sama dan mengubah durasi nominal menjadi 30 menit. API memberi 201, membuat versi 2 dengan satu hari dan dua exercise, mengarsipkan versi lama dalam mock, dan memanggil commit satu kali. [program_service.py, urutan persistensi](../backend/app/services/program_service.py#L259), [test_program_generation_errors.py](../backend/tests/generator/test_program_generation_errors.py#L94)

## Hasil pengujian

Tes terlebih dahulu dijalankan pada kode produksi lama, lalu suite generator dijalankan setelah perbaikan. FastAPI hanya memasang router program dan memakai override untuk autentikasi serta session. Pembacaan context dan katalog diganti fixture. Runner membuat subclass ORM `DeclarativeBase` tanpa engine dan menyediakan config kosong dalam proses Python. Bytecode, cache pytest, dan plugin autoload dinonaktifkan.

| Pemeriksaan | Sebelum | Sesudah |
| --- | --- | --- |
| Durasi tidak feasible dan kandidat kosong | 2 gagal, keduanya menerima 500 | 2 lulus, keduanya menerima 422 dan pesan domain |
| Runtime, driver, dan tiga invariant generator | 5 lulus | 5 lulus, tetap 500 generik |
| Konfigurasi feasible | 1 lulus | 1 lulus, 201 dengan commit mock |
| Suite `backend/tests/generator`, termasuk regresi H1 | Tahap reproduksi hanya menjalankan file H2 | **86 lulus** |

Runner mencatat empat warning deprecation dari Starlette/AnyIO setelah perbaikan, termasuk alias konstanta HTTP 422 yang dipakai route saat ini. Perubahan alias berada di luar perbaikan perilaku H2.

## File yang diubah

- [backend/app/services/program_service.py](../backend/app/services/program_service.py#L229) — pemetaan exception lokal pada build.
- [backend/tests/generator/test_program_generation_errors.py](../backend/tests/generator/test_program_generation_errors.py) — regresi HTTP, rollback mock, klasifikasi error internal dan jalur sukses.
- `audits/FIX-DURATION-FITTING-H2-PHASE5D-20261119.md` — laporan ini.

## Risiko dan batas verifikasi

Tes membuktikan urutan operasi dan tidak adanya mutasi program aktif sebelum persistensi pada kegagalan build. Rollback transaksi PostgreSQL, konkurensi, dan perilaku kegagalan setelah commit belum diverifikasi. Refresh sesudah commit pada jalur sukses tetap mengikuti perilaku sebelumnya. Cakupan fixture meliputi kasus durasi tidak feasible dan kandidat kosong, sehingga konfigurasi olahraga dan katalog lain belum diuji end-to-end. Perbaikan mengubah respons API, sementara kebijakan durasi, coverage, serta pemilihan exercise tetap mengikuti algoritme yang ada.
