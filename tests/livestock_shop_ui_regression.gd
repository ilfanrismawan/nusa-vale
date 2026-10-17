extends Node

var failures := 0

func check(value: bool, caption: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + caption)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	GameState.money = 100000
	var barn := {"uid": 10, "item": "barn", "cell": [44, 18], "storage": [], "open": false, "job": {}, "ready": {}}
	var coop := {"uid": 11, "item": "chicken_coop", "cell": [56, 18], "storage": [], "open": false, "job": {}, "ready": {}}
	var second := {"uid": 12, "item": "barn", "cell": [66, 18], "storage": [], "open": false, "job": {}, "ready": {}}
	StructureManager.records.assign([barn, coop, second])
	StructureManager._next_uid = 13
	var room := load("res://scenes/world/interior/barn_interior.tscn").instantiate() as Node2D
	room.ranch_uid = 10
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await get_tree().process_frame
	var player: Player = room.get_node("Player/CharacterBody2D")
	player.set_physics_process(false)
	var shop = load("res://scenes/ui/livestock_shop_ui.tscn").instantiate()
	shop.player = player
	Coop.ui_parent(player).add_child(shop)
	await get_tree().process_frame
	await get_tree().process_frame
	check(shop.get_node("%Cards").columns == 4, "reference-style four-column animal grid")
	check(shop.get_node("%Cards").get_child_count() == shop.presentation.display_slots, "editable display slots include disabled placeholders")
	check(shop._species_order.size() == RanchHusbandry.SPECIES.size(), "all supported animals are listed without inventing unavailable species")
	check(shop.get_node("Design/Detail").position == Vector2(935, 189), "detail panel follows reference placement")
	check(shop.get_node("%Preview").texture != null and shop.get_node("%Vendor").texture != null, "animal and seller art are real project assets")
	check(shop.get_node("%Swatches").get_child_count() == 2, "chicken exposes only two supported colors")
	shop._choose_variant("brown")
	check(shop._variant == "brown", "color swatch updates actual purchase variant")
	shop._animal_name = "Cokelat"
	var before := GameState.money
	shop._buy()
	check(GameState.money == before - int(RanchHusbandry.SPECIES.chicken.price), "UI keeps authoritative chicken price")
	check(StructureManager.coop_state(coop).chickens[0].variant == "brown", "selected color is delivered")
	check(shop.get_node("%AnimalName").text.is_empty(), "successful purchase clears name field")
	shop._select("cow")
	check(shop.get_node("%Swatches").get_child_count() == 0, "unsupported colors are not offered")
	check(shop.get_node("%LivestockHousing").item_count == 2, "destination selector includes both matching barns")
	shop._choose_home(1)
	shop._animal_name = "Sari"
	before = GameState.money
	shop._buy()
	check(StructureManager.coop_state(second).chickens[0].name == "Sari" and StructureManager.coop_state(barn).chickens.is_empty(), "delivery targets the selected barn only")
	check(GameState.money == before - int(RanchHusbandry.SPECIES.cow.price), "cow purchase preserves exact price")
	while StructureManager.coop_state(second).chickens.size() < RanchHusbandry.capacity(StructureManager.coop_state(second)):
		StructureManager.buy_animal(12, "cow")
	shop._refresh()
	check(shop.get_node("%PurchaseLivestock").disabled, "full housing disables Buy")
	before = GameState.money
	shop._buy()
	check(GameState.money == before, "direct purchase still cannot charge a full barn")
	shop._choose_home(0)
	GameState.money = 0
	shop._refresh()
	check(shop.get_node("%PurchaseLivestock").disabled, "insufficient shared money disables Buy")
	GameState.money = 100000
	shop._select("chicken")
	shop._refresh()
	shop._status.text = ""
	if OS.get_environment("NUSA_LIVESTOCK_SCREENSHOT") == "1" and DisplayServer.get_name() != "headless":
		for child in room.get_node("Player").get_children():
			if child is CanvasLayer:
				child.hide()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://scratch/livestock-shop-ui-preview.png") == OK, "native livestock shop preview renders")
	shop._close()
	await get_tree().process_frame
	check(not get_tree().paused, "closing livestock shop restores solo gameplay")
	get_tree().current_scene = self
	room.queue_free()
	await get_tree().process_frame
	print("LIVESTOCK SHOP UI COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
