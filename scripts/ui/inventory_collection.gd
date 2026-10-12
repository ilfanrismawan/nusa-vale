extends PanelContainer
## Penemuan disimpan DiscoveryManager, tetap terbuka setelah item dijual/dibuang.

const FONT = preload("res://assets/fonts/m5x7.ttf")
const CATEGORIES := [ItemData.Category.FISH, ItemData.Category.FORAGE, ItemData.Category.CROP, ItemData.Category.MATERIAL]
var category: ItemData.Category = ItemData.Category.FISH
var catalog: Array[ItemData] = []
var _summary: Label
var _list: GridContainer
var _detail: Label
var _filters: Array[Button] = []
var _metadata: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.79, 0.62)
	style.border_color = Color(0.55, 0.32, 0.2)
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", Color(0.28, 0.16, 0.11))
	theme = ui_theme
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	add_child(content)
	var filters := HBoxContainer.new()
	content.add_child(filters)
	for i in range(CATEGORIES.size()):
		var button := Button.new()
		button.text = ["Ikan", "Hutan", "Tanaman", "Mineral"][i]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(_set_category.bind(CATEGORIES[i]))
		filters.add_child(button)
		_filters.append(button)
	_summary = Label.new()
	content.add_child(_summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_list = GridContainer.new()
	_list.columns = 2
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("h_separation", 4)
	_list.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_list)
	_detail = Label.new()
	_detail.custom_minimum_size = Vector2(0, 38)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.max_lines_visible = 2
	_detail.clip_text = true
	content.add_child(_detail)
	_load_catalog()
	DiscoveryManager.discovered.connect(_on_discovered)
	refresh()

func _load_catalog() -> void:
	for folder in ["fish_data", "forage_data"]:
		for file in DirAccess.get_files_at("res://resources/" + folder):
			var name_text := file.trim_suffix(".remap")
			if not name_text.ends_with(".tres"):
				continue
			var resource := load("res://resources/" + folder + "/" + name_text)
			if resource is FishData or resource is ForageData:
				_metadata[resource.item.item_id] = resource
	for file in DirAccess.get_files_at("res://resources/item_data"):
		var name_text := file.trim_suffix(".remap")
		if not name_text.ends_with(".tres"):
			continue
		var item := load("res://resources/item_data/" + name_text) as ItemData
		if item == null or not CATEGORIES.has(item.category):
			continue
		if item.category == ItemData.Category.MATERIAL and not (item.item_id.ends_with("_ore") or item.item_id.ends_with("_bar") or item.item_id in ["stone", "coal"]):
			continue
		catalog.append(item)
	catalog.sort_custom(func(a: ItemData, b: ItemData): return a.display_name.naturalnocasecmp_to(b.display_name) < 0)

func is_known(item: ItemData) -> bool:
	return DiscoveryManager.has_discovered("item_" + item.item_id) or (item.category == ItemData.Category.FISH and DiscoveryManager.has_discovered("fish_" + item.item_id))

func _set_category(value: ItemData.Category) -> void:
	category = value
	refresh()

func refresh() -> void:
	if not is_instance_valid(_list):
		return
	# Migrasi save lama: item yang masih dimiliki semua pemain ikut dicatat.
	for data in GameState.players:
		for slot in data.inventory:
			if slot != null and slot.get("item") != null and CATEGORIES.has(slot.item.category):
				DiscoveryManager.discover("item_" + slot.item.item_id)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var found := 0
	var total := 0
	for item in catalog:
		if item.category != category:
			continue
		total += 1
		var known := is_known(item)
		if known:
			found += 1
		var button := Button.new()
		button.custom_minimum_size = Vector2(185, 26)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = item.display_name if known else "??? Belum ditemukan"
		button.icon = item.icon if known else null
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 20)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_show_detail.bind(item))
		_list.add_child(button)
	_summary.text = "%d / %d ditemukan - penemuan bersama semua pemain" % [found, total]
	_detail.text = "Pilih penemuan untuk melihat info. ??? akan terbuka saat ditemukan."
	for i in range(_filters.size()):
		_filters[i].set_pressed_no_signal(category == CATEGORIES[i])

func _show_detail(item: ItemData) -> void:
	if not is_known(item):
		_detail.text = "Belum ditemukan. Jelajahi dunia untuk membuka catatan ini."
		return
	var info: Resource = _metadata.get(item.item_id)
	var text := item.description
	if info is FishData:
		text = "Lokasi: %s | %02d:00-%02d:00" % [", ".join(info.locations), info.min_hour, info.max_hour]
	elif info is ForageData:
		text = "Lokasi: %s | %s" % [", ".join(info.locations), "Semua musim" if info.seasons.is_empty() else ", ".join(info.seasons)]
	_detail.text = "%s - %d G\n%s" % [item.display_name, item.sell_price, text]

func _on_discovered(_id: String) -> void:
	if visible:
		# Deferred agar migrasi penemuan tidak memanggil refresh secara rekursif.
		if not _refresh_pending:
			_refresh_pending = true
			call_deferred("_refresh_discoveries")

var _refresh_pending := false
func _refresh_discoveries() -> void:
	_refresh_pending = false
	refresh()
