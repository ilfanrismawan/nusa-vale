extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	DayCycle.is_running = false
	GameState.new_game()
	var ui := (load("res://scenes/ui/ui_inventory.tscn") as PackedScene).instantiate()
	add_child(ui)
	check(ui._collection_panel.catalog.is_empty(), "closed inventory does not load collection catalog")
	ui.show()
	ui._show_collection()
	check(ui._collection_panel.catalog.size() > 0 and ui._collection_panel._list.get_child_count() > 0, "collection populates when first opened")
	var catalog_size: int = ui._collection_panel.catalog.size()
	ui._show_bag_page()
	ui._show_collection()
	check(ui._collection_panel.catalog.size() == catalog_size, "reopening collection does not duplicate catalog")
	ui._show_equipment()
	check(ui._equipment_panel._portrait.texture != null and not ui._equipment_panel._stats.text.is_empty(), "equipment portrait and stats appear on first opening")
	ui._show_crafting()
	check(ui._crafting_panel._list.get_child_count() > 0, "crafting recipes appear on first opening")
	ui._show_bag_page()
	check(not ui._collection_panel.visible and not ui._equipment_panel.visible and not ui._crafting_panel.visible, "returning to bag hides other panels")
	var catalog := load("res://resources/character/character_catalog.tres") as CharacterCatalog
	var appearance := catalog.sanitize(GameState.p1().appearance)
	var first := CharacterSpriteBuilder.build(catalog, appearance)
	var second := CharacterSpriteBuilder.build(catalog, appearance)
	var independent := true
	for key in first.textures:
		independent = independent and first.textures[key] != second.textures[key] and first.textures[key].get_image().get_data() == second.textures[key].get_image().get_data()
	check(independent, "cached character images produce separate identical textures for each player")
	var key: Variant = first.textures.keys()[0]
	var before: PackedByteArray = second.textures[key].get_image().get_data()
	var changed: Image = first.textures[key].get_image()
	changed.fill(Color.RED)
	first.textures[key].update(changed)
	check(second.textures[key].get_image().get_data() == before, "updating one player texture leaves the other player unchanged")
	ui.queue_free()
	await get_tree().process_frame
	print("PERFORMANCE UI REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
