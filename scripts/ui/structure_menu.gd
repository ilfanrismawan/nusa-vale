extends CanvasLayer

const FONT = preload("res://assets/fonts/m5x7.ttf")
var player: Player
var uid := 0
var _panel: PanelContainer
var _content: VBoxContainer
var _status: Label
var _title: Label
var _opened := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 45
	_panel = PanelContainer.new()
	_panel.size = Vector2(520, 330)
	var vp := get_viewport().get_visible_rect().size
	var zoom := minf(1.0, minf((vp.x - 20) / 520, (vp.y - 20) / 330))
	_panel.scale = Vector2.ONE * zoom
	_panel.position = ((vp - _panel.size * zoom) / 2).floor()
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("50321f"))
	_panel.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color("efd9b2")
	style.border_color = Color("997039")
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var rows := VBoxContainer.new()
	_panel.add_child(rows)
	var heading := HBoxContainer.new()
	rows.add_child(heading)
	var title := Label.new()
	_title = title
	var record := StructureManager.record_for(uid)
	title.text = GameState._resolve_item(record.item).display_name
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := _button("Tutup (Esc)", _close)
	heading.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	_status = Label.new()
	_status.custom_minimum_size.y = 28
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_status)
	var pack := _button("Kemas kembali ke tas", _pack)
	rows.add_child(pack)
	StructureManager.changed.connect(_refresh)
	GameState.inventory_changed.connect(_refresh)
	_opened = true
	Coop.set_menu_open(player, true)
	_refresh()

func _button(text: String, callback: Callable) -> Button:
	var button: Button = player.ui_inventory._make_menu_button(text)
	button.pressed.connect(callback)
	return button

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label

func _refresh() -> void:
	var record := StructureManager.record_for(uid)
	if record.is_empty():
		_close()
		return
	var building := GameState._resolve_item(record.item)
	_title.text = building.display_name
	if record.item in StructureManager.CHESTS:
		_title.text += " · Tier %d · %d slot" % [building.chest_tier + 1, building.storage_slots]
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match record.item:
		"wooden_chest", "copper_chest", "iron_chest", "gold_chest":
			var columns := HBoxContainer.new()
			columns.add_theme_constant_override("separation", 14)
			_content.add_child(columns)
			var chest := StructureManager.storage(record)
			for deposit in [true, false]:
				var list := VBoxContainer.new()
				list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				columns.add_child(list)
				_label(list, "TAS P%d → PETI" % (player.data.index + 1) if deposit else "PETI (%d SLOT) → TAS" % chest.bag_size)
				var source := player.data if deposit else chest
				var used := 0
				for slot in source.bag_size:
					if source.inventory[slot] == null:
						continue
					used += 1
					var item: ItemData = source.inventory[slot]["item"]
					var button := _button("%s x%d" % [item.display_name, source.inventory[slot]["count"]], _transfer.bind(slot, deposit))
					button.icon = item.icon
					button.expand_icon = true
					button.add_theme_constant_override("icon_max_width", 18)
					button.clip_text = true
					button.tooltip_text = ("Simpan " if deposit else "Ambil ") + item.display_name + " (satu tumpukan)."
					list.add_child(button)
				if used == 0:
					_label(list, "Kosong")
			var next := StructureManager.next_chest_recipe(uid)
			if next != null:
				var target := GameState._resolve_item(next.output_item_id)
				var costs: PackedStringArray = []
				var available := true
				for id in next.ingredients:
					costs.append("%s x%d" % [GameState._resolve_item(id).display_name, next.ingredients[id]])
					available = available and player.data.has_item(id, next.ingredients[id])
				_label(_content, "Bahan upgrade: " + ", ".join(costs))
				var upgrade := _button("Upgrade → %s (%d slot)" % [target.display_name, target.storage_slots], _upgrade)
				upgrade.disabled = not available
				upgrade.tooltip_text = "Bahan diambil dari tas Anda. Isi dan posisi peti tetap tersimpan."
				_content.add_child(upgrade)
			else:
				_label(_content, "Tier tertinggi · 60 slot")
			_status.text = "Klik item untuk memindahkan satu tumpukan. Peti dipakai bersama."
		"furnace":
			if not record.job.is_empty():
				_label(_content, "Sedang melebur. Hasil tetap tersimpan sampai diambil.")
			elif not record.ready.is_empty():
				var item := GameState._resolve_item(record.ready.id)
				_content.add_child(_button("Ambil %s x%d" % [item.display_name, record.ready.count], _collect))
			else:
				_label(_content, "Pilih bijih dari tas untuk dilebur:")
				for recipe in StructureManager.furnace_recipes():
					var input := GameState._resolve_item(recipe.input_item_id)
					var output := GameState._resolve_item(recipe.output_item_id)
					var button := _button("%s x%d → %s x%d" % [input.display_name, recipe.input_amount, output.display_name, recipe.output_amount], _smelt.bind(recipe))
					button.disabled = not player.data.has_item(recipe.input_item_id, recipe.input_amount)
					_content.add_child(button)
			_status.text = "Proses dan hasil furnace ikut tersimpan saat save."
		"wooden_gate":
			_content.add_child(_button("Tutup gerbang" if record.open else "Buka gerbang", _toggle))
			_status.text = "Gerbang terbuka bisa dilewati pemain."
		"crafting_workbench":
			_content.add_child(_button("Buka Crafting", _open_crafting))
			_status.text = "Meja kerja untuk membuat perlengkapan dan bangunan."
		_:
			_label(_content, "Pagar pembatas farm. Kemas kembali jika ingin memindahkannya.")
			_status.text = "Bangunan dikembalikan utuh tanpa biaya bahan tambahan."

func _transfer(slot: int, deposit: bool) -> void:
	var result := StructureManager.transfer(player.data, uid, slot, deposit)
	_refresh()
	_status.text = result.message

func _upgrade() -> void:
	var result := StructureManager.upgrade_chest(player.data, uid)
	_refresh()
	_status.text = result.message

func _smelt(recipe: FurnaceRecipe) -> void:
	var result := StructureManager.smelt(player.data, uid, recipe)
	_refresh()
	_status.text = result.message

func _collect() -> void:
	var result := StructureManager.collect(player.data, uid)
	_refresh()
	_status.text = result.message

func _toggle() -> void:
	StructureManager.toggle_gate(uid)
	_close()

func _open_crafting() -> void:
	_close()
	player.ui_inventory._open()
	player.ui_inventory._show_crafting()

func _pack() -> void:
	var result := StructureManager.pack(player.data, uid)
	if result.ok:
		_close()
	else:
		_status.text = result.message

func _input(event: InputEvent) -> void:
	if player.input.is_event(event, &"ui_cancel") or player.input.is_event(event, &"inventory"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if not _opened:
		return
	_opened = false
	set_process_input(false)
	hide()
	Coop.set_menu_open(player, false)
	queue_free()

func _exit_tree() -> void:
	if _opened and is_instance_valid(player):
		Coop.set_menu_open(player, false)
