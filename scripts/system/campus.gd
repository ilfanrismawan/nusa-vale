class_name Campus
extends RefCounted
## Fungsi ruangan Sekolah & Universitas. Data per save di GameState.campus:
##   "<siapa>|<stasiun>" -> hari terakhir dipakai (batas harian/mingguan per karakter)
##   "card|<siapa>"      -> 1 bila punya Kartu Mahasiswa
##   "exam|<siapa>|<role>|<lv>" -> 1 bila sertifikasi role itu sudah diambil
##   "lab|<item_id>"     -> 1 bila sampel itu sudah dianalisis (milik bersama rumah tangga)
## Angka ekonomi dikumpulkan di sini supaya mudah di-balancing.

const LECTURE_FEE := 400
const LECTURE_MINUTES := 120
const LECTURE_EXP := 60
const LECTURE_OPEN_HOUR := 8
const LECTURE_CLOSE_HOUR := 17
const CARD_PRICE := 2500
## Pemegang Kartu Mahasiswa membayar setengah biaya kuliah.
const CARD_LECTURE_DISCOUNT := 0.5
const READ_EXP := 15
const SCHOOL_READ_EXP := 10
const STUDY_STAMINA := 20
const STUDY_EXP := 25
const LESSON_EXP := 10
const REST_STAMINA := 15
const TEACH_MIN_LEVEL := 3
const TEACH_STAMINA := 15
const TEACH_MINUTES := 120
const TEACH_PAY_PER_LEVEL := 150
const TEACH_COOLDOWN_DAYS := 7
## Level role -> biaya ujian sertifikasi (hadiah 1 Token Talenta).
const EXAMS := {5: 3000, 10: 10000}
const LAB_EXP_PER_GOLD := 0.25
const LAB_EXP_MIN := 10
const LAB_EXP_MAX := 80
const REQUEST_EXP := 10
## Imbalan pesanan makan siang sekolah = nilai jual x pengali ini.
const REQUEST_PAY_MULT := 1.5

## Pesanan makan siang sekolah per musim: [item_id, jumlah]. Dingin: ikan.
const SCHOOL_REQUESTS := [
	[["carrot", 5], ["potato", 5], ["parsnip", 6], ["cabbage", 3]],
	[["tomato", 5], ["corn", 3], ["cucumber", 5], ["onion", 5]],
	[["pumpkin", 2], ["eggplant", 4], ["wheat", 8], ["broccoli", 3]],
	[["fish_carp", 3], ["fish_bream", 3], ["fish_anchovy", 4], ["fish_bullhead_catfish", 2]],
]

## Topik kuliah & pelajaran berganti tiap hari dalam pekan, satu role per hari.
const DAILY_TOPICS := {
	&"farmer": "Agronomi: rotasi tanaman dan kesuburan tanah.",
	&"forager": "Ekologi Hutan: siklus hidup pohon dan tanaman liar.",
	&"fisher": "Biologi Perairan: arus, umpan, dan musim ikan.",
	&"combat": "Pertahanan Diri: membaca gerak makhluk gua.",
	&"miner": "Geologi: lapisan batuan dan urat bijih.",
	&"merchant": "Niaga: harga, permintaan, dan tawar-menawar.",
	&"economist": "Ekonomi Desa: tabungan, bunga, dan investasi.",
}

const ROLE_ITEM_CATEGORY := {
	ItemData.Category.CROP: &"farmer",
	ItemData.Category.FORAGE: &"forager",
	ItemData.Category.FISH: &"fisher",
}


static func who(data: PlayerData) -> String:
	if data == null:
		return "p0"
	return data.character_id if not data.character_id.is_empty() else "p%d" % data.index


static func today() -> int:
	return DayCycle.current_day


static func topic_role(day: int = -1) -> StringName:
	var index := ((today() if day < 0 else day) - 1) % SkillSystem.ROLE_IDS.size()
	return SkillSystem.ROLE_IDS[index]


static func role_title(role_id: StringName) -> String:
	var role := SkillSystem.role(role_id)
	return role.title if role != null else String(role_id)


# ── Batas pemakaian ─────────────────────────────────────────────────

static func last_used(data: PlayerData, station: String) -> int:
	return int(GameState.campus.get("%s|%s" % [who(data), station], 0))


static func used_today(data: PlayerData, station: String) -> bool:
	return last_used(data, station) == today()


static func days_until_ready(data: PlayerData, station: String, cooldown: int) -> int:
	var last := last_used(data, station)
	if last <= 0:
		return 0
	return maxi(0, last + cooldown - today())


static func mark_used(data: PlayerData, station: String) -> void:
	GameState.campus["%s|%s" % [who(data), station]] = today()


# ── Kartu Mahasiswa ─────────────────────────────────────────────────

