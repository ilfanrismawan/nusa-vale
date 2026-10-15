# Core loop peternakan — implementasi

Status: terpasang, 13 Oktober 2026. Desain utama: `GDD.md`, bagian 2 dan 4.10.

## Mulai bermain

1. Temui Pak Damar di kota untuk membangun Kandang Ayam, Kandang Ternak, atau Silo. Bangunan dan mesin juga tersedia melalui crafting.
2. Temui Rian, Penjual Ternak di kota. Beli ayam/bebek/sapi/kambing/domba melalui Toko Ternak, pilih kandang tujuan, lalu beri nama. Pembelian memeriksa kapasitas dan uang sebelum transaksi. Klik kanan pintu kandang untuk masuk.
3. Beli Jerami, Pemeras Susu, Gunting Wol, Sikat Ternak, dan Bibit Rumput Pakan di General Store. Peralatan harus berada di tas pemain yang melakukan aksi.
4. Setiap hari: ambil hasil siap, beri satu jatah pakan, elus, sikat ternak besar, dan bersihkan kandang. Tombol pakan semua menggunakan tas pemain tersebut.
5. Jual hasil langsung di toko atau kirim melalui Shipping Bin; buat Mesin Mayones, Mesin Keju, atau Alat Tenun untuk menambah nilai hasil.

## Perawatan dan produksi

| Hewan | Harga | Kandang | Hasil | Interval hari terawat | Alat |
|---|---:|---|---|---:|---|
| Ayam putih/cokelat | 800 G | Unggas | Telur ayam | 1 | Ambil telur di kandang |
| Bebek | 1.400 G | Unggas | Telur bebek | 2 | Ambil telur di kandang |
| Sapi | 2.500 G | Ternak | Susu sapi | 1 | Pemeras Susu |
| Kambing | 3.200 G | Ternak | Susu kambing | 2 | Pemeras Susu |
| Domba | 3.000 G | Ternak | Wol | 3 | Gunting Wol |

Hari terawat adalah hari hewan makan dan tidak sakit. Hasil dibuat pada pergantian hari; memberi pakan tidak memberi produk seketika. Hari lapar tidak menambah kemajuan produksi. Susu/wol menyimpan satu hasil siap per hewan dan menunggu dipanen sebelum produksi berikutnya. Telur tersimpan sampai total 999, kemudian produksi berhenti sampai stok diambil.

Mengelus memberi +3 kasih sayang sekali sehari, menyikat +1, makan +2 pada pergantian hari, dan lapar −3. Nilai dibatasi 0–100. Kualitas Normal/Perak/Emas terbuka pada 0/40/80 poin; ukuran Besar pada 60 poin. Pengali harga kualitas 1/1,25/1,5; ukuran Besar memberi pengali tambahan 1,25. Kualitas dikunci saat produksi, bukan saat diambil.

Kandang berisi hewan menambah satu titik kotor setiap pagi, maksimum tiga. Tiap aksi membersihkan menghapus satu titik dan memakai 1 stamina. Tiga titik kotor membatasi hasil ke Normal. Dua evaluasi berturut-turut lapar atau kandang penuh kotor membuat hewan kurang sehat dan berhenti produksi. Satu hari penuh makan dengan kandang bersih memulihkan kondisi; produksi dilanjutkan setelah pemulihan. Hewan tidak mati atau hilang. Panen susu/wol memakai 1 stamina hanya jika berhasil.

## Merumput dan cadangan

Bibit Rumput Pakan dipasang dari hotbar pada tanah kosong dekat kandang. Satu petak memberi satu jatah dan tumbuh kembali setelah dua hari. Buka pintu saat cerah, pukul 06:00–18:00, di luar musim dingin. Hewan keluar, berjalan menuju rumput yang dapat dicapai, dan baru kenyang setelah tiba. Tanpa rumput, pemain perlu menyediakan pakan. Hewan kembali aman saat pintu ditutup, pukul 18:00, cuaca hujan, atau hari berganti.

Interaksi langsung dengan hewan di luar: panen jika siap, kemudian elus, pakan bila lapar, dan sikat bila diperlukan. Papan pengelolaan di interior menyediakan seluruh aksi secara individual.

Setiap kandang menyimpan sampai 240 jerami; tombol simpan/ambil memindahkan sampai 10 jatah. Silo menyimpan 240 jerami dan otomatis menerima satu jerami dari rumput liar **ladang** yang ditebas, tanpa mengganti peluang drop Serat. Saat silo penuh, pemain masih bisa membeli jerami. Rumput pakan adalah petak terpisah, bukan rumput liar.

