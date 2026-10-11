class_name CharacterHairStyler
extends RefCounted

## Pixel-native curtain cut. Pose anchors/palette come from each source frame,
## so head bob, directions, sleep and fishing remain aligned with the face.
const FRONT: Array[String] = [
	"....DD.DD....",
	"..DDSS.SSDD..",
	".DSSMH.HMSSD.",
	"DSSMHDSDHMSSD",
	"DSMHHD.DHHMSD",
	"DSMHD...DHMSD",
	"DSMD.....DMSD",
	".DMD.....DMD.",
	"..D.......D..",
]
const BACK: Array[String] = [
	"....DDDDD....",
	"..DDSMMSSDD..",
	".DSMMHHHMMSD.",
	"DSMHHMSMHHMSD",
	"DSMHMSDSHMMSD",
	"DSMMSSSSSMMSD",
	".DSMSSSSSMSD.",
	"..DSSSSSSSD..",
	"...DDSSSDD...",
]
const SIDE: Array[String] = [
	"....DDDDD....",
	"..DDSMMSSDD..",
	".DSMMHHMMSSD.",
	"DSMHHMMSSMMSD",
	"DSMMSSDDHMMSD",
	"DSMMSSD.DMMSD",
	".DSSSD...DMSD",
	"..DSSD....DD.",
	"...DD........",
]

@warning_ignore_start("integer_division")
static func curtain(source: Image, directions: int) -> Image:
	var size := source.get_height()
	var count := source.get_width() / size
	var per_direction := maxi(count / maxi(directions, 1), 1)
	var output := Image.create_empty(source.get_width(), size, false, Image.FORMAT_RGBA8)
	var palette: Array[Color] = []
	for y in size:
		for x in source.get_width():
			var c := source.get_pixel(x, y)
			if c.a > 0 and not palette.has(c):
				palette.append(c)
	palette.sort_custom(func(a: Color, b: Color): return a.get_luminance() < b.get_luminance())
	if palette.is_empty():
		return source
	var shades := {
		"D": palette[0],
		"S": palette[mini(1, palette.size() - 1)],
		"M": palette[mini(2, palette.size() - 1)],
		"H": palette[mini(3, palette.size() - 1)],
	}
	for frame in count:
		var bounds := source.get_region(Rect2i(frame * size, 0, size, size)).get_used_rect()
		if bounds.size == Vector2i.ZERO:
			continue
		var direction := frame / per_direction if directions > 1 else 0
		var pattern: Array[String] = FRONT if direction == 0 else BACK if direction == 1 else SIDE
		var left := bounds.position.x + bounds.size.x / 2 - 6
		for y in pattern.size():
			for x in pattern[y].length():
				var key := pattern[y].substr(x, 1)
				if not shades.has(key):
					continue
				var px := left + (12 - x if direction == 3 else x)
				var py := bounds.position.y + y
				if px >= 0 and px < size and py < size:
					output.set_pixel(frame * size + px, py, shades[key])
	return output
@warning_ignore_restore("integer_division")
