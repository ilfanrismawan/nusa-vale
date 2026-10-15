class_name ToolUpgradeUI
extends CanvasLayer

const ServiceTheme = preload("res://scripts/ui/farm_service_theme.gd")

## UI Dialog Interaksi Upgrade Alat dengan NPC Pandai Besi (Blacksmith).
## Memungkinkan pemain melihat daftar alat di tas, biaya perakitan, dan material yang dibutuhkan.

signal finished

const FONT := preload("res://resources/ui/readable_font.tres")
const TEX_INVENTORY := preload("res://assets/farm_rpg/ui/inventory/inventory.png")
const TEX_BANNER := preload("res://assets/farm_rpg/ui/inventory/Banner.png")
const TEX_PORTRAIT := preload("res://assets/farm_rpg/Character/PNG/Portrait.png")
const TEX_CLOSE := preload("res://resources/ui/btn_close_x.tres")
const TEX_CLOSE_PRESSED := preload("res://resources/ui/btn_close_x_pressed.tres")

const COLOR_TEXT := Color(0.36, 0.2, 0.15)
const COLOR_TEXT_LIGHT := Color(0.97, 0.88, 0.78)
const COLOR_MONEY_OK := Color(0.18, 0.52, 0.22)
const COLOR_MONEY_BAD := Color(0.75, 0.2, 0.2)

var player: Player
var data: PlayerData:
	get: return player.data if is_instance_valid(player) else GameState.p1()

var _dialog_label: Label
var _money_label: Label
var _tool_list_box: VBoxContainer
var _detail_title: Label
var _detail_cost: Label
var _detail_materials: VBoxContainer
var _upgrade_btn: Button
var _selected_tool_entry: Dictionary = {}
var _result_icon: TextureRect
var _benefits: Label
var _order_progress: ProgressBar
var _closed := false

func _ready() -> void:
	layer = ServiceTheme.LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh_tools()
	Coop.set_menu_open(player, true)
	GameState.money_changed.connect(func(_money: int):
		_update_money_label()
		if not _selected_tool_entry.is_empty(): _select_tool(_selected_tool_entry))
	DayCycle.day_passed.connect(func(_day: int): _refresh_tools())

func _input(event: InputEvent) -> void:
	var input := player.input if is_instance_valid(player) else PlayerInput.solo()
	if input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if _closed: return
	_closed = true
	hide()
	set_process_input(false)
	Coop.set_menu_open(player, false)
	finished.emit()
	queue_free()

func _exit_tree() -> void:
	if not _closed and is_instance_valid(player): Coop.set_menu_open(player, false)

func _build_ui() -> void:
	var ui_theme := ServiceTheme.make_theme()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.theme = ui_theme
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 340)
	panel.add_theme_stylebox_override("panel", _style(TEX_INVENTORY, Rect2(0, 64, 48, 48), 8, 12))
	center.add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(main_vbox)

	# Header (Judul + Tombol Tutup)
	var header := HBoxContainer.new()
	main_vbox.add_child(header)

	var title := Label.new()
	title.text = "BENGKEL TEMPA — EMPU BIMA"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", COLOR_TEXT)
	header.add_child(title)

	var close_btn := TextureButton.new()
	close_btn.texture_normal = TEX_CLOSE
	close_btn.texture_pressed = TEX_CLOSE_PRESSED
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	# Konten Tengah (Kolom Kiri: NPC, Kolom Kanan: Daftar Alat & Detail)
	var body_hbox := HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 10)
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(body_hbox)

	body_hbox.add_child(_build_npc_column())
	body_hbox.add_child(_build_tools_column())
	ServiceTheme.mount(self, panel, Vector2(750, 420))

