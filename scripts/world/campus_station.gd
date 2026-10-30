class_name CampusStation
extends StaticBody2D

## Perabot Sekolah/Universitas yang punya fungsi (lihat Campus untuk angka & state).
## Tindakan berbayar atau yang memakan stamina/waktu minta tekan sekali lagi untuk konfirmasi.

@export_enum("lecture", "library_read", "self_study", "market_pc", "student_card", "shop",
	"exam", "database", "lab", "rest", "lesson", "guest_teacher", "school_request") var station := "library_read"
## Untuk library_read: role EXP rak ini. Kosong = topik hari ini.
@export var role_id: StringName = &""
## Untuk shop.
@export var shop_data: ShopData
## Kunci batas harian bersama (mis. semua rak satu perpustakaan). Kosong = nama station.
@export var usage_key := ""
## Teks suasana sebelum keterangan fungsi.
@export_multiline var message := ""

const CONFIRM_MSEC := 4000

var _pending_player: Player
var _pending_until := 0
var _shop_ui: ShopUI


func _ready() -> void:
	set_meta("player_interaction", true)


func interact(player: Player = null) -> void:
	if player == null:
		player = RoomDoor.player()
	if player == null or player.is_input_locked() or is_instance_valid(_shop_ui):
		return
	call("_" + station, player, player.data)


func _key() -> String:
	return usage_key if not usage_key.is_empty() else station


func _say(text: String) -> void:
	Notify.say(text if message.is_empty() else "%s\n%s" % [message, text])


## true bila pemain ini sudah menekan sekali dalam CONFIRM_MSEC; selain itu tampilkan tawaran.
func _confirmed(player: Player, offer: String) -> bool:
	if _pending_player == player and Time.get_ticks_msec() <= _pending_until:
		_pending_player = null
		return true
	_pending_player = player
	_pending_until = Time.get_ticks_msec() + CONFIRM_MSEC
	_say(offer + " Tekan lagi untuk lanjut.")
	return false


# ── Universitas ─────────────────────────────────────────────────────

func _lecture(player: Player, data: PlayerData) -> void:
	var role := Campus.topic_role()
	var topic: String = Campus.DAILY_TOPICS.get(role, "")
	if DayCycle.hour < Campus.LECTURE_OPEN_HOUR or DayCycle.hour >= Campus.LECTURE_CLOSE_HOUR:
		_say("Kuliah umum hari ini: %s\nKelas dibuka %02d.00–%02d.00." % [topic, Campus.LECTURE_OPEN_HOUR, Campus.LECTURE_CLOSE_HOUR])
		return
	if Campus.used_today(data, _key()):
		_say("Kamu sudah mengikuti kuliah hari ini. Topik besok berbeda.")
		return
	var fee := Campus.lecture_fee(data)
	if not _confirmed(player, "Kuliah umum: %s\nBiaya %d G, 2 jam, +%d EXP %s." % [topic, fee, Campus.LECTURE_EXP, Campus.role_title(role)]):
		return
	if not GameState.spend_money(fee):
		_say("Uangmu belum cukup untuk biaya kuliah (%d G)." % fee)
		return
	Campus.mark_used(data, _key())
	DayCycle.advance_minute(Campus.LECTURE_MINUTES)
	Notify.say("Kuliah selesai: +%d EXP %s." % [Campus.LECTURE_EXP, Campus.role_title(role)])
	SkillSystem.gain(data, role, Campus.LECTURE_EXP)


func _library_read(_player: Player, data: PlayerData) -> void:
	var role := role_id if role_id != &"" else Campus.topic_role()
	if Campus.used_today(data, _key()):
		_say("Kamu sudah membaca di sini hari ini. Datang lagi besok.")
		return
	var amount := Campus.SCHOOL_READ_EXP if _key().begins_with("school") else Campus.READ_EXP
	Campus.mark_used(data, _key())
	_say("Kamu membaca sebentar: +%d EXP %s." % [amount, Campus.role_title(role)])
	SkillSystem.gain(data, role, amount)


