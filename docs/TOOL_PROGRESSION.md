# Kemampuan tools dan alasan upgrade

Sumber stat: `resources/tool_data/`. Ketujuh jenis alat memiliki 10 tier.
Semua aksi sukses menggunakan stamina sekali per ayunan, termasuk area besar.
Sel tidak valid dan air habis tidak menghabiskan stamina/air. Menuang pada tanah
yang sudah basah tetap memakai stamina sekali per aksi dan satu air per petak.

| Tier | Jangkauan bidik (petak) | Kecepatan | Area cangkul/sekop/sabit/air | Kapasitas air | Kekuatan kapak/beliung/sabit | Bonus loot sekop |
|---|---:|---:|---|---:|---:|---:|
| Kayu | 1.5 | 1.00x | 1x1 | 20 | 1 | 0% |
| Tembaga | 1.6 | 1.10x | 1x2 | 35 | 2 | 5% |
| Besi | 1.8 | 1.20x | 1x3 | 55 | 3 | 10% |
| Emas | 2.0 | 1.30x | 2x2 | 80 | 4 | 15% |
| Platinum | 2.2 | 1.40x | 2x3 | 110 | 5 | 20% |
| Crimson | 2.4 | 1.55x | 3x3 | 145 | 7 | 25% |
| Frost | 2.6 | 1.70x | 3x4 | 185 | 9 | 30% |
| Shadow | 2.8 | 1.85x | 3x5 | 230 | 12 | 35% |
| Fairy | 3.0 | 2.00x | 4x5 | 280 | 15 | 40% |
| Obsidian | 3.2 | 2.20x | 5x5 | 350 | 20 | 45% |

- Kapak dan beliung tetap membidik satu objek: peningkatan kekuatan mengurangi jumlah pukulan, jangkauan mouse dan kecepatan meningkat.
- Cangkul menyiapkan area tanah di depan target; hanya petak farmable yang diproses.
- Sekop membersihkan area tanah kosong dan membuka titik gali. Bonus adalah peluang +1 hasil pada setiap titik gali yang berisi loot, bukan tambahan peluang menemukan item langka.
- Sabit memanen tanaman matang dalam area tanpa merusak tanaman muda, sekaligus menebas rumput. Radius rumput naik 12 → 48 px.
- Penyiram menggunakan satu air per petak yang berhasil disiram. Isi ulang dengan menggunakan alat di FishingSpot (sungai/kolam), memakai animasi penyiram dan biaya stamina sesuai tier sekali saat air masuk. Tangki penuh tidak dikenai biaya isi ulang. Tangki sebagian tetap bisa dipakai. Upgrade memperbesar kapasitas tetapi tidak otomatis mengisi tangki.
- Sisa air milik pemain, disimpan untuk solo dan co-op. Game baru/save lama mulai dengan 20 air. Memiliki beberapa penyiram memakai tangki pemain yang sama.
- Tanpa mouse, target dimulai satu petak ke arah hadap; perluasan area tetap mengikuti arah tersebut.

Stamina kapak/beliung: **4, 4, 3, 3, 2, 2, 2, 1, 1, 1**.
Stamina cangkul: **3, 3, 2, 2, 1, 1, 1, 1, 1, 1**.
Stamina sekop: **4, 4, 4, 3, 3, 3, 2, 2, 2, 1**.
Stamina penyiram: **2, 2, 2, 2, 2, 2, 1, 1, 1, 1**. Sabit: **0** semua tier.

Biaya upgrade mulai Tembaga: **500, 1.200, 2.500, 4.500, 7.000, 10.000, 14.000, 20.000, 28.000 G**. Bahan dan dua hari pengerjaan tetap mengikuti pesanan bengkel.

Pancing mempertahankan kemampuan kumulatif RodData yang sudah berjalan: lemparan 3 → 8 petak, charge/perfect, waktu gigitan, zona minigame, pengurangan drain, gerak ikan, bobot ikan langka/legendaris dan peluang tangkapan ganda. Bobot bukan persentase peluang mutlak.

