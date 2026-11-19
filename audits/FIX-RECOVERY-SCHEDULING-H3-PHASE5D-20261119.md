# Perbaikan H3 — Recovery Scheduling Across Weekly Boundaries

**19 November 2026 · FORGE · `test/workout-mobile-api-phase5d` · basis `15bea21`**

Split dan distribusi kini menghitung jarak hari dalam siklus tujuh hari untuk setiap pasangan sesi atau exposure yang relevan. Setiap pasangan menyumbang penalti paling banyak sekali. Pada split, penalti dibebankan ke sesi yang datang belakangan pada arah terpendek, misalnya Senin untuk pasangan Minggu–Senin.

## Root cause

- Split sudah memiliki fungsi jarak melingkar. Sebelumnya skor assignment hanya memeriksa pasangan pada indeks `i, i+1`, dan skor per sesi hanya memeriksa pendahulu langsung. Pada daftar Senin/Rabu/Minggu, Senin–Minggu terlewat. Pada daftar Senin/Selasa/Rabu, Senin–Rabu terlewat. Bukti sebelum perubahan ada di `split.py:820–830, 974–995, 1098–1115`. [Jarak hari](../backend/app/generator/split.py#L820), [skor assignment sesudah perubahan](../backend/app/generator/split.py#L974)
- Distribusi sebelumnya mengurutkan exposure, memasangkan tetangga daftar, dan menghitung `second.day_of_week − first.day_of_week`. Akibatnya, pasangan Minggu–Senin tetap dianggap berjarak enam hari walaupun hanya ada dua exposure. Bukti sebelum perubahan ada di `distribution.py:261–282`. [Skor pemilihan exposure sesudah perubahan](../backend/app/generator/distribution.py#L196)
- Penalti olahraga pada split sudah memakai jarak melingkar untuk hari yang sama atau satu hari terpisah. `training_capacity_factor` dan pemeriksaan olahraga pada validator memakai kesamaan weekday secara sengaja untuk kapasitas hari yang sama. Fitter menerapkan faktor itu pada budget sesi. Ketiga aturan tetap berlaku. [Skor sport](../backend/app/generator/split.py#L832), [kapasitas hari yang sama](../backend/app/generator/fatigue.py#L20), [fitter](../backend/app/generator/fitter.py#L761), [validator](../backend/app/generator/validator.py#L337)

## Formula jarak dan penalti

| Tahap | Sebelum | Sesudah |
| --- | --- | --- |
| Split | Jarak `min(Δ, 7 − Δ)`, dengan `Δ = abs(a − b)`, hanya untuk tetangga daftar. | Formula jarak yang sama untuk setiap pasangan tak berurutan. Total skor adalah jumlah penalti semua pasangan. |
| Distribusi exposure | Jarak linear `b − a` untuk tetangga pada daftar exposure yang sudah diurutkan. | Jarak `min(Δ, 7 − Δ)` dari helper split yang sama, untuk setiap pasangan exposure dalam kandidat. |

Untuk split, penalti per pasangan tetap `Σ(bobot otot overlap × bobot prioritas × proximity × 4,0)`. Proximity adalah 1,0 untuk jarak satu hari, 0,25 untuk dua hari, dan 0 untuk jarak lain. Untuk exposure otot yang sama, komponen penalti jarak tetap +6,0 pada satu hari, +1,5 pada dua hari, dan 0 untuk jarak lain. Bobot konflik olahraga, recovery sesi, projected load dan kapasitas di skor distribusi tidak dikalibrasi ulang. [Bobot dan faktor split](../backend/app/generator/split.py#L38), [penalti split](../backend/app/generator/split.py#L915), [penalti dan bobot distribusi](../backend/app/generator/distribution.py#L196)

### Contoh manual dan expected vs actual

**Koreksi angka audit awal.** Source sudah mengalikan penalti split dengan 4,0. Untuk CHEST high, bobot otot 1,2 dan prioritas 1,35, sehingga **1,62 adalah penalti pada jarak dua hari**. Penalti pada jarak satu hari adalah **6,48**. Faktor 4,0 dipertahankan. [Formula aktual](../backend/app/generator/split.py#L944)

| Jadwal fixture | Expected | Actual sebelum | Actual sesudah |
| --- | --- | --- | --- |
| Split Senin/Minggu, CHEST high pada keduanya | Jarak `min(6, 1) = 1`, maka `1,2 × 1,35 × 1 × 4 = 6,48` masuk skor Senin. | Total 6,48, seluruhnya masuk Minggu. | Total 6,48, seluruhnya masuk Senin. |
| Split Selasa/Minggu, CHEST high pada keduanya | Jarak `min(5, 2) = 2`, maka `1,2 × 1,35 × 0,25 × 4 = 1,62` masuk skor Selasa. | Total 1,62, seluruhnya masuk Minggu. | Total 1,62, seluruhnya masuk Selasa. |
| Split Senin/Rabu/Minggu, semua CHEST high | Minggu→Senin 6,48 + Senin→Rabu 1,62 + Rabu–Minggu 0 = 8,10. | 1,62 | 8,10 |
| Split Senin/Selasa/Rabu, semua CHEST high | Senin→Selasa dan Selasa→Rabu masing-masing 6,48, ditambah Senin→Rabu 1,62 = 14,58. | 12,96 | 14,58 |
| Exposure Senin/Rabu/Minggu, komponen jarak saja | Minggu–Senin 6,0 + Senin–Rabu 1,5 = 7,5. | 1,5 | 7,5 |
| Exposure Senin/Selasa/Rabu, komponen jarak saja | Dua pasangan jarak satu hari dan satu pasangan jarak dua hari = 13,5. | 12,0 | 13,5 |

## Double counting dan perubahan ranking

`combinations(..., 2)` menghasilkan satu pasangan untuk setiap dua sesi berbeda. Satu sesi menghasilkan nol pasangan, dua sesi menghasilkan satu pasangan walaupun melewati batas minggu, dan tiga sesi menghasilkan tiga pasangan. Jarak tiga hari atau tanpa overlap tidak menambah skor split. Satu penalti dimasukkan ke satu skor sesi pada akhir busur yang lebih pendek. Total dan skor per sesi berasal dari akumulasi yang sama sebelum pembulatan, sehingga `RECOVERY_SPACING_ADJUSTMENT` juga tercatat pada hari penerima yang tepat. Pada hasil dengan banyak sesi, jumlah angka per sesi yang sudah dibulatkan bisa berbeda sedikit dari total yang dibulatkan secara terpisah. [Agregasi pasangan](../backend/app/generator/split.py#L974), [total dan skor per sesi](../backend/app/generator/split.py#L1060)

Pada fixture split Senin/Rabu/Minggu dengan dua blueprint CHEST dan satu BACK, ranking lama memilih CHEST Senin/Minggu dengan skor overlap nol karena pasangan itu tidak dinilai. Ranking baru memilih CHEST Rabu/Minggu dan menempatkan BACK pada Senin. Pada fixture distribusi terpisah, empat set CHEST normal tetap diberikan sebagai dua exposure masing-masing dua set, dan hari pilihan juga berubah dari Senin/Minggu menjadi Rabu/Minggu. Perubahan waktu penempatan dapat memengaruhi penilaian kapasitas dan distribusi otot berikutnya. Split tetap mengoptimalkan gabungan skor sport dan recovery, sedangkan distribusi tetap memakai komponen jarak bersama skor konflik dan beban. [Ranking split](../backend/app/generator/split.py#L1018), [Ranking exposure](../backend/app/generator/distribution.py#L342), [Tes ranking split](../backend/tests/generator/test_weekly_recovery.py#L90), [Tes ranking exposure](../backend/tests/generator/test_weekly_recovery.py#L136)

## Hasil test-first

| Cakupan | Sebelum | Sesudah |
| --- | --- | --- |
| Split, skor total dan skor per hari. Meliputi lintas minggu, dua hari dengan sesi di tengah, satu/dua sesi, jarak tiga hari, dan input weekday terbalik | 4 gagal, 3 lulus | 7 lulus |
| Split tanpa overlap dan tes perubahan ranking blueprint | 1 gagal, 1 lulus | 2 lulus |
| Skor jarak exposure, termasuk urutan sesi yang dibalik dan pasangan lintas minggu | 4 gagal, 3 lulus | 7 lulus |
| Distribusi empat set dengan opsi pasangan lintas minggu | 1 gagal | 1 lulus |
| Seluruh `backend/tests/generator`, termasuk regresi H1 dan H2 | Tahap reproduksi menjalankan file H3 saja | **103 lulus** |

Tes H3 memakai fixture blueprint dan jadwal deterministik tanpa katalog DB. Seluruh suite berjalan dengan subclass `DeclarativeBase` tanpa engine, config stub dan dependency override FastAPI untuk H2. Tidak ada koneksi PostgreSQL. Empat warning deprecation dari dependensi FastAPI, Starlette, dan AnyIO tetap muncul saat suite H2 berjalan. [Tes skenario split](../backend/tests/generator/test_weekly_recovery.py#L45), [tes urutan exposure](../backend/tests/generator/test_weekly_recovery.py#L115)

## File yang diubah

- [backend/app/generator/split.py](../backend/app/generator/split.py#L974) — cakupan pasangan siklik, atribusi skor per sesi, dan pemakaian ulang helper jarak.
- [backend/app/generator/distribution.py](../backend/app/generator/distribution.py#L261) — penalti jarak untuk semua pasangan exposure dalam kombinasi kandidat.
- [backend/tests/generator/test_weekly_recovery.py](../backend/tests/generator/test_weekly_recovery.py) — 17 kasus deterministik.
- `audits/FIX-RECOVERY-SCHEDULING-H3-PHASE5D-20261119.md` — laporan ini.

## Risiko dan batas pengujian

Perbaikan memperluas penilaian dari paling banyak enam pasangan bertetangga ke paling banyak 21 pasangan per assignment tujuh hari. Dampak latensi produksi belum diukur. Koefisien tetap bersifat penalti lunak. Jadwal dengan hari yang sangat terbatas atau konflik sport yang lebih mahal masih bisa menempatkan sesi berdekatan. Skor split menggunakan fokus blueprint dan distribusi menilai exposure terencana sebelum pemilihan exercise serta fitting, sehingga recovery atas komposisi akhir belum diukur. Persistensi, katalog riil dan perangkat Flutter berada di luar verifikasi unit ini.
