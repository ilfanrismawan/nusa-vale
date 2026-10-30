extends SceneTree

## Sprite SEMENTARA Progres Horor (GDD 4.1): Genderuwo dan Banaspati beserta wajah jumpscare
## (Tahap 2), ikon 16x16 barang gaib (Tahap 3–5), serta Sundel Bolong dan Leak (Tahap 5).
## Ganti dengan gambar Aseprite bila sudah ada (nama file sama). File yang sudah punya sumber
## .aseprite di sebelahnya tidak ditimpa (hantu dan wajah jumpscare kini digambar di Aseprite).
## Jalankan: Godot --headless --path . --script res://tools/generate_horror_placeholders.gd

const OUT := "res://assets/horror/"
const OUTLINE := Color8(14, 8, 6)


func _init() -> void:
	_save(_genderuwo_sheet(), "genderuwo.png")
	_save(_banaspati_sheet(), "banaspati.png")
	_save(_genderuwo_face(), "jumpscare_genderuwo.png")
	_save(_banaspati_face(), "jumpscare_banaspati.png")
	_save(_sundel_bolong(load_png("kuntilanak.png")), "sundel_bolong.png")
	_save(_sundel_bolong(load_png("jumpscare_kuntilanak.png")), "jumpscare_sundel_bolong.png")
	_save(_leak_sheet(), "leak.png")
	_save(_leak_face(), "jumpscare_leak.png")
	for id in ICONS:
		_save(_icon(ICONS[id]), "icons/%s.png" % id)
	quit()


func _save(image: Image, file: String) -> void:
	if FileAccess.file_exists(OUT + file.get_basename() + ".aseprite"):
		print("%s dilewati (ada sumber .aseprite)" % file)
		return
	var err := image.save_png(ProjectSettings.globalize_path(OUT + file))
	print("%s %s" % [file, "OK" if err == OK else "ERROR %d" % err])


# Pola acak tetap per piksel (tanpa RNG) agar hasil selalu sama.
func _noise(x: int, y: int, salt: int = 0) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	return float(posmod(h, 1000)) / 1000.0


func _in_ellipse(x: float, y: float, cx: float, cy: float, rx: float, ry: float) -> bool:
	var dx := (x - cx) / rx
	var dy := (y - cy) / ry
	return dx * dx + dy * dy <= 1.0


func _outline(image: Image, ox: int, oy: int, w: int, h: int) -> void:
	var marks: Array[Vector2i] = []
	for y in range(oy, oy + h):
		for x in range(ox, ox + w):
			if image.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= ox and n.y >= oy and n.x < ox + w and n.y < oy + h and image.get_pixelv(n).a > 0.0 and image.get_pixelv(n) != OUTLINE:
					marks.append(Vector2i(x, y))
					break
	for p in marks:
		image.set_pixelv(p, OUTLINE)


func _put(image: Image, x: int, y: int, c: Color, ox: int, oy: int, w: int, h: int) -> void:
	if x >= ox and y >= oy and x < ox + w and y < oy + h:
		image.set_pixel(x, y, c)


# ── Genderuwo: makhluk besar berbulu, bungkuk, lengan panjang, mata merah ────

const FUR_DARK := Color8(38, 24, 17)
const FUR_MID := Color8(58, 37, 24)
const FUR_LIGHT := Color8(82, 54, 33)
const FACE := Color8(28, 18, 13)
const EYE := Color8(255, 52, 30)
const FANG := Color8(232, 220, 192)


func _fur(x: int, y: int, top: float, frame: int) -> Color:
	var n := _noise(x, y, frame / 2)
	var light := 1.0 - clampf((float(y) - top) / 40.0, 0.0, 1.0)
	if n < 0.18 + light * 0.25:
		return FUR_LIGHT
	if n < 0.62:
		return FUR_MID
	return FUR_DARK


