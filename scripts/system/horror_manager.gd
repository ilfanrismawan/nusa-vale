class_name HorrorManager
extends Node

## Progres Horor & Kesulitan Gaib (GDD 4.1), dipegang GameState.horror.
## - Tingkat Gaib 1–4 dihitung dari progres yang sudah tersimpan (gua, hari, unlock area).
## - Kesulitan Gaib milik save (save v27); opsi aksesibilitas berlaku untuk semua save
##   (user://settings.cfg, bagian "horror").

signal difficulty_changed(difficulty: HorrorDifficulty)
signal accessibility_changed
signal journal_changed

@export_group("Progres Horor")
@export var profiles: Array[HorrorProfile] = []
## Urutan tampil di Pengaturan.
@export var difficulties: Array[HorrorDifficulty] = []
const DEFAULT_DIFFICULTY := &"normal"
const SETTINGS_PATH := "user://settings.cfg"

enum Jumpscare { FULL, NO_FACE, OFF }

var difficulty_id: StringName = DEFAULT_DIFFICULTY
## Tingkat tertinggi yang pesannya sudah disampaikan (agar pesan pagi muncul sekali).
var notified_tier: int = 1
## Penunggu Area di Catatan Gaib (Tahap 6): ghost_id -> nama (altar di Hutan Dalam, Gunung, Gua).
const PENUNGGU := {"penunggu_hutan": "Penunggu Hutan Dalam", "penunggu_gunung": "Penunggu Gunung", "penunggu_gua": "Penunggu Gua"}

## Makhluk di Catatan Gaib (ghost_id NightStalker di katalog NightHorror; tes memeriksa kecocokannya).
const JOURNAL_GHOSTS := ["kuntilanak", "pocong", "genderuwo", "banaspati", "sundel_bolong", "leak"]
## Hadiah sekali per save saat Catatan Gaib lengkap (keputusan pemilik: tanpa Balai Nadi).
const JOURNAL_REWARD := "mustika_pemberani"

## Catatan Gaib: ghost_id -> berapa kali pemain selamat darinya (per save, Tahap 3).
var journal: Dictionary = {}
## Hadiah Catatan Gaib lengkap sudah diterima.
var journal_rewarded: bool = false
## Tuyul (Tahap 4): hari farm terakhir Tuyul mencuri (malam setelah 00.00 masih hari yang sama)
## dan laporan untuk pagi berikutnya. Disimpan agar tidak mencuri dua kali setelah load.
var theft_day: int = 0
var theft_report: String = ""
## Ritual Penunggu (Tahap 6): area -> hari farm ritual terakhir berhasil (sekali per malam per area).
var ritual_day: Dictionary = {}
## Debug: paksa Malam Jumat Kliwon (tidak disimpan).
var forced_kliwon: bool = false
## Debug: paksa tingkat (0 = ikut progres). Tidak disimpan.
var forced_tier: int = 0

## Aksesibilitas (global, bukan per save).
var jumpscare_mode: Jumpscare = Jumpscare.FULL
## Grain, aberration, glitch, dan guncangan kamera horor.
var screen_effects: bool = true


func _ready() -> void:
	load_accessibility()
	DayCycle.day_passed.connect(_on_day_passed)


func _exit_tree() -> void:
	HorrorSynth.clear_cache()


func reset() -> void:
	difficulty_id = DEFAULT_DIFFICULTY
	notified_tier = 1
	forced_tier = 0
	journal.clear()
	journal_rewarded = false
	theft_day = 0
	theft_report = ""
	ritual_day.clear()
	forced_kliwon = false
	difficulty_changed.emit(difficulty())
	journal_changed.emit()


# ── Tingkat Gaib ─────────────────────────────────────────────────────────────

func tier() -> int:
	if forced_tier > 0:
		return clampi(forced_tier, 1, profiles.size())
	var deepest := GameState.cave.deepest_floor if GameState.cave != null else 0
	var reached := 1
	for profile in profiles:
		if profile.is_reached(deepest, DayCycle.current_day, UnlockManager.is_unlocked):
			reached = maxi(reached, profile.tier)
	return reached


## Profil malam ini: Tingkat Gaib, kecuali Malam Jumat Kliwon yang memakai tingkat 4.
func profile() -> HorrorProfile:
	return profile_for(night_tier())


