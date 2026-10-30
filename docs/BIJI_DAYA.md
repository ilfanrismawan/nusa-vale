# Biji Daya (MVP)

Tiga biji unik per permainan: panen dua jenis tanaman; berinteraksi dengan Akar Keramat di hutan setelah perbaikan jembatan; menyelesaikan fasilitas pertama Balai Nadi. Petunjuk tampil setelah panen pertama dan ketika masuk hutan.

Konsumsi dari inventory memakai konfirmasi. Setiap biji menambah kapasitas pemain penerima 10 permanen dan memulihkan tepat 10 stamina, dibatasi kapasitas baru. Biji Daya sendiri: 100 → 130; ditambah bonus rumah Lv2 +30 dan Lv3 +40, maksimum individu kini 200 (balancing 22 Oktober 2026). Ikon emas berpola akar, gestur memegang biji, aliran akar bercahaya, dan HUD memanjang ke atas.

Save v13 menyimpan ID diperoleh, hadiah tertunda saat tas penuh, jenis panen, dan ID dikonsumsi per pemain. Hadiah bersama berlaku sekali dalam co-op; kapasitas bertambah untuk pemain yang mengonsumsi. Biji tidak bisa dibuang atau dijual. Save lama tetap memakai stamina awal 100. Tujuh sumber lanjutan belum aktif; target 200 kini sudah dicapai melalui tiga Biji Daya dan total bonus rumah 70, tanpa menambah ID baru.

Uji: Godot headless tests/daya_regression.tscn.


## Penguatan transaksi

Konsumsi menyimpan biji, kapasitas dan stamina dalam satu transaksi; kegagalan I/O mengembalikan seluruh perubahan. Penyelesaian fasilitas menyimpan ID hadiah tertunda dan pemain penerima bersama progres fasilitas. Hadiah tertunda aman diterima ulang setelah load tanpa menggandakan biji. Daftar konsumsi global mencegah konsumsi ID yang sama oleh pemain co-op lain.

Efek konsumsi menampilkan biji di tangan/depan karakter dan aliran akar selama kurang dari satu detik; kontrol kembali setelah efek selesai. Akar Keramat berubah redup setelah hadiah diperoleh. Tes mencakup interaksi fisika di hutan, konfirmasi/batal, rollback kegagalan save, donor co-op, dan HUD.


## Akar Keramat sebagai scene (27 Oktober 2026)

Akar Keramat kini scene `scenes/world/exterior/object/daya_shrine.tscn` yang dipasang di `Forest.tscn` pada `YSortEntities/DayaShrine` (posisi awal 688, 500); geser langsung di editor. Visual memakai altar berakar Deep Forest (`Altar.png`, rune menyala selama biji belum diambil, padam setelahnya) dan ikon item `biji_daya_forest`. Footprint, area interaksi, aura, partikel, dan label adalah node biasa yang bisa diubah di editor.

Inspector `DayaShrine` mengatur ID biji, flag syarat, semua teks/pesan (termasuk pesan saat masuk hutan, kini hanya tampil selama biji belum diambil), frame altar, ayunan biji, serta efek ambil: paket `ActionFeedback` saat biji lepas (`resources/feedback/daya_obtain.tres`) dan saat diangkat (`sparkle.tres`), tinggi/lama lompatan dan lengkungan ke atas kepala, lama diangkat, skala pop, teks melayang, zoom kamera, nada lonceng, dan kunci input. Urutan efek: altar berkilat + partikel + riak + guncangan, biji melompat, melengkung ke atas kepala pemain, lonceng + teks "Biji Daya!" + zoom, lalu terbang ke tas dan rune padam. Efek konsumsi di tas memakai ikon item yang dikonsumsi.
