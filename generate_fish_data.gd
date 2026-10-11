@tool
extends EditorScript
## Cara pakai:
## 1. Simpan file ini di project (mis. res://tools/generate_fish_data.gd).
## 2. Ganti ICON_ROOT di bawah dengan folder yang berisi subfolder River/ dan Sea/.
## 3. Buka file ini di Script Editor Godot -> menu File -> Run (Ctrl+Shift+X).
##
## Hasil: satu ItemData (resources/item_data/fish_<id>.tres) dan satu FishData
## (resources/fish_data/fish_<id>.tres) per baris di ROWS.
## Aman dijalankan ulang: file dengan id yang sama akan ditimpa.
## Harga jual diambil dari FishTiers (per tier), bisa diubah manual setelahnya.

const ICON_ROOT := "res://assets/farm_rpg/icons/Fish/" # <-- GANTI sesuai lokasi aset Anda
const ITEM_DIR := "res://resources/item_data/"
const FISH_DIR := "res://resources/fish_data/"
const ICON_DIR := "res://resources/icons/"

# habitat -> daftar location_id (sama dengan location_id di node FishingSpot)
const HABITAT := {
	"river": ["farm_pond", "farm_river", "forest_river"],
	"sea": ["beach_sea"], # belum ada lokasinya; ikan laut baru muncul bila ada FishingSpot "beach_sea"
}

