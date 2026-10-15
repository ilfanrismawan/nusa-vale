# Audit load dan lag farm/town — 12 Oktober 2026

## Temuan terukur

Profil dilakukan dalam proses Godot terpisah, dengan APPDATA sementara.
Pengukuran rendering memakai Compatibility/ANGLE pada Intel HD Graphics,
driver 10.18.10.4358. Editor pengguna tetap berjalan, sehingga angka merupakan
hasil pengujian lokal dan dapat berubah mengikuti beban komputer.

| Pengukuran | Sebelum | Sesudah |
| --- | ---: | ---: |
| Inisialisasi inventory tertutup | 1.823 ms | 66 ms |
| `_ready` farm, avatar sudah dipersiapkan | 1.680 ms | 240 ms |
| `_ready` town, avatar sudah dipersiapkan | 1.392 ms | 115 ms |
| Bake karakter berulang, asset sudah hangat | 129 ms | 28 ms |
| Median interval frame farm | 41,49 ms (~24 FPS) | 16,77 ms (~60 FPS) |
| Median interval frame town | 34,81 ms (~29 FPS) | 16,71 ms (~60 FPS) |

Setiap scene diukur selama 120 frame; median bukan jaminan semua frame 60 FPS.
Sesudah optimasi, farm masih memiliki p95 34,31 ms dan lonjakan awal 1.100 ms.
Kunjungan farm berikutnya: median 17,03 ms, p95 46,27 ms. Initialisasi shader,
spawner, asset dingin, dan beban editor masih bisa menimbulkan jeda sesaat.

## Penyebab dan perbaikan

1. **Panel inventory dibangun dan diisi sebelum disembunyikan.** Saat masuk
   scene, koleksi membaca resource seluruh katalog, membuat daftar, equipment
   menyusun portrait, dan crafting mengisi resep, padahal inventory tertutup.
   Panel sekarang disembunyikan sebelum masuk tree; data/portrait/daftar diisi
   saat tab pertama dibuka. Koleksi dimuat sekali per panel. Pembukaan tab pertama
   masih memiliki biaya pengisian, tetapi biaya itu tidak lagi menghambat masuk area.
2. **Karakter disusun ulang setiap scene.** Cache sebelumnya hanya menyimpan
   layer sumber, bukan hasil komposisi. Hasil komposisi sekarang disimpan dengan
   kunci katalog, sheet, appearance, tier tool, dan ukuran, maksimal 64 sheet.
   ImageTexture tetap terpisah untuk setiap pemain, sehingga upgrade tool seorang
   pemain tidak mengganti tampilan pemain lain. Bake pertama tetap membutuhkan
   sekitar 1,8–2 detik pada pengukuran rendering ini.
3. **Efek shader dihitung pada piksel yang tidak memerlukannya.** Shader rumput
   juga memanggil efek tanah dan air. Efek air menghitung noise, dasar sungai,
   batu, caustics, dan ripple meskipun mask air bernilai nol. Efek tanah/air sekarang
   langsung mengembalikan warna asli ketika mask nol; detail visual yang relevan
   dipertahankan. A/B tanpa material sebelumnya menurunkan median town ke
   16,49 ms, menunjukkan kontribusi shader pada perangkat ini. Farm membutuhkan
   gabungan perbaikan inisialisasi dan shader; meniadakan material saja tidak
   memperbaiki median farm secara berarti.
4. **Error sementara saat pergantian scene.** Spawner forage mengakses world
   pemain ketika current_scene sudah kosong. Tambahkan pemeriksaan validitas
   world untuk mencegah error tersebut selama pergantian area.

Scene juga memuat banyak objek: sekitar 3.246 node/337 draw call pada farm dan
1.701 node/71 draw call pada town sesudah optimasi. Pembacaan resource masih
sekitar 1,4 detik untuk farm pertama dan 0,38 detik untuk town dalam probe ini.
Optimasi ini tidak mengganti loading sinkron menjadi asynchronous dan tidak
menghapus biaya cold load pertama.

## Verifikasi

`tests/performance_ui_regression.tscn`: delapan pemeriksaan lulus, termasuk
isi koleksi/equipment/crafting saat pertama dibuka, tidak ada duplikasi katalog,
dan independensi texture karakter antar pemain setelah memakai cache.
Probe rendering farm/town selesai tanpa error script; Godot masih memberikan
warning driver OpenGL dan otomatis menggunakan ANGLE.

Log pengukuran sementara: `scratch/perf-render-before.log`,
`scratch/perf-no-material.log`, `scratch/perf-render-after.log`.
Runner MVP juga memasukkan tes regresi UI/cache yang baru.
Suite MVP lengkap lulus (`MVP verification passed.`), termasuk parser, scene,
co-op 2–4 pemain, menu, crafting, bangunan, tanaman, animasi karakter,
Balai Nadi, greenhouse, serta save. `git diff --check` lulus.
