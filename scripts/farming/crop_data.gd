class_name CropData
extends Resource


@export var crop_id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D

@export var growth_stages: Array[Vector2i] = []

@export var days_per_stage: int = 1
## Pohon buah: hari sampai berbuah lagi setelah panen pertama (0 = days_per_stage).
@export var regrow_days: int = 0

@export var harvest_item_id: String = ""
@export var harvest_count: int = 1

@export var tileset_source_id: int = 0
@export var season: String = "" # "spring", "summer", "fall", "winter"

# Ukuran frame dan enam pose pertumbuhan, bukan kolom ikon hasil panen.
const GROWTH_SHEETS := {
	"strawberry": ["spring/Strawberry.png", 16, 16, [0, 1, 2, 3, 4, 5]],
	"carrot": ["spring/Carrot.png", 16, 16, [0, 1, 2, 3, 4, 5]],
	"blueberry": ["spring/Blueberry.png", 16, 32, [0, 1, 2, 3, 4, 5]],
	"potato": ["spring/Potato.png", 16, 16, [0, 1, 2, 3, 4, 5]],
	"onion": ["spring/Onion.png", 16, 16, [0, 1, 2, 3, 4, 5]],
	"parsnip": ["spring/Parsnip.png", 16, 16, [0, 1, 2, 3, 3, 4]],
	"cabbage": ["spring/Cabbage.png", 16, 16, [0, 1, 2, 3, 4, 5]],
	"cauliflower": ["spring/Cauliflower.png", 16, 16, [0, 1, 2, 3, 4, 5]],
	"rice": ["spring/Rice.png", 16, 16, [0, 1, 2, 3, 4, 5]],
	"broccoli": ["spring/Broccoli.png", 16, 16, [0, 1, 2, 3, 3, 4]],
	"leek": ["spring/Spring Onion.png", 16, 16, [0, 1, 2, 3, 4, 5]],
	"tomato": ["Summer/Tomato.png", 16, 16, [0, 1, 2, 3, 4, 6]],
	"sunflower": ["Summer/Sunflower.png", 16, 32, [0, 1, 2, 3, 4, 5]],
	"chili": ["Summer/Hot Pepper.png", 16, 16, [0, 1, 2, 3, 4, 6]],
	"red_pepper": ["Summer/Bell Pepper.png", 16, 16, [0, 1, 2, 3, 4, 6]],
	"yellow_pepper": ["Summer/Bell Pepper.png", 16, 16, [0, 1, 2, 3, 4, 5]],
	"melon": ["Summer/Melon.png", 16, 16, [0, 1, 2, 3, 4, 5]],
	"watermelon": ["Summer/Watermelon.png", 16, 16, [0, 1, 2, 3, 5, 7]],
	"cucumber": ["Summer/Cucumber.png", 16, 32, [0, 1, 2, 3, 4, 5]],
	"pineapple": ["Summer/Pineapple.png", 16, 32, [0, 1, 2, 3, 4, 5]],
	"pea": ["Summer/Green Beans.png", 16, 32, [0, 1, 2, 3, 4, 6]],
	"blackberry": ["Summer/Blackberry.png", 16, 16, [0, 1, 2, 3, 4, 6]],
	"wheat": ["Summer/Wheat.png", 16, 16, [0, 1, 2, 3, 4, 5]],
	"beet": ["Fall/Beetroot.png", 16, 16, [0, 1, 2, 3, 4, 5]],
	"pumpkin": ["Fall/Pumpkin.png", 16, 16, [0, 0, 2, 3, 4, 5]],
	"grape": ["Fall/Grapes.png", 16, 32, [0, 0, 2, 3, 4, 5]],
	"corn": ["Fall/Corn.png", 16, 32, [0, 1, 2, 3, 5, 7]],
	"eggplant": ["Fall/Eggplant.png", 16, 16, [0, 1, 2, 3, 4, 5]],
	"cherry": ["Fruits Tree/Spring/Cherry Tree.png", 32, 48, [0, 1, 2, 3, 4, 5]],
	"apricot": ["Fruits Tree/Spring/Apricot Tree.png", 32, 48, [0, 1, 2, 3, 3, 4]],
	"banana": ["Fruits Tree/Summer/Banana Tree.png", 32, 48, [0, 0, 1, 2, 3, 4]],
	"orange": ["Fruits Tree/Summer/Orange Tree.png", 32, 48, [0, 1, 2, 3, 3, 4]],
	"mango": ["Fruits Tree/Summer/Mango Tree.png", 32, 48, [0, 1, 2, 3, 3, 4]],
	"peach": ["Fruits Tree/Summer/Peach Tree.png", 32, 48, [0, 1, 2, 3, 3, 4]],
	"apple": ["Fruits Tree/Fall/Apple Tree.png", 32, 48, [0, 1, 2, 3, 5, 6]],
}

var _growth_texture: Texture2D

func get_growth_frame_size() -> Vector2i:
	var sheet: Array = GROWTH_SHEETS.get(crop_id, [])
	return Vector2i(sheet[1], sheet[2]) if not sheet.is_empty() else Vector2i(16, 16)

func get_growth_coords(stage: int) -> Vector2i:
	var sheet: Array = GROWTH_SHEETS.get(crop_id, [])
	if not sheet.is_empty():
		return Vector2i(sheet[3][clampi(stage, 0, sheet[3].size() - 1)], 0)
	return Vector2i(clampi(stage, 0, get_total_stages() - 1), 0)

func get_growth_texture() -> Texture2D:
	if _growth_texture != null:
		return _growth_texture
	var sheet: Array = GROWTH_SHEETS.get(crop_id, [])
	if not sheet.is_empty():
		_growth_texture = load("res://assets/farm_rpg/crops/" + sheet[0]) as Texture2D
	else:
		# Rhubarb, garlic, green apple dan zucchini tidak punya sheet khusus.
		# Gunakan tunas bersama lalu ikon tanaman itu sendiri, bukan strawberry.
		var seedlings := (load("res://assets/farm_rpg/crops/spring/Carrot.png") as Texture2D).get_image()
		var produce := icon.get_image() if icon != null else null
		if produce == null:
			return null
		var image := Image.create_empty(get_total_stages() * 16, 16, false, Image.FORMAT_RGBA8)
		image.blit_rect(seedlings, Rect2i(0, 0, 48, 16), Vector2i.ZERO)
		for stage in range(3, get_total_stages()):
			var frame := produce.duplicate()
			var size := mini(16, 8 + (stage - 3) * 4)
			frame.resize(size, size, Image.INTERPOLATE_NEAREST)
			image.blit_rect(frame, Rect2i(0, 0, size, size), Vector2i(stage * 16 + (16 - size) / 2, 16 - size))
		_growth_texture = ImageTexture.create_from_image(image)
	return _growth_texture

func get_total_stages() -> int:
	return growth_stages.size()
	
func is_harvestable(current_stage: int) -> bool:
	return current_stage >= growth_stages.size() - 1

func is_fruit_tree() -> bool:
	return crop_id in ["cherry", "apricot", "banana", "orange", "mango", "peach", "apple"]
