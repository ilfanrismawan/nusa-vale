class_name Abilities
extends RefCounted
## Kemampuan gerak & tempur yang dipelajari di fakultas Universitas (bukan bawaan awal game).
## Status per karakter di PlayerData.abilities {id: true}. Save lama tanpa kunci "abilities"
## dianggap sudah menguasai semuanya supaya pemain lama tidak kehilangan kemampuan.

const JUMP := &"jump"
const DOUBLE_JUMP := &"double_jump"
const DODGE := &"dodge"
const GUARD := &"guard"
const PARRY := &"parry"
const WEAPON_ART := &"weapon_art"
const MAGIC := &"magic"

const FACULTY_SPORTS := "sports"
const FACULTY_MARTIAL := "martial"
const FACULTY_MAGIC := "magic"

const FACULTY_NAMES := {
	FACULTY_SPORTS: "Fakultas Olahraga",
	FACULTY_MARTIAL: "Fakultas Bela Diri",
	FACULTY_MAGIC: "Fakultas Sihir",
}

## Urutan = urutan kursus di tiap fakultas. requires: kemampuan sebelumnya; role: {role_id: level}.
const COURSES := [
	{"id": JUMP, "faculty": FACULTY_SPORTS, "title": "Lompat", "price": 200, "requires": &"", "role": {},
		"hint": "Tekan tombol lompat untuk melompat."},
	{"id": DODGE, "faculty": FACULTY_SPORTS, "title": "Guling Menghindar", "price": 600, "requires": JUMP, "role": {},
		"hint": "Sambil memegang senjata, tekan tombol dodge untuk berguling."},
	{"id": DOUBLE_JUMP, "faculty": FACULTY_SPORTS, "title": "Lompat Ganda", "price": 1500, "requires": DODGE, "role": {&"forager": 2},
		"hint": "Tekan lompat sekali lagi saat di udara."},
	{"id": GUARD, "faculty": FACULTY_MARTIAL, "title": "Bertahan (Block)", "price": 400, "requires": &"", "role": {},
		"hint": "Tahan tombol guard sambil memegang senjata untuk menahan serangan."},
	{"id": PARRY, "faculty": FACULTY_MARTIAL, "title": "Parry", "price": 1500, "requires": GUARD, "role": {&"combat": 2},
		"hint": "Tekan guard tepat sebelum serangan mengenai untuk menangkisnya."},
	{"id": WEAPON_ART, "faculty": FACULTY_MARTIAL, "title": "Jurus Senjata", "price": 4000, "requires": PARRY, "role": {&"combat": 4},
		"hint": "Tekan tombol weapon art untuk jurus khusus senjatamu."},
	{"id": MAGIC, "faculty": FACULTY_MAGIC, "title": "Dasar Sihir Tongkat", "price": 2500, "requires": &"", "role": {&"combat": 1},
		"hint": "Tongkat sihir kini bisa dipakai menyerang."},
]
const COURSE_MINUTES := 120


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for course in COURSES:
		result.append(course.id)
	return result


static func course(id: StringName) -> Dictionary:
	for entry in COURSES:
		if entry.id == id:
			return entry
	return {}


static func title(id: StringName) -> String:
	return str(course(id).get("title", id))


static func has(data: PlayerData, id: StringName) -> bool:
	return data != null and bool(data.abilities.get(String(id), false))


static func learn(data: PlayerData, id: StringName) -> void:
	data.abilities[String(id)] = true


static func grant_all(data: PlayerData) -> void:
	for id in ids():
		learn(data, id)


## Bila belum dipelajari: teks melayang singkat (dibatasi supaya tidak spam) lalu false.
static func check(player: Player, id: StringName) -> bool:
	if player == null or has(player.data, id):
		return true
	var now := Time.get_ticks_msec()
	if now - int(player.get_meta(&"ability_hint_ms", -100000)) > 1500:
		player.set_meta(&"ability_hint_ms", now)
		CombatJuice.float_text(player, "Belum dipelajari", Color(0.8, 0.8, 0.85))
		Notify.say("%s belum dipelajari. Ambil kursusnya di %s, Universitas." % [title(id), FACULTY_NAMES.get(course(id).get("faculty", ""), "Universitas")])
	return false


## Kursus berikutnya di fakultas ini yang belum dipelajari (kosong = semua selesai).
static func next_course(data: PlayerData, faculty: String) -> Dictionary:
	for entry in COURSES:
		if entry.faculty == faculty and not has(data, entry.id):
			return entry
	return {}


## Alasan kursus belum bisa diambil, kosong bila boleh.
static func blocker(data: PlayerData, entry: Dictionary) -> String:
	var needed: StringName = entry.requires
	if needed != &"" and not has(data, needed):
		return "Selesaikan dulu kursus %s." % title(needed)
	for role_id in entry.role:
		if data.skills.level(role_id) < int(entry.role[role_id]):
			return "Syarat: keahlian %s Lv %d." % [Campus.role_title(role_id), int(entry.role[role_id])]
	return ""


static func valid_save(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 64:
		return false
	for key in value:
		if not key is String or not value[key] is bool:
			return false
	return true


## Kunci tidak ada (save lama) = semua kemampuan sudah dikuasai.
static func load_save(data: PlayerData, saved: Dictionary, key: String = "abilities") -> void:
	data.abilities.clear()
	if not saved.has(key):
		grant_all(data)
		return
	var value: Variant = saved[key]
	if valid_save(value):
		for id in value:
			if StringName(id) in ids() and value[id]:
				data.abilities[id] = true