Inventory menampilkan stat aktif, sisa air, harga upgrade, dan kemampuan tier berikutnya. Detail bisa digulir agar teks tetap berada dalam bingkai buku. Biaya uang/material upgrade tetap menggunakan data yang sudah ada.

Validasi: `tests/tool_progression_regression.tscn`, lewat `tools/verify_mvp.ps1` untuk memakai data save terisolasi.

## Pesanan bengkel dan feedback — 13 Oktober 2026

Upgrade dititipkan ke Empu Bima selama dua pergantian hari. Biaya dan bahan
dibayar saat pemesanan; alat dikeluarkan dari tas dan tidak dapat digunakan.
Satu pesanan aktif per pemain, termasuk P2–P4. Setelah selesai, alat harus
diambil dari bengkel. Tas penuh mempertahankan alat di bengkel; pengambilan
tidak dapat diulang. Save versi 10 menyimpan pesanan setiap pemain, dan save
lama tanpa pesanan tetap didukung.

HUD menampilkan ikon penyiram, bar kapasitas, angka sisa/maksimum dan warna
peringatan saat air tinggal 20% atau habis. Meter muncul saat penyiram dipilih.
Sepuluh tier memakai aksen SFX material yang berbeda; pengambilan alat baru
memainkan chord hadiah. Audio menggunakan Kenney Impact Sounds CC0, lihat
`assets/audio/sfx/kenney_impact/SOURCES.md`.

## Pancing per tier

| Tier | Jarak max | Waktu gigitan | Zona | Drain | Gerak ikan | Bobot langka | Bobot legendaris | Ganda |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Wood | 3 | 1x | 1x | 1x | 1x | 1x | 1x | 0% |
| Copper | 3.5 | 1x | 1x | 1x | 1x | 1x | 1x | 0% |
| Iron | 4 | 1x | 1.1x | 1x | 1x | 1x | 1x | 0% |
| Gold | 4.5 | 0.75x | 1.1x | 1x | 1x | 1x | 1x | 0% |
| Platinum | 5 | 0.75x | 1.1x | 1x | 1x | 1.3x | 1x | 0% |
| Crimson | 5.5 | 0.75x | 1.1x | 0.75x | 1x | 1.3x | 1x | 0% |
| Frost | 6 | 0.75x | 1.1x | 0.75x | 0.8x | 1.3x | 1x | 0% |
| Shadow | 6.5 | 0.75x | 1.1x | 0.75x | 0.8x | 1.3x | 1x | 10% |
| Fairy | 7 | 0.75x | 1.1x | 0.75x | 0.8x | 1.3x | 1x | 10% |
| Obsidian | 8 | 0.65x | 1.2x | 0.65x | 0.75x | 1.5x | 2x | 15% |
# Batas resource — 15 Oktober 2026

Kapak/Beliung Kayu hanya memanen kategori kecil, Tembaga membuka normal,
Besi membuka besar. Pada root scene pohon/batu, Inspector → Tool requirement
memiliki `Resource Size` dan `Minimum Tool Tier` (syarat tambahan resource langka).
Pine/Birch/Maple dewasa normal; Mahogany/Deep Forest dewasa besar. Pohon muda,
kayu lepas dan batu kecil tetap bisa dipanen dengan Kayu. Batu tembaga Kayu,
endapan besi kecil Tembaga, batu besi besar Besi, batu emas Emas.
Penolakan tidak menghabiskan stamina. Endapan yang pulih di Forest menyediakan
bahan untuk naik tier tanpa dependensi melingkar; lihat [audit progres awal](EARLY_PROGRESSION_AUDIT_2026-10-15.md).

Penyiraman memakai stamina sekali per aksi dan satu air per petak valid yang
dituangi, termasuk yang sudah basah; minimum biaya satu sesuai tier. Isi ulang
ditagih sekali pada impact animasi. Panduan edit: [EDITOR_GUIDE.md](EDITOR_GUIDE.md).
