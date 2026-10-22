extends CanvasLayer

const ServiceTheme = preload("res://scripts/ui/farm_service_theme.gd")

const FONT = preload("res://resources/ui/readable_font.tres")
const PreservesJarRecipe = preload("res://scripts/resources/preserves_jar_recipe.gd")
const DehydratorRecipe = preload("res://scripts/resources/dehydrator_recipe.gd")
var player: Player
var uid := 0
var _panel: PanelContainer
var _content: VBoxContainer
var _status: Label
var _title: Label
var _opened := false
var _progress_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = ServiceTheme.LAYER
	_panel = PanelContainer.new()
	_panel.size = Vector2(520, 330)
	var vp := get_viewport().get_visible_rect().size
	var zoom := minf(1.0, minf((vp.x - 20) / 520, (vp.y - 20) / 330))
	_panel.scale = Vector2.ONE * zoom
	_panel.position = ((vp - _panel.size * zoom) / 2).floor()
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var theme := ServiceTheme.make_theme()
	_panel.theme = theme
	var style := ServiceTheme.frame()
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
	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 16)
	rows.add_child(_progress_label)
	var pack := _button("Kemas kembali ke tas", _pack)
	rows.add_child(pack)
	StructureManager.changed.connect(_refresh)
	GameState.inventory_changed.connect(_refresh)
	_opened = true
	Coop.set_menu_open(player, true)
	_refresh()

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 28
	button.pressed.connect(callback)
	return button

