extends Node
var failures := 0
func check(value: bool, message: String) -> void:
	if value: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var inv = load("res://scenes/ui/ui_inventory.tscn").instantiate()
	add_child(inv)
	inv._open()
	if "--npc-details-only" in OS.get_cmdline_user_args():
		inv._show_relationships()
		inv._relationship_ui._open_npc("zarathia")
		for section in 4:
			inv._relationship_ui._select_section(section)
			await get_tree().process_frame
			check_area(inv._relationship_ui.get_node("%DetailsLeft"), "NPC profile/journal %d" % section)
			check_area(inv._relationship_ui.get_node("Design/Right"), "NPC gift panel %d" % section)
		inv._relationship_ui._select_section(2)
		for category in 5:
			inv._relationship_ui._select_category(category)
			await get_tree().process_frame
			check_area(inv._relationship_ui.get_node("Design/Right"), "NPC gift category %d" % category)
		inv._relationship_ui._select_section(3)
		var gift_info: Control = inv._relationship_ui.get_node("%GiftInfo")
		var long_gift_note := "Catatan hadiah panjang untuk memeriksa font piksel enam belas. ".repeat(24)
		gift_info.text = long_gift_note
		await get_tree().process_frame
		await get_tree().process_frame
		check(gift_info._pages.size() > 1, "16px gift detail paginates long descriptions")
		check_area(inv._relationship_ui.get_node("Design/Right"), "long 16px gift detail")
		check("".join(gift_info._pages).replace(" ", "").replace("\n", "") == long_gift_note.replace(" ", ""), "16px gift pagination preserves all text")
		inv._close()
		inv.queue_free()
		print("NPC DETAIL LAYOUT COMPLETE: failures=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	var top_tabs: Control = inv.get_node("%TopTabsContainer")
	check(top_tabs.position == Vector2(44, -40), "compact tabs match reference book inset and top margin")
	check(inv._top_tabs.size() == 8 and top_tabs.find_children("*", "Label", true, false).is_empty(), "all eight top tabs are icon-only")
	for index in inv._top_tabs.size():
		var tab: TextureButton = inv._top_tabs[index]
		check(tab.position.x == index * 44 and tab.size.x == 38, "tab %d uses equal width and six-unit spacing" % index)
		check(is_equal_approx(tab.position.y + tab.size.y, 42.0), "tab %d stays attached to book edge" % index)
		check(not tab.tooltip_text.is_empty() and tab.get_node("Icon").get_rect() == Rect2(7, 4, 24, 24), "tab %d has centred icon padding and accessible name" % index)
		tab.mouse_entered.emit()
		check(is_equal_approx(tab.position.y + tab.size.y, 42.0), "hover keeps tab %d attached" % index)
		tab.mouse_exited.emit()
	inv._show_bag_page()
	if DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("res://scratch/inventory_top_tabs_preview.png")
	# Native dropdown internals have no scene owner; page content must have no scrollers.
	check(inv.book_root.find_children("*", "ScrollContainer", true, true).is_empty(), "inventory contains no scroll containers")
	for method: String in ["_show_bag_page", "_show_status", "_show_equipment", "_show_crafting", "_show_skills", "_show_relationships", "_show_collection", "_on_gear_pressed"]:
		inv.call(method)
		await get_tree().process_frame
		await get_tree().process_frame
		var areas: Array[Control] = []
		if method == "_show_bag_page":
			areas.assign([inv.book_root.get_node("LeftPage"), inv.book_root.get_node("RightPage")])
		else:
			var pages: Dictionary = {"_show_status": inv._status_panel, "_show_equipment": inv._equipment_panel, "_show_crafting": inv._crafting_panel, "_show_skills": inv._skill_tree, "_show_relationships": inv._relationship_ui, "_show_collection": inv._collection_panel, "_on_gear_pressed": inv._settings_panel}
			var page: Control = pages[method]
			var design: Node = page.get_node("Design" if page.has_node("Design") else "Pages")
			areas.assign([design.get_child(0), design.get_child(1)])
		var count := 0
		for area: Control in areas:
			var bounds := area.get_global_rect().grow(0.2)
			for control: Node in area.find_children("*", "Control", true, false):
				if control.is_visible_in_tree():
					if not bounds.encloses(control.get_global_rect()):
						check(false, "%s outside paper: %s %s vs %s" % [method, area.get_path_to(control), control.get_global_rect(), bounds])
					count += 1
		print("CHECKED: %s (%d visible controls)" % [method, count])
	# Check secondary sections as well as the initial view of every tab.
	inv._on_gear_pressed()
	for index in 3:
		inv._settings_panel._select_section(index)
		await get_tree().process_frame
		check_area(inv._settings_panel.get_node("Pages/Left"), "settings section %d" % index)
	inv._show_relationships()
	inv._relationship_ui._open_npc("zarathia")
	for index in 4:
		inv._relationship_ui._select_section(index)
		await get_tree().process_frame
		check_area(inv._relationship_ui.get_node("%DetailsLeft"), "NPC left section %d" % index)
		check_area(inv._relationship_ui.get_node("Design/Right"), "NPC section %d" % index)
	inv._relationship_ui._select_section(2)
	for index in 5:
		inv._relationship_ui._select_category(index)
		await get_tree().process_frame
		check_area(inv._relationship_ui.get_node("Design/Right"), "gift category %d" % index)
	inv._show_collection()
	var detail = inv._collection_panel.get_node("%Detail")
	var source := "Kalimat panjang untuk memeriksa isi halaman buku. ".repeat(12)
	detail.text = source
	await get_tree().process_frame
	check(detail._pages.size() > 1, "long notes create text pages")
	var reconstructed := "".join(detail._pages).replace(" ", "").replace("\n", "")
	check(reconstructed == source.replace(" ", ""), "text pagination preserves every character")
	detail._change(1)
	check(detail._page == 1 and detail.get_node("Body").text == detail._pages[1], "text next reaches second page")
	inv._show_crafting()
	var pager = inv._crafting_panel.get_node("%RecipePager")
	var total: int = inv._crafting_panel._recipe_buttons.size()
	pager.reveal(total - 1)
	check(inv._crafting_panel._recipe_buttons[-1].visible, "last recipe reachable without scroll")
	check(not inv._crafting_panel._recipe_buttons[0].visible and pager.get_node("Next").disabled, "last recipe group excludes first group")
	pager.reveal(0)
	check(inv._crafting_panel._recipe_buttons[0].visible, "recipe pager returns to first group")
	inv._close()
	inv.queue_free()
	print("INVENTORY BOOK LAYOUT COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func check_area(area: Control, context: String) -> void:
	var bounds := area.get_global_rect().grow(0.2)
	for node: Node in area.find_children("*", "Control", true, false):
		if node.is_visible_in_tree() and not bounds.encloses(node.get_global_rect()):
			check(false, "%s outside paper: %s %s vs %s" % [context, area.get_path_to(node), node.get_global_rect(), bounds])