func _self_study(player: Player, data: PlayerData) -> void:
	if Campus.used_today(data, _key()):
		_say("Kepalamu sudah penuh. Belajar mandiri lagi besok.")
		return
	var role := Campus.weakest_role(data)
	if not _confirmed(player, "Belajar mandiri (%d stamina): +%d EXP %s, keahlian yang paling tertinggal." % [Campus.STUDY_STAMINA, Campus.STUDY_EXP, Campus.role_title(role)]):
		return
	if data.stamina < Campus.STUDY_STAMINA:
		_say("Kamu terlalu lelah untuk belajar.")
		return
	data.stamina -= Campus.STUDY_STAMINA
	Campus.mark_used(data, _key())
	_say("Catatanmu rapi: +%d EXP %s." % [Campus.STUDY_EXP, Campus.role_title(role)])
	SkillSystem.gain(data, role, Campus.STUDY_EXP)


## Informasi harga: tiga barang di tas dengan nilai kirim tertinggi.
func _market_pc(_player: Player, data: PlayerData) -> void:
	var rows: Array = []
	var seen := {}
	for slot in data.bag_size:
		var entry: Variant = data.inventory[slot]
		if entry == null or seen.has(entry["item"].item_id):
			continue
		var item: ItemData = entry["item"]
		seen[item.item_id] = true
		var price := SkillSystem.sell_price(data, item, true)
		if price > 0:
			rows.append([price, item.display_name])
	if rows.is_empty():
		_say("Analisis Pasar: tidak ada barang bernilai jual di tasmu.")
		return
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var lines: PackedStringArray = []
	for row in rows.slice(0, 3):
		lines.append("%s %d G" % [row[1], row[0]])
	_say("Analisis Pasar (harga kirim per buah): " + ", ".join(lines) + ".")


func _student_card(player: Player, data: PlayerData) -> void:
	if Campus.has_card(data):
		_say("Kartu Mahasiswa aktif: kuliah %d G, akses Lab & ujian sertifikasi." % Campus.lecture_fee(data))
		return
	if not _confirmed(player, "Layanan Mahasiswa: Kartu Mahasiswa %d G (kuliah setengah harga, akses Lab & ujian sertifikasi)." % Campus.CARD_PRICE):
		return
	if not Campus.buy_card(data):
		_say("Uangmu belum cukup untuk Kartu Mahasiswa (%d G)." % Campus.CARD_PRICE)
		return
	_say("Selamat! Kartu Mahasiswa atas namamu sudah terbit.")


func _shop(player: Player, _data: PlayerData) -> void:
	if shop_data == null:
		_say("Sedang tutup.")
		return
	_shop_ui = ShopUI.new()
	_shop_ui.player = player
	_shop_ui.shop_data = shop_data
	Coop.ui_parent(player).add_child(_shop_ui)


func _exam(player: Player, data: PlayerData) -> void:
	if not Campus.has_card(data):
		_say("Ujian sertifikasi khusus pemegang Kartu Mahasiswa (Layanan Mahasiswa).")
		return
	var exam := Campus.next_exam(data)
	if exam.is_empty():
		var levels := Campus.EXAMS.keys()
		levels.sort()
		_say("Ujian sertifikasi terbuka saat sebuah keahlian mencapai Lv %s." % "/".join(levels.map(func(v): return str(v))))
		return
	if not _confirmed(player, "Ujian Sertifikasi %s Lv %d: biaya %d G, hadiah 1 Token Talenta." % [Campus.role_title(exam.role), exam.level, exam.fee]):
		return
	if not Campus.take_exam(data, exam):
		_say("Uangmu belum cukup untuk biaya ujian (%d G)." % exam.fee)
		return
	_say("Lulus! Sertifikat %s Lv %d: +1 Token Talenta. Pakai di tab Keahlian." % [Campus.role_title(exam.role), exam.level])


func _database(_player: Player, _data: PlayerData) -> void:
	_say("Basis Data Lembah — Catatan Satwa %d/%d, sampel Lab %d jenis." % [WildlifeJournal.seen_count(), WildlifeJournal.ids().size(), Campus.analyzed_count()])