static func has_card(data: PlayerData) -> bool:
	return GameState.campus.has("card|" + who(data))


static func buy_card(data: PlayerData) -> bool:
	if has_card(data) or not GameState.spend_money(CARD_PRICE):
		return false
	GameState.campus["card|" + who(data)] = 1
	return true


static func lecture_fee(data: PlayerData) -> int:
	return roundi(LECTURE_FEE * (1.0 - CARD_LECTURE_DISCOUNT)) if has_card(data) else LECTURE_FEE


# ── Belajar mandiri ─────────────────────────────────────────────────

## Role dengan level (lalu EXP) terendah: belajar mandiri membantu mengejar ketertinggalan.
static func weakest_role(data: PlayerData) -> StringName:
	var best: StringName = SkillSystem.ROLE_IDS[0]
	var best_score := INF
	for role_id in SkillSystem.ROLE_IDS:
		if data.skills.get_points(role_id) >= SkillSystem.max_points():
			continue
		var score := float(data.skills.level(role_id)) * 1000000.0 + data.skills.get_points(role_id)
		if score < best_score:
			best_score = score
			best = role_id
	return best


static func best_role(data: PlayerData) -> StringName:
	var best: StringName = SkillSystem.ROLE_IDS[0]
	for role_id in SkillSystem.ROLE_IDS:
		if data.skills.level(role_id) > data.skills.level(best):
			best = role_id
	return best


# ── Ujian sertifikasi ───────────────────────────────────────────────

## Ujian pertama yang bisa diambil: {"role", "level", "fee"}; kosong bila tidak ada.
static func next_exam(data: PlayerData) -> Dictionary:
	var levels := EXAMS.keys()
	levels.sort()
	for at_level in levels:
		for role_id in SkillSystem.ROLE_IDS:
			if data.skills.level(role_id) >= at_level and not GameState.campus.has(_exam_key(data, role_id, at_level)):
				return {"role": role_id, "level": at_level, "fee": EXAMS[at_level]}
	return {}


static func take_exam(data: PlayerData, exam: Dictionary) -> bool:
	if exam.is_empty() or GameState.campus.has(_exam_key(data, exam.role, exam.level)):
		return false
	if not GameState.spend_money(int(exam.fee)):
		return false
	GameState.campus[_exam_key(data, exam.role, exam.level)] = 1
	data.skills.tokens += 1
	return true


static func _exam_key(data: PlayerData, role_id: StringName, at_level: int) -> String:
	return "exam|%s|%s|%d" % [who(data), role_id, at_level]


# ── Laboratorium ────────────────────────────────────────────────────

static func lab_role(item: ItemData) -> StringName:
	return ROLE_ITEM_CATEGORY.get(item.category, &"") if item != null else &""


static func is_analyzed(item_id: String) -> bool:
	return GameState.campus.has("lab|" + item_id)


static func lab_exp(item: ItemData) -> int:
	return SkillSystem.scaled_exp(item.sell_price, LAB_EXP_PER_GOLD, LAB_EXP_MIN, LAB_EXP_MAX)


static func analyzed_count() -> int:
	var count := 0
	for key in GameState.campus:
		count += 1 if str(key).begins_with("lab|") else 0
	return count


## Analisis sampel di slot itu: 1 item terpakai, EXP sekali per jenis. true bila berhasil.
static func analyze(data: PlayerData, slot: int) -> bool:
	if slot < 0 or slot >= data.bag_size or data.inventory[slot] == null:
		return false
	var item: ItemData = data.inventory[slot]["item"]
	if lab_role(item) == &"" or is_analyzed(item.item_id):
		return false
	data.remove_item_at(slot, 1)
	GameState.campus["lab|" + item.item_id] = 1
	SkillSystem.gain(data, lab_role(item), lab_exp(item))
	return true


# ── Pesanan makan siang sekolah ─────────────────────────────────────

static func school_request(day: int = -1) -> Array:
	day = today() if day < 0 else day
	var season := ((day - 1) / DayCycle.DAYS_PER_SEASON) % SCHOOL_REQUESTS.size()
	var options: Array = SCHOOL_REQUESTS[season]
	return options[(day - 1) % options.size()]


static func request_pay(item: ItemData, amount: int) -> int:
	return roundi(item.sell_price * amount * REQUEST_PAY_MULT)


# ── Save ────────────────────────────────────────────────────────────

static func valid_save(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 4096:
		return false
	for key in value:
		if not key is String or key.is_empty() or key.length() > 256:
			return false
		if not RanchHusbandry.integer(value[key]) or int(value[key]) < 0 or int(value[key]) > 1000000:
			return false
	return true


static func load_save(value: Variant) -> void:
	GameState.campus = (value as Dictionary).duplicate() if valid_save(value) else {}
