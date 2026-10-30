extends Node

var failures := 0
func check(ok: bool, label: String) -> void:
	if ok: print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func settle() -> void:
	for frame in 5: await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	FarmManager.farm_data.clear()
	FarmManager.clear_references()
	DayCycle.is_running = false
	GameState.money = 1000
	var rig = load("res://scenes/player/Player.tscn").instantiate()
	add_child(rig)
	var player: Player = rig.get_node("CharacterBody2D")
	player.set_process(false)
	player.set_physics_process(false)
	var shop := ShopUI.new()
	shop.player = player
	add_child(shop)
	var item := GameState._resolve_item("animal_feed")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	shop._on_row_input(click, item)
	check(GameState.money == 1000 and not player.data.has_item("animal_feed"), "selecting a shop item does not spend money or buy accidentally")
	shop._quantity.value = 5
	check(shop._purchase_summary.text.contains("50 G") and not shop._purchase_button.disabled, "quantity and total cost are shown before purchase")
	shop._purchase_button.pressed.emit()
	check(GameState.money == 950 and player.data.get_item_count("animal_feed") == 5, "purchase button charges exact displayed batch and delivers all items")
	GameState.spend_money(950)
	check(shop._purchase_button.disabled, "shared money changes disable unaffordable purchases immediately")
	shop._purchase_selected()
	check(player.data.get_item_count("animal_feed") == 5, "disabled purchase cannot consume money or grant items")
	shop._on_season_tab_pressed("all")
	check(shop._selected_item == null and shop._purchase_button.disabled, "changing shop category clears stale selection")
	shop._move_pad_cursor(1)
	shop._move_pad_cursor(1)
	var highlighted := 0
	for row in shop._rows:
		if row.panel.visible and row.panel.get_theme_stylebox("panel") == shop.card_selected: highlighted += 1
	check(highlighted == 1, "controller navigation highlights only the currently selected shop item")
	shop.close_shop()
	await settle()
	GameState.money = 10000
	player.data.add_item_silent("wood", 300)
	player.data.add_item_silent("stone", 150)
	var carpenter = load("res://scenes/ui/carpenter_menu.tscn").instantiate()
	carpenter.player = player
	add_child(carpenter)
	await settle()
	# Kartu pertama adalah peningkatan rumah, sisanya bangunan StructureManager.CONSTRUCTION.
	check(carpenter._content.get_child_count() == StructureManager.CONSTRUCTION.size() + 1 and carpenter._content.get_child(0).get_theme_stylebox("normal") is StyleBoxFlat, "building catalog uses editable native cream-theme cards")
	carpenter._close()
	await settle()
	var other := GameState.ensure_player(1)
	other.bag_level = 2
	other.add_item_silent("copper_bar", 10)
	other.add_item_silent("wood", 100)
	rig.player_index = 1
	Coop.active = true
	GameState.use_player(GameState.p1())
	var upgrade := load("res://scenes/ui/tool_upgrade_ui.tscn").instantiate() as ToolUpgradeUI
	upgrade.player = player
	add_child(upgrade)
	await settle()
	check(not upgrade._upgrade_btn.disabled and upgrade._benefits.text.contains("Stamina"), "upgrade uses the owner's materials and previews the tool improvement")
	check(upgrade._benefits.text.contains("Kekuatan") and upgrade._benefits.text.contains("kecil/normal") and upgrade._detail_cost.text.contains("Sisa saldo"), "upgrade explains resource access, hit power and remaining seed capital")
	upgrade._on_upgrade_pressed()
	check(not other.tool_order.is_empty() and GameState.p1().tool_order.is_empty(), "upgrade order is created for the interacting player")
	check(upgrade._order_progress.visible and upgrade._benefits.text.contains("Siap pada hari"), "active upgrade shows progress and promised completion day")
	DayCycle.current_day = int(other.tool_order.ready_day)
	DayCycle.day_passed.emit(DayCycle.current_day)
	check(not upgrade._upgrade_btn.disabled and upgrade._upgrade_btn.text == "Ambil alat", "completed order exposes a clear pickup action")
	upgrade._upgrade_btn.pressed.emit()
	check(other.tool_order.is_empty() and other.has_item("axe_copper"), "pickup action delivers the upgraded tool to its owner")
	upgrade._close()
	await settle()
	Coop.active = false
	check(not get_tree().paused, "closing service UI restores gameplay")
	rig.queue_free()
	await settle()
	# Release pooled pickup/upgrade playback before the headless audio server exits.
	for voice in Juice._voices:
		voice.stop()
		voice.stream = null
	await get_tree().create_timer(1.0, true).timeout
	print("SERVICE UI REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
