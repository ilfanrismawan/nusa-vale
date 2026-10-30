class_name RanchVisual
extends RefCounted

## Sprite ternak dari paket Farm RPG: assets/farm_rpg/animals/Farm dan Forest.
## Kerbau tidak ada di paket, jadi tetap memakai animals/buffalo.png.
const ROOT := "res://assets/farm_rpg/animals/"
## species -> varian -> sheet dewasa. Varian yang tidak ada memakai entri pertama.
const SHEETS := {
	"chicken": {"white": "Farm/Chicken/Chicken White.png", "brown": "Farm/Chicken/Chicken Brown White.png"},
	"duck": {"white": "Farm/Ducks/Duck White.png"},
	"cow": {"white": "Farm/Cow/Common Cow/Female Cow Black.png"},
	"goat": {"white": "Farm/Goat/Goat Female Brown.png"},
	"sheep": {"white": "Farm/Sheep/Sheep Female.png"},
	"capybara": {"white": "Forest/Capybara/Brown Capybara.png"},
	"pig": {"white": "Farm/Pig/Pig Pink.png", "brown": "Farm/Pig/Pig Mud Pink.png"},
	"ostrich": {"white": "Farm/Ostrich/Ostrich Brown.png", "brown": "Farm/Ostrich/Ostrich Black.png"},
	"buffalo": {"white": "buffalo.png"},
	"horse": {"1": "Farm/Horse/1/idle.png", "2": "Farm/Horse/2/idle.png"},
}
## Sheet anak (baby_days > 0). Spesies tanpa entri memakai sheet dewasa yang diperkecil.
const BABY_SHEETS := {
	"chicken": {"white": "Farm/Chicken/Baby Chicken White.png", "brown": "Farm/Chicken/Baby Chicken Brown.png"},
	"duck": {"white": "Farm/Ducks/Baby Duck White.png"},
	"cow": {"white": "Farm/Cow/Common Cow/Baby Cow Black.png"},
	"goat": {"white": "Farm/Goat/Goat Baby Brown.png"},
	"sheep": {"white": "Farm/Sheep/Baby Sheep .png"},
	"pig": {"white": "Farm/Pig/Baby Pig Pink.png", "brown": "Farm/Pig/Baby Pig Mud Pink.png"},
	"ostrich": {"white": "Farm/Ostrich/Ostrich Baby Brown.png", "brown": "Farm/Ostrich/Ostrich Baby Black.png"},
}
## Kuda: animasi jalan ada di file terpisah.
const WALK_SHEETS := {"Farm/Horse/1/idle.png": "Farm/Horse/1/Run.png", "Farm/Horse/2/idle.png": "Farm/Horse/2/run.png"}
## Warna kuda Eep ("1".."5") -> sheet Farm/Horse: 1 = surai gelap, 2 = surai terang.
const HORSE_SHEET := {"1": "1", "2": "2", "3": "2", "4": "1", "5": "2"}
## Tata letak per arah: [baris, kolom...] untuk diam dan jalan. Sheet Farm: baris 0-2 = siklus jalan
## samping/bawah/atas; baris 3-5 = berbaring/duduk (bukan jalan).
const DEFAULT_LAYOUT := {
	"idle": {"side": [0, 0, 1], "down": [1, 0, 1], "up": [2, 0, 1]},
	"walk": {"side": [0, 0, 1, 2, 3], "down": [1, 0, 1, 2, 3], "up": [2, 0, 1, 2, 3]},
}
## Baris samping semua sheet menghadap kiri, kecuali kuda Farm/Horse (menghadap kanan).
const FACES_RIGHT := ["horse"]
const LAYOUTS := {
	"chicken_baby": {
		"idle": {"side": [0, 0, 1], "down": [1, 0, 1], "up": [1, 0, 1]},
		"walk": {"side": [0, 0, 1, 2, 3], "down": [1, 0, 1, 2, 3], "up": [1, 0, 1, 2, 3]},
	},
	"duck_baby": {
		"idle": {"side": [0, 0, 1], "down": [1, 0, 1], "up": [1, 0, 1]},
		"walk": {"side": [0, 0, 1, 2, 3], "down": [1, 0, 1, 2, 3], "up": [1, 0, 1, 2, 3]},
	},
	"capybara": {
		"idle": {"side": [11, 0, 2], "down": [12, 0, 2], "up": [13, 0, 2]},
		"walk": {"side": [0, 0, 1, 2, 3], "down": [1, 0, 1, 2, 3], "up": [2, 0, 1, 2, 3]},
	},
	"horse": {
		"idle": {"side": [0, 4, 5], "down": [0, 0, 1], "up": [0, 2, 3]},
		"walk": {"side": [2, 0, 1, 2, 3, 4, 5], "down": [0, 0, 1, 2, 3, 4, 5], "up": [1, 0, 1, 2, 3, 4, 5]},
	},
}

static var _cache: Dictionary = {}

static func frames(species: String, variant: String = "white", walking: bool = false, direction: String = "down", baby: bool = false) -> SpriteFrames:
	baby = baby and has_baby_sheet(species)
	var key := species + variant + direction + ("_walk" if walking else "_idle") + ("_baby" if baby else "")
	if _cache.has(key):
		return _cache[key]
	var path := sheet_path(species, variant, baby)
	if walking and WALK_SHEETS.has(path):
		path = WALK_SHEETS[path]
	var texture: Texture2D = load(ROOT + path)
	var size := 16 if species in ["chicken", "duck"] else 32
	var layout: Dictionary = LAYOUTS.get(species + ("_baby" if baby else ""), DEFAULT_LAYOUT)
	var cells: Array = layout["walk" if walking else "idle"].get(direction, layout["walk" if walking else "idle"]["down"])
	var result := SpriteFrames.new()
	result.set_animation_speed(&"default", 5 if walking else 2.5)
	for column in cells.slice(1):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(int(column) * size, int(cells[0]) * size, size, size)
		frame.filter_clip = true
		result.add_frame(&"default", frame)
	_cache[key] = result
	return result

static func faces_right(species: String) -> bool:
	return species in FACES_RIGHT

static func has_baby_sheet(species: String) -> bool:
	return BABY_SHEETS.has(species)

static func sheet_path(species: String, variant: String = "white", baby: bool = false) -> String:
	if species == "horse":
		variant = HORSE_SHEET[RanchHusbandry.horse_coat({"variant": variant})]
	var sheets: Dictionary = (BABY_SHEETS if baby and has_baby_sheet(species) else SHEETS).get(species, SHEETS.chicken)
	return sheets.get(variant, sheets.values()[0])
