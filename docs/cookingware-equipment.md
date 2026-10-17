# Cookingware set: peralatan dan requirements resep

Aset asli `Downloads/cookingware set.png` disalin tanpa mengubah gambarnya ke `assets/cooking/cookingware_set.png`. Dua puluh objek diambil melalui resource AtlasTexture terpisah; tidak ada pemotongan gambar permanen atau pembuatan sprite lewat kode runtime.

## Daftar objek dari gambar baru

| ID | Nama | Peran | Resource gambar |
| --- | --- | --- | --- |
| `chef_knife` | Pisau Koki | Peralatan resep | `resources/cooking/icons/cookware_chef_knife.tres` |
| `seasoning_set` | Set Bumbu | Peralatan resep | `resources/cooking/icons/cookware_seasoning_set.tres` |
| `kitchen_blender` | Blender | Peralatan resep | `resources/cooking/icons/cookware_kitchen_blender.tres` |
| `cooking_grill` | Panggangan | Peralatan resep | `resources/cooking/icons/cookware_cooking_grill.tres` |
| `ceramic_bowl` | Mangkuk Keramik | Peralatan resep | `resources/cooking/icons/cookware_ceramic_bowl.tres` |
| `kitchen_pot` | Panci | Peralatan resep | `resources/cooking/icons/cookware_kitchen_pot.tres` |
| `frying_pan` | Wajan Datar | Peralatan resep | `resources/cooking/icons/cookware_frying_pan.tres` |
| `cooking_wok` | Wajan Goreng | Peralatan resep | `resources/cooking/icons/cookware_cooking_wok.tres` |
| `cooking_oven` | Oven | Peralatan resep | `resources/cooking/icons/cookware_cooking_oven.tres` |
| `rice_cooker` | Penanak Nasi | Peralatan resep | `resources/cooking/icons/cookware_rice_cooker.tres` |
| `kitchen_kettle` | Ketel | Peralatan resep | `resources/cooking/icons/cookware_kitchen_kettle.tres` |
| `kitchen_toaster` | Pemanggang Roti | Peralatan resep | `resources/cooking/icons/cookware_kitchen_toaster.tres` |
| `mortar_pestle` | Cobek dan Ulekan | Peralatan resep | `resources/cooking/icons/cookware_mortar_pestle.tres` |
| `cutting_board` | Talenan | Peralatan resep | `resources/cooking/icons/cookware_cutting_board.tres` |
| `kitchen_cleaver` | Pisau Daging | Peralatan resep | `resources/cooking/icons/cookware_kitchen_cleaver.tres` |
| `kitchen_utensils` | Set Spatula dan Sendok | Peralatan resep | `resources/cooking/icons/cookware_kitchen_utensils.tres` |
| `kitchen_steamer` | Kukusan | Peralatan resep | `resources/cooking/icons/cookware_kitchen_steamer.tres` |
| `baking_tray` | Loyang | Peralatan resep | `resources/cooking/icons/cookware_baking_tray.tres` |
| `dish_rack` | Rak Piring | Dekorasi, bukan syarat resep | `resources/cooking/icons/cookware_dish_rack.tres` |
| `cooking_stove` | Kompor | Peralatan resep | `resources/cooking/icons/cookware_cooking_stove.tres` |

Sembilan belas alat dari sheet berfungsi sebagai requirements. Meja persiapan, pengaduk mentega, dan tong fermentasi lama tetap tersedia, sehingga katalog sekarang berisi 22 peralatan fungsional. Rak piring baru adalah dekorasi; tidak memberikan storage inventory. Galeri memuat 27 objek baru/lama, termasuk bak cuci, lemari es, piring, dan sendok madu.

## Mengedit di Godot

