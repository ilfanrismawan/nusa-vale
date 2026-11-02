extends Node
## Data jenis hewan dari resources/animals (AnimalSpeciesData/PetCareData) dan tab Hewan di buku tas.

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func building(id: int, item: String, cell: Vector2i) -> Dictionary:
	return {"uid": id, "item": item, "cell": [cell.x, cell.y], "storage": [], "open": false, "job": {}, "ready": {}}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame

	# Angka sebelum dipindah dari kamus RanchHusbandry ke .tres (2 November 2026).
	var legacy := {
		"chicken": [800, 1, "chicken_egg", "", "chicken_coop", true],
		"duck": [1400, 2, "duck_egg", "", "chicken_coop", true],
		"cow": [2500, 1, "cow_milk", "milk_pail", "barn", true],
		"goat": [3200, 2, "goat_milk", "milk_pail", "barn", true],
		"sheep": [3000, 3, "wool", "shears", "barn", true],
		"buffalo": [4000, 2, "buffalo_milk", "milk_pail", "barn", true],
		"pig": [6000, 3, "truffle", "", "barn", false],
		"ostrich": [4500, 3, "ostrich_egg", "", "chicken_coop", false],
		"capybara": [2000, 0, "", "", "barn", true],
		"horse": [5000, 0, "", "", "barn", true],
	}
	check(RanchHusbandry.SPECIES.keys() == legacy.keys(), "species load from resources in the old shop order (%s)" % [RanchHusbandry.SPECIES.keys()])
	for kind in legacy:
		var info: Dictionary = RanchHusbandry.SPECIES.get(kind, {})
		var want: Array = legacy[kind]
		check([info.get("price"), info.get("interval"), info.get("product"), info.get("tool"), info.get("home"), info.get("large")] == want, "%s keeps price/interval/product/tool/home/large" % kind)
		check(not RanchHusbandry.species_data[kind].description.is_empty(), "%s has a player-facing description" % kind)
	check(RanchHusbandry.BREED_DAYS == {"cow": 6, "sheep": 5, "goat": 5, "buffalo": 7, "pig": 5, "capybara": 4}, "breeding days unchanged")
	check(RanchHusbandry.HATCH == {"chicken_egg": {"species": "chicken", "days": 3}, "duck_egg": {"species": "duck", "days": 5}, "ostrich_egg": {"species": "ostrich", "days": 7}}, "hatching unchanged")
	var care := PetActor.CARE
	check(care.pet_gain == 5 and care.feed_gain == 3 and care.max_affection == 100 and care.day_start == 6 and care.day_end == 20, "pet care numbers load from pet_care.tres")

	GameState.new_game()
	DayCycle.current_day = 2
	DayCycle.hour = 10
	DayCycle.is_running = false
	GameState.money = 100000
	var data := GameState.p1()
	data.load_pet({"pet_id": "cat", "pet_name": "Mochi", "pet_affection": 40, "pet_day": 2, "pet_fed_day": 0})
	StructureManager.records.assign([building(1, "chicken_coop", Vector2i.ZERO), building(2, "barn", Vector2i(10, 0))])
	check(StructureManager.buy_animal(1, "chicken", "Pipit").ok and StructureManager.buy_animal(2, "cow", "Mawar").ok and StructureManager.buy_animal(2, "sheep", "Bulu").ok, "test animals bought")
	var barn := StructureManager.coop_state(StructureManager.record_for(2))
	barn.chickens[0].fed_day = 2
	barn.chickens[0].pet_day = 2
	barn.chickens[0].brush_day = 2
	barn.chickens[0].ready = "cow_milk"

	var entries := AnimalBook.entries()
	check(entries.size() == 4, "book lists the pet and every ranch animal (%d)" % entries.size())
	if entries.size() == 4:
		check(entries[0].group == AnimalBook.GROUP_PET and entries[0].name == "Mochi" and entries[0].portrait != null, "pet comes first with its portrait")
		check(entries[0].todo and not entries[0].ready, "unfed pet counts as needing care")
		check(entries[1].group.ends_with(" 1") and entries[1].name == "Pipit" and entries[1].portrait != null, "coop animals are grouped under their building")
		var cow: Dictionary = entries[2]
		check(cow.name == "Mawar" and not cow.todo and cow.ready, "cared-for cow with milk waiting is ready, not todo")
		check(cow.info.any(func(pair: Array) -> bool: return pair[0] == "Produksi" and str(pair[1]).begins_with("Siap")), "ready product shows in the detail info")
		check(AnimalBook.filtered(entries, "todo").size() == 3 and AnimalBook.filtered(entries, "ready").size() == 1, "filters split todo and ready animals")

	# Halaman buku berdiri sendiri: daftar, detail, filter, dan pindah halaman tanpa scroll.
	var page: PanelContainer = load("res://scenes/ui/inventory_animals.tscn").instantiate()
	add_child(page)
	page.refresh()
	await get_tree().process_frame
	var rows := page.get_node("%List").get_children().filter(func(node: Node) -> bool: return node is AnimalBookRow)
	check(rows.size() == 4, "list shows one row per animal (%d)" % rows.size())
	check(page.get_node("%AnimalName").text == "Mochi" and page.get_node("%Detail").visible, "first animal is selected and detailed")
	page._select(entries[2].key)
	check(page.get_node("%AnimalName").text == "Mawar" and page.get_node("%Info").get_child_count() >= 2, "selecting a row updates the detail page")
	page._set_filter("ready")
	rows = page.get_node("%List").get_children().filter(func(node: Node) -> bool: return node is AnimalBookRow)
	check(rows.size() == 1 and page.get_node("%AnimalName").text == "Mawar", "ready filter keeps only animals with products")
	page._set_filter("all")
	barn.tier = 2
	for index in 10:
		StructureManager.buy_animal(2, "goat", "Kambing %d" % index)
	page.refresh()
	await get_tree().process_frame
	check(page.get_node("%Pager").visible and page._pages().size() > 1, "long lists paginate instead of scrolling")
	var list_rect: Rect2 = page.get_node("Pages/Left").get_global_rect().grow(0.2)
	var inside := true
	for node in page.get_node("%List").get_children():
		inside = inside and list_rect.encloses((node as Control).get_global_rect())
	check(inside, "list rows stay on the left page")
	page._turn(1)
	check(page._page == 1 and page.get_node("%List").get_child(0) is Label, "next page repeats the building header")
	# Gamepad: bawah di baris terakhir / atas di baris pertama membalik halaman.
	page._turn(-1)
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	var up := InputEventAction.new()
	up.action = &"ui_up"
	up.pressed = true
	var first_rows := page.get_node("%List").get_children().filter(func(node: Node) -> bool: return node is AnimalBookRow)
	page._row_input(down, first_rows[0].key)
	check(page._page == 0, "down inside the page does not turn it")
	page._row_input(down, first_rows[-1].key)
	var second_rows := page.get_node("%List").get_children().filter(func(node: Node) -> bool: return node is AnimalBookRow)
	check(page._page == 1 and page._selected == second_rows[0].key, "down on the last row turns to the next page and selects its first animal")
	page._row_input(up, second_rows[0].key)
	check(page._page == 0 and page._selected == first_rows[-1].key, "up on the first row returns to the last animal of the previous page")
	# Filter = tab ikon di tepi kiri luar buku, satu per filter, dengan ikon dan nama.
	var tabs: Array = page.get_node("%FilterTabsContainer").get_children()
	var left_edge: float = page.get_node("Pages/Left").get_global_rect().position.x
	var tabs_ok: bool = tabs.size() == page.FILTERS.size()
	for tab in tabs:
		tabs_ok = tabs_ok and tab is TextureButton and tab.get_node("Icon").texture != null and not tab.tooltip_text.is_empty() and tab.get_global_rect().end.x <= left_edge
	check(tabs_ok, "every filter is an icon tab on the outer left edge")
	tabs[3].pressed.emit()
	check(page._shown.size() == 1 and page._shown[0].home == "pet" and tabs[3].button_pressed and not tabs[0].button_pressed, "pet tab shows only the pet")
	tabs[5].pressed.emit()
	var barn_only: bool = page._shown.size() == 12
	for entry in page._shown:
		barn_only = barn_only and entry.home == "barn"
	check(barn_only, "barn tab shows only barn animals (%d)" % page._shown.size())
	tabs[4].pressed.emit()
	check(page._shown.size() == 1 and page._shown[0].name == "Pipit", "coop tab shows only poultry")
	tabs[2].pressed.emit()
	check(page._shown.size() == 1 and page._shown[0].name == "Mawar", "ready tab shows animals with products")
	tabs[0].pressed.emit()
	check(page._shown.size() == 14, "all tab shows every animal again")
	page.queue_free()
	await get_tree().process_frame
	StructureManager.records.clear()
	GameState.new_game()
	print("ANIMAL BOOK REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