## 5 frame 32x48: 0–3 diam bernapas/berayun, 4 menerkam (lengan terangkat, mulut terbuka).
func _genderuwo_sheet() -> Image:
	var w := 32
	var h := 48
	var image := Image.create(w * 5, h, false, Image.FORMAT_RGBA8)
	for frame in 5:
		var ox := frame * w
		var lunge := frame == 4
		var breath: int = [0, 1, 1, 0][frame % 4] if not lunge else 0
		var sway: int = [0, 1, 0, -1][frame % 4] if not lunge else 0
		for y in h:
			for x in w:
				var fx := float(x) + 0.5
				var fy := float(y) + 0.5
				var shaggy := (_noise(x, y, 7) - 0.5) * 1.6
				var inside := false
				# Kaki pendek.
				if fy > 38.0 and fy < 47.0 and (absf(fx - 11.5) < 3.5 or absf(fx - 20.5) < 3.5):
					inside = true
				# Badan bungkuk lebar.
				if _in_ellipse(fx, fy, 16.0, 29.0 - breath * 0.5, 11.5 + shaggy, 12.0 + breath * 0.5):
					inside = true
				# Kepala kecil menjorok ke depan.
				if _in_ellipse(fx, fy, 16.0, 13.0 + breath, 6.0 + shaggy * 0.5, 6.0):
					inside = true
				# Lengan panjang menjuntai (atau terangkat saat menerkam).
				for side: float in [-1.0, 1.0]:
					var ax: float = 16.0 + side * 12.0
					if lunge:
						if absf(fx - (ax - side * 1.0)) < 2.6 + shaggy * 0.3 and fy > 6.0 and fy < 28.0:
							inside = true
					elif absf(fx - (ax + sway * side * 0.5)) < 2.6 + shaggy * 0.3 and fy > 20.0 and fy < 42.0 + breath:
						inside = true
				if inside:
					image.set_pixel(ox + x, y, _fur(x, y, 6.0, frame))
		# Wajah gelap + mata merah + taring.
		var fy0: int = 13 + breath
		for x in range(12, 21):
			for y in range(fy0 - 1, fy0 + 4):
				if _in_ellipse(x + 0.5, y + 0.5, 16.0, fy0 + 1.5, 4.6, 3.2):
					image.set_pixel(ox + x, y, FACE)
		for ex in [13, 18]:
			image.set_pixel(ox + ex, fy0, EYE)
			image.set_pixel(ox + ex + 1, fy0, EYE)
		if lunge:
			for x in range(14, 19):
				for y in range(fy0 + 2, fy0 + 5):
					image.set_pixel(ox + x, y, Color8(70, 8, 6))
			image.set_pixel(ox + 14, fy0 + 2, FANG)
			image.set_pixel(ox + 18, fy0 + 2, FANG)
			image.set_pixel(ox + 15, fy0 + 4, FANG)
			image.set_pixel(ox + 17, fy0 + 4, FANG)
		else:
			image.set_pixel(ox + 14, fy0 + 3, FANG)
			image.set_pixel(ox + 18, fy0 + 3, FANG)
		# Cakar.
		for side: int in [-1, 1]:
			var cx: int = 16 + side * 12
			var cy: int = 6 if lunge else 42 + breath
			for i in 3:
				_put(image, ox + cx - 1 + i, cy + (-1 if lunge else 1), FANG, ox, 0, w, h)
		_outline(image, ox, 0, w, h)
	return image


# ── Banaspati: bola api berwajah tengkorak ────────────────────────────────────

const FIRE_RED := Color8(200, 50, 30)
const FIRE_ORANGE := Color8(240, 122, 30)
const FIRE_YELLOW := Color8(255, 210, 60)
const FIRE_CORE := Color8(255, 242, 160)
const SOCKET := Color8(58, 10, 5)


