# Memasak dasar — 14 Oktober 2026

Bagian awal fase 4 sesuai bagian 6 GDD. Dapur Warung berada di town,
di sebelah timur lokasi awal Chef (936, 388). Dekati panci, arahkan pemain
ke panci, lalu klik kanan/Enter untuk membuka menu. UI memakai aset panel
dan tombol yang sudah dimiliki proyek.

| Masakan | Bahan per porsi | Stamina | Buku resep |
|---|---|---:|---:|
| Sup Sayur Bening | 1 wortel + 1 kubis | 35 | Gratis |
| Telur Goreng | 1 telur ayam | 20 | Gratis |
| Ikan Bakar Lele | 1 lele | 45 | 150 G |
| Salad Buah | 1 apel + 1 stroberi | 40 | 200 G |
| Tumis Jamur | 2 jamur biasa | 25 | 100 G |

Pilih makanan di hotbar, klik kiri/X untuk makan satu porsi. Stamina
dibatasi maksimum pemain; makanan tanpa buff tidak dikonsumsi saat stamina
penuh. Salad memberikan laju berjalan/berlari +15% selama 60 detik aktif,
dengan sisa durasi terlihat di HUD. Buff sejenis memperbarui durasi maksimum,
tidak menumpuk pengali. Buff berhenti selama pause dan berakhir saat reload.

Resep yang dibeli tersimpan per pemain; uang tetap milik bersama sesuai
ekonomi co-op. Save lama tanpa daftar resep tetap mendapat dua resep dasar.
Memasak menggunakan transaksi inventory bertahap: bahan dikurangi dan ruang
hasil diperiksa sebelum inventory asli diperbarui. Slot yang kosong karena
bahan habis dapat menampung hasil, dan tas penuh tidak kehilangan bahan.

Konfigurasi resep: `scripts/system/cooking_manager.gd`.
Data makanan: `resources/item_data/{vegetable_soup,fried_egg,grilled_catfish,
fruit_salad,mushroom_saute}.tres`. FOOD ditambahkan sebagai kategori 9,
tanpa mengubah nomor kategori lama.

Belum terpasang: dapur rumah melalui upgrade rumah, buku resep dari TV/hadiah
persahabatan, pemulihan HP dan buff combat/keberuntungan. Sistem HP/combat
dan sosial perlu dibangun sebelum integrasi tersebut. Resep berkualitas
susu/telur tidak otomatis menggantikan bahan normal pada tahap ini.

Tes `tests/cooking_regression.tscn` memeriksa transaksi, tas penuh, pemisahan
resep pemain, save/load, interaksi dapur town, konsumsi, stamina, dan buff.
