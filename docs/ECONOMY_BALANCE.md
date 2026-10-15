# Balancing ekonomi dan rutinitas — 13 Oktober 2026

Baseline demo untuk pemain solo; co-op menggunakan uang bersama dan stamina/tas
per pemain. Angka ini sudah dipasang di Resource dan kode. Kenyamanan dan
balancing akhir masih perlu playtest manual beberapa hari, terutama fishing,
jumlah mesin, serta co-op dengan 3–4 pemain.

## Waktu dan stamina

Pembaruan progres awal 15 Oktober: [EARLY_PROGRESSION_AUDIT_2026-10-15.md](EARLY_PROGRESSION_AUDIT_2026-10-15.md)
memeriksa akses material dan modal bibit setelah pembatas tier. Harga tetap.
Panen starter solo 510 G + uang awal 100 G menyisakan 110 G setelah satu order
Tembaga, sedangkan menanam ulang paket awal perlu 225 G. UI upgrade sekarang
memperlihatkan sisa saldo; peningkatan semua alat sekaligus belum menjadi target awal.

- 10 menit game = 6 detik aktif. Dari 06:00 sampai 05:00 berlangsung 13 menit
  48 detik nyata. Batas pingsan 05:10. Menu/pause tidak menghabiskan waktu aktif.
- Stamina awal 100 dan pulih setelah tidur; tiga Biji Daya dapat menaikkan kapasitas
  pemain sampai 130. Rincian perbedaan tidur/pingsan ada di GDD.
- Kapak/beliung kayu dan tembaga: 4 stamina per pukulan (sebelumnya 6).
  Urutan semua tier: 4, 4, 3, 3, 2, 2, 2, 1, 1, 1.
- Cangkul: 3, 3, 2, 2, 1, 1, 1, 1, 1, 1 stamina per ayunan/area.
- Penyiram tetap 2 stamina awal; tier tinggi 1. Sekop dan pancing mengikuti
  stat sebelumnya. Sabit gratis pada semua tier, sesuai aturan pembersihan lahan.
- Delapan petak baru membutuhkan 24 stamina untuk cangkul dan 16 untuk siram.
  Ada 60 stamina tersisa untuk aksi lain, sebelum biaya menanam dan isi air.

## Tanaman, harga, dan hasil

Harga bibit dan lama tumbuh dipertahankan. Semua 39 tanaman menghasilkan
sekitar 7 G laba per petak per hari tumbuh untuk tanaman 5 hari, atau 10 G
untuk tanaman 10 hari. Rumus laba adalah `(harga hasil × jumlah panen − harga
bibit) / hari tumbuh`. Ini belum menghitung waktu perawatan, stamina, serta
modal mesin. Angka dibulatkan ke unit G.

| Tanaman | Bibit | Hari tumbuh | Hasil | Harga/unit | Laba/siklus |
|---|---:|---:|---:|---:|---:|
| Wortel | 25 G | 5 | 1 | 60 G | 35 G |
| Stroberi | 30 G | 5 | 2 | 33 G | 36 G |
| Blueberry | 50 G | 5 | 2 | 43 G | 36 G |
| Kacang polong | 25 G | 5 | 2 | 30 G | 35 G |
| Padi | 20 G | 5 | 3 | 19 G | 37 G |
| Gandum | 15 G | 5 | 3 | 17 G | 36 G |
| Kembang kol | 45 G | 10 | 1 | 145 G | 100 G |
| Melon | 50 G | 10 | 1 | 150 G | 100 G |

Stroberi, blueberry, blackberry, anggur, dan kacang polong menghasilkan 2 unit;
padi/gandum 3 unit. Tanaman lainnya 1 unit. Harga per unit beberapa tanaman
turun karena hasil panennya bertambah. Jenis buah yang kini memakai sistem
crop sekali panen tetap dihitung sebagai crop, bukan pohon buah permanen.