## 5 frame 24x24: 0–3 api berkobar, 4 menyambar (mulut menganga).
func _banaspati_sheet() -> Image:
	var w := 24
	var h := 24
	var image := Image.create(w * 5, h, false, Image.FORMAT_RGBA8)
	for frame in 5:
		var ox := frame * w
		var phase := float(frame) * 1.7
		for y in h:
			for x in w:
				var fx := float(x) + 0.5
				var fy := float(y) + 0.5
				# Bola di bawah, lidah api meruncing ke atas dan bergoyang.
				var ball := _in_ellipse(fx, fy, 12.0, 16.0, 7.0, 6.5)
				var t := clampf((16.0 - fy) / 14.0, 0.0, 1.0)
				var flick := sin(fy * 0.9 + phase) * 1.6 * t + (_noise(x, y, frame) - 0.5) * 2.0 * t
				var tongue := fy > 2.0 and fy < 16.0 and absf(fx - 12.0 - flick) < 7.0 * (1.0 - t) + 0.6
				if not (ball or tongue):
					continue
				var depth := 1.0 - minf(1.0, Vector2((fx - 12.0) / 7.0, (fy - 15.0) / 8.0).length())
				var c := FIRE_RED
				if depth > 0.25:
					c = FIRE_ORANGE
				if depth > 0.5:
					c = FIRE_YELLOW
				if depth > 0.72:
					c = FIRE_CORE
				image.set_pixel(ox + x, y, c)
		# Wajah tengkorak.
		for ex in [9, 14]:
			for i in 2:
				for j in 2:
					image.set_pixel(ox + ex + i, 13 + j, SOCKET)
		if frame == 4:
			for x in range(10, 15):
				for y in range(17, 21):
					image.set_pixel(ox + x, y, SOCKET)
		else:
			for x in range(10, 15):
				image.set_pixel(ox + x, 18, SOCKET)
			image.set_pixel(ox + 11, 19, SOCKET)
			image.set_pixel(ox + 13, 19, SOCKET)
		_outline(image, ox, 0, w, h)
	return image


# ── Wajah jumpscare 64x64 ─────────────────────────────────────────────────────

func _genderuwo_face() -> Image:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var fx := float(x) + 0.5
			var fy := float(y) + 0.5
			var c := Color8(20, 6, 4)
			if _in_ellipse(fx, fy, 32.0, 34.0, 30.0 + (_noise(x, y, 3) - 0.5) * 4.0, 32.0):
				c = _fur(x / 2, y / 2, 0.0, 0)
			if _in_ellipse(fx, fy, 32.0, 36.0, 19.0, 17.0):
				c = FACE
			image.set_pixel(x, y, c)
	# Alis tebal, mata merah menyala, mulut bertaring.
	for side: int in [-1, 1]:
		var cx: int = 32 + side * 9
		for x in range(cx - 6, cx + 6):
			image.set_pixel(x, 25 + absi(x - cx) / 3, FUR_DARK)
			image.set_pixel(x, 26 + absi(x - cx) / 3, FUR_DARK)
		for y in range(28, 34):
			for x in range(cx - 4, cx + 4):
				if _in_ellipse(x + 0.5, y + 0.5, cx, 31.0, 4.0, 3.0):
					image.set_pixel(x, y, EYE)
		image.set_pixel(cx, 30, Color8(255, 230, 200))
	for y in range(40, 52):
		for x in range(20, 44):
			if _in_ellipse(x + 0.5, y + 0.5, 32.0, 45.0, 12.0, 6.0):
				image.set_pixel(x, y, Color8(70, 8, 6))
	for fx in [22, 27, 37, 42]:
		for i in 5:
			image.set_pixel(fx, 40 + i, FANG)
			image.set_pixel(fx + 1, 40 + i, FANG if i < 4 else Color8(70, 8, 6))
	for fx in [25, 31, 39]:
		for i in 3:
			image.set_pixel(fx, 50 - i, FANG)
	return image


func _banaspati_face() -> Image:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var fx := float(x) + 0.5
			var fy := float(y) + 0.5
			var d := Vector2((fx - 32.0) / 30.0, (fy - 36.0) / 30.0).length() + (_noise(x, y, 5) - 0.5) * 0.18
			var c := Color8(30, 4, 2)
			if d < 1.0:
				c = FIRE_RED
			if d < 0.78:
				c = FIRE_ORANGE
			if d < 0.55:
				c = FIRE_YELLOW
			if d < 0.32:
				c = FIRE_CORE
			image.set_pixel(x, y, c)
	for side: int in [-1, 1]:
		var cx: int = 32 + side * 10
		for y in range(26, 38):
			for x in range(cx - 6, cx + 6):
				if _in_ellipse(x + 0.5, y + 0.5, cx, 32.0, 6.0, 6.0):
					image.set_pixel(x, y, SOCKET)
		image.set_pixel(cx, 32, Color8(255, 255, 220))
	for y in range(40, 46):
		for x in range(29, 36):
			if absi(x - 32) <= (y - 40) / 2:
				image.set_pixel(x, y, SOCKET)
	for y in range(48, 58):
		for x in range(18, 47):
			if _in_ellipse(x + 0.5, y + 0.5, 32.0, 52.0, 14.0, 5.0):
				image.set_pixel(x, y, SOCKET if (x % 4) != 0 or y < 50 or y > 54 else FIRE_CORE)
	return image


