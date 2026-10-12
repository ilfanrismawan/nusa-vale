# Sprite pertumbuhan tanaman

Bug: generator CropData memberikan semua tanaman source ID 0 (strawberry)
atau 1 (carrot). Tileset Crop farm hanya memiliki dua source itu. Jenis crop
dan hasil panen benar, tetapi gambar dari penanaman sampai pertumbuhan salah.

CropData kini memilih sheet/frame berdasarkan crop_id. FarmManager membuat
source atlas per jenis tanaman pada tileset runtime milik masing-masing layer.
Pose kosong dan kolom ikon panen dilewati; blueberry dan tanaman tinggi memakai
frame 16×32, pohon buah 32×48, dengan origin di dasar petak.

Jumlah tahap, waktu pertumbuhan, musim, dan hasil panen tetap dari CropData.
Save lama tetap kompatibel: crop path dan nomor stage yang sudah tersimpan
dipakai untuk menggambar sprite yang benar saat ladang dipulihkan. Tidak perlu
memulai game baru atau menjalankan generator resource ulang.

35 tanaman memakai sheet pertumbuhan dari asset pack. Rhubarb, garlic,
green_apple, dan zucchini belum memiliki sheet khusus; fallback memakai tunas
umum lalu ikon hasil panen masing-masing dalam ukuran bertahap. Ini tampilan
sementara sampai tersedia sprite pertumbuhan khusus untuk keempat tanaman itu.

Verifikasi: `tests/crop_regression.tscn` menguji semua 39 CropData, hubungan
bibit, penanaman di musim yang tepat, texture/pose yang terlihat, pertumbuhan,
pemulihan tile, dan save/load campuran tanaman. Hasil: 238 pemeriksaan lulus,
`CROP REGRESSION COMPLETE: failures=0`, tanpa error atau warning. Startup farm
headless dan `git diff --check` juga lulus. Tes masuk runner `verify_mvp.ps1`.
