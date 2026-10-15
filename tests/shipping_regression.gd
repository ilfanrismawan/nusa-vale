extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _ready() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	DayCycle.is_running = false
	GameState.new_game()
	var item := ItemData.new()
	item.item_id = "audit_crop"
	item.display_name = "Audit Crop"
	item.sell_price = 20
	GameState.shipping.deposit(item, 3)
	GameState.shipping.deposit(item, 2)
	check(GameState.money == 100, "deposit does not pay immediately")
	check(GameState.shipping.pending.size() == 1, "shared deposits aggregate")
	var saved := SaveManager._build_save_data()
	GameState.shipping.reset()
	SaveManager._apply_save(saved)
	check(int(GameState.shipping.pending[0].count) == 5, "pending survives save round trip")
	item.sell_price = 99
	DayCycle.advance_day()
	check(GameState.money == 200, "dawn pays locked deposit price")
	check(GameState.shipping.pending.is_empty(), "paid items cleared")
	check(int(GameState.shipping.last_report.total) == 100 and int(GameState.shipping.last_report.day) == 1, "next morning report records previous day")
	saved = SaveManager._build_save_data()
	SaveManager._apply_save(saved)
	DayCycle.advance_day()
	check(GameState.money == 200, "reload and next dawn do not pay twice")
	GameState.new_game()
	check(GameState.shipping.pending.is_empty() and GameState.shipping.last_report.is_empty(), "new game resets shipping")
	print("SHIPPING REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