# ── Ikon barang gaib 16x16 (Tahap 3) ──────────────────────────────────────────
# Satu huruf = satu warna; "." = transparan. Garis luar ditambahkan otomatis.

const ICON_PALETTE := {
	"w": Color8(246, 240, 214), "c": Color8(214, 200, 150), "y": Color8(250, 214, 80),
	"g": Color8(86, 140, 70), "b": Color8(150, 196, 230), "B": Color8(90, 140, 190),
	"v": Color8(196, 220, 236), "d": Color8(38, 24, 17), "m": Color8(58, 37, 24),
	"l": Color8(82, 54, 33), "r": Color8(200, 50, 30), "o": Color8(240, 122, 30),
	"Y": Color8(255, 242, 160), "s": Color8(170, 170, 176), "S": Color8(120, 120, 130),
	"k": Color8(120, 80, 40), "K": Color8(160, 110, 60), "R": Color8(150, 24, 24),
	"p": Color8(232, 214, 170), "t": Color8(150, 96, 60), "T": Color8(110, 68, 40),
}

const ICONS := {
	"bunga_kantil": [
		"................",
		"......ww........",
		".....wcw..ww....",
		".....wcw.wcw....",
		"..ww.wcwwcw.....",
		".wccwwyywcw.....",
		"..wcwyyyyw......",
		"...wwyyyyww.....",
		"..wccwyywccw....",
		".wcw.wwww..w....",
		"..w...gg........",
		"......gg........",
		"......g.gg......",
		".....g..ggg.....",
		".....g...g......",
		"................"],
	"embun_kubur": [
		"................",
		"......SSSS......",
		"......sccs......",
		".......ss.......",
		"......vvvv......",
		".....vbbbbv.....",
		"....vbbvbbbv....",
		"....vbvbbbbv....",
		"....vbbbbbBv....",
		"....vbbbbBBv....",
		"....vbbbBBBv....",
		".....vBBBBv.....",
		"......vvvv......",
		"................",
		"................",
		"................"],
	"bulu_genderuwo": [
		"................",
		"..........ll....",
		".........lml....",
		"........lmml....",
		".......lmmdl....",
		"......lmmdm.....",
		".....lmmdml.....",
		"....lmmdml......",
		"...lmmdml.......",
		"...lmdml........",
		"..lmdml.........",
		"..ldml..........",
		".lddl...........",
		".ld.............",
		"................",
		"................"],
	"bara_banaspati": [
		"................",
		".......r........",
		"......ror.......",
		"......ror..r....",
		"..r..rooor.r....",
		"..rr.roYorrr....",
		"...rroYYYoor....",
		"...roYYYYYor....",
		"...roYYwYYor....",
		"...rooYYYoor....",
		"....rooooor.....",
		".....rrrrr......",
		"....SSSSSSS.....",
		"...SsssssssS....",
		"....SSSSSSS.....",
		"................"],
	"kemenyan": [
		"......ss........",
		".....s..s.......",
		"......ss........",
		"........s.......",
		".......s........",
		"......ss........",
		".......o........",
		"......kKk.......",
		".....kKKKk......",
		"....kKKkKKk.....",
		"...kKkKKKkKk....",
		"..TTTTTTTTTTT...",
		"..TtttttttttT...",
		"...TTTTTTTTT....",
		"................",
		"................"],
	"jimat_penolak": [
		"......RR........",
		".....R..R.......",
		".....R..R.......",
		"......RR........",
		".....pppp.......",
		"....pppppp......",
		"....pRpppp......",
		"....pRRRpp......",
		"....ppRppp......",
		"....pRRRRp......",
		"....ppRppp......",
		"....pRpRpp......",
		"....pppppp......",
		".....pppp.......",
		"................",
		"................"],
	"sesajen_tuyul": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"....RR.RR.RR....",
		"...RkKRkRKkRR...",
		"..wKkKkKkKkKKw..",
		"..wwwwwwwwwwww..",
		"..wcccccccccccw.",
		"...wcccccccccw..",
		"....wcccccccw...",
		".....wwwwwww....",
		"....TTTTTTTT....",
		"................",
		"................"],
	"keris_pusaka": [
		"............Yy..",
		"...........yYy..",
		"..........yYy...",
		".........yYy....",
		"........ySy.....",
		".......yYy......",
		"......ySy.......",
		".....yYy........",
		"....RSR.........",
		"...RyyR.........",
		"..kKR...........",
		".kKk............",
		"kKk.............",
		"Kk..............",
		"................",
		"................"],
	"tugu_pagar_gaib": [
		"......RRRR......",
		".....RyyyyR.....",
		"......SSSS......",
		".....SssssS.....",
		".....SsRRsS.....",
		".....SsRRsS.....",
		".....SssssS.....",
		".....SsyysS.....",
		".....SssssS.....",
		".....SssssS.....",
		"....SSssssSS....",
		"...SSSSSSSSSS...",
		"...TTTTTTTTTT...",
		"..TTTTTTTTTTTT..",
		"................",
		"................"],
	"kayu_keramat": [
		"................",
		"................",
		"..........TT....",
		"........TTkT....",
		"......TTkTkT....",
		"....TTkTkTT.....",
		"...TkTkTTR......",
		"..TkTkTTRR......",
		"..TTkTTRR.......",
		"...TTTRR........",
		"....RR..........",
		"................",
		"................",
		"................",
		"................",
		"................"],
	"batu_keramat": [
		"................",
		"................",
		"................",
		"......SSSS......",
		".....SssssS.....",
		"....SssbssSS....",
		"...SssbbsssS....",
		"...SsssbsssS....",
		"...SsssssssS....",
		"...SSssssSSS....",
		"....SSSSSSS.....",
		"................",
		"................",
		"................",
		"................",
		"................"],
	"kristal_keramat": [
		"................",
		".......v........",
		"......vBv.......",
		".....vBRBv......",
		".....vRBRv......",
		"....vBRwRBv.....",
		"....vRBwBRv.....",
		"....vBRBRBv.....",
		".....vRBRv......",
		".....vBRBv......",
		"......vRv.......",
		".......v........",
		"................",
		"................",
		"................",
		"................"],
	"mustika_pemberani": [
		"................",
		".....RRRRRR.....",
		"....R......R....",
		"...R........R...",
		"...R........R...",
		"....R..yy..R....",
		".....yyYYyy.....",
		"....yYBBBBYy....",
		"....yBBvwBBy....",
		"....yBBBvBBy....",
		"....yYBBBBYy....",
		".....yyYYyy.....",
		".......yy.......",
		"................",
		"................",
		"................"],
	"wedang_kantil": [
		"......s..s......",
		".......s..s.....",
		"......s..s......",
		"................",
		"...wwwwwwwww....",
		"...wkoowkokw.ww.",
		"...wokkokkow..w.",
		"...wwwwwwwww..w.",
		"...wcccccccw.w..",
		"...wcccccccww...",
		"....wcccccw.....",
		".....wwwww......",
		"..ccccccccccc...",
		"...ccccccccc....",
		"................",
		"................"],
}