func _build_npc_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(140, 0)
	col.add_theme_constant_override("separation", 6)

	var portrait_panel := PanelContainer.new()
	portrait_panel.add_theme_stylebox_override("panel", _style(TEX_INVENTORY, Rect2(7, 9, 18, 18), 4, 4))
	col.add_child(portrait_panel)

	var portrait := ServiceTheme.blacksmith_portrait()
	portrait_panel.add_child(portrait)

	var name_panel := PanelContainer.new()
	name_panel.add_theme_stylebox_override("panel", _row_style(false))
	var name_label := Label.new()
	name_label.text = "Empu Bima (Pandai Besi)"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_panel.add_child(name_label)
	col.add_child(name_panel)

	var dialog_panel := PanelContainer.new()
	dialog_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog_panel.add_theme_stylebox_override("panel", _style(TEX_BANNER, Rect2(0, 0, 48, 48), 8, 8))
	_dialog_label = Label.new()
	_dialog_label.text = "Bawa alat dan batangan logam kemari. Aku akan menempanya jadi lebih kuat!"
	_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_label.custom_minimum_size = Vector2(120, 0)
	dialog_panel.add_child(_dialog_label)
	col.add_child(dialog_panel)

	var money_panel := PanelContainer.new()
	money_panel.add_theme_stylebox_override("panel", _row_style(true))
	_money_label = Label.new()
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_label.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
	money_panel.add_child(_money_label)
	col.add_child(money_panel)
	_update_money_label()

	return col

func _build_tools_column() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)

	# Daftar Alat Pemain
	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(190, 0)
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_stylebox_override("panel", _panel_style())
	hbox.add_child(list_panel)

	var list_vbox := VBoxContainer.new()
	list_panel.add_child(list_vbox)

	var list_title := Label.new()
	list_title.text = "Alat di Tas"
	list_vbox.add_child(list_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_vbox.add_child(scroll)

	_tool_list_box = VBoxContainer.new()
	_tool_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_list_box.add_theme_constant_override("separation", 3)
	scroll.add_child(_tool_list_box)

	# Panel Detail Upgrade
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _panel_style())
	hbox.add_child(detail_panel)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 6)
	detail_panel.add_child(detail_vbox)
	_result_icon = TextureRect.new()
	_result_icon.custom_minimum_size = Vector2(48, 48)
	_result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_vbox.add_child(_result_icon)

	_detail_title = Label.new()
	_detail_title.custom_minimum_size.x = 180
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title.text = "Pilih alat untuk ditempa"
	detail_vbox.add_child(_detail_title)

	_detail_cost = Label.new()
	_detail_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_cost.text = ""
	detail_vbox.add_child(_detail_cost)
	_benefits = Label.new()
	_benefits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_benefits.add_theme_font_size_override("font_size", 14)
	detail_vbox.add_child(_benefits)
	_order_progress = ProgressBar.new()
	_order_progress.max_value = ToolUpgradeManager.WORK_DAYS
	_order_progress.show_percentage = false
	_order_progress.custom_minimum_size.y = 12
	_order_progress.add_theme_stylebox_override("background", ServiceTheme.ribbon())
	_order_progress.add_theme_stylebox_override("fill", ServiceTheme.ribbon(true))
	_order_progress.hide()
	detail_vbox.add_child(_order_progress)

	var mat_label := Label.new()
	mat_label.text = "Material Dibutuhkan:"
	detail_vbox.add_child(mat_label)

	var mat_scroll := ScrollContainer.new()
	mat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(mat_scroll)

	_detail_materials = VBoxContainer.new()
	_detail_materials.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mat_scroll.add_child(_detail_materials)

	_upgrade_btn = Button.new()
	_upgrade_btn.text = "Pesan upgrade · %d hari" % ToolUpgradeManager.WORK_DAYS
	_upgrade_btn.disabled = true
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	detail_vbox.add_child(_upgrade_btn)

	return hbox