- Buka `resources/cooking/data/cooking_catalog.tres` untuk daftar alat dan scene. Semua alat memiliki ItemData di `resources/item_data` dan data fungsional di `resources/cooking/equipment`.
- Buka `scenes/objects/cooking/cooking_equipment_gallery.tscn` untuk pratinjau seluruh objek. Drag scene alat ke world untuk menempatkannya dari editor.
- Ubah Atlas/Region pada AtlasTexture `resources/cooking/icons/cookware_*.tres` untuk mengganti gambar/crop. Ikon inventory dan texture world memakai resource bersama ini; Make Unique bila ingin mengubah satu penggunaan saja.
- Ubah `Sprite2D.scale` dan `position` pada scene alat untuk mengatur ukuran world. Sprite dinormalisasi sekitar 32 piksel world agar cocok dengan skala game; ukuran AtlasTexture sumber tidak diperkecil.
- Ubah `CookingEquipmentData.icon` bila ingin ikon UI berbeda dengan gambar world. Field kosong memakai `item.icon`.
- Edit array `RecipeData.required_equipment` pada masing-masing resep untuk mengubah syarat alat. Semua alat pada array wajib tersedia. Resep otomatis dapat ditampilkan pada menu alat yang tercantum di requirements; recipe_tags tetap tersedia untuk kategori tambahan.
- Edit `KitchenStation.installed_equipment` untuk mengatur fasilitas dapur. Dapur Warung awal menyediakan 22 alat katalog. Daftar ini adalah fasilitas yang dipasang oleh pembuat level, bukan hasil pencarian otomatis objek tetangga atau tas pemain.
- Gunakan Debug Cooking untuk menonaktifkan alat lalu menguji penolakan memasak. Katalog cheat otomatis mengikuti daftar alat baru.

Alat dan rak tetap ditempatkan melalui editor; belum ditambahkan pembelian, konstruksi dari inventory, animasi penggunaan, atau timer peralatan baru.

## Requirements per resep

Pengelompokan ini adalah konfigurasi awal yang bisa disesuaikan lewat Inspector. Mesin memasak hanya membaca resource; tidak memilih alat berdasarkan nama/ID makanan dalam kode runtime.

