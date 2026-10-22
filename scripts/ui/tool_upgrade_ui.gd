class_name ToolUpgradeUI
extends CanvasLayer

const Presentation = preload("res://scripts/resources/blacksmith_presentation.gd")
signal finished

@export var presentation: Presentation = preload("res://resources/ui/blacksmith_presentation.tres")
@export var card_scene: PackedScene = preload("res://scenes/ui/blacksmith_tool_card.tscn")
@export var material_scene: PackedScene = preload("res://scenes/ui/blacksmith_material_row.tscn")
@export var design_size := Vector2(1600, 800)

var player: Player
var social_npc_id := ""
var data: PlayerData:
	get: return player.data if is_instance_valid(player) else GameState.p1()
var _selected_tool_entry: Dictionary = {}
var _entries: Array[Dictionary] = []
var _kinds: PackedStringArray = []
var _page := 0
var _closed := false
var _refresh_pending := false

@onready var _dialog_label: Label = %Dialog
@onready var _money_label: Label = %Money
@onready var _tool_list_box: GridContainer = %Tools
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_cost: Label = %DetailCost
@onready var _detail_materials: VBoxContainer = %Materials
@onready var _upgrade_btn: Button = %UpgradeButton
@onready var _result_icon: TextureRect = %ResultIcon
@onready var _benefits: Label = %Benefits
@onready var _order_progress: ProgressBar = %OrderProgress

func _ready() -> void:
	layer = FarmServiceTheme.LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	%VendorName.text = presentation.vendor_name
	_dialog_label.text = presentation.greeting
	%VendorOverride.texture = presentation.vendor_art
	%VendorOverride.visible = presentation.vendor_art != null
	%PortraitLayers.visible = presentation.vendor_art == null
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	%CloseButton.pressed.connect(_close)
	%SocialButton.visible = NPCSocialService.known(social_npc_id)
	%SocialButton.pressed.connect(_open_social_dialog)
	%PreviousPage.pressed.connect(_change_page.bind(-1))
	%NextPage.pressed.connect(_change_page.bind(1))
	get_viewport().size_changed.connect(_resize)
	GameState.money_changed.connect(_money_changed)
	GameState.inventory_changed.connect(_queue_refresh)
	DayCycle.day_passed.connect(_day_changed)
	for kind in presentation.tool_order:
		if kind in ToolUpgradeManager.TOOL_TYPES and not _kinds.has(kind):
			_kinds.append(kind)
	for kind in ToolUpgradeManager.TOOL_TYPES:
		if not _kinds.has(kind):
			_kinds.append(kind)
	_build_entries()
	_refresh_tools()
	_resize()
	Coop.set_menu_open(player, true)

func _open_social_dialog() -> void:
	_close()
	NPCSocialService.open_dialog(player, social_npc_id, presentation.vendor_name, presentation.vendor_art)

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

func _build_entries() -> void:
	for kind in _kinds:
		for index in range(1, ToolUpgradeManager.TIERS.size()):
			var source := kind + "_" + ToolUpgradeManager.TIERS[index - 1]
			var upgrade := ToolUpgradeManager.get_upgrade_data(source)
			var item := GameState._resolve_item(source)
			if item != null and not upgrade.is_empty():
				_entries.append({"item": item, "next": str(upgrade.next), "tier_index": index - 1, "kind": kind})

func _owned_id(id: String) -> String:
	if data.has_item(id):
		return id
	if id.ends_with("_wood") and data.has_item(id.trim_suffix("_wood")):
		return id.trim_suffix("_wood")
	return id

func _page_count() -> int:
	return ceili(float(ToolUpgradeManager.TIERS.size() - 1) / presentation.tiers_per_page)

func _change_page(direction: int) -> void:
	_page = posmod(_page + direction, _page_count())
	_build_cards()
	var page_entries := _entries.filter(func(entry: Dictionary): return int(entry.tier_index) / presentation.tiers_per_page == _page)
	if not page_entries.is_empty():
		_select_tool(page_entries[0])