func _refresh_tools() -> void:
	for child in _tool_list_box.get_children():
		child.queue_free()

	_selected_tool_entry = {}
	_clear_detail()
	_update_money_label()

	var tools_found: Array[Dictionary] = []
	var inv: Array = data.inventory if data != null else []

	for slot_idx in inv.size():
		var slot = inv[slot_idx]
		if slot == null or slot.get("item") == null:
			continue
		var item: ItemData = slot["item"]
		if item.category == ItemData.Category.TOOL and item.is_tool():
			tools_found.append({
				"slot_idx": slot_idx,
				"item": item
			})

	if not data.tool_order.is_empty():
		var waiting := ToolUpgradeManager.days_remaining(data)
		_upgrade_btn.text = "Ambil alat" if waiting == 0 else "Sedang dikerjakan"
		_upgrade_btn.disabled = waiting > 0
		var item := GameState._resolve_item(str(data.tool_order["next"]))
		_result_icon.texture = item.icon
		_order_progress.show()
		_order_progress.value = ToolUpgradeManager.WORK_DAYS - waiting
		_benefits.text = "Siap pada hari %d · ambil di bengkel ini" % int(data.tool_order.ready_day)
		var order_button := Button.new()
		order_button.text = "Ambil %s" % item.display_name if waiting == 0 else "%s — %d hari lagi" % [item.display_name, waiting]
		order_button.disabled = waiting > 0
		order_button.pressed.connect(func():
			if ToolUpgradeManager.collect_tool(data):
				_refresh_tools())
		_tool_list_box.add_child(order_button)
		_dialog_label.text = "Pesananmu siap. Ambil alat di daftar sebelah." if waiting == 0 else "Alatmu sedang kutempa. Selesai dalam %d hari lagi." % waiting
		_detail_title.text = item.display_name
		_detail_cost.text = "Siap diambil!" if waiting == 0 else "Sedang ditempa · %d hari lagi" % waiting
		var hint := Label.new()
		hint.text = "Alat ditahan di bengkel.\nSediakan satu slot kosong saat mengambil."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_materials.add_child(hint)
		return

	if tools_found.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Tidak ada alat di tas."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.3))
		_tool_list_box.add_child(empty_lbl)
		return

	for entry in tools_found:
		var item: ItemData = entry["item"]
		var btn := Button.new()
		btn.text = item.display_name
		btn.toggle_mode = true
		btn.set_meta("tool_id", item.item_id)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = item.icon
		btn.expand_icon = true
		btn.custom_minimum_size.y = 28
		btn.pressed.connect(_select_tool.bind(entry))
		_tool_list_box.add_child(btn)

	# Pilih alat pertama secara otomatis
	if not tools_found.is_empty():
		_select_tool(tools_found[0])