func _icon(rows: Array) -> Image:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in mini(row.length(), 16):
			var key := row[x]
			if ICON_PALETTE.has(key):
				image.set_pixel(x, y, ICON_PALETTE[key])
	_outline(image, 0, 0, 16, 16)
	return image


# ── Sundel Bolong (recolor Kuntilanak) dan Leak/Kuyang (Tahap 5) ─────────────

func load_png(file: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(OUT + file))
	image.convert(Image.FORMAT_RGBA8)
	return image


## Gaun putih jadi kelabu kehijauan; lubang merah gelap di punggung (sisi kiri tubuh).
func _sundel_bolong(image: Image) -> Image:
	var w := image.get_width()
	var h := image.get_height()
	var frame_w := 32 if h == 32 else w
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			if c.r > 0.6 and c.g > 0.6 and c.b > 0.6:
				image.set_pixel(x, y, Color(c.r * 0.72, c.g * 0.8, c.b * 0.7, c.a))
	if h == 32:
		for f in w / frame_w:
			for y in range(17, 23):
				for x in range(f * frame_w + 12, f * frame_w + 16):
					if image.get_pixel(x, y).a > 0.0 and _in_ellipse(x + 0.5, y + 0.5, f * frame_w + 14.0, 20.0, 2.2, 3.0):
						image.set_pixel(x, y, Color8(90, 8, 12))
	else:
		for y in h:
			for x in w:
				var c := image.get_pixel(x, y)
				if c.a > 0.0:
					image.set_pixel(x, y, Color(minf(1.0, c.r * 1.15), c.g * 0.82, c.b * 0.82, c.a))
	return image


