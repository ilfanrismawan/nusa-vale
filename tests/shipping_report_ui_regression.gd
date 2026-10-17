extends Node

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for frame in 6:
		await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var crop := ItemData.new()
	crop.item_id = "strawberry"
	crop.display_name = "Strawberry"
	crop.sell_price = 25
	GameState.shipping.deposit(crop, 4)
	GameState.shipping.settle(30)
	var paid := GameState.money
	crop.sell_price = 999
	GameState.shipping.show_report()
	await settle()
	var ui = GameState.shipping._report_ui
	check(ui != null and get_tree().paused, "native shipping report opens and pauses gameplay")
	check(ui.get_node("%Rows").get_child(0).get_node("UnitPrice").text == "25 G", "report displays the locked deposit price rather than a changed catalog price")
	check(ui.get_node("%Rows").get_child(0).get_node("Subtotal").text == "100 G" and ui.get_node("%Totals").text == "100 G", "report row subtotal and total match settled payment")
	check(ui.get_node("%Date").text.contains("Hari 1") and ui.get_node("%Date").text.contains("Musim Panas"), "report date reflects the sold day and game calendar")
	GameState.shipping.show_report()
	check(GameState.shipping._report_ui == ui, "reopening does not create duplicate report dialogs")
	if OS.get_environment("NUSA_SHIPPING_SCREENSHOT") == "1" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://scratch/shipping-report-ui-preview.png")
	ui._close()
	ui._close()
	await settle()
	check(GameState.money == paid and not get_tree().paused, "closing report never pays twice and restores gameplay")
	PauseManager.set_requested(true)
	GameState.shipping.show_report()
	await settle()
	GameState.shipping._report_ui.queue_free()
	await settle()
	check(PauseManager.requested and get_tree().paused, "external report removal preserves an existing pause request")
	PauseManager.set_requested(false)
	GameState.shipping.settle(31)
	GameState.shipping.show_report()
	await settle()
	ui = GameState.shipping._report_ui
	check(ui.get_node("%Empty").visible and ui.get_node("%Totals").text == "0 G", "empty shipping day displays an explicit empty state")
	GameState.shipping.reset()
	await settle()
	check(not get_tree().paused, "shipping reset removes the report and its pause reason")
	print("SHIPPING REPORT UI REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
