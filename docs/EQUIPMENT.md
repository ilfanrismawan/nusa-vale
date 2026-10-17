# Senjata & Armor (item equipment)

Ditambahkan 2026-10-11. Combat belum ada (Phase 4B-1); item ini baru berupa data + bisa dipasang di menu Equipment.

## Isi
- 8 jenis x 10 tier = 80 item, ikon dari `assets/farm_rpg/icons/RPG icons/Weapons and Armor/<tier>/`.
- Tier mengikuti urutan alat: wood, copper, iron, gold, platinum, crimson, frost, shadow, fairy, obsidian.
- `item_id` = `<jenis>_<tier>`: `sword`, `bow`, `staff`, `arrow`, `helmet`, `armor` (chestplate), `leggings`, `boots`.
- Semua `category = EQUIPMENT (7)`. Arrow bisa ditumpuk (99) dan tidak dipasang ke slot; amunisi untuk busur nanti.

## Field baru di ItemData (ditambah di akhir enum)
- `EquipmentSlot`: + `HELMET`, `LEGGINGS`, `BOOTS` (ARMOR = pelindung badan).
- `WeaponType { NONE, SWORD, BOW, STAFF, ARROW }` dan `weapon_type`.
- `equipment_tier: ToolData.ToolTier`.
- Stat tetap `attack_bonus` / `defense_bonus` (dipakai combat: damage = max(1, ATK - DEF)).

## Slot Equipment
PlayerData.EQUIPMENT_KEYS = helmet, armor, leggings, boots (sejak Phase 4B-1, 17 Oktober 2026). Senjata (pedang, busur, tongkat sihir) dipegang dari hotbar dan dipakai dengan klik kiri; slot Weapon di menu hanya menampilkan senjata yang sedang dipegang. Save lama yang memasang senjata di slot weapon memindahkannya ke tas saat dimuat. Pemain baru mulai dengan Pedang Kayu di tas dan Armor Kayu terpasang. Gaya serangan tiap jenis senjata ada di `resources/combat/<jenis>.tres` (lihat GDD 8.1).
Di menu Equipment: kiri = Helm, Armor, Celana Zirah; kanan atas = Sepatu (menggantikan slot Sarung tangan yang terkunci, karena aset sarung tangan tidak punya tier).

## Harga & stat
Harga jual = 40% harga beli. Item belum dijual di toko mana pun.