## Tingkat yang berlaku malam ini (Malam Jumat Kliwon = 4 bila progres sudah tingkat 2+).
func night_tier() -> int:
	var progress := tier()
	return profiles.size() if is_kliwon() and progress >= 2 else progress


# ── Malam Jumat Kliwon (Tahap 6, versi sederhana) ────────────────────────────
## Kamis (hari ke-4 dalam minggu, hari 1 = Senin) pada minggu ke-4 tiap musim: hari 25 musim.
## Malam hari farm itu (sampai sebelum tidur, termasuk lewat 00.00) semua makhluk tingkat 4 aktif,
## kejadian ganjil lebih sering, dan hadiah material malam ×2.
@export_range(0, 6) var kliwon_weekday: int = 3
@export_range(1, 28) var kliwon_from_day: int = 22


func is_kliwon(day: int = DayCycle.current_day) -> bool:
	if forced_kliwon and day == DayCycle.current_day:
		return true
	var in_season := ((day - 1) % DayCycle.DAYS_PER_SEASON) + 1
	return (day - 1) % 7 == kliwon_weekday and in_season >= kliwon_from_day


func _announce_kliwon() -> void:
	if tier() < 2 or difficulty().ambience_only:
		return
	if is_kliwon(DayCycle.current_day + 1):
		Notify.say("Mbah Darmi berpesan: \"Besok malam Jumat Kliwon. Jangan keluyuran lewat tengah malam kalau tak siap.\"")
	elif is_kliwon():
		Notify.say("Malam ini malam Jumat Kliwon. Semua penunggu keluar, tapi yang berani pulang membawa hadiah dua kali lipat.")


func profile_for(value: int) -> HorrorProfile:
	for p in profiles:
		if p.tier == value:
			return p
	return profiles[0]


## Pesan pagi: laporan Tuyul semalam, pengumuman Malam Jumat Kliwon, lalu tingkat baru yang
## pertama kali tercapai.
func _on_day_passed(_day: int) -> void:
	if not theft_report.is_empty():
		Notify.say(theft_report)
		theft_report = ""
	_announce_kliwon()
	try_journal_reward()
	if forced_tier > 0:
		return
	var now := tier()
	if now <= notified_tier:
		return
	var text := profile_for(now).notify_reached
	notified_tier = now
	if not text.is_empty():
		Notify.say(text)


# ── Kesulitan Gaib (per save) ────────────────────────────────────────────────

func difficulty() -> HorrorDifficulty:
	return difficulty_by_id(difficulty_id)


func difficulty_by_id(id: StringName) -> HorrorDifficulty:
	for d in difficulties:
		if d.id == id:
			return d
	for d in difficulties:
		if d.id == DEFAULT_DIFFICULTY:
			return d
	return difficulties[0]


func set_difficulty(id: StringName) -> void:
	var d := difficulty_by_id(id)
	if d.id == difficulty_id:
		return
	difficulty_id = d.id
	difficulty_changed.emit(d)


func is_ambience_only() -> bool:
	return difficulty().ambience_only


# ── Catatan Gaib (per save) ──────────────────────────────────────────────────

## Catat pemain selamat dari makhluk ini. Entri baru diumumkan sekali; entri terakhir yang
## melengkapi Catatan Gaib memberi hadiah ke recipient (null = pemain utama).
func record_survival(ghost_id: StringName, display_name: String, recipient: PlayerData = null) -> void:
	var key := String(ghost_id)
	var first := not journal.has(key)
	journal[key] = int(journal.get(key, 0)) + 1
	if first:
		Notify.say("Catatan Gaib baru: %s. Lihat Tas > Pengaturan > Horor." % display_name)
	journal_changed.emit()
	try_journal_reward(recipient)


func journal_total() -> int:
	return JOURNAL_GHOSTS.size() + PENUNGGU.size()


func journal_known() -> int:
	var known := 0
	for id in JOURNAL_GHOSTS + PENUNGGU.keys():
		if survived_count(StringName(id)) > 0:
			known += 1
	return known