func _build_cards() -> void:
	for child in _tool_list_box.get_children():
		_tool_list_box.remove_child(child)
		child.queue_free()
	_tool_list_box.columns = presentation.tiers_per_page
	for kind in _kinds:
		for column in presentation.tiers_per_page:
			var tier_index := _page * presentation.tiers_per_page + column
			var card := card_scene.instantiate() as Button
			_tool_list_box.add_child(card)
			if tier_index >= ToolUpgradeManager.TIERS.size() - 1:
				card.disabled = true
				card.modulate.a = 0.15
				continue
			var output_id := kind + "_" + ToolUpgradeManager.TIERS[tier_index + 1]
			var entry: Dictionary = {}
			for candidate in _entries:
				if candidate.next == output_id:
					entry = candidate
					break
			if entry.is_empty():
				card.disabled = true
				continue
			var result := GameState._resolve_item(output_id)
			card.get_node("Icon").texture = result.icon if result != null else null
			card.set_meta("entry", entry)
			card.tooltip_text = result.display_name if result != null else output_id
			card.pressed.connect(_select_tool.bind(entry))
			card.focus_entered.connect(_select_tool.bind(entry))
			card.get_node("Icon").modulate = Color.WHITE if data.has_item(_owned_id(entry.item.item_id)) else Color(0.68, 0.68, 0.68)
	var start := _page * presentation.tiers_per_page + 1
	var end := mini(start + presentation.tiers_per_page - 1, ToolUpgradeManager.TIERS.size() - 1)
	var first: String = ToolUpgradeManager.TIERS[start]
	var last: String = ToolUpgradeManager.TIERS[end]
	%TierPage.text = "%s — %s   %d/%d" % [presentation.tier_labels.get(first, first), presentation.tier_labels.get(last, last), _page + 1, _page_count()]

func _queue_refresh() -> void:
	if _refresh_pending or _closed:
		return
	_refresh_pending = true
	_refresh_tools.call_deferred()

func _money_changed(_money: int) -> void:
	_update_money_label()
	if not _selected_tool_entry.is_empty():
		_select_tool(_selected_tool_entry)

func _day_changed(_day: int) -> void:
	_refresh_tools()

func _refresh_tools() -> void:
	_refresh_pending = false
	if _closed:
		return
	_update_money_label()
	if not data.tool_order.is_empty():
		if _selected_tool_entry.is_empty():
			for entry in _entries:
				if entry.next == str(data.tool_order.next):
					_selected_tool_entry = entry
					_page = floori(float(entry.tier_index) / presentation.tiers_per_page)
					break
		_build_cards()
		_show_order()
		return
	if _selected_tool_entry.is_empty():
		for entry in _entries:
			if data.has_item(_owned_id(entry.item.item_id)):
				_selected_tool_entry = entry
				_page = floori(float(entry.tier_index) / presentation.tiers_per_page)
				break
		if _selected_tool_entry.is_empty() and not _entries.is_empty():
			_selected_tool_entry = _entries[0]
	_build_cards()
	if not _selected_tool_entry.is_empty():
		_select_tool(_selected_tool_entry)

func _clear_materials() -> void:
	for child in _detail_materials.get_children():
		_detail_materials.remove_child(child)
		child.queue_free()

func _select_tool(entry: Dictionary) -> void:
	if not data.tool_order.is_empty():
		_show_order()
		return
	_selected_tool_entry = entry
	var item: ItemData = entry.item
	var upgrade := ToolUpgradeManager.get_upgrade_data(item.item_id)
	if upgrade.is_empty():
		_upgrade_btn.disabled = true
		return
	var result := GameState._resolve_item(str(upgrade.next))
	_result_icon.texture = result.icon
	_detail_title.text = result.display_name
	%Description.text = _description(result)
	_detail_cost.text = "◷ %d hari pengerjaan\n● %d G" % [ToolUpgradeManager.WORK_DAYS, int(upgrade.cost)]
	if GameState.money >= int(upgrade.cost):
		_detail_cost.text += "\nSisa saldo: %d G" % (GameState.money - int(upgrade.cost))
	_order_progress.hide()
	_upgrade_btn.text = "Pesan upgrade · %d hari" % ToolUpgradeManager.WORK_DAYS
	_clear_materials()
	var owned := data.has_item(_owned_id(item.item_id))
	_add_material(item, 1 if owned else 0, 1)
	var enough := owned and GameState.money >= int(upgrade.cost)
	for id in upgrade.materials:
		var count := data.get_item_count(id)
		var required := int(upgrade.materials[id])
		_add_material(GameState._resolve_item(id), count, required)
		enough = enough and count >= required
	_upgrade_btn.disabled = not enough
	%Availability.text = "" if enough else "Alat sebelumnya belum dimiliki." if not owned else "Koin atau bahan tempa belum lengkap."
	var before: ToolData = item.action_data.tool_data
	var after: ToolData = result.action_data.tool_data
	_benefits.text = "Stamina %s → %s · Area %d → %d petak" % [str(before.stamina_cost), str(after.stamina_cost), before.area_size, after.area_size]
	if after.tool_type in [ToolData.ToolType.AXE, ToolData.ToolType.PICKAXE]:
		var access := "kecil/normal" if after.tier == ToolData.ToolTier.COPPER else "kecil/normal/besar"
		_benefits.text += "\nKekuatan %d → %d · Objek %s" % [before.damage, after.damage, access]
	_highlight(str(upgrade.next))

