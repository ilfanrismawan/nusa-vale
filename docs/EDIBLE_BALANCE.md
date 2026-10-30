# Makanan mentah, forage, dan artisan (27 Oktober 2026)

Hasil panen, produk kebun, forage, telur/susu, dan barang artisan kini bisa dimakan (`ItemData.edible`). Masakan (kategori FOOD) tetap seperti sebelumnya.

## Cara makan

- **Klik kanan di dunia** sambil memegang makanan apa pun di hotbar, saat tidak ada objek interaksi di depan (forage/NPC/toko/mesin tetap didahulukan).
- **Klik kanan slot di tas** untuk makanan; untuk barang lain klik kanan tetap membuka dialog buang.
- **Klik kiri** tetap memakan masakan (FOOD). Untuk hasil panen dan artisan, klik kiri tetap dipakai memasukkan ke Shipping Bin dan mesin.
- Stamina penuh: makanan tanpa efek tambahan ditolak dan itemnya tidak berkurang.

## Efek makan

`FoodEating` (`scripts/system/food_eating.gd`), angka di `resources/feedback/eat.tres` (`EatFeedback`): pemain menghadap kamera, makanan diangkat ke mulut, digigit 3 kali (remah sewarna ikon dari `eat_crumbs.tres`, suara kunyah naik nada, tubuh mengangguk atau animasi `eat`), lalu ditelan dengan kilau dan teks `+N Stamina` / `+N HP` / nama efek. Input dikunci selama efek. Animasi karakter `eat_down` dipakai otomatis begitu sheet-nya ada di katalog karakter.

## Aturan nilai (`tools/rebalance_edible.py`)

- Dasar = `round(k × √harga_jual)`: panen/forage k=1.0 (4–14), telur/susu k=1.2 (6–15, varian ≤18), artisan k=1.5 (8–22, varian ≤26).
- Batas: maksimal 70% stamina barang jadi termurah yang dibuat dari item itu (resep masak, mesin artisan, preserves jar, dehydrator). Varian kualitas maksimal 85%.
- Tidak bisa dimakan: gandum, padi, bunga matahari, ikan dan daging mentah, bumbu/bahan dapur (garam, gula, tepung, minyak, kecap), bunga, holly, Biji Daya.
- HP = setengah stamina (aturan `hp_restore` bawaan).
- Jalankan ulang skrip setelah mengubah harga atau resep; nilai per item tetap bisa diubah manual di Inspector.

Tes: `tests/food_eating_regression.tscn`.

## Hasil panen & produk kebun

| Item | Harga jual | Stamina | Barang jadi termurah |
|---|---|---|---|
| apple | 160 | 12 | 18 |
| apricot | 85 | 9 | – |
| artichoke | 20 | 4 | 34 |
| asparagus | 15 | 4 | – |
| avocado | 20 | 4 | 26 |
| banana | 175 | 13 | 34 |
| beet | 65 | 8 | – |
| blackberry | 40 | 6 | 42 |
| blueberry | 43 | 7 | 13 |
| broccoli | 70 | 8 | 42 |
| cabbage | 70 | 8 | 34 |
| carrot | 60 | 8 | 34 |
| cauliflower | 145 | 12 | 42 |
| cherry | 75 | 9 | 45 |
| chili | 65 | 8 | 34 |
| coconut | 20 | 4 | 26 |
| corn | 135 | 12 | 18 |
| cranberry | 15 | 4 | 34 |
| cucumber | 60 | 8 | 16 |
| eggplant | 65 | 8 | 34 |
| garlic | 65 | 8 | 34 |
| grape | 38 | 6 | 13 |
| green_apple | 160 | 13 | – |
| green_coconut | 20 | 4 | – |
| green_pepper | 15 | 4 | 34 |
| leek | 55 | 7 | – |
| lemon | 15 | 4 | 26 |
| mango | 170 | 13 | 34 |
| melon | 150 | 12 | 45 |
| onion | 60 | 8 | 34 |
| orange | 160 | 13 | 26 |
| parsnip | 55 | 7 | 34 |
| pea | 30 | 5 | 34 |
| peach | 165 | 13 | 45 |
| peanut | 10 | 4 | 9 |
| pineapple | 170 | 13 | 26 |
| potato | 60 | 8 | 26 |
| pumpkin | 150 | 12 | 34 |
| red_pepper | 70 | 8 | – |
| rhubarb | 75 | 9 | – |
| strawberry | 33 | 6 | 12 |
| sweet_potato | 12 | 4 | 18 |
| tomato | 65 | 8 | 16 |
| watermelon | 160 | 13 | 26 |
| yellow_pepper | 70 | 8 | – |
| zucchini | 60 | 8 | – |

## Forage

