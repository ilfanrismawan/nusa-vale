# Biji Daya (MVP)

Tiga biji unik per permainan: panen dua jenis tanaman; berinteraksi dengan Akar Keramat di hutan (672, 480) setelah perbaikan jembatan; menyelesaikan fasilitas pertama Balai Nadi. Petunjuk tampil setelah panen pertama dan ketika masuk hutan.

Konsumsi dari inventory memakai konfirmasi. Setiap biji menambah kapasitas pemain penerima 10 permanen dan memulihkan tepat 10 stamina, dibatasi kapasitas baru. Biji Daya sendiri: 100 → 130; ditambah bonus rumah Lv2 +30 dan Lv3 +40, maksimum individu kini 200 (balancing 22 Oktober 2026). Ikon emas berpola akar, gestur memegang biji, aliran akar bercahaya, dan HUD memanjang ke atas.

Save v13 menyimpan ID diperoleh, hadiah tertunda saat tas penuh, jenis panen, dan ID dikonsumsi per pemain. Hadiah bersama berlaku sekali dalam co-op; kapasitas bertambah untuk pemain yang mengonsumsi. Biji tidak bisa dibuang atau dijual. Save lama tetap memakai stamina awal 100. Tujuh sumber lanjutan belum aktif; target 200 kini sudah dicapai melalui tiga Biji Daya dan total bonus rumah 70, tanpa menambah ID baru.

Uji: Godot headless tests/daya_regression.tscn.


## Penguatan transaksi

Konsumsi menyimpan biji, kapasitas dan stamina dalam satu transaksi; kegagalan I/O mengembalikan seluruh perubahan. Penyelesaian fasilitas menyimpan ID hadiah tertunda dan pemain penerima bersama progres fasilitas. Hadiah tertunda aman diterima ulang setelah load tanpa menggandakan biji. Daftar konsumsi global mencegah konsumsi ID yang sama oleh pemain co-op lain.

Efek konsumsi menampilkan biji di tangan/depan karakter dan aliran akar selama kurang dari satu detik; kontrol kembali setelah efek selesai. Akar Keramat berubah redup setelah hadiah diperoleh. Tes mencakup interaksi fisika di hutan, konfirmasi/batal, rollback kegagalan save, donor co-op, dan HUD.