func _lab(player: Player, data: PlayerData) -> void:
	if not Campus.has_card(data):
		_say("Laboratorium khusus pemegang Kartu Mahasiswa (Layanan Mahasiswa).")
		return
	var slot := data.hotbar_page * 8 + player.tool_controller.current_index
	var item: ItemData = data.inventory[slot]["item"] if slot < data.bag_size and data.inventory[slot] != null else null
	var role := Campus.lab_role(item)
	if role == &"":
		_say("Lab Analisis: pegang hasil panen, tanaman liar, atau ikan untuk dianalisis (%d jenis tercatat)." % Campus.analyzed_count())
		return
	if Campus.is_analyzed(item.item_id):
		_say("%s sudah pernah dianalisis. Bawa sampel jenis lain." % item.display_name)
		return
	if not _confirmed(player, "Analisis 1 %s: +%d EXP %s." % [item.display_name, Campus.lab_exp(item), Campus.role_title(role)]):
		return
	var gained := Campus.lab_exp(item)
	if Campus.analyze(data, slot):
		Notify.say("Sampel %s tercatat: +%d EXP %s." % [item.display_name, gained, Campus.role_title(role)])


func _rest(_player: Player, data: PlayerData) -> void:
	if Campus.used_today(data, _key()) or data.stamina >= data.max_stamina:
		_say("Tempat yang nyaman untuk duduk sebentar.")
		return
	Campus.mark_used(data, _key())
	data.restore_stamina(Campus.REST_STAMINA)
	_say("Kamu beristirahat sejenak: +%d stamina." % Campus.REST_STAMINA)


# ── Sekolah ─────────────────────────────────────────────────────────

func _lesson(_player: Player, data: PlayerData) -> void:
	var role := Campus.topic_role()
	var topic: String = Campus.DAILY_TOPICS.get(role, "")
	if Campus.used_today(data, _key()):
		_say("Pelajaran hari ini: %s" % topic)
		return
	Campus.mark_used(data, _key())
	_say("Pelajaran hari ini: %s\nKamu ikut mencatat: +%d EXP %s." % [topic, Campus.LESSON_EXP, Campus.role_title(role)])
	SkillSystem.gain(data, role, Campus.LESSON_EXP)


func _guest_teacher(player: Player, data: PlayerData) -> void:
	var role := Campus.best_role(data)
	var level := data.skills.level(role)
	if level < Campus.TEACH_MIN_LEVEL:
		_say("Butuh guru tamu! Syarat: salah satu keahlian minimal Lv %d." % Campus.TEACH_MIN_LEVEL)
		return
	var wait := Campus.days_until_ready(data, _key(), Campus.TEACH_COOLDOWN_DAYS)
	if wait > 0:
		_say("Murid masih membahas pelajaranmu. Mengajar lagi dalam %d hari." % wait)
		return
	var pay := level * Campus.TEACH_PAY_PER_LEVEL
	if not _confirmed(player, "Mengajar %s (2 jam, %d stamina): honor %d G." % [Campus.role_title(role), Campus.TEACH_STAMINA, pay]):
		return
	if data.stamina < Campus.TEACH_STAMINA:
		_say("Kamu terlalu lelah untuk mengajar.")
		return
	data.stamina -= Campus.TEACH_STAMINA
	Campus.mark_used(data, _key())
	DayCycle.advance_minute(Campus.TEACH_MINUTES)
	GameState.add_money(pay)
	Notify.say("Kelas selesai. Murid-murid bertepuk tangan: +%d G." % pay)


func _school_request(player: Player, data: PlayerData) -> void:
	var request := Campus.school_request()
	var item := load("res://resources/item_data/%s.tres" % request[0]) as ItemData
	var amount: int = request[1]
	if item == null:
		return
	if Campus.used_today(data, _key()):
		_say("Pesanan makan siang hari ini sudah terpenuhi. Terima kasih!")
		return
	var pay := Campus.request_pay(item, amount)
	if data.get_item_count(item.item_id) < amount:
		_say("Dapur sekolah butuh %d %s untuk makan siang murid. Imbalan %d G." % [amount, item.display_name, pay])
		return
	if not _confirmed(player, "Serahkan %d %s ke dapur sekolah? Imbalan %d G." % [amount, item.display_name, pay]):
		return
	if not data.remove_item(item.item_id, amount):
		return
	Campus.mark_used(data, _key())
	GameState.add_money(pay)
	_say("Murid-murid makan siang dengan lahap: +%d G." % pay)
	SkillSystem.gain(data, &"farmer" if item.category == ItemData.Category.CROP else &"fisher", Campus.REQUEST_EXP)