## Beri hadiah Catatan Gaib lengkap sekali. Tas penuh: dicoba lagi tiap pagi.
func try_journal_reward(recipient: PlayerData = null) -> bool:
	if journal_rewarded or journal_known() < journal_total():
		return false
	if recipient == null:
		recipient = GameState.p1()
	if recipient == null or recipient.add_item(JOURNAL_REWARD, 1) > 0:
		Notify.say("Catatan Gaib lengkap! Kosongkan satu slot tas untuk menerima hadiahnya besok pagi.")
		return false
	journal_rewarded = true
	Notify.say("Catatan Gaib lengkap! Sesepuh desa menghadiahkan Mustika Pemberani.")
	return true


func survived_count(ghost_id: StringName) -> int:
	return int(journal.get(String(ghost_id), 0))


# ── Tuyul (Tahap 4) ──────────────────────────────────────────────────────────
## Batas curian Normal; dikali theft_scale Kesulitan Gaib (Tenang 0 = tidak mencuri).
@export_range(0.0, 1.0) var tuyul_money_share: float = 0.05
@export_range(0, 100000) var tuyul_value_cap: int = 500
## Mulai jam ini (dini hari, hari farm yang sama) pemain di luar ruangan mengundang Tuyul.
@export_range(0, 5) var tuyul_from_hour: int = 1


## Dipanggil NightHorror selama pemain di luar ruangan. Sekali per hari farm: Tuyul mengambil
## satu baris Shipping Bin (nilai maksimal tuyul_value_cap) atau 5% uang (maksimal tuyul_value_cap).
## Sesajen Penangkal Tuyul di farm mencegahnya. Mengembalikan teks laporan ("" = tidak mencuri).
func try_tuyul(rng: RandomNumberGenerator = null) -> String:
	if theft_day == DayCycle.current_day or DayCycle.hour < tuyul_from_hour or DayCycle.hour >= 6:
		return ""
	var d := difficulty()
	if tier() < 2 or d.ambience_only or d.theft_scale <= 0.0:
		return ""
	theft_day = DayCycle.current_day
	if has_tuyul_ward():
		return ""
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var cap := roundi(tuyul_value_cap * d.theft_scale)
	var pending: Array = GameState.shipping.pending
	# Barang yang satu buahnya saja melebihi batas nilai tidak bisa dibawa Tuyul.
	var stealable := pending.filter(func(row: Dictionary) -> bool: return maxi(1, int(row.price)) <= cap)
	if not stealable.is_empty() and (rng.randf() < 0.5 or GameState.money < 20):
		var row: Dictionary = stealable[rng.randi_range(0, stealable.size() - 1)]
		var price := maxi(1, int(row.price))
		var count := mini(int(row.count), floori(float(cap) / price))
		row.count = int(row.count) - count
		if row.count <= 0:
			pending.erase(row)
		theft_report = "Pagi ini ada jejak kaki kecil di dekat Shipping Bin. Tuyul mengambil %d %s." % [count, row.name]
	else:
		var amount := mini(roundi(GameState.money * tuyul_money_share * d.theft_scale), cap)
		if amount <= 0:
			theft_report = "Pagi ini ada jejak kaki kecil di dekat Shipping Bin, tetapi Tuyul pulang dengan tangan kosong."
		else:
			GameState.spend_money(amount)
			theft_report = "Pagi ini ada jejak kaki kecil di dekat Shipping Bin. Tuyul mencuri %d G." % amount
	Notify.say("Terdengar gemerincing koin dari arah farm...")
	for bin in get_tree().get_nodes_in_group(&"shipping_bin"):
		TuyulTracks.attach(bin)
	return theft_report


## Sesajen Penangkal Tuyul atau Tugu Pagar Gaib terpasang di mana pun di farm.
func has_tuyul_ward() -> bool:
	for record in StructureManager.records:
		if record.get("item") in ["sesajen_tuyul", "tugu_pagar_gaib"]:
			return true
	return false


# ── Ritual Penunggu (Tahap 6) ────────────────────────────────────────────────

func ritual_done_tonight(area: String) -> bool:
	return int(ritual_day.get(area, 0)) == DayCycle.current_day


func mark_ritual(area: String) -> void:
	ritual_day[area] = DayCycle.current_day


## Tugu Pagar Gaib (Tahap 5): farm aman dari makhluk dan Tuyul.
func has_farm_ward() -> bool:
	for record in StructureManager.records:
		if record.get("item") == "tugu_pagar_gaib":
			return true
	return false