const SKIN := Color8(214, 200, 176)
const HAIR := Color8(18, 14, 16)
const GUTS := Color8(160, 40, 52)
const GUTS_DARK := Color8(96, 18, 30)


## 5 frame 24x32: kepala melayang dengan isi perut menjuntai; frame 4 mulut menganga.
func _leak_sheet() -> Image:
	var w := 24
	var h := 32
	var image := Image.create(w * 5, h, false, Image.FORMAT_RGBA8)
	for frame in 5:
		var ox := frame * w
		var sway := sin(float(frame) * 1.6) * 1.5
		for y in h:
			for x in w:
				var fx := float(x) + 0.5
				var fy := float(y) + 0.5
				# Rambut panjang di belakang kepala.
				if _in_ellipse(fx, fy, 12.0, 10.0, 7.5, 8.0) and fy < 15.0:
					image.set_pixel(ox + x, y, HAIR)
				if _in_ellipse(fx, fy, 12.0, 10.5, 5.0, 5.5):
					image.set_pixel(ox + x, y, SKIN)
				# Isi perut menjuntai dan bergoyang.
				if fy > 15.0 and fy < 30.0:
					var t := (fy - 15.0) / 15.0
					for strand in [-3.5, 0.0, 3.5]:
						var cx: float = 12.0 + float(strand) * (1.0 - t * 0.4) + sin(fy * 0.6 + float(frame) + float(strand)) * sway * t
						if absf(fx - cx) < 0.6 + (1.0 - t) * 0.4:
							image.set_pixel(ox + x, y, GUTS if int(fy) % 3 else GUTS_DARK)
		# Rambut menutup dahi, mata merah, mulut.
		for x in range(8, 16):
			image.set_pixel(ox + x, 6, HAIR)
			image.set_pixel(ox + x, 7, HAIR if x % 2 == 0 else SKIN)
		image.set_pixel(ox + 10, 10, EYE)
		image.set_pixel(ox + 14, 10, EYE)
		if frame == 4:
			for x in range(10, 15):
				for y in range(12, 15):
					image.set_pixel(ox + x, y, SOCKET)
		else:
			for x in range(11, 14):
				image.set_pixel(ox + x, 13, SOCKET)
		_outline(image, ox, 0, w, h)
	return image


func _leak_face() -> Image:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var fx := float(x) + 0.5
			var fy := float(y) + 0.5
			var c := Color8(12, 4, 6)
			if _in_ellipse(fx, fy, 32.0, 30.0, 28.0, 30.0):
				c = HAIR
			if _in_ellipse(fx, fy, 32.0, 34.0, 18.0, 22.0):
				c = SKIN.darkened(_noise(x, y, 9) * 0.12)
			if fy > 54.0 and absf(fx - 32.0 - sin(fy) * 3.0) < 6.0:
				c = GUTS if int(fy) % 3 else GUTS_DARK
			image.set_pixel(x, y, c)
	for x in range(14, 50):
		for y in range(14, 22 + absi(x - 32) / 4):
			if _in_ellipse(x + 0.5, y + 0.5, 32.0, 30.0, 28.0, 30.0):
				image.set_pixel(x, y, HAIR)
	for side: int in [-1, 1]:
		var cx: int = 32 + side * 8
		for y in range(28, 34):
			for x in range(cx - 4, cx + 4):
				if _in_ellipse(x + 0.5, y + 0.5, cx, 31.0, 4.0, 2.6):
					image.set_pixel(x, y, EYE)
		image.set_pixel(cx, 31, Color8(20, 0, 0))
	for y in range(40, 52):
		for x in range(24, 41):
			if _in_ellipse(x + 0.5, y + 0.5, 32.0, 46.0, 8.0, 6.0):
				image.set_pixel(x, y, SOCKET)
	for fx in [27, 31, 35]:
		image.set_pixel(fx, 41, FANG)
		image.set_pixel(fx, 42, FANG)
	return image
