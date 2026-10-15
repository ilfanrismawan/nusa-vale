# Interior kandang yang bisa dimasuki

Status: terpasang, 13 Oktober 2026.

## Referensi dan arah desain

- [Stardew Valley — Barn](https://wiki.stardewvalley.net/Barn): palung, penyimpanan jerami, dan kapasitas bertahap 4/8/12. Di Nusa Vale, titik layanan dikelompokkan di bagian belakang agar pemain dapat melihat kebutuhan kandang saat masuk.
- [Harvest Moon 64 — Your Farm](https://shrines.rpgclassics.com/n64/hm64/farm.shtml): hewan memiliki tempat istirahat dan pemberian pakan yang mudah dikenali. Di Nusa Vale, empat petak per baris memberi lokasi awal yang jelas, tetapi hewan tetap bergerak kecil di dalam petaknya.

Interpretasi desain untuk Nusa Vale: kandang kayu yang hangat, lantai papan lebih terang daripada dinding, alas jerami, jendela dan lampu, serta lorong tengah lebar. Hewan tidak memblokir pemain. Palung, papan pengelolaan, dan cadangan dapat dicapai tanpa melewati hewan. Kandang unggas menambahkan sarang telur; kandang ternak besar memberi ruang untuk sapi, kambing, dan domba.

## Scene dan tata ruang

| Scene | Fungsi | Pembeda |
|---|---|---|
| `scenes/world/interior/barn_interior.tscn` | Sapi, kambing, domba | Petak istirahat dengan alas jerami; perah susu/cukur wol langsung pada hewan |
| `scenes/world/interior/coop_interior.tscn` | Ayam, bebek | Petak istirahat dan sarang; stasiun pengambilan telur |

Ukuran interior 22 × 14 petak (352 × 224 piksel dunia), dengan pintu di tengah sisi bawah. Kapasitas Dasar/Besar/Deluxe membuka satu/dua/tiga baris tempat istirahat, masing-masing empat hewan, tanpa memindahkan pintu atau mengubah tapak bangunan luar. Kamera solo memakai zoom awal 2,0 agar seluruh ruang terbaca pada viewport 854 × 480.

Bagian belakang: cadangan jerami di kiri, palung di tengah, dan papan pengelolaan di kanan. Dua kelompok petak berada di sisi kiri dan kanan; lorong tengah tetap terbuka. Titik kotor berada dekat lorong agar dapat dibersihkan dengan mudah. Wadah air merupakan dekorasi; tidak menambahkan kebutuhan hidrasi baru.

## Cara masuk dan berinteraksi

1. Bangun kandang melalui Pak Damar atau crafting, lalu klik kanan di depan pintunya.
2. Pemain langsung masuk; pintu tidak berpindah scene hanya karena disentuh. Tombol E/X dan gamepad tetap dapat digunakan sebagai alternatif interaksi.
3. Dekati hewan dan gunakan tombol interaksi yang biasa: panen bila siap, kemudian elus, pakan, atau sikat sesuai kebutuhan.
4. Interaksi palung memberi makan dari cadangan kandang; bila tidak ada cadangan, menggunakan pakan di tas pemain. Interaksi cadangan atau papan membuka pengelolaan kandang yang sama.
5. Interaksi titik kotor membersihkan satu titik. Sarang utama kandang unggas mengambil stok telur bersama.
6. Klik kanan di dekat pintu bawah untuk kembali ke ladang, tepat di luar bangunan yang dimasuki.

Saat pintu merumput dibuka, hewan terlihat di ladang dan tidak digandakan di dalam. Saat pintu ditutup atau hewan kembali otomatis, mereka kembali terlihat di interior. Semua aksi menggunakan data perawatan, produksi, alat, stamina, dan inventory yang sudah ada.

## Co-op dan identitas kandang

Setiap bangunan memakai UID yang stabil. Save/load mempertahankan UID meskipun urutannya tidak berurutan setelah bangunan lain dikemas. Co-op menggunakan kunci area `scene_path#ranch=UID`: pemain di kandang yang sama berbagi World2D; kandang berbeda memakai World2D berbeda. Perpindahan satu pemain tidak memindahkan pemain lain. Bangunan tidak dapat dikemas selama ada pemain di dalam, termasuk kandang kosong.

`ranch_interior.gd` membangun tile, dekorasi, bounds, hotspot, serta tampilan hewan pada runtime. Scene memakai parameter `housing` dan `ranch_uid`; tidak menyimpan salinan hewan terpisah pada berkas scene.

## Aset

Aset paket pengguna: `Barn tileset.png`, `Tileset House.png`, Hay Bales, jendela dan lampu Barn, sprite hewan, font, dan UI yang sudah ada. Tambahan SVG piksel di `assets/ranch`: `feeding_trough.svg`, `nesting_box.svg`, `care_board.svg`, dan `water_basin.svg`. Tambahan ini dibuat untuk melengkapi objek interaktif yang tidak tersedia sebagai aset terpisah dalam paket. Tidak mengambil aset visual dari game referensi.

## Verifikasi

`tests/ranch_interior_regression.tscn` menguji perpindahan solo masuk/keluar, pakan, elusan, kebersihan, panen susu/telur, save/load dengan UID tidak berurutan, co-op di kandang berbeda/sama, serta larangan mengemas kandang yang sedang ditempati pemain. Tangkapan render berada di `scratch/barn-interior.png` dan `scratch/coop-interior.png`.

```powershell
./tools/verify_mvp.ps1 -Scenes @('tests/ranch_interior_regression.tscn', 'tests/ranch_regression.tscn', 'tests/ranch_world_regression.tscn', 'tests/coop_smoke.tscn', 'tests/structure_regression.tscn', 'tests/save_regression.tscn')
```
