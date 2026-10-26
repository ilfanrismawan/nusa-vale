# Dapur Nusantara — toko peralatan masak

## Scene dan akses

- Interior: `scenes/world/interior/cookware_shop.tscn`.
- Pintu toko ada di kota, bangunan beratap jingga pada posisi (273, 534), dengan papan **Alat Masak**. Toko umum lama tidak diganti.
- Rumah memiliki pintu **Dapur** pada (360, 155), di sisi kanan jalur atas meja. Setelah renovasi, pintu ini menuju `scenes/world/interior/home_kitchen.tscn`.
- Pintu keluar toko memakai return marker kota milik pemain yang masuk; mendukung perpindahan solo/co-op yang sudah ada.

## Layout yang bisa diedit

Referensi utama adalah `assets/cooking/referensi toko jual peralatan masak.png` (1536 × 1024), bukan referensi alternatif kedua. Semua posisi layout memakai koordinat ilustrasi ini dalam node Showroom dengan skala 0.25, agar proporsi pemain sesuai dengan furniture.

- Showroom/Floor: potongan lantai berulang, bukan satu screenshot ruangan.
- Showroom/Fixtures: 31 node Sprite2D terpisah untuk empat display kitchen set di dinding belakang, rak sisi kiri/kanan, dua rak tengah, kasir, dekorasi (termasuk empat barang pajangan `Sprite2D`–`Sprite2D4`), karpet, dan tangga.
- Jendela dan karpet mengambil potongan dari tileset toko yang disediakan. Fixture rak berisi barang dan kitchen set memakai potongan AtlasTexture dari ilustrasi referensi agar ilustrasi serta susunannya tetap sama. Isi barang yang sudah tergambar di suatu rak adalah bagian tekstur fixture tersebut; untuk mengubah tiap barang secara terpisah, ganti tekstur rak dengan rak kosong tileset lalu tambahkan Sprite2D barang sendiri.
- Tidak ada screenshot penuh sebagai background. Floor, wall backing, furniture, collision, kamera, pemain, trigger kasir dan pintu adalah node tersendiri.
- Texture/region bisa diubah melalui resource `resources/cooking/shop/art/*.tres`; tidak perlu mengubah kode untuk memindahkan atau mengganti sprite.
- Posisi Sprite2D fixture berada di kaki objek untuk Y-sort, dengan offset negatif tinggi tekstur. Pindahkan node untuk menggeser furniture; sesuaikan CollisionShape2D terkait di Showroom/Obstacles.
- Semua collision dinding/rak/kasir dibuat di scene. Kamera tetap ShowroomCamera menjaga komposisi referensi; ukuran/zoom bisa diubah di Inspector.

## Katalog, harga, dan persyaratan

Master resource: `resources/cooking/shop/cooking_shop.tres`.

Terdapat 27 penawaran: 1 renovasi rumah, 22 alat dari katalog cooking, dan 4 kitchen set (kayu, putih, hitam, pink).

Setiap `resources/cooking/shop/offers/*.tres` menyediakan:

- price: harga yang bisa diedit (default renovasi 5000 G, kitchen set 7500 G, alat memakai harga resource/default 1000 G).
- materials: bahan renovasi opsional berdasarkan item ID dan jumlah (default kosong).
- required_flags: persyaratan progres, default alat/set memerlukan `house_kitchen_upgraded`.
- owned_flag: status kepemilikan satu kali.
- grants_flags: flag tambahan saat dibeli; kitchen set juga memasang kompor.
- equipment: resource alat yang benar-benar digunakan untuk requirement resep.
- kitchen_scene: scene furniture yang bisa dibuka/diedit.
- selection_group: kitchen set satu grup hanya memiliki satu warna aktif; warna yang telah dimiliki dapat dipasang ulang gratis.

Renovasi selesai langsung saat dibayar. Pembelian alat adalah instalasi permanen pada dapur rumah, bukan item tambahan di tas. Kepemilikan dibagi oleh semua penghuni rumah/co-op dan tidak hilang saat alat dipakai. Tas tidak diperlukan untuk menampung instalasi. Uang bersama dan bahan pemain pembeli tetap memakai sistem yang ada.

## Dapur rumah dan penyimpanan

KitchenStation di home_kitchen memakai `household_kitchen_station.gd` dan membaca alat yang telah dimiliki dari katalog toko. Berbeda dengan dapur warung/galleri, dapur rumah tidak diberi semua alat secara otomatis. RecipeData.required_equipment tetap wajib terpenuhi.

Empat scene kitchen set diinstansiasikan secara native di home_kitchen, dengan visibility berdasarkan flag warna aktif. Jika menambah varian baru, tambahkan offer dan node varian di scene, lalu hubungkan flag aktif yang sesuai melalui Inspector.

Kepemilikan, renovasi, dan varian aktif memakai WorldState flags yang sudah ikut save/load. Save lama tanpa flag tersebut tetap terkunci; New Game mereset progres ini. Tidak ada autosave baru saat belanja: gunakan mekanisme simpan game biasa.

## Validasi

Dengan APPDATA terisolasi dan `NUSA_SAVE_AUDIT=1`, jalankan `tests/cookware_shop_regression.tscn` secara headless untuk mengecek lock renovasi, transaksi satu kali, katalog lengkap, pergantian kitchen set, save/load flag, dapur rumah, counter UI, serta collision/posisi rak.

Untuk render native, gunakan renderer grafis dan `NUSA_SHOP_SCREENSHOT=1`. Hasil: `scratch/cookware-shop-preview.png`.