func _process(_delta: float) -> void:
	if _progress_label == null:
		return
	var record := StructureManager.record_for(uid)
	_progress_label.visible = not record.is_empty() and record.job.has("seconds")
	if _progress_label.visible:
		_progress_label.text = "Sisa %.1f detik aktif%s" % [maxf(0, float(record.job.seconds)), " · Dijeda" if get_tree().paused or not DayCycle.is_running else ""]

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
		"mayonnaise_maker", "cheese_press", "loom", "keg", "oil_maker", "fish_smoker":
			if not record.job.is_empty():
				_label(_content, "Sedang mengolah. Hasil siap setelah 20 detik permainan aktif.")
			elif not record.ready.is_empty():
				_content.add_child(_button("Ambil " + GameState._resolve_item(record.ready.id).display_name, _collect))
			else:
				var options := StructureManager.artisan_options(player.data, str(record.item))
				var prompt := "Pilih bahan olahan dari tas:"
				match str(record.item):
					"keg": prompt = "Pilih gandum, madu, buah, atau sayur dari tas:"
					"oil_maker": prompt = "Pilih jagung, bunga matahari, bawang, atau truffle dari tas:"
					"fish_smoker": prompt = "Pilih ikan mentah dari tas untuk diasap:"
					_: prompt = "Pilih hasil ternak dari tas:"
				_label(_content, prompt if not options.is_empty() else "Bahan yang sesuai tidak ditemukan di tasmu.")
				for id in options:
					var output := StructureManager.artisan_output(str(record.item), id)
					_content.add_child(_button("%s → %s" % [GameState._resolve_item(id).display_name, GameState._resolve_item(output).display_name], _artisan.bind(id)))
			_status.text = "Satu bahan menjadi satu olahan; kualitas bahan dipertahankan."
		"lightning_rod":
			if not record.ready.is_empty():
				_content.add_child(_button("Ambil " + GameState._resolve_item(record.ready.id).display_name, _collect))
				_status.text = "Battery Pack terkumpul dari sambaran petir badai!"
			else:
				_label(_content, "Penangkal petir siap menyerap energi sambaran Badai Petir.")
				_status.text = "Hasilkan Battery Pack keesokan paginya jika terjadi Badai Petir."
		"silo":
			_label(_content, "Cadangan jerami: %d/240" % int(record.get("hay", 0)))
			_content.add_child(_button("Simpan 10 jerami dari tas", _hay.bind(true)))
			_content.add_child(_button("Ambil 10 jerami ke tas", _hay.bind(false)))
			_status.text = "Menebas rumput liar di ladang mengisi silo. Kandang Deluxe mengambil pakan setiap pagi."
		"pasture_grass":
			_label(_content, "Rumput siap dimakan" if int(record.get("regrow_day", 0)) <= DayCycle.current_day else "Tumbuh kembali pada hari %d" % int(record.regrow_day))
			_status.text = "Buka pintu kandang saat cerah. Satu petak untuk satu hewan; tumbuh kembali 2 hari."
		"wooden_chest", "copper_chest", "iron_chest", "gold_chest", "platinum_chest", "crimson_chest", "frost_chest", "shadow_chest", "fairy_chest", "obsidian_chest":
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
				_label(_content, "Tier tertinggi · %d slot" % chest.bag_size)
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
		"preserves_jar":
			if not record.job.is_empty():
				_label(_content, "Sedang mengolah hasil panen. Hasil tetap tersimpan sampai diambil.")
			elif not record.ready.is_empty():
				var item := GameState._resolve_item(record.ready.id)
				_content.add_child(_button("Ambil %s x%d" % [item.display_name, record.ready.count], _collect))
			else:
				_label(_content, "Pilih hasil panen dari tas untuk diolah:")
				for recipe in StructureManager.preserves_jar_recipes():
					var input := GameState._resolve_item(recipe.input_item_id)
					var output := GameState._resolve_item(recipe.output_item_id)
					var button := _button("%s x%d → %s x%d" % [input.display_name, recipe.input_amount, output.display_name, recipe.output_amount], _preserve.bind(recipe))
					button.disabled = not player.data.has_item(recipe.input_item_id, recipe.input_amount)
					_content.add_child(button)
			_status.text = "Olahan hasil panen bernilai jual lebih tinggi. Proses tersimpan saat save."
		"dehydrator":
			if not record.job.is_empty():
				_label(_content, "Sedang mengeringkan hasil panen. Hasil tetap tersimpan sampai diambil.")
			elif not record.ready.is_empty():
				var item := GameState._resolve_item(record.ready.id)
				_content.add_child(_button("Ambil %s x%d" % [item.display_name, record.ready.count], _collect))
			else:
				_label(_content, "Pilih hasil panen dari tas untuk dikeringkan:")
				for recipe in StructureManager.dehydrator_recipes():
					var input := GameState._resolve_item(recipe.input_item_id)
					var output := GameState._resolve_item(recipe.output_item_id)
					var button := _button("%s x%d → %s x%d" % [input.display_name, recipe.input_amount, output.display_name, recipe.output_amount], _dehydrate.bind(recipe))
					button.disabled = not player.data.has_item(recipe.input_item_id, recipe.input_amount)
					_content.add_child(button)
			_status.text = "Hasil pengeringan bernilai jual tinggi. Proses tersimpan saat save."
		"sawmill":
			if not record.job.is_empty():
				_label(_content, "Sedang menggergaji. Hasil tetap tersimpan sampai diambil.")
			elif not record.ready.is_empty():
				var item := GameState._resolve_item(record.ready.id)
				_content.add_child(_button("Ambil %s x%d" % [item.display_name, record.ready.count], _collect))
			else:
				_label(_content, "Pilih kayu dari tas untuk digergaji:")
				for recipe in StructureManager.sawmill_recipes():
					var input := GameState._resolve_item(recipe.input_item_id)
					var output := GameState._resolve_item(recipe.output_item_id)
					var button := _button("%s x%d → %s x%d" % [input.display_name, recipe.input_amount, output.display_name, recipe.output_amount], _saw.bind(recipe))
					button.disabled = not player.data.has_item(recipe.input_item_id, recipe.input_amount)
					_content.add_child(button)
			_status.text = "Papan Kayu dipakai untuk dekorasi dan mesin. Proses tersimpan saat save."
		"beehive":
			if not record.ready.is_empty():
				var item := GameState._resolve_item(record.ready.id)
				var text := "Ambil %s x%d" % [item.display_name, record.ready.count]
				if record.ready.get("extra") is Dictionary:
					text += " + %s x%d" % [GameState._resolve_item(record.ready.extra.id).display_name, record.ready.extra.count]
				_content.add_child(_button(text, _collect))
			elif DayCycle.get_current_season() == "winter":
				_label(_content, "Lebah beristirahat selama Musim Dingin.")
			else:
				var days := maxi(1, int(record.job.get("day", DayCycle.current_day + StructureManager.BEEHIVE_DAYS)) - DayCycle.current_day)
				_label(_content, "Madu siap dalam %d hari." % days)
			_status.text = "Menghasilkan 1 Madu dan 1 Lilin Lebah setiap 3 hari, kecuali Musim Dingin."
		"alchemy_table", "anvil":
			var catalog := StructureManager.station_catalog(str(record.item))
			_label(_content, "Pilih yang ingin dibuat. Bahan diambil dari tas:")
			for recipe in catalog.recipes:
				var output := GameState._resolve_item(recipe.output_item_id)
				var costs: PackedStringArray = []
				for id in recipe.ingredients:
					costs.append("%s x%d" % [GameState._resolve_item(id).display_name, recipe.ingredients[id]])
				var button := _button("%s  ←  %s" % [output.display_name, ", ".join(costs)], _station_craft.bind(recipe))
				button.icon = output.icon
				button.expand_icon = true
				button.add_theme_constant_override("icon_max_width", 18)
				button.clip_text = true
				button.tooltip_text = output.description
				button.disabled = not CraftingSystem.preview(player.data, recipe)["ok"]
				_content.add_child(button)
			_status.text = "Ramuan dimakan dari hotbar." if record.item == "alchemy_table" else "Cincin dan kalung dipasang di menu Equipment."
		"wooden_gate":
			_content.add_child(_button("Tutup gerbang" if record.open else "Buka gerbang", _toggle))
			_status.text = "Gerbang terbuka bisa dilewati pemain."
		"barn":
			_label(_content, "Kandang untuk ternak besar.")
			_status.text = "Belum ada hewan di kandang ini. Kandang kosong bisa dikemas dan dipindahkan."
		"crafting_workbench":
			_content.add_child(_button("Buka Crafting", _open_crafting))
			_status.text = "Meja kerja untuk membuat perlengkapan dan bangunan."
		_:
			if record.item in StructureManager.DECOR:
				_label(_content, "Hiasan farm. Kemas kembali jika ingin memindahkannya.")
			else:
				_label(_content, "Pagar pembatas farm. Kemas kembali jika ingin memindahkannya.")
			_status.text = "Bangunan dikembalikan utuh tanpa biaya bahan tambahan."

func _transfer(slot: int, deposit: bool) -> void:
	var result := StructureManager.transfer(player.data, uid, slot, deposit)
	_refresh()
	_status.text = result.message

func _hay(deposit: bool) -> void:
	var result := StructureManager.store_hay(player.data, uid) if deposit else StructureManager.take_hay(player.data, uid)
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

func _preserve(recipe: PreservesJarRecipe) -> void:
	var result := StructureManager.preserve(player.data, uid, recipe)
	_refresh()
	_status.text = result.message

func _dehydrate(recipe: DehydratorRecipe) -> void:
	var result := StructureManager.dehydrate(player.data, uid, recipe)
	_refresh()
	_status.text = result.message

func _saw(recipe: FurnaceRecipe) -> void:
	var result := StructureManager.saw(player.data, uid, recipe)
	_refresh()
	_status.text = result.message

func _station_craft(recipe: CraftingRecipe) -> void:
	var result := CraftingSystem.craft(player.data, recipe)
	_refresh()
	_status.text = result.message

func _collect() -> void:
	var result := StructureManager.collect(player.data, uid)
	_refresh()
	_status.text = result.message

func _artisan(input: String) -> void:
	var result := StructureManager.process_animal_product(player.data, uid, input)
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
