class_name CalendarEvents
extends RefCounted
## Data acara kalender (tab Kalender di buku inventory). Semua dihitung dari data yang sudah ada:
## ulang tahun warga (NPCDatabase), ulang tahun pemain (PlayerData), Malam Jumat Kliwon
## (HorrorManager) dan hari tutup layanan (ServiceHours). Tidak ada state yang disimpan.
##
## Hari absolut = DayCycle.current_day (1 = Senin, 1 Semi tahun 1). Satu musim 28 hari = 4 pekan,
## jadi tanggal 1 tiap musim selalu Senin.

const KIND_PLAYER_BIRTHDAY := "player_birthday"
const KIND_BIRTHDAY := "birthday"
const KIND_KLIWON := "kliwon"

const SEASON_NAMES := ["Musim Semi", "Musim Panas", "Musim Gugur", "Musim Dingin"]
const WEEKDAY_SHORT := ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"]


static func days_per_year() -> int:
	return DayCycle.DAYS_PER_SEASON * DayCycle.SEASONS.size()


## Indeks musim berjalan sejak awal permainan: 0 = Semi tahun 1, 4 = Semi tahun 2, dst.
@warning_ignore("integer_division")
static func season_serial(abs_day: int) -> int:
	return (maxi(abs_day, 1) - 1) / DayCycle.DAYS_PER_SEASON


static func first_day_of(serial: int) -> int:
	return maxi(serial, 0) * DayCycle.DAYS_PER_SEASON + 1


static func season_of(abs_day: int) -> int:
	return season_serial(abs_day) % DayCycle.SEASONS.size()


@warning_ignore("integer_division")
static func year_of(abs_day: int) -> int:
	return season_serial(abs_day) / DayCycle.SEASONS.size() + 1


static func day_of_season(abs_day: int) -> int:
	return (maxi(abs_day, 1) - 1) % DayCycle.DAYS_PER_SEASON + 1


static func weekday_index(abs_day: int) -> int:
	return posmod(abs_day - 1, 7)


static func weekday_name(abs_day: int) -> String:
	return ServiceHours.DAY_NAMES[ServiceHours.DAY_IDS[weekday_index(abs_day)]]


static func date_text(abs_day: int) -> String:
	return "%s, %d %s" % [weekday_name(abs_day), day_of_season(abs_day), SEASON_NAMES[season_of(abs_day)]]


## Semua warga yang punya ulang tahun tercatat: [{id, name, season, day}], urut nama.
static func resident_birthdays() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	for source: Dictionary in [NPCDatabase.residents, NPCDatabase.gift_profiles]:
		for id: String in source:
			if seen.has(id):
				continue
			seen[id] = true
			var birthday := NPCSocialService.birthday_of(id)
			if birthday.is_empty():
				continue
			var definition := NPCDatabase.social_definition(id)
			result.append({"id": id, "name": str(definition.get("name", id.capitalize())), "season": birthday.season, "day": birthday.day})
	result.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return result


## Malam Jumat Kliwon hanya ditampilkan bila pemain sudah mengenalnya (pengumuman Mbah Darmi
## aktif mulai tingkat gaib 2 dan bukan mode suasana saja).
static func kliwon_known() -> bool:
	var horror: HorrorManager = GameState.horror if GameState != null else null
	if horror == null:
		return false
	var difficulty := horror.difficulty()
	return horror.tier() >= 2 and (difficulty == null or not difficulty.ambience_only)


static func is_kliwon(abs_day: int) -> bool:
	return GameState != null and GameState.horror != null and GameState.horror.is_kliwon(abs_day)


## Acara pada satu hari absolut, urut tampil: ulang tahun pemain, ulang tahun warga, Kliwon.
## `birthdays` boleh diisi hasil resident_birthdays() agar tidak dihitung ulang per sel.
static func events_for(data: PlayerData, abs_day: int, birthdays: Array[Dictionary] = [], show_kliwon := true) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var season := DayCycle.SEASONS[season_of(abs_day)]
	var day := day_of_season(abs_day)
	if data != null and data.birthday_season == season and data.birthday_day == day:
		events.append({"kind": KIND_PLAYER_BIRTHDAY, "title": "Ulang tahunmu", "detail": "Selamat ulang tahun, %s!" % (data.player_name if not data.player_name.is_empty() else "Petani")})
	if birthdays.is_empty():
		birthdays = resident_birthdays()
	for entry in birthdays:
		if entry.season == season and int(entry.day) == day:
			events.append({"kind": KIND_BIRTHDAY, "id": entry.id, "title": "Ulang tahun %s" % entry.name, "detail": "Hadiah hari ini bernilai 8× poin dan tidak memakai jatah pekanan."})
	if show_kliwon and is_kliwon(abs_day):
		events.append({"kind": KIND_KLIWON, "title": "Malam Jumat Kliwon", "detail": "Semua penunggu keluar malam ini; hadiah material malam ×2."})
	return events


## Nama layanan yang tutup seharian pada hari itu (dari ServiceHours).
static func closed_services(abs_day: int) -> PackedStringArray:
	var names: PackedStringArray = []
	var weekday_id: String = ServiceHours.DAY_IDS[weekday_index(abs_day)]
	for id: String in ServiceHours.SERVICES:
		var rules: Dictionary = ServiceHours.SERVICES[id]
		if weekday_id in rules.closed_days:
			names.append(str(rules.name))
	return names


## Acara mulai `from_day` (termasuk) sampai `span` hari ke depan: [{day, event}], maksimal `limit`.
static func upcoming(data: PlayerData, from_day: int, span := 28, limit := 5) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var birthdays := resident_birthdays()
	var show_kliwon := kliwon_known()
	for offset in span:
		for event in events_for(data, from_day + offset, birthdays, show_kliwon):
			result.append({"day": from_day + offset, "event": event})
			if result.size() >= limit:
				return result
	return result