| Item | Harga jual | Stamina | Barang jadi termurah |
|---|---|---|---|
| common_mushroom | 40 | 6 | 42 |
| hazelnut | 45 | 7 | – |
| mooncap | 180 | 13 | – |
| spring_onion | 8 | 4 | – |
| truffle | 250 | 14 | – |
| wild_berry | 15 | 4 | 34 |
| winter_root | 35 | 6 | – |

## Telur & susu

| Item | Harga jual | Stamina | Barang jadi termurah |
|---|---|---|---|
| buffalo_milk | 180 | 15 | 22 |
| buffalo_milk_gold | 270 | 18 | 22 |
| buffalo_milk_large | 225 | 17 | 22 |
| buffalo_milk_large_gold | 337 | 18 | 22 |
| buffalo_milk_large_silver | 281 | 18 | 22 |
| buffalo_milk_silver | 225 | 17 | 22 |
| chicken_egg | 50 | 8 | 13 |
| chicken_egg_gold | 75 | 10 | 13 |
| chicken_egg_large | 62 | 9 | 13 |
| chicken_egg_large_gold | 93 | 11 | 13 |
| chicken_egg_large_silver | 78 | 10 | 13 |
| chicken_egg_silver | 62 | 9 | 13 |
| cow_milk | 100 | 12 | 18 |
| cow_milk_gold | 150 | 15 | 18 |
| cow_milk_large | 125 | 14 | 18 |
| cow_milk_large_gold | 187 | 15 | 18 |
| cow_milk_large_silver | 156 | 15 | 18 |
| cow_milk_silver | 125 | 14 | 18 |
| duck_egg | 110 | 13 | 19 |
| duck_egg_gold | 165 | 16 | 19 |
| duck_egg_large | 137 | 15 | 19 |
| duck_egg_large_gold | 206 | 16 | 19 |
| duck_egg_large_silver | 171 | 16 | 19 |
| duck_egg_silver | 137 | 15 | 19 |
| goat_milk | 170 | 15 | 22 |
| goat_milk_gold | 255 | 18 | 22 |
| goat_milk_large | 212 | 17 | 22 |
| goat_milk_large_gold | 318 | 18 | 22 |
| goat_milk_large_silver | 265 | 18 | 22 |
| goat_milk_silver | 212 | 17 | 22 |
| ostrich_egg | 50 | 8 | – |

## Artisan

| Item | Harga jual | Stamina | Barang jadi termurah |
|---|---|---|---|
| blueberry_jam | 80 | 13 | – |
| buffalo_cheese | 270 | 22 | – |
| buffalo_cheese_gold | 405 | 26 | – |
| buffalo_cheese_large | 337 | 25 | – |
| buffalo_cheese_large_gold | 506 | 26 | – |
| buffalo_cheese_large_silver | 421 | 26 | – |
| buffalo_cheese_silver | 337 | 25 | – |
| butter | 220 | 18 | 26 |
| cheese | 150 | 18 | 26 |
| cheese_gold | 225 | 22 | 26 |
| cheese_large | 187 | 21 | 26 |
| cheese_large_gold | 281 | 22 | 26 |
| cheese_large_silver | 234 | 22 | 26 |
| cheese_silver | 187 | 21 | 26 |
| chocolate | 30 | 8 | 26 |
| cream | 220 | 22 | 34 |
| dried_fruit | 290 | 22 | – |
| duck_mayonnaise | 165 | 19 | – |
| duck_mayonnaise_gold | 247 | 25 | – |
| duck_mayonnaise_large | 206 | 22 | – |
| duck_mayonnaise_large_gold | 309 | 26 | – |
| duck_mayonnaise_large_silver | 257 | 25 | – |
| duck_mayonnaise_silver | 206 | 22 | – |
| goat_cheese | 255 | 22 | – |
| goat_cheese_gold | 382 | 26 | – |
| goat_cheese_large | 318 | 25 | – |
| goat_cheese_large_gold | 478 | 26 | – |
| goat_cheese_large_silver | 398 | 26 | – |
| goat_cheese_silver | 318 | 25 | – |
| honey | 25 | 8 | 26 |
| maple_syrup | 25 | 8 | 26 |
| mayonnaise | 75 | 13 | 34 |
| mayonnaise_gold | 112 | 17 | 34 |
| mayonnaise_large | 93 | 15 | 34 |
| mayonnaise_large_gold | 140 | 20 | 34 |
| mayonnaise_large_silver | 117 | 17 | 34 |
| mayonnaise_silver | 93 | 15 | 34 |
| peanut_butter | 39 | 9 | – |
| pickled_cucumber | 110 | 16 | – |
| pickled_tomato | 120 | 16 | – |
| raisins | 70 | 13 | 42 |
| strawberry_jam | 60 | 12 | – |
| yogurt | 220 | 22 | 34 |
