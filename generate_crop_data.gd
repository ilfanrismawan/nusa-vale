@tool
extends EditorScript
## Generator otomatis untuk semua tanaman & benih dari res://assets/farm_rpg/crops/All Crops.png
## Cara pakai di Godot:
## Buka file ini di Script Editor Godot -> menu File -> Run (Ctrl+Shift+X).

const ALL_CROPS_TEX := "res://assets/farm_rpg/crops/All Crops.png"
const ITEM_DIR := "res://resources/item_data/"
const CROP_DIR := "res://resources/crop_data/"
const ACTION_DIR := "res://resources/action_data/"
const ICON_DIR := "res://resources/icons/"
const SHOP_PATH := "res://resources/shop/general_store.tres"

## Format: [id, nama_tampilan, musim, section (1..3), row (0..N), harga_beli_benih, harga_jual_panen, days_per_stage, is_root]
## Section 1: x_seed = 0,   x_crop = 32
## Section 2: x_seed = 144, x_crop = 176
## Section 3: x_seed = 288, x_crop = 320
const ROWS := [
	# ===== SECTION 1 =====
	["cherry", "Ceri", "spring", 1, 0, 40, 65, 1, false],
	["apricot", "Aprikot", "spring", 1, 1, 50, 80, 1, false],
	["strawberry", "Strawberry", "spring", 1, 2, 30, 50, 1, false],
	["leek", "Daun Bawang", "spring", 1, 3, 20, 35, 1, true],
	["potato", "Kentang", "spring", 1, 4, 25, 45, 1, true],
	["onion", "Bawang", "summer", 1, 5, 25, 45, 1, true],
	["carrot", "Wortel", "spring", 1, 6, 25, 45, 1, true],
	["blueberry", "Blueberry", "summer", 1, 7, 50, 85, 1, false],
	["parsnip", "Lobak Putih", "spring", 1, 8, 20, 35, 1, true],
	["cabbage", "Kubis", "spring", 1, 9, 35, 60, 1, false],
	["cauliflower", "Kembang Kol", "spring", 1, 10, 45, 80, 2, false],
	["rice", "Padi", "spring", 1, 11, 20, 35, 1, false],
	["broccoli", "Brokoli", "fall", 1, 12, 35, 60, 1, false],
	["rhubarb", "Rhubarb", "spring", 1, 13, 40, 70, 1, true],

	# ===== SECTION 2 =====
	["banana", "Pisang", "summer", 2, 0, 75, 120, 2, false],
	["orange", "Jeruk", "summer", 2, 1, 60, 95, 2, false],
	["mango", "Mangga", "summer", 2, 2, 70, 110, 2, false],
	["peach", "Persik", "summer", 2, 3, 65, 100, 2, false],
	["tomato", "Tomat", "summer", 2, 4, 30, 55, 1, false],
	["sunflower", "Bunga Matahari", "summer", 2, 5, 40, 70, 1, false],
	["chili", "Cabai", "summer", 2, 6, 30, 50, 1, false],
	["green_apple", "Apel Hijau", "fall", 2, 7, 60, 95, 2, false],
	["red_pepper", "Paprika Merah", "summer", 2, 8, 35, 60, 1, false],
	["yellow_pepper", "Paprika Kuning", "summer", 2, 9, 35, 60, 1, false],
	["melon", "Melon", "summer", 2, 10, 50, 90, 2, false],
	["watermelon", "Semangka", "summer", 2, 11, 60, 110, 2, false],
	["cucumber", "Timun", "summer", 2, 12, 25, 45, 1, false],
	["pineapple", "Nanas", "summer", 2, 13, 70, 125, 2, false],
	["pea", "Kacang Polong", "spring", 2, 14, 25, 45, 1, false],
	["garlic", "Bawang Putih", "spring", 2, 15, 30, 50, 1, true],
	["blackberry", "Blackberry", "fall", 2, 16, 45, 75, 1, false],
	["wheat", "Gandum", "fall", 2, 17, 15, 30, 1, false],

	# ===== SECTION 3 =====
	["apple", "Apel", "fall", 3, 0, 60, 95, 2, false],
	["beet", "Bit Merah", "fall", 3, 1, 30, 55, 1, true],
	["pumpkin", "Labu", "fall", 3, 2, 50, 95, 2, false],
	["grape", "Anggur", "fall", 3, 3, 40, 70, 1, false],
	["corn", "Jagung", "summer", 3, 4, 35, 65, 2, false],
	["eggplant", "Terong", "fall", 3, 5, 30, 55, 1, false],
	["zucchini", "Zukini", "summer", 3, 6, 25, 45, 1, false],
]

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ITEM_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CROP_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ACTION_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ICON_DIR))

	var atlas_tex: Texture2D = load(ALL_CROPS_TEX)
	if atlas_tex == null:
		push_error("Tidak dapat memuat atlas: " + ALL_CROPS_TEX)
		return

	var all_seeds: Array[ItemData] = []
	var count := 0

	for row in ROWS:
		var id: String = row[0]
		var dname: String = row[1]
		var season: String = row[2]
		var section: int = row[3]
		var row_idx: int = row[4]
		var buy_price: int = row[5]
		var sell_price: int = row[6]
		var days_per_stage: int = row[7]
		var is_root: bool = row[8]

		var seed_x := 0
		var crop_x := 32
		if section == 2:
			seed_x = 144
			crop_x = 176
		elif section == 3:
			seed_x = 288
			crop_x = 320
		var y := row_idx * 16

		var season_label := "musim semi"
		match season:
			"summer": season_label = "musim panas"
			"fall": season_label = "musim gugur"
			"winter": season_label = "musim dingin"

		# 1. Icon Crop
		var icon_crop := AtlasTexture.new()
		icon_crop.atlas = atlas_tex
		icon_crop.region = Rect2(crop_x, y, 16, 16)
		var icon_crop_path := ICON_DIR + "icon_" + id + ".tres"
		icon_crop.take_over_path(icon_crop_path)
		ResourceSaver.save(icon_crop, icon_crop_path)

		# 2. Icon Seed
		var icon_seed := AtlasTexture.new()
		icon_seed.atlas = atlas_tex
		icon_seed.region = Rect2(seed_x, y, 16, 16)
		var icon_seed_path := ICON_DIR + "icon_seed_" + id + ".tres"
		icon_seed.take_over_path(icon_seed_path)
		ResourceSaver.save(icon_seed, icon_seed_path)

		# 3. CropData
		var crop := CropData.new()
		crop.crop_id = id
		crop.display_name = dname
		crop.icon = icon_crop
		crop.growth_stages = [
			Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
			Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)
		]
		crop.days_per_stage = days_per_stage
		crop.harvest_item_id = id
		crop.harvest_count = 1
		crop.tileset_source_id = 1 if is_root else 0
		crop.season = season
		var crop_path := CROP_DIR + id + ".tres"
		crop.take_over_path(crop_path)
		ResourceSaver.save(crop, crop_path)

		# 4. ActionData (Seed)
		var seed_effect := SeedEffect.new()
		seed_effect.crop = crop
		seed_effect.seed_item_id = "seed_" + id

		var action := ActionData.new()
		action.display_name = "Benih " + dname
		action.icon = icon_seed
		action.animation_name = &"throw"
		action.hit_frame = 3
		action.effect = seed_effect
		var action_path := ACTION_DIR + "seed_" + id + ".tres"
		action.take_over_path(action_path)
		ResourceSaver.save(action, action_path)

		# 5. ItemData Crop (Hasil Panen)
		var item_crop := ItemData.new()
		item_crop.category = ItemData.Category.CROP
		item_crop.item_id = id
		item_crop.display_name = dname
		item_crop.icon = icon_crop
		item_crop.description = "Hasil panen %s segar berkualitas." % dname
		item_crop.stackable = true
		item_crop.max_stack = 99
		item_crop.buy_price = 0
		item_crop.sell_price = sell_price
		item_crop.season = season
		var item_crop_path := ITEM_DIR + id + ".tres"
		item_crop.take_over_path(item_crop_path)
		ResourceSaver.save(item_crop, item_crop_path)

		# 6. ItemData Seed (Benih)
		var item_seed := ItemData.new()
		item_seed.category = ItemData.Category.SEED
		item_seed.item_id = "seed_" + id
		item_seed.display_name = "Benih " + dname
		item_seed.icon = icon_seed
		item_seed.description = "Benih untuk menanam tanaman %s di %s." % [dname, season_label]
		item_seed.stackable = true
		item_seed.max_stack = 99
		item_seed.action_data = action
		item_seed.buy_price = buy_price
		item_seed.sell_price = int(buy_price / 2)
		item_seed.season = season
		var item_seed_path := ITEM_DIR + "seed_" + id + ".tres"
		item_seed.take_over_path(item_seed_path)
		ResourceSaver.save(item_seed, item_seed_path)

		all_seeds.append(item_seed)
		count += 1

	# Update Toko general_store.tres
	if ResourceLoader.exists(SHOP_PATH):
		var shop: ShopData = load(SHOP_PATH)
		if shop:
			var stock: Array[ItemData] = []
			stock.append_array(all_seeds)
			# Masukkan tas ransel jika ada
			for bag_id in ["backpack_medium", "backpack_large"]:
				var p := ITEM_DIR + bag_id + ".tres"
				if ResourceLoader.exists(p):
					stock.append(load(p))
			shop.stock = stock
			ResourceSaver.save(shop, SHOP_PATH)
			print("general_store.tres berhasil diupdate dengan %d item benih!" % all_seeds.size())

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	print("Selesai: %d tanaman & benih berhasil dibuat!" % count)
