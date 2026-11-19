# Perbaikan H1 — Volume Distribution Over-allocation

**19 November 2026 · FORGE · `test/workout-mobile-api-phase5d` · basis `15bea21`**

Temuan H1 (High, P0) diperbaiki pada tahap distribusi. Regression test mereproduksi kelebihan alokasi untuk CHEST dan BACK dari konfigurasi audit. Setelah perbaikan, kedua otot menerima satu set efektif sesuai target, dan seluruh 78 kasus unit generator lulus.

## Root cause dan reproduksi

Pada profil beginner strength dengan tiga hari × 15 menit, CHEST high memiliki base 10, menjadi 9 setelah pengali strength, lalu menjadi 1 setelah skala jadwal `45 / 375` dan pembulatan. BACK normal juga menghasilkan 1 dari `round(7 × 45 / 375)`. Volume engine memang bisa memberi target sekecil satu set. Builder meneruskan volume plan ke distribusi sebelum memuat katalog exercise. [volume.py, pembulatan dan skala](../backend/app/generator/volume.py#L72), [volume.py, target akhir](../backend/app/generator/volume.py#L138), [builder.py, urutan pipeline](../backend/app/generator/builder.py#L161)

Pada implementasi lama (`distribution.py:549–587`), jumlah exposure awal adalah minimum antara frekuensi yang diinginkan oleh prioritas (maintenance/normal/high = 1/2/3) dan jumlah hari kandidat. Target set belum membatasi jumlah exposure. Alokasi awal memberi minimal satu set ke setiap exposure (`distribution.py:457–476`). Untuk target 1 dengan tiga exposure, sisa alokasi menjadi `1 − 3 = −2`. Loop hanya menambah set saat sisa positif, sehingga hasil tetap `[1, 1, 1]`. [distribution.py, aturan prioritas](../backend/app/generator/distribution.py#L16), [distribution.py, minimum dan sisa](../backend/app/generator/distribution.py#L457)

| Kasus | Target | Expected | Actual sebelum | Actual sesudah |
| --- | ---: | --- | --- | --- |
| Beginner strength, Senin/Rabu/Jumat, 15 menit, CHEST high | 1 | `[1]` | `[1, 1, 1]` | `[1]` |
| Profil yang sama, BACK normal | 1 | `[1]` | `[1, 1]` | `[1]` |
| CHEST high, tiga hari kandidat, target sintetis | 2 | `[1, 1]` | Total 3 | Total 2 |

## Strategi dan bukti invariant

Batasi jumlah exposure awal menjadi `min(desired, candidate_count, total_sets)` sebelum memilih hari. Setiap exposure terpilih membutuhkan setidaknya satu set, sehingga membatasi kandidat sejak awal memungkinkan aturan fokus, fallback, beban sesi dan kapasitas olahraga tetap memilih hari terbaik untuk jumlah exposure yang layak. Batas enam set per otot per exposure dan ekspansi jumlah exposure saat kapasitas tidak cukup tetap berlaku. [distribution.py, pemilihan hari](../backend/app/generator/distribution.py#L287), [distribution.py, perubahan H1 dan ekspansi kapasitas](../backend/app/generator/distribution.py#L549)

Untuk target integer positif `T` dan jumlah exposure awal `N`, perubahan menjamin `N ≤ T`. Penambahan exposure hanya terjadi ketika `ceil(T/N) > 6`, yaitu ketika `T > 6N`. Karena `N ≥ 1`, exposure tambahan masih memenuhi `N + 1 ≤ T`. Pada input generator yang sah, volume engine membatasi target ke enam kali jumlah hari dan distribusi dapat mengisi dari seluruh jadwal lewat fallback. Allocator memberi minimum dua jika `T ≥ 2N` atau satu jika kurang, sehingga jumlah minimum tidak pernah melebihi `T`. Loop kemudian membagikan sisa satu per satu hingga nol, tanpa melampaui enam set per exposure. Hasilnya, untuk setiap otot, **jumlah set teralokasi = target mingguan**, dan **jumlah exposure positif ≤ target**. [volume.py, batas dari jumlah hari](../backend/app/generator/volume.py#L173), [distribution.py, alokasi integer](../backend/app/generator/distribution.py#L426), [distribution.py, pemilihan fallback](../backend/app/generator/distribution.py#L695)

Untuk target ≥3, batas baru tidak mengubah exposure awal karena semua prioritas meminta paling banyak tiga exposure. Ekspansi kapasitas, pemilihan hari dan alokasi mendapat input yang sama untuk otot yang targetnya tidak dibatasi. Dalam program campuran dengan target kecil yang diperbaiki, hari untuk otot berikutnya masih dapat bergeser karena distribusi memperhitungkan beban yang telah dialokasikan ke tiap hari. [distribution.py, urutan prioritas](../backend/app/generator/distribution.py#L615), [distribution.py, akumulasi beban](../backend/app/generator/distribution.py#L841)

## Pengujian

Tes ditulis dan dijalankan sebelum source produksi diubah. Runner menggunakan Python lokal dan pytest, menyediakan subclass `DeclarativeBase` di modul `app.core.database` dalam proses tes agar model bisa diimpor tanpa engine, session factory, atau konfigurasi `.env`. Runner hanya mengumpulkan unit test yang disebut di bawah, dengan plugin auto-load, bytecode, dan cache pytest dinonaktifkan.

| Cakupan | Kasus | Sebelum | Sesudah |
| --- | ---: | --- | --- |
| Reproduksi audit melalui `calculate_volume_plan → generate_split_plan → distribute_volume`, dua otot | 1 | 1 gagal | 1 lulus |
| Target 1, 2, 3 × jadwal 1–7 hari × tiga prioritas. Cek jumlah set, jumlah exposure, hari unik, hari tersedia, dan 1–6 set per exposure | 63 | 17 gagal, 46 lulus | 63 lulus |
| Volume 8, 10, 13, 16, dan 18 set. Cek pembagian persis, termasuk ekspansi 1→2 serta 2→3 exposure | 5 | 5 lulus | 5 lulus |
| Target 1 set dengan dua kandidat berkapasitas penuh dan satu hari boxing high. Cek hari terpilih dan jumlah set | 1 | 1 gagal | 1 lulus |
| Unit test generator yang sudah ada untuk split, selector dan fitter | 8 | Tidak dijalankan pada tahap reproduksi | 8 lulus |

**Hasil sebelum:** file regresi saja, 19 gagal dan 51 lulus. **Hasil sesudah:** direktori `backend/tests/generator`, 78 lulus. [Kasus audit](../backend/tests/generator/test_volume_distribution.py#L69), [matriks target kecil](../backend/tests/generator/test_volume_distribution.py#L87), [volume normal/tinggi dan kapasitas](../backend/tests/generator/test_volume_distribution.py#L108)

## File yang diubah

- [backend/app/generator/distribution.py](../backend/app/generator/distribution.py#L565) — batas jumlah exposure awal berdasarkan target set.
- [backend/tests/generator/test_volume_distribution.py](../backend/tests/generator/test_volume_distribution.py) — reproduksi audit dan pengujian distribusi.
- `audits/FIX-VOLUME-DISTRIBUTION-H1-PHASE5D-20261119.md` — laporan ini.

## Risiko dan batas verifikasi

Invariant berlaku pada **alokasi target** dari volume plan generator, yang memberi target positif dan jadwal 1–7 hari. Actual effective sets setelah pemilihan exercise dan fitting dapat berbeda karena kontribusi sekunder, keterbatasan alat, dan pemangkasan durasi. Filter equipment tetap berada di exercise pool. Kelayakan menyelesaikan semua sesi pada profil 15 menit, katalog aktual, persistensi PostgreSQL, API dan Flutter tidak diuji pada tugas ini. Tidak ada operasi database, seed, atau migrasi. [builder.py, tahap setelah distribusi](../backend/app/generator/builder.py#L186), [exercise_pool.py, pemeriksaan equipment](../backend/app/generator/exercise_pool.py#L175)
