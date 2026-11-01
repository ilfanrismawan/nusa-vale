class_name ShippingManager
extends Node

## Isi Shipping Bin berubah (titip, ambil lagi, diangkut, dibayar). Dipakai ShippingBinUI.
signal changed

## Jam Ubay (kurir desa) mengangkut isi Shipping Bin. Sebelum itu (dan sebelum tidur) barang
## boleh diambil lagi; setelah diangkut barisnya terkunci, uangnya tetap dibayar saat tidur.
const UBAY_HOUR := 17

## Baris: {id, name, price, count, seller (indeks pemain), locked (sudah diangkut Ubay)}.
## seller/locked opsional: baris dari save lama dianggap milik P1 dan belum diangkut.
var pending: Array = []
var last_report: Dictionary = {}
var pickup_day := 0
var pickup_mask := 0
var collected_rows: Array = []
## Hari terakhir Ubay mengangkut kiriman (disimpan agar reload sore hari tidak mengangkut ulang).
var ubay_day := 0
var _report_ui: CanvasLayer

## seller = pemain yang menitip (null = pemain aktif). Harga dikunci saat dititip, termasuk
## bonus role (Angler, Economist, Shared Prosperity), dan penitip mendapat EXP Economist.
func deposit(item: ItemData, amount: int, seller: PlayerData = null) -> void:
	if item == null or amount <= 0 or item.sell_price <= 0 or item.is_tool():
		return
	if seller == null:
		seller = GameState.current
	var price := SkillSystem.sell_price(seller, item, true)
	SkillSystem.gain_from_value(seller, &"economist", price * amount, SkillSystem.RULES.ship_gold_per_exp)
	for row in pending:
		if row.id == item.item_id and int(row.price) == price and can_take_back(row) and int(row.get("seller", 0)) == seller.index:
			row.count += amount
			changed.emit()
			return
	pending.append({"id": item.item_id, "name": item.display_name if not item.display_name.is_empty() else item.item_id, "price": price, "count": amount, "seller": seller.index, "locked": false})
	changed.emit()

## true jika baris ini belum diangkut Ubay (masih boleh diambil lagi).
func can_take_back(row: Dictionary) -> bool:
	return not bool(row.get("locked", false))

## Ambil lagi `amount` dari baris `index` ke tas `taker`. Mengembalikan jumlah yang masuk tas
## (bisa kurang bila tas penuh). EXP Economist dari titipan itu ditarik kembali.
func take_back(index: int, amount: int, taker: PlayerData = null) -> int:
	if index < 0 or index >= pending.size() or amount <= 0:
		return 0
	if taker == null:
		taker = GameState.current
	var row: Dictionary = pending[index]
	if not can_take_back(row):
		return 0
	var item := GameState._resolve_item(str(row.id))
	if item == null:
		return 0
	var want := mini(amount, int(row.count))
	var got := want - taker.add_item(item, want)
	if got <= 0:
		return 0
	var seller := _player_data(int(row.get("seller", taker.index)), taker)
	if seller.skills != null:
		seller.skills.remove_points(&"economist", float(int(row.price) * got) / SkillSystem.RULES.ship_gold_per_exp)
	row.count = int(row.count) - got
	if int(row.count) <= 0:
		pending.remove_at(index)
	changed.emit()
	return got

func total_pending() -> int:
	var total := 0
	for row in pending:
		total += int(row.price) * int(row.count)
	return total

func _player_data(index: int, fallback: PlayerData) -> PlayerData:
	for data in GameState.players:
		if data != null and data.index == index:
			return data
	return fallback

## Ubay datang sore hari: semua baris yang ada sekarang terkunci (tidak bisa diambil lagi).
func ubay_pickup() -> void:
	ubay_day = DayCycle.current_day
	var picked := 0
	for row in pending:
		if can_take_back(row):
			row.locked = true
			picked += int(row.count)
	if picked > 0:
		Notify.say("Ubay sudah mengangkut %d barang dari Shipping Bin. Uangnya dibayar saat tidur." % picked)
		changed.emit()

