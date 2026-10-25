extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: " + message)
func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var shop := ShopUI.new()
	add_child(shop)
	await get_tree().process_frame
	await get_tree().process_frame
	shop._on_season_tab_pressed("all")
	check(shop._list.get_child_count() > 6, "catalog retains full stock")
	check(shop.find_children("*", "ScrollContainer", true, true).is_empty(), "shop uses pagination rather than scrolling")
	check(shop._list is GridContainer and shop._list.columns == 3, "catalog uses a three-column visual card grid")
	var first: Control = shop._rows[0]["panel"]
	check(first.visible, "first catalog page visible")
	shop._change_catalog_page(1)
	check(not first.visible and shop._rows[6]["panel"].visible, "next catalog page is reachable")
	shop._on_season_tab_pressed("all")
	var item: ItemData = shop._rows[0]["item"]
	GameState.add_money(100000)
	shop._selected_item = item
	shop._quantity.value = 2
	shop._refresh_purchase()
	var before := GameState.money
	var price := shop._unit_price(item, 2)
	shop._purchase_selected()
	check(GameState.money == before - price * 2, "purchase charges exact displayed quantity")
	var sale_item: ItemData = load("res://resources/item_data/stone.tres")
	shop.data.add_item(sale_item, 2)
	var sold_before := GameState.money
	for i in shop.data.bag_size:
		var slot = shop.data.inventory[i]
		if slot != null and slot["item"].item_id == sale_item.item_id:
			shop._sell(i, false)
			break
	check(GameState.money == sold_before + SkillSystem.sell_price(shop.data, sale_item, false), "selling credits exact price")
	shop.data.bag_level = 2
	shop._refresh_inventory()
	check(shop._inv_grid.get_child_count() == 12, "bag shows twelve slots per page")
	shop._change_inventory_page(1)
	check(shop._inventory_page == 1, "expanded bag page reachable")
	for i in range(10): shop._move_pad_cursor(1)
	check(shop._pad_row()["panel"].visible, "gamepad selection reveals catalog page")
	check(shop._detail_icon.texture == shop._selected_item.icon and shop._detail_name.text == shop._selected_item.display_name, "detail panel shows selected item icon and full name")
	var money_before_hover := GameState.money
	shop._on_row_hover(shop._rows[0]["panel"], shop._rows[0]["item"])
	check(GameState.money == money_before_hover, "hover previews item without triggering a purchase")
	shop._on_row_unhover(shop._rows[0]["panel"])
	shop._on_season_tab_pressed("winter")
	var winter_count := 0
	for row in shop._rows:
		if row["item"].season == "winter": winter_count += 1
	check(shop._empty.visible == (winter_count == 0), "empty seasonal category shows an honest empty state")
	check(shop._selected_item == null and shop._detail_icon.texture == null and shop._purchase_button.disabled, "changing category clears stale item preview and purchase")
	shop._on_season_tab_pressed("all")
	shop._move_pad_cursor(1)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		shop._inventory_page = 0
		shop._refresh_inventory()
		for notice in Notify._box.get_children():
			notice.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("res://scratch/shop-book.png")
	var book: Control = shop._list.get_parent()
	for control in book.get_children():
		if control is Control and control.name != "Paper":
			check(control.position.y + control.size.y <= shop.design_size.y, "shop design lower margin: " + control.name)
	var original_size := get_tree().root.size
	get_tree().root.size = Vector2i(640, 360)
	await get_tree().process_frame
	await get_tree().process_frame
	var bounds := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	for path in ["Buy", "Close", "Quantity", "Inventory", "Filters", "Stock"]:
		check(bounds.encloses(book.get_node(path).get_global_rect()), "shop control fits small viewport: " + path)
	get_tree().root.size = original_size
	shop.close_shop()
	await get_tree().process_frame
	print("SHOP BOOK COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
