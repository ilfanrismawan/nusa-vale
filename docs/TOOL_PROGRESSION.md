# Kemampuan tools dan alasan upgrade

Sumber stat: `resources/tool_data/`. Ketujuh jenis alat memiliki 10 tier.
Semua aksi sukses menggunakan stamina sekali per ayunan, termasuk area besar.
Sel tidak valid, air habis, dan tanah yang sudah disiram tidak menghabiskan stamina/air.

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
- Penyiram menggunakan satu air per petak yang berhasil disiram. Isi ulang gratis dengan menggunakan alat di FishingSpot (sungai/kolam). Tangki sebagian tetap bisa dipakai. Upgrade memperbesar kapasitas tetapi tidak otomatis mengisi tangki.
- Sisa air milik pemain, disimpan untuk solo dan co-op. Game baru/save lama mulai dengan 20 air. Memiliki beberapa penyiram memakai tangki pemain yang sama.
- Tanpa mouse, target dimulai satu petak ke arah hadap; perluasan area tetap mengikuti arah tersebut.

Stamina kapak/beliung: **6, 6, 5, 5, 4, 4, 3, 3, 2, 2**.
Stamina cangkul/sekop: **4, 4, 4, 3, 3, 3, 2, 2, 2, 1**.
Stamina penyiram/sabit: **2, 2, 2, 2, 2, 2, 1, 1, 1, 1**.

Pancing mempertahankan kemampuan kumulatif RodData yang sudah berjalan: lemparan 3 → 8 petak, charge/perfect, waktu gigitan, zona minigame, pengurangan drain, gerak ikan, bobot ikan langka/legendaris dan peluang tangkapan ganda. Bobot bukan persentase peluang mutlak.

Inventory menampilkan stat aktif, sisa air, harga upgrade, dan kemampuan tier berikutnya. Detail bisa digulir agar teks tetap berada dalam bingkai buku. Biaya uang/material upgrade tetap menggunakan data yang sudah ada.

Validasi: `tests/tool_progression_regression.tscn`, lewat `tools/verify_mvp.ps1` untuk memakai data save terisolasi.

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