| item_id | Nama | Stat | Beli | Jual |
|---|---|---|---|---|
| `sword_wood` | Pedang Kayu | ATK +4 | 150 | 60 |
| `sword_copper` | Pedang Tembaga | ATK +7 | 380 | 152 |
| `sword_iron` | Pedang Besi | ATK +11 | 750 | 300 |
| `sword_gold` | Pedang Emas | ATK +16 | 1500 | 600 |
| `sword_platinum` | Pedang Platinum | ATK +22 | 2700 | 1080 |
| `sword_crimson` | Pedang Crimson | ATK +29 | 4500 | 1800 |
| `sword_frost` | Pedang Frost | ATK +37 | 6750 | 2700 |
| `sword_shadow` | Pedang Shadow | ATK +46 | 9750 | 3900 |
| `sword_fairy` | Pedang Fairy | ATK +56 | 13500 | 5400 |
| `sword_obsidian` | Pedang Obsidian | ATK +68 | 18750 | 7500 |
| `bow_wood` | Busur Kayu | ATK +3 | 180 | 72 |
| `bow_copper` | Busur Tembaga | ATK +6 | 450 | 180 |
| `bow_iron` | Busur Besi | ATK +9 | 900 | 360 |
| `bow_gold` | Busur Emas | ATK +13 | 1800 | 720 |
| `bow_platinum` | Busur Platinum | ATK +18 | 3240 | 1296 |
| `bow_crimson` | Busur Crimson | ATK +24 | 5400 | 2160 |
| `bow_frost` | Busur Frost | ATK +31 | 8100 | 3240 |
| `bow_shadow` | Busur Shadow | ATK +39 | 11700 | 4680 |
| `bow_fairy` | Busur Fairy | ATK +48 | 16200 | 6480 |
| `bow_obsidian` | Busur Obsidian | ATK +58 | 22500 | 9000 |
| `staff_wood` | Tongkat Sihir Kayu | ATK +3 | 200 | 80 |
| `staff_copper` | Tongkat Sihir Tembaga | ATK +5 | 500 | 200 |
| `staff_iron` | Tongkat Sihir Besi | ATK +8 | 1000 | 400 |
| `staff_gold` | Tongkat Sihir Emas | ATK +12 | 2000 | 800 |
| `staff_platinum` | Tongkat Sihir Platinum | ATK +17 | 3600 | 1440 |
| `staff_crimson` | Tongkat Sihir Crimson | ATK +23 | 6000 | 2400 |
| `staff_frost` | Tongkat Sihir Frost | ATK +30 | 9000 | 3600 |
| `staff_shadow` | Tongkat Sihir Shadow | ATK +38 | 13000 | 5200 |
| `staff_fairy` | Tongkat Sihir Fairy | ATK +47 | 18000 | 7200 |
| `staff_obsidian` | Tongkat Sihir Obsidian | ATK +57 | 25000 | 10000 |
| `arrow_wood` | Anak Panah Kayu | ATK +1 | 2 | 1 |
| `arrow_copper` | Anak Panah Tembaga | ATK +2 | 5 | 2 |
| `arrow_iron` | Anak Panah Besi | ATK +3 | 10 | 4 |
| `arrow_gold` | Anak Panah Emas | ATK +4 | 20 | 8 |
| `arrow_platinum` | Anak Panah Platinum | ATK +5 | 36 | 14 |
| `arrow_crimson` | Anak Panah Crimson | ATK +6 | 60 | 24 |
| `arrow_frost` | Anak Panah Frost | ATK +8 | 90 | 36 |
| `arrow_shadow` | Anak Panah Shadow | ATK +10 | 130 | 52 |
| `arrow_fairy` | Anak Panah Fairy | ATK +12 | 180 | 72 |
| `arrow_obsidian` | Anak Panah Obsidian | ATK +15 | 250 | 100 |
| `helmet_wood` | Helm Kayu | DEF +1 | 100 | 40 |
| `helmet_copper` | Helm Tembaga | DEF +2 | 250 | 100 |
| `helmet_iron` | Helm Besi | DEF +4 | 500 | 200 |
| `helmet_gold` | Helm Emas | DEF +6 | 1000 | 400 |
| `helmet_platinum` | Helm Platinum | DEF +8 | 1800 | 720 |
| `helmet_crimson` | Helm Crimson | DEF +11 | 3000 | 1200 |
| `helmet_frost` | Helm Frost | DEF +14 | 4500 | 1800 |
| `helmet_shadow` | Helm Shadow | DEF +18 | 6500 | 2600 |
| `helmet_fairy` | Helm Fairy | DEF +22 | 9000 | 3600 |
| `helmet_obsidian` | Helm Obsidian | DEF +27 | 12500 | 5000 |
| `armor_wood` | Armor Kayu | DEF +3 | 160 | 64 |
| `armor_copper` | Armor Tembaga | DEF +5 | 400 | 160 |
| `armor_iron` | Armor Besi | DEF +8 | 800 | 320 |
| `armor_gold` | Armor Emas | DEF +11 | 1600 | 640 |
| `armor_platinum` | Armor Platinum | DEF +15 | 2880 | 1152 |
| `armor_crimson` | Armor Crimson | DEF +20 | 4800 | 1920 |
| `armor_frost` | Armor Frost | DEF +26 | 7200 | 2880 |
| `armor_shadow` | Armor Shadow | DEF +33 | 10400 | 4160 |
| `armor_fairy` | Armor Fairy | DEF +41 | 14400 | 5760 |
| `armor_obsidian` | Armor Obsidian | DEF +50 | 20000 | 8000 |
| `leggings_wood` | Celana Zirah Kayu | DEF +2 | 130 | 52 |
| `leggings_copper` | Celana Zirah Tembaga | DEF +3 | 320 | 128 |
| `leggings_iron` | Celana Zirah Besi | DEF +5 | 650 | 260 |
| `leggings_gold` | Celana Zirah Emas | DEF +8 | 1300 | 520 |
| `leggings_platinum` | Celana Zirah Platinum | DEF +11 | 2340 | 936 |
| `leggings_crimson` | Celana Zirah Crimson | DEF +14 | 3900 | 1560 |
| `leggings_frost` | Celana Zirah Frost | DEF +18 | 5850 | 2340 |
| `leggings_shadow` | Celana Zirah Shadow | DEF +23 | 8450 | 3380 |
| `leggings_fairy` | Celana Zirah Fairy | DEF +28 | 11700 | 4680 |
| `leggings_obsidian` | Celana Zirah Obsidian | DEF +34 | 16250 | 6500 |
| `boots_wood` | Sepatu Bot Kayu | DEF +1 | 90 | 36 |
| `boots_copper` | Sepatu Bot Tembaga | DEF +2 | 220 | 88 |
| `boots_iron` | Sepatu Bot Besi | DEF +3 | 450 | 180 |
| `boots_gold` | Sepatu Bot Emas | DEF +5 | 900 | 360 |
| `boots_platinum` | Sepatu Bot Platinum | DEF +7 | 1620 | 648 |
| `boots_crimson` | Sepatu Bot Crimson | DEF +9 | 2700 | 1080 |
| `boots_frost` | Sepatu Bot Frost | DEF +12 | 4050 | 1620 |
| `boots_shadow` | Sepatu Bot Shadow | DEF +15 | 5850 | 2340 |
| `boots_fairy` | Sepatu Bot Fairy | DEF +19 | 8100 | 3240 |
| `boots_obsidian` | Sepatu Bot Obsidian | DEF +23 | 11250 | 4500 |
