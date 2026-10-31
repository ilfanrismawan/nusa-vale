extends Resource
## Peti panen: saat memegang banyak hasil panen, karakter mengangkat peti berisi panen itu
## (seperti Harvest Moon). Gambar peti dari objects/exterior/Box.png; posisi per frame dari
## layer Character/Pre-made/Josh/Pick Up Itens/{Idle,Walk,Run,Pick Up Itens} Box.png.

## Sheet peti (Box.png).
@export var texture: Texture2D
## Jumlah minimal hasil panen di tas supaya yang diangkat berupa peti, bukan satu buah.
@export_range(1, 999) var min_amount: int = 5
## item_id -> Rect2 peti berisi panen itu di `texture`.
@export var crates: Dictionary = {}
## Peti kosong terbuka; hasil panen tanpa peti khusus ditaruh di atasnya.
@export var empty_crate := Rect2(16, 0, 16, 16)
## Dasar peti (baris piksel, eksklusif) per frame dalam frame 64x64 layer Box, per arah
## [bawah, atas, samping]. Badan 32x32 berpusat di frame ini.
@export var crate_bottom := {
	"carry_idle": [[29, 30, 29, 30], [29, 30, 29, 30], [29, 30, 29, 30]],
	"carry_walk": [[30, 30, 29, 30, 30, 29], [30, 30, 29, 30, 30, 29], [30, 30, 29, 30, 30, 29]],
	"carry_run": [[30, 31, 29, 29, 30, 31, 29, 29], [30, 31, 32, 30, 30, 31, 32, 30], [30, 31, 30, 29, 29, 31, 29, 29]],
	"pick_up": [[42, 39, 35, 33], [40, 39, 34, 32], [41, 40, 37, 31]],
}
## Geser horizontal peti saat mengangkat menghadap samping (kanan; kiri dicerminkan).
@export var pick_up_side_x: Array = [10, 10, 6, 0]

var _cache := {}

## Peti untuk barang ini, atau null bila bukan hasil panen.
func crate_for(item: ItemData) -> Texture2D:
	if item == null or texture == null or item.category != ItemData.Category.CROP:
		return null
	if _cache.has(item.item_id):
		return _cache[item.item_id]
	var result: Texture2D
	if crates.has(item.item_id):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = crates[item.item_id]
		result = atlas
	else:
		result = _stack_on_empty(item.icon)
	_cache[item.item_id] = result
	return result

## Baris dasar peti untuk frame ini, -1 bila animasinya tidak punya data.
func bottom_row(animation: String, direction: String, frame: int) -> int:
	if not crate_bottom.has(animation):
		return -1
	var rows: Array = crate_bottom[animation]
	var row: Array = rows[0 if direction == "down" else (1 if direction == "up" else 2)]
	return int(row[clampi(frame, 0, row.size() - 1)])

func side_offset(animation: String, direction: String, frame: int) -> int:
	if animation != "pick_up" or direction in ["down", "up"] or pick_up_side_x.is_empty():
		return 0
	return int(pick_up_side_x[clampi(frame, 0, pick_up_side_x.size() - 1)])

## Ikon panen dibenamkan ke peti kosong (dasar ikon masuk ke balik bibir peti).
func _stack_on_empty(icon: Texture2D) -> Texture2D:
	var sheet := texture.get_image()
	if sheet == null:
		return null
	var size := Vector2i(empty_crate.size)
	var canvas := Image.create(size.x, size.y + 8, false, Image.FORMAT_RGBA8)
	var crate := sheet.get_region(Rect2i(empty_crate))
	crate.convert(Image.FORMAT_RGBA8)
	canvas.blend_rect(crate, Rect2i(Vector2i.ZERO, size), Vector2i(0, 8))
	var picture := icon.get_image() if icon != null else null
	if picture != null:
		picture.convert(Image.FORMAT_RGBA8)
		if picture.get_size() != size:
			picture.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
		# Hanya bagian atas ikon yang digambar: sisanya tertutup dinding depan peti.
		canvas.blend_rect(picture, Rect2i(0, 0, size.x, 14), Vector2i(0, 0))
	return ImageTexture.create_from_image(canvas)