## Jejak terlihat pada malam pencurian dan pagi berikutnya sampai 12.00.
func tracks_visible() -> bool:
	if theft_day <= 0:
		return false
	if DayCycle.current_day == theft_day:
		return DayCycle.hour < 6
	return DayCycle.current_day == theft_day + 1 and DayCycle.hour < 12


# ── Aksesibilitas (global) ───────────────────────────────────────────────────

func set_jumpscare_mode(mode: int) -> void:
	jumpscare_mode = clampi(mode, Jumpscare.FULL, Jumpscare.OFF) as Jumpscare
	save_accessibility()
	accessibility_changed.emit()


func set_screen_effects(value: bool) -> void:
	screen_effects = value
	save_accessibility()
	accessibility_changed.emit()


func load_accessibility() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	jumpscare_mode = clampi(int(config.get_value("horror", "jumpscare", Jumpscare.FULL)), Jumpscare.FULL, Jumpscare.OFF) as Jumpscare
	screen_effects = bool(config.get_value("horror", "screen_effects", true))


## Ditulis ke bagian "horror" saja; pengaturan lain di file yang sama dipertahankan.
func save_accessibility() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	write_accessibility(config)
	config.save(SETTINGS_PATH)


func write_accessibility(config: ConfigFile) -> void:
	config.set_value("horror", "jumpscare", int(jumpscare_mode))
	config.set_value("horror", "screen_effects", screen_effects)


# ── Save (v27) ───────────────────────────────────────────────────────────────

func to_save() -> Dictionary:
	return {"difficulty": String(difficulty_id), "notified_tier": notified_tier, "journal": journal.duplicate(), "theft_day": theft_day, "theft_report": theft_report, "ritual_day": ritual_day.duplicate(), "journal_rewarded": journal_rewarded}


static func valid_save(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.has("difficulty") and not data["difficulty"] is String:
		return false
	if data.has("notified_tier") and not (data["notified_tier"] is int or data["notified_tier"] is float):
		return false
	if data.has("theft_day") and not (data["theft_day"] is int or data["theft_day"] is float):
		return false
	if data.has("theft_report") and not data["theft_report"] is String:
		return false
	if data.has("journal_rewarded") and not data["journal_rewarded"] is bool:
		return false
	if data.has("ritual_day"):
		if not data["ritual_day"] is Dictionary:
			return false
		for value in data["ritual_day"].values():
			if not (value is int or value is float):
				return false
	if data.has("journal"):
		if not data["journal"] is Dictionary:
			return false
		for value in data["journal"].values():
			if not (value is int or value is float) or value < 0:
				return false
	return true


## Dipanggil setelah gua, hari, dan unlock dimuat. Save v26 ke bawah: Normal, dan tingkat
## yang sudah tercapai dianggap sudah diumumkan (tanpa pesan susulan).
func load_save(data: Variant) -> void:
	forced_tier = 0
	var entry: Dictionary = data if data is Dictionary else {}
	difficulty_id = difficulty_by_id(StringName(str(entry.get("difficulty", DEFAULT_DIFFICULTY)))).id
	notified_tier = clampi(int(entry.get("notified_tier", tier())), 1, profiles.size())
	# Tuyul (opsional, tanpa naik versi save).
	theft_day = maxi(0, int(entry.get("theft_day", 0)))
	theft_report = str(entry.get("theft_report", ""))
	journal_rewarded = bool(entry.get("journal_rewarded", false))
	# Ritual Penunggu (opsional, tanpa naik versi save).
	ritual_day.clear()
	var saved_rituals: Variant = entry.get("ritual_day", {})
	if saved_rituals is Dictionary:
		for key in saved_rituals:
			ritual_day[str(key)] = int(saved_rituals[key])
	# Catatan Gaib (opsional, tanpa naik versi save): save tanpa key ini mulai kosong.
	journal.clear()
	var saved_journal: Variant = entry.get("journal", {})
	if saved_journal is Dictionary:
		for key in saved_journal:
			journal[str(key)] = maxi(0, int(saved_journal[key]))
	difficulty_changed.emit(difficulty())
	journal_changed.emit()
