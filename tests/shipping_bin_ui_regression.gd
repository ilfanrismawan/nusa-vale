extends Node
## Buku Shipping Bin: titip, ambil lagi (EXP ditarik), dikunci setelah Ubay datang, save.
## Tidak menulis file save. Jalankan scene tests/shipping_bin_ui_regression.tscn.

var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _ready() -> void:
	await get_tree().process_frame
	DayCycle.is_running = false
	var data: PlayerData = GameState.current
	GameState.shipping.reset()
	var carrot := GameState._resolve_item("carrot")
	check(carrot != null and carrot.sell_price > 0, "carrot item exists and sells")
	data.remove_item("carrot", data.get_item_count("carrot"))
	data.add_item(carrot, 10)
	var exp_before := data.skills.get_points(&"economist")
	var ui = load("res://scenes/ui/shipping_bin_ui.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	check(ui.get_node("%SlotGrid").get_child_count() == 12, "12 slot nodes in the scene")
	var slot = null
	for s in ui.get_node("%SlotGrid").get_children():
		if s.bag_index >= 0 and data.inventory[s.bag_index] != null and data.inventory[s.bag_index].item.item_id == "carrot":
			slot = s
	check(slot != null, "carrot shown in bag grid")
	if slot == null:
		_finish(ui)
		return
	ui._on_slot_pressed(slot)
	ui._amount = 4
	check(ui._ship(4), "ship 4 carrots")
	check(data.get_item_count("carrot") == 6, "bag lost 4 carrots")
	check(GameState.shipping.pending.size() == 1 and int(GameState.shipping.pending[0].count) == 4, "pending row has 4")
	check(int(GameState.shipping.pending[0].get("seller", -1)) == data.index, "row remembers seller")
	await get_tree().process_frame
	check(ui.get_node("%Rows").get_child_count() == 1, "Kotak Kiriman shows 1 row")
	ui._take_back(0)
	check(data.get_item_count("carrot") == 10 and GameState.shipping.pending.is_empty(), "take back returns all carrots")
	check(data.skills.get_points(&"economist") <= exp_before + 1, "take back removes Economist EXP")
	ui._on_slot_pressed(slot)
	ui._ship(3)
	GameState.shipping.ubay_pickup()
	check(not GameState.shipping.can_take_back(GameState.shipping.pending[0]), "Ubay pickup locks the row")
	check(GameState.shipping.take_back(0, 3, data) == 0, "locked row cannot be taken back")
	var state: Variant = JSON.parse_string(JSON.stringify(GameState.shipping.to_save()))
	check(ShippingManager.valid_save(state), "save data with seller/locked/ubay_day is valid")
	GameState.shipping.load_save(state)
	check(bool(GameState.shipping.pending[0].get("locked", false)) and GameState.shipping.ubay_day == DayCycle.current_day, "locked state survives save round trip")
	check(ShippingManager.valid_save({"pending": [{"id": "carrot", "name": "Carrot", "price": 35, "count": 2}]}), "old rows without seller/locked still valid")
	check(not ShippingManager.valid_save({"pending": [{"id": "carrot", "name": "Carrot", "price": 35, "count": 2, "locked": "ya"}]}), "bad locked value rejected")
	_finish(ui)

func _finish(ui: Node) -> void:
	if is_instance_valid(ui):
		ui.close()
	GameState.shipping.reset()
	await get_tree().process_frame
	print("SHIPPING BIN UI REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