func _ready() -> void:
	DayCycle.time_tick.connect(_on_time_tick)

func _on_time_tick(hour: int, _minute: int) -> void:
	if hour >= UBAY_HOUR and ubay_day != DayCycle.current_day:
		ubay_pickup()
	if SkillSystem.household(&"shipping_pickups") <= 0.0:
		return
	if pickup_day != DayCycle.current_day:
		pickup_day = DayCycle.current_day
		pickup_mask = 0
	for slot in 2:
		if hour < (12 if slot == 0 else 17) or pickup_mask & (1 << slot):
			continue
		pickup_mask |= 1 << slot
		var total := 0
		for row in pending:
			total += int(row.price) * int(row.count)
		collected_rows.append_array(pending.duplicate(true))
		pending.clear()
		changed.emit()
		if total > 0:
			GameState.add_money(total)
			Notify.say("Kurir Logistik: kiriman dibayar +%d G." % total)

func settle(day: int) -> void:
	var total := 0
	for row in pending:
		total += int(row.price) * int(row.count)
	var rows := collected_rows.duplicate(true)
	rows.append_array(pending.duplicate(true))
	var report_total := total
	for row in collected_rows:
		report_total += int(row.price) * int(row.count)
	last_report = {"day": day - 1, "rows": rows, "total": report_total}
	collected_rows.clear()
	pending.clear()
	changed.emit()
	if total > 0:
		GameState.add_money(total)

func show_report() -> void:
	if last_report.is_empty() or is_instance_valid(_report_ui):
		return
	_report_ui = load("res://scenes/ui/shipping_report_ui.tscn").instantiate()
	_report_ui.report = last_report.duplicate(true)
	add_child(_report_ui)

func reset() -> void:
	if is_instance_valid(_report_ui):
		_report_ui.queue_free()
	_report_ui = null
	pending.clear()
	collected_rows.clear()
	pickup_day = 0
	pickup_mask = 0
	ubay_day = 0
	last_report.clear()
	changed.emit()

func to_save() -> Dictionary:
	return {"pending": pending.duplicate(true), "last_report": last_report.duplicate(true), "collected_rows": collected_rows.duplicate(true), "pickup_day": pickup_day, "pickup_mask": pickup_mask, "ubay_day": ubay_day}

func load_save(value: Dictionary) -> void:
	reset()
	pending = value.get("pending", []).duplicate(true)
	last_report = value.get("last_report", {}).duplicate(true)
	collected_rows = value.get("collected_rows", []).duplicate(true)
	pickup_day = int(value.get("pickup_day", 0))
	pickup_mask = int(value.get("pickup_mask", 0))
	ubay_day = int(value.get("ubay_day", 0))
	changed.emit()

static func valid_save(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["pickup_day", "pickup_mask", "ubay_day"]:
		var count: Variant = value.get(key, 0)
		if not PlayerSkills._is_count(count) or float(count) != floorf(float(count)) or count > (3 if key == "pickup_mask" else 1000000):
			return false
	var report: Variant = value.get("last_report", {})
	if not report is Dictionary:
		return false
	for rows in [value.get("pending", []), report.get("rows", []), value.get("collected_rows", [])]:
		if not rows is Array:
			return false
		for row in rows:
			if not row is Dictionary or not row.get("id") is String or not row.get("name") is String:
				return false
			if row.has("locked") and not row.locked is bool:
				return false
			if row.has("seller"):
				var seller: Variant = row.seller
				if not (seller is int or seller is float) or float(seller) != floorf(float(seller)) or float(seller) < 0 or float(seller) > 7:
					return false
			for key in ["price", "count"]:
				var number: Variant = row.get(key)
				if not (number is int or number is float):
					return false
				if not is_finite(float(number)) or float(number) <= 0 or float(number) > 100000000:
					return false
	if not report.is_empty():
		for key in ["day", "total"]:
			var number: Variant = report.get(key)
			if not (number is int or number is float):
				return false
			if not is_finite(float(number)) or float(number) < 0:
				return false
	return true