| Resep | Semua alat wajib |
| --- | --- |
| `anguilla_fritta` | `cooking_wok` + `cooking_stove` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `apple_pie` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `chef_knife` + `cutting_board` + `seasoning_set` |
| `apple_slices` | `chef_knife` + `cutting_board` |
| `artichoke_dip` | `cooking_stove` + `frying_pan` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `avocado_toast` | `kitchen_toaster` + `chef_knife` + `cutting_board` |
| `baked_fish` | `cooking_oven` + `baking_tray` + `chef_knife` + `cutting_board` |
| `baked_potato` | `cooking_oven` + `baking_tray` |
| `baked_sweet_potato` | `cooking_oven` + `baking_tray` |
| `banana_bread` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `banana_pudding` | `kitchen_pot` + `cooking_stove` + `ceramic_bowl` + `kitchen_utensils` + `chef_knife` + `cutting_board` + `seasoning_set` |
| `bean_hotpot` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `berry_sorbet` | `kitchen_blender` + `ceramic_bowl` + `seasoning_set` |
| `blackberry_cobbler` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `seasoning_set` |
| `blueberry_muffin` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` |
| `blueberry_tart` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` |
| `boba_tea` | `kitchen_pot` + `cooking_stove` + `ceramic_bowl` + `kitchen_utensils` + `seasoning_set` |
| `boiled_egg` | `kitchen_pot` + `cooking_stove` |
| `bread` | `cooking_oven` + `baking_tray` |
| `bread_roll` | `cooking_oven` + `baking_tray` |
| `bruschetta` | `kitchen_toaster` + `chef_knife` + `cutting_board` + `ceramic_bowl` + `kitchen_utensils` |
| `butter` | `butter_churn` + `ceramic_bowl` |
| `cake` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `seasoning_set` |
| `cappuccino_cake` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `seasoning_set` |
| `caramel_custard` | `kitchen_steamer` + `kitchen_pot` + `cooking_stove` + `ceramic_bowl` + `seasoning_set` |
| `carrot_cake` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `chef_knife` + `cutting_board` + `seasoning_set` |
| `cassava_cake` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `chef_knife` + `cutting_board` + `seasoning_set` |
| `casserole` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `kitchen_cleaver` + `cutting_board` |
| `chamomile_tea` | `kitchen_kettle` + `cooking_stove` |
| `chocolate_cake` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `seasoning_set` |
| `chocolate_popcorn` | `kitchen_pot` + `cooking_stove` + `kitchen_utensils` |
| `christmas_cookies` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `seasoning_set` |
| `christmas_pudding` | `kitchen_steamer` + `kitchen_pot` + `cooking_stove` + `ceramic_bowl` + `seasoning_set` |
| `cioppino` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `coffee` | `mortar_pestle` + `kitchen_kettle` + `cooking_stove` |
| `coleslaw` | `chef_knife` + `cutting_board` + `ceramic_bowl` + `kitchen_utensils` |
| `complete_breakfast` | `frying_pan` + `cooking_stove` + `kitchen_toaster` + `kitchen_utensils` |
| `cookies` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `seasoning_set` |
| `corn_on_cob` | `kitchen_pot` + `cooking_stove` |
| `cotton_candy` | `kitchen_pot` + `cooking_stove` + `kitchen_utensils` + `seasoning_set` |
| `crab_cakes` | `cooking_wok` + `cooking_stove` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `cranberry_sauce` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `seasoning_set` |
| `cream` | `butter_churn` + `ceramic_bowl` |
| `croissant` | `cooking_oven` + `baking_tray` + `prep_counter` + `kitchen_utensils` |
| `cucumber_salad` | `chef_knife` + `cutting_board` + `ceramic_bowl` + `kitchen_utensils` |
| `cupcake` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `seasoning_set` |
| `donut` | `cooking_wok` + `cooking_stove` + `kitchen_utensils` + `seasoning_set` |
| `dough` | `prep_counter` + `ceramic_bowl` + `kitchen_utensils` |
| `eggplant_parmigiana` | `cooking_oven` + `baking_tray` + `chef_knife` + `cutting_board` |
| `escargot` | `cooking_stove` + `frying_pan` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `espresso` | `mortar_pestle` + `kitchen_kettle` + `cooking_stove` |
| `farofa` | `frying_pan` + `cooking_stove` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `fiddlehead_risotto` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `fish_stew` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `fish_tacos` | `frying_pan` + `cooking_stove` + `chef_knife` + `cutting_board` + `kitchen_utensils` |
| `flour` | `mortar_pestle` |
| `french_fries` | `cooking_wok` + `cooking_stove` + `kitchen_utensils` + `seasoning_set` |
| `fried_calamari` | `cooking_wok` + `cooking_stove` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `fried_egg` | `frying_pan` + `cooking_stove` + `kitchen_utensils` |
| `fruit_salad` | `chef_knife` + `cutting_board` + `ceramic_bowl` + `kitchen_utensils` |
| `fruit_tea` | `kitchen_kettle` + `cooking_stove` + `chef_knife` + `cutting_board` |
| `garlic_oil` | `kitchen_pot` + `cooking_stove` + `chef_knife` + `cutting_board` |
| `gingerbread_house` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `seasoning_set` |
| `glazed_yams` | `frying_pan` + `cooking_stove` + `kitchen_utensils` |
| `green_tea` | `kitchen_kettle` + `cooking_stove` |
| `grilled_catfish` | `cooking_grill` + `chef_knife` + `cutting_board` |
| `hamburger` | `cooking_grill` + `kitchen_cleaver` + `cutting_board` + `kitchen_utensils` |
| `hash_browns` | `frying_pan` + `cooking_stove` + `kitchen_utensils` |
| `hawaiian_poi` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` |
| `ice_cream` | `kitchen_blender` + `ceramic_bowl` + `seasoning_set` |
| `ice_cream_sandwich` | `chef_knife` + `cutting_board` |
| `jam` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `seasoning_set` |
| `jasmine_tea` | `kitchen_kettle` + `cooking_stove` |
| `jawbreaker` | `kitchen_pot` + `cooking_stove` + `kitchen_utensils` + `seasoning_set` |
| `jelly` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `seasoning_set` |
| `juice` | `kitchen_blender` + `chef_knife` + `cutting_board` |
| `ketchup` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `chef_knife` + `cutting_board` + `seasoning_set` |
| `lavender_tea` | `kitchen_kettle` + `cooking_stove` |
| `lemon_tea` | `kitchen_kettle` + `cooking_stove` + `chef_knife` + `cutting_board` |
| `lobster_bisque` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `lollipop` | `kitchen_pot` + `cooking_stove` + `kitchen_utensils` + `seasoning_set` |
| `maki_sushi` | `rice_cooker` + `chef_knife` + `cutting_board` + `ceramic_bowl` |
| `mango_sticky_rice` | `kitchen_steamer` + `kitchen_pot` + `cooking_stove` + `ceramic_bowl` + `chef_knife` + `cutting_board` + `seasoning_set` |
| `maple_bar` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` |
| `matcha` | `mortar_pestle` + `kitchen_kettle` + `cooking_stove` + `ceramic_bowl` + `kitchen_utensils` |
| `milkshake` | `kitchen_blender` |
| `mushroom_saute` | `frying_pan` + `cooking_stove` + `kitchen_utensils` |
| `mustard` | `mortar_pestle` + `ceramic_bowl` + `kitchen_utensils` + `seasoning_set` |
| `nachos` | `cooking_oven` + `baking_tray` + `chef_knife` + `cutting_board` |
| `omelet` | `frying_pan` + `cooking_stove` + `kitchen_utensils` |
| `pancakes` | `frying_pan` + `cooking_stove` + `kitchen_utensils` |
| `panzanella_salad` | `chef_knife` + `cutting_board` + `ceramic_bowl` + `kitchen_utensils` |
| `paprika_powder` | `mortar_pestle` |
| `parsnip_soup` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `peanut_butter` | `kitchen_blender` |
| `pepper_popper` | `cooking_stove` + `frying_pan` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `pickles` | `fermentation_barrel` + `chef_knife` + `cutting_board` + `seasoning_set` |
| `pina_colada` | `kitchen_blender` + `chef_knife` + `cutting_board` |
| `pizza` | `cooking_oven` + `baking_tray` + `chef_knife` + `cutting_board` |
| `popcorn` | `kitchen_pot` + `cooking_stove` + `kitchen_utensils` |
| `popsicle` | `kitchen_blender` + `ceramic_bowl` + `seasoning_set` |
| `pretzel` | `cooking_oven` + `baking_tray` + `prep_counter` + `kitchen_utensils` + `seasoning_set` |
| `pumpkin_pie` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `chef_knife` + `cutting_board` + `seasoning_set` |
| `pumpkin_soup` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `quesadilla` | `frying_pan` + `cooking_stove` + `kitchen_utensils` |
| `rice_ball` | `rice_cooker` + `ceramic_bowl` + `seasoning_set` |
| `rice_bowl` | `rice_cooker` + `ceramic_bowl` |
| `rice_pudding` | `kitchen_pot` + `cooking_stove` + `ceramic_bowl` + `kitchen_utensils` + `seasoning_set` |
| `rock_candy` | `kitchen_pot` + `cooking_stove` + `kitchen_utensils` + `seasoning_set` |
| `salad` | `chef_knife` + `cutting_board` + `ceramic_bowl` + `kitchen_utensils` |
| `salted_peanuts` | `cooking_stove` + `frying_pan` + `kitchen_utensils` + `seasoning_set` |
| `sashimi` | `chef_knife` + `cutting_board` |
| `shoyu` | `fermentation_barrel` + `mortar_pestle` + `seasoning_set` |
| `shrimp_cocktail` | `kitchen_pot` + `cooking_stove` + `chef_knife` + `cutting_board` + `ceramic_bowl` |
| `smoothie` | `kitchen_blender` |
| `spaghetti` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `kitchen_cleaver` + `cutting_board` |
| `spice_tea` | `kitchen_kettle` + `cooking_stove` + `seasoning_set` |
| `spicy_tacos` | `frying_pan` + `cooking_stove` + `kitchen_cleaver` + `cutting_board` + `kitchen_utensils` |
| `stir_fry` | `cooking_wok` + `cooking_stove` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `strawberry_candy` | `kitchen_pot` + `cooking_stove` + `kitchen_utensils` + `seasoning_set` |
| `strawberry_matcha` | `kitchen_blender` |
| `strawberry_milkshake` | `kitchen_blender` |
| `strawberry_tart` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` |
| `stuffed_mushrooms` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `stuffed_peppers` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `kitchen_cleaver` + `cutting_board` |
| `sun_tea` | `kitchen_kettle` |
| `sweet_berry_cake` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `seasoning_set` |
| `toast` | `kitchen_toaster` + `kitchen_utensils` |
| `tom_kha_soup` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `kitchen_cleaver` + `cutting_board` |
| `tortilla` | `frying_pan` + `cooking_stove` + `kitchen_utensils` |
| `tropical_fruit_salad` | `chef_knife` + `cutting_board` + `ceramic_bowl` + `kitchen_utensils` |
| `tropical_shrimp` | `cooking_wok` + `cooking_stove` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `unagi_kabayaki` | `cooking_grill` + `chef_knife` + `cutting_board` + `seasoning_set` |
| `vanilla_cake` | `cooking_oven` + `baking_tray` + `ceramic_bowl` + `kitchen_utensils` + `seasoning_set` |
| `vegetable_mix` | `chef_knife` + `cutting_board` + `ceramic_bowl` + `kitchen_utensils` |
| `vegetable_stir_fry` | `cooking_wok` + `cooking_stove` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `vegetable_soup` | `cooking_stove` + `kitchen_pot` + `kitchen_utensils` + `chef_knife` + `cutting_board` |
| `yogurt` | `fermentation_barrel` + `ceramic_bowl` |

