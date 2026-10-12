class_name OutlineIcon
extends RefCounted
## Versi ikon dengan outline putih, untuk barang yang tergeletak di tanah.
## 1) Cari versi outline yang sudah ada di sheet yang sama: salinan gambar yang persis sama
##    dengan cincin putih 1 px di sekelilingnya, bergeser kelipatan CELL ke kanan/bawah.
##    (Food Icons: +16 kanan, All Crops: beberapa kolom kanan, Stones: 1 baris bawah, Bars and ores: +64.)
## 2) Kalau tidak ada, outline putih dibuat otomatis dari ikonnya.
## Hasil di-cache, jadi pencarian hanya sekali per ikon.

const CELL := 16
const MAX_STEPS_X := 8
const MAX_STEPS_Y := 4
const WHITE_MIN := 0.85  # bagian cincin yang harus putih

static var _cache: Dictionary = {}  # key -> Texture2D
static var _images: Dictionary = {}  # atlas -> Image


static func get_for(icon: Texture2D) -> Texture2D:
	if icon == null:
		return null
	var key := _key(icon)
	if _cache.has(key):
		return _cache[key]
	var result: Texture2D = null
	if icon is AtlasTexture and (icon as AtlasTexture).atlas:
		result = _find_in_sheet(icon as AtlasTexture)
	if result == null:
		result = _generate(icon)
	if result == null:
		result = icon
	_cache[key] = result
	return result


static func _key(icon: Texture2D) -> String:
	if icon is AtlasTexture:
		var at := icon as AtlasTexture
		var base := at.atlas.resource_path if at.atlas else ""
		return "%s|%s" % [base if not base.is_empty() else str(at.atlas.get_instance_id()), at.region]
	return icon.resource_path if not icon.resource_path.is_empty() else str(icon.get_instance_id())


static func _image_of(tex: Texture2D) -> Image:
	if _images.has(tex):
		return _images[tex]
	var img := tex.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
	_images[tex] = img
	return img


## Cari salinan ber-outline, lalu salin hanya piksel item dan cincin outline.
## Region yang diperbesar dapat menyentuh garis/ikon tetangga di spritesheet.
static func _find_in_sheet(icon: AtlasTexture) -> Texture2D:
	var img := _image_of(icon.atlas)
	if img == null:
		return null
	var r := Rect2i(icon.region)
	if r.size.x <= 0 or r.size.y <= 0:
		return null
	var mask: Array[Vector2i] = []
	var ring: Array[Vector2i] = []
	_mask_and_ring(img, r, mask, ring)
	if mask.is_empty() or ring.is_empty():
		return null
	var offsets: Array[Vector2i] = []
	for sy in range(0, MAX_STEPS_Y + 1):
		for sx in range(0, MAX_STEPS_X + 1):
			if sx != 0 or sy != 0:
				offsets.append(Vector2i(sx * CELL, sy * CELL))
	offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.length_squared() < b.length_squared())
	var bounds := Rect2i(Vector2i.ZERO, img.get_size())
	for off in offsets:
		if _matches(img, bounds, mask, ring, off):
			var clean := Image.create(r.size.x + 2, r.size.y + 2, false, Image.FORMAT_RGBA8)
			for p in mask:
				var local := p - r.position + Vector2i.ONE
				clean.set_pixelv(local, img.get_pixelv(p + off))
			for p in ring:
				var local := p - r.position + Vector2i.ONE
				clean.set_pixelv(local, Color.WHITE)
			return ImageTexture.create_from_image(clean)
	return null


## mask = piksel terlihat ikon; ring = piksel kosong 4-arah di sebelahnya (boleh 1 px di luar region).
static func _mask_and_ring(img: Image, r: Rect2i, mask: Array[Vector2i], ring: Array[Vector2i]) -> void:
	var opaque := {}
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if img.get_pixel(x, y).a > 0.5:
				var p := Vector2i(x, y)
				mask.append(p)
				opaque[p] = true
	var seen := {}
	for p in mask:
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = p + d
			if opaque.has(q) or seen.has(q):
				continue
			seen[q] = true
			ring.append(q)


static func _matches(img: Image, bounds: Rect2i, mask: Array[Vector2i], ring: Array[Vector2i], off: Vector2i) -> bool:
	for p in mask:
		var q := p + off
		if not bounds.has_point(q):
			return false
		var a := img.get_pixel(p.x, p.y)
		var b := img.get_pixel(q.x, q.y)
		if absf(a.r - b.r) > 0.02 or absf(a.g - b.g) > 0.02 or absf(a.b - b.b) > 0.02 or b.a < 0.5:
			return false
	var white := 0
	for p in ring:
		var q := p + off
		if not bounds.has_point(q):
			continue
		var c := img.get_pixel(q.x, q.y)
		if c.a > 0.5 and c.r > 0.9 and c.g > 0.9 and c.b > 0.9:
			white += 1
	return float(white) / float(ring.size()) >= WHITE_MIN


## Buat outline putih 1 px sendiri (untuk ikon yang tidak punya versi outline).
static func _generate(icon: Texture2D) -> Texture2D:
	var src: Image
	if icon is AtlasTexture and (icon as AtlasTexture).atlas:
		var sheet := _image_of((icon as AtlasTexture).atlas)
		if sheet == null:
			return null
		var r := Rect2i((icon as AtlasTexture).region).intersection(Rect2i(Vector2i.ZERO, sheet.get_size()))
		if r.size.x <= 0 or r.size.y <= 0:
			return null
		src = sheet.get_region(r)
	else:
		src = _image_of(icon)
		if src == null:
			return null
		src = src.duplicate()
	var w := src.get_width()
	var h := src.get_height()
	if w > 64 or h > 64:
		return null  # bukan ikon kecil, biarkan apa adanya
	var out := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(0, 0, w, h), Vector2i(1, 1))
	for y in range(h + 2):
		for x in range(w + 2):
			if out.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 1 and ny >= 1 and nx <= w and ny <= h and src.get_pixel(nx - 1, ny - 1).a > 0.5:
					out.set_pixel(x, y, Color.WHITE)
					break
	return ImageTexture.create_from_image(out)
