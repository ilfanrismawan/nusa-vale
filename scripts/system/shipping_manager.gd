class_name ShippingManager
extends Node

var pending: Array = []
var last_report: Dictionary = {}
var _report_ui: CanvasLayer

func deposit(item: ItemData, amount: int) -> void:
	if item == null or amount <= 0 or item.sell_price <= 0 or item.is_tool():
		return
	for row in pending:
		if row.id == item.item_id and int(row.price) == item.sell_price:
			row.count += amount
			return
	pending.append({"id": item.item_id, "name": item.display_name if not item.display_name.is_empty() else item.item_id, "price": item.sell_price, "count": amount})

func settle(day: int) -> void:
	var total := 0
	for row in pending:
		total += int(row.price) * int(row.count)
	last_report = {"day": day - 1, "rows": pending.duplicate(true), "total": total}
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
	last_report.clear()

func to_save() -> Dictionary:
	return {"pending": pending.duplicate(true), "last_report": last_report.duplicate(true)}

func load_save(value: Dictionary) -> void:
	reset()
	pending = value.get("pending", []).duplicate(true)
	last_report = value.get("last_report", {}).duplicate(true)

static func valid_save(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var report: Variant = value.get("last_report", {})
	if not report is Dictionary:
		return false
	for rows in [value.get("pending", []), report.get("rows", [])]:
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