Upgrade kandang mempertahankan lokasi dan tapak awal: 4 → 8 → 12 hewan. Upgrade pertama memakai 4.000 G + 150 kayu + 100 batu; kedua 8.000 G + 250 kayu + 150 batu. Deluxe memberi pakan otomatis pada pagi hari dari cadangan kandang, lalu silo, sebatas stok. Elusan, sikat, kebersihan, dan panen tetap dilakukan pemain.

## Pengolahan

Mesin Mayones menerima telur ayam/bebek; Mesin Keju menerima susu sapi/kambing; Alat Tenun menerima wol. Satu bahan menjadi satu produk dalam 20 detik permainan aktif. Ukuran dan kualitas dipertahankan; harga olahan sekitar 50% lebih tinggi dengan pembulatan harga item. Proses dan hasil ikut save/load. Tas penuh mempertahankan hasil mesin.

## Save dan co-op

Hewan, kebutuhan, kasih sayang, kemajuan produksi, hasil siap, kualitas, kotoran, pintu, stok jerami, dan waktu tumbuh rumput tersimpan. Save ayam lama diterima tanpa kehilangan nama, kasih sayang, atau telur. Hewan dan stok bersifat bersama; pakan, alat, stamina, serta hasil panen memakai data pemain pelaku. Aksi harian dan produksi tidak berulang karena reload atau interaksi pemain lain. Lompatan hari mengevaluasi konsumsi cadangan setiap hari secara berurutan.

Kandang berisi hewan/produk/jerami dan silo berisi jerami tidak bisa dikemas. Rumput yang baru dimakan tidak bisa dikemas sampai tumbuh kembali.

## Aset dan batas cakupan

Sprite hewan, bangunan, upgrade kandang, silo, jerami, produk, Mesin Keju, Alat Tenun, dan bingkai UI menggunakan Farm RPG Tiny Asset Pack milik pengguna. Ikon Pemeras Susu, Gunting Wol, Sikat Ternak, Rumput Pakan, serta sprite Mesin Mayones dibuat sebagai SVG piksel di `assets/ranch`.

Interior kandang kini bisa dimasuki: klik kanan di depan pintu. Keluar juga melalui klik kanan pintu interior. Hewan, palung, titik kotor, sarang telur, dan papan pengelolaan dapat diinteraksikan langsung. Pembelian hewan dilakukan melalui Toko Ternak Rian di kota. Panduan dan referensi desain: [RANCH_INTERIORS.md](RANCH_INTERIORS.md). Kuda, kerbau, kapibara, pembiakan, inkubasi, bulu bebek, festival, serta layanan kesehatan berbayar masih pengembangan lanjutan.

## Verifikasi

`tests/ranch_regression.tscn` menguji perawatan, interval, kualitas, kesehatan, co-op, kapasitas, auto-feeder, migrasi dan mesin olahan. `tests/ranch_world_regression.tscn` menguji pembangunan di ladang sebenarnya, hewan berjalan ke rumput, pintu, menu, dan panen melalui UI. Keduanya masuk `tools/verify_mvp.ps1`; save pengujian memakai APPDATA terisolasi.

Hasil verifikasi 13 Oktober 2026: regresi ayam, ranch, ranch di ladang, interior, pintu/Toko Ternak, audit mesin, audit save, co-op, placement, dan NPC lulus dengan `failures=0`. Render menu/hewan diperiksa pada `scratch/ranch-barn-menu.png`, `scratch/ranch-farm.png`, `scratch/barn-interior.png`, dan `scratch/coop-interior.png`. Pemeriksaan struktur pernah lulus pada fondasi sebelumnya, tetapi pengulangan terakhir timeout sebelum pemeriksaan pertama sehingga belum terverifikasi ulang.

Suite keseluruhan belum bersih: `greenhouse_regression` timeout dan `balai_wings_regression` gagal pada akses Balai Nadi. Kedua tes masih merujuk `Farm/BalaiNadiAccess`, sedangkan node tersebut tidak ada pada scene Farm saat verifikasi. Scene Farm dan alur restorasi tersebut tidak diubah oleh implementasi peternakan.

Untuk menjalankan pemeriksaan peternakan secara khusus:

```powershell
./tools/verify_mvp.ps1 -Scenes @('tests/chicken_regression.tscn', 'tests/ranch_regression.tscn', 'tests/ranch_world_regression.tscn', 'tests/save_regression.tscn')
```