# [path ikon relatif ICON_ROOT, nama tampilan, tier, habitat, jam mulai, jam akhir]
# tier: 0 Umum, 1 Tidak Umum, 2 Langka, 3 Epik, 4 Legendaris
# jam: 0..24; bila jam mulai > jam akhir berarti melewati tengah malam (mis. 20 -> 5)
const ROWS := [
	# ===== SUNGAI: ikan =====
	["River/Carp.png", "Ikan Mas", 0, "river", 0, 24],
	["River/Chub.png", "Ikan Chub", 0, "river", 0, 24],
	["River/Perch.png", "Ikan Perca", 0, "river", 0, 24],
	["River/Sunfish.png", "Ikan Sunfish", 0, "river", 6, 20],
	["River/Bullhead Catfish.png", "Lele Bullhead", 0, "river", 0, 24],
	["River/Shad .png", "Ikan Shad", 0, "river", 0, 24],
	["River/Large Mouth Bass.png", "Bass Mulut Besar", 1, "river", 0, 24],
	["River/Walleye.png", "Walleye", 1, "river", 0, 24],
	["River/Pike Fish.png", "Ikan Pike", 1, "river", 0, 24],
	["River/Tiger Trout.png", "Trout Harimau", 1, "river", 0, 24],
	["River/Dorado.png", "Dorado", 2, "river", 0, 24],
	["River/Sturgeon.png", "Sturgeon", 2, "river", 0, 24],
	["River/Dynamite Fish.png", "Ikan Dinamit", 2, "river", 0, 24],
	["River/Bone Fish.png", "Ikan Tulang", 3, "river", 0, 24],
	["River/Zombie Fish.png", "Ikan Zombi", 3, "river", 20, 5],
	["River/Ghost Catfish.png", "Lele Hantu", 3, "river", 20, 5],
	["River/Faeries Fish.png", "Ikan Peri", 4, "river", 5, 8],
	["River/Golden Fish.png", "Ikan Emas", 4, "river", 6, 18],
	# ===== SUNGAI: makhluk =====
	["River/Creatures/Crayfish.png", "Udang Karang", 0, "river", 0, 24],
	["River/Creatures/Frog.png", "Katak", 1, "river", 0, 24],

	# ===== LAUT: ikan =====
	["Sea/Anchovy.png", "Teri", 0, "sea", 0, 24],
	["Sea/Sardine.png", "Sarden", 0, "sea", 0, 24],
	["Sea/Herring.png", "Haring", 0, "sea", 0, 24],
	["Sea/Goby.png", "Ikan Goby", 0, "sea", 0, 24],
	["Sea/Bream.png", "Ikan Bream", 0, "sea", 0, 24],
	["Sea/Sea bullhead.png", "Bullhead Laut", 0, "sea", 0, 24],
	["Sea/Red Mullet.png", "Kuniran", 0, "sea", 0, 24],
	["Sea/Flounder.png", "Ikan Sebelah", 1, "sea", 0, 24],
	["Sea/Smallmouth Bass.png", "Bass Mulut Kecil", 1, "sea", 0, 24],
	["Sea/Salmon.png", "Salmon", 1, "sea", 0, 24],
	["Sea/Albacore.png", "Albacore", 1, "sea", 0, 24],
	["Sea/Clownfish.png", "Ikan Badut", 1, "sea", 6, 18],
	["Sea/Red Snapper.png", "Kakap Merah", 1, "sea", 0, 24],
	["Sea/Halibut.png", "Halibut", 2, "sea", 0, 24],
	["Sea/Lingcod.png", "Lingcod", 2, "sea", 0, 24],
	["Sea/Crimson Snapper.png", "Kakap Crimson", 2, "sea", 0, 24],
	["Sea/LionFish.png", "Ikan Singa", 2, "sea", 0, 24],
	["Sea/pufferfish.png", "Ikan Buntal", 2, "sea", 0, 24],
	["Sea/Regal Blue Tang.png", "Ikan Tang Biru", 2, "sea", 6, 18],
	["Sea/Tuna.png", "Tuna", 3, "sea", 0, 24],
	["Sea/Anglerfish.png", "Ikan Angler", 3, "sea", 20, 5],
	["Sea/Devil Fish.png", "Ikan Iblis", 3, "sea", 0, 24],
	["Sea/BlobFish.png", "Ikan Blob", 3, "sea", 0, 24],
	["Sea/Glacier Fish.png", "Ikan Gletser", 3, "sea", 0, 24],
	["Sea/Dolphin.png", "Lumba-lumba", 4, "sea", 6, 18],
	# ===== LAUT: makhluk =====
	["Sea/Creatures/Shell.png", "Cangkang", 0, "sea", 0, 24],
	["Sea/Creatures/Clam.png", "Kerang", 0, "sea", 0, 24],
	["Sea/Creatures/Snail.png", "Siput", 0, "sea", 0, 24],
	["Sea/Creatures/Shrimp.png", "Udang", 0, "sea", 0, 24],
	["Sea/Creatures/Starfish.png", "Bintang Laut", 0, "sea", 0, 24],
	["Sea/Creatures/Sea Cucumber.png", "Teripang", 0, "sea", 0, 24],
	["Sea/Creatures/Crab.png", "Kepiting", 1, "sea", 0, 24],
	["Sea/Creatures/Eel.png", "Sidat", 1, "sea", 0, 24],
	["Sea/Creatures/Jellyfish.png", "Ubur-ubur", 1, "sea", 0, 24],
	["Sea/Creatures/Squid.png", "Cumi-cumi", 1, "sea", 0, 24],
	["Sea/Creatures/Lobster.png", "Lobster", 2, "sea", 0, 24],
	["Sea/Creatures/Octupus.png", "Gurita", 2, "sea", 0, 24],
	["Sea/Creatures/Stingray.png", "Pari", 2, "sea", 0, 24],
	["Sea/Creatures/Seahorse.png", "Kuda Laut", 2, "sea", 0, 24],
	["Sea/Creatures/Snake.png", "Ular Laut", 2, "sea", 0, 24],
	["Sea/Creatures/Nautilus.png", "Nautilus", 3, "sea", 0, 24],
]

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ITEM_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FISH_DIR))

	var made := 0
	var missing := 0
	for row in ROWS:
		var icon_path: String = ICON_ROOT + row[0]
		if not ResourceLoader.exists(icon_path):
			push_warning("Ikon tidak ditemukan: %s" % icon_path)
			missing += 1
			continue

		var tier: int = row[2]
		var id: String = "fish_" + icon_path.get_file().get_basename().strip_edges().to_lower().replace(" ", "_")

		# --- ItemData ---
		var item := ItemData.new()
		item.category = ItemData.Category.FISH
		item.item_id = id
		item.display_name = row[1]
		var icon_tres_path := ICON_DIR + "icon_" + id + ".tres"
		if ResourceLoader.exists(icon_tres_path):
			item.icon = load(icon_tres_path)
		else:
			item.icon = load(icon_path)
		item.stackable = true
		item.max_stack = 99
		item.rarity = tier as ItemData.Rarity
		item.sell_price = int(FishTiers.TIERS[tier]["price"])
		var item_path := ITEM_DIR + id + ".tres"
		item.take_over_path(item_path)
		ResourceSaver.save(item, item_path)

		# --- FishData ---
		var fish := FishData.new()
		fish.item = item
		fish.locations = PackedStringArray(HABITAT[row[3]])
		fish.min_hour = row[4]
		fish.max_hour = row[5]
		var fish_path := FISH_DIR + id + ".tres"
		fish.take_over_path(fish_path)
		ResourceSaver.save(fish, fish_path)

		made += 1

	EditorInterface.get_resource_filesystem().scan()
	print("Selesai: %d ikan dibuat, %d dilewati (ikon tidak ketemu)." % [made, missing])
