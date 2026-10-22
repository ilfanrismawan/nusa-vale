class_name HouseManager
extends Node

## Tingkat rumah milik rumah tangga (dibagi semua pemain co-op), dipegang GameState.house.
## Upgrade dipesan ke Wira, dibayar di depan, selesai setelah build_days hari (GDD 4.12, save v17).

signal level_changed(level: int)
signal order_changed

const LEVEL_PATH := "res://resources/house/house_level_%d.tres"
const MAX_LEVELS := 10
## Save v16 ke bawah: renovasi dapur dari toko Dapur Nusantara = rumah tingkat 1.
const LEGACY_KITCHEN_FLAG := "house_kitchen_upgraded"

## Bonus stamina maksimum tingkat rumah sekarang; dibaca PlayerData.max_stamina tanpa lewat autoload.
static var stamina_bonus_total: int = 0

var level: int = 0
## Pesanan berjalan: {"level": int, "ready_day": int}. Kosong = tidak ada pesanan.
var order: Dictionary = {}
var _levels: Array[HouseLevelData] = []

func _ready() -> void:
	for number in range(1, MAX_LEVELS + 1):
		var path := LEVEL_PATH % number
		if not ResourceLoader.exists(path):
			break
		var data := load(path) as HouseLevelData
		if data == null:
			push_error("HouseLevelData tidak valid: " + path)
			break
		_levels.append(data)
	DayCycle.day_passed.connect(_on_day_passed)

func reset() -> void:
	order.clear()
	_set_level(0)
	order_changed.emit()

func max_level() -> int:
	return _levels.size()

func data_for(target: int) -> HouseLevelData:
	return _levels[target - 1] if target >= 1 and target <= _levels.size() else null

func next_level() -> HouseLevelData:
	return data_for(level + 1)

func is_building() -> bool:
	return not order.is_empty()

func days_remaining() -> int:
	return maxi(0, int(order.get("ready_day", DayCycle.current_day)) - DayCycle.current_day)

func stamina_bonus() -> int:
	var total := 0
	for index in mini(level, _levels.size()):
		total += _levels[index].stamina_bonus
	return total

## Alasan pesanan ditolak, atau "" bila bisa dipesan.
func status(data: PlayerData) -> String:
	if is_building():
		var building := data_for(int(order.level))
		return "Wira sedang membangun %s. Selesai dalam %d hari." % [building.display_name if building != null else "rumahmu", days_remaining()]
	var next := next_level()
	if next == null:
		return "Rumahmu sudah di tingkat tertinggi."
	if GameState.money < price_for(data):
		return "Uang belum cukup."
	for id in next.materials:
		if data == null or data.get_item_count(id) < next.materials[id]:
			return "Bahan bangunan belum cukup."
	return ""

## Harga upgrade berikutnya setelah diskon fasilitas Merchant (GDD 13).
func price_for(data: PlayerData) -> int:
	var next := next_level()
	return SkillSystem.facility_price(data, next.price) if next != null else 0

func can_order(data: PlayerData) -> bool:
	return status(data).is_empty()

## Bahan dari tas pemain yang memesan, uang dari kas bersama.
func order_upgrade(data: PlayerData) -> bool:
	var reason := status(data)
	if not reason.is_empty():
		Notify.say(reason)
		return false
	var next := next_level()
	var price := price_for(data)
	for id in next.materials:
		data.remove_item(id, next.materials[id])
	GameState.spend_money(price)
	SkillSystem.gain_from_value(data, &"merchant", price, SkillSystem.RULES.shop_gold_per_exp, SkillSystem.RULES.shop_exp_max)
	order = {"level": level + 1, "ready_day": DayCycle.current_day + next.build_days}
	order_changed.emit()
	if next.build_days <= 0:
		_complete(true)
	else:
		Notify.say("Wira mulai membangun %s. Selesai dalam %d hari." % [next.display_name, next.build_days])
	return true

func _on_day_passed(_day: int) -> void:
	if is_building() and days_remaining() <= 0:
		_complete(true)

func _complete(announce: bool) -> void:
	var target := int(order.get("level", level + 1))
	order.clear()
	_set_level(target)
	var data := data_for(level)
	if announce and data != null:
		Notify.say(data.completed_message if not data.completed_message.is_empty() else "Wira selesai membangun %s!" % data.display_name)
	order_changed.emit()

func _set_level(value: int) -> void:
	level = clampi(value, 0, max_level())
	stamina_bonus_total = stamina_bonus()
	_apply_flags()
	# Stamina maksimum berubah: kirim ulang supaya HUD menggambar bar baru.
	for player in GameState.players:
		player.stamina = player.stamina
	level_changed.emit(level)

func _apply_flags() -> void:
	for index in mini(level, _levels.size()):
		for flag in _levels[index].grants_flags:
			WorldState.set_flag(flag)

func to_save() -> Dictionary:
	return {"level": level, "order": order.duplicate()}

static func valid_save(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.has("level") and not (data.level is int or data.level is float):
		return false
	if data.has("order"):
		var value: Variant = data.order
		if not value is Dictionary:
			return false
		if not value.is_empty():
			for key in ["level", "ready_day"]:
				if not (value.get(key) is int or value.get(key) is float):
					return false
	return true

## Dipanggil sebelum pemain dimuat, supaya stamina tersimpan tidak terpotong bonus rumah.
func load_save(data: Variant) -> void:
	order.clear()
	_set_level(0)
	if data is Dictionary:
		level = clampi(int(data.get("level", 0)), 0, max_level())
		var saved: Variant = data.get("order", {})
		if saved is Dictionary and not saved.is_empty():
			var target := int(saved.get("level", 0))
			if target == level + 1 and target <= max_level():
				order = {"level": target, "ready_day": int(saved.get("ready_day", DayCycle.current_day))}
	# Flag dunia menyusul di sync_with_world(); bonus stamina harus sudah benar sebelum pemain dimuat.
	stamina_bonus_total = stamina_bonus()
	level_changed.emit(level)
	order_changed.emit()

## Dipanggil setelah flag dunia dimuat: migrasi save lama dan nyalakan flag tingkat yang sudah jadi.
func sync_with_world() -> void:
	if level < 1 and max_level() >= 1 and WorldState.has_flag(LEGACY_KITCHEN_FLAG):
		level = 1
		if int(order.get("level", 0)) == 1:
			order.clear()
	if is_building() and days_remaining() <= 0:
		_complete(false)
	else:
		_set_level(level)
	order_changed.emit()
