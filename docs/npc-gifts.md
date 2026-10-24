# Daftar hadiah NPC

Seluruh daftar menggunakan item yang sudah tersedia di `resources/item_data/`, beserta ikon yang sudah terhubung ke assets. Tidak perlu membuat item baru untuk daftar ini. Selera disesuaikan dengan profesi dan karakter NPC.

## Lokasi pengaturan

- Seluruh 13 resident: `gift_tastes` dan `gift_dialogue` pada masing-masing JSON di `data/npc/`. Wira/Ubay/Eep tetap memakai nama file sebelumnya; si kembar tetap `npc_zarathia.json`/`npc_zarathustra.json`; delapan tambahan memakai `<id>.json`, termasuk `baskoro.json`.
- `data/npc/social/gift_profiles.json` kini kosong untuk kompatibilitas loader; jangan menambahkan salinan profil di sana. Pendaftaran aktif melalui `scenes/npc/npc_database.tscn` dan resource `*_resident.tres`. Lihat [laporan migrasi 24 Oktober](NPC_CENTRALIZATION_2026-10-24.md).
- Path file profil sosial dapat diubah lewat **Gift Profiles File** pada root `scenes/npc/npc_database.tscn`.
- Lima nama kategori yang dipakai: `loved`, `liked`, `neutral`, `disliked`, `hated`. Alias lama `love`, `like`, `dislike`, `hate` tetap diterima; gunakan satu gaya saja dalam satu profil.
- Satu ID item hanya boleh berada pada satu kategori per NPC. Item yang tidak tercantum tetap dianggap **neutral**. Daftar neutral disediakan untuk menegaskan pilihan yang bisa diedit.
- Poin dasar: loved +80, liked +45, neutral +20, disliked -20, hated -40. Bonus ulang tahun dan batas hadiah mengikuti sistem sosial yang sudah ada.

## Daftar item

Kolom menggunakan `item_id` agar dapat langsung disalin ke JSON.

| NPC | Love | Like | Neutral | Dislike | Hate |
| --- | --- | --- | --- | --- | --- |
| Eep | `complete_breakfast`, `carrot`, `cow_milk`, `chicken_egg` | `apple`, `hay`, `animal_feed`, `green_tea` | `bread`, `wood`, `stone`, `fiber` | `clay`, `coal`, `fish_bone_fish` | `slime_gel`, `old_bone`, `shadow_ore` |
| Zarathia | `sunflower`, `sweet_pea`, `cake`, `sweet_berry_cake` | `green_tea`, `chamomile_tea`, `lavender_tea`, `honey`, `banana_bread` | `apple`, `carrot`, `rice`, `bread` | `coal`, `iron_ore`, `stone` | `slime_gel`, `old_bone`, `worm` |
| Zarathustra | `banana_bread`, `banana_pudding`, `iron_bar`, `coffee` | `plank`, `wood`, `copper_bar`, `baked_potato` | `apple`, `carrot`, `stone`, `bread` | `sweet_pea`, `chamomile_tea`, `daffodil` | `slime_gel`, `old_bone`, `worm` |
| Ubay | `coffee`, `complete_breakfast`, `fruit_salad`, `rice_ball` | `apple`, `banana`, `orange`, `bread`, `green_tea` | `wood`, `stone`, `corn`, `cow_milk` | `clay`, `fiber`, `coal` | `slime_gel`, `old_bone`, `worm` |
| Wira | `plank`, `green_tea`, `spice_tea` | `wood`, `copper_bar`, `iron_bar`, `vegetable_soup`, `rice_ball` | `stone`, `fiber`, `carrot`, `apple` | `clay`, `coal`, `fish_carp` | `slime_gel`, `old_bone`, `worm` |
| Kirana | `sunflower`, `cake`, `strawberry` | `apple`, `honey`, `green_tea`, `sweet_pea` | `wood`, `stone`, `rice`, `bread` | `coal`, `clay`, `fiber` | `slime_gel`, `old_bone`, `worm` |
| Pak Bahar | `grilled_catfish`, `fish_red_snapper`, `fish_stew`, `spice_tea` | `rice_ball`, `baked_fish`, `fish_mas`, `bait`, `worm` | `bread`, `wood`, `stone`, `carrot` | `chili`, `pepper`, `espresso` | `slime_gel`, `old_bone`, `coal` |
| Pak Joko | `vegetable_soup`, `pumpkin_soup`, `complete_breakfast`, `cake` | `fish_mas`, `cow_milk`, `chicken_egg`, `flour`, `pepper` | `wood`, `apple`, `corn`, `rice` | `clay`, `fiber`, `stone` | `slime_gel`, `old_bone`, `worm` |
| dr. Ratih | `chamomile_tea`, `lavender_tea`, `vegetable_soup`, `aloe` | `daffodil`, `sweet_pea`, `honey`, `salad` | `apple`, `carrot`, `wood`, `rice` | `espresso`, `chili`, `coal` | `slime_gel`, `old_bone`, `worm` |
| Rian | `cow_milk`, `chicken_egg`, `cheese`, `complete_breakfast` | `hay`, `animal_feed`, `apple`, `carrot` | `wood`, `rice`, `bread`, `stone` | `coal`, `clay`, `fiber` | `slime_gel`, `old_bone`, `worm` |
| Pak Damar | `plank`, `iron_bar`, `complete_breakfast` | `wood`, `copper_bar`, `coffee`, `vegetable_soup` | `stone`, `rice`, `bread`, `apple` | `clay`, `fiber`, `fish_carp` | `slime_gel`, `old_bone`, `worm` |
| Empu Bima | `iron_bar`, `gold_bar`, `coffee` | `copper_bar`, `coal`, `iron_ore`, `baked_potato` | `wood`, `stone`, `rice`, `bread` | `daffodil`, `sweet_pea`, `clay` | `slime_gel`, `old_bone`, `worm` |