func _add_material(item: ItemData, count: int, required: int) -> void:
	var row := material_scene.instantiate()
	_detail_materials.add_child(row)
	row.get_node("Layout/Icon").texture = item.icon if item != null else null
	row.get_node("Layout/Name").text = item.display_name if item != null else "Material"
	row.get_node("Layout/Count").text = "%d / %d" % [count, required]
	row.get_node("Layout/Count").add_theme_color_override("font_color", presentation.enough_material_color if count >= required else presentation.missing_material_color)

func _description(item: ItemData) -> String:
	if not item.description.is_empty():
		return item.description
	var parsed := ToolUpgradeManager._parse_tool(item.item_id)
	return presentation.descriptions.get(str(parsed.get("type", "")), "")

func _highlight(output_id: String) -> void:
	for card in _tool_list_box.get_children():
		if card.has_meta("entry"):
			card.set_pressed_no_signal(card.get_meta("entry").next == output_id)

func _show_order() -> void:
	var item := GameState._resolve_item(str(data.tool_order.next))
	var waiting := ToolUpgradeManager.days_remaining(data)
	_result_icon.texture = item.icon
	_detail_title.text = item.display_name
	%Description.text = _description(item)
	_detail_cost.text = "Siap diambil!" if waiting == 0 else "Sedang ditempa · %d hari lagi" % waiting
	_benefits.text = "Siap pada hari %d · ambil di bengkel ini" % int(data.tool_order.ready_day)
	_order_progress.max_value = ToolUpgradeManager.WORK_DAYS
	_order_progress.value = ToolUpgradeManager.WORK_DAYS - waiting
	_order_progress.show()
	_upgrade_btn.text = "Ambil alat" if waiting == 0 else "Sedang dikerjakan"
	_upgrade_btn.disabled = waiting > 0
	_dialog_label.text = "Pesananmu siap diambil!" if waiting == 0 else "Alatmu sedang kutempa. Kembali setelah %d hari." % waiting
	%Availability.text = "Sediakan satu slot kosong saat mengambil alat."
	_clear_materials()
	_add_material(item, 1 if waiting == 0 else 0, 1)
	_highlight(str(data.tool_order.next))

func _update_money_label() -> void:
	_money_label.text = "● %d G" % GameState.money

func _on_upgrade_pressed() -> void:
	if not data.tool_order.is_empty():
		if ToolUpgradeManager.collect_tool(data):
			_selected_tool_entry = {}
			_dialog_label.text = presentation.greeting
			_refresh_tools()
		return
	if _selected_tool_entry.is_empty() or _upgrade_btn.disabled:
		return
	var item: ItemData = _selected_tool_entry.item
	GameState.use_player(player if is_instance_valid(player) else data)
	if ToolUpgradeManager.upgrade_tool(item.item_id):
		if is_instance_valid(player) and player.tool_controller != null:
			player.tool_controller.select_tool(player.tool_controller.current_index)
		_refresh_tools()

func _input(event: InputEvent) -> void:
	var input := player.input if is_instance_valid(player) else PlayerInput.solo()
	if input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
	elif input.uses_mouse() and event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER: _on_upgrade_pressed()
			KEY_Q: _change_page(-1)
			KEY_R: _change_page(1)
			_: return
		get_viewport().set_input_as_handled()
	elif not input.uses_mouse():
		if input.is_event(event, &"ui_accept"):
			_on_upgrade_pressed()
		elif input.is_event(event, &"tool_prev"):
			_change_page(-1)
		elif input.is_event(event, &"tool_next"):
			_change_page(1)
		elif not input.is_event(event, &"move_left") and not input.is_event(event, &"move_right") and not input.is_event(event, &"move_up") and not input.is_event(event, &"move_down"):
			return
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or player.input.uses_mouse() or not data.tool_order.is_empty():
		return
	var direction := 0
	if player.input.just_pressed(&"move_right"): direction = 1
	elif player.input.just_pressed(&"move_left"): direction = -1
	elif player.input.just_pressed(&"move_down"): direction = presentation.tiers_per_page
	elif player.input.just_pressed(&"move_up"): direction = -presentation.tiers_per_page
	if direction == 0:
		return
	var cards := _tool_list_box.get_children().filter(func(card: Node): return card.has_meta("entry"))
	var selected := 0
	for index in cards.size():
		if cards[index].button_pressed:
			selected = index
			break
	var card: Control = cards[posmod(selected + direction, cards.size())]
	_select_tool(card.get_meta("entry"))
	%ToolScroll.ensure_control_visible(card)

func _close() -> void:
	if _closed: return
	_closed = true
	Coop.set_menu_open(player, false)
	finished.emit()
	queue_free()

func _exit_tree() -> void:
	if not _closed and is_instance_valid(player):
		Coop.set_menu_open(player, false)
