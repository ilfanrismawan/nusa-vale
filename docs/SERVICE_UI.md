# Dialog, toko, dan layanan desa

Semua layanan memakai aset UI Farm RPG yang sudah ada: `dialogue box.png`, bingkai `inventory.png`, ribbon `Banner.png`, tombol tutup dari atlas `inventory/button.png`, font m5x7, ikon item, serta potret NPC. Potret berupa sprite sheet dipotong ke satu frame; atlas potret yang sudah ditentukan dipertahankan. Filter texture nearest menjaga pixel art tetap tajam.

- Dialog memakai frame percakapan, nama dan peran pada dua baris, satu potret, indikator halaman, serta tombol **Lanjut / Selesai**. Panel tetap di dalam layar dan melepaskan kontrol setelah ditutup.
- Toko memisahkan **pilih barang → tentukan jumlah → Beli**. Klik pada daftar tidak langsung memotong uang. Total harga tampil sebelum konfirmasi. Pembelian yang tidak cukup uang, tas penuh, atau upgrade tas terkunci diblokir. Shift memilih jumlah 5; gamepad menggunakan atas/bawah untuk memilih, kiri/kanan untuk jumlah, dan A untuk membeli. Penjualan dari tas mempertahankan kontrol yang sudah ada.
- Tukang bangunan menampilkan kartu bergambar, footprint, biaya, bahan tersedia/dibutuhkan, dan deskripsi bangunan. Tombol **Pilih lokasi** aktif ketika uang serta bahan cukup. Biaya tetap dipotong setelah lokasi dikonfirmasi dalam mode placement.
- Bengkel hanya menampilkan alat. Detail memperlihatkan ikon hasil, perubahan stamina/area, harga, dan kebutuhan bahan dari tas pemain yang membuka menu. Pesanan memperlihatkan progres harian dan hari selesai; alat tetap ditahan hingga diambil.
- Menu kandang dan struktur memakai frame serta tombol yang sama. Panel layanan diskalakan agar muat pada viewport dan tetap berada di atas teks petunjuk dunia.

Transaksi, pause, kepemilikan tas co-op, serta save mengikuti sistem gameplay yang sudah ada. `tests/service_ui_regression.tscn` memeriksa pemilihan tanpa pembelian otomatis, pembelian batch, kekurangan uang, kartu bangunan, dan kepemilikan pesanan upgrade. Tes NPC, kandang, dan suite MVP tetap dijalankan untuk mendeteksi regresi.