Bibit awal gratis tetap 5 stroberi + 3 wortel. Panen pertamanya memberi
`5 × 2 × 33 + 3 × 60 = 510 G`; bersama 100 G uang awal menjadi 610 G.
Ini membuat satu upgrade tembaga memungkinkan setelah panen pertama,
tetapi pemain harus memilih antara upgrade dan membeli kembali semua bibit.
Perhitungan ini mengasumsikan semua tanaman disiram tiap hari, tanpa kegagalan
musim dan tanpa menghitung bahan upgrade yang perlu dikumpulkan.

Target progres: panen pertama sekitar hari 6, satu upgrade awal pada minggu
pertama/awal minggu kedua, serta modal coop dan ayam sebagai target berikutnya.
Target tersebut bukan jaminan waktu; fishing, forage, dan pilihan belanja dapat
mempercepat atau memperlambatnya.

## Pakan dan ternak

Pakan/jerami tetap 10 G per hewan per hari, nilai jual 2 G. Setiap hewan
tetap membutuhkan satu jatah per hari; rumput/silo dapat mengurangi pembelian.
Harga beli hewan, biaya kandang, dan interval produksinya dipertahankan.

| Hewan | Modal hewan | Produk normal | Interval | Laba/hari setelah pakan | Balik modal hewan |
|---|---:|---:|---:|---:|---:|
| Ayam | 800 G | 50 G | 1 hari | 40 G | 20 hari |
| Bebek | 1.400 G | 110 G | 2 hari | 45 G | ~31 hari |
| Sapi | 2.500 G | 100 G | 1 hari | 90 G | ~28 hari |
| Kambing | 3.200 G | 170 G | 2 hari | 75 G | ~43 hari |
| Domba | 3.000 G | 270 G | 3 hari | 80 G | ~38 hari |

Balik modal tidak memasukkan harga kandang/alat, pertumbuhan kasih sayang,
hari sakit/lapar, atau mesin. Bebek sebelumnya menghasilkan 35 G/hari;
domba sekitar 63 G/hari. Kualitas dan ukuran besar tetap memberi premi sesuai
kasih sayang; produk olahan mayones bebek/kain mengikuti peningkatan tersebut.

## Mesin pengolah dan biaya upgrade

Mayones/keju/kain mempertahankan kenaikan sekitar 50% atas produk ternak.
Selai, acar, dan buah kering memberi sekitar 80–90% tambahan atas bahan:
stroberi 33 → selai 60 G; blueberry 43 → selai 80 G; anggur 38 → kismis
70 G; apel 160 → buah kering 290 G. Biaya pembelian/crafting mesin dan
durasi proses tidak diubah. Audit memastikan semua resep preserves/dehydrator
lebih bernilai dari bahannya dan tidak melebihi dua kali nilai bahan.

| Tier hasil upgrade | Biaya |
|---|---:|
| Tembaga | 500 G |
| Besi | 1.200 G |
| Emas | 2.500 G |
| Platinum | 4.500 G |
| Crimson | 7.000 G |
| Frost | 10.000 G |
| Shadow | 14.000 G |
| Fairy | 20.000 G |
| Obsidian | 28.000 G |

Bahan tetap 5 batangan logam; tembaga juga membutuhkan 10 kayu dan besi 15
kayu. Lama pengerjaan tetap dua pergantian hari, satu pesanan per pemain.
Quote resource dan fallback diselaraskan untuk seluruh 7 jenis alat.

## Save dan verifikasi

Format save tidak berubah. Pesanan yang sudah dibayar dan harga shipping yang
sudah dikunci tidak dihitung ulang. Harga baru berlaku untuk transaksi berikutnya;
jumlah hasil baru berlaku saat panen berikutnya. Stamina stat alat berasal dari
resource terbaru saat permainan dimuat.

Tes `economy_balance_regression` memeriksa 39 margin tanaman, modal panen awal,
rutinitas stamina, durasi hari, margin ternak, resep olahan, dan konsistensi quote
63 upgrade. Regresi crop, tools, gameplay, ternak, struktur/mesin, dan UI layanan
juga lulus pada run balancing ini. Bukti lokal: `scratch/economy-balance-audit.log`
dan `scratch/balance-verification.log`.
