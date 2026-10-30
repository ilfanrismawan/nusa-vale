class_name WildlifeData
extends Resource
## Satu jenis satwa liar (GDD 4.10.13). File: resources/wildlife/<id>.tres, dimuat WildlifeSpawner.
## Satwa liar hanya suasana: berkeliaran, kabur bila didekati, tidak disimpan, tidak diburu.
## Sheet dari assets/farm_rpg/animals/Forest. Baris sheet per arah ditulis [samping, bawah, atas].

@export var display_name := ""
## Ukuran sel sheet (px).
@export_enum("16:16", "32:32") var frame_size: int = 32
## Animasi jalan pelan.
@export var walk_sheet: Texture2D
@export var walk_rows := PackedInt32Array([0, 1, 2])
@export var walk_columns := PackedInt32Array([0, 1, 2, 3])
## Animasi diam. Kosong = walk_sheet.
@export var idle_sheet: Texture2D
@export var idle_rows := PackedInt32Array([0, 1, 2])
@export var idle_columns := PackedInt32Array([0, 1])
## Animasi kabur (lari/lompat). Kosong = walk_sheet. Bila run_speed 0, animasi ini dipakai
## untuk bersembunyi di tempat (kura-kura masuk cangkang).
@export var run_sheet: Texture2D
@export var run_rows := PackedInt32Array([0, 1, 2])
@export var run_columns := PackedInt32Array([0, 1, 2, 3])
## Baris samping menghadap kanan (default: kiri).
@export var faces_right := false
## Musim ("spring", "summer", "fall", "winter"). Kosong = sepanjang tahun.
@export var seasons: PackedStringArray = []
## Area, cocok dengan WildlifeSpawner.location_id ("forest", "deep_forest", "mountain").
@export var locations: PackedStringArray = []
## Waktu muncul: siang 06-18, malam 18-06, senja 05-08 dan 17-21.
@export_enum("any", "day", "night", "twilight") var time: String = "any"
## Bobot acak relatif; 1.0 = biasa, 0.3 = langka.
@export_range(0.01, 10.0, 0.01) var weight: float = 1.0
@export_range(2.0, 80.0, 1.0) var walk_speed: float = 12.0
## 0 = tidak lari; bersembunyi di tempat.
@export_range(0.0, 160.0, 1.0) var run_speed: float = 70.0
## Jarak (px) pemain berjalan yang membuatnya kabur; pemain berlari mengejutkan dari 2x jarak ini.
@export_range(8.0, 120.0, 1.0) var flee_radius: float = 40.0
## Burung: kabur dengan terbang menjauh ke atas, menembus rintangan, lalu menghilang.
@export var flies := false
## Makanan kesukaan (item_id). Pemain yang memegangnya tidak membuatnya kabur saat berjalan;
## satwa bisa diberi makan sekali (interaksi) dan setelah itu jinak. Kosong = tidak bisa diberi makan.
@export var favorite_foods: PackedStringArray = []
## Hadiah yang mungkin ditinggalkan beberapa detik setelah diberi makan (sekali per satwa).
## Kosong = tanpa hadiah.
@export var gift_item := ""
@export_range(0.0, 1.0, 0.05) var gift_chance: float = 0.0


static func time_matches(rule: String, hour: int) -> bool:
	match rule:
		"day":
			return hour >= 6 and hour < 18
		"night":
			return hour >= 18 or hour < 6
		"twilight":
			return (hour >= 5 and hour < 8) or (hour >= 17 and hour < 21)
	return true


func is_available(location_id: String, season: String, hour: int) -> bool:
	if walk_sheet == null or not locations.has(location_id):
		return false
	if not seasons.is_empty() and not seasons.has(season):
		return false
	return time_matches(time, hour)


## Animasi idle_/walk_/run_ + side/down/up. Dibangun sekali per Resource.
func frames() -> SpriteFrames:
	if has_meta(&"frames"):
		return get_meta(&"frames")
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	var specs := {
		"idle": [idle_sheet if idle_sheet != null else walk_sheet, idle_rows, idle_columns, 3.0],
		"walk": [walk_sheet, walk_rows, walk_columns, 7.0],
		"run": [run_sheet if run_sheet != null else walk_sheet, run_rows, run_columns, 12.0 if run_speed > 0 else 6.0],
	}
	var directions := ["side", "down", "up"]
	for action in specs:
		var spec: Array = specs[action]
		for d in directions.size():
			var anim := StringName("%s_%s" % [action, directions[d]])
			result.add_animation(anim)
			result.set_animation_speed(anim, spec[3])
			# Bersembunyi tidak berulang: berhenti di frame terakhir (di dalam cangkang).
			result.set_animation_loop(anim, not (action == "run" and run_speed <= 0))
			var rows: PackedInt32Array = spec[1]
			for column in spec[2]:
				var frame := AtlasTexture.new()
				frame.atlas = spec[0]
				frame.region = Rect2(column * frame_size, rows[mini(d, rows.size() - 1)] * frame_size, frame_size, frame_size)
				frame.filter_clip = true
				result.add_frame(anim, frame)
	set_meta(&"frames", result)
	return result
