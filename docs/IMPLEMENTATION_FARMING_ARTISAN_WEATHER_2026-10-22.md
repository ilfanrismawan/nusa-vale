# Implementasi Farming, Kualitas, Pohon Buah, Artisan dan Cuaca Badai

Tanggal: 22 Oktober 2026. Acuan: GDD v3.28.
Ruang lingkup: Pelengkap loop utama farming/produksi serta penutup loop ekonomi artisan & cuaca.

## Hasil Implementasi

| Fitur | Status & Implementasi |
|---|---|
| **Kualitas Panen & Forage** | Mendukung kualitas Normal, Bintang Perak (Silver, 1.25× nilai jual), dan Bintang Emas (Gold, 1.5× nilai jual). Peluang panen ditentukan oleh level Farmer dan perk Lv8 ("Bintang Perak") & Lv9 ("Bintang Emas"). Forage liar juga memiliki peluang menghasilkan kualitas Perak (Lv5+) dan Emas (Lv8+). `GameState._resolve_item` menangani varian `*_silver` dan `*_gold` secara dinamis dengan caching dan perhitungan harga otomatis. |
| **Pohon Buah Permanen Lintas Musim** | Apel, Jeruk, Ceri, Persik, Pisang, Aprikot, dan Mangga diidentifikasi sebagai pohon buah permanen (`CropData.is_fruit_tree()`). Saat dipanen, pohon buah tidak dicabut dari tanah melainkan kembali ke tahap sebelum panen (siap berbuah kembali). Pohon buah tidak layu saat pergantian musim. Di luar musim berbuah, pohon tetap hidup tanpa berbuah kecuali perk Master Farmer Lv10 A ("Perpetual Orchard") aktif atau ditanam di Greenhouse. |
| **Mesin Artisan: Tong Fermentasi (Keg)** | Mengolah komoditas pertanian menjadi produk fermentasi bernilai tinggi: Gandum $\rightarrow$ Bir Olahan (`beer`), Buah/Anggur $\rightarrow$ Anggur (`wine`) atau Jus Olahan (`juice`), Madu $\rightarrow$ Madu Fermentasi (`mead`). Kualitas bahan dipertahankan. |
| **Mesin Artisan: Pembuat Minyak (Oil Maker)** | Memeras bahan mentah menjadi minyak masak dan minyak aroma mewah: Jagung / Bunga Matahari $\rightarrow$ Minyak Masak (`oil`), Bawang Putih $\rightarrow$ Minyak Bawang (`garlic_oil`), Truffle $\rightarrow$ Minyak Truffle (`truffle_oil`). |
| **Mesin Artisan: Pengasap Ikan (Fish Smoker)** | Mengolah berbagai ikan mentah air tawar maupun laut menjadi Ikan Asap (`smoked_fish`). Bernilai jual 2× lipat dari harga dasar ikan dan memulihkan stamina tinggi (+55 stamina, +30 HP). Kualitas ikan dipertahankan. |
| **Cuaca Badai Petir (Thunderstorm / Heavy Storm)** | Status cuaca baru `"storm"` (`DailyWeather.STATES`). Menghasilkan hujan lebat dengan kilat petir prosedural pada layar dunia luar, secara otomatis menyiram seluruh petak ladang luar ruangan seperti cuaca hujan. |
| **Penangkal Petir (Lightning Rod) & Battery Pack** | Mesin/struktur penangkal petir yang dapat dirakit di crafting workbench (`Recipe_lightning_rod`). Saat terjadi Badai Petir (`storm`), penangkal petir menyerap sambaran listrik dan menghasilkan `battery_pack` siap panen keesokan paginya. |

## Resep Crafting Baru di Katalog

- **Tong Fermentasi (Keg)**: 30 Kayu, 2 Batang Tembaga, 1 Batang Besi
- **Pembuat Minyak (Oil Maker)**: 25 Kayu, 20 Batu, 2 Batang Besi
- **Pengasap Ikan (Fish Smoker)**: 30 Kayu, 5 Batubara, 1 Batang Besi
- **Penangkal Petir (Lightning Rod)**: 10 Batu, 1 Batang Tembaga, 2 Batang Besi

## Verifikasi Otomatis

Suite pengujian khusus `tests/artisan_production_regression.tscn` telah ditambahkan ke runner `tools/verify_mvp.ps1` dan lulus dengan 0 kegagalan:
1. `Test 1: Dynamic Quality Resolution & Pricing` - Normal, Silver (1.25×), Gold (1.5×) lulus.
2. `Test 2: Permanent Fruit Trees & Seasonal Resistance` - Panen tidak menghapus pohon, regrow stage terjaga, pergantian musim ke musim dingin tidak membuat pohon layu.
3. `Test 3: Artisan Machines` - Registrasi IDS, output resep keg/oil/smoker, proses aktif 20 detik, dan klaim hasil ke tas pemain lulus.
4. `Test 4: Lightning Rod & Badai Petir` - Validasi enum storm, auto-watering check, penyerapan petir badai, dan produksi battery pack lulus.
5. Regresi Cuaca (`tests/weather_regression.tscn`) dan Save/Role tetap lulus tanpa regresi.