func _select_tool(entry: Dictionary) -> void:
	_selected_tool_entry = entry
	var item: ItemData = entry["item"]
	for button in _tool_list_box.get_children():
		if button is Button and button.has_meta("tool_id"):
			button.set_pressed_no_signal(button.get_meta("tool_id") == item.item_id)
	_result_icon.texture = item.icon
	_benefits.text = ""

	for child in _detail_materials.get_children():
		child.queue_free()

	if not ToolUpgradeManager.can_upgrade(item.item_id):
		_detail_title.text = "%s (Maksimal)" % item.display_name
		_detail_cost.text = "Tingkat alat ini sudah maksimal."
		_upgrade_btn.disabled = true
		_dialog_label.text = "Keahlian alat ini sudah luar biasa, aku tidak bisa meningkatkannya lagi!"
		return

	var up_data: Dictionary = ToolUpgradeManager.get_upgrade_data(item.item_id)
	var next_id: String = up_data.get("next", "")
	var next_res := GameState._resolve_item(next_id)
	if next_res != null:
		_result_icon.texture = next_res.icon
		var before: ToolData = item.action_data.tool_data
		var after: ToolData = next_res.action_data.tool_data
		_benefits.text = "Stamina %s → %s · Area %d → %d petak" % [str(before.stamina_cost), str(after.stamina_cost), before.area_size, after.area_size]
		if after.tool_type in [ToolData.ToolType.AXE, ToolData.ToolType.PICKAXE]:
			var access := "kecil/normal" if after.tier == ToolData.ToolTier.COPPER else "kecil/normal/besar"
			_benefits.text += "\nKekuatan %d → %d · Objek %s" % [before.damage, after.damage, access]
	var next_name: String = next_res.display_name if next_res != null else next_id
	var cost: int = int(up_data.get("cost", 0))

	_detail_title.text = "Upgrade ke: %s" % next_name
	_detail_cost.text = "Biaya: %d G · Waktu: %d hari\nAlat ditahan sampai diambil." % [cost, ToolUpgradeManager.WORK_DAYS]
	if GameState.money >= cost:
		_detail_cost.text += "\nSisa saldo: %d G" % (GameState.money - cost)
	if GameState.money >= cost:
		_detail_cost.add_theme_color_override("font_color", COLOR_MONEY_OK)
	else:
		_detail_cost.add_theme_color_override("font_color", COLOR_MONEY_BAD)

	var materials: Dictionary = up_data.get("materials", {})
	var has_all_materials := true

	for mat_id in materials:
		var req_count: int = int(materials[mat_id])
		var current_count: int = data.get_item_count(mat_id)
		var mat_res := GameState._resolve_item(mat_id)
		var mat_name: String = mat_res.display_name if mat_res != null else mat_id

		var mat_row := HBoxContainer.new()
		if mat_res != null and mat_res.icon != null:
			var mat_icon := TextureRect.new()
			mat_icon.texture = mat_res.icon
			mat_icon.custom_minimum_size = Vector2(16, 16)
			mat_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mat_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mat_row.add_child(mat_icon)

		var lbl := Label.new()
		lbl.text = "%s: %d/%d" % [mat_name, current_count, req_count]
		if current_count >= req_count:
			lbl.add_theme_color_override("font_color", COLOR_MONEY_OK)
		else:
			lbl.add_theme_color_override("font_color", COLOR_MONEY_BAD)
			has_all_materials = false
		mat_row.add_child(lbl)
		_detail_materials.add_child(mat_row)

	var can_afford := (GameState.money >= cost) and has_all_materials
	_upgrade_btn.disabled = not can_afford or not data.tool_order.is_empty()
	if can_afford:
		_dialog_label.text = "Bahan dan biaya sudah lengkap! Serahkan padaku untuk kutempa."
	else:
		_dialog_label.text = "Kamu masih kekurangan koin atau batangan logam untuk menempa %s." % next_name

func _clear_detail() -> void:
	_detail_title.text = "Pilih alat untuk ditempa"
	_detail_cost.text = ""
	_upgrade_btn.disabled = true
	_upgrade_btn.text = "Pesan upgrade · %d hari" % ToolUpgradeManager.WORK_DAYS
	_order_progress.hide()
	_result_icon.texture = null
	_benefits.text = ""
	for child in _detail_materials.get_children():
		child.queue_free()

func _update_money_label() -> void:
	if _money_label != null:
		_money_label.text = "%d G" % GameState.money

func _on_upgrade_pressed() -> void:
	if not data.tool_order.is_empty():
		if ToolUpgradeManager.collect_tool(data): _refresh_tools()
		return
	if _selected_tool_entry.is_empty():
		return
	var item: ItemData = _selected_tool_entry["item"]
	GameState.use_player(player)

	var success: bool = ToolUpgradeManager.upgrade_tool(item.item_id)
	if success:
		if is_instance_valid(player) and player.tool_controller != null:
			player.tool_controller.select_tool(player.tool_controller.current_index)
		_dialog_label.text = "Alatmu sedang ditempa. Kembali setelah dua hari."
		_refresh_tools()

func _panel_style() -> StyleBoxTexture:
	return ServiceTheme.frame()

func _row_style(dark: bool) -> StyleBoxTexture:
	return ServiceTheme.ribbon(dark)

func _style(tex: Texture2D, region: Rect2, tex_margin: int, content_margin: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.region_rect = region
	sb.set_texture_margin_all(tex_margin)
	sb.set_content_margin_all(content_margin)
	return sb
