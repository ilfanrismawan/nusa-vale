extends Node

var failures := 0
func check(ok: bool, label: String) -> void:
	if ok: print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	GameState.money = 1000
	var rig = load("res://scenes/player/Player.tscn").instantiate()
	add_child(rig)
	var player: Player = rig.get_node("CharacterBody2D")
	player.set_process(false)
	player.set_physics_process(false)

	var world := Node2D.new()
	add_child(world)
	var actors := Node2D.new()
	actors.name = "NPCActors"
	world.add_child(actors)
	var warteg: Node2D = load("res://scenes/world/exterior/town/warteg.tscn").instantiate()
	world.add_child(warteg)
	var joko := CharacterBody2D.new()
	joko.set_script(load("res://scripts/npc/scheduled_npc.gd"))
	joko.npc_id = "joko"
	joko.npc_name = "Pak Joko"
	joko.definition = {"service": "shop", "service_rules": {"available_activities": ["working", "lunch"]}}
	var body_sprite := AnimatedSprite2D.new()
	body_sprite.name = "AnimatedSprite2D"
	joko.add_child(body_sprite)
	actors.add_child(joko)
	joko.set_physics_process(false)
	joko.set_process(false)
	var polygon := warteg.get_node_or_null("Body/CollisionPolygon2D") as CollisionPolygon2D
	check(polygon != null and polygon.polygon.size() >= 3, "warteg punya polygon collision")
	var counter := warteg.get_node_or_null("Counter") as ShopCounter
	check(counter != null and counter.has_meta("player_interaction"), "meja warteg bisa diinteraksi pemain")

	DayCycle.hour = 3
	counter.interact(player)
	check(not is_instance_valid(counter._shop), "warteg tutup di luar jam buka")

	DayCycle.hour = 12
	check(counter.keeper == "joko", "warteg dijaga Pak Joko")
	joko._current_activity = "working"
	joko.global_position = counter.global_position + Vector2(0, 400)
	counter.interact(player)
	check(not is_instance_valid(counter._shop), "warteg tutup saat Pak Joko tidak di meja")
	joko.global_position = counter.global_position + Vector2(-15, 16)
	joko._current_activity = "sleeping"
	counter.interact(player)
	check(not is_instance_valid(counter._shop), "warteg tutup saat Pak Joko tidak bertugas")
	joko._current_activity = "working"
	counter.interact(player)
	var shop := counter._shop
	check(is_instance_valid(shop) and shop.scene_file_path == "res://scenes/ui/warteg_ui.tscn", "interaksi membuka UI warteg")
	check(shop != null and shop.shop_data.shop_id == "warteg" and not shop.shop_data.buys_items, "UI memakai menu warteg")
	check(shop != null and shop.shop_data.keeper_name == "Pak Joko" and shop.shop_data.portrait != null, "penjaga warteg adalah Pak Joko")
	check(shop != null and shop.shop_data.stock.all(func(item: ItemData): return item.buy_price > 0), "semua menu warteg punya harga")
	var listed := func(): return shop._rows.filter(func(row): return shop._matches_filter(row["item"])).size()
	check(not shop._filter_buttons.has("spring") and shop.current_season_filter == "All", "tab warteg bukan tab musim dan dibuka di Semua")
	check(listed.call() == shop.shop_data.stock.size(), "semua menu tampil saat dibuka")
	var tabbed := {}
	for id in ["RiceSides", "Soup", "Drinks"]:
		for item_id in shop._filter_buttons[id].get_meta("item_ids"):
			tabbed[item_id] = true
	check(shop.shop_data.stock.all(func(item: ItemData): return tabbed.has(item.item_id)), "setiap menu masuk salah satu tab")
	shop._filter_buttons["Drinks"].pressed.emit()
	check(listed.call() == 4, "tab Minuman hanya menampilkan minuman")
	shop._filter_buttons["All"].pressed.emit()
	shop._show_detail_item(GameState._resolve_item("anguilla_fritta"))
	var effect_rows := shop._effect_list.get_children().filter(func(row): return row.visible)
	check(effect_rows.size() == GameState._resolve_item("anguilla_fritta").effect_lines().size(), "detail warteg menampilkan buff & debuff menu")
	var nasi := GameState._resolve_item("rice_bowl")
	shop._on_row_input(_click(), nasi)
	shop._quantity.value = 2
	check(shop._purchase_button.text.begins_with("Pesan") and shop._purchase_summary.text.contains("2 porsi"), "tombol memakai kata pesan dan porsi")
	shop._purchase_button.pressed.emit()
	check(GameState.money == 1000 - 2 * nasi.buy_price and player.data.get_item_count("rice_bowl") == 2, "memesan nasi memotong uang dan memberi makanan")

	print("WARTEG REGRESSION: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(1 if failures else 0)

func _click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click