## Memberikan hadiah di game

1. Taruh item pada hotbar, lalu pilih slotnya.
2. Bicara dengan NPC. Pada NPC terjadwal, pilih **Bicara**. Pak Damar dan Empu Bima memiliki tombol **Bicara / Hadiah** pada menu layanan mereka; jika Bima membuka geoda lebih dahulu, lanjutkan ke menu upgrade alat.
3. Tekan tombol **Hadiah** pada dialog. Satu item diambil setelah seluruh pemeriksaan berhasil. Alat, perlengkapan, bangunan, senjata, dan Biji Daya tetap dilindungi.
4. Reaksi dan poin mengikuti NPC yang menerima hadiah; misalnya batubara disukai Bima tetapi tidak disukai Wira. Cacing disukai Pak Bahar sebagai umpan.

## Ikon

Resource item tetap menjadi sumber ikon untuk inventory dan tombol hadiah. Contoh sumber yang sudah ada:

- Teh Hijau: `assets/farm_rpg/icons/Food Icons/Green tea.png`.
- Roti Pisang: `assets/farm_rpg/icons/Food Icons/Banana Bread.png`.
- Kue: `assets/farm_rpg/icons/Food Icons/Cake.png`.
- Sweet Pea: `assets/farm_rpg/icons/Forage/sweet_pea.png` melalui `resources/icons/icon_sweet_pea.tres`.
- Daffodil: `assets/farm_rpg/icons/Forage/daffodil.png` melalui `resources/icons/icon_daffodil.tres`.
- Material logam memakai atlas ikon yang sudah direferensikan masing-masing ItemData.

Bahan mentah lavender dan kamomil yang belum mempunyai ikon tidak digunakan dalam daftar hadiah; teh lavender dan teh kamomil memakai ikon makanan yang sudah tersedia.

## Validasi

Jalankan `python tools/validate_npc_data.py`. Validator juga memeriksa kategori neutral, konflik antar kategori, item yang dilarang diberikan, serta adanya referensi ikon. Test runtime `tests/npc_gifts_regression.tscn` memuat setiap item dan ikon serta mencoba memberi hadiah untuk semua kategori pada 12 NPC, termasuk akses menu layanan.
