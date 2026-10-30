class_name ServiceHours
extends RefCounted
## Jam buka bangunan layanan & rumah warga di Town. Pintu bangunan (TownBuildingDoor) terkunci
## di luar jam ini. Layanan yang dijaga NPC (Bima, Wira, Eep, Joko, Zarathia) tetap mengikuti
## aktivitas jadwal NPC-nya; tabel ini hanya untuk pintu dan papan informasi.

const DAY_IDS := ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
const DAY_NAMES := {"monday": "Senin", "tuesday": "Selasa", "wednesday": "Rabu", "thursday": "Kamis",
	"friday": "Jumat", "saturday": "Sabtu", "sunday": "Minggu"}

## id -> {name, open, close (jam, 24 = tengah malam), closed_days}
const SERVICES := {
	"shop": {"name": "Toko Umum", "open": 9, "close": 17, "closed_days": ["wednesday"]},
	"cookware_shop": {"name": "Toko Perabot Dapur", "open": 9, "close": 17, "closed_days": ["wednesday"]},
	"library": {"name": "Perpustakaan", "open": 9, "close": 18, "closed_days": ["monday"]},
	"clinic": {"name": "Klinik Ratih", "open": 8, "close": 16, "closed_days": ["wednesday"]},
	"warung": {"name": "Warung Rasa Nusa", "open": 7, "close": 21, "closed_days": []},
	"school": {"name": "Sekolah", "open": 7, "close": 17, "closed_days": ["sunday"]},
	"university": {"name": "Universitas", "open": 7, "close": 21, "closed_days": []},
	## Rumah warga (termasuk rumah & bengkel Bima): bisa bertamu 07.00–21.00.
	"house": {"name": "Rumah warga", "open": 7, "close": 21, "closed_days": []},
}

## Interior yang dihitung sebagai rumah warga.
const HOUSES := ["house_blue", "house_brick", "house_pink", "house_tall", "house_west", "herbal_house",
	"blacksmith", "ubay_home", "wira_home"]


static func weekday(day: int = -1) -> String:
	return DAY_IDS[posmod((DayCycle.current_day if day < 0 else day) - 1, 7)]


## id layanan dari scene tujuan pintu; kosong = tidak pernah dikunci.
static func service_for_scene(path: String) -> String:
	var id := path.get_file().get_basename()
	if id == "school_v2":
		return "school"
	if id in HOUSES:
		return "house"
	return id if SERVICES.has(id) else ""


static func is_open(id: String, hour: int = -1, day: int = -1) -> bool:
	var rules: Dictionary = SERVICES.get(id, {})
	if rules.is_empty():
		return true
	if weekday(day) in rules.closed_days:
		return false
	var now := DayCycle.hour if hour < 0 else hour
	return now >= int(rules.open) and now < int(rules.close)


static func hours_text(id: String) -> String:
	var rules: Dictionary = SERVICES.get(id, {})
	if rules.is_empty():
		return ""
	var text := "%02d.00–%02d.00" % [int(rules.open), int(rules.close)]
	if not rules.closed_days.is_empty():
		var days: PackedStringArray = []
		for day in rules.closed_days:
			days.append(DAY_NAMES.get(day, day))
		text += ", libur " + ", ".join(days)
	return text


static func closed_message(id: String) -> String:
	var rules: Dictionary = SERVICES.get(id, {})
	if id == "house":
		return "Pintunya terkunci. Penghuninya sedang beristirahat (bertamu %s)." % hours_text(id)
	return "%s sedang tutup. Buka %s." % [rules.get("name", "Tempat ini"), hours_text(id)]
