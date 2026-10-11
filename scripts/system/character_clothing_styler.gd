class_name CharacterClothingStyler
extends RefCounted

## Adaptasi desain custom_clothes ke mask pose asli: seluruh animasi memakai
## siluet/frame masing-masing, termasuk tangan terangkat dan kaki melangkah.
const DENIM := Color8(52, 61, 97)
const DENIM_SHADOW := Color8(31, 35, 63)
const FARM_DENIM := Color8(26, 52, 115)
const FARM_SHADOW := Color8(31, 31, 56)

static func _is_denim(c: Color) -> bool:
	return c == DENIM or c == DENIM_SHADOW or c == FARM_DENIM or c == FARM_SHADOW

static func apply(source: Image, style: String, baggy: bool, reference: Image) -> Image:
	if style.is_empty() and not baggy:
		return source
	var result := source.duplicate() as Image
	var frame_size := source.get_height()
	@warning_ignore("integer_division")
	var count: int = source.get_width() / frame_size
	for frame in count:
		var start := frame * frame_size
		var top_mask: Array[Vector2i] = []
		var pants_mask: Array[Vector2i] = []
		for y in frame_size:
			for x in frame_size:
				var c := source.get_pixel(start + x, y)
				if c.a == 0:
					continue
				if _is_denim(reference.get_pixel(start + x, y)):
					pants_mask.append(Vector2i(x, y))
				elif not style.is_empty():
					# Shoes share the dark trim palette, but are below the denim.
					top_mask.append(Vector2i(x, y))
		var waist := frame_size
		var hem := -1
		for p in pants_mask:
			waist = mini(waist, p.y)
			hem = maxi(hem, p.y)
		var rows := {}
		for p in top_mask:
			if p.y > hem:
				continue
			if not rows.has(p.y):
				rows[p.y] = Vector2i(p.x, p.x)
			var bounds: Vector2i = rows[p.y]
			rows[p.y] = Vector2i(mini(bounds.x, p.x), maxi(bounds.y, p.x))
		for p in top_mask:
			if not rows.has(p.y) or p.y > hem:
				continue
			var bounds: Vector2i = rows[p.y]
			var edge := mini(p.x - bounds.x, bounds.y - p.x)
			var white_shirt := style == "striped_shirt"
			var color := Color8(232, 235, 239) if white_shirt else Color8(36, 39, 46)
			# At 32px three literal lines cannot fit: alternating high-contrast
			# pixels on the sleeve edges preserve the sportswear stripe motif.
			if edge <= 1:
				color = Color8(35, 37, 43) if white_shirt else Color8(226, 230, 236)
				if (p.y + edge) % 2 == 1:
					color = Color8(188, 194, 204) if white_shirt else Color8(55, 61, 73)
			elif not white_shirt and frame < count / 4 and p.x == (bounds.x + bounds.y) / 2:
				color = Color8(112, 120, 134)
			result.set_pixel(start + p.x, p.y, color)
		if baggy:
			for p in pants_mask:
				var shadow := _is_denim(reference.get_pixel(start + p.x, p.y)) and reference.get_pixel(start + p.x, p.y) == DENIM_SHADOW
				result.set_pixel(start + p.x, p.y, Color8(29, 37, 54) if shadow else Color8(47, 61, 81))
				# Expand each leg along its existing pose without filling the gap
				# between the legs or painting over shoes/hands.
				for dx in [-1, 1]:
					var nx: int = p.x + dx
					if nx < 0 or nx >= frame_size or p.y <= waist:
						continue
					if source.get_pixel(start + nx, p.y).a != 0:
						continue
					var opposite := false
					for gap in range(1, 4):
						var probe: int = nx + dx * gap
						if probe >= 0 and probe < frame_size and _is_denim(reference.get_pixel(start + probe, p.y)):
							opposite = true
					if not opposite:
						result.set_pixel(start + nx, p.y, Color8(35, 45, 63))
	return result
