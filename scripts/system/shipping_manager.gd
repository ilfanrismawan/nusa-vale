class_name ShippingManager
extends Node

var pending: Array = []
var last_report: Dictionary = {}
var pickup_day := 0
var pickup_mask := 0
var collected_rows: Array = []
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
		if row.id == item.item_id and int(row.price) == price:
			row.count += amount
			return
	pending.append({"id": item.item_id, "name": item.display_name if not item.display_name.is_empty() else item.item_id, "price": price, "count": amount})

func _ready() -> void:
	DayCycle.time_tick.connect(_on_time_tick)

func _on_time_tick(hour: int, _minute: int) -> void:
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
	last_report.clear()

func to_save() -> Dictionary:
	return {"pending": pending.duplicate(true), "last_report": last_report.duplicate(true), "collected_rows": collected_rows.duplicate(true), "pickup_day": pickup_day, "pickup_mask": pickup_mask}

func load_save(value: Dictionary) -> void:
	reset()
	pending = value.get("pending", []).duplicate(true)
	last_report = value.get("last_report", {}).duplicate(true)
	collected_rows = value.get("collected_rows", []).duplicate(true)
	pickup_day = int(value.get("pickup_day", 0))
	pickup_mask = int(value.get("pickup_mask", 0))

static func valid_save(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["pickup_day", "pickup_mask"]:
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
